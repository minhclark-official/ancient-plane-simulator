class_name NcScreen
extends Control
## One control-room / visitor-centre mini screen of the plant (port of ncDrawScreen).
## Rendered into a SubViewport whose texture is shown on the screen mesh.

const FONT := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const BG := Color("#05055a")
const PAN := Color("#10108a")
const LN := Color("#4a4aa8")
const TX := Color("#d6d2d4")
const DIM := Color("#8e8ab8")
const AM := Color("#ffd36a")
const GR := Color("#58f08a")
const RD := Color("#ff5a4a")
const CY := Color("#7fd8ff")
const WH := Color.WHITE

var kind := ""
var arg := 0
var reactor: ReactorModel
var wnd := Vector3(0, 0, -1)


func nf(v, d := 0) -> String:
	return ("%." + str(d) + "f") % float(v)


func fr(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, h), col)


func sr(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(x + 0.5, y + 0.5, w - 1.0, h - 1.0), col, false, 1.0)


func ln(x1: float, y1: float, x2: float, y2: float, col: Color) -> void:
	draw_line(Vector2(x1, y1), Vector2(x2, y2), col, 1.0)


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
	draw_string(FONT, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), col)


func nbar(x: float, y: float, w: float, h: float, v: float, col := GR) -> void:
	fr(x, y, w, h, Color("#000040"))
	fr(x, y, maxf(0.0, minf(1.0, v)) * w, h, col)
	sr(x, y, w, h, LN)


func nline(pts: Array, x: float, y: float, w: float, h: float, mn: float, mx: float, col: Color) -> void:
	if pts.size() < 2:
		return
	var pv := PackedVector2Array()
	for i in pts.size():
		var py := y + h - (float(pts[i]) - mn) / (mx - mn if mx != mn else 1.0) * h
		pv.append(Vector2(x + float(i) / (pts.size() - 1) * w, clampf(py, y, y + h)))
	draw_polyline(pv, col, 1.0)


