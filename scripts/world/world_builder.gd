class_name WorldBuilder
extends Node3D
## Builds the 3D world procedurally: terrain, Nile, cities, pyramids, runways and props.

signal progress(fraction: float, text: String)

const FACE_PATH := "res://assets/sprites/face.jpg"

var plane: PlaneModel
var king: MeshInstance3D
var cap: MeshInstance3D
var king_mat: StandardMaterial3D
var built := false


func build() -> void:
	progress.emit(0.0, "TERRAIN DATA")
	await get_tree().process_frame
	WorldData.ensure_grid()
	progress.emit(0.15, "TERRAIN MESH")
	await get_tree().process_frame
	_build_terrain()
	progress.emit(0.35, "NILE")
	await get_tree().process_frame
	_build_river()
	progress.emit(0.45, "CITIES")
	await get_tree().process_frame
	_build_cities()
	progress.emit(0.6, "STONE BLOCKS")
	await get_tree().process_frame
	_build_pyramids()
	progress.emit(0.8, "AIRFIELDS")
	await get_tree().process_frame
	_build_airports()
	_build_props()
	_build_scenery()
	_build_lmia_ground()
	_build_clouds()
	plane = PlaneModel.new()
	plane.name = "PlaneModel"
	plane.visible = false
	add_child(plane)
	progress.emit(1.0, "READY")
	built = true


func _std(col: Color, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


# ------------------------------------------------------------------ terrain
func _build_terrain() -> void:
	var nx := WorldData.TER_NX + 1
	var nz := WorldData.TER_NZ + 1
	var cell := WorldData.TER_CELL
	var hh := WorldData.H
	var cc := WorldData.COLORS
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	cols.resize(nx * nz)
	uvs.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k := j * nx + i
			var x := WorldData.TER_X0 + i * cell
			var z := WorldData.TER_Z0 + j * cell
			verts[k] = Vector3(x, hh[k], z)
			cols[k] = Color(cc[k * 3] / 255.0, cc[k * 3 + 1] / 255.0, cc[k * 3 + 2] / 255.0)
			uvs[k] = Vector2(x / 190.0, z / 190.0)
			var hl := hh[j * nx + maxi(i - 1, 0)]
			var hr := hh[j * nx + mini(i + 1, nx - 1)]
			var hd := hh[maxi(j - 1, 0) * nx + i]
			var hu := hh[mini(j + 1, nz - 1) * nx + i]
			norms[k] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var p := 0
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			idx[p] = a
			idx[p + 1] = b
			idx[p + 2] = c
			idx[p + 3] = b
			idx[p + 4] = d
			idx[p + 5] = c
			p += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Tex.grain_texture()
	mat.roughness = 1.0
	mat.metallic_specular = 0.1
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.extra_cull_margin = 16384.0
	add_child(mi)


func _build_river() -> void:
	var z0 := -56000.0
	var z1 := 66000.0
	var step := 250.0
	var n := int((z1 - z0) / step)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in n + 1:
		var z := z0 + i * step
		var x := WorldData.nile_x(z)
		var hw := 160.0 + (-24000.0 - z) * 0.004 if z < -24000.0 else 230.0 + 40.0 * sin(z / 3000.0)
		var y := WorldData.ground_h(x, z) + 1.4
		verts.append(Vector3(x - hw, y, z))
		verts.append(Vector3(x + hw, y, z))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		if i < n:
			var a := i * 2
			idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := _std(Color("#2d6f8c"), 0.15)
	mat.metallic_specular = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Nile"
	mi.mesh = mesh
	mi.extra_cull_margin = 16384.0
	add_child(mi)


# ------------------------------------------------------------------ cities
func _build_cities() -> void:
	var rn := WorldData.Rnd.new(2024)
	var pal: Array = [Color(0.78, 0.70, 0.58), Color(0.86, 0.80, 0.68), Color(0.72, 0.62, 0.50), Color(0.9, 0.86, 0.78),
		Color(0.66, 0.58, 0.50), Color(0.82, 0.66, 0.52), Color(0.7, 0.72, 0.70)]
	var xf: Array[Transform3D] = []
	var cl: Array[Color] = []
	for c in WorldData.cities():
		var placed := 0
		var tries := 0
		while placed < int(c["n"]) and tries < int(c["n"]) * 40:
			tries += 1
			var a := rn.next() * TAU
			var d := pow(rn.next(), 0.75) * float(c["r"])
			var x: float = float(c["x"]) + cos(a) * d
			var z: float = float(c["z"]) + sin(a) * d
			if WorldData.valley_t(x, z) < 0.9 or absf(x - WorldData.nile_x(z)) < 300.0:
				continue
			if absf(x - 16000.0) < 1500.0 and z > 2900.0 and z < 5900.0:
				continue
			var w := 22.0 + rn.next() * 46.0
			var dp := 22.0 + rn.next() * 46.0
			var fall := 1.0 - d / float(c["r"])
			var h := 9.0 + pow(rn.next(), 3.0) * (70.0 * float(c["tall"])) * (0.4 + fall) + rn.next() * 10.0
			var ang := floorf(rn.next() * 4.0) * 0.04 + (0.0 if rn.next() < 0.5 else PI / 2.0)
			var bas := Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(w, h, dp))
			xf.append(Transform3D(bas, Vector3(x, WorldData.ground_h(x, z) + h * 0.5, z)))
			var pc: Color = pal[int(floor(rn.next() * pal.size()))]
			var s := 0.85 + rn.next() * 0.25
			cl.append(Color(pc.r * s, pc.g * s, pc.b * s))
			placed += 1
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cl[i])
	var mat := _std(Color.WHITE, 0.95)
	mat.vertex_color_use_as_albedo = true
	box.material = mat
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Cities"
	mmi.multimesh = mm
	mmi.extra_cull_margin = 16384.0
	add_child(mmi)


