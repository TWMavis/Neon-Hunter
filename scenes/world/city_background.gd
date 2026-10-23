class_name CityBackground
extends Node2D
## 視差背景：遠景高樓與霓虹窗光（放在 Parallax2D 底下）。

const SKY_TOP := Color(0.04, 0.02, 0.09)
const SKY_BOTTOM := Color(0.16, 0.06, 0.24)
const BUILDING := Color(0.08, 0.05, 0.17)
const NEON := [Color(1.0, 0.24, 0.94), Color(0.24, 0.96, 1.0), Color(1.0, 0.88, 0.3)]

var _buildings: Array[Rect2] = []
var _windows: Array[Rect2] = []
var _window_colors: Array[Color] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := -200.0
	while x < 1700.0:
		var w := rng.randf_range(40.0, 90.0)
		var h := rng.randf_range(140.0, 380.0)
		_buildings.append(Rect2(x, 600.0 - h, w, h + 400.0))
		for i in rng.randi_range(4, 14):
			_windows.append(Rect2(x + rng.randf_range(4.0, w - 8.0), 600.0 - h + rng.randf_range(6.0, h - 10.0), 3.0, 2.0))
			var neon: Color = NEON[rng.randi() % NEON.size()]
			_window_colors.append(neon.darkened(rng.randf_range(0.2, 0.6)))
		x += w + rng.randf_range(4.0, 20.0)


func _draw() -> void:
	draw_rect(Rect2(-2000, -2000, 6000, 6000), SKY_TOP)
	for i in 8:
		draw_rect(Rect2(-2000, -100 + i * 90, 6000, 90), SKY_TOP.lerp(SKY_BOTTOM, i / 7.0))
	draw_rect(Rect2(-2000, 620, 6000, 3000), SKY_BOTTOM)
	for b in _buildings:
		draw_rect(b, BUILDING)
	for i in _windows.size():
		draw_rect(_windows[i], _window_colors[i])
