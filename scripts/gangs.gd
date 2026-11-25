## Street crews on their real turf. Tempers (from the owner's spec and
## world.json): tenderim trade and never fight, meshuparot ignore you until
## touched and then go all-out with backup, ktarim fight with the plastic
## chairs they sit on, students notice nothing at all.
class_name Gangs
extends Node3D

signal said(speaker: String, text: String)
signal hurt_player(amount: float)
signal charged(amount: int, by: String, line: String)

const ORIGIN_LAT := 31.24056
const ORIGIN_LON := 34.78802

## id -> turf circles [lat, lon, radius_m], look, temper, crews.
const DEFS := {
	"tenderim": {
		"name": "הטנדרים", "temper": "trade", "crews": 3, "cars": ["hilo", "maza323", "subara_dl"],
		"turf": [[31.2335, 34.7950, 450.0], [31.2385, 34.7980, 300.0]],
		"shirts": [Color(0.95, 0.95, 0.95), Color(0.24, 0.36, 0.54), Color(0.54, 0.43, 0.23)],
		"pants": [Color(0.18, 0.31, 0.5), Color(0.2, 0.31, 0.47)], "prop": "keffiyeh",
	},
	"meshuparot": {
		"name": "המשופרות", "temper": "fuse", "crews": 4, "cars": ["hondo_civic", "kia_picanta"],
		"turf": [[31.2595, 34.7935, 450.0], [31.2750, 34.8150, 600.0]],
		"shirts": [Color(1, 0.18, 0.58), Color(0, 0.82, 1), Color(0.62, 1, 0), Color(1, 0.8, 0)],
		"pants": [Color(0.1, 0.1, 0.1), Color(1, 1, 1), Color(0.23, 0.05, 0.64)], "prop": "logo",
	},
	"ktarim": {
		"name": "הכתרים", "temper": "chairs", "crews": 4, "cars": ["subara89", "sedan"],
		"turf": [[31.2400, 34.7895, 450.0], [31.2500, 34.7870, 400.0]],
		"shirts": [Color(0.07, 0.07, 0.07), Color(0.1, 0.16, 0.29)],
		"pants": [Color(0.07, 0.07, 0.07), Color(0.1, 0.16, 0.29)], "prop": "tracksuit4",
	},
	"students": {
		"name": "סטודנטים", "temper": "oblivious", "crews": 4, "cars": [],
		"turf": [[31.2620, 34.8010, 400.0], [31.2580, 34.7980, 300.0]],
		"shirts": [Color(0.78, 0.78, 0.78), Color(0.42, 0.56, 0.14), Color(0.27, 0.51, 0.71)],
		"pants": [Color(0.33, 0.42, 0.18), Color(0.18, 0.31, 0.31)], "prop": "backpack",
	},
}

var world_data: Dictionary
var player: Player
var spawn_car: Callable
var _crews: Array[Crew] = []
var _chairs: Array[Node3D] = []
var _flying: Array = []
var _bark_cd := 0.0

## From Thursday the students have gone home to their parents: their groups
## are simply not there until Sunday.
var students_away := false


class Member:
	var node: Humanoid
	var home: Vector3
	var crew
	var state := "idle"
	var down_t := 0.0
	var fling := Vector3.ZERO
	var attack_cd := 0.0
	var throw_cd := 0.0
	var greet_cd := 0.0


class Crew:
	var id: String
	var def: Dictionary
	var center: Vector3
	var members: Array = []
	var hostile := false
	var lost := 0.0


static func latlon_to_local(lat: float, lon: float) -> Vector3:
	var kx := deg_to_rad(1.0) * 6378137.0 * cos(deg_to_rad(ORIGIN_LAT))
	var kz := deg_to_rad(1.0) * 6378137.0
	return Vector3((lon - ORIGIN_LON) * kx, 0, -(lat - ORIGIN_LAT) * kz)


## Member.crew and Crew.members point at each other, so RefCounted would
## never free them; break the cycle when the gangs leave the scene.
func _exit_tree() -> void:
	for crew in _crews:
		for m in crew.members:
			m.crew = null
		crew.members.clear()
	_crews.clear()


func setup(city: CityBuilder, the_player: Player, data: Dictionary, car_spawner: Callable) -> void:
	world_data = data
	player = the_player
	spawn_car = car_spawner
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for id in DEFS:
		var def: Dictionary = DEFS[id]
		for i in def.crews:
			var turf: Array = def.turf[i % def.turf.size()]
			var spot := _sidewalk_spot(city, latlon_to_local(turf[0], turf[1]), turf[2], rng)
			if spot.is_empty():
				continue
			_spawn_crew(id, def, spot, rng)


