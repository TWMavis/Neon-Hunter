extends Control
## 攀登起點：選這次攀登的左鍵與右鍵武器，然後從第 1 區段第 1 層出發。

const GAME_SCENE := "res://scenes/game/game.tscn"

var _primary := &"pulse_rifle"
var _secondary := &"em_net"
var _primary_group := ButtonGroup.new()
var _secondary_group := ButtonGroup.new()


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.music("music_calm")

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var title := UiTheme.label("霓虹獵手", UiTheme.MAGENTA, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var story := UiTheme.label("你曾是天柱頂層的首席獵手。被陷害、晶片被拔光，丟到了最底層。\n獵殺流氓 AI，奪回電梯權限，一層一層爬回去。", UiTheme.DIM, 10)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(story)

	root.add_child(_section("左鍵主武器", Catalog.PRIMARY_WEAPONS, _primary_group, _primary, _on_primary))
	root.add_child(_section("右鍵副武器", Catalog.SECONDARY_WEAPONS, _secondary_group, _secondary, _on_secondary))

	var start := Button.new()
	start.text = "開始攀登　第 1 區段・廢料層"
	start.custom_minimum_size = Vector2(220, 26)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_start)
	root.add_child(start)


func _section(heading: String, table: Dictionary, group: ButtonGroup, selected: StringName, on_pick: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	var label := UiTheme.label(heading, UiTheme.CYAN, 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for id: StringName in table:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = id == selected
		button.custom_minimum_size = Vector2(140, 40)
		button.text = "%s\n%s" % [table[id][0], table[id][1]]
		button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(on_pick.bind(id))
		row.add_child(button)
	return box


func _on_primary(id: StringName) -> void:
	_primary = id


func _on_secondary(id: StringName) -> void:
	_secondary = id


func _start() -> void:
	ClimbState.new_climb(_primary, _secondary)
	get_tree().change_scene_to_file(GAME_SCENE)
