class_name LmiaGround
extends Node3D
## The LEMUEL INTL ground sequence after landing at LMIA (port of the LMG object of the HTML game):
## taxi to stand 7, chocks, refuelling tanker, repair van + welding crew, ground-crew clearing, pushback,
## taxi to the holding point, with the camera director and the ground-services panel.

signal finished

const PH: Array = ["taxiIn", "park", "fuel", "repair", "prep", "pushback", "taxiOut", "done"]
const CZ: Array = [45450.0, 44800.0, 44620.0]
const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")

var m: FlightModel
var plane: PlaneModel
var camera: Camera3D
var cap_cb: Callable
var ph := ""
var t := 0.0
var pt := 0.0
var path := {}
var s := 0.0
var pose := {"x": 0.0, "z": 0.0, "psi": 0.0}
var veh := {}
var fin := false
var cz := 0.0
var stats0 := {}
var hud_panel: PanelContainer
var hud_lab: RichTextLabel
var skip_lab: Label
var shot := {}
var shot_t := 99.0
var shot_n := 0
var fuel_p := 0.0
var rep_p := 0.0
var tk_t := 0.0
var vn_t := 0.0
var pb0 := 0.0
var done_t := 0.0
var tug_pos := Vector2.ZERO
var hose: Array = []
var cones: Array = []
var fdone := false
var cap_until := 0.0
var sparks: CPUParticles3D
var flame: OmniLight3D
var _mats := {}
var _glow: GradientTexture2D


func _mat(c: Color, em := Color.BLACK) -> StandardMaterial3D:
	var k := str(c) + str(em)
	if _mats.has(k):
		return _mats[k]
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.roughness = 0.9
	if em != Color.BLACK:
		mt.emission_enabled = true
		mt.emission = em
	_mats[k] = mt
	return mt


func _box(g: Node3D, w: float, h: float, d: float, c: Color, x: float, y: float, z: float, em := Color.BLACK) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = _mat(c, em)
	mi.position = Vector3(x, y, z)
	g.add_child(mi)
	return mi


