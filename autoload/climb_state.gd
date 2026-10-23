extends Node
## 一次攀登的狀態（跨樓層保存）：區段、樓層、等級、經驗、武器、被動技能、晶片配置。
## 死亡就回到區段起點重新攀登；晶片在攀登結束後重置。
##
## 晶片規則：有一個「總晶片額度」，每升一級 +1（打倒 Boss 也 +1）。
## 玩家把總額度自由分配給各技能（左鍵、右鍵、移動槽、被動），分配給技能的額度就是那個技能能插多少晶片。
## 晶片插在哪個技能上就只強化那個技能（電量、拾取範圍這類全身數值除外）。
## 空洞騎士規則：技能還剩至少 1 格就能插，超出的部分算超載（電量消耗加倍）。

signal loadout_changed
signal synergy_discovered(synergy: SynergyData)

const FLOORS_PER_SECTION := 5     # 4 個一般樓層 + 1 個 Boss 層
const PASSIVE_SLOTS := 4
const START_ALLOCATION := 3      # 開局左鍵、右鍵、移動槽各分到 3 格（總額度 9）
const MAX_CHIP_PLUS := 2
const OVERCLOCK_CHARGES := 3          # 每次攀登的超頻機會
const OVERCLOCK_BAR_MAX := 100.0      # 超頻條滿了回復一次超頻機會

var section := 1
var floor_index := 0
var floor_type := &"normal"
var level := 1
var xp := 0
var total_capacity := START_ALLOCATION * 3   # 總晶片額度（每升一級、打倒 Boss 各 +1）
var allocation: Dictionary = {}               # 技能 id -> 分配到的額度
var primary := &"pulse_rifle"
var secondary := &"em_net"
var passives: Array[StringName] = []
var owned: Dictionary = {}                 # 晶片 id -> 強化等級（0、1、2）
var slot_of: Dictionary = {}               # 晶片 id -> 插在哪個技能；沒有的就在背包
var discovered: Array[StringName] = []     # 發現過的共鳴
var active_synergies: Array[StringName] = []
var overclock_charges := OVERCLOCK_CHARGES
var overclock_bar := 0.0                   # 電量溢出累積，滿了回復一次超頻機會
var credits := 0                           # 信用點：擊殺、通關獲得，在電梯商店花
var shop_stock: Array[StringName] = []     # 電梯商店目前販賣的晶片
var shop_rerolls := 0                      # 這次電梯刷新過幾次（刷新越多次越貴）
var bonus_chip_pick := false               # 黑市層通關後可以挑一枚晶片
var section_cleared := false

var _stats: Dictionary = {}                # 全身數值
var _skill_stats: Dictionary = {}          # 技能 id -> {數值: 加總}


func _ready() -> void:
	new_climb(primary, secondary)  # 直接執行樓層場景（F6）時也有預設配置


func new_climb(primary_id: StringName, secondary_id: StringName) -> void:
	floor_index = 0
	floor_type = &"normal"
	level = 1
	xp = 0
	primary = primary_id
	secondary = secondary_id
	total_capacity = START_ALLOCATION * 3
	allocation = {primary: START_ALLOCATION, secondary: START_ALLOCATION, Catalog.MOVEMENT: START_ALLOCATION}
	passives.clear()
	owned.clear()
	slot_of.clear()
	overclock_charges = OVERCLOCK_CHARGES
	overclock_bar = 0.0
	credits = 0
	shop_stock.clear()
	shop_rerolls = 0
	bonus_chip_pick = false
	section_cleared = false
	_refresh()


func is_boss_floor() -> bool:
	return floor_index == FLOORS_PER_SECTION - 1


func advance_floor(next_type: StringName) -> void:
	floor_index += 1
	floor_type = next_type


# --- 經驗與等級 ---

func xp_to_next() -> int:
	return 4 + level * 3


## 回傳這次升了幾級
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
		total_capacity += 1  # 每升一級，總晶片額度 +1
	return gained


# --- 超頻 ---

