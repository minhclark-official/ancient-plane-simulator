extends SceneTree
## Windowed UI flow test: intro -> menu -> controls pane -> new flight -> pause menu -> main menu.
## Run:  godot --path . --script res://tools/flow_test.gd -- <output_dir>

var _out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run()


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await create_timer(0.1).timeout
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await create_timer(0.1).timeout


func _shot(name: String) -> void:
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(_out + "/" + name + ".png")
	print("saved ", name)


func _run() -> void:
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.6).timeout
	await _shot("f1_intro1")
	await _key(KEY_SPACE)
	await create_timer(2.2).timeout
	await _shot("f2_intro2")
	await _key(KEY_SPACE)
	await create_timer(2.0).timeout
	await _shot("f3_menu")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _shot("f4_controls")
	await _key(KEY_LEFT)
	await _key(KEY_UP)
	await _key(KEY_ENTER)
	await create_timer(4.5).timeout
	await _shot("f5_flight_loaded")
	await _key(KEY_T)
	await create_timer(3.0).timeout
	await _key(KEY_ESCAPE)
	await _shot("f6_pause")
	await _key(KEY_ESCAPE)
	await create_timer(1.0).timeout
	await _key(KEY_H)
	await _shot("f7_help")
	quit()
