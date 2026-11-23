class_name ReactorModel
extends RefCounted
## NAICOL REACTOR plant simulation (port of the NR object of the HTML game): two PWR units with turbines,
## four cooling towers, grid and switchyard, emergency diesels, radiation monitors, alarms and logs.
## step_fixed() runs the plant at 10 Hz.

var t := 0.0
var acc := 0.0
var cnt := 0.0
var units: Array = []
var tw: Array = []
var grid := {}
var wx := {}
var rad := {}
var dg: Array = []
var alarms: Array = []
var log_lines: Array = []
var hist: Array = []
var bays: Array = [1, 1, 1, 1]
var eccs: Array = [1, 1]
var spray: Array = [1, 1]
var fire := 1
var siren_until := 0.0
var clock0 := 14 * 3600 + 12 * 60 + 9
var pa := ""
var pa_t := 0.0
var pa_until := 0.0
var chime := 0
var alarm_new := false
var crit := false
var scram_ack := true
var wind := Vector3(0, 0, -1)    ## x, z direction, y = speed
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	units = [_unit(1), _unit(2)]
	for i in 4:
		tw.append(_tower(i))
	grid = {"f": 50.0, "v": 402.0, "sup": 2120.0, "dem": 2100.0, "cap": 3200.0, "exp": 2120.0}
	wx = {"t": 29.1, "rh": 41.0, "ws": 3.2, "wd": 0.4, "press": 1011.0}
	rad = {"site": 0.09, "stack": 0.0014, "cont": [14.0, 14.0], "pool": 2.1, "tur": [0.4, 0.4], "gate": 0.08}
	dg = [{"on": 0, "fuel": 96.0, "rpm": 0.0, "test": 0.0}, {"on": 0, "fuel": 94.0, "rpm": 0.0, "test": 0.0}]
	log_event("site monitoring system online. shift: day, supervisor: o. wahba", 0)
	log_event("unit 1 at 97% power. unit 2 at 97% power.", 0)


func _unit(i: int) -> Dictionary:
	return {"id": i, "rods": [78.0, 80.0, 77.0], "boron": 620.0, "pump": [1, 1, 1], "pumpN": [1.0, 1.0, 1.0], "pw": 0.97, "xe": 0.29,
		"tcold": 289.6, "thot": 324.0, "pz": 155.1, "sgl": 50.0, "sgp": 67.2, "feed": 1.0, "valve": 0.97, "rpm": 3000.0, "mwe": 1060.0,
		"vac": -0.935, "scram": false, "sc": 0.0, "brk": 1, "auto": false, "trip": "", "decay": 0.0, "flux": 97.0, "fuelT": 604.0,
		"state": "online", "rodT": [78.0, 80.0, 77.0], "pzL": 57.0, "gen": {"v": 24.0, "a": 25400.0, "pf": 0.9}, "turbT": 512.0, "vib": 1.6}


func _tower(i: int) -> Dictionary:
	return {"id": i, "unit": 0 if i < 2 else 1, "fans": [1.0, 1.0, 1.0], "fanN": [0.9, 0.9, 0.9], "basin": 98.0, "tc": 27.6,
		"flow": 17.4, "plume": 0.8, "make": 0.42, "q": 1100.0, "cond": 1.8, "pumpOn": 1}


func clock_text(tt := -1.0) -> String:
	var s := int(clock0 + (t if tt < 0.0 else tt)) % 86400
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


func log_event(msg: String, sev := 0) -> void:
	log_lines.push_front({"t": clock_text(), "m": msg, "s": sev})
	if log_lines.size() > 120:
		log_lines.pop_back()


func set_alarm(key: String, cond: bool, msg: String, sev := 1) -> void:
	var a = null
	for x in alarms:
		if x["k"] == key:
			a = x
	if cond:
		if a == null:
			a = {"k": key, "t": clock_text(), "m": msg, "s": sev, "ack": false, "on": true}
			alarms.push_front(a)
			log_event(msg, sev)
			if sev >= 2:
				chime += 1
		elif not a["on"]:
			a["on"] = true
			a["ack"] = false
			a["t"] = clock_text()
			alarms.erase(a)
			alarms.push_front(a)
			if sev >= 2:
				chime += 1
		a["m"] = msg
	elif a != null and a["on"]:
		a["on"] = false
		if a["ack"]:
			alarms.erase(a)
	if alarms.size() > 40:
		var keep: Array = []
		for x in alarms:
			if x["on"] or not x["ack"]:
				keep.append(x)
		alarms = keep.slice(0, 40)
	refresh()


