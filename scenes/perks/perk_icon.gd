class_name PerkIcon
extends Control
## Pastille ronde d'un talent : disque sombre + icône SVG (`assets/perk_icons/`) teintée au rendu selon l'état.
## États : "taken" (appris : anneau doré, icône à la couleur de sa famille), "open" (disponible : icône claire + halo),
## "reach" (rang atteint mais plus de point : icône pâle), "locked" (grisé), "picked" (sélectionné pour être appris).
## Une seule image par talent : la version « apprise » (colorée) et la version grisée viennent de la teinte (`modulate`).

signal clicked(key: String)
signal hovered(key: String)

const ICON_DIR := "res://assets/perk_icons/"
static var _tex_cache: Dictionary = {}
static var _badge_cache: Dictionary = {}

var key: String
var state: String = "open"
var selected: bool = false
var status_text: String = ""  ## ligne d'état de l'infobulle (posée par PerkTree)
var unit: Unit  ## homme affiché : sert à dire si la maîtrise est active avec son équipement (facultatif)
var _px: int
var _glow: float = 0.0  ## 0..1 : animation « l'anneau s'allume » quand le talent vient d'être appris
var _tween: Tween


func _init(perk_key: String = "", px: int = 44, st: String = "taken") -> void:
	key = perk_key
	state = st
	_px = px
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if key != "" and Data.PERKS.has(key):
		tooltip_text = "%s\n%s" % [Data.PERKS[key]["n"], Data.PERKS[key]["d"]]
	mouse_entered.connect(func() -> void: hovered.emit(key))


static func texture_of(perk_key: String) -> Texture2D:
	if _tex_cache.has(perk_key):
		return _tex_cache[perk_key]
	var tex: Texture2D = null
	var f: String = str(Data.PERKS.get(perk_key, {}).get("icon", ""))
	if f != "" and ResourceLoader.exists(ICON_DIR + f):
		tex = load(ICON_DIR + f) as Texture2D
	_tex_cache[perk_key] = tex
	return tex


## Silhouette de l'arme ou de l'armure de la famille d'un talent de maîtrise (null s'il n'en a pas).
static func badge_of(perk_key: String) -> Texture2D:
	var fam: String = Perks.family_of_perk(perk_key)
	if fam == "":
		return null
	if _badge_cache.has(fam):
		return _badge_cache[fam]
	var fd: Dictionary = Data.WEAPON_FAMILIES.get(fam, Data.ARMOR_FAMILIES.get(fam, {}))
	var path: String = "res://assets/icons/%s.svg" % str(fd.get("badge", ""))
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_badge_cache[fam] = tex
	return tex


static func family_color(perk_key: String) -> Color:
	return Color(str(Data.PERK_FAMILIES[Data.PERKS[perk_key]["fam"]]["c"]))


func set_state(st: String, sel: bool = false) -> void:
	state = st
	selected = sel
	queue_redraw()


