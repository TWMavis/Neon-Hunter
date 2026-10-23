class_name Art
extends RefCounted
## 讀取 art/ 的像素圖並畫出某一格影格。圖由 tools/generate_assets.gd 產生，影格橫向排列。
## 優先讀匯入後的資源；還沒匯入時（例如剛產生完、命令列測試）直接讀 PNG。

static var _cache: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "res://art/%s.png" % name
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	else:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			texture = ImageTexture.create_from_image(img)
	_cache[name] = texture
	return texture


## 以 center 為中心畫第 frame 格（共 frames 格）；flip 為左右翻轉（圖預設面向右）
static func draw(canvas: CanvasItem, name: String, frames: int, frame: int, center: Vector2, flip := false, modulate := Color.WHITE) -> void:
	var t := tex(name)
	if t == null:
		return
	var fw := int(t.get_width() / float(frames))
	var fh := t.get_height()
	var src := Rect2(fw * posmod(frame, frames), 0, fw, fh)
	canvas.draw_set_transform(center, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	canvas.draw_texture_rect_region(t, Rect2(-fw * 0.5, -fh * 0.5, fw, fh), src, modulate)
	canvas.draw_set_transform(Vector2.ZERO)
