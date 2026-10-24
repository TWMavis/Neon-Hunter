class_name Prey
extends CharacterBody2D
## 會逃跑的獵物（流氓 AI）。
## 狀態機：遊蕩 → 逃跑（消耗體力）→ 喘息（變慢、受到雙倍傷害）；被逼進死角 → 困獸（反撲玩家）。
## 地面型用平台導航圖逃跑（往「離玩家最遠的相鄰節點」走、跳、落下）；飛行型往遠離玩家又空曠的方向飛。
## 除了困獸反撲，每種獵物還有自己的反擊方式（見 _fight_back 與 docs/ENEMIES.md）。

signal died(prey: Prey)
signal escaped(prey: Prey)
signal split(prey: Prey)          # 複製體時間到要分裂
signal resurfaced(prey: Prey)     # Boss 從垃圾堆冒出來

enum Kind { RAT, DRONE, GOLDEN, JUMPER, REPLICATOR, ELITE, BOSS, KITER, MINELAYER }
enum State { WANDER, FLEE, EXHAUSTED, CORNERED, STUNNED, BURROWED }

const GRAVITY := 900.0
const EXHAUSTED_TIME := 2.5
const CORNERED_TIME := 1.0
const PANIC_RADIUS := 110.0
const FLY_PROBE := 56.0
const BURROW_TIME := 2.0
const SPRITES := {
	Kind.RAT: "rat", Kind.DRONE: "drone", Kind.GOLDEN: "golden", Kind.JUMPER: "jumper",
	Kind.REPLICATOR: "replicator", Kind.ELITE: "elite", Kind.BOSS: "boss",
	Kind.KITER: "kiter", Kind.MINELAYER: "minelayer",
}
const VIEW_HALF_ANGLE_COS := 0.5    # 視角：面向前方左右各 60 度（共 120 度）
const HEAR_RADIUS := 48.0           # 背後只聽得到這麼近的腳步聲
const HEAR_RADIUS_STEALTH := 14.0   # 潛行時背後幾乎要貼上才會發現
const KITE_RANGE := 150.0          # 風箏手：離玩家超過這個距離就停下來射擊
const MAX_MINES := 4               # 佈雷者同時留在場上的地雷上限

var kind: Kind = Kind.RAT
var state: State = State.WANDER
var player: Player
var graph: PlatformGraph
var burrow_points: Array[Vector2] = []

var size := Vector2(12, 8)
var color := Color("ff3df0")
var max_hp := 3.0
var hp := 3.0
var wander_speed := 30.0
var flee_speed := 150.0
var tired_speed := 40.0
var jump_velocity := -390.0
var sense_range := 130.0
var max_stamina := 2.5
var stamina := 2.5
var contact_damage := 10.0
var shard_drop := 1
var energy_drop := 8.0
var xp_drop := 1
var credit_drop := 3        # 信用點
var drops_chest := false
var lifetime := 0.0          # 大於 0 時倒數，歸零就「登出」消失（金色獵物）
var split_time := 0.0        # 大於 0 時倒數，歸零就分裂（複製體）

var _state_time := 0.0
var _dir := 1.0
var _wander_timer := 0.0
var _blocked_time := 0.0
var _contact_cooldown := 0.0
var _flash := 0.0
var _drop_time := 0.0
var _stun_duration := 0.0
var _fly_dir := Vector2.ZERO
var _fly_think := 0.0
var _slow_time := 0.0
var _mark_time := 0.0
var _nav_target := -1
var _nav_edge := PlatformGraph.Edge.WALK
var _next_burrow_hp := 0.0
var _hop_timer := 0.0
var _anim_t := 0.0
var _attack_timer := 0.0           # 反擊的冷卻
var _skill_cd := 0.0               # 閃現、翻滾、反擊封包的冷卻
var _dodge_time := 0.0             # 翻滾閃避中（打不到）
var _windup := 0.0                 # 裝甲運輸車衝撞前的蓄力
var _charge_time := 0.0
var _charge_dir := 1.0
var _was_on_floor := true
var _mines: Array = []
var _alert_time := 0.0              # 剛發現玩家時頭上的「!」


