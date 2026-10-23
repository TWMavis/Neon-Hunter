class_name WeaponManager
extends Node2D
## 左鍵 = 主武器（按住連射，負責輸出）；右鍵 = 副武器（冷卻制，負責「抓住」獵物）。
## 武器由這次攀登選的武器決定（ClimbState.primary / secondary）。

const JAM_AFTER := 3.0     # 過熱槍管：連射超過 3 秒卡彈
const JAM_TIME := 1.5
const FIRE_SOUNDS := {
	&"pulse_rifle": "shoot", &"shotgun": "shotgun", &"homing_darts": "dart",
	&"em_net": "net", &"grapple": "hook", &"emp_grenade": "net",
}

var primary: Weapon
var secondary: Weapon
var jam_left := 0.0
var _held := 0.0


func _ready() -> void:
	primary = create(ClimbState.primary)
	secondary = create(ClimbState.secondary)
	add_child(primary)
	add_child(secondary)


static func create(id: StringName) -> Weapon:
	match id:
		&"shotgun":
			return Shotgun.new()
		&"homing_darts":
			return HomingDarts.new()
		&"grapple":
			return Grapple.new()
		&"emp_grenade":
			return EmpGrenade.new()
		&"em_net":
			return EmNet.new()
	return PulseRifle.new()


func _physics_process(delta: float) -> void:
	var player := get_parent() as Player
	if player == null or player.dead:
		return
	var origin := player.global_position + Vector2(0.0, -2.0) + player.aim_dir * 10.0

	jam_left = maxf(jam_left - delta, 0.0)
	if Input.is_action_pressed("attack_primary") and jam_left <= 0.0:
		_held += delta
		if ClimbState.chip_on(primary.id, &"hot_barrel") and _held > JAM_AFTER:
			jam_left = JAM_TIME
			_held = 0.0
		else:
			if primary.try_fire(origin, player.aim_dir):
				Audio.sfx(FIRE_SOUNDS.get(primary.id, "shoot"), -3.0)
	else:
		_held = 0.0
	if Input.is_action_just_pressed("attack_secondary"):
		if secondary.try_fire(origin, player.aim_dir):
			Audio.sfx(FIRE_SOUNDS.get(secondary.id, "net"))
		else:
			Audio.sfx("denied", -6.0)
