extends Node
## Audio: the original game's recorded clips plus small procedural sounds
## (the HTML game synthesised these with WebAudio).

const CLIPS := {
	"curse": "res://assets/audio/curse.mp3",
	"scream": "res://assets/audio/scream.mp3",
	"theme": "res://assets/audio/theme.mp3",
	"end": "res://assets/audio/end.mp3",
	"expl": "res://assets/audio/expl.mp3",
	"death": "res://assets/audio/death.mp3",
	"loadsnd": "res://assets/audio/loadsnd.mp3",
	"pdastart": "res://assets/audio/pdastart.mp3",
	"pdaerr": "res://assets/audio/pdaerr.mp3",
	"cat": "res://assets/audio/cat.mp3",
	"alex": "res://assets/audio/alex.mp3",
	"danilo": "res://assets/audio/danilo.mp3",
	"ncjump": "res://assets/audio/ncjump.ogg",
	"ncamb": "res://assets/audio/ncamb.ogg",
	"ncsrv": "res://assets/audio/ncsrv.ogg",
}

const MIX := 22050

var muted := false
var siren_on := false
var _streams := {}
var _proc := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _engine: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _siren: AudioStreamPlayer
var _theme: AudioStreamPlayer
var _theme_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1234
	for i in 10:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_pool.append(pl)
	_engine = AudioStreamPlayer.new()
	_engine.stream = _loop_noise(2.0, 0.035)
	_engine.volume_db = -80.0
	add_child(_engine)
	_wind = AudioStreamPlayer.new()
	_wind.stream = _loop_noise(2.0, 0.12)
	_wind.volume_db = -80.0
	add_child(_wind)
	_siren = AudioStreamPlayer.new()
	_siren.stream = _loop_siren()
	_siren.volume_db = -80.0
	add_child(_siren)
	_theme = AudioStreamPlayer.new()
	add_child(_theme)
	_proc["blip"] = _tone(660.0, 660.0, 0.05, 0.25, 0)
	_proc["click"] = _tone(1800.0, 900.0, 0.03, 0.3, 1)
	_proc["clunk"] = _tone(140.0, 55.0, 0.16, 0.7, 2)
	_proc["thunk"] = _tone(90.0, 40.0, 0.35, 0.8, 2)
	_proc["chime"] = _chime()
	_proc["chirp"] = _tone(900.0, 1700.0, 0.12, 0.25, 0)
	_proc["apon"] = _tone(1200.0, 1200.0, 0.08, 0.25, 1)
	_proc["apoff"] = _tone(900.0, 500.0, 0.5, 0.3, 3)
	_proc["warn"] = _tone(1500.0, 1500.0, 0.2, 0.25, 1)
	_proc["thud"] = _tone(70.0, 30.0, 0.25, 0.9, 2)
	_proc["storm"] = _tone(400.0, 200.0, 0.8, 0.3, 3)


func clip(name: String) -> AudioStream:
	if not _streams.has(name):
		_streams[name] = load(CLIPS[name]) if CLIPS.has(name) else null
	return _streams[name]


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)


func toggle_mute() -> void:
	set_muted(not muted)


func _next_player() -> AudioStreamPlayer:
	_pool_i = (_pool_i + 1) % _pool.size()
	return _pool[_pool_i]