## 在加入場景前呼叫，決定種類與數值
func setup(new_kind: Kind) -> void:
	kind = new_kind
	match kind:
		Kind.DRONE:
			size = Vector2(12, 10)
			color = Color("ffe14d")
			max_hp = 2.0
			wander_speed = 25.0
			flee_speed = 120.0
			tired_speed = 35.0
			sense_range = 150.0
			max_stamina = 3.0
		Kind.GOLDEN:
			credit_drop = 20
			size = Vector2(12, 10)
			color = Color("ffb000")
			max_hp = 4.0
			flee_speed = 205.0
			tired_speed = 60.0
			sense_range = 200.0
			max_stamina = 4.0
			shard_drop = 3
			energy_drop = 30.0
			xp_drop = 5
			lifetime = 25.0
		Kind.JUMPER:
			credit_drop = 5
			size = Vector2(10, 12)
			color = Color("7dff6a")
			max_hp = 3.0
			flee_speed = 135.0
			jump_velocity = -430.0
			sense_range = 150.0
			xp_drop = 2
		Kind.REPLICATOR:
			credit_drop = 2
			size = Vector2(10, 10)
			color = Color("c8f6ff")
			max_hp = 2.0
			flee_speed = 140.0
			split_time = 12.0
		Kind.ELITE:
			credit_drop = 25
			size = Vector2(24, 14)
			color = Color("8aa3b8")
			max_hp = 30.0
			wander_speed = 20.0
			flee_speed = 75.0
			tired_speed = 30.0
			jump_velocity = -300.0
			max_stamina = 6.0
			contact_damage = 20.0
			shard_drop = 2
			energy_drop = 25.0
			xp_drop = 8
			drops_chest = true
		Kind.BOSS:
			credit_drop = 60
			size = Vector2(30, 20)
			color = Color("d9772b")
			max_hp = 90.0
			wander_speed = 40.0
			flee_speed = 115.0
			tired_speed = 40.0
			jump_velocity = -420.0
			sense_range = 400.0
			max_stamina = 5.0
			contact_damage = 20.0
			energy_drop = 50.0
			xp_drop = 20
		Kind.KITER:
			credit_drop = 6
			size = Vector2(10, 12)
			color = Color("6aa8ff")
			max_hp = 3.0
			flee_speed = 130.0
			sense_range = 200.0
			xp_drop = 2
		Kind.MINELAYER:
			credit_drop = 6
			size = Vector2(14, 9)
			color = Color("ff9a2b")
			max_hp = 4.0
			flee_speed = 125.0
			sense_range = 150.0
			xp_drop = 2
	hp = max_hp
	_attack_timer = randf_range(0.8, 1.6)
	stamina = max_stamina
	_next_burrow_hp = max_hp * 0.75


func is_flying() -> bool:
	return kind == Kind.DRONE


func _ready() -> void:
	add_to_group("prey")
	collision_layer = Layers.ENEMY
	if is_flying():
		collision_mask = Layers.TERRAIN
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	else:
		collision_mask = Layers.TERRAIN | Layers.ONEWAY
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	_dir = 1.0 if randf() < 0.5 else -1.0
	_wander_timer = randf_range(1.5, 3.5)


func _physics_process(delta: float) -> void:
	_anim_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	_slow_time = maxf(_slow_time - delta, 0.0)
	_mark_time = maxf(_mark_time - delta, 0.0)
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			escaped.emit(self)
			queue_free()
			return
	if split_time > 0.0:
		split_time -= delta
		if split_time <= 0.0:
			split.emit(self)
			queue_free()
			return

	var to_player := Vector2.ZERO
	var dist := INF
	if is_instance_valid(player) and not player.dead:
		to_player = player.global_position - global_position
		dist = to_player.length()

	_update_state(delta, dist)
	if state == State.BURROWED:
		queue_redraw()
		return
	if is_flying():
		_move_flying(delta, to_player)
	else:
		_move_ground(delta, to_player, dist)
	_check_cornered(delta, dist)
	_fight_back(delta, to_player, dist)

	if state == State.CORNERED and dist < size.x * 0.5 + 8.0 and _contact_cooldown <= 0.0:
		player.take_hit(contact_damage, global_position)
		_contact_cooldown = 1.0
	queue_redraw()


