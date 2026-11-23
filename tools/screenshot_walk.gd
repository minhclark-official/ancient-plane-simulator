extends SceneTree
var _out := "user://"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	_run()
func _shot(n: String) -> void:
	for i in 20:
		await process_frame
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(_out + "/" + n + ".png")
	print("saved ", n)
func _look(w, x, z, yaw, pitch := 0.0) -> void:
	w.P["x"] = x
	w.P["z"] = z
	w.P["y"] = w.ground_at(x, z)
	w.P["yaw"] = yaw
	w.P["pitch"] = pitch
func _run() -> void:
	await process_frame
	var w = load("res://scenes/nclr_walk.tscn").instantiate()
	root.add_child(w)
	for i in 40:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _shot("w1_spawn")
	_look(w, -300, 10, PI / 2.0)
	await _shot("w2_gate")
	_look(w, -60, -50, 0.0)
	await _shot("w3_control")
	_look(w, 150, 0, PI / 2.0, 0.2)
	await _shot("w4_units")
	_look(w, 330, 0, PI / 2.0, 0.35)
	await _shot("w5_towers")
	w._open_scada("u1")
	await _shot("w6_scada")
	quit()
