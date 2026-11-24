extends CharacterBody3D
## First-person controller. Its origin is at shoe level. World colliders may expose
## interaction_id and interaction_label metadata to the centre-screen ray.

signal interacted(id: String)
signal shortcut(action: String)
signal notice(message: String)
signal sound_made(location: Vector3, radius: float)

const LIGHT_MODEL = preload("res://assets/models/characters/raka_first_person_hands.glb")
const EFFECT_FOLDER := "res://assets/audio/effects/"
const WALK_SPEED := 2.7
const RUN_SPEED := 5.0
const CROUCH_SPEED := 1.38
const HEIGHT := 1.76
const LOW_HEIGHT := 1.05
const FOOT_RADIUS := 0.28
const REACH := 3.0

var active := false:
	set(value):
		active = value
		if is_inside_tree():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
		if not value:
			velocity.x = 0
			velocity.z = 0
var prompt := ""
var stamina := 100.0
var battery := 100.0
var spare_batteries := 0
var has_flashlight := false
var head_bob := true
var sensitivity := 0.0024
var hidden := false
var crouched := false
var is_sprinting := false
var look := Node3D.new()
var camera := Camera3D.new()
var flashlight := SpotLight3D.new()
var body_collision := CollisionShape3D.new()
var capsule := CapsuleShape3D.new()
var interaction := RayCast3D.new()
var foot_audio := AudioStreamPlayer3D.new()
var hand: Node3D
var target_id := ""
var torch_on := true
var sweep := 0.0
var step_distance := 0.0
var hand_motion := 0.0
var exhausted := false
var hand_audio := AudioStreamPlayer3D.new()
var step_variant := 0
var clips := {}

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48)
	capsule.radius = FOOT_RADIUS
	capsule.height = HEIGHT
	body_collision.shape = capsule
	body_collision.position.y = HEIGHT / 2
	add_child(body_collision)
	look.position.y = HEIGHT - 0.14
	add_child(look)
	look.add_child(camera)
	camera.fov = 76
	camera.near = 0.045
	camera.current = true
	camera.add_child(interaction)
	interaction.enabled = true
	interaction.target_position = Vector3.FORWARD * REACH
	interaction.collision_mask = 1 | 4 | 8
	interaction.collide_with_areas = true
	interaction.add_exception(self)
	camera.add_child(flashlight)
	flashlight.position = Vector3(0.19, -0.14, -0.22)
	flashlight.spot_range = 19
	flashlight.spot_attenuation = 0.65
	flashlight.spot_angle = 34
	flashlight.light_energy = 3.0
	flashlight.light_color = Color("#ffeac6")
	flashlight.shadow_enabled = false
	flashlight.visible = has_flashlight and torch_on
	hand = LIGHT_MODEL.instantiate()
	camera.add_child(hand)
	hand.position = Vector3(0.16, -0.165, -0.36)
	hand.visible = has_flashlight
	add_child(hand_audio)
	hand_audio.bus = "SFX"
	hand_audio.volume_db = -8
	add_child(foot_audio)
	foot_audio.bus = "SFX"
	foot_audio.max_distance = 8
	foot_audio.unit_size = 2
	foot_audio.volume_db = -10
	_register_input()

func _register_input() -> void:
	var keys := {"raka_left": KEY_A, "raka_right": KEY_D, "raka_forward": KEY_W,
		"raka_back": KEY_S, "raka_sprint": KEY_SHIFT, "raka_crouch": KEY_CTRL, "raka_jump": KEY_SPACE}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not hidden:
		rotate_y(-event.relative.x * sensitivity)
		look.rotation.x = clampf(look.rotation.x-event.relative.y*sensitivity, -1.39, 1.39)
		return
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_E:
			_use()
		KEY_F:
			if has_flashlight and battery > 0:
				torch_on = not torch_on
				_effect("flashlight_click")
				hand_motion = 0.45
			else:
				notice.emit("Cari senter di pos satpam." if not has_flashlight else "Baterai habis. Tekan R untuk menggantinya.")
		KEY_R:
			if has_flashlight and spare_batteries > 0 and battery < 99:
				_effect("battery_change")
				spare_batteries -= 1
				battery = 100
				torch_on = true
				hand_motion = 1.0
				notice.emit("Baterai senter diganti.")
			else:
				notice.emit("Tidak ada baterai cadangan." if spare_batteries == 0 else "Senter belum perlu baterai baru.")
		KEY_Q: shortcut.emit("radio")
		KEY_TAB: shortcut.emit("inventory")
		KEY_J: shortcut.emit("journal")
		KEY_M: shortcut.emit("map")
		KEY_ESCAPE: shortcut.emit("pause")
		_: return
	get_viewport().set_input_as_handled()