func _update_state(delta: float, dist: float) -> void:
	_state_time += delta
	match state:
		State.WANDER:
			stamina = minf(stamina + delta, max_stamina)
			if _can_detect_player(dist):
				_enter(State.FLEE)
		State.FLEE:
			stamina -= delta
			if stamina <= 0.0:
				_enter(State.EXHAUSTED)
			elif dist > sense_range * 2.2:
				_enter(State.WANDER)
		State.EXHAUSTED:
			if _state_time >= EXHAUSTED_TIME:
				stamina = max_stamina
				_enter(State.FLEE if dist < sense_range else State.WANDER)
		State.CORNERED:
			if _state_time >= CORNERED_TIME:
				_enter(State.FLEE)
		State.STUNNED:
			if _state_time >= _stun_duration:
				_enter(State.FLEE)
		State.BURROWED:
			if _state_time >= BURROW_TIME:
				_resurface()


## 玩家潛行時感知範圍縮小（Boss 不受影響）
func _sense_mult() -> float:
	if kind == Kind.BOSS or not is_instance_valid(player):
		return 1.0
	return player.sense_mult()


## 視角：獵物面向前方 120 度內才看得到玩家；背後只聽得到很近的腳步聲。Boss 四周都看得到
func _can_detect_player(dist: float) -> bool:
	if not is_instance_valid(player) or player.dead:
		return false
	if kind == Kind.BOSS:
		return dist < sense_range
	if in_view(player.global_position):
		return dist < sense_range * _sense_mult()
	return dist < (HEAR_RADIUS_STEALTH if player.stealthed else HEAR_RADIUS)


## 潛行時畫出獵物的視野（看得到你的範圍）
func _draw_view_cone() -> void:
	var reach := sense_range * _sense_mult()
	var base := Vector2(_dir, 0.0).angle()
	var spread := acos(VIEW_HALF_ANGLE_COS)
	var points := PackedVector2Array([Vector2.ZERO])
	for i in 9:
		points.append(Vector2.RIGHT.rotated(base - spread + spread * 2.0 * i / 8.0) * reach)
	draw_colored_polygon(points, Color(1.0, 0.88, 0.3, 0.08))
	draw_polyline(points + PackedVector2Array([Vector2.ZERO]), Color(1.0, 0.88, 0.3, 0.25), 1.0)


## 某個點在不在獵物的視角內
func in_view(point: Vector2) -> bool:
	var to := point - global_position
	if to == Vector2.ZERO:
		return true
	return Vector2(_dir, 0.0).dot(to.normalized()) >= VIEW_HALF_ANGLE_COS


## 玩家潛行、在正常感知範圍內但還沒被發現（頭上顯示「?」）
func is_suspicious() -> bool:
	return state == State.WANDER and is_instance_valid(player) and player.stealthed 		and global_position.distance_to(player.global_position) < sense_range


func _enter(next: State) -> void:
	if state == State.WANDER and next == State.FLEE:
		_alert_time = 0.6
		if is_instance_valid(player) and player.stealthed:
			Audio.sfx("alert", -4.0)
	state = next
	_state_time = 0.0
	_blocked_time = 0.0
	_nav_target = -1
	if next == State.CORNERED and is_instance_valid(player):
		# 困獸：朝玩家撲過去
		if is_flying():
			velocity = global_position.direction_to(player.global_position) * 170.0
		else:
			var lunge := 260.0 if kind == Kind.ELITE or kind == Kind.BOSS else 210.0
			velocity = Vector2(signf(player.global_position.x - global_position.x) * lunge, -170.0)


## 逃跑中卻幾乎沒在移動、玩家又很近 → 被逼進死角
func _check_cornered(delta: float, dist: float) -> void:
	if state != State.FLEE:
		return
	var moving := get_real_velocity().length() if is_flying() else absf(get_real_velocity().x)
	if moving < 20.0 and dist < 80.0:
		_blocked_time += delta
		if _blocked_time > 0.4:
			_enter(State.CORNERED)
	else:
		_blocked_time = 0.0


func _speed_mult() -> float:
	return 0.5 if _slow_time > 0.0 else 1.0


