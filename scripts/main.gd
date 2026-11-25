extends Node
const UI = preload("res://scripts/interface.gd")
const Story = preload("res://scripts/story.gd")
const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Actors = preload("res://scripts/actors.gd")
const Sound = preload("res://scripts/sound.gd")
const Station = preload("res://scripts/station.gd")
const SAVE = "user://checkpoint.json"
const PREFS = "user://settings.cfg"
const PLACES = {"gate":"Gerbang sekolah","security":"Pos satpam","class":"Kelas XII RPL","teachers":"Ruang guru","toilet":"Toilet","storage":"Gudang","power":"Ruang listrik","lab":"Lab komputer","canteen":"Kantin","library":"Perpustakaan","clinic":"UKS","bk":"Ruang BK","documentation":"Dokumentasi","principal":"Kepala sekolah","archive":"Ruang arsip","hall":"Aula","speaker":"Kontrol speaker","safe":"Ruang aman"}
const CUTS = ["cinematic_intro_01","cinematic_separation","loading_chapter2","cinematic_reski_rescue","cinematic_laras_reveal","cinematic_final_escape"]
const INTROS = [
	"Akbar merapatkan jaket. “Serius kita harus balik ke sekolah jam segini?”\nReski menunjuk ke balik gerbang. Map tugas mereka masih di kelas XII RPL.",
	"Jam dinding berhenti. Dari speaker terdengar perintah untuk kembali ke kelas. Ketika Raka membuka mata, kedua temannya sudah pergi.",
	"Sinyal Reski terputus sesaat setelah ia menyebut generator. Di sayap belakang, satu jalur listrik masih berdengung.",
	"Nama yang hilang dari absensi meninggalkan bekas tekanan di kertas. Mungkin halaman lain masih menyimpan tulisannya.",
	"Di balik ruang kepala sekolah ada lemari arsip yang luput dari api. Seseorang menyimpan kuncinya selama bertahun-tahun.",
	"Bel berikutnya bisa membuka gerbang. Untuk terakhir kalinya, seseorang harus bicara dari ruang kontrol."
]
var ui
var sound
var world
var player
var actors
var story
var session: Node3D
var markers: Node3D
var page := "home"
var cfg := ConfigFile.new()
var elapsed := 0.0
var objective_hud: Label
var bearing_hud: Label
var prompt_hud: Label
var energy_hud: Label
var notice_hud: Label
var notice_time := 0.0
var last_notice := ""
var dialog_title := ""
var notebook = preload("res://scripts/notebook.gd").new()
var gallery
var pending_cut := false
var marker_target: Vector3
var effect_time := 0.0
var flash_layer: ColorRect
var saving_failed := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	cfg.load(PREFS)
	sound = Sound.new()
	add_child(sound)
	sound.setup()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = UI.new()
	canvas.add_child(ui)
	apply_settings()
	home()

func home() -> void:
	if is_instance_valid(session):
		remove_child(session)
		session.queue_free()
		session = null
		player = null
		actors = null
	page = "home"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sound.ambience("menu")
	ui.home(not read_save().is_empty(),menu_action)
	ui.button("Arsip visual",Vector2(195,661),Vector2(170,42),menu_action.bind("gallery"))

func menu_action(id:String) -> void:
	sound.play("click")
	match id:
		"new":
			if read_save().is_empty():
				start_game(false)
			else:
				simple_page("new_confirm","Permainan baru","Mulai dari gerbang sekolah? Progres permainan sebelumnya akan diganti ketika kamu melanjutkan.")
				ui.button("Mulai permainan baru",Vector2(74,410),Vector2(310,50),start_game.bind(false),true)
		"continue": start_game(true)
		"settings": settings()
		"controls": controls()
		"credits": credits()
		"gallery":
			set_page("gallery")
			gallery = load("res://scripts/gallery.gd").new()
			gallery.show(self)
		"quit": exit_game()

