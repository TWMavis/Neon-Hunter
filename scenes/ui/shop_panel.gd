class_name ShopPanel
extends ScrollContainer
## 電梯商店：每次賣一把武器和幾枚隨機晶片（買到已持有的晶片就升一級）、花錢刷新商品、
## 或花購買價 1.5 倍直接強化已持有的晶片。用信用點付款。
## 整個商店頁面可以上下捲動（滑鼠滾輪或右側捲軸）。

signal changed

var _credits_label: Label
var _reroll_button: Button
var _stock_box: HFlowContainer
var _upgrade_box: HFlowContainer
var _message: Label


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	add_child(body)

	var head := HBoxContainer.new()
	body.add_child(head)
	_credits_label = UiTheme.label("", UiTheme.YELLOW, 11)
	_credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_credits_label)
	_reroll_button = Button.new()
	_reroll_button.add_theme_font_size_override("font_size", 9)
	_reroll_button.pressed.connect(_on_reroll)
	head.add_child(_reroll_button)

	_message = UiTheme.label("擊殺獵物、通關樓層可以賺信用點", UiTheme.DIM, 9)
	_message.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.add_child(_message)
	body.add_child(UiTheme.label("販賣中（已持有的晶片買了會升一級）", UiTheme.CYAN, 10))
	_stock_box = HFlowContainer.new()
	body.add_child(_stock_box)
	body.add_child(UiTheme.label("直接強化（購買價的 1.5 倍）", UiTheme.MAGENTA, 10))
	_upgrade_box = HFlowContainer.new()
	_upgrade_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_upgrade_box)
	refresh()


func refresh() -> void:
	_credits_label.text = "信用點 %d" % ClimbState.credits
	_reroll_button.text = "刷新商品（%d）" % ClimbState.reroll_price()
	_reroll_button.disabled = ClimbState.credits < ClimbState.reroll_price()

	for child in _stock_box.get_children():
		child.queue_free()
	if ClimbState.shop_weapon != &"":
		var w := ClimbState.shop_weapon
		var hand := "左鍵" if Catalog.PRIMARY_WEAPONS.has(w) else "右鍵"
		var weapon_button := _item_button("%s（%s武器）\n%d 信用點" % [Catalog.item_name(w), hand, ClimbState.weapon_price(w)], UiTheme.YELLOW)
		weapon_button.disabled = ClimbState.credits < ClimbState.weapon_price(w)
		weapon_button.pressed.connect(_on_buy_weapon)
		weapon_button.mouse_entered.connect(func() -> void: _message.text = "%s：%s" % [Catalog.item_name(w), ClimbState.describe_card({"type": "weapon", "id": w})[2]])
		_stock_box.add_child(weapon_button)
	if ClimbState.shop_stock.is_empty() and ClimbState.shop_weapon == &"":
		_stock_box.add_child(UiTheme.label("賣完了", UiTheme.DIM, 9))
	for id in ClimbState.shop_stock:
		var c := Catalog.chip(id)
		var price := ClimbState.chip_price(id)
		var tag := "升到 +%d" % (ClimbState.chip_plus(id) + 1) if ClimbState.owned.has(id) else "新・額度 %d" % c.cost
		var button := _item_button("%s（%s）\n%d 信用點" % [c.display_name, tag, price], c.rarity_color())
		button.disabled = ClimbState.credits < price
		button.pressed.connect(_on_buy.bind(id))
		button.mouse_entered.connect(_describe.bind(id))
		_stock_box.add_child(button)

	for child in _upgrade_box.get_children():
		child.queue_free()
	var any := false
	for id: StringName in ClimbState.owned:
		if ClimbState.chip_plus(id) >= ClimbState.MAX_CHIP_PLUS:
			continue
		any = true
		var c := Catalog.chip(id)
		var button := _item_button("%s +%d → +%d\n%d 信用點" % [c.display_name, ClimbState.chip_plus(id), ClimbState.chip_plus(id) + 1, ClimbState.upgrade_price(id)], c.rarity_color())
		button.disabled = not ClimbState.can_upgrade_direct(id)
		button.pressed.connect(_on_upgrade.bind(id))
		button.mouse_entered.connect(_describe.bind(id))
		_upgrade_box.add_child(button)
	if not any:
		_upgrade_box.add_child(UiTheme.label("沒有可以強化的晶片", UiTheme.DIM, 9))


func _item_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(108, 0)
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", color)
	return button


func _describe(id: StringName) -> void:
	var c := Catalog.chip(id)
	_message.text = "%s（%s・額度 %d）：%s　可插在：%s" % [c.display_name, c.rarity_name(), c.cost, c.description, Catalog.allowed_text(c)]


func _on_buy(id: StringName) -> void:
	var result := ClimbState.buy(id)
	_message.text = result if result != "" else "信用點不足"
	Audio.sfx("buy" if result != "" else "denied")
	_after_change()


func _on_buy_weapon() -> void:
	var result := ClimbState.buy_weapon()
	_message.text = result if result != "" else "信用點不足"
	Audio.sfx("buy" if result != "" else "denied")
	_after_change()


func _on_upgrade(id: StringName) -> void:
	var result := ClimbState.upgrade_direct(id)
	_message.text = result if result != "" else "信用點不足"
	Audio.sfx("buy" if result != "" else "denied")
	_after_change()


func _on_reroll() -> void:
	Audio.sfx("ui_click")
	if not ClimbState.reroll_shop():
		_message.text = "信用點不足"
	_after_change()


func _after_change() -> void:
	refresh.call_deferred()
	changed.emit()
