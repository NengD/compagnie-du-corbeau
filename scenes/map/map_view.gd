class_name MapView
extends Control
## Carte du monde : terrain peint (découpé en morceaux), rivières, routes, villes et villages, territoires, frontières, noms de régions,
## points d'intérêt, contrat, bandes, compagnie, chemin. Cycle jour/nuit, météo, cadre de parchemin : voir MapFx. Dessin du terrain :
## MapTerrain ; des lieux : MapPlaces ; mini-carte : MapMini ; légende : MapLegend.
## Caméra : ZQSD / WASD (touches PHYSIQUES, donc ZQSD sur AZERTY) et flèches, Maj = plus vite, défilement aux bords de l'écran,
## molette = zoom, clic milieu = glisser, H = recentrer, suivi de la compagnie pendant les trajets (voir `MapFrame`).
## Ne calcule aucune règle : lit `Game.world`, émet des demandes de déplacement.

signal travel_requested(target: Vector2, info: Dictionary)
signal stop_requested
signal view_changed  ## la caméra a bougé (mini-carte)

const ZOOM_MIN := 1.0
const ZOOM_MAX := 3.0  ## monde classique ; le grand monde borne le zoom par une échelle (MapFrame.SCALE_MAX_GRAND)
const DRAG_THRESHOLD := 6.0  ## pixels : en deçà, un clic droit reste un « s'arrêter »
const VISION := 240.0  ## rayon de vue par défaut (Game.vision_radius() s'il existe)
const OL := Color("17110c")
const PARTY_COLORS: Dictionary = {"b": Color("a33a2c"), "g": Color("7a5e9a"), "o": Color("4f7a2c"), "u": Color("8a8f86"), "m": Color("9a6a3a")}
const WATER_SHADER := """
shader_type canvas_item;
uniform float t = 0.0;
uniform vec2 grid = vec2(80.0, 50.0);
void fragment() {
	float m = texture(TEXTURE, UV).a;
	vec2 p = UV * grid * 3.2;
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

var input_blocked: bool = false  ## vrai quand un écran modal est ouvert : la caméra ignore le clavier et les bords
var _stage: Node2D
var _root: Node2D  ## fond et décor : teinté par la lumière du jour
var _ground: Layer
var _ground_chunks: Array[Sprite2D] = []
var _obj_chunks: Array[Sprite2D] = []
var _bakes: Array[SubViewport] = []
var _shimmer: Sprite2D
var _terr: Layer
var _places: Layer
var _lights_layer: Layer
var _dyn: Layer
var _names: Overlay
var _sky: Overlay
var _wx: Overlay
var _frame: Overlay
var _fx: MapFx = MapFx.new()
var _curves: Array = []
var _lights: Array = []
var _lab: Dictionary = {}  ## grille d'étiquettes des territoires (Territory.labels)
var _terr_tex: ImageTexture
var _borders: Array = []
var _stones: Array = []
var _regions: Dictionary = {}
var _terr_sig: String = ""
var _vis_sig: String = ""
var _lights_drawn: bool = false
var _fx_was_live: bool = true
var _px_built: int = 0  ## définition de la texture de fond construite (Quality.value("map_px"))
var _hover: Vector2 = Vector2.ZERO
var _hover_ok: bool = false
var _hover_path: Array[Vector2] = []
var _hover_days: float = 0.0
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_title: String = ""
var _t: float = 0.0
var zoom: float = 1.0  ## rapport à l'échelle de base (1 = tout le monde visible dans le grand monde)
var _base_k: float = 0.0  ## échelle qui fait tenir (ou couvrir) toute la carte dans la vue
var _drag_btn: int = 0  ## bouton qui fait glisser la carte (milieu ou droit), 0 = aucun
var _drag_moved: float = 0.0
var _focus_pos: Vector2 = Vector2.ZERO  ## lieu mis en évidence par Tab (anneau qui s'estompe)
var _focus_until: float = -1.0
var _cam_vel: Vector2 = Vector2.ZERO  ## vitesse de la caméra au clavier (px d'écran par seconde), lissée
var _manual_cam: bool = false  ## la caméra a été déplacée à la main pendant un trajet : le suivi attend un recentrage
var _mouse_in: bool = false  ## la souris a bougé dans la vue (pas de défilement aux bords avant)
var _iz: float = 1.0  ## agrandissement des pictogrammes (quantifié)
var _names_sig: String = ""
var show_territories: bool = true
var show_regions: bool = true
var show_borders: bool = true
static var _keep_zoom: float = 1.0  ## vue mémorisée d'un affichage de la carte au suivant (zoom, centre en coordonnées monde)
static var _keep_center: Vector2 = Vector2(-1.0, -1.0)
static var _keep_world: int = 0
static var _last_report_key: String = ""
static var _keep_territories: bool = true


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	show_territories = Settings.map_territories and _keep_territories
	show_regions = Settings.map_regions
	show_borders = Settings.map_borders
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
	_terr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_places = _layer(_paint_places, _root)
	_lights_layer = _layer(_paint_lights, _stage)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights_layer.material = add
	_dyn = _layer(_paint_dynamic, _stage)
	_names = _overlay(_paint_names)
	_sky = _overlay(_paint_sky)
	_wx = _overlay(_paint_wx)
	_frame = _overlay(_paint_frame)
	resized.connect(_fit)
	Settings.changed.connect(_on_settings)
	mouse_entered.connect(func() -> void: _mouse_in = true)
	mouse_exited.connect(func() -> void:
		_hover_ok = false
		_hover_cell = Vector2i(-1, -1)
		_mouse_in = false)
	rebuild()


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings):
		Settings.changed.disconnect(_on_settings)


func _on_settings() -> void:
	var w: World = Game.world
	if w != null and MapTerrain.px_for(w, int(Quality.value("map_px"))) != _px_built:  # définition de la carte modifiée : fond reconstruit
		rebuild()
	_fx_was_live = true
	var changed: bool = false
	for pair in [["map_territories", "show_territories"], ["map_regions", "show_regions"], ["map_borders", "show_borders"]]:
		var on: bool = bool(Settings.get(str(pair[0])))
		if bool(get(str(pair[1]))) != on:
			set(str(pair[1]), on)
			changed = true
	if changed:
		_redraw_terrain()


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


func _world_size() -> Vector2:
	return Game.world.size if Game.world != null else World.SIZE


func _is_grand() -> bool:
	return Game.world != null and Game.world.grand


func _process(delta: float) -> void:
	_t += delta
	var w: World = Game.world
	if w == null:
		return
	var wlevel: int = int(Quality.value("weather"))
	_fx.wx_full = wlevel >= 2
	_fx.density = clampf(Quality.particle_factor(), 0.4, 1.5)  # la météo de la carte garde un minimum visible
	_fx.update(delta, Game.day, Game.day_fraction, Settings.day_night, wlevel > 0, Settings.map_anim)
	var tint: Color = _fx.world_tint()
	_root.modulate = tint
	_dyn.modulate = tint.lerp(Color.WHITE, 0.45)
	var mat := _shimmer.material as ShaderMaterial
	if Settings.map_anim:
		mat.set_shader_parameter("t", _fx.t)
	if _fx.night > 0.02 or _lights_drawn:
		_lights_layer.queue_redraw()
		_lights_drawn = _fx.night > 0.02
	var fx_live: bool = Settings.map_anim or _fx.wx_k > 0.005 or _fx.night > 0.02
	if fx_live or _fx_was_live:  # qualité Bas : plus de redessin du ciel et de la météo quand rien ne bouge
		_sky.queue_redraw()
		_wx.queue_redraw()
	_fx_was_live = fx_live
	_frame.queue_redraw()
	_camera_tick(delta, w)
	_dyn.queue_redraw()
	var sig: String = _owners_signature(w)
	if sig != _terr_sig:
		_terr_sig = sig
		_rebuild_territories(w)
	var vsig: String = _visits_signature(w)
	if vsig != _vis_sig:
		_vis_sig = vsig
		_names_sig = ""
	var iz: float = snappedf(MapFrame.icon_scale(_stage.scale.x), 0.1)
	if not is_equal_approx(iz, _iz):
		_iz = iz
		_places.queue_redraw()
		_terr.queue_redraw()
	var nsig: String = "%s|%s|%.3f|%s|%s|%d" % [str(_stage.position), "", _stage.scale.x, _hover_title, _vis_sig, int(Settings.day_night)]
	if nsig != _names_sig:
		_names_sig = nsig
		_names.queue_redraw()


func _owners_signature(w: World) -> String:
	var parts: PackedStringArray = []
	for s in w.settlements:
		parts.append(str(s.get("owner", "")))
	return ",".join(parts)


func _visits_signature(w: World) -> String:
	var parts: PackedStringArray = []
	for s in w.settlements:
		parts.append(str(Visits.day_of(s)))
	for q in w.pois:
		parts.append("1" if bool(q.get("done", false)) else "0")
	return ",".join(parts)


## Recalcule territoires, frontières et noms de régions (changement de propriétaire d'un lieu, nouveau monde).
func _rebuild_territories(w: World) -> void:
	_lab = Territory.labels(w, 1)
	_terr_tex = ImageTexture.create_from_image(MapPlaces.territory_image(w, _lab, 0.2))
	var lines: Array = Territory.borders(w, _lab)
	_borders = lines
	_stones = Territory.border_stones(lines)
	_regions = Territory.region_info(w, Territory.labels(w, 2))
	_terr.queue_redraw()
	_names_sig = ""


func _redraw_terrain() -> void:
	_terr.queue_redraw()
	_names_sig = ""


func set_show_territories(on: bool) -> void:
	show_territories = on
	_keep_territories = on
	_redraw_terrain()


func set_show_regions(on: bool) -> void:
	show_regions = on
	_names_sig = ""


func set_show_borders(on: bool) -> void:
	show_borders = on
	_redraw_terrain()


# --- Caméra ---

func _fit() -> void:
	var ws: Vector2 = _world_size()
	var k: float = MapFrame.base_scale(size, ws, not _is_grand())
	if k <= 0.0:
		return
	var first: bool = _base_k <= 0.0
	var anchor: Vector2 = _world_pos(size * 0.5) if not first else _initial_anchor(k)
	_base_k = k
	zoom = clampf(zoom, ZOOM_MIN, zoom_max())
	_stage.scale = Vector2.ONE * k * zoom
	_stage.position = MapFrame.stage_for_center(anchor, size, _stage.scale.x)
	_clamp_view()
	_after_camera()


func zoom_max() -> float:
	return MapFrame.zoom_max(_base_k, _is_grand(), ZOOM_MAX)


## Première mise en page : reprend le zoom et le centre de la dernière vue de CE monde ; après une bataille (nouveau compte rendu),
## recentre sur la compagnie ; sinon (nouvelle partie) centre sur la compagnie avec un zoom qui montre environ un tiers du monde.
func _initial_anchor(k: float) -> Vector2:
	var w: World = Game.world
	var me: Vector2 = w.player_pos if w != null else World.SIZE * 0.5
	var wid: int = w.get_instance_id() if w != null else 0
	if wid != _keep_world:  # un autre monde que celui de la dernière vue : on repart de zéro
		_keep_world = wid
		_keep_zoom = -1.0
		_keep_center = Vector2(-1.0, -1.0)
	if _keep_zoom > 0.0:
		zoom = clampf(_keep_zoom, ZOOM_MIN, MapFrame.zoom_max(k, _is_grand(), ZOOM_MAX))
	elif _is_grand():
		zoom = MapFrame.start_zoom(size, _world_size(), k, MapFrame.zoom_max(k, true, ZOOM_MAX))
	else:
		zoom = 1.0
	var report: Dictionary = Game.last_battle_report
	var key: String = "%s|%s|%s" % [report.get("day", ""), report.get("title", ""), report.get("result", "")] if not report.is_empty() else ""
	if key != "" and key != _last_report_key:
		_last_report_key = key
		return me
	if _keep_center.x >= 0.0:
		return _keep_center
	return me


func _remember_view() -> void:
	_keep_zoom = zoom
	_keep_center = _world_pos(size * 0.5)
	_keep_world = Game.world.get_instance_id() if Game.world != null else 0


## Garde la carte dans la fenêtre : centrée si elle est plus petite, sans bord vide sinon.
func _clamp_view() -> void:
	_stage.position = MapFrame.clamp_stage(_stage.position, size, _world_size(), _stage.scale.x)


func _after_camera() -> void:
	_names_sig = ""
	view_changed.emit()


## Zone du monde visible dans la vue.
func visible_world_rect() -> Rect2:
	if _stage == null:
		return Rect2()
	return Rect2(_world_pos(Vector2.ZERO), size / maxf(_stage.scale.x, 0.0001))


## Zoom centré sur le point `at` de la vue (facteur appliqué au zoom, borné).
func zoom_at(at: Vector2, factor: float) -> void:
	var nz: float = clampf(zoom * factor, ZOOM_MIN, zoom_max())
	if is_equal_approx(nz, zoom):
		return
	var wp: Vector2 = _world_pos(at)
	zoom = nz
	_stage.scale = Vector2.ONE * _base_k * zoom
	_stage.position = at - wp * _stage.scale.x
	_clamp_view()
	_remember_view()
	_after_camera()


## Centre la vue sur le point `p` du monde (sans changer le zoom) et l'entoure d'un anneau un instant.
func center_on(p: Vector2, mark: bool = false) -> void:
	_stage.position = MapFrame.stage_for_center(p, size, _stage.scale.x)
	_clamp_view()
	_remember_view()
	_after_camera()
	if mark:
		_focus_pos = p
		_focus_until = _t + 2.0


## La caméra vient d'être déplacée à la main (mini-carte) : pendant un trajet, le suivi attend un recentrage.
func mark_manual() -> void:
	if Game.world != null and not Game.world.path.is_empty():
		_manual_cam = true


## Recentre la vue sur la compagnie (sans changer le zoom) ; le suivi pendant les trajets reprend.
func center_on_player() -> void:
	if Game.world == null:
		return
	_manual_cam = false
	_stage.position = MapFrame.stage_for_center(Game.world.player_pos, size, _stage.scale.x)
	_clamp_view()
	_remember_view()
	_after_camera()


## Déplace la vue de `delta_px` pixels d'écran (positif = la vue se déplace vers la droite/le bas du monde).
func pan_px(delta_px: Vector2) -> void:
	_stage.position -= delta_px
	_clamp_view()
	_remember_view()
	_after_camera()


func _keys_ok() -> bool:
	if input_blocked or not is_visible_in_tree():
		return false
	var f: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	return not (f is LineEdit or f is TextEdit)


## Direction voulue par le clavier (touches physiques W/A/S/D = Z/Q/S/D en AZERTY, et flèches).
static func key_direction() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_META):
		return d
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		d.y += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		d.y -= 1.0
	return d


## Caméra : clavier, bords de l'écran (lissés), puis suivi de la compagnie. `delta` en secondes réelles.
func _camera_tick(delta: float, w: World) -> void:
	var want := Vector2.ZERO
	var fast: bool = false
	if _keys_ok():
		want = key_direction()
		fast = Input.is_key_pressed(KEY_SHIFT)
		if want == Vector2.ZERO and Settings.edge_scroll and _mouse_in and _drag_btn == 0 and DisplayServer.window_is_focused():
			want = MapFrame.edge_dir(get_local_mouse_position(), size)
	var target_vel: Vector2 = want.normalized() * MapFrame.pan_speed_px(size, fast)
	_cam_vel = _cam_vel.lerp(target_vel, 1.0 - exp(-14.0 * delta))
	if _cam_vel.length() > 2.0:
		if want != Vector2.ZERO and not w.path.is_empty():
			_manual_cam = true
		pan_px(_cam_vel * delta)
	elif want == Vector2.ZERO:
		_cam_vel = Vector2.ZERO
	# suivi de la compagnie pendant le trajet
	if w.path.is_empty():
		_manual_cam = false
	elif Settings.camera_follow and not _manual_cam and _drag_btn == 0 and want == Vector2.ZERO:
		var goal: Vector2 = MapFrame.stage_for_center(w.player_pos, size, _stage.scale.x)
		goal = MapFrame.clamp_stage(goal, size, _world_size(), _stage.scale.x)
		if goal.distance_to(_stage.position) > 0.5:
			_stage.position = _stage.position.lerp(goal, 1.0 - exp(-5.0 * delta))
			_remember_view()
			_after_camera()


## Reconstruit le fond (à appeler quand le monde change : nouvelle partie, chargement).
func rebuild() -> void:
	var w: World = Game.world
	if w == null:
		return
	_px_built = MapTerrain.px_for(w, int(Quality.value("map_px")))
	var tx: Array = MapTerrain.textures(w, _px_built)
	_shimmer.texture = tx[1]
	_shimmer.scale = w.size / Vector2((tx[1] as Texture2D).get_size())
	(_shimmer.material as ShaderMaterial).set_shader_parameter("grid", Vector2(w.gw, w.gh))
	_curves = MapTerrain.road_curves(w)
	_terr_sig = ""
	_vis_sig = ""
	_lights.clear()
	_ground.set_meta("tex", tx[0])
	_build_chunks(w)
	_ground.queue_redraw()
	_places.queue_redraw()
	_terr.queue_redraw()
	_base_k = 0.0  # nouvelle mise en page : zoom et centre de départ recalculés
	_fit()


## Décor et objets découpés en morceaux de CHUNK × CHUNK cases, « cuits » une seule fois dans une texture (SubViewport) : à l'écran,
## un morceau ne coûte plus qu'une image au lieu de milliers de polygones (arbres, collines, routes).
const BAKE_MARGIN := 40.0  ## débord (px) pour les arbres et les pics qui dépassent de leur case

func _build_chunks(w: World) -> void:
	for c in _ground_chunks:
		c.queue_free()
	for c in _obj_chunks:
		c.queue_free()
	for vp in _bakes:
		vp.queue_free()
	_ground_chunks.clear()
	_obj_chunks.clear()
	_bakes.clear()
	var n: int = MapTerrain.CHUNK
	var g_parent: Node = _ground.get_parent()
	for cy in range(0, w.gh, n):
		for cx in range(0, w.gw, n):
			var cells := Rect2i(cx, cy, mini(n, w.gw - cx), mini(n, w.gh - cy))
			var rect := Rect2(Vector2(cells.position) * World.CELL, Vector2(cells.size) * World.CELL)
			for kind in 2:
				var origin: Vector2 = rect.position - Vector2(BAKE_MARGIN, BAKE_MARGIN)
				var vp := SubViewport.new()
				vp.size = Vector2i((rect.size + Vector2(BAKE_MARGIN, BAKE_MARGIN) * 2.0).ceil())
				vp.transparent_bg = true
				vp.disable_3d = true
				vp.render_target_update_mode = SubViewport.UPDATE_ONCE
				var layer := Layer.new()
				layer.position = -origin
				if kind == 0:
					layer.painter = func(l: Node2D) -> void:
						if Game.world != null:
							MapTerrain.paint_ground_decor(l, Game.world, cells)
							MapTerrain.paint_roads(l, Game.world, _curves, rect)
				else:
					layer.painter = func(l: Node2D) -> void:
						if Game.world != null:
							MapTerrain.paint_objects(l, Game.world, _curves, cells)
				vp.add_child(layer)
				add_child(vp)
				_bakes.append(vp)
				var sp := Sprite2D.new()
				sp.centered = false
				sp.position = origin
				sp.texture = vp.get_texture()
				g_parent.add_child(sp)
				if kind == 0:
					_ground_chunks.append(sp)
				else:
					_obj_chunks.append(sp)
	# ordre final : sol, morceaux de sol, reflets, territoires, morceaux d'objets, lieux
	var order: Array[Node] = [_ground]
	order.append_array(_ground_chunks)
	order.append(_shimmer)
	order.append(_terr)
	order.append_array(_obj_chunks)
	order.append(_places)
	for idx in order.size():
		g_parent.move_child(order[idx], idx)
	get_tree().create_timer(2.0).timeout.connect(_free_bake_sources.bind(_bakes.duplicate()))


## Les morceaux sont cuits : on libère les listes de dessin (les textures restent).
func _free_bake_sources(list: Array) -> void:
	for vp in list:
		if is_instance_valid(vp):
			for c in (vp as SubViewport).get_children():
				c.queue_free()


# --- Couches statiques ---

func _paint_ground(l: Node2D) -> void:
	var w: World = Game.world
	var tex: Texture2D = l.get_meta("tex", null)
	if w == null or tex == null:
		return
	l.draw_texture_rect(tex, Rect2(Vector2.ZERO, w.size), false)


func _paint_territories(l: Node2D) -> void:
	var w: World = Game.world
	if w == null or _terr_tex == null:
		return
	if show_territories:
		l.draw_texture_rect(_terr_tex, Rect2(Vector2.ZERO, w.size), false)
	if show_borders:
		MapPlaces.paint_borders(l, _borders, _iz)
		MapPlaces.paint_border_stones(l, _stones, minf(_iz, 1.6))


func _paint_places(l: Node2D) -> void:
	var w: World = Game.world
	if w == null:
		return
	_lights.clear()
	for s in w.settlements:
		MapPlaces.paint_settlement(l, s, w.settlement_pos(s), _lights, _iz)


func _paint_lights(l: Node2D) -> void:
	_fx.paint_lights(l, _lights)


# --- Surcouches en repère écran ---

func _screen_of(p: Vector2) -> Vector2:
	return _stage.position + p * _stage.scale.x


func _paint_names(c: Control) -> void:
	var w: World = Game.world
	if w == null:
		return
	var k: float = _stage.scale.x
	var font: Font = GameTheme.title_font()
	var view := Rect2(Vector2(-120, -60), size + Vector2(240, 120))
	# noms de régions : lettres espacées, estompés quand on s'approche
	if show_regions and show_territories:
		var a: float = clampf((1.15 - k) / 0.45, 0.0, 1.0)
		if a > 0.01:
			var fs: int = int(roundf(lerpf(24.0, 20.0, clampf((k - 0.3) / 0.7, 0.0, 1.0)) * GameTheme.scaled_size(10) / 10.0))
			for key in _regions:
				var info: Dictionary = _regions[key]
				var sp: Vector2 = _screen_of(info["pos"])
				if not view.has_point(sp):
					continue
				_paint_spaced(c, font, Territory.region_name(str(key)).to_upper(), sp, fs, Factions.color_of(str(key)).darkened(0.45), a)
	# noms des lieux (les villages seulement à partir d'un certain zoom)
	var pfont: Font = GameTheme.title_font()
	for s in w.settlements:
		var city: bool = s["kind"] == "city"
		var hov: bool = _hover_title == str(s["name"])
		if not city and k < 0.4 and not hov:
			continue
		var sp2: Vector2 = _screen_of(w.settlement_pos(s))
		if not view.has_point(sp2):
			continue
		var kk: float = _iz * MapPlaces.settlement_k(s)
		var fs2: int = int(roundf((lerpf(17.0, 24.0, clampf((k - 0.3) / 1.2, 0.0, 1.0)) if city else lerpf(14.0, 20.0, clampf((k - 0.3) / 1.2, 0.0, 1.0))) * GameTheme.scaled_size(10) / 10.0))
		var below: float = (30.0 if city else 25.0) * kk * k + float(fs2) * 0.6
		var at: Vector2 = sp2 + Vector2(-100.0, below)
		c.draw_string_outline(pfont, at, str(s["name"]), HORIZONTAL_ALIGNMENT_CENTER, 200, fs2, 6, Color("120f0c"))
		c.draw_string(pfont, at, str(s["name"]), HORIZONTAL_ALIGNMENT_CENTER, 200, fs2, GameTheme.INK)
		if Visits.day_of(s) > 0:
			MapPlaces.paint_visited_mark(c, sp2 + Vector2(34.0 if city else 26.0, -14.0) * kk * k, 0.9)
	# points d'intérêt : étiquette discrète de près
	if k >= 0.75 or _hover_title != "":
		for q in w.pois:
			var qp: Vector2 = _screen_of(w.poi_pos(q))
			if not view.has_point(qp):
				continue
			if k < 0.75 and _hover_title != str(q["name"]):
				continue
			var txt: String = str(q["name"]) + (" ✓" if bool(q.get("done", false)) else "")
			var ca := Color(GameTheme.INK, 0.62 if bool(q.get("done", false)) else 0.85)
			c.draw_string_outline(pfont, qp + Vector2(-90.0, 24.0 * _iz * k + 10.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, 4, Color(0.07, 0.06, 0.05, 0.8))
			c.draw_string(pfont, qp + Vector2(-90.0, 24.0 * _iz * k + 10.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, ca)


## Texte aux lettres espacées, centré sur `at`, légèrement bombé comme les noms de régions d'une carte ancienne.
func _paint_spaced(c: Control, font: Font, text: String, at: Vector2, fs: int, col: Color, alpha: float) -> void:
	var gap: float = float(fs) * 0.22
	var total: float = 0.0
	for ch in text:
		total += font.get_char_size(ch.unicode_at(0), fs).x + gap
	total -= gap
	var x: float = at.x - total * 0.5
	for ch in text:
		var cw: float = font.get_char_size(ch.unicode_at(0), fs).x
		var arc_y: float = pow((x + cw * 0.5 - at.x) / maxf(total, 1.0) * 2.0, 2.0) * float(fs) * 0.35
		c.draw_char_outline(font, Vector2(x, at.y + arc_y), ch, fs, 4, Color(0.95, 0.9, 0.74, 0.55 * alpha))
		c.draw_char(font, Vector2(x, at.y + arc_y), ch, fs, Color(col.r, col.g, col.b, 0.9 * alpha))
		x += cw + gap


func _paint_sky(c: Control) -> void:
	_fx.paint_sky(c)


func _paint_wx(c: Control) -> void:
	_fx.paint_weather(c)


func _paint_frame(c: Control) -> void:
	_fx.paint_frame(c, World.DAY_PX, _stage.scale.x, Game.day_fraction, false)  # l'heure est affichée par le HUD


# --- Éléments mobiles ---

func _in_view(p: Vector2, margin: float = 90.0) -> bool:
	var r: Rect2 = visible_world_rect().grow(margin / maxf(_stage.scale.x, 0.05))
	return r.has_point(p)


func _paint_dynamic(l: Node2D) -> void:
	var w: World = Game.world
	if w == null:
		return
	var animate: bool = Settings.map_anim
	var font: Font = GameTheme.bold_font()
	var iz: float = _iz
	# bannières de faction et ailes des moulins
	for s in w.settlements:
		var p: Vector2 = w.settlement_pos(s)
		if not _in_view(p, 120.0):
			continue
		var owner: String = str(s.get("owner", ""))
		var city: bool = s["kind"] == "city"
		var kk: float = iz * MapPlaces.settlement_k(s)
		if owner != "":
			var bn: Dictionary = MapPlaces.faction_banner(owner)
			if bn.is_empty():
				bn = {"primary": MapPlaces.faction_color(owner).to_html(false), "secondary": "d8cfb8", "emblem": 0}
			MapPlaces.paint_banner(l, p + (Vector2(0, -37) if city else Vector2(-15, -7)) * kk, bn, _fx.t, animate, (1.0 if city else 0.75) * kk)
			if bool(s.get("capital", false)):  # une capitale arbore aussi les couleurs sur ses deux tours
				for sx in [-1.0, 1.0]:
					MapPlaces.paint_banner(l, p + Vector2(29.0 * sx, -26.0) * kk, bn, _fx.t + sx, animate, 0.5 * kk)
		var hub: Vector2 = MapPlaces.windmill_hub(s, p, kk)
		if hub != Vector2.ZERO:
			MapPlaces.paint_blades(l, hub, _fx.t * 0.9 if animate else 0.4, kk)
	# points d'intérêt
	for q in w.pois:
		var qp: Vector2 = w.poi_pos(q)
		if _in_view(qp):
			MapPlaces.paint_poi(l, str(q["kind"]), qp, 0.8 * iz, bool(q.get("done", false)), _t, animate)
	# Contrat : drapeau sur le lieu à atteindre
	if not Game.active_contract.is_empty():
		var tp: Vector2 = Game.contract_target()
		var pulse: float = 0.5 + 0.5 * sin(_t * 3.0) if animate else 0.5
		MapPlaces.begin_scaled(l, tp, iz)
		MapPlaces.paint_contract_flag(l, Vector2.ZERO, pulse)
		l.draw_string_outline(font, Vector2(-80, 14), str(Game.active_contract["target_name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, 4, Color("120f0c"))
		l.draw_string(font, Vector2(-80, 14), str(Game.active_contract["target_name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color("f0a090"))
		MapPlaces.end_scaled(l)
	for site in w.sites:
		var sp: Vector2 = w.settlement_pos(site)
		if not _in_view(sp, 140.0):
			continue
		var col: Color = PARTY_COLORS.get(str(site["faction"]), Color("a33a2c"))
		MapPlaces.begin_scaled(l, sp, iz)
		MapPlaces.paint_site(l, site, Vector2.ZERO, col, GameTheme.title_font(), _t, animate)
		MapPlaces.end_scaled(l)
	if _t < _focus_until:
		var a: float = clampf(_focus_until - _t, 0.0, 1.0)
		var r: float = (26.0 + (1.0 - a) * 10.0) * iz
		l.draw_arc(_focus_pos, r, 0.0, TAU, 32, Color(GameTheme.GOLD, 0.9 * a), 3.0 * iz, true)
	# Bandes repérées (plus discrètes en bordure de la vue, donc surtout la nuit)
	var vis: float = _vision()
	for p in w.parties:
		var pp: Vector2 = w.party_pos(p)
		var d: float = pp.distance_to(w.player_pos)
		var hovered: bool = _hover_ok and pp.distance_to(_hover) < 24.0
		if (d > vis and not hovered) or not _in_view(pp, 120.0):
			continue
		var alpha: float = 1.0 if hovered else clampf((vis - d) / 45.0, 0.25, 1.0)
		var col2: Color = PARTY_COLORS.get(str(p["faction"]), Color("7a5e9a"))
		var label: String = "%s %s" % [w.party_title(p), "◆".repeat(int(p["d"]))]
		MapPlaces.begin_scaled(l, pp, iz)
		MapPlaces.paint_party(l, Vector2.ZERO, col2, label, font, _t, animate, alpha, int(p["id"]))
		MapPlaces.end_scaled(l)
	# Chemin prévu et chemin en cours
	if _hover_ok and _hover_path.size() >= 2:
		l.draw_polyline(PackedVector2Array(_hover_path), Color(1, 1, 1, 0.28), 2.0 * iz, true)
		l.draw_string_outline(font, _hover + Vector2(-40, -14) * iz, "≈ %.1f j" % _hover_days, HORIZONTAL_ALIGNMENT_CENTER, 80, int(13.0 * iz), 4, Color("120f0c"))
		l.draw_string(font, _hover + Vector2(-40, -14) * iz, "≈ %.1f j" % _hover_days, HORIZONTAL_ALIGNMENT_CENTER, 80, int(13.0 * iz), GameTheme.INK)
	if not w.path.is_empty():
		var pts := PackedVector2Array([w.player_pos])
		pts.append_array(PackedVector2Array(w.path))
		l.draw_polyline(pts, OL, 4.5 * iz, true)
		l.draw_polyline(pts, GameTheme.GOLD, 2.2 * iz, true)
		l.draw_arc(pts[pts.size() - 1], 7.0 * iz, 0.0, TAU, 16, GameTheme.GOLD, 2.4 * iz, true)
	# Compagnie
	var heading: float = 0.0
	if not w.path.is_empty():
		heading = 1.0 if (w.path[0] as Vector2).x >= w.player_pos.x else -1.0
	var bn2: Dictionary = Game.banner.duplicate()
	bn2["primary"] = Banner.primary(Game.banner).to_html(false)  # ocre d'origine si aucune couleur choisie
	var near_px: float = 45.0 / maxf(_stage.scale.x, 0.05)
	var crowded: bool = false
	for s2 in w.settlements + w.sites:
		crowded = crowded or w.settlement_pos(s2).distance_to(w.player_pos) < near_px
	for p2 in w.parties:
		crowded = crowded or w.party_pos(p2).distance_to(w.player_pos) < near_px
	CompanyMarker.paint(l, w.player_pos, bn2, Game.company_name, GameTheme.title_font(), _t, animate, heading, vis, _stage.scale.x, 1.0 + (zoom - 1.0) * 0.15, crowded)


# --- Entrées ---

func _world_pos(local: Vector2) -> Vector2:
	return (local - _stage.position) / _stage.scale.x


## Ce qui se trouve sous le point `p` : {"kind": ...} ou {} si rien.
func _thing_at(p: Vector2) -> Dictionary:
	var w: World = Game.world
	var r: float = _iz
	var party: Dictionary = w.party_near(p, 22.0 * r)
	if not party.is_empty() and w.party_pos(party).distance_to(w.player_pos) <= _vision():
		return {"kind": "party", "id": int(party["id"]), "pos": w.party_pos(party), "title": w.party_title(party)}
	var s: Dictionary = w.settlement_near(p, 30.0 * r * MapPlaces.CAPITAL_K)
	if not s.is_empty():
		return {"kind": "settlement", "id": str(s["id"]), "pos": w.settlement_pos(s), "title": str(s["name"])}
	var site: Dictionary = w.site_near(p, 28.0 * r)
	if not site.is_empty():
		return {"kind": "site", "id": str(site["id"]), "pos": w.settlement_pos(site), "title": str(site["name"])}
	var poi: Dictionary = w.poi_near(p, 18.0 * r)
	if not poi.is_empty():
		return {"kind": "poi", "id": str(poi["id"]), "pos": w.poi_pos(poi), "title": str(poi["name"])}
	if not Game.active_contract.is_empty() and Game.contract_target().distance_to(p) < 26.0 * r:
		return {"kind": "target", "pos": Game.contract_target(), "title": str(Game.active_contract["target_name"])}
	return {}


## Texte d'info-bulle d'un lieu habité : propriétaire, relation, réputation, prix, contrats.
func settlement_tooltip(s: Dictionary) -> String:
	var w: World = Game.world
	var t: String = Visits.tooltip(s, w.standing_of(s))
	var owner: String = str(s.get("owner", ""))
	if owner != "" and Data.FACTIONS.has(owner):
		var st: int = Game.standing_with(owner)
		t += "\nPropriétaire : %s%s" % [Factions.name_of(owner), " (capitale)" if bool(s.get("capital", false)) else ""]
		t += "\nRelation avec la compagnie : %s (%+d)" % [Factions.label(st), st]
		var rv: Array = Factions.rivals_of(owner).map(func(r: Variant) -> String: return Factions.name_of(str(r)))
		var al: Array = Factions.allies_of(owner).map(func(r: Variant) -> String: return Factions.name_of(str(r)))
		if not rv.is_empty():
			t += "\nRivales : " + ", ".join(rv)
		if not al.is_empty():
			t += "\nAlliées : " + ", ".join(al)
	var pm: float = float(s.get("price_mult", 1.0)) * World.standing_price_mult(w.standing_of(s)) * Factions.price_mult(Game.standing_with(owner))
	t += "\nPrix : ×%.2f" % pm
	var nc: int = (s.get("contracts", []) as Array).size()
	t += "\nContrats : %s" % (str(nc) if nc > 0 else "à découvrir en ville")
	return t


func poi_tooltip(q: Dictionary) -> String:
	var desc: String = {"ruins": "Des ruines anciennes : on dit qu'elles cachent encore quelque chose.", "shrine": "Un sanctuaire oublié, où brûle parfois une bougie.",
		"camp": "Un camp abandonné : cendres froides et sacs éventrés.", "tower": "Une tour de guet. Qui veille encore là-haut ?", "cave": "Une grotte sombre, dont l'entrée sent la bête."}.get(str(q["kind"]), "")
	return "%s\n%s\n%s" % [q["name"], desc, "Déjà exploré." if bool(q.get("done", false)) else "S'y arrêter déclenche une rencontre (une seule fois)."]


func _gui_input(event: InputEvent) -> void:
	var w: World = Game.world
	if w == null:
		return
	if event is InputEventMouseMotion:
		_mouse_in = true
	if event is InputEventMouseMotion and _drag_btn != 0:
		_drag_moved += (event as InputEventMouseMotion).relative.length()
		if _drag_btn == MOUSE_BUTTON_MIDDLE or _drag_moved > DRAG_THRESHOLD:
			_stage.position += (event as InputEventMouseMotion).relative
			_clamp_view()
			_remember_view()
			_after_camera()
			if not w.path.is_empty():
				_manual_cam = true
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
		_hover_title = str(thing.get("title", ""))
		if thing.is_empty():
			tooltip_text = _terrain_tooltip(w, p)
		elif thing.get("kind", "") == "settlement":
			tooltip_text = settlement_tooltip(w.settlement_by_id(str(thing["id"])))
		elif thing.get("kind", "") == "site":
			tooltip_text = Campaign.site_tooltip(w.site_by_id(str(thing["id"])), Game.renown)
		elif thing.get("kind", "") == "poi":
			tooltip_text = poi_tooltip(w.poi_by_id(str(thing["id"])))
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


## Info-bulle du terrain : son nom, et le territoire où l'on se trouve (grand monde).
func _terrain_tooltip(w: World, p: Vector2) -> String:
	var t: String = w.terrain_label(p)
	if w.grand and not _lab.is_empty():
		var o: String = Territory.owner_at(_lab, p)
		if o != "":
			t += " — %s" % Territory.region_name(o)
	return t