func _cyl(g: Node3D, r: float, h: float, c: Color, x: float, y: float, z: float, ax := "", seg := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = Vector3(x, y, z)
	if ax == "x":
		mi.rotation.z = PI / 2.0
	elif ax == "z":
		mi.rotation.x = PI / 2.0
	g.add_child(mi)
	return mi


func _wheels(g: Node3D, w: float, zs: Array, r := 0.5) -> void:
	for z in zs:
		for sd in [-1.0, 1.0]:
			_cyl(g, r, 0.35, Color("#151515"), sd * w / 2.0, r, z, "x", 10)


func _glow_tex() -> GradientTexture2D:
	if _glow == null:
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = gr
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 64
		_glow.height = 64
	return _glow


func _beacon(g: Node3D, x: float, y: float, z: float) -> void:
	var sp := Sprite3D.new()
	sp.texture = _glow_tex()
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.transparent = true
	sp.pixel_size = 0.05
	sp.modulate = Color(1.0, 0.63, 0.13)
	sp.position = Vector3(x, y, z)
	g.add_child(sp)
	var l: Array = g.get_meta("bc", [])
	l.append(sp)
	g.set_meta("bc", l)


func _tanker() -> Node3D:
	var g := Node3D.new()
	_box(g, 2.5, 0.5, 9.6, Color("#2c2d30"), 0, 0.85, 0.4)
	_cyl(g, 1.35, 7.2, Color("#e9e9e4"), 0, 2.35, 1.3, "z", 18)
	_cyl(g, 1.37, 1.0, Color("#e0661a"), 0, 2.35, 1.3, "z", 18)
	_cyl(g, 1.37, 0.5, Color("#e0661a"), 0, 2.35, -1.5, "z", 18)
	_box(g, 2.4, 2.1, 2.4, Color("#d24a18"), 0, 1.9, -3.9)
	_box(g, 2.0, 0.9, 0.1, Color("#9ec2d6"), 0, 2.4, -5.12, Color("#14202a"))
	_box(g, 0.6, 0.5, 0.7, Color("#888b90"), 0, 3.9, 1.3)
	_wheels(g, 2.3, [-3.9, 0.8, 2.6], 0.55)
	_beacon(g, 0, 3.2, -3.9)
	_box(g, 0.5, 0.7, 0.5, Color("#333333"), 1.3, 1.5, 3.8)
	return g


func _van() -> Node3D:
	var g := Node3D.new()
	_box(g, 2.3, 0.4, 5.4, Color("#2c2d30"), 0, 0.7, 0)
	_box(g, 2.3, 2.1, 2.4, Color("#f2c230"), 0, 1.9, -1.4)
	_box(g, 2.0, 0.9, 0.1, Color("#9ec2d6"), 0, 2.5, -2.62, Color("#14202a"))
	_box(g, 2.3, 1.5, 3.0, Color("#f2c230"), 0, 1.6, 1.5)
	_box(g, 2.34, 0.3, 3.04, Color("#333333"), 0, 0.95, 1.5)
	_box(g, 0.2, 2.6, 0.2, Color("#555555"), 0.9, 3.3, 2.4)
	_box(g, 0.9, 0.7, 0.35, Color.WHITE, 0.9, 4.7, 2.4, Color("#cfd8e0"))
	_wheels(g, 2.2, [-1.8, 1.9], 0.5)
	_beacon(g, 0, 3.1, -1.4)
	return g


func _tug() -> Node3D:
	var g := Node3D.new()
	_box(g, 2.3, 0.9, 4.4, Color("#f08a10"), 0, 0.9, 0)
	_box(g, 2.1, 1.1, 1.7, Color("#f08a10"), 0, 1.8, 0.5)
	_box(g, 1.9, 0.6, 0.1, Color("#9ec2d6"), 0, 2.0, -0.37, Color("#14202a"))
	_box(g, 2.34, 0.25, 4.5, Color("#222222"), 0, 0.55, 0)
	_box(g, 2.34, 0.3, 0.6, Color("#f2f2f2"), 0, 1.15, -2.1)
	_wheels(g, 2.2, [-1.5, 1.5], 0.45)
	_beacon(g, 0, 2.7, 0.5)
	return g


func _crew(c: Color) -> Node3D:
	var g := Node3D.new()
	var navy := Color("#1d2a44")
	_box(g, 0.22, 0.8, 0.26, navy, -0.14, 0.4, 0)
	_box(g, 0.22, 0.8, 0.26, navy, 0.14, 0.4, 0)
	_box(g, 0.58, 0.7, 0.34, c, 0, 1.15, 0)
	_box(g, 0.6, 0.1, 0.36, Color("#e8e8e0"), 0, 1.17, 0)
	_box(g, 0.14, 0.6, 0.16, c, -0.38, 1.1, 0)
	_box(g, 0.14, 0.6, 0.16, c, 0.38, 1.1, 0)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.19
	hs.height = 0.38
	head.mesh = hs
	head.material_override = _mat(Color("#b58a6a"))
	head.position.y = 1.7
	g.add_child(head)
	var hat := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.21
	hm.height = 0.21
	hat.mesh = hm
	hat.material_override = _mat(Color("#f4f4f0"))
	hat.position.y = 1.76
	g.add_child(hat)
	g.set_meta("arms", [g.get_child(5), g.get_child(6)])
	return g


func _cone() -> Node3D:
	var g := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.26
	cm.height = 0.72
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _mat(Color("#ff6a10"))
	mi.position.y = 0.36
	g.add_child(mi)
	_box(g, 0.6, 0.05, 0.6, Color("#222222"), 0, 0.03, 0)
	return g


# ------------------------------------------------------------------ paths
func _mk_path(P: Array) -> Dictionary:
	var n := P.size()
	var ds: Array = [0.0]
	for i in range(1, n):
		ds.append(ds[i - 1] + Vector2(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]).length())
	var hd: Array = []
	for i in n:
		var a: Array = P[maxi(0, i - 3)]
		var b: Array = P[mini(n - 1, i + 3)]
		hd.append(atan2(b[0] - a[0], -(b[1] - a[1])))
	var lim: Array = []
	for p in P:
		lim.append(10.5 if p[2] else 40.0)
	for k in 3:
		for i in n:
			for j in range(maxi(0, i - 9), mini(n - 1, i + 9) + 1):
				if P[j][2]:
					lim[i] = minf(lim[i], 14.0)
	var v: Array = []
	v.resize(n)
	v.fill(0.0)
	v[0] = 0.8
	for i in range(1, n):
		v[i] = minf(lim[i], sqrt(v[i - 1] * v[i - 1] + 2.0 * 2.4 * (ds[i] - ds[i - 1])))
	v[n - 1] = minf(v[n - 1], 0.5)
	for i in range(n - 2, -1, -1):
		v[i] = minf(v[i], sqrt(v[i + 1] * v[i + 1] + 2.0 * 2.2 * (ds[i + 1] - ds[i])))
	return {"P": P, "ds": ds, "hd": hd, "v": v, "L": ds[n - 1], "n": n}


