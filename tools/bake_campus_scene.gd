extends SceneTree
## Builds res://assets/campus/campus.scn (the NAICOL REACTOR campus scene graph) and res://assets/campus/logic.json
## from the raw dump produced by tools/campus_bake/bake.js (campus.json + campus.bin).
## Run:  godot --headless --path . --script res://tools/bake_campus_scene.gd -- <dir containing campus.json and campus.bin>

const OUT_SCENE := "res://assets/campus/campus.scn"
const OUT_LOGIC := "res://assets/campus/logic.json"

var data := {}
var bin := PackedByteArray()
var mats: Array = []
var tex_cache := {}
var geom_cache := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var f := FileAccess.open(dir + "/campus.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	bin = FileAccess.get_file_as_bytes(dir + "/campus.bin")
	print("json ok, bin ", bin.size())
	for m in data["mats"]:
		mats.append(null)
	var root := Node3D.new()
	root.name = "Campus"
	for ch in data["chunks"]:
		_build(ch, root, root)
	if data["props"] != null:
		var pr := Node3D.new()
		pr.name = "PropMeshes"
		pr.visible = true
		root.add_child(pr)
		pr.owner = root
		_build(data["props"], pr, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, OUT_SCENE)
	print("scene saved: ", err)
	# logic data without the heavy geometry
	var logic := {}
	for k in data:
		if k not in ["geoms", "mats", "chunks", "props"]:
			logic[k] = data[k]
	var lf := FileAccess.open(OUT_LOGIC, FileAccess.WRITE)
	lf.store_string(JSON.stringify(logic))
	lf.close()
	print("logic saved")
	quit()


func _floats(info: Array) -> PackedFloat32Array:
	return bin.slice(int(info[0]), int(info[0]) + int(info[1]) * 4).to_float32_array()


func _ints(info: Array) -> PackedInt32Array:
	return bin.slice(int(info[0]), int(info[0]) + int(info[1]) * 4).to_int32_array()


func _mesh(gi: int) -> ArrayMesh:
	if geom_cache.has(gi):
		return geom_cache[gi]
	var g: Dictionary = data["geoms"][gi]
	var cnt: int = g["count"]
	var p := _floats(g["p"])
	var verts := PackedVector3Array()
	verts.resize(cnt)
	for i in cnt:
		verts[i] = Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if g.has("n"):
		var n := _floats(g["n"])
		var nv := PackedVector3Array()
		nv.resize(cnt)
		for i in cnt:
			nv[i] = Vector3(n[i * 3], n[i * 3 + 1], n[i * 3 + 2])
		arrays[Mesh.ARRAY_NORMAL] = nv
	if g.has("u"):
		var u := _floats(g["u"])
		var uv := PackedVector2Array()
		uv.resize(cnt)
		for i in cnt:
			uv[i] = Vector2(u[i * 2], 1.0 - u[i * 2 + 1])
		arrays[Mesh.ARRAY_TEX_UV] = uv
	if g.has("c"):
		var c := _floats(g["c"])
		var cv := PackedColorArray()
		cv.resize(cnt)
		for i in cnt:
			cv[i] = Color(c[i * 3], c[i * 3 + 1], c[i * 3 + 2], 1.0)
		arrays[Mesh.ARRAY_COLOR] = cv
	var idx: PackedInt32Array
	if g.has("i"):
		idx = _ints(g["i"])
	else:
		idx = PackedInt32Array()
		idx.resize(cnt)
		for i in cnt:
			idx[i] = i
	# THREE is counter-clockwise front, Godot is clockwise: swap two indices of every triangle
	var t := 0
	while t + 2 < idx.size():
		var tmp := idx[t + 1]
		idx[t + 1] = idx[t + 2]
		idx[t + 2] = tmp
		t += 3
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	geom_cache[gi] = am
	return am


func _tex(info) -> Texture2D:
	if info == null:
		return null
	var nm: String = info["name"]
	if tex_cache.has(nm):
		return tex_cache[nm]
	var path := "res://assets/campus/tex/%s.png" % nm
	var t = load(path) if ResourceLoader.exists(path) else null
	tex_cache[nm] = t
	return t


func _material(mi: int) -> StandardMaterial3D:
	if mats[mi] != null:
		return mats[mi]
	var d: Dictionary = data["mats"][mi]
	var m := StandardMaterial3D.new()
	var col: Array = d["color"]
	m.albedo_color = Color(col[0], col[1], col[2], 1.0)
	if d["vc"]:
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
	var mp = d["map"]
	if mp != null:
		m.albedo_texture = _tex(mp)
		var nm: String = mp["name"]
		var tiled: bool = nm.begins_with("nct_") and not (nm in ["nct_tuft", "nct_reed", "nct_frond", "nct_flowers", "nct_puff", "nct_cloud"])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if tiled else BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_scale = Vector3(mp["rx"], mp["ry"], 1.0)
	if d["type"] == "MeshBasicMaterial" or d["type"] == "SpriteMaterial":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.roughness = 1.0
		m.metallic_specular = 0.0
	var em: Array = d["emissive"]
	if em[0] > 0.0 or em[1] > 0.0 or em[2] > 0.0:
		m.emission_enabled = true
		m.emission = Color(em[0], em[1], em[2])
	if d["alphaTest"] > 0.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = d["alphaTest"]
	elif d["transparent"] or d["opacity"] < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = d["opacity"]
	if int(d["side"]) == 2:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if int(d["blending"]) == 2:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if not d["depthWrite"]:
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if not d["fog"]:
		m.disable_fog = true
	mats[mi] = m
	return m


func _euler_order(s: String) -> int:
	match s:
		"XZY":
			return EULER_ORDER_XZY
		"YXZ":
			return EULER_ORDER_YXZ
		"YZX":
			return EULER_ORDER_YZX
		"ZXY":
			return EULER_ORDER_ZXY
		"ZYX":
			return EULER_ORDER_ZYX
	return EULER_ORDER_XYZ


func _build(n: Dictionary, parent: Node3D, root: Node3D) -> void:
	var node: Node3D = null
	var t: String = n["t"]
	if t == "mesh":
		var md: Dictionary = data["mats"][int(n["m"])]
		if int(md["side"]) == 1 or int(n["g"]) < 0:
			return                          # sky dome etc.
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh(int(n["g"]))
		mi.material_override = _material(int(n["m"]))
		if int(n.get("ro", 0)) != 0:
			mi.sorting_offset = float(n["ro"])
		node = mi
	elif t == "sprite":
		var md2: Dictionary = data["mats"][int(n["m"])]
		var sc: Array = n["s"]
		if sc[0] >= 400.0:
			return                          # the sun sprite: the sky is Godot's own
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE
		q.mesh = qm
		var m := _material(int(n["m"]))
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c: Array = md2["color"]
		m.albedo_color = Color(c[0], c[1], c[2], md2["opacity"])
		q.material_override = m
		node = q
	elif t == "group" or t == "Group" or t == "Object3D" or t == "Scene":
		node = Node3D.new()
	else:
		return
	node.name = "n%d" % int(n["id"])
	node.set_meta("tname", n["name"])
	var p: Array = n["p"]
	var r: Array = n["r"]
	var s: Array = n["s"]
	node.position = Vector3(p[0], p[1], p[2])
	node.basis = Basis.from_euler(Vector3(r[0], r[1], r[2]), _euler_order(str(r[3]))) * Basis.from_scale(Vector3(s[0], s[1], s[2]))
	node.visible = n["v"]
	parent.add_child(node)
	node.owner = root
	for c in n["ch"]:
		_build(c, node, root)
