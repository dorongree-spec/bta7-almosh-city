## The people of the city come to you. An encounter is one person who walks
## up to the player, says their piece and usually proposes something that
## can be answered with yes (E) or no (Q): a deal, a favour, a plate of food,
## a fine. What they do next depends on who they are: the Tenderim haggle and
## never fight, the Meshuparot explode and call their friends, the Ktarim
## chase you with a chair, a student apologises for standing in your fist.
##
## Encounters are started in two ways. A scheduler picks one every so often
## from those whose condition holds right now (standing idle, low on money,
## night, a dust haze, running from inspectors...). And the game reports
## what the player just did through notify(): honked, parked, took a chair,
## hit somebody's car. All of the text and outcomes come from two content
## files, read by EncounterBank; nothing here is specific to one encounter.
class_name Encounters
extends Node3D

signal said(speaker: String, text: String, seconds: float)
## Show / hide the yes-no prompt.
signal asked(speaker: String, text: String)
signal ask_closed()
## An outcome to apply to the player and the world (see EncounterBank for the keys).
signal outcome(change: Dictionary)
signal hurt_player(amount: float)

enum State { APPROACH, TALK, ANGRY, LEAVE, FLEE, DOWN }

const FIRST_AFTER := 14.0          # seconds into the game before anyone comes over
const GAP_MIN := 16.0              # seconds between scheduled encounters
const GAP_MAX := 30.0
const SPAWN_NEAR := 15.0           # how far away a visitor appears
const SPAWN_FAR := 24.0
const HAIL_RANGE := 10.0           # they call out from here
const TALK_RANGE := 2.3            # and stop to talk here
const WALK_OFF := 6.5              # the player has left the conversation
const ANSWER_TIME := 16.0
const MAX_NAGS := 2
const HAGGLE_STEPS := 3            # refusals a Tenderim trader will absorb
const HAGGLE_DROP := 0.8
const ANGRY_TIME := 8.0
const WALK := 1.9
const JOG := 3.7
const CHASE := 4.6
const EVENT_CHANCE := 0.75         # how often a reported action gets an answer
const REACT_GAP := 7.0             # seconds between bystander remarks
const GRUDGE := -3                 # standing at which a crowd comes looking for the player
const GRUDGE_CHANCE := 0.5
const GRUDGE_PRICE := 1.5          # everybody else just charges more
const FRIEND := 2                  # standing at which a trader gives a friend's price
const FRIEND_PRICE := 0.8
## The only crowds that come to blows over a grudge. The Tenderim trade and
## never fight; students do not notice; grandma has other methods.
const FIGHTERS := ["meshuparot", "ktarim"]
const CHAT_REACH := 3.0            # how close a passer-by must be to be spoken to
## The sorts of people an ordinary passer-by can turn out to be.
const CHATTY := ["local", "student", "landlord", "soldier", "babushka"]
const TOO_FAST_TO_STOP := 8.0       # m/s; above this nobody tries to wave the car down
const SPECIFIC_WEIGHT := 3         # encounters tied to a condition beat generic ones
const AVENGE_CHANCE := 0.45        # how often a punched passer-by has a relative nearby
const PEACEMAKER_CHANCE := 0.6     # how often grandma turns up to end a chase
const AMBIENT_MIN := 35.0          # seconds between remarks about the night, the dust, Thursday
const AMBIENT_MAX := 60.0
## Condition -> the kind of remark passers-by make while it holds.
const AMBIENT := {"night": "night", "dust_storm": "haze", "thursday": "thursday"}

var enabled := false

var _player: Player
var _bank := EncounterBank.new()
var _bystander: Callable            # (position, reach) -> Node3D or null
var _conditions: Callable           # () -> Dictionary of condition name -> bool
var _send_away: Callable            # (Node3D) -> void: retires a passer-by we replaced
var _visitors: Array[Visitor] = []
var _main: Visitor                  # the one doing the talking, if any
var _asking := false
var _next_t := FIRST_AFTER
var _react_cd := 0.0
var _cooldowns := {}                # encounter id -> seconds left
var _respect := {}                  # who -> standing with that crowd
var _price_factor := 1.0
var _idle_t := 0.0
var _run_t := 0.0
var _slow_t := 0.0
var _ambient_t := AMBIENT_MAX
var _rng := RandomNumberGenerator.new()