# ------------------------------------------------------------------ pyramids
func _pyramid_mesh(px: float, pz: float, half: float, h: float, base: float, tiles_across: int, tex_n: int) -> ArrayMesh:
	var slant := Vector2(h, half).length()
	var tile := 2.0 * half / tiles_across
	var corners: Array = [Vector2(-half, half), Vector2(half, half), Vector2(half, -half), Vector2(-half, -half)]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var apex := Vector3(px, base + h, pz)
	var centre := Vector3(px, base + h * 0.33, pz)
	var u1 := 2.0 * half / tile / tex_n
	var um := half / tile / tex_n
	var vt := slant / tile / tex_n
	for f in 4:
		var ca: Vector2 = corners[f]
		var cb: Vector2 = corners[(f + 1) % 4]
		var a := Vector3(px + ca.x, base, pz + ca.y)
		var b := Vector3(px + cb.x, base, pz + cb.y)
		var n := (b - a).cross(apex - a).normalized()
		var mid := (a + b + apex) / 3.0
		if n.dot(mid - centre) < 0.0:
			n = -n
		# Godot front faces are clockwise: pick the winding that faces outwards
		var ccw_n := (b - a).cross(apex - a)
		var order: Array
		if ccw_n.dot(mid - centre) > 0.0:
			order = [[a, Vector2(0, 0)], [apex, Vector2(um, vt)], [b, Vector2(u1, 0)]]
		else:
			order = [[a, Vector2(0, 0)], [b, Vector2(u1, 0)], [apex, Vector2(um, vt)]]
		for o in order:
			verts.append(o[0])
			uvs.append(o[1])
			norms.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_pyramids() -> void:
	var face_img: Image = null
	var ft := load(FACE_PATH) as Texture2D
	if ft != null:
		face_img = ft.get_image()
	var block_tex := Tex.block_texture(face_img, true)
	var plain_tex := Tex.block_texture(null, false)
	# MASTER KING: a face on every block
	var km := _pyramid_mesh(WorldData.PYR_X, WorldData.PYR_Z, WorldData.PYR_HALF, WorldData.PYR_H, WorldData.PYR_BASE, 14, 2)
	king_mat = StandardMaterial3D.new()
	king_mat.albedo_texture = block_tex
	king_mat.emission_enabled = true
	king_mat.emission = Color("#3a2a18")
	king_mat.emission_energy_multiplier = 0.25
	king_mat.roughness = 1.0
	king_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	km.surface_set_material(0, king_mat)
	king = MeshInstance3D.new()
	king.name = "MasterKing"
	king.mesh = km
	add_child(king)
	# golden capstone
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = WorldData.PYR_HALF * 0.085 * sqrt(2.0)
	cone.height = WorldData.PYR_H * 0.075
	cone.radial_segments = 4
	cone.rings = 1
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#ffc83a")
	gm.metallic = 0.7
	gm.roughness = 0.25
	gm.emission_enabled = true
	gm.emission = Color("#6a4a00")
	cone.material = gm
	cap = MeshInstance3D.new()
	cap.name = "Capstone"
	cap.mesh = cone
	cap.rotation.y = PI / 4.0
	cap.position = Vector3(WorldData.PYR_X, WorldData.PYR_BASE + WorldData.PYR_H * (1.0 - 0.075 / 2.0) + 0.1, WorldData.PYR_Z)
	add_child(cap)
	# the plain, honest neighbours
	var plain_mat := StandardMaterial3D.new()
	plain_mat.albedo_texture = plain_tex
	plain_mat.roughness = 1.0
	plain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for pyr in WorldData.OTHER_PYRS:
		var pm := _pyramid_mesh(pyr["x"], pyr["z"], pyr["half"], pyr["h"], pyr["base"], maxi(6, roundi(float(pyr["half"]) * 2.0 / 6.0)), 2)
		pm.surface_set_material(0, plain_mat)
		var mi := MeshInstance3D.new()
		mi.name = "Pyramid_" + str(pyr["name"])
		mi.mesh = pm
		add_child(mi)
	# base platform
	var ring := PlaneMesh.new()
	ring.size = Vector2(WorldData.PYR_HALF * 2.0 + 60.0, WorldData.PYR_HALF * 2.0 + 60.0)
	var rm := _std(Color("#b99a68"))
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material = rm
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring
	rmi.position = Vector3(WorldData.PYR_X, WorldData.PYR_BASE + 0.15, WorldData.PYR_Z)
	add_child(rmi)


