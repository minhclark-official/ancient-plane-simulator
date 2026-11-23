class_name StormModel
extends RefCounted
## Sandstorms: debris (rocks, crates, barrels, planks, books/discs) flies at the aircraft,
## the autopilot dodges what it can see. Port of the STORM object (simulation part).

const NM := WorldData.NM
const D2R := WorldData.D2R

var level := 0.0
var state := "idle"
var cd := 50.0
var t := 0.0
var dur := 0.0
var deb: Array = []           ## debris dictionaries (see spawn)
var next_spawn := 0.0
var next_sneak := 0.0
var evading := 0.0
var ev_msg := 0.0
var book_cool := 0.0
var sneak_book := true
var storms_done := 0
var last_hit := {}
var last_evade := [0, 0]
var cata := 0.0               ## secret ending intensity
var id_counter := 0
var rng := RandomNumberGenerator.new()
var enabled := true
var cata_mode := false         ## secret ending: the flight scene drives step_cata() instead


func _init() -> void:
	rng.randomize()
	reset()


func reset() -> void:
	cata = 0.0
	level = 0.0
	state = "idle"
	cd = 45.0 + rng.randf() * 45.0
	t = 0.0
	next_spawn = 0.0
	next_sneak = 0.0
	evading = 0.0
	book_cool = 0.0
	sneak_book = true
	storms_done = 0
	last_hit = {}
	deb.clear()


func allowed(m: FlightModel) -> bool:
	if m.crashed != "" or m.on_ground or not m.f_airborne or m.f_lockout:
		return false
	return m.f_takeoff_done and m.agl_m > 250.0 and not (m.al_st == "ENG" or m.al_st == "LOCK") and m.dist_dest > 8.5 * NM


func step(m: FlightModel, dt: float) -> void:
	if not enabled or cata_mode or (not m.f_takeoff_done and state == "idle"):
		return
	var ok := allowed(m)
	if state == "idle":
		if ok:
			cd -= dt
			if cd <= 0.0:
				state = "rise"
				t = 0.0
				dur = 56.0 + rng.randf() * 26.0
				sneak_book = true
				next_spawn = 3.0
				next_sneak = 13.0 + rng.randf() * 7.0
				m.ev.append("stormStart")
	else:
		t += dt
		if not ok and state != "fade":
			state = "fade"
		elif state == "rise" and t > 6.0:
			state = "on"
		elif state == "on" and t > dur:
			state = "fade"
			m.ev.append("stormEnd")
		if state == "fade" and level <= 0.001 and deb.is_empty():
			state = "idle"
			cd = 65.0 + rng.randf() * 60.0
			storms_done += 1
	var tgt := 1.0 if (state == "rise" or state == "on") else 0.0
	var rate := 1.0 / 6.0 if tgt > level else 1.0 / 7.0
	level = clampf(level + clampf(tgt - level, -rate * dt, rate * dt), 0.0, 1.0)
	if (state == "on" or (state == "rise" and level > 0.5)) and ok:
		next_spawn -= dt
		next_sneak -= dt
		if next_spawn <= 0.0 and deb.size() < 14:
			next_spawn = 0.7 + rng.randf() * 1.3
			spawn(m, "threat" if rng.randf() < 0.45 else "near")
		if next_sneak <= 0.0 and state == "on":
			next_sneak = 20.0 + rng.randf() * 14.0
			spawn(m, "sneak")
	advance(m, dt)


## Secret-ending storm: driven by the music clock (see secret ending in flight.gd)
func step_cata(m: FlightModel, dt: float, cfg: Dictionary) -> void:
	if state != "on":
		state = "on"
		t = 0.0
	t += dt
	level = clampf(level + dt / 3.2, 0.0, 1.0)
	if m.crashed != "" or m.on_ground:
		advance(m, dt)
		return
	next_spawn -= dt
	if next_spawn <= 0.0 and deb.size() < int(cfg["cap"]):
		next_spawn = float(cfg["gap"]) * (0.7 + rng.randf() * 0.6)
		var hit := rng.randf() < float(cfg["hit"])
		spawn(m, "threat" if hit else "near", {"noBook": true, "big": float(cfg["big"]) * (0.85 + rng.randf() * 0.5), "near": true})
	advance(m, dt)


func axes(m: FlightModel) -> Array:
	var cg := cos(m.gamma)
	return [Vector3(sin(m.psi) * cg, sin(m.gamma), -cos(m.psi) * cg), Vector3(cos(m.psi), 0.0, sin(m.psi))]