class Visitor:
	var node: Humanoid
	var deal: Dictionary
	var who := "local"
	var name := ""
	var state := State.APPROACH
	var after_down := State.LEAVE
	var t := 0.0                    # seconds in the current state
	var lines: Array = []           # still to be said before the question
	var line_t := 0.0
	var hailed := false
	var nags := 0
	var haggles := 0
	var price := 0                  # current asking price, if the deal has one
	var attack_cd := 0.0
	var angry_t := 0.0
	var fling := Vector3.ZERO
	var backup := false             # a summoned friend: only chases


func setup(player: Player, bystander: Callable, conditions: Callable, send_away := Callable()) -> void:
	_player = player
	_bystander = bystander
	_conditions = conditions
	_send_away = send_away
	_rng.randomize()
	_bank.load_all()
	_ensure_key("yes", KEY_E)
	_ensure_key("no", KEY_Q)


## Adds a keyboard action at run time, so the content keys need no project settings.
func _ensure_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var press := InputEventKey.new()
	press.physical_keycode = key
	InputMap.action_add_event(action, press)


## The on-screen name of the part of town `pos` is in, or "".
func area_name_at(pos: Vector3) -> String:
	return _bank.zone_name_at(pos)


## Everybody the player has a standing with, as "crowd: number" pairs.
func standings() -> Dictionary:
	return _respect.duplicate()


## Standing with a crowd: positive after favours, negative after insults.
func respect(who: String) -> int:
	return int(_respect.get(who, 0))


# --- what the game reports -------------------------------------------------------------

## The player just did something people react to: "honks", "parks",
## "takes_chair", "in_fight", "hits_vehicle", "touches_vehicle".
## `who` narrows it to one crowd (the owner of the car that was hit, say)
## and `at` is where the reacting person should come from. Returns true if
## somebody took it up.
func notify(event: String, who := "", at := Vector3.INF) -> bool:
	if not enabled or _main != null or _rng.randf() > EVENT_CHANCE:
		return false
	var deal := _pick(event, who)
	if deal.is_empty() and who != "":
		deal = _pick(event)  # nobody from that crowd has a line; anybody will do
	if deal.is_empty():
		return false
	_start(deal, at, 7.0, 11.0)
	return true


## The player starts it: E next to a passer-by, while nobody is asking
## anything. That passer-by turns out to have something to offer too.
func chat_up() -> bool:
	if not enabled or _main != null or _player.car != null or not _bystander.is_valid():
		return false
	var someone: Node3D = _bystander.call(_player.global_position, CHAT_REACH)
	if someone == null:
		return false
	var deal := _pick_chat()
	if deal.is_empty():
		said.emit("עובר אורח", _bank.one_reaction("loiter", _rng), 3.0)
		return true
	var spot := someone.global_position
	if _send_away.is_valid():
		_send_away.call(someone)
	_start(deal, spot)
	if _main != null:
		_main.hailed = true  # the player spoke first
	return true


## Something an ordinary passer-by could plausibly propose right here.
func _pick_chat() -> Dictionary:
	var flags: Dictionary = _conditions.call() if _conditions.is_valid() else {}
	var here := _player.global_position
	var bag: Array[Dictionary] = []
	for deal: Dictionary in _bank.deals:
		if not CHATTY.has(String(deal.who)) or String(deal.offer) == "" or String(deal.when) == "car":
			continue
		if EncounterBank.EVENT_TRIGGERS.has(String(deal.trigger)) or _cooldowns.get(deal.id, 0.0) > 0.0:
			continue
		if String(deal.who) == "student" and bool(flags.get("students_away", false)):
			continue
		if _bank.in_zone(String(deal.near), here):
			bag.append(deal)
	if bag.is_empty():
		return {}
	return bag[_rng.randi() % bag.size()]


## Where the person now talking to the player stands, or Vector3.INF if
## nobody is. The camera uses it to keep both of them in the picture.
func speaker_position() -> Vector3:
	if _main == null or _main.state != State.TALK:
		return Vector3.INF
	return _main.node.global_position


## Developer aid (the photo tour): starts one encounter by its id, now.
func start_by_id(id: String) -> bool:
	for deal: Dictionary in _bank.deals:
		if String(deal.id) == id:
			if _main != null:
				_remove(_main)
			_start(deal, Vector3.INF, 5.0, 8.0)
			return _main != null
	return false


