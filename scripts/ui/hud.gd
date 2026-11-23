class_name Hud
extends Control
## HUD-80 head-up display drawn over the windshield (port of the HUD object of the HTML game):
## pitch ladder, roll scale, heading / speed / altitude tapes, flight-path marker, LOC/GS diamonds,
## corner read-outs, system side panels, NAV / TGT modes (sandstorm radar, track brackets, A/P call-outs),
## IMPACT IMMINENT alerts and the power-up self test.
## All coordinates are the original stage coordinates (1600 x 900); the control is positioned at y = 62.

const FONT := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const WIN_Y0 := 62.0
const WIN_Y1 := 414.0
const HH := WIN_Y1 - WIN_Y0
const NM := WorldData.NM
const FT := WorldData.FT
const D2R := WorldData.D2R

const G := Color("#6dff93")
const D := Color("#2fb35c")
const A := Color("#ffc53a")
const R := Color("#ff4a3a")
const C := Color("#7df4ff")
const OUT := Color(0.0, 0.094, 0.024, 0.55)
const BOOT_T1 := 6.0

var ui: FlightUI
var camera: Camera3D
var vis_far := 105000.0
var mode := "NAV"
var sw_t := -9.0
var hit_t := -9.0
var hit_msg := ""
var av_t := -9.0
var av_msg := ""
var bt := 0.0
var thr := {}
var last_dir := [0, 0]
var dir_t := -9.0
var scope_ang := 0.0
var age := 0.0            ## seconds since the display was powered
var fin_tgt := false
var _prev_dead := {}


func bind(u: FlightUI, cam: Camera3D) -> void:
	ui = u
	camera = cam
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hit(zone: String) -> void:
	hit_t = ui.t
	hit_msg = "IMPACT " + zone.to_upper()
	thr = {}


func _process(dt: float) -> void:
	if ui == null or ui.m == null:
		return
	var lit: float = ui.power.get("hud", 1.0)
	if lit > 0.5:
		age += dt
	else:
		age = 0.0
	queue_redraw()


# ------------------------------------------------------------------ primitives
func _o(p: Vector2) -> Vector2:
	return p - Vector2(0, WIN_Y0)


func L(col: Color, x1: float, y1: float, x2: float, y2: float) -> void:
	var a := _o(Vector2(x1, y1))
	var b := _o(Vector2(x2, y2))
	var jit := 0.0
	if ui.glitch > 0.25 and age >= BOOT_T1 and randf() < ui.glitch * 0.1:
		a += Vector2((randf() - 0.5) * 60.0, (randf() - 0.5) * 14.0)
		b = a + (_o(Vector2(x2, y2)) - _o(Vector2(x1, y1)))
	draw_line(a, b, OUT, 3.4, true)
	draw_line(a, b, Color(col, col.a * _dimv), 1.8, true)


var _dimv := 1.0


func T(s: String, px: float, py: float, sc: int, col: Color, al := "l") -> float:
	if sc == 1:
		sc = 2
	s = s.to_upper()
	var size := int(sc * 8.6)
	var adv := 6.0 * sc
	var w := s.length() * adv - sc
	if al == "c":
		px -= w / 2.0
	elif al == "r":
		px -= w
	var base := _o(Vector2(px, py + size * 0.78))
	for i in s.length():
		var ch := s[i]
		if ch == " ":
			continue
		var p := base + Vector2(i * adv, 0)
		draw_string(FONT, p + Vector2(1, 1), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0.09, 0.024, 0.65))
		draw_string(FONT, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, col.a * _dimv))
	return w


func ring(cx: float, cy: float, r: float, col: Color, lw := 1.4) -> void:
	var p := _o(Vector2(cx, cy))
	draw_arc(p, r, 0.0, TAU, 40, OUT, lw + 2.0, true)
	draw_arc(p, r, 0.0, TAU, 40, Color(col, col.a * _dimv), lw, true)


func box(px: float, py: float, w: float, h: float, col: Color) -> void:
	L(col, px, py, px + w, py)
	L(col, px + w, py, px + w, py + h)
	L(col, px + w, py + h, px, py + h)
	L(col, px, py + h, px, py)


func brk(cx: float, cy: float, s: float, col: Color, k: float) -> void:
	var a := s * k
	var d := maxf(4.0, s * 0.45)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var x: float = cx + sx * a
			var y: float = cy + sy * a
			L(col, x, y, x - sx * d, y)
			L(col, x, y, x, y - sy * d)


## filled arrow, dir: 0 up 1 right 2 down 3 left
func tri(cx: float, cy: float, s: float, dir: int, col: Color) -> void:
	var pts := [Vector2(0, -s), Vector2(s * 0.8, s * 0.7), Vector2(-s * 0.8, s * 0.7)]
	var a := dir * 1.5708
	var c := cos(a)
	var n := sin(a)
	var poly := PackedVector2Array()
	for q in pts:
		poly.append(_o(Vector2(cx + q.x * c - q.y * n, cy + q.x * n + q.y * c)))
	draw_colored_polygon(poly, Color(col, col.a * _dimv))
	poly.append(poly[0])
	draw_polyline(poly, Color(0, 0.094, 0.024, 0.6), 1.0)


func dia(px: float, py: float, col: Color) -> void:
	L(col, px, py - 6, px + 6, py)
	L(col, px + 6, py, px, py + 6)
	L(col, px, py + 6, px - 6, py)
	L(col, px - 6, py, px, py - 6)


