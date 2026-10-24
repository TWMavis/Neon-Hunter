class_name Settings
extends RefCounted
## 玩家設定：音量（主音量／音樂／音效三條匯流排）與鍵盤按鍵，存在 user://settings.cfg。
## 遊戲啟動時由 GameInput 呼叫 load_and_apply()。

const PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX"]
const DEFAULT_VOLUME := {"Master": 0.8, "Music": 0.7, "SFX": 0.8}

## 可以在設定畫面改鍵的動作（滑鼠攻擊、手把不在這裡改）
const REBINDABLE := {
	&"move_left": "左移", &"move_right": "右移", &"move_up": "上", &"move_down": "下／從平台下跳",
	&"jump": "跳躍", &"dash": "衝刺", &"stealth": "潛行（按住）", &"interact": "搭電梯（按住）", &"chip_menu": "晶片頁面（按住）",
}

static var volumes: Dictionary = DEFAULT_VOLUME.duplicate()
static var keys: Dictionary = {}          # 動作 -> 實體按鍵碼（只記錄改過的）


static func load_and_apply() -> void:
	_ensure_buses()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for bus: String in BUSES:
			volumes[bus] = clampf(float(cfg.get_value("audio", bus, DEFAULT_VOLUME[bus])), 0.0, 1.0)
		for action: StringName in REBINDABLE:
			var code: int = cfg.get_value("keys", String(action), 0)
			if code != 0:
				keys[action] = code
	for bus: String in BUSES:
		set_volume(bus, volumes[bus], false)
	for action: StringName in keys:
		set_key(action, keys[action], false)


static func save() -> void:
	var cfg := ConfigFile.new()
	for bus: String in BUSES:
		cfg.set_value("audio", bus, volumes[bus])
	for action: StringName in keys:
		cfg.set_value("keys", String(action), keys[action])
	cfg.save(PATH)


## linear：0～1
static func set_volume(bus: String, linear: float, store := true) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)))
		AudioServer.set_bus_mute(index, volumes[bus] <= 0.001)
	if store:
		save()


## 把動作的鍵盤按鍵換成 physical_keycode（滑鼠、手把的對應不受影響）
static func set_key(action: StringName, physical_keycode: int, store := true) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, key)
	keys[action] = physical_keycode
	if store:
		save()


## 動作目前的鍵盤按鍵名稱（例如「Shift」）
static func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "-"
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			names.append(OS.get_keycode_string((event as InputEventKey).physical_keycode))
	return " / ".join(names) if not names.is_empty() else "-"


static func reset_defaults() -> void:
	volumes = DEFAULT_VOLUME.duplicate()
	keys.clear()
	var game_input := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameInput")
	if game_input:
		game_input.call("register_defaults")
	for bus: String in BUSES:
		set_volume(bus, volumes[bus], false)
	save()


## 萬一 default_bus_layout.tres 沒載入，補上 Music、SFX 匯流排
static func _ensure_buses() -> void:
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
