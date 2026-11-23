extends SceneTree
## Windowed screenshots of the new features. Run:  godot --path . --script res://tools/screenshot2.gd -- <dir>
var _out := "user://"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	_run()
func _shot(n: String) -> void:
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(_out + "/" + n + ".png")
	print("saved ", n)
func _run() -> void:
	await process_frame
	var w = load("res://scenes/nclr_walk.tscn").instantiate()
	root.add_child(w)
	await create_timer(0.8).timeout
	w.player.global_position = Vector3(150, 1, 0)
	w._yaw = deg_to_rad(-90.0)
	await _shot("n1_walk")
	w.player.global_position = Vector3(206, 1, 4)
	w._yaw = 0.0
	await create_timer(0.3).timeout
	w._open_scada()
	await _shot("n2_scada")
	w.queue_free()
	await process_frame
	var f = load("res://scenes/flight.tscn").instantiate()
	root.add_child(f)
	await f.begin()
	f.m.place_approach(25.0, 3000.0, 215.0)
	f.m.storm.state = "on"
	f.m.storm.dur = 90.0
	for i in 500:
		f._process(0.05)
	await _shot("n3_storm")
	f._toggle_ovh()
	await _shot("n4_overhead")
	f._toggle_ovh()
	root.get_node("Game").inv = ["bible", "booklet"]
	f._open_pda()
	f.pda._on_selected(0) if false else null
	await _shot("n5_pda")
	quit()
