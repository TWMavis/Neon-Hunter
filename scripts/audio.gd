class_name Audio
extends Node
## 音效與音樂。不需要自動載入：第一次呼叫時自己建立節點掛在場景樹根部，換場景也不會中斷。
##   Audio.sfx("shoot")         播放音效（audio/shoot.wav）
##   Audio.music("music_hunt")  切換背景音樂（循環播放）
## 音檔由 tools/generate_assets.gd 合成。

const POOL_SIZE := 16
const SFX_DB := -8.0
const MUSIC_DB := -14.0

static var _instance: Audio

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_name := ""
var _pending: Array = []


static func sfx(name: String, volume_db := 0.0, pitch_jitter := 0.06, min_gap := 0.03) -> void:
	var a := _shared()
	if a:
		a._play_sfx(name, volume_db, pitch_jitter, min_gap)


static func music(name: String) -> void:
	var a := _shared()
	if a:
		a._play_music(name)


## 音樂速度（清除協議時加快）
static func music_pitch(pitch: float) -> void:
	var a := _shared()
	if a and a._music_player:
		a._music_player.pitch_scale = pitch


static func _shared() -> Audio:
	if is_instance_valid(_instance):
		return _instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_instance = Audio.new()
	_instance.name = "Audio"
	_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_instance)   # 場景初始化時根節點忙碌，延後加入
	return _instance


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_DB
	add_child(_music_player)
	for pending_call: Callable in _pending:
		pending_call.call()
	_pending.clear()


func _play_sfx(name: String, volume_db: float, pitch_jitter: float, min_gap: float) -> void:
	if not is_inside_tree():
		_pending.append(_play_sfx.bind(name, volume_db, pitch_jitter, min_gap))
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(name, -10.0)) < min_gap:
		return
	_last_played[name] = now
	var stream := _stream(name)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = SFX_DB + volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _play_music(name: String) -> void:
	if not is_inside_tree():
		_pending.append(_play_music.bind(name))
		return
	_music_player.pitch_scale = 1.0
	if name == _music_name and _music_player.playing:
		return
	_music_name = name
	var stream := _stream(name)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_music_player.stream = stream
	_music_player.play()


func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := "res://audio/%s.wav" % name
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
	_streams[name] = stream
	return stream