func _at(pa: Dictionary, sv: float) -> Dictionary:
	var ds: Array = pa["ds"]
	var n: int = pa["n"]
	sv = clampf(sv, 0.0, pa["L"])
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if ds[mid] <= sv:
			lo = mid
		else:
			hi = mid
	var u: float = (sv - ds[lo]) / maxf(1e-6, ds[hi] - ds[lo])
	var hd: Array = pa["hd"]
	var dh: float = hd[hi] - hd[lo]
	if dh > PI:
		dh -= 2.0 * PI
	if dh < -PI:
		dh += 2.0 * PI
	var P: Array = pa["P"]
	var v: Array = pa["v"]
	return {"x": lerpf(P[lo][0], P[hi][0], u), "z": lerpf(P[lo][1], P[hi][1], u), "psi": hd[lo] + dh * u, "v": lerpf(v[lo], v[hi], u)}


func _line(pts: Array, x: float, z: float) -> void:
	var p: Array = pts[pts.size() - 1]
	var d := Vector2(x - p[0], z - p[1]).length()
	var n := maxi(1, ceili(d / 2.0))
	for i in range(1, n + 1):
		pts.append([p[0] + (x - p[0]) * i / n, p[1] + (z - p[1]) * i / n, 0])


func _arc(pts: Array, cx: float, cz_: float, r: float, a0: float, a1: float) -> void:
	var n := maxi(6, ceili(absf(a1 - a0) * r / 2.0))
	for i in range(1, n + 1):
		var a := a0 + (a1 - a0) * i / n
		pts.append([cx + cos(a) * r, cz_ + sin(a) * r, 1])


func _path_in() -> Dictionary:
	var A := WorldData.AIRPORT
	var L := WorldData.LMRW
	var x0 := m.pos.x
	var z0 := m.pos.z
	var c: float = CZ[CZ.size() - 1]
	for cc in CZ:
		if cc < z0 - 150.0:
			c = cc
			break
	cz = c
	var pts: Array = [[x0, z0, 0]]
	var ax: float = A["x"]
	var lx: float = L["x"]
	_line(pts, lx, minf(z0 - 30.0, c + 60.0 + maxf(40.0, (z0 - c - 60.0) * 0.25)))
	_line(pts, lx, c + 60.0)
	_arc(pts, lx + 60.0, c + 60.0, 60.0, PI, 1.5 * PI)
	_line(pts, ax + 50.0, c)
	_arc(pts, ax + 50.0, c + 60.0, 60.0, -PI / 2.0, 0.0)
	_line(pts, ax + 110.0, 46300.0)
	_line(pts, ax + 110.0, 46408.0)
	return _mk_path(pts)


func _path_out(z0: float) -> Dictionary:
	var A := WorldData.AIRPORT
	var ax: float = A["x"]
	var pts: Array = [[ax + 110.0, z0, 0]]
	_line(pts, ax + 110.0, 47620.0)
	_arc(pts, ax + 50.0, 47620.0, 60.0, 0.0, PI / 2.0)
	_arc(pts, ax + 50.0, 47630.0, 50.0, PI / 2.0, PI)
	_line(pts, ax, float(A["thrZ"]) - 80.0)
	return _mk_path(pts)


