## Puts boxes, cylinders and balls together into one mesh, with one surface
## per material. For the small things that are stamped across the city by
## the thousand (solar heaters, dumpsters, bus stops), where one mesh drawn
## many times is far cheaper than a node for every piece.
##
##   var kit := MeshKit.new()
##   kit.box(white, Vector3(1.0, 0.5, 2.0), Vector3(0, 0.25, 0))
##   kit.cylinder(steel, 0.05, 1.2, Vector3(0.4, 0.6, 0))
##   var mesh := kit.build()
##
## Sizes and positions are in metres. Use materials that need no tangents:
## plain colours, or the world-mapped photo materials of CityMaterials.
class_name MeshKit
extends RefCounted


## The triangles collected so far for one material.
class Part:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()


var _parts := {}                   # Material -> Part
var _order: Array[Material] = []   # materials in the order they first appeared


## A box of `size` centred on `centre`; `turn` rotates it about its centre.
func box(material: Material, size: Vector3, centre: Vector3, turn := Basis.IDENTITY) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	_add(material, shape, Transform3D(turn, centre))


## An upright cylinder centred on `centre`; `turn` lays it over. Give a
## different `top_radius` for a cone or a dish.
func cylinder(material: Material, radius: float, height: float, centre: Vector3,
		turn := Basis.IDENTITY, top_radius := -1.0, sides := 10) -> void:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	_add(material, shape, Transform3D(turn, centre))


## A ball centred on `centre`; `squash` below 1 flattens it.
func ball(material: Material, radius: float, centre: Vector3, squash := 1.0, sides := 8) -> void:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0 * squash
	shape.radial_segments = sides
	shape.rings = maxi(2, sides / 2)
	_add(material, shape, Transform3D(Basis.IDENTITY, centre))


## A roof-shaped wedge centred on `centre`: `size.x` wide at the eaves,
## `size.y` high at the ridge, with the ridge running `size.z` long.
func prism(material: Material, size: Vector3, centre: Vector3, turn := Basis.IDENTITY) -> void:
	var shape := PrismMesh.new()
	shape.size = size
	_add(material, shape, Transform3D(turn, centre))


## Everything added so far as one mesh.
func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material in _order:
		var part: Part = _parts[material]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = part.verts
		arrays[Mesh.ARRAY_NORMAL] = part.normals
		arrays[Mesh.ARRAY_TEX_UV] = part.uvs
		arrays[Mesh.ARRAY_INDEX] = part.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


## Copies the triangles of a ready-made shape, moved to `place`, into the
## part that belongs to `material`.
func _add(material: Material, shape: PrimitiveMesh, place: Transform3D) -> void:
	var arrays := shape.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if not _parts.has(material):
		_parts[material] = Part.new()
		_order.append(material)
	var part: Part = _parts[material]
	var first := part.verts.size()
	for i in verts.size():
		part.verts.append(place * verts[i])
		part.normals.append(place.basis * normals[i])
		part.uvs.append(uvs[i])
	for corner in indices:
		part.indices.append(first + corner)
