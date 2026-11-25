## Key art for the title and loading screens, rendered in-engine.
##
##   godot --path . --script tools/keyart.gd [-- only=3]
##
## Stages six scenes in the live city (time of day, people, cars), renders
## each through an off-screen 3840x2160 camera with 8x MSAA, TAA and depth of
## field, scales it down to 2560x1440 (supersampling) and saves
## assets/art/keyart_01.jpg ... keyart_06.jpg (JPEG, kept under 900 KB).
## No HUD: the HUD lives on the main viewport, the stills on their own.
extends SceneTree

const OUT := "res://assets/art/"
const SIZE := Vector2i(3840, 2160)
const FINAL := Vector2i(2560, 1440)
const SHIKUN_SPOT := Vector3(-300, 0, -1300)
const OLD_CITY_SPOT := Vector3(330, 0, 60)

var main: Node
var frame := 0
var started := false
var sv: SubViewport
var cam: Camera3D
var lens: CameraAttributesPractical
var only := 0
var extras: Array[Node] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = int(a.trim_prefix("only="))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if not started and main.player != null and main.encounters != null and frame > 30:
		started = true
		_run()
	return false


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _run() -> void:
	main.front.enter_game()
	sv = SubViewport.new()
	sv.size = SIZE
	sv.msaa_3d = Viewport.MSAA_8X
	sv.use_taa = true
	sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.far = 2500.0
	lens = CameraAttributesPractical.new()
	cam.attributes = lens
	sv.add_child(cam)
	cam.make_current()
	var shots := [_hero_and_car, _trader, _chairs_at_night, _tuned_at_roundabout, _grandma, _skyline]
	for i in shots.size():
		if only > 0 and only != i + 1:
			continue
		_clear()
		await shots[i].call()
		await _render("keyart_%02d" % (i + 1))
	quit()


func _clear() -> void:
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	lens.dof_blur_far_enabled = false
	lens.dof_blur_near_enabled = false
	main.weather.haze = 0.0
	main.weather._hazy = false
	main.weather._timer = 999.0
	main._env.tonemap_exposure = 1.25


func _render(name: String) -> void:
	await _wait(3.0)  # lights, shadows, TAA and streaming settle
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.resize(FINAL.x, FINAL.y, Image.INTERPOLATE_LANCZOS)
	var path := ProjectSettings.globalize_path(OUT + name + ".jpg")
	var q := 0.9
	img.save_jpg(path, q)
	while FileAccess.get_file_as_bytes(path).size() > 900 * 1024 and q > 0.6:
		q -= 0.05
		img.save_jpg(path, q)
	print("saved %s (q %.2f, %d KB)" % [name, q, FileAccess.get_file_as_bytes(path).size() / 1024])


# --- staging helpers ---------------------------------------------------------------

func _hour(h: float) -> void:
	main.day_night.hour = h


## Closest drivable road point to `near`: {pos, dir} in (x, z).
func _road(near: Vector3) -> Dictionary:
	var best := INF
	var out := {}
	for pts: PackedVector2Array in main.city.drive_paths:
		for i in pts.size() - 1:
			var seg := pts[i + 1] - pts[i]
			if seg.length() < 12.0:
				continue
			var p := pts[i].lerp(pts[i + 1], 0.5)
			var d := p.distance_to(Vector2(near.x, near.z))
			if d < best:
				best = d
				out = {"pos": p, "dir": seg.normalized()}
	return out


func _car(kind: String, at: Vector3, yaw: float) -> Car:
	var car := Car.create(kind)
	main.add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	car.process_mode = Node.PROCESS_MODE_DISABLED  # parked for the photo
	extras.append(car)
	return car


func _person(who: String, at: Vector3, face: Vector3, clip := "Idle_Loop") -> Humanoid:
	var look: Dictionary = main.encounters._bank.look(who, "", RandomNumberGenerator.new())
	var h := Humanoid.create(look)
	main.add_child(h)
	h.global_position = at
	h.look_at(Vector3(face.x, at.y, face.z), Vector3.UP, true)
	h.set_idle(clip)
	extras.append(h)
	return h


func _aim(from: Vector3, to: Vector3, fov := 42.0) -> void:
	cam.global_position = from
	cam.look_at(to)
	cam.fov = fov