func proj(p: Vector3) -> Dictionary:
	var behind := camera.is_position_behind(p)
	var q := camera.unproject_position(p)
	return {"x": q.x * 1600.0 / 1600.0, "y": WIN_Y0 + q.y, "behind": behind}


# ------------------------------------------------------------------ main
func _draw() -> void:
	if ui == null or ui.m == null or camera == null:
		return
	var m := ui.m
	var t := ui.t
	var warm: float = ui.power.get("hud", 1.0)
	if warm < 0.5:
		return
	modulate.a = clampf(warm, 0.0, 1.0) * (1.0 - 0.05 * sin(t * 53.0) - 0.03 * sin(t * 9.1))
	var gl: float = clampf((1.0 - m.sys.integ - 0.2) * 0.35, 0.0, 0.25)
	if ui.glitch > 0.3:
		gl = maxf(gl, ui.glitch * 0.8)
	_dimv = 1.0
	if gl > 0.35:
		_dimv = 0.4 if int(t * 17.0) % 4 == 0 else (1.6 if int(t * 23.0) % 7 == 0 else 1.0)
	_dimv = minf(_dimv, 1.0)
	# modes
	fin_tgt = ui.fin_state == "script" or ui.fin_state == "cine"
	var want := "TGT" if (fin_tgt or (m.storm != null and (m.storm.state != "idle" or not m.storm.deb.is_empty()))) else "NAV"
	if want != mode:
		mode = want
		sw_t = t
		Sfx.blip()
	var on := clampf((age - BOOT_T1) / 1.0, 0.0, 1.0)
	if on <= 0.0:
		_boot(age)
		return
	var cx := 800.0
	var cy := WIN_Y0 + HH / 2.0
	var ppd := HH / 38.0
	var ph := m.phi
	var cp := cos(-ph)
	var sp := sin(-ph)
	var tgt := mode == "TGT"
	var Am := A
	var rot := func(px: float, py: float) -> Vector2:
		return Vector2(cx + px * cp - py * sp, cy + px * sp + py * cp)
	var dd := m.cur_dest()
	if not tgt:
		var th := rad_to_deg(m.theta)
		for p in range(-30, 31, 5):
			var yo := (th - p) * ppd
			if absf(yo) > 100.0:
				continue
			var hz: bool = p == 0
			var half := 215.0 if hz else 56.0
			var gap := 36.0 if hz else 26.0
			var seg := func(a: float, b: float):
				var p1: Vector2 = rot.call(a, yo)
				var p2: Vector2 = rot.call(b, yo)
				L(G, p1.x, p1.y, p2.x, p2.y)
			if p < 0:
				for sdn in [-1.0, 1.0]:
					for q in 3:
						seg.call(sdn * (gap + q * (half - gap) / 3.0), sdn * (gap + (q + 0.62) * (half - gap) / 3.0))
			else:
				seg.call(-half, -gap)
				seg.call(gap, half)
			if not hz:
				var e1: Vector2 = rot.call(-half, yo)
				var e2: Vector2 = rot.call(half, yo)
				var dv := 6.0 if p > 0 else -6.0
				var e1b: Vector2 = rot.call(-half, yo + dv)
				var e2b: Vector2 = rot.call(half, yo + dv)
				L(G, e1.x, e1.y, e1b.x, e1b.y)
				L(G, e2.x, e2.y, e2b.x, e2b.y)
				var lab := str(absi(p))
				var pl: Vector2 = rot.call(-half - 6.0, yo - 7.0)
				var pr: Vector2 = rot.call(half + 6.0, yo - 7.0)
				T(lab, pl.x, pl.y, 1, G, "r")
				T(lab, pr.x, pr.y, 1, G, "l")
		var R0 := 104.0
		for a in [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]:
			var rad := deg_to_rad(a)
			var l: float = 9.0 if a % 30 == 0 else 5.0
			var sx := sin(rad)
			var sy := -cos(rad)
			L(G, cx + sx * R0, cy + sy * R0, cx + sx * (R0 + l), cy + sy * (R0 + l))
		var pa := -ph
		var p1 := Vector2(cx + sin(pa) * (R0 - 2.0), cy - cos(pa) * (R0 - 2.0))
		var p2 := Vector2(cx + sin(pa) * (R0 - 12.0) + cos(pa) * 6.0, cy - cos(pa) * (R0 - 12.0) + sin(pa) * 6.0)
		var p3 := Vector2(cx + sin(pa) * (R0 - 12.0) - cos(pa) * 6.0, cy - cos(pa) * (R0 - 12.0) - sin(pa) * 6.0)
		L(G, p1.x, p1.y, p2.x, p2.y)
		L(G, p2.x, p2.y, p3.x, p3.y)
		L(G, p3.x, p3.y, p1.x, p1.y)
	# heading tape
	var hdg := fposmod(rad_to_deg(m.psi), 360.0)
	var y0 := WIN_Y0 + 40.0
	var hw := 300.0
	L(G, cx - hw, y0 + 12, cx + hw, y0 + 12)
	for a in range(int(floor(hdg)) - 28, int(ceil(hdg)) + 29):
		if a % 5 != 0:
			continue
		var xx := cx + (a - hdg) * 11.0
		var big: bool = a % 10 == 0
		var aa := posmod(a, 360)
		if absf(xx - cx) > hw:
			continue
		L(G, xx, y0 + 12, xx, y0 + 12 - (8.0 if big else 4.0))
		if big and absf(xx - cx) > 34.0 and absf(xx - cx) < hw - 14.0:
			var n := "N" if aa == 0 else ("E" if aa == 90 else ("S" if aa == 180 else ("W" if aa == 270 else "%02d" % (aa / 10))))
			T(n, xx, y0 - 4.0, 2, G, "c")
	box(cx - 24, y0 - 30, 48, 20, G)
	T("%03d" % (roundi(hdg) % 360), cx, y0 - 27.0, 2, G, "c")
	L(G, cx, y0 - 10, cx, y0 - 5)
	tri(cx, y0 + 22, 5, 0, G)
	# speed tape (left)
	var ias := m.ias_kt
	var tx := cx - 262.0
	var top := cy - 72.0
	var bot := cy + 80.0
	L(G, tx, top, tx, bot)
	for v in range(int(floor(ias - 28.0)), int(ias + 29.0)):
		if v < 0 or v % 5 != 0:
			continue
		var yy := cy - (v - ias) * 3.0
		if yy < top or yy > bot:
			continue
		var big2: bool = v % 10 == 0
		L(G, tx, yy, tx + (10.0 if big2 else 5.0), yy)
		if v % 20 == 0 and absf(yy - cy) > 16.0:
			T(str(v), tx - 6, yy - 7, 1, G, "r")
	box(tx - 62, cy - 11, 60, 22, G)
	T("%3d" % roundi(ias), tx - 6, cy - 7, 2, G, "r")
	L(G, tx - 2, cy, tx + 8, cy)
	T("IAS", tx - 30, top - 20, 1, D, "c")
	T("M " + ("%.2f" % m.mach).substr(1), tx - 30, top - 36, 1, D, "c")
	var spd := 0.0
	if m.ap_on:
		spd = m.ap_spd_target if m.ap_spd_target > 0.0 else m.ap_spd
	if spd > 0.0:
		var ys := clampf(cy - (spd - ias) * 3.0, top, bot)
		tri(tx + 14, ys, 4, 3, C)
		T("SEL %d" % roundi(spd), tx - 30, bot + 8, 1, C, "c")
	# altitude tape (right)
	var alt := m.alt_ft
	tx = cx + 262.0
	L(G, tx, top, tx, bot)
	var v2 := floorf((alt - 280.0) / 50.0) * 50.0
	while v2 <= alt + 280.0:
		var yy2 := cy - (v2 - alt) * 0.3
		if yy2 >= top and yy2 <= bot:
			var big3 := int(v2) % 100 == 0
			L(G, tx, yy2, tx - (10.0 if big3 else 5.0), yy2)
			if int(v2) % 200 == 0 and absf(yy2 - cy) > 16.0:
				T(str(maxi(0, int(v2))), tx + 6, yy2 - 7, 1, G, "l")
		v2 += 50.0
	box(tx + 2, cy - 11, 66, 22, G)
	T("%5d" % (roundi(alt / 10.0) * 10), tx + 66, cy - 7, 2, G, "r")
	L(G, tx - 8, cy, tx + 2, cy)
	T("ALT", tx + 36, top - 20, 1, D, "c")
	if m.agl_m < 760.0:
		T("RA %04d" % maxi(0, roundi(m.agl_ft / 10.0) * 10), tx + 36, top - 36, 1, A if m.agl_m < 150.0 else D, "c")
	var vs := roundi(m.vs_ms * 60.0 / FT / 50.0) * 50
	T("VS %+d" % vs, tx + 36, bot + 8, 1, A if absi(vs) > 2500 else G, "c")
	# flight path marker
	var al := clampf(rad_to_deg(m.theta - m.gamma), -14.0, 14.0)
	var fx := cx
	var fy := cy + al * ppd
	ring(fx, fy, 7, G, 1.5)
	L(G, fx - 7, fy, fx - 17, fy)
	L(G, fx + 7, fy, fx + 17, fy)
	L(G, fx, fy - 7, fx, fy - 13)
	L(D, cx - 4, cy, cx + 4, cy)
	L(D, cx, cy - 4, cx, cy + 4)
	# ILS-ish diamonds
	if not tgt and (m.al_st == "ARM" or m.al_st == "ENG" or m.al_st == "LOCK"):
		var lx := clampf(m.cross / 60.0, -1.0, 1.0) * 70.0
		var gs_alt: float = float(dd["y"]) + m.dz * tan(3.0 * D2R)
		var gyy := clampf((m.alt_m - gs_alt) / 18.0, -1.0, 1.0) * 70.0
		L(D, cx - 72, cy + 90, cx + 72, cy + 90)
		for i in range(-2, 3):
			L(D, cx + i * 35, cy + 87, cx + i * 35, cy + 93)
		L(D, cx + 158, cy - 70, cx + 158, cy + 70)
		for i in range(-2, 3):
			L(D, cx + 155, cy + i * 35, cx + 161, cy + i * 35)
		dia(cx - lx, cy + 90, C)
		dia(cx + 158, cy + gyy, C)
		T("LOC", cx - 82, cy + 83, 1, D, "r")
		T("GS", cx + 170, cy - 7, 1, D, "l")
	# corner read-outs
	var yt := WIN_Y0 + 6.0
	var L0 := 306.0
	var R0b := 1294.0
	T("N1 %d %d" % [roundi(m.n1[0]), roundi(m.n1[1])], L0, yt, 1, D, "l")
	T(("GEAR DN" if m.gear_cmd == 1 else "GEAR UP") + " F%d" % m.flaps_cmd, L0, yt + 18, 1, A if (m.gear < 1.0 and m.gear > 0.0) else D, "l")
	var ig := m.sys.integ
	var pc := roundi(ig * 100.0)
	var ic := G if pc > 60 else (A if pc > 30 else (R if int(t * 4.0) % 2 == 1 else A))
	T("SYS INTEG %d%%" % pc, L0, yt + 36, 1, ic, "l")
	var nbars := 15
	var fill := ceili(ig * nbars - 0.001)
	box(L0, yt + 56, nbars * 10 + 4, 10, ic)
	for i in nbars:
		var rc := Rect2(_o(Vector2(L0 + 2 + i * 10, yt + 58)), Vector2(8, 6))
		draw_rect(rc, ic if i < fill else Color(1, 0.29, 0.23, 0.18))
	var apt := "A/P OFF"
	if m.ap_on:
		apt = "A/P " + ((("APPR" if (m.dest != "MKNG" and m.agl_ft > 500.0) else "LAND") if m.al_st == "ENG" else m.ap_lat)) + " " + ("GS" if m.al_st == "ENG" else m.ap_vert)
	T(apt, R0b, yt, 1, G if m.ap_on else A, "r")
	T("HUD-80 " + ("TGT" if tgt else "NAV") + (" #" if int(t * 2.0) % 2 == 1 else "  "), R0b, yt + 18, 1, A if tgt else D, "r")
	if m.f_airborne:
		var nm := m.dist_dest / NM
		if nm < 60.0:
			T("%s %.1f NM" % [str(dd["short"]), nm], R0b, yt + 36, 1, G, "r")
	_sides(m, t, dd)
	if tgt:
		_target(m, cx, cy, t)
	var swa := t - sw_t
	if swa < 2.4:
		var f := int(t * 8.0) % 2
		if f == 1 or swa < 0.5:
			var msg := "< NAV MODE >  CLEAR"
			if tgt:
				msg = "< TGT MODE >  OBSTACLE  TRACKING" if fin_tgt else "< TGT MODE >  SANDSTORM  TRACKING"
			T(msg, cx, cy + 84, 1, A if tgt else G, "c")
		if swa < 1.0:
			var sxp := cx - 480.0 + swa * 960.0
			L(A if tgt else G, sxp, WIN_Y0 + 70, sxp, WIN_Y1 - 80)
			L(D, sxp - 6, WIN_Y0 + 70, sxp - 6, WIN_Y1 - 80)
	_alerts(m, cx, cy, t)