## 電量超過上限的部分累積到超頻條；滿了回復一次超頻機會（最多 3 次，次數滿時超頻條停在滿格）
func add_overclock_bar(amount: float) -> void:
	overclock_bar += amount
	while overclock_bar >= OVERCLOCK_BAR_MAX and overclock_charges < OVERCLOCK_CHARGES:
		overclock_bar -= OVERCLOCK_BAR_MAX
		overclock_charges += 1
	if overclock_charges >= OVERCLOCK_CHARGES:
		overclock_bar = minf(overclock_bar, OVERCLOCK_BAR_MAX)


# --- 電梯商店 ---

const SHOP_SIZE := 4
const SHOP_REROLL_BASE := 15
const SHOP_REROLL_STEP := 5
const DIRECT_UPGRADE_MULT := 1.5

## 晶片售價：額度越高越貴；傳說加價、黑市便宜
func chip_price(id: StringName) -> int:
	var c := Catalog.chip(id)
	var price := 20 + c.cost * 15
	match c.rarity:
		ChipData.Rarity.LEGENDARY:
			price += 40
		ChipData.Rarity.BLACK_MARKET:
			price = maxi(price - 15, 15)
	return price


## 直接花錢強化已持有的晶片：購買價的 1.5 倍
func upgrade_price(id: StringName) -> int:
	return ceili(chip_price(id) * DIRECT_UPGRADE_MULT)


func reroll_price() -> int:
	return SHOP_REROLL_BASE + shop_rerolls * SHOP_REROLL_STEP


## 進電梯時呼叫：重新上架
func open_shop() -> void:
	shop_rerolls = 0
	_restock()


func reroll_shop() -> bool:
	if credits < reroll_price():
		return false
	credits -= reroll_price()
	shop_rerolls += 1
	_restock()
	return true


func _restock() -> void:
	var pool: Array[StringName] = []
	for id: StringName in Catalog.chips():
		var maxed := owned.has(id) and chip_plus(id) >= MAX_CHIP_PLUS
		if not maxed and _fits_any_skill(id):
			pool.append(id)
	pool.shuffle()
	shop_stock.assign(pool.slice(0, SHOP_SIZE))


## 買商店的晶片：沒有的就獲得（自動插上或放背包），已經有的就升級一級
func buy(id: StringName) -> String:
	if not shop_stock.has(id) or credits < chip_price(id):
		return ""
	credits -= chip_price(id)
	shop_stock.erase(id)
	if owned.has(id):
		return apply_card({"type": "upgrade", "id": id})
	return apply_card({"type": "chip", "id": id})


func can_upgrade_direct(id: StringName) -> bool:
	return owned.has(id) and chip_plus(id) < MAX_CHIP_PLUS and credits >= upgrade_price(id)


func upgrade_direct(id: StringName) -> String:
	if not can_upgrade_direct(id):
		return ""
	credits -= upgrade_price(id)
	return apply_card({"type": "upgrade", "id": id})


# --- 技能 ---

## 目前持有的技能：左鍵、右鍵、移動、被動
func skills() -> Array[StringName]:
	var list: Array[StringName] = [primary, secondary, Catalog.MOVEMENT]
	list.append_array(passives)
	return list


func has_item(id: StringName) -> bool:
	return id == primary or id == secondary or id == Catalog.MOVEMENT or passives.has(id)


func has_passive(id: StringName) -> bool:
	return passives.has(id)


# --- 晶片 ---

func capacity_of(skill: StringName) -> int:
	return allocation.get(skill, 0)


func allocated_total() -> int:
	var total := 0
	for skill: StringName in allocation:
		total += allocation[skill]
	return total


## 還沒分配出去的額度
func free_capacity() -> int:
	return total_capacity - allocated_total()


## 給技能加減一格額度；不會超過總額度，也不能減到比已插晶片還少
func can_adjust(skill: StringName, delta: int) -> bool:
	if not has_item(skill):
		return false
	if delta > 0:
		return free_capacity() >= delta
	return capacity_of(skill) + delta >= maxi(used(skill), 0) and capacity_of(skill) + delta >= 0