# --- 地面移動 ---

func _move_ground(delta: float, to_player: Vector2, dist: float) -> void:
	if _drop_time > 0.0:
		_drop_time -= delta
		if _drop_time <= 0.0:
			collision_mask |= Layers.ONEWAY
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	if _update_charge(delta):
		return

	var speed := 0.0
	var steer := _dir
	match state:
		State.WANDER:
			speed = wander_speed
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				_wander_timer = randf_range(1.5, 3.5)
				_dir = -_dir
			if is_on_floor() and (is_on_wall() or not _ground_ahead(_dir)):
				_dir = -_dir
			steer = _dir
		State.FLEE, State.EXHAUSTED:
			speed = flee_speed if state == State.FLEE else tired_speed
			if graph and graph.node_count() > 0:
				steer = _nav_flee()
			else:
				steer = _simple_flee(to_player, dist)
			if steer != 0.0:
				_dir = steer
			if kind == Kind.KITER and state == State.FLEE and dist > KITE_RANGE:
				steer = 0.0                      # 風箏手：拉開距離後就停下來射擊
				_dir = signf(to_player.x) if to_player.x != 0.0 else _dir
			if kind == Kind.JUMPER and state == State.FLEE and is_on_floor():
				_hop_timer -= delta
				if _hop_timer <= 0.0:
					_hop_timer = randf_range(0.4, 0.9)
					velocity.y = jump_velocity * 0.7  # 跳躍者：一路蹦蹦跳
		State.CORNERED:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			move_and_slide()
			return
		State.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			move_and_slide()
			return
	velocity.x = move_toward(velocity.x, steer * speed * _speed_mult(), 1000.0 * delta)
	move_and_slide()


## 裝甲運輸車的衝撞：蓄力 0.45 秒（閃紅）後朝玩家衝 0.6 秒。回傳 true 代表這幀由衝撞接管移動
func _update_charge(delta: float) -> bool:
	if _windup > 0.0:
		_windup -= delta
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		move_and_slide()
		if _windup <= 0.0:
			_charge_time = 0.6
			Audio.sfx("charge")
		return true
	if _charge_time > 0.0:
		_charge_time -= delta
		velocity.x = _charge_dir * 280.0
		move_and_slide()
		if is_instance_valid(player) and _contact_cooldown <= 0.0 \
				and global_position.distance_to(player.global_position) < size.x * 0.5 + 8.0:
			player.take_hit(20.0, global_position)
			player.velocity.x += _charge_dir * 220.0
			_contact_cooldown = 1.0
		if is_on_wall() or _charge_time <= 0.0:
			_charge_time = 0.0
			_attack_timer = 5.0
		return true
	return false


## 用平台導航圖逃：回傳水平方向（-1、0、1）
func _nav_flee() -> float:
	if is_on_floor():
		var here := graph.node_at_feet(global_position + Vector2(0.0, size.y * 0.5))
		if here >= 0:
			var best := here
			var best_d := graph.dist[here]
			var best_edge := PlatformGraph.Edge.WALK
			for e: Array in graph.edges_of(here):
				var to: int = e[0]
				if graph.dist[to] > best_d + 0.01:
					best_d = graph.dist[to]
					best = to
					best_edge = e[1]
			_nav_target = best
			_nav_edge = best_edge
			if best == here:
				return 0.0  # 已經是離玩家最遠的地方（死角）
			var target := graph.node_position(best)
			var dx := target.x - global_position.x
			match best_edge:
				PlatformGraph.Edge.JUMP:
					if absf(dx) < 20.0:
						velocity.y = jump_velocity
				PlatformGraph.Edge.DROP:
					if graph.nodes[best].x == graph.nodes[here].x:
						_drop_through()
			return signf(dx) if absf(dx) > 2.0 else 0.0
	if _nav_target >= 0:
		var dx := graph.node_position(_nav_target).x - global_position.x
		return signf(dx) if absf(dx) > 2.0 else 0.0
	return _dir


