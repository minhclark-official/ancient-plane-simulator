extends Control
## End credits (shown after the MASTER KING finale and after safe landings).

signal replay
signal to_menu

const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const FONT_REG := preload("res://assets/fonts/IBMPlexMono-Regular.woff2")
const LOGO := preload("res://assets/sprites/albionos_logo.png")

const DATA: Array = [
	["h", "ANCIENT PLANE SIMULATOR"],
	["s", "an albionOS production"],
	["gap"],
	["r", "Directed by", "THOMAS CLARK"],
	["r", "Created by", "THOMAS CLARK"],
	["r", "Written by", "THOMAS CLARK"],
	["r", "Produced by", "THOMAS CLARK"],
	["r", "Executive Producer", "THOMAS CLARK"],
	["r", "Co-Producer", "RANDY"],
	["r", "Cinematography", "THOMAS CLARK\n(and one very confused chase camera)"],
	["r", "Edited by", "THOMAS CLARK"],
	["r", "Visual Effects", "THOMAS CLARK"],
	["r", "Sound Design", "THOMAS CLARK"],
	["r", "Stunt Coordinator", "Gravity"],
	["gap"],
	["h2", "CAST"],
	["s", "in order of destruction"],
	["r", "Ancient Air 001", "Itself"],
	["r", "The Pilot", "You (briefly)"],
	["r", "The Autopilot", "\"I'm sorry, Dave.\""],
	["r", "G.P.W.S.", "\"Terrain! Terrain!\""],
	["r", "Master King", "The Great Pyramid"],
	["r", "The Face", "1,000,000+ blocks"],
	["r", "Passengers", "Did not make it"],
	["r", "Air Traffic Control", "Not responding"],
	["gap"],
	["h2", "MUSIC & SOUND"],
	["r", "Main Theme", "\"Ancient Plane Sim Theme\""],
	["r", "Sound Effects", "\"Curse\"  ·  \"Scream\""],
	["r", "Engines", "Synthesised on the Flight Deck"],
	["gap"],
	["h2", "FLIGHT DECK"],
	["r", "Aircraft", "Twin jet, model 1984"],
	["r", "Flight Model", "Point mass, rate-command attitude hold"],
	["r", "Autoland", "3° glideslope. Approach at 5 NM, autoland at 500 ft."],
	["r", "Displays", "CRT, 5×7 bitmap font, 640K RAM"],
	["r", "Rendering", "three.js (original) / Godot 4 (this port)"],
	["r", "Typeface", "IBM Plex Mono"],
	["gap"],
	["h2", "LOCATION"],
	["s", "Filmed on location in Egypt"],
	["s", "(a very small, very flat part of it)"],
	["gap"],
	["s", "No pyramids were harmed in the making of this production."],
	["s", "Several faces were."],
	["gap"],
	["s", "This is a work of parody and comedy."],
	["s", "Any resemblance to actual flights, airlines or pyramids is coincidental."],
	["s", "Not for navigation. Not for training. Not for pyramids."],
	["gap"],
	["h2", "SPECIAL THANKS"],
	["s", "You, for flying Ancient Air."],
	["gap"],
	["gap"],
	["logo"],
	["s", "© 2026 Thomas Clark. All rights reserved."],
]

const LAND_SWAPS := {
	"Passengers": "Safe. All of them.",
	"Master King": "Waiting patiently",
	"The Face": "Still 1,000,000+ blocks",
	"Air Traffic Control": "\"Welcome to JRNA.\"",
	"G.P.W.S.": "\"Nothing to see here.\"",
	"The Autopilot": "\"Landing complete.\"",
}

@onready var dim: ColorRect = $Dim
@onready var title: Label = $Title
@onready var clip: Control = $Clip
@onready var roll: VBoxContainer = $Clip/Roll
@onready var final_box: VBoxContainer = $Final
@onready var replay_btn: Button = $Final/Replay
@onready var skip_btn: Button = $Skip
@onready var menu_btn: Button = $MenuBtn

var mode := "finale"
var skipped := false
var can_replay := false
var _roll_tween: Tween


func _ready() -> void:
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 120)
	($Final/L1 as Label).add_theme_font_override("font", FONT_REG)
	($Final/L1 as Label).add_theme_font_size_override("font_size", 28)
	($Final/L2 as Label).add_theme_font_override("font", FONT_BOLD)
	($Final/L2 as Label).add_theme_font_size_override("font_size", 64)
	replay_btn.add_theme_font_override("font", FONT_BOLD)
	replay_btn.add_theme_font_size_override("font_size", 30)
	skip_btn.add_theme_font_override("font", FONT_BOLD)
	skip_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.add_theme_font_override("font", FONT_REG)
	menu_btn.add_theme_font_size_override("font_size", 22)
	replay_btn.pressed.connect(func(): _finish("replay"))
	menu_btn.pressed.connect(func(): _finish("menu"))
	skip_btn.pressed.connect(skip)
	final_box.modulate.a = 0.0
	menu_btn.modulate.a = 0.0
	menu_btn.visible = false
	title.modulate.a = 0.0
	dim.color.a = 0.0
	skip_btn.visible = false
	final_box.visible = false


