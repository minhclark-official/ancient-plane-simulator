extends SceneTree
## Headless test of the NCLR campus walk, SCADA and the PDA.
func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var w = load("res://scenes/nclr_walk.tscn").instantiate()
	root.add_child(w)
	for i in 30:
		await process_frame
	print("campus loaded ready=", w.ready_, " colliders=", w.col.size(), " ints=", w.ints.size(), " screens=", w.screens.size(), " props=", w.props.size())
	for i in 120:
		await process_frame
	print("walk y=", snappedf(w.P["y"], 0.01))
	# stand in front of the supervisor desk and the control room consoles
	w.P["x"] = -90.0
	w.P["z"] = -50.0
	w.P["yaw"] = 0.0
	for i in 10:
		await process_frame
	print("near=", w.near["label"] if w.near != null else "none")
	if w.near != null and w.near is Dictionary and w.near.has("act"):
		w._run_act(w.near)
		await process_frame
		print("scada open=", w.scada.visible, " tab=", w.scada.tab)
		for t in ["over", "u1", "u2", "cool", "grid", "alarm", "trend", "rad", "log"]:
			w.scada.tab = t
			w.scada.queue_redraw()
			await process_frame
		w.reactor.scram(w.reactor.units[0], "test")
		for i in 100:
			w.reactor.step_fixed(0.5)
		print("scram -> ", w.reactor.units[0]["state"], " alarms=", w.reactor.alarms.size())
		w.scada.close()
	w._truck_enter()
	for i in 60:
		await process_frame
	print("truck driving=", w.tr["driving"])
	w.queue_free()
	await process_frame
	quit()
