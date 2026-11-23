extends Node
## The flight scene: owns the simulation, the 3D camera, the cockpit UI wiring,
## the scripted MASTER KING finale and the crash / landing cutscenes.

signal finished(mode: String)      ## "finale", "land", "nclr", "lmia" or "crash"
signal pause_requested

enum St { LOADING, FLY, CINE, DONE }

const NM := WorldData.NM
const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")

const HINT_FONT := 22

const DENIALS: Array = [
	"I'm sorry, Dave. I'm afraid I can't do that.",
	"CONTROLS: 404 NOT FOUND",
	"The yoke is now decorative.",
	"Have you tried turning it off and on again?",
	"That's not a bug, it's a feature.",
	"Autopilot: 'Trust me.'",
	"Skill issue. (Not yours. Mine.)",
]

## seconds after reaching 2.0 NM: [time, text, kind, action]
const FIN_SCRIPT: Array = [
	[0.0, "ARRIVED!  Welcome to MASTER KING", "ok", ""],
	[3.2, "Autoland is performing flawlessly. Please remain seated.", "ok", ""],
	[6.4, "Wait...", "hmm", ""],
	[9.0, "Something isn't right...", "hmm", "slow"],
	[12.4, "Why is the runway... made of bricks?", "hmm", ""],
	[15.8, "Why does every single brick have a FACE on it?!", "bad", "caut"],
	[19.4, "Okay. Disconnect the autopilot. Disconnect it. DISCONNECT IT.", "bad", ""],
	[22.6, "AUTOPILOT: I'm sorry, Dave. I'm afraid I can't do that.", "bad", "warn"],
	[25.6, "TERRAIN! TERRAIN! PULL UP! PULL UP!", "panic", "siren"],
	[29.0, "It's a PYRAMID. It's a giant PYRAMID. It's looking at us.", "panic", ""],
	[33.0, "This is fine. This is fine. THIS IS FINE.", "panic", ""],
]

@onready var world_view: SubViewportContainer = $WorldView
@onready var viewport: SubViewport = $WorldView/Viewport
@onready var world: WorldBuilder = $WorldView/Viewport/World
@onready var camera: Camera3D = $WorldView/Viewport/World/Camera3D
@onready var sun: DirectionalLight3D = $WorldView/Viewport/World/Sun
@onready var cockpit: CanvasLayer = $Cockpit
@onready var help_label: Label = $Overlay/HelpBar
@onready var cap_label: Label = $Overlay/Caption
@onready var flash: ColorRect = $Overlay/Flash
@onready var help_dialog: Control = $Overlay/HelpDialog
@onready var help_ok: Button = $Overlay/HelpDialog/Box/Ok
@onready var loading: Control = $Overlay/Loading
@onready var load_text: Label = $Overlay/Loading/Text
@onready var load_bar: ProgressBar = $Overlay/Loading/Bar
@onready var skip_hint: Label = $Overlay/SkipHint
@onready var wenv: WorldEnvironment = $WorldView/Viewport/World/WorldEnvironment
@onready var storm_ov: ColorRect = $Overlay/StormOv
@onready var shutters: Control = $Overlay/Shutters
@onready var shutter_plate: ColorRect = $Overlay/Shutters/Plate
@onready var sec_msg: Label = $Overlay/SecretMsg
@onready var slap: Control = $Overlay/Slap
@onready var slap_img: TextureRect = $Overlay/Slap/Img
@onready var pda: Control = $Overlay/PDA
@onready var overhead: Instrument = $Cockpit/Panel/Overhead
@onready var hud: Hud = $Cockpit/Panel/Hud

var state := St.LOADING
var start_nclr := false
var m: FlightModel
var ui: FlightUI

var _tap := {}
var _kb_ail := 0.0
var _kb_elev := 0.0
var _kb_rud := 0.0
var _help_until := 0
var _help_cur := ""
var _denied_t := 0
var _denied_n := 0

# finale script
var fin_st := "idle"
var fin_t := 0.0
var fin_i := 0
var fin_curse: AudioStreamPlayer
var fin_scream: AudioStreamPlayer

# cutscenes
var cine_mode := ""
var cine_t := 0.0
var cine_T := 8.0
var cine_imp := false
var cine_t_imp := 0.0
var cine_p0 := Vector3.ZERO
var cine_d := Vector3.FORWARD
var cine_psi := 0.0
var cine_dist := 0.0
var cine_nose := Vector3.ZERO
var cine_ended := false
var cine_shake := 0.0
var cine_land_t := 0.0
var cine_td_cam := Vector3.ZERO
var cine_td_set := false
var cine_cap_text := ""
var debris: Array = []
var fx_nodes: Array = []
var fire_light: OmniLight3D
var _land_stop_t := 0.0

# systems / storm / shutdown / secret state
var env_def := {}
var glitch_spike := 0.0
var _caut_t := 0.0
var shut_st := "idle"
var shut_t := 0.0
var shut_why := ""
var shut_ev: Array = []
var shut_seg: Array = []
var slap_item := ""
var slap_t := -1.0
var slap_dir := 1.0
var slap_grabbed := false
var _deb_mats := {}
var sec_on := false
var sec_t0 := 0.0
var sec_mus: AudioStreamPlayer
var sec_i0 := 1.0
var sec_lock := false
var sec_lock_t0 := 0.0
var sec_sealed := false
var sec_ms := {}
var sec_alm := {}
var sec_cine_started := false
var sec_phase := ""
var sec_cine_t := 0.0
var sec_cam_pos := Vector3.ZERO
var sec_boomed := false
var sec_alex: AudioStreamPlayer
var sec_stage: Node3D
var sec_last_msg := 0.0


func _ready() -> void:
	help_label.add_theme_font_override("font", FONT_BOLD)
	help_label.add_theme_font_size_override("font_size", HINT_FONT)
	cap_label.add_theme_font_override("font", FONT_BOLD)
	cap_label.add_theme_font_size_override("font_size", 64)
	skip_hint.add_theme_font_override("font", FONT_BOLD)
	skip_hint.add_theme_font_size_override("font_size", 18)
	load_text.add_theme_font_override("font", FONT_BOLD)
	load_text.add_theme_font_size_override("font_size", 26)
	help_label.modulate.a = 0.0
	cap_label.text = ""
	skip_hint.visible = false
	flash.modulate.a = 0.0
	help_dialog.visible = false
	help_ok.pressed.connect(_toggle_help)
	_style_help_dialog()
	loading.visible = true
	cockpit.visible = false
	camera.fov = 38.0
	camera.near = 1.5
	camera.far = 130000.0
	# the sun shines from azimuth 232 deg, elevation 23 deg
	var az := deg_to_rad(232.0)
	var el := deg_to_rad(23.0)
	var sun_dir := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP)
	world.progress.connect(_on_world_progress)
	sec_msg.add_theme_font_override("font", FONT_BOLD)
	sec_msg.add_theme_font_size_override("font_size", 40)
	slap_img.pivot_offset = Vector2(150, 200)
	slap.pivot_offset = Vector2(150, 220)
	slap.gui_input.connect(_on_slap_input)
	pda.closed.connect(_on_pda_closed)
	var env := wenv.environment
	env_def = {"fog": env.fog_light_color, "begin": env.fog_depth_begin, "end": env.fog_depth_end, "sun": sun.light_energy}


## Called by Main once the scene is in the tree.
func begin() -> void:
	state = St.LOADING
	loading.visible = true
	Sfx.stop_all_loops()
	await world.build()
	_new_game()
	await get_tree().create_timer(0.5).timeout
	loading.visible = false
	cockpit.visible = true
	state = St.FLY
	Sfx.curse()
	if start_nclr:
		say("LEMUEL INTL (LMIA) is now landable. Press K in flight to arm the autoland; J cycles destinations.", "ok", 9000)
	else:
		say("Welcome aboard Ancient Air 001! Press T for AUTO TAKE-OFF, or do it the hard way.", "ok", 8000)


func _on_world_progress(f: float, text: String) -> void:
	load_bar.value = f * 100.0
	load_text.text = "loading map data plane_cockpit  -  " + text.to_lower()