## 沒有導航圖時：背對玩家跑，遇牆就跳
func _simple_flee(to_player: Vector2, dist: float) -> float:
	var dir := _dir
	if absf(to_player.x) > 4.0:
		dir = -signf(to_player.x)
	if is_on_floor():
		if state == State.FLEE and is_on_wall():
			velocity.y = jump_velocity
		elif to_player.y < -24.0 and dist < 100.0 and randf() < 0.03:
			_drop_through()
	return dir


# --- 飛行移動 ---

func _move_flying(delta: float, to_player: Vector2) -> void:
	var desired := Vector2.ZERO
	match state:
		State.WANDER:
			_wander_timer -= delta
			if _wander_timer <= 0.0 or is_on_wall():
				_wander_timer = randf_range(1.5, 3.5)
				_dir = -_dir
			desired = Vector2(_dir, sin(_state_time * 2.0) * 0.4) * wander_speed
		State.FLEE, State.EXHAUSTED:
			_fly_think -= delta
			if _fly_think <= 0.0:
				_fly_think = 0.15
				var away := -to_player.normalized() if to_player != Vector2.ZERO else Vector2.UP
				_fly_dir = _best_flee_dir(away)
			desired = _fly_dir * (flee_speed if state == State.FLEE else tired_speed) * _speed_mult()
		State.CORNERED:
			velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
			move_and_slide()
			return
		State.STUNNED:
			desired = Vector2(0.0, 15.0)
	velocity = velocity.move_toward(desired, 500.0 * delta)
	move_and_slide()


## 在 12 個方向中挑「離玩家遠、前方又空曠」的方向
func _best_flee_dir(away: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var best := away
	var best_score := -INF
	for i in 12:
		var dir := Vector2.RIGHT.rotated(TAU * i / 12.0)
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * FLY_PROBE, Layers.TERRAIN)
		var hit := space.intersect_ray(query)
		var clearance := 1.0
		if not hit.is_empty():
			var hit_pos: Vector2 = hit["position"]
			clearance = global_position.distance_to(hit_pos) / FLY_PROBE
		var score := dir.dot(away) + clearance * 1.2
		if score > best_score:
			best_score = score
			best = dir
	return best


func _ground_ahead(dir: float) -> bool:
	var from := global_position + Vector2(dir * (size.x * 0.5 + 3.0), 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, size.y * 0.5 + 10.0), Layers.TERRAIN | Layers.ONEWAY)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _drop_through() -> void:
	collision_mask &= ~Layers.ONEWAY
	_drop_time = 0.25


# --- Boss：鑽進垃圾堆 ---

func _burrow() -> void:
	Audio.sfx("burrow")
	_enter(State.BURROWED)
	velocity = Vector2.ZERO
	collision_layer = 0
	visible = false


func _resurface() -> void:
	var best := global_position
	var best_d := -1.0
	for p in burrow_points:
		var d := p.distance_to(player.global_position) if is_instance_valid(player) else randf()
		if d > best_d:
			best_d = d
			best = p
	global_position = best + Vector2(0.0, -size.y * 0.5)
	collision_layer = Layers.ENEMY
	visible = true
	stamina = max_stamina
	_enter(State.FLEE)
	resurfaced.emit(self)


# --- 受到玩家影響 ---

func stun(duration: float) -> void:
	if state == State.BURROWED:
		return
	_stun_duration = duration
	_enter(State.STUNNED)
	velocity = Vector2.ZERO
	_windup = 0.0         # 定身會打斷衝撞
	_charge_time = 0.0


## 攻擊從獵物背後來（獵物面向 _dir 的反方向）
func is_behind(attacker: Vector2) -> bool:
	var side := signf(attacker.x - global_position.x)
	return side != 0.0 and side == -_dir


## 直接進入喘息（幽靈突襲）
func exhaust() -> void:
	if state == State.BURROWED or kind == Kind.BOSS:
		return
	stamina = 0.0
	_enter(State.EXHAUSTED)


func slow(duration: float) -> void:
	_slow_time = maxf(_slow_time, duration)


func mark(duration: float) -> void:
	_mark_time = maxf(_mark_time, duration)


func knockback(push: Vector2) -> void:
	if kind == Kind.BOSS or state == State.BURROWED:
		return
	velocity += push


