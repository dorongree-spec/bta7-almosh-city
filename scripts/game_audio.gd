## All sound in one place: the engine note (synthesised, pitched by speed),
## crashes, punches, the horn and the car radio. Samples are CC0 packs listed
## in assets/CREDITS.md; anything missing is skipped silently so the game
## never depends on an audio file being present.
class_name GameAudio
extends Node

const SFX := "res://assets/audio/sfx/"
const RADIO := "res://assets/audio/radio/"
const MIX_RATE := 22050

var _engine := AudioStreamPlayer.new()
var _horn := AudioStreamPlayer.new()
var _radio := AudioStreamPlayer.new()
var _oneshots: Array[AudioStreamPlayer] = []
var _next_oneshot := 0
var _crashes: Array[AudioStream] = []
var _punches: Array[AudioStream] = []
var _whoosh: AudioStream
## The player's own music: any .mp3 or .ogg dropped into a folder called
## "music" next to the game. Nothing in it ships with the game.
const OWN_FOLDER := "music"
const OWN_STATION := {"id": "own", "name": "הדיסק של אבא", "host": "אבא", "bit": "מי נגע לי בדיסק? רק שאלה."}

## Stations come from the "radio" list in data/world.json. Each one names its
## music in "tracks", paths relative to assets/audio/radio/. A station with one
## track loops it; a station with several plays them in turn. Stations whose
## files are all missing are left off the dial, so a station can be written
## before its music arrives.
var _stations: Array = []
var _station := -1  # -1 = radio off
var _station_tracks: Array = []   # per entry of _stations: Array[String] of res:// paths
var _track_next := 0
var _own_tracks: PackedStringArray = []   # full paths, in the order they will play
var _own_next := 0


func _ready() -> void:
	_engine.stream = _engine_loop()
	_engine.volume_db = -60.0
	add_child(_engine)
	_horn.stream = _horn_blast()
	_horn.volume_db = -6.0
	add_child(_horn)
	_radio.volume_db = -9.0
	_radio.finished.connect(_on_track_finished)
	add_child(_radio)
	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_oneshots.append(player)
	_crashes = _load_all(["impactMetal_heavy_000", "impactMetal_heavy_001", "impactMetal_heavy_002", "impactMetal_medium_000", "impactMetal_medium_001"])
	_punches = _load_all(["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_medium_000", "impactPunch_medium_001"])
	var plank := _load_all(["impactPlank_medium_000"])
	_whoosh = plank[0] if not plank.is_empty() else null


func setup(world: Dictionary) -> void:
	_find_own_music()
	if not _own_tracks.is_empty():
		_stations.append(OWN_STATION)     # first on the dial
		_station_tracks.append([])
	for station in world.get("radio", []):
		var tracks := _existing_tracks(station)
		if not tracks.is_empty():
			_stations.append(station)
			_station_tracks.append(tracks)


## The station's "tracks" as res:// paths, without the files that are missing.
static func _existing_tracks(station: Dictionary) -> Array:
	var found := []
	for file in station.get("tracks", []):
		var path := RADIO + String(file)
		if ResourceLoader.exists(path):
			found.append(path)
		else:
			push_warning("Radio station %s: missing track %s" % [station.get("id", "?"), path])
	return found


## Where the player's own music lives: beside the game's .exe, or in the
## project folder when run from the editor.
static func own_music_folder() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").path_join(OWN_FOLDER)
	return OS.get_executable_path().get_base_dir().path_join(OWN_FOLDER)


func _find_own_music() -> void:
	var folder := own_music_folder()
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file in dir.get_files():
		if file.get_extension().to_lower() in ["mp3", "ogg"]:
			_own_tracks.append(folder.path_join(file))
	# A different running order every time the game starts.
	var shuffled := Array(_own_tracks)
	shuffled.shuffle()
	_own_tracks = PackedStringArray(shuffled)


## One of the player's own files as a stream, or null if it will not load.
func _own_stream(path: String) -> AudioStream:
	if path.get_extension().to_lower() == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var mp3 := AudioStreamMP3.new()
	mp3.data = bytes
	return mp3