func _new_game() -> void:
	m = FlightModel.new()
	m.from_nclr = Game.from_nclr
	m.storm = StormModel.new()
	m.secret_ok = Game.item_count("bible") >= 3
	if start_nclr:
		var nz: float = float(WorldData.NCLR["thrZ"]) - 80.0
		m.pos = Vector3(WorldData.NCLR["x"], WorldData.ground_h(WorldData.NCLR["x"], nz) + FlightModel.AC_GEARH, nz)
		m.dep_x = WorldData.NCLR["x"]
		m.from_nclr = true
		m.dest = "LMIA"
		m.derive()
	ui = FlightUI.new()
	ui.m = m
	ui.muted = Sfx.muted
	ui.say_requested.connect(say)
	ui.denied.connect(_deny_once)
	ui.pause_requested.connect(func(): pause_requested.emit())
	ui.help_requested.connect(_toggle_help)
	ui.mute_requested.connect(_toggle_mute)
	ui.inv_requested.connect(_open_pda)
	ui.ovh_requested.connect(_toggle_ovh)
	for n in get_tree().get_nodes_in_group("instruments"):
		(n as Instrument).bind(ui)
	hud.bind(ui, camera)
	ui.log_msg("SYSTEM POWER ON")
	ui.log_msg("PARKING BRAKE SET")
	fin_st = "idle"
	fin_t = 0.0
	fin_i = 0
	_update_camera()


func set_paused(p: bool) -> void:
	if ui:
		ui.paused = p
	if p:
		Sfx.stop_all_loops()
		_tap.clear()


# ------------------------------------------------------------------ help bar / captions
func say(text: String, kind := "ok", ms := 6500) -> void:
	_help_cur = text
	_help_until = Time.get_ticks_msec() + ms
	help_label.text = text
	var col := Color("#fff4d0")
	var border := Color("#c9a24a")
	match kind:
		"bad":
			col = Color("#ffb0a0")
			border = Color("#ff5a40")
		"panic":
			col = Color("#ff6a50")
			border = Color("#ff2a10")
		"hmm":
			col = Color("#ffe9a0")
	help_label.add_theme_color_override("font_color", col)
	var sb := help_label.get_theme_stylebox("normal") as StyleBoxFlat
	if sb:
		sb.border_color = border
	help_label.modulate.a = 1.0


func _hide_help() -> void:
	help_label.modulate.a = 0.0
	_help_cur = ""


func _hint() -> String:
	if m.f_lockout:
		return ""
	if m.on_ground and not m.f_airborne:
		if m.park_brake and m.ato_phase == "":
			return "Welcome aboard Ancient Air 001! Press T for AUTO TAKE-OFF — or release the parking brake (P), push the thrust up (R) and rotate at 130 knots."
		if m.ato_phase != "":
			return "Rolling! Sit back. The computer will rotate at 130 knots."
		return "Push the thrust levers up (hold R), then gently pull back (S) at 130 knots."
	if not m.f_takeoff_done:
		return "Positive rate! Raise the landing gear — press G." if m.gear_cmd == 1 else "Climb out to 500 feet to complete the takeoff."
	if m.al_st == "OFF" or m.al_st == "CANCEL":
		return "Takeoff complete! Press DEST (K) to arm the autoland for %s (J switches destination)." % m.cur_dest()["name"]
	if m.al_st == "ARM":
		if m.dest != "MKNG":
			return "%s is set. Approach locks on 5 NM out; autoland at 500 ft. Press X to speed up time." % m.cur_dest()["name"]
		return "%s is set. Autoland engages 5 NM out. Press X to speed up time." % m.cur_dest()["name"]
	if m.al_st == "ENG":
		if m.dest != "MKNG" and m.agl_ft > 500.0:
			return "Approach captured. Autoland takes over at 500 ft."
		return "Autoland engaged. Hands off — what could possibly go wrong?"
	return ""


func _deny_once() -> void:
	var n := Time.get_ticks_msec()
	if n - _denied_t > 1700:
		_denied_t = n
		_denied_n += 1
		say(DENIALS[_denied_n % DENIALS.size()], "bad", 1800)


func _toggle_help() -> void:
	help_dialog.visible = not help_dialog.visible


func _toggle_mute() -> void:
	Sfx.toggle_mute()
	if ui:
		ui.muted = Sfx.muted


func _style_help_dialog() -> void:
	for n in help_dialog.find_children("*", "Label", true, false):
		(n as Label).add_theme_font_override("font", FONT_BOLD)
	help_ok.add_theme_font_override("font", FONT_BOLD)


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if state != St.FLY and state != St.CINE:
		return
	if not (event is InputEventKey):
		return
	var e := event as InputEventKey
	if not e.pressed:
		return
	var c := e.physical_keycode
	if e.echo:
		return
	if state == St.CINE:
		if c == KEY_SPACE or c == KEY_ESCAPE or c == KEY_ENTER:
			_skip_cine()
		return
	_tap[c] = 2
	if ui.paused:
		return
	if help_dialog.visible and (c == KEY_ESCAPE or c == KEY_H or c == KEY_ENTER or c == KEY_F1):
		_toggle_help()
		return
	match c:
		KEY_M:
			_toggle_mute()
			return
		KEY_H, KEY_F1:
			_toggle_help()
			return
		KEY_SPACE:
			pause_requested.emit()
			return
		KEY_N:
			ui.press("range")
			return
		KEY_I:
			_open_pda()
			return
		KEY_O:
			_toggle_ovh()
			return
		KEY_X:
			ui.press("warp")
			return
		KEY_ESCAPE:
			if not help_dialog.visible:
				pause_requested.emit()
			return
	if m.f_lockout:
		if [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_G, KEY_R, KEY_F, KEY_K, KEY_T, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_Q, KEY_E].has(c):
			_deny_once()
		return
	match c:
		KEY_G:
			ui.press("gear")
		KEY_BRACKETRIGHT:
			ui.press("flap_dn")
		KEY_BRACKETLEFT:
			ui.press("flap_up")
		KEY_P:
			ui.press("park")
		KEY_T:
			ui.press("to")
		KEY_K, KEY_ENTER:
			ui.press("dest")
		KEY_J:
			ui.press("jsw")
		KEY_V:
			ui.press("ap")


func _key(c: int) -> bool:
	return Input.is_physical_key_pressed(c as Key) or _tap.get(c, 0) > 0


func _read_input(dt: float) -> void:
	for k in _tap.keys():
		if _tap[k] > 0:
			_tap[k] -= 1
	if m.f_lockout:
		m.in_ail = 0.0
		m.in_elev = 0.0
		m.in_rud = 0.0
		m.in_brake = 0.0
		return
	var t_a := (1.0 if (_key(KEY_D) or _key(KEY_RIGHT)) else 0.0) - (1.0 if (_key(KEY_A) or _key(KEY_LEFT)) else 0.0)
	var t_e := (1.0 if (_key(KEY_S) or _key(KEY_DOWN)) else 0.0) - (1.0 if (_key(KEY_W) or _key(KEY_UP)) else 0.0)
	var t_r := (1.0 if Input.is_physical_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_Q) else 0.0)
	_kb_ail += (t_a * 0.85 - _kb_ail) * minf(1.0, dt * (5.0 if t_a != 0.0 else 9.0))
	_kb_elev += (t_e * 0.7 - _kb_elev) * minf(1.0, dt * (5.0 if t_e != 0.0 else 9.0))
	_kb_rud += (t_r - _kb_rud) * minf(1.0, dt * 8.0)
	if ui.yoke_drag:
		m.in_ail = ui.yoke_ail
		m.in_elev = ui.yoke_elev
	else:
		m.in_ail += (_kb_ail - m.in_ail) * minf(1.0, dt * 10.0)
		m.in_elev += (_kb_elev - m.in_elev) * minf(1.0, dt * 10.0)
		if absf(m.in_ail) < 0.01 and t_a == 0.0:
			m.in_ail = 0.0
		if absf(m.in_elev) < 0.01 and t_e == 0.0:
			m.in_elev = 0.0
	m.in_rud = _kb_rud
	# steering on the ground also uses the roll axis
	if m.on_ground and absf(m.in_ail) > 0.05 and t_r == 0.0:
		m.in_rud = m.in_ail * 0.9
	m.in_brake = 1.0 if (Input.is_physical_key_pressed(KEY_B) or ui.wheel_brake) else 0.0
	var up := (1.0 if Input.is_physical_key_pressed(KEY_R) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_F) else 0.0)
	if up != 0.0:
		var base: float = m.lever[0] if m.athr_active else m.lever_cmd
		m.lever_cmd = clampf(base + up * dt * 0.45, 0.0, 1.0)
		m.ap_athr = false
		if m.ato_phase != "" and m.ato_phase != "DONE":
			m.ato_phase = ""
	if Input.is_physical_key_pressed(KEY_SHIFT) and Input.is_physical_key_pressed(KEY_R):
		m.lever_cmd = 1.0
	if m.athr_active and up == 0.0:
		m.lever_cmd = m.lever[0]
	if m.ato_phase == "DONE":
		m.ato_phase = ""


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if state == St.FLY:
		ui.t += dt
		if not ui.paused:
			_read_input(dt)
			_run_sim(dt * ui.warp)
			_handle_events()
			_systems_frame(dt)
			if state == St.FLY:
				_fin_maybe_trigger()
				_fin_update(dt)
				_shut_maybe()
				_shut_update(dt)
				_sec_update(dt)
			if ui.warp > 1 and m.al_st == "ENG" and m.dist_thr < 6.0 * NM:
				ui.warp = 1
				say("Time acceleration off. You will want to see this.", "ok")
			if Time.get_ticks_msec() > _help_until:
				var h := _hint()
				if h != "":
					if _help_cur != h:
						say(h, "ok", 600)
				else:
					if not m.f_lockout:
						_hide_help()
			Sfx.engine_update(m.n1avg, m.V, m.n1avg > 25.0 or not m.on_ground)
		_storm_visuals(dt)
		_update_slap(dt)
		_update_camera()
	elif state == St.CINE:
		_cine_update(dt)


