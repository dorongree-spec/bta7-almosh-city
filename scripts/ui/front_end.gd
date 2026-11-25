## Everything around the game rather than in it: the loading screen with
## its artwork and tips, the title menu, the pause menu, the black bars and
## captions of the opening shot, the name of the neighbourhood you have just
## driven into, and the big card across the screen when you pass out.
##
## Artwork is whatever is found in assets/art: files called keyart_*.jpg
## (rendered stills) come first, then poster_*.jpg (the drawn posters), so
## pictures can be added or replaced without touching this file.
##
## This layer keeps running while the game is paused; it is the thing that
## pauses it.
class_name FrontEnd
extends CanvasLayer

## The player chose "start" on the title menu (emitted while the screen is black).
signal start_pressed

enum Screen { LOADING, TITLE, GAME, PAUSED }

const ART_DIR := "res://assets/art/"
const LOGO := "res://assets/art/logo.png"
const SLIDE_TIME := 8.0        # seconds each picture stays up
const CROSS_FADE := 1.4
const ZOOM := 1.08             # how far a picture drifts in while it is up
const BAR_SHARE := 0.115       # height of each cinema bar, as a share of the screen
const SIDE := 70.0             # margin from the edge of the screen
const COLUMN := 620.0          # width of the logo and menu column

const TIPS := [
	"בכיכר, זכות קדימה היא עניין של אופי.",
	"כיסא כתר מחזיק שלוש מכות. השכנים מחזיקים יותר.",
	"הפקח לא ישן. הפקח רק ממצמץ.",
	"הטנדרים לא נלחמים. הם מתמחרים.",
	"אל תיגע בספוילר. ברצינות.",
	"סבתא גלינה היא הדבר הכי קרוב שיש פה לחוק.",
	"E זה כן, Q זה לא. מקש ל\"אולי\" אין. זאת באר שבע.",
	"חם לך? נכנסים לקניון. המזגן בחינם.",
	"יום חמישי: הסטודנטים נסעו, החנייה חזרה.",
	"מי שמביא כיסא משלו, מקבל קפה.",
	"צפירה לא מקצרת כיכר. היא רק מזמינה שיחה.",
	"מהיישובים? כולם פה מהיישובים. חוץ מאלה שלא.",
]

const CONTROLS := "WASD או חצים  ·  הליכה ונהיגה\nShift  ·  ריצה\nרווח או קליק  ·  מכה, ובלם יד ברכב\nF  ·  כניסה ויציאה מרכב, הרמת כיסא\nE  ·  כן, או פתיחת שיחה עם עובר אורח\nQ  ·  לא\nH  ·  צופר        R  ·  רדיו        M  ·  מפה\nEsc  ·  הפסקה"

const CREDITS := "BTA 7 אלמוש סיטי התחיל כבדיחה פרטית ויצא משליטה. עכשיו הוא קוד פתוח.\nסאטירה. כל הדמויות והכנופיות בדיוניות. כל דמיון למציאות הוא בעיה של המציאות.\n\nמנוע: Godot 4 (MIT)   ·   מפה: © תורמי OpenStreetMap (ODbL)\nמודלים, אנימציות, מרקמים וצלילים ברישיון CC0: Quaternius, Kenney, Poly Haven, ambientCG\nגופנים ברישיון OFL: Heebo, Secular One, Karantina\nקוד: MIT  ·  תוכן: CC BY-SA 4.0  ·  פירוט מלא ב-CREDITS.md"

var screen := Screen.LOADING
## Called when the pause menu opens; returns the text of the "where things stand" column.
var pause_info := Callable()

var _root := Control.new()
var _art: Array[Texture2D] = []
var _slides: Array[TextureRect] = []
var _showing := 0              # index into _slides of the picture on top
var _next_art := 0
var _slide_t := 0.0
var _tip_i := 0
var _backdrop: Control         # pictures and their shading
var _loading: Control          # tip, progress line
var _title: Control            # logo column with the menu
var _menu: VBoxContainer
var _tip: Label
var _step: Label
var _progress: ProgressBar
var _bars: Array[ColorRect] = []
var _captions: VBoxContainer
var _area: Label
var _card: Control
var _card_title: Label
var _card_sub: Label
var _pause: Control
var _pause_menu: VBoxContainer
var _pause_stats: Label
var _sheet: Control            # the "controls" / "credits" page
var _sheet_title: Label
var _sheet_body: Label
var _sheet_back: Button
var _sheet_return: Control     # what gets the focus back when the page closes
var _fade: ColorRect
var _bar_tween: Tween
var _area_tween: Tween
var _card_tween: Tween


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Placed left-to-right whatever the language of the computer, so that
	# "right" below always means the right of the screen. Hebrew text still
	# reads right to left: that is decided per label, from its letters.
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_root)
	_fit()
	get_viewport().size_changed.connect(_fit)

	_art = _find_art()
	_build_backdrop()
	_build_loading()
	_build_title()
	_build_bars_and_captions()
	_build_area_and_card()
	_build_pause()
	_build_sheet()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whole(_fade)
	_root.add_child(_fade)

	_show_screen(Screen.LOADING)
	_next_slide(true)
	_fade_to(0.0, 0.8)


