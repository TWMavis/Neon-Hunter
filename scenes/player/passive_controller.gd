class_name PassiveController
extends Node2D
## 非移動類的被動技能：僚機無人機、電漿光環、雷達掃描、護盾產生器。

const AURA_RADIUS := 30.0
const AURA_TICK := 0.4
const AURA_DAMAGE := 0.6
const RADAR_INTERVAL := 6.0
const RADAR_RANGE := 360.0
const RADAR_MARK_TIME := 3.0
const SHIELD_RECHARGE := 12.0

var shield_ready := false
var radar_pulse := 0.0         # 掃描動畫用

var _aura_timer := 0.0
var _radar_timer := 2.0
var _shield_timer := 0.0
var _wingmen: Array[Wingman] = []
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_update_wingmen()

	if ClimbState.has_passive(&"plasma_aura"):
		_aura_timer -= delta
		if _aura_timer <= 0.0:
			_aura_timer = AURA_TICK / (1.0 + ClimbState.skill_stat(&"plasma_aura", &"rate"))
			for node in get_tree().get_nodes_in_group("prey"):
				var prey := node as Prey
				if prey and prey.global_position.distance_to(global_position) < AURA_RADIUS:
					prey.take_damage(AURA_DAMAGE * (1.0 + ClimbState.skill_stat(&"plasma_aura", &"damage")), &"plasma_aura")

	if ClimbState.has_passive(&"radar"):
		_radar_timer -= delta
		radar_pulse = maxf(radar_pulse - delta, 0.0)
		if _radar_timer <= 0.0:
			_radar_timer = RADAR_INTERVAL / (1.0 + ClimbState.skill_stat(&"radar", &"rate"))
			radar_pulse = 0.6
			for node in get_tree().get_nodes_in_group("prey"):
				var prey := node as Prey
				if prey and prey.global_position.distance_to(global_position) < RADAR_RANGE:
					prey.mark(RADAR_MARK_TIME)

	if ClimbState.has_passive(&"shield") and not shield_ready:
		_shield_timer += delta
		if _shield_timer >= SHIELD_RECHARGE / (1.0 + ClimbState.skill_stat(&"shield", &"rate")):
			shield_ready = true
			_shield_timer = 0.0
	queue_redraw()


## 護盾擋下一次傷害
func consume_shield() -> bool:
	if not shield_ready:
		return false
	shield_ready = false
	return true


func _update_wingmen() -> void:
	var want := 0
	if ClimbState.has_passive(&"drone"):
		want = 2 if ClimbState.chip_on(&"drone", &"drone_two") else 1
	while _wingmen.size() < want:
		var w := Wingman.new()
		w.index = _wingmen.size()
		w.owner_player = get_parent() as Player
		w.top_level = true
		w.global_position = global_position
		add_child(w)
		_wingmen.append(w)
	while _wingmen.size() > want:
		_wingmen.pop_back().queue_free()


func _draw() -> void:
	if ClimbState.has_passive(&"plasma_aura"):
		draw_arc(Vector2.ZERO, AURA_RADIUS, 0.0, TAU, 24, Color(1.0, 0.24, 0.94, 0.25 + 0.1 * sin(_t * 6.0)), 1.0)
	if shield_ready:
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 16, Color(0.24, 0.96, 1.0, 0.6), 1.0)
	if radar_pulse > 0.0:
		var k := 1.0 - radar_pulse / 0.6
		draw_arc(Vector2.ZERO, RADAR_RANGE * k, 0.0, TAU, 48, Color(0.49, 1.0, 0.42, 0.5 * (1.0 - k)), 1.0)