func _use() -> void:
	if hidden:
		hidden = false
		_effect("locker_open")
		notice.emit("Raka keluar dari persembunyian.")
		return
	_scan()
	if target_id.begins_with("hide:"):
		hidden = true
		_effect("locker_close")
		torch_on = false
		notice.emit("Kau menahan napas. Tekan E untuk keluar.")
	elif not target_id.is_empty():
		hand_motion = 0.85
		sound_made.emit(global_position, 3.0)
		interacted.emit(target_id)

func _scan() -> void:
	target_id = ""
	prompt = ""
	if hidden:
		prompt = "Keluar dari persembunyian"
		return
	interaction.force_raycast_update()
	var hit = interaction.get_collider()
	if hit is Node and hit.has_meta("interaction_id"):
		target_id = str(hit.get_meta("interaction_id"))
		prompt = str(hit.get_meta("interaction_label", "Periksa"))

func _can_stand() -> bool:
	# Test the standing capsule, excluding the player and lifting off the floor
	# by a small skin to avoid touching the ground at the current foot position.
	var standing := CapsuleShape3D.new()
	standing.radius = FOOT_RADIUS - 0.015
	standing.height = HEIGHT - 0.04
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = standing
	params.transform.origin = global_position + Vector3.UP * (HEIGHT/2 + 0.015)
	params.collision_mask = 1
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()

func _physics_process(dt: float) -> void:
	if not active:
		return
	_scan()
	var want_low := hidden or Input.is_action_pressed("raka_crouch")
	if want_low != crouched and (want_low or _can_stand()):
		crouched = want_low
		capsule.height = LOW_HEIGHT if crouched else HEIGHT
		body_collision.position.y = capsule.height / 2
	var move := Input.get_vector("raka_left","raka_right","raka_forward","raka_back")
	if hidden:
		move = Vector2.ZERO
	is_sprinting = Input.is_action_pressed("raka_sprint") and move.length_squared() > 0.2 and not crouched and not exhausted
	stamina = clampf(stamina + (-13.0 if is_sprinting else 9.0) * dt, 0, 100)
	if stamina < 1:
		exhausted = true
	elif stamina >= 20:
		exhausted = false
	var speed := CROUCH_SPEED if crouched else (RUN_SPEED if is_sprinting else WALK_SPEED)
	var direction := global_transform.basis * Vector3(move.x, 0, move.y)
	velocity.x = move_toward(velocity.x, direction.x*speed, 17.0*dt)
	velocity.z = move_toward(velocity.z, direction.z*speed, 17.0*dt)
	if not is_on_floor():
		velocity.y -= 15.0 * dt
	elif Input.is_action_just_pressed("raka_jump") and not crouched:
		velocity.y = 3.4
		sound_made.emit(global_position, 6.0)
	move_and_slide()
	var travelled := Vector2(get_real_velocity().x, get_real_velocity().z).length() * dt
	if is_on_floor():
		step_distance += travelled
		sweep += travelled * 4.65
		if step_distance > (1.38 if is_sprinting else .96):
			step_distance = 0.0
			var surface := "ceramic"
			if global_position.z > 5 and global_position.y < 1:
				surface = "water" if global_position.z > 12 else "concrete"
			elif global_position.y > 3 and absf(global_position.z) > 3:
				surface = "wood"
			step_variant = 1 - step_variant
			foot_audio.stream = _clip("res://assets/audio/footsteps/footstep_%s_0%d.ogg" % [surface,step_variant+1])
			foot_audio.pitch_scale = randf_range(.92, 1.08)
			foot_audio.volume_db = -16.0 if crouched else (-6.0 if is_sprinting else -10.0)
			foot_audio.play()
			sound_made.emit(global_position, 1.5 if crouched else (11.0 if is_sprinting else 4.5))
	var bob := sin(sweep)*minf(travelled*32,1.0)*0.023 if head_bob else 0.0
	look.position.y = lerpf(look.position.y, capsule.height - 0.14 + bob, 1.0-exp(-12.0*dt))
	if has_flashlight and torch_on and battery > 0 and not hidden:
		battery = maxf(0, battery - .11*dt)
		if battery <= 0:
			torch_on = false
			notice.emit("Senter padam. Tekan R untuk mengganti baterai.")
	flashlight.visible = has_flashlight and torch_on and battery > 0 and not hidden
	hand.visible = has_flashlight and not hidden
	hand_motion = maxf(0, hand_motion - dt*1.4)
	hand.rotation.x = -sin(hand_motion*PI)*.64
	hand.position.y = -.165 + bob*.4 - sin(hand_motion*PI)*.04


func _effect(id: String) -> void:
	hand_audio.stream = _clip(EFFECT_FOLDER + id + ".ogg")
	hand_audio.play()

func _clip(path: String) -> AudioStream:
	if not clips.has(path):
		clips[path] = load(path)
	return clips[path]
