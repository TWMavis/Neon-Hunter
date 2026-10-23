class_name Hunter
extends Node2D
## 清除協議的追獵者（頂替你位置的新任首席獵手）：穿牆追殺玩家，無法擊殺，只能逃回電梯。

const START_SPEED := 60.0
const MAX_SPEED := 125.0
const RAMP_TIME := 40.0
const TOUCH_RADIUS := 12.0
const TOUCH_DAMAGE := 35.0

var target: Player
var _age := 0.0


func _ready() -> void:
	add_to_group("hunter")


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if not is_instance_valid(target) or target.dead:
		return
	var speed := lerpf(START_SPEED, MAX_SPEED, clampf(_age / RAMP_TIME, 0.0, 1.0))
	global_position = global_position.move_toward(target.global_position, speed * delta)
	if global_position.distance_to(target.global_position) < TOUCH_RADIUS:
		target.take_hit(TOUCH_DAMAGE, global_position)


func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(_age * 8.0)
	var red := Color("ff2244")
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.1, 0.2, 0.2 * pulse))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 16, Color(red, 0.4 * pulse), 1.0)
	var flip := is_instance_valid(target) and target.global_position.x < global_position.x
	Art.draw(self, "hunter", 5, 1 + int(_age * 8.0) % 2, Vector2.ZERO, flip)
