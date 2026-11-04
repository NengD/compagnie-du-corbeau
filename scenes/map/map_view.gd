class_name MapView
extends Control
## Carte du monde : terrain peint, rivières, routes, villes et villages, territoires, contrat, bandes, compagnie, chemin.
## Cycle jour/nuit, météo, cadre de parchemin : voir MapFx. Dessin du terrain : MapTerrain ; des lieux : MapPlaces.
## Ne calcule aucune règle : lit `Game.world`, émet des demandes de déplacement.

signal travel_requested(target: Vector2, info: Dictionary)
signal stop_requested

const ZOOM_MIN := 1.0
const ZOOM_MAX := 3.0
const DRAG_THRESHOLD := 6.0  ## pixels : en deçà, un clic droit reste un « s'arrêter »
const VISION := 240.0  ## rayon de vue par défaut (Game.vision_radius() s'il existe)
const OL := Color("17110c")
const PARTY_COLORS: Dictionary = {"b": Color("a33a2c"), "g": Color("7a5e9a"), "o": Color("4f7a2c"), "u": Color("8a8f86")}
const WATER_SHADER := """
shader_type canvas_item;
uniform float t = 0.0;
void fragment() {
	float m = texture(TEXTURE, UV).a;
	vec2 p = UV * vec2(80.0, 50.0) * 3.2;
	float a = sin(p.x * 2.3 + t * 1.2 + sin(p.y * 1.7 + t * 0.6) * 1.6);
	float b = sin(p.y * 2.9 - t * 0.8 + sin(p.x * 1.3 - t * 0.9) * 1.5);
	float h = smoothstep(0.72, 0.95, a * b);
	float g = smoothstep(0.55, 0.9, sin(p.x * 0.9 + p.y * 1.4 + t * 0.5)) * 0.08;
	COLOR = vec4(0.88, 0.95, 0.98, (h * 0.38 + g) * m);
}
"""

class Layer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


class Overlay extends Control:
	var painter: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)

var _stage: Node2D
var _root: Node2D  ## fond et décor : teinté par la lumière du jour
var _ground: Layer
var _shimmer: Sprite2D
var _terr: Layer
var _objects: Layer
var _lights_layer: Layer
var _labels: Layer
var _dyn: Layer
var _sky: Overlay
var _wx: Overlay
var _frame: Overlay
var _fx: MapFx = MapFx.new()
var _curves: Array = []
var _lights: Array = []
var _terr_data: Dictionary = {}
var _terr_sig: String = ""
var _lights_drawn: bool = false
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
var show_territories: bool = true
static var _keep_zoom: float = 1.0  ## vue mémorisée d'un affichage de la carte au suivant (zoom, centre en coordonnées monde)
static var _keep_center: Vector2 = Vector2(-1.0, -1.0)
static var _last_report_key: String = ""
static var _keep_territories: bool = true


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	show_territories = _keep_territories
	_stage = Node2D.new()
	add_child(_stage)
	_root = Node2D.new()
	_stage.add_child(_root)
	_ground = _layer(_paint_ground, _root)
	_shimmer = Sprite2D.new()
	_shimmer.centered = false
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WATER_SHADER
	mat.shader = sh
	_shimmer.material = mat
	_root.add_child(_shimmer)
	_terr = _layer(_paint_territories, _root)
	_objects = _layer(_paint_objects, _root)
	_lights_layer = _layer(_paint_lights, _stage)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights_layer.material = add
	_labels = _layer(_paint_labels, _stage)
	_dyn = _layer(_paint_dynamic, _stage)
	_sky = _overlay(_paint_sky)
	_wx = _overlay(_paint_wx)
	_frame = _overlay(_paint_frame)
	resized.connect(_fit)
	mouse_exited.connect(func() -> void:
		_hover_ok = false
		_hover_cell = Vector2i(-1, -1))
	rebuild()


func _layer(painter: Callable, parent: Node) -> Layer:
	var l := Layer.new()
	l.painter = painter
	parent.add_child(l)
	return l


func _overlay(painter: Callable) -> Overlay:
	var o := Overlay.new()
	o.painter = painter
	add_child(o)
	return o


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1b140d"))


func _vision() -> float:
	var base: float = VISION
	if Game.has_method("vision_radius"):
		base = float(Game.call("vision_radius"))
	return base * (_fx.vision_scale() if Settings.day_night else 1.0)