## A passer-by remarks on what the player is doing ("horn", "punch", "run"...).
func react(kind: String) -> void:
	if not enabled or _react_cd > 0.0 or not _bystander.is_valid():
		return
	var lines := _bank.reactions(kind)
	if lines.is_empty():
		return
	var someone: Node3D = _bystander.call(_focus(), 18.0)
	if someone == null:
		return
	_react_cd = REACT_GAP
	said.emit("עובר אורח", String(lines[_rng.randi() % lines.size()]), 3.5)


## The player just floored a passer-by at `at`. Sometimes that passer-by has
## a cousin within earshot, who comes over to discuss it with his fists.
func avenge(at: Vector3) -> void:
	if not enabled or _rng.randf() > AVENGE_CHANCE:
		return
	var spot := _spawn_spot(9.0, 15.0)
	if spot == Vector3.INF:
		spot = at
	var cousin := _make_visitor("local", "", spot)
	cousin.name = "בן דוד של מישהו"
	cousin.backup = true
	cousin.state = State.ANGRY
	cousin.angry_t = ANGRY_TIME
	said.emit(cousin.name, _bank.one_reaction("avenge", _rng), 3.0)


## Player swing or thrown chair. Returns true if a visitor was hit.
func hit_at(point: Vector3, with_chair: bool) -> bool:
	for v in _visitors:
		if v.state == State.DOWN or v.node.global_position.distance_to(point) > (2.0 if with_chair else 1.4):
			continue
		var push := (v.node.global_position - _player.global_position).normalized() * (7.0 if with_chair else 3.5)
		_knock_down(v, push)
		return true
	return false


# --- choosing and starting -------------------------------------------------------------

## True if the condition named by an encounter's trigger holds right now.
func _holds(trigger: String, flags: Dictionary) -> bool:
	var on_foot := _player.car == null
	match trigger:
		"near":
			return true
		"idle":
			return on_foot and _idle_t > 10.0
		"runs_past":
			return on_foot and _run_t > 3.0
		"drives_slow":
			return not on_foot and _slow_t > 4.0
		"holds_chair":
			return _player.has_chair
		"low_money":
			return _player.money < 60
		"low_health":
			return _player.health < 40.0
		"heat_high":
			return _player.heat > 70.0
		"enters_territory":
			return true  # the encounter's own `near` zone does the work
		_:
			return bool(flags.get(trigger, false))


## An eligible encounter for `trigger` ("" = whatever fits now), or {}.
func _pick(trigger: String, who := "") -> Dictionary:
	var flags: Dictionary = _conditions.call() if _conditions.is_valid() else {}
	var on_foot := _player.car == null
	var here := _focus()
	var bag: Array[Dictionary] = []
	for deal: Dictionary in _bank.deals:
		if _cooldowns.get(deal.id, 0.0) > 0.0:
			continue
		var wanted := String(deal.trigger)
		if trigger != "" and wanted != trigger:
			continue
		if trigger == "" and (EncounterBank.EVENT_TRIGGERS.has(wanted) or not _holds(wanted, flags)):
			continue
		if who != "" and String(deal.who) != who:
			continue
		if String(deal.who) == "student" and bool(flags.get("students_away", false)):
			continue  # it is the weekend; they are at their parents'
		# A reported action already says where the player is (parking means
		# they have just stepped out), so "when" only filters the scheduler.
		var when := String(deal.when)
		if trigger == "" and ((when == "foot" and not on_foot) or (when == "car" and on_foot)):
			continue
		if not _bank.in_zone(String(deal.near), here):
			continue
		var weight := 1 if (wanted == "near" and String(deal.near) == "") else SPECIFIC_WEIGHT
		for i in weight:
			bag.append(deal)
	if bag.is_empty():
		return {}
	return bag[_rng.randi() % bag.size()]


