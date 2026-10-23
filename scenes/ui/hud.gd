class_name Hud
extends Control
## HUD：電量、權限碎片、等級與經驗、晶片額度（超載變紅）、被動、時間、清除協議、Boss 血條、
## 畫面外指示箭頭、準心、死亡畫面。放在 process_mode = ALWAYS 的 CanvasLayer 裡。

const CYAN := UiTheme.CYAN
const MAGENTA := UiTheme.MAGENTA
const GREEN := UiTheme.GREEN
const RED := UiTheme.RED
const YELLOW := UiTheme.YELLOW
const WHITE := UiTheme.WHITE
const OVERCLOCK := Color(1.0, 0.62, 0.15)
const ARROW_RANGE := 320.0      # 沒有雷達時，只顯示這個距離內的畫面外獵物

var game: Game
var _announce := ""
var _announce_time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func announce(text: String) -> void:
	_announce = text
	_announce_time = 3.0


func _process(delta: float) -> void:
	_announce_time = maxf(_announce_time - delta, 0.0)
	if RunState.finished and not RunState.cleared and Input.is_action_just_pressed("restart"):
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu/climb_start.tscn")
		return
	if Input.is_action_just_pressed("ui_cancel") and not get_tree().paused:
		# Esc：放開／鎖回滑鼠
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()