# ------------------------------------------------------------------ sequence
func begin(model: FlightModel, pl: PlaneModel, cam: Camera3D, hud_parent: Node, caption_cb: Callable) -> void:
	m = model
	plane = pl
	camera = cam
	cap_cb = caption_cb
	stats0 = {"fuel": m.sys.fuel_total(), "integ": m.sys.integ}
	path = _path_in()
	s = 0.0
	pose = {"x": m.pos.x, "z": m.pos.z, "psi": m.psi}
	sparks = CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	var smt := StandardMaterial3D.new()
	smt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smt.albedo_color = Color(1, 0.8, 0.3)
	sm.material = smt
	sparks.mesh = sm
	sparks.amount = 60
	sparks.lifetime = 0.8
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 8.0
	sparks.gravity = Vector3(0, -18, 0)
	sparks.emitting = false
	add_child(sparks)
	flame = OmniLight3D.new()
	flame.light_energy = 0.0
	flame.omni_range = 70.0
	add_child(flame)
	hud_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.047, 0.063, 0.74)
	sb.border_color = Color("#ffc53a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	hud_panel.add_theme_stylebox_override("panel", sb)
	hud_panel.position = Vector2(40, 96)
	hud_lab = RichTextLabel.new()
	hud_lab.bbcode_enabled = true
	hud_lab.fit_content = true
	hud_lab.custom_minimum_size = Vector2(560, 0)
	hud_lab.add_theme_font_override("normal_font", FONT_BOLD)
	hud_lab.add_theme_font_override("bold_font", FONT_BOLD)
	hud_lab.add_theme_font_size_override("normal_font_size", 20)
	hud_lab.add_theme_font_size_override("bold_font_size", 20)
	hud_panel.add_child(hud_lab)
	hud_panel.modulate.a = 0.0
	hud_parent.add_child(hud_panel)
	skip_lab = Label.new()
	skip_lab.text = "SPACE  -  NEXT STEP"
	skip_lab.position = Vector2(1250, 840)
	skip_lab.add_theme_font_override("font", FONT_BOLD)
	skip_lab.add_theme_font_size_override("font_size", 18)
	skip_lab.modulate.a = 0.75
	hud_parent.add_child(skip_lab)
	_set_phase("taxiIn")


func _caption(txt: String, big: bool) -> void:
	cap_cb.call(txt, big)
	cap_until = t + (3.4 if big else 4.5)


func _set_phase(p: String) -> void:
	ph = p
	pt = 0.0
	shot_t = 99.0
	shot_n = 0
	shot = {}
	var caps := {"taxiIn": ["LEMUEL GROUND: TAXI TO STAND 7", true], "park": ["PARKED  -  STAND 7", true], "fuel": ["REFUELLING", true],
		"repair": ["REPAIRS & INSPECTION", true], "prep": ["GROUND CREW CLEARING", false], "pushback": ["PUSHBACK", true],
		"taxiOut": ["TAXI TO RWY 36R  -  HOLDING POINT", true], "done": ["BACK WHERE WE STARTED  -  READY FOR DEPARTURE", true]}
	var cp: Array = caps[p]
	_caption(cp[0], cp[1])
	Sfx.chime()
	match p:
		"park":
			m.V = 0.0
			m.park_brake = true
			_place_chocks()
		"fuel":
			_spawn_fuel()
		"repair":
			_spawn_repair()
		"pushback":
			var tg := _tug()
			add_child(tg)
			veh["tug"] = tg
			pb0 = pose["z"]
		"taxiOut":
			path = _path_out(pose["z"])
			s = 0.0
			for k in ["van", "tank", "tug", "marshal"]:
				if veh.has(k) and is_instance_valid(veh[k]):
					(veh[k] as Node3D).visible = false
			for c in cones:
				c.visible = false
		"done":
			done_t = 0.0


func skip() -> void:
	if fin:
		return
	if ph == "done" or ph == "taxiOut":
		_finish()
		return
	if ph == "taxiIn":
		var e: Array = path["P"][path["n"] - 1]
		pose = {"x": e[0], "z": e[1], "psi": PI}
		m.V = 0.0
		_set_phase("park")
		return
	if ph == "fuel":
		fuel_p = 1.0
	if ph == "repair":
		rep_p = 1.0
	if ph == "pushback":
		pose["z"] = pb0 - 34.0
		tug_pos = tug_pos if tug_pos != Vector2.ZERO else Vector2(pose["x"], pose["z"])
	_set_phase(PH[PH.find(ph) + 1])


func _lw(x: float, y: float, z: float) -> Vector3:
	return plane.to_global(Vector3(x, y, z))


func _sync_plane() -> void:
	var gy: float = WorldData.AIRPORT["elev"]
	plane.visible = true
	plane.set_pose(Vector3(pose["x"], gy + FlightModel.AC_GEARH, pose["z"]), pose["psi"], 0.0, 0.0)
	plane.set_gear_visible(true)


func _place_chocks() -> void:
	var gy: float = WorldData.AIRPORT["elev"]
	for sx in [-1.0, 1.0]:
		var w := _lw(sx * 3.9, -4.5, -3.2)
		var c := _box(self, 0.3, 0.28, 0.9, Color("#1a1a1a"), w.x, gy + 0.14, w.z)
		c.rotation.y = -pose["psi"]
	cones.clear()
	for q in [[-30, -24], [30, -24], [-30, 24], [30, 24], [0, -34]]:
		var w2 := _lw(q[0], -4.5, q[1])
		var cn := _cone()
		cn.position = Vector3(w2.x, gy, w2.z)
		add_child(cn)
		cones.append(cn)
	var cw := _crew(Color("#ff8a10"))
	add_child(cw)
	cw.set_meta("loc", [6.0, -29.0])
	veh["marshal"] = cw


func _spawn_fuel() -> void:
	var gy: float = WorldData.AIRPORT["elev"]
	var tk := _tanker()
	add_child(tk)
	veh["tank"] = tk
	tk_t = 0.0
	fuel_p = 0.0
	hose.clear()
	for i in 3:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.1
		cm.height = 1.0
		cm.radial_segments = 6
		mi.mesh = cm
		mi.material_override = _mat(Color("#1b1b1b"))
		mi.visible = false
		add_child(mi)
		hose.append(mi)
	var fc: Array = []
	for q in [[-27.0, 5.0], [-28.5, -3.0]]:
		var c := _crew(Color("#f0f040") if fc.size() > 0 else Color("#ff8a10"))
		var w := _lw(q[0], -4.5, q[1])
		c.position = Vector3(w.x, gy, w.z)
		c.rotation.y = -pose["psi"] + PI / 2.0
		add_child(c)
		fc.append(c)
	veh["fc"] = fc


func _link(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	var q := Quaternion(Vector3.UP, d.normalized())
	mi.transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(1, l, 1)), a + d * 0.5)
	mi.visible = true


