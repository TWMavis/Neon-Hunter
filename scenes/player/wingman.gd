class_name Wingman
extends Node2D
## 僚機無人機：跟在玩家身邊，自動射擊附近的獵物。

const RANGE := 150.0
const FIRE_INTERVAL := 0.7
const DAMAGE := 0.6

var owner_player: Player
var index := 0
var _cooldown := 0.0
var _t := 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		return
	_t += delta
	var side := -1.0 if index == 0 else 1.0
	var anchor := owner_player.global_position + Vector2(side * 16.0, -20.0 + sin(_t * 3.0 + index) * 3.0)
	global_position = global_position.lerp(anchor, minf(1.0, 8.0 * delta))

	_cooldown -= delta
	if _cooldown <= 0.0 and not owner_player.stealthed:   # 潛行時不開火，免得嚇跑獵物
		var target := _nearest_prey()
		if target:
			_cooldown = FIRE_INTERVAL / (1.0 + ClimbState.skill_stat(&"drone", &"rate"))
			var shot := Projectile.new()
			shot.position = global_position
			shot.velocity = global_position.direction_to(target.global_position) * 380.0
			shot.damage = DAMAGE * (1.0 + ClimbState.skill_stat(&"drone", &"damage"))
			shot.source = &"drone"
			shot.color = Color("ffe14d")
			shot.life = 0.6
			var container := get_tree().get_first_node_in_group("projectiles")
			if container:
				container.add_child(shot)
				Audio.sfx("shoot", -10.0)
	queue_redraw()


func _nearest_prey() -> Prey:
	var best: Prey = null
	var best_d := RANGE
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey and prey.visible:
			var d := prey.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = prey
	return best


func _draw() -> void:
	Art.draw(self, "wingman", 1, 0, Vector2.ZERO)
