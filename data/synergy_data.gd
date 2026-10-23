class_name SynergyData
extends Resource
## 晶片共鳴：skill 這個技能上同時插著 chips 裡的晶片（skill 空字串代表插在任何技能都算），
## 而且 also 裡的技能都持有時觸發。一開始不告訴玩家，發現後才記錄。

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var skill: StringName = &""
@export var chips: Array[StringName] = []
@export var also: Array[StringName] = []