## Play a procedural one-shot by name.
func play(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not _proc.has(name):
		return
	var pl := _next_player()
	pl.stream = _proc[name]
	pl.volume_db = vol_db
	pitch_scale_safe(pl, pitch)
	pl.play()


func pitch_scale_safe(pl: AudioStreamPlayer, pitch: float) -> void:
	pl.pitch_scale = maxf(0.05, pitch)


func blip() -> void: play("blip", -8.0)
func click() -> void: play("click", -6.0)
func clunk() -> void: play("clunk", -3.0)
func chime() -> void: play("chime", -6.0)
func chirp() -> void: play("chirp", -8.0)
func thud(v := 0.5) -> void: play("thud", linear_to_db(clampf(v, 0.05, 1.0)))
func gear_thunk() -> void: play("thunk", -2.0)
func tone_up() -> void: play("apon", -6.0)
func tone_down() -> void: play("apoff", -6.0)


## Play a recorded clip; returns the dedicated player so callers can stop it.
func meme(name: String, gain := 1.0) -> AudioStreamPlayer:
	var s := clip(name)
	if s == null:
		return null
	var pl := AudioStreamPlayer.new()
	pl.stream = s
	pl.volume_db = linear_to_db(maxf(gain, 0.001))
	add_child(pl)
	pl.finished.connect(pl.queue_free)
	pl.play()
	return pl


func stop_meme(pl: AudioStreamPlayer, fade := 0.05) -> void:
	if pl == null or not is_instance_valid(pl):
		return
	var tw := create_tween()
	tw.tween_property(pl, "volume_db", -60.0, maxf(fade, 0.01))
	tw.tween_callback(pl.queue_free)


func curse() -> AudioStreamPlayer:
	return meme("curse", 0.6)


func scream() -> AudioStreamPlayer:
	return meme("scream", 2.2)


func explosion() -> void:
	meme("expl", 1.6)


func pitch_down(pl: AudioStreamPlayer, to: float, dur: float) -> void:
	if pl == null or not is_instance_valid(pl):
		return
	var tw := create_tween()
	tw.tween_property(pl, "pitch_scale", maxf(to, 0.05), dur)


## Background music with fade-in. name is a CLIPS key ("theme" or "end").
func theme(name: String, vol := 0.85, fade := 3.0) -> void:
	var s := clip(name)
	if s == null:
		return
	if _theme_tween:
		_theme_tween.kill()
	_theme.stream = s
	_theme.volume_db = -60.0
	_theme.play()
	_theme_tween = create_tween()
	_theme_tween.tween_property(_theme, "volume_db", linear_to_db(vol), fade)


func theme_stop(fade := 1.2) -> void:
	if _theme_tween:
		_theme_tween.kill()
	if not _theme.playing:
		return
	_theme_tween = create_tween()
	_theme_tween.tween_property(_theme, "volume_db", -60.0, fade)
	_theme_tween.tween_callback(_theme.stop)


func siren(on: bool) -> void:
	siren_on = on
	if on:
		_siren.volume_db = -8.0
		if not _siren.playing:
			_siren.play()
	else:
		_siren.stop()
		_siren.volume_db = -80.0


## Engine rumble + wind driven by the flight model. active=false silences both.
func engine_update(n1: float, speed: float, active: bool) -> void:
	if not active:
		if _engine.playing:
			_engine.stop()
		if _wind.playing:
			_wind.stop()
		return
	if not _engine.playing:
		_engine.play()
	if not _wind.playing:
		_wind.play()
	var k := clampf((n1 - 24.0) / 76.0, 0.0, 1.0)
	_engine.pitch_scale = 0.55 + 1.2 * k
	_engine.volume_db = linear_to_db(0.05 + 0.5 * k)
	_wind.pitch_scale = 0.6 + speed / 220.0
	_wind.volume_db = linear_to_db(clampf(speed / 260.0, 0.0, 1.0) * 0.5 + 0.001)


func stop_all_loops() -> void:
	engine_update(24.0, 0.0, false)
	siren(false)


# ---------------------------------------------------------------- procedural sample builders
func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## shape: 0 sine, 1 square, 2 sine + noise thump, 3 sawtooth
func _tone(f0: float, f1: float, dur: float, vol: float, shape: int) -> AudioStreamWAV:
	var n := int(MIX * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var u := float(i) / n
		var f := lerpf(f0, f1, u)
		ph += TAU * f / MIX
		var env := (1.0 - u) * minf(1.0, u * 40.0)
		var v := 0.0
		match shape:
			0:
				v = sin(ph)
			1:
				v = 1.0 if sin(ph) > 0.0 else -1.0
			2:
				v = sin(ph) * 0.8 + (_rng.randf() * 2.0 - 1.0) * 0.25 * (1.0 - u)
			_:
				v = fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		s[i] = v * env * vol
	return _to_wav(s)


func _chime() -> AudioStreamWAV:
	var n := int(MIX * 0.7)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var u := float(i) / n
		var t := float(i) / MIX
		var v := sin(TAU * 880.0 * t) * 0.5 + sin(TAU * 1320.0 * t) * 0.3
		if u > 0.35:
			v += sin(TAU * 1760.0 * (t - 0.25)) * 0.3
		s[i] = v * pow(1.0 - u, 2.0) * 0.5
	return _to_wav(s)


func _loop_noise(dur: float, smooth: float) -> AudioStreamWAV:
	var n := int(MIX * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var w := _rng.randf() * 2.0 - 1.0
		lp += smooth * (w - lp)
		s[i] = lp * 2.5
	# crossfade the tail into the head so the loop is seamless
	var x := int(MIX * 0.05)
	for i in x:
		var a := float(i) / x
		s[i] = lerpf(s[n - x + i], s[i], a)
	return _to_wav(s, true)


func _loop_siren() -> AudioStreamWAV:
	var dur := 1.6
	var n := int(MIX * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var u := float(i) / n
		var f := 650.0 + 350.0 * (0.5 - 0.5 * cos(TAU * u))
		ph += TAU * f / MIX
		s[i] = (1.0 if sin(ph) > 0.0 else -1.0) * 0.18
	return _to_wav(s, true)
