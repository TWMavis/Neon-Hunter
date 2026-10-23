class_name Elevator
extends Node2D
## 電梯：湊滿權限碎片後解鎖，站進去按 W 離開這層樓。位置是電梯底部中央。

const SIZE := Vector2(28, 40)

var unlocked := false
var player_inside := false
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	unlocked = RunState.quota_met()
	player_inside = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.dead:
		var local := player.global_position - global_position
		player_inside = absf(local.x) < SIZE.x * 0.5 and local.y < 0.0 and local.y > -SIZE.y
		if unlocked and player_inside and Input.is_action_just_pressed("move_up"):
			RunState.clear_floor()
	queue_redraw()


func _draw() -> void:
	var light := Color("7dff6a") if unlocked else Color("ff2244")
	Art.draw(self, "elevator", 2, 1 if unlocked else 0, Vector2(0.0, -SIZE.y * 0.5))
	light.a = 0.7 + 0.3 * sin(_t * 4.0)
	draw_rect(Rect2(-3.0, -SIZE.y + 2.0, 6.0, 2.0), light)

	if player_inside:
		var text := "W 搭電梯" if unlocked else "權限不足 %d / %d" % [RunState.shards, RunState.quota]
		draw_string(Fonts.ui(), Vector2(-80.0, -SIZE.y - 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 11, light)
