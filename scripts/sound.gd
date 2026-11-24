extends Node
## Original stereo stems; crossfades only the layers that change at each location.

const BASE := "res://assets/audio/"
const MIX := {
	"menu": ["main_menu_theme", "rain_heavy_loop"],
	"prologue": ["prologue_theme", "outdoor_night"],
	"explore": ["exploration_ambient", "school_room_tone"],
	"power": ["tension_theme", "generator_loop"],
	"library": ["mystery_theme", "library_ambience"],
	"archive": ["tension_theme", "archive_ambience"],
	"chase": ["chase_theme", "fluorescent_hum"],
	"final": ["final_escape_theme", "rain_heavy_loop"],
	"good": ["good_ending_theme", "rain_light_loop"],
	"neutral": ["neutral_ending_theme", "outdoor_night"],
	"bad": ["bad_ending_theme", "distant_whispers"],
}
const CHAPTER_MODE := ["prologue", "explore", "power", "library", "archive", "final"]
const FOLEY := {
	"pickup":"item_pickup", "item":"item_pickup", "key":"key_pickup",
	"click":"switch_toggle", "ui":"switch_toggle", "radio":"radio_static",
	"light":"flashlight_click", "paper":"paper_turn", "battery":"battery_change",
	"bell":"school_bell", "ring":"school_bell", "blackout":"switch_toggle",
	"rain":"distant_thunder", "knock":"distant_knock", "whisper":"distant_whispers",
	"power":"generator_start", "chase":"guardian_detect", "caught":"jumpscare_02",
	"catch":"jumpscare_02", "scare":"jumpscare_01", "door":"door_open",
	"success":"puzzle_success", "failure":"puzzle_failure", "alarm":"puzzle_failure",
	"puzzle":"puzzle_success", "ending":"school_bell", "chapter":"school_bell",
	"save":"key_pickup", "heartbeat":"heartbeat_fast", "note":"paper_turn",
}
const BUS_GAIN := {"Music":-5.0, "Ambience":-7.0, "SFX":-1.0, "Dialogue":0.0, "UI":-5.0}
var _music: AudioStreamPlayer
var _air: AudioStreamPlayer
var _mode := ""
var _sfx: Array[AudioStreamPlayer] = []
var _index := 0
var _initialized := false

func setup() -> void:
	if _initialized:
		return
	_initialized = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in BUS_GAIN:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
			AudioServer.set_bus_volume_db(idx, BUS_GAIN[bus_name])
	for i in 8:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_sfx.append(voice)

func set_volume(value: float) -> void:
	set_bus_volume("Master", value)

func set_bus_volume(bus_name: String, value: float) -> void:
	setup()
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, value <= 0.001)
	var trim := float(BUS_GAIN.get(bus_name, 0.0))
	AudioServer.set_bus_volume_db(idx, trim + linear_to_db(clampf(value, 0.001, 1.0)))

func ambience(mode: String) -> void:
	setup()
	var scene_mode := mode.to_lower()
	if scene_mode.is_valid_int():
		scene_mode = CHAPTER_MODE[clampi(int(scene_mode), 0, 5)]
	if not MIX.has(scene_mode):
		scene_mode = "explore"
	if _mode == scene_mode:
		return
	var stems: Array = MIX[scene_mode]
	_music = _crossfade(_music, BASE + "music/" + stems[0] + ".ogg", "Music", -5.0)
	_air = _crossfade(_air, BASE + "ambience/" + stems[1] + ".ogg", "Ambience", -5.0)
	_mode = scene_mode

func _crossfade(previous: AudioStreamPlayer, path: String, bus_name: String, gain: float) -> AudioStreamPlayer:
	var stream := load(path) as AudioStreamOggVorbis
	if previous and previous.get_meta("track", "") == path:
		return previous
	if previous:
		var outgoing := create_tween()
		outgoing.tween_property(previous, "volume_db", -60.0, 0.6)
		outgoing.tween_callback(previous.queue_free)
	if not stream:
		return null
	# Duplicate so single-use playback of the same recorded weather remains finite.
	var loop_stream := stream.duplicate() as AudioStreamOggVorbis
	loop_stream.loop = true
	var layer := AudioStreamPlayer.new()
	layer.name = bus_name
	layer.stream = loop_stream
	layer.set_meta("track", path)
	layer.bus = bus_name
	layer.volume_db = -54.0
	add_child(layer)
	layer.play()
	create_tween().tween_property(layer, "volume_db", gain, 1.3)
	return layer

func play(id: String) -> void:
	setup()
	if id.is_empty():
		return
	var stem := str(FOLEY.get(id, id))
	var clip := _clip(stem)
	if not clip:
		return
	var voice: AudioStreamPlayer = _sfx[_index]
	_index = (_index + 1) % _sfx.size()
	voice.stop()
	voice.stream = clip
	voice.bus = &"UI" if id in ["click", "ui"] else &"SFX"
	voice.volume_db = -3.0
	voice.play()

func play_at(id: String, at: Vector3) -> void:
	setup()
	var clip := _clip(str(FOLEY.get(id, id)))
	if not clip:
		return
	var source := AudioStreamPlayer3D.new()
	source.stream = clip
	source.bus = &"SFX"
	source.unit_size = 2.6
	source.max_distance = 26.0
	source.attenuation_filter_cutoff_hz = 6400.0
	add_child(source)
	source.global_position = at
	source.finished.connect(source.queue_free)
	source.play()

func _clip(stem: String) -> AudioStream:
	for category in ["effects", "ambience", "footsteps"]:
		var path := BASE + str(category) + "/" + stem + ".ogg"
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null
