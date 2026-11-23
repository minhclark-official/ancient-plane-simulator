class_name Instrument
extends Control
## One cockpit panel / gauge. `kind` selects what is drawn with _draw();
## everything is procedural (the original game drew these on an HTML canvas).

@export var kind := ""

const C_PUTTY := Color("#b8b29b")
const C_BLACK := Color("#0b0c0e")
const C_COAL := Color("#16181c")
const C_METAL := Color("#2a2d33")
const C_CREAM := Color("#ece4c8")
const C_AMB := Color("#ffb030")
const C_GRN := Color("#46e46a")
const C_RED := Color("#ff3b30")
const C_CYAN := Color("#38d8ff")
const C_MAG := Color("#ff52e0")
const C_WHITE := Color("#f4f2e6")
const C_GOLD := Color("#ffd24a")
const C_SKY := Color("#2f7fd0")
const C_GND := Color("#8a5a2c")
const C_CRT := Color("#3cff6e")

const FONT_REG := preload("res://assets/fonts/IBMPlexMono-Regular.woff2")
const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")

var ui: FlightUI
var _hits: Array = []        # [Rect2, id]
var _held := ""
var _drag := ""


func bind(u: FlightUI) -> void:
	ui = u
	var interactive := ["yoke", "quad", "gear", "mcp", "panel", "overhead"].has(kind)
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE


func _process(_dt: float) -> void:
	if ui != null and ui.m != null and is_visible_in_tree():
		queue_redraw()


# ------------------------------------------------------------------ text / shape helpers
func _txt(s: String, p: Vector2, sz: int, col: Color, al := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, bold := true) -> void:
	draw_string(FONT_BOLD if bold else FONT_REG, p, s, al, w, sz, col)


func _pol(c: Vector2, r: float, deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return c + Vector2(sin(a), -cos(a)) * r


func _arc(c: Vector2, r: float, d0: float, d1: float, col: Color, w := 2.0) -> void:
	# degrees clockwise from "up"
	draw_arc(c, r, deg_to_rad(d0 - 90.0), deg_to_rad(d1 - 90.0), 48, col, w, true)


func _needle(c: Vector2, deg: float, ln: float, tail: float, w: float, col: Color) -> void:
	draw_line(_pol(c, -tail, deg), _pol(c, ln, deg), col, w, true)


func _bezel(c: Vector2, r: float) -> void:
	draw_circle(c, r + 5.0, Color("#1c1d20"))
	draw_circle(c, r + 2.0, Color("#55585e"))
	draw_circle(c, r, Color("#0a0b0d"))


func _panel_bg(col := C_COAL) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), col)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.13), false, 1.5)


func _button(r: Rect2, label: String, id: String, on := false, col := C_AMB) -> void:
	var held := _held == id
	var base := Color("#26282d") if not on else col.darkened(0.55)
	if held:
		base = base.lightened(0.25)
	draw_rect(r, base)
	draw_rect(r, col if on else Color("#5a5d63"), false, 1.5)
	_txt(label, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5.0), 13, col if on else C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_hits.append([r, id])


func _power_key() -> String:
	match kind:
		"asi", "alt", "vsi", "clock", "eadi":
			return "eadi"
		"nd":
			return "nd"
		"eicas", "eng":
			return "eicas"
		"cdu":
			return "cdu"
		"mcp":
			return "mcp"
	return ""


## glitchy value (damaged panels): returns v perturbed according to ui.glitch
func _gl(id: String, v: float, span: float) -> float:
	var l := ui.glitch
	if l < 0.22:
		return v
	var k := clampf((l - 0.22) / 0.6, 0.0, 1.0)
	var ph := floorf(ui.t * 1.7 + float(id.hash() % 7)) 
	var r := fposmod(sin(ph * 12.9898 + float(id.hash() % 97)) * 43758.5453, 1.0)
	match int(r * 4.0):
		0:
			return v + (randf() - 0.5) * span * 0.08 * k
		1:
			return v + span * 0.22 * k * sin(ui.t * (4.0 + l * 9.0))
		2:
			return v
	return v + (randf() - 0.5) * span * 0.4 * k * (1.0 if randf() < 0.2 else 0.0)


