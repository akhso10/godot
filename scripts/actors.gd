extends Node3D
## Characters use authored routes through the corridors, doorways and ramp.
## Each waypoint is approached by a physics body, so walls still block movement.

signal caught
signal guardian_state_changed(state: String)
signal subtitle(speaker: String, line: String)

const MODELS := {
	"reski": preload("res://assets/models/characters/reski_character.glb"),
	"akbar": preload("res://assets/models/characters/akbar_character.glb"),
	"laras": preload("res://assets/models/characters/laras_character.glb"),
	"guardian": preload("res://assets/models/characters/shadow_guardian_character.glb")
}
enum State {IDLE, PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, CHASE, ATTACK, RETURN, STUNNED}
var state := State.IDLE
var stage := 0
var difficulty := "Normal"
var player
var world
var bodies: Dictionary = {}
var rescued: Dictionary = {"reski": false, "akbar": false}
var remaining := 0.0
var patrol_index := 0
var last_seen := Vector3.ZERO
var unseen := 0.0
var perception_clock := 0.0
var can_see := false
var recently_caught := false
var apparition_seen := false
var ghost_clock := 0.0
var calm_time := 0.0
var patrol: Array[Vector3] = []
var after_catch := 0.0
var evacuation := false
var guard_sound := AudioStreamPlayer3D.new()
var guard_steps := AudioStreamPlayer3D.new()
var stride := 0.0

func setup(controller, school) -> void:
	player = controller
	world = school
	for id in MODELS:
		_add_character(id)
	patrol.assign(school.patrol_points)
	if patrol.is_empty():
		patrol.append(school.stations["security"])
		patrol.append(school.stations["teachers"])
	bodies.guardian.body.add_child(guard_sound)
	guard_sound.bus = "SFX"
	guard_sound.max_distance = 19
	guard_sound.position.y = 1.5
	bodies.guardian.body.add_child(guard_steps)
	guard_steps.bus = "SFX"
	guard_steps.max_distance = 12
	guard_steps.stream = load("res://assets/audio/effects/guardian_footstep.ogg")
	player.sound_made.connect(_heard)
	set_stage(0)

func _add_character(id: String) -> void:
	var body := CharacterBody3D.new()
	body.name = id.capitalize()
	body.collision_layer = 0
	body.collision_mask = 1
	body.floor_snap_length = 0.35
	body.floor_max_angle = deg_to_rad(48)
	add_child(body)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.67
	capsule.radius = .24
	col.shape = capsule
	col.position.y = capsule.height/2
	body.add_child(col)
	var model: Node3D = MODELS[id].instantiate()
	body.add_child(model)
	var animation: AnimationPlayer = model.find_child("AnimationPlayer",true,false)
	if animation:
		for clip in animation.get_animation_list():
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	bodies[id] = {"body": body, "model": model, "anim": animation, "path": [],
		"route_time": 0.0, "target": Vector3.INF, "stuck": 0.0, "last_pos": Vector3.INF,
		"home": Vector3.ZERO, "recover": 0.0}
	_play(id, "Idle")

func _station(id: String) -> Vector3:
	return world.stations.get(id, world.spawn_position)

func _put(id: String, point: Vector3) -> void:
	var record: Dictionary = bodies[id]
	var body: CharacterBody3D = record.body
	body.global_position = point + Vector3.UP * .08
	body.velocity = Vector3.ZERO
	record.path = []
	record.target = Vector3.INF
	record.route_time = 0.0
	record.stuck = 0.0
	record.last_pos = body.global_position
	record.home = point

