extends Node3D
## NAICOL REACTOR on foot: the full campus (baked from the HTML game's own build code), the plant simulation,
## the SCADA terminals, control-room screens, posters, the site truck, props, alarms and the plant's ambience.

signal pause_requested

const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")
const CAMPUS := "res://assets/campus/campus.scn"
const LOGIC := "res://assets/campus/logic.json"
const NC_CELL := 24
const HAZE := Color("#d6c9a4")
const EYE := 1.7
const K_BG := Color("#05055a")
const K_TX := Color("#d6d2d4")
const K_DIM := Color("#8e8ab8")
const K_AM := Color("#ffd36a")
const K_GR := Color("#58f08a")
const K_RD := Color("#ff5a4a")

const PLANT := {"cx": 80.0, "cz": 30.0, "hx": 445.0, "hz": 335.0}
const ROAD: Array = [[-600.0, 360.0], [-380.0, 360.0], [-380.0, 0.0], [-336.0, 0.0]]
const CANALS: Array = [{"z": 520.0, "x0": -1500.0, "x1": 1400.0, "w": 9.0}, {"z": -540.0, "x0": -1500.0, "x1": 1400.0, "w": 7.0},
	{"x": 690.0, "z0": -1300.0, "z1": 1300.0, "w": 7.0, "v": true}, {"x": -1180.0, "z0": -1300.0, "z1": 1300.0, "w": 6.0, "v": true}]

const CONTROLS_TEXT := "ON FOOT                      SITE TRUCK                   REACTOR CONSOLES\n" + \
	"w a s d   walk               e        get in / out        1-9      switch tabs\n" + \
	"mouse     look               w s      throttle, reverse   mouse    operate\n" + \
	"shift     run                a d      steer               shift a  acknowledge alarms\n" + \
	"space     jump               space    handbrake           esc      close console\n" + \
	"e         use / read         l        headlights\n" + \
	"f         pick up / drop     h        horn\n" + \
	"g         throw it\n" + \
	"u         unstick\n" + \
	"m         minimap\n" + \
	"esc       pause menu\n\n" + \
	"the control room consoles and the supervisor desk open the reactor operating system.\nyou can fly again from the pause menu."

# ------------------------------------------------------------------ state
var reactor := ReactorModel.new()
var logic := {}
var campus: Node3D
var nodes := {}               # baked id -> Node
var P := {"x": -684.0, "y": 0.0, "z": 352.0, "vy": 0.0, "yaw": 0.0, "pitch": 0.0, "vx": 0.0, "vz": 0.0, "bob": 0.0, "air": false, "step": 0}
var t := 0.0
var paused := false
var ready_ := false
var ui_open := false
var show_map := true
var grid := {}                # cell -> Array of colliders
var col: Array = []
var cir: Array = []
var floors: Array = []
var shells: Array = []
var zones: Array = []
var ints: Array = []
var near: Variant = null
var zone_name := ""
var zone_t := 0.0
var step_t := 0.0
var jump_ok := true
var bounds := Rect2(-1060, -800, 2020, 1600)
var hist: Array = []
var safe_t := 0.0
var wind := Vector3(0, 0, -1)
var screens: Array = []       # {painter, vp, mesh, px, pz, next}
var props: Array = []
var held: Dictionary = {}
var crane := {"on": true, "dir": 1.0}
var last_chime := 0
var alarm_sound_t := 0.0
var plane_model: PlaneModel
var pa_shown_until := 0.0
var toast_t := 0.0

# truck
var tr := {"driving": false, "x": -684.0, "z": 343.0, "y": 0.0, "yaw": PI / 2.0, "v": 0.0, "steer": 0.0, "odo": 0.0, "fuel": 100.0, "lights": false,
	"hb": false, "thr": 0.0, "pitch": 0.0, "msg": "", "msg_t": 0.0}
var truck: Node3D
var truck_wheels: Array = []
var truck_sw: MeshInstance3D
var truck_lights: Array = []

# nodes
@onready var cam: Camera3D = $Player/Camera3D
@onready var player: Node3D = $Player
@onready var sun: DirectionalLight3D = $Sun
@onready var wenv: WorldEnvironment = $WorldEnvironment
@onready var hud: CanvasLayer = $HUD
@onready var zone_lab: Label = $HUD/Zone
@onready var status_lab: Label = $HUD/Status
@onready var prompt: Label = $HUD/Prompt
@onready var alarm_lab: Label = $HUD/Alarm
@onready var hint_lab: Label = $HUD/Hint
@onready var toast: Label = $HUD/Toast
@onready var pa_lab: Label = $HUD/Pa
@onready var cross: Control = $HUD/Cross
@onready var info_panel: PanelContainer = $HUD/Info
@onready var info_title: Label = $HUD/Info/Box/Title
@onready var info_body: Label = $HUD/Info/Box/Body
@onready var scada: Control = $HUD/Scada
@onready var minimap: Control = $HUD/Minimap
@onready var dash: Control = $HUD/Dash
@onready var loading: Label = $HUD/Loading

var _amb: AudioStreamPlayer
var _srv: AudioStreamPlayer
var _snd_jump: AudioStreamPlayer
var _snd_g: AudioStreamPlayer
var _snd_c: AudioStreamPlayer
var _eng: AudioStreamPlayer


func _ready() -> void:
	for l in [zone_lab, status_lab, prompt, alarm_lab, hint_lab, toast, pa_lab, info_title, info_body, loading]:
		(l as Label).add_theme_font_override("font", FONT_BOLD)
	zone_lab.add_theme_font_size_override("font_size", 26)
	status_lab.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_font_size_override("font_size", 28)
	alarm_lab.add_theme_font_size_override("font_size", 26)
	hint_lab.add_theme_font_size_override("font_size", 20)
	toast.add_theme_font_size_override("font_size", 24)
	pa_lab.add_theme_font_size_override("font_size", 24)
	info_title.add_theme_font_size_override("font_size", 30)
	loading.add_theme_font_size_override("font_size", 30)
	scada.closed.connect(_on_scada_closed)
	minimap.draw.connect(_draw_minimap)
	dash.draw.connect(_draw_dash)
	cross.draw.connect(_draw_cross)
	info_panel.visible = false
	dash.visible = false
	_setup_env()
	_setup_audio()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	loading.visible = true
	await get_tree().process_frame
	_load_campus()
	loading.visible = false
	ready_ = true
	_snd_jump.stream = Sfx.clip("ncjump")


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for p in [_amb, _srv, _eng]:
		if p:
			(p as AudioStreamPlayer).stop()
	Sfx.siren(false)


func set_paused(p: bool) -> void:
	paused = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (p or ui_open) else Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ environment / audio
func _setup_env() -> void:
	var env := wenv.environment
	var sm := env.sky.sky_material as ProceduralSkyMaterial
	sm.sky_top_color = Color("#4f84d6")
	sm.sky_horizon_color = Color("#e6d8b0")
	sm.ground_horizon_color = Color("#e6d8b0")
	sm.ground_bottom_color = Color("#a89468")
	env.fog_light_color = HAZE
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 260.0
	env.fog_depth_end = 1750.0
	env.fog_density = 1.0
	sun.basis = Basis.looking_at(-Vector3(-0.725, 0.391, 0.567), Vector3.UP)