func _run_sim(rem: float) -> void:
	var steps := 0
	while rem > 1e-6 and steps < 30:
		var h := minf(rem, 1.0 / 30.0)
		m.step(h)
		rem -= h
		steps += 1
		if m.crashed != "":
			break


func _update_camera() -> void:
	if m == null:
		return
	var fwd := Vector3(sin(m.psi) * cos(m.theta), sin(m.theta), -cos(m.psi) * cos(m.theta))
	camera.position = m.pos + fwd * 16.5 + Vector3(0, 1.4, 0)
	camera.basis = Basis.from_euler(Vector3(m.theta, -m.psi, -m.phi), EULER_ORDER_YXZ)
	if sec_ext and sec_phase == "storm":
		world.plane.set_pose(m.pos, m.psi, m.theta, m.phi)
		var behind := Vector3(-sin(m.psi), 0, cos(m.psi))
		camera.position = m.pos + behind * 90.0 + Vector3(cos(m.psi), 0, sin(m.psi)) * 35.0 + Vector3(0, 18, 0)
		camera.look_at(m.pos, Vector3.UP)


# ------------------------------------------------------------------ events from the flight model
func _handle_events() -> void:
	while not m.ev.is_empty():
		var e: String = m.ev.pop_front()
		match e:
			"liftoff":
				say("Positive rate! Raise the landing gear — press G.", "ok")
				Sfx.clunk()
			"gear":
				Sfx.clunk()
				get_tree().create_timer(0.6 / ui.warp).timeout.connect(Sfx.gear_thunk)
			"flaps":
				Sfx.clunk()
			"takeoffComplete":
				Sfx.curse()
				say("Takeoff complete! Press DEST (K) to arm the autoland for %s. Press J to switch destination." % m.cur_dest()["name"], "ok", 9000)
				ui.log_msg("TAKEOFF COMPLETE")
			"atoStart":
				ui.log_msg("AUTO TAKE-OFF ACTIVE")
				Sfx.clunk()
			"destSet":
				var dd := m.cur_dest()
				if dd["id"] != "MKNG":
					var where := " by the towers"
					if m.dest == "LMIA":
						where = " beside your home runway; ground crews will then refuel and repair you"
					elif m.dest == "NCLR":
						where = " by the reactor"
					say("%s is set. The approach locks on 5 NM out and autoland takes over at 500 ft, landing you on the runway%s. Press X to speed up time." % [dd["name"], where], "ok", 8000)
				else:
					say("MASTER KING is set. Autoland will engage 5 NM out. Press X to speed up time.", "ok", 8000)
				ui.log_msg("DEST %s SET. AUTOLAND ARMED" % dd["short"])
				Sfx.chime()
			"destPick":
				var d2 := m.cur_dest()
				var txt := "MASTER KING — the Great Pyramid."
				if d2["id"] == "LMIA":
					txt = "LEMUEL INTL (LMIA) — home, on its second runway. Autoland, then the ground crews refuel and repair you."
				elif d2["id"] == "NCLR":
					txt = "NAICOL REACTOR (NCLR) — a nuclear plant on the grass plains. Autoland lands you safely."
				elif d2["id"] == "JRNA":
					txt = "JRNA — the runway by the two towers. Autoland will actually land you!"
				say("Destination: %s (J switches)" % txt, "ok", 6500)
				ui.log_msg("DEST %s SELECTED" % d2["short"])
				Sfx.chime()
			"destBusy":
				say("Too late to change destination — autoland is engaged.", "bad")
			"apprCap":
				Sfx.chime()
				say("%s approach captured (LOC / GS). Autoland takes over at 500 ft." % m.cur_dest()["short"], "ok", 7000)
				ui.log_msg("APPR LOC/GS CAPTURED")
			"flare":
				ui.log_msg("FLARE")
			"jrnaTouch":
				ui.log_msg("TOUCHDOWN %s RWY 36" % (m.rwy if m.rwy != "" else "JRNA"))
			"rolloutStop":
				ui.log_msg("FULL STOP. WELCOME TO %s" % m.cur_dest()["short"])
				Sfx.chime()
				if state == St.FLY:
					ui.warp = 1
					_start_cine("land")
			"destClear":
				say("Destination cleared. Autoland disarmed.", "ok")
				ui.log_msg("AUTOLAND DISARMED")
			"destRefuse":
				say("Take off first — then set the destination!", "bad")
			"apRefuse":
				say("Autopilot needs some altitude first.", "bad")
			"gearLocked":
				say("The gear lever is locked while rolling. (Safety!)", "bad")
			"apOn":
				Sfx.tone_up()
				ui.log_msg("A/P ENGAGED")
			"apOff":
				Sfx.tone_down()
				ui.log_msg("A/P DISCONNECT")
				ui.caut_flash = true
			"alEngaged":
				if m.dest != "MKNG":
					if state == St.FLY:
						ui.warp = 1
						Sfx.chime()
						ui.log_msg("AUTOLAND ENGAGED 500 FT")
						_start_cine("land")
				else:
					Sfx.curse()
					say("AUTOLAND ENGAGED. Hands off — what could possibly go wrong?", "ok", 9000)
					ui.log_msg("AUTOLAND ENGAGED 5 NM")
					ui.caut_flash = false
			"touchdown":
				Sfx.thud(0.5)
				if m.dest == "MKNG":
					say("Touchdown! (Not the plan, but nice.)", "ok")
			"hardLanding":
				say("Ouch. That was a landing.", "bad")
			"stormStart":
				ui.warp = 1
				say("SANDSTORM! Visibility dropping - debris incoming. The autopilot will try to dodge. (No promises.)", "bad", 7000)
				Sfx.play("storm")
				ui.log_msg("WX: SANDSTORM")
				ui.caut_flash = true
			"stormEnd":
				say("The sandstorm is clearing. Visibility improving.", "ok", 5000)
				ui.log_msg("WX: STORM CLEARING")
			"evade":
				Sfx.chirp()
				ui.log_msg("A/P EVASIVE MANEUVER")
				if slap_t < 0.0:
					say(["Autopilot: EVASIVE MANEUVER!", "Debris! Autopilot is dodging!", "Incoming! Hold on!", "Autopilot: \"I got this.\""][randi() % 4], "bad", 2200)
			"nearMiss":
				say(["Whoa! That was close!", "It missed us by a wing!", "Did you see THAT?!", "Autopilot: \"I meant to do that.\"", "Too close for comfort!"][randi() % 5], "ok", 2600)
			"debrisHit":
				_on_debris_hit()
			"secretStart":
				_sec_begin()
			"crash":
				if state == St.FLY and fin_st != "cine":
					fin_st = "crash"
					ui.warp = 1
					_start_cine("crash")
				elif state == St.CINE and cine_mode == "land":
					_start_cine("crash")


# ------------------------------------------------------------------ the approach script (cockpit view)
func _fin_maybe_trigger() -> void:
	if fin_st != "idle" or m.crashed != "" or m.on_ground or not m.f_airborne or m.f_secret or shut_st != "idle":
		return
	if m.dest == "MKNG" and m.dist_pyr <= 2.0 * NM and m.along_nm > 0.0 and m.pos.z > WorldData.PYR_HALF:
		fin_st = "script"
		fin_t = 0.0
		fin_i = 0
		ui.warp = 1
		m.f_lockout = true
		m.fin_active = true
		m.fin_athr = false
		m.ap_on = true
		m.ap_athr = true
		m.al_st = "LOCK"
		m.gear_cmd = 1
		m.flaps_cmd = 4
		fin_curse = Sfx.curse()
		ui.king_lamp = true
		ui.log_msg("ARRIVED. WELCOME TO MASTER KING")


