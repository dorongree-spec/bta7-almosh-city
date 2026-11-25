## Round radar in the corner of the screen: nearby streets drawn from the
## same road data the city is built from, rotated so that "up" is where the
## camera looks, with the player in the middle and the mission goal as a
## blip that sticks to the rim while it is out of range.
class_name Minimap
extends Control

const RADIUS_PX := 105.0
const RANGE_M := 230.0
const CELL := 200.0
const ROAD := Color(0.86, 0.86, 0.84, 0.95)
const MAIN_ROAD := Color(1.0, 0.86, 0.45, 0.95)
const BACK := Color(0.12, 0.13, 0.15, 0.72)
const ROUTE := Color(0.75, 0.35, 1.0, 0.95)

var _city: CityBuilder
## Grid cell -> indices into city.drive_paths that touch it.
var _grid := {}
var _centre := Vector2.ZERO
var _yaw := 0.0
var _goal := Vector2.ZERO
var _has_goal := false
var _route := PackedVector2Array()


func setup(city: CityBuilder) -> void:
	_city = city
	for i in city.drive_paths.size():
		var pts: PackedVector2Array = city.drive_paths[i]
		var seen := {}
		for p in pts:
			var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
			if seen.has(cell):
				continue
			seen[cell] = true
			if not _grid.has(cell):
				_grid[cell] = PackedInt32Array()
			var bucket: PackedInt32Array = _grid[cell]
			bucket.append(i)
			_grid[cell] = bucket
	custom_minimum_size = Vector2(RADIUS_PX, RADIUS_PX) * 2.0
	size = custom_minimum_size


## centre: world position of the player; yaw: camera heading (radians).
func track(centre: Vector3, yaw: float) -> void:
	_centre = Vector2(centre.x, centre.z)
	_yaw = yaw
	queue_redraw()


func set_goal(world_pos: Vector3, active: bool) -> void:
	_goal = Vector2(world_pos.x, world_pos.z)
	_has_goal = active


## The sat-nav line to draw (world x/z points), or an empty array for none.
func set_route(points: PackedVector2Array) -> void:
	_route = points


## World (x, z) -> radar pixels, camera-forward up.
func _to_radar(world: Vector2) -> Vector2:
	var rel := (world - _centre) * (RADIUS_PX / RANGE_M)
	# Camera forward is (sin yaw, cos yaw); its right-hand side is (-cos yaw, sin yaw).
	var forward := Vector2(sin(_yaw), cos(_yaw))
	var right := Vector2(-forward.y, forward.x)
	return Vector2(RADIUS_PX, RADIUS_PX) + Vector2(rel.dot(right), -rel.dot(forward))


func _draw() -> void:
	if _city == null:
		return
	var mid := Vector2(RADIUS_PX, RADIUS_PX)
	draw_circle(mid, RADIUS_PX, BACK)
	var cell := Vector2i(floori(_centre.x / CELL), floori(_centre.y / CELL))
	var drawn := {}
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var bucket: PackedInt32Array = _grid.get(cell + Vector2i(dx, dy), PackedInt32Array())
			for i in bucket:
				if drawn.has(i):
					continue
				drawn[i] = true
				_draw_road(i, mid)
	if _has_goal and _route.size() >= 2:
		_draw_clipped(_route, mid, ROUTE, 4.0)
	draw_arc(mid, RADIUS_PX, 0.0, TAU, 48, Color(0, 0, 0, 0.9), 4.0, true)
	draw_arc(mid, RADIUS_PX - 3.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 1.5, true)

	if _has_goal:
		var blip := _to_radar(_goal) - mid
		if blip.length() > RADIUS_PX - 8.0:
			blip = blip.normalized() * (RADIUS_PX - 8.0)
		draw_circle(mid + blip, 7.0, Color(0, 0, 0, 0.9))
		draw_circle(mid + blip, 5.0, Color(1.0, 0.8, 0.15))

	# The player: an arrow that always points up, since the map turns instead.
	draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -9), mid + Vector2(6, 7), mid + Vector2(0, 3), mid + Vector2(-6, 7)]), Color.WHITE)


## Draws one street in the colour and width that suit its size.
func _draw_road(index: int, mid: Vector2) -> void:
	var wide: bool = index < _city.drive_widths.size() and _city.drive_widths[index] >= 9.0
	_draw_clipped(_city.drive_paths[index], mid, MAIN_ROAD if wide else ROAD, 4.0 if wide else 2.0)


## Draws a world-space polyline, clipped to the radar disc segment by segment.
func _draw_clipped(pts: PackedVector2Array, mid: Vector2, color: Color, width: float) -> void:
	var limit := RADIUS_PX - 3.0
	var prev := _to_radar(pts[0])
	for k in range(1, pts.size()):
		var cur := _to_radar(pts[k])
		var a := prev - mid
		var b := cur - mid
		prev = cur
		var a_in := a.length() <= limit
		var b_in := b.length() <= limit
		if not a_in and not b_in:
			continue
		# Pull an outside end back onto the rim.
		if not a_in:
			a = _clip(b, a, limit)
		elif not b_in:
			b = _clip(a, b, limit)
		draw_line(mid + a, mid + b, color, width, true)


## Point on segment inside->outside where it crosses the circle of `radius`.
func _clip(inside: Vector2, outside: Vector2, radius: float) -> Vector2:
	var lo := 0.0
	var hi := 1.0
	for i in 8:
		var m := (lo + hi) * 0.5
		if inside.lerp(outside, m).length() <= radius:
			lo = m
		else:
			hi = m
	return inside.lerp(outside, lo)
