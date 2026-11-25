## Sat-nav. Turns the city's streets into a graph once, then finds the
## shortest way along them from the player to the mission goal; the radar
## and the big map draw the result as a coloured line.
##
## Streets are joined wherever two of them share a point, which is how the
## map data marks a junction. One-way streets are ignored: this is a town
## where the sat-nav's opinion was never binding anyway.
class_name Gps
extends RefCounted

const SNAP := 2.0  # points closer than 1/SNAP metres count as the same junction

var _roads := AStar2D.new()
var _ids := {}  # snapped position (Vector2i) -> point id


func build(city: CityBuilder) -> void:
	for pts: PackedVector2Array in city.drive_paths:
		var previous := -1
		for p in pts:
			var id := _point(p)
			if previous >= 0 and previous != id and not _roads.are_points_connected(previous, id):
				_roads.connect_points(previous, id)
			previous = id


## Id of the graph point at `p`, created on first use.
func _point(p: Vector2) -> int:
	var key := Vector2i(roundi(p.x * SNAP), roundi(p.y * SNAP))
	if _ids.has(key):
		return _ids[key]
	var id := _ids.size()
	_ids[key] = id
	_roads.add_point(id, p)
	return id


## Street points from `from` to `to` (world x/z in metres), empty if there
## is no way through.
func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	if _ids.is_empty():
		return PackedVector2Array()
	var start := _roads.get_closest_point(Vector2(from.x, from.z))
	var finish := _roads.get_closest_point(Vector2(to.x, to.z))
	if start < 0 or finish < 0:
		return PackedVector2Array()
	return _roads.get_point_path(start, finish)
