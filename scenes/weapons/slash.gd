class_name Slash
extends Node2D
## 小刀揮砍的弧形殘影。

const DURATION := 0.12

var radius := 26.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var sweep := lerpf(-1.2, 1.2, minf(k * 1.6, 1.0))
	draw_arc(Vector2.ZERO, radius, -1.2, sweep, 12, Color(0.9, 1.0, 1.0, 1.0 - k), 2.0)
	draw_arc(Vector2.ZERO, radius - 4.0, -1.0, sweep, 10, Color(0.24, 0.96, 1.0, 0.6 * (1.0 - k)), 1.0)
