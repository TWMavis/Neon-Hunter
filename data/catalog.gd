class_name Catalog
extends RefCounted
## 資料表：晶片、共鳴、被動技能、武器。調平衡改這裡。

const PRIMARY_WEAPONS := {
	&"pulse_rifle": ["脈衝步槍", "中距離連射，最平衡"],
	&"shotgun": ["霰彈槍", "近距離高傷害，擊退能把獵物推進死角"],
	&"homing_darts": ["追蹤飛鏢", "傷害低但會轉彎，專打逃跑中的目標"],
}

const SECONDARY_WEAPONS := {
	&"em_net": ["電磁網", "命中後定身 2 秒"],
	&"grapple": ["鉤爪砲", "打中獵物把牠拉過來；打中牆壁把自己拉過去"],
	&"emp_grenade": ["EMP 手雷", "拋物線投擲，範圍緩速"],
}

const PASSIVES := {
	&"drone": ["僚機無人機", "自動射擊附近的獵物"],
	&"plasma_aura": ["電漿光環", "持續傷害貼身的獵物"],
	&"radar": ["雷達掃描", "畫面外所有獵物都會顯示，定時標記獵物（受到額外傷害）"],
	&"shield": ["護盾產生器", "定時擋下一次傷害"],
}

## 「移動」技能（跳躍・衝刺）：每個角色都有，有自己的晶片槽與額度，移動類晶片只能插在這裡
const MOVEMENT := &"movement"
const MOVEMENT_INFO := ["移動", "跳躍與衝刺"]

## 這些數值不管插在哪個技能上都是全身生效
const BODY_KEYS: Array[StringName] = [&"pickup_range", &"energy_max", &"energy_drain", &"kill_energy", &"damage_taken"]

const PRIMARY: Array[StringName] = [&"pulse_rifle", &"shotgun", &"homing_darts"]
const DAMAGE_SKILLS: Array[StringName] = [&"pulse_rifle", &"shotgun", &"homing_darts", &"grapple", &"emp_grenade", &"drone", &"plasma_aura"]
const COOLDOWN_SKILLS: Array[StringName] = [&"em_net", &"grapple", &"emp_grenade", &"drone", &"plasma_aura", &"radar", &"shield"]

static var _chips: Dictionary = {}
static var _synergies: Array[SynergyData] = []


static func chips() -> Dictionary:
	if _chips.is_empty():
		_build_chips()
	return _chips


static func chip(id: StringName) -> ChipData:
	return chips().get(id) as ChipData


static func synergies() -> Array[SynergyData]:
	if _synergies.is_empty():
		_build_synergies()
	return _synergies


static func item_name(id: StringName) -> String:
	if id == MOVEMENT:
		return MOVEMENT_INFO[0]
	for table: Dictionary in [PRIMARY_WEAPONS, SECONDARY_WEAPONS, PASSIVES]:
		if table.has(id):
			return table[id][0]
	var c := chip(id)
	return c.display_name if c else String(id)


## 「可插在：…」的說明
static func allowed_text(c: ChipData) -> String:
	if c.allowed.is_empty():
		return "任何技能"
	var names: PackedStringArray = []
	for id in c.allowed:
		names.append(item_name(id))
	if names.size() > 3:
		return "%s 等 %d 個技能" % ["、".join(names.slice(0, 2)), names.size()]
	return "、".join(names)


