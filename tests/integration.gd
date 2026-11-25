extends SceneTree
## Use a fresh XDG_DATA_HOME with no existing game/checkpoint when running on Linux.
## A real key event and interaction ray start the campaign. Later stations are
## approached via fixture positions so story and UI tests are independent of AI paths.
const MAIN := preload("res://scenes/main.tscn")
var game
var checks := 0
var failures := 0
var routes := 0

func _initialize() -> void:
	run.call_deferred()

func check(value:bool, context:String) -> bool:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",context)
	return value

func key(code:Key) -> void:
	for pressed in [true,false]:
		var e := InputEventKey.new()
		e.keycode=code
		e.physical_keycode=code
		e.pressed=pressed
		root.push_input(e,true)

func listed(title:String) -> Button:
	for n in game.ui.get_children():
		if n is Button and n.text==title: return n
	return null

func click(title:String) -> bool:
	var b := listed(title)
	if not check(is_instance_valid(b) and not b.disabled,"button %s on %s" % [title,game.page]): return false
	b.pressed.emit()
	return true

func has_text(part:String) -> bool:
	for n in game.ui.get_children():
		if n is Label and part in n.text: return true
	return false

func run() -> void:
	# Never overwrite a user's checkpoint. Always use a fresh data sandbox.
	for name in ["checkpoint.json","checkpoint.json.bak","settings.cfg"]:
		if FileAccess.file_exists("user://"+name):
			printerr("Refusing to overwrite existing test/player data. Set XDG_DATA_HOME to an empty directory.")
			quit(2)
			return
	game=MAIN.instantiate()
	root.add_child(game)
	await process_frame
	check(game.page=="home","main menu")
	check(listed("Lanjutkan").disabled,"locked continue on fresh profile")
	click("Pengaturan")
	click("Tampilan")
	click("Audio")
	for n in game.ui.get_children():
		if n is HSlider:
			n.value = .45
			break
	var settings := ConfigFile.new()
	check(settings.load("user://settings.cfg")==OK and is_equal_approx(settings.get_value("game","volume",0.),.45),"volume slider persists")
	click("Kembali")
	click("Panduan kontrol")
	check(has_text("Bergerak"),"control reference")
	click("Kembali")
	click("Permainan baru")
	check(game.page=="cut","intro")
	click("Masuk ke sekolah")
	if game.page!="play":
		check(false,"gameplay entered")
		quit(1)
		return
	for i in 4: await physics_frame
	var old:Vector3=game.player.position
	Input.action_press("raka_forward")
	for i in 12: await physics_frame
	Input.action_release("raka_forward")
	check(game.player.position.distance_to(old)>.12,"physical walking")
	var gate:Vector3=game.marker_target
	game.player.look_at(Vector3(gate.x,game.player.position.y,gate.z))
	game.player.look.look_at(gate+Vector3.UP*.9)
	for i in 2: await physics_frame
	key(KEY_E)
	if not check(game.page=="dialog" and game.story.completed==1,"eye ray and E advance gate interaction"):
		print("pose=",game.player.position," target=",game.player.target_id)
		quit(1)
		return
	click("Lanjutkan")
	key(KEY_TAB)
	check(game.page=="inventory" and has_text("Isi tas"),"Tab shows real inventory")
	click("Jurnal")
	click("Tokoh")
	click("›")
	check(has_text("Reski"),"page through portraits")
	click("Denah")
	click("2")
	check(has_text("Perpustakaan"),"upper-floor map")
	key(KEY_M)
	check(game.page=="play","return from map")
	key(KEY_ESCAPE)
	check(game.page=="pause","pause via Escape")
	click("Muat checkpoint")
	check(game.story.completed==1 and game.page=="play","restore progress")
	# Exercise the recovery path with an interrupted primary write in this isolated profile.
	game.checkpoint()
	var damaged := FileAccess.open("user://checkpoint.json",FileAccess.WRITE)
	damaged.store_string("{")
	damaged.close()
	game.caught()
	check(game.page=="caught","capture screen")
	click("Coba dari checkpoint")
	check(game.story.completed==1 and game.page=="play","recover previous checkpoint")
	game.checkpoint()
	for ending in ["good","neutral","bad"]:
		if ending!="good":
			game.home()
			click("Permainan baru")
			click("Mulai permainan baru")
			click("Masuk ke sekolah")
		await route(ending)
		if failures>0: break
	game.home()
	game.sound.ambience("menu")
	# Release audio streams while the Dummy audio thread is still mixing.
	for n in game.sound.get_children():
		if n is AudioStreamPlayer: n.stop()
	game.queue_free()
	await create_timer(.15).timeout
	print("Integration checks: %d; ending screens: %d; failures: %d" % [checks,routes,failures])
	quit(1 if failures else 0)

func route(last:String) -> void:
	var chapters:Dictionary={}
	while not game.story.objective().is_empty():
		if failures>0: return
		var q:Dictionary=game.story.objective()
		chapters[game.story.chapter]=true
		if not check(game.page=="play","play before "+str(q.id)): return
		var from:Vector3=game.marker_target
		var approach := -1.5 if q.room=="gate" and q.id!="enter_school" else 1.5
		var pos:=Vector3(from.x,from.y+.06,from.z+approach)
		game.player.position=pos
		game.player.velocity=Vector3.ZERO
		game.player.rotation.y=0. if approach>0 else PI
		game.player.look.rotation=Vector3(-.4,0,0)
		for i in 2: await physics_frame
		key(KEY_E)
		if not check(game.page in ["dialog","ending"],"interact %s (%s), hit=%s" % [q.id,q.room,game.player.target_id]): return
		if q.has("p"):
			for card in q.p.order:
				if not click(q.p.cards[card]): return
		elif q.has("decision"):
			var decision:=0
			if q.id=="broadcast" and last=="neutral": decision=1
			if q.id=="plan_escape" and last=="bad": decision=3
			if not click(q.decision[decision]): return
		check(game.story.objective().get("id")!=q.id, "advanced "+str(q.id))
		if game.page=="dialog": click("Lanjutkan")
		if game.page=="cut": click("Lanjutkan")
		if last=="good" and q.id=="battery":
			game.player.battery = 61.
			key(KEY_F)
			check(not game.player.torch_on,"flashlight toggle")
			key(KEY_R)
			check(game.player.battery==100 and game.player.spare_batteries==0,"replace battery")
		if last=="good" and q.get("item","")=="school_yearbook":
			key(KEY_TAB)
			click("‹")
			check(has_text("1  /"),"inventory pagination")
			key(KEY_TAB)
			key(KEY_J)
			click("›")
			check(has_text("2  /"),"document pagination")
			key(KEY_J)
	if check(game.page=="ending" and game.story.ending==last,"ending "+last):
		routes+=1
	check(chapters.size()==6,"six sections")
	check(game.read_save().story.ending==last,"ending is persisted")