func _spawn_repair() -> void:
	var gy: float = WorldData.AIRPORT["elev"]
	var vn := _van()
	add_child(vn)
	veh["van"] = vn
	vn_t = 0.0
	rep_p = 0.0
	var rc: Array = []
	for q in [[13.0, -1.2], [13.5, 2.4]]:
		var c := _crew(Color("#ff8a10") if rc.size() > 0 else Color("#f0f040"))
		var w := _lw(q[0], -4.5, q[1])
		c.position = Vector3(w.x, gy, w.z)
		c.rotation.y = -pose["psi"] - PI / 2.0
		add_child(c)
		rc.append(c)
	veh["rc"] = rc


# ------------------------------------------------------------------ camera director
const SHOTS := {"taxiIn": ["chase", "pass", "wheel", "tele", "front", "high"], "park": ["orbit", "front", "high"],
	"fuel": ["hose", "orbit", "wide", "hose"], "repair": ["crew", "orbit", "wide", "crew"], "prep": ["high", "orbit"],
	"pushback": ["tug", "chase", "orbit"], "taxiOut": ["chase", "pass", "tele", "front", "high"], "done": ["orbit"]}
const SHOT_DUR := {"chase": 7.0, "pass": 6.5, "wheel": 5.0, "tele": 7.0, "front": 6.0, "high": 8.0, "orbit": 9.0, "hose": 6.0, "wide": 7.0, "crew": 6.5, "tug": 5.0}