func _fit() -> void:
	_root.position = Vector2.ZERO
	_root.size = get_viewport().get_visible_rect().size
	for slide in _slides:
		slide.pivot_offset = _root.size * 0.5


## Stretches a control over the whole screen.
func _whole(c: Control) -> void:
	UiStyle.pin(c, Rect2(0, 0, 1, 1), 0, 0, 0, 0)


# --- building the pieces ---------------------------------------------------------------

## Every picture in assets/art, rendered stills first. In an exported game
## the folder lists "name.jpg.import" instead of "name.jpg", hence the trim.
func _find_art() -> Array[Texture2D]:
	var names: Array[String] = []
	var dir := DirAccess.open(ART_DIR)
	if dir != null:
		for file: String in dir.get_files():
			var plain := file.trim_suffix(".import")
			var is_art := plain.begins_with("keyart_") or plain.begins_with("poster_")
			if is_art and plain.get_extension() in ["jpg", "png"] and not names.has(plain):
				names.append(plain)
	names.sort()  # "keyart_" sorts before "poster_"
	var found: Array[Texture2D] = []
	for plain in names:
		if ResourceLoader.exists(ART_DIR + plain):
			var picture := load(ART_DIR + plain) as Texture2D
			if picture != null:
				found.append(picture)
	return found


func _build_backdrop() -> void:
	_backdrop = Control.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whole(_backdrop)
	_root.add_child(_backdrop)
	var night := ColorRect.new()
	night.color = UiStyle.INK
	_whole(night)
	_backdrop.add_child(night)
	for i in 2:
		var slide := TextureRect.new()
		slide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slide.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		slide.modulate.a = 0.0
		slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_whole(slide)
		slide.pivot_offset = _root.size * 0.5
		_backdrop.add_child(slide)
		_slides.append(slide)
	# Darker towards the right and the bottom, where the words go.
	_backdrop.add_child(_shade(Vector2(0.35, 0.0), Vector2(1.0, 0.0), 0.82))
	_backdrop.add_child(_shade(Vector2(0.0, 0.55), Vector2(0.0, 1.0), 0.75))


## A see-through-to-dark gradient over the whole screen.
func _shade(from: Vector2, to: Vector2, strength: float) -> TextureRect:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(UiStyle.INK, 0.0))
	ramp.set_color(1, Color(UiStyle.INK, strength))
	var fill := GradientTexture2D.new()
	fill.gradient = ramp
	fill.fill_from = from
	fill.fill_to = to
	fill.width = 256
	fill.height = 256
	var rect := TextureRect.new()
	rect.texture = fill
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whole(rect)
	return rect


