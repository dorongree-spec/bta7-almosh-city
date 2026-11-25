## A small floating name over somebody's head, always turned to the camera,
## so that it is clear who in the street is the one talking to you.
class_name NameTag
extends Label3D

const HEIGHT := 2.1            # metres above the feet
const SEEN_FROM := 40.0        # metres


static func make(text_shown: String, tint := Color(1.0, 0.85, 0.3)) -> NameTag:
	var tag := NameTag.new()
	tag.font = UiStyle.heading()
	tag.text = text_shown
	tag.font_size = 48
	tag.pixel_size = 0.0045
	tag.outline_size = 10
	tag.modulate = tint
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.fixed_size = false
	tag.position = Vector3(0, HEIGHT, 0)
	tag.visibility_range_end = SEEN_FROM
	return tag