## Plays the next of the player's own tracks; skips files that will not load.
func _play_own() -> void:
	for attempt in _own_tracks.size():
		var stream := _own_stream(_own_tracks[_own_next])
		_own_next = (_own_next + 1) % _own_tracks.size()
		if stream != null:
			_radio.stream = stream
			_radio.play()
			return
	_radio.stop()


## Plays the current station's next track. A single track loops on its own;
## with several, each plays once and _on_track_finished moves on.
func _play_station_track() -> void:
	var tracks: Array = _station_tracks[_station]
	var path := String(tracks[_track_next % tracks.size()])
	_track_next += 1
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = tracks.size() == 1
	_radio.stream = stream
	_radio.play()


func _on_track_finished() -> void:
	if _station < 0:
		return
	if String(_stations[_station].get("id", "")) == "own":
		_play_own()
	else:
		_play_station_track()


func _load_all(names: Array) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for n in names:
		var path := SFX + String(n) + ".ogg"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				streams.append(stream)
	return streams


func _play(stream: AudioStream, volume_db: float, pitch := 1.0) -> void:
	if stream == null:
		return
	var player := _oneshots[_next_oneshot]
	_next_oneshot = (_next_oneshot + 1) % _oneshots.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


# --- synthesised sounds -----------------------------------------------------------------

func _wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Half a second of a four-cylinder idling: a stack of harmonics of 56 Hz
## (28 whole cycles, so the loop is seamless) with a little firing roughness.
func _engine_loop() -> AudioStreamWAV:
	var count := MIX_RATE / 2
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in count:
		var t := float(i) / MIX_RATE
		var v := 0.0
		for k in range(1, 8):
			v += sin(TAU * 56.0 * k * t + k * 1.7) / (k * (1.0 if k % 2 == 0 else 1.6))
		# Uneven firing: every second cycle is a touch louder.
		v *= 0.8 + 0.2 * sin(TAU * 28.0 * t)
		samples[i] = v * 0.3 + rng.randf_range(-0.02, 0.02)
	return _wav(samples, true)


func _horn_blast() -> AudioStreamWAV:
	var count := int(MIX_RATE * 0.4)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / MIX_RATE
		var fade := minf(1.0, minf(t * 60.0, (0.4 - t) * 30.0))
		var v := signf(sin(TAU * 415.0 * t)) * 0.5 + signf(sin(TAU * 523.0 * t)) * 0.5
		samples[i] = v * 0.35 * fade
	return _wav(samples, false)


# --- game events --------------------------------------------------------------------------

## load_factor: 0 (idle) .. 1 (flat out); throttle: -1..1.
func engine(running: bool, load_factor: float, throttle: float) -> void:
	if not running:
		_engine.volume_db = move_toward(_engine.volume_db, -60.0, 4.0)
		if _engine.volume_db <= -59.0 and _engine.playing:
			_engine.stop()
		return
	if not _engine.playing:
		_engine.play()
	_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.75 + clampf(load_factor, 0.0, 1.2) * 1.7 + absf(throttle) * 0.12, 0.15)
	_engine.volume_db = move_toward(_engine.volume_db, -17.0 + absf(throttle) * 6.0, 3.0)


func crash(impact: float) -> void:
	if _crashes.is_empty():
		return
	_play(_crashes.pick_random(), clampf(-14.0 + impact * 0.9, -14.0, 0.0), randf_range(0.8, 1.1))


func punch(connected: bool) -> void:
	if connected and not _punches.is_empty():
		_play(_punches.pick_random(), -4.0, randf_range(0.9, 1.1))
	else:
		_play(_whoosh, -16.0, 1.6)


func horn() -> void:
	_horn.play()


## Tunes to the next station (or switches off after the last one). Returns
## the station entry from world.json, or an empty Dictionary for "off".
func next_station() -> Dictionary:
	if _stations.is_empty():
		return {}
	_station += 1
	if _station >= _stations.size():
		_station = -1
		_radio.stop()
		return {}
	var station: Dictionary = _stations[_station]
	if String(station.id) == "own":
		_play_own()
	else:
		_track_next = 0
		_play_station_track()
	return station


func radio_off() -> void:
	_station = -1
	_radio.stop()
