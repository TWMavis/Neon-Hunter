extends Control
## 電梯：樓層之間的中場。進電梯電量就回滿。
## 1. 配置晶片（免費；樓層中長按 Tab 也能調，但要花電量）
## 1b. 商店：用信用點買晶片、刷新商品、直接強化
## 2. 選路線：兩部電梯通往不同類型的樓層
## 3. 故事片段（大樓廣播）

const GAME_SCENE := "res://scenes/game/game.tscn"
const START_SCENE := "res://scenes/menu/climb_start.tscn"

const FLOOR_TYPES := {
	&"normal": ["一般層", "標準獵殺"],
	&"danger": ["危險層", "獵物更多更快，經驗 ×1.5，精英提早出現"],
	&"repair": ["維修層", "配額少，電量消耗減半"],
	&"black_market": ["黑市層", "通關後可以挑一枚晶片"],
	&"vault": ["金庫層", "全是金色獵物，抓到幾隻就拿幾個寶箱，限時 60 秒"],
}

const BROADCASTS := [
	"「天柱住民請注意：底層第 %d 層的流氓 AI 清除作業，由自由獵手接手。」",
	"「……你還記得頂層的天空嗎？廢料層的人一輩子沒看過。」——陌生的通訊",
	"「企業公告：前首席獵手的權限已全數註銷。發現者請立即通報。」",
	"「第 %d 層偵測到大型回收單位活動。建議所有住民遠離垃圾堆。」",
]

var _chips: ChipPanel
var _shop: ShopPanel
var _route_box: HBoxContainer
var _picker: CardPicker


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.music("music_calm")

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	root.add_child(UiTheme.label(_header(), UiTheme.CYAN, 12))
	var broadcast := UiTheme.label(_broadcast(), UiTheme.DIM, 9)
	broadcast.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	root.add_child(broadcast)

	ClimbState.open_shop()
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 10)
	root.add_child(tabs)
	_chips = ChipPanel.new()
	_chips.name = "晶片配置"
	tabs.add_child(_chips)
	_shop = ShopPanel.new()
	_shop.name = "商店"
	_shop.changed.connect(_chips.refresh)
	tabs.add_child(_shop)

	_route_box = HBoxContainer.new()
	_route_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_route_box.add_theme_constant_override("separation", 8)
	root.add_child(_route_box)
	_build_routes()

	_picker = CardPicker.new()
	_picker.picked.connect(_on_bonus_picked)
	add_child(_picker)

	if ClimbState.bonus_chip_pick:
		ClimbState.bonus_chip_pick = false
		_picker.open("黑市商人：挑一枚晶片", ClimbState.roll_chip_cards())


func _header() -> String:
	if ClimbState.section_cleared:
		return "第 %d 區段完成！廢料層已突破" % ClimbState.section
	return "電梯上行中　第 %d 層 → 第 %d 層　Lv %d　電量已回滿" % [
		ClimbState.floor_index + 1, ClimbState.floor_index + 2, ClimbState.level]


func _broadcast() -> String:
	if ClimbState.section_cleared:
		return "「回收巨獸訊號消失。」你取回了第一枚原裝義體晶片。上面還有五個區段。"
	var line: String = BROADCASTS[ClimbState.floor_index % BROADCASTS.size()]
	return line % (ClimbState.floor_index + 2) if line.contains("%d") else line


func _build_routes() -> void:
	if ClimbState.section_cleared:
		var again := Button.new()
		again.text = "回到起點（第 2 區段之後的內容還在製作中）"
		again.pressed.connect(func() -> void: get_tree().change_scene_to_file(START_SCENE))
		_route_box.add_child(again)
		return
	if ClimbState.floor_index + 1 == ClimbState.FLOORS_PER_SECTION - 1:
		_route_box.add_child(_route_button(&"boss", "Boss 層：回收巨獸", "打倒牠取回核心晶片（總晶片額度 +1）"))
		return
	var options: Array[StringName] = [&"danger", &"repair", &"black_market", &"vault"]
	options.shuffle()
	for type: StringName in [&"normal", options[0]]:
		var info: Array = FLOOR_TYPES[type]
		_route_box.add_child(_route_button(type, info[0], info[1]))


func _route_button(type: StringName, title: String, desc: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(200, 30)
	button.text = "%s\n%s" % [title, desc]
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(_go.bind(type))
	return button


func _go(type: StringName) -> void:
	ClimbState.advance_floor(&"normal" if type == &"boss" else type)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_bonus_picked(card: Dictionary) -> void:
	_chips.show_message(ClimbState.apply_card(card))
	_chips.refresh()
	_shop.refresh()