## Puts the player (the lamp pool and street life follow it) near the shot but
## out of frame.
func _focus_here(at: Vector3) -> void:
	main.player.global_position = at + Vector3(0, 0.3, 0)
	main.player.visible = false


# --- the six stills ------------------------------------------------------------------

## (a) The hero leaning on an old boxy sedan at golden hour, housing blocks behind.
func _hero_and_car() -> void:
	_hour(17.25)
	var r := _road(SHIKUN_SPOT)
	var d: Vector2 = r.dir
	var side := Vector2(-d.y, d.x)
	var p: Vector2 = r.pos + side * 4.6
	var yaw := atan2(d.x, d.y)
	var car := _car("subara_dl", Vector3(p.x, 0.0, p.y), yaw)
	var hero_at := car.global_position - car.global_transform.basis.x * 1.15 + car.global_transform.basis.z * 0.4
	_focus_here(hero_at + Vector3(30, 0, 30))
	var hero_look: Dictionary = (main.player.humanoid.look if main.player.get("humanoid") else Humanoid.random_look()).duplicate()
	hero_look["pose"] = 2   # leaning on his car, arms crossed: not squaring up for a fight
	hero_look["shoes"] = "sneaker"
	var hero := Humanoid.create(hero_look)
	main.add_child(hero)
	hero.global_position = hero_at
	hero.look_at(hero_at + car.global_transform.basis.z * 3.0 - car.global_transform.basis.x, Vector3.UP, true)
	hero.set_idle("Idle_Loop")
	extras.append(hero)
	var cam_at := hero_at - car.global_transform.basis.x * 4.2 + car.global_transform.basis.z * 4.0 + Vector3(0, 1.15, 0)
	_aim(cam_at, hero_at + car.global_transform.basis.z * 0.6 + Vector3(0, 1.1, 0), 38.0)
	lens.dof_blur_far_enabled = true
	lens.dof_blur_far_distance = 14.0
	lens.dof_blur_far_transition = 30.0
	lens.dof_blur_amount = 0.08


## (b) A trader with his pickup, the desert horizon behind.
func _trader() -> void:
	_hour(17.4)
	var c: Vector2 = main.city.bounds.get_center()
	var best := Vector2.ZERO
	var best_d := 0.0
	for pts: PackedVector2Array in main.city.drive_paths:
		for p in pts:
			var dd := p.distance_to(c)
			if dd > best_d and main.city.bounds.has_point(p):
				best_d = dd
				best = p
	var out := (best - c).normalized()
	var r := _road(Vector3(best.x, 0, best.y))
	var d: Vector2 = r.dir
	var p: Vector2 = r.pos + Vector2(-d.y, d.x) * 4.0
	var car := _car("hilo", Vector3(p.x, 0.0, p.y), atan2(d.x, d.y))
	var trader_at := car.global_position + Vector3(out.x, 0, out.y) * -2.4 + car.global_transform.basis.z * 1.0
	_focus_here(trader_at - Vector3(out.x, 0, out.y) * 40.0)
	_person("tenderim", trader_at, trader_at - Vector3(out.x, 0, out.y) * 5.0, "Idle_Talking_Loop")
	var cam_at := trader_at - Vector3(out.x, 0, out.y) * 7.5 + Vector3(0, 1.4, 0) + car.global_transform.basis.z * -2.0
	_aim(cam_at, trader_at + Vector3(out.x, 0, out.y) * 3.0 + Vector3(0, 1.0, 0), 40.0)
	lens.dof_blur_far_enabled = true
	lens.dof_blur_far_distance = 25.0
	lens.dof_blur_far_transition = 60.0
	lens.dof_blur_amount = 0.06


