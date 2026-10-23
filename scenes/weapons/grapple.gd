class_name Grapple
extends Weapon
## 鉤爪砲：打中獵物把牠拉過來；打中牆壁把自己拉過去（追擊和移動兩用）。雙鉤：可以連續發射兩次。


func _init() -> void:
	id = &"grapple"
	base_cooldown = 2.2
	is_secondary = true


func max_charges() -> int:
	return 2 if ClimbState.chip_on(id, &"twin_hook") else 1


func _fire(origin: Vector2, aim: Vector2) -> void:
	var shot := _shot(origin, aim * 520.0, Color("3df5ff"))
	shot.kind = Projectile.Kind.HOOK
	shot.damage = 0.5 * damage_mult()
	shot.life = 0.4
	_spawn(shot)
