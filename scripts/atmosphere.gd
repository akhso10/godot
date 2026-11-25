extends Node3D
## Lightweight practical effects for the school. Story cues wait for gameplay to
## resume, so closing a dialogue never skips the event it just introduced.

const VFX := "res://assets/vfx/"
const FIGURE := preload("res://assets/models/characters/laras_character.glb")
const REFLECTION := preload("res://assets/art/laras_portrait.webp")
const MASKS := ["dust_particle", "mist_particle", "rain_particle", "flashlight_cookie",
	"light_halo", "wet_footprint", "window_droplets", "glass_crack", "shadow_smoke",
	"vignette", "static_noise", "camera_noise", "subtle_film_grain", "flicker_mask",
	"paranormal_distortion"]
const FLOOR_PRINTS := 8

var player
var world
var masks := {}
var props := {}
var dust := CPUParticles3D.new()
var haze := CPUParticles3D.new()
var overlay := CanvasLayer.new()
var screen_mask := TextureRect.new()
var feedback := TextureRect.new()
var torch_glow: Sprite3D
var reflection: Sprite3D
var figure: Node3D
var smoke: Sprite3D
var prints: Array[Sprite3D] = []
var print_cursor := 0
var wet_steps := 0
var last_step := Vector3.ZERO
var remaining := 0.0
var duration := 0.0
var strength := 0.0
var cooldown := 0.0
var apparition_life := 0.0
var mirror_glimpse := false
var library_glimpse := false
var pending := ""
var sample_clock := 0.0
var sound_source := AudioStreamPlayer3D.new()
var room_audio := {}
var current_room := ""
var active_tweens: Array[Tween] = []
var initialized := false

func setup(controller, campus) -> void:
	if initialized:
		return
	initialized = true
	player = controller
	world = campus
	for id in MASKS:
		masks[id] = load(VFX+id+".png")
	for child in world.get_children():
		if child is Node3D and not child.scene_file_path.is_empty():
			var id:String = child.scene_file_path.get_file().get_basename()
			if not props.has(id): props[id] = []
			props[id].append(child)
	_particles(dust, "dust_particle", 14, Color(.8,.78,.66,.58), .026, 4.0)
	_particles(haze, "mist_particle", 6, Color(.55,.65,.60,.14), 2.8, 6.0)
	haze.position = Vector3(1.5,.65,17)
	haze.emission_box_extents = Vector3(9,.25,3.5)
	haze.direction = Vector3.LEFT
	for i in FLOOR_PRINTS:
		var mark := _sprite("wet_footprint",.16)
		mark.rotation.x = -PI*.5
		mark.visible = false
		prints.append(mark)
	smoke = _sprite("shadow_smoke",1.6)
	smoke.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	smoke.visible = false
	figure = FIGURE.instantiate()
	add_child(figure)
	figure.visible = false
	reflection = Sprite3D.new()
	reflection.texture = REFLECTION
	reflection.pixel_size = .65 / float(REFLECTION.get_height())
	reflection.modulate = Color(.55,.69,.61,.65)
	reflection.visible = false
	add_child(reflection)
	torch_glow = _sprite("flashlight_cookie",.52)
	torch_glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	torch_glow.visible = false
	_install_practicals()
	add_child(overlay)
	# Below the HUD and dialogs. All effects leave pointer input to the UI.
	overlay.layer = 0
	for image in [screen_mask,feedback]:
		overlay.add_child(image)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.visible = false
	sound_source.bus = &"SFX" if AudioServer.get_bus_index("SFX")>=0 else &"Master"
	sound_source.max_distance = 17
	sound_source.unit_size = 3
	add_child(sound_source)
	for id in ["metal_drag","glass_creak","paper_turn","guardian_breath","door_creak"]:
		room_audio[id] = load("res://assets/audio/effects/"+id+".ogg")
	last_step = player.global_position
	visibility_changed.connect(_visibility_changed)

func _particles(emitter:CPUParticles3D,id:String,count:int,tint:Color,width:float,life:float) -> void:
	emitter.amount = count
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.emission_box_extents = Vector3(1.35,.78,1.4)
	emitter.lifetime = life
	emitter.preprocess = life*.6
	emitter.local_coords = false
	emitter.gravity = Vector3.ZERO
	emitter.direction = Vector3.UP
	emitter.spread = 58
	emitter.initial_velocity_min = .04
	emitter.initial_velocity_max = .15
	emitter.scale_amount_min = .48
	emitter.scale_amount_max = 1.0
	emitter.mesh = _quad(id, Vector2.ONE*width, tint)
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)

