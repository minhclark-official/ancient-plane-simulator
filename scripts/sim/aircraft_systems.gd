class_name AircraftSystems
extends RefCounted
## Fuel, engines (start / flameout), electrics, hydraulics, pitot / window heat and airframe integrity.
## Port of the SYS object of the HTML game. Overhead switches live in `sw`.

const DEFAULTS := {
	"BATT": 1, "STBY": 1, "GEN1": 1, "GEN2": 1, "APU": 0, "EXT PWR": 0, "L PUMP": 1, "R PUMP": 1, "XFEED": 0,
	"HYD A": 1, "HYD B": 1, "START 1": 0, "START 2": 0, "IGN": 1, "CUTOFF": 0, "PITOT": 1, "WINDOW": 1,
	"GPWS INH": 0, "LAND L": 0, "LAND R": 0, "TAXI": 0, "STROBE": 0, "BEACON": 1, "NAV": 1, "LOGO": 0,
	"NO SMOK": 1, "BELTS": 1,
}
## switches the scripted endings take away from the player
const CRITICAL := ["BATT", "STBY", "GEN1", "GEN2", "APU", "EXT PWR", "L PUMP", "R PUMP", "XFEED", "HYD A", "HYD B",
	"START 1", "START 2", "IGN", "CUTOFF", "PITOT", "WINDOW"]
const ORDER := ["BATT", "STBY", "GEN1", "GEN2", "APU", "EXT PWR", "L PUMP", "R PUMP", "XFEED", "HYD A", "HYD B",
	"START 1", "START 2", "IGN", "CUTOFF", "PITOT", "WINDOW", "GPWS INH", "LAND L", "LAND R", "TAXI", "STROBE",
	"BEACON", "NAV", "LOGO", "NO SMOK", "BELTS"]

var sw := DEFAULTS.duplicate()
var lock := false
var eng_run: Array = [true, true]
var eng_st: Array = [0.0, 0.0]
var starve: Array = [0.0, 0.0]
var apu := 0.0
var batt := 1.0
var ac := true
var dc_on := true
var stby_on := true
var gen: Array = [1, 1]
var apu_gen := false
var ext := false
var hyd: Array = [1.0, 1.0]
var hp := 1.0
var fuel: Array = [15.7, 15.7]
var leak: Array = [0.0, 0.0]
var pitot := 0.0
var f_ias := -1.0
var f_alt := 0.0
var frost := 0.0
var integ := 1.0
## display power 0..1 per screen (eased in frame())
var dpv := {"eadi": 1.0, "nd": 1.0, "eicas": 1.0, "cdu": 1.0, "mcp": 1.0, "hud": 1.0}
## when >= 0 a scripted shutdown owns the electrics (0..1 flicker level)
var shut_level := -1.0
var msgs: Array = []       ## [text, code] consumed by the flight scene


func e(id: String) -> int:
	var v: int = sw.get(id, 0)
	if lock and CRITICAL.has(id):
		return DEFAULTS[id]
	return v


func set_sw(id: String, v: int) -> void:
	sw[id] = v


func say(t: String, c := "") -> void:
	msgs.append([t, c])


func fuel_total() -> float:
	return fuel[0] + fuel[1]


func feed(i: int) -> int:
	var p := [e("L PUMP"), e("R PUMP")]
	var x := e("XFEED")
	if p[i] and fuel[i] > 0.0:
		return i
	if x and p[1 - i] and fuel[1 - i] > 0.0:
		return 1 - i
	return -1


func _release(i: int) -> void:
	sw["START %d" % (i + 1)] = 0


