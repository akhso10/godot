extends RefCounted
## Progresses only the active objective. The view owns presentation and the file system.
signal progressed(objective_id: String)
signal item_acquired(item_id: String)

const Campaign := preload("res://data/campaign.gd")
const MAIN_EVIDENCE := [
	"fire_report", "witness_statement_01", "witness_statement_02",
	"witness_statement_03", "original_photo", "cassette_tape"
]
const SECRETS: Array[Dictionary] = [
	{"id":"water_bottle", "chapter":1, "room":"canteen", "label":"Periksa botol penyok",
		"description":"Ada yang tertinggal di kantin.", "item":"water_bottle",
		"text":"Inisial A digores di tutup botol. Akbar pasti sempat lewat sini. Kamu menyimpan botol itu supaya bisa mengembalikannya nanti."},
	{"id":"old_newspaper", "chapter":3, "room":"principal", "label":"Balik guntingan koran",
		"description":"Edisi lama koran lokal.", "item":"old_newspaper",
		"text":"KORAN DAERAH • 18 AGUSTUS 2008\n“Kegiatan belajar kembali normal.” Foto pada berita ini dipotong tepat di jendela ruang arsip. Pada sisi belakang ada coretan: “Normal untuk siapa?”"},
	{"id":"black_notebook", "chapter":4, "room":"library", "label":"Buka buku bersampul hitam",
		"description":"Sebuah catatan terselip di rak.", "item":"black_notebook",
		"text":"“Kalau mereka lupa muka saya, mungkin masih ada yang ingat tulisan tangan saya.” Laras menggambar antena radio kecil di akhir halaman."},
	{"id":"find_backpack","chapter":0,"room":"class","label":"Periksa tas di bawah meja",
		"description":"Tas tua tertinggal sejak sore.","item":"backpack",
		"text":"Pada label bagasi tertulis dua nomor telepon rumah. Raka mengenali salah satunya: nomor rumahnya sebelum ia lahir."},
	{"id":"find_locker_key","chapter":1,"room":"teachers","label":"Ambil kunci loker 07",
		"description":"Periksa baki kunci yang tergantung miring.","item":"locker_key",
		"text":"Kunci nomor tujuh masih dibungkus kertas bertanggal 2008. Bukan kunci loker kombinasi, tapi geriginya baru saja dipakai."},
	{"id":"find_padlock","chapter":1,"room":"toilet","label":"Periksa gembok yang terbuka",
		"description":"Dari pintu bilik paling ujung terdengar tetesan air.","item":"padlock",
		"text":"Gembok ini digergaji dari dalam. Raka membungkusnya dengan tisu; di cermin, pantulan tangannya terlambat bergerak."},
	{"id":"find_smartphone_reski","chapter":2,"room":"lab","label":"Ambil ponsel bercasing hijau",
		"description":"Sebuah layar menyala di bawah meja komputer.","item":"smartphone_reski",
		"text":"Pesan terakhir Reski belum terkirim: “Rak, kalau ada yang nyuruh masuk lewat speaker, tanya dulu nomor absen gue.”"},
	{"id":"find_master_key","chapter":2,"room":"security","label":"Cari kunci induk lama",
		"description":"Ada gantungan kosong di antara kunci gerbang dan gudang.","item":"master_key",
		"text":"Kepala kunci dicap satu bintang. Di balik papan kunci tertulis: “Kunci induk dicabut setelah penggantian silinder, 19 Agustus.”"},
	{"id":"find_smartphone_akbar","chapter":3,"room":"bk","label":"Periksa ponsel yang bergetar",
		"description":"Ada dengung singkat di dekat kursi tamu.","item":"smartphone_akbar",
		"text":"Pemutar pesan suara Akbar terbuka. Sebelum suara Raka memanggil namanya, terdengar klik kaset dibalik."},
	{"id":"find_medicine_box","chapter":3,"room":"clinic","label":"Buka kotak plester",
		"description":"Sudut kotak P3K tertahan selapis perban tua.","item":"medicine_box",
		"text":"Di balik daftar persediaan ada catatan petugas UKS. “Satu murid belum dijemput.” Tidak ada nama di bawahnya."},
	{"id":"find_archive_key","chapter":4,"room":"principal","label":"Periksa amplop kepala sekolah",
		"description":"Ada bayangan berbentuk kunci di balik amplop.","item":"archive_key",
		"text":"Kunci arsip lama dilampiri dua tanda terima dengan sidik jari sama. Orang yang menyerahkan dan menerimanya memakai nama berbeda."},
	{"id":"find_voice_recorder","chapter":4,"room":"documentation","label":"Periksa perekam saku",
		"description":"Sebuah perekam tua terbungkus kain penyerap lembap.","item":"voice_recorder",
		"text":"Log rekaman berhenti pada 23.46. Pada detik terakhir Laras berbisik, “Saya mau mereka dengar suara saya sendiri.”"},
	{"id":"find_emergency_gate_key","chapter":5,"room":"safe","label":"Simpan kunci gerbang cadangan",
		"description":"Ada segel lilin yang sudah patah di bawah bangku.","item":"emergency_gate_key",
		"text":"Raka menyimpan kunci cadangan untuk petugas pagi. Palang dari dalam tetap harus dilepas melalui tuas."},
	{"id":"find_microphone","chapter":5,"room":"hall","label":"Periksa mikrofon panggung",
		"description":"Mikrofon panggung mengarah ke deretan kursi kosong.","item":"microphone",
		"text":"Kabelnya dipotong, tetapi saat Raka mengangkat mikrofon seseorang di belakang panggung pelan-pelan bertepuk tangan."},
	{"id":"find_emergency_lever","chapter":5,"room":"storage","label":"Ambil gagang tuas yang patah",
		"description":"Sebuah gagang merah terselip di antara alat kebun.","item":"emergency_lever",
		"text":"Ini gagang dari palang gerbang lama, dilepas sesudah kebakaran. Bekas kuku di catnya berada di sisi yang menghadap halaman."}
]
var chapters := [
	"Pukul 23.47", "Bel yang Tidak Berhenti", "Listrik Padam",
	"Nama yang Dihapus", "Arsip Terlarang", "Bel Terakhir"
]
var chapter: int = 0
var completed: int = 0
var inventory: Array = ["smartphone_raka"]
var journal: Array = []
var evidence: Array = []
var rescued: Array = []
var ending: String = ""
var broadcast: bool = false
var _cursor: int = 0
var _chosen_cards: Array = []
var _attempts: int = 0
var _route: Array = []
var _pending: String = ""
var _found_secrets: Array = []