## 鉤爪：把獵物拉向某一點
func pull_toward(point: Vector2, speed: float) -> void:
	if kind == Kind.BOSS or kind == Kind.ELITE:
		stun(0.3)
		return
	stun(0.45)
	velocity = global_position.direction_to(point) * speed
	if not is_flying():
		velocity.y = minf(velocity.y, -120.0)


func is_vulnerable() -> bool:
	return state == State.EXHAUSTED or state == State.STUNNED


func take_damage(amount: float, source: StringName = &"") -> void:
	if hp <= 0.0 or state == State.BURROWED or _dodge_time > 0.0:
		return  # 風箏手翻滾中打不到
	var dealt := amount
	if is_vulnerable():
		dealt *= 2.0 + ClimbState.skill_stat(source, &"exhausted_damage")  # 喘息、被網住時受到暴擊
	if _mark_time > 0.0:
		dealt *= 1.25
	dealt *= RunState.damage_mult()  # 超頻模式：攻擊力加倍
	hp -= dealt
	_flash = 0.08
	Audio.sfx("hit", -8.0, 0.15, 0.05)
	if hp <= 0.0:
		Audio.sfx("explode" if kind == Kind.BOSS or kind == Kind.ELITE else "kill", -2.0)
		if kind == Kind.REPLICATOR:
			# 複製體：死亡時爆出四發碎片
			for dir: Vector2 in [Vector2(1, -1), Vector2(-1, -1), Vector2(1, -0.3), Vector2(-1, -0.3)]:
				_shoot(dir.normalized() * 150.0, 4.0, color, 300.0, 0.0, 0.7, 1.5)
		died.emit(self)
		queue_free()
		return
	if kind == Kind.BOSS and hp <= _next_burrow_hp:
		_next_burrow_hp -= max_hp * 0.25
		_burrow()
		return
	if kind == Kind.RAT and _skill_cd <= 0.0 and randf() < 0.35 and is_instance_valid(player):
		# 資料鼠：被打中時有機率回敬一個干擾封包
		_skill_cd = 1.5
		_shoot(global_position.direction_to(player.global_position) * 110.0, 6.0, Color("ff3df0"), 0.0, 0.0, 2.5)
	if state == State.WANDER:
		_enter(State.FLEE)
	_spread_panic()


# --- 各自的反擊 ---

func _fight_back(delta: float, to_player: Vector2, dist: float) -> void:
	_attack_timer -= delta
	_skill_cd = maxf(_skill_cd - delta, 0.0)
	_dodge_time = maxf(_dodge_time - delta, 0.0)
	var landed := is_on_floor() and not _was_on_floor
	_was_on_floor = is_on_floor()
	_alert_time = maxf(_alert_time - delta, 0.0)
	# 還沒發現玩家（遊蕩中）就不會反擊
	if state == State.STUNNED or state == State.WANDER or not is_instance_valid(player) or player.dead:
		return
	match kind:
		Kind.DRONE:
			# 轟炸：玩家在正下方就丟炸彈（玩家潛行時不轟炸）
			if not player.stealthed and _attack_timer <= 0.0 and to_player.y > 16.0 and absf(to_player.x) < 36.0 and dist < 170.0:
				_attack_timer = 2.5
				_shoot(Vector2(velocity.x * 0.3, 30.0), 8.0, Color("ffe14d"), 500.0, 24.0, 2.5, 3.0)
		Kind.JUMPER:
			# 踩踏：落地時玩家在旁邊就被震到
			if landed and dist < 30.0:
				player.take_hit(8.0, global_position)
				_burst(color, 30.0)
		Kind.GOLDEN:
			# 閃現：被貼近就瞬移到附近離玩家較遠的平台
			if dist < 55.0 and _skill_cd <= 0.0:
				_blink()
		Kind.KITER:
			# 回頭射擊：射擊前 0.35 秒會畫出瞄準線
			if state != State.CORNERED and _attack_timer <= 0.0 and dist < 260.0 and _clear_line(player.global_position):
				_attack_timer = 1.6
				_shoot(to_player.normalized() * 170.0, 8.0, color, 0.0, 0.0, 2.0)
			_try_dodge(to_player, dist)
		Kind.MINELAYER:
			# 沿路布雷
			if state == State.FLEE and _attack_timer <= 0.0 and is_on_floor():
				_attack_timer = 1.2
				_lay_mine()
		Kind.ELITE:
			# 衝撞：玩家在同一高度就蓄力後衝過去
			if _windup <= 0.0 and _charge_time <= 0.0 and _attack_timer <= 0.0 and is_on_floor() \
					and dist < 170.0 and absf(to_player.y) < 20.0:
				_windup = 0.45
				_charge_dir = signf(to_player.x) if to_player.x != 0.0 else _dir
				_dir = _charge_dir
		Kind.BOSS:
			# 投擲廢料：一次丟三團會爆炸的廢料
			if _attack_timer <= 0.0 and dist < 300.0 and state != State.CORNERED:
				_attack_timer = 3.0
				for i in 3:
					var flight := 0.9 + i * 0.15
					var target := player.global_position + Vector2((i - 1) * 28.0, 0.0)
					var vel := (target - global_position) / flight - Vector2(0.0, 0.5 * 500.0 * flight)
					_shoot(vel, 12.0, Color("d9772b"), 500.0, 22.0, flight + 0.5, 3.5)