func adjust_capacity(skill: StringName, delta: int) -> bool:
	if not can_adjust(skill, delta):
		return false
	allocation[skill] = capacity_of(skill) + delta
	_refresh()
	return true


func used(skill: StringName) -> int:
	var total := 0
	for id: StringName in slot_of:
		if slot_of[id] == skill:
			total += Catalog.chip(id).cost
	return total


func chips_on(skill: StringName) -> Array[StringName]:
	var list: Array[StringName] = []
	for id: StringName in slot_of:
		if slot_of[id] == skill:
			list.append(id)
	return list


func backpack() -> Array[StringName]:
	var list: Array[StringName] = []
	for id: StringName in owned:
		if not slot_of.has(id):
			list.append(id)
	return list


## 技能還剩至少 1 格就能插，超出的部分算超載
func can_equip(id: StringName, skill: StringName) -> bool:
	return owned.has(id) and not slot_of.has(id) and has_item(skill) \
		and Catalog.chip(id).fits(skill) and used(skill) < capacity_of(skill)


func equip(id: StringName, skill: StringName) -> bool:
	if not can_equip(id, skill):
		return false
	slot_of[id] = skill
	_refresh()
	return true


func unequip(id: StringName) -> void:
	slot_of.erase(id)
	_refresh()


## 把晶片移到另一個技能；放不下就留在原位
func move(id: StringName, skill: StringName) -> bool:
	var old: StringName = slot_of.get(id, &"")
	slot_of.erase(id)
	if can_equip(id, skill):
		slot_of[id] = skill
		_refresh()
		return true
	if old != &"":
		slot_of[id] = old
	_refresh()
	return false


## 找一個放得下這枚晶片、空位最多的技能；沒有就回傳空字串
func best_skill_for(id: StringName) -> StringName:
	var best := &""
	var best_free := 0
	for skill in skills():
		if Catalog.chip(id).fits(skill):
			var free := capacity_of(skill) - used(skill)
			if free > best_free:
				best_free = free
				best = skill
	return best


## 新晶片自動插上：先找有空位的技能；都滿了就從未分配的額度撥 1 格給第一個合適的技能
func auto_equip(id: StringName) -> StringName:
	var skill := best_skill_for(id)
	if skill == &"" and free_capacity() > 0:
		for s in skills():
			if Catalog.chip(id).fits(s) and used(s) >= capacity_of(s):
				allocation[s] = capacity_of(s) + 1
				skill = s
				break
	if skill != &"" and equip(id, skill):
		return skill
	return &""


func skill_overloaded(skill: StringName) -> bool:
	return used(skill) > capacity_of(skill)


func is_overloaded() -> bool:
	for skill in skills():
		if skill_overloaded(skill):
			return true
	return false


func chip_plus(id: StringName) -> int:
	return owned.get(id, 0)


## 晶片有沒有插著（插在哪都算）
func has_chip(id: StringName) -> bool:
	return slot_of.has(id)


func chip_on(skill: StringName, id: StringName) -> bool:
	return slot_of.get(id, &"") == skill


func has_synergy(id: StringName) -> bool:
	return active_synergies.has(id)


## 全身數值（電量、拾取範圍、衝刺次數……）
func stat(key: StringName) -> float:
	return _stats.get(key, 0.0)


## 某個技能身上晶片的數值（射速、傷害、冷卻……）
func skill_stat(skill: StringName, key: StringName) -> float:
	var table: Dictionary = _skill_stats.get(skill, {})
	return table.get(key, 0.0)


func _refresh() -> void:
	_stats.clear()
	_skill_stats.clear()
	for id: StringName in slot_of:
		var skill: StringName = slot_of[id]
		var c := Catalog.chip(id)
		var mult := 1.0 + 0.5 * chip_plus(id)
		if not _skill_stats.has(skill):
			_skill_stats[skill] = {}
		var table: Dictionary = _skill_stats[skill]
		for key: StringName in c.modifiers:
			var value := float(c.modifiers[key]) * mult
			if Catalog.BODY_KEYS.has(key):
				_stats[key] = stat(key) + value
			else:
				table[key] = table.get(key, 0.0) + value

	active_synergies.clear()
	for s in Catalog.synergies():
		if _synergy_ok(s):
			active_synergies.append(s.id)
			if not discovered.has(s.id):
				discovered.append(s.id)
				synergy_discovered.emit(s)
	loadout_changed.emit()


