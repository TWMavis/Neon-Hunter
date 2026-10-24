class_name Game
extends Node2D
## 一層樓：電梯門打開 → 獵殺湊權限碎片 → 電梯解鎖 → 清除協議警報 → 追獵者出現。
## 樓層編號與類型（一般／危險／維修／黑市／金庫／Boss）來自 ClimbState，會修改基礎參數。

const NORMAL_TINT := Color(0.85, 0.85, 1.0)
const PURGE_TINT := Color(1.0, 0.35, 0.4)
const OVERCLOCK_TINT := Color(1.0, 0.75, 0.3)
const TAB_HOLD_TIME := 0.5
const FLOOR_CLEAR_CREDITS := 20
const STEALTH_DRAIN_MULT := 0.5
const SPAWN_MIN_DISTANCE := 200.0
const GRAPH_UPDATE_INTERVAL := 0.3
const MAX_REPLICATORS := 10
const ELEVATOR_SCENE := "res://scenes/elevator/elevator_scene.tscn"

@export var floor_data: FloorData     ## 基礎參數（每層會複製一份再修改）

var auto_advance := true               # 通關後自動切到電梯（測試時關掉）
var map_override: Dictionary = {}     # 指定地圖（測試用）；空的就照樓層隨機抽
var level: Level
var player: Player
var elevator: Elevator
var hunter: Hunter
var boss: Prey
var hud: Hud
var picker: CardPicker
var chip_menu: ChipMenu
var settings: SettingsPanel
var tab_hold := 0.0                    # 長按 Tab 的進度（秒）；-1 代表要先放開才能再按
var purge_active := false

var _enemies: Node2D
var _pickups: Node2D
var _tint: CanvasModulate
var _respawn_timer := 0.0
var _graph_timer := 0.0
var _golden_spawned := false
var _elite_spawned := false
var _base_energy_max := 100.0
var _pending_picks: Array[String] = []    # "level" 或 "chest"


func _ready() -> void:
	add_to_group("game")
	floor_data = _build_floor_data(floor_data if floor_data else FloorData.new())
	RunState.reset(floor_data)
	_base_energy_max = floor_data.energy_max
	_apply_energy_max()
	RunState.player_died.connect(_on_player_died)
	RunState.floor_cleared.connect(_on_floor_cleared)
	RunState.overclock_started.connect(_on_overclock_started)
	RunState.overclock_ended.connect(_on_overclock_ended)
	ClimbState.loadout_changed.connect(_apply_energy_max)
	ClimbState.synergy_discovered.connect(_on_synergy_discovered)
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	Audio.music("music_hunt")

	var parallax := Parallax2D.new()
	parallax.scroll_scale = Vector2(0.35, 0.35)
	parallax.add_child(CityBackground.new())
	add_child(parallax)

	_tint = CanvasModulate.new()
	_tint.color = NORMAL_TINT
	add_child(_tint)

	level = Level.new()
	var maps := Section1Maps.floors()
	if not map_override.is_empty():
		level.setup(map_override)
	else:
		level.setup(Section1Maps.boss() if ClimbState.is_boss_floor() else maps.pick_random())
	add_child(level)

	elevator = Elevator.new()
	elevator.position = level.elevator_position()
	add_child(elevator)

	_pickups = Node2D.new()
	add_child(_pickups)
	_enemies = Node2D.new()
	add_child(_enemies)

	player = Player.new()
	player.position = elevator.position + Vector2(0, -12)
	add_child(player)
	var map_size := level.size_px()
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = int(map_size.x)
	player.camera.limit_bottom = int(map_size.y)
	level.graph.compute_from(player.global_position)

	var shots := Node2D.new()
	shots.add_to_group("projectiles")
	add_child(shots)

	var rain_layer := CanvasLayer.new()
	rain_layer.layer = 1
	rain_layer.add_child(Rain.new())
	add_child(rain_layer)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud = Hud.new()
	hud.game = self
	hud_layer.add_child(hud)
	picker = CardPicker.new()
	picker.picked.connect(_on_card_picked)
	hud_layer.add_child(picker)
	settings = SettingsPanel.new()
	settings.closed.connect(_resume.call_deferred)
	hud_layer.add_child(settings)
	chip_menu = ChipMenu.new()
	chip_menu.closed.connect(_on_chip_menu_closed)
	hud_layer.add_child(chip_menu)
	add_child(hud_layer)

	_initial_spawn()


