extends Node
## Global game state: unlocked endings (saved to disk) and a few cross-scene flags.

const SAVE_PATH := "user://endings.cfg"

const ENDS: Array = [
	{"k": "crash", "t": "belly landing", "d": "flew it into the ground. or landed on the wrong bits."},
	{"k": "fuel", "t": "out of fuel", "d": "the gauge did mention it. several times."},
	{"k": "hull", "t": "came apart", "d": "system integrity hits 0%."},
	{"k": "land", "t": "safe landing at jrna", "d": "autoland, a real runway, a quiet ending."},
	{"k": "nclr", "t": "naicol reactor", "d": "land at nclr, then walk the whole plant."},
	{"k": "finale", "t": "master king", "d": "arrive at the pyramid. regret it."},
	{"k": "secret", "t": "the secret ending", "d": "hidden. something in your bag might help."},
]

var got := {}
## LMIA (home) becomes selectable once the player has landed at NCLR.
var from_nclr := false
## PDA storage (item ids), persisted
var inv: Array = []


func _ready() -> void:
	_load()


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for e in ENDS:
		if cf.get_value("endings", e["k"], false):
			got[e["k"]] = true
	from_nclr = cf.get_value("flags", "from_nclr", false)
	inv = cf.get_value("flags", "inv", [])


func _save() -> void:
	var cf := ConfigFile.new()
	for k in got:
		cf.set_value("endings", k, true)
	cf.set_value("flags", "from_nclr", from_nclr)
	cf.set_value("flags", "inv", inv)
	cf.save(SAVE_PATH)


func unlock(k: String) -> void:
	if got.has(k):
		return
	got[k] = true
	_save()


func set_from_nclr() -> void:
	if from_nclr:
		return
	from_nclr = true
	_save()


func count() -> int:
	var n := 0
	for e in ENDS:
		if got.has(e["k"]):
			n += 1
	return n


func item_count(id: String) -> int:
	var n := 0
	for k in inv:
		if k == id:
			n += 1
	return n


func add_item(id: String) -> bool:
	if not Items.DATA.has(id) or inv.size() >= Items.MAX_ITEMS:
		return false
	inv.append(id)
	_save()
	return true


func drop_item(i: int) -> void:
	if i >= 0 and i < inv.size():
		inv.remove_at(i)
		_save()
