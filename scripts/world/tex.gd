class_name Tex
extends RefCounted
## Procedural textures (the HTML game painted these on <canvas> elements).


static func _mip(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Sandstone block atlas (2x2 tiles). With a face image every block carries the face.
static func block_texture(face_img: Image, with_face: bool) -> ImageTexture:
	const N := 2
	const T := 256
	var img := Image.create(T * N, T * N, false, Image.FORMAT_RGBA8)
	var rn := WorldData.Rnd.new(77 if with_face else 91)
	var stones: Array = [Color8(206, 176, 126), Color8(214, 184, 132), Color8(200, 168, 118), Color8(210, 180, 130)]
	var tinted: Image = null
	var pad := 10
	var fs := T - 2 * pad
	if with_face and face_img != null:
		tinted = face_img.duplicate() as Image
		if tinted.is_compressed():
			tinted.decompress()
		tinted.convert(Image.FORMAT_RGBA8)
		tinted.resize(fs, fs, Image.INTERPOLATE_BILINEAR)
		var mult := Color(232.0 / 255.0, 200.0 / 255.0, 150.0 / 255.0)
		var w := 0.62
		var f := Color(1.0 - w + w * mult.r, 1.0 - w + w * mult.g, 1.0 - w + w * mult.b)
		for y in fs:
			for x in fs:
				var px := tinted.get_pixel(x, y)
				tinted.set_pixel(x, y, Color(px.r * f.r, px.g * f.g, px.b * f.b, 1.0))
	for j in N:
		for i in N:
			var ox := i * T
			var oy := j * T
			var k := j * N + i
			var st: Color = stones[k]
			img.fill_rect(Rect2i(ox, oy, T, T), st)
			for n in 700:
				var g := (rn.next() * 40.0 - 20.0) / 255.0
				img.fill_rect(Rect2i(ox + int(rn.next() * T), oy + int(rn.next() * T), 1 + int(rn.next() * 3), 1 + int(rn.next() * 3)),
					Color(st.r + g, st.g + g, st.b + g, 1.0))
			if tinted != null:
				var tf := tinted.duplicate() as Image
				if k % 2 == 1:
					tf.flip_x()
				img.blit_rect(tf, Rect2i(0, 0, fs, fs), Vector2i(ox + pad, oy + pad))
				var fr := Color(0.35, 0.26, 0.15, 0.9)
				img.fill_rect(Rect2i(ox + pad, oy + pad, fs, 3), fr)
				img.fill_rect(Rect2i(ox + pad, oy + pad + fs - 3, fs, 3), fr)
				img.fill_rect(Rect2i(ox + pad, oy + pad, 3, fs), fr)
				img.fill_rect(Rect2i(ox + pad + fs - 3, oy + pad, 3, fs), fr)
			# bevel
			img.fill_rect(Rect2i(ox, oy, T, 4), Color(1.0, 0.96, 0.84, 1.0))
			img.fill_rect(Rect2i(ox, oy, 4, T), Color(1.0, 0.96, 0.84, 1.0))
			img.fill_rect(Rect2i(ox, oy + T - 6, T, 6), Color(0.27, 0.19, 0.1, 1.0))
			img.fill_rect(Rect2i(ox + T - 6, oy, 6, T), Color(0.27, 0.19, 0.1, 1.0))
	return _mip(img)


## Asphalt runway with edge lines, centre dashes and threshold bars (north end up).
static func runway_texture() -> ImageTexture:
	const W := 64
	const L := 1024
	var img := Image.create(W, L, false, Image.FORMAT_RGBA8)
	img.fill(Color8(52, 54, 58))
	var rn := WorldData.Rnd.new(11)
	for i in 1800:
		var g := (40.0 + rn.next() * 28.0) / 255.0
		img.fill_rect(Rect2i(int(rn.next() * W), int(rn.next() * L), 1 + int(rn.next() * 2), 1 + int(rn.next() * 6)), Color(g, g, g + 0.01, 1.0))
	var white := Color8(233, 230, 220)
	img.fill_rect(Rect2i(1, 0, 1, L), white)
	img.fill_rect(Rect2i(W - 2, 0, 1, L), white)
	var y := 70
	while y < L - 70:
		img.fill_rect(Rect2i(W / 2 - 1, y, 2, 12), white)
		y += 24
	for end in 2:
		var y0 := 4 if end == 0 else L - 30
		for i in 8:
			img.fill_rect(Rect2i(5 + int(i * (W - 10) / 7.0), y0, 3, 26), white)
		for off in [150, 300, 450]:
			var yy: int = (y0 + off) if end == 0 else (y0 + 26 - off)
			img.fill_rect(Rect2i(W / 2 - 14, yy, 9, 3), white)
			img.fill_rect(Rect2i(W / 2 + 5, yy, 9, 3), white)
	return _mip(img)


static func grain_texture() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rn := WorldData.Rnd.new(31)
	for y in 128:
		for x in 128:
			var g := 0.86 + rn.next() * 0.26
			img.set_pixel(x, y, Color(g, g, g, 1.0))
	return _mip(img)
