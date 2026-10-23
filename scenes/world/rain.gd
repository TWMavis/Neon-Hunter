class_name Rain
extends Node2D
## 螢幕空間的雨（放在 CanvasLayer 裡）。

const COUNT := 80
const COLOR := Color(0.55, 0.8, 1.0, 0.22)

var _drops: Array[Vector3] = []  # x, y, 速度


func _ready() -> void:
	for i in COUNT:
		_drops.append(Vector3(randf() * 540.0, randf() * 270.0, randf_range(220.0, 340.0)))


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	for i in _drops.size():
		var d := _drops[i]
		d.y += d.z * delta
		d.x -= d.z * 0.25 * delta
		if d.y > view.y:
			d.y = -8.0
			d.x = randf() * (view.x + 60.0)
		_drops[i] = d
	queue_redraw()


func _draw() -> void:
	for d in _drops:
		draw_line(Vector2(d.x, d.y), Vector2(d.x + 2.0, d.y - 7.0), COLOR, 1.0)
