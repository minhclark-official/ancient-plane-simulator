extends SceneTree
## Generates res://assets/sprites/albionos_logo.png (halftone albionOS wordmark, same algorithm as the HTML game).
## Run WINDOWED:  godot --path . --script res://tools/make_logo.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 460)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var c := Control.new()
	c.set_script(load("res://tools/logo_canvas.gd"))
	c.size = Vector2(1280, 460)
	vp.add_child(c)
	await process_frame
	await process_frame
	await process_frame
	var src := vp.get_texture().get_image()
	src.convert(Image.FORMAT_RGBA8)
	var W := 1280
	var H := 460
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var col := Color("#f4f8ff")
	var cell := 15
	var ca := cos(PI / 4.0)
	var sa := sin(PI / 4.0)
	for gy in range(-W, W + H, cell):
		for gx in range(-W, W + H, cell):
			var px := gx * ca - gy * sa + W / 2.0
			var py := gx * sa + gy * ca + H / 2.0
			if px < 0 or py < 0 or px >= W or py >= H:
				continue
			var s := 0.0
			var n := 0
			for dy in [-5, 0, 5]:
				for dx in [-5, 0, 5]:
					var sx := clampi(roundi(px + dx), 0, W - 1)
					var sy := clampi(roundi(py + dy), 0, H - 1)
					s += src.get_pixel(sx, sy).r
					n += 1
			var cov := s / n
			if cov < 0.1:
				continue
			var r := cell * 0.74 * sqrt(cov)
			for yy in range(int(py - r) - 1, int(py + r) + 2):
				for xx in range(int(px - r) - 1, int(px + r) + 2):
					if xx < 0 or yy < 0 or xx >= W or yy >= H:
						continue
					var d := Vector2(xx + 0.5 - px, yy + 0.5 - py).length()
					if d <= r:
						out.set_pixel(xx, yy, col)
	out.save_png("res://assets/sprites/albionos_logo.png")
	print("logo saved")
	quit()