## A point on the pavement beside a real road inside the turf circle.
func _sidewalk_spot(city: CityBuilder, center: Vector3, radius: float, rng: RandomNumberGenerator) -> Dictionary:
	var c2 := Vector2(center.x, center.z)
	for tries in 200:
		var pts: PackedVector2Array = city.drive_paths[rng.randi() % city.drive_paths.size()]
		var i := rng.randi() % maxi(1, pts.size() - 1)
		if i + 1 >= pts.size():
			continue
		var p := pts[i].lerp(pts[i + 1], 0.5)
		if p.distance_to(c2) > radius:
			continue
		var d := (pts[i + 1] - pts[i]).normalized()
		var side := Vector2(-d.y, d.x) * 7.5
		return {"pos": Vector3(p.x + side.x, 0, p.y + side.y), "road": Vector3(p.x + side.x * 0.55, 0, p.y + side.y * 0.55), "yaw": atan2(d.x, d.y)}
	return {}


func _spawn_crew(id: String, def: Dictionary, spot: Dictionary, rng: RandomNumberGenerator) -> void:
	var crew := Crew.new()
	crew.id = id
	crew.def = def
	crew.center = spot.pos
	var n := rng.randi_range(3, 4)
	for k in n:
		var m := Member.new()
		m.crew = crew
		var look := {
			"shirt": def.shirts[rng.randi() % def.shirts.size()], "pants": def.pants[rng.randi() % def.pants.size()],
			"skin": Humanoid.random_look(rng).skin, "hair": Humanoid.random_look(rng).hair,
			"prop": def.prop if (def.prop != "keffiyeh" or rng.randf() < 0.4) else "",
		}
		m.node = Humanoid.create(look)
		m.node.set_idle("Idle_Talking_Loop" if def.temper != "oblivious" else "Idle_Loop")
		var a := TAU * k / n
		m.home = crew.center + Vector3(cos(a) * 1.7, 0, sin(a) * 1.7)
		m.node.position = m.home
		m.node.rotation.y = atan2(crew.center.x - m.home.x, crew.center.z - m.home.z)
		add_child(m.node)
		crew.members.append(m)
		if def.temper == "chairs":
			# Sitting on the chair is implied; the chair is right there.
			var ch := Props.chair()
			ch.position = m.home - (crew.center - m.home).normalized() * 0.4
			add_child(ch)
			_chairs.append(ch)
	if def.temper == "chairs":
		var table := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(1.0, 0.75, 1.0)
		table.mesh = tb
		table.material_override = CityMaterials.color(Color(0.95, 0.95, 0.93), 0.4)
		table.position = crew.center + Vector3(0, 0.37, 0)
		add_child(table)
	if not def.cars.is_empty():
		spawn_car.call(def.cars[rng.randi() % def.cars.size()], spot.road, spot.yaw)
	_crews.append(crew)


func _lines(key: String) -> Array:
	var barks: Dictionary = world_data.get("gang_barks", {})
	return barks.get(key, ["..."])


func _say(speaker: String, text: String, force := false) -> void:
	if not force and _bark_cd > 0:
		return
	_bark_cd = 3.0
	said.emit(speaker, text)


## Player swing. Returns true if it connected.
func hit_at(point: Vector3, with_chair: bool) -> bool:
	for crew in _crews:
		if _is_away(crew):
			continue
		for m in crew.members:
			if m.state == "down" or m.node.global_position.distance_to(point) > (2.0 if with_chair else 1.4):
				continue
			if with_chair or randf() < 0.55:
				m.state = "down"
				m.down_t = 0.0
				m.fling = (m.node.global_position - player.global_position).normalized() * (7.0 if with_chair else 4.0)
			_provoke(crew)
			return true
	return false


func _provoke(crew: Crew) -> void:
	match String(crew.def.temper):
		"trade":
			charged.emit(100, crew.def.name, _lines("tenderim").pick_random())
		"oblivious":
			var st: Dictionary = world_data.get("students", {})
			_say(crew.def.name, (st.get("lines", ["...מה?"]) as Array).pick_random(), true)
		_:
			if not crew.hostile:
				crew.hostile = true
				crew.lost = 0.0
				var key := "meshuparot_angry" if crew.id == "meshuparot" else "ktarim"
				_say(crew.def.name, _lines(key).pick_random(), true)
				if crew.id == "meshuparot":
					# They call everyone: every crew of theirs within 400 m joins in.
					for other in _crews:
						if other.id == crew.id and other.center.distance_to(crew.center) < 400:
							other.hostile = true
			for c in _crews:
				if c.hostile:
					for m in c.members:
						if m.state == "idle":
							m.state = "hostile"


func _is_away(crew: Crew) -> bool:
	return students_away and crew.id == "students"