func _start(deal: Dictionary, from := Vector3.INF, near := SPAWN_NEAR, far := SPAWN_FAR) -> void:
	_cooldowns[deal.id] = float(deal.cooldown)
	if bool(deal.phone):
		# Nobody walks up: it is a phone call.
		for line: String in deal.lines:
			said.emit(String(deal.name), line, 5.0)
		outcome.emit(deal.effects)
		_schedule_next()
		return
	var spot := from if from != Vector3.INF else _spawn_spot(near, far)
	if spot == Vector3.INF:
		_next_t = 3.0  # nowhere clear to come from; try again shortly
		return
	var v := _make_visitor(String(deal.who), String(deal.look), spot)
	v.deal = deal
	v.name = String(deal.name)
	v.lines = (deal.lines as Array).duplicate()
	v.price = int(deal.price)
	var standing := respect(v.who)
	if standing >= FRIEND:
		v.price = int(round(v.price * FRIEND_PRICE / 5.0)) * 5
	elif standing <= GRUDGE:
		v.price = int(round(v.price * GRUDGE_PRICE / 5.0)) * 5
	v.node.add_child(NameTag.make(v.name))
	_main = v
	if standing <= GRUDGE and FIGHTERS.has(v.who) and _rng.randf() < GRUDGE_CHANCE:
		_settle_score(v)


## This crowd has had enough of the player: no offer today, they have come
## to settle it. Beating them (or grandma) is the only way to end it, and
## afterwards the slate is a little cleaner.
func _settle_score(v: Visitor) -> void:
	said.emit(v.name, _bank.one_reaction("grudge", _rng), 3.5)
	_respect[v.who] = respect(v.who) + 2
	v.state = State.ANGRY
	v.angry_t = ANGRY_TIME + 6.0
	_main = null
	_schedule_next()
	_call_backup(v)


func _make_visitor(who: String, look_key: String, at: Vector3) -> Visitor:
	var v := Visitor.new()
	v.who = who
	v.node = Humanoid.create(_bank.look(who, look_key, _rng))
	add_child(v.node)
	v.node.global_position = at
	v.node.set_idle("Idle_Talking_Loop")
	_visitors.append(v)
	return v


## A point on a ring around the player with a clear line to walk along.
func _spawn_spot(near: float, far: float) -> Vector3:
	var centre := _focus()
	var space := get_world_3d().direct_space_state
	for tries in 10:
		var angle := _rng.randf() * TAU
		var spot := centre + Vector3(sin(angle), 0.0, cos(angle)) * _rng.randf_range(near, far)
		spot.y = 0.0
		var ray := PhysicsRayQueryParameters3D.create(centre + Vector3(0, 1.0, 0), spot + Vector3(0, 1.0, 0))
		ray.collision_mask = StreetProps.WORLD_LAYER
		var skip: Array[RID] = [_player.get_rid()]
		if _player.car != null:
			skip.append(_player.car.get_rid())
		ray.exclude = skip
		if space.intersect_ray(ray).is_empty():
			return spot
	return Vector3.INF


func _schedule_next() -> void:
	_next_t = _rng.randf_range(GAP_MIN, GAP_MAX)


## Where the player is: on foot, or the driver's window of their car.
func _focus() -> Vector3:
	if _player.car != null:
		return _player.car.global_position + _player.car.global_transform.basis.x * 1.5
	return _player.global_position


# --- every frame -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not enabled or _player == null:
		return
	_react_cd -= delta
	for id in _cooldowns:
		_cooldowns[id] = float(_cooldowns[id]) - delta
	_watch_player(delta)

	# E with nobody asking anything is the player starting a conversation.
	# Checked before the visitors move, so the E that answers an offer on
	# this frame is not also read as a new hello.
	if _main == null and Input.is_action_just_pressed("yes"):
		chat_up()

	for v in _visitors.duplicate():
		_update(v, delta)

	if _main == null:
		_schedule_tick(delta)


## Counts down to the next person who comes over of their own accord.
func _schedule_tick(delta: float) -> void:
	_next_t -= delta
	if _next_t > 0.0:
		return
	if _driving_fast():
		_next_t = 3.0  # nobody flags down a car at speed; wait for a slower moment
		return
	var deal := {}
	if _is_chased() and _rng.randf() < PEACEMAKER_CHANCE:
		deal = _pick("chased")
	if deal.is_empty():
		deal = _pick("")
	if deal.is_empty():
		_next_t = 5.0
	else:
		_start(deal)


