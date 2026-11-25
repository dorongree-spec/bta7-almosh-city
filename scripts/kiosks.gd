## Somewhere to cool down. Every kiosk, cafe, falafel place and petrol
## station on the real map sells something cold: walk up to one while the
## heat meter is climbing and the player buys a drink, pays for it, and
## cools off. Being in a car with the AC on is the only other way.
class_name Kiosks
extends Node

## Player bought a drink at `place`.
signal served(place: String, line: String, price: int, cooling: float)
signal said(speaker: String, text: String)

const CELL := 60.0            # metres, for the lookup grid
const REACH := 9.0            # how close counts as "at the counter"
const THIRSTY_ABOVE := 35.0   # heat below which nobody bothers
const WARN_ABOVE := 72.0      # heat at which the player starts complaining
const COOLING := 65.0
const COOLDOWN := 20.0        # seconds before the next purchase
const CHECK_EVERY := 0.4

## What each kind of place sells: [line, price in shekels].
const MENU := {
	"kiosk": ["בקבוק מים קפוא. הדבר הכי טוב שקרה לך היום.", 8],
	"convenience": ["בקבוק מים קפוא. הדבר הכי טוב שקרה לך היום.", 8],
	"supermarket": ["שישיית מים. חמש בשביל הדרך, אחת על הראש.", 12],
	"fuel": ["פחית מהמקרר של התחנה. במחיר של מכל דלק.", 14],
	"cafe": ["אייס קפה. חצי קרח, חצי חרטה.", 16],
	"bakery": ["לימונדה ובורקס. הבורקס לא עזר לחום.", 14],
	"fast_food": ["פחית קרה ומזגן. נשארת רבע שעה בלי להזמין כלום.", 9],
	"restaurant": ["קנקן מים מהברז. שירות עשרה אחוז.", 10],
	"ice_cream": ["ארטיק לימון. נמס לפני ששילמת.", 7],
	"bar": ["בירה מהחבית. לא נגד החום, נגד הכול.", 22],
	"pub": ["בירה מהחבית. לא נגד החום, נגד הכול.", 22],
}

var _player: Player
var _grid := {}  # cell (Vector2i) -> Array of {at: Vector2, name: String, kind: String}
var _check_t := 0.0
var _cooldown := 0.0
var _warned := false


func setup(city: CityBuilder, player: Player) -> void:
	_player = player
	for poi: Dictionary in city.data.get("pois", []):
		var kind := String(poi.get("kind", ""))
		if not MENU.has(kind):
			continue
		var p: Array = poi.get("p", [0.0, 0.0])
		var at := Vector2(p[0], p[1])
		var cell := Vector2i(floori(at.x / CELL), floori(at.y / CELL))
		if not _grid.has(cell):
			_grid[cell] = []
		(_grid[cell] as Array).append({"at": at, "name": String(poi.get("name", "קיוסק")), "kind": kind})


func _process(delta: float) -> void:
	if _player == null:
		return
	_cooldown -= delta
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_EVERY

	if _player.heat < WARN_ABOVE:
		_warned = false
	elif not _warned and _player.car == null:
		_warned = true
		said.emit("", "אתה מתבשל. קיוסק, מסעדה, תחנת דלק, כל דבר עם מקרר.")

	if _player.car != null or _cooldown > 0.0 or _player.heat < THIRSTY_ABOVE:
		return
	var spot := _nearest(Vector2(_player.global_position.x, _player.global_position.z))
	if spot.is_empty():
		return
	var offer: Array = MENU[spot.kind]
	var price: int = offer[1]
	if _player.money < price:
		return
	_cooldown = COOLDOWN
	served.emit(String(spot.name), String(offer[0]), price, COOLING)


## The closest place within REACH of `from`, or an empty dictionary.
func _nearest(from: Vector2) -> Dictionary:
	var best := {}
	var best_d := REACH
	var cell := Vector2i(floori(from.x / CELL), floori(from.y / CELL))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for spot: Dictionary in _grid.get(cell + Vector2i(dx, dy), []):
				var at: Vector2 = spot.at
				var d := at.distance_to(from)
				if d < best_d:
					best_d = d
					best = spot
	return best
