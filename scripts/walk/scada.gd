extends Control
## The plant SCADA ("albion nros - naicol reactor operating system"): one 1024x576 canvas shown at 1.5x,
## nine tabs with clickable / draggable controls. Port of NCUI of the HTML game.

signal closed

const FONT := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const BG := Color("#05055a")
const BG2 := Color("#0a0a78")
const PAN := Color("#10108a")
const LN := Color("#4a4aa8")
const TX := Color("#d6d2d4")
const DIM := Color("#8e8ab8")
const AM := Color("#ffd36a")
const GR := Color("#58f08a")
const RD := Color("#ff5a4a")
const CY := Color("#7fd8ff")
const WH := Color.WHITE
const W := 1024.0
const H := 576.0

const TABS: Array = [["over", "overview"], ["u1", "unit 1"], ["u2", "unit 2"], ["cool", "cooling"], ["grid", "grid"], ["alarm", "alarms"], ["trend", "trends"], ["rad", "radiation"], ["log", "event log"]]

var reactor: ReactorModel
var tab := "over"
var hits: Array = []       # {x,y,w,h,fn,drag}
var drag = null
var mp = null
var hover = null
var toast := ""
var toast_t := 0.0
var oy := 0.0
var wind_dx := 0.0
var wind_dz := -1.0


func _ready() -> void:
	visible = false
	scale = Vector2(1.5, 1.5)
	position = Vector2(32, 18)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(r: ReactorModel) -> void:
	reactor = r
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	drag = null
	closed.emit()


func say(s: String) -> void:
	toast = s
	toast_t = 3.0


func _process(dt: float) -> void:
	if visible and reactor != null:
		toast_t -= dt
		queue_redraw()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE or k.physical_keycode == KEY_E:
			close()
		elif k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
			tab = TABS[k.physical_keycode - KEY_1][0]
		elif k.physical_keycode == KEY_A and k.shift_pressed:
			reactor.ack_all()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p: Vector2 = event.position
			for h in hits:
				if p.x >= h["x"] and p.x <= h["x"] + h["w"] and p.y >= h["y"] and p.y <= h["y"] + h["h"]:
					if h.get("drag", false):
						drag = h
					(h["fn"] as Callable).call((p.x - h["x"]) / h["w"])
					break
		else:
			drag = null
	elif event is InputEventMouseMotion:
		mp = event.position
		if drag != null:
			var p2: Vector2 = event.position
			(drag["fn"] as Callable).call(clampf((p2.x - drag["x"]) / drag["w"], 0.0, 1.0))


# ------------------------------------------------------------------ canvas helpers
func nf(v, d := 0) -> String:
	if v == null:
		return "--"
	return ("%." + str(d) + "f") % float(v)


func fr(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(x, y + oy, w, h), col)


func sr(x: float, y: float, w: float, h: float, col: Color, lw := 1.0) -> void:
	draw_rect(Rect2(x + 0.5, y + oy + 0.5, w - 1.0, h - 1.0), col, false, lw)


func ln(x1: float, y1: float, x2: float, y2: float, col: Color, lw := 1.0) -> void:
	draw_line(Vector2(x1, y1 + oy), Vector2(x2, y2 + oy), col, lw)


func circ(x: float, y: float, r: float, col: Color, fill := true, lw := 1.0) -> void:
	if fill:
		draw_circle(Vector2(x, y + oy), r, col)
	else:
		draw_arc(Vector2(x, y + oy), r, 0.0, TAU, 32, col, lw)


func poly(pts: Array, fill: Color, stroke: Color) -> void:
	var pv := PackedVector2Array()
	for p in pts:
		pv.append(Vector2(p[0], p[1] + oy))
	draw_colored_polygon(pv, fill)
	pv.append(pv[0])
	draw_polyline(pv, stroke, 1.0)


