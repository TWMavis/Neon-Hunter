class_name Player
extends CharacterBody2D
## 玩家：A/D 移動、空白鍵跳躍（按越久跳越高）、Shift 朝 WASD 方向衝刺、S 從單向平台下跳、滑鼠瞄準。
## 移動槽的晶片（二段跳、牆跳、推進器、衝刺……）在這裡處理；被動技能在 PassiveController。

const RUN_SPEED := 135.0
const GROUND_ACCEL := 1500.0
const AIR_ACCEL := 950.0
const GRAVITY := 900.0
const FALL_GRAVITY_MULT := 1.6
const MAX_FALL_SPEED := 420.0
const JUMP_VELOCITY := -410.0
const JUMP_CUT := 0.45                 # 放開跳躍鍵時保留的上升速度比例
const APEX_THRESHOLD := 45.0           # 跳躍頂點短暫滯空
const APEX_GRAVITY_MULT := 0.5
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12
const DASH_SPEED := 340.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.45
const DROP_THROUGH_TIME := 0.2
const HIT_INVULN_TIME := 0.7
const STEALTH_SPEED_MULT := 0.5       # 潛行時的移動速度
const STEALTH_COOLDOWN := 0.6         # 潛行解除後多久才能再潛行
const STEALTH_SENSE_MULT := 0.35      # 潛行時獵物的感知範圍倍率
const WALL_SLIDE_SPEED := 60.0
const WALL_JUMP_PUSH := 170.0
const JETPACK_TIME := 1.0
const JETPACK_FALL_SPEED := 30.0
const GRAPPLE_SPEED := 380.0
const GRAPPLE_TIME := 0.35
const GHOST_DAMAGE := 3.0
const BODY_SIZE := Vector2(10, 20)
const CAMERA_LOOK_AHEAD := 0.3
const CAMERA_MAX_OFFSET := 70.0

var facing := 1.0
var aim_dir := Vector2.RIGHT
var dead := false
var camera: Camera2D
var weapons: WeaponManager
var passives: PassiveController

var _coyote := 0.0
var _jump_buffer := 0.0
var _air_jumps := 0
var _jet_left := 0.0
var _dash_time := 0.0
var _dash_cooldown := 0.0
var _dash_charges := 1
var _dash_dir := Vector2.RIGHT
var _dash_hits: Array[Prey] = []
var _invuln := 0.0
var _drop_time := 0.0
var _grapple_time := 0.0
var _grapple_point := Vector2.ZERO
var _anim_t := 0.0
var stealthed := false                # 潛行中（按住潛行鍵、站在地上）
var _stealth_cd := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.TERRAIN | Layers.ONEWAY

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	add_child(shape)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)

	weapons = WeaponManager.new()
	add_child(weapons)
	passives = PassiveController.new()
	add_child(passives)


func max_dash_charges() -> int:
	return 1 + int(ClimbState.skill_stat(Catalog.MOVEMENT, &"dash_charges"))


