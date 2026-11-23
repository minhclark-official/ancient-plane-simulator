class_name WorldData
extends RefCounted
## Geography of the game world (a direct port of the HTML game's world model):
## pyramids, runways, destinations, the Nile valley and the terrain height field.
## World axes: +X east, +Y up, -Z north. Heading 0 = north (-Z), clockwise positive.

const NM := 1852.0
const KT := 0.514444
const FT := 0.3048
const G0 := 9.80665
const D2R := PI / 180.0
const R2D := 180.0 / PI

# ---------------------------------------------------------------- pyramids
const PYR_NAME := "MASTER KING"
const PYR_X := 0.0
const PYR_Z := 0.0
const PYR_HALF := 115.2 * 3.2
const PYR_H := 146.6 * 3.2
const PYR_BASE := 60.0
const PYR_SLOPE := PYR_H / PYR_HALF
## virtual "runway threshold" sits ON the face, 120 m up
const THR_X := 0.0
const THR_HH := 120.0
const THR_Z := PYR_HALF - THR_HH / PYR_SLOPE
const THR_Y := PYR_BASE + THR_HH

const OTHER_PYRS: Array = [
	{"name": "KHAFRE", "x": -1150.0, "z": 620.0, "half": 107.5, "h": 143.5, "base": 60.0},
	{"name": "MENKAURE", "x": -1650.0, "z": 1300.0, "half": 51.5, "h": 65.0, "base": 60.0},
	{"name": "Q1", "x": 760.0, "z": -250.0, "half": 22.0, "h": 28.0, "base": 60.0},
	{"name": "Q2", "x": 760.0, "z": -350.0, "half": 22.0, "h": 28.0, "base": 60.0},
	{"name": "Q3", "x": 760.0, "z": -450.0, "half": 22.0, "h": 28.0, "base": 60.0},
	{"name": "BENT", "x": -3200.0, "z": 41000.0, "half": 94.0, "h": 105.0, "base": 58.0},
	{"name": "RED", "x": -3100.0, "z": 38200.0, "half": 110.0, "h": 105.0, "base": 58.0},
	{"name": "SAQQARA", "x": -1800.0, "z": 23500.0, "half": 60.0, "h": 62.0, "base": 60.0},
]

# ---------------------------------------------------------------- runways
const AIRPORT := {"name": "LEMUEL INTL", "code": "LMIA", "x": -9000.0, "z": 46000.0, "len": 3200.0, "wid": 60.0, "elev": 55.0,
	"thrZ": 46000.0 + 1600.0, "endZ": 46000.0 - 1600.0}
const JRNA := {"name": "JRNA", "code": "JRNA", "x": 1700.0, "z": -600.0, "len": 2400.0, "wid": 52.0, "elev": 60.0,
	"thrZ": -600.0 + 1200.0, "endZ": -600.0 - 1200.0}
const NCLR := {"name": "NCLR", "code": "NCLR", "x": 15500.0, "z": 4400.0, "len": 2800.0, "wid": 52.0, "elev": 18.4,
	"thrZ": 4400.0 + 1400.0, "endZ": 4400.0 - 1400.0}
const LMRW := {"name": "LMIA", "code": "LMIA", "x": -9470.0, "z": 46000.0, "len": 3000.0, "wid": 56.0, "elev": 55.0,
	"thrZ": 46000.0 + 1500.0, "endZ": 46000.0 - 1500.0}
const RUNWAYS: Array = [AIRPORT, JRNA, NCLR, LMRW]

const DESTS := {
	"MKNG": {"id": "MKNG", "short": "MKNG", "name": "MASTER KING", "x": THR_X, "z": THR_Z, "y": THR_Y, "rwy": "36"},
	"JRNA": {"id": "JRNA", "short": "JRNA", "name": "JRNA", "x": 1700.0, "z": 600.0, "y": 75.0, "rwy": "36"},
	"NCLR": {"id": "NCLR", "short": "NCLR", "name": "NAICOL REACTOR", "x": 15500.0, "z": 5800.0, "y": 33.4, "rwy": "36"},
	"LMIA": {"id": "LMIA", "short": "LMIA", "name": "LEMUEL INTL", "x": -9470.0, "z": 47500.0, "y": 70.0, "rwy": "36L"},
}
const IAF_NM := 5.0

