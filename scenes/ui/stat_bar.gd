class_name StatBar
extends Control
## Barre « libellé — jauge — valeur/max » (PV, armure, fatigue, XP).

const LABEL_W := 58.0
const VALUE_W := 62.0

var label_text: String
var value: float
var max_value: float
var color: Color


func _init(p_label: String = "", p_value: float = 0.0, p_max: float = 1.0, p_color: Color = GameTheme.BLOOD) -> void:
	label_text = p_label
	value = p_value
	max_value = p_max
	color = p_color
	custom_minimum_size = Vector2(0, 16)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(0, 12), label_text, HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, 12, GameTheme.INK)
	var track := Rect2(LABEL_W, 4, maxf(0.0, size.x - LABEL_W - VALUE_W - 12.0), 8)
	draw_rect(track, Color("15120f"))
	var frac: float = clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)), color)
	draw_string(font, Vector2(size.x - VALUE_W, 12), "%d/%d" % [roundi(value), roundi(max_value)], HORIZONTAL_ALIGNMENT_RIGHT, VALUE_W, 12, GameTheme.MUTE)
