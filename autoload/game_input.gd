extends Node
## 輸入設定：鍵盤滑鼠與手把。啟動時註冊預設按鍵，再套用玩家在設定畫面改過的按鍵（Settings）。
## 鍵盤：WASD 移動、空白鍵跳、Shift 衝刺、滑鼠瞄準與攻擊、長按 Tab 晶片頁面、長按 F 搭電梯
## 手把：左搖桿移動、右搖桿瞄準、A 跳、RB 衝刺、RT／LT（或 LB）左右鍵攻擊、長按 X 搭電梯、長按 Back 晶片頁面、Start 重新開始

const DEADZONE := 0.25

## 最後一次是用手把操作（決定瞄準來源與準心位置）
var using_gamepad := false


func _ready() -> void:
	register_defaults()
	Settings.load_and_apply()


func register_defaults() -> void:
	_bind(&"move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind(&"move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind(&"move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind(&"move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind(&"jump", [KEY_SPACE], [JOY_BUTTON_A], [])
	_bind(&"dash", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B], [])
	_bind(&"restart", [KEY_R], [JOY_BUTTON_START], [])
	_bind(&"chip_menu", [KEY_TAB], [JOY_BUTTON_BACK], [])
	_bind(&"interact", [KEY_F], [JOY_BUTTON_X], [])
	_bind(&"attack_primary", [], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind(&"attack_secondary", [], [JOY_BUTTON_LEFT_SHOULDER], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add_mouse(&"attack_primary", MOUSE_BUTTON_LEFT)
	_add_mouse(&"attack_secondary", MOUSE_BUTTON_RIGHT)
	_bind(&"aim_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind(&"aim_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_bind(&"aim_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_bind(&"aim_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		using_gamepad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4:
		using_gamepad = true
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		using_gamepad = false
	elif event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false


## 手把右搖桿的瞄準方向；沒推就回傳 Vector2.ZERO
func gamepad_aim() -> Vector2:
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", DEADZONE)
	return stick.normalized() if stick.length() > 0.3 else Vector2.ZERO


## 重設一個動作的所有對應（鍵盤、手把按鈕、手把搖桿）
func _bind(action: StringName, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, DEADZONE)
	InputMap.action_set_deadzone(action, DEADZONE)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button: JoyButton in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
	for pair: Array in axes:
		var event := InputEventJoypadMotion.new()
		event.axis = pair[0]
		event.axis_value = pair[1]
		InputMap.action_add_event(action, event)


func _add_mouse(action: StringName, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