## The BTA 7 mark on a soft dark oval, so its thin white chair (far left) and
## the strap line read over a bright sky as well as over the dim pause screen.
func _logo(height: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(COLUMN, height)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := GradientTexture2D.new()
	shade.fill = GradientTexture2D.FILL_RADIAL
	shade.fill_from = Vector2(0.5, 0.5)
	shade.fill_to = Vector2(1.0, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(UiStyle.INK, 0.62))
	ramp.set_color(1, Color(UiStyle.INK, 0.0))
	ramp.add_point(0.8, Color(UiStyle.INK, 0.5))
	shade.gradient = ramp
	var back := TextureRect.new()
	back.texture = shade
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whole(back)
	holder.add_child(back)
	var mark := TextureRect.new()
	if ResourceLoader.exists(LOGO):
		mark.texture = load(LOGO) as Texture2D
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whole(mark)
	holder.add_child(mark)
	return holder


func _build_loading() -> void:
	_loading = Control.new()
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whole(_loading)
	_root.add_child(_loading)

	var mark := _logo(310.0)
	UiStyle.pin(mark, Rect2(1, 1, 0, 0), -SIDE - COLUMN, -SIDE - 400.0, -SIDE, -SIDE - 90.0)
	_loading.add_child(mark)

	_step = UiStyle.label("", UiStyle.heading(), 26, UiStyle.GOLD)
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.pin(_step, Rect2(1, 1, 0, 0), -SIDE - COLUMN, -SIDE - 78.0, -SIDE, -SIDE - 40.0)
	_loading.add_child(_step)

	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.fill_mode = ProgressBar.FILL_END_TO_BEGIN  # fills from the right, like the text
	var done := StyleBoxFlat.new()
	done.bg_color = UiStyle.PINK
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(1, 1, 1, 0.18)
	_progress.add_theme_stylebox_override("fill", done)
	_progress.add_theme_stylebox_override("background", rest)
	UiStyle.pin(_progress, Rect2(1, 1, 0, 0), -SIDE - COLUMN, -SIDE - 26.0, -SIDE, -SIDE - 18.0)
	_loading.add_child(_progress)

	_tip = UiStyle.label("", UiStyle.body(true), 30)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	UiStyle.pin(_tip, Rect2(0, 1, 0, 0), SIDE, -SIDE - 160.0, SIDE + 760.0, -SIDE)
	_root.add_child(_tip)


func _build_title() -> void:
	_title = Control.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whole(_title)
	_root.add_child(_title)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 6)
	UiStyle.pin(column, Rect2(1, 0, 0, 1), -SIDE - COLUMN, SIDE, -SIDE, -SIDE)
	_title.add_child(column)
	column.add_child(_logo(330.0))
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 0)
	column.add_child(_menu)
	_menu.add_child(_menu_item("יאללה, נוסעים", _on_start))
	_menu.add_child(_menu_item("איך משחקים", func(): _open_sheet("איך משחקים", CONTROLS, _menu)))
	_menu.add_child(_menu_item("קרדיטים", func(): _open_sheet("קרדיטים", CREDITS, _menu)))
	_menu.add_child(_menu_item("יציאה", func(): get_tree().quit()))
	var small := UiStyle.label("כל הדמויות והכנופיות בדיוניות. כל דמיון למציאות הוא בעיה של המציאות.", UiStyle.body(), 18, Color(1, 1, 1, 0.7))
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(small)


## One line of a menu: plain text that turns gold under the mouse or the keyboard focus.
func _menu_item(text: String, action: Callable, size := 46) -> Button:
	var item := Button.new()
	item.text = text
	item.flat = true
	item.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item.focus_mode = Control.FOCUS_ALL
	item.add_theme_font_override("font", UiStyle.heading())
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", UiStyle.PAPER)
	item.add_theme_color_override("font_hover_color", UiStyle.GOLD)
	item.add_theme_color_override("font_focus_color", UiStyle.GOLD)
	item.add_theme_color_override("font_pressed_color", UiStyle.PINK)
	item.add_theme_color_override("font_outline_color", Color(UiStyle.INK, 0.9))
	item.add_theme_constant_override("outline_size", 8)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		item.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	item.mouse_entered.connect(item.grab_focus)
	item.pressed.connect(action)
	return item


func _build_bars_and_captions() -> void:
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if top:
			UiStyle.pin(bar, Rect2(0, 0, 1, 0), 0, 0, 0, 0)
		else:
			UiStyle.pin(bar, Rect2(0, 1, 1, 0), 0, 0, 0, 0)
		_root.add_child(bar)
		_bars.append(bar)
	_captions = VBoxContainer.new()
	_captions.alignment = BoxContainer.ALIGNMENT_END
	_captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_captions.add_theme_constant_override("separation", -6)
	UiStyle.pin(_captions, Rect2(1, 1, 0, 0), -SIDE - 900.0, -SIDE - 420.0, -SIDE, -SIDE - 110.0)
	_root.add_child(_captions)


func _build_area_and_card() -> void:
	_area = UiStyle.label("", UiStyle.display(), 72)
	_area.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_area.modulate.a = 0.0
	# Above the HUD street name, below the subtitles (PC: it overlapped them).
	UiStyle.pin(_area, Rect2(1, 1, 0, 0), -SIDE - 900.0, -178.0, -30.0, -96.0)
	_root.add_child(_area)

	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	_whole(_card)
	_root.add_child(_card)
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.62)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.pin(band, Rect2(0, 0.5, 1, 0), 0, -130.0, 0, 130.0)
	_card.add_child(band)
	_card_title = UiStyle.label("", UiStyle.display(), 170, UiStyle.WASTED)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.pin(_card_title, Rect2(0, 0.5, 1, 0), 0, -128.0, 0, 52.0)
	_card.add_child(_card_title)
	_card_sub = UiStyle.label("", UiStyle.body(true), 30)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.pin(_card_sub, Rect2(0, 0.5, 1, 0), 0, 62.0, 0, 110.0)
	_card.add_child(_card_sub)