## lay a list of [text, colour] rows into a rect (1-3 columns, font size chosen so that everything fits)
func rows(x: float, y: float, w: float, h: float, lst: Array, base := 10.0) -> void:
	var n := lst.size()
	if n == 0:
		return
	var mw := 0.0
	for r in lst:
		mw = maxf(mw, FONT.get_string_size(str(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x / 10.0)
	var best := {}
	for cols in range(1, 4):
		var per := ceili(float(n) / cols)
		var cw := w / cols - 4.0
		var sz := minf(base, minf(h / (per * 1.22), cw / mw))
		if best.is_empty() or sz > best["sz"] + 0.4:
			best = {"cols": cols, "per": per, "sz": sz, "cw": cw}
	var sz2 := maxf(6.0, floorf(best["sz"] * 2.0) / 2.0)
	var pitch := minf(sz2 * 1.3, h / best["per"])
	for i in n:
		var col := i / int(best["per"])
		var row := i % int(best["per"])
		ntx(str(lst[i][0]), x + col * (w / best["cols"]), y + sz2 + row * pitch, lst[i][1], sz2, "left", best["cw"])


func sc(u: Dictionary) -> Color:
	return RD if u["scram"] else (GR if u["state"] == "online" else AM)


func _draw() -> void:
	if reactor == null:
		return
	var r := reactor
	var w := size.x
	var h := size.y
	fr(0, 0, w, h, BG)
	var U := r.units
	var G: Dictionary = r.grid
	var hd := func(t: String):
		fr(0, 0, w, 13, PAN)
		ntx(t, 3, 10, AM, 9)
		ntx(r.clock_text(), w - 3, 10, TX, 9, "right")
	match kind:
		"visitor":
			hd.call("naicol reactor")
			ntx("welcome", w / 2, h * 0.45, WH, roundf(h * 0.16), "center")
			ntx(nf(r.total_mwe()) + " mw to the grid", w / 2, h * 0.72, GR, roundf(h * 0.12), "center")
		"visitorbig":
			hd.call("naicol reactor - live")
			rows(6, 16, w - 12, h - 18, [["unit 1  %s mw  reactor %s%%" % [nf(U[0]["mwe"]), nf(r.power_of(U[0]) * 100.0)], sc(U[0])],
				["unit 2  %s mw  reactor %s%%" % [nf(U[1]["mwe"]), nf(r.power_of(U[1]) * 100.0)], sc(U[1])],
				["to the grid: %s mw" % nf(G["exp"]), AM], ["grid frequency %s hz" % nf(G["f"], 2), TX],
				["site dose rate %s usv/h" % nf(r.rad["site"], 3), GR], ["weather %s c  %s m/s" % [nf(r.wx["t"], 1), nf(r.wx["ws"], 1)], TX],
				["plume: harmless", DIM], ["natural background 0.1", DIM]], 12.0)
		"mimic":
			fr(0, 0, w, 18, PAN)
			ntx("naicol reactor - site mimic", 8, 13, AM, 13)
			ntx(r.clock_text(), w - 8, 13, TX, 13, "right")
			for i in 2:
				var u: Dictionary = U[i]
				var x0 := 14.0 + i * (w / 2.0)
				var sw := w / 2.0 - 30.0
				var y := 46.0
				ntx("unit %d  %s" % [i + 1, u["state"]], x0, 40, sc(u), 14)
				var nodes: Array = [["reactor", nf(r.power_of(u) * 100.0) + "%", RD if u["scram"] else GR],
					["coolant", nf(u["thot"]) + "c", RD if u["thot"] > 335.0 else GR], ["sg", nf(u["sgp"], 1) + "bar", GR],
					["turbine", nf(u["rpm"]) + "rpm", GR if u["rpm"] > 2900.0 else AM], ["gen", nf(u["mwe"]) + "mw", GR if u["brk"] else RD],
					["tower", nf(r.tw[i * 2]["tc"], 1) + "c", CY]]
				for j in nodes.size():
					var n: Array = nodes[j]
					var x := x0 + j * (sw / 6.0)
					fr(x, y, sw / 6.0 - 14.0, 50, Color("#0a0a40"))
					sr(x, y, sw / 6.0 - 14.0, 50, n[2])
					ntx(n[0], x + 4, y + 14, DIM, 10)
					ntx(n[1], x + 4, y + 34, n[2], 14)
					if j < 5:
						ln(x + sw / 6.0 - 14.0, y + 25, x + sw / 6.0, y + 25, RD if n[2] == RD else CY)
				fr(x0, y + 58, sw, 12, Color("#0a0a40"))
				fr(x0, y + 58, sw * r.power_of(u), 12, sc(u))
			ln(w / 2, 24, w / 2, h - 20, LN)
			fr(0, h - 16, w, 16, PAN)
			ntx("grid %s mw  %s hz  %s kv" % [nf(G["exp"]), nf(G["f"], 2), nf(G["v"])], w / 2, h - 4, AM, 12, "center", w - 24)
		"alarms":
			hd.call("alarms")
			var A: Array = r.alarms.slice(0, int((h - 16) / 11))
			if A.is_empty():
				ntx("no active alarms", w / 2, h / 2, GR, 10, "center")
			for i in A.size():
				var a: Dictionary = A[i]
				var col := RD if a["s"] >= 3 else (AM if a["s"] == 2 else CY)
				var on: bool = a["on"] and (a["ack"] or int(r.t * 2.0) % 2 == 1)
				if on or not a["on"]:
					ntx(str(a["t"]).left(5) + " " + str(a["m"]).left(int(w / 5.4) - 6), 3, 24 + i * 11, col if a["on"] else DIM, 9)
		"grid":
			hd.call("grid")
			var fc := RD if absf(G["f"] - 50.0) > 0.2 else GR
			var bw := minf(w * 0.3, 64.0)
			rows(4, 16, w - bw - 10, h - 18, [["%s hz  %s kv" % [nf(G["f"], 2), nf(G["v"])], fc], ["supply " + nf(G["sup"]), TX], ["demand " + nf(G["dem"]), TX],
				["export %s/%s" % [nf(G["exp"]), nf(G["cap"])], AM]], 12.0)
			var lw := floorf((bw - 2.0) / 2.0)
			var lh := minf(14.0, floorf((h - 24.0) / 2.0))
			for i in 4:
				var lx := w - bw - 2.0 + (i % 2) * (lw + 2.0)
				var ly := 18.0 + (i / 2) * (lh + 3.0)
				fr(lx, ly, lw, lh, GR if r.bays[i] else RD)
				ntx("abcd"[i], lx + lw / 2.0, ly + lh - 3.0, Color.BLACK, minf(9.0, lh - 3.0), "center")
		"cool":
			hd.call("cooling")
			for i in r.tw.size():
				var t: Dictionary = r.tw[i]
				var y := 24.0 + i * floorf((h - 26.0) / 4.0)
				ntx("cell %s%s" % ["1" if i < 2 else "2", "ab"[i % 2]], 4, y + 8, CY, 9)
				ntx(nf(t["tc"], 1) + " c", w * 0.4, y + 8, RD if t["tc"] > 34.0 else TX, 9)
				nbar(w * 0.62, y, w * 0.34, 8, t["plume"], CY)
		"wx":
			hd.call("weather")
			var Wx: Dictionary = r.wx
			ntx(nf(Wx["t"], 1) + " c", 6, 40, AM, 18)
			ntx("humidity " + nf(Wx["rh"]) + "%", 6, 58, TX, 10)
			ntx("wind " + nf(Wx["ws"], 1) + " m/s", 6, 70, TX, 10)
			ntx("pressure " + nf(Wx["press"]) + " hpa", 6, 82, TX, 10)
			draw_arc(Vector2(w - 34, h - 36), 22.0, 0.0, TAU, 24, CY, 1.0)
			ln(w - 34, h - 36, w - 34 + wnd.x * 20.0, h - 36 + wnd.z * 20.0, CY)
		"unit", "turb":
			var u: Dictionary = U[arg]
			hd.call(("turbine " if kind == "turb" else "unit ") + str(u["id"]))
			if kind == "unit":
				rows(4, 16, w - 8, h - 18, [["%s  power %s%%" % [u["state"], nf(u["pw"] * 100.0)], sc(u)], ["hot leg %s c" % nf(u["thot"], 1), RD if u["thot"] > 335.0 else TX],
					["pressure %s bar" % nf(u["pz"], 1), TX], ["rods %s %s %s" % [nf(u["rods"][0]), nf(u["rods"][1]), nf(u["rods"][2])], TX], ["boron %s ppm" % nf(u["boron"]), TX]], 11.0)
			else:
				rows(4, 16, w - 8, h - 18, [["%s rpm" % nf(u["rpm"]), GR if u["rpm"] > 2900.0 else AM], ["load %s mw" % nf(u["mwe"]), TX],
					["vibration %s mm/s" % nf(u["vib"], 1), RD if u["vib"] > 3.2 else TX], ["vacuum %s bar" % nf(u["vac"], 3), TX],
					["breaker " + ("closed" if u["brk"] else "open"), GR if u["brk"] else RD], ["steam %s c" % nf(u["turbT"]), TX]], 11.0)
		"trend":
			var ui := int(arg)
			hd.call("trend: unit %d" % (ui + 1))
			var Hs: Array = r.hist.slice(maxi(0, r.hist.size() - 120))
			nline(Hs.map(func(q): return q["p2"] if ui == 1 else q["p1"]), 4, 22, w - 8, (h - 30) / 2.0 - 4.0, 0, 110, GR)
			nline(Hs.map(func(q): return q["m2"] if ui == 1 else q["m1"]), 4, 22 + (h - 30) / 2.0, w - 8, (h - 30) / 2.0 - 4.0, 0, 1200, AM)
			ntx("power %", 5, 32, GR, 8)
			ntx("mwe", 5, 22 + (h - 30) / 2.0 + 10.0, AM, 8)
		"overview":
			hd.call("shift overview")
			ntx("unit 1 %s mw %s" % [nf(U[0]["mwe"]), U[0]["state"]], 4, 28, sc(U[0]), 9)
			ntx("unit 2 %s mw %s" % [nf(U[1]["mwe"]), U[1]["state"]], 4, 40, sc(U[1]), 9)
			ntx("grid %s hz" % nf(G["f"], 2), 4, 56, TX, 9)
			var n_on := 0
			var any2 := false
			for a in r.alarms:
				if a["on"]:
					n_on += 1
					if a["s"] >= 2:
						any2 = true
			ntx("alarms %d" % n_on, 4, 68, RD if any2 else GR, 9)
			ntx("[e] open scada", 4, h - 6, AM, 9)
		"pool":
			hd.call("spent fuel pool")
			ntx(nf(r.rad["pool"], 2) + " usv/h", 4, 36, GR, 14)
			ntx("temp 38.2 c", 4, 54, TX, 10)
			ntx("level 9.00 m", 4, 66, TX, 10)
			ntx("cooling: running", 4, 78, GR, 10)
		"lab":
			hd.call("primary chemistry")
			for i in 2:
				var u2: Dictionary = U[i]
				var y2 := 26.0 + i * 40.0
				ntx("unit %d%s" % [i + 1, " shut down" if u2["scram"] else " on line"], 4, y2, DIM if u2["scram"] else GR, 10)
				ntx("boron %s ppm  ph %s" % [nf(u2["boron"]), nf(7.05 + 0.12 * sin(r.t / 90.0 + i), 2)], 4, y2 + 13, TX, 9)
				ntx("lithium %s ppm" % nf(maxf(0.7, 2.4 - u2["boron"] / 900.0), 2), 4, y2 + 25, TX, 9)
		"frisk":
			hd.call("hand + foot")
			var ok := int(r.t * 0.5) % 2 == 0
			ntx("clear" if ok else "step in", w / 2, h * 0.72, GR if ok else AM, roundf(h * 0.26), "center")
		"diesel":
			hd.call("emergency diesels")
			for i in 2:
				var d: Dictionary = r.dg[i]
				var y3 := 26.0 + i * 34.0
				ntx("dg %d%s" % [i + 1, " running" if d["on"] else " standby"], 4, y3, GR if d["on"] else DIM, 10)
				ntx("%s rpm  fuel %s%%" % [nf(d["rpm"]), nf(d["fuel"])], 4, y3 + 12, TX, 9)
