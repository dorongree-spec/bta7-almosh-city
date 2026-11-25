## Roadside billboards along the main roads, carrying the city's finest
## advertising (texts come from data/world.json: "signs" and "radio_ads").
## Each one faces the traffic coming towards it on its own side of the road.
class_name Billboards
extends Node3D

const MIN_ROAD_WIDTH := 11.0   # only proper main roads get billboards
const SPACING := 330.0         # metres of road between two billboards
const MAX_BOARDS := 26
const SETBACK := 5.0           # metres from the kerb
const BOARD := Vector3(9.0, 4.4, 0.25)
const LEG_HEIGHT := 5.2
const PIXEL := 0.012           # metres per font pixel
const PALETTE := [Color(0.93, 0.9, 0.82), Color(0.12, 0.25, 0.5), Color(0.75, 0.12, 0.1), Color(0.95, 0.75, 0.1), Color(0.1, 0.4, 0.3)]

var _font: Font = UiStyle.heading()
var _texts: Array = []
var _count := 0


func build(city: CityBuilder, world: Dictionary) -> void:
	_texts = (world.get("signs", []) as Array) + (world.get("radio_ads", []) as Array)
	if _texts.is_empty():
		return
	_texts.shuffle()

	for i in city.drive_paths.size():
		if _count >= MAX_BOARDS:
			return
		var width: float = city.drive_widths[i] if i < city.drive_widths.size() else 0.0
		if width < MIN_ROAD_WIDTH:
			continue
		_line_road(city.drive_paths[i], width)


## Walks one road and drops a billboard every SPACING metres, alternating sides.
func _line_road(pts: PackedVector2Array, width: float) -> void:
	var travelled := SPACING * 0.5
	for k in range(1, pts.size()):
		var a := pts[k - 1]
		var b := pts[k]
		var seg := a.distance_to(b)
		travelled += seg
		if travelled < SPACING or seg < 1.0 or _count >= MAX_BOARDS:
			continue
		travelled = 0.0
		var along := (b - a).normalized()
		# Right-hand side of the direction of travel, and the opposite way on odd boards.
		var flip := -1.0 if _count % 2 == 1 else 1.0
		var right := Vector2(-along.y, along.x) * flip
		var spot := a.lerp(b, 0.5) + right * (width * 0.5 + SETBACK)
		var facing := -along * flip  # towards the cars that drive on this side
		_add_board(Vector3(spot.x, 0.0, spot.y), facing)


func _add_board(at: Vector3, facing: Vector2) -> void:
	var text := String(_texts[_count % _texts.size()])
	var back: Color = PALETTE[_count % PALETTE.size()]
	_count += 1

	var root := Node3D.new()
	# Label3D text reads from +Z, so +Z is turned to face the traffic.
	root.transform = Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.y)), at)
	add_child(root)

	var steel := CityMaterials.color(Color(0.3, 0.3, 0.32), 0.6, 0.6)
	for side: float in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var post := BoxMesh.new()
		post.size = Vector3(0.3, LEG_HEIGHT, 0.3)
		leg.mesh = post
		leg.position = Vector3(side * BOARD.x * 0.3, LEG_HEIGHT * 0.5, -0.2)
		leg.material_override = steel
		leg.visibility_range_end = 500.0
		root.add_child(leg)

	var face := StandardMaterial3D.new()
	face.albedo_color = back
	face.roughness = 0.7
	# A little self-light, so the board still reads after dark.
	face.emission_enabled = true
	face.emission = back
	face.emission_energy_multiplier = 0.35
	var board := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = BOARD
	board.mesh = slab
	board.position = Vector3(0, LEG_HEIGHT + BOARD.y * 0.5, 0)
	board.material_override = face
	board.visibility_range_end = 700.0
	root.add_child(board)

	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = 64
	label.pixel_size = PIXEL
	label.outline_size = 0
	label.double_sided = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = (BOARD.x - 1.0) / PIXEL
	label.modulate = Color(0.08, 0.08, 0.08) if back.get_luminance() > 0.5 else Color.WHITE
	label.position = Vector3(0, LEG_HEIGHT + BOARD.y * 0.5, BOARD.z * 0.5 + 0.03)
	label.visibility_range_end = 320.0
	root.add_child(label)
