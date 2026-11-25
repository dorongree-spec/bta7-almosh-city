## Developer aid, not part of the game. Started with
##
##     godot --path . -- --tour
##
## it plays through a fixed list of views (start, a car up close, a person,
## the Old City, a housing block, driving, a handbrake turn, night, dust
## haze, the map), saves a JPEG of each to docs/screenshots/ together with
## tour.txt (frame rate per view), and quits. It lets the look of a build be
## checked the same way every time without anyone touching the keyboard.
##
## The tour drives the game from outside, so it reaches into main.gd's
## internals on purpose; nothing in the game depends on this file.
class_name PhotoTour
extends Node

const OUT_DIR := "res://docs/screenshots/"
const SETTLE := 3.0            # seconds for lighting and street life to settle
const JPEG_QUALITY := 0.88
const OLD_CITY_SPOT := Vector3(330, 0, 60)
const SHIKUN_SPOT := Vector3(-300, 0, -1300)
const MODEL_KINDS := ["hilo", "hondo_civic", "truck"]

var _game  # the main scene script; untyped because main.gd has no class name
var _still: Camera3D
var _log: PackedStringArray = []


func run(game) -> void:
	_game = game
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_still = Camera3D.new()
	_still.fov = 55.0
	_still.far = 1500.0
	add_child(_still)

	_game._start()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(SETTLE)
	await _shoot("start")
	await _shoot("hud_walk")

	await _shoot_cars()
	await _shoot_person()

	await _visit(OLD_CITY_SPOT, "old_city")
	await _shoot_encounter()
	await _visit(SHIKUN_SPOT, "shikun")
	await _shoot_driving()
	await _shoot_dressing()

	_game.day_night.hour = 21.5
	await _wait(SETTLE)
	await _shoot("night")

	_game.day_night.hour = 13.0
	_game.weather.haze = 1.0
	_game.weather._hazy = true
	_game.weather._timer = 60.0
	await _wait(SETTLE)
	await _shoot("haze")

	_game.hud.city_map.toggle()
	await _wait(0.5)
	await _shoot("map")
	_game.hud.city_map.toggle()

	# The front-end screens, each as the player would see it.
	for screen in ["loading", "title", "pause", "card", "intro"]:
		_game.front.preview(screen)
		await _wait(1.6)
		await _shoot("ui_" + screen)
	_game.front.preview("game")

	var notes := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR + "tour.txt"), FileAccess.WRITE)
	if notes != null:
		notes.store_string("\n".join(_log) + "\n")
		notes.close()
	print("TOUR DONE\n", "\n".join(_log))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Saves what is on screen right now as <name>.jpg and notes the frame rate.
func _shoot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_jpg(ProjectSettings.globalize_path(OUT_DIR + shot_name + ".jpg"), JPEG_QUALITY)
	var line := "%s: %d fps" % [shot_name, int(Engine.get_frames_per_second())]
	if err != OK:
		line += "  (could not save, error %d)" % err
	_log.append(line)


## Points the still camera at `target` from `offset` (in the target's own axes).
func _frame(target: Node3D, offset: Vector3, look_height: float) -> void:
	var basis := target.global_transform.basis
	_still.global_position = target.global_position + basis.x * offset.x + Vector3.UP * offset.y + basis.z * offset.z
	_still.look_at(target.global_position + Vector3.UP * look_height)
	_still.make_current()


func _back_to_game_camera() -> void:
	(_game.camera as Camera3D).make_current()


## Nearest car to the player, optionally only kinds from `kinds`.
func _find_car(kinds: Array, parked_only: bool) -> Car:
	var from: Vector3 = _game.player.global_position
	var best: Car = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("cars"):
		var car := node as Car
		if car == null or car.wrecked:
			continue
		if not kinds.is_empty() and not kinds.has(car.kind):
			continue
		if parked_only and car.driver != Car.Driver.NONE:
			continue
		var d := car.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = car
	return best


## Nearest parked car with no other car within 4 m of the camera spot at
## `offset` (with 30 parked cars the nearest one was often hemmed in, and the
## still camera ended up inside its neighbour).
func _clear_parked_car(offset: Vector3) -> Car:
	var from: Vector3 = _game.player.global_position
	var best: Car = null
	var best_d := INF
	var cars := get_tree().get_nodes_in_group("cars")
	for node in cars:
		var car := node as Car
		if car == null or car.wrecked or car.driver != Car.Driver.NONE or not car.visible:
			continue
		var b := car.global_transform.basis
		var cam := car.global_position + b.x * offset.x + b.z * offset.z
		var clear := true
		for other in cars:
			if other != car and (other as Node3D).global_position.distance_to(cam) < 4.0:
				clear = false
				break
		var d := car.global_position.distance_to(from)
		if clear and d < best_d:
			best_d = d
			best = car
	return best if best != null else _find_car([], true)


## One of the built-in car bodies and one of the ready-made models.
func _shoot_cars() -> void:
	var own := _clear_parked_car(Vector3(2.8, 1.5, 5.4))
	if own != null:
		_frame(own, Vector3(2.8, 1.5, 5.4), 0.7)
		await _wait(1.0)
		await _shoot("car")
	var model := _find_car(MODEL_KINDS, false)
	if model != null:
		_frame(model, Vector3(2.8, 1.5, 5.4), 0.7)
		await _wait(1.0)
		await _shoot("car_model")
	_back_to_game_camera()


