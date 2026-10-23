class_name Weapon
extends Node
## 武器基底：處理冷卻與充能次數，子類別實作 _fire()。
## 射速、冷卻、傷害只受插在這把武器上的晶片影響。

var id: StringName
var display_name := ""
var base_cooldown := 0.2
var is_secondary := false
var charges := 1
var _cooldown_left := 0.0


func _ready() -> void:
	display_name = Catalog.item_name(id)
	charges = max_charges()


func _physics_process(delta: float) -> void:
	if charges < max_charges():
		_cooldown_left -= delta
		if _cooldown_left <= 0.0:
			charges += 1
			if charges < max_charges():
				_cooldown_left = cooldown()


func max_charges() -> int:
	return 1


## 只看插在這把武器上的晶片
func cooldown() -> float:
	return base_cooldown / (1.0 + maxf(ClimbState.skill_stat(id, &"rate"), 0.0))


func damage_mult() -> float:
	return 1.0 + ClimbState.skill_stat(id, &"damage")


## 0 = 可以發射，1 = 剛發射完
func cooldown_ratio() -> float:
	if charges >= max_charges():
		return 0.0
	return clampf(_cooldown_left / cooldown(), 0.0, 1.0)


func try_fire(origin: Vector2, aim: Vector2) -> bool:
	if charges <= 0:
		return false
	charges -= 1
	if _cooldown_left <= 0.0:
		_cooldown_left = cooldown()
	_fire(origin, aim)
	return true


func _fire(_origin: Vector2, _aim: Vector2) -> void:
	pass


func _shot(origin: Vector2, velocity: Vector2, color: Color) -> Projectile:
	var shot := Projectile.new()
	shot.position = origin
	shot.velocity = velocity
	shot.color = color
	shot.source = id
	return shot


func _spawn(node: Node2D) -> void:
	var container := get_tree().get_first_node_in_group("projectiles")
	if container:
		container.add_child(node)
