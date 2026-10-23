extends Node
## 本層樓的執行狀態：電量、權限碎片、時間、超頻與結算。
##
## 超頻模式：電量歸零時，如果還有超頻機會（ClimbState.overclock_charges），就消耗一次進入超頻：
## 攻擊力加倍、倒數 10 秒。倒數期間擊殺照樣回電，但超頻會持續到時間結束；
## 時間到時電量還是 0 才真的死亡。沒有超頻機會時，電量歸零直接死亡。
## 電量超過上限的部分會累積到超頻條（見 ClimbState.add_overclock_bar）。

signal player_died
signal floor_cleared
signal overclock_started
signal overclock_ended

const OVERCLOCK_TIME := 10.0
const OVERCLOCK_DAMAGE_MULT := 2.0

var max_energy := 100.0
var energy := 100.0
var shards := 0
var quota := 12
var kills := 0
var elapsed := 0.0
var finished := false
var cleared := false
var overclocked := false
var overclock_left := 0.0


func reset(data: FloorData) -> void:
	max_energy = data.energy_max
	energy = max_energy
	shards = 0
	quota = data.quota
	kills = 0
	elapsed = 0.0
	finished = false
	cleared = false
	overclocked = false
	overclock_left = 0.0


func add_energy(amount: float) -> void:
	if finished:
		return
	var next := energy + amount
	if next > max_energy:
		ClimbState.add_overclock_bar(next - max_energy)  # 溢出的電量累積到超頻條
		next = max_energy
	energy = maxf(next, 0.0)
	if energy <= 0.0 and not overclocked:
		if ClimbState.overclock_charges > 0:
			ClimbState.overclock_charges -= 1
			overclocked = true
			overclock_left = OVERCLOCK_TIME
			overclock_started.emit()
		else:
			_die()


## 每個物理幀由 Game 呼叫
func tick(delta: float) -> void:
	if finished or not overclocked:
		return
	overclock_left -= delta
	if overclock_left <= 0.0:
		overclocked = false
		overclock_left = 0.0
		if energy <= 0.0:
			_die()  # 倒數結束時電量還是 0：真的死亡
		else:
			overclock_ended.emit()


func damage_mult() -> float:
	return OVERCLOCK_DAMAGE_MULT if overclocked else 1.0


func _die() -> void:
	finished = true
	player_died.emit()


func add_shards(amount: int) -> void:
	shards += amount


func quota_met() -> bool:
	return shards >= quota


func clear_floor() -> void:
	if finished:
		return
	finished = true
	cleared = true
	floor_cleared.emit()
