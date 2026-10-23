class_name Elevator
extends Node2D
## 電梯：湊滿權限碎片後解鎖，站進去按住 F 2 秒（避免誤觸）離開這層樓。位置是電梯底部中央。

const SIZE := Vector2(28, 40)
const HOLD_TIME := 2.0

var unlocked := false
var player_inside := false
var hold := 0.0                 # 按住 F 的秒數
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	unlocked = RunState.quota_met()
	player_inside = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.dead:
		var local := player.global_position - global_position
		player_inside = absf(local.x) < SIZE.x * 0.5 and local.y < 0.0 and local.y > -SIZE.y
	if unlocked and player_inside and Input.is_action_pressed("interact"):
		if hold == 0.0:
			Audio.sfx("ui_click")
		hold += delta
		if hold >= HOLD_TIME:
			hold = 0.0
			RunState.clear_floor()
	else:
		hold = 0.0
	queue_redraw()


func _draw() -> void:
	var light := Color("7dff6a") if unlocked else Color("ff2244")
	Art.draw(self, "elevator", 2, 1 if unlocked else 0, Vector2(0.0, -SIZE.y * 0.5))
	light.a = 0.7 + 0.3 * sin(_t * 4.0)
	draw_rect(Rect2(-3.0, -SIZE.y + 2.0, 6.0, 2.0), light)

	if not player_inside:
		return
	var text := "按住 F 搭電梯" if unlocked else "權限不足 %d / %d" % [RunState.shards, RunState.quota]
	if hold > 0.0:
		text = "搭電梯中… %.1f" % maxf(HOLD_TIME - hold, 0.0)
	draw_string(Fonts.ui(), Vector2(-80.0, -SIZE.y - 10.0), text, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 11, light)
	if unlocked:
		var bar := Rect2(-16.0, -SIZE.y - 6.0, 32.0, 3.0)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hold / HOLD_TIME, bar.size.y)), Color("7dff6a"))
