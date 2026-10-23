class_name Pickup
extends Node2D
## 掉落物：權限碎片（湊配額開電梯）、電量、資料晶片（經驗）、寶箱（挑一枚晶片）。
## 掉出來後受重力落到地板或平台上；靠近時會被吸過來。

enum Kind { SHARD, ENERGY, XP, CHEST }

const MAGNET_RADIUS := 56.0
const COLLECT_RADIUS := 9.0
const PULL_SPEED := 260.0
const GRAVITY := 700.0
const MAX_FALL_SPEED := 360.0
const SPRITES := {Kind.SHARD: "shard", Kind.ENERGY: "energy", Kind.XP: "xp", Kind.CHEST: "chest"}
const SOUNDS := {Kind.SHARD: "pickup_shard", Kind.ENERGY: "pickup_energy", Kind.XP: "pickup_xp", Kind.CHEST: "chest"}

var kind: Kind = Kind.SHARD
var amount := 1.0
var velocity := Vector2.ZERO
var _t := 0.0
var _pulling := false
var _grounded := false


func _physics_process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.dead:
		var dist := global_position.distance_to(player.global_position)
		if dist < COLLECT_RADIUS:
			_collect()
			return
		var magnet := MAGNET_RADIUS * (1.0 + ClimbState.stat(&"pickup_range"))
		if kind == Kind.CHEST:
			magnet = 20.0
		if dist < magnet or _pulling:
			_pulling = true
			_grounded = false
			velocity = velocity.move_toward(global_position.direction_to(player.global_position) * PULL_SPEED, 900.0 * delta)
			global_position += velocity * delta
			queue_redraw()
			return
	_fall(delta)
	queue_redraw()


## 受重力掉到地板或平台上；撞到牆就停下水平移動
func _fall(delta: float) -> void:
	if _grounded:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	velocity.x = move_toward(velocity.x, 0.0, 60.0 * delta)
	var space := get_world_2d().direct_space_state
	var half := _half_height()
	# 水平：撞牆
	var step_x := Vector2(velocity.x * delta, 0.0)
	if step_x != Vector2.ZERO:
		var wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + step_x + Vector2(signf(step_x.x) * 3.0, 0.0), Layers.TERRAIN))
		if wall.is_empty():
			global_position += step_x
		else:
			velocity.x = 0.0
	# 垂直：往下時單向平台也算地板，往上只會撞到實心天花板
	var step_y := velocity.y * delta
	var mask := Layers.TERRAIN | (Layers.ONEWAY if velocity.y > 0.0 else 0)
	var from := global_position + Vector2(0.0, half if velocity.y > 0.0 else -half)
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, step_y + signf(step_y)), mask))
	if hit.is_empty():
		global_position.y += step_y
	elif velocity.y > 0.0:
		var floor_y: float = hit["position"].y
		global_position.y = floor_y - half
		velocity = Vector2.ZERO
		_grounded = true
	else:
		velocity.y = 0.0


func _half_height() -> float:
	var t := Art.tex(SPRITES[kind])
	return t.get_height() * 0.5 if t else 4.0


func _collect() -> void:
	var game := get_tree().get_first_node_in_group("game") as Game
	Audio.sfx(SOUNDS[kind], -4.0 if kind == Kind.XP else 0.0, 0.08, 0.04)
	match kind:
		Kind.SHARD:
			RunState.add_shards(int(amount))
		Kind.ENERGY:
			RunState.add_energy(amount)
		Kind.XP:
			if game:
				game.gain_xp(int(amount))
		Kind.CHEST:
			if game:
				game.open_chest()
	queue_free()


func _draw() -> void:
	Art.draw(self, SPRITES[kind], 1, 0, Vector2.ZERO)