## The nearest pedestrian, from the front.
func _shoot_person() -> void:
	var from: Vector3 = _game.player.global_position
	var best: Node3D = null
	var best_d := INF
	for node in (_game.pedestrians as Node).get_children():
		var person := node as Node3D
		if person == null or not person.visible:
			continue
		var d := person.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = person
	if best == null:
		return
	_frame(best, Vector3(0.5, 1.5, 3.0), 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot("person")
	_back_to_game_camera()


## Walks the player to a spot and takes the ordinary game view there.
func _visit(spot: Vector3, shot_name: String) -> void:
	var landing: Vector3 = _game._nearest_pavement(spot)
	_game.player.global_position = landing + Vector3(0, 0.3, 0)
	_game._cam_pitch = -0.12
	await _wait(SETTLE + 1.5)
	await _shoot(shot_name)


## A visitor (the watermelon seller) walks up and asks; shot with the normal
## game camera turned towards him once the E/Q prompt is on screen.
func _shoot_encounter() -> void:
	var enc = _game.encounters
	if enc == null or not enc.start_by_id("watermelon"):
		return
	var waited := 0.0
	while not enc._asking and waited < 10.0:
		await _wait(0.25)
		waited += 0.25
	# The game camera frames the talk by itself once the mouse is still
	# (main._frame_conversation); give it time to swing round and settle.
	await _wait(2.5)
	await _shoot("encounter")
	await _shoot("hud_offer")
	Input.action_press("no")  # let him go; the price drops are not part of the shot
	await get_tree().process_frame
	Input.action_release("no")


## The city dressing: roofs from above, a residential street at eye level and
## the far lights at night. Leaves the player on foot.
func _shoot_dressing() -> void:
	if _game.player.car:
		Input.action_release("move_forward")
		_game._toggle_car()
	_game.player.global_position = _game._nearest_pavement(SHIKUN_SPOT) + Vector3(0, 0.3, 0)
	await _wait(1.0)
	var above := SHIKUN_SPOT + Vector3(0, 60, 0)
	_still.global_position = above + Vector3(-60, 0, -60)
	_still.look_at(above + Vector3(25, -60 * tan(deg_to_rad(35.0)) * 2.0, 25))
	_still.make_current()
	await _wait(2.0)
	await _shoot("roofs")
	_back_to_game_camera()
	_game.player.global_position = _game._nearest_pavement(Vector3(-250, 0, -450)) + Vector3(0, 0.3, 0)
	_game._cam_pitch = -0.1
	await _wait(SETTLE + 1.0)
	await _shoot("yard")
	# One of the Old City squares (paving and rows of trees), from head height.
	_game.player.global_position = Vector3(30, 0.3, -250)
	await _wait(1.0)
	_still.global_position = Vector3(8, 2.2, -228)
	_still.look_at(Vector3(40, 1.5, -262))
	_still.make_current()
	await _wait(2.0)
	await _shoot("square")
	_back_to_game_camera()
	var hour: float = _game.day_night.hour
	_game.day_night.hour = 22.0
	await _wait(SETTLE)
	var c: Vector3 = _game.player.global_position
	_still.global_position = c + Vector3(0, 80, 0)
	_still.look_at(c + Vector3(400, 20, 400))
	_still.make_current()
	await _wait(2.0)
	await _shoot("night_far")
	_back_to_game_camera()
	_game.day_night.hour = hour
	await _wait(1.0)


## No car within 12 m of the first 40 m of this lane (the tour car used to land on one).
func _lane_clear(start: Vector2, dir: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("cars"):
		var p := Vector2((node as Node3D).global_position.x, (node as Node3D).global_position.z)
		for k in 5:
			if p.distance_to(start + dir * (8.0 + k * 8.0)) < 12.0:
				return false
	return true


## Start of the nearest straight road stretch at least 90 m long:
## {pos, yaw} in the right-hand lane, or {} if there is none nearby.
func _open_lane(near: Vector3, need_clear := true) -> Dictionary:
	var best := {}
	var best_d := INF
	for pts: PackedVector2Array in _game.city.drive_paths:
		for i in pts.size() - 1:
			var seg := pts[i + 1] - pts[i]
			if seg.length() < 90.0:
				continue
			var d := pts[i].distance_to(Vector2(near.x, near.z))
			if d < best_d and (not need_clear or _lane_clear(pts[i], seg.normalized())):
				best_d = d
				var dir := seg.normalized()
				var p := pts[i] + dir * 8.0 + Vector2(-dir.y, dir.x) * 1.9
				best = {"pos": Vector3(p.x, 0.5, p.y), "yaw": atan2(dir.x, dir.y)}
	if best.is_empty() and need_clear:
		return _open_lane(near, false)  # busy streets: take the nearest straight anyway
	return best


## Gets into the nearest parked car, floors it, then pulls the handbrake.
func _shoot_driving() -> void:
	var car := _find_car([], true)
	if car == null:
		return
	# Parked cars sit half on the kerb, often nose to a lamp post (the old shots
	# read 0 km/h). Put this one in the right-hand lane at the start of the
	# nearest long straight, pointing along it.
	var lane := _open_lane(_game.player.global_position)
	if not lane.is_empty():
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		# A parked car is asleep, and a sleeping body ignores a plain transform
		# write: wake it and move it through the physics server.
		car.sleeping = false
		var xf := Transform3D(Basis(Vector3.UP, lane.yaw), lane.pos)
		PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
		car.global_transform = xf
		await _wait(0.5)
	_game.player.global_position = car.global_position + car.global_transform.basis.x * 1.8 + Vector3(0, 0.3, 0)
	await _wait(0.3)
	_game._toggle_car()
	Input.action_press("move_forward")
	await _wait(5.0)
	await _shoot("driving")
	await _shoot("hud_drive")
	Input.action_press("action")
	Input.action_press("move_left")
	await _wait(1.3)
	await _shoot("handbrake")
	Input.action_release("action")
	Input.action_release("move_left")
	Input.action_release("move_forward")