## Pick up a chair lying around (returns true if one was taken).
func take_chair(at: Vector3) -> bool:
	for ch in _chairs:
		if ch.global_position.distance_to(at) < 1.3:
			_chairs.erase(ch)
			ch.queue_free()
			return true
	return false


func _process(delta: float) -> void:
	if player == null:
		return
	_bark_cd -= delta
	var pp := player.global_position
	for crew in _crews:
		var d: float = crew.center.distance_to(pp)
		var here := not _is_away(crew)
		for m in crew.members:
			m.node.visible = here and d < 260
		if not here:
			continue
		if d > 200 and not crew.hostile:
			continue
		if crew.hostile:
			crew.lost = crew.lost + delta if d > 90 else 0.0
			if crew.lost > 6:
				crew.hostile = false
				for m in crew.members:
					if m.state == "hostile":
						m.state = "idle"
		for m in crew.members:
			_update_member(m, delta, pp)
	_update_flying(delta, pp)


func _update_member(m: Member, delta: float, pp: Vector3) -> void:
	var node := m.node
	m.attack_cd -= delta
	m.throw_cd -= delta
	m.greet_cd -= delta
	# Cars hitting crew members.
	if m.state != "down" and player.car and player.car.global_position.distance_to(node.global_position) < 2.0 and player.car.linear_velocity.length() > 4:
		m.state = "down"
		m.down_t = 0
		m.fling = player.car.linear_velocity * 0.5
		_provoke(m.crew)
	if m.state == "down":
		m.down_t += delta
		node.global_position += m.fling * delta
		m.fling = m.fling.move_toward(Vector3.ZERO, delta * 15)
		node.set_knockdown(minf(1.0, m.down_t * 5))
		if m.down_t > 3.5:
			node.set_knockdown(0)
			m.state = "hostile" if m.crew.hostile else "idle"
		return
	var to := pp - node.global_position
	to.y = 0
	var d := to.length()
	var temper: String = m.crew.def.temper
	if m.state == "hostile":
		var speed := 6.4 if temper == "fuse" else 5.2
		node.hold_chair(temper == "chairs")
		if temper == "chairs" and d > 5 and d < 15 and m.throw_cd <= 0:
			m.throw_cd = randf_range(2.5, 4.0)
			_throw_chair(node, to / d, d)
		if d > 1.3:
			node.global_position += to / d * speed * delta
			node.animate(delta, speed)
		elif m.attack_cd <= 0:
			m.attack_cd = 0.9
			node.swing()
			if player.car:
				player.car.damage(4)
			else:
				hurt_player.emit(12.0 if temper == "chairs" else 9.0)
		node.rotation.y = atan2(to.x, to.z)
	else:
		node.hold_chair(false)
		var home := m.home - node.global_position
		home.y = 0
		if home.length() > 0.4:
			node.global_position += home.normalized() * 2.0 * delta
			node.rotation.y = atan2(home.x, home.z)
			node.animate(delta, 2.0)
		else:
			node.animate(delta, 0)
			if d < 6:
				node.rotation.y = atan2(to.x, to.z)
		if d < 5 and m.greet_cd <= 0 and player.car == null:
			m.greet_cd = 12.0
			var key: String = {"tenderim": "tenderim", "meshuparot": "meshuparot_calm", "ktarim": "ktarim"}.get(m.crew.id, "")
			if key != "":
				_say(m.crew.def.name, _lines(key).pick_random())


func _throw_chair(from: Humanoid, dir: Vector3, dist: float) -> void:
	var ch := Props.chair()
	add_child(ch)
	ch.global_position = from.global_position + dir + Vector3(0, 1.6, 0)
	var flight := dist / 16.0
	_flying.append({"node": ch, "vel": dir * 16.0 + Vector3(0, 9.8 * flight * 0.5, 0), "age": 0.0})
	from.swing()


func _update_flying(delta: float, pp: Vector3) -> void:
	for f in _flying.duplicate():
		f.age += delta
		f.vel.y -= 9.8 * delta
		var ch: Node3D = f.node
		ch.global_position += f.vel * delta
		ch.rotation += Vector3(9, 0, 5) * delta
		var p := ch.global_position
		var hit := Vector2(p.x - pp.x, p.z - pp.z).length() < 1.1 and p.y < 2.2
		if hit:
			if player.car:
				player.car.damage(6)
			else:
				hurt_player.emit(12.0)
		if hit or p.y <= 0.05 or f.age > 3.0:
			_flying.erase(f)
			if hit:
				ch.queue_free()
			else:
				# Landed chairs stay on the street for anyone to pick up.
				ch.position.y = 0
				ch.rotation = Vector3(0, randf() * TAU, 0)
				_chairs.append(ch)