func _build_pause() -> void:
	_pause = Control.new()
	_pause.visible = false
	_whole(_pause)
	_root.add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, 0.78)
	_whole(dim)
	_pause.add_child(dim)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	UiStyle.pin(column, Rect2(1, 0, 0, 1), -SIDE - COLUMN, SIDE, -SIDE, -SIDE)
	_pause.add_child(column)
	column.add_child(_logo(250.0))
	var heading := UiStyle.label("הפסקה", UiStyle.display(), 120, UiStyle.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(heading)
	_pause_menu = VBoxContainer.new()
	column.add_child(_pause_menu)
	_pause_menu.add_child(_menu_item("ממשיכים", resume))
	_pause_menu.add_child(_menu_item("איך משחקים", func(): _open_sheet("איך משחקים", CONTROLS, _pause_menu)))
	_pause_menu.add_child(_menu_item("יציאה מהמשחק", func(): get_tree().quit()))

	_pause_stats = UiStyle.label("", UiStyle.body(true), 30)
	_pause_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.pin(_pause_stats, Rect2(0, 0, 0, 1), SIDE, SIDE, SIDE + 640.0, -SIDE)
	_pause.add_child(_pause_stats)


func _build_sheet() -> void:
	_sheet = Control.new()
	_sheet.visible = false
	_whole(_sheet)
	_root.add_child(_sheet)
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, 0.9)
	_whole(dim)
	_sheet.add_child(dim)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	UiStyle.pin(column, Rect2(0.5, 0, 0, 1), -520.0, SIDE, 520.0, -SIDE)
	_sheet.add_child(column)
	_sheet_title = UiStyle.label("", UiStyle.display(), 110, UiStyle.GOLD)
	_sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_sheet_title)
	_sheet_body = UiStyle.label("", UiStyle.body(), 28)
	_sheet_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_sheet_body)
	_sheet_back = _menu_item("חזרה", _close_sheet, 40)
	_sheet_back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_sheet_back)


# --- loading and title -----------------------------------------------------------------

## Loading has moved on: `done` is 0..1 and `what` says what is being built.
func set_progress(done: float, what: String) -> void:
	_progress.value = done
	_step.text = what


