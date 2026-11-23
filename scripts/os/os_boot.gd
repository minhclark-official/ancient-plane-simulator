extends Control
## albionOS start-up: name prompt, content disclaimer (typewriter), BIOS POST, login screen.

signal finished(user_name: String)

const FONT_REG := preload("res://assets/fonts/IBMPlexMono-Regular.woff2")
const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const DISC_LOGO := preload("res://assets/sprites/disc_logo.png")
const SAVE := "user://os.cfg"

@onready var text: Label = $Text
@onready var name_box: VBoxContainer = $Name
@onready var name_edit: LineEdit = $Name/Edit
@onready var logo: TextureRect = $Logo
@onready var login: VBoxContainer = $Login
@onready var login_btn: Button = $Login/Btn
@onready var login_name: Label = $Login/UserName

var _skip := false
var _user := "guest"
var _stage := "key"


func _ready() -> void:
	text.add_theme_font_override("font", FONT_REG)
	text.add_theme_font_size_override("font_size", 24)
	text.add_theme_color_override("font_color", Color("#c8d8c8"))
	($Name/Prompt as Label).add_theme_font_override("font", FONT_BOLD)
	($Name/Prompt as Label).add_theme_font_size_override("font_size", 30)
	name_edit.add_theme_font_override("font", FONT_BOLD)
	name_edit.add_theme_font_size_override("font_size", 30)
	login_name.add_theme_font_override("font", FONT_BOLD)
	login_name.add_theme_font_size_override("font_size", 40)
	login_btn.add_theme_font_override("font", FONT_BOLD)
	login_btn.add_theme_font_size_override("font_size", 28)
	logo.modulate.a = 0.0
	name_box.visible = false
	login.visible = false
	text.text = "press any key to start"
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		name_edit.text = cf.get_value("user", "name", "")
	name_edit.text_submitted.connect(_on_name)
	login_btn.pressed.connect(_on_login)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _stage == "key":
			_stage = "name"
			text.text = ""
			name_box.visible = true
			name_edit.grab_focus()
			Sfx.blip()
		elif _stage == "disc" or _stage == "post":
			_skip = true
	elif event is InputEventMouseButton and event.pressed and (_stage == "disc" or _stage == "post"):
		_skip = true


func _on_name(v: String) -> void:
	v = v.strip_edges()
	if v == "":
		Sfx.play("warn", -6.0)
		return
	_user = v
	var cf := ConfigFile.new()
	cf.set_value("user", "name", v)
	cf.save(SAVE)
	name_box.visible = false
	_run_disclaimer()


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


func _type(full: String, cps: float) -> void:
	text.text = ""
	for ch in full:
		if _skip:
			text.text = full
			return
		text.text += ch
		if ch != " " and ch != "\n":
			Sfx.click()
		var w := 1.0 / cps * (0.6 + randf() * 0.8)
		if ch == ".":
			w = 0.26
		elif ch == "\n":
			w = 0.15
		await get_tree().create_timer(w).timeout


func _run_disclaimer() -> void:
	_stage = "disc"
	_skip = false
	logo.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 0.15, 0.2)
	tw.tween_property(logo, "modulate:a", 0.7, 0.2)
	tw.tween_property(logo, "modulate:a", 1.0, 0.3)
	await _wait(1.2)
	_skip = false
	await _type("disclaimer\n\nthis game is not for the faint of heart. some scenes may be distressing for others.\n\nall characters, depictions, and events in this game are purely a work of fiction.\n\nany real life events relating to the story of the game, as well as references to real products or persons, are used in jest.", 38.0)
	await _wait(3.0)
	logo.modulate.a = 0.0
	_run_post()


func _run_post() -> void:
	_stage = "post"
	_skip = false
	var head := "//ab-bos 3.05 -- albion software systems,inc\n//(c)opyright 1960-1974 all rights reserved\n\nmain processor:   albion core(r) - 2400hz(x 02)\n(cpu0) 0f29 patch(d)\nram:              13500kb\ngraphic unit:     albion basic+ (512mb)\n(gpu0) cs:default 00x0\n"
	text.text = head
	await _wait(1.0)
	for v in [1688, 4348, 9044, 14294, 20480, 27402, 31878]:
		text.text = head + "\nmem test:  %d ok" % v
		Sfx.click()
		await _wait(0.35)
	var tail := "\n\nmemory runs at dual channel\nch 01 | master |    albion rn            default\nch 02 | master |    ieac    cd-0002\nch 03 | master |    addon detected on port01 (sign.:'sigil start')\n\n(!) driver channel 03: error\n      | 0x14   :   sub drive missing\n      | 1x30   :   couldn't verify signature"
	text.text += tail
	await _wait(2.2)
	text.text = ""
	_stage = "login"
	login_name.text = _user
	login.visible = true
	Sfx.chime()


func _on_login() -> void:
	if _stage != "login":
		return
	_stage = "done"
	Sfx.clunk()
	finished.emit(_user)
