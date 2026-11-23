extends Control
## The albionOS ("albion") desktop: icons, windows and a handful of apps.
## Double-click ancient_plane_sim to launch the game.

signal launch_plane
signal logout
signal power_off

const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const FONT_REG := preload("res://assets/fonts/IBMPlexMono-Regular.woff2")
const FORUM_PATH := "res://assets/data/forum.json"

const ICONS: Array = [
	["explorer", "file\nexplorer", Vector2(46, 104), Color("#e0b040")],
	["net", "albion net", Vector2(46, 247), Color("#4090e0")],
	["audio", "audio\nplayer", Vector2(46, 390), Color("#b060e0")],
	["chat", "albion\nchat", Vector2(46, 533), Color("#40c080")],
	["mine", "minefield", Vector2(46, 676), Color("#e06050")],
	["plane", "ancient_plane_sim", Vector2(1400, 404), Color("#ffd870")],
	["text", "textedit", Vector2(1423, 556), Color("#d0d0d0")],
	["settings", "settings", Vector2(1423, 708), Color("#909090")],
]

const TRACKS: Array = [["ancient plane sim theme", "theme"], ["end credits", "end"], ["danilo tuna fish - the commercial", "danilo"],
	["storm song (cat)", "cat"], ["master alex", "alex"], ["curse", "curse"], ["scream", "scream"]]

const FILES := {
	"readme.txt": "welcome to albion / albionOS.\n\ndouble-click ancient_plane_sim on the desktop to fly.\nquinn says: dont fly to MASTER KING.",
	"notes.txt": "todo:\n- fuel gauge. watch it.\n- bring three bibles. (do not ask)\n- never trust autoland near bricks",
	"flightlog.txt": "ancient air 001\nlogs are kept in the PDA (press I in flight).",
}

var user_name := "guest"
var _wins: Control
var _clock: Label
var _who: Label
var _sel: Control
var _forum := {}
var _audio: AudioStreamPlayer
var _theme := Theme.new()
var _chat_step := 0
var _chat_log: RichTextLabel
var _chat_btn: Button


func _ready() -> void:
	_theme.default_font = FONT_REG
	_theme.default_font_size = 18
	var white := StyleBoxFlat.new()
	white.bg_color = Color("#f4f2ec")
	var dark := Color("#111111")
	for tc in ["Label", "Button", "CheckButton", "ItemList", "TextEdit", "LineEdit"]:
		_theme.set_color("font_color", tc, dark)
	for tc2 in ["Button", "CheckButton"]:
		_theme.set_color("font_hover_color", tc2, dark)
		_theme.set_color("font_pressed_color", tc2, dark)
		_theme.set_color("font_focus_color", tc2, dark)
		_theme.set_color("font_disabled_color", tc2, Color("#666666"))
	_theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	_theme.set_color("default_color", "RichTextLabel", dark)
	_theme.set_stylebox("panel", "ItemList", white)
	_theme.set_stylebox("normal", "TextEdit", white)
	_theme.set_stylebox("normal", "RichTextLabel", white)
	_theme.set_stylebox("normal", "LineEdit", white)
	theme = _theme
	var bg := ColorRect.new()
	bg.color = Color("#3d6b3a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var rn := RandomNumberGenerator.new()
	rn.seed = 1993
	for i in 140:
		var g := ColorRect.new()
		g.color = Color(0.2 + rn.randf() * 0.15, 0.4 + rn.randf() * 0.2, 0.18, 0.7)
		g.position = Vector2(rn.randf() * 1600.0, 40.0 + rn.randf() * 860.0)
		g.size = Vector2(2, 6 + rn.randf() * 8)
		bg.add_child(g)
	for ic in ICONS:
		_make_icon(ic)
	_wins = Control.new()
	_wins.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wins)
	var bar := ColorRect.new()
	bar.color = Color("#2b2230")
	bar.size = Vector2(1600, 36)
	add_child(bar)
	var lo := Button.new()
	lo.text = "log out"
	lo.focus_mode = Control.FOCUS_NONE
	lo.position = Vector2(8, 4)
	lo.size = Vector2(100, 28)
	lo.pressed.connect(func(): logout.emit())
	bar.add_child(lo)
	var po := Button.new()
	po.text = "power off"
	po.focus_mode = Control.FOCUS_NONE
	po.position = Vector2(116, 4)
	po.size = Vector2(110, 28)
	po.pressed.connect(func(): power_off.emit())
	bar.add_child(po)
	_who = Label.new()
	_who.position = Vector2(250, 6)
	_who.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(_who)
	_clock = Label.new()
	_clock.position = Vector2(1480, 6)
	_clock.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(_clock)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	var f := FileAccess.open(FORUM_PATH, FileAccess.READ)
	if f:
		_forum = JSON.parse_string(f.get_as_text())
	_refresh_who()


