## The look of everything written on screen: the three typefaces and the
## handful of colours the interface is allowed to use. All fonts are open
## (SIL OFL, see assets/CREDITS.md) and carry both Hebrew and Latin.
##
##   display()  Karantina Bold   tall condensed capitals: logo lines, big cards
##   heading()  Secular One      menu items, names of places
##   body()     Heebo            everything that has to be read quickly
class_name UiStyle
extends RefCounted

const FONTS := "res://assets/fonts/"

const GOLD := Color(1.0, 0.82, 0.35)
const SUNSET := Color(1.0, 0.54, 0.23)
const PINK := Color(0.94, 0.19, 0.48)
const TEAL := Color(0.75, 0.95, 0.94)
const INK := Color(0.07, 0.024, 0.12)       # the dark purple of the logo outline
const PAPER := Color(1.0, 0.98, 0.94)
const WASTED := Color(0.95, 0.2, 0.2)

static var _cache := {}


static func display() -> Font:
	return _font("Karantina-Bold.ttf", 700)


static func heading() -> Font:
	return _font("SecularOne-Regular.ttf", 400)


static func body(bold := false) -> Font:
	return _font("Heebo-Bold.ttf" if bold else "Heebo-Regular.ttf", 700 if bold else 400)


## The font file if Godot has imported it, otherwise a system font of about
## the same weight, so a missing file never leaves the screen without text.
static func _font(file: String, weight: int) -> Font:
	if _cache.has(file):
		return _cache[file]
	var found: Font = null
	if ResourceLoader.exists(FONTS + file):
		found = load(FONTS + file) as Font
	if found == null:
		var fallback := SystemFont.new()
		fallback.font_names = PackedStringArray(["Arial", "Segoe UI", "DejaVu Sans", "Noto Sans Hebrew"])
		fallback.font_weight = weight
		found = fallback
	_cache[file] = found
	return found


## A label in one of the house fonts, with the soft dark outline that keeps
## text readable over any picture.
static func label(text: String, font: Font, size: int, color := PAPER) -> Label:
	var made := Label.new()
	made.text = text
	made.add_theme_font_override("font", font)
	made.add_theme_font_size_override("font_size", size)
	made.add_theme_color_override("font_color", color)
	made.add_theme_color_override("font_outline_color", Color(INK, 0.85))
	made.add_theme_constant_override("outline_size", maxi(4, size / 7))
	made.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	made.add_theme_constant_override("shadow_offset_x", 0)
	made.add_theme_constant_override("shadow_offset_y", maxi(2, size / 18))
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## Pins a control to a rectangle of its parent: the anchors say which part
## (0..1 on each axis) and the offsets how many pixels in from there. Written
## out in full because setting `position` on an anchored control is ignored.
static func pin(c: Control, anchors: Rect2, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = anchors.position.x
	c.anchor_top = anchors.position.y
	c.anchor_right = anchors.end.x
	c.anchor_bottom = anchors.end.y
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom
