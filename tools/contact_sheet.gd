extends SceneTree
## 把 art/ 裡所有精靈圖放大 6 倍拼成一張預覽圖：
##   Godot --headless --path . --script res://tools/contact_sheet.gd -- <輸出路徑.png>

const SCALE := 6


func _init() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://contact_sheet.png"
	var images: Array[Image] = []
	for file in DirAccess.get_files_at("res://art"):
		if file.ends_with(".png"):
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/" + file))
			img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
			images.append(img)
	var width := 1200
	var x := 0
	var y := 0
	var row_h := 0
	var places: Array[Vector2i] = []
	for img in images:
		if x + img.get_width() > width:
			x = 0
			y += row_h + 8
			row_h = 0
		places.append(Vector2i(x, y))
		x += img.get_width() + 8
		row_h = maxi(row_h, img.get_height())
	var sheet := Image.create(width, y + row_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.18, 0.3))
	for i in images.size():
		sheet.blend_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), places[i])
	sheet.save_png(out_path)
	quit()