# ------------------------------------------------------------------ side panels
func _sbar(px: float, py: float, w: float, f: float, col: Color) -> void:
	f = clampf(f, 0.0, 1.0)
	draw_rect(Rect2(_o(Vector2(px, py)), Vector2(w, 5)), Color(0, 0.11, 0.03, 0.55))
	draw_rect(Rect2(_o(Vector2(px, py)), Vector2(w * f, 5)), col)
	L(D, px, py + 6, px + w, py + 6)


func _shead(px: float, py: float, w: float, s: String, col: Color) -> void:
	T(s, px, py, 1, col, "l")
	L(col, px, py + 17, px + w, py + 17)


func _srow(px: float, py: float, w: float, l: String, v: String, col: Color, f := -1.0) -> void:
	T(l, px, py, 1, D, "l")
	T(v, px + w, py, 1, col, "r")
	if f >= 0.0:
		_sbar(px, py + 15, w, f, col)


func _sides(m: FlightModel, t: float, dd: Dictionary) -> void:
	var W := 132.0
	var ig := m.sys.integ
	var n1: Array = m.n1
	var egt := func(i: int) -> int:
		return roundi(380.0 + n1[i] * 5.2 + (30.0 if n1[i] > 96.0 else 0.0))
	var j := func(a: float) -> float:
		return a * (1.0 + 0.004 * sin(t * 3.1 + a))
	var px := 74.0
	var py := WIN_Y0 + 10.0
	_shead(px, py, W, "ENGINES", A)
	_srow(px, py + 24, W, "N1 L", "%.1f" % n1[0], R if n1[0] > 100.0 else G, n1[0] / 110.0)
	_srow(px, py + 50, W, "N1 R", "%.1f" % n1[1], R if n1[1] > 100.0 else G, n1[1] / 110.0)
	var e0: int = egt.call(0)
	var e1: int = egt.call(1)
	_srow(px, py + 76, W, "EGT L", str(e0), R if e0 > 880 else G, e0 / 1000.0)
	_srow(px, py + 102, W, "EGT R", str(e1), R if e1 > 880 else G, e1 / 1000.0)
	_shead(px, py + 134, W, "POWER", A)
	var ac := roundi(j.call(115.0 * (0.88 + 0.12 * ig)))
	var dc: float = j.call(28.0 * (0.88 + 0.12 * ig))
	var bat := roundi(m.sys.batt * 100.0)
	_srow(px, py + 158, W, "AC BUS", "%dV" % ac, A if ac < 105 else G, ac / 120.0)
	_srow(px, py + 184, W, "DC BUS", "%.1fV" % dc, A if dc < 25.0 else G, dc / 30.0)
	_srow(px, py + 210, W, "BATT", "%d%%" % bat, A if bat < 50 else G, bat / 100.0)
	_shead(px, py + 242, W, "HYD / FUEL", A)
	var hy := roundi(float(j.call(3000.0 * (0.55 + 0.45 * ig))) * (0.06 + 0.94 * m.sys.hyd[0]))
	var fu := m.sys.fuel_total()
	_srow(px, py + 266, W, "HYD A", str(hy), A if hy < 2200 else G, hy / 3200.0)
	_srow(px, py + 292, W, "FUEL", "%.1f" % fu, A if fu < 12.0 else G, fu / 32.0)
	# right: navigation / autopilot / track rose
	px = 1394.0
	var dnm := m.dist_dest / NM
	var ete := m.dist_dest / m.gs if m.gs > 20.0 else 0.0
	_shead(px, py, W, "NAVIGATION", A)
	_srow(px, py + 24, W, "DEST", str(dd["short"]), C)
	_srow(px, py + 44, W, "DIST", "%.1f" % dnm, G)
	var es := maxi(0, roundi(ete))
	_srow(px, py + 64, W, "ETE", "%02d:%02d" % [es / 60, es % 60], G)
	_srow(px, py + 84, W, "XTK", ("R" if m.cross >= 0.0 else "L") + str(absi(roundi(m.cross))), A if absf(m.cross) > 200.0 else G)
	_shead(px, py + 112, W, "AUTOFLIGHT", A)
	_srow(px, py + 136, W, "A/P", "CMD" if m.ap_on else "OFF", G if m.ap_on else A)
	_srow(px, py + 156, W, "A/T", "ON" if m.ap_athr else "OFF", G if m.ap_athr else A)
	var landmap := {"ENG": "ENGD", "LOCK": "ENGD", "ARM": "ARMD", "ROLL": "ROLL", "CANCEL": "CNCL"}
	_srow(px, py + 176, W, "LAND", landmap.get(m.al_st, "OFF"), G if (m.al_st == "ENG" or m.al_st == "LOCK" or m.al_st == "ROLL") else (C if m.al_st == "ARM" else D))
	_shead(px, py + 204, W, "TRACK", A)
	var rx := px + W / 2.0
	var ry := py + 290.0
	var rr := 36.0
	ring(rx, ry, rr, D, 1.2)
	ring(rx, ry, rr * 0.5, D, 0.8)
	for d in range(0, 360, 30):
		var a := d * D2R - m.psi
		var l: float = 9.0 if d % 90 == 0 else 5.0
		L(D, rx + sin(a) * rr, ry - cos(a) * rr, rx + sin(a) * (rr - l), ry - cos(a) * (rr - l))
	var an := -m.psi
	T("N", rx + sin(an) * (rr + 10.0) - 6.0, ry - cos(an) * (rr + 10.0) - 7.0, 1, A, "l")
	var br := atan2(float(dd["x"]) - m.pos.x, -(float(dd["z"]) - m.pos.z)) - m.psi
	dia(rx + sin(br) * (rr - 10.0), ry - cos(br) * (rr - 10.0), C)
	tri(rx, ry, 5, 0, G)
	L(G, rx, ry - 6, rx, ry - rr)