# ---------------------------------------------------------------- terrain grid
const TER_X0 := -46000.0
const TER_Z0 := -56000.0
const TER_CELL := 420.0
const TER_NX := 262
const TER_NZ := 286

static var H := PackedFloat32Array()
static var COLORS := PackedByteArray()
static var _cities: Array = []


static func clampf_(x: float, a: float, b: float) -> float:
	return a if x < a else (b if x > b else x)


static func sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func wrap180(d: float) -> float:
	d = fposmod(d + 180.0, 360.0)
	return d - 180.0


static func wrap360(d: float) -> float:
	return fposmod(d, 360.0)


static func wrap_pi(a: float) -> float:
	return fposmod(a + PI, 2.0 * PI) - PI


# ---------------------------------------------------------------- noise
const _M := 0xFFFFFFFF


static func hash2(ix: int, iz: int) -> float:
	var h: int = ((((ix & _M) * 374761393) & _M) + (((iz & _M) * 668265263) & _M)) & _M
	h = (((h ^ (h >> 13)) * 1274126177) & _M)
	h = h ^ (h >> 16)
	return float(h & _M) / 4294967296.0


static func vnoise(x: float, z: float) -> float:
	var ix := int(floor(x))
	var iz := int(floor(z))
	var fx := x - ix
	var fz := z - iz
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uz := fz * fz * (3.0 - 2.0 * fz)
	return lerpf(lerpf(hash2(ix, iz), hash2(ix + 1, iz), ux), lerpf(hash2(ix, iz + 1), hash2(ix + 1, iz + 1), ux), uz)


static func fbm(x: float, z: float, o: int) -> float:
	var s := 0.0
	var a := 0.5
	var f := 1.0
	var n := 0.0
	for i in o:
		s += a * vnoise(x * f + i * 17.3, z * f - i * 9.1)
		n += a
		a *= 0.5
		f *= 2.03
	return s / n


static func ridged(x: float, z: float, o: int) -> float:
	var s := 0.0
	var a := 0.5
	var f := 1.0
	var n := 0.0
	for i in o:
		var v := 1.0 - absf(vnoise(x * f + i * 5.7, z * f + i * 3.1) * 2.0 - 1.0)
		v *= v
		s += a * v
		n += a
		a *= 0.5
		f *= 2.1
	return s / n


# ---------------------------------------------------------------- the world of Egypt
static func nile_x(z: float) -> float:
	return 9500.0 + 3600.0 * sin(z / 16000.0 + 0.7) + 1400.0 * sin(z / 5200.0 + 2.0)


static func valley_half(z: float) -> float:
	var w := 5200.0 + 1500.0 * sin(z / 9000.0 + 1.0)
	if z < -22000.0:
		w += (-22000.0 - z) * 0.9
	return w


## 1 inside the green valley, 0 in desert
static func valley_t(x: float, z: float) -> float:
	var d := absf(x - nile_x(z))
	var w := valley_half(z)
	return 1.0 - sstep(w - 350.0, w + 250.0, d)


static func airport_w(x: float, z: float) -> float:
	var dx := maxf(0.0, absf(x - AIRPORT["x"]) - 900.0)
	var dz := maxf(0.0, absf(z - AIRPORT["z"]) - float(AIRPORT["len"]) / 2.0 - 700.0)
	return 1.0 - sstep(0.0, 1100.0, Vector2(dx, dz).length())


static func nclr_w(x: float, z: float) -> float:
	var dx := maxf(0.0, absf(x - 16000.0) - 1100.0)
	var dz := maxf(0.0, absf(z - float(NCLR["z"])) - float(NCLR["len"]) / 2.0 - 250.0)
	return 1.0 - sstep(0.0, 900.0, Vector2(dx, dz).length())


