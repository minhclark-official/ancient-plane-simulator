extends Control
## Two title cards: the studio logo, then the parody / content warning.

signal finished

const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const FONT_REG := preload("res://assets/fonts/IBMPlexMono-Regular.woff2")

@onready var card1: Control = $Card1
@onready var card2: Control = $Card2

var _skip := false
var _armed := false


func _ready() -> void:
	for l in find_children("*", "Label", true, false):
		var lab := l as Label
		lab.add_theme_font_override("font", FONT_REG)
	($Card1/From as Label).add_theme_font_override("font", FONT_REG)
	($Card1/From as Label).add_theme_font_size_override("font_size", 28)
	($Card1/Sub as Label).add_theme_font_size_override("font_size", 24)
	($Card2/Cols/Left/Head as Label).add_theme_font_override("font", FONT_BOLD)
	($Card2/Cols/Left/Head as Label).add_theme_font_size_override("font_size", 44)
	($Card2/Cols/Left/Warn as Label).add_theme_font_size_override("font_size", 28)
	($Card2/Cols/Right/P1 as Label).add_theme_font_size_override("font_size", 22)
	($Card2/Cols/Right/P2 as Label).add_theme_font_size_override("font_size", 22)
	($Card2/Cols/Right/P3 as Label).add_theme_font_size_override("font_size", 22)
	($Card2/Cont as Label).add_theme_font_size_override("font_size", 22)
	card1.modulate.a = 0.0
	card2.modulate.a = 0.0
	_run()


func _run() -> void:
	await _show_card(card1, 3.4)
	await _show_card(card2, -1.0)
	finished.emit()


func _show_card(card: Control, hold: float) -> void:
	_skip = false
	_armed = false
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 1.0)
	await tw.finished
	_armed = true
	var t := 0.0
	while not _skip and (hold < 0.0 or t < hold):
		await get_tree().process_frame
		t += get_process_delta_time()
	var tw2 := create_tween()
	tw2.tween_property(card, "modulate:a", 0.0, 0.7)
	await tw2.finished


func _input(event: InputEvent) -> void:
	if not _armed:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		_skip = true
		get_viewport().set_input_as_handled()
