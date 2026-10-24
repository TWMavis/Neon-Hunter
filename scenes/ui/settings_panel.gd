class_name SettingsPanel
extends Control
## 設定畫面：主音量／音樂／音效滑桿、鍵盤改鍵、手把按鍵說明。改了就存到 user://settings.cfg。
## 起始畫面、電梯、遊戲中（Esc）都可以打開。

signal closed

const GAMEPAD_HELP := "手把：左搖桿移動、右搖桿瞄準、A 跳躍、RB 衝刺、按住 LB 潛行、RT／LT 左右鍵攻擊、長按 X 搭電梯、長按 Back 晶片頁面、Start 重新開始"

var _sliders: Dictionary = {}       # bus -> HSlider
var _key_buttons: Dictionary = {}   # action -> Button
var _waiting_for: StringName = &""  # 正在等玩家按新鍵的動作
var _close_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 4)
	scroll.add_child(root)

	root.add_child(UiTheme.label("設定", UiTheme.MAGENTA, 14))
	root.add_child(UiTheme.label("音量", UiTheme.CYAN, 11))
	for bus: String in Settings.BUSES:
		root.add_child(_volume_row(bus))

	root.add_child(UiTheme.label("鍵盤按鍵（點按鈕後按下新的鍵，Esc 取消）", UiTheme.CYAN, 11))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	root.add_child(grid)
	for action: StringName in Settings.REBINDABLE:
		grid.add_child(UiTheme.label(Settings.REBINDABLE[action], UiTheme.WHITE, 10))
		var button := Button.new()
		button.custom_minimum_size = Vector2(80, 0)
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_start_rebind.bind(action))
		grid.add_child(button)
		_key_buttons[action] = button

	var help := UiTheme.label(GAMEPAD_HELP, UiTheme.DIM, 9)
	help.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	root.add_child(help)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	var reset := Button.new()
	reset.text = "恢復預設"
	reset.pressed.connect(_on_reset)
	row.add_child(reset)
	var close := Button.new()
	close.text = "關閉"
	close.custom_minimum_size = Vector2(100, 0)
	close.pressed.connect(close_panel)
	row.add_child(close)
	_close_button = close


func open() -> void:
	_refresh()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_close_button.grab_focus.call_deferred()


func close_panel() -> void:
	if not visible:
		return
	_waiting_for = &""
	visible = false
	Audio.sfx("ui_click")
	closed.emit()


func _volume_row(bus: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var names := {"Master": "主音量", "Music": "音樂", "SFX": "音效"}
	var label := UiTheme.label(names[bus], UiTheme.WHITE, 10)
	label.custom_minimum_size.x = 60
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(180, 16)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var percent := UiTheme.label("", UiTheme.DIM, 10)
	percent.custom_minimum_size.x = 40
	row.add_child(percent)
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_volume(bus, v)
		percent.text = "%d%%" % roundi(v * 100.0)
		if bus == "SFX":
			Audio.sfx("pickup_xp", 0.0, 0.0, 0.15))   # 試聽音效音量
	_sliders[bus] = slider
	return row


func _refresh() -> void:
	for bus: String in _sliders:
		(_sliders[bus] as HSlider).set_value_no_signal(Settings.volumes[bus])
		var percent := (_sliders[bus] as HSlider).get_parent().get_child(2) as Label
		percent.text = "%d%%" % roundi(float(Settings.volumes[bus]) * 100.0)
	for action: StringName in _key_buttons:
		(_key_buttons[action] as Button).text = "按下新的鍵…" if action == _waiting_for else Settings.key_name(action)


func _start_rebind(action: StringName) -> void:
	_waiting_for = action
	_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if _waiting_for != &"" and key and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		if key.physical_keycode != KEY_ESCAPE:
			Settings.set_key(_waiting_for, key.physical_keycode)
			Audio.sfx("ui_click")
		_waiting_for = &""
		_refresh()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func _on_reset() -> void:
	Settings.reset_defaults()
	_refresh()
