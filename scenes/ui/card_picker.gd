class_name CardPicker
extends Control
## 三選一卡片：升級、寶箱、黑市共用。用滑鼠點或按 1／2／3 選。

signal picked(card: Dictionary)

var _cards: Array[Dictionary] = []
var _row: HBoxContainer
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)

	_title = UiTheme.label("", UiTheme.YELLOW, 14)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	box.add_child(_row)
	var hint := UiTheme.label("點選或按 1 / 2 / 3", UiTheme.DIM, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func open(title: String, cards: Array[Dictionary]) -> void:
	_cards = cards
	_title.text = title
	for child in _row.get_children():
		child.queue_free()
	for i in cards.size():
		_row.add_child(_make_card(i, cards[i]))
	visible = true
	if _row.get_child_count() > 0:
		(_row.get_child(_row.get_child_count() - cards.size()) as Control).grab_focus.call_deferred()   # 手把用方向鍵選、A 確認


func _make_card(i: int, card: Dictionary) -> Button:
	var info := ClimbState.describe_card(card)
	var button := Button.new()
	button.custom_minimum_size = Vector2(130, 120)
	button.pressed.connect(_choose.bind(i))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(col)

	var accent := UiTheme.CYAN
	if card["type"] == "chip" or card["type"] == "upgrade":
		accent = Catalog.chip(card["id"]).rarity_color()
	elif card["type"] == "weapon":
		accent = UiTheme.YELLOW
	elif card["type"] == "passive":
		accent = UiTheme.GREEN
	col.add_child(UiTheme.label("%d" % (i + 1), UiTheme.DIM, 9))
	var name_label := UiTheme.label(info[0], accent, 13)
	col.add_child(name_label)
	var tag := UiTheme.label(info[1], UiTheme.DIM, 9)
	tag.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	tag.custom_minimum_size.x = 118
	col.add_child(tag)
	var desc := UiTheme.label(info[2], UiTheme.WHITE, 10)
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc.custom_minimum_size.x = 118
	col.add_child(desc)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		var index := key.physical_keycode - KEY_1
		if index >= 0 and index < _cards.size():
			get_viewport().set_input_as_handled()
			_choose(index)


func _choose(i: int) -> void:
	if not visible:
		return
	visible = false
	Audio.sfx("ui_click")
	picked.emit(_cards[i])
