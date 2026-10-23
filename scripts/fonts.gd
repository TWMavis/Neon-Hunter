class_name Fonts
extends RefCounted
## 共用的介面字型（使用系統的中文字型）

static var _ui: Font


static func ui() -> Font:
	if _ui == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray([
			"Microsoft JhengHei", "Microsoft JhengHei UI", "PingFang TC", "Noto Sans CJK TC", "sans-serif",
		])
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_ui = font
	return _ui
