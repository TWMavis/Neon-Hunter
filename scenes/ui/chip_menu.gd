class_name ChipMenu
extends Control
## 樓層中的晶片頁面：長按 Tab 打開（避免誤觸），每次打開消耗 10% 電量上限的電量。
## 打開時遊戲暫停；按 Tab、Esc 或「關閉」回到遊戲。

signal closed

const COST_RATIO := 0.1

var _chips: ChipPanel
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	_title = UiTheme.label("", UiTheme.MAGENTA, 12)
	root.add_child(_title)
	_chips = ChipPanel.new()
	_chips.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_chips)
	var close := Button.new()
	close.text = "關閉（Tab / Esc）"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(160, 20)
	close.pressed.connect(close_menu)
	root.add_child(close)


## 電量夠就扣電並打開，回傳是否打開
func open_menu() -> bool:
	var cost := RunState.max_energy * COST_RATIO
	if RunState.energy <= cost:
		return false  # 電量不足：避免調晶片直接把自己弄死
	RunState.add_energy(-cost)
	_title.text = "晶片調整（消耗 %d 電量，剩 %d）　遊戲暫停中" % [roundi(cost), roundi(RunState.energy)]
	_chips.refresh()
	visible = true
	return true


func close_menu() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("chip_menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
