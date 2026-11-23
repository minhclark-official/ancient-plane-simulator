class_name FlightModel
extends RefCounted
## Point-mass flight model, autopilot, auto take-off and autoland.
## Direct port of simStep() and friends from the HTML game.
## Angles are radians, distances metres, speeds m/s unless a name says otherwise (Kt, Ft, Fpm).

const NM := WorldData.NM
const KT := WorldData.KT
const FT := WorldData.FT
const G0 := WorldData.G0
const D2R := WorldData.D2R
const R2D := WorldData.R2D

const FLAP_POS: Array = [0.0, 5.0, 15.0, 25.0, 30.0]
const AC_M := 100000.0
const AC_S := 283.0
const AC_TMAX := 2.0 * 118000.0
const AC_CLA := 5.4
const AC_CL0 := 0.25
const AC_K := 0.0497
const AC_CD0 := 0.0215
const AC_GEARH := 4.5
const AC_CLFLAP: Array = [0.0, 0.12, 0.32, 0.50, 0.60]
const AC_CLMAX_BASE := 1.45
const AC_CLMAX_FLAP: Array = [0.0, 0.2, 0.5, 0.76, 0.9]
const AC_CDFLAP: Array = [0.0, 0.004, 0.014, 0.03, 0.042]
const AC_CDGEAR := 0.015
const AC_VR := 130.0
const AC_V2 := 140.0
const AC_VFE: Array = [999.0, 230.0, 200.0, 190.0, 175.0]
const AC_VREF := 140.0
const AC_QMAX := 6.0 * D2R
const AC_PMAX := 20.0 * D2R

# ------------------------------------------------------------ state
var t := 0.0
var pos := Vector3.ZERO
var psi := 0.0
var theta := 0.0
var phi := 0.0
var gamma := 0.0
var V := 0.0
var q := 0.0
var p := 0.0

# pilot inputs
var in_elev := 0.0
var in_ail := 0.0
var in_rud := 0.0
var in_brake := 0.0

var lever: Array = [0.0, 0.0]
var lever_cmd := 0.0
var n1: Array = [24.0, 24.0]
var flaps_cmd := 1
var flaps := 5.0
var gear_cmd := 1
var gear := 1.0
var park_brake := true
var on_ground := true
var crashed := ""          ## "", "pyramid", "belly" or "terrain"
var crash_name := ""
var landed := false
var dest := "MKNG"
var from_nclr := false
var dep_x := float(WorldData.AIRPORT["x"])   ## runway centre line used by the auto take-off
var auto_brake := 0.0
var rwy := ""
var spd_brake := 0.0
var athr_active := false
var fd_p := 0.0
var fd_r := 0.0

# autopilot
var ap_on := false
var ap_athr := false
var ap_lat := "HDG"
var ap_vert := "VS"
var ap_spd := 210.0
var ap_hdg := 360.0
var ap_alt := 3000.0
var ap_vs := 1800.0
var ap_spd_target := 210.0

# autoland manager
var al_st := "OFF"
var al_t0 := 0.0
var al_msg := ""
var al_cf := 0.0
var al_leg := -1
var al_rt := 0.0
var al_flare := false
var al_idle := false
var al_gscap := false
var al_cine_evt := false
var al_hold_alt := NAN

# auto take-off
var ato_phase := ""        ## "", "ROLL", "CLIMB", "DONE"
var ato_t0 := 0.0

# flags
var f_airborne := false
var f_takeoff_done := false
var f_al_done := false
var f_lockout := false
var f_secret := false
var secret_ok := false      ## set by the flight scene: three bibles aboard
var al_secret := false
var fin_active := false
var fin_athr := false
var fin_spd := 0.0

var ev: Array[String] = []
var td := {}
var sys := AircraftSystems.new()
var storm: StormModel = null

# warnings
var w_stall := false
var w_gear := false
var w_overspeed := false
var w_sink := false

