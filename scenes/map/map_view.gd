class_name MapView
extends Control
## Carte du monde : terrain peint, routes, villes et villages, contrat, bandes, compagnie, chemin.
## Ne calcule aucune règle : lit `Game.world`, émet des demandes de déplacement.

signal travel_requested(target: Vector2, info: Dictionary)
signal stop_requested

const ZOOM_MIN := 1.0
const ZOOM_MAX := 3.0
const DRAG_THRESHOLD := 6.0  ## pixels : en deçà, un clic droit reste un « s'arrêter »
const VISION := 240.0  ## rayon dans lequel on repère les bandes errantes
const TEX_SCALE := 5  ## pixels de texture par case
const OL := Color("17110c")
const PARTY_COLORS: Dictionary = {"b": Color("a33a2c"), "g": Color("7a5e9a"), "o": Color("4f7a2c"), "u": Color("8a8f86")}
const TERRAIN_COLORS: Array[Color] = [Color("707f45"), Color("46572f"), Color("8b8553"), Color("3f5f73"), Color("7d7466")]

class Layer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)

var _stage: Node2D
var _terrain: Layer
var _dyn: Layer
var _tex: ImageTexture
var _roads: Array[PackedVector2Array] = []
var _hover: Vector2 = Vector2.ZERO
var _hover_ok: bool = false
var _hover_path: Array[Vector2] = []
var _hover_days: float = 0.0
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _t: float = 0.0
var zoom: float = 1.0  ## ×1 à ×3 (molette)
var _base_k: float = 0.0  ## échelle qui fait tenir toute la carte dans la vue
var _drag_btn: int = 0  ## bouton qui fait glisser la carte (milieu ou droit), 0 = aucun
var _drag_moved: float = 0.0
var _focus_pos: Vector2 = Vector2.ZERO  ## lieu mis en évidence par Tab (anneau qui s'estompe)
var _focus_until: float = -1.0
static var _keep_zoom: float = 1.0  ## vue mémorisée d'un affichage de la carte au suivant (zoom, centre en coordonnées monde)
static var _keep_center: Vector2 = Vector2(-1.0, -1.0)
static var _last_report_key: String = ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = Node2D.new()
	add_child(_stage)
	_terrain = Layer.new()
	_terrain.painter = _paint_terrain
	_stage.add_child(_terrain)
	_dyn = Layer.new()
	_dyn.painter = _paint_dynamic
	_stage.add_child(_dyn)
	resized.connect(_fit)
	mouse_exited.connect(func() -> void:
		_hover_ok = false
		_hover_cell = Vector2i(-1, -1))
	rebuild()


func _process(delta: float) -> void:
	_t += delta
	_dyn.queue_redraw()


func _fit() -> void:
	var k: float = minf(size.x / World.SIZE.x, size.y / World.SIZE.y)
	if k <= 0.0:
		return
	var anchor: Vector2 = _world_pos(size * 0.5) if _base_k > 0.0 else _initial_anchor()
	_base_k = k
	_stage.scale = Vector2.ONE * k * zoom
	_stage.position = size * 0.5 - anchor * _stage.scale.x
	_clamp_view()


## Première mise en page : reprend le zoom et le centre de la dernière vue ; après une bataille (nouveau compte rendu),
## recentre sur la compagnie.
func _initial_anchor() -> Vector2:
	zoom = clampf(_keep_zoom, ZOOM_MIN, ZOOM_MAX)
	var report: Dictionary = Game.last_battle_report
	var key: String = "%s|%s|%s" % [report.get("day", ""), report.get("title", ""), report.get("result", "")] if not report.is_empty() else ""
	if key != "" and key != _last_report_key:
		_last_report_key = key
		return Game.world.player_pos if Game.world != null else World.SIZE * 0.5
	if _keep_center.x >= 0.0:
		return _keep_center
	return World.SIZE * 0.5


func _remember_view() -> void:
	_keep_zoom = zoom
	_keep_center = _world_pos(size * 0.5)


## Garde la carte dans la fenêtre : centrée si elle est plus petite, sans bord vide sinon.
func _clamp_view() -> void:
	var ws: Vector2 = World.SIZE * _stage.scale.x
	var p: Vector2 = _stage.position
	p.x = (size.x - ws.x) * 0.5 if ws.x <= size.x else clampf(p.x, size.x - ws.x, 0.0)
	p.y = (size.y - ws.y) * 0.5 if ws.y <= size.y else clampf(p.y, size.y - ws.y, 0.0)
	_stage.position = p


