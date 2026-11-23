extends Node
## Top-level state machine: intro -> main menu -> flight -> THE END / credits -> replay.
## Main Scene of the project (res://scenes/main.tscn).

const INTRO_SCENE := preload("res://scenes/intro.tscn")
const MENU_SCENE := preload("res://scenes/menu.tscn")
const FLIGHT_SCENE := preload("res://scenes/flight.tscn")
const END_SCENE := preload("res://scenes/the_end.tscn")
const CREDITS_SCENE := preload("res://scenes/credits.tscn")
const WALK_SCENE := preload("res://scenes/nclr_walk.tscn")
const BOOT_SCENE := preload("res://scenes/os_boot.tscn")
const DESKTOP_SCENE := preload("res://scenes/os_desktop.tscn")

@onready var ui_layer: CanvasLayer = $UI
@onready var fade: ColorRect = $Fade/Rect

var flight = null
var menu = null
var screen = null
var walk = null
var desktop = null
var user_name := "guest"
var start_nclr := false


func _ready() -> void:
	fade.color = Color(0, 0, 0, 0)
	_run_boot()


## albionOS: start-up sequence, then the desktop
func _run_boot() -> void:
	var b = BOOT_SCENE.instantiate()
	ui_layer.add_child(b)
	user_name = await b.finished
	b.queue_free()
	_show_desktop()


func _show_desktop() -> void:
	_clear_screens()
	_free_flight()
	Sfx.stop_all_loops()
	if desktop:
		desktop.queue_free()
	desktop = DESKTOP_SCENE.instantiate()
	ui_layer.add_child(desktop)
	desktop.set_user(user_name)
	desktop.launch_plane.connect(_launch_plane)
	desktop.logout.connect(_logout)
	desktop.power_off.connect(func(): get_tree().quit())
	await _fade_to(0.0, 0.4)


func _logout() -> void:
	await _fade_to(1.0, 0.3)
	if desktop:
		desktop.stop_audio()
		desktop.queue_free()
		desktop = null
	fade.color.a = 0.0
	_run_boot()


## "ancient_plane_sim" on the desktop: title cards, then the game's own main menu
func _launch_plane() -> void:
	await _fade_to(1.0, 0.4)
	if desktop:
		desktop.stop_audio()
		desktop.queue_free()
		desktop = null
	fade.color.a = 0.0
	var intro = INTRO_SCENE.instantiate()
	ui_layer.add_child(intro)
	await intro.finished
	intro.queue_free()
	_show_main_menu()


func _fade_to(a: float, sec: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, sec)
	await tw.finished


func _clear_screens() -> void:
	if menu:
		menu.queue_free()
		menu = null
	if screen:
		screen.queue_free()
		screen = null
	Sfx.theme_stop(0.5)
	Sfx.siren(false)


func _free_flight() -> void:
	if walk:
		walk.queue_free()
		walk = null
	if flight:
		flight.queue_free()
		flight = null


func _show_main_menu() -> void:
	_clear_screens()
	_free_flight()
	menu = MENU_SCENE.instantiate()
	menu.mode = "main"
	ui_layer.add_child(menu)
	menu.chosen.connect(_on_menu_chosen)
	await _fade_to(0.0, 0.6)


func _on_menu_chosen(key: String) -> void:
	match key:
		"new":
			_start_flight()
		"res":
			_resume()
		"fly":
			if menu:
				menu.queue_free()
				menu = null
			start_nclr = true
			_start_flight()
		"main":
			await _fade_to(1.0, 0.3)
			_show_main_menu()
		"exit":
			await _fade_to(1.0, 0.3)
			_show_desktop()


func _start_flight() -> void:
	await _fade_to(1.0, 0.4)
	_clear_screens()
	_free_flight()
	flight = FLIGHT_SCENE.instantiate()
	flight.start_nclr = start_nclr
	start_nclr = false
	add_child(flight)
	flight.finished.connect(_on_flight_finished)
	flight.pause_requested.connect(_on_pause_requested)
	await _fade_to(0.0, 0.3)
	await flight.begin()


func _on_pause_requested() -> void:
	if menu != null or (flight == null and walk == null):
		return
	var which = walk if walk else flight
	which.set_paused(true)
	menu = MENU_SCENE.instantiate()
	menu.mode = "pausew" if walk else "pause"
	ui_layer.add_child(menu)
	menu.chosen.connect(_on_menu_chosen)


func _resume() -> void:
	if menu:
		menu.queue_free()
		menu = null
	if walk:
		walk.set_paused(false)
	elif flight:
		flight.set_paused(false)


func _on_flight_finished(mode: String) -> void:
	await _fade_to(1.0, 0.5)
	_free_flight()
	match mode:
		"nclr":
			_start_walk()
		"finale", "land", "secret":
			screen = CREDITS_SCENE.instantiate()
			ui_layer.add_child(screen)
			screen.replay.connect(_on_replay)
			screen.to_menu.connect(_show_main_menu)
			await _fade_to(0.0, 0.5)
			screen.run(mode)
		"lmia":
			_start_flight()
		"dead_fuel", "dead_hull":
			Game.unlock(mode.substr(5))
			screen = END_SCENE.instantiate()
			ui_layer.add_child(screen)
			screen.replay.connect(_on_replay)
			screen.to_menu.connect(_show_main_menu)
			await _fade_to(0.0, 0.3)
			screen.show_end(mode)
		_:
			Game.unlock("crash")
			screen = END_SCENE.instantiate()
			ui_layer.add_child(screen)
			screen.replay.connect(_on_replay)
			screen.to_menu.connect(_show_main_menu)
			await _fade_to(0.0, 0.3)
			screen.show_end("crash")


## LMIA (home): the original plays a ground-crew sequence, then you fly again from the stand.
func _lemuel_ground_crew() -> void:
	var l := Label.new()
	l.text = "LEMUEL INTL\n\nGround crews refuel and repair the aircraft\nand tow it back to stand 7.\n\nReady for departure."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_font_override("font", preload("res://assets/fonts/IBMPlexMono-Bold.woff2"))
	l.add_theme_color_override("font_color", Color("#ffb030"))
	ui_layer.add_child(l)
	Sfx.chime()
	await _fade_to(0.0, 0.5)
	await get_tree().create_timer(4.5).timeout
	await _fade_to(1.0, 0.5)
	l.queue_free()
	_start_flight()


func _on_replay() -> void:
	_start_flight()


func _start_walk() -> void:
	walk = WALK_SCENE.instantiate()
	add_child(walk)
	walk.pause_requested.connect(_on_pause_requested)
	await _fade_to(0.0, 0.5)