func objective() -> Dictionary:
	if _cursor >= Campaign.MISSIONS.size():
		return {}
	return Campaign.MISSIONS[_cursor]

func extras() -> Array:
	var available := []
	if ending.is_empty():
		for entry in SECRETS:
			if chapter == entry.chapter and entry.id not in _found_secrets:
				available.append(entry)
	return available

func interact(id: String) -> Dictionary:
	for entry in extras():
		if id == entry.id:
			_found_secrets.append(id)
			_collect(entry.item)
			journal.append(entry.text)
			progressed.emit(id)
			return {"text":entry.text, "checkpoint":true}
	var quest := objective()
	if quest.is_empty() or quest.id != id:
		return {"text":"Belum ada yang bisa diperiksa di sini."}
	if quest.has("decision") or quest.has("p"):
		_pending = id
		return _menu(quest)
	return _finish(quest)

func _menu(quest: Dictionary) -> Dictionary:
	if quest.has("decision"):
		var prompt: String = quest.text
		match quest.id:
			"broadcast": prompt = "Kaset Laras siap diputar. Jika kamu memilih jalur darurat, malam ini sekolah hanya mendengar bunyi bel."
			"plan_escape": prompt = "Reski di ruang listrik. Akbar di UKS. Siapa yang kamu jemput sebelum menuju gerbang?"
		return {"text":prompt, "choices":quest.decision.duplicate()}
	var p: Dictionary = quest.p
	var selected := PackedStringArray()
	var options := []
	for card in _chosen_cards:
		selected.append(p.cards[card])
	for i in range(p.cards.size()):
		if i not in _chosen_cards:
			options.append(p.cards[i])
	var prompt := str(p.question)
	if not selected.is_empty():
		prompt += "\n\nTerpasang: " + "  →  ".join(selected)
	if _attempts > 0:
		prompt += "\n\n" + str(p.hints[mini(_attempts - 1, p.hints.size() - 1)])
	return {"text":prompt, "choices":options}

func choose(index: int) -> Dictionary:
	var quest := objective()
	if quest.is_empty() or quest.id != _pending:
		return {"text":"Periksa dulu benda yang ingin digunakan."}
	if index < 0:
		return _menu(quest)
	if quest.has("decision"):
		if index >= quest.decision.size():
			return _menu(quest)
		match quest.id:
			"broadcast":
				broadcast = index == 0
			"plan_escape":
				_route = [["reski", "akbar"], ["reski"], ["akbar"], []][index].duplicate()
				rescued.clear()
		return _finish(quest, index > 0)
	var p: Dictionary = quest.p
	var remaining := []
	for i in range(p.cards.size()):
		if i not in _chosen_cards:
			remaining.append(i)
	if index >= remaining.size():
		return _menu(quest)
	var card: int = remaining[index]
	if card != int(p.order[_chosen_cards.size()]):
		_chosen_cards.clear()
		_attempts += 1
		var result := _menu(quest)
		result.text = "Urutannya belum cocok. Coba lagi.\n\n" + str(result.text)
		if p.get("alarm", false):
			result.text = "Alarm panel berbunyi! Menjauhlah jika terdengar langkah di lorong.\n\n" + str(result.text)
			result.alarm = true
		return result
	_chosen_cards.append(card)
	if _chosen_cards.size() < p.order.size():
		return _menu(quest)
	return _finish(quest)

func _collect(item: String) -> void:
	if item not in inventory:
		inventory.append(item)
		item_acquired.emit(item)