func set_stage(chapter: int) -> void:
	var changed := stage != chapter
	stage = chapter
	if bodies.is_empty():
		return
	if chapter < 5:
		evacuation = false
	if chapter == 0:
		rescued = {"reski": false, "akbar": false}
		_put("reski", player.global_position + Vector3(1.0,0,-1.65))
		_put("akbar", player.global_position + Vector3(-1.0,0,-1.85))
		apparition_seen = false
	else:
		if not rescued.reski:
			_put("reski", _station("power" if evacuation else "lab") + Vector3(1.1,0,.3))
		if not rescued.akbar:
			_put("akbar", _station("clinic") + Vector3(-1.15,0,.3))
	for id in ["reski","akbar"]:
		bodies[id].body.visible = chapter == 0 or rescued[id] or chapter >= (2 if id=="reski" else 3)
	bodies.guardian.body.visible = chapter >= 1
	bodies.laras.body.visible = false
	ghost_clock = 0.0
	recently_caught = false
	if chapter == 0 or (chapter == 1 and changed) or chapter == 5 or bodies.guardian.home == Vector3.ZERO:
		var start: Vector3 = patrol[patrol.size()/2]
		# Final pursuit starts in a known corridor, granting several steps of lead.
		if chapter == 5:
			start = _station("hall")
		_put("guardian", start)
		patrol_index = 0
	calm_time = 3.5
	_set_state(State.PATROL if chapter > 0 else State.IDLE, 1.0)

func rescue(id: String) -> void:
	var key := id.to_lower()
	if not rescued.has(key):
		return
	rescued[key] = true
	if bodies.has(key):
		bodies[key].body.visible = true
		bodies[key].route_time = 0.0

func begin_evacuation() -> void:
	evacuation = true
	rescued = {"reski": false, "akbar": false}
	_put("reski", _station("power") + Vector3(1.0,0,.4))
	_put("akbar", _station("clinic") + Vector3(-1.0,0,.4))
	_guard_effect("guardian_chase")
	_investigate(_station("speaker"))

func _guard_effect(id: String) -> void:
	guard_sound.stream = load("res://assets/audio/effects/" + id + ".ogg")
	guard_sound.play()

func alarm() -> void:
	if stage > 0 and not bodies.is_empty():
		_investigate(player.global_position)

func stun(seconds: float = 3.0) -> void:
	if stage > 0:
		_set_state(State.STUNNED, seconds)

func _heard(position_heard: Vector3, radius: float) -> void:
	if stage < 1 or calm_time > 0 or state in [State.ATTACK, State.STUNNED, State.CHASE]:
		return
	var guard: CharacterBody3D = bodies.guardian.body
	if guard.global_position.distance_to(position_heard) <= radius * _factor() and absf(guard.global_position.y-position_heard.y) < 2.2:
		_investigate(position_heard)

func _investigate(position_heard: Vector3) -> void:
	last_seen = position_heard
	if state != State.CHASE:
		_set_state(State.SUSPICIOUS,.55)

func _factor() -> float:
	match difficulty.to_lower():
		"story", "cerita": return .69
		"nightmare", "mimpi buruk": return 1.35
		_: return 1.0

func _set_state(next: State, seconds: float = 0.0) -> void:
	if state != next:
		guardian_state_changed.emit(State.keys()[next])
		if next == State.CHASE:
			_guard_effect("guardian_detect")
		elif next == State.SEARCH:
			_guard_effect("guardian_breath")
	state = next
	remaining = seconds

func _visible_from_player(point: Vector3) -> bool:
	if player.camera.is_position_behind(point):
		return false
	return player.get_viewport().get_visible_rect().has_point(player.camera.unproject_position(point))