# derived ("A" block of the original)
var rho := 1.225
var tas := 0.0
var ias := 0.0
var ias_kt := 0.0
var mach := 0.0
var alt_m := 0.0
var alt_ft := 0.0
var gh := 0.0
var agl_m := 0.0
var agl_ft := 0.0
var vs_ms := 0.0
var vs_fpm := 0.0
var hdg := 0.0
var alpha_a := 0.0
var dx := 0.0
var dz := 0.0
var dist_thr := 0.0
var along_nm := 0.0
var cross := 0.0
var dist_pyr := 0.0
var dist_dest := 0.0
var vfe := 999.0
var n1avg := 24.0
var gs := 0.0
var fix16 := Vector2.ZERO


func _init() -> void:
	var z0: float = float(WorldData.AIRPORT["thrZ"]) - 80.0
	var x0: float = WorldData.AIRPORT["x"]
	pos = Vector3(x0, WorldData.ground_h(x0, z0) + AC_GEARH, z0)
	derive()


# ------------------------------------------------------------ helpers
static func interp(arr: Array, def: float) -> float:
	if def <= 0.0:
		return arr[0]
	for i in range(1, FLAP_POS.size()):
		if def <= FLAP_POS[i]:
			var tt: float = (def - FLAP_POS[i - 1]) / (FLAP_POS[i] - FLAP_POS[i - 1])
			return lerpf(arr[i - 1], arr[i], tt)
	return arr[arr.size() - 1]


static func tf_of_n1(n: float) -> float:
	return 0.04 + 0.96 * pow(clampf((n - 24.0) / 76.0, 0.0, 1.0), 1.5)


static func lever_of_tf(tf: float) -> float:
	return clampf(pow(clampf((tf - 0.04) / 0.96, 0.0, 1.0), 1.0 / 1.5), 0.0, 1.0)


static func n1_of_lever(l: float) -> float:
	return 24.0 + 76.0 * pow(clampf(l, 0.0, 1.0), 0.92)


func cur_dest() -> Dictionary:
	return WorldData.DESTS[dest]


func cur_rw() -> Dictionary:
	if dest == "NCLR":
		return WorldData.NCLR
	if dest == "LMIA":
		return WorldData.LMRW
	return WorldData.JRNA


func next_dest() -> String:
	var o: Array = ["MKNG", "JRNA", "NCLR"]
	if from_nclr:
		o.append("LMIA")
	var i := o.find(dest)
	return o[(i + 1) % o.size()]


func derive() -> void:
	var y := pos.y
	var at := WorldData.isa(y)
	rho = at.x
	tas = V
	ias = V * sqrt(rho / 1.225)
	ias_kt = ias / KT
	mach = V / at.y
	alt_m = y - AC_GEARH
	alt_ft = alt_m / FT
	gh = WorldData.ground_h(pos.x, pos.z)
	agl_m = y - AC_GEARH * gear - (AC_GEARH * 0.55) * (1.0 - gear) - gh
	agl_ft = agl_m / FT
	vs_ms = V * sin(gamma)
	vs_fpm = vs_ms / FT * 60.0
	hdg = WorldData.wrap360(psi * R2D)
	alpha_a = theta - gamma
	var dd := cur_dest()
	fix16 = Vector2(dd["x"], float(dd["z"]) + 7.5 * NM)
	dx = pos.x - dd["x"]
	dz = pos.z - dd["z"]
	dist_thr = Vector2(dx, dz).length()
	along_nm = dz / NM
	cross = dx
	dist_pyr = Vector2(pos.x - WorldData.PYR_X, pos.z - WorldData.PYR_Z).length()
	dist_dest = dist_thr if dest != "MKNG" else dist_pyr
	vfe = AC_VFE[flaps_cmd]
	n1avg = (n1[0] + n1[1]) / 2.0
	gs = V * cos(gamma)
	sys.fix_air(self)


# ------------------------------------------------------------ flight-director loops
func pitch_loop(gamma_cmd: float, _dt: float) -> float:
	var v := maxf(V, 35.0)
	var qq := 0.5 * rho * v * v * AC_S
	var gdes := 0.45 * (gamma_cmd - gamma)
	var cphi := maxf(0.5, cos(phi))
	var lreq := AC_M * (v * gdes + G0 * cos(gamma)) / cphi
	var cl0 := AC_CL0 + interp(AC_CLFLAP, flaps)
	var al := (lreq / qq - cl0) / AC_CLA
	var th_cmd := clampf(gamma + al, -12.0 * D2R, 18.0 * D2R)
	fd_p = th_cmd - theta
	return clampf(1.7 * (th_cmd - theta) / AC_QMAX, -0.8, 0.8)