## Zoom (×1 à ×3) centré sur le point `at` de la vue.
func zoom_at(at: Vector2, factor: float) -> void:
	var nz: float = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(nz, zoom):
		return
	var wp: Vector2 = _world_pos(at)
	zoom = nz
	_stage.scale = Vector2.ONE * _base_k * zoom
	_stage.position = at - wp * _stage.scale.x
	_clamp_view()
	_remember_view()


## Centre la vue sur le point `p` du monde (sans changer le zoom) et l'entoure d'un anneau un instant.
func center_on(p: Vector2, mark: bool = false) -> void:
	_stage.position = size * 0.5 - p * _stage.scale.x
	_clamp_view()
	_remember_view()
	if mark:
		_focus_pos = p
		_focus_until = _t + 2.0


## Recentre la vue sur la compagnie (sans changer le zoom).
func center_on_player() -> void:
	if Game.world == null:
		return
	_stage.position = size * 0.5 - Game.world.player_pos * _stage.scale.x
	_clamp_view()
	_remember_view()


## Reconstruit le fond (à appeler quand le monde change : nouvelle partie, chargement).
func rebuild() -> void:
	var w: World = Game.world
	if w == null:
		return
	_tex = _build_texture(w)
	_roads = _build_roads(w)
	_terrain.queue_redraw()
	_fit()


func _build_texture(w: World) -> ImageTexture:
	var iw: int = World.GW * TEX_SCALE
	var ih: int = World.GH * TEX_SCALE
	var img := Image.create(iw, ih, false, Image.FORMAT_RGB8)
	var n1 := FastNoiseLite.new()
	n1.seed = 7
	n1.frequency = 0.05
	var n2 := FastNoiseLite.new()
	n2.seed = 11
	n2.frequency = 0.35
	for y in ih:
		for x in iw:
			var fx: float = (x + 0.5) / TEX_SCALE - 0.5
			var fy: float = (y + 0.5) / TEX_SCALE - 0.5
			var x0: int = clampi(int(floorf(fx)), 0, World.GW - 1)
			var y0: int = clampi(int(floorf(fy)), 0, World.GH - 1)
			var x1: int = mini(x0 + 1, World.GW - 1)
			var y1: int = mini(y0 + 1, World.GH - 1)
			var tx: float = clampf(fx - x0, 0.0, 1.0)
			var ty: float = clampf(fy - y0, 0.0, 1.0)
			var c00: Color = TERRAIN_COLORS[w.terrain[y0 * World.GW + x0]]
			var c10: Color = TERRAIN_COLORS[w.terrain[y0 * World.GW + x1]]
			var c01: Color = TERRAIN_COLORS[w.terrain[y1 * World.GW + x0]]
			var c11: Color = TERRAIN_COLORS[w.terrain[y1 * World.GW + x1]]
			var c: Color = c00.lerp(c10, tx).lerp(c01.lerp(c11, tx), ty)
			var shade: float = n1.get_noise_2d(x, y) * 0.09 + n2.get_noise_2d(x, y) * 0.04
			img.set_pixel(x, y, Color(c.r + shade, c.g + shade, c.b + shade * 0.8))
	return ImageTexture.create_from_image(img)


## Routes décoratives : chaque lieu est relié à son plus proche voisin.
func _build_roads(w: World) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var done: Dictionary = {}
	for i in w.settlements.size():
		var a: Vector2 = w.settlement_pos(w.settlements[i])
		var order: Array = range(w.settlements.size())
		order.erase(i)
		order.sort_custom(func(p: int, q: int) -> bool: return a.distance_to(w.settlement_pos(w.settlements[p])) < a.distance_to(w.settlement_pos(w.settlements[q])))
		for j in order.slice(0, 2):
			var key: String = "%d-%d" % [mini(i, j), maxi(i, j)]
			if done.has(key):
				continue
			done[key] = true
			var p: Array[Vector2] = w.find_path(a, w.settlement_pos(w.settlements[j]))
			if p.size() >= 2:
				out.append(PackedVector2Array(p))
	return out


# --- Terrain (dessiné une fois) ---