func _process(delta: float) -> void:
	_t += delta
	var w: World = Game.world
	if w == null:
		return
	_fx.update(delta, Game.day, Game.day_fraction, Settings.day_night, Settings.weather_fx, Settings.map_anim)
	var tint: Color = _fx.world_tint()
	_root.modulate = tint
	_dyn.modulate = tint.lerp(Color.WHITE, 0.45)
	var mat := _shimmer.material as ShaderMaterial
	if Settings.map_anim:
		mat.set_shader_parameter("t", _fx.t)
	if _fx.night > 0.02 or _lights_drawn:
		_lights_layer.queue_redraw()
		_lights_drawn = _fx.night > 0.02
	_sky.queue_redraw()
	_wx.queue_redraw()
	_frame.queue_redraw()
	_dyn.queue_redraw()
	var sig: String = _owners_signature(w)
	if sig != _terr_sig:
		_terr_sig = sig
		_terr_data = MapPlaces.territories(w)
		_terr.queue_redraw()
		_labels.queue_redraw()


func _owners_signature(w: World) -> String:
	var parts: PackedStringArray = []
	for s in w.settlements:
		parts.append("%s%d" % [str(s.get("owner", "")), Visits.day_of(s)])
	return ",".join(parts)


func set_show_territories(on: bool) -> void:
	show_territories = on
	_keep_territories = on
	_terr.queue_redraw()
	_labels.queue_redraw()


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
	var tx: Array = MapTerrain.textures(w)
	_shimmer.texture = tx[1]
	_shimmer.scale = World.SIZE / Vector2((tx[1] as Texture2D).get_size())
	_curves = MapTerrain.road_curves(w)
	_terr_sig = ""
	_lights.clear()
	_ground.set_meta("tex", tx[0])
	for l in [_ground, _objects, _labels]:
		l.queue_redraw()
	_fit()


# --- Couches statiques ---

func _paint_ground(l: Node2D) -> void:
	var w: World = Game.world
	var tex: Texture2D = l.get_meta("tex", null)
	if w == null or tex == null:
		return
	l.draw_texture_rect(tex, Rect2(Vector2.ZERO, World.SIZE), false)
	MapTerrain.paint_ground_decor(l, w)
	MapTerrain.paint_roads(l, w, _curves)


func _paint_territories(l: Node2D) -> void:
	if not show_territories or _terr_data.is_empty():
		return
	MapPlaces.paint_territories(l, _terr_data)


func _paint_objects(l: Node2D) -> void:
	var w: World = Game.world
	if w == null:
		return
	MapTerrain.paint_objects(l, w, _curves)
	_lights.clear()
	for s in w.settlements:
		MapPlaces.paint_settlement(l, s, w.settlement_pos(s), _lights)


func _paint_lights(l: Node2D) -> void:
	_fx.paint_lights(l, _lights)


func _paint_labels(l: Node2D) -> void:
	var w: World = Game.world
	if w == null:
		return
	if show_territories and not _terr_data.is_empty():
		MapPlaces.paint_territory_names(l, _terr_data, w, GameTheme.title_font())
	var font: Font = GameTheme.title_font()
	for s in w.settlements:
		MapPlaces.paint_label(l, s, w.settlement_pos(s), font)


# --- Surcouches en repère écran ---

func _paint_sky(c: Control) -> void:
	_fx.paint_sky(c)


func _paint_wx(c: Control) -> void:
	_fx.paint_weather(c)


func _paint_frame(c: Control) -> void:
	_fx.paint_frame(c, World.DAY_PX, _stage.scale.x, Game.day_fraction, Settings.day_night)


# --- Éléments mobiles ---