func theta_loop(th_cmd: float) -> float:
	return clampf(1.7 * (th_cmd - theta) / AC_QMAX, -0.8, 0.8)


func roll_loop(phi_cmd: float) -> float:
	fd_r = phi_cmd - phi
	var pc := clampf(1.3 * (phi_cmd - phi), -AC_PMAX, AC_PMAX)
	return clampf(pc / AC_PMAX, -1.0, 1.0)


func bank_from_hdg(hdg_t: float, max_bank: float) -> float:
	var err := WorldData.wrap_pi(hdg_t - psi)
	var rate := clampf(0.45 * err, -0.0524, 0.0524)
	var v := maxf(V, 40.0)
	return clampf(atan(v * rate / G0), -max_bank, max_bank)


func bearing_to(x: float, z: float) -> float:
	return atan2(x - pos.x, -(z - pos.z))


# ------------------------------------------------------------ pilot / system commands
func set_flaps(i: int) -> void:
	i = clampi(i, 0, 4)
	if i != flaps_cmd:
		flaps_cmd = i
		ev.append("flaps")


func set_gear(v: int) -> void:
	if on_ground and v == 0 and V > 2.0:
		ev.append("gearLocked")
		return
	if v != gear_cmd:
		gear_cmd = v
		ev.append("gear")


func ap_disconnect() -> void:
	if ap_on or ap_athr or al_st == "ENG" or al_st == "ARM":
		ap_on = false
		if al_st == "ENG":
			al_st = "CANCEL"
		ev.append("apOff")
	ap_on = false


func engage_ap() -> void:
	if f_lockout:
		return
	if on_ground or agl_m < 60.0:
		ev.append("apRefuse")
		return
	ap_on = true
	ap_athr = true
	if ap_lat == "TO":
		ap_lat = "HDG"
	ap_hdg = float(roundi(WorldData.wrap360(psi * R2D)))
	if ap_hdg == 0.0:
		ap_hdg = 360.0
	var vs := vs_fpm
	ap_vert = "ALT" if absf(alt_ft - ap_alt) < 80.0 else "VS"
	if ap_vert == "VS":
		ap_vs = roundf(clampf(vs, -3000.0, 3000.0) / 100.0) * 100.0
	ev.append("apOn")


func start_auto_takeoff() -> void:
	if not on_ground or crashed != "" or f_lockout:
		return
	park_brake = false
	set_flaps(1)
	ato_phase = "ROLL"
	ato_t0 = t
	ap_on = false
	ap_athr = false
	ev.append("atoStart")


func dest_toggle() -> void:
	if f_lockout:
		return
	if al_st == "ENG" or al_st == "LOCK" or al_st == "ROLL":
		ev.append("destBusy")
		return
	dest = next_dest()
	if al_st == "ARM":
		_reset_al("OFF")
	ev.append("destPick")


func dest_press() -> void:
	if f_lockout:
		return
	if al_st == "ARM" or al_st == "ENG":
		al_st = "OFF"
		ev.append("destClear")
		return
	if on_ground or agl_m < 150.0:
		ev.append("destRefuse")
		return
	_reset_al("ARM")
	al_t0 = t
	ev.append("destSet")
	if not ap_on:
		engage_ap()
	ap_athr = true


func _reset_al(st: String) -> void:
	al_st = st
	al_t0 = 0.0
	al_msg = ""
	al_cf = 0.0
	al_leg = -1
	al_rt = 0.0
	al_flare = false
	al_idle = false
	al_gscap = false
	al_cine_evt = false
	al_hold_alt = NAN


