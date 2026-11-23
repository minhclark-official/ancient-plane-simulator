extends SceneTree
## Headless flight-model check: auto take-off, then autoland at JRNA / MKNG-approach.
## Run:  godot --headless --path . --script res://tools/sim_test.gd


func _init() -> void:
	WorldData.ensure_grid()
	var m := FlightModel.new()
	m.start_auto_takeoff()
	var dt := 1.0 / 30.0
	var n := 0
	while n < 30 * 400 and not m.f_takeoff_done and m.crashed == "":
		m.step(dt)
		m.ev.clear()
		n += 1
	print("takeoff done=", m.f_takeoff_done, " t=", snappedf(m.t, 0.1), " alt_ft=", snappedf(m.alt_ft, 1.0), " ias=", snappedf(m.ias_kt, 1.0), " crashed=", m.crashed)
	for d in ["JRNA", "NCLR", "LMIA"]:
		var s := FlightModel.new()
		s.dest = d
		s.place_approach(9.0, 2600.0, 205.0)
		var k := 0
		while k < 30 * 900 and s.crashed == "" and s.al_st != "STOPPED":
			s.step(dt)
			s.ev.clear()
			k += 1
		print(d, ": al=", s.al_st, " crashed=", s.crashed, " t=", snappedf(s.t, 0.1), " td=", s.td, " V=", snappedf(s.V, 0.1))
	var f := FlightModel.new()
	f.dest = "MKNG"
	f.place_approach(9.0, 3000.0, 215.0)
	var k2 := 0
	while k2 < 30 * 400 and f.crashed == "" and f.dist_pyr > 1.8 * 1852.0:
		f.step(dt)
		f.ev.clear()
		k2 += 1
	print("MKNG: al=", f.al_st, " crashed=", f.crashed, " dist_pyr_nm=", snappedf(f.dist_pyr / 1852.0, 0.01), " alt=", snappedf(f.alt_ft, 1.0), " ias=", snappedf(f.ias_kt, 1.0))
	quit()
