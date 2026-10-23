class_name ChipData
extends Resource
## 一枚強化晶片。插在哪個技能（武器或被動）上，就只強化那個技能；可以在電梯裡移到別的技能。
## modifiers 裡屬於 Catalog.BODY_KEYS 的項目（拾取範圍、電量等）是全身生效，插在任何技能上都一樣。

enum Rarity { GENERIC, EXCLUSIVE, LEGENDARY, BLACK_MARKET }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var cost := 1
@export var rarity: Rarity = Rarity.GENERIC
@export var allowed: Array[StringName] = []   ## 可以插的技能 id；空的代表任何技能都能插
@export var modifiers: Dictionary = {}        ## 例如 {&"rate": 0.2}；晶片強化 +1、+2 時乘上 1.5、2 倍


func fits(skill: StringName) -> bool:
	return allowed.is_empty() or allowed.has(skill)


func rarity_name() -> String:
	match rarity:
		Rarity.EXCLUSIVE:
			return "專屬"
		Rarity.LEGENDARY:
			return "傳說"
		Rarity.BLACK_MARKET:
			return "黑市"
	return "通用"


func rarity_color() -> Color:
	match rarity:
		Rarity.EXCLUSIVE:
			return Color(0.24, 0.96, 1.0)
		Rarity.LEGENDARY:
			return Color(1.0, 0.7, 0.1)
		Rarity.BLACK_MARKET:
			return Color(1.0, 0.13, 0.27)
	return Color(0.85, 0.85, 0.95)
