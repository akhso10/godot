extends SceneTree
## Accelerated physical traversal of the real campus. Every step moves a real
## player capsule against the level via the character's input and move_and_slide.
const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Story = preload("res://scripts/story.gd")
const Actors = preload("res://scripts/actors.gd")
var world
var player
var story
var actors
var checks := 0
var failures := 0
var rooms := {}
var ascent := false
var descent := false
var captured := false

func _initialize() -> void:
	call_deferred("run")

func check(ok:bool,why:String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",why)

func walk(target:Vector3, near:float=0.25) -> bool:
	var flat := Vector2(target.x-player.position.x,target.z-player.position.z)
	var limit := int(flat.length()*45+240)
	var last:Vector3 = player.position
	Input.action_press("raka_forward")
	for i in limit:
		flat = Vector2(target.x-player.position.x,target.z-player.position.z)
		if flat.length() < near:
			Input.action_release("raka_forward")
			return absf(target.y-player.position.y)<.36
		player.rotation.y = atan2(-flat.x,-flat.y)
		await physics_frame
		if i%90 == 89:
			if player.position.distance_to(last)<.1: break
			last = player.position
	Input.action_release("raka_forward")
	printerr("Stuck at ",player.position," heading to ",target)
	return false

func travel(goal:Vector3) -> bool:
	var spline:Array = world.route_between(player.position,goal)
	for point in spline:
		if not await walk(point): return false
	return true

func ray(origin:Vector3,target:Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(origin,target,1)
	return not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func run() -> void:
	world = World.new()
	root.add_child(world)
	world.setup()
	player = Player.new()
	root.add_child(player)
	player.position = world.spawn_position
	player.active = true
	story = Story.new()
	world.apply_progress(story)
	for i in 10: await physics_frame
	check(ray(Vector3(0,1.2,26),Vector3(0,1.2,23)),"gate closed at start")
	check(ray(Vector3(-15.8,1.1,0),Vector3(-15.8,1.1,-4)),"class door closed at start")
	check(await walk(world.interaction_position(story.objective())),"first goal outside gate")
	story.interact("enter_school")
	world.apply_progress(story)
	for i in 45: await physics_frame
	check(not ray(Vector3(0,1.2,26),Vector3(0,1.2,23)),"gate opens after first mission")
	check(await walk(Vector3(1.65,0,20.3)),"walk physically through opened gate")
	# Traverse every authored mission on the full rescue route. The story state
	# drives actual locks and lights; chase AI is tested separately below.
	while not story.objective().is_empty():
		var q:Dictionary = story.objective()
		var goal:Vector3 = world.interaction_position(q)
		var previous_y:float = player.position.y
		var ok := await travel(goal)
		check(ok,"physically reach "+q.id+" in "+q.room)
		if not ok: break
		ascent = ascent or goal.y-previous_y>3
		descent = descent or previous_y-goal.y>3
		rooms[q.room] = true
		var result:Dictionary = story.interact(q.id)
		if q.has("p"):
			for idx in q.p.order:
				result = story.choose(result.choices.find(q.p.cards[idx]))
		elif q.has("decision"): story.choose(0)
		world.apply_progress(story)
		for i in 41: await physics_frame
		if q.id=="unlock_class":
			check(not ray(Vector3(-15.8,1.1,0),Vector3(-15.8,1.1,-4)),"class physically unlocked")
		if q.id=="blackout": check(world._phase=="blackout","power loss")
		if q.id=="generator": check(world._phase=="night","restored power")
	check(ascent and descent,"stairs both directions")
	check(story.ending=="good","through gate to ending")
	actors = Actors.new()
	root.add_child(actors)
	actors.setup(player,world)
	actors.set_stage(1)
	player.position = Vector3(1.65,0,19)
	actors._put("guardian",Vector3(8,0,0))
	var old_pos:Vector3 = actors.bodies.guardian.body.position
	for i in 180: await physics_frame
	check(actors.bodies.guardian.body.position.distance_to(old_pos)>1.0,"patrol moves physically")
	actors._put("guardian",Vector3(1.65,0,11))
	actors.bodies.guardian.model.rotation.y = 0.0
	actors.calm_time=0
	actors.perception_clock=0
	actors._set_state(Actors.State.IDLE,2.0)
	for i in 20: await physics_frame
	check(actors.state==Actors.State.CHASE,"clear line of sight starts chase")
	player.hidden=true
	for i in 30: await physics_frame
	check(actors.state!=Actors.State.CHASE,"hiding breaks chase")
	player.hidden=false
	actors._put("guardian",Vector3(1.65,0,18.4))
	actors.bodies.guardian.model.rotation.y=0
	actors.caught.connect(func(): captured=true)
	for i in 22: await physics_frame
	check(captured,"guardian capture signal")
	actors.set_stage(0)
	actors._put("reski",Vector3(1.65,0,12.5))
	var before:float = actors.bodies.reski.body.position.distance_to(player.position)
	for i in 220: await physics_frame
	check(actors.bodies.reski.body.position.distance_to(player.position)<before-1.5,"Reski follows physically")
	print("Physical campus: ",rooms.size()," visited mission locations; ",checks," checks; failures: ",failures)
	player.active = false
	for audio in root.find_children("*","AudioStreamPlayer3D",true,false):
		audio.stop()
	# The dummy audio driver drains its mixing buffer in wall-clock time even
	# when physics is accelerated with --fixed-fps.
	for i in 24:
		OS.delay_msec(8)
		await process_frame
	actors.queue_free()
	player.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
