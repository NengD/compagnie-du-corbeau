class_name StatRow
extends Control
## Ligne de statistique de la fiche de personnage : petite icône, jauge sombre remplie à la couleur de la statistique, valeur centrée.
## Tout est dessiné par code (icônes d'objets de ItemIcons ou glyphes simples) : aucune image copiée.

const H: float = 21.0
const ICON_W: float = 22.0
const LABEL_W: float = 82.0  ## largeur réservée au libellé court (0 si la ligne n'en a pas)
const LABEL_FS: int = 12

var icon_kind: String = ""  ## "heart", "hourglass", "chevrons", "flag", "ring", "eye" (dessinés) ou "kind:key" d'une icône d'objet
var value: float = 0.0
var max_value: float = 100.0
var color: Color = GameTheme.BLOOD
var text: String = ""
var tip: String = ""
var label_text: String = ""  ## libellé court affiché entre l'icône et la jauge (« PV », « Armure tête »…)
var _tex: Texture2D = null


func _init(p_icon: String = "", p_value: float = 0.0, p_max: float = 100.0, p_color: Color = GameTheme.BLOOD, p_text: String = "", p_tip: String = "", p_label: String = "") -> void:
	icon_kind = p_icon
	value = p_value
	max_value = p_max
	color = p_color
	text = p_text
	tip = p_tip
	label_text = p_label
	custom_minimum_size = Vector2(0, H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = p_tip
	if p_icon.contains(":"):
		var kk: PackedStringArray = p_icon.split(":")
		_tex = ItemIcons.get_icon(kk[0], kk[1])


func _draw() -> void:
	var font: Font = GameTheme.bold_font()
	var lw: float = LABEL_W if label_text != "" else 0.0
	var track := Rect2(ICON_W + 4.0 + lw, 2.0, maxf(0.0, size.x - ICON_W - 4.0 - lw), H - 4.0)
	draw_rect(track, Color("0f0c09"))
	var frac: float = clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	var fill := Rect2(track.position + Vector2(1, 1), Vector2(maxf(0.0, (track.size.x - 2.0) * frac), track.size.y - 2.0))
	draw_rect(fill, color.darkened(0.25))
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.45)), Color(1, 1, 1, 0.08))
	draw_rect(track, Color("3a2f22"), false, 1.0)
	var fs: int = 13
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(track.position.x + (track.size.x - w) * 0.5, track.position.y + track.size.y * 0.5 + fs * 0.34)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GameTheme.INK)
	if label_text != "":
		var lpos := Vector2(ICON_W + 4.0, H * 0.5 + LABEL_FS * 0.34)
		draw_string(font, lpos, label_text, HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 4.0, LABEL_FS, GameTheme.MUTE)
	_draw_icon(Rect2(0, 0, ICON_W, H))


func _draw_icon(r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	var gold := Color("d9b25a")
	if _tex != null:
		draw_texture_rect(_tex, Rect2(c - Vector2(9, 9), Vector2(18, 18)), false)
		return
	match icon_kind:
		"heart":
			draw_circle(c + Vector2(-3.5, -2.5), 4.0, Color("c0392b"))
			draw_circle(c + Vector2(3.5, -2.5), 4.0, Color("c0392b"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-7.4, -0.5), c + Vector2(7.4, -0.5), c + Vector2(0, 8)]), Color("c0392b"))
		"hourglass":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -8), c + Vector2(6, -8), c + Vector2(0, 0)]), gold)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 8), c + Vector2(6, 8), c + Vector2(0, 0)]), gold.darkened(0.2))
			draw_line(c + Vector2(-7, -8), c + Vector2(7, -8), gold, 2.0)
			draw_line(c + Vector2(-7, 8), c + Vector2(7, 8), gold, 2.0)
		"chevrons":
			for k in 2:
				var y: float = -4.0 + 7.0 * k
				draw_polyline(PackedVector2Array([c + Vector2(-6, y + 3), c + Vector2(0, y - 3), c + Vector2(6, y + 3)]), gold, 2.2)
		"flag":
			draw_line(c + Vector2(-5, 8), c + Vector2(-5, -8), gold, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -8), c + Vector2(7, -4), c + Vector2(-5, 1)]), gold.darkened(0.1))
		"ring":
			draw_arc(c, 6.5, 0.0, TAU, 20, gold, 2.2)
			draw_circle(c, 2.2, gold)
		"eye":
			draw_arc(c + Vector2(0, 5), 8.0, PI + 0.5, TAU - 0.5, 14, gold, 2.0)
			draw_arc(c + Vector2(0, -5), 8.0, 0.5, PI - 0.5, 14, gold, 2.0)
			draw_circle(c, 2.6, gold)
		"weight":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 6), c + Vector2(5, 6), c + Vector2(3, -3), c + Vector2(-3, -3)]), gold.darkened(0.15))
			draw_arc(c + Vector2(0, -5), 3.0, 0.0, TAU, 12, gold, 1.8)
		"percent":
			draw_circle(c + Vector2(-3.5, -3.5), 2.4, gold)
			draw_circle(c + Vector2(3.5, 3.5), 2.4, gold)
			draw_line(c + Vector2(5, -6), c + Vector2(-5, 6), gold, 1.8)