## Keeps the timers behind "idle", "runs_past" and "drives_slow", and lets
## bystanders comment on loitering and sprinting.
func _watch_player(delta: float) -> void:
	var on_foot := _player.car == null
	var speed := _player.velocity.length() if on_foot else _player.car.linear_velocity.length()
	_idle_t = _idle_t + delta if (on_foot and speed < 0.3) else 0.0
	_run_t = _run_t + delta if (on_foot and speed > 6.0) else 0.0
	_slow_t = _slow_t + delta if (not on_foot and speed < 4.0) else 0.0
	if _main != null:
		return
	if _idle_t > 18.0:
		_idle_t = 11.0
		react("loiter")
	elif _run_t > 6.0:
		_run_t = 3.5
		react("run")
	elif _slow_t > 9.0:
		_slow_t = 4.5
		react("slow")
	_ambient_t -= delta
	if _ambient_t <= 0.0:
		_ambient_t = _rng.randf_range(AMBIENT_MIN, AMBIENT_MAX)
		_remark_on_the_day()


## Somebody comments on the night, the dust or the fact that it is Thursday.
func _remark_on_the_day() -> void:
	var flags: Dictionary = _conditions.call() if _conditions.is_valid() else {}
	var kinds: Array[String] = []
	for condition: String in AMBIENT:
		if bool(flags.get(condition, false)):
			kinds.append(String(AMBIENT[condition]))
	if not kinds.is_empty():
		react(kinds[_rng.randi() % kinds.size()])


func _driving_fast() -> bool:
	return _player.car != null and _player.car.linear_velocity.length() > TOO_FAST_TO_STOP


## True while somebody is after the player with bad intentions.
func _is_chased() -> bool:
	for v in _visitors:
		if v.state == State.ANGRY:
			return true
	return false


func _update(v: Visitor, delta: float) -> void:
	v.t += delta
	v.attack_cd -= delta
	var here := v.node.global_position
	var target := _focus()
	var gap := Vector2(target.x - here.x, target.z - here.z).length()
	match v.state:
		State.APPROACH:
			_update_approach(v, target, gap, delta)
		State.TALK:
			_update_talk(v, target, gap, delta)
		State.ANGRY:
			_update_angry(v, target, gap, delta)
		State.LEAVE, State.FLEE:
			var away := here + (here - target).normalized() * 5.0
			_walk(v, away, CHASE + 1.5 if v.state == State.FLEE else WALK, delta)
			if v.t > 12.0 or gap > 60.0:
				_remove(v)
		State.DOWN:
			_update_down(v, delta)
	# Cars do not stop for them either.
	var car := _player.car
	if car != null and v.state != State.DOWN and car.linear_velocity.length() > 4.0 and car.global_position.distance_to(here) < 1.8:
		_knock_down(v, car.linear_velocity * 0.6 + Vector3(0, 3, 0))


func _update_approach(v: Visitor, target: Vector3, gap: float, delta: float) -> void:
	if gap > 55.0 or v.t > 25.0:
		_finish(v, State.LEAVE)  # the player got away
		return
	if not v.hailed and gap < HAIL_RANGE:
		v.hailed = true
		var hail := String(v.deal.get("hail", ""))
		if hail != "":
			said.emit(v.name, hail, 3.0)
	if gap <= TALK_RANGE:
		v.state = State.TALK
		v.t = 0.0
		v.line_t = 0.0
		return
	_walk(v, target, JOG if gap > 9.0 else WALK, delta)


func _update_talk(v: Visitor, target: Vector3, gap: float, delta: float) -> void:
	_face(v, target, delta)
	v.node.animate(delta, 0.0)
	if gap > WALK_OFF:
		_walked_off(v)
		return
	# First whatever they have to say, one line at a time.
	if not v.lines.is_empty():
		v.line_t -= delta
		if v.line_t <= 0.0:
			var line := String(v.lines.pop_front())
			var seconds := EncounterBank.reading_time(line)
			v.line_t = seconds
			var speaker := v.name
			if line.begins_with("שחקן:"):
				speaker = "אתה"
				line = line.trim_prefix("שחקן:").strip_edges()
			elif line.begins_with("("):
				speaker = ""
			said.emit(speaker, line, seconds + 0.4)
		return
	v.line_t -= delta
	if v.line_t > 0.0:
		return

	var offer := String(v.deal.offer)
	if offer == "":
		_resolve(v, v.deal.effects)
		return
	if not _asking:
		_asking = true
		v.t = 0.0
		asked.emit(v.name, _priced(offer, v))
	if Input.is_action_just_pressed("yes"):
		_answer(v, true)
	elif Input.is_action_just_pressed("no"):
		_answer(v, false)
	elif v.t > ANSWER_TIME:
		_walked_off(v)