func _quad(id:String,size_m:Vector2,tint:Color) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = masks[id]
	mat.albedo_color = tint
	var quad := QuadMesh.new()
	quad.material = mat
	quad.size = size_m
	return quad

func _sprite(id:String,width:float) -> Sprite3D:
	var node := Sprite3D.new()
	node.texture = masks[id]
	node.pixel_size = width/float(node.texture.get_width())
	node.double_sided = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _closest_prop(ids:Array,point:Vector3,max_distance:float) -> Node3D:
	var closest: Node3D
	var limit := max_distance*max_distance
	for id in ids:
		for prop in props.get(id,[]):
			var d:float = point.distance_squared_to(prop.global_position)
			if d<limit:
				limit = d
				closest = prop
	return closest

func _install_practicals() -> void:
	var rain := world.get_node_or_null("HujanHalaman") as CPUParticles3D
	if rain:
		rain.mesh = _quad("rain_particle",Vector2(.20,.39),Color(.81,.88,.90,.74))
		rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# All decals sit on their own surfaces. Keep the total number small on iGPUs.
	for room in ["class","archive","speaker"]:
		var win := _closest_prop(["school_window"],world.stations[room],7.0)
		if win:
			var drops := _sprite("window_droplets",1.15)
			drops.global_position = win.global_position+Vector3(0,.53,.045)
			drops.modulate.a = .60
			drops.visibility_range_end = 10.0
	var mirror := _closest_prop(["mirror"],world.stations.toilet,7.0)
	if mirror:
		var normal:Vector3 = -mirror.global_basis.z.normalized()
		reflection.global_transform = mirror.global_transform
		reflection.global_position += normal*.044
		var crack := _sprite("glass_crack",.49)
		crack.global_transform = mirror.global_transform
		crack.global_position += normal*.051
		crack.modulate.a = .7
		crack.visibility_range_end = 8
	for p in [world.stations.security, world.stations.library]:
		var lamp := _closest_prop(["ceiling_lamp"],p,5)
		if lamp:
			var halo := _sprite("light_halo",1.25)
			halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			halo.global_position = lamp.global_position+Vector3.DOWN*.17
			halo.modulate.a = .25
			halo.visibility_range_end = 11

func _visibility_changed() -> void:
	overlay.visible = is_visible_in_tree()
	if not overlay.visible:
		pending = ""
		remaining = 0
		apparition_life = 0
		figure.visible = false
		smoke.visible = false
		reflection.visible = false
		dust.emitting = false
		haze.emitting = false
		sound_source.stop()

func event(id:String) -> void:
	if initialized and is_visible_in_tree():
		pending = id

func _process(dt:float) -> void:
	if not initialized: return
	var playing:bool = is_visible_in_tree() and player.active
	overlay.visible = playing
	if not playing:
		dust.emitting = false
		haze.emitting = false
		return
	if not pending.is_empty():
		_perform(pending)
		pending = ""
	cooldown = maxf(0,cooldown-dt)
	if remaining>0:
		remaining = maxf(0,remaining-dt)
		var alpha := sin(PI*(1-remaining/duration))*strength
		feedback.modulate.a = alpha
		screen_mask.modulate.a = alpha*.6
		if remaining<=0:
			feedback.visible = false
			screen_mask.visible = false
	if apparition_life>0:
		apparition_life = maxf(0,apparition_life-dt)
		smoke.modulate.a = minf(.4,apparition_life*.5)
		reflection.modulate.a = minf(.72,apparition_life)
		if apparition_life<=0:
			figure.visible = false
			smoke.visible = false
			reflection.visible = false
	sample_clock -= dt
	if sample_clock<=0:
		sample_clock = .15
		_update_surroundings()
	# Pause a chair's movement while the player is consulting a notebook.
	for i in range(active_tweens.size()-1,-1,-1):
		if not active_tweens[i].is_valid(): active_tweens.remove_at(i)

