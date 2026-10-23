class_name PulseRifle
extends Weapon
## 脈衝步槍：中距離連射，最平衡。共鳴「軌道槍」：無限貫穿、彈速與傷害大增。

const SPEED := 430.0
const SPREAD_DEG := 3.0


func _init() -> void:
	id = &"pulse_rifle"
	base_cooldown = 0.12


func cooldown() -> float:
	return super() * (1.2 if ClimbState.has_synergy(&"railgun") else 1.0)


func _fire(origin: Vector2, aim: Vector2) -> void:
	var railgun := ClimbState.has_synergy(&"railgun")
	var dir := aim.rotated(deg_to_rad(randf_range(-SPREAD_DEG, SPREAD_DEG)))
	var shot := _shot(origin, dir * (620.0 if railgun else SPEED), Color.WHITE if railgun else Color("3df5ff"))
	shot.damage = damage_mult() * (1.5 if railgun else 1.0)
	shot.pierce = 99 if railgun else int(ClimbState.skill_stat(id, &"pierce"))
	shot.trail = 10.0 if railgun else 5.0
	shot.life = 0.7
	_spawn(shot)
