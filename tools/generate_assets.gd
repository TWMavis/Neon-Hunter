extends SceneTree
## 素材產生器：像素圖（art/*.png）與音效、音樂（audio/*.wav）全部由這支程式產生，沒有外部素材。
## 改圖就改下面的字元圖，改音就改合成參數，然後重新執行：
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/generate_assets.gd
##
## 字元圖：每個字元是一個像素，對應 PALETTE 的顏色；「.」是透明。精靈圖是橫向排列的影格條。

const PALETTE := {
	"k": "0d0b1a", "B": "2a3d6e", "b": "1b2a4a", "c": "3df5ff", "C": "1a7f8f",
	"m": "ff3df0", "M": "8a1f86", "w": "e6f7ff", "y": "ffe14d", "Y": "b8860b",
	"r": "ff2244", "R": "7a0a1c", "o": "d9772b", "O": "8a4a1c", "g": "9aa3c0",
	"G": "3a3f5c", "s": "8aa3b8", "e": "7dff6a", "E": "2f7a28", "d": "120c24",
	"D": "2b1f52", "n": "6a3fd0",
}

const MIX_RATE := 22050

var _warnings := 0


func _init() -> void:
	seed(20261023)   # 固定亂數，重新產生時音檔不會每次都不同
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio"))
	_make_art()
	_make_sfx()
	_make_music()
	print("assets generated, %d warnings" % _warnings)
	quit()


# =====================================================================
# 像素圖
# =====================================================================