func spawn(m: FlightModel, mode: String, opt := {}) -> Dictionary:
	var ax := axes(m)
	var f: Vector3 = ax[0]
	var r: Vector3 = ax[1]
	var v := maxf(m.V, 40.0)
	var kind := ""
	var u := rng.randf()
	if mode == "sneak" and sneak_book and book_cool <= 0.0 and rng.randf() < 0.75:
		kind = "book"
		sneak_book = false
	else:
		kind = "rock" if u < 0.34 else ("crate" if u < 0.52 else ("barrel" if u < 0.66 else ("plank" if u < 0.78 else "book")))
	if opt.get("noBook", false) and kind == "book":
		kind = "rock"
	var vd := Vector3((rng.randf() - 0.5) * 16.0, (rng.randf() - 0.5) * 5.0, 26.0 + rng.randf() * 24.0)
	var clos := maxf(30.0, (f * v - vd).dot(f))
	var dd := 250.0 + rng.randf() * 90.0 if mode == "sneak" else ((420.0 + rng.randf() * 180.0) if opt.get("near", false) else (720.0 + rng.randf() * 300.0))
	var tt := dd / clos
	var mr := 0.0
	var mu := 0.0
	var sg := -1.0 if rng.randf() < 0.5 else 1.0
	if mode == "threat":
		mr = sg * rng.randf() * 6.0
		mu = (rng.randf() - 0.5) * 5.0
	elif mode == "near":
		if rng.randf() < 0.7:
			mr = sg * (21.0 + rng.randf() * 13.0)
		else:
			mu = sg * (11.0 + rng.randf() * 8.0)
	else:
		mr = sg * rng.randf() * 2.5
		mu = 0.5 + rng.randf() * 1.5
	var target := m.pos + f * v * tt + r * mr + Vector3(0, mu, 0)
	var pos := target - vd * tt
	pos.y = maxf(WorldData.ground_h(target.x, target.z) + 8.0, target.y - vd.y * tt)
	var sizes := {"rock": 2.4 + rng.randf() * 2.6, "crate": 2.6 + rng.randf() * 2.2, "barrel": 2.6 + rng.randf() * 1.8,
		"plank": 3.0 + rng.randf() * 2.0, "book": 6.5 if mode == "sneak" else 4.5 + rng.randf() * 3.0}
	var size: float = sizes[kind] * float(opt.get("big", 1.0))
	var item := ""
	if kind == "book":
		var q := rng.randf()
		if mode == "sneak":
			item = "bible" if rng.randf() < 0.4 else ("booklet" if q < 0.34 else ("dvd" if q < 0.67 else "danilo"))
		else:
			item = "bible" if q < 0.42 else ("booklet" if q < 0.66 else ("dvd" if q < 0.83 else "danilo"))
	id_counter += 1
	var d := {"id": id_counter, "kind": kind, "item": item, "mode": mode, "p": pos, "v": vd, "size": size,
		"rad": size * 1.2 if kind == "plank" else size * (0.55 if kind == "book" else 0.6),
		"spin": Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5) * 3.0, "dmin": 1e9, "passed": false, "age": 0.0,
		"dead": false, "tcpa": -1.0, "mr": 0.0, "mu": 0.0, "a": 0.0, "n": 9.0,
		"rot": Vector3(rng.randf(), rng.randf(), rng.randf()) * 6.0, "node": null, "min_b": 0.0}
	if kind == "book":
		d["spin"] = Vector3(rng.randf() - 0.5, rng.randf() - 0.5, (rng.randf() - 0.5) * 1.6) * 1.4
	deb.append(d)
	return d


