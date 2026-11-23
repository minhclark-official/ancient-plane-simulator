extends SceneTree
## Renders a few views and saves PNGs (run WITHOUT --headless).
## Run:  godot --path . --script res://tools/screenshot_test.gd -- <output_dir>

var _out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run()


func _shot(name: String) -> void:
	await create_timer(0.4).timeout
	var img := root.get_texture().get_image()
	img.save_png(_out + "/" + name + ".png")
	print("saved ", name)


func _run() -> void:
	await process_frame
	var f = load("res://scenes/flight.tscn").instantiate()
	root.add_child(f)
	await f.begin()
	await create_timer(0.6).timeout
	await _shot("1_ground")
	# airborne, 6 NM from MASTER KING
	f.m.place_approach(6.0, 2200.0, 205.0)
	f.m.al_st = "OFF"
	await _shot("2_approach_king")
	# near the pyramid face
	f.m.place_approach(2.2, 1100.0, 160.0)
	f.m.al_st = "OFF"
	f.m.gear_cmd = 1
	await _shot("3_close_king")
	# JRNA approach
	f.m.dest = "JRNA"
	f.m.place_approach(2.0, 900.0, 160.0)
	await _shot("4_jrna")
	# finale cutscene
	f.m.dest = "MKNG"
	f.m.place_approach(2.1, 1000.0, 150.0)
	f.m.gear_cmd = 1
	f.m.gear = 1.0
	f.m.flaps_cmd = 4
	f.m.flaps = 30.0
	f.m.al_st = "ENG"
	for i in 400:
		f._process(0.05)
	await _shot("5_finale_script")
	for i in 500:
		f._process(0.05)
		if f.state == 2:
			break
	for i in 60:
		f._process(0.05)
	await _shot("6_cine_a")
	for i in 120:
		f._process(0.05)
	await _shot("7_cine_b")
	for i in 40:
		f._process(0.05)
	await _shot("8_cine_boom")
	quit()