func _cam(dt: float) -> void:
	var psi: float = pose["psi"]
	var gy: float = WorldData.AIRPORT["elev"]
	var f := Vector3(sin(psi), 0, -cos(psi))
	var r := Vector3(cos(psi), 0, sin(psi))
	var py := gy + FlightModel.AC_GEARH
	var P := Vector3(pose["x"], 0, pose["z"])
	if shot_t > float(shot.get("dur", 0.0)):
		var L: Array = SHOTS[ph]
		var k: String = L[shot_n % L.size()]
		shot_n += 1
		shot = {"k": k, "dur": SHOT_DUR.get(k, 6.0), "a": randf() * 6.28, "side": -1.0 if randf() < 0.5 else 1.0}
		shot_t = 0.0
		if k == "pass" or k == "tele":
			var ah := 170.0 if k == "pass" else 380.0
			var sd := 46.0 if k == "pass" else 70.0
			shot["anc"] = Vector3(P.x + f.x * ah + r.x * sd * shot["side"], gy + (3.2 if k == "pass" else 7.0), P.z + f.z * ah + r.z * sd * shot["side"])
	shot_t += dt
	var st := shot_t
	var cp := Vector3.ZERO
	var lk := Vector3.ZERO
	var fov := 42.0
	var side: float = shot["side"]
	var orb := func(rad: float, h: float, sp: float) -> Vector3:
		var a: float = shot["a"] + st * sp
		return Vector3(P.x + sin(a) * rad, gy + h, P.z + cos(a) * rad)
	match shot["k"]:
		"chase":
			var d := 62.0 - 2.0 * st
			cp = Vector3(P.x - f.x * d + r.x * 14.0 * side, gy + 14.0 + st * 0.4, P.z - f.z * d + r.z * 14.0 * side)
			lk = Vector3(P.x + f.x * 14.0, gy + 3.0, P.z + f.z * 14.0)
			fov = 48.0
		"pass":
			cp = shot["anc"]
			lk = Vector3(P.x, py, P.z)
			fov = clampf(rad_to_deg(2.0 * atan(34.0 / cp.distance_to(lk))), 12.0, 62.0)
		"tele":
			cp = shot["anc"]
			lk = Vector3(P.x, py, P.z)
			fov = clampf(rad_to_deg(2.0 * atan(26.0 / cp.distance_to(lk))), 5.0, 40.0)
		"wheel":
			var gx := P.x + r.x * 4.4 * side - f.x * 3.0
			var gz := P.z + r.z * 4.4 * side - f.z * 3.0
			cp = Vector3(gx + r.x * 10.0 * side + f.x * 7.0, gy + 1.4, gz + r.z * 10.0 * side + f.z * 7.0)
			lk = Vector3(gx, gy + 1.5, gz)
			fov = 36.0
		"front":
			cp = Vector3(P.x + f.x * (38.0 + st * 1.2) + r.x * 9.0, gy + 2.4, P.z + f.z * (38.0 + st * 1.2) + r.z * 9.0)
			lk = Vector3(P.x + f.x * 3.0, py - 1.5, P.z + f.z * 3.0)
			fov = 48.0
		"high":
			cp = Vector3(P.x - f.x * 26.0 + r.x * 30.0, gy + 70.0 + st * 2.0, P.z - f.z * 26.0 + r.z * 30.0)
			lk = Vector3(P.x + f.x * 4.0, gy, P.z + f.z * 4.0)
		"orbit":
			cp = orb.call(74.0 + st * 2.0, 14.0 + st * 0.8, 0.22)
			lk = Vector3(P.x, py + 1.0, P.z)
			fov = 44.0
		"wide":
			cp = orb.call(120.0, 24.0, 0.1)
			lk = Vector3(P.x, py, P.z)
			fov = 40.0
		"hose":
			var q := _lw(-17.0, -1.5, 2.5)
			cp = Vector3(q.x + r.x * 9.0 - f.x * 4.0 + sin(st * 0.3) * 2.0, gy + 3.4 + st * 0.15, q.z + r.z * 9.0 - f.z * 4.0)
			lk = Vector3(q.x, q.y - 1.6, q.z)
		"crew":
			var q2 := _lw(9.3, -3.0, -1.2)
			cp = Vector3(q2.x + r.x * 12.0 + f.x * (10.0 - st), gy + 5.0 + st * 0.2, q2.z + r.z * 12.0 + f.z * (10.0 - st))
			lk = Vector3(q2.x, q2.y + 0.5, q2.z)
			fov = 40.0
		"tug":
			var n := _lw(0.0, -4.5, -24.0)
			cp = Vector3(n.x + r.x * 14.0 - f.x * 6.0, gy + 3.0, n.z + r.z * 14.0 - f.z * 6.0)
			lk = Vector3(n.x, gy + 1.8, n.z)
			fov = 44.0
		_:
			cp = orb.call(80.0, 18.0, 0.2)
			lk = Vector3(P.x, py, P.z)
	if cp.y < gy + 1.2:
		cp.y = gy + 1.2
	camera.position = cp
	camera.fov = fov
	camera.look_at(lk, Vector3.UP)


# ------------------------------------------------------------------ frame
func update(dt: float) -> void:
	if fin:
		return
	dt = minf(dt, 0.1)
	t += dt
	pt += dt
	if hud_panel and t > 0.3:
		hud_panel.modulate.a = minf(1.0, hud_panel.modulate.a + dt * 1.6)
	if cap_until > 0.0 and t > cap_until:
		cap_cb.call("", false)
		cap_until = 0.0
	if ph == "taxiIn" or ph == "taxiOut":
		var v: float = _at(path, s)["v"]
		s += maxf(0.5, v) * dt
		var q := _at(path, s)
		pose = {"x": q["x"], "z": q["z"], "psi": q["psi"]}
		m.V = q["v"]
		if ph == "taxiOut" and pt < 4.0:
			m.V = maxf(m.V, 2.0)
		if s >= float(path["L"]) - 0.2:
			var e: Array = path["P"][path["n"] - 1]
			pose["x"] = e[0]
			pose["z"] = e[1]
			m.V = 0.0
			_set_phase("park" if ph == "taxiIn" else "done")
	if ph == "park":
		m.V = 0.0
		if pt > 3.2:
			_set_phase("fuel")
	elif ph == "fuel":
		_do_fuel(dt)
	elif ph == "repair":
		_do_repair(dt)
	elif ph == "prep":
		_do_prep(dt)
	elif ph == "pushback":
		_do_push(dt)
	elif ph == "done":
		done_t += dt
		if done_t > 4.5 and not fin:
			_finish()
	if fin:
		return
	var gy: float = WorldData.AIRPORT["elev"]
	m.pos = Vector3(pose["x"], gy + FlightModel.AC_GEARH, pose["z"])
	m.psi = pose["psi"]
	_sync_plane()
	_anim()
	_cam(dt)
	_hud()