func _finish(quest: Dictionary, alternate := false) -> Dictionary:
	var text: String = quest.get("skip_text", quest.text) if alternate else quest.text
	var result := {"text":text, "checkpoint":true}
	if quest.has("effect"):
		result.effect = quest.effect
	if quest.has("item") and not alternate:
		_collect(quest.item)
		if quest.get("proof", false):
			evidence.append(quest.item)
	if quest.has("rescue"):
		rescued.append(quest.rescue)
		result.rescued = quest.rescue
	if quest.id.begins_with("evac_"):
		var name_id: String = quest.id.trim_prefix("evac_")
		rescued.append(name_id)
		result.rescued = name_id
	if quest.id == "escape":
		if rescued.size() < 2:
			ending = "bad"
			text = "ABSENSI TERAKHIR\nBesok pagi Raka menemukan namanya sendiri pada foto kelas lama. Di sampingnya, wajah teman yang tertinggal. Ponselnya menyala: “Rak… jangan lupa jemput kita.”"
		elif broadcast and evidence.size() == MAIN_EVIDENCE.size():
			ending = "good"
			text = "BEL PULANG\nMatahari muncul di balik genting. Laras berdiri di jendela arsip. Jarum jam bergerak satu menit, dan ia sudah pergi.\nRAKA  /  Akhirnya… kita bisa pulang."
		else:
			ending = "neutral"
			text = "RAHASIA YANG TERTINGGAL\nKalian bertiga menyeberang jalan bersama. Saat gerbang hilang di balik tikungan, bel berbunyi lagi. Reski mengecek jamnya. Masih 00.00."
		result.ending = ending
		result.text = text
	journal.append(text)
	completed += 1
	_cursor += 1
	while _cursor < Campaign.MISSIONS.size():
		var next: Dictionary = Campaign.MISSIONS[_cursor]
		if next.id.begins_with("evac_") and next.id.trim_prefix("evac_") not in _route:
			_cursor += 1
			continue
		chapter = next.chapter
		break
	_chosen_cards.clear()
	_attempts = 0
	_pending = ""
	progressed.emit(quest.id)
	return result

func save_data() -> Dictionary:
	return {
		"version":1, "cursor":_cursor, "completed":completed, "inventory":inventory.duplicate(),
		"journal":journal.duplicate(), "evidence":evidence.duplicate(), "rescued":rescued.duplicate(),
		"secrets":_found_secrets.duplicate(), "route":_route.duplicate(), "broadcast":broadcast,
		"cards":_chosen_cards.duplicate(), "attempts":_attempts, "ending":ending, "chapter":chapter
	}

## Validate first so a malformed primary save can be retried from the previous checkpoint.
func restore(data: Dictionary) -> bool:
	if data.get("version", 0) != 1:
		return false
	for key in ["cursor","completed","attempts"]:
		if typeof(data.get(key)) not in [TYPE_FLOAT,TYPE_INT] or float(data[key]) != floorf(data[key]):
			return false
	var cursor := int(data.cursor)
	if cursor < 0 or cursor > Campaign.MISSIONS.size() or int(data.completed) < 0 or int(data.completed) > cursor:
		return false
	for key in ["inventory","journal","evidence","rescued","secrets","route"]:
		if typeof(data.get(key)) != TYPE_ARRAY:
			return false
		for s in data[key]:
			if typeof(s) != TYPE_STRING:
				return false
	if typeof(data.get("cards")) != TYPE_ARRAY or typeof(data.get("broadcast")) != TYPE_BOOL:
		return false
	var saved_ending: Variant = data.get("ending")
	if saved_ending not in ["", "bad", "neutral", "good"] or (cursor == Campaign.MISSIONS.size()) != (saved_ending != ""):
		return false
	for key in ["rescued","route"]:
		var seen := []
		for s in data[key]:
			if s not in ["reski","akbar"] or s in seen:
				return false
			seen.append(s)
	var proof_ids := []
	for s in data.evidence:
		if s not in MAIN_EVIDENCE or s in proof_ids or s not in data.inventory:
			return false
		proof_ids.append(s)
	var cards := []
	if not data.cards.is_empty():
		if cursor >= Campaign.MISSIONS.size() or not Campaign.MISSIONS[cursor].has("p"):
			return false
		var sequence: Array = Campaign.MISSIONS[cursor].p.order
		if data.cards.size() >= sequence.size():
			return false
		for i in range(data.cards.size()):
			if data.cards[i] != sequence[i]:
				return false
			cards.append(int(data.cards[i]))
	_cursor = cursor
	chapter = Campaign.MISSIONS[mini(cursor,Campaign.MISSIONS.size()-1)].chapter
	completed = int(data.completed)
	inventory = data.inventory.duplicate()
	journal = data.journal.duplicate()
	evidence = data.evidence.duplicate()
	rescued = data.rescued.duplicate()
	_found_secrets = data.secrets.duplicate()
	_route = data.route.duplicate()
	broadcast = data.broadcast
	ending = saved_ending
	_attempts = maxi(0,int(data.attempts))
	_chosen_cards = cards
	_pending = ""
	return true