func refresh() -> void:
	alarm_new = false
	crit = false
	for a in alarms:
		if a["on"] and not a["ack"] and a["s"] >= 2:
			alarm_new = true
		if a["on"] and not a["ack"] and a["s"] >= 3:
			crit = true


func ack_all() -> void:
	for a in alarms:
		a["ack"] = true
	var keep: Array = []
	for a in alarms:
		if a["on"]:
			keep.append(a)
	alarms = keep
	scram_ack = true
	siren_until = 0.0
	refresh()


func scram(u: Dictionary, why := "manual scram") -> void:
	if u["scram"]:
		return
	u["scram"] = true
	u["sc"] = 0.0
	u["trip"] = why
	u["auto"] = false
	log_event("unit %d reactor scram: %s" % [u["id"], why], 3)
	scram_ack = false
	siren_until = t + 6.0


func reset_scram(u: Dictionary) -> bool:
	if not u["scram"]:
		return false
	for r in u["rods"]:
		if r > 6.0:
			return false
	if u["pw"] > 0.02:
		return false
	u["scram"] = false
	u["trip"] = ""
	log_event("unit %d scram reset. reactor in shutdown state." % u["id"], 1)
	return true


func auto_start(u: Dictionary) -> bool:
	if u["scram"]:
		return false
	u["auto"] = true
	u["state"] = "startup"
	log_event("unit %d automatic startup sequence started" % u["id"], 1)
	return true


func turb_trip(u: Dictionary, on: bool) -> void:
	if on:
		if u["brk"]:
			u["brk"] = 0
			log_event("unit %d turbine trip, generator breaker open" % u["id"], 2)
	else:
		if not u["brk"] and u["rpm"] > 2900.0:
			u["brk"] = 1
			log_event("unit %d generator synchronised to grid" % u["id"], 1)
		elif not u["brk"]:
			u["valve"] = maxf(u["valve"], 0.2)
			log_event("unit %d turbine run-up commanded" % u["id"], 1)


func toggle_pump(u: Dictionary, k: int) -> void:
	u["pump"][k] = 0 if u["pump"][k] else 1
	log_event("unit %d coolant pump %s%s" % [u["id"], "abc"[k], " start" if u["pump"][k] else " stop"], 1)


func set_rod(u: Dictionary, b: int, v: float) -> void:
	if u["scram"]:
		return
	u["rodT"][b] = clampf(v, 0.0, 100.0)
	u["auto"] = false


func set_boron(u: Dictionary, v: float) -> void:
	u["boron"] = clampf(v, 0.0, 1800.0)


func set_fan(tower: Dictionary, g: int, v: float) -> void:
	tower["fans"][g] = clampf(v, 0.0, 1.0)


func toggle_bay(i: int) -> void:
	bays[i] = 0 if bays[i] else 1
	log_event("switchyard bay %s%s" % ["abcd"[i], " closed" if bays[i] else " opened"], 1)


func test_diesel(i: int) -> void:
	var d: Dictionary = dg[i]
	if d["test"] > 0.0:
		return
	d["test"] = 18.0
	log_event("emergency diesel generator %d start test" % (i + 1), 1)


func drill_siren() -> void:
	siren_until = t + 7.0
	log_event("site siren test", 1)


func total_mwe() -> float:
	return units[0]["mwe"] + units[1]["mwe"]


func total() -> float:
	return total_mwe()


func power_of(u: Dictionary) -> float:
	return maxf(u["pw"], u["decay"]) if u["scram"] else u["pw"]