static func terrain_h(x: float, z: float) -> float:
	var nx := nile_x(z)
	var w := valley_half(z)
	var plateau := 62.0 + 16.0 * fbm(x / 14000.0 + 3.1, z / 14000.0 + 7.7, 3)
	var west := 0.0
	if x < nx:
		west = 8.0 * fbm(x / 2300.0, z / 2300.0, 3)
	var ee := sstep(nx + w + 1500.0, nx + w + 16000.0, x)
	var east := 0.0
	if ee > 0.0:
		east = ee * (140.0 + 560.0 * ridged(x / 9000.0 + 2.0, z / 9000.0 + 8.0, 4))
	var dunes := 26.0 * (ridged(x / 4200.0 + 1.0, z / 2100.0 + 7.0, 3) - 0.42) * (1.0 - sstep(nx - w - 3000.0, nx - w + 1500.0, x) * 0.6)
	var desert := plateau + west + east + dunes
	var floor_h := 18.0 + 0.8 * fbm(x / 3000.0, z / 3000.0, 2)
	var h := lerpf(desert, floor_h, valley_t(x, z))
	var r := Vector2(x - PYR_X, z - PYR_Z).length()
	h = lerpf(h, 60.0, 1.0 - sstep(2600.0, 4600.0, r))
	h = lerpf(h, float(AIRPORT["elev"]), airport_w(x, z))
	h = lerpf(h, float(NCLR["elev"]), nclr_w(x, z))
	return h


## Bilinear lookup in the cached grid (exactly what the mesh shows).
static func ground_h(x: float, z: float) -> float:
	if H.size() == 0:
		return terrain_h(x, z)
	var fx := (x - TER_X0) / TER_CELL
	var fz := (z - TER_Z0) / TER_CELL
	if fx < 0.0 or fz < 0.0 or fx >= TER_NX or fz >= TER_NZ:
		return terrain_h(x, z)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var n := TER_NX + 1
	var a := H[j * n + i]
	var b := H[j * n + i + 1]
	var c := H[(j + 1) * n + i]
	var d := H[(j + 1) * n + i + 1]
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (b - d) * (1.0 - v) + (c - d) * (1.0 - u)


# ---------------------------------------------------------------- cities (placement + colour mask)
static func cities() -> Array:
	if _cities.size() > 0:
		return _cities
	_cities.append({"x": nile_x(-12500.0) + 5200.0, "z": -12500.0, "r": 11000.0, "n": 7800, "tall": 1.0})
	_cities.append({"x": nile_x(-12500.0) - 3800.0, "z": -9000.0, "r": 5200.0, "n": 2300, "tall": 0.5})
	_cities.append({"x": nile_x(-500.0) - 3600.0, "z": -300.0, "r": 3400.0, "n": 1900, "tall": 0.55})
	var rn := Rnd.new(55)
	var z := 6000.0
	while z < 60000.0:
		var s := -1.0 if rn.next() < 0.5 else 1.0
		_cities.append({"x": nile_x(z) + s * (1100.0 + rn.next() * 1500.0), "z": z, "r": 700.0 + rn.next() * 900.0,
			"n": 150 + int(floor(rn.next() * 200.0)), "tall": 0.12})
		z += 4200.0 + rn.next() * 3000.0
	return _cities


static func city_mask(x: float, z: float) -> float:
	var m := 0.0
	for c in cities():
		var d := Vector2(x - c["x"], z - c["z"]).length() / float(c["r"])
		if d < 1.0:
			m = maxf(m, (1.0 - d) * 1.4)
	return clampf(m, 0.0, 0.8)


static func terrain_color(x: float, z: float, h: float) -> Color:
	var vt := valley_t(x, z)
	var n := fbm(x / 1900.0, z / 1900.0, 3)
	var n2 := vnoise(x / 260.0, z / 260.0)
	var rock_f := sstep(120.0, 300.0, h)
	var dune := ridged(x / 2600.0 + 3.0, z / 1500.0 + 1.0, 3)
	var sand := Color(0.90, 0.76, 0.54)
	var sand2 := Color(0.84, 0.68, 0.46)
	var dunec := Color(0.95, 0.82, 0.58)
	var rock := Color(0.58, 0.45, 0.34)
	var rock2 := Color(0.46, 0.37, 0.30)
	var d := sand.lerp(sand2, n)
	d = d.lerp(dunec, sstep(0.55, 0.9, dune) * 0.7)
	d = d.lerp(rock.lerp(rock2, n), rock_f)
	var pr := 1.0 - sstep(1800.0, 4600.0, Vector2(x - PYR_X, z - PYR_Z).length())
	d = d.lerp(Color(0.93, 0.80, 0.57), pr)
	var fields: Array = [Color(0.36, 0.52, 0.20), Color(0.45, 0.58, 0.24), Color(0.55, 0.60, 0.26),
		Color(0.30, 0.45, 0.18), Color(0.62, 0.55, 0.30), Color(0.50, 0.40, 0.24)]
	var fi := int(floor(vnoise(x / 330.0 + 4.0, z / 330.0 + 9.0) * 6.0)) % 6
	var sh := 0.9 + 0.2 * n2
	var fc: Color = fields[fi]
	var v := Color(fc.r * sh, fc.g * sh, fc.b * sh)
	v = v.lerp(Color(0.62, 0.55, 0.46), city_mask(x, z))
	var c := d.lerp(v, vt)
	c.a = 1.0
	return c