func _process(delta: float) -> void:
	_anim_t += delta
	# 鏡頭往準心偏移：用螢幕座標計算，避免和鏡頭移動互相拉扯
	var viewport := get_viewport()
	var from_center := viewport.get_mouse_position() - viewport.get_visible_rect().size * 0.5
	var target := (from_center * CAMERA_LOOK_AHEAD).limit_length(CAMERA_MAX_OFFSET)
	if GameInput.using_gamepad:
		target = aim_dir * CAMERA_MAX_OFFSET * 0.6   # 手把：鏡頭往右搖桿瞄準的方向偏
	camera.offset = camera.offset.lerp(target, minf(1.0, 8.0 * delta))
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)

	if GameInput.using_gamepad:
		var stick: Vector2 = GameInput.gamepad_aim()
		if stick != Vector2.ZERO:
			aim_dir = stick          # 手把：右搖桿瞄準，放開時保持原方向
	else:
		aim_dir = global_position.direction_to(get_global_mouse_position())
	if absf(aim_dir.x) > 0.01:
		facing = signf(aim_dir.x)

	if _drop_time > 0.0:
		_drop_time -= delta
		if _drop_time <= 0.0:
			collision_mask |= Layers.ONEWAY

	if is_on_floor():
		_coyote = COYOTE_TIME
		_dash_charges = max_dash_charges()
		_air_jumps = 1 if ClimbState.chip_on(Catalog.MOVEMENT, &"double_jump") else 0
		_jet_left = JETPACK_TIME
	else:
		_coyote -= delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer -= delta

	if _grapple_time > 0.0:
		_grapple_time -= delta
		velocity = global_position.direction_to(_grapple_point) * GRAPPLE_SPEED
		if global_position.distance_to(_grapple_point) < 10.0:
			_grapple_time = 0.0
		move_and_slide()
		if _grapple_time <= 0.0:
			velocity *= 0.5
		return

	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_dir * DASH_SPEED
		_ghost_hits()
		if _dash_time <= 0.0:
			velocity *= 0.45
		move_and_slide()
		return

	var input := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))

	_update_stealth(delta)
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 and _dash_charges > 0:
		break_stealth()
		_start_dash(input)
		return

	var gravity := GRAVITY
	if velocity.y > 0.0:
		gravity *= FALL_GRAVITY_MULT
	elif absf(velocity.y) < APEX_THRESHOLD and Input.is_action_pressed("jump"):
		gravity *= APEX_GRAVITY_MULT
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)

	var on_wall := ClimbState.chip_on(Catalog.MOVEMENT, &"wall_jump") and is_on_wall_only() and input.x != 0.0
	if on_wall:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)  # 貼牆下滑

	if ClimbState.chip_on(Catalog.MOVEMENT, &"jetpack") and not is_on_floor() and velocity.y > 0.0 \
			and Input.is_action_pressed("jump") and _jet_left > 0.0 and _jump_buffer <= 0.0:
		_jet_left -= delta
		velocity.y = minf(velocity.y, JETPACK_FALL_SPEED)

	if Input.is_action_just_pressed("move_down") and is_on_floor():
		collision_mask &= ~Layers.ONEWAY
		_drop_time = DROP_THROUGH_TIME

	if _jump_buffer > 0.0 and stealthed:
		break_stealth()   # 跳躍會解除潛行
	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			_jump(Vector2(velocity.x, JUMP_VELOCITY * _jump_mult()))
		elif on_wall:
			_jump(Vector2(get_wall_normal().x * WALL_JUMP_PUSH, JUMP_VELOCITY * 0.9 * _jump_mult()))
		elif _air_jumps > 0:
			_air_jumps -= 1
			_jump(Vector2(velocity.x, JUMP_VELOCITY * 0.85 * _jump_mult()))
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var speed := RUN_SPEED * (1.0 + ClimbState.skill_stat(Catalog.MOVEMENT, &"run_speed"))
	if stealthed:
		speed *= STEALTH_SPEED_MULT
	velocity.x = move_toward(velocity.x, input.x * speed, accel * delta)
	move_and_slide()


## 按住潛行鍵、站在地上就進入潛行；放開或離地就解除
func _update_stealth(delta: float) -> void:
	_stealth_cd = maxf(_stealth_cd - delta, 0.0)
	var want := Input.is_action_pressed("stealth") and is_on_floor() and _grapple_time <= 0.0
	if stealthed and not want:
		break_stealth()
	elif not stealthed and want and _stealth_cd <= 0.0:
		stealthed = true
		Audio.sfx("stealth", -6.0)


## 解除潛行（跳躍、衝刺、開槍、近戰出手、被打中）；之後要等一下才能再潛行
func break_stealth() -> void:
	if not stealthed:
		return
	stealthed = false
	_stealth_cd = STEALTH_COOLDOWN


## 獵物的感知範圍倍率（潛行時縮小）
func sense_mult() -> float:
	return STEALTH_SENSE_MULT if stealthed else 1.0