func read_slot(path:String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {}
	var parsed = parser.data
	if parsed is Dictionary and parsed.get("version") == 1 and parsed.get("story") is Dictionary and parsed.get("pos") is Array and parsed.pos.size()==3:
		if Story.new().restore(parsed.story) and parsed.pos.all(func(v): return (v is float or v is int) and is_finite(v)):
			return parsed
	return {}

func read_save() -> Dictionary:
	var primary = read_slot(SAVE)
	return read_slot(SAVE+".bak") if primary.is_empty() else primary

func checkpoint() -> void:
	if not is_instance_valid(player): return
	var pos: Vector3 = player.position
	var packed = {"version":1,"story":story.save_data(),"elapsed":elapsed,"pos":[pos.x,pos.y,pos.z],
		"yaw":player.rotation.y,"pitch":player.look.rotation.x,"charge":player.battery,"spares":player.spare_batteries,"torch":player.torch_on}
	var path := ProjectSettings.globalize_path(SAVE)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		save_error()
		return
	file.store_string(JSON.stringify(packed))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		save_error()
		return
	if not read_slot(SAVE).is_empty():
		if DirAccess.copy_absolute(path,path+".bak") != OK:
			save_error()
			return
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		save_error()

func save_error() -> void:
	saving_failed = true
	notify("Checkpoint gagal ditulis ke direktori pengguna.")

func start_game(resume:bool) -> void:
	notebook = preload("res://scripts/notebook.gd").new()
	var data:Dictionary = read_save() if resume else {}
	if resume and data.is_empty():
		home()
		return
	if is_instance_valid(session):
		remove_child(session)
		session.queue_free()
	session = Node3D.new()
	add_child(session)
	world = World.new()
	session.add_child(world)
	world.setup()
	story = Story.new()
	if resume: story.restore(data.story)
	elapsed = data.get("elapsed",0.)
	pending_cut = false
	if not story.ending.is_empty():
		show_ending(story.ending)
		return
	player = Player.new()
	session.add_child(player)
	player.position = world.spawn_position + Vector3.UP*.07
	if resume:
		player.position = Vector3(data.pos[0],data.pos[1],data.pos[2]) + Vector3.UP*.03
		player.rotation.y = data.get("yaw",0.)
		player.look.rotation.x = data.get("pitch",0.)
		player.battery = data.get("charge",100.)
		player.spare_batteries = data.get("spares",0)
		player.torch_on = data.get("torch",true)
	elapsed = data.get("elapsed",0.)
	player.has_flashlight = "flashlight" in story.inventory
	player.interacted.connect(interact)
	player.shortcut.connect(shortcut)
	player.notice.connect(notify)
	actors = Actors.new()
	session.add_child(actors)
	actors.setup(player,world)
	actors.caught.connect(caught)
	actors.set_stage(story.chapter)
	actors.set_meta("shown_chapter",story.chapter)
	actors.subtitle.connect(func(who,line): 
		if setting("subs",true): notify(str(who).to_upper()+"   /   "+line))
	if story.objective().get("id","") in ["evac_reski","evac_akbar","escape"]:
		actors.begin_evacuation()
	if "battery" in story.inventory: player.set_meta("received_battery",true)
	for person in story.rescued: actors.rescue(person)
	if ResourceLoader.exists("res://scripts/atmosphere.gd"):
		atmosphere = load("res://scripts/atmosphere.gd").new()
		session.add_child(atmosphere)
		atmosphere.setup(player,world)
	markers = Node3D.new()
	session.add_child(markers)
	sync_markers()
	apply_settings()
	sound.ambience(str(story.chapter))
	if resume:
		play_screen()
	else:
		checkpoint()
		cutscene()

func sync_markers() -> void:
	if world.has_method("apply_progress"): world.apply_progress(story)
	for node in markers.get_children():
		markers.remove_child(node)
		node.queue_free()
	var quests:Array = [story.objective()]
	quests.append_array(story.extras())
	var station_counts := {}
	for i in range(quests.size()):
		var quest:Dictionary = quests[i]
		if quest.is_empty(): continue
		var obj = Station.new()
		markers.add_child(obj)
		var count:int = station_counts.get(quest.room,0)
		obj.position = (world.interaction_position(quest) if world.has_method("interaction_position") else world.stations[quest.room]) + Vector3(count*1.15,0,0)
		obj.setup(quest,i>0)
		station_counts[quest.room] = count+1
		if i==0: marker_target = obj.position

func set_page(id:String) -> void:
	page = id
	if is_instance_valid(player): player.active = id == "play"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if id=="play" else Input.MOUSE_MODE_VISIBLE
	ui.clear()

func cutscene() -> void:
	set_page("cut")
	var name_key:String = CUTS[story.chapter]
	var art = "res://assets/art/"+name_key+".webp"
	ui.backplate(art if ResourceLoader.exists(art) else UI.MENU,.12)
	ui.box(Vector2(0,438),Vector2(1280,282),Color(0.035,0.052,0.046,.90))
	ui.label("PROLOG   /   23.47" if story.chapter==0 else "BAB   /   %02d" % story.chapter,Vector2(74,461),Vector2(480,27),15,UI.BOLD,Color("#cc9981"))
	ui.label(story.chapters[story.chapter],Vector2(71,494),Vector2(1110,71),51,UI.SERIF)
	ui.label(INTROS[story.chapter],Vector2(74,577),Vector2(805,101),21,UI.SANS,UI.PAPER,true)
	ui.button("Masuk ke sekolah" if story.chapter==0 else "Lanjutkan",Vector2(958,621),Vector2(243,52),play_screen,true,true,"play")

func play_screen() -> void:
	set_page("play")
	ui.box(Vector2(40,37),Vector2(3,77),UI.RED)
	ui.box(Vector2(43,37),Vector2(480,77),Color(0.04,0.06,0.05,.72))
	var objective:Dictionary = story.objective()
	objective_hud = ui.label(objective.get("label","Gerbang sekolah"),Vector2(59,45),Vector2(452,32),21,UI.BOLD)
	bearing_hud = ui.label("",Vector2(59,82),Vector2(455,23),15,UI.SANS,UI.MUTED)
	ui.box(Vector2(638,358),Vector2(4,4),UI.PAPER)
	prompt_hud = ui.label("",Vector2(240,405),Vector2(800,40),22,UI.BOLD)
	prompt_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_hud.add_theme_constant_override("outline_size",5)
	prompt_hud.add_theme_color_override("font_outline_color",Color("#18211e"))
	energy_hud = ui.label("",Vector2(48,644),Vector2(580,44),16,UI.BOLD)
	energy_hud.add_theme_constant_override("outline_size",4)
	notice_hud = ui.label("",Vector2(245,560),Vector2(790,72),21,UI.SANS,UI.PAPER,true)
	notice_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_hud.add_theme_constant_override("outline_size",6)
	flash_layer = ui.box(Vector2.ZERO,Vector2(1280,720),Color.TRANSPARENT)
	if story.completed==0: notify("WASD bergerak   •   Mouse melihat   •   E memeriksa   •   M denah")

func _process(delta:float) -> void:
	if page!="play" or not is_instance_valid(player): return
	elapsed += delta
	var target:Vector3 = marker_target-player.position
	var local:Vector3 = player.transform.basis.inverse()*target
	var direction := "di depan"
	if local.z>absf(local.x)*0.8: direction="di belakang"
	elif absf(local.x)>absf(local.z)*0.6: direction = "di kanan" if local.x>0 else "di kiri"
	var floor_text := "  ↑ Lantai 2" if target.y>2.1 else ("  ↓ Lantai 1" if target.y < -2.1 else "")
	bearing_hud.text = "%s   ·   %d m %s%s" % [PLACES.get(story.objective().get("room",""),""),ceili(target.length()),direction,floor_text]
	prompt_hud.text = ("[ E ]   "+player.prompt) if player.prompt else ""
	energy_hud.text = ("SENTER   %d%%    " % ceili(player.battery) if player.has_flashlight and player.torch_on else "") + ("NAPAS   %d%%" % int(player.stamina) if player.stamina<96 else "")
	notice_time = maxf(0,notice_time-delta)
	notice_hud.text = last_notice if notice_time>0 else ""
	effect_time = maxf(0,effect_time-delta)
	flash_layer.color = Color(.04,.065,.055,effect_time*.62)

func notify(message:String) -> void:
	last_notice = message
	notice_time = 4.5

func interact(id:String) -> void:
	var title = story.objective().get("label","Catatan")
	for q in story.extras():
		if q.id==id: title=q.label
	dialog_title = title
	process_event(story.interact(id),story_chapter_before)

var story_chapter_before:int:
	get: return actors.get_meta("shown_chapter",0) if is_instance_valid(actors) else 0

func answer(i:int) -> void:
	process_event(story.choose(i),story_chapter_before)

func process_event(result:Dictionary, old_chapter:int) -> void:
	var effect:String = result.get("effect","")
	if effect!="":
		sound.play(effect)
		if is_instance_valid(atmosphere) and setting("effects",true): atmosphere.event(effect)
		if effect=="chase" and story.chapter==5: actors.begin_evacuation()
		if effect in ["blackout","chase","whisper"] and cfg.get_value("game","effects",true): effect_time=.86
	else: sound.play("pickup" if not result.has("choices") else "click")
	if result.get("alarm",false): actors.alarm()
	if result.get("rescued","")!="": actors.rescue(result.rescued)
	player.has_flashlight = "flashlight" in story.inventory
	if "battery" in story.inventory and not player.has_meta("received_battery"):
		player.set_meta("received_battery",true)
		player.spare_batteries += 1
	pending_cut = old_chapter != story.chapter
	if pending_cut:
		actors.set_stage(story.chapter)
		actors.set_meta("shown_chapter",story.chapter)
		sound.ambience(str(story.chapter))
	sync_markers()
	if result.get("checkpoint",false) or not result.has("choices"): checkpoint()
	if result.get("ending","")!="":
		show_ending(result.ending)
		return
	set_page("dialog")
	if result.get("rescued","") in ["reski","akbar"] and story.chapter in [2,3]:
		ui.picture("res://assets/art/cinematic_%s_rescue.webp" % result.rescued,Vector2.ZERO,Vector2(1280,720)) 
	ui.box(Vector2(0,258),Vector2(1280,462),Color(.045,.067,.058,.96))
	ui.box(Vector2(72,300),Vector2(35,3),UI.RED)
	ui.label(dialog_title,Vector2(74,314),Vector2(1120,54),32,UI.SERIF)
	var choices:Array = result.get("choices",[])
	ui.label(result.get("text",""),Vector2(74,380),Vector2(1100,150),int(cfg.get_value("game","text",21)),UI.SANS,UI.PAPER,true)
	if choices.is_empty():
		ui.button("Lanjutkan",Vector2(74,634),Vector2(236,50),finish_dialog,true,true,"play")
	else:
		for i in range(choices.size()):
			var row := floori(i/2.0)
			ui.button(choices[i],Vector2(74+(i%2)*568,536+row*50),Vector2(550,45),answer.bind(i),false)

func finish_dialog() -> void:
	if pending_cut:
		pending_cut = false
		cutscene()
	else:
		play_screen()

func caught() -> void:
	if page!="play": return
	set_page("caught")
	sound.play("catch") if setting("scares",true) else sound.play("bell")
	ui.backplate("res://assets/art/apparitions/guardian_jumpscare_overlay.webp" if setting("effects",true) else UI.MENU,.57)
	ui.header("Penjaga Bayangan","Kamu tidak berhasil keluar.")
	ui.label("Langkahnya berhenti tepat di belakangmu. Suara bel terdengar lagi.",Vector2(74,253),Vector2(980,90),24,UI.SERIF)
	ui.button("Coba dari checkpoint",Vector2(74,462),Vector2(332,54),start_game.bind(true),true,true,"continue")
	ui.button("Menu utama",Vector2(74,530),Vector2(332,48),home)

func show_ending(id:String) -> void:
	set_page("ending")
	sound.ambience(id)
	var titles = {"good":"Bel Pulang","neutral":"Rahasia yang Tertinggal","bad":"Absensi Terakhir"}
	var lines = {"good":"Jam di pos mulai berdetak. Di jendela atas, Laras menurunkan tangan.\nRaka menoleh pada kedua temannya. “Akhirnya… kita bisa pulang.”","neutral":"Tiga pasang sepatu meninggalkan jejak di jalan yang basah. Dari lantai dua yang gelap, bel berbunyi sekali lagi.","bad":"Besok pagi sebuah nama baru tertulis di daftar siswa yang tidak pernah pulang. Telepon Raka berdering. “Rak… jangan lupa jemput kita.”"}
	ui.backplate("res://assets/art/ending_"+id+".webp",.23)
	ui.box(Vector2(0,405),Vector2(1280,315),Color(.035,.05,.04,.92))
	ui.label("AKHIR CERITA",Vector2(76,427),Vector2(500,30),15,UI.BOLD,UI.MUTED)
	ui.label(titles[id],Vector2(72,464),Vector2(1050,70),54,UI.SERIF)
	ui.label(lines[id],Vector2(76,548),Vector2(1080,70),21,UI.SANS,UI.PAPER,true)
	ui.label("%d misi   ·   %d bukti   ·   %d teman selamat   ·   %d menit" % [story.completed,story.evidence.size(),story.rescued.size(),ceili(elapsed/60)],Vector2(76,640),Vector2(800,46),17,UI.BOLD,UI.MUTED)
	ui.button("Menu utama",Vector2(975,638),Vector2(230,49),home,true)

func simple_page(id:String,title:String,body:String="") -> void:
	set_page(id)
	ui.backplate(UI.MENU,.84)
	ui.header("SMA Nusa Bangsa",title)
	if body!="":
		ui.label(body,Vector2(74,239),Vector2(1070,108),23,UI.SANS,UI.PAPER,true)
	ui.button("Kembali",Vector2(74,647),Vector2(197,47),back,false,true,"back")

func back() -> void:
	if page in ["inventory","journal","map","pause"]: play_screen()
	elif is_instance_valid(session) and is_instance_valid(player): paused()
	else: home()

func controls() -> void:
	simple_page("controls","Panduan kontrol")
	var rows = [["W A S D","Bergerak"],["Mouse","Melihat sekeliling"],["Shift / Ctrl","Lari / jongkok"],["Spasi","Melompat"],["E","Periksa, bicara, sembunyi"],["F / R","Senter / ganti baterai"],["Tab / J","Tas / jurnal"],["M","Denah sekolah"],["Q","Hubungi radio"],["Esc","Jeda / kembali"]]
	for i in rows.size():
		var x = 75+(i/5)*590
		var y = 232+(i%5)*69
		ui.label(rows[i][0],Vector2(x,y),Vector2(135,39),20,UI.BOLD,Color("#debe9a"))
		ui.label(rows[i][1],Vector2(x+135,y),Vector2(421,39),21)
		ui.box(Vector2(x,y+48),Vector2(527,1),Color("#3a423a"))

func credits() -> void:
	simple_page("credits","Kredit")
	ui.picture("res://assets/ui/crest.svg",Vector2(77,247),Vector2(105,122),false)
	ui.label("Sekolah Setelah Tengah Malam",Vector2(219,236),Vector2(940,60),36,UI.SERIF)
	ui.label("Cerita, karakter dan lingkungan asli untuk proyek SMA Nusa Bangsa.\nDibuat dengan Godot Engine. Musik, efek suara, model dan ilustrasi disertakan dalam proyek.",Vector2(221,317),Vector2(880,120),21,UI.SANS,UI.PAPER,true)
	ui.label("Huruf: Open Sans dan DejaVu Serif. Lisensi dan asal setiap aset tersedia di dokumentasi proyek.",Vector2(221,475),Vector2(832,94),17,UI.SANS,UI.MUTED,true)

func shortcut(action:String) -> void:
	match action:
		"pause": paused()
		"inventory","map","journal":
			set_page(action)
			notebook.show(self,action)
		"radio":
			if "walkie_talkie" in story.inventory:
				sound.play("radio")
				notify("RADIO   /   "+str(story.objective().get("description","Pergi ke gerbang.")))
			else:
				notify("Cari radio komunikasi di sekolah.")

func paused() -> void:
	simple_page("pause","Permainan dijeda")
	var options = [["Lanjutkan permainan",play_screen],["Muat checkpoint",start_game.bind(true)],["Pengaturan",settings],["Panduan kontrol",controls],["Menu utama",home],["Keluar",exit_game]]
	for i in options.size():
		ui.button(options[i][0],Vector2(74,224+i*60),Vector2(410,48),options[i][1],i==0)

func setting(key:String,default_value:Variant) -> Variant:
	return cfg.get_value("game",key,default_value)

func update_setting(key:String,value:Variant) -> void:
	cfg.set_value("game",key,value)
	if cfg.save(PREFS)!=OK: notify("Pengaturan gagal disimpan.")
	apply_settings()

func apply_settings() -> void:
	sound.set_volume(setting("volume",.85))
	for bus in ["Music","Ambience","SFX","Dialogue","UI"]:
		sound.set_bus_volume(bus,setting(bus,1.0))
	Engine.max_fps = int(setting("fps",30))
	get_viewport().scaling_3d_scale = float(setting("scale",.85))
	if DisplayServer.get_name()!="headless":
		var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if setting("fullscreen",false) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode()!=mode: DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if setting("vsync",true) else DisplayServer.VSYNC_DISABLED)
	if is_instance_valid(player):
		player.sensitivity = float(setting("sensitivity",2.4))*.001
		player.camera.fov = float(setting("fov",76))
		player.camera.far = 90.0
		player.head_bob = setting("bob",true)
	if is_instance_valid(actors): actors.difficulty = setting("difficulty","Normal")
	if is_instance_valid(atmosphere):
		atmosphere.visible = setting("effects",true)

