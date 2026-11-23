extends Control
## PERLICA WAYNE PDA-84: item storage (read / play / drop), mail, a tiny web browser, flight log, system page.
## Opened with I during a flight.

signal closed

const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const FONT_REG := preload("res://assets/fonts/IBMPlexMono-Regular.woff2")
const GREEN := Color("#46ff7a")
const AMBER := Color("#ffc53a")

@onready var dim: ColorRect = $Dim
@onready var tabs: VBoxContainer = $Body/Tabs
@onready var title: Label = $Body/Screen/Title
@onready var list: ItemList = $Body/Screen/List
@onready var text: Label = $Body/Screen/Text
@onready var pic: TextureRect = $Body/Screen/Pic
@onready var btn_a: Button = $Body/Screen/Bar/ActA
@onready var btn_b: Button = $Body/Screen/Bar/ActB
@onready var btn_prev: Button = $Body/Screen/Bar/Prev
@onready var btn_next: Button = $Body/Screen/Bar/Next
@onready var status: Label = $Body/Screen/Status

var page := "storage"
var log_lines: Array = []
var _sel := -1
var _sub := 0              ## page index inside a book / booklet
var _reading := false
var _player: AudioStreamPlayer
var _web := "home"


func _ready() -> void:
	visible = false
	for n in find_children("*", "Label", true, false):
		(n as Label).add_theme_font_override("font", FONT_REG)
		(n as Label).add_theme_color_override("font_color", GREEN)
	for n in find_children("*", "Button", true, false):
		(n as Button).add_theme_font_override("font", FONT_BOLD)
		(n as Button).focus_mode = Control.FOCUS_NONE
	list.add_theme_font_override("font", FONT_REG)
	list.add_theme_color_override("font_color", GREEN)
	list.add_theme_color_override("font_selected_color", Color.BLACK)
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 30)
	text.add_theme_font_size_override("font_size", 21)
	for n in find_children("*", "Button", true, false):
		(n as Button).add_theme_font_size_override("font_size", 20)
	list.add_theme_font_size_override("font_size", 20)
	for tname in ["storage", "web", "mail", "log", "sys"]:
		var b := Button.new()
		b.text = {"storage": "STORAGE", "web": "INTERNET", "mail": "MAIL", "log": "LOG", "sys": "SYSTEM"}[tname]
		b.custom_minimum_size = Vector2(170, 56)
		b.add_theme_font_override("font", FONT_BOLD)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_set_page.bind(tname))
		tabs.add_child(b)
	var cl := Button.new()
	cl.text = "CLOSE (I)"
	cl.custom_minimum_size = Vector2(170, 56)
	cl.add_theme_font_override("font", FONT_BOLD)
	cl.focus_mode = Control.FOCUS_NONE
	cl.pressed.connect(close)
	tabs.add_child(cl)
	list.item_selected.connect(_on_selected)
	btn_a.pressed.connect(_on_a)
	btn_b.pressed.connect(_on_b)
	btn_prev.pressed.connect(func(): _flip(-1))
	btn_next.pressed.connect(func(): _flip(1))
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close())
	_player = AudioStreamPlayer.new()
	add_child(_player)


func open(log: Array) -> void:
	log_lines = log
	visible = true
	Sfx.clip("pdastart")
	Sfx.meme("pdastart", 0.5)
	_set_page("storage")


