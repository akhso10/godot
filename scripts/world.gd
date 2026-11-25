extends Node3D
## Walkable SMA Nusa Bangsa campus. Surface heights and station coordinates use meters.

const MODEL_DIR := "res://assets/models/environment/"
const STEP_HEIGHT := 3.6
const STAIR_X := -1.65
const STAIR_BOTTOM_Z := 10.0
const STAIR_TOP_Z := 1.48
const LABELS := {
	"gate":"Gerbang utama", "security":"Pos satpam", "safe":"Bale istirahat",
	"class":"XII RPL", "teachers":"Ruang guru", "power":"Instalasi listrik",
	"storage":"Gudang", "lab":"Laboratorium komputer", "canteen":"Kantin",
	"clinic":"Unit kesehatan siswa", "bk":"Bimbingan konseling", "toilet":"Toilet",
	"library":"Perpustakaan", "documentation":"Dokumentasi", "principal":"Kepala sekolah",
	"archive":"Arsip terbatas", "hall":"Aula", "speaker":"Ruang siaran",
	"xi":"XI IPA", "xib":"XI IPS", "xii":"XII Bahasa",
}
const GROUND_BACK := ["class","teachers","lab","power","storage"]
const GROUND_FRONT := ["clinic","bk","","canteen","toilet"]
const UPPER_BACK := ["library","documentation","archive","principal","speaker"]
const UPPER_FRONT := ["xi","xib","","hall","xii"]
const COLOURS := {
	"plaster_ivory":"b7b6a1","school_green":"597968","burned_plaster":"716b5d",
	"floor_grey":"919c92","wet_asphalt":"475350","paving":"7b8279","rough_concrete":"899084",
	"roof_tiles":"7f5948","painted_iron":"425e51","cabinet_metal":"596567","wood":"8a684c",
	"glass":"4c6365","soffit":"9a9d91","ink":"253e37","brass":"c2a565","red":"ab5546",
	"fluorescent":"f3e4b4", "signal":"e29263","line":"c2b99a","night":"253943",
}
var stations: Dictionary = {}
var spawn_position := Vector3(1.65,0.06,28.0)
var patrol_points: Array[Vector3] = [Vector3(-16,0,0),Vector3(8,0,0),Vector3(8,0,5.6),Vector3(16,0,0),Vector3(0,0,-5.6)]
var _doors: Dictionary = {}
var _gate_leaves: Array[StaticBody3D] = []
var _gate_open := false
var _door_states := {}
var _progress_initialized := false
var _mission_index := {}
var _prop_meshes := {}
var _prop_groups := {}
var _transforms: Dictionary = {}
var _materials: Dictionary = {}
var _models: Dictionary = {}
var _static: StaticBody3D
var _world_environment: Environment
var _lights: Array[OmniLight3D] = []
var _rain: CPUParticles3D
var _phase: String = "night"
var _built := false
var _boxes: BoxMesh = BoxMesh.new()
var _flicker_time := 0.0
var _fixture_index := -1
var _local_rng := RandomNumberGenerator.new()

func setup() -> void:
	if _built:
		return
	_built = true
	_local_rng.seed = 2347
	_static = StaticBody3D.new()
	_static.name = "Struktur"
	add_child(_static)
	_prepare_sky()
	_school()
	_courtyard()
	_flush_batches()