func settings(tab:int=0) -> void:
	simple_page("settings","Pengaturan")
	for i in 3:
		ui.button(["Permainan","Tampilan","Audio"][i],Vector2(74+240*i,210),Vector2(229,44),settings.bind(i),i==tab)
	if tab==0:
		option_row("Kesulitan","difficulty",["Cerita","Normal","Mimpi buruk"],["Story","Normal","Nightmare"],"Normal",0)
		slider_row("Sensitivitas mouse","sensitivity",1.,6.,.1,2.4,1)
		slider_row("Sudut pandang","fov",60.,100.,1.,76.,2)
		toggle_row("Gerak kepala saat berjalan","bob",true,3)
		slider_row("Ukuran teks dialog","text",16,24,1,21,4)
		toggle_row("Subtitle percakapan teman","subs",true,5)
	elif tab==1:
		toggle_row("Layar penuh","fullscreen",false,0)
		toggle_row("Sinkronisasi vertikal","vsync",true,1)
		option_row("Batas frame per detik","fps",["30 FPS","60 FPS","120 FPS"],[30,60,120],30,2)
		option_row("Skala render 3D","scale",["70%","85%","100%"],[.7,.85,1.],.85,3)
		toggle_row("Efek suasana dan kilatan","effects",true,4)
		toggle_row("Kejutan suara saat tertangkap","scares",true,5)
	else:
		var names = ["Utama","Musik","Suasana sekolah","Efek dan langkah","Dialog","Antarmuka"]
		var keys = ["volume","Music","Ambience","SFX","Dialogue","UI"]
		for i in 6: slider_row(names[i],keys[i],0.,1.,.05,.85 if i==0 else 1.,i)