func _do_fuel(dt: float) -> void:
	var T: Node3D = veh["tank"]
	var psi: float = pose["psi"]
	var gy: float = WorldData.AIRPORT["elev"]
	tk_t += dt
	var d := clampf(tk_t / 5.5, 0.0, 1.0)
	var e := WorldData.sstep(0.0, 1.0, d)
	var a := _lw(-150.0, -4.5, 0.2)
	var w := _lw(-34.0, -4.5, 0.2)
	T.position = Vector3(lerpf(a.x, w.x, e), gy, lerpf(a.z, w.z, e))
	T.rotation.y = -(psi + PI / 2.0 * (1.0 - WorldData.sstep(0.55, 1.0, d)))
	if d >= 1.0:
		var tp: Vector3 = T.to_global(Vector3(1.3, 1.5, 3.8))
		var port := _lw(-17.5, -1.6, 2.6)
		var m1 := tp.lerp(port, 0.35)
		m1.y = gy + 0.45
		var m2 := tp.lerp(port, 0.7)
		m2.y = gy + 1.4
		_link(hose[0], tp, m1)
		_link(hose[1], m1, m2)
		_link(hose[2], m2, port)
		if tk_t > 6.5:
			fuel_p = minf(1.0, (tk_t - 6.5) / 12.0)
		var fc: Array = veh["fc"]
		for i in fc.size():
			(fc[i] as Node3D).position.y = gy + absf(sin(tk_t * (1.3 + i * 0.5))) * 0.03
		if fuel_p >= 1.0 and not fdone:
			fdone = true
			_caption("FUEL COMPLETE  -  31.4 T", true)
		if fuel_p >= 1.0 and tk_t > 20.5:
			for h in hose:
				h.visible = false
			fdone = false
			_set_phase("repair")
		m.sys.fuel = [lerpf(stats0["fuel"], 31.4, fuel_p) / 2.0, lerpf(stats0["fuel"], 31.4, fuel_p) / 2.0]


func _do_repair(dt: float) -> void:
	var V: Node3D = veh["van"]
	var psi: float = pose["psi"]
	var gy: float = WorldData.AIRPORT["elev"]
	vn_t += dt
	var d := clampf(vn_t / 4.5, 0.0, 1.0)
	var e := WorldData.sstep(0.0, 1.0, d)
	var a := _lw(150.0, -4.5, -4.0)
	var w := _lw(33.0, -4.5, -4.0)
	V.position = Vector3(lerpf(a.x, w.x, e), gy, lerpf(a.z, w.z, e))
	V.rotation.y = -(psi - PI / 2.0 * (1.0 - WorldData.sstep(0.55, 1.0, d)))
	var rc: Array = veh["rc"]
	for i in rc.size():
		(rc[i] as Node3D).position.y = gy + absf(sin(vn_t * (2 + i))) * 0.04
	if d >= 1.0 and vn_t > 6.0:
		rep_p = minf(1.0, (vn_t - 6.0) / 11.0)
		var eng := _lw(10.8, -3.0, -1.2)
		sparks.global_position = eng + Vector3(0, 0.5, 0)
		sparks.emitting = true
		flame.global_position = eng + Vector3(0, 0.6, 0)
		flame.light_color = Color("#bfe0ff")
		flame.light_energy = (4.0 if randf() < 0.7 else 0.4)
		if vn_t >= 18.0:
			flame.light_energy = 0.0
			sparks.emitting = false
			rep_p = 1.0
			_set_phase("prep")
	m.sys.integ = lerpf(stats0["integ"], 1.0, rep_p)