func _synergy_ok(s: SynergyData) -> bool:
	if s.skill != &"" and not has_item(s.skill):
		return false
	for id in s.chips:
		if not (has_chip(id) if s.skill == &"" else chip_on(s.skill, id)):
			return false
	for id in s.also:
		if not has_item(id):
			return false
	return true


# --- 三選一卡片 ---

## 升級時的三選一：新晶片、晶片強化、新被動（被動欄還沒滿才會出現）
func roll_level_up_cards(count := 3) -> Array[Dictionary]:
	var pool := _chip_pool()
	if passives.size() < PASSIVE_SLOTS:
		for id: StringName in Catalog.PASSIVES:
			if not passives.has(id):
				pool.append({"type": "passive", "id": id})
	return _deal(pool, count)


## 寶箱、黑市：只出晶片
func roll_chip_cards(count := 3) -> Array[Dictionary]:
	return _deal(_chip_pool(), count)


func _chip_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for id: StringName in Catalog.chips():
		if not owned.has(id):
			if _fits_any_skill(id):
				pool.append({"type": "chip", "id": id})
		elif chip_plus(id) < MAX_CHIP_PLUS:
			pool.append({"type": "upgrade", "id": id})
	return pool


func _fits_any_skill(id: StringName) -> bool:
	for skill in skills():
		if Catalog.chip(id).fits(skill):
			return true
	return false


func _deal(pool: Array[Dictionary], count: int) -> Array[Dictionary]:
	pool.shuffle()
	var cards: Array[Dictionary] = []
	for card in pool:
		if cards.size() >= count:
			break
		cards.append(card)
	if cards.is_empty():
		cards.append({"type": "energy", "id": &""})  # 全部拿滿：改給電量
	return cards


## 回傳 [標題, 標籤, 說明]
func describe_card(card: Dictionary) -> PackedStringArray:
	var id: StringName = card["id"]
	match card["type"]:
		"chip":
			var c := Catalog.chip(id)
			var tag := "新晶片・%s・額度 %d" % [c.rarity_name(), c.cost]
			return PackedStringArray([c.display_name, tag, "%s\n可插在：%s" % [c.description, Catalog.allowed_text(c)]])
		"upgrade":
			var c := Catalog.chip(id)
			var plus := chip_plus(id) + 1
			return PackedStringArray(["%s +%d" % [c.display_name, plus], "晶片強化・額度不變", "效果提升到 %d%%" % int(100 + 50 * plus)])
		"passive":
			var info: Array = Catalog.PASSIVES[id]
			return PackedStringArray([info[0], "新被動技能（%d / %d 格）" % [passives.size() + 1, PASSIVE_SLOTS], info[1]])
	return PackedStringArray(["緊急充電", "全部滿級", "電量回復 40"])


## 回傳要顯示的提示文字
func apply_card(card: Dictionary) -> String:
	var id: StringName = card["id"]
	match card["type"]:
		"chip":
			owned[id] = 0
			var skill := auto_equip(id)
			if skill != &"":
				return "%s 插到 %s" % [Catalog.chip(id).display_name, Catalog.item_name(skill)]
			_refresh()
			return "%s 放進背包（到電梯裡再配置）" % Catalog.chip(id).display_name
		"upgrade":
			owned[id] = chip_plus(id) + 1
			_refresh()
			return "%s 強化到 +%d" % [Catalog.chip(id).display_name, chip_plus(id)]
		"passive":
			passives.append(id)
			_refresh()
			return "獲得被動：%s" % Catalog.PASSIVES[id][0]
	RunState.add_energy(40.0)
	return "電量回復 40"