## (c) Three men on white plastic chairs outside a kiosk at night under a street lamp.
func _chairs_at_night() -> void:
	_hour(22.2)
	main._env.tonemap_exposure = 2.3  # night stills need a longer exposure, like a photo
	var crew = null
	for c in main.gangs._crews:
		if c.def.temper == "chairs":
			crew = c
			break
	if crew == null:
		return
	var at: Vector3 = crew.center
	for m in crew.members:
		var chair: Node3D = null
		var cd := INF
		for ch in main.gangs._chairs:
			var dd: float = ch.global_position.distance_to(m.node.global_position)
			if dd < cd:
				cd = dd
				chair = ch
		if chair != null and cd < 2.0:
			m.node.global_position = chair.global_position
		m.node.look_at(Vector3(at.x, m.node.global_position.y, at.z), Vector3.UP, true)
		m.node.set_idle("Sitting_Idle_Loop")
		m.node.process_mode = Node.PROCESS_MODE_ALWAYS
	_focus_here(at + Vector3(4, 0, 4))
	var r := _road(at)
	var d: Vector2 = r.dir
	var from := at + Vector3(d.x, 0, d.y) * 6.5 + Vector3(-d.y, 0, d.x) * 3.0 + Vector3(0, 1.5, 0)
	_aim(from, at + Vector3(0, 0.9, 0), 46.0)
	await _wait(1.0)  # lamp pool moves to the new focus


## (d) A tuned hatchback with neon at a roundabout at night.
func _tuned_at_roundabout() -> void:
	_hour(22.8)
	main._env.tonemap_exposure = 2.6
	var ring: Array = []
	for r in main.city.data.get("roads", []):
		if r.get("roundabout", false) and r.pts.size() > 6:
			ring = r.pts
			break
	var centre := Vector2.ZERO
	for p in ring:
		centre += Vector2(p[0], p[1])
	centre /= maxf(1, ring.size())
	var p0 := Vector2(ring[0][0], ring[0][1]) if ring.size() > 1 else centre + Vector2(20, 0)
	var p1 := Vector2(ring[1][0], ring[1][1]) if ring.size() > 1 else centre + Vector2(20, 5)
	var dir := (p1 - p0).normalized()
	var car := _car("kia_picanta", Vector3(p0.x, 0.0, p0.y), atan2(dir.x, dir.y))
	car.set_headlights(true)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 6.0
	lamp.omni_range = 18.0
	main.add_child(lamp)
	lamp.global_position = car.global_position + car.global_transform.basis.x * -5.0 + Vector3(0, 6.5, 0)
	extras.append(lamp)
	_focus_here(car.global_position + Vector3(6, 0, 6))
	var b := car.global_transform.basis
	_aim(car.global_position + b.z * 5.5 + b.x * 3.2 + Vector3(0, 0.75, 0), car.global_position + Vector3(0, 0.6, 0), 40.0)
	lens.dof_blur_far_enabled = true
	lens.dof_blur_far_distance = 12.0
	lens.dof_blur_far_transition = 25.0
	lens.dof_blur_amount = 0.07
	await _wait(1.0)


## (e) An old woman in front of a housing block, morning.
func _grandma() -> void:
	_hour(8.8)
	var r := _road(SHIKUN_SPOT + Vector3(120, 0, -80))
	var d: Vector2 = r.dir
	var side := Vector2(-d.y, d.x)
	var p: Vector2 = r.pos + side * 6.8
	var at := Vector3(p.x, 0.0, p.y)
	_focus_here(at + Vector3(20, 0, 20))
	var cam_at := at - Vector3(side.x, 0, side.y) * 5.0 + Vector3(d.x, 0, d.y) * 1.5 + Vector3(0, 1.45, 0)
	_person("babushka", at, cam_at, "Idle_Talking_Loop")
	_aim(cam_at, at + Vector3(side.x, 0, side.y) * 6.0 + Vector3(0, 2.2, 0), 44.0)
	lens.dof_blur_far_enabled = true
	lens.dof_blur_far_distance = 10.0
	lens.dof_blur_far_transition = 40.0
	lens.dof_blur_amount = 0.05


## (f) The city's skyline at dusk.
func _skyline() -> void:
	_hour(17.85)
	var towers := Vector2.ZERO
	var n := 0
	for b in main.city.data.get("buildings", []):
		if float(b.h) > 35.0:
			var p: Array = b.pts[0]
			towers += Vector2(p[0], p[1])
			n += 1
	var c: Vector2 = main.city.bounds.get_center()
	var aim := towers / n if n > 0 else c
	var from2 := aim + (aim - c).normalized().rotated(2.4) * 850.0
	_focus_here(Vector3(aim.x, 0, aim.y))
	_aim(Vector3(from2.x, 95.0, from2.y), Vector3(aim.x, 25.0, aim.y), 34.0)
	await _wait(1.0)
