class_name Mine
extends Node2D
## 佈雷者留下的地雷：放下 0.6 秒後啟動，玩家靠近就爆炸；15 秒後自己消失。衝刺中無敵可以安全穿過。

const ARM_TIME := 0.6
const TRIGGER_RADIUS := 16.0
const BLAST_RADIUS := 26.0
const DAMAGE := 12.0
const LIFETIME := 15.0

var _t := 0.0


func _ready() -> void:
	add_to_group("mines")


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	if _t >= ARM_TIME:
		var player := get_tree().get_first_node_in_group("player") as Player
		if player and not player.dead and player.global_position.distance_to(global_position) < TRIGGER_RADIUS + 8.0:
			_explode(player)
			return
	queue_redraw()


func _explode(player: Player) -> void:
	Audio.sfx("explode", -4.0)
	if player.global_position.distance_to(global_position) < BLAST_RADIUS + 8.0:
		player.take_hit(DAMAGE, global_position)
	var burst := Burst.new()
	burst.position = global_position
	burst.color = Color("ff9a2b")
	burst.max_radius = BLAST_RADIUS
	get_parent().add_child(burst)
	queue_free()


func _draw() -> void:
	Art.draw(self, "mine", 1, 0, Vector2(0, -2))
	var armed := _t >= ARM_TIME
	var blink := int(_t * (8.0 if armed else 3.0)) % 2 == 0
	if blink:
		draw_rect(Rect2(-1, -5, 2, 1), Color("ff2244") if armed else Color("7a0a1c"))