## 被準心瞄準時翻滾閃避（風箏手）
func _try_dodge(to_player: Vector2, dist: float) -> void:
	if _skill_cd > 0.0 or not is_on_floor() or dist > 220.0 or to_player == Vector2.ZERO:
		return
	if player.aim_dir.dot(-to_player.normalized()) > 0.985:
		_skill_cd = 3.0
		_dodge_time = 0.35
		velocity = Vector2(-signf(to_player.x) * 220.0, -170.0)


func _blink() -> void:
	if graph == null or graph.node_count() == 0:
		return
	var options: Array[Vector2] = []
	for id in graph.node_count():
		var p := graph.node_position(id)
		var from_me := p.distance_to(global_position)
		if from_me > 60.0 and from_me < 170.0 and p.distance_to(player.global_position) > 110.0:
			options.append(p)
	if options.is_empty():
		return
	_burst(color, 16.0)
	var target: Vector2 = options.pick_random()
	global_position = target + Vector2(0.0, -size.y * 0.5 - 1.0)
	velocity = Vector2.ZERO
	_burst(color, 16.0)
	_skill_cd = 4.0
	Audio.sfx("blink")


func _lay_mine() -> void:
	_mines = _mines.filter(func(m: Variant) -> bool: return is_instance_valid(m))
	if _mines.size() >= MAX_MINES:
		return
	var mine := Mine.new()
	mine.position = global_position + Vector2(0.0, size.y * 0.5)
	_spawn_node(mine)
	_mines.append(mine)
	Audio.sfx("mine", -6.0)


func _shoot(vel: Vector2, damage: float, shot_color: Color, grav: float, explode_r: float, life: float, radius := 2.5) -> void:
	var shot := EnemyShot.new()
	shot.position = global_position
	shot.velocity = vel
	shot.damage = damage
	shot.color = shot_color
	shot.gravity = grav
	shot.explode_radius = explode_r
	shot.life = life
	shot.radius = radius
	_spawn_node(shot)
	Audio.sfx("enemy_shot", -8.0, 0.1, 0.05)


func _burst(burst_color: Color, burst_radius: float) -> void:
	var burst := Burst.new()
	burst.position = global_position
	burst.color = burst_color
	burst.max_radius = burst_radius
	_spawn_node(burst)


func _spawn_node(node: Node2D) -> void:
	var container := get_tree().get_first_node_in_group("projectiles")
	if container:
		container.add_child.call_deferred(node)


func _clear_line(target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target, Layers.TERRAIN)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## 恐慌傳染：附近還在遊蕩的獵物一起逃
func _spread_panic() -> void:
	for node in get_tree().get_nodes_in_group("prey"):
		var other := node as Prey
		if other and other != self and other.state == State.WANDER \
				and other.global_position.distance_to(global_position) < PANIC_RADIUS:
			other._enter(State.FLEE)


