class_name Shotgun
extends Weapon
## 霰彈槍：近距離高傷害，擊退可以把獵物推進死角。

const PELLETS := 6
const SPREAD_DEG := 14.0


func _init() -> void:
	id = &"shotgun"
	base_cooldown = 0.65


func _fire(origin: Vector2, aim: Vector2) -> void:
	for i in PELLETS:
		var dir := aim.rotated(deg_to_rad(randf_range(-SPREAD_DEG, SPREAD_DEG)))
		var shot := _shot(origin, dir * randf_range(320.0, 400.0), Color("ffe14d"))
		shot.damage = 0.8 * damage_mult()
		shot.life = 0.28
		shot.knock = 140.0
		_spawn(shot)
