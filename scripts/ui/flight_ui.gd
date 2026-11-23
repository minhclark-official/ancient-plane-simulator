class_name FlightUI
extends RefCounted
## Shared cockpit state between the flight controller and the instrument panels.
## Instruments only talk to this object (never to the flight scene), which keeps the
## scripts free of circular references.

signal say_requested(text: String, kind: String)
signal denied
signal pause_requested
signal help_requested
signal mute_requested
signal inv_requested
signal ovh_requested

const RANGES: Array = [10, 20, 40, 80, 160]

var m: FlightModel
var warp := 1
var rng := 20
var paused := false
var log: Array[String] = []
var king_lamp := false
var warn_flash := false
var caut_flash := false
var terrain_warn := false
var t := 0.0
var yoke_drag := false
var yoke_ail := 0.0
var yoke_elev := 0.0
var wheel_brake := false
var muted := false
var power := {"eadi": 1.0, "nd": 1.0, "eicas": 1.0, "cdu": 1.0, "mcp": 1.0, "hud": 1.0}
var fin_state := "idle"
var fin_siren := false
var sec_on := false
var glitch := 0.0
var ovh_open := false

const LOCKED := ["gear", "flap_up", "flap_dn", "dest", "to", "jsw", "ap", "at", "park", "hdg+", "hdg-", "alt+", "alt-", "spd+", "spd-", "vs+", "vs-"]


func log_msg(s: String) -> void:
	log.append(s)
	if log.size() > 30:
		log.pop_front()


func say(text: String, kind := "ok") -> void:
	say_requested.emit(text, kind)


func cycle_warp() -> void:
	warp = 1 if warp >= 8 else warp * 2
	Sfx.clunk()


func cycle_range() -> void:
	var i := RANGES.find(rng)
	rng = RANGES[(i + 1) % RANGES.size()]
	Sfx.click()


func set_lever(v: float) -> void:
	m.lever_cmd = clampf(v, 0.0, 1.0)
	if m.ap_athr:
		m.ap_athr = false
	if m.ato_phase != "" and m.ato_phase != "DONE":
		m.ato_phase = ""


func press(id: String) -> void:
	if m == null:
		return
	if m.f_lockout and LOCKED.has(id):
		denied.emit()
		return
	if id.begins_with("ovh:"):
		var nm := id.substr(4)
		if nm.begins_with("START"):
			m.sys.set_sw(nm, 1)
		else:
			m.sys.set_sw(nm, 0 if m.sys.sw.get(nm, 0) == 1 else 1)
		Sfx.click()
		return
	match id:
		"inv":
			inv_requested.emit()
		"ovh":
			ovh_requested.emit()
		"gear":
			m.set_gear(0 if m.gear_cmd == 1 else 1)
		"flap_up":
			m.set_flaps(m.flaps_cmd - 1)
		"flap_dn":
			m.set_flaps(m.flaps_cmd + 1)
		"park":
			m.park_brake = not m.park_brake
			Sfx.clunk()
		"brake":
			wheel_brake = true
		"to":
			m.start_auto_takeoff()
		"dest":
			m.dest_press()
		"jsw":
			m.dest_toggle()
		"ap":
			if m.ap_on:
				m.ap_disconnect()
				if m.al_st == "ENG" or m.al_st == "ARM":
					m.al_st = "OFF"
			else:
				m.engage_ap()
		"at":
			if m.ap_on and not m.on_ground:
				m.ap_athr = not m.ap_athr
				Sfx.click()
		"warp":
			cycle_warp()
		"range":
			cycle_range()
		"mute":
			mute_requested.emit()
		"help":
			help_requested.emit()
		"pause":
			pause_requested.emit()
		"hdg+":
			m.ap_hdg = WorldData.wrap360(m.ap_hdg - 1.0 + 10.0) + 1.0
			if m.ap_hdg > 360.0:
				m.ap_hdg -= 360.0
			m.ap_lat = "HDG"
			Sfx.click()
		"hdg-":
			m.ap_hdg = WorldData.wrap360(m.ap_hdg - 1.0 - 10.0) + 1.0
			m.ap_lat = "HDG"
			Sfx.click()
		"alt+":
			m.ap_alt = minf(m.ap_alt + 500.0, 41000.0)
			Sfx.click()
		"alt-":
			m.ap_alt = maxf(m.ap_alt - 500.0, 0.0)
			Sfx.click()
		"spd+":
			m.ap_spd = minf(m.ap_spd + 5.0, 340.0)
			Sfx.click()
		"spd-":
			m.ap_spd = maxf(m.ap_spd - 5.0, 130.0)
			Sfx.click()
		"vs+":
			m.ap_vs = minf(m.ap_vs + 200.0, 3000.0)
			m.ap_vert = "VS"
			Sfx.click()
		"vs-":
			m.ap_vs = maxf(m.ap_vs - 200.0, -3000.0)
			m.ap_vert = "VS"
			Sfx.click()


func release(id: String) -> void:
	if id == "brake":
		wheel_brake = false
