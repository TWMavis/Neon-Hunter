class_name Burst
extends Node2D
## 擴散的光環特效（爆炸、網、雷達）。

const DURATION := 0.3

var color := Color.WHITE
var max_radius := 30.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var c := color
	c.a = 1.0 - k
	draw_arc(Vector2.ZERO, max_radius * k, 0.0, TAU, 24, c, 1.0)
