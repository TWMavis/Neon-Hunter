class_name WeaponManager
extends Node2D
## 左鍵 = 主武器（按住連射，負責輸出）；右鍵 = 副武器（冷卻制，負責「抓住」獵物）。
## 開場只有小刀、沒有右鍵武器；升級卡、商店拿到槍後換上（ClimbState.primary / secondary）。

const JAM_AFTER := 3.0     # 過熱槍管：連射超過 3 秒卡彈
const JAM_TIME := 1.5
const FIRE_SOUNDS := {
	&"knife": "slash", &"pulse_rifle": "shoot", &"shotgun": "shotgun", &"homing_darts": "dart",
	&"em_net": "net", &"grapple": "hook", &"emp_grenade": "net",
}

var primary: Weapon
var secondary: Weapon
var jam_left := 0.0
var _held := 0.0


func _ready() -> void:
	_sync()
	ClimbState.loadout_changed.connect(_sync)


## 換武器（升級卡、商店）後，重建對應的武器節點
func _sync() -> void:
	if primary == null or primary.id != ClimbState.primary:
		if primary:
			primary.queue_free()
		primary = create(ClimbState.primary)
		add_child(primary)
	var want := ClimbState.secondary
	if (secondary == null and want != &"") or (secondary and secondary.id != want):
		if secondary:
			secondary.queue_free()
		secondary = create(want) if want != &"" else null
		if secondary:
			add_child(secondary)


static func create(id: StringName) -> Weapon:
	match id:
		&"knife":
			return Knife.new()
		&"pulse_rifle":
			return PulseRifle.new()
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
	return Knife.new()


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
				if primary.id != &"knife":
					player.break_stealth()   # 槍聲會解除潛行（小刀自己處理潛行一擊）
	else:
		_held = 0.0
	if Input.is_action_just_pressed("attack_secondary") and secondary:
		if secondary.try_fire(origin, player.aim_dir):
			Audio.sfx(FIRE_SOUNDS.get(secondary.id, "net"))
			player.break_stealth()
		else:
			Audio.sfx("denied", -6.0)