func set_user(n: String) -> void:
	user_name = n
	if is_node_ready():
		_refresh_who()


func _refresh_who() -> void:
	_who.text = "logged in as " + user_name


func _process(_dt: float) -> void:
	var d := Time.get_datetime_dict_from_system()
	_clock.text = "%02d:%02d:%02d" % [d["hour"], d["minute"], d["second"]]


func stop_audio() -> void:
	_audio.stop()


# ------------------------------------------------------------------ icons
func _make_icon(ic: Array) -> void:
	var p := Panel.new()
	p.position = ic[2]
	p.size = Vector2(120, 118)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	p.add_theme_stylebox_override("panel", sb)
	var glyph := ColorRect.new()
	glyph.color = ic[3]
	glyph.position = Vector2(30, 4)
	glyph.size = Vector2(60, 60)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(glyph)
	var lab := Label.new()
	lab.text = ic[1]
	lab.position = Vector2(0, 68)
	lab.size = Vector2(120, 48)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_outline_color", Color.BLACK)
	lab.add_theme_constant_override("outline_size", 5)
	lab.add_theme_font_size_override("font_size", 16)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lab)
	p.gui_input.connect(_on_icon_input.bind(p, ic[0]))
	add_child(p)


func _on_icon_input(ev: InputEvent, p: Panel, app: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _sel and _sel != p:
			(_sel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0)
		_sel = p
		(p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(1, 1, 1, 0.18)
		Sfx.click()
		if ev.double_click:
			_open_app(app)


func _open_app(app: String) -> void:
	match app:
		"plane":
			launch_plane.emit()
		"explorer":
			_open_explorer()
		"net":
			_open_net()
		"audio":
			_open_audio()
		"chat":
			_open_chat()
		"mine":
			_add_win("minefield", Vector2(430, 560), Minesweeper.new(), Vector2(500, 120))
		"text":
			_open_text("untitled.txt", "")
		"settings":
			_open_settings()


func _add_win(title: String, sz: Vector2, body: Control, pos := Vector2(300, 100)) -> OsWindow:
	var w := OsWindow.make(title, sz, body)
	w.position = pos + Vector2(randf() * 30.0, randf() * 30.0)
	_wins.add_child(w)
	Sfx.blip()
	return w


# ------------------------------------------------------------------ apps
func _open_text(name_: String, text: String) -> void:
	var te := TextEdit.new()
	te.text = text
	_add_win("textedit - " + name_, Vector2(600, 460), te, Vector2(360, 140))


func _open_explorer() -> void:
	var il := ItemList.new()
	for k in FILES:
		il.add_item(k)
	il.add_item("danilo_commercial.mp3")
	il.add_item("theme.mp3")
	il.item_activated.connect(func(i: int):
		var nm := il.get_item_text(i)
		if FILES.has(nm):
			_open_text(nm, FILES[nm])
		else:
			_open_audio())
	_add_win("file explorer", Vector2(520, 380), il, Vector2(200, 120))


func _open_audio() -> void:
	var box := VBoxContainer.new()
	var il := ItemList.new()
	il.custom_minimum_size = Vector2(480, 230)
	for t in TRACKS:
		il.add_item(t[0])
	box.add_child(il)
	var row := HBoxContainer.new()
	var play := Button.new()
	play.text = "play"
	var stop := Button.new()
	stop.text = "stop"
	row.add_child(play)
	row.add_child(stop)
	box.add_child(row)
	var lab := Label.new()
	lab.text = "select a track"
	box.add_child(lab)
	var start := func():
		var sel := il.get_selected_items()
		if sel.size() == 0:
			return
		var key: String = TRACKS[sel[0]][1]
		_audio.stream = Sfx.clip(key)
		_audio.play()
		lab.text = "playing: " + str(TRACKS[sel[0]][0])
	play.pressed.connect(start)
	il.item_activated.connect(func(_i): start.call())
	stop.pressed.connect(func():
		_audio.stop()
		lab.text = "stopped")
	_add_win("audio player", Vector2(520, 360), box, Vector2(420, 160))


func _bb(s: String) -> String:
	var out := s.replace("[", "(").replace("]", ")")
	var rx := RegEx.new()
	rx.compile("\\*\\*(.+?)\\*\\*")
	return rx.sub(out, "[b]$1[/b]", true)


func _open_net() -> void:
	if _forum.is_empty():
		return
	var split := HBoxContainer.new()
	var threads := ItemList.new()
	threads.custom_minimum_size = Vector2(300, 0)
	var ids: Array = []
	for id in _forum["FT"]:
		ids.append(id)
		threads.add_item(str(_forum["FT"][id]["t"]).substr(0, 34))
	split.add_child(threads)
	var view := RichTextLabel.new()
	view.bbcode_enabled = true
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.text = "[b]gamecreate.albion-forums.com[/b]\n\nthe ultimate game developer forum.\nselect a thread on the left."
	split.add_child(view)
	threads.item_selected.connect(func(i: int):
		var th: Dictionary = _forum["FT"][ids[i]]
		var s := "[b][font_size=26]%s[/font_size][/b]\n\n" % _bb(str(th["t"]))
		for p in th["posts"]:
			var mem: Array = _forum["FM"].get(p[0], [p[0], "", ""])
			s += "[color=#1a3a8a][b]%s[/b][/color]  (joined %s)\n%s\n" % [_bb(str(mem[0])), str(mem[1]), _bb(str(p[1]))]
			if p.size() > 2 and p[2] is Array:
				s += "[i]attachment: %s (%d kb)[/i]\n" % [p[2][0], p[2][1]]
			s += "\n-----\n\n"
		view.text = s)
	var w := _add_win("albion net - gamecreate.albion-forums.com", Vector2(1100, 640), split, Vector2(200, 80))
	w.content.theme = null


func _open_chat() -> void:
	if _forum.is_empty():
		return
	var split := HBoxContainer.new()
	var fl := ItemList.new()
	fl.custom_minimum_size = Vector2(190, 0)
	for n in ["quinn_winn", "alice_x0", "terrance_w", "jasOn1"]:
		fl.add_item(n)
	split.add_child(fl)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.scroll_following = true
	_chat_log.text = "[color=#2a8a4a]quinn_winn:[/color] hey, thanks for accepting my friend request!\n"
	right.add_child(_chat_log)
	_chat_btn = Button.new()
	_chat_btn.custom_minimum_size = Vector2(0, 44)
	_chat_btn.pressed.connect(_chat_reply)
	right.add_child(_chat_btn)
	split.add_child(right)
	_chat_step = 0
	_chat_show_choice()
	_add_win("albion chat", Vector2(820, 520), split, Vector2(300, 120))


func _chat_show_choice() -> void:
	var q: Array = _forum["Q"]
	while _chat_step < q.size() and not q[_chat_step].has("u"):
		_chat_step += 1
	if _chat_step >= q.size():
		_chat_btn.text = "(quinn is typing... no. quinn is waiting at the runway.)"
		_chat_btn.disabled = true
	else:
		_chat_btn.text = str(q[_chat_step]["u"])
		_chat_btn.disabled = false


func _chat_reply() -> void:
	var q: Array = _forum["Q"]
	_chat_log.append_text("[color=#8a2a2a]%s:[/color] %s\n" % [user_name, _bb(str(q[_chat_step]["u"]))])
	_chat_step += 1
	_chat_btn.disabled = true
	Sfx.click()
	if _chat_step < q.size() and q[_chat_step].has("q"):
		for line in q[_chat_step]["q"]:
			await get_tree().create_timer(1.1).timeout
			if not is_instance_valid(_chat_log):
				return
			_chat_log.append_text("[color=#2a8a4a]quinn_winn:[/color] %s\n" % _bb(str(line)))
			Sfx.chime()
		_chat_step += 1
	if is_instance_valid(_chat_btn):
		_chat_show_choice()


func _open_settings() -> void:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = "master volume"
	box.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	sl.custom_minimum_size = Vector2(360, 24)
	sl.value_changed.connect(func(v): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001))))
	box.add_child(sl)
	var mute := CheckButton.new()
	mute.text = "mute"
	mute.button_pressed = Sfx.muted
	mute.toggled.connect(func(on): Sfx.set_muted(on))
	box.add_child(mute)
	var fs := CheckButton.new()
	fs.text = "fullscreen"
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	box.add_child(fs)
	_add_win("settings", Vector2(420, 260), box, Vector2(560, 220))