func _paint_terrain(l: Node2D) -> void:
	var w: World = Game.world
	if w == null or _tex == null:
		return
	l.draw_texture_rect(_tex, Rect2(Vector2.ZERO, World.SIZE), false)
	for y in World.GH:
		for x in World.GW:
			var t: int = w.terrain[y * World.GW + x]
			if t == World.T.PLAIN:
				continue
			var r := RandomNumberGenerator.new()
			r.seed = x * 7919 + y * 104729 + 3
			var o := Vector2(x * World.CELL, y * World.CELL)
			match t:
				World.T.FOREST:
					for k in 2:
						var p: Vector2 = o + Vector2(r.randf_range(4, 16), r.randf_range(7, 17))
						var rad: float = r.randf_range(4.5, 6.5)
						l.draw_circle(p + Vector2(1, 1.5), rad + 1.0, OL)
						l.draw_circle(p, rad, Color("2f4224"))
						l.draw_circle(p + Vector2(-1.5, -1.5), rad * 0.55, Color("4a6232"))
				World.T.HILLS:
					var p2: Vector2 = o + Vector2(r.randf_range(5, 15), r.randf_range(10, 17))
					l.draw_arc(p2, 7.0, PI, TAU, 10, Color("5c5834"), 2.0, true)
					l.draw_arc(p2 + Vector2(-4, -1), 4.0, PI, TAU, 8, Color("a09a63"), 1.4, true)
				World.T.MOUNTAIN:
					if r.randf() < 0.75:
						var b: Vector2 = o + Vector2(r.randf_range(8, 14), 18)
						var h: float = r.randf_range(15.0, 22.0)
						var hw: float = h * 0.62
						var tri := PackedVector2Array([b + Vector2(-hw, 0), b + Vector2(0, -h), b + Vector2(hw, 0)])
						l.draw_colored_polygon(tri, Color("8a8070"))
						l.draw_colored_polygon(PackedVector2Array([b + Vector2(0, -h), b + Vector2(hw, 0), b + Vector2(hw * 0.2, 0)]), Color("5f574b"))
						l.draw_colored_polygon(PackedVector2Array([b + Vector2(-hw * 0.28, -h * 0.72), b + Vector2(0, -h), b + Vector2(hw * 0.28, -h * 0.72), b + Vector2(0, -h * 0.62)]), Color("e8e4da"))
						l.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), OL, 1.2)
				World.T.WATER:
					if r.randf() < 0.14:
						var p3: Vector2 = o + Vector2(r.randf_range(4, 16), r.randf_range(4, 16))
						l.draw_arc(p3, 4.0, PI * 1.15, PI * 1.85, 6, Color("6f93a8"), 1.2, true)
	for road in _roads:
		l.draw_polyline(road, Color(0.30, 0.22, 0.14, 0.55), 5.0, true)
		l.draw_polyline(road, Color(0.66, 0.55, 0.38, 0.75), 2.4, true)
	for s in w.settlements:
		_paint_settlement(l, s)


func _ellipse(l: Node2D, c: Vector2, rx: float, ry: float, col: Color) -> void:
	l.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	l.draw_circle(Vector2.ZERO, rx, col)
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_settlement(l: Node2D, s: Dictionary) -> void:
	var p: Vector2 = Game.world.settlement_pos(s)
	_ellipse(l, p + Vector2(0, 11), 30 if s["kind"] == "city" else 20, 8, Color(0, 0, 0, 0.3))
	if s["kind"] == "city":
		l.draw_rect(Rect2(p + Vector2(-21, -4), Vector2(42, 16)), Color("8f8470"))
		l.draw_rect(Rect2(p + Vector2(-21, -4), Vector2(42, 16)), OL, false, 1.4)
		for dx in [-23.0, -5.0, 15.0]:
			var tall: float = 24.0 if dx == -5.0 else 19.0
			l.draw_rect(Rect2(p + Vector2(dx, 12 - tall), Vector2(9, tall)), Color("a89d86"))
			l.draw_rect(Rect2(p + Vector2(dx, 12 - tall), Vector2(9, tall)), OL, false, 1.2)
			var roof := PackedVector2Array([p + Vector2(dx - 2, 12 - tall), p + Vector2(dx + 4.5, 12 - tall - 9), p + Vector2(dx + 11, 12 - tall)])
			l.draw_colored_polygon(roof, Color("8a3a2e"))
			l.draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[0]]), OL, 1.1)
		l.draw_rect(Rect2(p + Vector2(-4, 4), Vector2(8, 8)), Color("2a2118"))
	else:
		for off in [Vector2(-14, 2), Vector2(2, -2), Vector2(14, 5)]:
			var b: Vector2 = p + off
			l.draw_rect(Rect2(b + Vector2(-6, -3), Vector2(12, 9)), Color("b08e60"))
			l.draw_rect(Rect2(b + Vector2(-6, -3), Vector2(12, 9)), OL, false, 1.1)
			var roof := PackedVector2Array([b + Vector2(-8, -3), b + Vector2(0, -11), b + Vector2(8, -3)])
			l.draw_colored_polygon(roof, Color("7a4a32"))
			l.draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[0]]), OL, 1.1)
	var font: Font = GameTheme.title_font()
	var size: int = 28 if s["kind"] == "city" else 22
	l.draw_string_outline(font, p + Vector2(-90, 32), str(s["name"]), HORIZONTAL_ALIGNMENT_CENTER, 180, size, 5, Color("120f0c"))
	l.draw_string(font, p + Vector2(-90, 32), str(s["name"]), HORIZONTAL_ALIGNMENT_CENTER, 180, size, GameTheme.INK)
	if Visits.day_of(s) > 0:  # marque discrète : déjà visité
		var vp: Vector2 = p + Vector2(26 if s["kind"] == "city" else 20, -12)
		l.draw_circle(vp, 6.5, OL)
		l.draw_circle(vp, 5.2, Color("8aa05a"))
		l.draw_polyline(PackedVector2Array([vp + Vector2(-2.6, 0.2), vp + Vector2(-0.6, 2.4), vp + Vector2(2.8, -2.2)]), OL, 1.6, true)


