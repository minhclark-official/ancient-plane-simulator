extends Control
## "THE END?" screen shown after a crash (TV static, a few sad lines, FLY AGAIN).

signal replay
signal to_menu

const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const FONT_REG := preload("res://assets/fonts/IBMPlexMono-Regular.woff2")

@onready var title: Label = $Title
@onready var lines_box: VBoxContainer = $Lines
@onready var fly_again: Button = $FlyAgain
@onready var menu_btn: Button = $MenuBtn

var _noise_t := 0.0
var _ready_for_input := false


func _ready() -> void:
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 120)
	fly_again.add_theme_font_override("font", FONT_BOLD)
	fly_again.add_theme_font_size_override("font_size", 30)
	menu_btn.add_theme_font_override("font", FONT_REG)
	menu_btn.add_theme_font_size_override("font_size", 22)
	fly_again.pressed.connect(func(): replay.emit())
	menu_btn.pressed.connect(func(): to_menu.emit())
	fly_again.modulate.a = 0.0
	menu_btn.modulate.a = 0.0
	title.modulate.a = 0.0


func show_end(mode: String) -> void:
	var lines: Array = ["The flight ended early.", "Maybe next time try the pyramid."]
	var ttl := "THE END?"
	match mode:
		"dead_fuel":
			ttl = "SYSTEM OFFLINE"
			lines = ["Ancient Air flight 001 ran out of fuel.", "The gauge did mention it. Several times.", "Cause of crash: gravity."]
		"dead_hull":
			ttl = "SYSTEM OFFLINE"
			lines = ["Ancient Air flight 001 came apart.", "System integrity: 0%.", "Cause of crash: everything."]
	title.text = ttl
	title.add_theme_color_override("font_color", Color("#ff4030") if ttl == "SYSTEM OFFLINE" else Color.WHITE)
	for c in lines_box.get_children():
		c.queue_free()
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 1.2)
	var i := 0
	for ln in lines:
		var l := Label.new()
		l.text = ln
		l.add_theme_font_override("font", FONT_REG)
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color("#e0d6b8"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		lines_box.add_child(l)
		tw.tween_interval(0.5)
		tw.tween_property(l, "modulate:a", 1.0, 0.8)
		i += 1
	tw.tween_interval(0.8)
	tw.tween_property(fly_again, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(menu_btn, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func(): _ready_for_input = true)


func _process(dt: float) -> void:
	_noise_t += dt
	if _noise_t > 0.07:
		_noise_t = 0.0
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.01, 1.0))
	for i in 260:
		var g := randf() * 0.18
		draw_rect(Rect2(randf() * size.x, randf() * size.y, 2 + randf() * 6, 1 + randf() * 2), Color(g, g, g, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _ready_for_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var c := (event as InputEventKey).physical_keycode
		if c == KEY_R or c == KEY_ENTER:
			replay.emit()