func _face_hit(p: Vector3, d: Vector3) -> float:
	return (WorldData.PYR_BASE + WorldData.PYR_SLOPE * (WorldData.PYR_HALF - p.z) - p.y) / (d.y + WorldData.PYR_SLOPE * d.z)


func _fin_update(dt: float) -> void:
	if fin_st != "script":
		return
	fin_t += dt
	while fin_i < FIN_SCRIPT.size() and fin_t >= float(FIN_SCRIPT[fin_i][0]):
		var s: Array = FIN_SCRIPT[fin_i]
		fin_i += 1
		say(s[1], s[2], 6500)
		ui.log_msg(str(s[1]).left(30))
		match s[3]:
			"slow":
				Sfx.pitch_down(fin_curse, 0.1, 3.6)
			"caut":
				ui.caut_flash = true
			"warn":
				ui.warn_flash = true
			"siren":
				Sfx.siren(true)
				ui.terrain_warn = true
	# fate: nudge us onto the centreline so the destination is guaranteed
	var k := minf(1.0, dt * 0.35)
	m.pos.x += (WorldData.THR_X - m.pos.x) * k * 0.5
	var d := Vector3(sin(m.psi) * cos(m.gamma), sin(m.gamma), -cos(m.psi) * cos(m.gamma))
	var s_hit := _face_hit(m.pos, d)
	if not (s_hit > 0.0):
		s_hit = Vector2(WorldData.THR_X - m.pos.x, WorldData.THR_Z - m.pos.z).length()
	var sd := 8.5
	var sc := Sfx.clip("scream")
	if sc != null:
		sd = sc.get_length()
	var tti := (s_hit - 21.0) / maxf(30.0, m.V)
	if tti <= sd and fin_st == "script":
		fin_st = "cine"
		Sfx.siren(false)
		ui.terrain_warn = false
		Sfx.stop_meme(fin_curse, 0.05)
		fin_scream = Sfx.scream()
		say("WE'RE CRASHING!!!", "panic")
		_start_cine("finale", sd)


# ------------------------------------------------------------------ cutscenes
func _enter_cine_view() -> void:
	state = St.CINE
	cine_ended = false
	cine_imp = false
	cine_t = 0.0
	cine_shake = 0.0
	debris.clear()
	cockpit.visible = false
	help_label.modulate.a = 0.0
	help_dialog.visible = false
	world_view.position = Vector2.ZERO
	world_view.size = Vector2(1600, 900)
	Sfx.stop_all_loops()
	world.plane.reset_parts()
	world.plane.visible = true
	world.plane.set_gear_visible(m.gear > 0.5)
	camera.near = 0.5
	skip_hint.visible = true


func _start_cine(mode: String, dur := 0.0) -> void:
	_enter_cine_view()
	cine_mode = mode
	cine_p0 = m.pos
	cine_psi = m.psi
	cine_d = Vector3(sin(m.psi) * cos(m.gamma), sin(m.gamma), -cos(m.psi) * cos(m.gamma))
	if mode == "finale":
		var s := _face_hit(cine_p0, cine_d)
		if not (s > 0.0 and s < 4000.0):
			s = Vector2(WorldData.THR_X - cine_p0.x, WorldData.THR_Z - cine_p0.z).length()
		cine_nose = cine_p0 + cine_d * s
		cine_dist = s - 21.0
		cine_T = dur if dur > 0.0 else maxf(3.0, (s - 21.0) / maxf(30.0, m.V))
		skip_hint.text = "SPACE: skip"
	elif mode == "crash":
		cine_nose = m.pos
		cine_T = 0.01
		skip_hint.text = "SPACE: skip"
		world.plane.set_pose(m.pos, m.psi, m.theta, m.phi)
		_boom()
	else:
		cine_nose = m.pos
		cine_T = 0.01
		cine_td_set = false
		_land_stop_t = 0.0
		skip_hint.text = "SPACE: skip"


func _skip_cine() -> void:
	if cine_ended:
		return
	if cine_mode == "land":
		cine_ended = true
		_end_land()
	elif cine_mode == "lmia":
		if lm:
			lm.skip()
	else:
		_end_cine_now()


func _end_cine_now() -> void:
	if cine_ended:
		return
	cine_ended = true
	cap_label.text = ""
	state = St.DONE
	if cine_mode == "finale":
		Game.unlock("finale")
		finished.emit("finale")
	elif cine_mode == "secret":
		Game.unlock("secret")
		finished.emit("secret")
	elif shut_why != "":
		finished.emit("dead_" + shut_why)
	else:
		finished.emit("crash")


func _end_land() -> void:
	cap_label.text = ""
	state = St.DONE
	match m.dest:
		"NCLR":
			Game.unlock("nclr")
			Game.set_from_nclr()
			finished.emit("nclr")
		"LMIA":
			_start_lmia_cine()
		_:
			Game.unlock("land")
			finished.emit("land")


func _cine_update(dt: float) -> void:
	cine_t += dt
	_update_debris(dt)
	match cine_mode:
		"finale":
			_cine_finale(dt)
		"crash":
			_cine_crash(dt)
		"land":
			_cine_land(dt)
		"secret":
			_cine_secret(dt)
		"lmia":
			_cine_lmia(dt)
	if cine_shake > 0.0:
		cine_shake = maxf(0.0, cine_shake - dt * 2.2)
		camera.position += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * cine_shake * 6.0


func _cine_finale(_dt: float) -> void:
	var pl := world.plane
	var tt := cine_t
	var u := clampf(tt / cine_T, 0.0, 1.0)
	var k := u * cine_dist
	var dmg := WorldData.sstep(cine_T * 0.2, cine_T * 0.8, tt)
	var sway := sin(tt * 3.1) * (5.0 + 9.0 * dmg) * (1.0 - u) * (1.0 if tt > 1.0 else tt)
	var roll := sin(tt * 2.3) * 0.16 * minf(1.0, tt / 1.5) + sin(tt * 7.1) * 0.04 + dmg * (0.5 * sin(tt * 3.7) - 0.22)
	var pitch := asin(cine_d.y) + 0.02 - 0.01 * minf(1.0, tt / 2.0) + 0.22 * WorldData.sstep(cine_T - 2.6, cine_T - 0.1, tt)
	var r := Vector3(cos(cine_psi), 0, sin(cine_psi))
	var pos := cine_p0 + cine_d * k + r * sway + Vector3(0, 0.8 * sin(tt * 5.2) * (1.0 - u), 0)
	var cam_p := Vector3(85.0, WorldData.PYR_BASE + 3.5, cine_nose.z + 300.0)
	if not cine_imp:
		pl.set_pose(pos, cine_psi + sin(tt * 1.7) * 0.02, pitch, roll)
		camera.position = cam_p
		camera.look_at(pos, Vector3.UP)
		camera.fov = 40.0
		cine_cap_text = _finale_caption(tt)
		if tt >= cine_T:
			_boom()
	else:
		camera.position = cam_p
		camera.look_at(cine_nose + Vector3(0, 40, 0), Vector3.UP)
		var a := cine_t - cine_t_imp
		cine_cap_text = ""
		for ln in [[0.3, "Task failed successfully.", 2.6], [3.0, "Press F to pay respects.", 2.6], [5.8, "(Welcome to MASTER KING.)", 2.6]]:
			if a >= float(ln[0]) and a < float(ln[0]) + float(ln[2]):
				cine_cap_text = ln[1]
		if a > 9.5 and not cine_ended:
			_end_cine_now()
	_set_caption(cine_cap_text, not cine_imp)


func _finale_caption(tt: float) -> String:
	var sc := cine_T / 8.0
	var lines: Array = [[0.05 * sc, "NOOOOOOOOOO!!!", 2.4 * sc], [2.9 * sc, "WHY IS EVERYTHING A FACE?!", 1.9 * sc],
		[4.9 * sc, "Mayday, mayday... ah.", 1.6 * sc], [6.5 * sc, "Houston, we have a problem.", 1.5 * sc]]
	for ln in lines:
		if tt >= float(ln[0]) and tt < float(ln[0]) + float(ln[2]):
			return ln[1]
	return ""


func _set_caption(text: String, red: bool) -> void:
	cap_label.text = text
	cap_label.add_theme_color_override("font_color", Color("#ff4030") if red else Color("#ffffff"))


