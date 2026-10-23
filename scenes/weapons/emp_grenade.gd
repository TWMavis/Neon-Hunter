class_name EmpGrenade
extends Weapon
## EMP 手雷：拋物線投擲，爆炸範圍內的獵物緩速 3 秒。


func _init() -> void:
	id = &"emp_grenade"
	base_cooldown = 4.0
	is_secondary = true


func _fire(origin: Vector2, aim: Vector2) -> void:
	var shot := _shot(origin, aim * 260.0 + Vector2(0.0, -60.0), Color("6aa8ff"))
	shot.kind = Projectile.Kind.GRENADE
	shot.damage = 1.0 * damage_mult()
	shot.life = 1.0
	shot.gravity = 500.0
	shot.radius = 3.0
	_spawn(shot)
