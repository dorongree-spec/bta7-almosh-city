## What is on screen during play, in the house style (see ui/ui_style.gd):
##
##   top right      the wallet, what was just earned or paid, parking
##                  reports as little paper slips, the day and the clock
##   bottom left    the radar, health and heat under it, the speedometer
##   bottom right   the name of the street
##   top left       the current goal and the keys that do something right now
##   bottom centre  whoever is talking, and the offer card with its E / Q keys
##
## Everything is placed by anchors and offsets from the edges, so it holds
## at any window size. Hebrew text relies on Godot's advanced text server.
class_name Hud
extends CanvasLayer

const EDGE := 28.0             # margin from the edge of the screen
const HINT_AWAKE := 7.0        # seconds the key hints stay bright after they change
const HINT_REST := 0.38        # how see-through they are after that
const TALK_WIDTH := 1120.0     # width of the column that carries speech
const ASK_WIDTH := 780.0       # width of the text on the offer card

var minimap: Minimap
var city_map: CityMap

## Full-screen parent of every element: anchors are worked out against it.
var _ui := Control.new()
var _money: Label
var _money_change: Label
var _ticket_row: HBoxContainer
var _tickets: Tickets
var _clock: Label
var _health: ProgressBar
var _heat: ProgressBar
var _street: Label
var _speed_row: HBoxContainer
var _speed: Label
var _objective: Label
var _hints: HBoxContainer
var _hint_text := ""
var _hint_t := 0.0
var _sub_name: Label
var _sub_text: Label
var _ask_card: PanelContainer
var _ask_name: Label
var _ask_text: Label
var _banner: Label
var _sub_t := 0.0
var _banner_t := 0.0
var _change_t := 0.0