func _unit_step(u: Dictionary, dt: float, tower: Dictionary) -> void:
	var rods: Array = u["rods"]
	var rod_avg: float = (rods[0] + rods[1] + rods[2]) / 300.0
	for k in 3:
		u["pumpN"][k] += ((1.0 if u["pump"][k] else 0.0) - u["pumpN"][k]) * (1.0 - exp(-dt / 5.0))
	var flow: float = (u["pumpN"][0] + u["pumpN"][1] + u["pumpN"][2]) / 3.0
	var base_rods := [78.0, 80.0, 77.0]
	for k in 3:
		var to: float = 0.0 if u["scram"] else (base_rods[k] if u["auto"] else u["rodT"][k])
		var sp: float = (40.0 if u["scram"] else (2.2 if u["auto"] else 8.0)) * dt
		rods[k] += clampf(to - rods[k], -sp, sp)
	if u["auto"] and not u["scram"]:
		u["rodT"] = rods.duplicate()
	var target := 0.0
	if not u["scram"]:
		var rod_f := clampf((rod_avg - 0.20) / (0.78 - 0.20), 0.0, 1.3)
		var boron_f := clampf(1.0 - (u["boron"] - 620.0) / 1400.0, 0.25, 1.6)
		var xe_f := clampf(1.0 - (u["xe"] - 0.29) * 1.1, 0.6, 1.2)
		target = clampf(rod_f * boron_f * xe_f, 0.0, 1.2) * clampf(0.2 + flow * 0.95, 0.0, 1.0)
	var tau := 24.0 if target > u["pw"] else 10.0
	if u["scram"]:
		u["sc"] += dt
		u["pw"] = maxf(0.0, u["pw"] * exp(-dt / 1.3))
		u["decay"] = 0.066 * exp(-u["sc"] / 1200.0) + 0.012 * exp(-u["sc"] / 20000.0)
	else:
		u["pw"] += (target - u["pw"]) * (1.0 - exp(-dt / tau))
		u["decay"] = maxf(0.0, u["decay"] * exp(-dt / 300.0))
	var P: float = maxf(u["pw"], u["decay"]) if u["scram"] else u["pw"]
	u["flux"] = P * 100.0 * (1.0 + 0.004 * sin(t * 1.7))
	u["xe"] = clampf(u["xe"] + dt * (0.00045 * P * (1.0 - u["xe"] * 0.6) - 0.00014 * u["xe"] - 0.00055 * u["xe"] * P), 0.02, 0.9)
	var dT := 34.5 * P / maxf(0.12, flow)
	var tcold_t: float = 286.2 + (tower["tc"] - 27.5) * 0.22 + P * 3.4
	u["tcold"] += (tcold_t - u["tcold"]) * (1.0 - exp(-dt / 14.0))
	var thot_t: float = u["tcold"] + dT
	u["thot"] += (thot_t - u["thot"]) * (1.0 - exp(-dt / 8.0))
	var pz_t: float = 155.1 + (u["thot"] - 324.0) * 0.42
	u["pz"] += (pz_t - u["pz"]) * (1.0 - exp(-dt / 9.0))
	u["pzL"] += ((57.0 + (u["thot"] - 324.0) * 0.45) - u["pzL"]) * (1.0 - exp(-dt / 20.0))
	u["fuelT"] = u["thot"] + P * 282.0 + sin(t * 0.9) * 0.8
	if not u["scram"] and not str(u["trip"]).begins_with("tt") and u["valve"] < 0.2 and P > 0.05:
		u["valve"] = minf(1.0, u["valve"] + dt * 0.02)
	if u["scram"]:
		u["valve"] = maxf(0.0, u["valve"] - dt * 0.08)
	var eff_v := clampf(1.0 - (u["vac"] + 0.935) * 3.2, 0.7, 1.02)
	var mw_t := 1090.0 * minf(1.0, P) * minf(1.0, u["valve"] * 1.04) * eff_v if (u["brk"] and u["rpm"] > 2900.0) else 0.0
	u["mwe"] += (mw_t - u["mwe"]) * (1.0 - exp(-dt / 7.0))
	var want_rpm := 3000.0 if (u["brk"] or (P > 0.04 and u["valve"] > 0.18)) else 0.0
	if want_rpm > u["rpm"]:
		u["rpm"] = minf(want_rpm, u["rpm"] + 420.0 * dt)
	else:
		u["rpm"] = maxf(want_rpm, u["rpm"] - 30.0 * dt)
	if u["auto"] and not u["brk"] and u["rpm"] >= 2990.0 and P > 0.3:
		u["brk"] = 1
		log_event("unit %d generator synchronised to grid" % u["id"], 1)
	if u["auto"] and P > 0.94 and absf(rods[0] - 78.0) < 0.4:
		u["auto"] = false
		u["state"] = "online"
		log_event("unit %d startup complete. full power." % u["id"], 1)
	var vac_t: float = -0.935 + (tower["tc"] - 27.6) * 0.0035 + (0.0 if u["brk"] else 0.01) - (0.02 if P < 0.05 else 0.0)
	u["vac"] += (vac_t - u["vac"]) * (1.0 - exp(-dt / 10.0))
	u["sgp"] += ((67.2 + (P - 0.97) * 9.0) - u["sgp"]) * (1.0 - exp(-dt / 10.0))
	u["sgl"] += ((50.0 + sin(t * 0.13 + u["id"]) * 1.4 - (3.0 if P > 1.05 else 0.0)) - u["sgl"]) * (1.0 - exp(-dt / 6.0))
	u["feed"] = P * 1.05 + 0.01
	u["turbT"] = 486.0 + P * 26.0 + sin(t * 0.3) * 1.2
	u["vib"] = 1.4 + 0.35 * sin(t * 0.77 + u["id"]) + (1.6 if (u["rpm"] < 2900.0 and u["rpm"] > 300.0) else 0.0)
	u["gen"]["v"] = 24.0 + 0.02 * sin(t * 0.5) if u["brk"] else 0.0
	u["gen"]["a"] = u["mwe"] * 1000.0 / (1.732 * 24.0 * 0.9)
	u["gen"]["pf"] = 0.9
	if not u["scram"]:
		if u["pw"] > 1.09:
			scram(u, "high neutron flux")
		elif u["thot"] > 342.0:
			scram(u, "high coolant temperature")
		elif flow < 0.34 and P > 0.18:
			scram(u, "low coolant flow")
		elif u["pz"] > 166.0 or (u["pz"] < 134.0 and P > 0.1):
			scram(u, "pressuriser pressure out of range")
		elif u["sgl"] < 18.0:
			scram(u, "low steam generator level")
	u["state"] = "scrammed" if u["scram"] else ("startup" if u["auto"] else ("shutdown" if P < 0.02 else "online"))
	var id: int = u["id"]
	set_alarm("u%dflow" % id, flow < 0.7 and flow >= 0.34 and not u["scram"], "unit %d coolant flow low" % id, 1)
	set_alarm("u%dhot" % id, u["thot"] > 335.0 and not u["scram"], "unit %d hot leg temperature high" % id, 2)
	set_alarm("u%dpw" % id, u["pw"] > 1.03 and not u["scram"], "unit %d power above 103%%" % id, 1)
	set_alarm("u%dsc" % id, u["scram"], "unit %d reactor tripped: %s" % [id, u["trip"]], 3)
	set_alarm("u%dbrk" % id, not u["brk"] and u["pw"] > 0.05 and not u["scram"], "unit %d generator breaker open" % id, 2)
	set_alarm("u%dvib" % id, u["vib"] > 3.2, "unit %d turbine vibration high" % id, 1)


