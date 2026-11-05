class_name MapMini
extends Control
## Mini-carte du grand monde : relief et territoires colorés (texture réduite précalculée, une seule fois), lieux, position de la
## compagnie (point doré) et rectangle de la vue. Clic ou glisser = déplacer la caméra. Repliable (réglage `Settings.minimap`).
## Ne calcule aucune règle : lit `Game.world`.

signal navigate(world_pos: Vector2)
signal collapse_toggled(collapsed: bool)

const INNER := Vector2(220, 146)
const PAD := 6.0
const HEAD := 20.0
const TERRAIN_COL: Array[Color] = [
	Color("8fa65a"), Color("4f6e3a"), Color("a39a62"), Color("4a7498"), Color("78726a"), Color("b59a5c"), Color("6f98b0"), Color("62703f"), Color("e4eaec"),
]

static var _cache_key: String = ""
static var _cache_tex: ImageTexture

var collapsed: bool = false
var _tex: ImageTexture
var _world: World
var _view_rect: Rect2 = Rect2()
var _player: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _toggle: Button


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = _full_size()
	size = custom_minimum_size


func _ready() -> void:
	_toggle = Button.new()
	_toggle.flat = true
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.text = "▾"
	_toggle.tooltip_text = "Replier la mini-carte"
	_toggle.add_theme_font_size_override("font_size", 14)
	_toggle.custom_minimum_size = Vector2(22, 18)
	_toggle.position = Vector2(_full_size().x - 28.0, 1.0)
	_toggle.pressed.connect(func() -> void: set_collapsed(not collapsed))
	add_child(_toggle)


func _full_size() -> Vector2:
	return Vector2(INNER.x + PAD * 2.0, INNER.y + PAD * 2.0 + HEAD)


## Rectangle de la carte (dans le contrôle).
func map_rect() -> Rect2:
	return Rect2(Vector2(PAD, PAD + HEAD), INNER)


func set_collapsed(on: bool) -> void:
	collapsed = on
	var sz: Vector2 = Vector2(_full_size().x, HEAD + 2.0) if on else _full_size()
	custom_minimum_size = sz
	size = sz
	if _toggle != null:
		_toggle.text = "▸" if on else "▾"
		_toggle.tooltip_text = "Déplier la mini-carte" if on else "Replier la mini-carte"
	collapse_toggled.emit(on)
	queue_redraw()


## Construit la texture réduite du monde (relief + territoires). Mise en cache tant que le monde ne change pas.
func rebuild(w: World) -> void:
	_world = w
	var key: String = "%d|%d|%s" % [hash(w.terrain), w.settlements.size(), _owners_sig(w)]
	if key == _cache_key and _cache_tex != null:
		_tex = _cache_tex
		queue_redraw()
		return
	var img := Image.create(w.gw, w.gh, false, Image.FORMAT_RGB8)
	var lab: Dictionary = Territory.labels(w, 2)
	var n: int = int(lab["w"])
	var own: PackedByteArray = lab["own"]
	var keys: Array = lab["keys"]
	for y in w.gh:
		for x in w.gw:
			var t: int = w.terrain[y * w.gw + x]
			var c: Color = TERRAIN_COL[clampi(t, 0, TERRAIN_COL.size() - 1)]
			var v: int = own[(y / 2) * n + (x / 2)]
			if v > 0 and t != World.T.WATER:
				c = c.lerp(MapPlaces.faction_color(str(keys[v - 1])), 0.42)
			img.set_pixel(x, y, c)
	_tex = ImageTexture.create_from_image(img)
	_cache_key = key
	_cache_tex = _tex
	queue_redraw()


static func _owners_sig(w: World) -> String:
	var parts: PackedStringArray = []
	for s in w.settlements:
		parts.append(str(s.get("owner", "")))
	return ",".join(parts)


## Met à jour le rectangle de vue (monde) et la position de la compagnie ; ne redessine que si quelque chose a changé.
func set_state(view_rect: Rect2, player: Vector2) -> void:
	if view_rect.is_equal_approx(_view_rect) and player.is_equal_approx(_player):
		return
	_view_rect = view_rect
	_player = player
	if not collapsed:
		queue_redraw()


func to_mini(p: Vector2) -> Vector2:
	var r: Rect2 = map_rect()
	return r.position + Vector2(p.x / _world.size.x * r.size.x, p.y / _world.size.y * r.size.y)


func to_world(m: Vector2) -> Vector2:
	var r: Rect2 = map_rect()
	return Vector2(clampf((m.x - r.position.x) / r.size.x, 0.0, 1.0) * _world.size.x, clampf((m.y - r.position.y) / r.size.y, 0.0, 1.0) * _world.size.y)


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	var illus: bool = GameTheme.illustrated()
	draw_rect(full, Color(0.10, 0.075, 0.05, 0.88) if illus else Color(GameTheme.PANEL, 0.9))
	draw_rect(full, Color("7a5f30") if illus else GameTheme.LINE, false, 2.0)
	draw_string(GameTheme.bold_font(), Vector2(PAD + 2.0, 15.0), "Carte du monde", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameTheme.GOLD)
	if collapsed or _world == null or _tex == null:
		return
	var r: Rect2 = map_rect()
	draw_texture_rect(_tex, r, false)
	draw_rect(r, Color(0, 0, 0, 0.7), false, 1.0)
	for s in _world.settlements:
		var m: Vector2 = to_mini(_world.settlement_pos(s))
		var col: Color = MapPlaces.faction_color(str(s.get("owner", ""))).lightened(0.25)
		var big: bool = s["kind"] == "city"
		var rad: float = 3.4 if bool(s.get("capital", false)) else (2.6 if big else 1.8)
		draw_circle(m, rad + 1.0, Color(0.07, 0.05, 0.04, 0.9))
		draw_circle(m, rad, col)
	for st in _world.sites:
		var m2: Vector2 = to_mini(_world.settlement_pos(st))
		var hostile: bool = str(st["state"]) == "hostile"
		draw_rect(Rect2(m2 - Vector2(1.6, 1.6), Vector2(3.2, 3.2)), Color("a33a2c") if hostile else Color("8a8f86"))
	# rectangle de la vue
	var a: Vector2 = to_mini(_view_rect.position)
	var b: Vector2 = to_mini(_view_rect.end)
	var vr := Rect2(a, b - a).intersection(r)
	if vr.size.x > 0.0 and vr.size.y > 0.0:
		draw_rect(vr, Color(1, 1, 1, 0.12))
		draw_rect(vr, Color(1, 1, 1, 0.95), false, 1.4)
	# compagnie
	var pm: Vector2 = to_mini(_player)
	draw_circle(pm, 5.0, Color(0.07, 0.05, 0.04, 0.95))
	draw_circle(pm, 3.6, GameTheme.GOLD)


func _gui_input(event: InputEvent) -> void:
	if collapsed or _world == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed and map_rect().has_point(event.position)
		if _dragging:
			navigate.emit(to_world(event.position))
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		navigate.emit(to_world(event.position))
		accept_event()