func _mat(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	var path := "res://assets/materials/" + key + ".tres"
	if ResourceLoader.exists(path):
		var authored := load(path) as StandardMaterial3D
		if authored:
			material = authored.duplicate()
			material.uv1_world_triplanar = true
			material.uv1_triplanar = true
	else:
		material.albedo_color = Color(COLOURS.get(key,"808880"))
		material.roughness = 0.78
	if key == "fluorescent" or key == "signal":
		material.emission_enabled = true
		material.emission = Color(COLOURS[key])
		material.emission_energy_multiplier = 1.45
	_materials[key] = material
	return material

func _box(p: Vector3, size: Vector3, key: String, solid: bool = false, rot: Vector3 = Vector3.ZERO) -> void:
	var basis := Basis.from_euler(rot)
	if not _transforms.has(key):
		_transforms[key] = []
	_transforms[key].append(Transform3D(basis * Basis.from_scale(size),p))
	if solid:
		_collider(_static,p,size,basis)

func _collider(body: StaticBody3D, p: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(basis,p)
	body.add_child(collision)

func _flush_batches() -> void:
	for key in _transforms:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _boxes
		batch.instance_count = _transforms[key].size()
		for i in batch.instance_count:
			batch.set_instance_transform(i,_transforms[key][i])
		var group := MultiMeshInstance3D.new()
		group.name = "Bahan_" + key
		group.multimesh = batch
		group.material_override = _mat(key)
		add_child(group)
	_transforms.clear()
	for sector in _prop_groups:
		var prop:Dictionary = _prop_groups[sector]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = prop.mesh
		batch.instance_count = prop.instances.size()
		for i in batch.instance_count:
			batch.set_instance_transform(i,prop.instances[i])
		var group := MultiMeshInstance3D.new()
		group.name = sector
		group.multimesh = batch
		group.visibility_range_end = 46
		add_child(group)
	_prop_groups.clear()

func _model(key:String) -> PackedScene:
	if not _models.has(key):
		var scene:PackedScene = load(MODEL_DIR + key + ".glb")
		# These GLBs carry linear RGB in COLOR_0. The importer retains that
		# channel but leaves the material's vertex-colour switch off.
		var sample := scene.instantiate()
		for instance in sample.find_children("*","MeshInstance3D",true,false):
			var mesh:Mesh = instance.mesh
			for surface in mesh.get_surface_count():
				var mat := mesh.surface_get_material(surface) as StandardMaterial3D
				if mat and mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
					mat.vertex_color_use_as_albedo = true
		sample.free()
		_models[key] = scene
	return _models[key]

func _prop(key: String, p: Vector3, yaw: float = 0, size: Vector3 = Vector3.ONE) -> void:
	# Each authored GLB is one vertex-coloured static mesh. Batch instances per wing
	# so that the compatibility renderer can cull sectors and submit fewer draws.
	if not _prop_meshes.has(key):
		var scene: Node3D = _model(key).instantiate()
		var instance: MeshInstance3D = scene if scene is MeshInstance3D else scene.find_children("*","MeshInstance3D",true,false)[0]
		_prop_meshes[key] = instance.mesh
		scene.free()
	var sector := "%s_%s_%s_%s" % [key, floori(p.x / 12.0), floori(p.z / 12.0), int(p.y / STEP_HEIGHT)]
	if not _prop_groups.has(sector):
		_prop_groups[sector] = {"mesh":_prop_meshes[key],"instances":[]}
	_prop_groups[sector].instances.append(Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(size),p))

func _room_doors(key:String, opening:Vector3, direction:float) -> void:
	var leaves: Array[StaticBody3D] = []
	var model_id := "metal_door" if key in ["archive","storage","power","speaker"] else "wooden_door"
	for side in [-1,1]:
		var leaf := StaticBody3D.new()
		leaf.position = opening + Vector3(side*1.29,0,0)
		leaf.set_meta("open_angle",side*direction*PI*.50)
		add_child(leaf)
		var panel := _model(model_id).instantiate() as Node3D
		panel.rotation.y = PI if side == 1 else 0.0
		panel.scale.x = 1.29/.98
		leaf.add_child(panel)
		_collider(leaf,Vector3(-side*.645,1.01,0),Vector3(1.29,2.02,.085))
		leaves.append(leaf)
	_doors[key] = leaves
	_set_room(key,true,false)

func _turn(body:StaticBody3D, angle:float, animate:bool) -> void:
	# Shortest rotation always turns the leaves into the room or courtyard.
	if animate:
		var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(body,"rotation:y",angle,.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		body.rotation.y = angle

func _set_room(key:String,opened:bool,animate:bool) -> void:
	if _door_states.has(key) and _door_states[key] == opened:
		return
	_door_states[key] = opened
	for leaf in _doors[key]:
		_turn(leaf,leaf.get_meta("open_angle") if opened else 0.0,animate)

func apply_progress(story) -> void:
	if _mission_index.is_empty():
		for i in story.Campaign.MISSIONS.size():
			_mission_index[story.Campaign.MISSIONS[i].id] = i
	var step:int = _mission_index.get(story.objective().get("id",""),_mission_index.size())
	_set_room("class",step > _mission_index.unlock_class,_progress_initialized)
	_set_room("archive",step > _mission_index.unlock_archive,_progress_initialized)
	_set_room("speaker",step > _mission_index.speaker_access,_progress_initialized)
	_set_room("teachers","teachers_office_key" in story.inventory,_progress_initialized)
	_set_room("clinic","infirmary_key" in story.inventory,_progress_initialized)
	var gate:bool = step > _mission_index.enter_school and (step < _mission_index.gate_locked or step > _mission_index.emergency_lever)
	if gate != _gate_open or not _progress_initialized:
		for leaf in _gate_leaves:
			_turn(leaf,-float(leaf.get_meta("side"))*PI*.47 if gate else 0.0,_progress_initialized)
		_gate_open = gate
	var phase := "night"
	if not story.ending.is_empty():
		phase = "dawn"
	elif step > _mission_index.blackout and step <= _mission_index.generator:
		phase = "blackout"
	if phase != _phase:
		set_phase(phase)
	_progress_initialized = true

func interaction_position(quest:Dictionary) -> Vector3:
	if quest.id == "enter_school":
		return Vector3(1.65,0,25.72)
	if not _door_states.get(quest.room,true):
		var room:Vector3 = stations[quest.room]
		return Vector3(room.x,room.y,signf(room.z)*1.26)
	return stations[quest.room]

func _label(title: String, p: Vector3, yaw: float = 0.0, px: float = .006, tint := Color("eadab8")) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.font_size = 36
	label.pixel_size = px
	label.modulate = tint
	label.outline_size = 0
	label.rotation.y = yaw
	label.position = p
	label.double_sided = false
	label.visibility_range_end = 28
	add_child(label)
	return label

func _prepare_sky() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("07131e")
	sky_mat.sky_horizon_color = Color("14232d")
	sky_mat.ground_horizon_color = Color("14232d")
	sky_mat.ground_bottom_color = Color("091311")
	sky_mat.sun_angle_max = 4.2
	sky_mat.sky_curve = .17
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("879ca5")
	env.ambient_light_energy = .32
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color("16292b")
	env.fog_density = .014
	env.fog_sky_affect = .18
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_world_environment = env
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-143,0)
	moon.light_color = Color("bbd4dc")
	moon.light_energy = .13
	add_child(moon)

func _light(p: Vector3, warm: bool, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = p
	light.light_color = Color("ffbe77") if warm else Color("c1dfd0")
	light.omni_range = radius * .83
	light.omni_attenuation = 1.45
	light.light_energy = energy * (1.8 if warm else 1.45)
	light.set_meta("energy",light.light_energy)
	_lights.append(light)
	add_child(light)

func _school() -> void:
	_box(Vector3(0,-.14,0),Vector3(40.6,.28,21.1),"floor_grey",true)
	_box(Vector3(0,3.46,-4.55),Vector3(40.6,.28,12.06),"floor_grey",true)
	_box(Vector3(0,3.31,-4.55),Vector3(40.6,.04,12.06),"soffit")
	for side in [-1,1]:
		_box(Vector3(side*12.16,3.31,6.0),Vector3(16.05,.04,9.12),"soffit")
		_box(Vector3(side*12.16,3.46,6.0),Vector3(16.05,.28,9.12),"floor_grey",true)
	# Pitched eaves above the atrium and adjoining wings.
	for side in [-1,1]:
		_box(Vector3(0,7.85,side*5.55),Vector3(43.0,.20,11.64),"roof_tiles",false,Vector3(side*.15,0,0))
	_box(Vector3(0,7.15,0),Vector3(40.7,.12,21.15),"soffit",true)
	for level in 2:
		var y := STEP_HEIGHT * level
		var rear: Array = GROUND_BACK if level == 0 else UPPER_BACK
		var front: Array = GROUND_FRONT if level == 0 else UPPER_FRONT
		for bay in range(5):
			var x := float(bay-2)*8
			_room(rear[bay],x,y,-1)
			if front[bay] != "":
				_room(front[bay],x,y,1)
			if bay % 2 == level:
				_prop("ceiling_lamp",Vector3(x,y+3.20,0))
				_box(Vector3(x,y+3.13,0),Vector3(1.13,.035,.12),"fluorescent")
				_light(Vector3(x,y+2.73,.08),bay==3,.94,8.0)
		for side in [-1,1]:
			_box(Vector3(side*20.24,y+1.72,0),Vector3(.24,3.45,21.0),"plaster_ivory",true)
			_prop("noticeboard",Vector3(side*20.04,y+1.55,0),side*PI/2)
		_box(Vector3(0,y+3.14,-1.99),Vector3(40.0,.11,.11),"painted_iron")
		_box(Vector3(0,y+3.00,-1.99),Vector3(40.0,.047,.047),"cabinet_metal")
		for x in [-19.65,-11.85,-4.1,4.1,11.85,19.65]:
			for z in [-1.96,1.96]:
				_prop("concrete_column",Vector3(x,y,z),0,Vector3(.82,1,.82))
	# Smooth inclined collision underneath a staircase with individual tread nosings.
	var run := STAIR_BOTTOM_Z - STAIR_TOP_Z
	var angle := atan2(STEP_HEIGHT,run)
	var top_center := Vector3(STAIR_X,STEP_HEIGHT*.5,(STAIR_BOTTOM_Z+STAIR_TOP_Z)*.5)
	_collider(_static,top_center+Basis(Vector3.RIGHT,angle)*Vector3(0,-.10,0),Vector3(2.35,.20,sqrt(run*run+STEP_HEIGHT*STEP_HEIGHT)),Basis(Vector3.RIGHT,angle))
	_prop("staircase",Vector3(STAIR_X,0,STAIR_BOTTOM_Z))
	for side in [-1,1]:
		var x: float = STAIR_X+side*1.17
		_box(Vector3(x,2.71,top_center.z),Vector3(.06,.068,sqrt(run*run+STEP_HEIGHT*STEP_HEIGHT)),"painted_iron",true,Vector3(angle,0,0))
		for i in range(6):
			var t := i/5.0
			_box(Vector3(x,STEP_HEIGHT*t+.45,lerpf(STAIR_BOTTOM_Z,STAIR_TOP_Z,t)),Vector3(.035,.91,.035),"painted_iron")
	for x in [1.9,3.0,-3.52]:
		_prop("balcony_railing",Vector3(x,3.60,1.46),0,Vector3(.55,1,1))
	_box(Vector3(1.83,4.07,1.48),Vector3(4.28,.95,.08),"painted_iron",false)
	# Use narrow physical rails to guard the open upper edge without sealing the stair landing.
	_collider(_static,Vector3(1.85,4.1,1.5),Vector3(4.22,1,.09))
	_collider(_static,Vector3(-3.55,4.1,1.5),Vector3(1.0,1,.09))
	for side in [-1,1]:
		_collider(_static,Vector3(side*4.09,4.12,6.0),Vector3(.1,1.0,9.05))
		for z in [2.55,4.55,6.55,8.55,10]:
			_prop("balcony_railing",Vector3(side*4.09,3.6,z),PI*.5)
	_prop("school_speaker",Vector3(3.94,2.5,1.99),PI*.5)
	_label("↑  LANTAI DUA",Vector3(-2.0,2.49,10.01),0,.0044)
	_box(Vector3(-2.0,2.5,9.98),Vector3(1.78,.36,.08),"ink")
	# A lit lintel over the open entrance anchors the courtyard sightline.
	_box(Vector3(0,5.54,10.50),Vector3(8.14,1.08,.29),"ink")
	_box(Vector3(0,5.03,10.57),Vector3(8.24,.09,.31),"brass")
	_label("S M A   N U S A   B A N G S A",Vector3(0,5.55,10.67),0,.0086)

func _room(key: String,x: float,y: float,direction: int) -> void:
	var sign_z := float(direction)
	var yaw := 0.0 if direction == -1 else PI
	var inner_z := sign_z*2.04
	var rear_z := sign_z*10.42
	var station := Vector3(x,y,sign_z*5.52)
	stations[key] = station
	
	for side in [-1,1]:
		var side_x:float = x+side*2.68
		_box(Vector3(side_x,y+1.68,inner_z),Vector3(2.71,3.36,.19),"plaster_ivory",true)
		_box(Vector3(side_x,y+.56,inner_z),Vector3(2.71,1.12,.215),"school_green")
		_box(Vector3(side_x,y+1.14,inner_z),Vector3(2.71,.046,.22),"line")
	_box(Vector3(x,y+2.8,inner_z),Vector3(2.70,1.12,.19),"school_green",true)
	# Raised doors and framed transoms are visible even from the far end of each hall.
	for side in [-1,1]:
		_box(Vector3(x+1.32*side,y+1.1,inner_z),Vector3(.082,2.2,.25),"wood")
	_box(Vector3(x,y+2.20,inner_z),Vector3(2.71,.085,.27),"wood")
	_room_doors(key,Vector3(x,y,inner_z+sign_z*.13),sign_z)
	_box(Vector3(x,y+2.62,inner_z-sign_z*.12),Vector3(2.65,.37,.07),"ink")
	_label(str(LABELS[key]).to_upper(),Vector3(x,y+2.63,inner_z-sign_z*.17),yaw,.0045)
	for side in [-1,1]:
		var wall_x:float = x+side*4.02
		_box(Vector3(wall_x,y+1.69,sign_z*6.19),Vector3(.17,3.38,8.51),"plaster_ivory",true)
		_box(Vector3(wall_x,y+.56,sign_z*6.19),Vector3(.19,1.12,8.51),"school_green")
	_box(Vector3(x,y+.60,rear_z),Vector3(8.04,1.20,.22),"school_green",true)
	_box(Vector3(x,y+3.02,rear_z),Vector3(8.04,.72,.22),"plaster_ivory",true)
	_collider(_static,Vector3(x,y+1.87,rear_z),Vector3(8.04,1.46,.15))
	for i in range(4):
		_prop("school_window",Vector3(x-3.0+i*2.0,y+1.16,rear_z),0,Vector3(1.30,1.39,1))
	var lamp_z := sign_z*6.94
	_prop("ceiling_lamp",Vector3(x+.8,y+3.18,lamp_z),PI/2)
	_box(Vector3(x+.8,y+3.11,lamp_z),Vector3(.13,.03,1.12),"fluorescent")
	_light(Vector3(x+.87,y+2.83,lamp_z), key in ["archive","library","storage","principal","canteen"],.77,6.4)
	_furnish(key,Vector3(x,y,sign_z*6.48),direction)

# All furniture lies beside the common central aisle so story markers and companions
# can share the same walkable stations even when the chapter changes.
func _furnish(key: String,center: Vector3,direction: int) -> void:
	var d := float(direction)
	var yaw := PI if direction > 0 else 0.0
	match key:
		"class","xi","xib","xii","lab":
			for col in [-1,1]:
				for row in range(3):
					var p := center+Vector3(col*2.37,0,d*(-1.85+2.16*row))
					_prop("student_desk",p,yaw)
					_prop("student_chair",p+Vector3(0,0,d*.59),yaw)
					_collider(_static,p+Vector3(0,.40,d*.18),Vector3(1.16,.8,1.05))
					if key == "lab":
						_prop("monitor",p+Vector3(0,.78,-d*.10),yaw+PI)
						_prop("keyboard",p+Vector3(0,.787,d*.16),yaw+PI)
						_prop("computer",p+Vector3(.36,0,.04),yaw)
			_prop("blackboard",center+Vector3(-3.85,1.65,0),-PI/2)
			_prop("clock",center+Vector3(-3.86,2.22,d*2.04),-PI/2)
			_prop("ceiling_fan",center+Vector3(0,3.18,d*1.95))
		"storage","teachers","principal","bk","documentation","archive","library":
			for row in range(2):
				var p := center+Vector3(3.36,0,d*(-1.12+2.35*row))
				var kind := "bookshelf" if key in ["library","bk","principal"] else ("storage_rack" if key == "storage" else "filing_cabinet")
				_prop(kind,p,PI/2)
				_collider(_static,p+Vector3(0,.89,0),Vector3(.61,1.78,1.5))
				if key == "storage":
					for n in range(3):
						_prop("cardboard_box", p+Vector3(-.08,.106+n*.46,0),PI/2,Vector3(.80,.73,.75))
			var desk := center+Vector3(-2.1,0,d*.94)
			_prop("teachers_desk",desk,yaw)
			_prop("teachers_chair",desk+Vector3(0,0,d*.69),yaw)
			_collider(_static,desk+Vector3(0,.40,d*.15),Vector3(1.57,.80,1.16))
			_prop("book_stack",desk+Vector3(.42,.78,0))
			if key in ["teachers","principal","documentation"]:
				_prop("desk_lamp",desk+Vector3(-.50,.78,.12),yaw)
				_prop("phone",desk+Vector3(.06,.78,-.04),yaw)
			if key == "principal":
				_prop("trophy",desk+Vector3(-.18,.78,.18))
				_prop("picture_frame",center+Vector3(-3.86,1.65,0),-PI/2,Vector3(2,2,1))
			if key in ["archive","teachers","storage"]:
				_locker(key,center+Vector3(-3.41,0,-d*1.42),-PI/2)
			if key == "library":
				for x in [-2,2]:
					_prop("bookshelf",center+Vector3(x,0,d*3.44),yaw+PI)
					_collider(_static,center+Vector3(x,.95,d*3.44),Vector3(1.46,1.9,.46))
			if key == "archive":
				_box(center+Vector3(0,1.0,d*3.76),Vector3(7.8,2.0,.055),"burned_plaster")
			_prop("calendar",center+Vector3(-3.86,1.7,-d*.13),-PI/2)
		"power":
			for j in range(3):
				var p := center+Vector3(3.70,0,d*(j-1)*1.22)
				_prop("breaker_panel",p,PI/2)
				_collider(_static,p+Vector3(0,.8,0),Vector3(.35,1.6,.85))
			_prop("generator",center+Vector3(-2.4,0,d*1.65),PI/2)
			_collider(_static,center+Vector3(-2.4,.38,d*1.65),Vector3(.67,.76,1.07))
			for i in range(7):
				_box(center+Vector3(3.75,2.25,d*(-2.72+.89*i)),Vector3(.048,1.2,.047),"painted_iron")
		"clinic":
			for i in range(2):
				var p := center+Vector3(2.58,0,d*(-1.11+i*2.68))
				_prop("clinic_bed",p)
				_collider(_static,p+Vector3(0,.42,0),Vector3(.94,.84,2.00))
			_prop("privacy_curtain",center+Vector3(2.61,0,0),yaw)
			_prop("medicine_cabinet",center+Vector3(-3.71,1.04,0),-PI/2)
			_prop("washbasin",center+Vector3(-3.54,0,d*1.99),-PI/2)
			_prop("mirror",center+Vector3(-3.79,1.62,d*1.99),-PI/2)
		"toilet":
			for i in range(3):
				var p := center+Vector3(2.87,0,d*(-2.2+i*2.0))
				_prop("toilet",p,PI/2)
				_box(p+Vector3(.02,.93,1.0),Vector3(1.9,1.86,.07),"school_green",true)
				_prop("washbasin",p+Vector3(-6.05,0,0),-PI/2)
				_prop("mirror",p+Vector3(-6.65,1.52,0),-PI/2)
		"canteen":
			for row in range(2):
				var p := center+Vector3(-2.50,0,d*(-1.22+row*2.74))
				_prop("food_counter",p,PI/2)
				_collider(_static,p+Vector3(0,.67,0),Vector3(.78,1.34,1.82))
				_prop("canteen_bench",p+Vector3(5.05,0,0),PI/2)
				_collider(_static,p+Vector3(5.05,.24,0),Vector3(.44,.48,1.74))
		"hall":
			for x in [-2.24,2.24]:
				for z in [-1.83,-.68,.5]:
					var p := center+Vector3(x,0,d*z)
					_prop("student_chair",p,yaw)
					_collider(_static,p+Vector3(0,.38,0),Vector3(.44,.76,.44))
			_box(center+Vector3(0,.10,d*2.84),Vector3(7.1,.20,1.94),"wood",true)
			_prop("stage_curtain",center+Vector3(0,.2,d*3.68),yaw)
			_prop("stage_podium",center+Vector3(-1.93,.20,d*2.73),yaw)
		"speaker":
			var p := center+Vector3(2.08,0,d*.15)
			_prop("audio_mixer",p,yaw)
			_collider(_static,p+Vector3(0,.43,0),Vector3(1.8,.86,.76))
			_prop("microphone_stand",p+Vector3(-.65,.78,0))
			for i in range(3):
				_prop("school_speaker",center+Vector3(-2.87,i*.73,d*.76),yaw)
			_prop("ceiling_fan",center+Vector3(0,3.22,0))

func _locker(key: String,p: Vector3,yaw: float) -> void:
	_prop("metal_locker",p,yaw)
	var body := StaticBody3D.new()
	body.name = "Lemari_" + key
	body.position = p
	body.rotation.y = yaw
	body.set_meta("interaction_id","hide:"+key)
	body.set_meta("interaction_label","Sembunyi di lemari")
	add_child(body)
	_collider(body,Vector3(0,.94,0),Vector3(.88,1.88,.58))

func _courtyard() -> void:
	_box(Vector3(0,-.18,17.6),Vector3(48,.36,14.4),"paving",true)
	# Gutter, curb, court markings and roofline.
	_box(Vector3(0,.006,10.78),Vector3(41.1,.012,.27),"cabinet_metal")
	for x in [-8.1,8.1]:
		_box(Vector3(x,.009,17.18),Vector3(.07,.018,9.2),"line")
	for z in [12.64,17.15,21.72]:
		_box(Vector3(0,.009,z),Vector3(16.25,.018,.06),"line")
	for side in [-1,1]:
		_box(Vector3(side*23.9,1.41,17.48),Vector3(.27,2.82,15.15),"school_green",true)
		_box(Vector3(side*22.0,1.41,10.52),Vector3(4.03,2.82,.24),"school_green",true)
		_box(Vector3(side*13.95,.91,24.60),Vector3(19.95,1.82,.34),"school_green",true)
		_box(Vector3(side*13.95,1.84,24.60),Vector3(19.98,.10,.40),"plaster_ivory")
		for i in range(4):
			_prop("tropical_tree",Vector3(side*(22.2+i%2*.72),0,12.9+i*3.3),i*1.67)
		for x in [4.05,11.05,18.05]:
			_prop("concrete_column",Vector3(side*x,0,24.43),0,Vector3(1.35,.87,1.35))
		var gate_leaf := StaticBody3D.new()
		gate_leaf.position = Vector3(side*4.0,0,24.45)
		gate_leaf.set_meta("side",side)
		add_child(gate_leaf)
		_gate_leaves.append(gate_leaf)
		var grille := _model("school_gate").instantiate() as Node3D
		grille.position.x = -side*2.0
		grille.scale.x = 4.0/3.4
		gate_leaf.add_child(grille)
		_collider(gate_leaf,Vector3(-side*2.0,1.05,0),Vector3(4.0,2.1,.13))
		_light(Vector3(side*4.05,2.60,24.26),true,.67,4.1)
		_box(Vector3(side*4.05,2.87,24.40),Vector3(.26,.18,.25),"fluorescent")
	# Street-side approach to the school. Kerbs and fence surround the full playable strip.
	_box(Vector3(0,-.17,27.85),Vector3(8.3,.34,6.7),"wet_asphalt",true)
	for edge in [-1,1]:
		_box(Vector3(edge*4.1,.85,27.9),Vector3(.18,1.70,6.8),"painted_iron",true)
	_box(Vector3(0,.9,31.1),Vector3(8.35,1.8,.18),"painted_iron",true)
	_prop("flagpole",Vector3(-6.96,0,20.45))
	_box(Vector3(-6.96,.095,20.45),Vector3(1.13,.19,1.13),"rough_concrete",true)
	_box(Vector3(-6.96,.24,20.45),Vector3(.78,.11,.78),"rough_concrete",true)
	_prop("noticeboard",Vector3(4.45,1.44,11.0),PI)
	_box(Vector3(4.45,.73,11.04),Vector3(.13,1.46,.18),"wood",true)
	stations["gate"] = Vector3(1.65,0,23.33)
	stations["security"] = Vector3(14.78,0,17.7)
	stations["safe"] = Vector3(-13.6,0,17.7)
	for key in ["safe","security"]:
		var p: Vector3 = stations[key]
		var side := signf(p.x)
		_box(p+Vector3(0,2.79,0),Vector3(5.12,.16,4.95),"roof_tiles",true)
		_box(p+Vector3(2.38*side,1.34,0),Vector3(.16,2.71,4.64),"plaster_ivory",true)
		_box(p+Vector3(0,.56,-2.26),Vector3(4.78,1.12,.16),"school_green",true)
		_box(p+Vector3(0,.56,2.26),Vector3(4.78,1.12,.16),"school_green",true)
		for z in [-1,1]:
			_prop("concrete_column",p+Vector3(-side*2.32,0,z*2.20),0,Vector3(.70,.85,.70))
		_prop("ceiling_lamp",p+Vector3(0,2.66,0))
		_light(p+Vector3(0,2.22,.05),true,1.45,6.3)
		_locker(key,p+Vector3(side*1.72,0,-1.45),side*PI/2)
		var desk := p+Vector3(side*.65,0,1.36)
		if key == "security":
			_prop("teachers_desk",desk)
			_prop("monitor",desk+Vector3(-.40,.78,0),PI*.12)
			_prop("book_stack",desk+Vector3(.42,.78,0))
			_prop("cctv",p+Vector3(side*1.85,2.38,1.4),-.8)
		else:
			_prop("canteen_bench",desk)
			_prop("potted_plant",p+Vector3(1.55,0,-1.56))
		_collider(_static,desk+Vector3(0,.34,0),Vector3(1.7,.68,.57))
		_label(str(LABELS[key]).to_upper(),p+Vector3(-side*2.49,2.46,0),-side*PI/2,.0054)
		_box(p+Vector3(-side*2.44,2.45,0),Vector3(.08,.37,2.65),"ink")
	_prop("potted_plant",Vector3(3.3,0,10.94))
	_prop("potted_plant",Vector3(-3.55,0,10.94))
	_rain = CPUParticles3D.new()
	_rain.name = "HujanHalaman"
	_rain.amount = 150
	_rain.lifetime = .98
	_rain.preprocess = 1.1
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(22,.4,6.78)
	_rain.position = Vector3(0,7.1,17.66)
	_rain.direction = Vector3(-.08,-1,0)
	_rain.spread = 2
	_rain.gravity = Vector3(-.72,-4.7,0)
	_rain.initial_velocity_min = 7.2
	_rain.initial_velocity_max = 8.3
	var drop := BoxMesh.new()
	drop.size = Vector3(.008,.22,.008)
	var rain_mat := StandardMaterial3D.new()
	rain_mat.albedo_color = Color("829b9b")
	drop.material = rain_mat
	_rain.mesh = drop
	add_child(_rain)

func set_phase(phase: String) -> void:
	_phase = phase
	if not _built:
		return
	var power_scale := .42 if phase == "blackout" else 1.0
	_world_environment.ambient_light_energy = .20 if phase == "blackout" else (.67 if phase == "dawn" else .32)
	for light in _lights:
		light.light_energy = light.get_meta("energy") * power_scale

func startle() -> void:
	if _lights.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var point := camera.global_position if camera else spawn_position
	var nearest := INF
	for i in _lights.size():
		var distance := _lights[i].global_position.distance_squared_to(point)
		if distance < nearest:
			nearest = distance
			_fixture_index = i
	_flicker_time = 1.4

func _process(dt: float) -> void:
	if _flicker_time > 0 and _fixture_index >= 0:
		_flicker_time -= dt
		var light := _lights[_fixture_index]
		var factor := .42 if _phase == "blackout" else 1.0
		var dip := .06 if _flicker_time > 0 and sin(_flicker_time*38.0)+cos(_flicker_time*19.4) > .2 else 1.0
		light.light_energy = float(light.get_meta("energy"))*factor*dip

# Routes use centers of door openings and a dedicated stair centerline. A caller
# can retarget every few seconds; endpoints are the exact positions requested.
func _zone(p: Vector3) -> String:
	if p.z > 10.52:
		return "court"
	if p.z > STAIR_TOP_Z and absf(p.x-STAIR_X) < 1.35 and p.z < STAIR_BOTTOM_Z+.18:
		return "stair"
	if absf(p.z) < 2.15:
		return "corridor"
	if p.z > 0 and absf(p.x) < 4.03:
		return "entrance"
	return "room"

func _floor(p: Vector3) -> float:
	return STEP_HEIGHT if p.y > STEP_HEIGHT*.65 else 0.0

func _to_hall(p: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var y := _floor(p)
	match _zone(p):
		"room":
			var x := clampf(roundf(p.x/8.0)*8.0,-16.0,16.0)
			path.append(Vector3(x,y,p.z))
			path.append(Vector3(x,y,0))
		"court":
			if absf(p.x)>11.1:
				path.append(Vector3(p.x,0,17.7))
				path.append(Vector3(1.65,0,17.7))
			else:
				path.append(Vector3(1.65,0,p.z))
			path.append(Vector3(1.65,0,0))
		"entrance":
			path.append(Vector3(1.65,0,p.z))
			path.append(Vector3(1.65,0,0))
		"stair":
			if y > 0:
				path.append(Vector3(STAIR_X,STEP_HEIGHT,STAIR_TOP_Z-.20))
				path.append(Vector3(STAIR_X,STEP_HEIGHT,0))
			else:
				path.append(Vector3(STAIR_X,0,STAIR_BOTTOM_Z+.60))
				path.append(Vector3(1.65,0,STAIR_BOTTOM_Z+.60))
				path.append(Vector3(1.65,0,0))
		_:
			path.append(Vector3(p.x,y,0))
	return path

func route_between(start: Vector3,finish: Vector3) -> Array[Vector3]:
	if _floor(start) == _floor(finish):
		if _zone(start) == "corridor" and _zone(finish) == "corridor":
			return [finish]
		if _zone(start) == "room" and _zone(finish) == "room" and roundi(start.x/8.0) == roundi(finish.x/8.0) and signf(start.z) == signf(finish.z):
			return [Vector3(roundf(start.x/8.0)*8.0,start.y,start.z),Vector3(roundf(start.x/8.0)*8.0,finish.y,finish.z),finish]
	if _zone(start) == "court" and _zone(finish) == "court":
		var flat := Vector3(finish.x-start.x,0,finish.z-start.z)
		var clearance := flat.normalized().cross(Vector3.UP)*.31
		var clear := true
		for side in [-1,0,1]:
			var offset := Vector3.UP * .65 + clearance * float(side)
			var query := PhysicsRayQueryParameters3D.create(start+offset,finish+offset,1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				clear = false
				break
		if clear:
			return [finish]
		return [Vector3(start.x,0,17.7),Vector3(finish.x,0,17.7),finish]
	var raw: Array[Vector3] = _to_hall(start)
	if not is_equal_approx(_floor(start), _floor(finish)):
		var ramp: Array[Vector3] = [
			Vector3(1.65,0,0),Vector3(1.65,0,STAIR_BOTTOM_Z+.66),
			Vector3(STAIR_X,0,STAIR_BOTTOM_Z+.66),Vector3(STAIR_X,STEP_HEIGHT,STAIR_TOP_Z-.26),
			Vector3(STAIR_X,STEP_HEIGHT,0)]
		if _floor(start) > 0:
			ramp.reverse()
		raw.append_array(ramp)
	var out_path := _to_hall(finish)
	out_path.reverse()
	raw.append_array(out_path)
	raw.append(finish)
	var clean: Array[Vector3] = []
	var prev := start
	for point in raw:
		if point.distance_to(prev) > .12:
			clean.append(point)
			prev = point
	return clean