func _jump(new_velocity: Vector2) -> void:
	velocity = new_velocity
	Audio.sfx("jump")
	_jump_buffer = 0.0
	_coyote = 0.0


## 彈簧腿：跳躍初速提升（插在移動槽）
func _jump_mult() -> float:
	return 1.0 + ClimbState.skill_stat(Catalog.MOVEMENT, &"jump")


func _start_dash(input: Vector2) -> void:
	_dash_dir = input.normalized() if input != Vector2.ZERO else Vector2(facing, 0.0)
	Audio.sfx("dash")
	_dash_time = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN / (1.0 + ClimbState.skill_stat(Catalog.MOVEMENT, &"rate"))
	_dash_charges -= 1
	_dash_hits.clear()


## 幽靈迴路：衝刺穿過敵人時造成傷害；共鳴「幽靈突襲」讓牠們直接喘息
func _ghost_hits() -> void:
	if not ClimbState.has_chip(&"ghost"):
		return
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey and not _dash_hits.has(prey) and prey.global_position.distance_to(global_position) < 16.0:
			_dash_hits.append(prey)
			if ClimbState.has_synergy(&"phantom_dash"):
				prey.exhaust()
			prey.take_damage(GHOST_DAMAGE)


## 鉤爪打中牆壁：把自己拉過去
func grapple_to(point: Vector2) -> void:
	_grapple_point = point
	_grapple_time = GRAPPLE_TIME
	_dash_charges = max_dash_charges()


func is_dashing() -> bool:
	return _dash_time > 0.0


func take_hit(amount: float, from: Vector2) -> void:
	if dead or _invuln > 0.0 or is_dashing():
		return  # 衝刺中無敵
	_invuln = HIT_INVULN_TIME
	break_stealth()
	if passives.consume_shield():
		Audio.sfx("shield")
		return
	Audio.sfx("hurt")
	RunState.add_energy(-amount * (1.0 + ClimbState.stat(&"damage_taken")))
	var push := signf(global_position.x - from.x)
	if push == 0.0:
		push = -facing
	velocity = Vector2(push * 200.0, -180.0)


func _draw() -> void:
	if _invuln > 0.0 and int(_invuln * 20.0) % 2 == 0:
		return
	var flip := facing < 0.0
	var frame := 0                      # 0 站立、1-2 跑步、3 空中、4 衝刺
	if is_dashing():
		frame = 4
		Art.draw(self, "player", 5, frame, -_dash_dir * 8.0, flip, Color(0.4, 1.0, 1.0, 0.35))
	elif not is_on_floor():
		frame = 3
	elif absf(velocity.x) > 20.0:
		frame = 1 + int(_anim_t * 10.0) % 2
	if stealthed:
		# 潛行：半透明、變暗，腳下畫出大概的「被發現距離」
		draw_arc(Vector2(0.0, BODY_SIZE.y * 0.5), 130.0 * STEALTH_SENSE_MULT, PI, TAU, 24, Color(0.6, 0.4, 1.0, 0.35), 1.0)
		Art.draw(self, "player", 5, frame, Vector2.ZERO, flip, Color(0.55, 0.5, 0.9, 0.5))
	else:
		Art.draw(self, "player", 5, frame, Vector2.ZERO, flip)
	var shoulder := Vector2(0.0, -2.0)
	var gun := Color("ff2244") if weapons and weapons.jam_left > 0.0 else Color("e6f7ff")
	draw_line(shoulder, shoulder + aim_dir * 11.0, gun, 2.0)
	if _jet_left < JETPACK_TIME and velocity.y >= 0.0 and not is_on_floor() and Input.is_action_pressed("jump") \
			and ClimbState.chip_on(Catalog.MOVEMENT, &"jetpack") and _jet_left > 0.0:
		draw_rect(Rect2(-3, BODY_SIZE.y * 0.5, 6, 3 + randf() * 3.0), Color("ffb000"))