func _setup_audio() -> void:
	_amb = AudioStreamPlayer.new()
	var s := Sfx.clip("ncamb")
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_amb.stream = s
	_amb.volume_db = -10.0
	add_child(_amb)
	_amb.play()
	_srv = AudioStreamPlayer.new()
	var s2 := Sfx.clip("ncsrv")
	if s2 is AudioStreamOggVorbis:
		(s2 as AudioStreamOggVorbis).loop = true
	_srv.stream = s2
	_srv.volume_db = -80.0
	add_child(_srv)
	_srv.play()
	_snd_jump = AudioStreamPlayer.new()
	add_child(_snd_jump)
	_snd_g = AudioStreamPlayer.new()
	_snd_g.stream = load("res://assets/audio/ncstepg.ogg")
	add_child(_snd_g)
	_snd_c = AudioStreamPlayer.new()
	_snd_c.stream = load("res://assets/audio/ncstepc.ogg")
	add_child(_snd_c)
	_eng = AudioStreamPlayer.new()
	_eng.stream = Sfx._loop_noise(1.5, 0.03)
	_eng.volume_db = -80.0
	add_child(_eng)


# ------------------------------------------------------------------ ground (port of ncGroundH)
func ss(a: float, b: float, x: float) -> float:
	return WorldData.sstep(a, b, x)