func _cine_crash(_dt: float) -> void:
	var behind := Vector3(-sin(cine_psi), 0, cos(cine_psi))
	var right := Vector3(cos(cine_psi), 0, sin(cine_psi))
	camera.position = cine_p0 + behind * 130.0 + right * 35.0 + Vector3(0, 38, 0)
	camera.look_at(cine_p0 + Vector3(0, 6, 0), Vector3.UP)
	camera.fov = 45.0
	var a := cine_t - cine_t_imp
	_set_caption("Aircraft lost." if a < 3.5 else "", true)
	if a > 5.5 and not cine_ended:
		_end_cine_now()


func _cine_land(dt: float) -> void:
	var pl := world.plane
	var tgt := 1.0
	_run_sim(dt * tgt)
	_handle_events_in_land()
	if state != St.CINE or cine_mode != "land":
		return
	pl.set_pose(m.pos, m.psi, m.theta, m.phi)
	pl.set_gear_visible(m.gear > 0.5)
	var behind := Vector3(-sin(m.psi), 0, cos(m.psi))
	var right := Vector3(cos(m.psi), 0, sin(m.psi))
	if m.on_ground and not cine_td_set:
		cine_td_set = true
		var rw := m.cur_rw()
		cine_td_cam = Vector3(float(rw["x"]) + 55.0, float(rw["elev"]) + 6.0, m.pos.z - 260.0)
	if cine_td_set:
		camera.position = cine_td_cam
		camera.look_at(m.pos + Vector3(0, 3, 0), Vector3.UP)
		camera.fov = 34.0
	else:
		var want := m.pos + behind * 75.0 + right * 30.0 + Vector3(0, 14.0, 0)
		camera.position = camera.position.lerp(want, minf(1.0, dt * 4.0)) if cine_t > 0.2 else want
		camera.look_at(m.pos, Vector3.UP)
		camera.fov = 45.0
	var dd := m.cur_dest()
	var txt := ""
	if m.al_st == "STOPPED":
		txt = "FULL STOP.  WELCOME TO %s" % str(dd["name"])
		_land_stop_t += dt
		if _land_stop_t > 3.0 and not cine_ended:
			cine_ended = true
			_end_land()
	elif m.on_ground:
		txt = "TOUCHDOWN"
	elif m.al_flare:
		txt = "FLARE"
	_set_caption(txt, false)
	cap_label.add_theme_font_size_override("font_size", 44)


func _handle_events_in_land() -> void:
	_handle_events()


func _boom() -> void:
	cine_imp = true
	cine_t_imp = cine_t
	cine_shake = 1.0
	Sfx.explosion()
	flash.modulate.a = 1.0
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.5)
	var pl := world.plane
	var f := cine_d
	for key in pl.parts:
		if key == "gear":
			continue
		var n: Node3D = pl.parts[key]
		var gt := n.global_transform
		n.reparent(world, false)
		n.global_transform = gt
		var sp := 18.0 + randf() * 34.0
		var vel := Vector3((randf() - 0.5) * sp, 10.0 + randf() * 30.0, (randf() - 0.5) * sp) - f * 18.0 * (1.0 if cine_mode == "finale" else 0.2) + Vector3(0, 0, 22 if cine_mode == "finale" else 0)
		debris.append({"n": n, "v": vel, "w": Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 5.0})
	pl.set_gear_visible(false)
	var big := cine_mode == "finale"
	_spawn_fx(cine_nose, 1.6 if big else 1.0, big)
	if big:
		world.king_mat.emission = Color("#ff7a20")
		world.king_mat.emission_energy_multiplier = 1.2
		cine_shake = 2.0
		world.cap.visible = true
		debris.append({"n": world.cap, "v": Vector3(randf() * 20.0 - 10.0, 90.0, randf() * 20.0 - 10.0), "w": Vector3(2, 1, 3)})
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color("#ff7a20")
	fire_light.omni_range = 900.0
	fire_light.light_energy = 6.0
	fire_light.position = cine_nose + Vector3(0, 30, 40 if big else 0)
	world.add_child(fire_light)
	fx_nodes.append(fire_light)
	create_tween().tween_property(fire_light, "light_energy", 1.5, 3.0)


func _spawn_fx(p: Vector3, sc: float, big: bool) -> void:
	# fire ball
	var fire := _particles(p, 260 if big else 160, 2.4, 14.0 * sc, 70.0 * sc, Color(1, 0.9, 0.6), Color(0.95, 0.3, 0.05, 0.0), true, 55.0 * sc)
	fx_nodes.append(fire)
	# smoke column
	var smoke := _particles(p + Vector3(0, 8, 0), 120, 12.0, 20.0 * sc, 120.0 * sc, Color(0.2, 0.15, 0.1, 0.7), Color(0.45, 0.42, 0.38, 0.0), false, 24.0 * sc)
	fx_nodes.append(smoke)
	# sparks
	var sp := _particles(p, 200, 2.6, 2.0, 1.0, Color(1, 0.9, 0.55), Color(1, 0.3, 0.05, 0.0), true, 90.0 * sc)
	fx_nodes.append(sp)


func _particles(p: Vector3, amount: int, life: float, s0: float, s1: float, c0: Color, c1: Color, additive: bool, speed: float) -> CPUParticles3D:
	var pt := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.material = mat
	pt.mesh = sm
	pt.amount = amount
	pt.lifetime = life
	pt.one_shot = true
	pt.explosiveness = 0.95
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = 6.0
	pt.direction = Vector3(0, 1, 0)
	pt.spread = 180.0
	pt.initial_velocity_min = speed * 0.3
	pt.initial_velocity_max = speed
	pt.gravity = Vector3(0, 6.0 if not additive else -18.0, 0)
	pt.damping_min = 0.5
	pt.damping_max = 1.2
	pt.scale_amount_min = s0 / 14.0
	pt.scale_amount_max = s1 / 14.0
	var grad := Gradient.new()
	grad.set_color(0, c0)
	grad.set_color(1, c1)
	pt.color_ramp = grad
	pt.position = p
	world.add_child(pt)
	pt.emitting = true
	return pt


func _update_debris(dt: float) -> void:
	for d in debris:
		var n: Node3D = d["n"]
		if not is_instance_valid(n):
			continue
		var v: Vector3 = d["v"]
		v.y -= 9.8 * dt
		n.global_position += v * dt
		n.rotation += (d["w"] as Vector3) * dt
		var g := WorldData.ground_h(n.global_position.x, n.global_position.z)
		if n.global_position.y < g + 0.5:
			n.global_position.y = g + 0.5
			v = Vector3.ZERO
			d["w"] = Vector3.ZERO
		d["v"] = v


func _exit_tree() -> void:
	Sfx.stop_all_loops()
	Sfx.siren(false)


# ------------------------------------------------------------------ systems, PDA, overhead
func _systems_frame(dt: float) -> void:
	for ms in m.sys.msgs:
		ui.log_msg(str(ms[0]))
		if ms[1] == "r" or ms[1] == "a":
			ui.caut_flash = true
		if ms[1] == "r":
			say(str(ms[0]), "bad", 3000)
	m.sys.msgs.clear()
	m.sys.frame(dt)
	for k in ui.power:
		ui.power[k] = m.sys.dpv[k]
	glitch_spike = maxf(0.0, glitch_spike - dt * 0.2)
	ui.fin_state = fin_st
	ui.fin_siren = Sfx.siren_on
	ui.sec_on = sec_on
	hud.vis_far = wenv.environment.fog_depth_end
	ui.glitch = clampf((1.0 - m.sys.integ) * 1.3 + glitch_spike, 0.0, 0.44)
	if shut_st != "idle" and shut_why == "hull":
		ui.glitch = clampf(0.5 + shut_t * 0.11, 0.0, 0.97)
	if ui.caut_flash:
		_caut_t += dt
		if _caut_t > 6.0:
			ui.caut_flash = false
			_caut_t = 0.0
	if ui.warn_flash and fin_st == "idle" and not sec_on:
		ui.warn_flash = false


func _open_pda() -> void:
	if state != St.FLY or pda.visible:
		return
	ui.paused = true
	Sfx.stop_all_loops()
	pda.open(ui.log)


func _on_pda_closed() -> void:
	ui.paused = false


func _toggle_ovh() -> void:
	if state != St.FLY:
		return
	ui.ovh_open = not ui.ovh_open
	overhead.visible = ui.ovh_open
	Sfx.click()