func advance(m: FlightModel, dt: float) -> void:
	var ax := axes(m)
	var f: Vector3 = ax[0]
	var r: Vector3 = ax[1]
	var P := m.pos
	for d in deb:
		d["age"] += dt
		d["p"] += (d["v"] as Vector3) * dt
		var rel: Vector3 = d["p"] - P
		var a := rel.dot(f)
		var b := rel.x * r.x + rel.z * r.z
		var c := rel.y
		var dist := rel.length()
		if dist < d["dmin"]:
			d["dmin"] = dist
			d["min_b"] = b
		d["a"] = a
		d["clos"] = ((d["v"] as Vector3) - f * m.V).length()
		var vrel: Vector3 = (d["v"] as Vector3) - f * m.V
		var vv := vrel.length_squared()
		var tcpa := -rel.dot(vrel) / maxf(vv, 0.0001)
		var rad: float = d["rad"]
		if a > -5.0 and tcpa > 0.0 and tcpa < 9.0:
			var mp := rel + vrel * tcpa
			d["tcpa"] = tcpa
			d["mr"] = mp.x * r.x + mp.z * r.z
			d["mu"] = mp.y
			d["n"] = Vector2(d["mr"] / (26.0 + rad), d["mu"] / (11.0 + rad * 0.7)).length()
		else:
			d["tcpa"] = -1.0
			d["n"] = 9.0
		var fus := absf(a + 2.0) < 20.0 + rad and absf(b) < 3.6 + rad and absf(c) < 4.2 + rad * 0.8
		var wing := absf(a - 1.0) < 7.0 + rad and absf(b) < 17.0 + rad * 0.6 and absf(c) < 2.6 + rad * 0.6
		var tail := a < -12.0 - rad * 0.3 and a > -25.0 - rad and absf(b) < 2.5 + rad and c > -2.0 and c < 12.0 + rad * 0.5
		if not d["dead"] and (fus or wing or tail):
			d["dead"] = true
			var nose := fus and a > 4.0 and absf(b) < 5.0 + rad and c > -3.0
			last_hit = {"mode": d["mode"], "kind": d["kind"], "item": d["item"], "zone": "nose" if nose else ("wing" if wing else ("tail" if tail else "fuselage")),
				"size": rad, "b": b}
			m.ev.append("debrisHit")
			if d["kind"] == "book":
				book_cool = 14.0
		if not d["passed"] and a < -6.0 and not d["dead"]:
			d["passed"] = true
			if d["dmin"] < 24.0:
				m.ev.append("nearMiss")
		if a < -160.0 or d["age"] > 45.0 or dist > 2500.0:
			d["dead"] = true
	book_cool = maxf(0.0, book_cool - dt)
	var keep: Array = []
	for d in deb:
		if d["dead"]:
			if d["node"] != null and is_instance_valid(d["node"]):
				(d["node"] as Node).queue_free()
		else:
			keep.append(d)
	deb = keep
	evading = maxf(0.0, evading - dt)
	ev_msg = maxf(0.0, ev_msg - dt)


## The autopilot's eyes: returns {} or {"dphi": rad, "dgam": rad}
func evade(m: FlightModel) -> Dictionary:
	if deb.is_empty() or m.agl_m < 110.0 or m.f_lockout:
		return {}
	var th: Array = []
	for d in deb:
		if d["tcpa"] < 0.0 or d["tcpa"] > 7.5 or d["a"] > 1100.0 or d["dead"]:
			continue
		th.append({"t": d["tcpa"], "mr": d["mr"], "mu": d["mu"], "Rl": 26.0 + d["rad"], "Ru": 11.0 + d["rad"] * 0.7})
	var tmin := 99.0
	for q in th:
		var n := Vector2(q["mr"] / q["Rl"], q["mu"] / q["Ru"]).length()
		if n < 1.1 and q["t"] < tmin:
			tmin = q["t"]
	if tmin == 99.0:
		return {}
	var climb_only := m.agl_m < 420.0
	var best := [0, 0]
	var bp := 1e9
	for dl in [-1, 0, 1]:
		for du in [-1, 0, 1]:
			if climb_only and du < 0:
				continue
			var pen := (0.025 if dl != 0 else 0.0) + (0.035 if du != 0 else 0.0)
			if last_evade[0] == dl and last_evade[1] == du:
				pen -= 0.03
			for q in th:
				var tq: float = q["t"]
				var Dl := minf(70.0, 2.3 * pow(maxf(0.0, tq - 1.25), 2.0))
				var Du := minf(40.0, 4.8 * maxf(0.0, tq - 1.2))
				var n2 := Vector2((q["mr"] - dl * Dl) / q["Rl"], (q["mu"] - du * Du) / q["Ru"]).length()
				pen += pow(maxf(0.0, 1.3 - n2), 2.0) * (1.0 + 1.5 / (tq + 0.7))
			if pen < bp:
				bp = pen
				best = [dl, du]
	last_evade = best
	if best[0] == 0 and best[1] == 0:
		return {}
	if evading <= 0.05 and ev_msg <= 0.0:
		ev_msg = 3.2
		m.ev.append("evade")
	evading = 0.7
	return {"dphi": best[0] * 30.0 * D2R, "dgam": best[1] * 0.07}
