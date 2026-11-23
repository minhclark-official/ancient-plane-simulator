extends Control
## Main menu and pause menu (same screen, two item lists).

signal chosen(key: String)

const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const FONT_REG := preload("res://assets/fonts/IBMPlexMono-Regular.woff2")

const MAIN_ITEMS: Array = [
	{"t": "new flight", "k": "new"},
	{"t": "controls", "k": "ctl"},
	{"t": "endings", "k": "end"},
	{"t": "exit to desktop", "k": "exit"},
]
const WALK_ITEMS: Array = [
	{"t": "resume", "k": "res"},
	{"t": "fly again", "k": "fly"},
	{"t": "controls", "k": "ctl"},
	{"t": "endings", "k": "end"},
	{"t": "return to main menu", "k": "main"},
	{"t": "exit to desktop", "k": "exit"},
]
const PAUSE_ITEMS: Array = [
	{"t": "resume", "k": "res"},
	{"t": "controls", "k": "ctl"},
	{"t": "endings", "k": "end"},
	{"t": "return to main menu", "k": "main"},
	{"t": "exit to desktop", "k": "exit"},
]

@onready var bg: ColorRect = $Bg
@onready var title: Label = $Title
@onready var header: Label = $Header
@onready var list: VBoxContainer = $List
@onready var footer: Label = $Footer
@onready var pane: Panel = $Pane
@onready var pane_title: Label = $Pane/PaneTitle
@onready var pane_body: Label = $Pane/PaneBody
@onready var pane_back: Label = $Pane/PaneBack
@onready var joining: Label = $Joining

var mode := "main"
var items: Array = MAIN_ITEMS
var sel := 0
var pane_open := ""
var busy := false
var _rows: Array[Label] = []


func _ready() -> void:
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 64)
	header.add_theme_font_override("font", FONT_REG)
	header.add_theme_font_size_override("font_size", 22)
	footer.add_theme_font_override("font", FONT_REG)
	footer.add_theme_font_size_override("font_size", 20)
	joining.add_theme_font_override("font", FONT_BOLD)
	joining.add_theme_font_size_override("font_size", 34)
	pane_title.add_theme_font_override("font", FONT_BOLD)
	pane_title.add_theme_font_size_override("font_size", 34)
	pane_body.add_theme_font_override("font", FONT_REG)
	pane_body.add_theme_font_size_override("font_size", 19)
	pane_back.add_theme_font_override("font", FONT_BOLD)
	pane_back.add_theme_font_size_override("font_size", 26)
	pane_back.gui_input.connect(_on_back_input)
	pane.visible = false
	joining.visible = false
	open(mode)


func open(m: String) -> void:
	mode = m
	items = MAIN_ITEMS if m == "main" else (WALK_ITEMS if m == "pausew" else PAUSE_ITEMS)
	sel = 0
	pane_open = ""
	busy = false
	if is_node_ready():
		_setup_mode()


func _setup_mode() -> void:
	var paused := mode != "main"
	bg.color = Color(0.03, 0.02, 0.01, 0.82) if paused else Color(0.035, 0.026, 0.015, 1.0)
	title.visible = not paused
	footer.visible = not paused
	header.text = "ancient plane sim - paused" if paused else "ancient plane sim   (up/down navigate, enter submit, left back)"
	pane.visible = false
	joining.visible = false
	_build_rows()


func _build_rows() -> void:
	for c in list.get_children():
		c.queue_free()
	_rows.clear()
	for i in items.size():
		var l := Label.new()
		l.add_theme_font_override("font", FONT_BOLD)
		l.add_theme_font_size_override("font_size", 40)
		l.custom_minimum_size = Vector2(620, 62)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(_on_row_input.bind(i))
		l.mouse_entered.connect(_on_row_hover.bind(i))
		list.add_child(l)
		_rows.append(l)
	_mark()


func _mark() -> void:
	for i in _rows.size():
		var on := i == sel
		_rows[i].text = ("> " if on else "  ") + str(items[i]["t"])
		_rows[i].add_theme_color_override("font_color", Color("#ffb030") if on else Color("#d9c9a0"))


func _on_row_hover(i: int) -> void:
	if busy or pane_open != "" or sel == i:
		return
	sel = i
	Sfx.blip()
	_mark()


func _on_row_input(ev: InputEvent, i: int) -> void:
	if busy or pane_open != "":
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		sel = i
		_mark()
		_choose(i)


func _on_back_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_back()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or busy or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var c := (event as InputEventKey).physical_keycode
	if pane_open != "":
		if c in [KEY_LEFT, KEY_ESCAPE, KEY_BACKSPACE, KEY_ENTER, KEY_SPACE, KEY_RIGHT]:
			_back()
		get_viewport().set_input_as_handled()
		return
	if mode != "main" and c == KEY_ESCAPE:
		chosen.emit("res")
		get_viewport().set_input_as_handled()
		return
	match c:
		KEY_DOWN, KEY_S:
			sel = (sel + 1) % items.size()
			Sfx.blip()
			_mark()
		KEY_UP, KEY_W:
			sel = (sel + items.size() - 1) % items.size()
			Sfx.blip()
			_mark()
		KEY_ENTER, KEY_SPACE, KEY_RIGHT, KEY_D:
			_choose(sel)
		_:
			return
	get_viewport().set_input_as_handled()


func _panel(t: String, body: String) -> void:
	pane_title.text = t
	pane_body.text = body
	pane.visible = true


func _back() -> void:
	if pane_open == "":
		return
	pane_open = ""
	Sfx.blip()
	pane.visible = false


func _choose(i: int) -> void:
	var k: String = items[i]["k"]
	match k:
		"ctl":
			Sfx.blip()
			pane_open = "ctl"
			if mode == "pausew":
				_panel("controls", "ON FOOT
w a s d  walk       mouse  look
shift  run          space  jump
e  use / read / operate
esc  menu

TRUCK
e  get in / out    w s  drive    a d  steer

fly again takes off from the nclr runway.")
				return
			_panel("controls", "FLYING                        AUTOMATION\n" +
				"w s   pitch (or arrows)      t     auto take-off\n" +
				"a d   roll                   k     arm autoland\n" +
				"q e   rudder                 j     switch destination\n" +
				"r f   thrust up / down       v     autopilot on / off\n" +
				"g     landing gear           x     time acceleration\n" +
				"[ ]   flaps                  n     map range\n" +
				"p b   parking / brake        autoland: 5 nm out\n\n" +
				"SYSTEM\n" +
				"space pause     m  mute     h  help in flight     esc  close\n\n" +
				"Everything in the cockpit is clickable.\nDrag the yoke and the thrust levers.")
		"end":
			Sfx.blip()
			pane_open = "end"
			var lines := PackedStringArray()
			for e in Game.ENDS:
				var got: bool = Game.got.has(e["k"])
				lines.append(("[x] " if got else "[ ] ") + str(e["t"]))
				lines.append("      " + (str(e["d"]) if got else "not achieved yet"))
			_panel("endings %d/%d" % [Game.count(), Game.ENDS.size()], "\n".join(lines))
		"new":
			busy = true
			Sfx.clunk()
			joining.text = "starting flight..."
			joining.visible = true
			await get_tree().create_timer(0.9).timeout
			chosen.emit("new")
		_:
			Sfx.clunk()
			chosen.emit(k)
