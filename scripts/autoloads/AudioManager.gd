extends Node
## AudioManager — Autoload
## Pool de reproductores de SFX, música por escena y control de volumen.
## En el MVP no hay assets de audio: la API es segura (no-op si falta el stream)
## para que el resto del código pueda llamar a play_sfx/play_music sin romperse.
## Autor: Claude Code · Versión: 0.4.0

const SFX_POOL_SIZE := 12

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0

var _sfx_cache := {}   # name -> AudioStream
var _music_cache := {} # name -> AudioStream

var music_volume := 0.8
var sfx_volume := 0.9
var current_music := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = linear_to_db(music_volume)
	add_child(_music_player)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = linear_to_db(sfx_volume)
		add_child(p)
		_sfx_players.append(p)

func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

func play_sfx(sfx_name: String) -> void:
	if not _sfx_cache.has(sfx_name):
		_sfx_cache[sfx_name] = _try_load("res://assets/audio/sfx/%s.wav" % sfx_name)
	var stream: AudioStream = _sfx_cache[sfx_name]
	if stream == null:
		return
	var p := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	p.stream = stream
	p.volume_db = linear_to_db(sfx_volume)
	p.play()

func play_music(music_name: String) -> void:
	if current_music == music_name:
		return
	current_music = music_name
	if not _music_cache.has(music_name):
		_music_cache[music_name] = _try_load("res://assets/audio/music/%s.ogg" % music_name)
	var stream: AudioStream = _music_cache[music_name]
	_music_player.stop()
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.play()

func stop_music() -> void:
	current_music = ""
	_music_player.stop()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_music_player.volume_db = linear_to_db(maxf(music_volume, 0.0001))

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
