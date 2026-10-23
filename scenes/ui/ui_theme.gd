class_name UiTheme
extends RefCounted
## 選單共用的霓虹風格主題。

const BG := Color(0.05, 0.03, 0.11, 0.92)
const CYAN := Color(0.24, 0.96, 1.0)
const MAGENTA := Color(1.0, 0.24, 0.94)
const GREEN := Color(0.49, 1.0, 0.42)
const RED := Color(1.0, 0.13, 0.27)
const YELLOW := Color(1.0, 0.88, 0.3)
const WHITE := Color(0.92, 0.95, 1.0)
const DIM := Color(0.55, 0.55, 0.7)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font = Fonts.ui()
	_theme.default_font_size = 11
	_theme.set_stylebox("normal", "Button", _box(Color(0.08, 0.05, 0.17), CYAN.darkened(0.5)))
	_theme.set_stylebox("hover", "Button", _box(Color(0.12, 0.08, 0.25), CYAN))
	_theme.set_stylebox("pressed", "Button", _box(Color(0.2, 0.06, 0.24), MAGENTA))
	_theme.set_stylebox("hover_pressed", "Button", _box(Color(0.24, 0.08, 0.3), MAGENTA))
	_theme.set_stylebox("disabled", "Button", _box(Color(0.06, 0.05, 0.09), Color(0.25, 0.25, 0.3)))
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	_theme.set_color("font_color", "Button", WHITE)
	_theme.set_color("font_hover_color", "Button", CYAN)
	_theme.set_color("font_pressed_color", "Button", MAGENTA)
	_theme.set_color("font_hover_pressed_color", "Button", MAGENTA)
	_theme.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.5))
	_theme.set_color("font_color", "Label", WHITE)
	_theme.set_stylebox("panel", "PanelContainer", _box(BG, CYAN.darkened(0.6)))
	return _theme


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(4)
	return box


static func label(text: String, color := WHITE, size := 11) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
