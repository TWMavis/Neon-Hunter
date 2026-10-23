class_name Projectile
extends Node2D
## 玩家射出的子彈、飛鏢、網、鉤爪、手雷。用射線檢測移動路徑，避免高速穿透。

enum Kind { BULLET, NET, HOOK, GRENADE }

const EXPLOSION_RADIUS := 50.0

var kind: Kind = Kind.BULLET
var velocity := Vector2.ZERO
var damage := 1.0
var life := 0.7
var color := Color.WHITE
var radius := 1.5
var trail := 5.0
var stun_time := 0.0
var catch_radius := 0.0   # 大於 0 時，路徑附近的獵物也會被抓到（網子）
var pierce := 0           # 還能貫穿幾個敵人
var knock := 0.0          # 擊退力道
var homing := 0.0         # 追蹤轉向速度（弧度／秒）
var gravity := 0.0
var source: StringName = &""   # 射出它的技能 id（決定吃哪個技能的晶片加成）

var _exclude: Array[RID] = []


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		if kind == Kind.GRENADE:
			_explode(global_position)
		queue_free()
		return
	velocity.y += gravity * delta
	if homing > 0.0:
		_steer(delta)

	var from := global_position
	var to := from + velocity * delta

	if catch_radius > 0.0:
		var caught := _prey_near(to, catch_radius)
		if caught:
			_on_prey(caught, to)
			queue_free()
			return

	var query := PhysicsRayQueryParameters2D.create(from, to, Layers.TERRAIN | Layers.ENEMY, _exclude)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var point: Vector2 = hit["position"]
		var prey := hit["collider"] as Prey
		if prey:
			_on_prey(prey, point)
			if pierce > 0 and kind == Kind.BULLET:
				pierce -= 1
				_exclude.append(prey.get_rid())
				global_position = to
				queue_redraw()
				return
		else:
			_on_terrain(point)
		queue_free()
		return
	global_position = to
	queue_redraw()


func _steer(delta: float) -> void:
	var target := _prey_near(global_position, 170.0, true)
	if target == null:
		return
	var want := global_position.direction_to(target.global_position).angle()
	var now := velocity.angle()
	var turn := clampf(angle_difference(now, want), -homing * delta, homing * delta)
	velocity = velocity.rotated(turn)


func _prey_near(point: Vector2, within: float, nearest := false) -> Prey:
	var best: Prey = null
	var best_d := within
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not prey.visible:
			continue
		var d := prey.global_position.distance_to(point)
		if d < best_d:
			best = prey
			best_d = d
			if not nearest:
				return prey
	return best


func _on_prey(prey: Prey, point: Vector2) -> void:
	match kind:
		Kind.BULLET:
			prey.take_damage(damage, source)
			if knock > 0.0 and is_instance_valid(prey):
				prey.knockback(velocity.normalized() * knock)
		Kind.NET:
			_net(prey, point)
		Kind.HOOK:
			var player := _player()
			prey.take_damage(damage, source)
			if player and is_instance_valid(prey):
				prey.pull_toward(player.global_position, 320.0)
		Kind.GRENADE:
			_explode(point)


func _on_terrain(point: Vector2) -> void:
	match kind:
		Kind.HOOK:
			var player := _player()
			if player:
				player.grapple_to(point - velocity.normalized() * 6.0)
		Kind.GRENADE:
			_explode(point)


func _net(prey: Prey, point: Vector2) -> void:
	prey.stun(stun_time)
	if ClimbState.chip_on(&"em_net", &"chain_net"):
		for node in get_tree().get_nodes_in_group("prey"):
			var other := node as Prey
			if other and other != prey and other.global_position.distance_to(point) < 90.0:
				other.stun(stun_time)
				_spawn_burst(other.global_position, color, 10.0)
				break
	if ClimbState.has_synergy(&"capture_array"):
		# 捕獸陣列：把附近的獵物一起網住並吸到命中點
		for node in get_tree().get_nodes_in_group("prey"):
			var other := node as Prey
			if other and other.global_position.distance_to(point) < 80.0:
				other.stun(stun_time)
				other.velocity = other.global_position.direction_to(point) * 160.0
		_spawn_burst(point, color, 80.0)


func _explode(point: Vector2) -> void:
	Audio.sfx("explode")
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey and prey.global_position.distance_to(point) < EXPLOSION_RADIUS:
			prey.slow(3.0)
			prey.take_damage(damage, source)
	_spawn_burst(point, color, EXPLOSION_RADIUS)


func _spawn_burst(point: Vector2, burst_color: Color, burst_radius: float) -> void:
	var burst := Burst.new()
	burst.position = point
	burst.color = burst_color
	burst.max_radius = burst_radius
	get_parent().add_child(burst)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _draw() -> void:
	match kind:
		Kind.NET:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 8, color, 1.0)
			draw_line(Vector2(-radius, 0.0), Vector2(radius, 0.0), color, 1.0)
			draw_line(Vector2(0.0, -radius), Vector2(0.0, radius), color, 1.0)
		Kind.HOOK:
			var player := _player()
			if player:
				draw_line(Vector2.ZERO, player.global_position - global_position, color.darkened(0.3), 1.0)
			draw_rect(Rect2(-2, -2, 4, 4), color)
		Kind.GRENADE:
			draw_circle(Vector2.ZERO, radius, color)
		_:
			draw_line(Vector2.ZERO, -velocity.normalized() * trail, color, 2.0)
