class_name PlatformGraph
extends RefCounted
## 平台導航圖：每個可站立的格子是一個節點，連線分成「走、跳、落下」。
## 每隔一段時間從玩家所在節點跑一次 Dijkstra（逃跑距離圖），所有獵物共用這份結果，
## 每隻獵物只要往「離玩家最遠的相鄰節點」移動。

enum Edge { WALK, JUMP, DROP }

const TILE := 16
const MAX_JUMP_TILES := 5      # 地面獵物跳躍高度約 5 格
const MAX_JUMP_DX := 2

const EMPTY := 0
const SOLID := 1
const ONE_WAY := 2

var nodes: Array[Vector2i] = []     # 節點的格座標（站立的那一格平台）
var dist := PackedFloat64Array()    # 每個節點離玩家的距離（Dijkstra 結果）；用 64 位元避免比較時的精度誤差

var _index: Dictionary = {}         # Vector2i -> 節點 id
var _edges: Array = []              # 節點 id -> Array of [目標 id, Edge, 成本]
var _cells := PackedByteArray()
var _width := 0
var _height := 0


func build(blocks: Array, width: int, height: int) -> void:
	_width = width
	_height = height
	_cells.resize(width * height)
	_cells.fill(EMPTY)
	for b: Array in blocks:
		var kind: int = SOLID if b[4] == 0 else ONE_WAY
		for x in range(b[0], b[0] + b[2]):
			for y in range(b[1], b[1] + b[3]):
				if _cell(x, y) != SOLID:
					_cells[y * width + x] = kind

	for y in range(1, height):
		for x in width:
			if _cell(x, y) != EMPTY and _cell(x, y - 1) != SOLID:
				_index[Vector2i(x, y)] = nodes.size()
				nodes.append(Vector2i(x, y))

	_edges.resize(nodes.size())
	for id in nodes.size():
		_edges[id] = []
	for id in nodes.size():
		_build_edges(id)
	dist.resize(nodes.size())
	dist.fill(0.0)


func node_count() -> int:
	return nodes.size()


func edges_of(id: int) -> Array:
	return _edges[id]


## 節點的世界座標（平台表面中央）
func node_position(id: int) -> Vector2:
	var c := nodes[id]
	return Vector2(c.x * TILE + TILE * 0.5, c.y * TILE)


## 站在地面上的角色腳底座標 → 節點 id（找不到回傳 -1）
func node_at_feet(feet: Vector2) -> int:
	return _index.get(Vector2i(floori(feet.x / TILE), roundi(feet.y / TILE)), -1)


## 任意世界座標往下找最近的節點（玩家在空中也找得到）
func nearest_node(world: Vector2) -> int:
	var tx := floori(world.x / TILE)
	var ty := floori(world.y / TILE)
	for r in range(maxi(ty, 0), mini(ty + 8, _height)):
		var id: int = _index.get(Vector2i(tx, r), -1)
		if id >= 0:
			return id
	var best := -1
	var best_d := INF
	for id in nodes.size():
		var d := node_position(id).distance_squared_to(world)
		if d < best_d:
			best_d = d
			best = id
	return best


## Dijkstra：從離 world 最近的節點出發，算出到每個節點的距離
func compute_from(world: Vector2) -> void:
	dist.fill(INF)
	var start := nearest_node(world)
	if start < 0:
		return
	dist[start] = 0.0
	var heap_cost: Array[float] = [0.0]
	var heap_id: Array[int] = [start]
	while not heap_id.is_empty():
		var cost := heap_cost[0]
		var id := heap_id[0]
		_heap_pop(heap_cost, heap_id)
		if cost > dist[id]:
			continue
		for e: Array in _edges[id]:
			var to: int = e[0]
			var next: float = cost + e[2]
			if next < dist[to]:
				dist[to] = next
				_heap_push(heap_cost, heap_id, next, to)


func _build_edges(id: int) -> void:
	var c := nodes[id]
	# 走：同一層左右相鄰；走到邊緣就落下
	for dx: int in [-1, 1]:
		var n := Vector2i(c.x + dx, c.y)
		if _index.has(n):
			_add(id, _index[n], Edge.WALK, 1.0)
		elif _cell(n.x, n.y) == EMPTY and _cell(n.x, n.y - 1) != SOLID:
			var land := _land_below(n.x, n.y)
			if land >= 0:
				_add(id, land, Edge.DROP, 1.0 + 0.15 * (nodes[land].y - c.y))
	# 單向平台：往下鑽
	if _cell(c.x, c.y) == ONE_WAY:
		var land := _land_below(c.x, c.y + 1)
		if land >= 0:
			_add(id, land, Edge.DROP, 1.0 + 0.15 * (nodes[land].y - c.y))
	# 跳：上方 5 格內、左右 2 格內的平台，中間不能有實心牆
	for dx in range(-MAX_JUMP_DX, MAX_JUMP_DX + 1):
		for dy in range(1, MAX_JUMP_TILES + 1):
			var t := Vector2i(c.x + dx, c.y - dy)
			if not _index.has(t):
				continue
			if _column_blocked(c.x, t.y, c.y - 1):
				continue
			_add(id, _index[t], Edge.JUMP, 2.0 + 0.3 * dy)


func _column_blocked(x: int, from_y: int, to_y: int) -> bool:
	for y in range(from_y, to_y + 1):
		if _cell(x, y) == SOLID:
			return true
	return false


func _land_below(x: int, from_y: int) -> int:
	for y in range(from_y, _height):
		if _cell(x, y) != EMPTY:
			return _index.get(Vector2i(x, y), -1)
	return -1


func _cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= _width or y >= _height:
		return SOLID
	return _cells[y * _width + x]


func _add(from: int, to: int, type: Edge, cost: float) -> void:
	_edges[from].append([to, type, cost])


func _heap_push(costs: Array[float], ids: Array[int], cost: float, id: int) -> void:
	costs.append(cost)
	ids.append(id)
	var i := costs.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if costs[parent] <= costs[i]:
			break
		_swap(costs, ids, i, parent)
		i = parent


func _heap_pop(costs: Array[float], ids: Array[int]) -> void:
	var last := costs.size() - 1
	costs[0] = costs[last]
	ids[0] = ids[last]
	costs.resize(last)
	ids.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var smallest := i
		if l < last and costs[l] < costs[smallest]:
			smallest = l
		if r < last and costs[r] < costs[smallest]:
			smallest = r
		if smallest == i:
			break
		_swap(costs, ids, i, smallest)
		i = smallest


func _swap(costs: Array[float], ids: Array[int], a: int, b: int) -> void:
	var tc := costs[a]
	costs[a] = costs[b]
	costs[b] = tc
	var ti := ids[a]
	ids[a] = ids[b]
	ids[b] = ti
