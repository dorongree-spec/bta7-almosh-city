## Low desert hills on the horizon (the Negev round Beer Sheva: Tel Sheva,
## the ridge towards Omer, the antenna hill), as a ring that travels with the
## camera just inside the far plane. Haze turns it into a soft silhouette, so
## the edge of the drawn world reads as distance, not as the end of the map.
class_name Horizon
extends Node3D

const RADIUS := 1320.0     # just inside camera.far (1500)
const SEGMENTS := 240
const DEPTH := 150.0       # ring depth from the front ridge back

var _mesh := MeshInstance3D.new()


func _ready() -> void:
	_mesh.mesh = _build()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.6, 0.45)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = m
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = Vector3(cam.global_position.x, -2.0, cam.global_position.z)


## Height of the skyline at an angle: a few long swells plus smaller bumps,
## with one taller rise (the antenna hill to the south-east).
static func _height(a: float) -> float:
	var h := 22.0 + 14.0 * sin(a * 2.0 + 0.7) + 9.0 * sin(a * 5.0 + 2.1) + 5.0 * sin(a * 11.0 + 0.3) + 2.5 * sin(a * 23.0)
	var bump := exp(-pow(wrapf(a - 2.4, -PI, PI) / 0.12, 2.0)) * 45.0
	return maxf(h, 4.0) + bump


func _build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var h0 := _height(a0)
		var h1 := _height(a1)
		var foot0 := d0 * RADIUS
		var foot1 := d1 * RADIUS
		var top0 := d0 * (RADIUS + DEPTH * 0.5) + Vector3(0, h0, 0)
		var top1 := d1 * (RADIUS + DEPTH * 0.5) + Vector3(0, h1, 0)
		var back0 := d0 * (RADIUS + DEPTH) + Vector3(0, h0 * 0.7, 0)
		var back1 := d1 * (RADIUS + DEPTH) + Vector3(0, h1 * 0.7, 0)
		for tri in [[foot0, top0, top1], [foot0, top1, foot1], [top0, back0, back1], [top0, back1, top1]]:
			for p: Vector3 in tri:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()