## The offer text with the current asking price in place of the listed one.
func _priced(offer: String, v: Visitor) -> String:
	var listed := int(v.deal.price)
	if listed <= 0 or v.price == listed:
		return offer
	return "%s  (עכשיו: %d ₪)" % [offer, v.price]


func _answer(v: Visitor, yes: bool) -> void:
	_close_ask()
	var branch: Dictionary = (v.deal.yes if yes else v.deal.no) as Dictionary
	var change := branch.duplicate()
	if yes and v.price > 0 and float(change.get("money", 0)) < 0.0:
		var cost := int(round(v.price * _price_factor))
		if _player.money < cost:
			said.emit(v.name, _bank.one_reaction("broke", _rng), 3.5)
			_finish(v, State.LEAVE)
			return
		change["money"] = -cost
	# The Tenderim never take a first "no": the price comes down, three times.
	if not yes and v.who == "tenderim" and v.price > 0 and v.haggles < HAGGLE_STEPS:
		v.haggles += 1
		# Always at least 5 less: rounding to 5 used to repeat "10" twice.
		v.price = maxi(5, mini(v.price - 5, int(round(v.price * HAGGLE_DROP / 5.0)) * 5))
		said.emit(v.name, "%d. בשבילך. מחיר אחרון. כמעט." % v.price, 3.0)
		v.line_t = 2.2
		return
	_resolve(v, change)


func _resolve(v: Visitor, change: Dictionary) -> void:
	_close_ask()
	var line := String(change.get("line", ""))
	if line != "":
		said.emit(v.name, line, EncounterBank.reading_time(line) + 1.0)
	var step := int(change.get("respect", 0))
	if step != 0:
		_respect[v.who] = respect(v.who) + step
	if bool(change.get("price_up", false)):
		_price_factor = minf(2.0, _price_factor * 1.2)
	if bool(change.get("calm", false)):
		_calm_everyone()
	outcome.emit(change)

	var backup := int(change.get("backup", 0))
	for i in backup:
		_call_backup(v)
	match String(change.get("mood", "")):
		"angry":
			v.state = State.ANGRY
			v.t = 0.0
			v.angry_t = ANGRY_TIME
			if v == _main:
				_main = null
				_schedule_next()
		"nag":
			if v.nags < MAX_NAGS:
				# Not taking no for an answer: asks again in a moment.
				v.nags += 1
				v.line_t = 3.0
			else:
				_finish(v, State.LEAVE)
		"flee":
			_finish(v, State.FLEE)
		_:
			if String(change.get("chain", "")) != "":
				_chain(v)
			else:
				_finish(v, State.LEAVE)


## "Come, I have something for you": the same person moves on to an offer.
func _chain(v: Visitor) -> void:
	var next := _pick_offer(v.who)
	if next.is_empty():
		_finish(v, State.LEAVE)
		return
	_cooldowns[next.id] = float(next.cooldown)
	v.deal = next
	v.lines = (next.lines as Array).duplicate()
	v.price = int(next.price)
	v.haggles = 0
	v.line_t = 2.5


func _pick_offer(who: String) -> Dictionary:
	var bag: Array[Dictionary] = []
	for deal: Dictionary in _bank.deals:
		if String(deal.who) == who and String(deal.offer) != "" and not EncounterBank.EVENT_TRIGGERS.has(String(deal.trigger)):
			bag.append(deal)
	if bag.is_empty():
		return {}
	return bag[_rng.randi() % bag.size()]


## The player turned their back on the conversation.
func _walked_off(v: Visitor) -> void:
	_close_ask()
	if v.nags < MAX_NAGS and String(v.deal.offer) != "":
		v.nags += 1
		said.emit(v.name, _bank.one_reaction("ignored", _rng), 3.0)
		v.state = State.APPROACH
		v.t = 0.0
		v.hailed = true
		return
	_finish(v, State.LEAVE)