## 兩格動畫：逃跑時動得比較快；跳躍者在空中用伸展的那格
func _sprite_frame() -> int:
	match kind:
		Kind.JUMPER:
			return 0 if is_on_floor() else 1
		Kind.REPLICATOR:
			return int(_anim_t * lerpf(2.0, 12.0, clampf(1.0 - split_time / 12.0, 0.0, 1.0))) % 2
	var speed := 12.0 if state == State.FLEE else 5.0
	if state == State.STUNNED:
		speed = 0.0
	return int(_anim_t * speed) % 2


func _draw() -> void:
	if state == State.BURROWED:
		return
	if state == State.WANDER and kind != Kind.BOSS and is_instance_valid(player) and player.stealthed 			and global_position.distance_to(player.global_position) < sense_range * 1.2:
		_draw_view_cone()
	var half := size * 0.5
	var body := Rect2(-half, size)
	var tint := Color.WHITE
	if state == State.EXHAUSTED:
		tint = Color(0.55, 0.55, 0.7)
	if _flash > 0.0:
		tint = Color(6.0, 6.0, 6.0)   # 被打中閃白

	if kind == Kind.GOLDEN:
		draw_circle(Vector2.ZERO, size.x, Color(1.0, 0.8, 0.2, 0.15 + 0.1 * sin(_state_time * 10.0)))
	if kind == Kind.REPLICATOR:
		var pulse := clampf(1.0 - split_time / 12.0, 0.0, 1.0)
		draw_rect(body.grow(1.0 + pulse * 2.0), Color(0.8, 0.95, 1.0, 0.3 + pulse * 0.5), false, 1.0)
	if is_suspicious():
		draw_string(Fonts.ui(), Vector2(-20.0, -size.y * 0.5 - 3.0), "?", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 11, Color("ffe14d"))
	elif _alert_time > 0.0:
		draw_string(Fonts.ui(), Vector2(-20.0, -size.y * 0.5 - 3.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, Color("ff2244"))
	if _windup > 0.0 and int(_windup * 20.0) % 2 == 0:
		tint = Color(3.0, 0.6, 0.6)   # 衝撞蓄力：閃紅
	if _dodge_time > 0.0:
		tint.a = 0.5
	Art.draw(self, SPRITES[kind], 2, _sprite_frame(), Vector2.ZERO, _dir < 0.0, tint)
	if kind == Kind.KITER and _attack_timer < 0.35 and state != State.CORNERED and state != State.STUNNED and state != State.WANDER \
			and is_instance_valid(player) and global_position.distance_to(player.global_position) < 260.0:
		draw_line(Vector2.ZERO, player.global_position - global_position, Color(color, 0.45), 1.0)  # 瞄準線
	if _windup > 0.0:
		draw_string(Fonts.ui(), Vector2(-20.0, -size.y * 0.5 - 4.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, Color("ff2244"))

	if _slow_time > 0.0:
		draw_rect(body.grow(3.0), Color(0.4, 0.6, 1.0, 0.5), false, 1.0)
	if _mark_time > 0.0:
		draw_arc(Vector2.ZERO, half.x + 5.0, 0.0, TAU, 12, Color(0.49, 1.0, 0.42, 0.7), 1.0)
	match state:
		State.STUNNED:
			var net := Color("ff3df0")
			draw_rect(body.grow(2.0), net, false, 1.0)
			draw_line(-half - Vector2(2, 2), half + Vector2(2, 2), net, 1.0)
			draw_line(Vector2(half.x + 2.0, -half.y - 2.0), Vector2(-half.x - 2.0, half.y + 2.0), net, 1.0)
		State.CORNERED:
			draw_rect(body.grow(2.0), Color("ff2244"), false, 1.0)
		State.EXHAUSTED:
			draw_circle(Vector2(-2.0, -half.y - 4.0), 1.0, Color(0.8, 0.8, 0.9))
			draw_circle(Vector2(2.0, -half.y - 6.0), 1.0, Color(0.8, 0.8, 0.9))

	if state == State.FLEE and stamina < max_stamina:
		draw_rect(Rect2(-6.0, -half.y - 4.0, 12.0 * stamina / max_stamina, 1.0), Color(1, 1, 1, 0.6))
	if hp < max_hp and kind != Kind.BOSS:
		draw_rect(Rect2(-6.0, half.y + 2.0, 12.0 * hp / max_hp, 1.0), Color("7dff6a"))