## Parking reports, drawn as slips of paper: one for every inspector after you.
class Tickets:
	extends Control

	const SLIP := Vector2(20.0, 30.0)
	const STEP := 30.0

	var level := 0:
		set(value):
			level = value
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(Law.MAX_LEVEL * STEP, 40.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in Law.MAX_LEVEL:
			var written := i < level
			# Slips fill up from the right, each a little askew.
			draw_set_transform(Vector2(size.x - 16.0 - i * STEP, size.y * 0.5), -0.18, Vector2.ONE)
			draw_rect(Rect2(-SLIP * 0.5, SLIP), Color(UiStyle.PAPER, 1.0 if written else 0.16))
			if written:
				draw_rect(Rect2(-SLIP.x * 0.5, -SLIP.y * 0.5, SLIP.x, 7.0), UiStyle.WASTED)
				for line in 3:
					draw_rect(Rect2(-6.0, -3.0 + line * 5.0, 12.0, 1.5), Color(UiStyle.INK, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ready() -> void:
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Left-to-right placement whatever the language of the computer, so
	# "right" below is the right of the screen. Hebrew still reads right to
	# left: that is decided per label, from its letters.
	_ui.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_ui)
	_fit_ui()
	get_viewport().size_changed.connect(_fit_ui)
	_build_wallet()
	_build_radar()
	_build_street()
	_build_goal_and_hints()
	_build_talk()
	_build_banner()
	city_map = CityMap.new()
	add_child(city_map)


func _fit_ui() -> void:
	_ui.position = Vector2.ZERO
	_ui.size = get_viewport().get_visible_rect().size


# --- building the pieces ---------------------------------------------------------------

func _text(font: Font, size: int, color := UiStyle.PAPER, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var made := UiStyle.label("", font, size, color)
	made.horizontal_alignment = align
	return made


func _build_wallet() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", -4)
	UiStyle.pin(column, Rect2(1, 0, 0, 0), -EDGE - 440.0, 8.0, -EDGE, 320.0)
	_ui.add_child(column)

	_money = _text(UiStyle.display(), 78, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	column.add_child(_money)
	_money_change = _text(UiStyle.body(true), 28, UiStyle.PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	_money_change.visible = false
	column.add_child(_money_change)

	_ticket_row = HBoxContainer.new()
	_ticket_row.alignment = BoxContainer.ALIGNMENT_END
	_ticket_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticket_row.visible = false
	column.add_child(_ticket_row)
	_tickets = Tickets.new()
	_ticket_row.add_child(_tickets)
	_ticket_row.add_child(UiStyle.label("דוחות", UiStyle.heading(), 22, UiStyle.WASTED))

	_clock = _text(UiStyle.heading(), 24, UiStyle.PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	column.add_child(_clock)


func _build_radar() -> void:
	var side := Minimap.RADIUS_PX * 2.0
	var bars_room := 40.0   # space under the radar for the two bars and their names
	minimap = Minimap.new()
	_ui.add_child(minimap)
	UiStyle.pin(minimap, Rect2(0, 1, 0, 0), EDGE, -EDGE - bars_room - side, EDGE + side, -EDGE - bars_room)
	minimap.visible = false

	var half := side * 0.5 - 4.0
	_health = _bar(UiStyle.PINK, EDGE, half, "בריאות")
	_heat = _bar(UiStyle.SUNSET, EDGE + side - half, half, "חום")

	# The speedometer stands to the right of the radar, large, with its unit small beside it.
	_speed_row = HBoxContainer.new()
	_speed_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_row.add_theme_constant_override("separation", 8)
	_speed_row.visible = false
	UiStyle.pin(_speed_row, Rect2(0, 1, 0, 0), EDGE + side + 20.0, -EDGE - 132.0, EDGE + side + 320.0, -EDGE - 24.0)
	_ui.add_child(_speed_row)
	_speed = _text(UiStyle.display(), 104)
	_speed.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_speed_row.add_child(_speed)
	var unit := UiStyle.label("קמ\"ש", UiStyle.heading(), 22, UiStyle.GOLD)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	_speed_row.add_child(unit)


## A thin bar under the radar, `width` wide starting at `left`, with its name below it.
func _bar(color: Color, left: float, width: float, title: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	UiStyle.pin(bar, Rect2(0, 1, 0, 0), left, -EDGE - 30.0, left + width, -EDGE - 20.0)
	_ui.add_child(bar)
	var caption := UiStyle.label(title, UiStyle.body(true), 14, Color(1, 1, 1, 0.8))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.pin(caption, Rect2(0, 1, 0, 0), left, -EDGE - 20.0, left + width, -EDGE + 2.0)
	_ui.add_child(caption)
	return bar


func _build_street() -> void:
	_street = _text(UiStyle.heading(), 28, UiStyle.PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	UiStyle.pin(_street, Rect2(1, 1, 0, 0), -EDGE - 620.0, -EDGE - 46.0, -EDGE, -EDGE - 6.0)
	_ui.add_child(_street)


func _build_goal_and_hints() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	UiStyle.pin(column, Rect2(0, 0, 0, 0), EDGE, 14.0, EDGE + 1000.0, 220.0)
	_ui.add_child(column)
	_objective = _text(UiStyle.heading(), 26, UiStyle.GOLD)
	column.add_child(_objective)
	_hints = HBoxContainer.new()
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.add_theme_constant_override("separation", 6)
	column.add_child(_hints)


## A key as it looks on a keyboard: dark letters on a pale rounded cap.
func _key_cap(key: String, size := 17, tint := UiStyle.PAPER) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var face := StyleBoxFlat.new()
	face.bg_color = Color(tint, 0.94)
	face.set_corner_radius_all(5)
	face.content_margin_left = size * 0.5
	face.content_margin_right = size * 0.5
	face.content_margin_top = 1.0
	face.content_margin_bottom = 1.0
	cap.add_theme_stylebox_override("panel", face)
	var letter := Label.new()
	letter.text = key
	letter.add_theme_font_override("font", UiStyle.body(true))
	letter.add_theme_font_size_override("font_size", size)
	letter.add_theme_color_override("font_color", UiStyle.INK)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(letter)
	return cap


func _build_talk() -> void:
	# Speech stacks upwards from just above the street name: the line being
	# said at the bottom, an offer card (when there is one) above it.
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 4)
	UiStyle.pin(column, Rect2(0.5, 1, 0, 0), -TALK_WIDTH * 0.5, -660.0, TALK_WIDTH * 0.5, -196.0)
	_ui.add_child(column)

	_ask_card = PanelContainer.new()
	_ask_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ask_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ask_card.visible = false
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(UiStyle.INK, 0.86)
	paper.border_color = Color(UiStyle.GOLD, 0.7)
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(12)
	paper.set_content_margin_all(18.0)
	_ask_card.add_theme_stylebox_override("panel", paper)
	column.add_child(_ask_card)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	_ask_card.add_child(inside)
	_ask_name = _text(UiStyle.heading(), 26, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	inside.add_child(_ask_name)
	_ask_text = _text(UiStyle.body(true), 28, UiStyle.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_ask_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask_text.custom_minimum_size = Vector2(ASK_WIDTH, 0.0)   # a wrapping label needs a width to wrap to
	inside.add_child(_ask_text)
	# "No" on the left, "yes" on the right: Hebrew reads the right one first.
	var answers := HBoxContainer.new()
	answers.alignment = BoxContainer.ALIGNMENT_CENTER
	answers.add_theme_constant_override("separation", 10)
	inside.add_child(answers)
	answers.add_child(UiStyle.label("לא", UiStyle.heading(), 26, UiStyle.PINK))
	answers.add_child(_key_cap("Q", 22, UiStyle.PINK))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(70.0, 0.0)
	answers.add_child(gap)
	answers.add_child(UiStyle.label("כן", UiStyle.heading(), 26, UiStyle.TEAL))
	answers.add_child(_key_cap("E", 22, UiStyle.TEAL))

	_sub_name = _text(UiStyle.heading(), 24, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_sub_name.visible = false
	column.add_child(_sub_name)
	_sub_text = _text(UiStyle.body(true), 30, UiStyle.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_text.visible = false
	column.add_child(_sub_text)


func _build_banner() -> void:
	_banner = _text(UiStyle.display(), 140, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UiStyle.pin(_banner, Rect2(0, 0.5, 1, 0), 0.0, -130.0, 0.0, 40.0)
	_ui.add_child(_banner)


# --- what the game tells the screen ----------------------------------------------------

func set_stats(money: int, health: float, heat: float) -> void:
	_money.text = "₪" + _with_commas(money)
	_health.value = health
	_heat.value = heat


## 12500 -> "12,500".
func _with_commas(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out


func set_street(name: String) -> void:
	_street.text = name


func set_speed(kmh: float, in_car: bool) -> void:
	_speed_row.visible = in_car
	if in_car:
		_speed.text = str(roundi(kmh))


func set_clock(text: String) -> void:
	_clock.text = text


## How many parking inspectors are after the player (0 hides the slips).
func set_reports(level: int) -> void:
	_tickets.level = level
	_ticket_row.visible = level > 0


## The keys that do something right now, as "KEY - what it does" joined by
## " · ". Shown as key caps; they dim once they have been up for a while.
func set_hint(text: String) -> void:
	if text == _hint_text:
		return
	_hint_text = text
	_hint_t = HINT_AWAKE
	for old in _hints.get_children():
		old.queue_free()
	var parts := text.split("·", false)
	# Built back to front so the first hint ends up on the right, where a
	# Hebrew reader starts; inside a pair the key is on the right of its words.
	for i in range(parts.size() - 1, -1, -1):
		var pair := parts[i].strip_edges().split(" - ", false, 1)
		if pair.size() < 2:
			_hints.add_child(UiStyle.label(pair[0], UiStyle.body(true), 18))
		else:
			_hints.add_child(UiStyle.label(pair[1].strip_edges(), UiStyle.body(true), 18))
			_hints.add_child(_key_cap(pair[0].strip_edges()))
		if i > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(12.0, 0.0)
			_hints.add_child(gap)


## Current mission goal, shown above the key hints.
func set_objective(text: String) -> void:
	_objective.text = text


func say(speaker: String, text: String, seconds := 4.0) -> void:
	_sub_name.text = speaker
	_sub_name.visible = speaker != ""
	_sub_text.text = text
	_sub_text.visible = text != ""
	_sub_t = seconds


## Somebody is proposing something: the card stays up until end_ask().
func ask(speaker: String, text: String) -> void:
	_ask_name.text = speaker
	_ask_text.text = text
	_ask_card.visible = true


func end_ask() -> void:
	_ask_card.visible = false


## Shows what was just earned or paid under the wallet for a moment.
func flash_money(amount: int) -> void:
	if amount == 0:
		return
	_money_change.text = ("+₪" if amount > 0 else "-₪") + _with_commas(absi(amount))
	_money_change.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if amount > 0 else Color(1.0, 0.45, 0.4))
	_money_change.visible = true
	_change_t = 2.5


func banner(text: String, seconds := 3.0) -> void:
	_banner.text = text
	_banner_t = seconds


func _process(delta: float) -> void:
	_sub_t -= delta
	if _sub_t <= 0.0 and _sub_text.visible:
		_sub_text.visible = false
		_sub_name.visible = false
	_banner_t -= delta
	if _banner_t <= 0.0:
		_banner.text = ""
	_change_t -= delta
	if _change_t <= 0.0:
		_money_change.visible = false
	_hint_t -= delta
	var wanted := 1.0 if _hint_t > 0.0 else HINT_REST
	_hints.modulate.a = move_toward(_hints.modulate.a, wanted, delta * 1.5)


## Pause screen up: the encounter question waits out of sight, and comes
## back as it was on resume (its own visibility is left alone).
func set_paused(on: bool) -> void:
	if _ask_card != null:
		_ask_card.modulate.a = 0.0 if on else 1.0