func _update_angry(v: Visitor, target: Vector3, gap: float, delta: float) -> void:
	v.angry_t -= delta
	if v.angry_t <= 0.0 or gap > 45.0:
		_finish(v, State.LEAVE)
		return
	if _player.car != null:
		_face(v, target, delta)
		v.node.animate(delta, 0.0)
		return
	if gap > 1.3:
		_walk(v, target, CHASE, delta)
		return
	_face(v, target, delta)
	v.node.animate(delta, 0.0)
	if v.attack_cd <= 0.0:
		# PC playtest: 1.1 s and 5-7 per hit let a three-man crowd kill a
		# standing player in 7 s. Now ~14 s for three, ~25 s for one Ktarim.
		v.attack_cd = _rng.randf_range(1.3, 1.9)
		v.node.swing()
		hurt_player.emit(6.0 if v.who == "ktarim" else 4.0)
		if _rng.randf() < 0.4:
			said.emit(v.name, _bank.one_reaction("chase", _rng), 2.5)


func _update_down(v: Visitor, delta: float) -> void:
	var pos := v.node.global_position + v.fling * delta
	v.fling.y -= 12.0 * delta
	if pos.y <= 0.0:
		pos.y = 0.0
		v.fling = v.fling.move_toward(Vector3.ZERO, delta * 14.0)
		v.fling.y = 0.0
	v.node.global_position = pos
	if v.t > 2.6:
		v.node.set_knockdown(0.0)
		v.state = v.after_down
		v.t = 0.0


# --- reactions to being hit ------------------------------------------------------------

func _knock_down(v: Visitor, push: Vector3) -> void:
	var was_angry := v.state == State.ANGRY
	v.state = State.DOWN
	v.t = 0.0
	v.fling = push
	v.node.set_knockdown(1.0)
	if v == _main:
		_close_ask()
	if was_angry or v.backup:
		v.after_down = State.ANGRY  # gets up and carries on
		return
	# How this sort of person takes a punch. Their friends will hear about it.
	_respect[v.who] = respect(v.who) - 1
	var answer := _bank.hit_response(v.who, _rng)
	var line := String(answer.get("line", ""))
	if line != "":
		said.emit(v.name if v.name != "" else "עובר אורח", line, 4.0)
	outcome.emit(answer)
	if String(answer.get("mood", "")) == "angry":
		v.after_down = State.ANGRY
		v.angry_t = ANGRY_TIME + 2.6
		for i in int(answer.get("backup", 0)):
			_call_backup(v)
	elif String(answer.get("mood", "")) == "flee":
		v.after_down = State.FLEE
	else:
		v.after_down = State.LEAVE
	if v == _main:
		_main = null
		_schedule_next()


## A friend of `v` comes running from round the corner.
func _call_backup(v: Visitor) -> void:
	var spot := _spawn_spot(18.0, 26.0)
	if spot == Vector3.INF:
		return
	var friend := _make_visitor(v.who, "", spot)
	friend.name = v.name
	friend.backup = true
	friend.state = State.ANGRY
	friend.angry_t = ANGRY_TIME + 4.0
	_next_t = minf(_next_t, 6.0)  # with luck, grandma hears the noise


## Grandma has spoken: everybody who was chasing the player goes home.
func _calm_everyone() -> void:
	for v in _visitors:
		if v.state == State.ANGRY:
			v.state = State.LEAVE
			v.t = 0.0


# --- small helpers ---------------------------------------------------------------------

func _close_ask() -> void:
	if _asking:
		_asking = false
		ask_closed.emit()


## Ends a visitor's part in the encounter and sends them on their way.
func _finish(v: Visitor, next: State) -> void:
	if v == _main:
		_close_ask()
		_main = null
		_schedule_next()
	v.state = next
	v.t = 0.0


func _remove(v: Visitor) -> void:
	if v == _main:
		_close_ask()
		_main = null
		_schedule_next()
	_visitors.erase(v)
	v.node.queue_free()


func _walk(v: Visitor, target: Vector3, speed: float, delta: float) -> void:
	var here := v.node.global_position
	var step := Vector3(target.x - here.x, 0.0, target.z - here.z)
	if step.length() > 0.05:
		v.node.global_position = here + step.normalized() * minf(speed * delta, step.length())
	_face(v, target, delta)
	v.node.animate(delta, speed)


func _face(v: Visitor, target: Vector3, delta: float) -> void:
	var to := target - v.node.global_position
	if Vector2(to.x, to.z).length() > 0.1:
		v.node.rotation.y = lerp_angle(v.node.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))