# ------------------------------------------------------------------ sandstorm visuals / debris
func _debris_material(kind: String, item: String) -> StandardMaterial3D:
	var key := kind + item
	if _deb_mats.has(key):
		return _deb_mats[key]
	var mt := StandardMaterial3D.new()
	mt.roughness = 1.0
	match kind:
		"rock":
			mt.albedo_color = Color("#8d7556")
		"crate":
			mt.albedo_color = Color("#9a7140")
		"barrel":
			mt.albedo_color = Color("#7a4e28")
		"plank":
			mt.albedo_color = Color("#b08a58")
		_:
			var tex_path: String = Items.DATA[item]["img"] if item != "" else "res://assets/sprites/alex_bible.jpg"
			mt.albedo_texture = load(tex_path)
			mt.emission_enabled = true
			mt.emission = Color("#302018")
	_deb_mats[key] = mt
	return mt


func _make_debris_node(d: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sz: float = d["size"]
	match d["kind"]:
		"rock":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 0.85
			sm.radial_segments = 8
			sm.rings = 5
			mi.mesh = sm
			mi.scale = Vector3(sz, sz * (0.7 + randf() * 0.5), sz * (0.8 + randf() * 0.4)) * 2.0
		"crate":
			var bm := BoxMesh.new()
			mi.mesh = bm
			mi.scale = Vector3.ONE * sz
		"barrel":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.5
			cm.bottom_radius = 0.5
			cm.height = 1.25
			cm.radial_segments = 12
			mi.mesh = cm
			mi.scale = Vector3.ONE * sz
		"plank":
			var pm := BoxMesh.new()
			pm.size = Vector3(0.22, 0.1, 2.6)
			mi.mesh = pm
			mi.scale = Vector3.ONE * sz
		_:
			var bk := BoxMesh.new()
			bk.size = Vector3(0.626, 1.0, 0.1 if d["item"] != "bible" else 0.17)
			mi.mesh = bk
			mi.scale = Vector3.ONE * sz
	mi.material_override = _debris_material(d["kind"], d["item"])
	world.add_child(mi)
	return mi


func _storm_visuals(dt: float) -> void:
	var st: StormModel = m.storm
	for d in st.deb:
		if d["node"] == null:
			d["node"] = _make_debris_node(d)
		var n: Node3D = d["node"]
		d["rot"] += (d["spin"] as Vector3) * dt
		n.position = d["p"]
		n.rotation = d["rot"]
	var k := st.level
	var e := k * k * (3.0 - 2.0 * k)
	if sec_on:
		e = maxf(e, 0.0)
	var env := wenv.environment
	var haze: Color = env_def["fog"]
	var storm_col := Color(0.80, 0.60, 0.36)
	var ca := st.cata
	var col := haze.lerp(storm_col, e) * (1.0 - 0.5 * ca * e)
	col.a = 1.0
	env.fog_light_color = col
	env.fog_depth_begin = lerpf(float(env_def["begin"]), 25.0, e)
	env.fog_depth_end = float(env_def["end"]) * pow((1150.0 - 520.0 * ca) / float(env_def["end"]), e)
	sun.light_energy = float(env_def["sun"]) * (1.0 - (0.55 + 0.3 * ca) * e)
	var sm := (env.sky.sky_material as ProceduralSkyMaterial)
	sm.sky_horizon_color = Color(0.82, 0.74, 0.62).lerp(col, e)
	sm.ground_horizon_color = Color(0.82, 0.68, 0.52).lerp(col, e)
	sm.sky_top_color = Color(0.17, 0.38, 0.76).lerp(col, e * 0.85)
	storm_ov.color.a = k * 0.35


func _on_debris_hit() -> void:
	var h: Dictionary = m.storm.last_hit
	if h.is_empty():
		return
	var pws := {"rock": 1.4, "crate": 1.2, "barrel": 1.1, "plank": 0.8, "book": 1.0}
	var pw: float = pws.get(h["kind"], 1.0)
	var nose: bool = h["zone"] == "nose"
	var lk := ""
	if h["zone"] == "wing":
		var i := 0 if h["b"] < 0.0 else 1
		m.sys.leak[i] = minf(0.1, m.sys.leak[i] + 0.02 * pw)
		lk = "WING TANK " + ("R" if i == 1 else "L")
	elif h["zone"] == "fuselage" or h["zone"] == "tail":
		for i in 2:
			m.sys.leak[i] = minf(0.1, m.sys.leak[i] + 0.006 * pw)
		lk = "CENTER FEED LINES"
	if lk != "":
		get_tree().create_timer(0.9).timeout.connect(func():
			say("FUEL LEAK  %s - fuel is draining fast!" % lk, "bad", 4800)
			ui.log_msg("FUEL LEAK: " + lk))
	Sfx.thud(pw)
	Sfx.play("warn", -4.0)
	ui.warn_flash = nose or pw > 1.2
	ui.caut_flash = true
	_caut_t = 0.0
	if not sec_on:
		m.sys.integ = maxf(0.0, m.sys.integ - 0.04 * pw * (1.3 if nose else 1.0))
	glitch_spike = minf(0.3, glitch_spike + 0.15 * pw)
	flash.modulate.a = 0.5
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.35)
	hud.hit(str(h["zone"]))
	var nm := {"rock": "a ROCK", "crate": "a CRATE", "barrel": "a BARREL", "plank": "a PLANK", "book": "a BOOK"}[h["kind"]] as String
	if h["kind"] == "book" and nose:
		var it: String = h["item"] if h["item"] != "" else "bible"
		_start_slap(it)
		var texts := {"bible": "...was that a BIBLE?! \"ALEX BIBLE - Chapter 69\"", "booklet": "A booklet?! \"NAICOLIOUS DATA BOOKLET\"",
			"dvd": "A DVD?! \"THE DARK KNIGHT\"... who throws a DVD at a plane?", "danilo": "A disc?! \"DANILO TUNA FISH\"... is that a man with a fish body?"}
		say(texts.get(it, ""), "bad", 6500)
		ui.log_msg("IMPACT: " + str(Items.DATA[it]["name"]))
	elif h["kind"] == "book":
		say("Something hit the %s... it was a BOOK. A big one." % h["zone"], "bad", 4500)
		ui.log_msg("IMPACT: BOOK (%s)" % str(h["zone"]).to_upper())
	else:
		var upper := nm.replace("a ", "A ")
		if nose:
			say("CRACK! %s hit the windshield! Systems glitching - but still flying." % upper, "bad", 4500)
		else:
			say("Ouch! %s hit the %s. Systems glitching - but still flying." % [nm, h["zone"]], "bad", 4500)
		ui.log_msg("IMPACT: %s (%s)" % [nm.replace("a ", ""), str(h["zone"]).to_upper()])


# ------------------------------------------------------------------ the book that slaps the windshield
func _start_slap(item: String) -> void:
	slap_item = item
	slap_img.texture = load(Items.DATA[item]["img"])
	slap_t = 0.0
	slap_dir = -1.0 if randf() < 0.5 else 1.0
	slap_grabbed = false
	slap.visible = true
	slap.modulate.a = 1.0
	slap.mouse_filter = Control.MOUSE_FILTER_STOP


func _update_slap(dt: float) -> void:
	if slap_t < 0.0 or slap_grabbed:
		return
	slap_t += dt
	var t := slap_t
	var x := 0.0
	var y := 0.0
	var sc := 1.0
	var rot := 0.0
	var hold := 2.1
	var slide := 2.6
	if t < 0.3:
		var u := t / 0.3
		var e := 1.0 - pow(1.0 - u, 3.0)
		sc = lerpf(0.12, 1.07, e)
		rot = slap_dir * (-14.0 + 11.0 * e)
		y = -30.0 * (1.0 - e)
	elif t < 0.46:
		sc = 1.07 - 0.07 * (t - 0.3) / 0.16
		rot = -slap_dir * 3.0
	elif t < hold:
		sc = 1.0 + sin(t * 3.0) * 0.006
		rot = -slap_dir * (3.0 - minf(1.0, (t - 0.46) / 1.2) * 1.2)
		y = sin(t * 1.7) * 3.0
	else:
		var u := clampf((t - hold) / slide, 0.0, 1.0)
		var e := u * u * (0.55 + 0.45 * u)
		x = slap_dir * e * 620.0
		rot = -slap_dir * 1.8 + slap_dir * u * 22.0
		sc = 1.0 - u * 0.12
		y = u * 30.0
		if u >= 1.0:
			_end_slap()
			return
	slap.position = Vector2(650.0 + x, 70.0 + y)
	slap.scale = Vector2(sc, sc)
	slap.rotation = deg_to_rad(rot)


func _end_slap() -> void:
	slap_t = -1.0
	slap.visible = false