func _sight() -> bool:
	var guard: CharacterBody3D = bodies.guardian.body
	if player.hidden:
		return false
	var eye := guard.global_position + Vector3.UP * 1.72
	var endpoint: Vector3 = player.look.global_position
	var delta := endpoint-eye
	var sight_radius := (12.0 if stage >= 4 else 9.0) * _factor()
	if player.crouched:
		sight_radius *= .64
	if delta.length() > sight_radius:
		return false
	var facing: Vector3 = bodies.guardian.model.global_transform.basis.z
	if state != State.CHASE and delta.length() > 2.0 and facing.dot(delta.normalized()) < .36:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, endpoint, 1, [guard.get_rid(),player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(dt: float) -> void:
	if player == null or not player.active:
		return
	calm_time = maxf(0,calm_time-dt)
	for id in ["reski","akbar"]:
		_friend_tick(id,dt)
	if stage > 0:
		_guard_tick(dt)
		_ghost_tick(dt)

func _friend_tick(id: String, dt:float) -> void:
	var r: Dictionary = bodies[id]
	var npc: CharacterBody3D = r.body
	if not npc.visible:
		return
	if stage != 0 and not rescued[id]:
		_stand(id,dt,"Search")
		return
	var distance := npc.global_position.distance_to(player.global_position)
	var separated := distance > 12.0
	# If a follower lags behind a bend, resume on an earlier point in the
	# player's corridor. Recovery is allowed only with both points off camera.
	r.recover = float(r.recover) + dt if separated else 0.0
	if r.recover > 3.5 and not _visible_from_player(npc.global_position + Vector3.UP):
		var trail: Array = world.route_between(npc.global_position,player.global_position)
		for i in range(trail.size()-1,-1,-1):
			var node: Vector3 = trail[i]
			if node.distance_to(player.global_position) > 3.4 and node.distance_to(player.global_position) < 10.0 and not _visible_from_player(node + Vector3.UP):
				_put(id,node)
				break
		r.recover = 0.0
	if distance < (2.15 if id=="reski" else 2.75) or player.hidden:
		_stand(id,dt,"Idle")
		return
	var speed := 4.25 if distance > 5.5 else 2.55
	_move(id,player.global_position,speed,dt)

func _guard_tick(dt: float) -> void:
	if recently_caught:
		after_catch -= dt
		if after_catch > 0:
			return
		recently_caught = false
		_put("guardian",patrol[patrol_index % patrol.size()])
		calm_time = 3
		_set_state(State.RETURN)
	var guard: CharacterBody3D = bodies.guardian.body
	remaining -= dt
	perception_clock -= dt
	if perception_clock <= 0:
		perception_clock = .13
		can_see = _sight()
	if state != State.STUNNED and calm_time <= 0 and can_see:
		unseen = 0
		last_seen = player.global_position
		_set_state(State.CHASE)
	else:
		unseen += dt
	match state:
		State.IDLE:
			_stand("guardian",dt,"Search")
			if remaining <= 0: _set_state(State.PATROL)
		State.PATROL, State.RETURN:
			if _move("guardian",patrol[patrol_index],1.0*_factor(),dt):
				patrol_index = (patrol_index+1) % patrol.size()
				_set_state(State.IDLE, 1.8)
		State.SUSPICIOUS:
			_stand("guardian",dt,"Search")
			if remaining <= 0: _set_state(State.INVESTIGATE)
		State.INVESTIGATE:
			if _move("guardian",last_seen,1.62*_factor(),dt):
				_set_state(State.SEARCH,3.0*_factor())
		State.SEARCH:
			_stand("guardian",dt,"Search")
			bodies.guardian.model.rotate_y(dt*.72)
			if remaining <= 0: _set_state(State.RETURN)
		State.CHASE:
			if unseen > 2.2 or player.hidden:
				_set_state(State.INVESTIGATE)
			elif _move("guardian",last_seen,(3.15 if stage == 5 else 2.70)*_factor(),dt) or guard.global_position.distance_to(player.global_position) < .96:
				if can_see and not player.hidden and guard.global_position.distance_to(player.global_position) < 1.0:
					_set_state(State.ATTACK,.40)
					recently_caught = true
					after_catch = 2.0
					_play("guardian","Startle")
					caught.emit()
		State.STUNNED:
			_stand("guardian",dt,"Startle")
			if remaining <= 0: _set_state(State.RETURN)
		State.ATTACK: _stand("guardian",dt,"Startle")

func _ghost_tick(dt: float) -> void:
	if not apparition_seen and stage >= 3 and player.global_position.distance_to(_station("archive")) < 12:
		apparition_seen = true
		_put("laras",_station("archive") + Vector3(1,0,.6))
		var ghost: CharacterBody3D = bodies.laras.body
		ghost.visible = true
		ghost_clock = 6.0
		subtitle.emit("Laras", "Masih ada salinannya. Cari di antara berkas yang gosong.")
	if ghost_clock > 0:
		ghost_clock -= dt
		_face("laras",player.global_position,dt)
		var pose := "Appear" if ghost_clock > 4.4 else ("Disappear" if ghost_clock < 1.7 else "Float")
		_stand("laras",dt,pose)
		bodies.laras.body.visible = ghost_clock > 0

func _face(id: String,target: Vector3,dt: float) -> void:
	var r: Dictionary = bodies[id]
	var offset: Vector3 = target - r.body.global_position
	if Vector2(offset.x,offset.z).length_squared() > .02:
		r.model.rotation.y = lerp_angle(r.model.rotation.y,atan2(offset.x,offset.z),1-exp(-8*dt))

func _stand(id: String,dt: float,clip: String) -> void:
	var body: CharacterBody3D = bodies[id].body
	body.velocity.x = 0
	body.velocity.z = 0
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - dt*15.0
	body.move_and_slide()
	_play(id,clip)

func _move(id: String,target: Vector3,speed: float,dt: float) -> bool:
	var r: Dictionary = bodies[id]
	var body: CharacterBody3D = r.body
	var here := body.global_position
	if here.distance_to(target) < .60:
		_stand(id,dt,"Idle")
		return true
	r.route_time = float(r.route_time) - dt
	if r.route_time <= 0.0 and (r.path.is_empty() or target.distance_to(r.target) > .60 or r.stuck > .8):
		r.path = world.route_between(here,target)
		r.target = target
		r.route_time = .65
		r.stuck = 0
	while not r.path.is_empty():
		var first: Vector3 = r.path.front()
		if Vector2(first.x-here.x,first.z-here.z).length() > .38:
			break
		r.path.pop_front()
	var destination: Vector3 = target if r.path.is_empty() else r.path.front()
	var flat := Vector3(destination.x-here.x,0,destination.z-here.z)
	var direction := flat.normalized()
	body.velocity.x = direction.x*speed
	body.velocity.z = direction.z*speed
	body.velocity.y = 0 if body.is_on_floor() else body.velocity.y-dt*15
	body.move_and_slide()
	if id == "guardian":
		stride += body.global_position.distance_to(here)
		if stride > 1.24:
			stride = 0
			guard_steps.pitch_scale = randf_range(.85,1.0)
			guard_steps.play()
	_face(id,destination,dt)
	_play(id,"Run" if speed > 3.0 else "Walk")
	if here.distance_to(body.global_position) < dt*speed*.15:
		r.stuck = float(r.stuck)+dt
	else:
		r.stuck = 0
	return false

func _play(id: String, clip: String) -> void:
	var anim: AnimationPlayer = bodies[id].anim
	if id == "guardian":
		match state:
			State.PATROL: clip = "Patrol" if clip == "Walk" else clip
			State.SUSPICIOUS: clip = "Listen"
			State.INVESTIGATE: clip = "Investigate" if clip == "Walk" else "HeadTurn"
			State.CHASE: clip = "Chase" if clip in ["Walk", "Run"] else clip
			State.ATTACK: clip = "Attack"
			State.RETURN: clip = "ReturnPatrol" if clip == "Walk" else clip
	elif id in ["akbar", "reski"]:
		if clip == "Search":
			clip = "NervousIdle"
		elif clip == "Idle" and player and player.hidden:
			clip = "Hide"
		elif clip in ["Walk", "Run"]:
			clip = "Escape" if clip == "Run" else "Follow"
	if anim and anim.has_animation(clip) and anim.current_animation != clip:
		anim.play(clip,.20)