func _finish(what: String) -> void:
	Sfx.theme_stop(1.0)
	if what == "replay":
		replay.emit()
	else:
		to_menu.emit()


func _build_rows() -> void:
	for c in roll.get_children():
		c.queue_free()
	var land := mode == "land" or mode == "nclr"
	var rows: Array = DATA.duplicate()
	if mode == "secret":
		var i := 0
		for k in rows.size():
			if rows[k][0] == "r" and rows[k][1] == "Sound Effects":
				i = k + 1
		rows.insert(i, ["r", "", "Courtesy of Goon Master Records"])
		rows.insert(i, ["r", "\"Master Alex\"", "Written and Performed by
Harry (IB12)"])
		for k in rows.size():
			if rows[k][0] == "r" and rows[k][1] == "Passengers":
				rows.insert(k, ["r", "Alex Xavier", "Master of-"])
				rows.insert(k, ["r", "Harry (IB12)", "Himself. Briefly."])
				break
	for r0 in rows:
		var r: Array = r0
		if land and r[0] == "r" and LAND_SWAPS.has(r[1]):
			r = ["r", r[1], LAND_SWAPS[r[1]]]
		if land and r[0] == "s" and str(r[1]).begins_with("No pyramids"):
			r = ["s", "Nobody was harmed in the making of this landing."]
		if land and r[0] == "s" and str(r[1]) == "Several faces were.":
			continue
		match r[0]:
			"gap":
				var g := Control.new()
				g.custom_minimum_size = Vector2(0, 60)
				roll.add_child(g)
			"h":
				roll.add_child(_label(r[1], 60, FONT_BOLD, Color("#ffd24a")))
			"h2":
				roll.add_child(_label(r[1], 38, FONT_BOLD, Color("#ffb030")))
			"s":
				roll.add_child(_label(r[1], 26, FONT_REG, Color("#d9d0b8")))
			"logo":
				var tr := TextureRect.new()
				tr.texture = LOGO
				tr.custom_minimum_size = Vector2(500, 150)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				roll.add_child(tr)
			_:
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", 32)
				var a := _label(r[1], 26, FONT_REG, Color("#b8ae94"))
				a.custom_minimum_size = Vector2(560, 0)
				a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				var b := _label(r[2], 26, FONT_BOLD, Color("#f4efe0"))
				b.custom_minimum_size = Vector2(700, 0)
				b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				hb.add_child(a)
				hb.add_child(b)
				roll.add_child(hb)


func _label(t: String, sz: int, f: Font, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not skipped:
		await get_tree().process_frame
		t += get_process_delta_time()


func run(m: String) -> void:
	mode = m
	skipped = false
	can_replay = false
	var land := mode == "land" or mode == "nclr"
	title.text = "SUCCESSFUL LANDING" if land else "THE END"
	title.add_theme_font_size_override("font_size", 84 if land else 120)
	Sfx.theme("end", 0.85, 3.5)
	skip_btn.visible = true
	create_tween().tween_property(dim, "color:a", 0.84, 3.0)
	await _wait(2.0)
	if not skipped:
		var tw := create_tween()
		tw.tween_property(title, "modulate:a", 1.0, 1.0)
		tw.tween_interval(2.2)
		tw.tween_property(title, "modulate:a", 0.0, 1.0)
		await _wait(4.2)
		await _wait(1.5)
	if not skipped:
		_build_rows()
		await get_tree().process_frame
		await get_tree().process_frame
		var h := roll.get_combined_minimum_size().y
		roll.size = Vector2(1600, h)
		roll.position = Vector2(0, 900)
		var dur := maxf(40.0, (h + 900.0) / 52.0)
		_roll_tween = create_tween()
		_roll_tween.tween_property(roll, "position:y", -h, dur)
		await _wait(dur)
	_show_final()


func skip() -> void:
	if can_replay:
		return
	skipped = true
	title.modulate.a = 0.0
	if _roll_tween:
		_roll_tween.kill()
	roll.visible = false
	_show_final()


func _show_final() -> void:
	if can_replay:
		return
	can_replay = true
	skip_btn.visible = false
	roll.visible = false
	title.modulate.a = 0.0
	dim.color.a = 0.9
	final_box.visible = true
	menu_btn.visible = true
	var tw := create_tween()
	tw.tween_property(final_box, "modulate:a", 1.0, 1.5)
	tw.parallel().tween_property(menu_btn, "modulate:a", 1.0, 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var c := (event as InputEventKey).physical_keycode
	if c == KEY_SPACE or c == KEY_ESCAPE:
		skip()
	elif can_replay and c == KEY_R:
		_finish("replay")