func _make_art() -> void:
	var upper := [
		"...kkkkkk...",
		"..kBBBBBBk..",
		"..kBBBBBBk..",
		"..kBBmmmmk..",
		"..kBBmwmmk..",
		"..kBBBBBBk..",
		"...kkBBkk...",
		"..kcbbbbck..",
		".kbbbbbbbbk.",
		".kbcbbbbcbk.",
		".kbcbbbbcbk.",
		".kbbbbbbbbk.",
		"..kmmmmmmk..",
	]
	var legs := {
		"idle": [
			"..kbbbbbbk..",
			"..kbbkkbbk..",
			"..kbbkkbbk..",
			"..kcbkkcbk..",
			"..kbbkkbbk..",
			"..kbbkkbbk..",
			".kkkk..kkkk.",
		],
		"run1": [
			"..kbbbbbbk..",
			"..kbbk.kbbk.",
			".kbbk...kbbk",
			".kcbk...kcbk",
			"kbbk.....kbk",
			"kbk......kkk",
			"kkk.........",
		],
		"run2": [
			"..kbbbbbbk..",
			"...kbbkbbk..",
			"...kbbkbbk..",
			"...kcbkcbk..",
			"...kbbkbk...",
			"...kbbkbk...",
			"...kkkkkk...",
		],
		"jump": [
			"..kbbbbbbk..",
			"..kbbk.kbbk.",
			".kbbk..kbbk.",
			".kcbk...kck.",
			".kbk.....kk.",
			".kk.........",
			"............",
		],
		"dash": [
			"..kbbbbbbk..",
			".kbbbbbbbk..",
			"kbbkkbbbk...",
			"kck..kcbk...",
			"kk....kbk...",
			"......kk....",
			"............",
		],
	}
	var player_frames: Array = []
	for pose in ["idle", "run1", "run2", "jump", "dash"]:
		player_frames.append(upper + legs[pose])
	_sheet("player", 12, 20, player_frames)
	var hunter_swap := {"B": "R", "b": "R", "c": "r", "m": "r", "w": "y"}
	_sheet("hunter", 12, 20, _swap_frames(player_frames, hunter_swap))

	var rat := [
		[
			"............",
			"......kkkk..",
			"....kkmmmmk.",
			"..kkmmmmmwmk",
			".kmmmmmmmmmk",
			"kMkMMMMMMMk.",
			"...kk..kk...",
			"............",
		],
		[
			"............",
			"......kkkk..",
			"....kkmmmmk.",
			"..kkmmmmmwmk",
			".kmmmmmmmmmk",
			"kMkMMMMMMMk.",
			"....kk..kk..",
			"............",
		],
	]
	_sheet("rat", 12, 8, rat)
	_sheet("golden", 12, 8, _swap_frames(rat, {"m": "y", "M": "Y"}))

	var drone_body := [
		"....kkkk....",
		"...kyyyyk...",
		"..kyyYYyyk..",
		".kyyYwwYyyk.",
		".kyyYwwYyyk.",
		"..kyyYYyyk..",
		"...kyyyyk...",
		"....krrk....",
		".....kk.....",
	]
	_sheet("drone", 12, 10, [["kkkkk..kkkkk"] + drone_body, [".kkk....kkk."] + drone_body])

	_sheet("jumper", 10, 12, [
		[
			"..........",
			"..........",
			"..........",
			"..kk..kk..",
			".kwekkwek.",
			".keeeeeek.",
			"keeEeeEeek",
			"keeeeeeeek",
			".kEeeeeEk.",
			"kEk....kEk",
			"kk......kk",
			"..........",
		],
		[
			"..kk..kk..",
			".kwekkwek.",
			".keeeeeek.",
			"keeEeeEeek",
			"keeeeeeeek",
			".kEeeeeEk.",
			"..keeeek..",
			"..kEkkEk..",
			"..kEk.kEk.",
			"..kk...kk.",
			"..........",
			"..........",
		],
	])

	var rep := [
		"..kkkkkk..",
		".kwwwwwwk.",
		"kwccccccwk",
		"kwckwwkcwk",
		"kwckwwkcwk",
		"kwccccccwk",
		"kwcCCCCcwk",
		"kwccccccwk",
		".kwwwwwwk.",
		"..kkkkkk..",
	]
	_sheet("replicator", 10, 10, [rep, _swap(rep, {"c": "C", "C": "c"})])

	var elite_body := [
		"....kkkkkkkkkkkkkkk.....",
		"...ksssssssssssssssk....",
		"..kssGGGGGGGGGGGGGssk...",
		"..ksGGGGGGGGGGGGGGGsskk.",
		"..ksGGGGGGGGGGGGGGGsssrk",
		"..ksGGGGGGGGGGGGGGGssssk",
		".kssssssssssssssssssssk.",
		".ksyyssssssssssssssyysk.",
		".kssssssssssssssssssssk.",
		"kkkkkkkkkkkkkkkkkkkkkkkk",
	]
	_sheet("elite", 24, 14, [
		elite_body + ["..kGGGk..........kGGGk..", ".kGgggGk........kGgggGk.", ".kGgkgGk........kGgkgGk.", "..kGGGk..........kGGGk.."],
		elite_body + ["..kGGGk..........kGGGk..", ".kGgkgGk........kGgkgGk.", ".kGgggGk........kGgggGk.", "..kGGGk..........kGGGk.."],
	])

	var boss_body := [
		"..............................",
		"..........kkkkkkkkkk..........",
		".......kkkooooooooookkk.......",
		".....kkooooOOOOOOOOooookk.....",
		"....kooOOOOOOOOOOOOOOOOook....",
		"...kooOOOgggOOOOOOgggOOOook...",
		"..kooOOOgGGGgOOOOgGGGgOOOOok..",
		"..koOOOOgGrrgOOOOgGrrgOOOOOk..",
		".kooOOOOgggggOOOOgggggOOOOook.",
		".koOOOOOOOOOOOOOOOOOOOOOOOOOk.",
		".koOOOkwkwkwkwkwkwkwkwkOOOOOk.",
		"kooOOOkkkkkkkkkkkkkkkkkOOOOOok",
		"koOOOOOOOOOOOOOOOOOOOOOOOOOOOk",
		"koOOsOOOOsOOOOOOOsOOOOsOOOOOOk",
		"koOOOOOOOOOOOOOOOOOOOOOOOOOOOk",
		".kooOOOOOOOOOOOOOOOOOOOOOOook.",
		"..kkoooooooooooooooooooookk...",
	]
	_sheet("boss", 30, 20, [
		boss_body + ["..kGGk..kGGk......kGGk..kGGk..", "..kGGk..kGGk......kGGk..kGGk..", "..kkkk..kkkk......kkkk..kkkk.."],
		boss_body + ["...kGGk..kGGk....kGGk..kGGk...", "...kGGk..kGGk....kGGk..kGGk...", "...kkkk..kkkk....kkkk..kkkk..."],
	])

	# 風箏手：拿槍的瘦長機器人
	var kiter_body := [
		"...kkkk...",
		"..kccCCk..",
		"..kcwkCk..",
		"..kCCCCk..",
		"...kbbk...",
		".kkbccbkkk",
		"kCkbccbkgg",
		"...kbbk...",
		"...kBBk...",
	]
	_sheet("kiter", 10, 12, [
		kiter_body + ["..kBkkBk..", "..kBk.kBk.", "..kk...kk."],
		kiter_body + ["...kBBk...", "...kBkBk..", "...kk.kk.."],
	])
	# 佈雷者：背著地雷的螃蟹型機械
	var layer_body := [
		"....kkkkk.....",
		"...kGrGrGk....",
		"..koooooook...",
		".kooOOOOOwok..",
		"koooooooooook.",
		"kOOOOOOOOOOOk.",
		".kkkkkkkkkkk..",
	]
	_sheet("minelayer", 14, 9, [
		layer_body + [".kGk.kGk.kGk..", "kGk..kGk..kGk."],
		layer_body + ["..kGk.kGk.kGk.", ".kGk..kGk..kGk"],
	])
	_sheet("mine", 6, 4, [[
		"..kk..",
		".kGGk.",
		"kGooGk",
		"kkkkkk",
	]])

	_sheet("shard", 7, 9, [[
		"...k...",
		"..kek..",
		".kewek.",
		"keweEek",
		"kewEEek",
		"keEEEek",
		".keEek.",
		"..kek..",
		"...k...",
	]])
	_sheet("energy", 6, 8, [[
		"..kk..",
		".kyyk.",
		"kyyyyk",
		"kywyyk",
		"kyyyyk",
		"kyYYyk",
		"kyyyyk",
		"kkkkkk",
	]])
	_sheet("xp", 4, 4, [[".kk.", "kcwk", "kcck", ".kk."]])
	_sheet("chest", 14, 11, [[
		"..kkkkkkkkkk..",
		".kOOOOOOOOOOk.",
		"kOooooooooooOk",
		"kOooooooooooOk",
		"kkkkkkyykkkkkk",
		"kOooooyyooooOk",
		"kOooooooooooOk",
		"kOooooooooooOk",
		"kOooooooooooOk",
		"kOOOOOOOOOOOOk",
		"kkkkkkkkkkkkkk",
	]])
	_sheet("wingman", 8, 6, [[
		"kkk..kkk",
		"..kkkk..",
		".kyyyyk.",
		"kyywwyyk",
		".kyyyyk.",
		"..krrk..",
	]])

	var bricks := [
		"dddddddddddddddd",
		"dnddddddddddddnd",
		"dddddddddddddddd",
		"DDDDDDDDDDDDDDDD",
		"ddddddddDddddddd",
		"ddddddddDddddddd",
		"ddddddddDddddddd",
		"DDDDDDDDDDDDDDDD",
	]
	_sheet("tile_fill", 16, 16, [bricks + bricks])
	_sheet("tile_top", 16, 16, [["cccccccccccccccc", "CCCCCCCCCCCCCCCC"] + bricks.slice(2) + bricks])
	_sheet("platform", 16, 6, [[
		"mmmmmmmmmmmmmmmm",
		"wmmmmmmmwmmmmmmm",
		"MMMMMMMMMMMMMMMM",
		".kM.......kM....",
		".kM.......kM....",
		"................",
	]])
	_make_elevator()


