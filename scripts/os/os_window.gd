class_name OsWindow
extends Panel
## A draggable window of the albionOS desktop (title bar + close button + content area).

signal closed

const TITLE_H := 30.0

var title_text := "window"
var content: Control
var _drag := false
var _drag_off := Vector2.ZERO
var _title: Label


static func make(title: String, win_size: Vector2, body: Control) -> OsWindow:
	var w := OsWindow.new()
	w.title_text = title
	w.size = win_size
	w.custom_minimum_size = win_size
	w.content = body
	return w


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#c0c0c0")
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color("#5b504b")
	add_theme_stylebox_override("panel", sb)
	var bar := ColorRect.new()
	bar.color = Color("#2a2a78")
	bar.position = Vector2(3, 3)
	bar.size = Vector2(size.x - 6.0, TITLE_H)
	bar.gui_input.connect(_on_bar_input)
	add_child(bar)
	_title = Label.new()
	_title.text = title_text
	_title.position = Vector2(10, 4)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(_title)
	var x := Button.new()
	x.text = "x"
	x.focus_mode = Control.FOCUS_NONE
	x.size = Vector2(26, 22)
	x.position = Vector2(bar.size.x - 30.0, 4)
	x.pressed.connect(close)
	bar.add_child(x)
	if content != null:
		content.position = Vector2(6, TITLE_H + 8.0)
		content.size = size - Vector2(12, TITLE_H + 14.0)
		add_child(content)
	gui_input.connect(_on_win_input)


func close() -> void:
	closed.emit()
	queue_free()


func _on_win_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		move_to_front()


func _on_bar_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		_drag_off = get_global_mouse_position() - global_position
		if ev.pressed:
			move_to_front()
	elif ev is InputEventMouseMotion and _drag:
		global_position = get_global_mouse_position() - _drag_off