## Builds the height + colour grid from scratch (slow; normally loaded from the baked file).
static func compute_grid() -> void:
	var nx := TER_NX + 1
	var nz := TER_NZ + 1
	H = PackedFloat32Array()
	H.resize(nx * nz)
	COLORS = PackedByteArray()
	COLORS.resize(nx * nz * 3)
	for j in nz:
		for i in nx:
			var x := TER_X0 + i * TER_CELL
			var z := TER_Z0 + j * TER_CELL
			H[j * nx + i] = terrain_h(x, z)
	for j in nz:
		for i in nx:
			var k := j * nx + i
			var c := terrain_color(TER_X0 + i * TER_CELL, TER_Z0 + j * TER_CELL, H[k])
			COLORS[k * 3] = int(clampf(c.r, 0.0, 1.0) * 255.0)
			COLORS[k * 3 + 1] = int(clampf(c.g, 0.0, 1.0) * 255.0)
			COLORS[k * 3 + 2] = int(clampf(c.b, 0.0, 1.0) * 255.0)


const GRID_FILE := "res://assets/data/terrain.bin"


static func load_grid() -> bool:
	if H.size() > 0:
		return true
	if not FileAccess.file_exists(GRID_FILE):
		return false
	var f := FileAccess.open(GRID_FILE, FileAccess.READ)
	if f == null:
		return false
	var nx := f.get_32()
	var nz := f.get_32()
	if nx != TER_NX + 1 or nz != TER_NZ + 1:
		return false
	H = f.get_buffer(nx * nz * 4).to_float32_array()
	COLORS = f.get_buffer(nx * nz * 3)
	return H.size() == nx * nz and COLORS.size() == nx * nz * 3


static func save_grid() -> void:
	var f := FileAccess.open(GRID_FILE, FileAccess.WRITE)
	f.store_32(TER_NX + 1)
	f.store_32(TER_NZ + 1)
	f.store_buffer(H.to_byte_array())
	f.store_buffer(COLORS)
	f.close()


static func ensure_grid() -> void:
	if load_grid():
		return
	compute_grid()


# ---------------------------------------------------------------- pyramid tests
static func in_pyramid(px: float, pz: float, half: float, h: float, base: float, x: float, y: float, z: float) -> bool:
	var dy := y - base
	if dy < -5.0 or dy > h:
		return false
	var w := half * (1.0 - dy / h)
	return absf(x - px) < w and absf(z - pz) < w


## Returns the name of the pyramid hit, or "" when clear.
static func hits_pyramid(x: float, y: float, z: float) -> String:
	if in_pyramid(PYR_X, PYR_Z, PYR_HALF, PYR_H, PYR_BASE, x, y, z):
		return PYR_NAME
	for p in OTHER_PYRS:
		if in_pyramid(p["x"], p["z"], p["half"], p["h"], p["base"], x, y, z):
			return p["name"]
	return ""


# ---------------------------------------------------------------- atmosphere
## returns Vector2(rho, speed of sound)
static func isa(h: float) -> Vector2:
	h = maxf(-300.0, h)
	var t := 288.15 - 0.0065 * h
	var p := 101325.0 * pow(t / 288.15, 5.25588)
	return Vector2(p / (287.05 * t), sqrt(1.4 * 287.05 * t))


## xorshift32 pseudo random generator (same sequence as the HTML game's rnd()).
class Rnd:
	var s: int

	func _init(seed_: int) -> void:
		s = seed_ & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> float:
		s = (s ^ (s << 13)) & 0xFFFFFFFF
		s = s ^ (s >> 17)
		s = (s ^ (s << 5)) & 0xFFFFFFFF
		return float(s) / 4294967296.0