func seg_d(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	var dx := bx - ax
	var dz := bz - az
	var l := dx * dx + dz * dz
	var tt := clampf(((px - ax) * dx + (pz - az) * dz) / l, 0.0, 1.0) if l != 0.0 else 0.0
	return Vector2(px - (ax + dx * tt), pz - (az + dz * tt)).length()


func flat_w(x: float, z: float) -> float:
	var dx := maxf(0.0, absf(x - PLANT["cx"]) - PLANT["hx"])
	var dz := maxf(0.0, absf(z - PLANT["cz"]) - PLANT["hz"])
	var w := 1.0 - ss(0.0, 70.0, Vector2(dx, dz).length())
	var rx := maxf(0.0, absf(x + 880.0) - 90.0)
	w = maxf(w, 1.0 - ss(0.0, 60.0, Vector2(rx, maxf(0.0, absf(z - 360.0) - 60.0)).length()))
	w = maxf(w, 1.0 - ss(0.0, 70.0, maxf(0.0, absf(x + 880.0) - 26.0)))
	for i in ROAD.size() - 1:
		w = maxf(w, 1.0 - ss(8.0, 34.0, seg_d(x, z, ROAD[i][0], ROAD[i][1], ROAD[i + 1][0], ROAD[i + 1][1])))
	return w


func canal_d(x: float, z: float) -> float:
	var d := 1e9
	for c in CANALS:
		var dd: float = absf(x - c["x"]) if c.get("v", false) else absf(z - c["z"])
		if dd < d:
			d = dd - c["w"] / 2.0
	return d


func ground_h(x: float, z: float) -> float:
	var fw := flat_w(x, z)
	var h := (WorldData.fbm(x / 310.0 + 11.0, z / 310.0 + 4.0, 3) - 0.5) * 3.4 + (WorldData.fbm(x / 60.0, z / 60.0, 2) - 0.5) * 0.5
	var cd := canal_d(x, z)
	if cd < 9.0:
		h -= 1.3 * (1.0 - ss(0.0, 9.0, cd))
	return h * (1.0 - fw)


func ground_at(x: float, z: float) -> float:
	return maxf(ground_h(x, z), -0.2)


# ------------------------------------------------------------------ loading the baked campus
func _load_campus() -> void:
	var f := FileAccess.open(LOGIC, FileAccess.READ)
	logic = JSON.parse_string(f.get_as_text())
	var ps := load(CAMPUS) as PackedScene
	campus = ps.instantiate()
	add_child(campus)
	_index_nodes(campus)
	col = logic["col"]
	cir = logic["cir"]
	floors = logic["floors"]
	shells = logic["shells"]
	zones = logic["zones"]
	ints = logic["ints"]
	# the aeroplane parked at the airfield
	var sp: Dictionary = logic["planeSpot"] if logic["planeSpot"] != null else {"x": -660.0, "z": 360.0}
	plane_model = PlaneModel.new()
	add_child(plane_model)
	plane_model.set_pose(Vector3(sp["x"], ground_at(sp["x"], sp["z"]) + 4.5, sp["z"]), 0.0, 0.0, 0.0)
	var sx: float = sp["x"]
	var sz: float = sp["z"]
	col.append([sx - 3, sz - 24, sx + 3, sz + 23, 7.2, 1.9])
	col.append([sx - 24, sz - 5, sx - 3, sz + 11, 7.8, 2.6])
	col.append([sx + 3, sz - 5, sx + 24, sz + 11, 7.8, 2.6])
	col.append([sx - 10.8, sz - 3.8, sx - 7.8, sz + 2, 2.9, 0])
	col.append([sx + 7.8, sz - 3.8, sx + 10.8, sz + 2, 2.9, 0])
	cir.append([sx - 3.6, sz + 4.3, 0.7])
	cir.append([sx + 3.6, sz + 4.3, 0.7])
	cir.append([sx, sz - 17.0, 0.8])
	_index_colliders()
	_build_screens()
	_build_props()
	_build_truck()
	P["y"] = ground_at(P["x"], P["z"])
	P["yaw"] = 0.0
	cam.near = 0.2
	cam.far = 3000.0
	cam.fov = 72.0


func _index_nodes(n: Node) -> void:
	for c in n.get_children():
		nodes[int(String(c.name).substr(1))] = c if String(c.name).begins_with("n") and String(c.name).substr(1).is_valid_int() else null
		_index_nodes(c)


func nd(id) -> Node3D:
	if id == null:
		return null
	var k := int(id)
	return nodes.get(k, null)


func _put(key: int, o: Array) -> void:
	if not grid.has(key):
		grid[key] = []
	grid[key].append(o)


func _index_colliders() -> void:
	grid.clear()
	for b in col:
		for gx in range(floori(b[0] / NC_CELL), floori(b[2] / NC_CELL) + 1):
			for gz in range(floori(b[1] / NC_CELL), floori(b[3] / NC_CELL) + 1):
				_put(gx * 4096 + gz, b)
	for c in cir:
		for gx in range(floori((c[0] - c[2]) / NC_CELL), floori((c[0] + c[2]) / NC_CELL) + 1):
			for gz in range(floori((c[1] - c[2]) / NC_CELL), floori((c[1] + c[2]) / NC_CELL) + 1):
				_put(gx * 4096 + gz, c)


## push the point (x,z at height y) out of colliders; returns the corrected Vector2
func collide(px: float, py: float, pz: float, r: float, st := 0.4, ph := 1.78) -> Vector2:
	var gx := floori(px / NC_CELL)
	var gz := floori(pz / NC_CELL)
	for it in 2:
		for ax in range(gx - 1, gx + 2):
			for az in range(gz - 1, gz + 2):
				var a = grid.get(ax * 4096 + az)
				if a == null:
					continue
				for o in a:
					if o.size() == 5 or o.size() == 6:
						if py > o[4] - st:
							continue
						if o.size() == 6 and py + ph < o[5]:
							continue
						var cx := clampf(px, o[0], o[2])
						var cz := clampf(pz, o[1], o[3])
						var dx := px - cx
						var dz := pz - cz
						var d2 := dx * dx + dz * dz
						if d2 < r * r:
							if d2 > 1e-8:
								var d := sqrt(d2)
								var k := (r - d) / d
								px += dx * k
								pz += dz * k
							else:
								var l: float = px - o[0]
								var rr: float = o[2] - px
								var tt: float = pz - o[1]
								var bb: float = o[3] - pz
								var m := minf(minf(l, rr), minf(tt, bb))
								if m == l:
									px = o[0] - r
								elif m == rr:
									px = o[2] + r
								elif m == tt:
									pz = o[1] - r
								else:
									pz = o[3] + r
					else:
						var dx2: float = px - o[0]
						var dz2: float = pz - o[1]
						var d3 := sqrt(dx2 * dx2 + dz2 * dz2)
						var mm: float = o[2] + r
						if d3 < mm:
							var k2 := (mm - d3) / d3 if d3 > 1e-6 else 0.0
							if k2 != 0.0:
								px += dx2 * k2
								pz += dz2 * k2
							else:
								px += mm
	return Vector2(px, pz)


# ------------------------------------------------------------------ screens / props / truck
func _build_screens() -> void:
	for s in logic["scr"]:
		var mesh := nd(s["mid"]) as MeshInstance3D
		if mesh == null:
			continue
		var pw := 256
		var ph := maxi(48, int(round(256.0 * float(s["ph"]) / float(s["pw"]) / 8.0)) * 8)
		var vp := SubViewport.new()
		vp.size = Vector2i(pw, ph)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.disable_3d = true
		var pn := NcScreen.new()
		pn.kind = s["kind"]
		pn.arg = int(s["arg"])
		pn.reactor = reactor
		pn.size = Vector2(pw, ph)
		vp.add_child(pn)
		add_child(vp)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = vp.get_texture()
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mesh.material_override = m
		screens.append({"p": pn, "vp": vp, "px": s["px"], "pz": s["pz"], "next": randf() * 0.3})


func _build_props() -> void:
	for p in logic["propList"]:
		var n := nd(p["mid"])
		if n == null:
			continue
		props.append({"n": n, "kind": p["kind"], "name": p.get("name", p["kind"]), "x": p["x"], "z": p["z"], "y": p["y"], "r": p["r"],
			"h": p.get("h", 0.5), "vx": 0.0, "vz": 0.0, "vy": 0.0, "fly": false})


func _bx(parent: Node3D, w: float, h: float, d: float, c: Color, x: float, y: float, z: float, emis := Color.BLACK) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.roughness = 1.0
	if emis != Color.BLACK:
		mt.emission_enabled = true
		mt.emission = emis
	mi.material_override = mt
	mi.position = Vector3(x, y, z)
	parent.add_child(mi)
	return mi


func _build_truck() -> void:
	truck = Node3D.new()
	add_child(truck)
	var body := Color("#bdb9ac")
	var org := Color("#d9702a")
	var dark := Color("#26282c")
	var glass := Color("#1a2a38")
	var chrome := Color("#9a9ea4")
	var seat := Color("#5a4a3a")
	_bx(truck, 1.7, 0.44, 4.8, dark, 0, 0.76, 0)
	_bx(truck, 1.84, 0.76, 1.72, body, 0, 1.04, -1.56)
	_bx(truck, 1.3, 0.34, 0.05, dark, 0, 1.02, -2.43)
	_bx(truck, 1.94, 0.09, 0.3, org, 0, 1.43, -2.3)
	_bx(truck, 1.86, 1.34, 1.78, body, 0, 1.37, 0.1)
	_bx(truck, 1.9, 0.46, 1.5, glass, 0, 1.8, 0.1, Color("#06101a"))
	for sx in [-0.93, 0.93]:
		_bx(truck, 0.06, 0.5, 0.06, body, sx, 1.8, 0.92)
	_bx(truck, 2.0, 0.1, 1.95, org, 0, 2.09, 0.1)
	_bx(truck, 1.86, 0.2, 1.52, org, 0, 1.04, 1.7)
	_bx(truck, 0.1, 0.6, 1.52, org, 0.88, 1.44, 1.7)
	_bx(truck, 0.1, 0.6, 1.52, org, -0.88, 1.44, 1.7)
	_bx(truck, 1.86, 0.6, 0.1, org, 0, 1.44, 2.43)
	_bx(truck, 1.66, 0.6, 0.1, org, 0, 1.44, 1.0)
	for s in [-1.0, 1.0]:
		_bx(truck, 0.12, 0.2, 0.34, dark, s * 0.6, 0.52, -2.32)
		_bx(truck, 0.12, 0.2, 0.34, dark, s * 0.6, 0.52, 2.32)
		truck_lights.append(_bx(truck, 0.34, 0.2, 0.1, Color("#fff2b0"), s * 0.68, 1.2, -2.44, Color("#403818")))
		_bx(truck, 0.3, 0.18, 0.1, Color("#c01818"), s * 0.72, 1.28, 2.5, Color("#300000"))
	_bx(truck, 2.0, 0.15, 0.3, chrome, 0, 0.52, -2.54)
	_bx(truck, 2.0, 0.15, 0.3, chrome, 0, 0.52, 2.54)
	_bx(truck, 1.6, 0.2, 0.4, Color("#34363c"), 0, 1.28, -0.7)
	_bx(truck, 0.5, 0.1, 0.5, seat, -0.45, 1.05, 0.5)
	_bx(truck, 0.5, 0.62, 0.12, seat, -0.45, 1.4, 0.78)
	_bx(truck, 0.5, 0.1, 0.5, seat, 0.45, 1.05, 0.5)
	_bx(truck, 0.5, 0.62, 0.12, seat, 0.45, 1.4, 0.78)
	truck_sw = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.14
	tm.outer_radius = 0.2
	truck_sw.mesh = tm
	var smt := StandardMaterial3D.new()
	smt.albedo_color = dark
	truck_sw.material_override = smt
	truck_sw.position = Vector3(-0.45, 1.52, -0.35)
	truck_sw.rotation.x = -0.9
	truck.add_child(truck_sw)
	for sx in [-1.0, 1.0]:
		for sz in [-1.5, 1.5]:
			var g := Node3D.new()
			g.position = Vector3(sx * 0.98, 0.44, sz)
			var cyl := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.44
			cm.bottom_radius = 0.44
			cm.height = 0.32
			cm.radial_segments = 12
			cyl.mesh = cm
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color("#151515")
			cyl.material_override = wm
			cyl.rotation.z = PI / 2.0
			g.add_child(cyl)
			_bx(g, 0.34, 0.5, 0.1, chrome, 0, 0, 0)
			truck.add_child(g)
			truck_wheels.append({"g": g, "cyl": cyl, "front": sz < 0.0})
	_place_truck()
	ints.append({"x": tr["x"], "y": 0.0, "z": tr["z"], "r": 5.2, "label": "drive the site truck", "kind": "", "box": null, "reach": null, "act": [], "truck": true})


func _place_truck() -> void:
	var f := Vector2(sin(tr["yaw"]), -cos(tr["yaw"]))
	var fr := ground_at(tr["x"] + f.x * 1.5, tr["z"] + f.y * 1.5)
	var bk := ground_at(tr["x"] - f.x * 1.5, tr["z"] - f.y * 1.5)
	tr["y"] = (fr + bk) / 2.0
	tr["pitch"] = atan2(fr - bk, 3.0)
	truck.position = Vector3(tr["x"], tr["y"], tr["z"])
	truck.basis = Basis.from_euler(Vector3(tr["pitch"], -tr["yaw"], 0.0), EULER_ORDER_YXZ)


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if paused or not ready_:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not ui_open:
		var mm := event as InputEventMouseMotion
		P["yaw"] += mm.relative.x * 0.0022
		P["pitch"] = clampf(P["pitch"] - mm.relative.y * 0.0022, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed and not ui_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		var c := (event as InputEventKey).physical_keycode
		if scada.visible:
			return
		if info_panel.visible:
			if c == KEY_ESCAPE or c == KEY_E or c == KEY_ENTER or c == KEY_SPACE:
				_close_info()
			return
		match c:
			KEY_ESCAPE:
				pause_requested.emit()
			KEY_E:
				if tr["driving"]:
					_truck_exit()
				else:
					_interact()
			KEY_F:
				_grab()
			KEY_G:
				_throw()
			KEY_U:
				if not tr["driving"]:
					_unstick(false)
			KEY_L:
				if tr["driving"]:
					tr["lights"] = not tr["lights"]
			KEY_H:
				if tr["driving"]:
					Sfx.chime()
			KEY_M:
				show_map = not show_map
				minimap.visible = show_map
			KEY_TAB:
				_show_info("controls", CONTROLS_TEXT)
				get_viewport().set_input_as_handled()


func _key(c: int) -> bool:
	return Input.is_physical_key_pressed(c as Key)


# ------------------------------------------------------------------ info panel / scada / interactions
func _show_info(title: String, body: String) -> void:
	info_title.text = title
	info_body.text = body
	var fs := 25
	info_body.add_theme_font_size_override("font_size", fs)
	info_panel.visible = true
	ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame
	while fs > 14 and info_panel.size.y > 840.0:
		fs -= 1
		info_body.add_theme_font_size_override("font_size", fs)
		info_panel.reset_size()
		await get_tree().process_frame


func _close_info() -> void:
	info_panel.visible = false
	ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_scada(tab: String) -> void:
	ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scada.tab = tab
	scada.open(reactor)


func _on_scada_closed() -> void:
	ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _chem_sheet() -> String:
	var s := ""
	for i in 2:
		var u: Dictionary = reactor.units[i]
		var li := maxf(0.7, 2.4 - u["boron"] / 900.0)
		var ph := 7.05 + 0.12 * sin(t / 90.0 + i)
		s += "unit %d  %s\nboron %.0f ppm   lithium %.2f ppm\nph %.2f   hydrogen %.1f cc/kg\nactivity %.2f mbq/g   chloride <0.05 ppm\n\n" % [i + 1, "shut down" if u["scram"] else "on line", u["boron"], li, ph, 34.0 + 3.0 * sin(t / 60.0 + i), 0.4 if u["scram"] else 1.1 + 0.1 * sin(t / 40.0)]
	return s + "all values within limits."


func _run_act(it: Dictionary) -> void:
	if it.get("truck", false):
		_truck_enter()
		return
	var src := str(it.get("src", ""))
	if src.contains("CR.on"):
		crane["on"] = not crane["on"]
		Sfx.play("blip", -6.0, 1.3 if crane["on"] else 0.8)
		return
	for a in it["act"]:
		if a.has("read"):
			var info: Dictionary = a["read"]
			var title := str(info["title"])
			if title == "primary coolant: sample results":
				_show_info(title, _chem_sheet())
			else:
				_show_info(title, str(info.get("body", _strip(str(info.get("html", ""))))))
			return
		if a.has("open"):
			_open_scada(str(a["open"]))
			return
		if a.has("tp"):
			var tp: Array = a["tp"]
			P["x"] = tp[0]
			P["z"] = tp[1]
			P["yaw"] = tp[2] if tp[2] != null else P["yaw"]
			P["y"] = ground_at(P["x"], P["z"])
			P["vy"] = 0.0
			return
	for a in it["act"]:
		if a.has("nr"):
			match str(a["nr"]):
				"testDiesel":
					reactor.test_diesel(int(a["args"][0]))
				"toggleBay":
					reactor.toggle_bay(int(a["args"][0]))
				"drillSiren":
					reactor.drill_siren()
				"ackAll":
					reactor.ack_all()
	Sfx.play("blip", -6.0)


func _strip(s: String) -> String:
	var rx := RegEx.new()
	rx.compile("<[^>]*>")
	return rx.sub(s.replace("</p>", "\n").replace("<br>", "\n"), "", true)


func _interact() -> void:
	if near != null and not scada.visible:
		if near is Dictionary and near.get("prop", false):
			return
		_run_act(near)


func _ray_box(o: Vector3, d: Vector3, b: Array) -> float:
	var t0 := 0.0
	var t1 := 1e9
	var lo := [b[0], b[4], b[1]]
	var hi := [b[2], b[5], b[3]]
	var oo := [o.x, o.y, o.z]
	var dd := [d.x, d.y, d.z]
	for k in 3:
		if absf(dd[k]) < 1e-9:
			if oo[k] < lo[k] or oo[k] > hi[k]:
				return -1.0
		else:
			var a: float = (lo[k] - oo[k]) / dd[k]
			var c: float = (hi[k] - oo[k]) / dd[k]
			if a > c:
				var q := a
				a = c
				c = q
			if a > t0:
				t0 = a
			if c < t1:
				t1 = c
			if t0 > t1:
				return -1.0
	return t0


func _nearest() -> Variant:
	var fx := sin(P["yaw"])
	var fz := -cos(P["yaw"])
	var best = null
	var bd := 1e9
	var cp := cos(P["pitch"])
	var o := Vector3(P["x"], P["y"] + EYE, P["z"])
	var d := Vector3(fx * cp, sin(P["pitch"]), fz * cp)
	for it in ints:
		if it["box"] == null:
			continue
		var tt := _ray_box(o, d, it["box"])
		var reach: float = it["reach"] if it["reach"] != null else 3.8
		if tt >= 0.0 and tt <= reach and tt - 20.0 < bd:
			bd = tt - 20.0
			best = it
	if best != null:
		return best
	for it in ints:
		if it["box"] != null:
			continue
		var dx: float = it["x"] - P["x"]
		var dz: float = it["z"] - P["z"]
		var dist := sqrt(dx * dx + dz * dz)
		if dist > it["r"] or absf(float(it["y"] if it["y"] != null else 1.2) - (P["y"] + 1.2)) > 6.0:
			continue
		var dot := (dx * fx + dz * fz) / dist if dist > 0.01 else 1.0
		if dist > it["r"] * 0.55 and dot < 0.1:
			continue
		var sc := dist - dot * 2.0
		if sc < bd:
			bd = sc
			best = it
	return best


# ------------------------------------------------------------------ props (pick up, throw)
func _prop_hint() -> Variant:
	if not held.is_empty():
		return {"label": "drop it [f]   throw [g]", "raw": true, "prop": true}
	var fx := sin(P["yaw"])
	var fz := -cos(P["yaw"])
	var best = null
	var bd := 1e9
	for p in props:
		var dx: float = p["x"] - P["x"]
		var dz: float = p["z"] - P["z"]
		var d := sqrt(dx * dx + dz * dz)
		if d > 3.0:
			continue
		var dot := (dx * fx + dz * fz) / maxf(d, 0.01)
		if dot < 0.55:
			continue
		if d < bd:
			bd = d
			best = p
	if best != null:
		return {"label": "[f] pick up: " + str(best["name"]), "raw": true, "prop": true, "p": best}
	return null


func _grab() -> void:
	if not held.is_empty():
		held["fly"] = true
		held["vx"] = 0.0
		held["vz"] = 0.0
		held["vy"] = 0.0
		held = {}
		return
	var h: Variant = _prop_hint()
	if h != null and (h as Dictionary).has("p"):
		held = (h as Dictionary)["p"]
		held["fly"] = false
		Sfx.click()


func _throw() -> void:
	if held.is_empty():
		return
	var cp := cos(P["pitch"])
	held["vx"] = sin(P["yaw"]) * cp * 9.0
	held["vz"] = -cos(P["yaw"]) * cp * 9.0
	held["vy"] = sin(P["pitch"]) * 9.0 + 2.0
	held["fly"] = true
	held = {}
	Sfx.play("thud", -6.0, 1.4)


func _prop_ground(x: float, z: float) -> float:
	var g := ground_at(x, z)
	for s in shells:
		if x > s[0] and x < s[2] and z > s[1] and z < s[3] and s[4] > g:
			g = s[4]
	return g


func _update_props(dt: float) -> void:
	for p in props:
		var n: Node3D = p["n"]
		if not held.is_empty() and is_same(p, held):
			var cp := cos(P["pitch"])
			var f := Vector3(sin(P["yaw"]) * cp, sin(P["pitch"]), -cos(P["yaw"]) * cp)
			var pos := Vector3(P["x"], P["y"] + EYE - 0.3, P["z"]) + f * 1.1
			p["x"] = pos.x
			p["z"] = pos.z
			p["y"] = maxf(pos.y - 0.2, _prop_ground(pos.x, pos.z))
		elif p["fly"]:
			p["vy"] -= 13.0 * dt
			p["x"] += p["vx"] * dt
			p["z"] += p["vz"] * dt
			p["y"] += p["vy"] * dt
			var g := _prop_ground(p["x"], p["z"])
			if p["y"] <= g:
				p["y"] = g
				if absf(p["vy"]) > 2.0:
					p["vy"] = -p["vy"] * 0.3
					p["vx"] *= 0.6
					p["vz"] *= 0.6
				else:
					p["vy"] = 0.0
					p["vx"] *= 0.85
					p["vz"] *= 0.85
					if absf(p["vx"]) + absf(p["vz"]) < 0.1:
						p["fly"] = false
		else:
			# a walking player nudges loose props
			var dx: float = p["x"] - P["x"]
			var dz: float = p["z"] - P["z"]
			var d := sqrt(dx * dx + dz * dz)
			var m: float = p["r"] + 0.42
			if d < m and d > 0.001 and absf(float(p["y"]) - float(P["y"])) < 1.2:
				p["x"] += dx / d * (m - d)
				p["z"] += dz / d * (m - d)
				p["y"] = _prop_ground(p["x"], p["z"])
		n.position = Vector3(p["x"], p["y"], p["z"])


# ------------------------------------------------------------------ truck
func _truck_enter() -> void:
	if tr["driving"] or not ready_:
		return
	tr["driving"] = true
	tr["v"] = 0.0
	P["yaw"] = tr["yaw"]
	P["pitch"] = 0.0
	dash.visible = true
	_tsay("w/s drive  a/d steer  space brake  e exit")
	Sfx.play("blip", -6.0)


func _truck_exit() -> void:
	if not tr["driving"]:
		return
	if absf(tr["v"]) > 3.2:
		_tsay("stop the truck first")
		return
	tr["driving"] = false
	tr["v"] = 0.0
	dash.visible = false
	_eng.volume_db = -80.0
	var rx := cos(tr["yaw"])
	var rz := sin(tr["yaw"])
	P["x"] = tr["x"] - rx * 2.4
	P["z"] = tr["z"] - rz * 2.4
	P["y"] = ground_at(P["x"], P["z"])
	P["vx"] = 0.0
	P["vz"] = 0.0
	P["vy"] = 0.0
	P["yaw"] = tr["yaw"]
	P["pitch"] = 0.0
	var c := collide(P["x"], P["y"], P["z"], 0.42)
	P["x"] = c.x
	P["z"] = c.y
	near = null


func _tsay(s: String) -> void:
	tr["msg"] = s
	tr["msg_t"] = 4.0


const RING: Array = [[-2.0, -0.4], [-2.0, 0.4], [-1.0, -0.4], [-1.0, 0.4], [0.0, -0.4], [0.0, 0.4], [1.0, -0.4], [1.0, 0.4], [2.0, -0.4], [2.0, 0.4], [-2.3, 0.0], [2.3, 0.0], [0.0, 0.0]]


func _truck_update(dt: float) -> void:
	var th := (1.0 if (_key(KEY_W) or _key(KEY_UP)) else 0.0) - (1.0 if (_key(KEY_S) or _key(KEY_DOWN)) else 0.0)
	tr["thr"] = th
	tr["hb"] = _key(KEY_SPACE)
	var v: float = tr["v"]
	var a := 0.0
	if th > 0.0:
		a = -signf(v) * 16.0 if v < 0.0 else 7.2 * maxf(0.0, 1.0 - v / 33.0)
	elif th < 0.0:
		a = -16.0 if v > 0.4 else (-3.6 if v > -9.0 else 0.0)
	else:
		a = -signf(v) * minf(absf(v) / dt, 1.4 + 0.012 * v * v)
	if tr["hb"]:
		a = -signf(v) * minf(absf(v) / dt, 22.0)
	tr["v"] += a * dt
	if absf(tr["v"]) < 0.05 and th == 0.0:
		tr["v"] = 0.0
	var tgt := (1.0 if (_key(KEY_D) or _key(KEY_RIGHT)) else 0.0) - (1.0 if (_key(KEY_A) or _key(KEY_LEFT)) else 0.0)
	var mx := 0.62 / (1.0 + absf(tr["v"]) * 0.09)
	tr["steer"] += (tgt * mx - tr["steer"]) * minf(1.0, dt * 6.0)
	tr["yaw"] += tr["v"] / 3.1 * tan(tr["steer"]) * dt
	var f := Vector2(sin(tr["yaw"]), -cos(tr["yaw"]))
	tr["x"] += f.x * tr["v"] * dt
	tr["z"] += f.y * tr["v"] * dt
	var r := Vector2(cos(tr["yaw"]), sin(tr["yaw"]))
	var gy := ground_at(tr["x"], tr["z"])
	var tx := 0.0
	var tz := 0.0
	for it in 2:
		for q in RING:
			var qx: float = tr["x"] + tx + f.x * q[0] + r.x * q[1]
			var qz: float = tr["z"] + tz + f.y * q[0] + r.y * q[1]
			var c := collide(qx, gy, qz, 0.55)
			tx += c.x - qx
			tz += c.y - qz
	var hit := sqrt(tx * tx + tz * tz)
	if hit > 0.0:
		tr["x"] += tx * 0.85
		tr["z"] += tz * 0.85
		if hit > 0.02:
			tr["v"] *= maxf(0.2, 1.0 - hit * 4.0)
	tr["x"] = clampf(tr["x"], bounds.position.x, bounds.end.x)
	tr["z"] = clampf(tr["z"], bounds.position.y, bounds.end.y)
	tr["odo"] += absf(tr["v"]) * dt
	tr["fuel"] = maxf(0.0, tr["fuel"] - absf(tr["v"]) * dt / 1500.0 * (1.0 if th != 0.0 else 0.2))
	for w in truck_wheels:
		(w["cyl"] as Node3D).rotation.x += tr["v"] * dt / 0.44
		if w["front"]:
			(w["g"] as Node3D).rotation.y = -tr["steer"] * 0.9
	truck_sw.rotation.z = -tr["steer"] * 3.0
	_place_truck()
	P["x"] = tr["x"]
	P["z"] = tr["z"]
	P["y"] = tr["y"]
	P["vx"] = f.x * tr["v"]
	P["vz"] = f.y * tr["v"]
	P["vy"] = 0.0
	P["air"] = false
	var dy := wrapf(tr["yaw"] - P["yaw"], -PI, PI)
	P["yaw"] += dy * minf(1.0, dt * (2.4 + absf(tr["v"]) * 0.06))
	P["pitch"] *= maxf(0.0, 1.0 - dt * 1.5)
	var rate := absf(tr["v"]) / 33.0
	_eng.pitch_scale = 0.4 + rate * 1.4 + (0.15 if th > 0.0 else 0.0)
	_eng.volume_db = linear_to_db(0.05 + 0.2 * rate)
	if not _eng.playing:
		_eng.play()


# ------------------------------------------------------------------ frame
func _process(dt: float) -> void:
	if paused or not ready_:
		return
	dt = minf(dt, 0.05)
	t += dt
	reactor.step_fixed(dt)
	wind = reactor.wind
	if tr["driving"] and not ui_open:
		_truck_update(dt)
	elif not ui_open:
		_walk(dt)
	_update_props(dt)
	# camera
	if tr["driving"]:
		var f := Vector2(sin(tr["yaw"]), -cos(tr["yaw"]))
		var r := Vector2(cos(tr["yaw"]), sin(tr["yaw"]))
		var sh := (randf() - 0.5) * 0.004 * minf(1.0, absf(tr["v"]) / 20.0)
		cam.global_position = Vector3(tr["x"] - r.x * 0.45 + f.x * 0.05, tr["y"] + 1.98 + sh, tr["z"] - r.y * 0.45 + f.y * 0.05)
		cam.global_rotation = Vector3(P["pitch"] + tr["pitch"] * 0.6, -P["yaw"], -tr["steer"] * tr["v"] * 0.004)
	else:
		var bob_y := sin(P["bob"]) * 0.045 * minf(1.0, Vector2(P["vx"], P["vz"]).length() / 4.0)
		cam.global_position = Vector3(P["x"], P["y"] + EYE + bob_y, P["z"])
		cam.global_rotation = Vector3(P["pitch"], -P["yaw"], 0.0)
	zone_t -= dt
	if zone_t <= 0.0:
		zone_t = 0.25
		zone_name = _zone_at()
	near = null
	if not ui_open and not tr["driving"]:
		near = _nearest()
		if near == null:
			near = _prop_hint()
	# the truck's interaction point follows it
	for it in ints:
		if it.get("truck", false):
			it["x"] = tr["x"]
			it["z"] = tr["z"]
			it["r"] = 0.0 if tr["driving"] else 4.2
	_animate(dt)
	_update_screens(dt)
	_safety(dt)
	_hud(dt)
	_audio(dt)
	if scada.visible:
		scada.queue_redraw()


func _walk(dt: float) -> void:
	var look := 1.9 * dt
	if _key(KEY_LEFT):
		P["yaw"] -= look
	if _key(KEY_RIGHT):
		P["yaw"] += look
	if _key(KEY_UP):
		P["pitch"] = minf(1.45, P["pitch"] + look)
	if _key(KEY_DOWN):
		P["pitch"] = maxf(-1.45, P["pitch"] - look)
	var mx := 0.0
	var mz := 0.0
	if _key(KEY_W):
		mz += 1.0
	if _key(KEY_S):
		mz -= 1.0
	if _key(KEY_D):
		mx += 1.0
	if _key(KEY_A):
		mx -= 1.0
	var sprint := _key(KEY_SHIFT)
	var sp := 8.4 if sprint else 4.6
	var fx := sin(P["yaw"])
	var fz := -cos(P["yaw"])
	var rx := cos(P["yaw"])
	var rz := sin(P["yaw"])
	var tx := fx * mz + rx * mx
	var tz := fz * mz + rz * mx
	var l := sqrt(tx * tx + tz * tz)
	if l > 1.0:
		tx /= l
		tz /= l
	var acc := 1.0 - exp(-dt * (2.5 if P["air"] else 12.0))
	P["vx"] += (tx * sp - P["vx"]) * acc
	P["vz"] += (tz * sp - P["vz"]) * acc
	P["x"] += P["vx"] * dt
	P["z"] += P["vz"] * dt
	var gy := ground_at(P["x"], P["z"])
	if _key(KEY_SPACE) and not P["air"] and jump_ok:
		P["vy"] = 4.4
		P["air"] = true
		_snd_jump.play()
	jump_ok = not _key(KEY_SPACE)
	P["vy"] -= 13.0 * dt
	P["y"] += P["vy"] * dt
	if P["y"] <= gy:
		if P["air"] and P["vy"] < -2.4:
			Sfx.thud(minf(1.0, -P["vy"] / 8.0))
		P["y"] = gy
		P["vy"] = 0.0
		P["air"] = false
	elif P["y"] > gy + 0.05:
		P["air"] = true
	var c := collide(P["x"], P["y"], P["z"], 0.42)
	P["x"] = c.x
	P["z"] = c.y
	_truck_push_out()
	P["x"] = clampf(P["x"], bounds.position.x, bounds.end.x)
	P["z"] = clampf(P["z"], bounds.position.y, bounds.end.y)
	var spd := Vector2(P["vx"], P["vz"]).length()
	if not P["air"] and spd > 0.5:
		P["bob"] += dt * spd * 1.5
		var st := floori(P["bob"] / PI)
		if st != P["step"]:
			P["step"] = st
			_footstep()
	else:
		P["bob"] *= 0.9


func _footstep() -> void:
	var on_c := false
	for fl in floors:
		if P["x"] >= fl[0] and P["x"] <= fl[2] and P["z"] >= fl[1] and P["z"] <= fl[3]:
			on_c = true
			break
	(_snd_c if on_c else _snd_g).play()


func _truck_push_out() -> void:
	var sy := sin(tr["yaw"])
	var cy := cos(tr["yaw"])
	var dx: float = P["x"] - tr["x"]
	var dz: float = P["z"] - tr["z"]
	var lf := dx * sy - dz * cy
	var lr := dx * cy + dz * sy
	var hf := 2.75 + 0.42
	var hr := 1.08 + 0.42
	if absf(lf) < hf and absf(lr) < hr:
		if hf - absf(lf) < hr - absf(lr):
			lf = (-1.0 if lf < 0.0 else 1.0) * hf
		else:
			lr = (-1.0 if lr < 0.0 else 1.0) * hr
		P["x"] = tr["x"] + lf * sy + lr * cy
		P["z"] = tr["z"] - lf * cy + lr * sy


func _zone_at() -> String:
	var best := ""
	var ba := 1e12
	for z in zones:
		if P["x"] >= z["x0"] and P["x"] <= z["x1"] and P["z"] >= z["z0"] and P["z"] <= z["z1"]:
			var a: float = (z["x1"] - z["x0"]) * (z["z1"] - z["z0"])
			if a < ba:
				ba = a
				best = z["name"]
	if best != "":
		return best
	return "nclr runway" if absf(P["x"] + 880.0) < 60.0 else "grass plains"


func _unstick(quiet: bool) -> void:
	var h: Dictionary = hist[maxi(0, hist.size() - 4)] if hist.size() >= 4 else (hist[0] if hist.size() > 0 else {"x": -684.0, "z": 352.0})
	P["x"] = h["x"]
	P["z"] = h["z"]
	P["y"] = ground_at(P["x"], P["z"])
	P["vx"] = 0.0
	P["vz"] = 0.0
	P["vy"] = 0.0
	P["air"] = false
	held = {}
	if not quiet:
		toast.text = "back on safe ground"
		toast_t = 2.5


func _safety(dt: float) -> void:
	if tr["driving"]:
		return
	if not is_finite(P["x"] + P["y"] + P["z"]) or P["y"] < -6.0:
		if not is_finite(P["x"] + P["z"]):
			P["x"] = -684.0
			P["z"] = 352.0
		P["y"] = 0.0
		_unstick(true)
		return
	safe_t -= dt
	if safe_t <= 0.0:
		safe_t = 1.0
		if not P["air"]:
			var l = hist[hist.size() - 1] if hist.size() > 0 else null
			if l == null or Vector2(l["x"] - P["x"], l["z"] - P["z"]).length() > 1.5:
				hist.append({"x": P["x"], "z": P["z"]})
				if hist.size() > 30:
					hist.pop_front()


# ------------------------------------------------------------------ animation
func _update_screens(dt: float) -> void:
	for s in screens:
		s["next"] -= dt
		if s["next"] > 0.0:
			continue
		var d := Vector2(s["px"] - P["x"], s["pz"] - P["z"]).length()
		if d > 70.0:
			s["next"] = 1.0
			continue
		s["next"] = 0.25 if d < 20.0 else 0.6
		(s["p"] as NcScreen).wnd = wind
		(s["p"] as NcScreen).queue_redraw()
		(s["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE


func _animate(dt: float) -> void:
	var ex: Dictionary = logic["extra"]
	var U: Array = reactor.units
	for a in logic["anims"]:
		var ty: String = a["type"]
		var o := nd(a["o"]["ref"]) if a.has("o") else null
		if o == null:
			continue
		if ty == "blink":
			o.visible = int(t * 1.0 + o.position.x * 0.01) % 2 == 0
		elif ty == "crane":
			var sp: float = float(a.get("slow", 1.0)) * 0.06
			var f := 0.5 + 0.5 * sin(t * sp + a["ph"])
			o.position.x = a["x0"] + (a["x1"] - a["x0"]) * f
			if a.get("tr") != null:
				var tro := nd(a["tr"]["ref"])
				var tz: float = sin(t * sp * 2.3 + a["ph"] * 1.3) * a["tz"]
				tro.position.z = tz
				if a.get("hook") != null:
					nd(a["hook"]["ref"]).position.z = tz
				if a.get("cab") != null:
					nd(a["cab"]["ref"]).position.z = tz
					var lf: float = a["lift"] * (0.5 + 0.5 * sin(t * sp * 3.1 + a["ph"]))
					var hy: float = a["hy0"] + lf
					nd(a["hook"]["ref"]).position.y = hy
					var bot := hy + 0.8
					var ln: float = a["top"] - bot
					var cab := nd(a["cab"]["ref"])
					cab.scale.y = ln / a["ch"]
					cab.position.y = bot + ln / 2.0
		elif ty == "shaft":
			o.rotation.x += dt * U[int(a["u"])]["rpm"] / 60.0 * 0.6
	# the workshop's overhead crane (toggled with [e])
	if ex["crane"] != null and crane["on"]:
		var cr := nd(ex["crane"]["g"])
		cr.position.x += crane["dir"] * 1.6 * dt
		if cr.position.x > 124.0:
			cr.position.x = 124.0
			crane["dir"] = -1.0
		if cr.position.x < 84.0:
			cr.position.x = 84.0
			crane["dir"] = 1.0
		var tz2 := sin(t * 0.4) * 7.0
		nd(ex["crane"]["tr"]).position.z = tz2
		nd(ex["crane"]["ch"]).position.z = tz2
		nd(ex["crane"]["hk"]).position.z = tz2
	# cooling tower plumes
	for pf in ex["puffs"]:
		var tw: Dictionary = reactor.tw[int(pf["tw"]) * 2]
		var tw2: Dictionary = reactor.tw[int(pf["tw"]) * 2 + 1]
		var pl: float = (tw["plume"] + tw2["plume"]) / 2.0
		for q in pf["sp"]:
			var s := nd(q["s"])
			if s == null:
				continue
			var a2 := fmod(t * 0.045 + q["ph"], 1.0)
			s.position = Vector3(pf["tx"] + wind.x * a2 * 160.0 * (0.5 + wind.y / 6.0) + sin(q["ph"] * 40.0) * 8.0 * a2,
				96.0 + a2 * (58.0 + pl * 34.0), pf["tz"] + wind.z * a2 * 160.0 * (0.5 + wind.y / 6.0))
			var sz := 16.0 + a2 * 58.0 * (0.6 + pl * 0.4)
			s.scale = Vector3(sz, sz * 0.82, 1.0)
			var mat := (s as MeshInstance3D).material_override as StandardMaterial3D
			mat.albedo_color.a = maxf(0.0, sin(PI * pow(a2, 0.6))) * 0.85 * minf(1.0, pl * 1.2)
	for c in ex["clouds"]:
		var cn := nd(c)
		if cn:
			cn.position.x += (1.0 + wind.y * 0.2) * dt * 3.0
			if cn.position.x > 2200.0:
				cn.position.x = -2200.0
	var sock := nd(ex["sock"])
	if sock:
		sock.rotation.y = atan2(-wind.z, wind.x)
		for i in sock.get_child_count():
			(sock.get_child(i) as Node3D).position.y = -0.02 * i * (6.0 - wind.y)
	for tid in ex["turbs"]:
		var tn := nd(tid)
		if tn:
			tn.rotation.z += dt * 0.4 * (0.4 + wind.y * 0.25)
	var ps := nd(ex["poolSurf"])
	if ps:
		var pm := (ps as MeshInstance3D).material_override as StandardMaterial3D
		pm.uv1_offset.x = t * 0.01
	_alarm_beacons(dt)
	# plant sounds
	if reactor.chime != last_chime:
		if last_chime != 0 or reactor.chime != 0:
			Sfx.play("blip", -6.0, 1.5)
		last_chime = reactor.chime
	alarm_sound_t -= dt
	if reactor.crit and alarm_sound_t <= 0.0:
		alarm_sound_t = 2.2
		Sfx.play("warn", -4.0)
	if not reactor.crit:
		alarm_sound_t = 0.0


func _alarm_active() -> bool:
	if reactor.crit or reactor.t < reactor.siren_until:
		return true
	if not reactor.scram_ack:
		for u in reactor.units:
			if u["scram"]:
				return true
	return false


var _beacon_k := {}


func _alarm_beacons(dt: float) -> void:
	var on := _alarm_active()
	for i in logic["extra"]["alm"].size():
		var B: Dictionary = logic["extra"]["alm"][i]
		var k: float = _beacon_k.get(i, 0.0)
		k += ((1.0 if on else 0.0) - k) * minf(1.0, dt * (9.0 if on else 3.0))
		_beacon_k[i] = k
		var rot := nd(B["rot"])
		var halo := nd(B["halo"]) as MeshInstance3D
		var dome := nd(B["dome"]) as MeshInstance3D
		var bulb := nd(B["bulb"]) as MeshInstance3D
		if rot == null:
			continue
		if k < 0.01 and not on:
			(halo.material_override as StandardMaterial3D).albedo_color.a = 0.0
			for b in B["beams"]:
				((nd(b) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.0
			(dome.material_override as StandardMaterial3D).albedo_color = Color("#4a1208")
			(bulb.material_override as StandardMaterial3D).albedo_color = Color("#5a1a10")
			continue
		rot.rotation.y += dt * 7.5
		var pulse := 0.55 + 0.45 * absf(cos(rot.rotation.y * 2.0 + B["ph"]))
		(dome.material_override as StandardMaterial3D).albedo_color = Color(0.28 + 0.72 * k, 0.07 + 0.12 * k, 0.03 + 0.05 * k)
		(bulb.material_override as StandardMaterial3D).albedo_color = Color(0.35 + 0.65 * k, 0.1 + 0.6 * k, 0.06 + 0.4 * k)
		var ops := [0.14, 0.14, 0.22, 0.22]
		var bi := 0
		for b in B["beams"]:
			var bm := (nd(b) as MeshInstance3D).material_override as StandardMaterial3D
			bm.albedo_color.a = ops[bi % 4] * k
			bi += 1
		(halo.material_override as StandardMaterial3D).albedo_color.a = k * (0.55 + 0.45 * pulse)
		var hs: float = float(B["s"]) * (0.8 + 0.9 * pulse)
		halo.scale = Vector3(hs, hs, 1.0)


func _audio(_dt: float) -> void:
	var z := zone_name
	var inb := z.contains("hall") or z.contains("control") or z.contains("building") or z.contains("visitor") or z.contains("diesel") or z.contains("maintenance") or z.contains("radwaste") or z.contains("training") or z.contains("kiosk") or z.contains("gatehouse")
	_srv.volume_db = -10.0 if z.contains("control") else (-22.0 if z.contains("turbine hall") else -80.0)
	_amb.volume_db = -22.0 if inb else -10.0
	Sfx.siren(_alarm_active())
	if _alarm_active():
		Sfx._siren.volume_db = -22.0 if inb else -14.0


# ------------------------------------------------------------------ HUD
func _hud(dt: float) -> void:
	var U: Array = reactor.units
	zone_lab.text = zone_name
	status_lab.text = "unit 1 %s   unit 2 %s\n%s mw to grid   %s" % [
		"scrammed" if U[0]["scram"] else "%.0f%%" % (U[0]["pw"] * 100.0), "scrammed" if U[1]["scram"] else "%.0f%%" % (U[1]["pw"] * 100.0),
		"%.0f" % reactor.grid["exp"], reactor.clock_text()]
	var txt := ""
	if near != null and not ui_open:
		txt = ("" if near.get("raw", false) else "[e] ") + str(near["label"])
	prompt.text = txt
	cross.queue_redraw()
	var sev := false
	var anyn := false
	for a in reactor.alarms:
		if a["on"] and a["s"] >= 3:
			sev = true
		if a["on"] and not a["ack"] and a["s"] >= 2:
			anyn = true
	alarm_lab.text = ("! reactor trip" if int(reactor.t * 2.0) % 2 == 1 else "") if sev else ("! alarm" if anyn else "")
	hint_lab.text = "[m] map  [tab] controls"
	if reactor.pa != "" and reactor.t < reactor.pa_until:
		pa_lab.text = reactor.pa
	else:
		pa_lab.text = ""
	toast_t -= dt
	if toast_t <= 0.0:
		toast.text = ""
	if tr["driving"]:
		tr["msg_t"] -= dt
		dash.queue_redraw()
	if show_map:
		minimap.queue_redraw()


func _draw_cross() -> void:
	var c := Vector2(10, 10)
	if near != null and not ui_open:
		cross.draw_arc(c, 7.0, 0.0, TAU, 20, K_AM, 2.0)
	else:
		cross.draw_circle(c, 3.0, Color(1, 1, 1, 0.75))


func _draw_minimap() -> void:
	if logic.is_empty():
		return
	var S := 240.0
	var R := 250.0
	var k := S / (2.0 * R)
	var m := minimap
	m.draw_rect(Rect2(0, 0, S, S), K_BG)
	var tf := func(x: float, z: float) -> Vector2:
		return Vector2(S / 2.0 + (x - P["x"]) * k, S / 2.0 + (z - P["z"]) * k)
	var rect := func(x0: float, z0: float, x1: float, z1: float, c: Color):
		var a: Vector2 = tf.call(x0, z0)
		var b: Vector2 = tf.call(x1, z1)
		var r := Rect2(a, b - a).abs().intersection(Rect2(0, 0, S, S))
		if r.size.x > 0.0 and r.size.y > 0.0:
			m.draw_rect(r, c)
	rect.call(-1600, -1300, 1600, 1300, Color("#1a2a1a"))
	rect.call(-340, -290, 500, 330, Color("#303050"))
	rect.call(-906, -1000, -854, 1000, Color("#3a3a58"))
	rect.call(-854, 350, -720, 370, Color("#3a3a58"))
	rect.call(-720, 296, -596, 424, Color("#3a3a58"))
	for z in zones:
		rect.call(z["x0"], z["z0"], z["x1"], z["z1"], Color(0.43, 0.43, 0.78, 0.35))
	for T in logic["towers"]:
		var p: Vector2 = tf.call(T["x"], T["z"])
		m.draw_circle(p, 40.0 * k, Color("#d6d2d4"))
	for zc in [-110.0, 110.0]:
		var p2: Vector2 = tf.call(60.0, zc)
		m.draw_circle(p2, 22.0 * k, Color("#e8e4d8"))
	var pc := Vector2(S / 2.0, S / 2.0)
	var yaw: float = P["yaw"]
	var pts := PackedVector2Array([Vector2(0, -8), Vector2(5.5, 6), Vector2(0, 3), Vector2(-5.5, 6)])
	var out := PackedVector2Array()
	for q in pts:
		out.append(pc + q.rotated(yaw))
	m.draw_colored_polygon(out, K_AM)
	m.draw_string(FONT_BOLD, Vector2(S / 2.0 - 4.0, 12.0), "n", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_dash() -> void:
	var c := dash
	var Wd := 460.0
	var Hd := 210.0
	c.draw_rect(Rect2(0, 22, Wd, Hd - 22), Color(5.0 / 255.0, 5.0 / 255.0, 90.0 / 255.0, 0.78))
	c.draw_rect(Rect2(1.5, 23.5, Wd - 3, Hd - 25), Color("#4a4aa8"), false, 3.0)
	var kmh := absf(tr["v"]) * 3.6
	var cx := 120.0
	var cy := 118.0
	var R := 82.0
	for k in 15:
		var a := deg_to_rad(-225.0 + k * 18.0)
		var L := 6.0 if k % 2 == 1 else 12.0
		c.draw_line(Vector2(cx + cos(a) * (R - L), cy + sin(a) * (R - L)), Vector2(cx + cos(a) * R, cy + sin(a) * R), K_DIM, 2.0)
		if k % 2 == 0:
			c.draw_string(FONT_BOLD, Vector2(cx + cos(a) * (R - 26.0) - 10.0, cy + sin(a) * (R - 26.0) + 5.0), str(k * 10), HORIZONTAL_ALIGNMENT_CENTER, 20.0, 13, K_TX)
	c.draw_arc(Vector2(cx, cy), R + 3.0, deg_to_rad(-225.0 + 12.5 * 18.0), deg_to_rad(-225.0 + 14.0 * 18.0), 12, K_RD, 3.0)
	var na := deg_to_rad(-225.0 + minf(150.0, kmh) / 140.0 * 252.0)
	c.draw_line(Vector2(cx, cy), Vector2(cx + cos(na) * (R - 10.0), cy + sin(na) * (R - 10.0)), K_AM, 4.0)
	c.draw_circle(Vector2(cx, cy), 6.0, K_AM)
	c.draw_string(FONT_BOLD, Vector2(cx - 60.0, cy + 50.0), str(roundi(kmh)), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 38, Color.WHITE)
	c.draw_string(FONT_BOLD, Vector2(cx - 40.0, cy + 68.0), "km/h", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 14, K_DIM)
	var gear := "n" if (absf(tr["v"]) < 0.3 and tr["thr"] == 0.0) else ("r" if tr["v"] < -0.3 else "d")
	var hd := fposmod(rad_to_deg(tr["yaw"]), 360.0)
	var dirs := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
	var cp: String = dirs[roundi(hd / 45.0) % 8]
	c.draw_string(FONT_BOLD, Vector2(250, 52), "gear", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K_TX)
	c.draw_string(FONT_BOLD, Vector2(250, 86), gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	c.draw_string(FONT_BOLD, Vector2(330, 52), "hdg", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K_TX)
	c.draw_string(FONT_BOLD, Vector2(330, 82), "%s %03d" % [cp, roundi(hd)], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	c.draw_string(FONT_BOLD, Vector2(250, 112), "fuel", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, K_DIM)
	c.draw_rect(Rect2(290, 100, 150, 14), Color("#4a4aa8"), false, 2.0)
	c.draw_rect(Rect2(292, 102, 146.0 * tr["fuel"] / 100.0, 10), K_RD if tr["fuel"] < 15.0 else K_GR)
	c.draw_string(FONT_BOLD, Vector2(250, 136), "trip", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, K_DIM)
	c.draw_string(FONT_BOLD, Vector2(290, 136), "%.2f km" % (tr["odo"] / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var lamps := [[250, "lights", tr["lights"], K_AM], [314, "brake", tr["hb"], K_RD], [378, "fuel", tr["fuel"] < 15.0, K_RD]]
	for l in lamps:
		c.draw_rect(Rect2(l[0], 174, 58, 18), l[3] if l[2] else Color("#2a2a6a"))
		c.draw_string(FONT_BOLD, Vector2(l[0], 187), l[1], HORIZONTAL_ALIGNMENT_CENTER, 58.0, 12, Color.BLACK if l[2] else Color("#6a66a0"))
	if tr["msg_t"] > 0.0:
		c.draw_string(FONT_BOLD, Vector2(0, 14), str(tr["msg"]), HORIZONTAL_ALIGNMENT_CENTER, Wd, 15, K_AM)
