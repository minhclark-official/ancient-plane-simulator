extends SceneTree
## Headless test of storms, fuel exhaustion, the hull shutdown, the secret ending, LMIA and NCLR flows.
## Run:  godot --headless --path . --script res://tools/smoke_systems.gd

var _flight
var _finished := ""


func _initialize() -> void:
	_run()


func _on_finished(mode: String) -> void:
	_finished = mode


func _boot() -> void:
	_flight = load("res://scenes/flight.tscn").instantiate()
	root.add_child(_flight)
	_flight.finished.connect(_on_finished)
	_finished = ""
	await _flight.begin()


func _run() -> void:
	await process_frame
	# --- storm
	await _boot()
	_flight.m.place_approach(25.0, 3000.0, 215.0)
	_flight.m.storm.state = "on"
	_flight.m.storm.dur = 90.0
	var seen := 0
	for i in 1200:
		_flight._process(0.05)
		seen = maxi(seen, _flight.m.storm.deb.size())
		if _finished != "":
			break
	print("storm: max debris=", seen, " integ=", snappedf(_flight.m.sys.integ, 0.01), " finished=", _finished)
	_flight.queue_free()
	await process_frame
	# --- fuel exhaustion
	await _boot()
	_flight.m.place_approach(30.0, 3000.0, 215.0)
	_flight.m.sys.fuel = [0.01, 0.01]
	for i in 8000:
		_flight._process(0.05)
		if _finished != "":
			break
	print("fuel: finished=", _finished, " shut=", _flight.shut_st)
	_flight.queue_free()
	await process_frame
	# --- hull
	await _boot()
	_flight.m.place_approach(30.0, 3000.0, 215.0)
	_flight.m.sys.integ = 0.0
	for i in 8000:
		_flight._process(0.05)
		if _finished != "":
			break
	print("hull: finished=", _finished)
	_flight.queue_free()
	await process_frame
	# --- secret ending
	root.get_node("Game").inv = ["bible", "bible", "bible"]
	await _boot()
	_flight.m.place_approach(9.0, 3000.0, 215.0)
	var sim_t := 0.0
	for i in 40000:
		_flight._process(0.05)
		sim_t += 0.05
		if _flight.sec_on and _flight.sec_mus != null and is_instance_valid(_flight.sec_mus) and _flight.sec_mus.playing:
			_flight.sec_mus.stop()   # headless audio clock does not advance
		if _flight.sec_on and _flight.sec_phase == "storm":
			_flight.sec_t0 -= 0.05      # headless: run the story clock at sim speed
		if _finished != "":
			break
	print("secret crash=", _flight.m.crashed, " name=", _flight.m.crash_name, " dist=", int(_flight.m.dist_pyr), " alt=", int(_flight.m.alt_ft), " fuel=", _flight.m.sys.fuel, " eng=", _flight.m.sys.eng_run)
	print("secret: finished=", _finished, " phase=", _flight.sec_phase, " sec_t=", snappedf(_flight._sec_t(), 0.1))
	root.get_node("Game").inv = []
	_flight.queue_free()
	await process_frame
	# --- LMIA
	await _boot()
	_flight.m.from_nclr = true
	_flight.m.dest = "LMIA"
	_flight.m.place_approach(9.0, 2600.0, 205.0)
	for i in 12000:
		_flight._process(0.05)
		if _finished != "":
			break
	print("lmia: finished=", _finished)
	_flight.queue_free()
	await process_frame
	quit()
