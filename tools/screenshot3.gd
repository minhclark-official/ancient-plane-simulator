extends SceneTree
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
	var f = load("res://scenes/flight.tscn").instantiate()
	root.add_child(f)
	await f.begin()
	f.hud.age = 20.0
	f.m.place_approach(4.0, 1800.0, 190.0)
	f.m.al_st = "ENG"
	for i in 100:
		f._process(0.05)
		f.hud.age = 20.0
	await _shot("h1_hud")
	f.m.storm.state = "on"
	f.m.storm.dur = 90.0
	for i in 600:
		f._process(0.05)
		f.hud.age = 20.0
	await _shot("h2_hud_tgt")
	quit()