func _step(dt: float) -> void:
	t += dt
	var W := wx
	var G := grid
	W["ws"] = clampf(3.1 + 1.6 * sin(t / 137.0) + 0.7 * sin(t / 31.0), 0.6, 8.0)
	W["wd"] += dt * 0.004 * sin(t / 90.0)
	W["t"] = 29.1 + 1.1 * sin(t / 600.0)
	W["rh"] = 41.0 + 4.0 * sin(t / 420.0)
	wind = Vector3(sin(W["wd"]), W["ws"], -cos(W["wd"]))
	var cap_bays := 0
	for b in bays:
		cap_bays += b
	for tower in tw:
		var u: Dictionary = units[tower["unit"]]
		var P := power_of(u)
		for g in 3:
			tower["fanN"][g] += (tower["fans"][g] - tower["fanN"][g]) * (1.0 - exp(-dt / 4.0))
		var fan_avg: float = (tower["fanN"][0] + tower["fanN"][1] + tower["fanN"][2]) / 3.0
		var Q := maxf(0.0, (P * 3411.0 - u["mwe"]) / 2.0)
		tower["q"] += (Q - tower["q"]) * (1.0 - exp(-dt / 12.0))
		var target: float = W["t"] - 2.0 + W["rh"] * 0.04 + 0.4 + 9.5 * (tower["q"] / 1160.0) * (1.0 - 0.78 * fan_avg) + (0.0 if tower["pumpOn"] else 12.0)
		tower["tc"] += (target - tower["tc"]) * (1.0 - exp(-dt / 20.0))
		tower["flow"] = 17.4 * (0.4 + 0.6 * minf(1.0, P + 0.3)) if tower["pumpOn"] else 0.0
		tower["make"] = 0.2 + 0.26 * (tower["q"] / 1160.0)
		tower["basin"] += ((98.0 + sin(t * 0.05 + tower["id"])) - tower["basin"]) * (1.0 - exp(-dt / 30.0))
		tower["plume"] = clampf(0.08 + 0.95 * (tower["q"] / 1160.0) * (0.75 + 0.25 * fan_avg) * (1.15 - W["t"] / 60.0), 0.0, 1.1)
		tower["cond"] = 1.8 + 0.002 * tower["q"] * 0.1
		set_alarm("tw%d" % tower["id"], tower["tc"] > 35.0, "warning: cooling tower %d basin temperature high (%.1f c)" % [tower["id"] + 1, tower["tc"]], 2)
		set_alarm("twc%d" % tower["id"], tower["tc"] > 44.0, "cooling tower %d basin temperature critical (%.1f c)" % [tower["id"] + 1, tower["tc"]], 3)
	for u in units:
		_unit_step(u, dt, tw[0 if u["id"] == 1 else 2])
	G["sup"] = units[0]["mwe"] + units[1]["mwe"]
	G["dem"] = 2090.0 + 210.0 * sin(t / 180.0) + 60.0 * sin(t / 23.0)
	G["cap"] = cap_bays * 800.0
	G["exp"] = minf(G["sup"], G["cap"])
	var ft: float = 50.0 + (G["exp"] - G["dem"]) / 6000.0 + 0.012 * sin(t * 0.7)
	G["f"] += (ft - G["f"]) * (1.0 - exp(-dt / 3.0))
	G["v"] = 402.0 + 1.4 * sin(t / 45.0) + (G["exp"] - G["dem"]) * 0.002
	if G["sup"] > G["cap"] + 20.0:
		for u in units:
			u["valve"] = maxf(0.25, u["valve"] - dt * 0.01 * (G["sup"] / G["cap"]))
	set_alarm("grid", G["sup"] > G["cap"] + 40.0, "export capacity limited by open switchyard bays", 2)
	set_alarm("freq", absf(G["f"] - 50.0) > 0.25, "grid frequency deviation %.2f hz" % G["f"], 2)
	for i in 2:
		var d: Dictionary = dg[i]
		if d["test"] > 0.0:
			d["test"] -= dt
			d["on"] = 1 if d["test"] > 2.0 else 0
			d["rpm"] = minf(1500.0, d["rpm"] + dt * 260.0) if d["on"] else maxf(0.0, d["rpm"] - dt * 180.0)
			if d["test"] <= 0.0:
				d["test"] = 0.0
				d["on"] = 0
				log_event("emergency diesel generator %d test complete: ok" % (i + 1), 1)
		else:
			d["on"] = 0
			d["rpm"] = maxf(0.0, d["rpm"] - dt * 180.0)
		d["fuel"] = clampf(d["fuel"] - (dt * 0.01 if d["on"] else 0.0), 0.0, 100.0)
	var R := rad
	var P1: float = units[0]["pw"]
	var P2: float = units[1]["pw"]
	R["cont"][0] = 12.0 + 260.0 * P1 + rng.randf() * 0.4
	R["cont"][1] = 12.0 + 260.0 * P2 + rng.randf() * 0.4
	R["stack"] = 0.0012 + 0.0004 * (P1 + P2) + rng.randf() * 0.00008
	R["site"] = 0.085 + rng.randf() * 0.006
	R["gate"] = 0.078 + rng.randf() * 0.005
	R["pool"] = 2.05 + rng.randf() * 0.08
	R["tur"][0] = 0.3 + 0.2 * P1 + rng.randf() * 0.02
	R["tur"][1] = 0.3 + 0.2 * P2 + rng.randf() * 0.02
	acc += dt
	if acc >= 1.0:
		acc -= 1.0
		var a: Dictionary = units[0]
		var b: Dictionary = units[1]
		hist.append({"t": t, "m1": a["mwe"], "m2": b["mwe"], "p1": a["pw"] * 100.0, "p2": b["pw"] * 100.0,
			"tb": (tw[0]["tc"] + tw[2]["tc"]) / 2.0, "f": G["f"], "d": G["dem"], "s": G["sup"], "h1": a["thot"], "h2": b["thot"]})
		if hist.size() > 300:
			hist.pop_front()
	if t > pa_t:
		pa_t = t + 80.0 + rng.randf() * 60.0
		var lst: Array = ["attention please: routine turbine hall inspection in progress. hard hats are mandatory.",
			"visitors are reminded to remain on marked paths.",
			"unit 2 turbine hall: crane maintenance at gantry b. please use the south walkway.",
			"all personnel: dosimeters must be worn at all times inside the fenced area.",
			"the fuel handling building is closed to visitors until further notice."]
		pa = lst[rng.randi() % lst.size()]
		pa_until = t + 7.0


## advance the plant by real time dt in 0.1 s steps
func step_fixed(dt: float) -> void:
	cnt += dt
	var n := 0
	while cnt >= 0.1 and n < 12:
		cnt -= 0.1
		_step(0.1)
		n += 1
	if cnt > 1.0:
		cnt = 0.0
