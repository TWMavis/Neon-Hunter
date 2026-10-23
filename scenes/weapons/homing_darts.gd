class_name HomingDarts
extends Weapon
## 追蹤飛鏢：傷害低但會轉彎，專打逃跑中的目標。共鳴「獵犬蜂群」：一次三枚、轉彎更快。


func _init() -> void:
	id = &"homing_darts"
	base_cooldown = 0.28


func _fire(origin: Vector2, aim: Vector2) -> void:
	var swarm := ClimbState.has_synergy(&"hound_swarm")
	var angles: Array[float] = [0.0]
	if swarm:
		angles = [-20.0, 0.0, 20.0]
	for angle in angles:
		var shot := _shot(origin, aim.rotated(deg_to_rad(angle)) * 260.0, Color("7dff6a"))
		shot.damage = 0.8 * damage_mult()
		shot.life = 1.4
		shot.homing = 10.0 if swarm else 6.0
		_spawn(shot)
