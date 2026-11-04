class_name PerkIcon
extends Control
## Pastille de talent dessinée par code : disque coloré par famille + sigle. États : "taken" (or), "picked" (choisi, pas confirmé),
## "open" (disponible), "locked" (grisé).

signal clicked(key: String)
signal hovered(key: String)

var key: String
var state: String = "open"
var selected: bool = false
var _px: int


func _init(perk_key: String = "", px: int = 44, st: String = "taken") -> void:
	key = perk_key
	state = st
	_px = px
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if key != "" and Data.PERKS.has(key):
		tooltip_text = "%s\n%s" % [Data.PERKS[key]["n"], Data.PERKS[key]["d"]]
	mouse_entered.connect(func() -> void: hovered.emit(key))


func set_state(st: String, sel: bool = false) -> void:
	state = st
	selected = sel
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(key)


func _draw() -> void:
	if key == "" or not Data.PERKS.has(key):
		return
	var pd: Dictionary = Data.PERKS[key]
	var c := Vector2(size.x, size.y) * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 2.0
	var fam := Color(str(Data.PERK_FAMILIES[pd["fam"]]["c"]))
	var fill: Color = fam.darkened(0.35)
	var ring: Color = GameTheme.LINE
	var ink: Color = GameTheme.INK
	match state:
		"taken":
			fill = fam.darkened(0.15)
			ring = GameTheme.GOLD
		"picked":
			fill = fam
			ring = Color("f3dc8a")
		"open":
			ring = GameTheme.INK
		"locked":
			fill = Color("2a2620")
			ring = Color("3a3226")
			ink = Color(GameTheme.MUTE, 0.45)
	if selected:
		draw_arc(c, r + 1.5, 0.0, TAU, 40, GameTheme.GOLD, 2.0)
	draw_circle(c, r, Color("141210"))
	draw_circle(c, r - 2.0, fill)
	draw_arc(c, r - 1.0, 0.0, TAU, 40, ring, 2.0 if state != "locked" else 1.0)
	var font: Font = GameTheme.bold_font()
	var fs: int = maxi(10, int(_px * 0.34))
	var txt: String = str(pd["ic"])
	var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if state == "picked":
		draw_circle(Vector2(size.x - 7, 7), 6.0, GameTheme.GOLD)
		draw_string(font, Vector2(size.x - 10.5, 11.0), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("1c1915"))


## Rangée de pastilles « talents pris » d'un homme (null s'il n'en a aucun).
static func row(u: Unit, px: int = 26) -> Control:
	if u.perks.is_empty():
		return null
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	for k in u.perks:
		if Data.PERKS.has(k):
			f.add_child(PerkIcon.new(k, px, "taken"))
	return f
