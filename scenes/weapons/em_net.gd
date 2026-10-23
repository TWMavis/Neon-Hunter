class_name EmNet
extends Weapon
## 電磁網：命中後定身 2 秒（被網住的獵物受到暴擊）。
## 連鎖網：彈到附近 1 個敵人。共鳴「捕獸陣列」：網住的獵物互相吸在一起。

const SPEED := 280.0
const STUN_TIME := 2.0


func _init() -> void:
	id = &"em_net"
	base_cooldown = 3.0
	is_secondary = true


func _fire(origin: Vector2, aim: Vector2) -> void:
	var shot := _shot(origin, aim * SPEED, Color("ff3df0"))
	shot.kind = Projectile.Kind.NET
	shot.damage = 0.0
	shot.life = 0.8
	shot.radius = 4.0
	shot.stun_time = STUN_TIME
	shot.catch_radius = 14.0
	_spawn(shot)