func _draw() -> void:
	if ui == null or ui.m == null:
		return
	_hits.clear()
	match kind:
		"asi": _draw_asi()
		"alt": _draw_alt()
		"vsi": _draw_vsi()
		"clock": _draw_clock()
		"eadi": _draw_eadi()
		"nd": _draw_nd()
		"eicas": _draw_eicas()
		"cdu": _draw_cdu()
		"yoke": _draw_yoke()
		"gear": _draw_gear()
		"quad": _draw_quad()
		"ann": _draw_ann()
		"eng": _draw_eng()
		"panel": _draw_panel()
		"mcp": _draw_mcp()
		"overhead": _draw_overhead()
	var pk := _power_key()
	if pk != "":
		var lit: float = ui.power.get(pk, 1.0)
		if lit < 0.99:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.016, 0.02, 0.03, (1.0 - clampf(lit, 0.0, 1.0)) * 0.94))


# ------------------------------------------------------------------ round dials
func _draw_asi() -> void:
	var m := ui.m
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 6.0
	_bezel(c, r)
	for k in range(40, 401, 10):
		var a := -150.0 + (float(k) - 40.0) / 360.0 * 300.0
		var major := k % 40 == 0
		draw_line(_pol(c, r - (14.0 if major else 8.0), a), _pol(c, r - 2.0, a), C_WHITE, 2.0 if major else 1.0)
		if major:
			_txt(str(k), _pol(c, r - 26.0, a) + Vector2(-20, 5), 12, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	# flap-extended speed band and VMO line
	_arc(c, r - 5.0, -150.0 + (float(FlightModel.AC_VREF) - 40.0) / 360.0 * 300.0, -150.0 + (float(m.vfe if m.vfe < 900.0 else 340.0) - 40.0) / 360.0 * 300.0, C_GRN, 3.0)
	draw_line(_pol(c, r - 16.0, -150.0 + 300.0 / 360.0 * 300.0 + 0.0), _pol(c, r - 1.0, -150.0 + 300.0 / 360.0 * 300.0), C_RED, 4.0)
	_txt("KNOTS", c + Vector2(-30, 30), 12, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	_txt("%03d" % int(m.ias_kt), c + Vector2(-26, 56), 20, C_AMB, HORIZONTAL_ALIGNMENT_CENTER, 52.0)
	_needle(c, -150.0 + (clampf(_gl("ias", m.ias_kt, 360.0), 40.0, 400.0) - 40.0) / 360.0 * 300.0, r - 10.0, 12.0, 3.0, C_WHITE)
	draw_circle(c, 6.0, Color("#999"))


func _draw_alt() -> void:
	var m := ui.m
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 6.0
	_bezel(c, r)
	for i in 50:
		var a := i * 7.2
		var major := i % 5 == 0
		draw_line(_pol(c, r - (14.0 if major else 7.0), a), _pol(c, r - 2.0, a), C_WHITE, 2.0 if major else 1.0)
		if major:
			_txt(str(i / 5), _pol(c, r - 28.0, a) + Vector2(-10, 6), 16, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 20.0)
	_txt("ALT", c + Vector2(-30, -34), 12, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	draw_rect(Rect2(c + Vector2(-42, 18), Vector2(84, 24)), Color.BLACK)
	draw_rect(Rect2(c + Vector2(-42, 18), Vector2(84, 24)), Color("#777"), false, 1.0)
	_txt("%05d" % int(maxf(m.alt_ft, 0.0)), c + Vector2(-42, 37), 18, C_AMB, HORIZONTAL_ALIGNMENT_CENTER, 84.0)
	_txt("RA %d" % int(maxf(m.agl_ft, 0.0)), c + Vector2(-40, -16), 12, C_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 80.0)
	var h := fposmod(_gl("alt", m.alt_ft, 1000.0), 1000.0) / 1000.0 * 360.0
	_needle(c, h, r - 12.0, 12.0, 4.0, C_WHITE)
	_needle(c, fposmod(m.alt_ft, 10000.0) / 10000.0 * 360.0, r - 46.0, 6.0, 5.0, C_AMB)
	draw_circle(c, 6.0, Color("#999"))


func _draw_vsi() -> void:
	var m := ui.m
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 5.0
	_bezel(c, r)
	for v in range(-3000, 3001, 500):
		var a := -90.0 + float(v) / 3000.0 * 150.0
		draw_line(_pol(c, r - 10.0, a), _pol(c, r - 2.0, a), C_WHITE, 2.0 if v % 1000 == 0 else 1.0)
		if v % 1000 == 0:
			_txt(str(absi(v) / 1000), _pol(c, r - 20.0, a) + Vector2(-5, 5), 11, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10.0)
	_txt("V/S", c + Vector2(-20, 24), 11, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	_txt("%+d" % int(roundf(m.vs_fpm / 50.0) * 50.0), c + Vector2(-30, 40), 11, C_AMB, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	_needle(c, -90.0 + clampf(_gl("vs", m.vs_fpm, 3000.0), -3000.0, 3000.0) / 3000.0 * 150.0, r - 8.0, 6.0, 3.0, C_WHITE)
	draw_circle(c, 4.0, Color("#999"))


func _draw_clock() -> void:
	var m := ui.m
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 4.0
	_bezel(c, r)
	for i in 12:
		draw_line(_pol(c, r - 7.0, i * 30.0), _pol(c, r - 1.0, i * 30.0), C_WHITE, 2.0)
	var tt := m.t
	_needle(c, fposmod(tt / 3600.0 * 360.0, 360.0), r * 0.5, 0.0, 3.0, C_WHITE)
	_needle(c, fposmod(tt / 60.0 * 6.0, 360.0), r * 0.8, 0.0, 2.0, C_WHITE)
	_needle(c, fposmod(tt * 6.0, 360.0), r * 0.85, 4.0, 1.0, C_RED)
	_txt("x%d" % ui.warp, c + Vector2(-16, r * 0.62), 11, C_AMB if ui.warp > 1 else C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, 32.0)


# ------------------------------------------------------------------ glass cockpit
func _draw_eadi() -> void:
	var m := ui.m
	_panel_bg(Color("#05070b"))
	var c := size / 2.0
	var pxd := 3.4
	var yh := rad_to_deg(m.theta) * pxd
	draw_set_transform(c, -m.phi, Vector2.ONE)
	draw_rect(Rect2(-400, -400 + yh, 800, 400), C_SKY)
	draw_rect(Rect2(-400, yh, 800, 400), C_GND)
	draw_line(Vector2(-400, yh), Vector2(400, yh), C_WHITE, 2.0)
	for d in range(-30, 31, 5):
		if d == 0:
			continue
		var y := yh - d * pxd
		var w := 40.0 if d % 10 == 0 else 20.0
		draw_line(Vector2(-w, y), Vector2(w, y), C_WHITE, 1.5)
		if d % 10 == 0:
			_txt(str(absi(d)), Vector2(w + 4, y + 4), 10, C_WHITE)
			_txt(str(absi(d)), Vector2(-w - 18, y + 4), 10, C_WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# roll scale (fixed) and pointer
	for a in [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]:
		draw_line(_pol(c, 78.0, a), _pol(c, 86.0 if a % 30 == 0 else 82.0, a), C_WHITE, 1.5)
	var tri_a := -rad_to_deg(m.phi)
	draw_colored_polygon(PackedVector2Array([_pol(c, 78.0, tri_a), _pol(c, 90.0, tri_a - 4.0), _pol(c, 90.0, tri_a + 4.0)]), C_GOLD)
	# flight director
	if m.ap_on:
		var fy := clampf(-m.fd_p * 57.3 * pxd, -50.0, 50.0)
		var fx := clampf(m.fd_r * 57.3 * 1.2, -60.0, 60.0)
		draw_line(c + Vector2(-50, fy), c + Vector2(50, fy), C_MAG, 3.0)
		draw_line(c + Vector2(fx, -42), c + Vector2(fx, 42), C_MAG, 3.0)
	# aircraft symbol
	draw_line(c + Vector2(-46, 0), c + Vector2(-16, 0), C_GOLD, 4.0)
	draw_line(c + Vector2(16, 0), c + Vector2(46, 0), C_GOLD, 4.0)
	draw_line(c + Vector2(-16, 0), c + Vector2(-16, 8), C_GOLD, 4.0)
	draw_line(c + Vector2(16, 0), c + Vector2(16, 8), C_GOLD, 4.0)
	draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), C_GOLD)
	# mode annunciation
	_txt(_mode_text(), Vector2(0, 14), 11, C_GRN, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_txt("%d" % int(m.ias_kt), Vector2(4, size.y - 6), 12, C_WHITE)
	_txt("%d" % int(m.alt_ft), Vector2(0, size.y - 6), 12, C_WHITE, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4.0)
	_txt("%03d" % int(m.hdg), Vector2(0, size.y - 6), 12, C_CYAN, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _mode_text() -> String:
	var m := ui.m
	if m.f_lockout:
		return "A/P  ???  ???"
	if m.al_st == "ENG":
		return "AUTOLAND  LOC GS" if m.dest == "MKNG" else "APPR  LOC GS"
	if m.al_st == "ARM":
		return "A/P  NAV  ALT  LAND ARM"
	if m.al_st == "ROLL":
		return "ROLLOUT"
	if m.ato_phase != "" and m.ato_phase != "DONE":
		return "AUTO T/O " + m.ato_phase
	if m.ap_on:
		return "A/P  " + m.ap_lat + "  " + m.ap_vert
	return "MANUAL"


func _draw_nd() -> void:
	var m := ui.m
	_panel_bg(Color("#04060a"))
	var c := Vector2(size.x * 0.5, size.y * 0.8)
	var scl := (size.y * 0.74) / (ui.rng * WorldData.NM)
	var f := Vector2(sin(m.psi), -cos(m.psi))
	var rt := Vector2(cos(m.psi), sin(m.psi))
	# range rings
	for i in [0.5, 1.0]:
		draw_arc(c, ui.rng * WorldData.NM * scl * i, deg_to_rad(-170.0), deg_to_rad(-10.0), 32, Color(1, 1, 1, 0.25), 1.0, true)
	var to_scr := func(wx: float, wz: float) -> Vector2:
		var rel := Vector2(wx - m.pos.x, wz - m.pos.z)
		return c + Vector2(rel.dot(rt), -rel.dot(f)) * scl
	# Nile
	var pts := PackedVector2Array()
	var z0 := m.pos.z - ui.rng * WorldData.NM
	var zz := z0 - fposmod(z0, 1500.0)
	while zz < m.pos.z + ui.rng * WorldData.NM:
		pts.append(to_scr.call(WorldData.nile_x(zz), zz))
		zz += 1500.0
	if pts.size() > 1:
		draw_polyline(pts, Color("#2a6a8a"), 2.0)
	# runways
	for r in WorldData.RUNWAYS:
		var a: Vector2 = to_scr.call(r["x"], r["endZ"])
		var b: Vector2 = to_scr.call(r["x"], r["thrZ"])
		draw_line(a, b, C_WHITE, 3.0)
		_txt(str(r["code"]), b + Vector2(6, 4), 10, C_WHITE)
	# destination and extended centre line
	var dd := m.cur_dest()
	var ds: Vector2 = to_scr.call(dd["x"], dd["z"])
	var far: Vector2 = to_scr.call(dd["x"], float(dd["z"]) + 15.0 * WorldData.NM)
	draw_line(ds, far, Color(C_MAG, 0.7), 1.5)
	var iaf: Vector2 = to_scr.call(dd["x"], float(dd["z"]) + WorldData.IAF_NM * WorldData.NM)
	draw_circle(iaf, 4.0, C_MAG)
	_txt(str(dd["short"]), ds + Vector2(8, -6), 11, C_MAG)
	# pyramids
	var kp: Vector2 = to_scr.call(WorldData.PYR_X, WorldData.PYR_Z)
	draw_colored_polygon(PackedVector2Array([kp + Vector2(0, -8), kp + Vector2(8, 6), kp + Vector2(-8, 6)]), C_GOLD)
	_txt("KING", kp + Vector2(10, 4), 10, C_GOLD)
	for p in WorldData.OTHER_PYRS:
		var s: Vector2 = to_scr.call(p["x"], p["z"])
		draw_colored_polygon(PackedVector2Array([s + Vector2(0, -4), s + Vector2(4, 3), s + Vector2(-4, 3)]), Color(0.8, 0.7, 0.5))
	# own ship
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(7, 9), c + Vector2(0, 5), c + Vector2(-7, 9)]), C_WHITE)
	# header
	draw_rect(Rect2(0, 0, size.x, 18), Color(0, 0, 0, 0.7))
	_txt("HDG %03d   GS %d   RNG %d" % [int(m.hdg), int(m.gs / WorldData.KT), ui.rng], Vector2(4, 13), 11, C_GRN)
	_txt("%s  %.1f NM" % [str(dd["short"]), m.dist_dest / WorldData.NM], Vector2(0, size.y - 5), 11, C_MAG, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _n1_gauge(c: Vector2, r: float, n1: float, tag: String) -> void:
	_arc(c, r, -120.0, 120.0, Color("#444"), 5.0)
	_arc(c, r, 100.0, 120.0, C_RED, 5.0)
	var a := -120.0 + clampf(n1, 0.0, 110.0) / 110.0 * 240.0
	_needle(c, a, r - 2.0, 0.0, 3.0, C_WHITE)
	draw_circle(c, 4.0, C_WHITE)
	_txt("%.1f" % n1, c + Vector2(-30, r + 24.0), 14, C_GRN, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	_txt(tag, c + Vector2(-30, -r - 6.0), 11, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, 60.0)


func _draw_eicas() -> void:
	var m := ui.m
	_panel_bg(Color("#05070b"))
	_n1_gauge(Vector2(62, 70), 44.0, m.n1[0], "N1 L")
	_n1_gauge(Vector2(160, 70), 44.0, m.n1[1], "N1 R")
	# configuration
	_txt("FLAPS", Vector2(10, 148), 11, C_CREAM)
	_txt(str(int(FlightModel.FLAP_POS[m.flaps_cmd])), Vector2(58, 148), 13, C_GRN if absf(m.flaps - float(FlightModel.FLAP_POS[m.flaps_cmd])) < 0.3 else C_AMB)
	_txt("GEAR", Vector2(10, 170), 11, C_CREAM)
	var gcol := C_GRN if m.gear > 0.99 else (C_RED if m.gear > 0.01 else C_WHITE)
	var gtxt := "DOWN" if m.gear > 0.99 else ("UP" if m.gear < 0.01 else "TRANSIT")
	_txt(gtxt, Vector2(58, 170), 13, gcol)
	_txt("SPD BRK", Vector2(10, 192), 11, C_CREAM)
	_txt("%d%%" % int(m.spd_brake * 100.0), Vector2(78, 192), 12, C_GRN if m.spd_brake < 0.05 else C_AMB)
	# messages
	var msgs := _eicas_messages()
	var y := 150.0
	for ms in msgs:
		_txt(ms[0], Vector2(size.x - 128, y), 12, ms[1])
		y += 16.0
		if y > size.y - 4.0:
			break


func _eicas_messages() -> Array:
	var m := ui.m
	var out: Array = []
	if m.f_lockout and m.fin_active:
		out.append(["TERRAIN", C_RED])
		out.append(["SYSTEM", C_RED])
	if m.w_stall:
		out.append(["STALL", C_RED])
	if m.w_gear:
		out.append(["GEAR UNSAFE", C_RED])
	if m.w_overspeed:
		out.append(["OVERSPEED", C_RED])
	if m.w_sink:
		out.append(["SINK RATE", C_AMB])
	if m.park_brake:
		out.append(["PARK BRAKE", C_AMB])
	if m.on_ground and m.flaps_cmd == 0 and m.V > 20.0 and not m.landed:
		out.append(["CONFIG FLAPS", C_AMB])
	if ui.caut_flash:
		out.append(["A/P DISC", C_AMB])
	for fm in m.sys.fuel_msgs():
		out.append(fm)
	if out.is_empty():
		out.append(["NORMAL", C_GRN])
	return out


func _draw_cdu() -> void:
	var m := ui.m
	draw_rect(Rect2(Vector2.ZERO, size), Color("#020a04"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#555"), false, 2.0)
	var dd := m.cur_dest()
	var lines: Array = []
	lines.append("ANCIENT AIR 001   CDU")
	lines.append("DEST  %s  RWY %s" % [str(dd["name"]), str(dd["rwy"])])
	var eta := ""
	if m.gs > 5.0:
		var sec := int(m.dist_dest / m.gs)
		eta = "%02d:%02d" % [sec / 60, sec % 60]
	lines.append("DIST  %5.1f NM   ETA %s" % [m.dist_dest / WorldData.NM, eta])
	lines.append("AUTOLAND  %s" % m.al_st)
	lines.append("SEL  SPD %d  HDG %03d  ALT %d" % [int(m.ap_spd), int(m.ap_hdg) % 360, int(m.ap_alt)])
	lines.append("------------------------")
	var from_i := maxi(0, ui.log.size() - 6)
	for i in range(from_i, ui.log.size()):
		lines.append("> " + ui.log[i].substr(0, 30))
	var y := 17.0
	for ln in lines:
		_txt(ln, Vector2(8, y), 12, C_CRT, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, false)
		y += 15.0


# ------------------------------------------------------------------ controls
func _draw_yoke() -> void:
	var m := ui.m
	_panel_bg()
	var c := Vector2(size.x * 0.5, size.y * 0.62)
	var push := m.in_elev * 14.0
	draw_rect(Rect2(c.x - 9.0, c.y - 8.0 - push, 18.0, 90.0), Color("#33363c"))
	var rot := m.in_ail * deg_to_rad(80.0)
	draw_set_transform(c + Vector2(0, -push), rot, Vector2.ONE)
	draw_arc(Vector2.ZERO, 54.0, deg_to_rad(200.0), deg_to_rad(340.0), 24, Color("#1b1c20"), 12.0, true)
	draw_line(Vector2(-60, -22), Vector2(60, -22), Color("#1b1c20"), 12.0, true)
	draw_rect(Rect2(-8, -26, 16, 20), Color("#101114"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_txt("YOKE  (drag / WASD)", Vector2(0, 16), 11, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_txt("AIL %+.2f  ELEV %+.2f" % [m.in_ail, m.in_elev], Vector2(0, size.y - 8), 11, C_AMB, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_gear() -> void:
	var m := ui.m
	_panel_bg()
	_txt("LANDING GEAR", Vector2(0, 16), 11, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	# gear lever
	var lx := 40.0
	draw_rect(Rect2(lx - 4.0, 30.0, 8.0, 100.0), Color("#0a0a0a"))
	var ly := 36.0 if m.gear_cmd == 0 else 104.0
	draw_rect(Rect2(lx - 12.0, ly, 24.0, 22.0), C_AMB if m.gear_cmd == 1 else C_CREAM)
	_txt("UP", Vector2(lx + 16.0, 52.0), 12, C_CREAM)
	_txt("DN", Vector2(lx + 16.0, 124.0), 12, C_CREAM)
	_hits.append([Rect2(lx - 20.0, 26.0, 70.0, 110.0), "gear"])
	# three lamps
	for i in 3:
		var col := C_GRN if m.gear > 0.99 else (C_RED if m.gear > 0.01 else Color("#222"))
		draw_circle(Vector2(112.0 + (i - 1) * 0.0, 44.0 + i * 24.0), 8.0, col)
	# flaps
	_txt("FLAPS", Vector2(96, 130), 10, C_CREAM)
	_txt(str(int(FlightModel.FLAP_POS[m.flaps_cmd])), Vector2(96, 150), 16, C_AMB)
	_button(Rect2(136, 112, 28, 22), "-", "flap_up")
	_button(Rect2(136, 138, 28, 22), "+", "flap_dn")


func _draw_quad() -> void:
	var m := ui.m
	_panel_bg()
	_txt("THRUST (drag / R F)", Vector2(0, 16), 11, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	for i in 2:
		var x := 70.0 + i * 70.0
		draw_rect(Rect2(x - 6.0, 34.0, 12.0, 112.0), Color("#050505"))
		var y := 144.0 - float(m.lever[i]) * 108.0
		draw_rect(Rect2(x - 18.0, y - 12.0, 36.0, 24.0), Color("#a82820") if m.lever[i] > 0.97 else Color("#2d3036"))
		draw_rect(Rect2(x - 18.0, y - 12.0, 36.0, 24.0), Color("#999"), false, 1.5)
		_txt("%d" % int(m.lever[i] * 100.0), Vector2(x - 18.0, y + 5.0), 12, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 36.0)
	# speedbrake (read-only, driven by autoland)
	draw_rect(Rect2(226.0, 34.0, 8.0, 112.0), Color("#050505"))
	draw_rect(Rect2(216.0, 130.0 - m.spd_brake * 90.0, 28.0, 16.0), C_AMB if m.spd_brake > 0.05 else Color("#2d3036"))
	_txt("SPD", Vector2(212, 160), 10, C_CREAM)
	if m.athr_active:
		_txt("A/T", Vector2(20, 160), 12, C_GRN)


func _draw_ann() -> void:
	var m := ui.m
	_panel_bg(Color("#121315"))
	var defs: Array = [
		["GEAR", "UNSAFE", C_RED, m.w_gear],
		["STALL", "", C_RED, m.w_stall],
		["OVER", "SPEED", C_RED, m.w_overspeed],
		["SINK", "RATE", C_AMB, m.w_sink],
		["TERRAIN", "PULL UP", C_RED, ui.terrain_warn],
		["A/P", "ENGAGED", C_GRN, m.ap_on],
		["A/T", "ARMED", C_GRN, m.ap_athr and m.ap_on],
		["AUTO", "LAND", C_GRN, m.al_st == "ENG" or m.al_st == "LOCK"],
		["FLAPS", "LIMIT", C_AMB, m.flaps > 0.5 and m.ias_kt > m.vfe + 2.0],
		["PARK", "BRAKE", C_AMB, m.park_brake],
		["GEAR", "DOWN", C_GRN, m.gear > 0.99],
		["MASTER", "KING", C_GOLD, ui.king_lamp],
	]
	var flash := fmod(ui.t, 0.6) < 0.3
	for i in defs.size():
		var d: Array = defs[i]
		var col := i % 4
		var row := i / 4
		var r := Rect2(10 + col * 64, 8 + row * 48, 58, 42)
		var on: bool = d[3]
		if on and d[2] == C_RED and not flash:
			on = false
		draw_rect(r, Color("#050506"))
		draw_rect(r, Color("#3a3c40"), false, 1.5)
		if on:
			draw_rect(r.grow(-3.0), Color(d[2], 0.28))
		var tc: Color = d[2] if on else Color(0.35, 0.35, 0.38)
		_txt(d[0], Vector2(r.position.x, r.position.y + 18.0), 11, tc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		_txt(d[1], Vector2(r.position.x, r.position.y + 34.0), 11, tc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# system integrity readout
	_txt("SYS INTEG %d%%" % int(m.sys.integ * 100.0), Vector2(0, size.y - 8), 12, C_GRN if m.sys.integ > 0.5 else C_RED, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_eng() -> void:
	var m := ui.m
	_panel_bg()
	_txt("ENGINES", Vector2(0, 16), 11, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	for i in 2:
		var x := 18.0 + i * 112.0
		var n: float = m.n1[i]
		_txt("ENG %d" % (i + 1), Vector2(x, 40), 12, C_WHITE)
		_bar(Rect2(x, 48, 96, 10), n / 110.0, C_GRN)
		_txt("N1 %5.1f" % n, Vector2(x, 76), 11, C_GRN)
		var n2 := 0.0 if n < 20.0 else 40.0 + n * 0.58
		_txt("N2 %5.1f" % n2, Vector2(x, 92), 11, C_GRN)
		var egt := 380.0 + (n - 24.0) * 5.5
		_txt("EGT %4d" % int(egt), Vector2(x, 108), 11, C_AMB if egt > 700.0 else C_GRN)
		var ff := 400.0 + FlightModel.tf_of_n1(n) * 2900.0
		_txt("FF  %4d" % int(ff), Vector2(x, 124), 11, C_GRN)
	var sy := m.sys
	var fcol := C_GRN if sy.fuel_total() > 3.0 else C_RED
	_txt("FUEL L %.1f  R %.1f  T" % [sy.fuel[0], sy.fuel[1]], Vector2(0, 142), 11, fcol, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_txt("HYD A %d%%  B %d%%  BATT %d%%" % [int(sy.hyd[0] * 100.0), int(sy.hyd[1] * 100.0), int(sy.batt * 100.0)], Vector2(0, 158), 10, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, size.x, false)


func _bar(r: Rect2, v: float, col: Color) -> void:
	draw_rect(r, Color("#000040"))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), col)
	draw_rect(r, Color("#8a8ab0"), false, 1.0)


func _draw_panel() -> void:
	var m := ui.m
	_panel_bg()
	_txt("FLIGHT DECK", Vector2(0, 14), 11, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var bw := 124.0
	var bh := 25.0
	var defs: Array = [
		["PARK BRAKE", "park", m.park_brake, C_AMB], ["WHEEL BRAKE", "brake", ui.wheel_brake, C_AMB],
		["TIME x%d" % ui.warp, "warp", ui.warp > 1, C_CYAN], ["MAP RNG %d" % ui.rng, "range", false, C_CYAN],
		["MUTE" if not ui.muted else "UNMUTE", "mute", ui.muted, C_RED], ["HELP (H)", "help", false, C_GRN],
		["PAUSE", "pause", ui.paused, C_AMB], ["AUTO T/O (T)", "to", m.ato_phase != "" and m.ato_phase != "DONE", C_GRN],
		["OVERHEAD (O)", "ovh", ui.ovh_open, C_GRN], ["PDA (I)", "inv", false, C_GRN],
	]
	for i in defs.size():
		var d: Array = defs[i]
		_button(Rect2(6.0 + (i % 2) * 130.0, 20.0 + (i / 2) * 29.0, bw, bh), d[0], d[1], d[2], d[3])


func _draw_mcp() -> void:
	var m := ui.m
	_panel_bg(Color("#202226"))
	_button(Rect2(8, 8, 62, 26), "A/P", "ap", m.ap_on, C_GRN)
	_button(Rect2(8, 38, 62, 26), "A/T", "at", m.ap_athr and m.ap_on, C_GRN)
	var vals: Array = [
		["SPD", "%d" % int(m.ap_spd), "spd"],
		["HDG", "%03d" % (int(m.ap_hdg) % 360), "hdg"],
		["ALT", "%d" % int(m.ap_alt), "alt"],
		["V/S", "%+d" % int(m.ap_vs), "vs"],
	]
	for i in 4:
		var x := 84.0 + i * 118.0
		var v: Array = vals[i]
		_txt(v[0], Vector2(x, 14), 11, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, 108.0)
		draw_rect(Rect2(x + 22.0, 18.0, 64.0, 24.0), Color.BLACK)
		_txt(v[1], Vector2(x + 22.0, 37.0), 16, C_AMB, HORIZONTAL_ALIGNMENT_CENTER, 64.0)
		_button(Rect2(x, 18.0, 20.0, 24.0), "-", v[2] + "-")
		_button(Rect2(x + 88.0, 18.0, 20.0, 24.0), "+", v[2] + "+")
		_txt(("LOCK" if i == 1 and m.ap_lat == "HDG" else ""), Vector2(x, 60), 9, C_GRN, HORIZONTAL_ALIGNMENT_CENTER, 108.0)
	_button(Rect2(560, 8, 90, 26), "DEST (K)", "dest", m.al_st == "ARM" or m.al_st == "ENG", C_GRN)
	_button(Rect2(560, 38, 90, 26), m.dest + " (J)", "jsw", false, C_MAG)
	_txt("VERT " + m.ap_vert, Vector2(660, 28), 11, C_GRN)
	_txt("AL: " + m.al_st, Vector2(660, 52), 11, C_GRN)


# ------------------------------------------------------------------ mouse
func _gui_input(event: InputEvent) -> void:
	if ui == null or ui.m == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at(event.position)
		else:
			_release()
	elif event is InputEventMouseMotion and _drag != "":
		_drag_to(event.position)


func _press_at(p: Vector2) -> void:
	if kind == "yoke":
		if ui.m.f_lockout:
			ui.denied.emit()
			return
		_drag = "yoke"
		ui.yoke_drag = true
		_drag_to(p)
		return
	if kind == "quad":
		if ui.m.f_lockout:
			ui.denied.emit()
			return
		_drag = "quad"
		_drag_to(p)
		return
	for h in _hits:
		if (h[0] as Rect2).has_point(p):
			_held = h[1]
			ui.press(_held)
			return


func _release() -> void:
	if _held != "":
		ui.release(_held)
		_held = ""
	if _drag == "yoke":
		ui.yoke_drag = false
		ui.yoke_ail = 0.0
		ui.yoke_elev = 0.0
	_drag = ""


func _drag_to(p: Vector2) -> void:
	if _drag == "yoke":
		var c := Vector2(size.x * 0.5, size.y * 0.55)
		ui.yoke_ail = clampf((p.x - c.x) / 90.0, -1.0, 1.0)
		ui.yoke_elev = clampf((p.y - c.y) / 55.0, -1.0, 1.0)
	elif _drag == "quad":
		ui.set_lever((144.0 - p.y) / 108.0)


func _draw_overhead() -> void:
	var m := ui.m
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.11, 0.96))
	draw_rect(Rect2(Vector2.ZERO, size), C_AMB, false, 3.0)
	_txt("OVERHEAD PANEL  (O to close)", Vector2(16, 28), 18, C_AMB)
	var sy := m.sys
	for i in AircraftSystems.ORDER.size():
		var nm: String = AircraftSystems.ORDER[i]
		var col := i % 9
		var row := i / 9
		var r := Rect2(16.0 + col * 108.0, 50.0 + row * 86.0, 100.0, 70.0)
		var on: bool = sy.e(nm) == 1
		var crit := AircraftSystems.CRITICAL.has(nm)
		var locked: bool = sy.lock and crit
		var lamp := C_GRN if on else Color("#333")
		if nm.begins_with("START"):
			lamp = C_AMB if sy.eng_st[int(nm.right(1)) - 1] > 0.0 else Color("#333")
		draw_rect(r, Color("#202226"))
		draw_rect(r, Color("#5a5d63") if not locked else Color("#802020"), false, 2.0)
		draw_circle(r.position + Vector2(50, 20), 8.0, lamp)
		_txt(nm, Vector2(r.position.x, r.position.y + 48.0), 12, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		_txt("ON" if on else "OFF", Vector2(r.position.x, r.position.y + 63.0), 11, C_GRN if on else C_AMB, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		_hits.append([r, "ovh:" + nm])
	_txt("Tip: START switches need bleed air (other engine / APU / airspeed). CUTOFF kills an engine.", Vector2(16, size.y - 14), 13, C_CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1.0, false)