func _on_slap_input(ev: InputEvent) -> void:
	if slap_t < 0.0 or slap_grabbed:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		slap_grabbed = true
		var added := Game.add_item(slap_item)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(slap, "position", Vector2(1340.0, 20.0), 0.6)
		tw.tween_property(slap, "scale", Vector2(0.04, 0.04), 0.6)
		tw.tween_property(slap, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(_end_slap)
		if added:
			Sfx.chime()
			say("%s scanned to PDA storage. (Press I to open.)" % Items.DATA[slap_item]["name"], "ok", 4200)
			ui.log_msg("PDA: +" + str(Items.DATA[slap_item]["name"]))
			m.secret_ok = Game.item_count("bible") >= 3
		else:
			say("PDA storage full (12/12). The item slips away.", "ok", 3500)


# ------------------------------------------------------------------ fuel / hull shutdown ending
func _shut_maybe() -> void:
	if shut_st != "idle" or m.crashed != "" or m.f_lockout or m.f_secret or fin_st != "idle":
		return
	if m.sys.integ <= 0.0005:
		_shut_start("hull")
	elif m.sys.fuel_total() <= 0.0005:
		_shut_start("fuel")


func _shut_start(why: String) -> void:
	shut_st = "run"
	shut_t = 0.0
	shut_why = why
	ui.warp = 1
	var hull := why == "hull"
	shut_seg = []
	var u := 0.0 if hull else 1.9
	if hull:
		shut_seg.append_array([[0.12, 0.15], [0.22, 1.0], [0.4, 0.3], [0.55, 1.0], [1.6, 1.0]])
		u = 1.6
	else:
		shut_seg.append([1.9, 1.0])
	while u < 7.4:
		var kk := (u - 1.9) / 5.5
		var on := randf() < 0.88 - 0.78 * kk
		var d := (0.05 + randf() * 0.26) if on else (0.04 + randf() * 0.16)
		u = minf(7.4, u + d)
		shut_seg.append([u, (0.35 + randf() * 0.4 if randf() < 0.35 else 1.0) if on else randf() * 0.08])
	shut_seg.append([99.0, 0.0])
	var e1 := 0.8 if hull else 0.45
	var e2 := 1.5 if hull else 1.25
	shut_ev = [
		[0.05, "AIRFRAME FAILURE  SYS INTEG 0%" if hull else "FUEL  EMPTY", ""],
		[e1, "", "eng1"], [e1 + 0.1, "ENG 1  FLAMEOUT", ""],
		[e2, "", "eng2"], [e2 + 0.1, "ENG 2  FLAMEOUT", ""],
		[1.9, "HYD A+B  LOSS", ""], [2.3, "GEN 1+2  OFF", ""], [3.4, "BUS TIE  FAIL", ""],
		[5.0, "ELEC  EMERGENCY", ""], [6.4, "DC BUS  FAIL", ""], [7.4, "ALL SYSTEMS OFFLINE", ""],
	]
	m.ap_on = false
	m.ap_athr = false
	if m.al_st == "ARM" or m.al_st == "ENG":
		m.al_st = "OFF"
	m.f_lockout = false
	Sfx.meme("death", 0.9)
	if hull:
		glitch_spike = 0.5


func _shut_level(t: float) -> float:
	for g in shut_seg:
		if t < g[0]:
			return g[1]
	return 0.0


func _shut_update(dt: float) -> void:
	if shut_st != "run" and shut_st != "end":
		return
	if shut_st == "end":
		m.sys.shut_level = 0.0
		if m.on_ground and state == St.FLY:
			state = St.DONE
			finished.emit("dead_" + shut_why)
		return
	shut_t += dt
	var keep: Array = []
	for e in shut_ev:
		if shut_t >= e[0]:
			if e[1] != "":
				say(e[1], "bad", 2400)
				ui.log_msg(e[1])
			if e[2] == "eng1":
				m.sys.eng_run[0] = false
				m.sys.eng_st[0] = 0.0
				if shut_why == "fuel":
					m.sys.fuel = [0.0, 0.0]
			elif e[2] == "eng2":
				m.sys.eng_run[1] = false
				m.sys.eng_st[1] = 0.0
		else:
			keep.append(e)
	shut_ev = keep
	var lv := _shut_level(shut_t)
	m.sys.shut_level = lv
	m.sys.batt = 1.0 if lv > 0.2 else 0.0
	m.sys.apu = 0.0
	m.lever_cmd = 0.0
	if shut_t >= 11.8:
		shut_st = "end"
		if m.on_ground:
			state = St.DONE
			finished.emit("dead_" + shut_why)


# ------------------------------------------------------------------ the secret ending (three bibles at MASTER KING)
const SEC_KN: Array = [[0.0, 1.0], [21.0, 1.0], [26.0, 0.6], [31.0, 0.25], [46.0, 0.05]]
var sec_ext := false
var sec_sealed_t := 0.0
var sec_seal := 0.0
var sec_cam_k := 0.0
var sec_msg_t := 0.0
var sec_flash_cd := 0.0


func _sec_now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _sec_t() -> float:
	if sec_mus != null and is_instance_valid(sec_mus) and sec_mus.playing:
		return sec_mus.get_playback_position()
	return _sec_now() - sec_t0


func _sec_curve(t: float) -> float:
	if t <= SEC_KN[0][0]:
		return SEC_KN[0][1]
	for i in range(1, SEC_KN.size()):
		if t <= SEC_KN[i][0]:
			var a: Array = SEC_KN[i - 1]
			var b: Array = SEC_KN[i]
			var u: float = (t - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf(a[1], b[1], u * u * (3.0 - 2.0 * u))
	return SEC_KN[SEC_KN.size() - 1][1]


func _sec_cfg(t: float) -> Dictionary:
	if t < 21.0:
		return {"gap": 2.9, "cap": 9, "hit": 0.0, "big": 1.5}
	var u := clampf((t - 21.0) / 24.0, 0.0, 1.0)
	return {"gap": lerpf(1.5, 0.22, u), "cap": int(lerpf(14.0, 40.0, u)), "hit": lerpf(0.15, 0.8, u), "big": lerpf(1.7, 2.5, u)}


func _sec_begin() -> void:
	if sec_on:
		return
	sec_on = true
	sec_phase = "storm"
	sec_t0 = _sec_now()
	ui.warp = 1
	m.storm.cata_mode = true
	m.storm.state = "on"
	m.storm.cd = 999.0
	sec_i0 = m.sys.integ
	sec_mus = Sfx.meme("cat", 0.95)
	say("AUTOLAND UNAVAILABLE.", "bad", 6000)
	ui.log_msg("AUTOLAND REFUSED - 3 BIBLES ABOARD")
	Sfx.play("warn")
	ui.caut_flash = true


func _sec_msg(txt: String) -> void:
	sec_msg.text = txt
	sec_msg_t = 4.5
	Sfx.play("warn", -10.0, 1.4)


func _sec_update(dt: float) -> void:
	if sec_msg_t > 0.0:
		sec_msg_t -= dt
		if sec_msg_t <= 0.0:
			sec_msg.text = ""
	if not sec_on or sec_phase != "storm":
		return
	var t := _sec_t()
	ui.warp = 1
	m.storm.step_cata(m, dt, _sec_cfg(t))
	m.storm.cata = clampf(t / 36.0, 0.0, 1.0)
	var up := minf(sec_i0, _sec_curve(t))
	var lo := minf(up, maxf(0.05, _sec_curve(t + 3.5)))
	m.sys.integ = clampf(m.sys.integ, lo, up)
	# the pyramid will wait: keep a safe distance from it until the cutscene takes over
	if m.dist_pyr < 1300.0:
		m.pos.x -= sin(m.psi) * m.V * dt
		m.pos.z += cos(m.psi) * m.V * dt
	# one-shot messages
	var once := func(k: String, cond: bool, txt: String):
		if cond and not sec_ms.has(k):
			sec_ms[k] = true
			_sec_msg(txt)
	once.call("d", t >= 15.0, "DANGER  CATASTROPHIC SANDSTORM")
	once.call("a", t >= 17.6, "STORM CELL CAT-5  WIND 190 KT")
	once.call("e", t >= 21.2, "A/P EVASIVE MANEUVERS")
	once.call("f", t >= 24.0, "DEBRIS DENSITY CRITICAL")
	once.call("h", sec_lock, "COCKPIT LOCKDOWN")
	once.call("r", sec_sealed, "SEALED  HUD REBOOT")
	once.call("i", sec_sealed and _sec_now() - sec_sealed_t > 6.0, "EXTERIOR CAMERAS ONLINE")
	once.call("j", sec_cam_k >= 1.0 and t >= 40.0, "STRUCTURAL FAILURE IMMINENT")
	# lockdown at 25%
	if not sec_lock and m.sys.integ <= 0.2505:
		sec_lock = true
		sec_lock_t0 = _sec_now()
		shutters.visible = true
		Sfx.play("thunk")
		ui.warn_flash = true
	if sec_lock:
		var e := _sec_now() - sec_lock_t0
		sec_seal = clampf((e - 0.9) / 5.0, 0.0, 1.0)
		shutter_plate.position.y = -352.0 + 352.0 * sec_seal
		if sec_seal >= 1.0 and not sec_sealed:
			sec_sealed = true
			sec_sealed_t = _sec_now()
			Sfx.play("thunk")
		if sec_sealed:
			sec_cam_k = clampf((_sec_now() - sec_sealed_t - 6.2) / 1.1, 0.0, 1.0)
			if sec_cam_k > 0.0 and not sec_ext:
				sec_ext = true
				shutters.visible = false
				world.plane.visible = true
				Sfx.play("apon")
	# alarms that pile up as the airframe fails
	var i := m.sys.integ
	var due := func(k: String, iv: float) -> bool:
		if _sec_now() - float(sec_alm.get(k, 0.0)) >= iv:
			sec_alm[k] = _sec_now()
			return true
		return false
	if not sec_sealed:
		if i < 0.72 and due.call("w", 3.3):
			Sfx.play("warn", -6.0)
		if i < 0.58 and due.call("s", 2.3):
			Sfx.play("apoff", -8.0)
			ui.warn_flash = true
		if i < 0.34 and due.call("k", 1.1):
			Sfx.play("storm", -8.0)
	# lightning in the dust
	sec_flash_cd -= dt
	if t > 8.0 and sec_flash_cd <= 0.0 and randf() < dt * 0.28:
		sec_flash_cd = 0.5
		flash.modulate.a = 0.35 + randf() * 0.4
		create_tween().tween_property(flash, "modulate:a", 0.0, 0.45)
	if not sec_cine_started and (t >= 46.0 or (m.sys.integ <= 0.0505 and t > 40.0)):
		sec_cine_started = true
		_sec_start_cine()


func _sec_start_cine() -> void:
	sec_phase = "cine"
	shutters.visible = false
	sec_msg.text = ""
	_start_cine("secret")
	cine_p0 = m.pos
	cine_psi = m.psi
	cine_d = Vector3(sin(m.psi), 0, -cos(m.psi))
	cine_nose = m.pos
	sec_cine_t = 0.0
	sec_boomed = false
	world.plane.set_pose(m.pos, m.psi, m.theta, m.phi)


func _cine_secret(dt: float) -> void:
	var pl := world.plane
	sec_cine_t += dt
	var t := sec_cine_t
	if sec_phase == "cine":
		m.storm.step_cata(m, dt, _sec_cfg(46.0))
		_storm_visuals(dt)
		var fwd := cine_d
		if not sec_boomed:
			cine_p0 += fwd * 60.0 * dt
			pl.set_pose(cine_p0, cine_psi, 0.04 * sin(t * 3.0), 0.25 * sin(t * 2.1) + 0.1)
			var behind := -fwd
			camera.position = cine_p0 + behind * 80.0 + Vector3(30, 16, 0)
			camera.look_at(cine_p0, Vector3.UP)
			camera.fov = 45.0
			_set_caption("", false)
			if t >= 5.0:
				sec_boomed = true
				cine_nose = cine_p0
				_boom()
				cine_imp = false
				flash.modulate.a = 1.0
				create_tween().tween_property(flash, "modulate:a", 0.0, 2.5)
		else:
			camera.position = cine_p0 + Vector3(60, 30, 140)
			camera.look_at(cine_p0, Vector3.UP)
			if t >= 9.0:
				_sec_concert()
	elif sec_phase == "concert":
		var a := (t - 9.0) * 0.18
		var c := Vector3(0, WorldData.PYR_BASE + 14.0, 540.0)
		camera.position = c + Vector3(sin(a) * 120.0, 18.0, cos(a) * 120.0 + 60.0)
		camera.look_at(c, Vector3.UP)
		camera.fov = 45.0
		_set_caption("MASTER ALEX" if t < 22.0 else ("Written and performed by Harry (IB12)" if t < 34.0 else ""), false)
		cap_label.add_theme_font_size_override("font_size", 48)
		if sec_stage:
			sec_stage.rotation.y = sin(t * 0.7) * 0.02
		if (sec_alex == null or not is_instance_valid(sec_alex) or not sec_alex.playing) and t > 14.0 and not cine_ended:
			_end_cine_now()


func _sec_concert() -> void:
	sec_phase = "concert"
	if sec_mus and is_instance_valid(sec_mus):
		Sfx.stop_meme(sec_mus, 0.5)
	for d in m.storm.deb:
		if d["node"] != null and is_instance_valid(d["node"]):
			(d["node"] as Node).queue_free()
	m.storm.deb.clear()
	m.storm.reset()
	storm_ov.color.a = 0.0
	# night
	var env := wenv.environment
	var sm := env.sky.sky_material as ProceduralSkyMaterial
	sm.sky_top_color = Color(0.01, 0.02, 0.06)
	sm.sky_horizon_color = Color(0.05, 0.06, 0.12)
	sm.ground_horizon_color = Color(0.03, 0.03, 0.05)
	sm.ground_bottom_color = Color(0.01, 0.01, 0.02)
	env.fog_light_color = Color(0.03, 0.035, 0.07)
	env.fog_depth_begin = 500.0
	env.fog_depth_end = 52000.0
	env.ambient_light_energy = 0.25
	sun.light_energy = 0.05
	world.king_mat.emission = Color("#1a1210")
	# stage and crowd in front of the pyramid
	sec_stage = Node3D.new()
	sec_stage.position = Vector3(0, WorldData.PYR_BASE, 540.0)
	world.add_child(sec_stage)
	var plat := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(60, 3, 24)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.1, 0.1, 0.12)
	pm.material = pmat
	plat.mesh = pm
	plat.position = Vector3(0, 1.5, 0)
	sec_stage.add_child(plat)
	var cols := [Color(1, 0.2, 0.3), Color(0.2, 0.6, 1), Color(1, 0.8, 0.2), Color(0.4, 1, 0.5)]
	for i in 4:
		var sl := SpotLight3D.new()
		sl.light_color = cols[i]
		sl.light_energy = 6.0
		sl.spot_range = 160.0
		sl.spot_angle = 22.0
		sl.position = Vector3(-24.0 + i * 16.0, 40.0, 30.0)
		sl.rotation_degrees = Vector3(-70, i * 6.0 - 9.0, 0)
		sec_stage.add_child(sl)
	var crowd := MultiMesh.new()
	crowd.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.05, 0.05, 0.07)
	cm.material = cmat
	crowd.mesh = cm
	crowd.instance_count = 220
	var rn := RandomNumberGenerator.new()
	rn.seed = 69
	for i in 220:
		crowd.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(rn.randf_range(-40, 40), 0.9 + 0.3 * rn.randf(), rn.randf_range(22, 90))))
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = crowd
	sec_stage.add_child(cmi)
	pl_hide()
	sec_alex = Sfx.meme("alex", 1.0)
	cap_label.add_theme_font_size_override("font_size", 48)


func pl_hide() -> void:
	world.plane.visible = false
	for d in debris:
		if d["n"] != null and is_instance_valid(d["n"]) and d["n"] != world.cap:
			(d["n"] as Node).visible = false


# ------------------------------------------------------------------ LMIA ground services (full sequence in lmia_ground.gd)
var lm: LmiaGround


func _start_lmia_cine() -> void:
	_enter_cine_view()
	cine_mode = "lmia"
	skip_hint.visible = false
	lm = LmiaGround.new()
	world.add_child(lm)
	lm.finished.connect(_on_lmia_done)
	lm.begin(m, world.plane, camera, $Overlay, _lm_caption)


func _lm_caption(txt: String, big: bool) -> void:
	cap_label.text = txt
	cap_label.add_theme_font_size_override("font_size", 64 if big else 40)
	cap_label.add_theme_color_override("font_color", Color.WHITE)


func _on_lmia_done() -> void:
	if state == St.DONE:
		return
	cap_label.text = ""
	state = St.DONE
	finished.emit("lmia")


func _cine_lmia(dt: float) -> void:
	if lm:
		lm.update(dt)