func step(m: FlightModel, dt: float) -> void:
	lock = m.f_lockout
	var cut := e("CUTOFF")
	if lock:
		for i in 2:
			if not eng_run[i]:
				eng_run[i] = true
				eng_st[i] = 0.0
				starve[i] = 0.0
			fuel[i] = maxf(fuel[i], 4.0)
	for i in 2:
		if leak[i] > 0.0:
			fuel[i] = maxf(0.0, fuel[i] - leak[i] * dt)
	for i in 2:
		var src := feed(i)
		var n1: float = m.n1[i]
		if eng_run[i]:
			if cut or src < 0:
				starve[i] += dt
				var lim := 0.25 if cut else (0.4 if fuel_total() <= 0.0 else 7.0)
				if starve[i] > lim:
					eng_run[i] = false
					starve[i] = 0.0
					say("ENG %d %s" % [i + 1, "SHUTDOWN" if cut else "FLAMEOUT"], "a" if cut else "r")
			else:
				starve[i] = 0.0
			if src >= 0:
				fuel[src] = maxf(0.0, fuel[src] - (0.05 + 0.004 * n1) / 60.0 * dt)
		else:
			var s := e("START %d" % (i + 1))
			var bleed: bool = apu >= 90.0 or (eng_run[1 - i] and m.n1[1 - i] >= 18.0) or (not m.on_ground and m.V > 85.0)
			if s and eng_st[i] == 0.0:
				if not bleed:
					say("NO BLEED AIR", "a")
					_release(i)
				else:
					eng_st[i] = 0.001
			if eng_st[i] > 0.0:
				eng_st[i] += dt
				var ign := e("IGN")
				var fed := src >= 0 and not cut
				if not bleed and not (m.V > 85.0):
					eng_st[i] = 0.0
					_release(i)
					say("START ABORT  NO BLEED", "a")
				elif n1 >= 21.0 and ign and fed:
					eng_run[i] = true
					eng_st[i] = 0.0
					_release(i)
					say("ENG %d STABLE" % (i + 1), "g")
				elif eng_st[i] > 26.0:
					eng_st[i] = 0.0
					_release(i)
					say("START ABORT  " + ("NO IGNITION" if not ign else ("NO FUEL" if not fed else "HUNG START")), "r")
	# APU
	var apu_want := e("APU") and dc_on and fuel_total() > 0.1
	apu = clampf(apu + (dt * 7.5 if apu_want else -dt * 10.0), 0.0, 100.0)
	gen = [1 if (e("GEN1") and eng_run[0] and m.n1[0] >= 18.0) else 0, 1 if (e("GEN2") and eng_run[1] and m.n1[1] >= 18.0) else 0]
	apu_gen = e("APU") and apu >= 95.0
	ext = e("EXT PWR") and m.on_ground and m.V < 1.5 and not m.f_airborne
	ac = gen[0] or gen[1] or apu_gen or ext
	var nl := 0
	for id in ["LAND L", "LAND R", "TAXI", "STROBE", "BEACON", "NAV", "LOGO"]:
		if e(id):
			nl += 1
	if e("BATT"):
		if ac:
			batt = minf(1.0, batt + dt * 0.002)
		else:
			batt = maxf(0.0, batt - dt * (0.00035 + nl * 0.00008 + (0.004 if apu > 0.0 and apu < 95.0 else 0.0)))
	elif e("STBY") and not ac:
		batt = maxf(0.0, batt - dt * 0.0002)
	dc_on = ac or (e("BATT") and batt > 0.02)
	stby_on = e("STBY") and batt > 0.02
	# hydraulics
	var ha := 1.0 if (e("HYD A") and eng_run[0] and m.n1[0] >= 18.0) else 0.0
	var hb := 1.0 if (e("HYD B") and eng_run[1] and m.n1[1] >= 18.0) else 0.0
	var k := minf(1.0, dt * 1.2)
	hyd[0] += (ha - hyd[0]) * k
	hyd[1] += (hb - hyd[1]) * k
	hp = (hyd[0] + hyd[1]) / 2.0
	# pitot / window heat
	if not e("PITOT") and m.f_airborne and not lock:
		pitot = minf(1.0, pitot + dt / 80.0)
	else:
		pitot = maxf(0.0, pitot - dt / 6.0)
	if pitot <= 0.001:
		f_ias = -1.0
	if not e("WINDOW") and not lock:
		frost = minf(1.0, frost + dt / 70.0)
	else:
		frost = maxf(0.0, frost - dt / 9.0)
	# autopilot servos need DC and hydraulics
	if not lock and m.ap_on and (not dc_on or hp < 0.15):
		m.ap_on = false
		m.ap_athr = false
		if m.al_st == "ARM" or m.al_st == "ENG":
			m.al_st = "OFF"
		m.ev.append("apOff")
		say("A/P DISC  NO POWER" if not dc_on else "A/P DISC  HYD", "a")


## returns Vector2(target N1, time constant; 0 = default)
func engine_target(m: FlightModel, i: int, lv: float) -> Vector2:
	if eng_run[i]:
		return Vector2(lv, 0.0)
	if eng_st[i] > 0.0:
		var ok: bool = e("IGN") and feed(i) >= 0 and not e("CUTOFF")
		return Vector2(26.0 if ok else 12.0, 4.5)
	return Vector2(clampf(m.V * 0.12, 0.0, 18.0), 5.0)


func act_rate(kind: String, down := false) -> float:
	if kind == "gear":
		if hp > 0.2:
			return hp
		return 0.2 if down else 0.0
	return hp if hp > 0.2 else 0.0


func auth() -> float:
	return 0.3 + 0.7 * minf(1.0, hp * 1.25)


func brake_k() -> float:
	return 0.45 + 0.55 * hp


func fix_air(m: FlightModel) -> void:
	if not (pitot > 0.01):
		return
	if f_ias < 0.0:
		f_ias = m.ias_kt
		f_alt = m.alt_ft
	m.ias_kt = m.ias_kt * (1.0 - pitot) + pitot * maxf(0.0, f_ias + (m.alt_ft - f_alt) * 0.012)
	m.ias = m.ias_kt * FlightModel.KT


func gpws_inh() -> bool:
	return e("GPWS INH") == 1


## real-time display power easing
func frame(dt: float) -> void:
	var tg := {"eadi": dc_on or stby_on, "mcp": dc_on, "cdu": dc_on, "nd": ac, "eicas": ac, "hud": ac}
	if shut_level >= 0.0:
		var on := shut_level > 0.2
		tg = {"eadi": on, "mcp": on, "cdu": on, "nd": on, "eicas": on, "hud": on}
	for kk in tg:
		var t := 1.0 if tg[kk] else 0.0
		dpv[kk] += (t - dpv[kk]) * minf(1.0, dt * (5.0 if t > 0.5 else 14.0))


## 0..1 average of the lit-ness of the whole panel (used to dim analog dials)
func panel_power() -> float:
	return clampf((dpv["eadi"] + dpv["nd"]) * 0.5, 0.0, 1.0)


func fuel_msgs() -> Array:
	var out: Array = []
	if fuel_total() < 3.0:
		out.append(["LOW FUEL", Color("#ff3b30")])
	if not eng_run[0]:
		out.append(["ENG 1 OUT", Color("#ff3b30")])
	if not eng_run[1]:
		out.append(["ENG 2 OUT", Color("#ff3b30")])
	if not dc_on:
		out.append(["DC BUS OFF", Color("#ff3b30")])
	if hp < 0.5:
		out.append(["HYD LOW", Color("#ffb030")])
	if frost > 0.3:
		out.append(["WINDOW ICE", Color("#ffb030")])
	if pitot > 0.1:
		out.append(["PITOT ICE", Color("#ffb030")])
	if integ < 0.8:
		out.append(["SYS INTEG %d%%" % int(integ * 100.0), Color("#ffb030")])
	return out
