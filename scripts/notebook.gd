extends RefCounted
## Raka's field notebook. Each open screen keeps its own selection and page.
const UI := preload("res://scripts/interface.gd")
const SHEET := Color("#202d29")
const FIELD := Color("#19251f")
const RULE := Color("#52665b")
const AMBER := Color("#f0c47a")
const JADE := Color("#93cbb7")
const CHARACTERS := [
	["raka", "Raka", "XII RPL", "Cuma mau mengambil map tugas yang tertinggal. Sekarang suara teman-temannya menjadi satu-satunya penunjuk jalan."],
	["reski", "Reski", "XII RPL", "Selalu membawa alat kecil di tasnya. Jika mendengar tiga ketukan berurutan dari radio, tunggu jawabannya."],
	["akbar", "Akbar", "XII RPL", "Jaket marunnya mudah terlihat dari ujung lorong. Biasanya ia yang paling dulu bercanda saat yang lain panik."],
	["laras", "Laras Wening", "Angkatan 2008", "Namanya muncul di balik salinan absensi. Pada potongan foto kelas ia memakai pita rambut putih."],
]
const SECTIONS := {"inventory":["Isi tas", "inventory"], "journal":["Jurnal", "journal"], "map":["Denah", "map"]}
var current := ""
var inventory_offset := 0
var selected_item := -1
var log_offset := 0
var character_index := 0
var journal_tab := "Catatan"
var level := 0

func show(game, page:String) -> void:
	current = page
	if page == "map":
		level = int(game.player.position.y >= 2.5)
	elif page == "inventory":
		selected_item = game.story.inventory.size() - 1
		inventory_offset = maxi(0, selected_item / 8)
	_draw(game)

func _draw(game) -> void:
	var ui = game.ui
	ui.clear()
	ui.box(Vector2.ZERO,Vector2(1280,720),Color(.043,.067,.057,.97))
	ui.picture("res://assets/ui/crest.svg", Vector2(61,26), Vector2(37,44), false)
	ui.label("SMA NUSA BANGSA",Vector2(115,25),Vector2(240,24),16,UI.BOLD)
	ui.label("Buku lapangan Raka",Vector2(115,51),Vector2(240,22),14,UI.SANS,UI.MUTED)
	for i in range(3):
		var key: String = SECTIONS.keys()[i]
		ui.button(SECTIONS[key][0],Vector2(698+i*174,30),Vector2(165,46),_switch.bind(game,key),current==key,true,SECTIONS[key][1])
	ui.box(Vector2(62,94),Vector2(1156,1),RULE)
	match current:
		"inventory": _bag(game)
		"journal": _journal(game)
		"map": _map(game)
	ui.box(Vector2(62,630),Vector2(1156,1),RULE)
	ui.button("Kembali",Vector2(62,650),Vector2(167,44),game.play_screen,false,true,"back")

func _switch(game,page_name:String) -> void:
	game.set_page(page_name)
	show(game,page_name)

func _title(ui, heading:String, detail:String) -> void:
	ui.label(heading,Vector2(59,109),Vector2(1010,70),44,UI.SERIF)
	ui.label(detail,Vector2(63,176),Vector2(1154,27),17,UI.SANS,UI.MUTED)