func _make_elevator() -> void:
	var w := 28
	var h := 40
	var img := Image.create(w * 2, h, false, Image.FORMAT_RGBA8)
	for f in 2:
		var ox := f * w
		img.fill_rect(Rect2i(ox, 0, w, h), _c("k"))
		img.fill_rect(Rect2i(ox + 1, 1, w - 2, h - 1), _c("b"))
		img.fill_rect(Rect2i(ox + 1, 1, w - 2, 4), _c("D"))
		img.fill_rect(Rect2i(ox + 11, 2, 6, 2), _c("G"))   # 指示燈的位置（遊戲中再畫顏色）
		img.fill_rect(Rect2i(ox + 1, 5, w - 2, 1), _c("c"))
		var gap := 1 if f == 0 else 7
		var door := _c("B")
		img.fill_rect(Rect2i(ox + 2, 6, 12 - gap, h - 6), door)
		img.fill_rect(Rect2i(ox + 14 + gap, 6, 12 - gap, h - 6), door)
		for y in range(10, h, 6):
			img.fill_rect(Rect2i(ox + 3, y, 12 - gap - 2, 1), _c("C"))
			img.fill_rect(Rect2i(ox + 15 + gap, y, 12 - gap - 2, 1), _c("C"))
		if f == 1:
			img.fill_rect(Rect2i(ox + 14 - gap, 6, gap * 2, h - 6), _c("d"))
	img.save_png("res://art/elevator.png")


