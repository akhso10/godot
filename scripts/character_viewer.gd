extends RefCounted
## The five playable/archive character rigs, rendered in isolation from the school.
const UI = preload("res://scripts/interface.gd")
const MODELS = ["raka","reski","akbar","laras","shadow_guardian"]
const TITLES = ["Raka","Reski","Akbar","Laras","Penjaga Bayangan"]
const LABELS = {
	"Idle":"Diam","Walk":"Berjalan","Run":"Berlari","Search":"Mencari","Startle":"Terkejut",
	"Signal":"Memberi isyarat","CrouchIdle":"Jongkok","CrouchWalk":"Berjalan jongkok","Pickup":"Mengambil barang",
	"Inspect":"Membaca dokumen","PushDoor":"Mendorong pintu","Flashlight":"Mengarahkan senter",
	"ChangeBattery":"Mengganti baterai","Radio":"Menggunakan radio","Hide":"Bersembunyi",
	"LeaveCover":"Keluar dari lemari","Fall":"Terjatuh","Capture":"Tertangkap","Talk":"Berbicara",
	"NervousIdle":"Gelisah","Fear":"Ketakutan","Sit":"Duduk","StandUp":"Berdiri",
	"Point":"Menunjuk arah","Follow":"Mengikuti Raka","Escape":"Melarikan diri","GhostIdle":"Melayang diam",
	"SlowWalk":"Berjalan pelan","Appear":"Muncul","Disappear":"Menghilang","HeadTurn":"Menoleh",
	"Float":"Melayang","Reflection":"Di balik cermin","Patrol":"Berpatroli","Listen":"Mendengarkan",
	"Investigate":"Menyelidiki","Chase":"Mengejar","Attack":"Menangkap","Jumpscare":"Menerkam","ReturnPatrol":"Kembali berpatroli"
}
var index := 0
var stage: Node3D
var model: Node3D
var animation: AnimationPlayer
var clip_list: OptionButton
var body_title: Label
var selected: StringName = &"Idle"

func show(game) -> void:
	game.set_page("character_viewer")
	var ui = game.ui
	ui.backplate(UI.MENU, .91)
	ui.header("Arsip sekolah", "Model dan gerakan")
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.place(holder, Vector2(74,219),Vector2(563,398))
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(563,398)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	stage = Node3D.new()
	vp.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position=Vector3(0,1.10,3.35)
	camera.look_at(Vector3(0,.96,0),Vector3.UP)
	camera.fov = 38
	camera.current = true
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#26372f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d3daca")
	env.ambient_light_energy = .85
	world_env.environment = env
	stage.add_child(world_env)
	for yaw in [-40,145]:
		var light := DirectionalLight3D.new()
		stage.add_child(light)
		light.rotation_degrees = Vector3(-27,yaw,0)
		light.light_energy = 1.35 if yaw < 0 else .85
		light.light_color = Color("#f6d4a8") if yaw<0 else Color("#b3d1c0")
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(8,8)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#405349")
	floor_mesh.material = floor_mat
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	stage.add_child(ground)
	body_title = ui.label("",Vector2(682,229),Vector2(521,67),42,UI.SERIF)
	ui.label("Karakter",Vector2(684,322),Vector2(430,28),17,UI.BOLD,UI.MUTED)
	var cast := OptionButton.new()
	for title in TITLES: cast.add_item(title)
	ui.place(cast,Vector2(683,354),Vector2(470,42))
	cast.select(index)
	cast.item_selected.connect(_switch)
	ui.label("Gerakan",Vector2(684,426),Vector2(430,28),17,UI.BOLD,UI.MUTED)
	clip_list = OptionButton.new()
	ui.place(clip_list,Vector2(683,458),Vector2(470,42))
	clip_list.item_selected.connect(_select_clip)
	ui.button("Putar kiri",Vector2(683,547),Vector2(214,44),turn.bind(-30))
	ui.button("Putar kanan",Vector2(927,547),Vector2(226,44),turn.bind(30))
	var back: Button = ui.button("Kembali ke galeri",Vector2(74,647),Vector2(251,44),_back.bind(game),false,true,"back")
	back.set_meta("controller",self)
	_switch(index)

func _switch(i:int) -> void:
	index=i
	if is_instance_valid(model):
		stage.remove_child(model)
		model.queue_free()
	var asset: PackedScene = load("res://assets/models/characters/%s_character.glb" % MODELS[index])
	model = asset.instantiate()
	stage.add_child(model)
	animation = model.find_child("AnimationPlayer",true,false)
	body_title.text = TITLES[i]
	clip_list.clear()
	for clip in animation.get_animation_list():
		if clip == &"RESET": continue
		clip_list.add_item(LABELS.get(clip,clip))
		clip_list.set_item_metadata(clip_list.item_count-1,clip)
		if clip == &"Idle": clip_list.select(clip_list.item_count-1)
	_select_clip(clip_list.selected)

func _select_clip(i:int) -> void:
	selected = clip_list.get_item_metadata(i)
	# The archive loops one-shot clips locally, preserving shared
	# animation resources when the same rig is used in the school.
	var animation_name: String = str(selected)
	var definition: Animation = animation.get_animation(animation_name)
	if definition.loop_mode==Animation.LOOP_NONE:
		animation.play(animation_name,.12)
		if not animation.animation_finished.is_connected(_replay):
			animation.animation_finished.connect(_replay)
	else:
		animation.play(animation_name,.12)

func _replay(clip:StringName) -> void:
	if is_instance_valid(animation) and selected==clip:
		animation.play(clip)

func turn(degrees:float) -> void:
	if is_instance_valid(model):
		model.rotate_y(deg_to_rad(degrees))

func _back(game) -> void:
	game.set_page("gallery")
	load("res://scripts/gallery.gd").new().show(game)