# ------------------------------------------------------------------ airfields
func _build_airports() -> void:
	var rtex := Tex.runway_texture()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = rtex
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lights: Array[Transform3D] = []
	var lcol: Array[Color] = []
	for r in WorldData.RUNWAYS:
		var pm := PlaneMesh.new()
		pm.size = Vector2(r["wid"], r["len"])
		pm.material = mat
		var mi := MeshInstance3D.new()
		mi.name = "Runway_" + str(r["code"])
		mi.mesh = pm
		mi.position = Vector3(r["x"], float(r["elev"]) + 0.35, r["z"])
		add_child(mi)
		var z: float = r["endZ"]
		while z <= float(r["thrZ"]):
			for s in [-1.0, 1.0]:
				lights.append(Transform3D(Basis.IDENTITY, Vector3(float(r["x"]) + s * (float(r["wid"]) / 2.0 + 2.0), float(r["elev"]) + 0.9, z)))
				lcol.append(Color(1, 0.95, 0.8))
			z += 60.0
		for i in 9:
			for s in [-1.0, 1.0]:
				lights.append(Transform3D(Basis.IDENTITY, Vector3(float(r["x"]) + s * (i * 2.4 + 1.0), float(r["elev"]) + 0.9, float(r["thrZ"]) + 1.0)))
				lcol.append(Color(0.2, 1, 0.3))
				lights.append(Transform3D(Basis.IDENTITY, Vector3(float(r["x"]) + s * (i * 2.4 + 1.0), float(r["elev"]) + 0.9, float(r["endZ"]) - 1.0)))
				lcol.append(Color(1, 0.15, 0.1))
		for i in 24:
			lights.append(Transform3D(Basis.IDENTITY, Vector3(float(r["x"]), float(r["elev"]) + 1.2, float(r["thrZ"]) + 30.0 + i * 30.0)))
			lcol.append(Color(1, 1, 0.95))
	var lbox := BoxMesh.new()
	lbox.size = Vector3(1.6, 1.6, 1.6)
	var lmat := StandardMaterial3D.new()
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.vertex_color_use_as_albedo = true
	lbox.material = lmat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = lbox
	mm.instance_count = lights.size()
	for i in lights.size():
		mm.set_instance_transform(i, lights[i])
		mm.set_instance_color(i, lcol[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "RunwayLights"
	mmi.multimesh = mm
	add_child(mmi)


func _box(parent: Node3D, size: Vector3, col: Color, pos: Vector3, emissive := false) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var m := _std(col, 0.8)
	if emissive:
		m.emission_enabled = true
		m.emission = col.darkened(0.7)
	bm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, rt: float, rb: float, h: float, col: Color, pos: Vector3) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = 20
	cm.material = _std(col, 0.8)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	var wall := Color("#e6d6b4")
	var glass := Color("#86a6b5")
	# Lemuel International: terminal, tower, hangars
	var a := WorldData.AIRPORT
	var ax: float = a["x"]
	var az: float = a["z"]
	var ae: float = a["elev"]
	_box(props, Vector3(180, 22, 38), wall, Vector3(ax + 330, ae + 11, az + 520))
	_box(props, Vector3(182, 9, 39), glass, Vector3(ax + 330, ae + 12, az + 520))
	_cyl(props, 4.0, 5.5, 46.0, wall, Vector3(ax + 180, ae + 23, az + 520))
	_cyl(props, 8.0, 6.0, 9.0, glass, Vector3(ax + 180, ae + 50, az + 520))
	for i in 3:
		_box(props, Vector3(60, 16, 48), wall, Vector3(ax + 480 + i * 70, ae + 8, az + 300))
	_box(props, Vector3(320, 0.4, 140), Color("#6b6c6e"), Vector3(ax + 230, ae + 0.3, az + 400))
	# JRNA: the runway by the two towers
	var j := WorldData.JRNA
	for i in 2:
		_box(props, Vector3(46, 180, 46), Color("#9fb4c4"), Vector3(float(j["x"]) + 300, float(j["elev"]) + 90, float(j["z"]) - 420 + i * 520))
	_box(props, Vector3(110, 16, 34), wall, Vector3(float(j["x"]) + 160, float(j["elev"]) + 8, float(j["z"]) + 60))
	# NCLR: cooling towers and a reactor hall on the grass plains
	var n := WorldData.NCLR
	for i in 2:
		_cyl(props, 22.0, 34.0, 110.0, Color("#c9c2b4"), Vector3(16300, float(n["elev"]) + 55, float(n["z"]) - 520 + i * 1040))
	_box(props, Vector3(140, 46, 100), Color("#9a9488"), Vector3(15900, float(n["elev"]) + 23, float(n["z"])))
	var dome := SphereMesh.new()
	dome.radius = 36.0
	dome.height = 72.0
	dome.material = _std(Color("#b6b4ac"), 0.7)
	var dmi := MeshInstance3D.new()
	dmi.mesh = dome
	dmi.position = Vector3(15900, float(n["elev"]) + 62, float(n["z"]))
	props.add_child(dmi)
	# LMIA second runway terminal
	var l := WorldData.LMRW
	_box(props, Vector3(150, 20, 34), wall, Vector3(float(l["x"]) - 240, float(l["elev"]) + 10, float(l["z"]) + 400))


# ------------------------------------------------------------------ clouds & scenery
func _cloud_texture(seed_: int) -> ImageTexture:
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	var rn := WorldData.Rnd.new(seed_)
	for i in 26:
		var px := 40.0 + rn.next() * 176.0
		var py := 70.0 - rn.next() * 30.0 * (1.0 - absf(px - 128.0) / 128.0)
		var r := 18.0 + rn.next() * 30.0
		for y in range(maxi(0, int(py - r)), mini(128, int(py + r))):
			for x in range(maxi(0, int(px - r)), mini(256, int(px + r))):
				var d := Vector2(x - px, y - py).length() / r
				if d < 1.0:
					var a := 0.55 * (1.0 - d)
					var old := img.get_pixel(x, y)
					var na := old.a + a * (1.0 - old.a)
					img.set_pixel(x, y, Color(1.0, 0.973, 0.925, na))
	return ImageTexture.create_from_image(img)


func _build_clouds() -> void:
	var texs := [_cloud_texture(3), _cloud_texture(9), _cloud_texture(21)]
	var rn := WorldData.Rnd.new(1234)
	for i in 46:
		var sp := Sprite3D.new()
		sp.texture = texs[i % 3]
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.double_sided = true
		sp.transparent = true
		sp.fixed_size = false
		sp.no_depth_test = false
		sp.modulate = Color(1.0, 0.95, 0.86, 0.75 + rn.next() * 0.25)
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		var a := rn.next() * TAU
		var d := 3000.0 + rn.next() * 60000.0
		sp.position = Vector3(cos(a) * d + 8000.0, 1800.0 + rn.next() * 2200.0, sin(a) * d)
		var w := 5000.0 + rn.next() * 9000.0
		sp.pixel_size = w / 256.0
		sp.name = "Cloud%d" % i
		add_child(sp)


func _build_scenery() -> void:
	var stone := _std(Color("#d7bd8c"), 0.9)
	var g := Node3D.new()
	g.name = "Sphinx"
	add_child(g)
	_box_m(g, Vector3(19, 17, 52), stone, Vector3(0, 8.5, 22))
	_box_m(g, Vector3(19, 20, 14), stone, Vector3(0, 10, 44))
	for s in [-1.0, 1.0]:
		_box_m(g, Vector3(5, 4.5, 22), stone, Vector3(s * 6.0, 2.3, -14))
	_box_m(g, Vector3(12, 16, 12), stone, Vector3(0, 24, -3))
	_box_m(g, Vector3(13, 17, 13), stone, Vector3(0, 35, -4))
	_box_m(g, Vector3(17, 10, 16), _std(Color("#4a7fb0"), 0.8), Vector3(0, 45, -3))
	g.position = Vector3(560, 60, 640)
	for o in [[800.0, 60.0, -600.0], [-900.0, 60.0, -900.0]]:
		var cm := CylinderMesh.new()
		cm.top_radius = 1.2
		cm.bottom_radius = 3.2
		cm.height = 40.0
		cm.radial_segments = 4
		cm.material = stone
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.position = Vector3(o[0], o[1] + 20.0, o[2])
		add_child(mi)


func _box_m(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)


# ------------------------------------------------------------------ LEMUEL INTL taxiways (buildLMIAGround)
func _pave(x0: float, z0: float, x1: float, z1: float, mat: Material, y: float) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, z1 - z0)
	pm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3((x0 + x1) / 2.0, y, (z0 + z1) / 2.0)
	add_child(mi)