func _draw() -> void:
	if game == null or game.player == null:
		return
	var font := Fonts.ui()
	var view := get_viewport_rect().size
	var blink := int(RunState.elapsed * 6.0) % 2 == 0

	_draw_arrows(view)

	# 電量（超載時閃爍）
	var ratio := RunState.energy / RunState.max_energy
	var overloaded := ClimbState.is_overloaded()
	var bar_color := RED if (ratio < 0.25 or overloaded) and blink else CYAN
	_text(font, Vector2(8, 15), "電量", 11, CYAN)
	draw_rect(Rect2(34, 8, 90, 7), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(34, 8, 90 * ratio, 7), bar_color)
	draw_rect(Rect2(34, 8, 90, 7), CYAN.darkened(0.4), false, 1.0)

	# 超頻：剩餘次數、超頻條（電量溢出累積）、倒數
	for i in ClimbState.OVERCLOCK_CHARGES:
		var c := OVERCLOCK if i < ClimbState.overclock_charges else Color(0.25, 0.2, 0.35)
		draw_colored_polygon(PackedVector2Array([Vector2(131 + i * 9, 8), Vector2(135 + i * 9, 11.5), Vector2(131 + i * 9, 15), Vector2(127 + i * 9, 11.5)]), c)
	draw_rect(Rect2(34, 17, 90, 2), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(34, 17, 90.0 * ClimbState.overclock_bar / ClimbState.OVERCLOCK_BAR_MAX, 2), OVERCLOCK)
	if RunState.overclocked:
		var pulse := OVERCLOCK
		pulse.a = 0.75 + 0.25 * sin(RunState.elapsed * 12.0)
		_text_center(font, Vector2(view.x * 0.5, 104), "超頻 %.1f" % RunState.overclock_left, 22, pulse)
		_text_center(font, Vector2(view.x * 0.5, 120), "攻擊力 ×2　時間到時電量要大於 0", 10, OVERCLOCK)

	# 權限碎片
	var met := RunState.quota_met()
	if RunState.quota > 0:
		_text(font, Vector2(8, 30), "權限碎片 %d / %d" % [RunState.shards, RunState.quota], 11, GREEN if met else WHITE)
	if met:
		_text(font, Vector2(8, 44), "電梯已解鎖", 11, GREEN)

	# 等級與經驗
	_text(font, Vector2(view.x - 120, 15), "Lv %d" % ClimbState.level, 11, YELLOW)
	_text(font, Vector2(view.x - 120, 28), "信用點 %d" % ClimbState.credits, 10, YELLOW)
	if ClimbState.free_capacity() > 0:
		_text(font, Vector2(view.x - 120, 52), "未分配額度 %d（長按 Tab）" % ClimbState.free_capacity(), 9, MAGENTA)
	draw_rect(Rect2(view.x - 88, 9, 80, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(view.x - 88, 9, 80.0 * ClimbState.xp / ClimbState.xp_to_next(), 5), Color("6aa8ff"))

	if overloaded:
		_text(font, Vector2(view.x - 120, 40), "晶片超載：消耗加倍", 10, RED)

	# 被動技能與各自的晶片額度
	var y := view.y - 7.0
	for i in range(ClimbState.passives.size() - 1, -1, -1):
		var id := ClimbState.passives[i]
		_text(font, Vector2(view.x - 112, y), Catalog.PASSIVES[id][0], 9, GREEN)
		_skill_pips(Vector2(view.x - 50, y - 6), id)
		y -= 12.0

	# 時間與清除協議
	_text_center(font, Vector2(view.x * 0.5, 15), _clock(RunState.elapsed), 12, WHITE)
	_text_center(font, Vector2(view.x * 0.5, 27), _floor_label(), 9, Color(0.6, 0.6, 0.8))
	if game.purge_active and blink:
		_text_center(font, Vector2(view.x * 0.5, 40), "清除協議啟動", 11, RED)

	# Boss 血條
	if is_instance_valid(game.boss):
		var hp_ratio := clampf(game.boss.hp / game.boss.max_hp, 0.0, 1.0)
		draw_rect(Rect2(view.x * 0.5 - 100, view.y - 30, 200, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(view.x * 0.5 - 100, view.y - 30, 200 * hp_ratio, 5), Color("d9772b"))
		_text_center(font, Vector2(view.x * 0.5, view.y - 34), "回收巨獸", 10, Color("d9772b"))

	# 武器
	var weapons := game.player.weapons
	if weapons:
		var primary_text := "左鍵 " + weapons.primary.display_name
		if weapons.jam_left > 0.0:
			primary_text += "（卡彈！）"
		_text(font, Vector2(8, view.y - 20), primary_text, 10, RED if weapons.jam_left > 0.0 else CYAN)
		_skill_pips(Vector2(82, view.y - 26), weapons.primary.id)
		_text(font, Vector2(8, view.y - 33), "移動 跳躍・衝刺", 10, YELLOW)
		_skill_pips(Vector2(82, view.y - 39), Catalog.MOVEMENT)
		var sec := weapons.secondary
		var ready_ratio := 1.0 - sec.cooldown_ratio()
		_text(font, Vector2(8, view.y - 7), "右鍵 " + sec.display_name, 10, MAGENTA)
		_skill_pips(Vector2(82, view.y - 13), sec.id)
		draw_rect(Rect2(8, view.y - 4, 60, 2), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(8, view.y - 4, 60 * ready_ratio, 2), MAGENTA if ready_ratio >= 1.0 else MAGENTA.darkened(0.5))
		if sec.max_charges() > 1:
			_text(font, Vector2(72, view.y - 1), "×%d" % sec.charges, 8, MAGENTA)

	if _announce_time > 0.0 and not game.picker.visible:
		var c := YELLOW
		c.a = clampf(_announce_time, 0.0, 1.0)
		_text_center(font, Vector2(view.x * 0.5, 70), _announce, 13, c)

	if RunState.finished and not RunState.cleared:
		_draw_death(font, view)
	elif Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		_draw_crosshair(get_viewport().get_mouse_position())

	# 長按 Tab 的進度
	if game.tab_hold > 0.0 and not game.chip_menu.visible:
		var k := clampf(game.tab_hold / Game.TAB_HOLD_TIME, 0.0, 1.0)
		_text_center(font, Vector2(view.x * 0.5, view.y - 44), "晶片調整（消耗 10% 電量）", 10, MAGENTA)
		draw_rect(Rect2(view.x * 0.5 - 40, view.y - 40, 80, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(view.x * 0.5 - 40, view.y - 40, 80 * k, 3), MAGENTA)


## 技能的晶片額度：已使用的亮起，超載的部分變紅
func _skill_pips(at: Vector2, skill: StringName) -> void:
	var used := ClimbState.used(skill)
	var cap := ClimbState.capacity_of(skill)
	for i in maxi(used, cap):
		var c := MAGENTA if i < used else Color(0.25, 0.2, 0.35)
		if i >= cap:
			c = RED
		draw_rect(Rect2(at.x + i * 5, at.y, 4, 4), c)


func _floor_label() -> String:
	if ClimbState.is_boss_floor():
		return "第 %d 區段・Boss 層" % ClimbState.section
	var names := {&"normal": "一般層", &"danger": "危險層", &"repair": "維修層", &"black_market": "黑市層", &"vault": "金庫層"}
	return "第 %d 區段・第 %d 層・%s" % [ClimbState.section, ClimbState.floor_index + 1, names.get(ClimbState.floor_type, "")]


func _draw_arrows(view: Vector2) -> void:
	var xf := get_viewport().get_canvas_transform()
	var radar := ClimbState.has_passive(&"radar")
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey and prey.visible and (radar or prey.global_position.distance_to(game.player.global_position) < ARROW_RANGE):
			_edge_arrow(xf * prey.global_position, view, prey.color, 6.0 if prey.kind == Prey.Kind.BOSS else 4.0)
	if is_instance_valid(game.hunter):
		_edge_arrow(xf * game.hunter.global_position, view, RED, 7.0)
	if RunState.quota_met():
		_edge_arrow(xf * (game.elevator.global_position + Vector2(0, -20)), view, GREEN, 7.0)


## 目標在畫面外時，在畫面邊緣畫一個指向它的三角形
func _edge_arrow(screen: Vector2, view: Vector2, color: Color, arrow_size: float) -> void:
	if Rect2(Vector2.ZERO, view).grow(-2.0).has_point(screen):
		return
	var center := view * 0.5
	var dir := (screen - center).normalized()
	var half := center - Vector2(10, 10)
	var reach := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var p := center + dir * reach
	var back := p - dir * arrow_size * 0.5
	var side := dir.orthogonal() * arrow_size * 0.7
	draw_colored_polygon(PackedVector2Array([p + dir * arrow_size, back + side, back - side]), color)


func _draw_crosshair(pos: Vector2) -> void:
	draw_arc(pos, 4.0, 0.0, TAU, 12, CYAN, 1.0)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(pos + d * 6.0, pos + d * 9.0, CYAN, 1.0)


func _draw_death(font: Font, view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.7))
	var title := "你被清除了" if is_instance_valid(game.hunter) else "電量耗盡"
	_text_center(font, Vector2(view.x * 0.5, 96), title, 22, RED)
	var stats := "第 %d 層　Lv %d　時間 %s　擊殺 %d" % [ClimbState.floor_index + 1, ClimbState.level, _clock(RunState.elapsed), RunState.kills]
	_text_center(font, Vector2(view.x * 0.5, 128), stats, 12, WHITE)
	_text_center(font, Vector2(view.x * 0.5, 148), "攀登失敗，回到第 %d 區段起點" % ClimbState.section, 11, Color(0.7, 0.7, 0.85))
	_text_center(font, Vector2(view.x * 0.5, 172), "按 R 重新攀登", 12, CYAN)


func _clock(seconds: float) -> String:
	var t := int(seconds)
	return "%d:%02d" % [int(t / 60.0), t % 60]


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_center(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var at := Vector2(pos.x - 200.0, pos.y)
	draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, font_size, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, font_size, color)
