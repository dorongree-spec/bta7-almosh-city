## Small procedural props: trees, plastic chairs, roundabout sculptures.
class_name Props
extends RefCounted


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Date palm or a dusty ficus, picked at random.
static func tree(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = rng.randf() * TAU
	parent.add_child(root)
	if rng.randf() < 0.6:
		var h := rng.randf_range(6.0, 10.0)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.2
		trunk.bottom_radius = 0.32
		trunk.height = h
		trunk.radial_segments = 8
		_mesh(root, trunk, TreeMeshes.bark_material(Color(0.45, 0.35, 0.24)), Vector3(0, h / 2, 0))
		var fronds := _mesh(root, TreeMeshes.palm_crown(), TreeMeshes.palm_material(), Vector3(0, h, 0))
		fronds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.25
		trunk.bottom_radius = 0.35
		trunk.height = 3.0
		_mesh(root, trunk, TreeMeshes.bark_material(Color(0.4, 0.36, 0.3)), Vector3(0, 1.5, 0))
		_mesh(root, TreeMeshes.ficus_crown(), TreeMeshes.leaf_material(), Vector3(0, 4.4, 0))


## The white stackable plastic chair: seat, back and four legs.
static func chair() -> Node3D:
	var root := Node3D.new()
	var white := CityMaterials.color(Color(0.95, 0.95, 0.93), 0.4)
	var seat := BoxMesh.new()
	seat.size = Vector3(0.48, 0.05, 0.45)
	_mesh(root, seat, white, Vector3(0, 0.45, 0))
	var back := BoxMesh.new()
	back.size = Vector3(0.48, 0.42, 0.05)
	_mesh(root, back, white, Vector3(0, 0.7, -0.21), Vector3(-0.15, 0, 0))
	var leg := BoxMesh.new()
	leg.size = Vector3(0.05, 0.45, 0.05)
	for x in [-0.2, 0.2]:
		for z in [-0.18, 0.18]:
			_mesh(root, leg, white, Vector3(x, 0.22, z))
	return root


## A questionable municipal sculpture for the middle of a roundabout.
static func sculpture(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var colors := [Color(0.85, 0.35, 0.1), Color(0.15, 0.45, 0.75), Color(0.8, 0.2, 0.2), Color(0.95, 0.8, 0.2), Color(0.9, 0.9, 0.88)]
	var island := CylinderMesh.new()
	island.top_radius = 4.0
	island.bottom_radius = 4.2
	island.height = 0.35
	_mesh(parent, island, CityMaterials.color(Color(0.5, 0.6, 0.3), 1.0), at + Vector3(0, 0.17, 0))
	match rng.randi() % 4:
		0:
			for k in 4:
				var b := BoxMesh.new()
				var s := 1.6 - k * 0.25
				b.size = Vector3(s, 1.2, s)
				_mesh(parent, b, CityMaterials.color(colors[rng.randi() % colors.size()], 0.5), at + Vector3(0, 0.95 + k * 1.2, 0), Vector3(0, k * 0.4, 0))
		1:
			var torus := TorusMesh.new()
			torus.inner_radius = 1.6
			torus.outer_radius = 2.0
			_mesh(parent, torus, CityMaterials.color(colors[rng.randi() % colors.size()], 0.3, 0.6), at + Vector3(0, 2.4, 0), Vector3(PI / 2, rng.randf() * TAU, 0))
		2:
			# A giant coffee cup on a pole, obviously.
			var pole := CylinderMesh.new()
			pole.top_radius = 0.15
			pole.bottom_radius = 0.15
			pole.height = 3.0
			_mesh(parent, pole, CityMaterials.color(Color(0.4, 0.4, 0.4), 0.4, 0.8), at + Vector3(0, 1.8, 0))
			var cup := CylinderMesh.new()
			cup.top_radius = 1.1
			cup.bottom_radius = 0.8
			cup.height = 1.6
			_mesh(parent, cup, CityMaterials.color(Color(0.95, 0.93, 0.88), 0.3), at + Vector3(0, 4.1, 0))
		_:
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.6
			spike.height = 8.0
			_mesh(parent, spike, CityMaterials.color(colors[rng.randi() % colors.size()], 0.4, 0.5), at + Vector3(0, 4.3, 0))