func _build_lmia_ground() -> void:
	var A := WorldData.AIRPORT
	var L := WorldData.LMRW
	var ax: float = A["x"]
	var lx: float = L["x"]
	var y: float = float(A["elev"]) + 0.3
	var tm := _std(Color("#5c5d60"))
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lm := _std(Color("#d8b020"))
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lights: Array[Transform3D] = []
	var blue := func(x: float, z: float):
		lights.append(Transform3D(Basis.IDENTITY, Vector3(x, y + 0.5, z)))
	var yx := ax + 110.0
	for c in [45450.0, 44800.0, 44620.0]:
		_pave(lx + 28.0, c - 13.0, ax - 30.0, c + 13.0, tm, y)
		_pave(ax + 30.0, c - 13.0, ax + 97.0, c + 13.0, tm, y)
		_pave(lx + 28.0, c + 13.0, lx + 86.0, c + 73.0, tm, y)
		_pave(ax + 37.0, c + 13.0, ax + 97.0, c + 73.0, tm, y)
		_pave(lx + 28.0, c - 0.4, ax - 30.0, c + 0.4, lm, y + 0.03)
		_pave(ax + 30.0, c - 0.4, ax + 97.0, c + 0.4, lm, y + 0.03)
		var x := lx + 30.0
		while x <= ax - 30.0:
			blue.call(x, c - 13.5)
			blue.call(x, c + 13.5)
			x += 40.0
		x = ax + 34.0
		while x <= ax + 96.0:
			blue.call(x, c - 13.5)
			blue.call(x, c + 13.5)
			x += 40.0
	_pave(ax - 30.0, 47601.0, ax + 97.0, 47700.0, tm, y)
	_pave(yx - 0.4, 44650.0, yx + 0.4, 47710.0, lm, y + 0.03)
	var z := 44660.0
	while z <= 47700.0:
		blue.call(yx - 13.5, z)
		blue.call(yx + 13.5, z)
		z += 45.0
	# the stand: a painted box and the lead-in line on the apron
	_pave(yx - 14.0, 46386.0, yx + 14.0, 46387.2, lm, y + 0.04)
	_pave(yx - 14.0, 46432.0, yx + 14.0, 46433.2, lm, y + 0.04)
	_pave(yx - 14.6, 46386.0, yx - 13.4, 46433.0, lm, y + 0.04)
	_pave(yx + 13.4, 46386.0, yx + 14.6, 46433.0, lm, y + 0.04)
	var lb := BoxMesh.new()
	lb.size = Vector3(1.2, 1.2, 1.2)
	var lmt := StandardMaterial3D.new()
	lmt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmt.albedo_color = Color(0.15, 0.35, 1.0)
	lb.material = lmt
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lb
	mm.instance_count = lights.size()
	for i in lights.size():
		mm.set_instance_transform(i, lights[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "LmiaTaxiLights"
	add_child(mmi)