func _c(ch: String) -> Color:
	return Color(PALETTE[ch])


func _swap(rows: Array, mapping: Dictionary) -> Array:
	var out := []
	for row: String in rows:
		var s := ""
		for ch in row:
			s += mapping.get(ch, ch)
		out.append(s)
	return out


func _swap_frames(frames: Array, mapping: Dictionary) -> Array:
	var out := []
	for f: Array in frames:
		out.append(_swap(f, mapping))
	return out


## 把多個影格的字元圖存成一張橫向的 PNG
func _sheet(name: String, w: int, h: int, frames: Array) -> void:
	var img := Image.create(w * frames.size(), h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in frames.size():
		var rows: Array = frames[i]
		if rows.size() != h:
			_warn("%s frame %d: %d rows (want %d)" % [name, i, rows.size(), h])
		for y in mini(rows.size(), h):
			var row: String = rows[y]
			if row.length() != w:
				_warn("%s frame %d row %d: width %d (want %d)" % [name, i, y, row.length(), w])
			for x in mini(row.length(), w):
				var ch := row[x]
				if ch != "." and PALETTE.has(ch):
					img.set_pixel(i * w + x, y, Color(PALETTE[ch]))
	img.save_png("res://art/%s.png" % name)


func _warn(text: String) -> void:
	_warnings += 1
	push_warning(text)
	print("WARN " + text)


# =====================================================================
# 音效
# =====================================================================

func _make_sfx() -> void:
	_save("shoot", _sweep(0.07, 900.0, 420.0, "square", 0.35))
	_save("shotgun", _mix([_noise(0.16, 0.55, 3000.0), _sweep(0.12, 180.0, 70.0, "square", 0.4)]))
	_save("dart", _sweep(0.06, 1200.0, 1700.0, "sine", 0.35))
	_save("net", _sweep(0.18, 300.0, 1000.0, "triangle", 0.45))
	_save("hook", _mix([_sweep(0.12, 520.0, 180.0, "square", 0.35), _noise(0.03, 0.4, 6000.0)]))
	_save("explode", _mix([_noise(0.45, 0.7, 1800.0), _sweep(0.4, 110.0, 40.0, "sine", 0.6)]))
	_save("hit", _mix([_noise(0.04, 0.4, 5000.0), _sweep(0.05, 260.0, 180.0, "square", 0.25)]))
	_save("kill", _mix([_notes([660.0, 990.0], 0.06, "square", 0.3), _noise(0.08, 0.3, 4000.0)]))
	_save("pickup_energy", _sweep(0.09, 880.0, 1320.0, "sine", 0.3))
	_save("pickup_shard", _notes([1320.0, 1760.0], 0.07, "triangle", 0.35))
	_save("pickup_xp", _sweep(0.03, 1500.0, 1800.0, "sine", 0.2))
	_save("levelup", _notes([523.0, 659.0, 784.0, 1047.0], 0.09, "square", 0.3))
	_save("chest", _notes([784.0, 988.0, 1175.0, 1568.0], 0.08, "triangle", 0.4))
	_save("dash", _noise(0.16, 0.35, 2500.0, true))
	_save("jump", _sweep(0.09, 280.0, 620.0, "square", 0.22))
	_save("hurt", _mix([_sweep(0.22, 420.0, 110.0, "square", 0.4), _noise(0.12, 0.3, 2000.0)]))
	_save("shield", _sweep(0.25, 1600.0, 600.0, "triangle", 0.35))
	_save("overclock", _mix([_sweep(0.9, 180.0, 1400.0, "saw", 0.3), _pulses(0.9, 12.0, 0.25)]))
	_save("elevator", _notes([988.0, 1319.0], 0.35, "sine", 0.45))
	_save("purge", _siren(1.4, 600.0, 950.0, 3.0, 0.35))
	_save("hunter", _mix([_sweep(1.0, 90.0, 50.0, "saw", 0.45), _noise(1.0, 0.2, 600.0)]))
	_save("golden", _notes([1047.0, 1319.0, 1568.0, 2093.0], 0.06, "sine", 0.35))
	_save("ui_click", _sweep(0.03, 1000.0, 1100.0, "square", 0.2))
	_save("buy", _notes([988.0, 1319.0], 0.07, "square", 0.3))
	_save("denied", _sweep(0.15, 160.0, 140.0, "square", 0.3))
	_save("burrow", _mix([_noise(0.5, 0.4, 900.0), _sweep(0.5, 140.0, 60.0, "square", 0.3)]))
	_save("enemy_shot", _sweep(0.1, 640.0, 320.0, "triangle", 0.3))
	_save("charge", _mix([_sweep(0.35, 70.0, 150.0, "saw", 0.4), _noise(0.35, 0.25, 1200.0)]))
	_save("blink", _sweep(0.12, 2200.0, 500.0, "sine", 0.3))
	_save("mine", _notes([1800.0, 1800.0], 0.03, "square", 0.2))
	_save("stealth", _sweep(0.25, 500.0, 220.0, "sine", 0.2))
	_save("alert", _notes([1400.0, 1900.0], 0.06, "square", 0.25))
	_save("backstab", _mix([_noise(0.14, 0.5, 8000.0, true), _sweep(0.18, 1400.0, 200.0, "saw", 0.3)]))
	_save("slash", _mix([_noise(0.1, 0.45, 7000.0, true), _sweep(0.08, 900.0, 300.0, "triangle", 0.2)]))


func _wave(shape: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match shape:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
		"saw":
			return 2.0 * p - 1.0
	return sin(p * TAU)


## 頻率從 f0 滑到 f1，音量線性衰減
func _sweep(length: float, f0: float, f1: float, shape: String, volume: float) -> PackedFloat32Array:
	var n := int(length * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / MIX_RATE
		out[i] = _wave(shape, phase) * volume * (1.0 - t) * minf(1.0, i / 40.0)
	return out


func _notes(freqs: Array, each: float, shape: String, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f: float in freqs:
		out.append_array(_sweep(each, f, f, shape, volume))
	return out


## 白噪音（簡單低通），sweep_down 時截止頻率由高往低
func _noise(length: float, volume: float, cutoff: float, sweep_down := false) -> PackedFloat32Array:
	var n := int(length * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / n
		var cut := cutoff * (1.0 - t * 0.8) if sweep_down else cutoff
		var a := clampf(cut / MIX_RATE * TAU, 0.0, 1.0)
		last = lerpf(last, randf_range(-1.0, 1.0), a)
		out[i] = last * volume * (1.0 - t)
	return out


func _pulses(length: float, rate: float, volume: float) -> PackedFloat32Array:
	var n := int(length * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var on := fposmod(t * rate, 1.0) < 0.3
		out[i] = (_wave("square", t * 1200.0) * volume if on else 0.0) * (1.0 - float(i) / n)
	return out


func _siren(length: float, f0: float, f1: float, cycles: float, volume: float) -> PackedFloat32Array:
	var n := int(length * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, 0.5 + 0.5 * sin(t * cycles * TAU))
		phase += f / MIX_RATE
		out[i] = _wave("square", phase) * volume * minf(1.0, (1.0 - t) * 4.0)
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p: PackedFloat32Array in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p: PackedFloat32Array in parts:
		for i in p.size():
			out[i] += p[i]
	return out


func _save(name: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav("res://audio/%s.wav" % name)


# =====================================================================
# 音樂（合成波風格，可無縫循環）
# =====================================================================

func _make_music() -> void:
	# 獵殺：116 BPM，Am - F - C - G，貝斯八分音符、琶音、鼓
	_save("music_hunt", _song(116.0, [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], true, 0.9))
	# 電梯、選單：84 BPM，安靜的墊音與慢琶音
	_save("music_calm", _song(84.0, [[57, 60, 64], [52, 55, 59], [53, 57, 60], [55, 59, 62]], false, 0.7))


func _midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## chords：每個和弦 2 小節（4/4），整首 = 和弦數 × 2 小節
func _song(bpm: float, chords: Array, drums: bool, volume: float) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var length := bar * 2.0 * chords.size()
	var n := int(length * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var step := beat / 2.0      # 八分音符
	var steps := int(round(length / step))
	var arp_pattern := [0, 1, 2, 1, 2, 0, 2, 1]
	for s in steps:
		var t0 := s * step
		var chord: Array = chords[int(t0 / (bar * 2.0)) % chords.size()]
		# 貝斯：八分音符根音，低兩個八度
		_add_tone(out, t0, step * 0.9, _midi(chord[0] - 24), "saw", 0.16 * volume, 0.002, 0.08)
		# 琶音：高一個八度的方波
		var note: int = chord[arp_pattern[s % arp_pattern.size()]] + 12
		_add_tone(out, t0, step * 0.8, _midi(note), "square", (0.05 if drums else 0.04) * volume, 0.003, 0.15)
		if drums:
			var in_beat := s % 2 == 0
			var beat_index := (s / 2) % 4
			if in_beat:
				_add_kick(out, t0, 0.5 * volume)
			if in_beat and (beat_index == 1 or beat_index == 3):
				_add_noise_hit(out, t0, 0.18, 0.22 * volume, 3500.0)
			_add_noise_hit(out, t0, 0.04, 0.06 * volume, 9000.0)
	# 墊音：每個和弦一個長音，慢慢淡入淡出
	for ci in chords.size():
		var chord: Array = chords[ci]
		for note: int in chord:
			_add_tone(out, ci * bar * 2.0, bar * 2.0, _midi(note), "triangle", 0.05 * volume, 0.6, 0.6)
	return out


func _add_tone(out: PackedFloat32Array, start: float, length: float, freq: float, shape: String, volume: float, attack: float, release: float) -> void:
	var i0 := int(start * MIX_RATE)
	var count := int(length * MIX_RATE)
	for i in count:
		var idx := (i0 + i) % out.size()   # 尾巴繞回開頭，讓循環接得上
		var t := float(i) / MIX_RATE
		var env := minf(1.0, t / maxf(attack, 0.0005)) * minf(1.0, (length - t) / maxf(release, 0.0005))
		out[idx] += _wave(shape, t * freq) * volume * env


func _add_kick(out: PackedFloat32Array, start: float, volume: float) -> void:
	var i0 := int(start * MIX_RATE)
	var count := int(0.18 * MIX_RATE)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += lerpf(120.0, 40.0, t) / MIX_RATE
		out[(i0 + i) % out.size()] += sin(phase * TAU) * volume * (1.0 - t)


func _add_noise_hit(out: PackedFloat32Array, start: float, length: float, volume: float, cutoff: float) -> void:
	var hit := _noise(length, volume, cutoff)
	var i0 := int(start * MIX_RATE)
	for i in hit.size():
		out[(i0 + i) % out.size()] += hit[i]
