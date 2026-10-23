class_name ChipPanel
extends HBoxContainer
## 晶片配置畫面（電梯和樓層中長按 Tab 共用）。
## 左邊列出每個技能與它身上的晶片；右邊是背包、說明、共鳴。
## 點一枚晶片選取，再按技能旁的「插到這裡」，或按「卸下選取的晶片」放回背包。
## 技能旁的 ＋／－ 把總晶片額度分配給各技能。

var _skill_list: VBoxContainer
var _backpack: HFlowContainer
var _unequip_button: Button
var _detail: Label
var _info_box: VBoxContainer
var _selected: StringName = &""
var _total_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var skills_panel := PanelContainer.new()
	skills_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_panel.size_flags_stretch_ratio = 1.5
	add_child(skills_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skills_panel.add_child(scroll)
	_skill_list = VBoxContainer.new()
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_skill_list)

	var side_panel := PanelContainer.new()
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(side_panel)
	var side := VBoxContainer.new()
	side_panel.add_child(side)
	_total_label = UiTheme.label("", UiTheme.YELLOW, 10)
	side.add_child(_total_label)
	side.add_child(UiTheme.label("背包", UiTheme.MAGENTA, 11))
	_backpack = HFlowContainer.new()
	side.add_child(_backpack)
	_unequip_button = Button.new()
	_unequip_button.text = "卸下選取的晶片"
	_unequip_button.add_theme_font_size_override("font_size", 9)
	_unequip_button.pressed.connect(_on_unequip)
	side.add_child(_unequip_button)
	_detail = UiTheme.label("點一枚晶片選取，再按技能旁的「插到這裡」", UiTheme.DIM, 9)
	_detail.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_detail.custom_minimum_size = Vector2(150, 36)
	side.add_child(_detail)
	_info_box = VBoxContainer.new()
	_info_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_info_box)

	ClimbState.loadout_changed.connect(refresh)
	refresh()


func show_message(text: String) -> void:
	_detail.text = text


func refresh() -> void:
	if _selected != &"" and not ClimbState.owned.has(_selected):
		_selected = &""

	_total_label.text = "總晶片額度 %d　未分配 %d（用 ＋／－ 分配給技能）" % [ClimbState.total_capacity, ClimbState.free_capacity()]
	_total_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

	for child in _skill_list.get_children():
		child.queue_free()
	for skill in ClimbState.skills():
		_skill_list.add_child(_skill_row(skill))

	for child in _backpack.get_children():
		child.queue_free()
	var pack := ClimbState.backpack()
	if pack.is_empty():
		_backpack.add_child(UiTheme.label("空的", UiTheme.DIM, 9))
	for id in pack:
		_backpack.add_child(_chip_button(id))
	_unequip_button.disabled = not ClimbState.slot_of.has(_selected)

	for child in _info_box.get_children():
		child.queue_free()
	_info_box.add_child(UiTheme.label("共鳴", UiTheme.YELLOW, 11))
	if ClimbState.discovered.is_empty():
		_info_box.add_child(UiTheme.label("尚未發現", UiTheme.DIM, 9))
	for s in Catalog.synergies():
		if ClimbState.discovered.has(s.id):
			var active := ClimbState.has_synergy(s.id)
			_info_box.add_child(UiTheme.label(("● " if active else "○ ") + s.display_name, UiTheme.YELLOW if active else UiTheme.DIM, 9))


func _skill_row(skill: StringName) -> VBoxContainer:
	var row := VBoxContainer.new()
	var head := HBoxContainer.new()
	row.add_child(head)
	var slot := "被動"
	var color := UiTheme.GREEN
	if skill == ClimbState.primary:
		slot = "左鍵"
		color = UiTheme.CYAN
	elif skill == ClimbState.secondary:
		slot = "右鍵"
		color = UiTheme.CYAN
	elif skill == Catalog.MOVEMENT:
		slot = "移動槽"
		color = UiTheme.YELLOW
	var used := ClimbState.used(skill)
	var cap := ClimbState.capacity_of(skill)
	var over := ClimbState.skill_overloaded(skill)
	var label: String = Catalog.MOVEMENT_INFO[1] if skill == Catalog.MOVEMENT else Catalog.item_name(skill)
	var title := UiTheme.label("%s %s　%d / %d%s" % [slot, label, used, cap, "　超載" if over else ""],
		UiTheme.RED if over else color, 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for delta: int in [-1, 1]:
		var adjust := Button.new()
		adjust.text = "－" if delta < 0 else "＋"
		adjust.custom_minimum_size = Vector2(18, 0)
		adjust.add_theme_font_size_override("font_size", 9)
		adjust.disabled = not ClimbState.can_adjust(skill, delta)
		adjust.pressed.connect(_on_adjust.bind(skill, delta))
		head.add_child(adjust)
	if _selected != &"" and ClimbState.slot_of.get(_selected, &"") != skill:
		var put := Button.new()
		put.text = "插到這裡"
		put.add_theme_font_size_override("font_size", 9)
		var c := Catalog.chip(_selected)
		put.disabled = not c.fits(skill) or used >= cap
		put.pressed.connect(_on_put.bind(skill))
		head.add_child(put)
	var chips := HFlowContainer.new()
	row.add_child(chips)
	for id in ClimbState.chips_on(skill):
		chips.add_child(_chip_button(id))
	return row


func _chip_button(id: StringName) -> Button:
	var c := Catalog.chip(id)
	var plus := ClimbState.chip_plus(id)
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = id == _selected
	button.text = "[%d] %s%s" % [c.cost, c.display_name, " +%d" % plus if plus > 0 else ""]
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", c.rarity_color())
	button.pressed.connect(_on_select.bind(id))
	return button


func _on_select(id: StringName) -> void:
	_selected = &"" if _selected == id else id
	if _selected != &"":
		var c := Catalog.chip(id)
		_detail.text = "%s（額度 %d）：%s\n可插在：%s" % [c.display_name, c.cost, c.description, Catalog.allowed_text(c)]
	refresh.call_deferred()


func _on_put(skill: StringName) -> void:
	var ok := ClimbState.move(_selected, skill) if ClimbState.slot_of.has(_selected) else ClimbState.equip(_selected, skill)
	Audio.sfx("ui_click" if ok else "denied")
	if not ok:
		_detail.text = "放不下：這個技能至少要剩 1 格額度（超出的部分算超載）"
	_selected = &""
	refresh.call_deferred()


func _on_adjust(skill: StringName, delta: int) -> void:
	if not ClimbState.adjust_capacity(skill, delta):
		_detail.text = "沒有未分配的額度了" if delta > 0 else "要先卸下晶片才能再減少"
	refresh.call_deferred()


func _on_unequip() -> void:
	if ClimbState.slot_of.has(_selected):
		ClimbState.unequip(_selected)
	_selected = &""
	refresh.call_deferred()
