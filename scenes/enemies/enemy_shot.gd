class_name EnemyShot
extends Node2D
## 獵物的反擊彈：直線彈、拋物線的廢料或炸彈、碎片。碰到玩家扣電；有爆炸半徑的會在落地時爆開。

var velocity := Vector2.ZERO
var gravity := 0.0
var damage := 6.0
var radius := 2.5
var life := 2.0
var color := Color("ff3df0")
var explode_radius := 0.0      # 大於 0：碰到地形或時間到就爆炸
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		_finish()
		return
	velocity.y += gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.dead and player.global_position.distance_to(to) < radius + 7.0:
		if explode_radius > 0.0:
			_explode()
		else:
			player.take_hit(damage, global_position)
		queue_free()
		return
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, Layers.TERRAIN))
	if not hit.is_empty():
		global_position = hit["position"]
		_finish()
		return
	global_position = to
	queue_redraw()


func _finish() -> void:
	if explode_radius > 0.0:
		_explode()
	queue_free()


func _explode() -> void:
	Audio.sfx("explode", -6.0)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.dead and player.global_position.distance_to(global_position) < explode_radius:
		player.take_hit(damage, global_position)
	var burst := Burst.new()
	burst.position = global_position
	burst.color = color
	burst.max_radius = explode_radius
	get_parent().add_child(burst)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 1.0, Color(color, 0.35))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, maxf(radius - 1.5, 0.5), Color.WHITE if int(_t * 12.0) % 2 == 0 else color.lightened(0.4))
