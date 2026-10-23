extends Control
## 攀登起點：開場只有一把小刀，從第 1 區段第 1 層出發。槍要在升級、電梯商店拿到。

const GAME_SCENE := "res://scenes/game/game.tscn"


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
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := UiTheme.label("霓虹獵手", UiTheme.MAGENTA, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var story := UiTheme.label("你曾是天柱頂層的首席獵手。被陷害、晶片被拔光，丟到了最底層。\n身上只剩一把小刀。獵殺流氓 AI，奪回電梯權限，一層一層爬回去。", UiTheme.DIM, 10)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(story)
	var hint := UiTheme.label("開場只有小刀（左鍵近身揮砍）。槍和右鍵武器要從升級、電梯商店取得。", UiTheme.CYAN, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	root.add_child(hint)

	var start := Button.new()
	start.text = "開始攀登　第 1 區段・廢料層"
	start.custom_minimum_size = Vector2(220, 26)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_start)
	root.add_child(start)
	start.grab_focus.call_deferred()   # 手把也能直接按 A 開始

	var settings_button := Button.new()
	settings_button.text = "設定（音量、按鍵）"
	settings_button.custom_minimum_size = Vector2(220, 22)
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(settings_button)
	var settings := SettingsPanel.new()
	add_child(settings)
	settings_button.pressed.connect(settings.open)
	settings.closed.connect(settings_button.grab_focus)


func _start() -> void:
	ClimbState.new_climb()
	get_tree().change_scene_to_file(GAME_SCENE)