func ntx(s: String, x: float, y: float, col: Color, sz := 10.0, al := "left", maxw := 0.0) -> void:
	var fs := sz
	if maxw > 0.0:
		var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
		if w > maxw:
			fs = maxf(6.0, floorf(fs * maxf(0.72, maxw / w) * 2.0) / 2.0)
			while s.length() > 2 and FONT.get_string_size(s + "..", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x > maxw:
				s = s.left(s.length() - 1)
			if FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x > maxw:
				s += ".."
	var w2 := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
	var px := x
	if al == "center":
		px = x - w2 / 2.0
	elif al == "right":
		px = x - w2
	draw_string(FONT, Vector2(px, y + oy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), col)


func nbar(x: float, y: float, w: float, h: float, v: float, col := GR, bg := Color("#000040")) -> void:
	fr(x, y, w, h, bg)
	fr(x, y, maxf(0.0, minf(1.0, v)) * w, h, col)
	sr(x, y, w, h, LN)


func nline(pts: Array, x: float, y: float, w: float, h: float, mn: float, mx: float, col: Color) -> void:
	if pts.size() < 2:
		return
	var pv := PackedVector2Array()
	for i in pts.size():
		var px := x + float(i) / (pts.size() - 1) * w
		var py := y + h - (float(pts[i]) - mn) / (mx - mn if mx != mn else 1.0) * h
		pv.append(Vector2(px, clampf(py, y, y + h) + oy))
	draw_polyline(pv, col, 1.0)


func panel(x: float, y: float, w: float, h: float, t: String) -> void:
	fr(x, y, w, h, BG2)
	sr(x, y, w, h, LN)
	fr(x + 1, y + 1, w - 2, 14, PAN)
	ntx(t, x + 5, y + 12, AM, 10)


func nbtn(x: float, y: float, w: float, h: float, label: String, col: Color, fn: Callable, on := false) -> void:
	fr(x, y, w, h, col if on else PAN)
	sr(x, y, w, h, col)
	ntx(label, x + w / 2.0, y + h / 2.0 + 4.0, Color.BLACK if on else col, 10, "center", w - 6.0)
	hits.append({"x": x, "y": y + oy, "w": w, "h": h, "fn": fn})


func slider(x: float, y: float, w: float, h: float, v: float, mn: float, mx: float, col: Color, label: String, fn: Callable, fmt: String) -> void:
	ntx(label, x, y - 3.0, DIM, 9, "left", w)
	fr(x, y, w, h, Color("#000040"))
	var f := (v - mn) / (mx - mn)
	fr(x, y, w * clampf(f, 0.0, 1.0), h, col)
	sr(x, y, w, h, LN)
	ntx(fmt, x + w + 6.0, y + h - 2.0, TX, 10)
	hits.append({"x": x, "y": y + oy, "w": w, "h": h, "drag": true, "fn": func(fx): fn.call(mn + fx * (mx - mn))})


func col_state(u: Dictionary) -> Color:
	return RD if u["scram"] else (GR if u["state"] == "online" else AM)


# ------------------------------------------------------------------ main draw
func _draw() -> void:
	if reactor == null:
		return
	var r := reactor
	hits.clear()
	oy = 0.0
	fr(0, 0, W, H, BG)
	fr(0, 0, W, 22, PAN)
	ntx("albion nros - naicol reactor operating system - scada   [esc] close  [1-9] tabs", 8, 15, AM, 12)
	ntx(r.clock_text(), W - 8, 15, TX, 12, "right")
	var alm := 0
	for a in r.alarms:
		if a["on"]:
			alm += 1
	var blink := int(r.t * 2.0) % 2 == 1
	ntx("alarms: %d" % alm if alm > 0 else "no alarms", W - 110, 15, (RD if blink else AM) if alm > 0 else GR, 12, "right")
	for i in TABS.size():
		var x := 6.0 + i * 112.0
		var on: bool = tab == TABS[i][0]
		fr(x, 28, 108, 20, AM if on else PAN)
		sr(x, 28, 108, 20, LN)
		ntx("%d %s" % [i + 1, TABS[i][1]], x + 54, 42, Color.BLACK if on else TX, 10, "center")
		var tn: String = TABS[i][0]
		hits.append({"x": x, "y": 28.0, "w": 108.0, "h": 20.0, "fn": func(_f): tab = tn})
	oy = 54.0
	match tab:
		"over":
			_p_over()
		"u1":
			_p_unit(r.units[0])
		"u2":
			_p_unit(r.units[1])
		"cool":
			_p_cool()
		"grid":
			_p_grid()
		"alarm":
			_p_alarm()
		"trend":
			_p_trend()
		"rad":
			_p_rad()
		"log":
			_p_log()
	oy = 0.0
	if toast_t > 0.0 and toast != "":
		fr(0, H - 22, W, 22, Color.BLACK)
		ntx(toast, 8, H - 7, AM, 11)
	hover = null
	if mp != null:
		for h in hits:
			if mp.x >= h["x"] and mp.x <= h["x"] + h["w"] and mp.y >= h["y"] and mp.y <= h["y"] + h["h"]:
				hover = h
				break
	if hover != null:
		draw_rect(Rect2(hover["x"] + 0.5, hover["y"] + 0.5, hover["w"] - 1.0, hover["h"] - 1.0), WH, false, 1.0)
	draw_rect(Rect2(0, 0, W, H), LN, false, 2.0)


# ------------------------------------------------------------------ overview
func _p_over() -> void:
	var r := reactor
	var U := r.units
	var G: Dictionary = r.grid
	for i in 2:
		var u: Dictionary = U[i]
		var x := 8.0 + i * 252.0
		panel(x, 6, 246, 238, "unit %d - %s" % [u["id"], u["state"]])
		ntx(nf(u["mwe"]), x + 8, 56, col_state(u), 34)
		ntx("mwe", x + 110, 56, DIM, 12)
		var rows: Array = [["reactor power", nf(r.power_of(u) * 100.0, 1) + " %"], ["hot leg", nf(u["thot"], 1) + " c"], ["cold leg", nf(u["tcold"], 1) + " c"],
			["pressure", nf(u["pz"], 1) + " bar"], ["turbine", nf(u["rpm"]) + " rpm"], ["breaker", "closed" if u["brk"] else "open"],
			["tower basin", nf(r.tw[i * 2]["tc"], 1) + " c"], ["containment", nf(r.rad["cont"][i], 0) + " usv/h"]]
		for j in rows.size():
			ntx(rows[j][0], x + 8, 84 + j * 18, DIM, 11)
			ntx(rows[j][1], x + 238, 84 + j * 18, TX, 11, "right")
		nbar(x + 8, 226, 230, 8, r.power_of(u), col_state(u))
		var tn := "u%d" % u["id"]
		nbtn(x + 160, 22, 78, 18, "open panel", CY, func(_f): tab = tn)
	panel(512, 6, 246, 238, "grid")
	ntx(nf(G["f"], 2), 520, 52, RD if absf(G["f"] - 50.0) > 0.2 else GR, 28)
	ntx("hz", 620, 52, DIM, 12)
	var gr: Array = [["supply", nf(G["sup"]) + " mw"], ["demand", nf(G["dem"]) + " mw"], ["export", nf(G["exp"]) + " mw"], ["capacity", nf(G["cap"]) + " mw"], ["voltage", nf(G["v"]) + " kv"]]
	for j in gr.size():
		ntx(gr[j][0], 520, 84 + j * 18, DIM, 11)
		ntx(gr[j][1], 750, 84 + j * 18, TX, 11, "right")
	for i in 4:
		var bi := i
		nbtn(520 + i * 58, 186, 52, 20, "bay " + "abcd"[i], GR if r.bays[i] else RD, func(_f): r.toggle_bay(bi), r.bays[i] == 1)
	panel(766, 6, 250, 238, "weather + site")
	var Wx: Dictionary = r.wx
	var wr: Array = [["air", nf(Wx["t"], 1) + " c"], ["humidity", nf(Wx["rh"]) + " %"], ["wind", nf(Wx["ws"], 1) + " m/s"], ["pressure", nf(Wx["press"]) + " hpa"],
		["site dose", nf(r.rad["site"], 3) + " usv/h"], ["stack", nf(r.rad["stack"], 4) + " bq/m3"], ["gate", nf(r.rad["gate"], 3) + " usv/h"]]
	for j in wr.size():
		ntx(wr[j][0], 774, 34 + j * 18, DIM, 11)
		ntx(wr[j][1], 1008, 34 + j * 18, TX, 11, "right")
	ntx("all readings within limits", 774, 176, GR, 11)
	panel(8, 252, 500, 268, "trend: power (green) and export (amber)")
	var Hs: Array = r.hist.slice(maxi(0, r.hist.size() - 200))
	fr(14, 274, 488, 240, Color("#000040"))
	for i in range(1, 5):
		ln(14, 274 + i * 48, 502, 274 + i * 48, Color("#1a1a70"))
	nline(Hs.map(func(q): return q["p1"]), 14, 274, 488, 240, 0, 120, GR)
	nline(Hs.map(func(q): return q["p2"]), 14, 274, 488, 240, 0, 120, Color("#88ffcc"))
	nline(Hs.map(func(q): return q["s"]), 14, 274, 488, 240, 0, 3200, AM)
	panel(516, 252, 500, 268, "active alarms + latest events")
	var A: Array = r.alarms.slice(0, 8)
	if A.is_empty():
		ntx("no active alarms", 524, 290, GR, 12)
	for j in A.size():
		var a: Dictionary = A[j]
		ntx(str(a["t"]).left(5) + " " + str(a["m"]), 524, 288 + j * 14, (RD if a["s"] >= 3 else AM) if a["on"] else DIM, 10, "left", 484)
	var lg: Array = r.log_lines.slice(0, 6)
	for j in lg.size():
		ntx(str(lg[j]["t"]).left(5) + " " + str(lg[j]["m"]), 524, 420 + j * 14, DIM, 10, "left", 366)
	nbtn(900, 480, 108, 22, "acknowledge all", AM, func(_f): r.ack_all())


# ------------------------------------------------------------------ unit panel
func _p_unit(u: Dictionary) -> void:
	var r := reactor
	var i: int = u["id"] - 1
	var P := r.power_of(u)
	panel(6, 6, 640, 514, "unit %d - primary + secondary circuit" % u["id"])
	var vx := 40.0
	var vy := 60.0
	fr(vx, vy, 70, 150, Color("#1a1a6a"))
	sr(vx, vy, 70, 150, RD if u["scram"] else CY, 2.0)
	for k in 3:
		var rx := vx + 10.0 + k * 20.0
		var len: float = u["rods"][k] / 100.0 * 110.0
		fr(rx, vy + 8, 8, len, Color("#d0d0d0"))
		fr(rx, vy + 8 + len - 3, 8, 3, AM)
	fr(vx + 4, vy + 120, 62, 26, Color(1.0, (120.0 + P * 100.0) / 255.0, 40.0 / 255.0, 0.2 + P * 0.6))
	ntx("reactor", vx, vy + 168, DIM, 10)
	ntx(nf(P * 100.0, 1) + "%", vx, vy + 184, col_state(u), 16)
	fr(vx + 86, vy - 24, 28, 56, Color("#1a1a6a"))
	sr(vx + 86, vy - 24, 28, 56, CY)
	fr(vx + 88, vy + 2, 24, minf(28.0, u["pzL"] / 57.0 * 28.0), Color("#2a6aa8"))
	ntx("pzr", vx + 88, vy - 28, DIM, 9)
	ntx(nf(u["pz"], 1) + " bar", vx + 118, vy, TX, 10)
	var sgx := 240.0
	fr(sgx, vy - 10, 60, 170, Color("#1a1a6a"))
	sr(sgx, vy - 10, 60, 170, CY)
	fr(sgx + 2, vy + 160 - u["sgl"] * 0.9, 56, u["sgl"] * 0.9 - 2.0, Color("#2a6aa8"))
	ntx("steam gen", sgx, vy - 16, DIM, 10)
	ntx("level " + nf(u["sgl"]) + "%", sgx + 4, vy + 176, TX, 10)
	ntx(nf(u["sgp"], 1) + " bar", sgx + 4, vy + 190, TX, 10)
	for k in 3:
		var y := vy + 10.0 + k * 38.0
		ln(vx + 70, y, sgx, y, RD, 3.0)
		ln(sgx, y + 16, vx + 70, y + 16, CY, 3.0)
		var on: bool = u["pump"][k] == 1
		circ(vx + 150, y + 16, 11, GR if on else Color("#400000"))
		ntx("abc"[k], vx + 146, y + 20, Color.BLACK, 10)
		var kk := k
		hits.append({"x": vx + 139, "y": y + 5 + oy, "w": 22.0, "h": 22.0, "fn": func(_f): r.toggle_pump(u, kk)})
		ntx(nf(u["pumpN"][k] * 100.0) + "%", vx + 164, y + 29, DIM, 9)
	ntx("hot " + nf(u["thot"], 1) + " c", vx + 72, vy + 140, RD, 10)
	ntx("cold " + nf(u["tcold"], 1) + " c", vx + 72, vy + 154, CY, 10)
	# secondary circuit
	var ay := vy + 10.0
	var sp: float = u["rpm"] / 3000.0
	poly([[420, ay - 8], [462, ay - 16], [462, ay + 16], [420, ay + 8]], Color("#2a2a8a"), CY)
	poly([[468, ay - 16], [522, ay - 30], [522, ay + 30], [468, ay + 16]], Color("#2a2a8a"), CY)
	for k in 5:
		var ph := fmod(r.t * sp * 1.4 + k / 5.0, 1.0)
		var x := 424.0 + ph * 94.0
		var hh := 8.0 + ((x - 420.0) / 42.0) * 8.0 if x < 465.0 else 16.0 + ((x - 468.0) / 54.0) * 14.0
		ln(x, ay - hh + 2.0, x, ay + hh - 2.0, AM)
	ln(sgx + 60, ay, 420, ay, TX, 3.0)
	ln(495, ay + 30, 495, ay + 40, TX, 3.0)
	poly([[490, ay + 38], [500, ay + 38], [495, ay + 45]], TX, TX)
	ln(522, ay, 548, ay, LN, 3.0)
	ntx("turbine", 420, ay - 36, DIM, 10)
	var ang: float = r.t * u["rpm"] / 300.0
	circ(560, ay, 12, LN, false)
	ln(560, ay, 560 + cos(ang) * 10.0, ay + sin(ang) * 10.0, AM)
	ntx("gen", 548, ay + 26, DIM, 10)
	ntx(nf(u["rpm"]) + " rpm", 420, vy + 46, GR if u["rpm"] > 2900.0 else AM, 12)
	ntx(nf(u["mwe"]) + " mwe", 420, vy + 62, TX, 12)
	ntx("breaker closed" if u["brk"] else "breaker open", 420, vy + 78, GR if u["brk"] else RD, 10)
	ntx("vacuum " + nf(u["vac"], 3), 420, vy + 92, TX, 10)
	ntx("steam %s c  vib %s" % [nf(u["turbT"]), nf(u["vib"], 1)], 420, vy + 106, TX, 10)
	ntx("generator %s kv %s a" % [nf(u["gen"]["v"], 1), nf(u["gen"]["a"])], 420, vy + 120, TX, 10)
	ntx("feedwater %s kg/s" % nf(u["feed"] * 1000.0), 420, vy + 134, TX, 10)
	var tw: Dictionary = r.tw[i * 2]
	ntx("cooling: basin %s c  flow %s m3/s  plume %s%%" % [nf(tw["tc"], 1), nf(tw["flow"], 1), nf(tw["plume"] * 100.0)], 20, 300, CY, 11)
	var g: Array = [["neutron flux", u["flux"], 0, 120, "%"], ["fuel temp", u["fuelT"], 300, 1200, "c"], ["hot leg", u["thot"], 280, 350, "c"],
		["pressure", u["pz"], 130, 170, "bar"], ["sg level", u["sgl"], 0, 100, "%"], ["xenon", u["xe"] * 100.0, 0, 90, "%"]]
	for j in g.size():
		var q: Array = g[j]
		var x2 := 20.0 + (j % 3) * 206.0
		var y2 := 330.0 + (j / 3) * 52.0
		ntx(q[0], x2, y2, DIM, 10, "left", 190)
		nbar(x2, y2 + 4, 136, 10, (q[1] - q[2]) / float(q[3] - q[2]), RD if q[1] > q[3] * 0.97 else GR)
		ntx(nf(q[1], 1) + q[4], x2 + 140, y2 + 13, TX, 10, "left", 62)
	var Hs: Array = r.hist.slice(maxi(0, r.hist.size() - 150))
	nline(Hs.map(func(q): return q["p2"] if i == 1 else q["p1"]), 20, 444, 610, 60, 0, 120, GR)
	nline(Hs.map(func(q): return q["h2"] if i == 1 else q["h1"]), 20, 444, 610, 60, 280, 350, RD)
	ntx("power / hot leg (last 150 s)", 22, 438, DIM, 9)
	# controls
	panel(652, 6, 364, 514, "operator controls")
	nbtn(662, 26, 344, 40, "scram reactor", RD, func(_f): r.scram(u, "manual scram"), u["scram"])
	nbtn(662, 72, 168, 22, "reset scram", AM, func(_f):
		if not r.reset_scram(u):
			say("cannot reset: rods must be fully inserted and power below 2%"))
	nbtn(838, 72, 168, 22, "auto startup", GR, func(_f):
		if not r.auto_start(u):
			say("startup refused: reset scram first"), u["auto"])
	var ready: bool = not u["scram"]
	for k in 3:
		var kk2 := k
		slider(662, 126 + k * 34, 240, 12, u["rodT"][k], 0, 100, CY if ready else DIM, "control rod %s (withdrawn %%)" % ["bank a", "bank b", "bank c"][k], func(v): r.set_rod(u, kk2, v), nf(u["rods"][k]) + "%")
	nbtn(662, 224, 110, 18, "all rods in", AM, func(_f):
		for k in 3:
			r.set_rod(u, k, 0.0))
	nbtn(780, 224, 110, 18, "all rods out", AM, func(_f):
		for k in 3:
			r.set_rod(u, k, 78.0))
	slider(662, 264, 240, 12, u["boron"], 0, 1800, AM, "boric acid (ppm)", func(v): r.set_boron(u, v), nf(u["boron"]))
	ntx("turbine", 662, 304, AM, 11)
	nbtn(662, 310, 110, 22, "trip turbine", RD, func(_f): r.turb_trip(u, true), u["brk"] == 0)
	nbtn(780, 310, 110, 22, "sync to grid", GR, func(_f): r.turb_trip(u, false), u["brk"] == 1)
	slider(662, 360, 240, 12, u["valve"], 0, 1, CY, "steam valve", func(v):
		if not u["scram"]:
			u["valve"] = v, nf(u["valve"] * 100.0) + "%")
	ntx("coolant pumps: click a,b,c on the diagram", 662, 404, DIM, 10)
	ntx("protection trips:", 662, 428, DIM, 10)
	ntx("flux>109%  hot leg>342c  flow<34%", 662, 442, TX, 9)
	ntx("pzr 134-166 bar  sg level<18%", 662, 454, TX, 9)
	ntx(("trip cause: " + str(u["trip"])) if u["scram"] else "protection system armed", 662, 478, RD if u["scram"] else GR, 10)
	ntx("decay heat " + nf(u["decay"] * 100.0, 2) + " %", 662, 494, TX, 10)


# ------------------------------------------------------------------ cooling
func _p_cool() -> void:
	var r := reactor
	for i in 4:
		var t: Dictionary = r.tw[i]
		var x := 8.0 + (i % 2) * 504.0
		var y := 6.0 + (i / 2) * 180.0
		panel(x, y, 498, 174, "cooling cell %s%s (unit %d)" % ["1" if i < 2 else "2", "ab"[i % 2], t["unit"] + 1])
		var rows: Array = [["basin temp", nf(t["tc"], 1) + " c"], ["flow", nf(t["flow"], 1) + " m3/s"], ["heat load", nf(t["q"]) + " mw"],
			["make-up", nf(t["make"], 2) + " m3/s"], ["plume", nf(t["plume"] * 100.0) + "%"], ["conductivity", nf(t["cond"], 1) + " us"]]
		for j in rows.size():
			ntx(rows[j][0], x + 8, y + 34 + j * 18, DIM, 11)
			ntx(rows[j][1], x + 190, y + 34 + j * 18, RD if (t["tc"] > 34.0 and j == 0) else TX, 11, "right")
		fr(x + 210, y + 24, 280, 146, Color("#000040"))
		for k in 3:
			var kk := k
			slider(x + 224, y + 44 + k * 30, 170, 10, t["fans"][k], 0, 1, CY, "fan " + "123"[k], func(v): r.set_fan(t, kk, v), nf(t["fanN"][k] * 100.0) + "%")
		nbtn(x + 224, y + 142, 120, 18, "pump " + ("on" if t["pumpOn"] else "off"), GR if t["pumpOn"] else RD, func(_f):
			t["pumpOn"] = 0 if t["pumpOn"] else 1
			r.log_event("cooling cell %d circulating pump %s" % [t["id"] + 1, "start" if t["pumpOn"] else "stop"], 1), t["pumpOn"] == 1)
	panel(8, 370, 1008, 150, "cooling water + weather")
	var Wx: Dictionary = r.wx
	ntx("ambient %s c   humidity %s%%   wind %s m/s" % [nf(Wx["t"], 1), nf(Wx["rh"]), nf(Wx["ws"], 1)], 16, 396, TX, 12)
	ntx("plume drift: %s , %s" % [nf(r.wind.x, 2), nf(r.wind.z, 2)], 16, 414, DIM, 11)
	ntx("high basin temperature raises the condenser vacuum,", 16, 442, DIM, 10)
	ntx("which lowers turbine output. a tower that runs hot", 16, 455, DIM, 10)
	ntx("for long can force the reactor to trip.", 16, 468, DIM, 10)
	var Hs: Array = r.hist.slice(maxi(0, r.hist.size() - 200))
	nline(Hs.map(func(q): return q["tb"]), 500, 384, 500, 124, 20, 40, CY)
	ntx("basin temp, last 200 s", 504, 398, DIM, 9)


# ------------------------------------------------------------------ grid
func _p_grid() -> void:
	var r := reactor
	var G: Dictionary = r.grid
	panel(8, 6, 500, 250, "grid frequency + exchange")
	ntx(nf(G["f"], 3) + " hz", 20, 70, RD if absf(G["f"] - 50.0) > 0.2 else GR, 44)
	fr(20, 90, 470, 16, Color("#000040"))
	fr(20 + 235 - 4, 90, 8, 16, GR)
	var fx: float = 20.0 + 235.0 + (G["f"] - 50.0) / 0.5 * 235.0
	fr(maxf(20.0, minf(488.0, fx)) - 2.0, 86, 4, 24, WH)
	ntx("49.5", 20, 122, DIM, 9)
	ntx("50", 248, 122, DIM, 9)
	ntx("50.5", 470, 122, DIM, 9)
	var rows: Array = [["supply", nf(G["sup"]) + " mw"], ["demand", nf(G["dem"]) + " mw"], ["export", nf(G["exp"]) + " mw"],
		["export capacity", nf(G["cap"]) + " mw"], ["400 kv voltage", nf(G["v"], 1) + " kv"]]
	for j in rows.size():
		ntx(rows[j][0], 20, 148 + j * 20, DIM, 12)
		ntx(rows[j][1], 490, 148 + j * 20, TX, 12, "right")
	panel(516, 6, 500, 250, "switchyard bays")
	for i in 4:
		var x := 530.0 + i * 120.0
		var closed: bool = r.bays[i] == 1
		fr(x, 40, 108, 70, Color("#0a3a1a") if closed else Color("#4a0a0a"))
		sr(x, 40, 108, 70, GR if closed else RD)
		ntx("bay " + "abcd"[i], x + 8, 60, TX, 12)
		ntx("closed" if closed else "open", x + 8, 80, GR if closed else RD, 12)
		ntx("800 mw", x + 8, 98, DIM, 10)
		var bi := i
		nbtn(x, 120, 108, 22, "open bay" if closed else "close bay", RD if closed else GR, func(_f): r.toggle_bay(bi))
	ntx("opening bays lowers the export capacity.", 530, 190, DIM, 10, "left", 470)
	ntx("if units produce more than the capacity, the turbine valves close back.", 530, 203, DIM, 10, "left", 470)
	ntx("siren + public address", 530, 220, AM, 11)
	nbtn(530, 226, 130, 20, "test siren", AM, func(_f): r.drill_siren())
	panel(8, 264, 1008, 256, "supply (amber) vs demand (cyan), last 300 s")
	var Hs: Array = r.hist
	fr(16, 290, 992, 220, Color("#000040"))
	nline(Hs.map(func(q): return q["s"]), 16, 290, 992, 220, 0, 3200, AM)
	nline(Hs.map(func(q): return q["d"]), 16, 290, 992, 220, 0, 3200, CY)
	nline(Hs.map(func(q): return q["m1"]), 16, 290, 992, 220, 0, 3200, Color("#88ffcc"))
	nline(Hs.map(func(q): return q["m2"]), 16, 290, 992, 220, 0, 3200, Color("#ff9d9d"))


# ------------------------------------------------------------------ alarms / trends / radiation / log
func _p_alarm() -> void:
	var r := reactor
	panel(8, 6, 1008, 514, "alarm list")
	nbtn(880, 22, 130, 20, "acknowledge all", AM, func(_f): r.ack_all())
	var A: Array = r.alarms.slice(0, 30)
	if A.is_empty():
		ntx("no alarms", 20, 60, GR, 14)
	for j in A.size():
		var a: Dictionary = A[j]
		var col := RD if a["s"] >= 3 else (AM if a["s"] == 2 else CY)
		var blink: bool = a["on"] and not a["ack"] and int(r.t * 2.0) % 2 == 1
		fr(16, 50 + j * 15, 10, 10, col if blink else Color("#0a0a40"))
		ntx(a["t"], 34, 59 + j * 15, DIM, 10)
		ntx(a["m"], 110, 59 + j * 15, col if a["on"] else DIM, 10)
		ntx(("acknowledged" if a["ack"] else "active") if a["on"] else "cleared", 990, 59 + j * 15, DIM, 10, "right")


func _p_trend() -> void:
	var Hs: Array = reactor.hist
	var defs: Array = [["reactor power %", "p1", "p2", 0, 120], ["electrical output mwe", "m1", "m2", 0, 1200], ["hot leg c", "h1", "h2", 280, 350], ["basin temp c", "tb", "tb", 20, 40]]
	for i in 4:
		var q: Array = defs[i]
		var x := 8.0 + (i % 2) * 504.0
		var y := 6.0 + (i / 2) * 258.0
		panel(x, y, 498, 252, str(q[0]) + " (unit 1 green, unit 2 amber)")
		fr(x + 8, y + 24, 482, 218, Color("#000040"))
		for k in range(1, 5):
			ln(x + 8, y + 24 + k * 43.6, x + 490, y + 24 + k * 43.6, Color("#1a1a70"))
		var k1: String = q[1]
		var k2: String = q[2]
		nline(Hs.map(func(h): return h[k1]), x + 8, y + 24, 482, 218, q[3], q[4], GR)
		nline(Hs.map(func(h): return h[k2]), x + 8, y + 24, 482, 218, q[3], q[4], AM)
		ntx(str(q[4]), x + 12, y + 36, DIM, 9)
		ntx(str(q[3]), x + 12, y + 238, DIM, 9)


func _p_rad() -> void:
	var r := reactor
	var R: Dictionary = r.rad
	panel(8, 6, 1008, 514, "radiation monitoring (all values in micro-sieverts per hour unless stated)")
	var rows: Array = [["site boundary", R["site"], 0.3], ["main gate", R["gate"], 0.3], ["visitor centre", 0.07 + 0.004 * sin(r.t), 0.3], ["control room", 0.09, 0.5],
		["turbine hall 1", R["tur"][0], 2.0], ["turbine hall 2", R["tur"][1], 2.0], ["spent fuel pool hall", R["pool"], 20.0],
		["unit 1 containment (inside)", R["cont"][0], 1000.0], ["unit 2 containment (inside)", R["cont"][1], 1000.0], ["stack discharge (bq/m3)", R["stack"] * 1000.0, 5.0]]
	for j in rows.size():
		var q: Array = rows[j]
		var y := 40.0 + j * 42.0
		ntx(q[0], 20, y, TX, 12)
		nbar(300, y - 12, 500, 14, q[1] / q[2], RD if q[1] / q[2] > 0.8 else GR)
		ntx(nf(q[1], 3 if q[1] < 1.0 else 1), 820, y, TX, 12)
		ntx("limit " + str(q[2]), 930, y, DIM, 10)
	ntx("natural background on the plain is about 0.1 usv/h. a flight at cruise altitude is roughly 3.", 20, 490, DIM, 11)


func _p_log() -> void:
	panel(8, 6, 1008, 514, "event log")
	var lg: Array = reactor.log_lines.slice(0, 34)
	for j in lg.size():
		var l: Dictionary = lg[j]
		ntx(str(l["t"]) + "  " + str(l["m"]).left(120), 16, 36 + j * 14, RD if l["s"] >= 3 else (AM if l["s"] == 2 else TX), 10)