func close() -> void:
	if not visible:
		return
	visible = false
	_player.stop()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		var c := (event as InputEventKey).physical_keycode
		if c == KEY_I or c == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func _set_page(p: String) -> void:
	page = p
	_sel = -1
	_sub = 0
	_reading = false
	pic.texture = null
	btn_a.visible = false
	btn_b.visible = false
	btn_prev.visible = false
	btn_next.visible = false
	list.clear()
	Sfx.click()
	match p:
		"storage":
			title.text = "STORAGE  %d/%d" % [Game.inv.size(), Items.MAX_ITEMS]
			for id in Game.inv:
				list.add_item(str(Items.info(id)["name"]))
			text.text = "Select an item." if not Game.inv.is_empty() else "STORAGE EMPTY.\n\nThings that fly into the windshield during a\nsandstorm end up here."
		"web":
			title.text = "INTERNET"
			for k in Items.WEB:
				list.add_item(k.to_upper())
			text.text = Items.WEB[_web]
		"mail":
			title.text = "MAIL"
			for m in Items.MAIL:
				list.add_item(str(m[1]))
			text.text = "Select a message."
		"log":
			title.text = "FLIGHT LOG"
			text.text = "\n".join(PackedStringArray(log_lines.slice(maxi(0, log_lines.size() - 22))))
		"sys":
			title.text = "SYSTEM"
			text.text = "PERLICA WAYNE PDA-84\nBIOS 1.84\nRAM 640K  OK\nSTORAGE %d/%d ITEMS\nENDINGS %d/%d\n\nTHIS DEVICE DOES NOT MAKE COFFEE." % [Game.inv.size(), Items.MAX_ITEMS, Game.count(), Game.ENDS.size()]


func _on_selected(i: int) -> void:
	_sel = i
	_sub = 0
	_reading = false
	Sfx.blip()
	match page:
		"storage":
			var it := Items.info(Game.inv[i])
			title.text = str(it["name"])
			var lines := PackedStringArray([str(it["sub"]), "", str(it["desc"]), ""])
			for mrow in it["meta"]:
				lines.append("%-10s %s" % [mrow[0], mrow[1]])
			text.text = "\n".join(lines)
			pic.texture = load(it["img"])
			btn_a.visible = true
			btn_b.visible = true
			btn_b.text = "DROP"
			match str(it["kind"]):
				"book":
					btn_a.text = "READ"
				"doc":
					btn_a.text = "OPEN"
				"audio":
					btn_a.text = "PLAY"
				_:
					btn_a.text = "READ DISC"
		"web":
			_web = list.get_item_text(i).to_lower()
			text.text = Items.WEB[_web]
		"mail":
			var m: Array = Items.MAIL[i]
			text.text = "FROM: %s\nSUBJ: %s\n\n%s" % [m[0], m[1], m[2]]


func _on_a() -> void:
	if page != "storage" or _sel < 0:
		return
	var it := Items.info(Game.inv[_sel])
	match str(it["kind"]):
		"book":
			_reading = true
			_sub = 0
			_show_read(it)
		"doc":
			_reading = true
			_sub = 0
			_show_read(it)
		"audio":
			if _player.playing:
				_player.stop()
				btn_a.text = "PLAY"
			else:
				_player.stream = Sfx.clip(str(it["audio"]))
				_player.play()
				btn_a.text = "STOP"
		_:
			Sfx.meme("pdaerr", 0.6)
			text.text = "ERROR: DISC UNREADABLE\n\nSURFACE: SCRATCHED / SANDED"


func _on_b() -> void:
	if page == "storage" and _sel >= 0:
		Game.drop_item(_sel)
		_player.stop()
		Sfx.clunk()
		_set_page("storage")


func _show_read(it: Dictionary) -> void:
	btn_prev.visible = true
	btn_next.visible = true
	if it.has("pages"):
		var pg: Array = it["pages"]
		_sub = clampi(_sub, 0, pg.size() - 1)
		text.text = "%s\n\n[page %d/%d]" % [pg[_sub][0], _sub + 1, pg.size()]
		pic.texture = null
	else:
		var im: Array = it["images"]
		_sub = clampi(_sub, 0, im.size() - 1)
		pic.texture = load(im[_sub][0])
		text.text = "%s\n\n[page %d/%d]" % [im[_sub][1], _sub + 1, im.size()]


func _flip(d: int) -> void:
	if not _reading or _sel < 0:
		return
	_sub += d
	Sfx.click()
	_show_read(Items.info(Game.inv[_sel]))