# ------------------------------------------------------------------ TGT overlay
func _tcol(d: Dictionary) -> Color:
	if d["dead"]:
		return D
	if d["tcpa"] >= 0.0 and d["n"] < 0.72 and d["tcpa"] < 3.6:
		return R
	if d["tcpa"] >= 0.0 and d["n"] < 1.1:
		return A
	return G


func _target(m: FlightModel, cx: float, cy: float, t: float) -> void:
	var deb: Array = m.storm.deb
	var sx := 372.0
	var sy := cy + 6.0
	var sr := 52.0
	var RNG := 1100.0
	draw_circle(_o(Vector2(sx, sy)), sr + 2.0, Color(0, 0.11, 0.03, 0.45))
	ring(sx, sy, sr, D, 1.3)
	ring(sx, sy, sr * 0.66, D, 0.8)
	ring(sx, sy, sr * 0.33, D, 0.8)
	L(D, sx - sr, sy, sx + sr, sy)
	L(D, sx, sy - sr, sx, sy + sr)
	for i in 14:
		var a := scope_ang - i * 0.07
		var al := 1.0 - i / 14.0
		draw_line(_o(Vector2(sx, sy)), _o(Vector2(sx + sin(a) * sr, sy - cos(a) * sr)), Color(0.43, 1.0, 0.58, 0.5 * al * al), 2.0)
	scope_ang = fposmod(t * 2.4, TAU)
	tri(sx, sy, 4, 0, G)
	for d in deb:
		var k := sr / RNG
		var bx: float = sx + clampf(d["min_b"] * 0.0 + _bearing(m, d) * k, -sr, sr)
		var by: float = sy - clampf(d["a"] * k, -sr, sr)
		if Vector2(bx - sx, by - sy).length() > sr:
			continue
		var c := _tcol(d)
		var sz := maxf(2.0, minf(5.0, d["rad"] * 0.9))
		if c == R and int(t * 8.0) % 2 == 1:
			continue
		draw_rect(Rect2(_o(Vector2(bx - sz / 2.0, by - sz / 2.0)), Vector2(sz, sz)), c)
	T("TGT RADAR", sx, sy - sr - 18.0, 1, A, "c")
	T("%dM" % int(RNG), sx + sr, sy + sr + 4.0, 1, D, "r")
	# track list
	var lst: Array = []
	for d in deb:
		if not d["dead"] and d["a"] > -30.0:
			lst.append(d)
	lst.sort_custom(func(a, b): return _range(m, a) < _range(m, b))
	var lx := 1150.0
	var ly := WIN_Y0 + 112.0
	T("ID  RNG  ACT", lx, ly, 1, A, "l")
	L(A, lx, ly + 16, lx + 144, ly + 16)
	for i in mini(5, lst.size()):
		var d: Dictionary = lst[i]
		var c := _tcol(d)
		var y := ly + 22.0 + i * 16.0
		var thr_: bool = d["tcpa"] >= 0.0 and d["n"] < 1.1
		var act := "BRK" if c == R else ("AVD" if thr_ else "TRK")
		T("T%02d %04d %s" % [int(d["id"]) % 100, roundi(_range(m, d)), act], lx, y, 1, c, "l")
	var nthr := 0
	for d in deb:
		if not d["dead"] and d["tcpa"] >= 0.0 and d["n"] < 1.1:
			nthr += 1
	T("TRK%02d THR%02d" % [deb.size(), nthr], lx, ly + 22.0 + 5.0 * 16.0 + 4.0, 1, (R if int(t * 4.0) % 2 == 1 else A) if nthr > 0 else G, "l")
	var vis := roundi(vis_far / 10.0) * 10
	T("VIS %sM" % ("---" if vis > 9999 else str(vis)), lx, ly + 22.0 + 6.0 * 16.0 + 4.0, 1, D, "l")
	# brackets on the windshield
	var prio = null
	for d in deb:
		if d["dead"] or d["a"] < 2.0:
			continue
		if prio == null or (d["tcpa"] >= 0.0 and d["n"] < 1.1 and (prio["tcpa"] < 0.0 or prio["n"] >= 1.1 or d["tcpa"] < prio["tcpa"])) or (prio["tcpa"] < 0.0 and _range(m, d) < _range(m, prio)):
			prio = d
	var placed: Array = []
	if prio != null:
		var pp := proj(prio["p"])
		if not pp["behind"]:
			placed.append(Vector2(pp["x"], pp["y"]))
	for d in deb:
		if d["dead"] or d["a"] < 2.0:
			continue
		var p := proj(d["p"])
		if p["behind"]:
			continue
		var c := _tcol(d)
		var rng := _range(m, d)
		var inx: bool = p["x"] > 560.0 and p["x"] < 1040.0 and p["y"] > WIN_Y0 + 130.0 and p["y"] < WIN_Y1 - 76.0
		var px: float = maxf(8.0, d["rad"] / maxf(rng, 8.0) * 511.0)
		var age_: float = d["age"]
		var k := 1.0 + maxf(0.0, 0.7 - age_) * 1.6
		if not inx:
			var ex := clampf(p["x"], 566.0, 1034.0)
			var ey := clampf(p["y"], WIN_Y0 + 136.0, WIN_Y1 - 82.0)
			var dr := 1
			if absf(p["x"] - ex) > absf(p["y"] - ey):
				dr = 3 if p["x"] < ex else 1
			else:
				dr = 0 if p["y"] < ey else 2
			tri(ex, ey, 4, dr, c)
			continue
		var s := px + 6.0
		brk(p["x"], p["y"], s, c, k)
		if c != G and (c == R or int(t * 3.0) % 2 == 1):
			L(c, p["x"] - s - 10.0, p["y"], p["x"] - s - 3.0, p["y"])
			L(c, p["x"] + s + 3.0, p["y"], p["x"] + s + 10.0, p["y"])
		var id := "T%02d" % (int(d["id"]) % 100)
		var lx2 := clampf(p["x"] - s, 566.0, 900.0)
		if not ui.sec_on:
			if d == prio:
				T(id + " " + str(d["kind"]).to_upper(), lx2, clampf(p["y"] - s - 22.0, WIN_Y0 + 128.0, WIN_Y1 - 120.0), 1, c, "l")
				T("%dM %dM/S" % [roundi(rng), roundi(d["clos"])], lx2, clampf(p["y"] + s + 6.0, WIN_Y0 + 146.0, WIN_Y1 - 80.0), 1, c, "l")
			else:
				var near := false
				for q in placed:
					if (q as Vector2).distance_to(Vector2(p["x"], p["y"])) < 90.0:
						near = true
				if not near:
					T(id, lx2, clampf(p["y"] - s - 17.0, WIN_Y0 + 128.0, WIN_Y1 - 120.0), 1, c, "l")
					placed.append(Vector2(p["x"], p["y"]))
		if c != G:
			var mx := clampf(d["mr"] * 0.9, -90.0, 90.0)
			var my := clampf(-d["mu"] * 0.9, -60.0, 60.0)
			var a0 := _o(Vector2(p["x"], p["y"]))
			draw_dashed_line(a0, a0 + Vector2(mx, my), c, 1.0, 3.0)
	# the autopilot's call-outs
	var st: StormModel = m.storm
	if st.evading > 0.0:
		var dl: int = st.last_evade[0]
		var du: int = st.last_evade[1]
		if dl != 0 or du != 0:
			last_dir = [dl, du]
			dir_t = t
	if t - dir_t < 0.9:
		var dl2: int = last_dir[0]
		var du2: int = last_dir[1]
		var f := int(t * 6.0) % 2
		var cc := A if f == 1 else R
		var msg := ("< " if dl2 < 0 else "") + ("CLIMB" if du2 > 0 else ("DESCEND" if du2 < 0 else "BREAK")) + (" >" if dl2 > 0 else "")
		T("A/P EVADE  " + msg, cx, cy + 62, 1, cc, "c")
		if dl2 < 0:
			tri(cx - 170, cy + 69, 7, 3, cc)
		if dl2 > 0:
			tri(cx + 170, cy + 69, 7, 1, cc)
		if du2 > 0:
			tri(cx, cy + 46, 7, 0, cc)
		if du2 < 0:
			tri(cx, cy + 96, 7, 2, cc)


