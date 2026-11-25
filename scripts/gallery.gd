extends RefCounted
## Optional production archive. ResourceLoader enumerates original paths even in an exported PCK.
const UI := preload("res://scripts/interface.gd")
const ART := "res://assets/art/"
const SETS := ["Lokasi","Tokoh","Adegan cerita","Benda","Properti 3D","Material","Efek","Ikon","Rekaman"]
const LOCATIONS := {
	"school_gate":"Gerbang sekolah","school_courtyard":"Halaman upacara","corridor_floor1":"Koridor lantai satu",
	"corridor_floor2":"Koridor lantai dua","classroom_xii_rpl":"Kelas XII RPL","teachers_office":"Ruang guru",
	"school_library":"Perpustakaan","school_infirmary":"Unit kesehatan sekolah","school_restroom":"Toilet",
	"school_storage":"Gudang","computer_laboratory":"Laboratorium komputer","electrical_room":"Ruang listrik",
	"restricted_archive":"Ruang arsip","principal_office":"Ruang kepala sekolah","security_post":"Pos satpam",
	"school_canteen":"Kantin","school_hall":"Aula","school_staircase":"Tangga sekolah","announcement_control_room":"Ruang kontrol speaker"
}
const STILLS := {
	"cinematic_intro_01":"Kembali ke sekolah","cinematic_separation":"Terpisah","cinematic_reski_rescue":"Reski di laboratorium",
	"cinematic_akbar_rescue":"Akbar di UKS","cinematic_laras_reveal":"Nama yang dihapus","cinematic_final_escape":"Bel terakhir",
	"ending_good":"Bel Pulang","ending_neutral":"Rahasia yang Tertinggal","ending_bad":"Absensi Terakhir"
}
const STUDIO_COLOR := Color("#24322d")
const STATES := ["Malam","Listrik padam","Darurat","Gangguan","Fajar"]
var category := 0
var index := 0
var lighting := 0
var rotation_step := 0

func show(game) -> void:
	game.set_page("gallery")
	_draw(game)

func _add_file(list:Array, path:String, title:String) -> void:
	if ResourceLoader.exists(path):
		list.append([path,title])

func _scan(list:Array, path:String, extension:String) -> void:
	var files := ResourceLoader.list_directory(path)
	files.sort()
	for file in files:
		if file.get_extension().to_lower()==extension:
			list.append([path.path_join(file),file.get_basename().replace("_"," ").capitalize()])

func _entries() -> Array:
	var list := []
	match category:
		0:
			for key in LOCATIONS:
				_add_file(list,ART+"locations/"+key+".webp",LOCATIONS[key])
			for i in 6:
				var title:String = "Prolog" if i==0 else "Bab %d" % i
				_add_file(list,ART+("loading_prologue" if i==0 else "loading_chapter%d"%i)+".webp","Peralihan · "+title)
			_add_file(list,ART+"menu.webp","Serambi tengah malam")
		1:
			for actor in ["raka","reski","akbar","laras","shadow_guardian"]:
				var title:String = "Penjaga Bayangan" if actor=="shadow_guardian" else str(actor).capitalize()
				for view in [["portrait","Potret"],["reference","Rujukan"],["front","Depan"],["side","Samping"],["back","Belakang"]]:
					_add_file(list,ART+actor+"_"+view[0]+".webp",title+" · "+view[1])
			if DirAccess.dir_exists_absolute(ART+"expressions") or ResourceLoader.list_directory(ART).has("expressions/"):
				_scan(list,ART+"expressions","webp")
			_scan(list,"res://assets/character_studies","png")
		2:
			for key in STILLS: _add_file(list,ART+key+".webp",STILLS[key])
			if ResourceLoader.list_directory(ART).has("apparitions/"):
				_scan(list,ART+"apparitions","webp")
		3: _scan(list,"res://assets/items/catalog","tres")
		4: _scan(list,"res://assets/models/environment","glb")
		5: _scan(list,"res://assets/materials","tres")
		6: _scan(list,"res://assets/vfx","png")
		7: _scan(list,"res://assets/ui/icons","svg")
		8:
			for section in ["ambience","music","effects","footsteps"]:
				_scan(list,"res://assets/audio/"+section,"ogg")
	return list