## Anneau qui s'allume quand le talent vient d'être appris.
func ignite() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_glow = 1.0
	_tween = create_tween()
	_tween.tween_method(_set_glow, 1.0, 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_glow(v: float) -> void:
	_glow = v
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(key)


func _make_custom_tooltip(_for_text: String) -> Object:
	if key == "" or not Data.PERKS.has(key):
		return null
	var pd: Dictionary = Data.PERKS[key]
	var panel := PanelContainer.new()
	panel.theme = GameTheme.get_theme()
	panel.theme_type_variation = "Card"
	var box := UiKit.vbox(3)
	box.custom_minimum_size = Vector2(260, 0)
	panel.add_child(box)
	box.add_child(UiKit.title(str(pd["n"]), 22))
	box.add_child(UiKit.sub("Rang %d · %s" % [int(pd["tier"]), Data.PERK_FAMILIES[pd["fam"]]["n"]], 13, false))
	box.add_child(UiKit.para(str(pd["d"]), 15))
	var fam: String = Perks.family_of_perk(key)
	if fam != "":
		var kind: String = "Maîtrise" if Perks.tier_of(key) == 4 else "Expert"
		var members := UiKit.sub("%s de la famille « %s » : %s" % [kind, Perks.family_name(fam), Perks.family_members(fam)], 13, false)
		members.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		members.custom_minimum_size = Vector2(250, 0)
		box.add_child(members)
		if unit != null:
			var act: bool = Perks.family_active(unit, fam)
			var st := UiKit.label(Perks.family_status(unit, key), 14, GameTheme.GOOD if act else GameTheme.MUTE, true)
			st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			st.custom_minimum_size = Vector2(250, 0)
			box.add_child(st)
	if status_text != "":
		var col: Color = GameTheme.GOLD if state == "taken" else (GameTheme.GOOD if state == "open" else GameTheme.MUTE)
		var l := UiKit.label(status_text, 14, col, true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(250, 0)
		box.add_child(l)
	return panel


func _draw() -> void:
	if key == "" or not Data.PERKS.has(key):
		return
	var c := Vector2(size.x, size.y) * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 1.5
	var fam: Color = family_color(key)
	var disc: Color = Color("17140f")
	var ring: Color = Color("3a3226")
	var tint: Color = Color(0.45, 0.42, 0.38, 0.55)
	var ring_w: float = 1.5
	match state:
		"taken":
			disc = fam.darkened(0.72)
			ring = GameTheme.GOLD
			tint = fam.lightened(0.25)
			ring_w = 3.0
		"picked":
			disc = fam.darkened(0.6)
			ring = Color("f3dc8a")
			tint = fam.lightened(0.4)
			ring_w = 3.0
		"open":
			disc = Color("221d16")
			ring = Color("7a6a4c")
			tint = GameTheme.INK
			ring_w = 2.0
			draw_circle(c, r + 1.0, Color(GameTheme.GOLD, 0.16 + 0.0))  # halo
		"reach":
			disc = Color("1c1813")
			ring = Color("4a3f31")
			tint = Color(GameTheme.MUTE, 0.8)
			ring_w = 1.5
		"locked":
			disc = Color("14110d")
			ring = Color("2f281f")
			tint = Color(0.5, 0.5, 0.5, 0.38)
			ring_w = 1.0
	draw_circle(c, r, disc)
	var tex: Texture2D = texture_of(key)
	var s: float = r * 1.28
	if tex != null:
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)
	else:
		var font: Font = GameTheme.bold_font()
		var fs: int = maxi(10, int(_px * 0.34))
		var txt: String = str(Data.PERKS[key]["n"]).substr(0, 2)
		var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tint)
	draw_arc(c, r - ring_w * 0.5, 0.0, TAU, 48, ring, ring_w, true)
	var badge: Texture2D = badge_of(key)
	if badge != null and r >= 12.0:  # badge de famille : silhouette de l'arme ou de l'armure, en bas à droite
		var br: float = r * 0.44
		var bc: Vector2 = c + Vector2(r, r) * 0.66
		draw_circle(bc, br + 1.5, Color("0e0c09"))
		var bcol: Color = Color(GameTheme.GOLD, 0.95) if state == "taken" else Color(tint, 0.9)
		draw_texture_rect(badge, Rect2(bc - Vector2(br, br) * 1.12, Vector2(br, br) * 2.24), false, bcol)
		draw_arc(bc, br, 0.0, TAU, 24, Color(ring, 0.9), 1.5, true)
	if _glow > 0.0:  # onde dorée qui s'étend puis s'éteint
		draw_arc(c, r + (1.0 - _glow) * r * 0.45, 0.0, TAU, 48, Color(GameTheme.GOLD, _glow), 3.0, true)
		draw_circle(c, r, Color(GameTheme.GOLD, _glow * 0.25))
	if selected:
		draw_arc(c, r + 2.5, 0.0, TAU, 48, Color("f3dc8a"), 2.0, true)


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