func _key(button:Button,keycode:Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	var keys := Shortcut.new()
	keys.events = [event]
	button.shortcut = keys

func _pager(game, pos:int, pages:int, navigate:Callable) -> void:
	var ui = game.ui
	ui.label("%d  /  %d" % [pos + 1, pages],Vector2(900,650),Vector2(100,44),17,UI.BOLD)
	var prev: Button = ui.button("‹",Vector2(1050,650),Vector2(75,44),func(): navigate.call(pos-1),false,pos>0)
	var nxt: Button = ui.button("›",Vector2(1137,650),Vector2(75,44),func(): navigate.call(pos+1),false,pos+1 < pages)
	prev.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nxt.alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev.tooltip_text = "Sebelumnya · Page Up"
	nxt.tooltip_text = "Berikutnya · Page Down"
	_key(prev,KEY_PAGEUP)
	_key(nxt,KEY_PAGEDOWN)

func _bag(game) -> void:
	var ui = game.ui
	var items: Array = game.story.inventory
	var pages := maxi(1,ceili(items.size()/8.0))
	inventory_offset = clampi(inventory_offset,0,pages-1)
	_title(ui,"Isi tas", "%d benda yang dibawa" % items.size())
	for slot in 8:
		var index: int = inventory_offset*8+slot
		var pos := Vector2(62 + (slot%4)*170, 231 + floori(slot/4.0)*170)
		ui.box(pos,Vector2(160,158),FIELD)
		if index >= items.size():
			continue
		var item_id: String = items[index]
		var definition = load("res://assets/items/catalog/"+item_id+".tres")
		var b: Button = ui.button("",pos,Vector2(160,158),_select_item.bind(game,index),index==selected_item)
		b.tooltip_text = definition.display_name
		ui.picture("res://assets/items/icons/"+item_id+".png",pos+Vector2(28,8),Vector2(105,105),false)
		var text: Label = ui.label(definition.display_name,pos+Vector2(4,112),Vector2(152,42),14,UI.BOLD,UI.PAPER,true)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.box(Vector2(765,228),Vector2(451,334),SHEET)
	if selected_item >= 0 and selected_item < items.size():
		var id: String = items[selected_item]
		var defn = load("res://assets/items/catalog/"+id+".tres")
		ui.picture("res://assets/items/icons/"+id+".png",Vector2(783,236),Vector2(412,148),false)
		ui.label(str(defn.item_type).to_upper(),Vector2(792,385),Vector2(392,24),14,UI.BOLD,JADE)
		ui.label(defn.display_name,Vector2(791,409),Vector2(404,53),28,UI.SERIF,UI.PAPER,true)
		ui.label(defn.description,Vector2(792,466),Vector2(398,77),17,UI.SANS,UI.PAPER,true)
	_pager(game,inventory_offset,pages,_bag_page.bind(game))

func _select_item(game,index:int) -> void:
	selected_item = index
	_draw(game)

func _bag_page(index:int,game) -> void:
	inventory_offset = index
	selected_item = index*8
	_draw(game)

func _journal(game) -> void:
	var ui = game.ui
	var story = game.story
	var q: Dictionary = story.objective()
	_title(ui,story.chapters[story.chapter],"Prolog" if story.chapter==0 else "Bab %d" % story.chapter)
	ui.box(Vector2(62,224),Vector2(344,383),FIELD)
	ui.box(Vector2(62,224),Vector2(4,383),UI.RED)
	ui.label("TUJUAN SEKARANG",Vector2(86,249),Vector2(288,27),14,UI.BOLD,AMBER)
	ui.label(q.get("description",""),Vector2(86,288),Vector2(287,112),25,UI.SERIF,UI.PAPER,true)
	ui.label(game.PLACES.get(q.get("room",""),""),Vector2(86,416),Vector2(287,54),19,UI.BOLD,JADE,true)
	ui.box(Vector2(86,489),Vector2(290,1),RULE)
	ui.label("%d misi selesai\n%d dari 6 bukti utama" % [story.completed,story.evidence.size()],Vector2(86,515),Vector2(290,72),17,UI.SANS,UI.MUTED)
	var tabs := ["Catatan","Bukti","Tokoh"]
	for i in tabs.size():
		ui.button(tabs[i],Vector2(434+i*157,224),Vector2(146,41),_journal_tab.bind(game,tabs[i]),journal_tab==tabs[i])
	match journal_tab:
		"Catatan":
			var count: int = story.journal.size()
			var page_count := maxi(1,ceili(count/2.0))
			log_offset = clampi(log_offset,0,page_count-1)
			if count == 0:
				ui.label("Belum ada catatan. Periksa benda di sekolah untuk mencatat temuanmu.",Vector2(439,290),Vector2(736,100),21,UI.SERIF,UI.MUTED,true)
			for i in 2:
				var index: int = count-1-log_offset*2-i
				if index < 0:
					break
				var y := 282+i*164
				ui.box(Vector2(435,y),Vector2(780,1),RULE)
				ui.label("CATATAN  %02d" % (index+1),Vector2(438,y+13),Vector2(743,25),14,UI.BOLD,JADE)
				ui.label(story.journal[index],Vector2(438,y+45),Vector2(748,112),17,UI.SANS,UI.PAPER,true)
			_pager(game,log_offset,page_count,_log_page.bind(game))
		"Bukti":
			if story.evidence.is_empty():
				ui.label("Belum ada bukti utama. Dokumen yang disimpan akan muncul di sini.",Vector2(437,293),Vector2(744,97),21,UI.SERIF,UI.MUTED,true)
			for i in story.evidence.size():
				var id:String = story.evidence[i]
				var pos := Vector2(436+(i%2)*391,281+floori(i/2.0)*107)
				ui.box(pos,Vector2(377,96),SHEET)
				ui.picture("res://assets/items/icons/"+id+".png",pos+Vector2(7,7),Vector2(78,78),false)
				var definition = load("res://assets/items/catalog/"+id+".tres")
				ui.label(definition.display_name,pos+Vector2(91,7),Vector2(275,80),17,UI.BOLD,UI.PAPER,true)
		"Tokoh":
			var count := 4 if story.chapter>=3 else 3
			character_index = clampi(character_index,0,count-1)
			var c: Array = CHARACTERS[character_index]
			ui.box(Vector2(437,282),Vector2(225,321),SHEET)
			ui.picture("res://assets/art/"+str(c[0])+"_portrait.webp",Vector2(442,287),Vector2(215,311))
			ui.label(c[2],Vector2(689,301),Vector2(489,28),15,UI.BOLD,JADE)
			ui.label(c[1],Vector2(688,340),Vector2(505,62),33,UI.SERIF)
			ui.label(c[3],Vector2(690,421),Vector2(492,136),20,UI.SANS,UI.PAPER,true)
			_pager(game,character_index,count,_person_page.bind(game))

func _journal_tab(game,tab:String) -> void:
	journal_tab = tab
	_draw(game)

func _log_page(index:int,game) -> void:
	log_offset = index
	_draw(game)

func _person_page(index:int,game) -> void:
	character_index = index
	_draw(game)

# X runs west to east and positive Z points toward the school's front gate.
func _point(p:Vector3) -> Vector2:
	return Vector2(456+p.x*16, 331+p.z*9.7)

func _map(game) -> void:
	var ui = game.ui
	var plan:Dictionary = game.world.stations
	var objective:Dictionary = game.story.objective()
	var room: String = objective.get("room","")
	var player_pos:Vector3 = game.player.position
	var player_level := int(player_pos.y>=2.5)
	_title(ui,"Denah sekolah","SMA Nusa Bangsa  /  Gedung utama dan halaman")
	ui.box(Vector2(62,211),Vector2(790,397),SHEET)
	# Plan grid follows the eight-metre classroom bays.
	for i in range(-3,4):
		ui.box(Vector2(456+i*128,211),Vector2(1,397),Color("#324238"))
	for i in 8:
		ui.box(Vector2(62,231+i*48),Vector2(790,1),Color("#324238"))
	ui.box(Vector2(134,313),Vector2(645,36),Color("#4a5c51"))
	ui.box(Vector2(405,349),Vector2(101,82),Color("#526457"))
	for i in 9:
		ui.box(Vector2(411,350+i*9),Vector2(36,1),JADE)
	for key in plan:
		var p:Vector3 = plan[key]
		if int(p.y>=2.5)!=level:
			continue
		var pos := _point(p)
		var highlight:bool = key==room
		var outside:bool = absf(p.z)>11.5
		var bounds := Vector2(121,64) if not outside else Vector2(135,41)
		var corner := pos-bounds/2
		ui.box(corner,bounds,AMBER if highlight else RULE)
		ui.box(corner+Vector2.ONE,bounds-Vector2(2,2),Color("#4e4a35") if highlight else FIELD)
		var name_text: String = game.PLACES.get(key,game.world.LABELS.get(key,str(key)))
		var text:Label = ui.label(name_text,corner+Vector2(3,0),bounds-Vector2(6,0),14,UI.BOLD,AMBER if highlight else UI.PAPER,true)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.label("Tangga",Vector2(445,354),Vector2(62,48),12,UI.BOLD)
	if player_level==level:
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([Vector2(0,-10),Vector2(7,8),Vector2(0,5),Vector2(-7,8)])
		marker.color = JADE
		ui.add_child(marker)
		marker.position = _point(player_pos)
		marker.rotation = -game.player.rotation.y
	ui.label("LANTAI",Vector2(886,220),Vector2(276,24),14,UI.BOLD,UI.MUTED)
	for i in 2:
		var b: Button = ui.button(str(i+1),Vector2(887+i*82,258),Vector2(71,47),_floor.bind(game,i),level==i)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_key(b,KEY_1 if i==0 else KEY_2)
	ui.box(Vector2(887,335),Vector2(12,12),JADE)
	ui.label("Kamu  ·  lantai %d" % (player_level+1),Vector2(911,323),Vector2(270,36),16,UI.SANS)
	ui.box(Vector2(887,382),Vector2(12,12),AMBER)
	if plan.has(room):
		ui.label("Tujuan  ·  lantai %d" % (1+int(plan[room].y>=2.5)),Vector2(911,370),Vector2(273,36),16,UI.SANS)
		ui.label(game.PLACES.get(room,room),Vector2(885,431),Vector2(312,63),25,UI.SERIF,AMBER,true)
		ui.label(objective.get("description",""),Vector2(887,508),Vector2(299,87),17,UI.SANS,UI.PAPER,true)

func _floor(game,index:int) -> void:
	level = index
	_draw(game)
