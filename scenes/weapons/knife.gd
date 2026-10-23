class_name Knife
extends Weapon
## 小刀：開場唯一的武器。朝準心方向揮出一道弧形斬擊，範圍內的獵物都會被砍到並擊退。

const REACH := 26.0
const ARC_DOT := 0.25          # 跟準心方向的夾角小於約 75 度才砍得到
const DAMAGE := 2.0


func _init() -> void:
	id = &"knife"
	base_cooldown = 0.32


func _fire(origin: Vector2, aim: Vector2) -> void:
	var center := origin - aim * 6.0   # 從手的位置算起
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not prey.visible:
			continue
		var to_prey := prey.global_position - center
		if to_prey.length() > REACH + prey.size.x * 0.5 or aim.dot(to_prey.normalized()) < ARC_DOT:
			continue
		prey.take_damage(DAMAGE * damage_mult(), id)
		if is_instance_valid(prey):
			prey.knockback(aim * 120.0)
	var slash := Slash.new()
	slash.position = center
	slash.rotation = aim.angle()
	slash.radius = REACH
	_spawn(slash)