func _update_surroundings() -> void:
	var here:Vector3 = player.global_position
	var outdoors := here.z>10.65
	dust.emitting = not outdoors
	haze.emitting = outdoors
	dust.global_position = player.camera.global_position - player.camera.global_basis.z*1.1
	# A constrained bounce at the centre of the beam. Collision distance comes
	# from the existing interaction ray and never requires an extra raycast.
	torch_glow.visible = player.flashlight.visible and player.interaction.is_colliding()
	if torch_glow.visible:
		torch_glow.global_position = player.interaction.get_collision_point()+player.interaction.get_collision_normal()*.04
		torch_glow.modulate.a = .13
	if outdoors:
		wet_steps = 6
	if wet_steps>0 and player.is_on_floor() and last_step.distance_to(here)>.9:
		last_step = here
		if not outdoors: wet_steps -= 1
		var mark := prints[print_cursor]
		print_cursor = (print_cursor+1)%FLOOR_PRINTS
		mark.global_position = here+player.global_basis.x*(.08 if print_cursor%2==0 else -.08)+Vector3.UP*.018
		mark.rotation = Vector3(-PI*.5,player.rotation.y,0)
		mark.modulate.a = .63
		mark.visible = true
	if cooldown>0: return
	# Restrict apparitions to the relevant chapter. Its value survives a load.
	var story_control = get_parent().get_parent()
	var chapter := -1
	if "story" in story_control and story_control.story:
		chapter = story_control.story.chapter
	if chapter>=1 and not mirror_glimpse and reflection.position!=Vector3.ZERO:
		if _in_view(reflection.global_position,3.6):
			mirror_glimpse = true
			reflection.visible = true
			apparition_life = 1.85
			_spatial_sound("glass_creak",reflection.global_position)
			_screen("paranormal_distortion","vignette",.16,.8)
			cooldown = 8.0
	elif chapter==3 and not library_glimpse and here.distance_to(world.stations.library)<3.0:
		var shelf := _closest_prop(["bookshelf"],here,6.0)
		if shelf and _in_view(shelf.global_position+Vector3.UP,5.8):
			library_glimpse = true
			_apparition(shelf.global_position+(here-shelf.global_position).normalized()*.8,1.85)
			_shift_prop("book_stack",here,5.5)
			cooldown = 9.0

func _in_view(point:Vector3,distance:float) -> bool:
	var toward:Vector3 = point-player.camera.global_position
	return toward.length()<distance and -player.camera.global_basis.z.dot(toward.normalized())>.65

func _screen(texture:String,frame:String,power:float,seconds:float) -> void:
	feedback.texture = masks[texture]
	screen_mask.texture = masks[frame]
	feedback.modulate.a = 0
	screen_mask.modulate.a = 0
	feedback.visible = true
	screen_mask.visible = true
	strength = power
	duration = seconds
	remaining = seconds

func _spatial_sound(id:String,at:Vector3) -> void:
	sound_source.global_position = at
	sound_source.stream = room_audio[id]
	sound_source.volume_db = -5
	sound_source.play()

func _apparition(point:Vector3,seconds:float) -> void:
	figure.global_position = point
	var toward:Vector3 = player.global_position-point
	figure.rotation.y = atan2(toward.x,toward.z)
	figure.visible = true
	smoke.global_position = point+Vector3.UP*.82
	smoke.visible = true
	apparition_life = seconds
	_spatial_sound("guardian_breath",point)

func _shift_prop(kind:String,point:Vector3,range_m:float) -> bool:
	var prop := _closest_prop([kind],point,range_m)
	if not prop: return false
	var origin := prop.position
	var original_yaw := prop.rotation.y
	var tween := create_tween()
	active_tweens.append(tween)
	if kind=="book_stack":
		tween.tween_property(prop,"position",origin+Vector3(.14,.05,.08),.18)
		tween.parallel().tween_property(prop,"rotation:y",original_yaw+.45,.18)
		tween.tween_property(prop,"position:y",origin.y,.1)
		_spatial_sound("paper_turn",origin)
	else:
		tween.tween_property(prop,"position",origin+prop.basis.z*.29,.37).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(prop,"rotation:y",original_yaw-.16,.42)
		_spatial_sound("metal_drag",origin)
	# Restore the visual mesh to its authored position (and static collider).
	tween.tween_interval(.36)
	tween.tween_property(prop,"position",origin,.21)
	tween.parallel().tween_property(prop,"rotation:y",original_yaw,.21)
	return true

func _perform(id:String) -> void:
	var here:Vector3 = player.global_position
	match id:
		"rain":
			_screen("window_droplets","vignette",.33,2.0)
		"radio","ring":
			_screen("static_noise","camera_noise",.16,.65)
		"knock":
			if cooldown<=0:
				if not _shift_prop("student_chair",here,4.2):
					if not _shift_prop("book_stack",here,4.5):
						_spatial_sound("door_creak",here+Vector3(2,1,-1))
				cooldown = 3.5
		"whisper":
			if cooldown<=0:
				var p:Vector3 = here+Vector3(.2,0,-3)
				if absf(here.z)<2.5: p = here+Vector3(3.8,0,.22)
				_apparition(p,1.4)
				_screen("paranormal_distortion","vignette",.18,1.3)
				cooldown = 7.0
		"blackout","power","bell":
			world.startle()
			_screen("flicker_mask","vignette",.38 if id=="blackout" else .16,1.1)
		"chase","caught":
			_screen("subtle_film_grain","vignette",.67,2.4)