## The city is built: the loading line gives way to the menu.
func loading_done() -> void:
	_show_screen(Screen.TITLE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_first_item(_menu).grab_focus()


func _on_start() -> void:
	if screen != Screen.TITLE:
		return
	screen = Screen.GAME  # no second press while the screen goes dark
	var dark := _fade_to(1.0, 0.6)
	dark.tween_callback(func():
		_show_screen(Screen.GAME)
		start_pressed.emit()
		_fade_to(0.0, 1.2))


## Straight into the game with nothing on screen (used by the photo tour).
func enter_game() -> void:
	_fade.color.a = 0.0
	_show_screen(Screen.GAME)


func _show_screen(which: Screen) -> void:
	screen = which
	var art_up := which == Screen.LOADING or which == Screen.TITLE
	_backdrop.visible = art_up
	_tip.visible = art_up
	_loading.visible = which == Screen.LOADING
	_title.visible = which == Screen.TITLE
	_pause.visible = which == Screen.PAUSED


func _first_item(menu: Container) -> Control:
	return menu.get_child(0) as Control


func _fade_to(alpha: float, seconds: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	return tween


func _process(delta: float) -> void:
	if not _backdrop.visible:
		return
	_slide_t += delta
	if _slide_t >= SLIDE_TIME:
		_next_slide(false)


## Brings the next picture (and the next tip) up over the current one.
func _next_slide(at_once: bool) -> void:
	_slide_t = 0.0
	_tip.text = "טיפ:  " + str(TIPS[_tip_i % TIPS.size()])
	_tip_i += 1
	if _art.is_empty():
		return
	var incoming := _slides[1 - _showing]
	incoming.texture = _art[_next_art % _art.size()]
	_next_art += 1
	_backdrop.move_child(incoming, 2)  # above the other picture, below the shading
	incoming.modulate.a = 0.0
	incoming.scale = Vector2.ONE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(incoming, "modulate:a", 1.0, 0.01 if at_once else CROSS_FADE)
	tween.tween_property(incoming, "scale", Vector2.ONE * ZOOM, SLIDE_TIME + CROSS_FADE * 2.0)
	_showing = 1 - _showing


# --- the page of text (controls, credits) ------------------------------------------------

func _open_sheet(title: String, body: String, back_to: Container) -> void:
	_sheet_title.text = title
	_sheet_body.text = body
	_sheet_return = _first_item(back_to)
	_sheet.visible = true
	_root.move_child(_sheet, _root.get_child_count() - 2)  # over everything but the fade
	_sheet_back.grab_focus()


func _close_sheet() -> void:
	_sheet.visible = false
	if _sheet_return != null and _sheet_return.is_visible_in_tree():
		_sheet_return.grab_focus()


# --- pause -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _sheet.visible:
		_close_sheet()
	elif screen == Screen.GAME:
		pause()
	elif screen == Screen.PAUSED:
		resume()
	else:
		return
	get_viewport().set_input_as_handled()


func pause() -> void:
	if screen != Screen.GAME:
		return
	_pause_stats.text = str(pause_info.call()) if pause_info.is_valid() else ""
	_show_screen(Screen.PAUSED)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_first_item(_pause_menu).grab_focus()


func resume() -> void:
	if screen != Screen.PAUSED:
		return
	_show_screen(Screen.GAME)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- in the game -----------------------------------------------------------------------

## Cinema bars slide in and the lines appear one after the other, large
## first: the caption of an opening shot.
func begin_intro(lines: Array) -> void:
	_slide_bars(true)
	for old in _captions.get_children():
		old.queue_free()
	var delay := 1.2
	for i in lines.size():
		var first := i == 0
		var line := UiStyle.label(str(lines[i]), UiStyle.display() if first else UiStyle.heading(), 150 if first else 38,
				UiStyle.PAPER if first else UiStyle.GOLD)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.modulate.a = 0.0
		_captions.add_child(line)
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(line, "modulate:a", 1.0, 0.7)
		delay += 0.9


func end_intro() -> void:
	_slide_bars(false)
	for line in _captions.get_children():
		var tween := create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.8)
		tween.tween_callback(line.queue_free)


func _slide_bars(shut: bool) -> void:
	var tall := _root.size.y * BAR_SHARE if shut else 0.0
	if _bar_tween != null:
		_bar_tween.kill()
	_bar_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bar_tween.tween_property(_bars[0], "offset_bottom", tall, 0.9)
	_bar_tween.tween_property(_bars[1], "offset_top", -tall, 0.9)


## The name of the part of town the player has just entered, bottom right.
func area(place: String) -> void:
	if screen != Screen.GAME:
		return
	_area.text = place
	if _area_tween != null:
		_area_tween.kill()
	_area_tween = create_tween()
	_area_tween.tween_property(_area, "modulate:a", 1.0, 0.5)
	_area_tween.tween_interval(3.5)
	_area_tween.tween_property(_area, "modulate:a", 0.0, 1.2)


## A band across the middle of the screen with one enormous word on it.
func card(title: String, subtitle := "", tint := UiStyle.WASTED, seconds := 3.0) -> void:
	_card_title.text = title
	_card_title.add_theme_color_override("font_color", tint)
	_card_sub.text = subtitle
	if _card_tween != null:
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.35)
	_card_tween.tween_interval(seconds)
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.8)


## Developer aid for the photo tour: puts one of the screens up as it would
## look, without pausing or starting anything. "loading", "title", "pause",
## "card", "intro" or "game".
func preview(what: String) -> void:
	_fade.color.a = 0.0
	end_intro()
	_card.modulate.a = 0.0
	match what:
		"loading":
			_show_screen(Screen.LOADING)
			set_progress(0.6, "מסדר את הכיכרות")
		"title":
			_show_screen(Screen.TITLE)
		"pause":
			_pause_stats.text = str(pause_info.call()) if pause_info.is_valid() else ""
			_show_screen(Screen.PAUSED)
		"card":
			_show_screen(Screen.GAME)
			card("התייבשת", "שתית מים היום? לא. ברור שלא.", UiStyle.WASTED, 30.0)
		"intro":
			_show_screen(Screen.GAME)
			begin_intro(["באר שבע", "יום רביעי  ·  15:30  ·  34 מעלות בצל, ואין צל"])
		_:
			_show_screen(Screen.GAME)
