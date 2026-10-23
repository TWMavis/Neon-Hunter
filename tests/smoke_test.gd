extends Node
## 冒煙測試：跑過攀登的主要流程，確認不會出錯而且規則正確。
## 執行：Godot --headless --path . res://tests/smoke_test.tscn

var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_graph()
	await _test_flee()
	await _test_chips()
	await _test_level_up()
	await _test_weapons_and_passives()
	await _test_full_loop()
	await _test_vault_and_danger()
	await _test_boss()
	await _test_hunter()
	await _test_menus()
	await _test_overclock()
	await _test_chip_menu()
	await _test_shop()
	await _test_pickup_falls()
	await _test_counterattacks()
	await _test_knife_start()
	print("SMOKE TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures += 1


func _new_game(floor_index := 0, floor_type := &"normal") -> Game:
	get_tree().paused = false
	ClimbState.floor_index = floor_index
	ClimbState.floor_type = floor_type
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	game.auto_advance = false
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	await _frames(10)
	return game


func _end(game: Game) -> void:
	get_tree().paused = false
	game.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _prey_of(game: Game, kind: Prey.Kind) -> Prey:
	for node in game.get_tree().get_nodes_in_group("prey"):
		var p := node as Prey
		if p and p.kind == kind and not p.is_queued_for_deletion():
			return p
	return null


func _test_graph() -> void:
	print("platform graph:")
	for map in Section1Maps.floors() + [Section1Maps.boss()]:
		var graph := PlatformGraph.new()
		graph.build(map["blocks"], map["width"], map["height"])
		var start := graph.nearest_node(Vector2(map["elevator_x"] * 16 + 8, (map["height"] - 1) * 16 - 10))
		graph.compute_from(graph.node_position(start))
		var reachable := 0
		for d in graph.dist:
			if d < INF:
				reachable += 1
		_check(reachable > graph.node_count() * 0.9, "%s: %d / %d nodes reachable from the elevator" % [map["name"], reachable, graph.node_count()])


func _test_flee() -> void:
	print("flee:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	var game := await _new_game()
	await _frames(30)
	var rat: Prey = null
	for node in game.get_tree().get_nodes_in_group("prey"):
		var p := node as Prey
		if p.kind == Prey.Kind.RAT and p.is_on_floor():
			rat = p
			break
	_check(rat != null, "found a grounded rat")
	if rat:
		game.player.global_position = rat.global_position + Vector2(40, -6)
		game.level.graph.compute_from(game.player.global_position)
		var before := rat.global_position.distance_to(game.player.global_position)
		await _frames(45)
		var after := rat.global_position.distance_to(game.player.global_position)
		_check(rat.state != Prey.State.WANDER, "rat noticed the player (state %d)" % rat.state)
		_check(after > before, "rat ran away using the nav graph (%.0f -> %.0f px)" % [before, after])
	await _end(game)


func _test_chips() -> void:
	print("chips:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	for id: StringName in [&"overclock", &"pierce", &"glass_cannon", &"magnet", &"heatsink", &"twin_hook"]:
		ClimbState.owned[id] = 0
	var rifle := &"pulse_rifle"
	_check(ClimbState.equip(&"overclock", rifle), "equip overclock on the rifle (2/3)")
	_check(ClimbState.equip(&"pierce", rifle), "equip pierce while 1 slot left -> rifle overloaded (4/3)")
	_check(ClimbState.skill_overloaded(rifle) and ClimbState.is_overloaded(), "rifle overloaded")
	_check(not ClimbState.equip(&"glass_cannon", rifle), "cannot equip on a full skill")
	_check(ClimbState.equip(&"magnet", &"em_net"), "the net has its own separate capacity")
	_check(not ClimbState.skill_overloaded(&"em_net"), "net is not overloaded")
	_check(ClimbState.has_synergy(&"railgun"), "railgun synergy active")
	_check(ClimbState.discovered.has(&"railgun"), "railgun recorded as discovered")
	_check(is_equal_approx(ClimbState.skill_stat(rifle, &"rate"), 0.2), "rifle rate = 0.2")
	_check(is_equal_approx(ClimbState.skill_stat(&"em_net", &"rate"), 0.0), "chips on the rifle do not boost the net")
	_check(is_equal_approx(ClimbState.stat(&"pickup_range"), 0.5), "body chip (magnet) works from any skill")
	_check(not ClimbState.equip(&"overclock", &"em_net"), "overclock does not fit the net")
	_check(ClimbState.equip(&"heatsink", &"em_net"), "heatsink fits the net")
	_check(not ClimbState.equip(&"twin_hook", rifle), "exclusive chip needs its own weapon")
	ClimbState.unequip(&"pierce")
	_check(not ClimbState.has_synergy(&"railgun"), "railgun off after unequipping pierce")
	_check(ClimbState.move(&"magnet", rifle), "move magnet from the net to the rifle")
	_check(ClimbState.slot_of[&"magnet"] == rifle and ClimbState.used(&"em_net") == 2, "magnet moved, net capacity freed")
	_check(not ClimbState.move(&"heatsink", rifle), "move fails when the chip does not fit")
	_check(ClimbState.slot_of.get(&"heatsink") == &"em_net", "failed move keeps the chip where it was")
	for id: StringName in [&"dash_cap", &"sprint_motor", &"ghost"]:
		ClimbState.owned[id] = 0
	_check(not ClimbState.equip(&"dash_cap", rifle), "movement chip does not fit a weapon")
	_check(ClimbState.equip(&"dash_cap", Catalog.MOVEMENT), "movement chip fits the movement slot")
	_check(ClimbState.equip(&"sprint_motor", Catalog.MOVEMENT) and ClimbState.used(Catalog.MOVEMENT) == 3, "movement slot has its own capacity (3/3)")
	_check(is_equal_approx(ClimbState.skill_stat(Catalog.MOVEMENT, &"dash_charges"), 1.0), "dash charges read from the movement slot")
	_check(ClimbState.best_skill_for(&"ghost") == &"", "no room left for ghost in the movement slot")
	ClimbState.owned[&"overclock"] = 2
	ClimbState._refresh()
	_check(is_equal_approx(ClimbState.skill_stat(rifle, &"rate"), 0.4), "overclock +2 doubles its effect")


func _test_level_up() -> void:
	print("level up:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	var game := await _new_game()
	game.gain_xp(ClimbState.xp_to_next())
	await _frames(2)
	_check(ClimbState.level == 2, "reached level 2")
	_check(game.picker.visible and get_tree().paused, "level-up picker open and game paused")
	game.picker._choose(0)
	await _frames(2)
	var gained := ClimbState.owned.size() + ClimbState.passives.size()
	_check(gained == 1, "picked card gave a chip or passive")
	_check(not get_tree().paused, "game resumes after picking")
	game.open_chest()
	await _frames(2)
	_check(game.picker.visible, "chest opens a chip picker")
	game.picker._choose(0)
	await _frames(2)
	for i in 4:
		ClimbState.add_xp(ClimbState.xp_to_next())
	_check(ClimbState.total_capacity == 9 + 5, "total chip capacity +1 per level (now %d at Lv %d)" % [ClimbState.total_capacity, ClimbState.level])
	_check(ClimbState.adjust_capacity(&"em_net", 1) and ClimbState.capacity_of(&"em_net") == 4, "allocate a point to the net")
	_check(ClimbState.adjust_capacity(&"em_net", -1), "take it back")
	ClimbState.total_capacity = ClimbState.allocated_total()
	_check(not ClimbState.adjust_capacity(&"em_net", 1), "cannot exceed the total capacity")
	await _end(game)


func _test_weapons_and_passives() -> void:
	print("weapons and passives:")
	var combos := [[&"pulse_rifle", &"em_net"], [&"shotgun", &"grapple"], [&"homing_darts", &"emp_grenade"]]
	for combo: Array in combos:
		ClimbState.new_climb(combo[0], combo[1])
		for id: StringName in Catalog.PASSIVES:
			ClimbState.passives.append(id)
		for id: StringName in Catalog.chips():
			ClimbState.owned[id] = 1
		ClimbState.total_capacity = 999
		for skill in ClimbState.skills():
			ClimbState.allocation[skill] = 99
		for id: StringName in Catalog.chips():
			var skill := ClimbState.best_skill_for(id)
			if skill != &"":
				ClimbState.equip(id, skill)
		var game := await _new_game()
		var kills_before := RunState.kills
		for i in 120:
			var target := _prey_of(game, Prey.Kind.RAT)
			if target:
				game.player.global_position = target.global_position + Vector2(-50, -4)
				var aim := game.player.global_position.direction_to(target.global_position)
				game.player.weapons.primary.try_fire(game.player.global_position, aim)
				if i % 30 == 0:
					game.player.weapons.secondary.try_fire(game.player.global_position, aim)
			await _frames(1)
		_check(RunState.kills > kills_before, "%s + %s kill prey with every chip and passive on (%d kills)" % [combo[0], combo[1], RunState.kills])
		await _end(game)


func _test_full_loop() -> void:
	print("full loop:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	var game := await _new_game(0, &"black_market")
	var guard := 0
	while not RunState.quota_met() and guard < 30:
		guard += 1
		for node in game.get_tree().get_nodes_in_group("prey"):
			(node as Prey).take_damage(1000.0)
		await _frames(3)
		for node in game._pickups.get_children():
			(node as Node2D).global_position = game.player.global_position
		await _frames(3)
		while game.picker.visible:
			game.picker._choose(0)
			await _frames(2)
		game._respawn_timer = 0.0
		await _frames(20)
	_check(RunState.quota_met(), "quota met (%d / %d shards, %d kills, Lv %d)" % [RunState.shards, RunState.quota, RunState.kills, ClimbState.level])
	game.player.global_position = game.elevator.global_position + Vector2(0, -12)
	await _frames(3)
	Input.action_press("move_up")
	await _frames(2)
	Input.action_release("move_up")
	await _frames(2)
	_check(RunState.cleared, "elevator clears the floor")
	_check(ClimbState.bonus_chip_pick, "black market floor grants a chip pick")
	await _end(game)


func _test_vault_and_danger() -> void:
	print("floor types:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	var game := await _new_game(1, &"vault")
	await _frames(5)
	_check(_prey_of(game, Prey.Kind.GOLDEN) != null and _prey_of(game, Prey.Kind.RAT) == null, "vault has only golden prey")
	_check(RunState.quota_met(), "vault elevator open from the start")
	await _end(game)
	game = await _new_game(3, &"danger")
	_check(game.floor_data.rat_count > 9 and game.floor_data.replicator_count > 0, "danger floor 4 has more rats and replicators")
	var rep := _prey_of(game, Prey.Kind.REPLICATOR)
	if rep:
		rep.split_time = 0.01
		await _frames(5)
		var count: int = game._count_kinds().get(Prey.Kind.REPLICATOR, 0)
		_check(count >= 3, "replicator split (%d replicators)" % count)
	await _end(game)


func _test_boss() -> void:
	print("boss:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	var game := await _new_game(4, &"normal")
	_check(is_instance_valid(game.boss), "boss spawned on floor 5")
	if is_instance_valid(game.boss):
		var boss := game.boss
		boss.take_damage(boss.max_hp * 0.3)
		await _frames(2)
		_check(boss.state == Prey.State.BURROWED and not boss.visible, "boss burrows after losing 25% hp")
		await _frames(int(Prey.BURROW_TIME * 60) + 10)
		_check(boss.visible and boss.state != Prey.State.BURROWED, "boss resurfaces from a junk pile")
		var cap := ClimbState.total_capacity
		for i in 10:
			if is_instance_valid(boss) and boss.state != Prey.State.BURROWED:
				boss.take_damage(1000.0)
			await _frames(int(Prey.BURROW_TIME * 60) + 10)
			if not is_instance_valid(boss):
				break
		_check(not is_instance_valid(boss), "boss killed")
		_check(ClimbState.total_capacity == cap + 1, "core chip: total chip capacity +1")
	await _end(game)


func _test_hunter() -> void:
	print("purge + hunter:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	var game := await _new_game()
	RunState.elapsed = game.floor_data.hunter_spawn_time - 0.05
	await _frames(5)
	_check(game.purge_active, "purge protocol active")
	_check(is_instance_valid(game.hunter), "hunter spawned")
	if is_instance_valid(game.hunter):
		var before := game.hunter.global_position.distance_to(game.player.global_position)
		await _frames(30)
		var after := game.hunter.global_position.distance_to(game.player.global_position)
		_check(after < before, "hunter closes in (%.0f -> %.0f px)" % [before, after])
	await _end(game)


func _test_menus() -> void:
	print("menus:")
	ClimbState.new_climb(&"shotgun", &"grapple")
	ClimbState.owned[&"magnet"] = 0
	ClimbState.owned[&"twin_hook"] = 1
	ClimbState.bonus_chip_pick = true
	var elevator: Control = load("res://scenes/elevator/elevator_scene.tscn").instantiate()
	add_child(elevator)
	await _frames(3)
	_check(elevator.get("_route_box").get_child_count() == 2, "elevator offers two routes")
	_check((elevator.get("_picker") as CardPicker).visible, "black market pick shown in the elevator")
	elevator.queue_free()
	ClimbState.floor_index = 3
	elevator = load("res://scenes/elevator/elevator_scene.tscn").instantiate()
	add_child(elevator)
	await _frames(3)
	_check(elevator.get("_route_box").get_child_count() == 1, "only the boss route before floor 5")
	elevator.queue_free()
	var start: Control = load("res://scenes/menu/climb_start.tscn").instantiate()
	add_child(start)
	await _frames(3)
	_check(start.get_child_count() > 0, "climb start menu builds")
	start.queue_free()
	await _frames(2)


func _test_overclock() -> void:
	print("overclock:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	var game := await _new_game()
	RunState.add_energy(-1000.0)
	_check(RunState.overclocked and not RunState.finished, "energy 0 -> overclock instead of death")
	_check(ClimbState.overclock_charges == 2, "used 1 of 3 overclock charges")
	var rat := _prey_of(game, Prey.Kind.RAT)
	if rat:
		var hp := rat.hp
		rat.take_damage(0.5)
		_check(is_equal_approx(hp - rat.hp, 1.0), "damage doubled during overclock")
	RunState.add_energy(1.0)
	await _frames(int(RunState.OVERCLOCK_TIME * 60) + 10)
	_check(not RunState.overclocked and not RunState.finished, "survived: energy above 0 when the countdown ended")
	RunState.add_energy(-1000.0)
	_check(RunState.overclocked, "second overclock")
	await _frames(int(RunState.OVERCLOCK_TIME * 60) + 10)
	_check(RunState.finished, "real death: energy still 0 when the countdown ended")
	await _end(game)

	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	game = await _new_game()
	ClimbState.overclock_charges = 0
	RunState.add_energy(-1000.0)
	_check(RunState.finished, "no charges left -> energy 0 is instant death")
	await _end(game)

	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	game = await _new_game()
	ClimbState.overclock_charges = 1
	RunState.energy = RunState.max_energy
	RunState.add_energy(60.0)
	_check(is_equal_approx(ClimbState.overclock_bar, 60.0), "energy over the max fills the overclock bar (60)")
	RunState.energy = RunState.max_energy
	RunState.add_energy(50.0)
	_check(ClimbState.overclock_charges == 2 and is_equal_approx(ClimbState.overclock_bar, 10.0), "full bar restores one charge")
	ClimbState.overclock_charges = 3
	RunState.add_energy(500.0)
	_check(ClimbState.overclock_charges == 3 and ClimbState.overclock_bar <= ClimbState.OVERCLOCK_BAR_MAX, "charges cap at 3")
	await _end(game)


func _test_chip_menu() -> void:
	print("tab chip menu:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	ClimbState.owned[&"magnet"] = 0
	var game := await _new_game()
	var before := RunState.energy
	Input.action_press("chip_menu")
	await _frames(15)
	_check(not game.chip_menu.visible, "a short Tab press does not open the chip page")
	await _frames(30)
	_check(game.chip_menu.visible and get_tree().paused, "holding Tab opens the chip page and pauses")
	_check(is_equal_approx(before - RunState.energy, RunState.max_energy * 0.1) or before - RunState.energy > RunState.max_energy * 0.09, "opening costs 10%% energy (%.1f -> %.1f)" % [before, RunState.energy])
	Input.action_release("chip_menu")
	_check(ClimbState.equip(&"magnet", &"em_net"), "can rearrange chips while open")
	game.chip_menu.close_menu()
	await _frames(3)
	_check(not game.chip_menu.visible and not get_tree().paused, "closing resumes the game")
	RunState.energy = RunState.max_energy * 0.05
	Input.action_press("chip_menu")
	await _frames(45)
	Input.action_release("chip_menu")
	_check(not game.chip_menu.visible, "not enough energy -> page does not open")
	await _end(game)


func _test_shop() -> void:
	print("shop:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	ClimbState.open_shop()
	_check(ClimbState.shop_stock.size() == ClimbState.SHOP_SIZE, "shop stocks %d chips" % ClimbState.SHOP_SIZE)
	var id: StringName = ClimbState.shop_stock[0]
	_check(ClimbState.buy(id) == "", "cannot buy without credits")
	ClimbState.credits = 1000
	var price := ClimbState.chip_price(id)
	_check(ClimbState.buy(id) != "" and ClimbState.owned.has(id) and ClimbState.credits == 1000 - price, "buy a new chip (%s, %d)" % [id, price])
	_check(not ClimbState.shop_stock.has(id), "bought chip leaves the stock")
	ClimbState.shop_stock.append(id)
	ClimbState.buy(id)
	_check(ClimbState.chip_plus(id) == 1, "buying a duplicate upgrades it to +1")
	var before := ClimbState.credits
	_check(ClimbState.upgrade_price(id) == ceili(price * 1.5), "direct upgrade costs 1.5x the price")
	ClimbState.upgrade_direct(id)
	_check(ClimbState.chip_plus(id) == 2 and ClimbState.credits == before - ceili(price * 1.5), "direct upgrade to +2")
	_check(not ClimbState.can_upgrade_direct(id), "cannot upgrade past +2")
	ClimbState.open_shop()
	_check(not ClimbState.shop_stock.has(id), "maxed chips are not sold")
	before = ClimbState.credits
	var cost := ClimbState.reroll_price()
	_check(ClimbState.reroll_shop() and ClimbState.credits == before - cost, "reroll costs %d" % cost)
	_check(ClimbState.reroll_price() > cost, "rerolling again costs more")
	ClimbState.credits = 0
	_check(not ClimbState.reroll_shop(), "cannot reroll without credits")
	var game := await _new_game()
	var rat := _prey_of(game, Prey.Kind.RAT)
	if rat:
		rat.take_damage(1000.0)
		await _frames(2)
		_check(ClimbState.credits == 3, "killing a rat gives 3 credits")
	await _end(game)


func _test_pickup_falls() -> void:
	print("pickups fall:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	var game := await _new_game()
	var floor_y := game.elevator.global_position.y   # 地面表面
	game.player.global_position = game.elevator.global_position + Vector2(400, -12)
	var drop := Pickup.new()
	drop.kind = Pickup.Kind.SHARD
	drop.position = game.elevator.global_position + Vector2(-60, -70)
	drop.velocity = Vector2(30, -80)
	game._pickups.add_child(drop)
	await _frames(90)
	var bottom := drop.global_position.y + 4.5
	_check(absf(bottom - floor_y) < 1.5, "dropped shard lands on the floor (bottom %.1f, floor %.1f)" % [bottom, floor_y])
	var y_before := drop.global_position.y
	await _frames(20)
	_check(is_equal_approx(drop.global_position.y, y_before), "stays put on the floor")
	await _end(game)


## 把一隻獵物放在玩家旁邊、讓牠進入逃跑狀態
func _place_prey(game: Game, kind: Prey.Kind, offset: Vector2) -> Prey:
	var prey := game._spawn_prey(kind, game.player.global_position + offset)
	await _frames(2)
	prey.player = game.player
	return prey


func _test_counterattacks() -> void:
	print("counterattacks:")
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	ClimbState.floor_index = 0
	get_tree().paused = false
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	game.auto_advance = false
	game.map_override = Section1Maps.floors()[0]
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	await _frames(10)
	for node in game._enemies.get_children():
		node.queue_free()
	game.floor_data.rat_count = 0
	game.floor_data.drone_count = 0
	game.player.global_position = game.elevator.global_position + Vector2(-60, -12)
	await _frames(5)

	var kiter := await _place_prey(game, Prey.Kind.KITER, Vector2(160, 0))
	kiter._attack_timer = 0.0
	await _frames(5)
	_check(game.get_tree().get_nodes_in_group("projectiles")[0].get_children().any(func(n: Node) -> bool: return n is EnemyShot), "kiter fires at the player")
	kiter.queue_free()
	var before := RunState.energy
	await _frames(70)
	_check(RunState.energy < before - 5.0, "kiter shot hits (%.0f -> %.0f)" % [before, RunState.energy])

	var layer := await _place_prey(game, Prey.Kind.MINELAYER, Vector2(60, 0))
	layer._enter(Prey.State.FLEE)
	layer._attack_timer = 0.0
	await _frames(30)
	_check(game.get_tree().get_nodes_in_group("mines").size() >= 1, "minelayer lays mines while fleeing")
	layer.queue_free()
	for m in game.get_tree().get_nodes_in_group("mines"):
		m.queue_free()

	game.player._invuln = 0.0
	var elite := await _place_prey(game, Prey.Kind.ELITE, Vector2(120, 0))
	elite._attack_timer = 0.0
	var wound := false
	for i in 40:
		await _frames(1)
		if elite._windup > 0.0:
			wound = true
			break
	_check(wound, "elite winds up (flashes red) before charging")
	before = RunState.energy
	await _frames(70)
	_check(RunState.energy < before - 10.0, "elite charge hits (%.0f -> %.0f)" % [before, RunState.energy])
	elite.queue_free()

	var rep := await _place_prey(game, Prey.Kind.REPLICATOR, Vector2(40, -30))
	rep.take_damage(1000.0)
	await _frames(3)
	var shards := game.get_tree().get_nodes_in_group("projectiles")[0].get_children().filter(func(n: Node) -> bool: return n is EnemyShot).size()
	_check(shards >= 4, "replicator bursts into shrapnel on death (%d)" % shards)

	var golden := await _place_prey(game, Prey.Kind.GOLDEN, Vector2(30, 0))
	await _frames(3)
	_check(golden.global_position.distance_to(game.player.global_position) > 100.0, "golden prey blinks away when you get close (now %.0f px away)" % golden.global_position.distance_to(game.player.global_position))
	await _end(game)

	ClimbState.floor_index = 4
	game = await _new_game(4)
	game.boss._attack_timer = 0.0
	game.player.global_position = game.boss.global_position + Vector2(-150, 0)
	await _frames(5)
	var lobs := game.get_tree().get_nodes_in_group("projectiles")[0].get_children().filter(func(n: Node) -> bool: return n is EnemyShot and (n as EnemyShot).explode_radius > 0.0).size()
	_check(lobs >= 3, "boss throws 3 exploding junk shots (%d)" % lobs)
	await _end(game)


func _test_knife_start() -> void:
	print("knife start:")
	ClimbState.new_climb()
	_check(ClimbState.primary == &"knife" and ClimbState.secondary == &"", "a new climb starts with only the knife")
	_check(not ClimbState.skills().has(&""), "empty right-click slot is not a skill")
	var cards := ClimbState.roll_level_up_cards()
	_check(cards.any(func(c: Dictionary) -> bool: return c["type"] == "weapon"), "level-up always offers a gun while holding only the knife")
	var game := await _new_game()
	_check(game.player.weapons.primary is Knife and game.player.weapons.secondary == null, "player holds the knife, right click empty")
	var rat := _prey_of(game, Prey.Kind.RAT)
	if rat:
		game.player.global_position = rat.global_position + Vector2(-14, -4)
		var hp := rat.hp
		var aim := game.player.global_position.direction_to(rat.global_position)
		game.player.weapons.primary.try_fire(game.player.global_position + aim * 10.0, aim)
		await _frames(2)
		_check(not is_instance_valid(rat) or rat.hp < hp, "knife slash hits a rat next to you")
	ClimbState.owned[&"kinetic"] = 0
	ClimbState.equip(&"kinetic", &"knife")
	ClimbState.apply_card({"type": "weapon", "id": &"shotgun"})
	await _frames(2)
	_check(ClimbState.primary == &"shotgun" and game.player.weapons.primary is Shotgun, "picking a gun card swaps the knife for the shotgun")
	_check(ClimbState.chip_on(&"shotgun", &"kinetic") and ClimbState.capacity_of(&"shotgun") == 3, "chips and capacity move to the new gun")
	ClimbState.apply_card({"type": "weapon", "id": &"em_net"})
	await _frames(2)
	_check(game.player.weapons.secondary is EmNet, "picking a right-click weapon fills the empty slot")
	ClimbState.credits = 100
	ClimbState.open_shop()
	var w := ClimbState.shop_weapon
	_check(w != &"" and w != &"shotgun" and w != &"em_net", "shop sells a weapon you don't have (%s)" % w)
	_check(ClimbState.buy_weapon() != "" and (ClimbState.primary == w or ClimbState.secondary == w), "buy the weapon from the shop")
	await _end(game)
