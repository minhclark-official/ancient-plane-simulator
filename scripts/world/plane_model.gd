class_name PlaneModel
extends Node3D
## The twin-jet, built from primitive meshes. The model origin is the centre of gravity,
## the nose points to local -Z (like the flight model's heading 0 = north = -Z).
## `parts` lets the crash cutscene tear the aircraft apart.

const NOSE_LEN := 21.0

var parts := {}


func _ready() -> void:
	_build()


func _mat(c: Color, metallic := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m


func _part(pname: String, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.name = pname
	add_child(mi)
	parts[pname] = mi
	return mi


func _build() -> void:
	var white := _mat(Color("#ecebe4"), 0.1, 0.5)
	var gold := _mat(Color("#d9a52a"), 0.4, 0.4)
	var grey := _mat(Color("#8c9096"), 0.3, 0.5)
	var dark := _mat(Color("#222428"), 0.0, 0.8)
	var glass := _mat(Color("#203040"), 0.6, 0.1)

	var fus := CylinderMesh.new()
	fus.top_radius = 2.0
	fus.bottom_radius = 2.0
	fus.height = 32.0
	fus.radial_segments = 16
	_part("fuselage", fus, white, Vector3.ZERO, Vector3(90, 0, 0))

	var nose := CylinderMesh.new()
	nose.top_radius = 0.15
	nose.bottom_radius = 2.0
	nose.height = 5.0
	nose.radial_segments = 16
	_part("nose", nose, white, Vector3(0, 0, -18.5), Vector3(-90, 0, 0))

	var cockpit := BoxMesh.new()
	cockpit.size = Vector3(3.2, 0.7, 1.4)
	_part("cockpit", cockpit, glass, Vector3(0, 0.9, -17.0))

	var tail := CylinderMesh.new()
	tail.top_radius = 0.3
	tail.bottom_radius = 2.0
	tail.height = 8.0
	tail.radial_segments = 16
	_part("tail", tail, white, Vector3(0, 0.6, 20.0), Vector3(90, 0, 0))

	var stripe := CylinderMesh.new()
	stripe.top_radius = 2.03
	stripe.bottom_radius = 2.03
	stripe.height = 3.0
	stripe.radial_segments = 16
	_part("stripe", stripe, gold, Vector3(0, 0, -6.0), Vector3(90, 0, 0))

	var wing := BoxMesh.new()
	wing.size = Vector3(22.0, 0.45, 6.5)
	_part("wingL", wing, grey, Vector3(-12.5, -1.4, 2.5), Vector3(0, 28, -3))
	_part("wingR", wing, grey, Vector3(12.5, -1.4, 2.5), Vector3(0, -28, 3))

	var eng := CylinderMesh.new()
	eng.top_radius = 1.2
	eng.bottom_radius = 1.0
	eng.height = 4.8
	eng.radial_segments = 14
	_part("engL", eng, dark, Vector3(-9.3, -3.0, -1.2), Vector3(90, 0, 0))
	_part("engR", eng, dark, Vector3(9.3, -3.0, -1.2), Vector3(90, 0, 0))

	var fin := BoxMesh.new()
	fin.size = Vector3(0.5, 7.5, 5.5)
	_part("fin", fin, gold, Vector3(0, 5.2, 19.0), Vector3(-18, 0, 0))

	var stab := BoxMesh.new()
	stab.size = Vector3(8.0, 0.35, 3.4)
	_part("stabL", stab, grey, Vector3(-5.0, 1.0, 21.0), Vector3(0, 22, 0))
	_part("stabR", stab, grey, Vector3(5.0, 1.0, 21.0), Vector3(0, -22, 0))

	var gear := Node3D.new()
	gear.name = "gear"
	add_child(gear)
	parts["gear"] = gear
	var strut := CylinderMesh.new()
	strut.top_radius = 0.15
	strut.bottom_radius = 0.15
	strut.height = 3.0
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.55
	wheel.bottom_radius = 0.55
	wheel.height = 0.5
	for gp in [Vector3(0, -3.0, -14.0), Vector3(-4.2, -3.0, 3.5), Vector3(4.2, -3.0, 3.5)]:
		var s := MeshInstance3D.new()
		s.mesh = strut
		s.material_override = grey
		s.position = gp + Vector3(0, 1.0, 0)
		gear.add_child(s)
		var w := MeshInstance3D.new()
		w.mesh = wheel
		w.material_override = dark
		w.position = gp + Vector3(0, -0.45, 0)
		w.rotation_degrees = Vector3(0, 0, 90)
		gear.add_child(w)


## Pose the whole aircraft: position of the CG, heading psi, pitch theta, bank phi (radians).
func set_pose(p: Vector3, psi: float, theta: float, phi: float) -> void:
	global_position = p
	basis = Basis.from_euler(Vector3(theta, -psi, -phi), EULER_ORDER_YXZ)


func set_gear_visible(v: bool) -> void:
	if parts.has("gear"):
		(parts["gear"] as Node3D).visible = v


## Put every part back where it started (after a crash cutscene).
func reset_parts() -> void:
	for k in parts:
		var n: Node3D = parts[k]
		if n.get_parent() != self:
			n.get_parent().remove_child(n)
			add_child(n)
	_rebuild_transforms()


func _rebuild_transforms() -> void:
	var layout := {
		"fuselage": [Vector3.ZERO, Vector3(90, 0, 0)],
		"nose": [Vector3(0, 0, -18.5), Vector3(-90, 0, 0)],
		"cockpit": [Vector3(0, 0.9, -17.0), Vector3.ZERO],
		"tail": [Vector3(0, 0.6, 20.0), Vector3(90, 0, 0)],
		"stripe": [Vector3(0, 0, -6.0), Vector3(90, 0, 0)],
		"wingL": [Vector3(-12.5, -1.4, 2.5), Vector3(0, 28, -3)],
		"wingR": [Vector3(12.5, -1.4, 2.5), Vector3(0, -28, 3)],
		"engL": [Vector3(-9.3, -3.0, -1.2), Vector3(90, 0, 0)],
		"engR": [Vector3(9.3, -3.0, -1.2), Vector3(90, 0, 0)],
		"fin": [Vector3(0, 5.2, 19.0), Vector3(-18, 0, 0)],
		"stabL": [Vector3(-5.0, 1.0, 21.0), Vector3(0, 22, 0)],
		"stabR": [Vector3(5.0, 1.0, 21.0), Vector3(0, -22, 0)],
		"gear": [Vector3.ZERO, Vector3.ZERO],
	}
	for k in layout:
		var n: Node3D = parts[k]
		n.visible = true
		n.position = layout[k][0]
		n.rotation_degrees = layout[k][1]