func _paint_dynamic(l: Node2D) -> void:
	var w: World = Game.world
	if w == null:
		return
	var animate: bool = Settings.map_anim
	var font: Font = GameTheme.bold_font()
	# bannières de faction et ailes des moulins
	for s in w.settlements:
		var p: Vector2 = w.settlement_pos(s)
		var owner: String = str(s.get("owner", ""))
		var city: bool = s["kind"] == "city"
		if owner != "":
			var bn: Dictionary = MapPlaces.faction_banner(owner)
			if bn.is_empty():
				bn = {"primary": MapPlaces.faction_color(owner).to_html(false), "secondary": "d8cfb8", "emblem": 0}
			MapPlaces.paint_banner(l, p + (Vector2(0, -37) if city else Vector2(-15, -7)), bn, _fx.t, animate, 1.0 if city else 0.75)
		var hub: Vector2 = MapPlaces.windmill_hub(s, p)
		if hub != Vector2.ZERO:
			MapPlaces.paint_blades(l, hub, _fx.t * 0.9 if animate else 0.4)
	# Contrat : drapeau sur le lieu à atteindre
	if not Game.active_contract.is_empty():
		var tp: Vector2 = Game.contract_target()
		var pulse: float = 0.5 + 0.5 * sin(_t * 3.0) if animate else 0.5
		l.draw_arc(tp, 16.0 + pulse * 5.0, 0.0, TAU, 28, Color(0.8, 0.25, 0.2, 0.7 - pulse * 0.4), 2.0, true)
		l.draw_line(tp, tp + Vector2(0, -26), OL, 3.0)
		l.draw_line(tp, tp + Vector2(0, -26), Color("c9c2b2"), 1.5)
		var flag := PackedVector2Array([tp + Vector2(0, -26), tp + Vector2(14, -21), tp + Vector2(0, -16)])
		l.draw_colored_polygon(flag, Color("b03a2e"))
		l.draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), OL, 1.0)
		l.draw_string_outline(font, tp + Vector2(-80, 14), str(Game.active_contract["target_name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, 4, Color("120f0c"))
		l.draw_string(font, tp + Vector2(-80, 14), str(Game.active_contract["target_name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color("f0a090"))
	for site in w.sites:
		var col: Color = PARTY_COLORS.get(str(site["faction"]), Color("a33a2c"))
		MapPlaces.paint_site(l, site, w.settlement_pos(site), col, GameTheme.title_font(), _t, animate)
	if _t < _focus_until:
		var a: float = clampf(_focus_until - _t, 0.0, 1.0)
		var r: float = 26.0 + (1.0 - a) * 10.0
		l.draw_arc(_focus_pos, r, 0.0, TAU, 32, Color(GameTheme.GOLD, 0.9 * a), 3.0, true)
	# Bandes repérées (plus discrètes en bordure de la vue, donc surtout la nuit)
	var vis: float = _vision()
	for p in w.parties:
		var pp: Vector2 = w.party_pos(p)
		var d: float = pp.distance_to(w.player_pos)
		var hovered: bool = _hover_ok and pp.distance_to(_hover) < 24.0
		if d > vis and not hovered:
			continue
		var alpha: float = 1.0 if hovered else clampf((vis - d) / 45.0, 0.25, 1.0)
		var col2: Color = PARTY_COLORS.get(str(p["faction"]), Color("7a5e9a"))
		var label: String = "%s %s" % [w.party_title(p), "◆".repeat(int(p["d"]))]
		MapPlaces.paint_party(l, pp, col2, label, font, _t, animate, alpha, int(p["id"]))
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
	var bn2: Dictionary = {"primary": Banner.primary(Game.banner).to_html(false), "secondary": Banner.secondary(Game.banner).to_html(false), "emblem": int(Game.banner.get("emblem", 0))}
	MapPlaces.paint_company(l, w.player_pos, bn2, _t, animate, not w.path.is_empty(), vis)


# --- Entrées ---

func _world_pos(local: Vector2) -> Vector2:
	return (local - _stage.position) / _stage.scale.x


## Ce qui se trouve sous le point `p` : {"kind": ...} ou {} si rien.
func _thing_at(p: Vector2) -> Dictionary:
	var w: World = Game.world
	var party: Dictionary = w.party_near(p, 22.0)
	if not party.is_empty() and w.party_pos(party).distance_to(w.player_pos) <= _vision():
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
		if thing.is_empty():
			tooltip_text = w.terrain_label(p)
		elif thing.get("kind", "") == "settlement":
			var ss: Dictionary = w.settlement_by_id(str(thing["id"]))
			tooltip_text = Visits.tooltip(ss, w.standing_of(ss))
			var fn: String = MapPlaces.faction_name(str(ss.get("owner", "")))
			if fn != "":
				tooltip_text += "\nPropriétaire : " + fn
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