func _build_floor_data(base: FloorData) -> FloorData:
	var data := base.duplicate() as FloorData
	var index := ClimbState.floor_index
	data.floor_type = ClimbState.floor_type
	data.quota = base.quota + index * 2
	if index >= 1:
		data.jumper_count = 2 + index
		data.kiter_count = 2
	if index >= 2:
		data.replicator_count = 2
		data.minelayer_count = 2
	if ClimbState.is_boss_floor():
		data.floor_type = &"boss"
		data.quota = 1
		data.rat_count = 4
		data.drone_count = 2
		data.jumper_count = 0
		data.replicator_count = 0
		data.kiter_count = 0
		data.minelayer_count = 0
		data.golden_count = 0
		data.elite_spawn_time = -1.0
		return data
	match data.floor_type:
		&"danger":
			data.rat_count = int(data.rat_count * 1.5)
			data.drone_count += 2
			data.jumper_count += 2
			data.kiter_count += 1
			data.minelayer_count += 1
			data.prey_speed_mult = 1.15
			data.xp_mult = 1.5
			data.elite_spawn_time = 60.0
		&"repair":
			data.quota = int(data.quota * 0.6)
			data.energy_drain *= 0.5
		&"vault":
			# 金庫層：全是金色獵物，限時內抓到幾隻就拿幾隻的獎勵
			data.quota = 0
			data.rat_count = 0
			data.drone_count = 0
			data.jumper_count = 0
			data.replicator_count = 0
			data.kiter_count = 0
			data.minelayer_count = 0
			data.golden_count = 6
			data.golden_spawn_time = 0.0
			data.elite_spawn_time = -1.0
			data.purge_warning_time = 60.0
			data.hunter_spawn_time = 80.0
	return data


func _initial_spawn() -> void:
	for _i in floor_data.rat_count:
		_spawn_prey(Prey.Kind.RAT)
	for _i in floor_data.drone_count:
		_spawn_prey(Prey.Kind.DRONE)
	for _i in floor_data.jumper_count:
		_spawn_prey(Prey.Kind.JUMPER)
	for _i in floor_data.kiter_count:
		_spawn_prey(Prey.Kind.KITER)
	for _i in floor_data.minelayer_count:
		_spawn_prey(Prey.Kind.MINELAYER)
	for _i in floor_data.replicator_count:
		_spawn_prey(Prey.Kind.REPLICATOR)
	match floor_data.floor_type:
		&"boss":
			boss = _spawn_prey(Prey.Kind.BOSS, _farthest_point_from_player())
			boss.burrow_points = level.junk_positions()
			boss.resurfaced.connect(_on_boss_resurfaced)
			hud.announce("回收巨獸在垃圾堆裡！打倒牠取回核心晶片")
		&"vault":
			hud.announce("金庫層：抓到幾隻金色獵物就拿幾個寶箱")
		_:
			hud.announce("獵殺流氓 AI，收集 %d 個權限碎片" % floor_data.quota)


## 長按 Tab 打開晶片頁面（避免誤觸）
func _process(delta: float) -> void:
	if RunState.finished or picker.visible or chip_menu.visible or settings.visible:
		return
	if not Input.is_action_pressed("chip_menu"):
		tab_hold = 0.0
		return
	if tab_hold < 0.0:
		return  # 上次打開或關閉後還沒放開
	tab_hold += delta
	if tab_hold >= TAB_HOLD_TIME:
		tab_hold = -1.0
		if chip_menu.open_menu():
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			hud.announce("電量不足，無法調整晶片（需要 %d%% 電量）" % int(ChipMenu.COST_RATIO * 100))


func _on_chip_menu_closed() -> void:
	tab_hold = -1.0
	_resume.call_deferred()


## Esc：暫停遊戲並打開設定畫面
func open_settings() -> void:
	if picker.visible or chip_menu.visible or settings.visible:
		return
	get_tree().paused = true
	settings.open()


func _resume() -> void:
	if RunState.finished or picker.visible or chip_menu.visible or settings.visible:
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN


func _physics_process(delta: float) -> void:
	if RunState.finished:
		return
	RunState.elapsed += delta
	RunState.tick(delta)
	if RunState.finished:
		return
	var drain := floor_data.energy_drain * maxf(1.0 + ClimbState.stat(&"energy_drain"), 0.2)
	if ClimbState.is_overloaded():
		drain *= 2.0  # 超載：電量消耗加倍
	if player.stealthed:
		drain *= STEALTH_DRAIN_MULT  # 潛行：電量消耗減半
	if not RunState.overclocked:
		RunState.add_energy(-drain * delta)  # 超頻中電量不會自然消耗

	_graph_timer -= delta
	if _graph_timer <= 0.0:
		_graph_timer = GRAPH_UPDATE_INTERVAL
		level.graph.compute_from(player.global_position)

	_maintain_population(delta)
	_update_timeline()


func _maintain_population(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_timer > 0.0:
		return
	_respawn_timer = floor_data.respawn_delay
	var counts := _count_kinds()
	var wanted := {
		Prey.Kind.RAT: floor_data.rat_count,
		Prey.Kind.DRONE: floor_data.drone_count,
		Prey.Kind.JUMPER: floor_data.jumper_count,
		Prey.Kind.KITER: floor_data.kiter_count,
		Prey.Kind.MINELAYER: floor_data.minelayer_count,
	}
	for kind: Prey.Kind in wanted:
		if counts.get(kind, 0) < wanted[kind]:
			_spawn_prey(kind)
			return


func _count_kinds() -> Dictionary:
	var counts := {}
	for node in _enemies.get_children():
		var prey := node as Prey
		if prey and not prey.is_queued_for_deletion():
			counts[prey.kind] = counts.get(prey.kind, 0) + 1
	return counts


func _update_timeline() -> void:
	var t := RunState.elapsed
	if not _golden_spawned and floor_data.golden_count > 0 and t >= floor_data.golden_spawn_time:
		_golden_spawned = true
		for _i in floor_data.golden_count:
			_spawn_prey(Prey.Kind.GOLDEN)
		if floor_data.floor_type != &"vault":
			hud.announce("金色獵物出現！限時內抓到牠")
			Audio.sfx("golden")
	if not _elite_spawned and floor_data.elite_spawn_time >= 0.0 and t >= floor_data.elite_spawn_time:
		_elite_spawned = true
		_spawn_prey(Prey.Kind.ELITE)
		hud.announce("精英：裝甲運輸車（掉寶箱）")
	if not purge_active and t >= floor_data.purge_warning_time:
		purge_active = true
		hud.announce("清除協議啟動，快回電梯！")
		Audio.sfx("purge")
		Audio.music_pitch(1.08)
	if RunState.overclocked:
		_tint.color = NORMAL_TINT.lerp(OVERCLOCK_TINT, 0.7 + 0.3 * sin(t * 10.0))
	elif purge_active:
		_tint.color = NORMAL_TINT.lerp(PURGE_TINT, 0.6 + 0.4 * sin(t * 4.0))
	else:
		_tint.color = NORMAL_TINT
	if hunter == null and t >= floor_data.hunter_spawn_time:
		hunter = Hunter.new()
		hunter.target = player
		hunter.position = _farthest_point_from_player() + Vector2(0, -12)
		add_child(hunter)
		hud.announce("追獵者來了，牠殺不死！")
		Audio.sfx("hunter")


func _spawn_prey(kind: Prey.Kind, at := Vector2.INF) -> Prey:
	var prey := Prey.new()
	prey.setup(kind)
	prey.flee_speed *= floor_data.prey_speed_mult
	prey.player = player
	prey.graph = level.graph
	var point := _pick_spawn_point() if at == Vector2.INF else at
	var lift := Vector2(0, -40) if kind == Prey.Kind.DRONE else Vector2(0, -prey.size.y * 0.5 - 1.0)
	prey.position = point + lift
	prey.died.connect(_on_prey_died)
	prey.escaped.connect(_on_prey_escaped)
	prey.split.connect(_on_prey_split)
	_enemies.add_child(prey)
	return prey


func _pick_spawn_point() -> Vector2:
	var points := level.spawn_points()
	var far: Array[Vector2] = []
	for p in points:
		if p.distance_to(player.global_position) > SPAWN_MIN_DISTANCE:
			far.append(p)
	return far.pick_random() if not far.is_empty() else points.pick_random()


func _farthest_point_from_player() -> Vector2:
	var best := Vector2.ZERO
	var best_dist := -1.0
	for p in level.spawn_points():
		var d := p.distance_to(player.global_position)
		if d > best_dist:
			best_dist = d
			best = p
	return best


# --- 獵物事件 ---

func _on_prey_died(prey: Prey) -> void:
	RunState.kills += 1
	ClimbState.credits += prey.credit_drop
	var at := prey.global_position
	var shards := RunState.quota if prey.kind == Prey.Kind.BOSS else prey.shard_drop
	if floor_data.floor_type != &"vault":
		for _i in shards:
			_drop(Pickup.Kind.SHARD, 1.0, at)
	_drop(Pickup.Kind.ENERGY, prey.energy_drop * (1.0 + ClimbState.stat(&"kill_energy")), at)
	var xp := int(ceil(prey.xp_drop * floor_data.xp_mult))
	for _i in mini(xp, 6):
		_drop(Pickup.Kind.XP, ceil(xp / minf(xp, 6.0)), at)
	if prey.drops_chest or (floor_data.floor_type == &"vault" and prey.kind == Prey.Kind.GOLDEN):
		_drop(Pickup.Kind.CHEST, 1.0, at)
	if prey.kind == Prey.Kind.BOSS:
		ClimbState.total_capacity += 1
		_drop(Pickup.Kind.CHEST, 1.0, at)
		hud.announce("取回核心晶片：總晶片額度 +1")


func _on_prey_escaped(prey: Prey) -> void:
	if prey.kind == Prey.Kind.GOLDEN:
		hud.announce("金色獵物登出了……")


## 複製體時間到：分裂成兩隻
func _on_prey_split(prey: Prey) -> void:
	var count: int = _count_kinds().get(Prey.Kind.REPLICATOR, 0)
	for i in 2:
		if count + i >= MAX_REPLICATORS:
			break
		var copy := _spawn_prey(Prey.Kind.REPLICATOR, prey.global_position + Vector2(0, prey.size.y * 0.5 + 1.0))
		copy.velocity = Vector2(-80.0 if i == 0 else 80.0, -150.0)
	hud.announce("複製體分裂了！")


func _on_boss_resurfaced(_prey: Prey) -> void:
	for _i in 2:
		_spawn_prey(Prey.Kind.RAT)


func _drop(kind: Pickup.Kind, amount: float, at: Vector2) -> void:
	var pickup := Pickup.new()
	pickup.kind = kind
	pickup.amount = amount
	pickup.position = at
	pickup.velocity = Vector2(randf_range(-60.0, 60.0), randf_range(-120.0, -60.0))
	_pickups.add_child.call_deferred(pickup)


# --- 升級與寶箱 ---

func gain_xp(amount: int) -> void:
	for _i in ClimbState.add_xp(amount):
		_pending_picks.append("level")
	_open_next_pick()


func open_chest() -> void:
	_pending_picks.append("chest")
	_open_next_pick()


func _open_next_pick() -> void:
	if picker.visible or _pending_picks.is_empty() or RunState.finished:
		return
	var what: String = _pending_picks.pop_front()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if what == "chest":
		picker.open("寶箱：挑一枚晶片", ClimbState.roll_chip_cards())
	else:
		var title := "升級！Lv %d　總晶片額度 +1" % ClimbState.level
		Audio.sfx("levelup")
		picker.open(title, ClimbState.roll_level_up_cards())


func _on_card_picked(card: Dictionary) -> void:
	hud.announce(ClimbState.apply_card(card))
	if _pending_picks.is_empty():
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	else:
		_open_next_pick.call_deferred()


func _apply_energy_max() -> void:
	RunState.max_energy = _base_energy_max * (1.0 + ClimbState.stat(&"energy_max"))
	RunState.energy = minf(RunState.energy, RunState.max_energy)


func _on_overclock_started() -> void:
	Audio.sfx("overclock")
	hud.announce("超頻模式！攻擊力加倍，10 秒內擊殺回電（剩 %d 次）" % ClimbState.overclock_charges)


func _on_overclock_ended() -> void:
	hud.announce("超頻結束，撐過來了")


func _on_synergy_discovered(synergy: SynergyData) -> void:
	hud.announce("共鳴發現：%s" % synergy.display_name)


# --- 結束 ---

func _on_player_died() -> void:
	player.dead = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_floor_cleared() -> void:
	Audio.sfx("elevator")
	# 回到電梯電量就回滿，所以不用把電量帶到下一層
	ClimbState.credits += FLOOR_CLEAR_CREDITS
	if floor_data.floor_type == &"black_market":
		ClimbState.bonus_chip_pick = true
	if ClimbState.is_boss_floor():
		ClimbState.section_cleared = true
	if auto_advance:
		get_tree().change_scene_to_file.call_deferred(ELEVATOR_SCENE)
