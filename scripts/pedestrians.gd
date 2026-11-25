## Ambient street life: people walking the pavements of whatever part of
## town the player is in. Walkers follow the road polylines a pavement's
## width to the side, turn back at the end of a street, jump out of the way
## of fast cars and go flying when they do not make it. They are recycled
## around the player, so the whole city feels populated with a fixed budget.
##
## Nobody here is a punching bag. A walker takes one to three blows before
## going down (a chair counts as two); one who stays up either hits back or
## runs. Every half a minute or so two of them start on each other over
## nothing, and some carry a Keter plastic chair ("כיסא כתר פלסטיק") that
## they will throw when it comes to that.
class_name Pedestrians
extends Node3D

signal said(speaker: String, text: String)
## Someone was floored by the player: with a car, or by hand.
signal knocked(by_car: bool)
## A walker landed a blow on the player (health points).
signal hurt_player(amount: float)

const COUNT := 60  # denser streets (PC: 71-87 fps uncapped)
const SPAWN_MIN := 30.0
const SPAWN_MAX := 110.0  # PC: at 150 only ~3 of 60 people were within 60 m
const DESPAWN := 150.0
const WALK := 1.4
const FLEE := 5.5
const PROPS := ["", "", "", "", "backpack", "backpack", "kitbag", "vest", "tracksuit4", "logo"]

const CHAIR_CARRIERS := 0.12      # share of walkers out with a chair under the arm
const HIT_BACK := 0.65            # share of the ones still standing who fight back
const FIGHT_SPEED := 3.4          # m/s closing in
const REACH := 1.3                # metres a fist reaches
const SWING_EVERY := 1.1          # seconds between blows
const PUNCH_DAMAGE := 6.0         # health points a walker's fist takes off the player
const FLOOR_CHANCE := 0.2         # a walker's blow that puts the player on the ground
const THROW_RANGE := Vector2(5.0, 14.0)   # metres a chair is thrown from
const BRAWL_EVERY := Vector2(25.0, 45.0)  # seconds between street fights
const BRAWL_NEAR := Vector2(12.0, 60.0)   # metres from the player a fight breaks out
const JOIN_IN := 0.3              # chance a bystander takes the floored one's side

## What a walker is doing. FIGHT goes for the player, BRAWL for another
## walker; RETURN walks back to the pavement it left.
enum Mood { WALK, FIGHT, BRAWL, RETURN }

const LINES_HIT_BACK := ["מה אתה דוחף?!", "בוא בוא, אתה לא יודע מי אני", "אח שלי, טעית בבן אדם", "על אמא שלי אתה אוכל אותה", "יאללה, נראה אותך"]
const LINES_RUN := ["משטרה! פקחים! מישהו!", "אני לא מכיר אותו, אני רק עובר", "אמאל'ה"]
const LINES_BRAWL := ["חניה! זאת החניה שלי מ-2004!", "מה הסתכלת על אחותי?", "החזרת לי את הכסא? לא החזרת לי את הכסא!", "אתה עקפת אותי בתור במכולת", "מי אמר שהשכונה שלך?"]
const LINES_THROW := ["קח כיסא כתר פלסטיק, שב!", "הנה, תנוח קצת", "כיסא כתר פלסטיק לפנים, מתנה מהשכונה"]

var _city: CityBuilder
var _player: Player
var _focus: Callable
var _chairs: Chairs
var _barks: Array = []
var _walkers: Array[Walker] = []
var _bark_cd := 0.0
var _brawl_in := 0.0
var _rng := RandomNumberGenerator.new()
var _frame := 0
var _lines := {"brawl": LINES_BRAWL, "throw": LINES_THROW, "won": []}


class Walker:
	var node: Humanoid
	var path: int
	var seg: int          # index of the segment start point
	var t: float          # 0..1 along the segment
	var dir: int          # +1 along the polyline, -1 against it
	var side: float       # signed pavement offset from the road centre line
	var speed: float
	var down_t := -1.0    # >= 0 while knocked down
	var fling := Vector3.ZERO
	var flee_t := 0.0
	var toughness := 1    # blows left before going down
	var mood: int = 0     # a Mood
	var mood_t := 0.0     # seconds left of the fight
	var foe: Walker       # who a BRAWL is with
	var swing_cd := 0.0
	var stagger_t := 0.0  # reeling from a blow, cannot act
	var chair := false    # carrying a chair
	var acc := 0.0        # time saved up between updates while far away