func _do_prep(dt: float) -> void:
	var k := pt
	var psi: float = pose["psi"]
	var go := func(o: Node3D, sg: float, delay: float):
		if o == null or not is_instance_valid(o):
			return
		var tt := maxf(0.0, k - delay)
		var sw := WorldData.sstep(0.0, 1.0, tt * 0.8)
		var hh := psi + sg * PI / 2.0 * sw
		o.rotation.y = -hh
		var v := minf(14.0, tt * 5.0) * (1.0 if sw > 0.2 else 0.0)
		o.position.x += sin(hh) * v * dt
		o.position.z += -cos(hh) * v * dt
	go.call(veh.get("van"), 1.0, 0.4)
	go.call(veh.get("tank"), -1.0, 0.8)
	for lst in ["rc", "fc"]:
		for c in veh.get(lst, []):
			(c as Node3D).visible = pt < 1.2
	if pt > 5.0:
		_set_phase("pushback")


func _do_push(dt: float) -> void:
	var T: Node3D = veh["tug"]
	var gy: float = WorldData.AIRPORT["elev"]
	var k := clampf(pt / 7.5, 0.0, 1.0)
	var psi: float = pose["psi"]
	if pt <= 8.0:
		pose["z"] = pb0 - 34.0 * WorldData.sstep(0.0, 1.0, k)
		var n := _lw(0.0, -4.5, -22.6)
		T.position = Vector3(n.x, gy, n.z)
		T.rotation.y = -(psi + PI)
		tug_pos = Vector2(n.x, n.z)
	else:
		var tt := pt - 8.0
		var v := minf(10.0, tt * 4.0)
		tug_pos.x += cos(psi) * v * dt
		tug_pos.y += sin(psi) * v * dt
		T.position = Vector3(tug_pos.x, gy, tug_pos.y)
		T.rotation.y = -(psi + PI / 2.0)
	if pt > 12.0:
		_set_phase("taxiOut")


func _anim() -> void:
	var gy: float = WorldData.AIRPORT["elev"]
	var on := 1.0 if sin(t * 9.0) > 0.0 else 0.15
	for k in veh:
		var o = veh[k]
		if o is Node3D and is_instance_valid(o) and o.has_meta("bc"):
			for b in o.get_meta("bc"):
				(b as Sprite3D).modulate.a = on
	if veh.has("marshal"):
		var mm: Node3D = veh["marshal"]
		if ph == "taxiOut" or ph == "done":
			mm.visible = false
		else:
			var loc: Array = mm.get_meta("loc")
			var q := _lw(loc[0], -4.5, loc[1])
			mm.position = Vector3(q.x, gy, q.z)
			mm.rotation.y = -(float(pose["psi"]) + PI)
			for a in mm.get_meta("arms"):
				(a as Node3D).rotation.z = sin(t * 4.0) * 0.5


func _hud() -> void:
	if hud_lab == null:
		return
	var I := PH.find(ph)
	var bar := func(p: float) -> String:
		var k := roundi(clampf(p, 0.0, 1.0) * 12.0)
		return "[color=#ffc53a]" + "#".repeat(k) + "[/color][color=#555555]" + ".".repeat(12 - k) + "[/color]"
	var ok := func(i: int) -> String:
		if I > i:
			return "[color=#6df08a]+[/color]"
		if I == i:
			return "[color=#ffc53a]>[/color]"
		return "[color=#666666].[/color]"
	var fp := 1.0 if I > 2 else (fuel_p if ph == "fuel" else 0.0)
	var rp := 1.0 if I > 3 else (rep_p if ph == "repair" else 0.0)
	var ft := lerpf(stats0["fuel"], 31.4, fp)
	var ig := lerpf(stats0["integ"], 1.0, rp)
	var out := "[color=#666666].[/color]"
	if I >= 5:
		out = "[color=#6df08a]+[/color]" if I > 5 else "[color=#ffc53a]>[/color]"
	hud_lab.text = "[color=#ffc53a]LEMUEL INTL  -  GROUND SERVICES[/color]\n" + ok.call(0) + " TAXI TO STAND 7\n" + ok.call(1) + " CHOCKS IN, ENGINES OFF\n" \
		+ ok.call(2) + " REFUEL  " + bar.call(fp) + " [b]%.1f / 31.4 T[/b]\n" % ft \
		+ ok.call(3) + " REPAIRS  " + bar.call(rp) + " [b]HULL %d%%[/b]\n" % roundi(ig * 100.0) \
		+ out + " PUSHBACK & TAXI TO RWY 36R"


func _finish() -> void:
	if fin:
		return
	fin = true
	cap_cb.call("", false)
	if hud_panel:
		hud_panel.queue_free()
	if skip_lab:
		skip_lab.queue_free()
	finished.emit()