# ------------------------------------------------------------ auto take-off
func _auto_takeoff_step(_dt: float, C: Dictionary) -> void:
	if ato_phase == "ROLL":
		C["lever"] = 1.0
		var cr := pos.x - dep_x
		C["rud"] = clampf(-(WorldData.wrap_pi(psi - 0.0) * 3.0) - cr * 0.0015, -1.0, 1.0)
		if V > AC_VR * KT:
			C["elev"] = 0.7
		if not on_ground:
			ato_phase = "CLIMB"
	elif ato_phase == "CLIMB":
		C["lever"] = 1.0
		C["elev"] = theta_loop(11.0 * D2R)
		C["ail"] = roll_loop(bank_from_hdg(0.0, 10.0 * D2R))
		if agl_m > 25.0 and gear_cmd == 1 and vs_ms > 1.0:
			set_gear(0)
		if agl_m > 150.0 and ias_kt > AC_V2 + 8.0:
			ap_lat = "HDG"
			ap_hdg = 360.0
			ap_vert = "VS"
			ap_vs = 2200.0
			ap_spd = 215.0
			ap_on = true
			ap_athr = true
			ato_phase = "DONE"
			ev.append("apOn")


# ------------------------------------------------------------ autoland
func _rollout_step(dt: float, C: Dictionary) -> void:
	ap_on = false
	ap_athr = false
	var cr := pos.x - float(cur_rw()["x"])
	C["rud"] = clampf(-(WorldData.wrap_pi(psi) * 3.2) - cr * 0.002, -1.0, 1.0)
	C["elev"] = 0.0
	C["ail"] = 0.0
	al_rt += dt
	spd_brake = minf(1.0, spd_brake + dt * 1.5)
	auto_brake = clampf((al_rt - 1.2) * 0.5, 0.0, 0.75)
	if V < 1.2 and al_rt > 3.0:
		V = 0.0
		auto_brake = 1.0
		park_brake = true
		al_st = "STOPPED"
		ev.append("rolloutStop")