func setup(city: CityBuilder, player: Player, world: Dictionary, focus: Callable) -> void:
	_city = city
	_player = player
	_focus = focus
	_barks = world.get("pedestrian_barks", [])
	_load_banter("res://data/encounters_tv.json")
	_rng.randomize()
	_brawl_in = _rng.randf_range(BRAWL_EVERY.x, BRAWL_EVERY.y)
	for i in COUNT:
		var w := Walker.new()
		var look := Humanoid.random_look(_rng)
		look["prop"] = PROPS[_rng.randi() % PROPS.size()]
		w.node = Humanoid.create(look)
		add_child(w.node)
		_walkers.append(w)
		_respawn(w, true)


## Adds the street-fight lines of a content file ("banter": fight_start,
## chair_throw, fight_end) to the built-in ones.
func _load_banter(path: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	var banter: Dictionary = data.get("banter", {})
	for pair in [["brawl", "fight_start"], ["throw", "chair_throw"], ["won", "fight_end"]]:
		var more: Array = banter.get(pair[1], [])
		_lines[pair[0]] = (_lines[pair[0]] as Array) + more


func _line(kind: String) -> String:
	var lines: Array = _lines[kind]
	return "" if lines.is_empty() else String(lines[_rng.randi() % lines.size()])


## The chairs in play, so that walkers can throw theirs.
func arm(chairs: Chairs) -> void:
	_chairs = chairs


## Player swing. Returns true if someone was hit.
func hit_at(point: Vector3, with_chair: bool) -> bool:
	var w := _walker_at(point, 2.0 if with_chair else 1.4, null)
	if w == null:
		return false
	var away := (w.node.global_position - _player.global_position).normalized()
	w.toughness -= 2 if with_chair else 1
	if w.toughness <= 0:
		_knock_down(w, away * (7.0 if with_chair else 3.5), true, false)
		_rally_against_player(w.node.global_position)
		return true
	# Still standing: reels back a step, then makes up their mind.
	w.stagger_t = 0.45
	w.fling = away * 3.0
	if w.mood == Mood.FIGHT or _rng.randf() < HIT_BACK:
		_pick_fight(w)
	else:
		_run(w)
	return true


## A blow (a chair thrown by a walker) landing at `point`: floors the first
## other walker there. Nobody reports it; it is between them.
func npc_hit_at(point: Vector3, thrower: Node3D) -> bool:
	var w := _walker_at(point, 1.6, thrower)
	if w == null:
		return false
	_knock_down(w, (w.node.global_position - point).normalized() * 5.0 + Vector3.UP * 2.0, false, true)
	return true


## Everybody near `at` runs for it (sirens, a stampede of camels).
func panic_all(at: Vector3, radius: float, seconds: float) -> void:
	for w in _walkers:
		if w.down_t < 0.0 and w.node.global_position.distance_to(at) < radius:
			if w.mood != Mood.WALK:
				w.mood = Mood.RETURN
			w.flee_t = seconds * _rng.randf_range(0.7, 1.0)


## Takes a walker off the street here (somebody else is now playing that
## person) and lets them reappear elsewhere in town.
func send_away(person: Node3D) -> void:
	for w in _walkers:
		if w.node == person:
			_respawn(w)
			return


## The walker closest to `pos` within `reach` metres who is on their feet, or null.
func nearest(pos: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for w in _walkers:
		if w.down_t >= 0.0 or not w.node.visible:
			continue
		var d := w.node.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = w.node
	return best


func _walker_at(point: Vector3, reach: float, except: Node3D) -> Walker:
	for w in _walkers:
		if w.down_t >= 0.0 or not w.node.visible or w.node == except:
			continue
		if w.node.global_position.distance_to(point) <= reach:
			return w
	return null


func _respawn(w: Walker, anywhere := false) -> void:
	var centre: Vector3 = _focus.call()
	var c2 := Vector2(centre.x, centre.z)
	for tries in 30:
		var i := _rng.randi() % _city.drive_paths.size()
		var pts: PackedVector2Array = _city.drive_paths[i]
		if pts.size() < 2:
			continue
		var j := _rng.randi() % (pts.size() - 1)
		var d := pts[j].distance_to(c2)
		if d > SPAWN_MAX or (not anywhere and d < SPAWN_MIN):
			continue
		w.path = i
		w.seg = j
		w.t = _rng.randf()
		w.dir = 1 if _rng.randf() < 0.5 else -1
		var half_road: float = _city.drive_widths[i] * 0.5 if i < _city.drive_widths.size() else 4.0
		w.side = (half_road + _rng.randf_range(0.9, 2.2)) * (1.0 if _rng.randf() < 0.5 else -1.0)
		w.speed = _rng.randf_range(1.1, 1.7)
		w.down_t = -1.0
		w.flee_t = 0.0
		w.toughness = 1 + _rng.randi() % 3
		w.mood = Mood.WALK
		w.foe = null
		w.stagger_t = 0.0
		w.chair = _rng.randf() < CHAIR_CARRIERS
		w.node.hold_chair(w.chair)
		w.node.set_knockdown(0.0)
		w.node.visible = true
		w.node.global_position = _spot(w)
		return
	w.node.visible = false


## World position of a walker: on its segment, pushed out sideways onto
## the pavement it was born on (it keeps to that side when it turns back).
func _spot(w: Walker) -> Vector3:
	var pts: PackedVector2Array = _city.drive_paths[w.path]
	var a := pts[w.seg]
	var b := pts[w.seg + 1]
	var along := (b - a).normalized()
	var p := a.lerp(b, w.t) + Vector2(-along.y, along.x) * w.side
	return Vector3(p.x, 0.0, p.y)


## `by_player`: the player did it, and the street will report it.
func _knock_down(w: Walker, impulse: Vector3, by_car: bool, by_player := true) -> void:
	w.down_t = 0.0
	w.fling = impulse
	w.mood = Mood.WALK
	w.foe = null
	if w.chair:
		w.chair = false
		w.node.hold_chair(false)
	if by_player:
		knocked.emit(by_car)
		_bark("עובר אורח", "אייי! יא חתיכת...")


func _pick_fight(w: Walker) -> void:
	w.mood = Mood.FIGHT
	w.mood_t = _rng.randf_range(12.0, 20.0)
	w.swing_cd = 0.6
	_bark("עובר אורח", LINES_HIT_BACK[_rng.randi() % LINES_HIT_BACK.size()], true)


func _run(w: Walker) -> void:
	w.mood = Mood.RETURN
	w.flee_t = 4.0
	_bark("עובר אורח", LINES_RUN[_rng.randi() % LINES_RUN.size()], true)


## Somebody was floored in front of the neighbours: one of them may step in.
func _rally_against_player(at: Vector3) -> void:
	if _rng.randf() > JOIN_IN:
		return
	for w in _walkers:
		if w.down_t < 0.0 and w.mood == Mood.WALK and w.node.visible and w.node.global_position.distance_to(at) < 10.0:
			_pick_fight(w)
			return


## Two walkers near the player who were going about their business are not any more.
func _start_brawl(centre: Vector3) -> bool:
	var a: Walker = null
	for w in _walkers:
		var d := w.node.global_position.distance_to(centre)
		if w.down_t < 0.0 and w.mood == Mood.WALK and w.node.visible and d > BRAWL_NEAR.x and d < BRAWL_NEAR.y:
			a = w
			break
	if a == null:
		return false
	var b: Walker = null
	var best := 40.0
	for w in _walkers:
		if w == a or w.down_t >= 0.0 or w.mood != Mood.WALK or not w.node.visible:
			continue
		var d := w.node.global_position.distance_to(a.node.global_position)
		if d < best:
			best = d
			b = w
	if b == null:
		return false
	for pair in [[a, b], [b, a]]:
		var w: Walker = pair[0]
		w.mood = Mood.BRAWL
		w.foe = pair[1]
		w.mood_t = _rng.randf_range(10.0, 16.0)
		w.swing_cd = _rng.randf_range(0.3, 1.0)
	_bark("עובר אורח", _line("brawl"), true)
	return true


func _bark(speaker: String, text: String, force := false) -> void:
	if _bark_cd > 0.0 and not force:
		return
	_bark_cd = 5.0
	said.emit(speaker, text)


func _process(delta: float) -> void:
	if _player == null:
		return
	_bark_cd -= delta
	var centre: Vector3 = _focus.call()
	_brawl_in -= delta
	if _brawl_in <= 0.0:
		# No pair in range this time: look again in a few seconds (PC: most
		# tries found nobody and the street went quiet for a whole minute).
		_brawl_in = _rng.randf_range(BRAWL_EVERY.x, BRAWL_EVERY.y) if _start_brawl(centre) else 3.0
	var car: Car = _player.car
	_frame += 1
	for wi in _walkers.size():
		var w := _walkers[wi]
		var pos := w.node.global_position
		var dist := pos.distance_to(centre)
		if not w.node.visible or dist > DESPAWN:
			_respawn(w)
			continue
		# Beyond 40 m the walker's pose freezes and the garment layer goes, and an
		# ordinary stroll is moved on every third frame only (PC profiling: the
		# per-walker script cost ~2.8 ms a frame for 60 people).
		var far := dist > 40.0 and w.mood == Mood.WALK
		w.node.set_far(far)
		w.node.set_mid(dist > 15.0 and dist <= 40.0 and w.mood == Mood.WALK)
		if far and w.down_t < 0.0 and w.flee_t <= 0.0 and w.stagger_t <= 0.0:
			w.acc += delta
			if (_frame + wi) % 3 != 0:
				continue
			_walk(w, w.acc)
			w.acc = 0.0
			continue
		w.acc = 0.0
		if w.down_t >= 0.0:
			_update_down(w, delta)
			continue
		if car != null:
			var gap := car.global_position.distance_to(pos)
			var car_speed := car.linear_velocity.length()
			if gap < 1.7 and car_speed > 4.0:
				_knock_down(w, car.linear_velocity * 0.6 + Vector3(0, 3, 0), true)
				continue
			if gap < 9.0 and car_speed > 6.0:
				w.flee_t = 1.5
				if w.mood == Mood.FIGHT:
					w.mood = Mood.RETURN
		elif w.mood == Mood.WALK and pos.distance_to(centre) < 3.0 and not _barks.is_empty():
			_bark("עובר אורח", String(_barks[_rng.randi() % _barks.size()]))
		if w.flee_t > 0.0:
			w.flee_t -= delta
		if w.stagger_t > 0.0:
			_reel(w, delta)
		elif w.mood == Mood.WALK:
			_walk(w, delta)
		elif w.mood == Mood.RETURN:
			_go_back(w, delta)
		else:
			_fight(w, delta)


## Along the pavement, at a stroll or at a run.
func _walk(w: Walker, delta: float) -> void:
	var speed := FLEE if w.flee_t > 0.0 else w.speed
	var pos := w.node.global_position
	_advance(w, speed * delta)
	var next := _spot(w)
	# One transform write instead of a rotation and a position: each write
	# walks the whole body (skeleton, meshes, bone attachments).
	var yaw := w.node.rotation.y
	var to := next - pos
	if Vector2(to.x, to.z).length_squared() > 0.000001:
		yaw = lerp_angle(yaw, atan2(to.x, to.z), minf(1.0, delta * 8.0))
	w.node.global_transform = Transform3D(Basis(Vector3.UP, yaw), next)
	w.node.animate(delta, speed)


## Knocked back a step by a blow that did not floor them.
func _reel(w: Walker, delta: float) -> void:
	w.stagger_t -= delta
	w.node.global_position += w.fling * delta
	w.fling = w.fling.move_toward(Vector3.ZERO, delta * 8.0)
	w.node.animate(delta, 0.0)


## Back to the spot on the pavement they left for the fight.
func _go_back(w: Walker, delta: float) -> void:
	var speed := FLEE if w.flee_t > 0.0 else w.speed * 1.3
	var home := _spot(w)
	var to := home - w.node.global_position
	if to.length() < 0.3:
		w.mood = Mood.WALK
		return
	_step_towards(w, home, speed, delta)


## Squares up to the player (FIGHT) or to the other walker (BRAWL): closes
## in, swings every second or so, and throws the chair if they have one.
func _fight(w: Walker, delta: float) -> void:
	w.mood_t -= delta
	w.swing_cd -= delta
	var target: Node3D = _player
	if w.mood == Mood.BRAWL:
		if w.foe == null or w.foe.down_t >= 0.0 or w.foe.mood != Mood.BRAWL:
			w.mood_t = 0.0
		else:
			target = w.foe.node
	elif _player.car != null:
		w.mood_t = minf(w.mood_t, 3.0)   # shouting at a windscreen gets old fast
	if w.mood_t <= 0.0:
		w.mood = Mood.RETURN
		w.foe = null
		return
	var aim := target.global_position
	var gap := Vector2(aim.x - w.node.global_position.x, aim.z - w.node.global_position.z).length()
	if w.chair and _chairs != null and gap > THROW_RANGE.x and gap < THROW_RANGE.y and w.swing_cd <= 0.0:
		_throw_chair(w, aim, gap)
		return
	if gap > REACH:
		_step_towards(w, aim, FIGHT_SPEED, delta)
		return
	_face(w, aim - w.node.global_position, delta)
	w.node.animate(delta, 0.0)
	if w.swing_cd > 0.0:
		return
	w.swing_cd = SWING_EVERY * _rng.randf_range(0.8, 1.3)
	w.node.swing()
	if w.mood == Mood.BRAWL:
		_land_on_walker(w, w.foe)
	elif _player.car == null and not _player.is_down():
		_land_on_player(w)


func _land_on_walker(w: Walker, foe: Walker) -> void:
	foe.toughness -= 1
	var away := (foe.node.global_position - w.node.global_position).normalized()
	if foe.toughness <= 0:
		_knock_down(foe, away * 4.0 + Vector3.UP * 1.5, false, false)
		w.mood_t = minf(w.mood_t, 1.5)   # won; a word over the body and off
		var last := _line("won")
		if not last.is_empty():
			_bark("עובר אורח", last, true)
	else:
		foe.stagger_t = 0.35
		foe.fling = away * 2.5


func _land_on_player(w: Walker) -> void:
	if _rng.randf() < FLOOR_CHANCE:
		var away := (_player.global_position - w.node.global_position).normalized()
		_player.knock_down(away * 4.0 + Vector3.UP * 2.0, PUNCH_DAMAGE * 1.5)
	else:
		hurt_player.emit(PUNCH_DAMAGE)


func _throw_chair(w: Walker, aim: Vector3, gap: float) -> void:
	var to := aim - w.node.global_position
	var yaw := atan2(to.x, to.z)
	w.node.rotation.y = yaw
	w.node.swing()
	w.chair = false
	w.node.hold_chair(false)
	w.swing_cd = SWING_EVERY
	var thrower := w.node
	# About 0.6 s in the air from shoulder height, so the speed sets the range.
	_chairs.throw(w.node.global_position, yaw, func(at: Vector3) -> bool: return _chair_lands(at, thrower), clampf(gap / 0.6, 7.0, 16.0))
	_bark("עובר אורח", _line("throw"), true)


## A walker's chair reaching `at`: it floors the player if he is there,
## otherwise whoever else is standing in the way.
func _chair_lands(at: Vector3, thrower: Node3D) -> bool:
	var feet := Vector3(_player.global_position.x, 0.0, _player.global_position.z)
	if _player.car == null and not _player.is_down() and feet.distance_to(at) < 1.4:
		var away := (feet - Vector3(thrower.global_position.x, 0.0, thrower.global_position.z)).normalized()
		_player.knock_down(away * 5.0 + Vector3.UP * 2.5, 14.0)
		return true
	return npc_hit_at(at, thrower)


func _step_towards(w: Walker, aim: Vector3, speed: float, delta: float) -> void:
	var to := aim - w.node.global_position
	to.y = 0.0
	var step := to.normalized() * minf(speed * delta, to.length())
	w.node.global_position += step
	_face(w, step, delta)
	w.node.animate(delta, speed)


func _face(w: Walker, towards: Vector3, delta: float) -> void:
	if Vector2(towards.x, towards.z).length_squared() > 0.000001:
		w.node.rotation.y = lerp_angle(w.node.rotation.y, atan2(towards.x, towards.z), minf(1.0, delta * 8.0))


## Moves a walker along its street; at either end it turns round and walks back.
func _advance(w: Walker, distance: float) -> void:
	var pts: PackedVector2Array = _city.drive_paths[w.path]
	var seg_len := maxf(pts[w.seg].distance_to(pts[w.seg + 1]), 0.01)
	w.t += w.dir * distance / seg_len
	if w.t > 1.0:
		if w.seg + 1 < pts.size() - 1:
			w.seg += 1
			w.t = 0.0
		else:
			w.t = 1.0
			w.dir = -1
	elif w.t < 0.0:
		if w.seg > 0:
			w.seg -= 1
			w.t = 1.0
		else:
			w.t = 0.0
			w.dir = 1


func _update_down(w: Walker, delta: float) -> void:
	w.down_t += delta
	var pos := w.node.global_position + w.fling * delta
	w.fling.y -= 12.0 * delta
	if pos.y <= 0.0:
		pos.y = 0.0
		w.fling = w.fling.move_toward(Vector3.ZERO, delta * 14.0)
		w.fling.y = 0.0
	w.node.global_position = pos
	w.node.set_knockdown(minf(1.0, w.down_t * 5.0))
	if w.down_t > 5.0:
		# Gets up, dusts off, and is quietly replaced somewhere else in town.
		_respawn(w)