func _range(m: FlightModel, d: Dictionary) -> float:
	return (d["p"] as Vector3).distance_to(m.pos)


func _bearing(m: FlightModel, d: Dictionary) -> float:
	var r := Vector3(cos(m.psi), 0, sin(m.psi))
	var rel: Vector3 = d["p"] - m.pos
	return rel.x * r.x + rel.z * r.z


# ------------------------------------------------------------------ alerts
func _alerts(m: FlightModel, cx: float, cy: float, t: float) -> void:
	var deb: Array = m.storm.deb
	var w = null
	for d in deb:
		if d["dead"] or d["tcpa"] < 0.0:
			continue
		if d["n"] < 1.1 and d["tcpa"] < 5.0:
			thr[d["id"]] = {"t": t, "kind": d["kind"]}
		if d["a"] > 0.0 and d["n"] < 0.75 and d["tcpa"] < 2.2 and (w == null or d["tcpa"] < w["tcpa"]):
			w = d
	for id in thr.keys():
		var found = null
		for q in deb:
			if q["id"] == id:
				found = q
		if found == null or found["dead"]:
			if found != null and found["dead"]:
				thr.erase(id)
				continue
			if t - hit_t > 0.6 and t - float(thr[id]["t"]) < 1.5:
				av_msg = "AVOIDED  T%02d %s" % [int(id) % 100, str(thr[id]["kind"]).to_upper()]
				av_t = t
			thr.erase(id)
	var y := cy - 92.0
	# pyramids: the ray along the velocity vector against the south face
	var py = null
	var g := m.gamma
	var vd := Vector3(sin(m.psi) * cos(g), sin(g), -cos(m.psi) * cos(g))
	var pyrs: Array = [{"name": WorldData.PYR_NAME, "x": WorldData.PYR_X, "z": WorldData.PYR_Z, "half": WorldData.PYR_HALF, "h": WorldData.PYR_H, "base": WorldData.PYR_BASE}]
	pyrs.append_array(WorldData.OTHER_PYRS)
	for P in pyrs:
		if P["half"] < 90.0:
			continue
		var sl: float = float(P["h"]) / float(P["half"])
		var den := vd.y + sl * vd.z
		if den >= 0.0:
			continue
		var s: float = (float(P["base"]) + sl * (float(P["half"]) - (m.pos.z - float(P["z"]))) - m.pos.y) / den
		if not (s > 0.0):
			continue
		var hp := m.pos + vd * s
		if absf(hp.x - float(P["x"])) > float(P["half"]) or hp.y < float(P["base"]) or hp.y > float(P["base"]) + float(P["h"]):
			continue
		var tti := s / maxf(m.V, 20.0)
		if tti < 22.0 and (py == null or tti < py["tti"]):
			py = {"name": P["name"], "tti": tti, "s": s, "p": hp}
	var fin_go: bool = fin_tgt and (ui.fin_siren or ui.fin_state == "cine")
	if fin_tgt and not fin_go:
		py = null
	if py == null and fin_go:
		var s0 := Vector2(WorldData.THR_X - m.pos.x, WorldData.THR_Z - m.pos.z).length()
		py = {"name": "MASTER KING", "tti": s0 / maxf(m.V, 20.0), "s": s0, "p": Vector3(WorldData.THR_X, WorldData.PYR_BASE + 70.0, WorldData.THR_Z)}
	if py != null:
		var brace: bool = py["tti"] < 8.0
		var f := int(t * (9.0 if brace else 5.0)) % 2
		var col := R if f == 1 else A
		if t > bt:
			bt = t + (0.3 if brace else 0.55)
			Sfx.play("warn", -6.0, 1.2 if brace else 1.0)
		var q := proj(py["p"])
		if not q["behind"] and q["x"] > 330.0 and q["x"] < 1270.0 and q["y"] > WIN_Y0 + 70.0 and q["y"] < WIN_Y1 - 50.0:
			var sz := clampf(2600.0 / maxf(py["s"], 40.0), 14.0, 110.0)
			brk(q["x"], q["y"], sz, col, 1.0)
			T(str(py["name"]), q["x"], q["y"] + sz + 8.0, 1, col, "c")
			T("%d M" % roundi(py["s"]), q["x"], q["y"] + sz + 26.0, 1, col, "c")
		box(308, WIN_Y0 + 66, 984, HH - 80.0, col)
		_alert_box(cx, y, brace, f, col)
		T("IMPACT IMMINENT", cx, y + 2, 3, col, "c")
		T("%s  %.1fS" % [str(py["name"]), py["tti"]], cx, y + 32, 1, A, "c")
		if brace:
			T(">> BRACE BRACE <<", cx, y + 54, 1, Color.WHITE if f == 1 else R, "c")
		return
	if w != null:
		var brace2: bool = w["tcpa"] < 1.2
		var f2 := int(t * (9.0 if brace2 else 5.0)) % 2
		if t > bt:
			bt = t + (0.3 if brace2 else 0.55)
			Sfx.play("warn", -6.0, 1.2 if brace2 else 1.0)
		var col2 := R if f2 == 1 else A
		box(308, WIN_Y0 + 66, 984, HH - 80.0, col2)
		_alert_box(cx, y, brace2, f2, col2)
		T("IMPACT IMMINENT", cx, y + 2, 3, col2, "c")
		T("T%02d %s  %.1fS" % [int(w["id"]) % 100, str(w["kind"]).to_upper(), w["tcpa"]], cx, y + 32, 1, A, "c")
		if brace2:
			T(">> BRACE BRACE <<", cx, y + 54, 1, Color.WHITE if f2 == 1 else R, "c")
		return
	if t - hit_t < 2.2:
		if int(t * 10.0) % 2 == 1:
			draw_rect(Rect2(_o(Vector2(cx - 210, y - 4)), Vector2(420, 34)), Color(0.43, 0, 0, 0.55))
			box(cx - 210, y - 4, 420, 34, R)
			T("*** " + hit_msg + " ***", cx, y + 4, 2, R, "c")
		return
	if t - av_t < 1.8:
		if int(t * 6.0) % 2 == 1 or t - av_t < 0.5:
			box(cx - 190, y - 4, 380, 26, G)
			T(av_msg, cx, y + 2, 1, G, "c")