# --- Lieux hostiles (forts, repaires, nécropoles, citadelle) ---

func _paint_site(l: Node2D, s: Dictionary, font: Font) -> void:
	var p: Vector2 = Game.world.settlement_pos(s)
	var state: String = str(s["state"])
	var col: Color = PARTY_COLORS.get(str(s["faction"]), Color("a33a2c"))
	var big: bool = s["kind"] == "citadel"
	var k: float = 1.45 if big else 1.0
	var fade: float = 1.0 if state == "hostile" else 0.55
	_ellipse(l, p + Vector2(0, 10 * k), 18 * k, 5 * k, Color(0, 0, 0, 0.35))
	if state == "hostile":
		var pulse: float = 0.5 + 0.5 * sin(_t * (4.0 if big else 2.5))
		l.draw_arc(p, (20.0 + pulse * 4.0) * k, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.5 - pulse * 0.3), 2.0, true)
	var wall: Color = Color("6b5a44") if s["kind"] != "necropolis" else Color("7d8079")
	if s["kind"] == "lair":
		wall = Color("5a4a2a")
	wall = Color(wall.r, wall.g, wall.b, fade)
	# tour crénelée
	var base := Rect2(p + Vector2(-9, -9) * k, Vector2(18, 20) * k)
	l.draw_rect(base, wall)
	l.draw_rect(base, OL, false, 1.4)
	for i in 3:
		var cx: float = (-9.0 + i * 7.0) * k
		var cren := Rect2(p + Vector2(cx, -14 * k), Vector2(4 * k, 5 * k))
		l.draw_rect(cren, wall)
		l.draw_rect(cren, OL, false, 1.0)
	l.draw_rect(Rect2(p + Vector2(-3, 3) * k, Vector2(6, 8) * k), Color("1c1610"))
	# palissade des repaires, croix des nécropoles
	if s["kind"] == "lair":
		for i in 5:
			var sx: float = (-15.0 + i * 7.5) * k
			l.draw_line(p + Vector2(sx, 11 * k), p + Vector2(sx, 3 * k), OL, 2.2)
	elif s["kind"] == "necropolis":
		l.draw_line(p + Vector2(0, -26), p + Vector2(0, -16), OL, 3.0)
		l.draw_line(p + Vector2(-4, -22), p + Vector2(4, -22), OL, 3.0)
	# oriflamme : faction (hostile), bleu acier (poste libéré), gris (libéré)
	var flag_col: Color = col if state == "hostile" else (Color("4a7a9a") if state == "friendly" else Color("8a8f86"))
	var top: Vector2 = p + Vector2(0, -14 * k)
	l.draw_line(top, top + Vector2(0, -14 * k), OL, 3.0)
	var fl := PackedVector2Array([top + Vector2(0, -14 * k), top + Vector2(12 * k, -10 * k), top + Vector2(0, -6 * k)])
	l.draw_colored_polygon(fl, flag_col)
	l.draw_polyline(PackedVector2Array([fl[0], fl[1], fl[2], fl[0]]), OL, 1.0)
	var label: String = str(s["name"]) + (" ◆◆◆" if state == "hostile" else (" ✓" if state == "friendly" else ""))
	var lc: Color = col.lerp(Color.WHITE, 0.55) if state == "hostile" else Color(GameTheme.INK, 0.8)
	l.draw_string_outline(font, p + Vector2(-90, 28 * k), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 17, 5, Color("120f0c"))
	l.draw_string(font, p + Vector2(-90, 28 * k), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 17, lc)


