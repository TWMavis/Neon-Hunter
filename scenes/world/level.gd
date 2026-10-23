class_name Level
extends Node2D
## 一層樓的地形：由地圖資料（見 data/maps）產生碰撞、平台導航圖與繪圖。
## 實心 = 牆與地板；單向平台（粉紅色）可從下方跳上、按 S 下跳。

const TILE := 16

var map: Dictionary = {}
var graph := PlatformGraph.new()
var width := 0
var height := 0
var blocks: Array = []
var junk: Array = []


## 加入場景前呼叫
func setup(map_data: Dictionary) -> void:
	map = map_data
	width = map["width"]
	height = map["height"]
	blocks = map["blocks"]
	junk = map.get("junk", [])
	graph.build(blocks, width, height)


func _ready() -> void:
	for b: Array in blocks:
		_add_block(b[0], b[1], b[2], b[3], b[4])


func size_px() -> Vector2:
	return Vector2(width, height) * TILE


## 電梯底部中央（站在地面上）
func elevator_position() -> Vector2:
	var x: int = map["elevator_x"]
	return Vector2(x * TILE + TILE * 0.5, (height - 1) * TILE)


## 生怪點：每個平台表面的中央，以及地面每隔 9 格一個（世界座標，位於表面上）
func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for b: Array in blocks:
		var x: int = b[0]
		var y: int = b[1]
		var w: int = b[2]
		var h: int = b[3]
		if h == 1 and w < width and y > 0 and y < height - 1:
			points.append(Vector2((x + w * 0.5) * TILE, y * TILE))
	for gx in range(4, width - 3, 9):
		points.append(Vector2(gx * TILE, (height - 1) * TILE))
	return points


## 垃圾堆的世界座標（Boss 層）
func junk_positions() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for j: Vector2i in junk:
		points.append(Vector2(j.x * TILE + TILE * 0.5, j.y * TILE))
	return points


func _add_block(x: int, y: int, w: int, h: int, type: int) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x, y) * TILE
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if type == 1:
		body.collision_layer = Layers.ONEWAY
		rect.size = Vector2(w * TILE, 4)
		shape.one_way_collision = true
	else:
		body.collision_layer = Layers.TERRAIN
		rect.size = Vector2(w, h) * TILE
	shape.shape = rect
	shape.position = rect.size * 0.5
	body.add_child(shape)
	add_child(body)


func _draw() -> void:
	var top := Art.tex("tile_top")
	var fill := Art.tex("tile_fill")
	var platform := Art.tex("platform")
	for b: Array in blocks:
		var x0: int = b[0]
		var y0: int = b[1]
		var w: int = b[2]
		var h: int = b[3]
		for x in range(x0, x0 + w):
			if b[4] == 1:
				draw_texture(platform, Vector2(x, y0) * TILE)
				continue
			for y in range(y0, y0 + h):
				# 上方是空的那一格用有霓虹邊的磚
				var exposed := y == y0 and y0 > 0
				draw_texture(top if exposed else fill, Vector2(x, y) * TILE)
	for p in junk_positions():
		var pile := PackedVector2Array([p + Vector2(-14, 0), p + Vector2(-8, -10), p + Vector2(0, -14), p + Vector2(9, -9), p + Vector2(14, 0)])
		draw_colored_polygon(pile, Color("3a2a1a"))
		draw_polyline(pile, Color("b8692e"), 1.0)