func _autoland_step(dt: float, C: Dictionary) -> void:
	if al_st == "ROLL":
		_rollout_step(dt, C)
		return
	if al_st != "ARM" and al_st != "ENG" and al_st != "LOCK":
		return
	var nm := dist_thr / NM
	var north := dz > 0.0
	var dd := cur_dest()
	var hdg_rwy := 0.0
	var lat_hdg := 0.0
	var cross_ang := -atan(cross / (maxf(V, 50.0) * 28.0))
	var loc_hdg := hdg_rwy + clampf(cross_ang, -0.62, 0.62)
	if al_st == "ARM":
		var d_fix := Vector2(pos.x - fix16.x, pos.z - fix16.y).length()
		if dest == "LMIA" and al_leg == -1:
			al_leg = 1 if dz < 1500.0 else 3
		if al_leg == 1 or al_leg == 2:
			var wx: float = float(dd["x"]) + 10200.0
			var wz: float = (float(dd["z"]) - 3600.0) if al_leg == 1 else (fix16.y + 4200.0)
			lat_hdg = bearing_to(wx, wz)
			if Vector2(pos.x - wx, pos.z - wz).length() < 1800.0:
				al_leg += 1
		elif d_fix > 2500.0 and dz > fix16.y - float(dd["z"]) - 300.0:
			lat_hdg = bearing_to(fix16.x, fix16.y)
		else:
			lat_hdg = loc_hdg
		if nm <= WorldData.IAF_NM and north and not (al_leg == 1 or al_leg == 2):
			al_st = "ENG"
			al_t0 = t
			al_msg = "LOC GS"
			f_al_done = true
			if dest == "MKNG" and secret_ok:
				al_secret = true
				al_msg = "UNAVAIL"
				f_secret = true
				ev.append("secretStart")
			else:
				ev.append("apprCap" if dest != "MKNG" else "alEngaged")
	if al_st == "ENG" or al_st == "LOCK":
		lat_hdg = loc_hdg
	# a real runway: the approach is captured at 5 NM, autoland itself takes over at 500 ft
	if dest != "MKNG" and al_st == "ENG" and not al_cine_evt and al_gscap and agl_ft <= 500.0:
		al_cine_evt = true
		ev.append("alEngaged")
	C["ap"] = true
	C["ail"] = roll_loop(bank_from_hdg(lat_hdg, (25.0 if al_st == "ARM" else 20.0) * D2R))
	# vertical
	var gs_alt: float = float(dd["y"]) + dz * tan(3.0 * D2R)
	var dev := alt_m - gs_alt
	var gcmd := 0.0
	if al_st == "ARM":
		var e := ap_alt * FT - alt_m
		gcmd = asin(clampf(clampf(e * 0.1, -8.0, 8.0) / maxf(V, 50.0), -0.15, 0.15))
	else:
		if dev < -25.0 and not al_gscap:
			if is_nan(al_hold_alt):
				al_hold_alt = alt_m
			var e2 := al_hold_alt - alt_m
			gcmd = asin(clampf(clampf(e2 * 0.1, -6.0, 6.0) / maxf(V, 50.0), -0.1, 0.1))
		else:
			al_gscap = true
			gcmd = -3.0 * D2R - clampf(dev * 0.0007, -0.07, 0.05)
			gcmd = clampf(gcmd, -0.12, 0.05)
		if dest != "MKNG" and al_gscap and agl_m < 26.0:
			if not al_flare:
				al_flare = true
				ev.append("flare")
			var vs_t := -(0.3 + 0.115 * maxf(0.0, agl_m))
			gcmd = asin(clampf(vs_t / maxf(V, 40.0), -0.1, 0.02))
			al_idle = agl_m < 11.0
	C["gamma"] = gcmd
	if al_flare:
		spd_brake += (0.0 - spd_brake) * minf(1.0, dt * 2.0)
	# configuration & speed schedule
	var want_flap := 1
	var spd := ap_spd
	var want_gear := false
	if al_st != "ARM":
		if nm > 4.5:
			want_flap = 1
			spd = 200.0
		elif nm > 4.0:
			want_flap = 2
			spd = 185.0
		elif nm > 3.5:
			want_flap = 3
			spd = 172.0
		elif nm > 2.0:
			want_flap = 4
			spd = 160.0
		else:
			want_flap = 4
			spd = AC_VREF + 4.0
		if nm < 4.3:
			want_gear = true
		if nm < 1.6 and ias_kt > AC_VREF + 10.0:
			spd = AC_VREF
		if want_gear and gear_cmd == 0:
			set_gear(1)
		if want_flap > flaps_cmd and t - al_cf > 0.6 and ias_kt < float(AC_VFE[flaps_cmd + 1]) - 6.0:
			set_flaps(flaps_cmd + 1)
			al_cf = t
	# overspeed protection: speedbrakes + shallower dive while fast
	if al_st != "ARM" and not al_flare:
		var over := ias_kt - spd
		var want := 0.0 if nm < 1.3 else clampf((over - 3.0) / 18.0, 0.0, 1.0)
		spd_brake += (want - spd_brake) * minf(1.0, dt * 1.5)
		if over > 10.0 and C["gamma"] < -0.09:
			C["gamma"] = -0.09
	ap_spd_target = spd
	C["spd"] = spd


# ------------------------------------------------------------ autopilot
func _autopilot_step(dt: float, C: Dictionary) -> void:
	if not ap_on:
		return
	if not C["ap"]:
		var phi_cmd := 0.0
		if ap_lat == "HDG":
			phi_cmd = bank_from_hdg(ap_hdg * D2R, 25.0 * D2R)
		elif ap_lat == "NAV":
			phi_cmd = bank_from_hdg(bearing_to(fix16.x, fix16.y), 25.0 * D2R)
		C["ail"] = roll_loop(phi_cmd)
		var v := maxf(V, 50.0)
		var gcmd := 0.0
		var alt_err := ap_alt * FT - alt_m
		if ap_vert == "VS":
			var vs := ap_vs * FT / 60.0
			gcmd = asin(clampf(vs / v, -0.2, 0.2))
			if signf(alt_err) == signf(vs) and absf(alt_err) < absf(vs) * 9.0 + 25.0:
				ap_vert = "ALT"
				ev.append("altCapture")
		if ap_vert == "ALT":
			gcmd = asin(clampf(clampf(alt_err * 0.1, -10.0, 10.0) / v, -0.15, 0.15))
		C["gamma"] = gcmd
		C["spd"] = ap_spd
	# storm debris: the autopilot dodges what it can see
	if storm != null and not storm.deb.is_empty():
		var evd := storm.evade(self)
		if not evd.is_empty():
			var fd := fd_r
			C["ail"] = roll_loop(fd + phi + float(evd["dphi"]))
			fd_r = fd
			C["gamma"] += float(evd["dgam"])
	C["elev"] = pitch_loop(C["gamma"], dt)


