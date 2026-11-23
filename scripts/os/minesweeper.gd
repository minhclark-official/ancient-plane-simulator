class_name Minesweeper
extends VBoxContainer
## "minefield": beginner / intermediate / expert minesweeper for the albionOS desktop.

const LEVELS := {"beginner": [9, 9, 10], "intermediate": [16, 11, 24], "expert": [30, 16, 99]}
const NUM_COL := [Color.WHITE, Color("#2040ff"), Color("#108010"), Color("#e01010"), Color("#101090"), Color("#801010"), Color("#108080"), Color.BLACK, Color("#606060")]

var w := 9
var h := 9
var mines := 10
var cells: Array = []      # {mine, open, flag, n, btn}
var over := false
var first := true
var _status: Label
var _grid: GridContainer
var _time := 0.0
var _running := false


func _ready() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	for lv in LEVELS:
		var b := Button.new()
		b.text = lv
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(new_game.bind(lv))
		top.add_child(b)
	_status = Label.new()
	add_child(_status)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	add_child(_grid)
	new_game("beginner")


func new_game(lv: String) -> void:
	var cfg: Array = LEVELS[lv]
	w = cfg[0]
	h = cfg[1]
	mines = cfg[2]
	over = false
	first = true
	_time = 0.0
	_running = false
	for c in _grid.get_children():
		c.queue_free()
	cells.clear()
	_grid.columns = w
	for i in w * h:
		var b := Button.new()
		b.custom_minimum_size = Vector2(26, 26)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.gui_input.connect(_on_cell_input.bind(i))
		_grid.add_child(b)
		cells.append({"mine": false, "open": false, "flag": false, "n": 0, "btn": b})
	_update_status()


func _process(dt: float) -> void:
	if _running and not over:
		_time += dt
		_update_status()


func _update_status() -> void:
	var flags := 0
	for c in cells:
		if c["flag"]:
			flags += 1
	_status.text = "mines %d   time %d" % [mines - flags, int(_time)]


func _neighbors(i: int) -> Array:
	var out: Array = []
	var x := i % w
	var y := i / w
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and ny >= 0 and nx < w and ny < h:
				out.append(ny * w + nx)
	return out


func _place(safe: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed := 0
	while placed < mines:
		var k := rng.randi() % (w * h)
		if k == safe or cells[k]["mine"] or _neighbors(safe).has(k):
			continue
		cells[k]["mine"] = true
		placed += 1
	for i in cells.size():
		var n := 0
		for j in _neighbors(i):
			if cells[j]["mine"]:
				n += 1
		cells[i]["n"] = n


func _on_cell_input(ev: InputEvent, i: int) -> void:
	if over or not (ev is InputEventMouseButton) or not ev.pressed:
		return
	var c: Dictionary = cells[i]
	if ev.button_index == MOUSE_BUTTON_RIGHT:
		if not c["open"]:
			c["flag"] = not c["flag"]
			(c["btn"] as Button).text = "F" if c["flag"] else ""
			Sfx.click()
			_update_status()
	elif ev.button_index == MOUSE_BUTTON_LEFT:
		if c["flag"] or c["open"]:
			return
		if first:
			first = false
			_running = true
			_place(i)
		_open(i)
		Sfx.click()
		_check_win()


func _open(i: int) -> void:
	var stack := [i]
	while not stack.is_empty():
		var k: int = stack.pop_back()
		var c: Dictionary = cells[k]
		if c["open"] or c["flag"]:
			continue
		c["open"] = true
		var b: Button = c["btn"]
		b.disabled = true
		if c["mine"]:
			b.text = "*"
			over = true
			_status.text = "BOOM. try again."
			Sfx.thud(0.4)
			for cc in cells:
				if cc["mine"]:
					(cc["btn"] as Button).text = "*"
			return
		if c["n"] > 0:
			b.text = str(c["n"])
			b.add_theme_color_override("font_disabled_color", NUM_COL[c["n"]])
		else:
			for j in _neighbors(k):
				stack.append(j)


func _check_win() -> void:
	if over:
		return
	var closed := 0
	for c in cells:
		if not c["open"]:
			closed += 1
	if closed == mines:
		over = true
		_status.text = "you win!  time %d" % int(_time)
		Sfx.chime()
