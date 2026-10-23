extends Node
## 啟動時註冊輸入動作：WASD 移動、空白鍵跳躍、Shift 衝刺、滑鼠左右鍵攻擊。


func _ready() -> void:
	_add_key(&"move_left", [KEY_A, KEY_LEFT])
	_add_key(&"move_right", [KEY_D, KEY_RIGHT])
	_add_key(&"move_up", [KEY_W, KEY_UP])
	_add_key(&"move_down", [KEY_S, KEY_DOWN])
	_add_key(&"jump", [KEY_SPACE])
	_add_key(&"dash", [KEY_SHIFT])
	_add_key(&"restart", [KEY_R])
	_add_key(&"chip_menu", [KEY_TAB])
	_add_key(&"interact", [KEY_F])
	_add_mouse(&"attack_primary", MOUSE_BUTTON_LEFT)
	_add_mouse(&"attack_secondary", MOUSE_BUTTON_RIGHT)


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _add_key(action: StringName, keys: Array) -> void:
	_ensure(action)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _add_mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