func _autothrottle(spd_kt: float) -> float:
	var v := maxf(V, 30.0)
	var vt := spd_kt * KT / sqrt(rho / 1.225)
	var ades := clampf(0.35 * (vt - V), -1.3, 1.3)
	var qq := 0.5 * rho * v * v * AC_S
	var cl := clampf(AC_M * G0 * cos(gamma) / maxf(qq, 1.0), 0.0, 2.5)
	var cd := AC_CD0 + interp(AC_CDFLAP, flaps) + AC_CDGEAR * gear + AC_K * cl * cl
	var dr := qq * cd
	var treq := dr + AC_M * G0 * sin(gamma) + AC_M * ades
	var tmax := AC_TMAX * pow(rho / 1.225, 0.75) * (1.0 - v / 420.0)
	return lever_of_tf(clampf(treq / tmax, 0.04, 1.0))


# ------------------------------------------------------------ master step
func step(dt: float) -> void:
	if crashed != "":
		return
	t += dt
	derive()
	sys.step(self, dt)
	if storm != null:
		storm.step(self, dt)
	var C := {"elev": in_elev, "ail": in_ail, "rud": in_rud, "lever": -1.0, "ap": false, "gamma": 0.0, "spd": ap_spd}
	var manual_deflect := absf(in_elev) > 0.45 or absf(in_ail) > 0.6
	if f_lockout:
		C["elev"] = 0.0
		C["ail"] = 0.0
	# manual override disconnects the autopilot
	if ap_on and manual_deflect and not f_lockout:
		ap_on = false
		if al_st == "ENG" or al_st == "ARM":
			al_st = "OFF"
		ev.append("apOff")
	if ato_phase != "":
		_auto_takeoff_step(dt, C)
	_autoland_step(dt, C)
	if al_st != "ROLL":
		_autopilot_step(dt, C)
	# thrust lever
	var lever_target := lever_cmd
	var athr := false
	if ato_phase != "" and ato_phase != "DONE" and C["lever"] >= 0.0:
		lever_target = C["lever"]
		athr = true
	elif al_st == "ROLL" or al_st == "STOPPED":
		lever_target = 0.0
		athr = true
	elif al_idle and (al_st == "ENG" or al_st == "LOCK"):
		lever_target = 0.0
		athr = true
	elif ap_athr and ap_on and not on_ground:
		lever_target = _autothrottle(C["spd"])
		athr = true
	elif f_lockout and fin_active and fin_athr:
		lever_target = _autothrottle(fin_spd if fin_spd > 0.0 else AC_VREF + 4.0)
		athr = true
	var au := sys.auth()
	C["elev"] *= au
	C["ail"] *= au
	C["rud"] *= au
	athr_active = athr
	var slew := 0.5 if athr else 3.0
	for i in 2:
		var d: float = lever_target - lever[i]
		lever[i] += clampf(d, -slew * dt, slew * dt)
	# engines
	for i in 2:
		var et := sys.engine_target(self, i, n1_of_lever(lever[i]))
		var tgt := et.x
		var d: float = tgt - n1[i]
		var tau := 1.8
		if d > 0.0:
			tau = 2.6 if n1[i] < 60.0 else 1.5
		if et.y > 0.0:
			tau = et.y
		n1[i] += d * (1.0 - exp(-dt / tau))
	# gear and flap actuators
	var gk := sys.act_rate("gear", gear_cmd > gear)
	gear = clampf(gear + clampf(gear_cmd - gear, -dt / 8.0 * gk, dt / 8.0 * gk), 0.0, 1.0)
	var fd: float = float(FLAP_POS[flaps_cmd]) - flaps
	var fk := sys.act_rate("flaps")
	flaps += clampf(fd, -1.8 * dt * fk, 1.8 * dt * fk)
	# ---------- forces
	var qq := 0.5 * rho * V * V * AC_S
	var alpha := theta - (0.0 if on_ground else gamma)
	var clmax := AC_CLMAX_BASE + interp(AC_CLMAX_FLAP, flaps)
	var a_stall := (clmax - (AC_CL0 + interp(AC_CLFLAP, flaps))) / AC_CLA
	var cl := AC_CL0 + interp(AC_CLFLAP, flaps) + AC_CLA * alpha
	if alpha > a_stall:
		cl = clmax - (alpha - a_stall) * 4.0
		cl = maxf(cl, 0.5)
	cl = clampf(cl, -0.8, 2.6)
	var cd := AC_CD0 + interp(AC_CDFLAP, flaps) + AC_CDGEAR * gear + AC_K * cl * cl + spd_brake * 0.03
	var lift := qq * cl
	var drag := qq * cd
	var tf := (tf_of_n1(n1[0]) + tf_of_n1(n1[1])) / 2.0
	var thrust := AC_TMAX * tf * pow(rho / 1.225, 0.75) * (1.0 - V / 420.0)
	w_stall = not on_ground and alpha > a_stall * 0.92 and V > 30.0
	# ---------- control surfaces
	var eff := clampf(qq / (0.5 * 1.225 * 60.0 * 60.0), 0.25, 1.4)
	if on_ground:
		var nn := maxf(0.0, AC_M * G0 - lift * (1.0 - 0.7 * spd_brake))
		var brk: float = (1.0 if park_brake else maxf(in_brake, auto_brake) * sys.brake_k()) * 0.42
		var F := thrust - drag - 0.018 * nn - brk * nn
		if gear < 0.9:
			F -= 0.5 * nn
		V = maxf(0.0, V + F / AC_M * dt)
		if park_brake and V < 0.3 and thrust < AC_M * G0 * 0.42:
			V = 0.0
		var steer: float = C["rud"]
		psi += steer * 0.26 * minf(1.0, V / 10.0) / (1.0 + V / 22.0) * dt * 2.2
		var th_t := 0.0
		if V > 52.0:
			th_t = clampf(C["elev"], 0.0, 1.0) * 12.0 * D2R * clampf((V - 52.0) / 12.0, 0.0, 1.0)
		if V > 52.0 and C["elev"] < 0.0:
			th_t = 0.0
		theta += clampf(th_t - theta, -3.5 * D2R * dt, 3.5 * D2R * dt)
		phi = 0.0
		p = 0.0
		q = 0.0
		gamma = 0.0
		pos.x += sin(psi) * V * dt
		pos.z += -cos(psi) * V * dt
		pos.y = WorldData.ground_h(pos.x, pos.z) + AC_GEARH * gear + AC_GEARH * 0.55 * (1.0 - gear)
		# lift off
		if lift > AC_M * G0 * 1.01 and theta > 2.0 * D2R and V > 45.0:
			on_ground = false
			gamma = 0.4 * D2R
			q = 0.04
			ev.append("liftoff")
			f_airborne = true
	else:
		# attitude dynamics (rate command / attitude hold)
		var el: float = C["elev"]
		var qc := el * AC_QMAX * eff
		q += (qc - q) * (1.0 - exp(-dt / 0.35))
		var al2 := theta - gamma
		if al2 > a_stall * 1.05 and q > 0.0:
			q *= maxf(0.0, 1.0 - (al2 - a_stall * 1.05) * 14.0)
		theta = clampf(theta + q * dt, -0.7, 0.75)
		var pc: float = float(C["ail"]) * AC_PMAX
		p += (pc - p) * (1.0 - exp(-dt / 0.4))
		phi += p * dt
		if absf(C["ail"]) < 0.02 and not ap_on and absf(phi) < 0.6:
			phi *= 1.0 - 0.30 * dt
		phi = clampf(phi, -1.2, 1.2)
		# point-mass dynamics in the wind axes
		var vv := maxf(V, 25.0)
		var sa := sin(alpha)
		var ca := cos(alpha)
		var dV := (thrust * ca - drag) / AC_M - G0 * sin(gamma)
		var dG := (lift * cos(phi) + thrust * sa) / (AC_M * vv) - G0 * cos(gamma) / vv
		var dPsi := lift * sin(phi) / (AC_M * vv * maxf(0.2, cos(gamma)))
		V = maxf(5.0, V + dV * dt)
		gamma = clampf(gamma + dG * dt, -1.2, 1.2)
		psi = WorldData.wrap_pi(psi + dPsi * dt)
		var vh := V * cos(gamma)
		pos.x += sin(psi) * vh * dt
		pos.z += -cos(psi) * vh * dt
		pos.y += V * sin(gamma) * dt
	# ---------- collisions
	if not on_ground and not fin_active:
		var g := WorldData.ground_h(pos.x, pos.z)
		var legs := AC_GEARH * gear + AC_GEARH * 0.55 * (1.0 - gear)
		var hp := WorldData.hits_pyramid(pos.x, pos.y - 1.0, pos.z)
		if hp != "":
			crashed = "pyramid"
			crash_name = hp
			ev.append("crash")
		elif pos.y - legs <= g and (gamma < 0.0 or pos.y - legs < g - 0.3):
			var vs := V * sin(gamma)
			var rw: Dictionary = {}
			for r in WorldData.RUNWAYS:
				if absf(pos.x - float(r["x"])) < (float(r["wid"]) / 2.0 + 14.0) and pos.z < float(r["thrZ"]) + 200.0 and pos.z > float(r["endZ"]) - 200.0:
					rw = r
					break
			if not rw.is_empty() and gear > 0.95 and vs > -6.0 and absf(phi) < 0.2 and theta < 0.2 and V < 90.0:
				on_ground = true
				landed = true
				pos.y = g + AC_GEARH
				gamma = 0.0
				ev.append("hardLanding" if vs < -3.0 else "touchdown")
				if rw == WorldData.JRNA or rw == WorldData.NCLR or rw == WorldData.LMRW:
					td = {"vs": vs, "cross": pos.x - float(rw["x"]), "dist": float(rw["thrZ"]) - pos.z, "ias": ias_kt, "hdg": psi}
					rwy = rw["code"]
					al_st = "ROLL"
					al_rt = 0.0
					ev.append("jrnaTouch")
			else:
				crashed = "belly" if gear < 0.95 else "terrain"
				ev.append("crash")
	# ---------- flags & events
	derive()
	if not on_ground and agl_m > 20.0:
		f_airborne = true
	if f_airborne and not f_takeoff_done and gear < 0.05 and agl_ft > 500.0 and not on_ground:
		f_takeoff_done = true
		ev.append("takeoffComplete")
	if on_ground and f_airborne and landed:
		f_airborne = false
	w_gear = not on_ground and gear < 0.99 and agl_ft < 1000.0 and V < 95.0 and flaps_cmd >= 3
	w_overspeed = ias_kt > (270.0 if gear > 0.05 else 340.0) or (flaps > 1.0 and ias_kt > vfe + 8.0)
	w_sink = not on_ground and vs_fpm < -1800.0 and agl_ft < 2500.0 and not f_lockout and not sys.gpws_inh()


## Scenario helper (also used by the tests): put the aircraft on approach.
func place_approach(nm: float, alt_ft_: float, ias_: float) -> void:
	var dd := cur_dest()
	var z: float = float(dd["z"]) + nm * NM
	pos = Vector3(dd["x"], alt_ft_ * FT + AC_GEARH, z)
	psi = 0.0
	theta = 2.0 * D2R
	gamma = 0.0
	V = ias_ * KT / sqrt(WorldData.isa(alt_ft_ * FT).x / 1.225)
	on_ground = false
	f_airborne = true
	f_takeoff_done = true
	gear = 0.0
	gear_cmd = 0
	flaps = 5.0
	flaps_cmd = 1
	park_brake = false
	lever = [0.6, 0.6]
	n1 = [80.0, 80.0]
	ap_on = true
	ap_athr = true
	ap_lat = "NAV"
	ap_vert = "ALT"
	ap_alt = alt_ft_
	ap_spd = ias_
	_reset_al("ARM")
	derive()