func _draw(game) -> void:
	var ui = game.ui
	ui.clear()
	ui.box(Vector2.ZERO,Vector2(1280,720),Color("#121c18"))
	ui.picture("res://assets/ui/crest.svg",Vector2(58,34),Vector2(44,51),false)
	ui.label("ARSIP SEKOLAH",Vector2(120,31),Vector2(450,34),20,UI.BOLD)
	ui.label("SMA Nusa Bangsa",Vector2(121,68),Vector2(450,23),14,UI.SANS,UI.MUTED)
	ui.box(Vector2(58,105),Vector2(1164,1),Color("#546258"))
	for i in SETS.size():
		ui.button(SETS[i],Vector2(58,125+i*46),Vector2(218,43),_category.bind(game,i),category==i)
	var close:Button = ui.button("Kembali",Vector2(58,632),Vector2(218,49),game.home,false,true,"back")
	close.set_meta("archive",self)
	if ResourceLoader.exists("res://scripts/character_viewer.gd"):
		ui.button("Animasi 3D",Vector2(58,557),Vector2(218,45),_viewer.bind(game))
	var entries := _entries()
	if entries.is_empty():
		ui.label("Album ini kosong.",Vector2(332,231),Vector2(580,60),28,UI.SERIF)
		return
	index = clampi(index,0,entries.size()-1)
	var path:String = entries[index][0]
	var title:String = entries[index][1]
	var origin := Vector2(316,135)
	var extent := Vector2(898,420)
	ui.box(origin,extent,STUDIO_COLOR)
	if category==3:
		var item = load(path)
		title = item.display_name
		_preview(ui,origin,extent,item.world_model)
		ui.picture(item.icon.resource_path,Vector2(340,402),Vector2(132,132),false)
	elif category==8:
		ui.picture("res://assets/art/locations/announcement_control_room.webp",origin,extent)
		var tape := AudioStreamPlayer.new()
		ui.add_child(tape)
		tape.stream = load(path)
		tape.volume_db = -4
		ui.button("Putar rekaman",Vector2(344,469),Vector2(225,52),tape.play,true,true,"play")
		ui.button("Berhenti",Vector2(585,469),Vector2(156,52),tape.stop)
	elif category==4 or category==5:
		_preview(ui,origin,extent,load(path))
	else:
		var picture:TextureRect = ui.picture(path,origin,extent,false)
		if category==0 and lighting>0:
			_grade(picture,lighting)
	ui.label(title,Vector2(316,567),Vector2(886,55),34,UI.SERIF)
	if category==0:
		var light := OptionButton.new()
		for state in STATES: light.add_item(state)
		light.selected=lighting
		ui.place(light,Vector2(316,643),Vector2(192,40))
		light.item_selected.connect(_lighting.bind(game))
	elif category in [3,4,5]:
		ui.button("Putar",Vector2(316,634),Vector2(153,45),_rotate.bind(game))
	var count:Label = ui.label("%d  /  %d" % [index+1,entries.size()],Vector2(793,631),Vector2(140,48),18,UI.BOLD,UI.MUTED)
	count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	for i in 2:
		var dir := -1 if i==0 else 1
		var b:Button = ui.button("‹" if i==0 else "›",Vector2(966+i*130,633),Vector2(116,47),_change.bind(game,dir),false,index+dir>=0 and index+dir<entries.size())
		b.alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text="Sebelumnya" if i==0 else "Berikutnya"
		var key := InputEventKey.new()
		key.keycode=KEY_PAGEUP if i==0 else KEY_PAGEDOWN
		b.shortcut=Shortcut.new()
		b.shortcut.events=[key]

func _viewer(game) -> void:
	load("res://scripts/character_viewer.gd").new().show(game)

func _lighting(value:int,game) -> void:
	lighting=value
	_draw(game)

func _category(game,which:int) -> void:
	category=which
	index=0
	lighting=0
	rotation_step=0
	_draw(game)

func _change(game,dir:int) -> void:
	index+=dir
	rotation_step=0
	_draw(game)

func _rotate(game) -> void:
	rotation_step=(rotation_step+1)%8
	_draw(game)

func _grade(pic:TextureRect,phase:int) -> void:
	var sh := Shader.new()
	sh.code="""shader_type canvas_item;
	uniform int mode = 0;
	void fragment() {
		vec4 tex=texture(TEXTURE,UV);
		float l=dot(tex.rgb,vec3(.299,.587,.114));
		vec3 c=tex.rgb;
		if(mode==1) {c=mix(c,vec3(l*.42,l*.59,l*.66),.8)*.37;}
		if(mode==2) {c=c*.42+vec3(.8,.14,.025)*pow(l,.85)*(.4+.6*(1.-UV.x));}
		if(mode==3) {c=mix(c,vec3(l*.64,l*.9,l*.77),.75)*(1.-.12*sin(UV.y*680.));}
		if(mode==4) {c=pow(c,vec3(.60))*(vec3(1.15,1.02,.82))+.05*vec3(1.,.73,.45)*(1.-UV.y);}
		COLOR=vec4(c,tex.a);
	}"""
	var mat := ShaderMaterial.new()
	mat.shader=sh
	mat.set_shader_parameter("mode",phase)
	pic.material=mat

func _preview(ui,origin:Vector2,extent:Vector2,res:Resource) -> void:
	var holder := SubViewportContainer.new()
	holder.stretch=true
	holder.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.place(holder,origin,extent)
	var view := SubViewport.new()
	view.own_world_3d=true
	view.size=Vector2i(extent)
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	holder.add_child(view)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=STUDIO_COLOR
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("#d1e4dc")
	env.environment.ambient_light_energy=0.72
	view.add_child(env)
	var lamp:=DirectionalLight3D.new()
	lamp.rotation_degrees=Vector3(-50,-28,0)
	lamp.light_energy=1.65
	view.add_child(lamp)
	var root:=Node3D.new()
	view.add_child(root)
	var model:Node3D
	if res is PackedScene:
		model=res.instantiate() as Node3D
	elif res is Material:
		var sphere:=MeshInstance3D.new()
		sphere.mesh=SphereMesh.new()
		sphere.material_override=res
		model=sphere
	if model==null: return
	root.add_child(model)
	root.rotation.y=deg_to_rad(rotation_step*45)
	var meshes := model.find_children("*","MeshInstance3D",true,false)
	if model is MeshInstance3D: meshes.push_front(model)
	var bounds:=AABB()
	for child in meshes:
		if child.mesh:
			var area:AABB=child.global_transform*child.get_aabb()
			bounds=area if bounds.size==Vector3.ZERO else bounds.merge(area)
	var camera:=Camera3D.new()
	view.add_child(camera)
	var radius:=maxf(.015,bounds.size.length()*.5)
	var target:=bounds.get_center()
	camera.near=maxf(.0007,radius*.005)
	camera.far=maxf(50,radius*18)
	camera.position=target+Vector3(1.0,.60,1.50).normalized()*radius*3.05
	camera.look_at(target)
	camera.current=true
