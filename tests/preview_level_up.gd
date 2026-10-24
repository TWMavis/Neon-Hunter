extends Node
## 預覽升級畫面（錄畫面用）：Godot --path . res://tests/preview_level_up.tscn


func _ready() -> void:
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	if OS.get_cmdline_user_args().has("enemies"):
		# 把每種獵物排在玩家前面，方便截圖
		game.map_override = Section1Maps.floors()[0]
		game.floor_data = load("res://data/floor_1_1.tres").duplicate()
		game.floor_data.rat_count = 0
		game.floor_data.drone_count = 0
	add_child(game)
	if OS.get_cmdline_user_args().has("enemies"):
		var x := 280.0
		for kind in [Prey.Kind.RAT, Prey.Kind.DRONE, Prey.Kind.JUMPER, Prey.Kind.REPLICATOR, Prey.Kind.KITER, Prey.Kind.MINELAYER, Prey.Kind.ELITE, Prey.Kind.GOLDEN]:
			game._spawn_prey(kind, Vector2(x, 528))
			x += 34.0
		game.player.global_position = Vector2(150, 516)
	await get_tree().create_timer(0.3).timeout
	if OS.get_cmdline_user_args().has("stealth"):
		Input.action_press(&"stealth")
		game.player.global_position = game.elevator.global_position + Vector2(-60, -12)
		game._spawn_prey(Prey.Kind.RAT, game.player.global_position + Vector2(60, 10))
		game._spawn_prey(Prey.Kind.KITER, game.player.global_position + Vector2(-60, 8))
		return
	if OS.get_cmdline_user_args().has("settings"):
		game.open_settings()
	elif OS.get_cmdline_user_args().has("fight"):
		for i in 40:
			var target: Prey = null
			for node in get_tree().get_nodes_in_group("prey"):
				var p := node as Prey
				if p and p.kind == Prey.Kind.RAT:
					target = p
					break
			if target:
				game.player.global_position = target.global_position + Vector2(-60, -6)
				for j in 6:
					var aim := game.player.global_position.direction_to(target.global_position) if is_instance_valid(target) else Vector2.RIGHT
					game.player.aim_dir = aim
					game.player.weapons.primary.try_fire(game.player.global_position + aim * 10.0, aim)
					await get_tree().physics_frame
			await get_tree().physics_frame
	elif OS.get_cmdline_user_args().has("chips"):
		ClimbState.owned[&"overclock"] = 0
		ClimbState.owned[&"magnet"] = 0
		ClimbState.equip(&"overclock", &"pulse_rifle")
		ClimbState.add_xp(ClimbState.xp_to_next() * 2)
		game.chip_menu.open_menu()
		get_tree().paused = true
	elif OS.get_cmdline_user_args().has("overclock"):
		RunState.add_energy(-1000.0)
	elif not OS.get_cmdline_user_args().has("enemies") and not OS.get_cmdline_user_args().has("settings") and not OS.get_cmdline_user_args().has("stealth"):
		game.gain_xp(ClimbState.xp_to_next())
