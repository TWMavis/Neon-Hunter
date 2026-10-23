extends Node
## 預覽電梯晶片配置畫面（錄畫面用）：Godot --path . res://tests/preview_elevator.tscn


func _ready() -> void:
	ClimbState.new_climb(&"pulse_rifle", &"em_net")
	ClimbState.passives.append(&"drone")
	ClimbState.passives.append(&"shield")
	for id: StringName in [&"overclock", &"pierce", &"heatsink", &"magnet", &"kinetic", &"glass_cannon"]:
		ClimbState.owned[id] = 0
	ClimbState.owned[&"overclock"] = 1
	ClimbState.equip(&"overclock", &"pulse_rifle")
	ClimbState.equip(&"pierce", &"pulse_rifle")
	ClimbState.equip(&"heatsink", &"em_net")
	ClimbState.equip(&"kinetic", &"drone")
	ClimbState.owned[&"dash_cap"] = 0
	ClimbState.equip(&"dash_cap", Catalog.MOVEMENT)
	var elevator: Control = load("res://scenes/elevator/elevator_scene.tscn").instantiate()
	add_child(elevator)
	await get_tree().process_frame
	(elevator.get("_chips") as ChipPanel)._on_select(&"magnet")
	if OS.get_cmdline_user_args().has("shop"):
		ClimbState.credits = 140
		(elevator.get("_shop") as ShopPanel).refresh()
		var tabs := (elevator.get("_shop") as Control).get_parent() as TabContainer
		tabs.current_tab = 1