func _alert_box(cx: float, y: float, brace: bool, f: int, col: Color) -> void:
	var h := 86.0 if brace else 62.0
	draw_rect(Rect2(_o(Vector2(cx - 250, y - 6)), Vector2(500, h)), Color(0.43, 0, 0, 0.5) if f == 1 else Color(0.24, 0.08, 0, 0.4))
	box(cx - 250, y - 6, 500, h, col)


# ------------------------------------------------------------------ power-up self test
func _boot(bt_: float) -> void:
	var cx := 800.0
	var cy := WIN_Y0 + 176.0
	var x0 := 380.0
	var t := ui.t
	var tw := 2.0
	var per := 0.27
	var items: Array = [["ROM CHECKSUM", "4F2A"], ["RAM PATTERN TEST", ""], ["SYMBOL GENERATOR", ""], ["DEFLECTION AMP X/Y", ""],
		["HIGH VOLTAGE PSU", "14.2KV"], ["ADC INTERFACE", ""], ["IRS INTERFACE", ""], ["FMC DATA BUS", ""], ["TGT RADAR PROC", ""], ["RADAR ALTIMETER", ""]]
	var tb := tw + items.size() * per + 0.3
	var tp := tb + 1.0
	if bt_ < tw:
		var k := clampf(bt_ / 0.55, 0.0, 1.0)
		var w := 500.0 * k
		L(G, cx - w, cy, cx + w, cy)
		if bt_ > 0.45:
			T("HUD-80  HEAD UP DISPLAY", cx, cy - 62, 1, G, "c")
			T("P/N 80-1984-3  SW 80.4.1", cx, cy - 38, 1, D, "c")
			var f := clampf((bt_ - 0.5) / (tw - 0.6), 0.0, 1.0)
			T("TUBE WARM-UP", x0 + 20, cy + 30, 1, A, "l")
			T("%d%%" % roundi(f * 100.0), cx + 400, cy + 30, 1, A, "r")
			box(x0 + 20, cy + 56, 760, 14, A)
			draw_rect(Rect2(_o(Vector2(x0 + 23, cy + 59)), Vector2(754.0 * f, 8)), A)
	elif bt_ < tb:
		var t0 := bt_ - tw
		T("BUILT-IN TEST", x0, WIN_Y0 + 70, 1, A, "l")
		T("HUD-80", x0 + 780, WIN_Y0 + 70, 1, D, "r")
		L(A, x0, WIN_Y0 + 88, x0 + 780, WIN_Y0 + 88)
		for i in items.size():
			var ts := i * per
			if t0 < ts:
				break
			var done := t0 > ts + 0.22
			var y := WIN_Y0 + 98 + i * 16
			T(items[i][0], x0, y, 1, G if done else D, "l")
			var dots := ".".repeat(1 + int(fmod(t0 * 9.0, 4.0)))
			T((items[i][1] + "  OK" if items[i][1] != "" else "OK") if done else dots, x0 + 780, y, 1, G if done else A, "r")
		var f2 := clampf(t0 / (items.size() * per + 0.1), 0.0, 1.0)
		T("BIT %d%%" % roundi(f2 * 100.0), x0, WIN_Y0 + 272, 1, A, "l")
		box(x0 + 110, WIN_Y0 + 272, 500, 14, A)
		draw_rect(Rect2(_o(Vector2(x0 + 113, WIN_Y0 + 275)), Vector2(494.0 * f2, 8)), A)
		if f2 >= 1.0 and int(t * 4.0) % 2 == 1:
			T("BIT PASS", x0 + 780, WIN_Y0 + 272, 1, G, "r")
	elif bt_ < tp:
		var f3 := bt_ - tb
		var x1 := 330.0
		var x2 := 1270.0
		var y1 := WIN_Y0 + 70.0
		var y2 := WIN_Y1 - 44.0
		box(x1, y1, x2 - x1, y2 - y1, G)
		var gx := x1 + 94.0
		while gx < x2:
			L(D, gx, y1, gx, y2)
			gx += 94.0
		var gy := y1 + 44.0
		while gy < y2:
			L(D, x1, gy, x2, gy)
			gy += 44.0
		L(G, cx, y1, cx, y2)
		L(G, x1, (y1 + y2) / 2.0, x2, (y1 + y2) / 2.0)
		ring(cx, (y1 + y2) / 2.0, 120, G, 1.5)
		ring(cx, (y1 + y2) / 2.0, 60, G, 1.2)
		for q in [[x1, y1], [x2, y1], [x1, y2], [x2, y2]]:
			ring(q[0], q[1], 9, A, 1.5)
		T("SYMBOL TEST  8888888", cx, y1 + 14, 1, A, "c")
		T("ALL SEGMENTS LIT", cx, y1 + 36, 1, A, "c")
		var sy := y1 + fmod(f3 * 1.4, 1.0) * (y2 - y1)
		L(G, x1, sy, x2, sy)
		L(G, x1, sy + 3, x2, sy + 3)
