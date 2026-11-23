extends SceneTree
## Headless smoke test: loads every scene, boots the flight scene and drives it through
## take-off, a JRNA landing, the MASTER KING finale and a crash.
## Run:  godot --headless --path . --script res://tools/smoke_test.gd

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
	for p in ["main", "intro", "menu", "the_end", "credits", "flight"]:
		var s = load("res://scenes/%s.tscn" % p)
		print("scene ", p, " loaded=", s != null)
		var inst = s.instantiate()
		root.add_child(inst)
		await process_frame
		inst.queue_free()
		await process_frame
	# --- take-off
	await _boot()
	print("flight state=", _flight.state, " (1 = FLY)")
	_flight.ui.press("to")
	for i in 2400:
		_flight._process(0.05)
		if _flight.m.f_takeoff_done:
			break
	print("takeoff done=", _flight.m.f_takeoff_done, " alt_ft=", int(_flight.m.alt_ft))
	_flight.queue_free()
	await process_frame
	# --- JRNA landing
	await _boot()
	_flight.m.dest = "JRNA"
	_flight.m.place_approach(9.0, 2600.0, 205.0)
	for i in 8000:
		_flight._process(0.05)
		if _finished != "":
			break
	print("JRNA finished=", _finished, " al=", _flight.m.al_st, " state=", _flight.state)
	_flight.queue_free()
	await process_frame
	# --- MASTER KING finale
	await _boot()
	_flight.m.place_approach(9.0, 3000.0, 215.0)
	for i in 12000:
		_flight._process(0.05)
		if _finished != "":
			break
	print("MKNG finished=", _finished, " fin_st=", _flight.fin_st, " state=", _flight.state, " t=", snappedf(_flight.m.t, 0.1))
	_flight.queue_free()
	await process_frame
	# --- crash into the ground
	await _boot()
	_flight.m.place_approach(20.0, 1200.0, 215.0)
	_flight.m.ap_on = false
	_flight.m.in_elev = -0.0
	_flight.m.gamma = -0.3
	_flight.m.theta = -0.3
	for i in 2000:
		_flight._process(0.05)
		if _finished != "":
			break
	print("crash finished=", _finished, " crashed=", _flight.m.crashed)
	_flight.queue_free()
	await process_frame
	quit()