static func _build_chips() -> void:
	var G := ChipData.Rarity.GENERIC
	var E := ChipData.Rarity.EXCLUSIVE
	var L := ChipData.Rarity.LEGENDARY
	var B := ChipData.Rarity.BLACK_MARKET
	var any: Array[StringName] = []
	var rate_skills: Array[StringName] = PRIMARY.duplicate()
	rate_skills.append_array([&"drone", &"plasma_aura"])
	# 全身生效（插在任何技能都行）
	_add(&"magnet", "磁力線圈", 1, G, any, {&"pickup_range": 0.5}, "拾取範圍 +50%")
	_add(&"battery", "電池擴充", 1, G, any, {&"energy_max": 0.3}, "電量上限 +30%")
	_add(&"efficiency", "節能迴路", 1, G, any, {&"energy_drain": -0.2}, "電量消耗 -20%")
	# 移動類：只能插在「移動」槽
	var move: Array[StringName] = [MOVEMENT]
	_add(&"dash_cap", "衝刺電容", 2, G, move, {&"dash_charges": 1.0}, "衝刺次數 +1")
	_add(&"sprint_motor", "疾行馬達", 1, G, move, {&"run_speed": 0.15}, "移動速度 +15%")
	_add(&"spring_legs", "彈簧腿", 2, G, move, {&"jump": 0.12}, "跳躍高度提升")
	_add(&"dash_circuit", "衝刺迴路", 2, G, move, {&"rate": 0.4}, "衝刺冷卻 -30%")
	_add(&"double_jump", "二段跳", 2, G, move, {}, "空中可以再跳一次")
	_add(&"wall_jump", "牆跳", 1, G, move, {}, "貼牆時可以蹬牆跳，下滑變慢")
	_add(&"jetpack", "推進器滯空", 2, G, move, {}, "下落時按住跳躍鍵可以滯空 1 秒")
	# 強化所插的技能
	_add(&"overclock", "超頻核心", 2, G, rate_skills, {&"rate": 0.2}, "這個技能的射速 +20%")
	_add(&"heatsink", "散熱鰭片", 2, G, COOLDOWN_SKILLS, {&"rate": 0.33}, "這個技能的冷卻 -25%")
	_add(&"kinetic", "動能放大器", 2, G, DAMAGE_SKILLS, {&"damage": 0.25}, "這個技能的傷害 +25%")
	_add(&"hunter_instinct", "獵人直覺", 2, G, DAMAGE_SKILLS, {&"exhausted_damage": 0.4}, "這個技能對喘息、被網住的獵物傷害 +40%")
	# 專屬
	_add(&"pierce", "貫穿彈頭", 2, E, [&"pulse_rifle"], {&"pierce": 2.0}, "子彈貫穿 2 個敵人")
	_add(&"chain_net", "連鎖網", 2, E, [&"em_net"], {}, "網子命中後彈到附近 1 個敵人")
	_add(&"twin_hook", "雙鉤", 3, E, [&"grapple"], {}, "可以連續發射兩次")
	_add(&"drone_two", "二號機", 3, E, [&"drone"], {}, "多一台無人機")
	# 傳說
	_add(&"gluttony", "暴食協定", 4, L, any, {&"kill_energy": 1.0, &"energy_drain": 0.5}, "擊殺回電 ×2，但電量消耗 ×1.5")
	_add(&"ghost", "幽靈迴路", 4, L, [MOVEMENT], {}, "衝刺穿過敵人時造成傷害")
	# 黑市
	_add(&"glass_cannon", "玻璃大砲", 1, B, DAMAGE_SKILLS, {&"damage": 0.6, &"damage_taken": 1.0}, "這個技能傷害 +60%，但你受到的傷害加倍")
	_add(&"hot_barrel", "過熱槍管", 1, B, PRIMARY, {&"rate": 0.3}, "射速 +30%，但連射超過 3 秒會卡彈")


static func _add(id: StringName, display_name: String, cost: int, rarity: ChipData.Rarity, allowed: Array, modifiers: Dictionary, description: String) -> void:
	var c := ChipData.new()
	c.id = id
	c.display_name = display_name
	c.cost = cost
	c.rarity = rarity
	c.allowed.assign(allowed)
	c.modifiers = modifiers
	c.description = description
	_chips[id] = c


static func _build_synergies() -> void:
	_add_synergy(&"railgun", "軌道槍", &"pulse_rifle", [&"overclock", &"pierce"], [], "脈衝步槍插上超頻核心＋貫穿彈頭：無限貫穿、彈速與傷害大增")
	_add_synergy(&"capture_array", "捕獸陣列", &"em_net", [&"chain_net", &"magnet"], [], "電磁網插上連鎖網＋磁力線圈：網住的獵物會互相吸在一起")
	_add_synergy(&"hound_swarm", "獵犬蜂群", &"homing_darts", [&"hunter_instinct"], [&"radar"], "追蹤飛鏢插上獵人直覺，且持有雷達：一次三枚，轉彎更快")
	_add_synergy(&"phantom_dash", "幽靈突襲", MOVEMENT, [&"ghost", &"dash_cap"], [], "移動槽插上幽靈迴路＋衝刺電容：衝刺穿過的敵人直接喘息")


static func _add_synergy(id: StringName, display_name: String, skill: StringName, chip_ids: Array, also: Array, description: String) -> void:
	var s := SynergyData.new()
	s.id = id
	s.display_name = display_name
	s.skill = skill
	s.chips.assign(chip_ids)
	s.also.assign(also)
	s.description = description
	_synergies.append(s)
