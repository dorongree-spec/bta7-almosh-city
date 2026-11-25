## Full-screen map of the whole city, north up, opened with M. Drawn from
## the same road data as the streets themselves, with the player as an arrow
## and the current mission goal as a yellow dot.
class_name CityMap
extends Control

const MARGIN := 60.0
const BACK := Color(0.07, 0.08, 0.1, 0.9)
const ROAD := Color(0.8, 0.8, 0.78, 0.9)
const MAIN_ROAD := Color(1.0, 0.86, 0.45)
const GOAL := Color(1.0, 0.8, 0.15)
const ROUTE := Color(0.75, 0.35, 1.0)
const REFRESH := 0.25

var _city: CityBuilder
var _player := Vector2.ZERO
var _yaw := 0.0
var _goal := Vector2.ZERO
var _has_goal := false
var _route := PackedVector2Array()
var _refresh_t := 0.0


func setup(city: CityBuilder) -> void:
	_city = city
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## The sat-nav line to draw (world x/z points), or an empty array for none.
func set_route(points: PackedVector2Array) -> void:
	_route = points


func toggle() -> void:
	visible = not visible
	queue_redraw()


## centre: world position of the player; yaw: heading (radians).
func track(centre: Vector3, yaw: float, goal: Vector3, has_goal: bool, delta: float) -> void:
	_player = Vector2(centre.x, centre.z)
	_yaw = yaw
	_goal = Vector2(goal.x, goal.z)
	_has_goal = has_goal
	if not visible:
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = REFRESH
		queue_redraw()


func _draw() -> void:
	if _city == null:
		return
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), BACK)
	var area := _city.bounds
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	# World x runs east and z south, which is already "north up" on screen.
	var scale_px := minf((screen.x - MARGIN * 2.0) / area.size.x, (screen.y - MARGIN * 2.0) / area.size.y)
	var shift := screen * 0.5 - area.get_center() * scale_px

	# Side streets first so that the main roads are drawn over them.
	for wide in [false, true]:
		for i in _city.drive_paths.size():
			var is_wide: bool = i < _city.drive_widths.size() and _city.drive_widths[i] >= 9.0
			if is_wide != wide:
				continue
			var pts: PackedVector2Array = _city.drive_paths[i]
			if pts.size() < 2:
				continue
			var line := PackedVector2Array()
			line.resize(pts.size())
			for k in pts.size():
				line[k] = pts[k] * scale_px + shift
			draw_polyline(line, MAIN_ROAD if wide else ROAD, 2.5 if wide else 1.0, true)

	if _has_goal and _route.size() >= 2:
		var way := PackedVector2Array()
		way.resize(_route.size())
		for k in _route.size():
			way[k] = _route[k] * scale_px + shift
		draw_polyline(way, ROUTE, 4.0, true)

	if _has_goal:
		var blip := _goal * scale_px + shift
		draw_circle(blip, 9.0, Color.BLACK)
		draw_circle(blip, 7.0, GOAL)

	# The player: an arrow pointing the way the camera looks.
	var at := _player * scale_px + shift
	var forward := Vector2(sin(_yaw), cos(_yaw))
	var right := Vector2(-forward.y, forward.x)
	var arrow := PackedVector2Array([at + forward * 13.0, at - forward * 8.0 + right * 8.0, at - forward * 3.0, at - forward * 8.0 - right * 8.0])
	draw_colored_polygon(arrow, Color.BLACK)
	var inner := PackedVector2Array([at + forward * 10.0, at - forward * 6.0 + right * 6.0, at - forward * 2.0, at - forward * 6.0 - right * 6.0])
	draw_colored_polygon(inner, Color.WHITE)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(MARGIN, MARGIN - 18.0), "M", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.7))