# --- Éléments mobiles ---

func _paint_dynamic(l: Node2D) -> void:
	var w: World = Game.world
	if w == null:
		return
	var font: Font = GameTheme.bold_font()
	# Contrat : drapeau sur le lieu à atteindre
	if not Game.active_contract.is_empty():
		var tp: Vector2 = Game.contract_target()
		var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
		l.draw_arc(tp, 16.0 + pulse * 5.0, 0.0, TAU, 28, Color(0.8, 0.25, 0.2, 0.7 - pulse * 0.4), 2.0, true)
		l.draw_line(tp, tp + Vector2(0, -26), OL, 3.0)
		l.draw_line(tp, tp + Vector2(0, -26), Color("c9c2b2"), 1.5)
		var flag := PackedVector2Array([tp + Vector2(0, -26), tp + Vector2(14, -21), tp + Vector2(0, -16)])
		l.draw_colored_polygon(flag, Color("b03a2e"))
		l.draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), OL, 1.0)
		l.draw_string_outline(font, tp + Vector2(-80, 14), str(Game.active_contract["target_name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, 4, Color("120f0c"))
		l.draw_string(font, tp + Vector2(-80, 14), str(Game.active_contract["target_name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color("f0a090"))
	for site in w.sites:
		_paint_site(l, site, font)
	if _t < _focus_until:
		var a: float = clampf(_focus_until - _t, 0.0, 1.0)
		var r: float = 26.0 + (1.0 - a) * 10.0
		l.draw_arc(_focus_pos, r, 0.0, TAU, 32, Color(GameTheme.GOLD, 0.9 * a), 3.0, true)
	# Bandes repérées
	for p in w.parties:
		var pp: Vector2 = w.party_pos(p)
		if pp.distance_to(w.player_pos) > VISION and not (_hover_ok and pp.distance_to(_hover) < 24.0):
			continue
		var col: Color = PARTY_COLORS.get(str(p["faction"]), Color("7a5e9a"))
		_ellipse(l, pp + Vector2(0, 5), 10, 3.5, Color(0, 0, 0, 0.35))
		l.draw_line(pp + Vector2(0, 4), pp + Vector2(0, -20), OL, 3.0)
		l.draw_line(pp + Vector2(0, 4), pp + Vector2(0, -20), Color("c9c2b2"), 1.4)
		var fl := PackedVector2Array([pp + Vector2(0, -20), pp + Vector2(13, -16), pp + Vector2(0, -11)])
		l.draw_colored_polygon(fl, col)
		l.draw_polyline(PackedVector2Array([fl[0], fl[1], fl[2], fl[0]]), OL, 1.0)
		var label: String = "%s %s" % [w.party_title(p), "◆".repeat(int(p["d"]))]
		l.draw_string_outline(font, pp + Vector2(-70, 18), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, 4, Color("120f0c"))
		l.draw_string(font, pp + Vector2(-70, 18), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, col.lerp(Color.WHITE, 0.55))
	# Chemin prévu et chemin en cours
	if _hover_ok and _hover_path.size() >= 2:
		l.draw_polyline(PackedVector2Array(_hover_path), Color(1, 1, 1, 0.28), 2.0, true)
		l.draw_string_outline(font, _hover + Vector2(-40, -14), "≈ %.1f j" % _hover_days, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, 4, Color("120f0c"))
		l.draw_string(font, _hover + Vector2(-40, -14), "≈ %.1f j" % _hover_days, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, GameTheme.INK)
	if not w.path.is_empty():
		var pts := PackedVector2Array([w.player_pos])
		pts.append_array(PackedVector2Array(w.path))
		l.draw_polyline(pts, OL, 4.5, true)
		l.draw_polyline(pts, GameTheme.GOLD, 2.2, true)
		l.draw_arc(pts[pts.size() - 1], 7.0, 0.0, TAU, 16, GameTheme.GOLD, 2.4, true)
	# Compagnie
	var me: Vector2 = w.player_pos
	l.draw_arc(me, VISION, 0.0, TAU, 72, Color(1, 1, 1, 0.07), 1.5, true)
	_ellipse(l, me + Vector2(0, 11), 13, 4, Color(0, 0, 0, 0.4))
	l.draw_circle(me, 14.0, OL)
	l.draw_circle(me, 12.5, GameTheme.GOLD)
	var raven := PackedVector2Array([
		Vector2(-8, 3), Vector2(-4, -3), Vector2(1, -6), Vector2(5, -4), Vector2(10, -5), Vector2(6, -1),
		Vector2(5, 2), Vector2(8, 7), Vector2(1, 5), Vector2(-5, 7),
	])
	var moved := PackedVector2Array()
	for v in raven:
		moved.append(me + v)
	l.draw_colored_polygon(moved, Color("1c1915"))


# --- Entrées ---

func _world_pos(local: Vector2) -> Vector2:
	return (local - _stage.position) / _stage.scale.x


## Ce qui se trouve sous le point `p` : {"kind": ...} ou {} si rien.
func _thing_at(p: Vector2) -> Dictionary:
	var w: World = Game.world
	var party: Dictionary = w.party_near(p, 22.0)
	if not party.is_empty() and w.party_pos(party).distance_to(w.player_pos) <= VISION:
		return {"kind": "party", "id": int(party["id"]), "pos": w.party_pos(party), "title": w.party_title(party)}
	var s: Dictionary = w.settlement_near(p, 30.0)
	if not s.is_empty():
		return {"kind": "settlement", "id": str(s["id"]), "pos": w.settlement_pos(s), "title": str(s["name"])}
	var site: Dictionary = w.site_near(p, 28.0)
	if not site.is_empty():
		return {"kind": "site", "id": str(site["id"]), "pos": w.settlement_pos(site), "title": str(site["name"])}
	if not Game.active_contract.is_empty() and Game.contract_target().distance_to(p) < 26.0:
		return {"kind": "target", "pos": Game.contract_target(), "title": str(Game.active_contract["target_name"])}
	return {}


func _gui_input(event: InputEvent) -> void:
	var w: World = Game.world
	if w == null:
		return
	if event is InputEventMouseMotion and _drag_btn != 0:
		_drag_moved += (event as InputEventMouseMotion).relative.length()
		if _drag_btn == MOUSE_BUTTON_MIDDLE or _drag_moved > DRAG_THRESHOLD:
			_stage.position += (event as InputEventMouseMotion).relative
			_clamp_view()
			_remember_view()
		_hover_ok = false
		accept_event()
		return
	if event is InputEventMouseButton and not event.pressed and _drag_btn == event.button_index:
		var was_click: bool = _drag_btn == MOUSE_BUTTON_RIGHT and _drag_moved <= DRAG_THRESHOLD
		_drag_btn = 0
		if was_click:
			stop_requested.emit()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_at(event.position, 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		_drag_btn = event.button_index
		_drag_moved = 0.0
		return
	if event is InputEventMouseMotion:
		var p: Vector2 = _world_pos(event.position)
		var thing: Dictionary = _thing_at(p)
		var goal: Vector2 = thing["pos"] if not thing.is_empty() else p
		tooltip_text = str(thing.get("title", ""))
		if thing.get("kind", "") == "settlement":
			var ss: Dictionary = w.settlement_by_id(str(thing["id"]))
			tooltip_text = Visits.tooltip(ss, w.standing_of(ss))
		elif thing.get("kind", "") == "site":
			tooltip_text = Campaign.site_tooltip(w.site_by_id(str(thing["id"])), Game.renown)
		var cell: Vector2i = w.cell_of(goal)
		_hover = goal
		if cell != _hover_cell or not thing.is_empty():
			_hover_cell = cell
			_hover_path = w.find_path(w.player_pos, goal)
			_hover_ok = not _hover_path.is_empty()
			_hover_days = w.path_days(_hover_path) if _hover_ok else 0.0
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var p: Vector2 = _world_pos(event.position)
			var thing: Dictionary = _thing_at(p)
			if thing.is_empty():
				travel_requested.emit(p, {"kind": "point"})
			else:
				travel_requested.emit(thing["pos"], thing)