func row_label(title:String,row:int) -> float:
	var y:float = 278+row*55
	ui.label(title,Vector2(77,y),Vector2(515,40),20,UI.SANS)
	ui.box(Vector2(74,y+45),Vector2(1103,1),Color("#3c453b"))
	return y

func option_row(title:String,key:String,names:Array,values:Array,fallback:Variant,row:int) -> void:
	var y = row_label(title,row)
	var opt := OptionButton.new()
	for item in names: opt.add_item(item)
	opt.select(maxi(0,values.find(setting(key,fallback))))
	ui.place(opt,Vector2(676,y),Vector2(360,38))
	opt.item_selected.connect(func(i): update_setting(key,values[i]))

func slider_row(title:String,key:String,low:float,high:float,step:float,fallback:float,row:int) -> void:
	var y = row_label(title,row)
	var slider := HSlider.new()
	slider.min_value=low
	slider.max_value=high
	slider.step=step
	slider.value=setting(key,fallback)
	ui.place(slider,Vector2(676,y+6),Vector2(328,32))
	var value = ui.label(str(snappedf(slider.value,.01)),Vector2(1036,y),Vector2(108,37),18)
	slider.value_changed.connect(func(v):
		update_setting(key,v)
		value.text=str(snappedf(v,.01)))

func toggle_row(title:String,key:String,fallback:bool,row:int) -> void:
	var y = row_label(title,row)
	var check := CheckButton.new()
	check.button_pressed = setting(key,fallback)
	check.text = "Aktif" if check.button_pressed else "Mati"
	ui.place(check,Vector2(676,y),Vector2(185,39))
	check.toggled.connect(func(value):
		update_setting(key,value)
		check.text="Aktif" if value else "Mati")

func _input(event:InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.physical_keycode==KEY_ESCAPE and page not in ["home","play","cut","ending","caught"]:
		if page=="dialog": finish_dialog()
		else: back()
		get_viewport().set_input_as_handled()
	elif (page=="inventory" and event.physical_keycode==KEY_TAB) or (page=="map" and event.physical_keycode==KEY_M) or (page=="journal" and event.physical_keycode==KEY_J):
		play_screen()
		get_viewport().set_input_as_handled()

var atmosphere

var leaving := false

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree(): exit_game()

func exit_game() -> void:
	if leaving: return
	leaving = true
	if is_instance_valid(player): player.active=false
	for node in find_children("*","AudioStreamPlayer",true,false)+find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream=null
	await get_tree().create_timer(.3).timeout
	get_tree().quit()
