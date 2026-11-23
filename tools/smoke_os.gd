extends SceneTree
## albionOS desktop check (+ screenshots when run windowed: -- <dir>)
var _out := ""
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	_run()
func _run() -> void:
	await process_frame
	var b = load("res://scenes/os_boot.tscn").instantiate()
	root.add_child(b)
	await create_timer(0.3).timeout
	b._stage = "name"
	b._on_name("tester")
	await create_timer(0.3).timeout
	b._skip = true
	await create_timer(1.0).timeout
	b._skip = true
	await create_timer(1.0).timeout
	print("boot stage=", b._stage)
	b.queue_free()
	var d = load("res://scenes/os_desktop.tscn").instantiate()
	root.add_child(d)
	d.set_user("tester")
	await process_frame
	for app in ["explorer", "net", "audio", "chat", "mine", "text", "settings"]:
		d._open_app(app)
		await process_frame
	d._chat_reply()
	await create_timer(0.5).timeout
	print("windows=", d._wins.get_child_count(), " forum threads=", d._forum["FT"].size())
	if _out != "":
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png(_out + "/os1_desktop.png")
	quit()
