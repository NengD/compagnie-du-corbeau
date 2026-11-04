class_name BoardView
extends Node2D
## Plateau hexagonal : sol peint (textures teintées par biome), décor animé, décalcomanies et cadavres au sol, figurines,
## météo, obscurité de nuit, effets. Ne calcule aucune règle.
## Couches : sol statique -> traces au sol -> décor animé -> surbrillances -> figurines -> lueurs -> météo -> nuit -> HUD -> effets.

const HS := 30.0
const MARGIN := 6.0
const OL := Color("17110c")
const TEX_PX := 112.0  ## taille d'une texture de sol en pixels du plateau
const ANIM_STEP := 0.05  ## le décor animé se redessine 20 fois par seconde au plus
const LIGHT_SLOTS := 24
## Couleurs visées (après teinte) par biome : herbe, forêt, colline.
const BIOME_GRASS: Dictionary = {
	"plain": Color("606a3e"), "forest": Color("4e5c35"), "hills": Color("76764a"), "water": Color("5a6e40"),
}
const FOREST_BASE := Color("46562f")
const HILL_BASE := Color("7d7c46")
const WATER_DEEP := Color("34525f")
const WATER_FORD := Color("5a7d84")
const TEX_GAIN := 1.18  ## les textures sont claires (~0,85) : la teinte est relevée d'autant
const FLAT_K := 0.86  ## sans texture (qualité Bas), la teinte est ramenée à la couleur visée

const NIGHT_SHADER := """
shader_type canvas_item;
render_mode blend_mul;
uniform vec4 dark : source_color = vec4(0.17, 0.2, 0.34, 1.0);
uniform vec3 lights[24];
uniform int count = 0;
varying vec2 wpos;
void vertex() { wpos = VERTEX; }
void fragment() {
	float lit = 0.0;
	for (int i = 0; i < 24; i++) {
		if (i >= count) { break; }
		float d = distance(wpos, lights[i].xy);
		lit = max(lit, 1.0 - smoothstep(lights[i].z * 0.4, lights[i].z, d));
	}
	COLOR = vec4(mix(dark.rgb, vec3(1.0), lit), 1.0);
}
"""

class Layer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)

var state: BattleState
var views: Dictionary = {}  ## id d'unité -> UnitView

# Surbrillances (renseignées par l'écran de bataille)
var reach: Dictionary = {}
var path_set: Dictionary = {}
var current_hex: Variant = null
var cost_hex: Variant = null
var cost_text: String = ""
var targets: Array = []  ## [{"hex": Vector2i, "pct": int}]

var weather_kind: String = "clear"
var decals: BattleDecals = BattleDecals.new()

var _terrain: Layer
var _floor: Layer
var _anim: Layer
var _marks: Layer
var _units: Node2D
var _glow: Layer
var _weather: BattleWeather
var _night: Layer
var _hud: Layer
var _fx: Node2D
var fx: BattleFx  ## particules : impacts, poussière, mort (voir effects.gd)

var _t: float = 0.0
var _ta: float = 0.0  ## horloge d'ambiance (herbe, feuillages, eau) : arrêtée quand les animations d'ambiance sont coupées
var _acc: float = 0.0
var _rng := RandomNumberGenerator.new()
var _tufts: Array = []
var _trees: Array = []  ## {p, k, ph} : canopées animées
var _waters: Array = []
var _night_on: bool = false


func _init() -> void:
	_terrain = Layer.new()
	_terrain.painter = _paint_terrain
	_terrain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_terrain)
	_floor = Layer.new()
	_floor.painter = _paint_floor
	add_child(_floor)
	_anim = Layer.new()
	_anim.painter = _paint_anim
	_anim.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_anim)
	_marks = Layer.new()
	_marks.painter = _paint_marks
	add_child(_marks)
	_units = Node2D.new()
	_units.y_sort_enabled = true
	add_child(_units)
	_glow = Layer.new()
	_glow.painter = _paint_glow
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = gm
	add_child(_glow)
	_weather = BattleWeather.new()
	add_child(_weather)
	_night = Layer.new()
	_night.painter = func(l: Node2D) -> void: l.draw_rect(Rect2(Vector2.ZERO, world_size(state.width, state.height)), Color.WHITE)
	var sh := Shader.new()
	sh.code = NIGHT_SHADER
	var smat := ShaderMaterial.new()
	smat.shader = sh
	_night.material = smat
	_night.visible = false
	add_child(_night)
	_hud = Layer.new()
	_hud.painter = _paint_hud
	add_child(_hud)
	_fx = Node2D.new()
	add_child(_fx)
	fx = BattleFx.new()
	_fx.add_child(fx)
	set_process(true)


func _ready() -> void:
	var st: Node = get_node_or_null("/root/Settings")
	if st != null and st.has_signal("changed"):
		st.connect("changed", _on_quality_changed)


## Réglages graphiques modifiés pendant la bataille : sol, ombres, météo et décalcomanies sont redessinés tout de suite.
func _on_quality_changed() -> void:
	if state == null or not is_inside_tree():
		return
	var cap: int = BattleDecals.cap_now()
	while decals.items.size() > cap:
		decals.items.remove_at(0)
	_weather.setup(weather_kind, world_size(state.width, state.height))
	_terrain.queue_redraw()
	refresh_units()


func _gmode() -> int:
	return int(Quality.value("ground_mode"))


func _shadows() -> int:
	return int(Quality.value("shadows"))


static func world_size(width: int, height: int) -> Vector2:
	return Vector2(HS * Hex.SQ * (width + 0.5) + 2.0 * MARGIN, HS * 1.5 * (height - 1) + 2.0 * HS + 2.0 * MARGIN)


func hex_px(h: Vector2i) -> Vector2:
	return Hex.to_pixel(h, HS, MARGIN)


func hex_at(local: Vector2) -> Vector2i:
	return Hex.from_pixel(local, HS, MARGIN)


## Graine stable de la bataille (déduite du terrain, donc identique après rechargement d'une sauvegarde).
static func battle_seed(s: BattleState) -> int:
	var acc: int = hash(s.biome)
	for h in s.cells:
		acc = (acc * 31 + (h.x * 73 + h.y * 19 + int(s.cells[h].get("v", 0)) * 7 + 1)) % 1000003
	return absi(acc)


func setup(s: BattleState) -> void:
	state = s
	for c in _units.get_children():
		c.queue_free()
	views.clear()
	for u in s.units:
		var v := UnitView.new().setup(u)
		v.position = hex_px(u.hex)
		_units.add_child(v)
		views[u.id] = v
	var sd: int = battle_seed(s)
	_rng.seed = sd
	weather_kind = BattleWeather.roll(s.biome, sd)
	_weather.setup(weather_kind, world_size(s.width, s.height))
	decals.save_carry()  # (au cas où une ancienne bataille n'aurait pas été vidée)
	decals = BattleDecals.new()
	decals.load_carry(s.cells, _rng)
	_build_decor()
	_terrain.queue_redraw()
	refresh_units()


func view_of(u: Unit) -> UnitView:
	return views.get(u.id)


func add_fx(n: Node) -> void:
	_fx.add_child(n)


## La pluie est en cours (les feux sont éteints ou faibles). Indépendant de l'option « Effets météo ».
func is_raining() -> bool:
	return weather_kind == "rain"


func is_night() -> bool:
	return state != null and bool(state.get("night"))


## Replace les figurines sur leurs cases et met à jour barres, moral et unité active.
func refresh_units() -> void:
	for u in state.units:
		var v: UnitView = views[u.id]
		if v.get_parent() and not v.has_meta("moving"):
			v.position = hex_px(u.hex)
		v.refresh()
		v.set_current(u == state.current and state.over == "")
		if u.dead:
			v.clear_arrows()
		if u.side == "e" and not _visible_to_player(u):
			v.visible = false
	_update_night()
	_floor.queue_redraw()
	_anim.queue_redraw()
	_glow.queue_redraw()
	_marks.queue_redraw()
	_hud.queue_redraw()


func _visible_to_player(u: Unit) -> bool:
	if not is_night() or not state.has_method("is_visible_to_player"):
		return true
	return bool(state.call("is_visible_to_player", u))


func set_marks(p_reach: Dictionary, p_path: Dictionary, p_current: Variant, p_cost_hex: Variant, p_cost_text: String, p_targets: Array) -> void:
	reach = p_reach
	path_set = p_path
	current_hex = p_current
	cost_hex = p_cost_hex
	cost_text = p_cost_text
	targets = p_targets
	_marks.queue_redraw()
	_hud.queue_redraw()


## Fait glisser la figurine jusqu'à la case `to` (l'état du jeu a déjà bougé).
func move_unit(u: Unit, to: Vector2i, duration: float, run: bool = false) -> void:
	var v: UnitView = views[u.id]
	v.set_meta("moving", true)
	fx.dust(v.position)
	await v.move_to(hex_px(to), duration, run)
	if is_instance_valid(v):
		v.remove_meta("moving")


func _process(delta: float) -> void:
	if state == null or UnitView._speed() <= 0.0:
		return
	_t += delta
	_acc += delta
	var ambient: bool = bool(Quality.value("map_anim"))
	if ambient:
		_ta += delta
	if _acc >= ANIM_STEP:
		_acc = 0.0
		if ambient or _has_objects():
			_anim.queue_redraw()
		_glow.queue_redraw()
		if _night_on:
			_update_night()


## Y a-t-il un objet animé (feu, torche…) sur le plateau ? (seul cas où le décor se redessine sans ambiance)
func _has_objects() -> bool:
	for h in state.cells:
		if state.cells[h].get("obj") is Dictionary:
			return true
	return false


# --- Effets ---

func float_text(h: Vector2i, text: String, color: Color, dy: float = 0.0, size: int = 15) -> void:
	var l := Label.new()
	l.text = text
	l.size = Vector2(120, 22)
	l.pivot_offset = Vector2(60, 11)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameTheme.bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("120f0c"))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: Vector2 = hex_px(h)
	l.position = Vector2(p.x - 60.0, p.y - 52.0 + dy)
	_fx.add_child(l)
	var sp: float = UnitView._speed()
	if sp > 0.0:
		l.scale = Vector2(0.6, 0.6)
		var pop: Tween = l.create_tween()
		pop.tween_property(l, "scale", Vector2(1.12, 1.12), 0.08).set_ease(Tween.EASE_OUT)
		pop.tween_property(l, "scale", Vector2.ONE, 0.08)
	var tw: Tween = l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 28.0, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## Ancien trait d'attaque (conservé pour compatibilité) ; les animations par arme sont dans attack_anims.gd.
func strike(from: Vector2i, to: Vector2i, ranged: bool) -> void:
	var a: Vector2 = hex_px(from)
	var b: Vector2 = hex_px(to)
	var line := Line2D.new()
	if ranged:
		line.points = PackedVector2Array([a + Vector2(0, -12), b + Vector2(0, -14)])
		line.width = 1.8
		line.default_color = Color("d9c79a")
	else:
		line.points = PackedVector2Array([b + Vector2(-10, -30), b + Vector2(10, 2)])
		line.width = 3.0
		line.default_color = Color("f3e3b5")
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_fx.add_child(line)
	var tw: Tween = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.4)
	tw.tween_callback(line.queue_free)


## Animation d'attaque par arme (rien si speed == 0). Les positions viennent des figurines, qui n'ont pas encore bougé.
func attack_anim(a: Unit, d: Unit, hit: bool, ability: String = "") -> void:
	await AttackAnims.play(self, a, d, hit, ability)


## Traces durables et effets de matière après une attaque (sang, flèches, poussière, éclats) ; `res` = résultat de `state.attack`.
func after_attack(a: Unit, d: Unit, res: Dictionary, ability: String = "") -> void:
	var kind: String = AttackAnims.kind_for(a.weapon, ability)
	var target_px: Vector2 = hex_px(d.hex)
	var dv: UnitView = view_of(d)
	if dv != null:
		target_px = dv.position
	var hit: bool = bool(res.get("hit", false))
	if hit and int(res.get("hp", 0)) > 0:
		var n: int = 2 if bool(res.get("head", false)) else 1
		for i in n:
			decals.add("blood", d.hex, _rng, blood_color(d), 1.0 + 0.4 * i)
		if d.dead:
			decals.add("blood", d.hex, _rng, blood_color(d), 1.8, 0.85)
	if AttackAnims.is_projectile(kind):
		if hit and not d.dead and dv != null and kind != "javelin":
			dv.add_arrow((target_px - hex_px(a.hex)).angle())
		elif not hit or d.dead:
			decals.add("arrow", d.hex if not hit else d.hex, _rng, Color("c9b98a"), 1.0, 0.95)
	if hit and kind == "smash" and fx != null:
		fx.heavy_hit(target_px)
	var obj: Variant = state.cells.get(d.hex, {}).get("obj")
	if hit and obj is Dictionary and str((obj as Dictionary).get("kind", "")) in ["wall", "gate", "barricade", "door"] and fx != null:
		fx.splinters(target_px)
		decals.add("splinter", d.hex, _rng, Color("8a6a3e"), 1.0, 0.9)
	_floor.queue_redraw()


static func blood_color(u: Unit) -> Color:
	match u.faction:
		"u":
			return Color(0.78, 0.76, 0.62)
		"g":
			return Color(0.29, 0.35, 0.16)
		"o":
			return Color(0.2, 0.28, 0.12)
	return Color(0.45, 0.07, 0.06)


## Cendres laissées sous un feu éteint ou qui brûle (appelé par le dessin du décor).
func add_ash(h: Vector2i) -> void:
	for d in decals.items:
		if d["hex"] == h and d["kind"] == "ash":
			return
	decals.add("ash", h, _rng, Color(0.1, 0.09, 0.08), 1.0, 0.7)


# --- Préparation du décor animé ---

func _build_decor() -> void:
	_tufts.clear()
	_trees.clear()
	_waters.clear()
	for h in state.cells:
		var cell: Dictionary = state.cells[h]
		var p: Vector2 = hex_px(h)
		var r := RandomNumberGenerator.new()
		r.seed = h.x * 131 + h.y * 7 + 1
		var kind: String = str(cell["t"])
		match kind:
			"g", "hill":
				if r.randf() < 0.55:
					var blades: Array = []
					for i in r.randi_range(4, 7):
						blades.append(Vector3(r.randf_range(-3.0, 3.0), r.randf_range(4.0, 8.0), r.randf_range(-2.0, 2.0)))
					_tufts.append({"p": p + Vector2(r.randf_range(-13, 13), r.randf_range(-8, 12)), "b": blades, "ph": r.randf_range(0.0, TAU)})
			"tree":
				_trees.append({"p": p, "k": 1.0, "ph": r.randf_range(0.0, TAU)})
			"forest":
				_trees.append({"p": p + Vector2(-9, -5), "k": 0.62, "ph": r.randf_range(0.0, TAU)})
				_trees.append({"p": p + Vector2(10, -3), "k": 0.62, "ph": r.randf_range(0.0, TAU)})
				_trees.append({"p": p + Vector2(0, 8), "k": 0.7, "ph": r.randf_range(0.0, TAU)})
			"river", "ford":
				_waters.append({"p": p, "ph": r.randf_range(0.0, TAU), "ford": kind == "ford", "y": r.randf_range(-3.0, 3.0)})
	_trees.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["p"] as Vector2).y < (b["p"] as Vector2).y)


# --- Sol statique ---

func _ellipse(l: Node2D, center: Vector2, rx: float, ry: float, col: Color) -> void:
	l.draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	l.draw_circle(Vector2.ZERO, rx, col)
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c: PackedVector2Array = pts.duplicate()
	c.append(pts[0])
	return c


static func _uvs(pts: PackedVector2Array) -> PackedVector2Array:
	var uv := PackedVector2Array()
	for q in pts:
		uv.append(q / TEX_PX)
	return uv


func _snow() -> float:
	return 0.55 if weather_kind == "snow" else 0.0


## Classe de sol d'une case (ce qui est dessiné sous les arbres et les rochers : de l'herbe).
func _ground_class(t: String) -> String:
	match t:
		"forest", "hill", "river", "ford":
			return t
	return "g"


func _ground_color(cls: String, v: int, h: Vector2i) -> Color:
	var r := RandomNumberGenerator.new()
	r.seed = h.x * 131 + h.y * 7 + 1
	var base: Color = BIOME_GRASS.get(state.biome, BIOME_GRASS["plain"])
	var col: Color
	match cls:
		"forest":
			col = FOREST_BASE
		"hill":
			col = HILL_BASE
		"river":
			col = WATER_DEEP
		"ford":
			col = WATER_FORD
		_:
			col = base.lightened([0.0, 0.03, -0.03][clampi(v, 0, 2)])
	col = col.lightened(r.randf_range(-0.03, 0.03))
	if cls != "river" and cls != "ford" and _snow() > 0.0:
		col = col.lerp(Color(0.8, 0.84, 0.88), _snow())
	return col


func _tex_for(cls: String, v: int) -> Texture2D:
	match cls:
		"forest":
			return GroundTex.get_tex("dirt")
		"hill":
			return GroundTex.get_tex("grass1")
		"river":
			return GroundTex.get_tex("water")
		"ford":
			return GroundTex.get_tex("sand")
	return GroundTex.get_tex("grass%d" % clampi(v, 0, 2))


func _paint_terrain(l: Node2D) -> void:
	if state == null:
		return
	var objects: Array[Vector2i] = []
	var gm: int = _gmode()
	for h in state.cells:
		var cell: Dictionary = state.cells[h]
		var p: Vector2 = hex_px(h)
		var r := RandomNumberGenerator.new()
		r.seed = h.x * 131 + h.y * 7 + 1
		var kind: String = str(cell["t"])
		var cls: String = _ground_class(kind)
		var v: int = int(cell["v"])
		var col: Color = _ground_color(cls, v, h)
		var pts: PackedVector2Array = Hex.corners(p, HS - 0.4)
		var tint: Color = Color(col.r * TEX_GAIN, col.g * TEX_GAIN, col.b * TEX_GAIN, 1.0)
		if gm == 0:  # qualité Bas : aplats colorés
			l.draw_colored_polygon(pts, tint * FLAT_K)
		else:
			l.draw_colored_polygon(pts, tint, _uvs(pts), _tex_for(cls, v))
		# fondus doux avec les cases voisines de nature différente (qualité Élevé et plus)
		for i in (6 if gm >= 2 else 0):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % 6]
			var mid: Vector2 = (a + b) * 0.5
			var nb: Vector2i = hex_at(p + (mid - p) * 2.0)
			if not state.cells.has(nb):
				continue
			var ncls: String = _ground_class(str(state.cells[nb]["t"]))
			if ncls == cls:
				continue
			var ncol: Color = _ground_color(ncls, int(state.cells[nb]["v"]), nb)
			var inward: Vector2 = (p - mid).normalized() * (11.0 if (cls == "river" or ncls == "river") else 8.0)
			var strip := PackedVector2Array([a, b, b + inward, a + inward])
			var wet: bool = ncls == "river" or ncls == "ford"
			var edge_a: float = 0.5 if not wet else 0.4
			var cols := PackedColorArray([Color(ncol, edge_a), Color(ncol, edge_a), Color(ncol, 0.0), Color(ncol, 0.0)])
			l.draw_polygon(strip, cols)
			if (cls == "river" or cls == "ford") and not wet or (cls == "ford" and ncls == "g"):
				l.draw_line(a, b, Color(0.82, 0.9, 0.88, 0.45), 1.6)  # écume sur la rive
		l.draw_polyline(_closed(pts), Color(0.07, 0.08, 0.04, 0.3), 1.0)
		match kind:
			"hill":
				_paint_hill(l, p, tint)
			"ford":
				_paint_ford(l, p)
			"g":
				var roll: float = r.randf()
				if roll < 0.10:  # cailloux
					var s := p + Vector2(r.randf_range(-12, 12), r.randf_range(-8, 12))
					_ellipse(l, s, 2.6, 1.7, Color(0.36, 0.34, 0.3, 0.9))
					_ellipse(l, s + Vector2(-0.5, -0.6), 1.8, 1.1, Color(0.58, 0.55, 0.48, 0.9))
				elif roll < 0.2 and _snow() == 0.0:  # fleurettes
					var s2 := p + Vector2(r.randf_range(-12, 12), r.randf_range(-8, 12))
					var fc: Color = [Color("d9cf7a"), Color("c9c9c0"), Color("b38aa6")][r.randi() % 3]
					l.draw_circle(s2, 1.1, fc)
		if kind == "tree" or kind == "rock" or kind == "forest":
			objects.append(h)
	objects.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for h in objects:
		var ot: String = str(state.cells[h]["t"])
		var op: Vector2 = hex_px(h)
		if ot == "tree":
			_tree_base(l, op, 1.0)
		elif ot == "forest":
			_tree_base(l, op + Vector2(-9, -5), 0.62)
			_tree_base(l, op + Vector2(10, -3), 0.62)
			_tree_base(l, op + Vector2(0, 8), 0.7)
		else:
			_paint_rock(l, op, h)


## Ombre portée (soleil en haut à gauche -> ombre vers le bas à droite) et tronc.
func _tree_base(l: Node2D, p: Vector2, k: float) -> void:
	if _shadows() > 0:
		l.draw_set_transform(p + Vector2(11, 12) * k, -0.12, Vector2(1.0, 0.3))
		l.draw_circle(Vector2.ZERO, 21.0 * k, Color(0, 0, 0, 0.3))
		l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var trunk := PackedVector2Array([p + Vector2(-2.5, 12) * k, p + Vector2(-1.5, -2) * k, p + Vector2(2.5, -2) * k, p + Vector2(3.5, 12) * k])
	l.draw_colored_polygon(trunk, Color("4a3424"))
	l.draw_line(p + Vector2(0.6, 11) * k, p + Vector2(0.9, -1) * k, Color("5e4630"), 1.0)
	l.draw_polyline(_closed(trunk), OL, 1.0)


## Canopée animée : cercles qui se balancent doucement (plus fort avec le vent).
func _tree_crown(l: Node2D, p: Vector2, k: float, ph: float) -> void:
	var sway: float = BattleWeather.wind_sway(weather_kind)
	var circles: Array = [[-9.0, -6.0, 10.0], [9.0, -5.0, 10.0], [0.0, -17.0, 12.0], [0.0, -5.0, 10.0]]
	var sx: float = sin(_ta * 1.1 + ph) * 0.9 * sway
	var sy: float = sin(_ta * 0.7 + ph * 1.7) * 0.35 * sway
	for c in circles:
		var w: float = (-float(c[1]) / 20.0)
		l.draw_circle(p + Vector2(float(c[0]) + sx * w, float(c[1]) + sy * w) * k, (float(c[2]) + 1.2) * k, OL)
	for c in circles:
		var w2: float = (-float(c[1]) / 20.0)
		l.draw_circle(p + Vector2(float(c[0]) + sx * w2, float(c[1]) + sy * w2) * k, float(c[2]) * k, Color("28361c"))
	for c in [[-5.0, -10.0, 7.0], [5.0, -14.0, 7.0], [7.0, -4.0, 5.0]]:
		l.draw_circle(p + Vector2(float(c[0]) + sx * 0.8, float(c[1]) + sy) * k, float(c[2]) * k, Color("3a4d27"))
	for c in [[-7.0, -13.0, 3.6], [1.0, -21.0, 4.0], [3.0, -9.0, 2.6]]:
		l.draw_circle(p + Vector2(float(c[0]) + sx, float(c[1]) + sy * 1.2) * k, float(c[2]) * k, Color("52683a"))
	if _snow() > 0.0:
		l.draw_circle(p + Vector2(-2.0 + sx, -21.0 + sy) * k, 6.0 * k, Color(0.92, 0.95, 0.98, 0.8))


func _paint_hill(l: Node2D, p: Vector2, tint: Color) -> void:
	if _shadows() > 0:
		_ellipse(l, p + Vector2(7, 10), 23, 6, Color(0.05, 0.06, 0.02, 0.38))
	var mound := PackedVector2Array()
	for i in 13:
		var a: float = PI + PI * i / 12.0
		mound.append(p + Vector2(cos(a) * 22.0, 8.0 + sin(a) * 18.0))
	var mt: Color = Color("8d8c52").lightened(0.1)
	mt = Color(mt.r * TEX_GAIN, mt.g * TEX_GAIN, mt.b * TEX_GAIN)
	if _snow() > 0.0:
		mt = mt.lerp(Color(1, 1, 1), _snow())
	if _gmode() == 0:
		l.draw_colored_polygon(mound, mt * FLAT_K)
	else:
		l.draw_colored_polygon(mound, mt, _uvs(mound), GroundTex.get_tex("grass2"))
	# face à l'ombre (à droite) : croissant sombre
	var shade := PackedVector2Array()
	for i in 9:
		var a2: float = -0.9 + 1.5 * i / 8.0 + PI * 0.0
		shade.append(p + Vector2(cos(a2) * 22.0, 8.0 + sin(a2) * 18.0))
	for i in 9:
		var a3: float = 0.6 - 1.5 * i / 8.0
		shade.append(p + Vector2(cos(a3) * 14.0 - 2.0, 8.0 + sin(a3) * 11.0))
	l.draw_colored_polygon(shade, Color(0.08, 0.08, 0.02, 0.3))
	# lumière en haut à gauche et courbes de niveau
	var hi := PackedVector2Array()
	for i in 9:
		var a4: float = PI * 1.05 + PI * 0.6 * i / 8.0
		hi.append(p + Vector2(cos(a4) * 14.0 - 2.0, 5.0 + sin(a4) * 11.0))
	l.draw_polyline(hi, Color(1, 1, 0.8, 0.35), 2.2)
	l.draw_arc(p + Vector2(0, 8), 13.0, PI * 1.1, PI * 1.9, 10, Color(0.1, 0.1, 0.03, 0.25), 1.0)
	l.draw_polyline(mound, Color(0.09, 0.09, 0.03, 0.7), 1.2)


func _paint_ford(l: Node2D, p: Vector2) -> void:
	for c in [[-9.0, 5.0, 4.0], [3.0, -6.0, 3.5], [10.0, 7.0, 4.5], [-2.0, 9.0, 3.0]]:
		l.draw_circle(p + Vector2(float(c[0]) + 1.0, float(c[1]) + 1.5), float(c[2]) + 1.0, Color(0, 0, 0, 0.25))
		l.draw_circle(p + Vector2(c[0], c[1]), float(c[2]) + 1.0, OL)
		l.draw_circle(p + Vector2(c[0], c[1]), float(c[2]), Color("8a8372"))
		l.draw_circle(p + Vector2(float(c[0]) - 1.0, float(c[1]) - 1.0), float(c[2]) * 0.5, Color("aaa28e"))


func _paint_rock(l: Node2D, p: Vector2, h: Vector2i) -> void:
	if _shadows() > 0:
		_ellipse(l, p + Vector2(8, 11), 17, 4.5, Color(0, 0, 0, 0.32))
	var r := RandomNumberGenerator.new()
	r.seed = h.x * 17 + h.y * 29 + 5
	var tex: Texture2D = GroundTex.get_tex("rock")
	var body := PackedVector2Array([Vector2(-14, 9), Vector2(-11, -4), Vector2(-3, -11), Vector2(8, -9), Vector2(14, 1), Vector2(12, 9)])
	var top := PackedVector2Array([Vector2(-3, -11), Vector2(8, -9), Vector2(4, -1), Vector2(-8, -2)])
	var side := PackedVector2Array([Vector2(4, -1), Vector2(14, 1), Vector2(12, 9), Vector2(3, 9)])
	var snow: float = _snow()
	for poly in [[body, Color("6c665a")], [top, Color("8f8877")], [side, Color("514c43")]]:
		var pts := PackedVector2Array()
		for v in poly[0]:
			pts.append(p + v)
		var c: Color = poly[1]
		c = Color(c.r * TEX_GAIN, c.g * TEX_GAIN, c.b * TEX_GAIN)
		if poly[1] == Color("8f8877") and snow > 0.0:
			c = c.lerp(Color(1, 1, 1), snow + 0.2)
		if _gmode() == 0:
			l.draw_colored_polygon(pts, c * FLAT_K)
		else:
			l.draw_colored_polygon(pts, c, _uvs(pts), tex)
		if poly[0] == body:
			l.draw_polyline(_closed(pts), OL, 1.1)
	# fissures et mousse
	l.draw_polyline(PackedVector2Array([p + Vector2(-6, -8), p + Vector2(-5, -3), p + Vector2(-8, 3), p + Vector2(-6, 8)]), Color(0.12, 0.1, 0.08, 0.7), 1.0)
	l.draw_polyline(PackedVector2Array([p + Vector2(6, -2), p + Vector2(8, 3), p + Vector2(6, 8)]), Color(0.1, 0.09, 0.07, 0.6), 1.0)
	l.draw_polyline(PackedVector2Array([p + Vector2(-9, -5), p + Vector2(-4, -10), p + Vector2(4, -9.5)]), Color(1, 1, 0.9, 0.35), 1.4)
	if r.randf() < 0.6:
		_ellipse(l, p + Vector2(-8, 6), 4.5, 2.2, Color(0.28, 0.4, 0.18, 0.8))


# --- Traces au sol et cadavres (sous les figurines) ---

func _paint_floor(l: Node2D) -> void:
	if state == null:
		return
	for d in decals.items:
		_paint_decal(l, d)
	var dead_at: Dictionary = {}
	for u in state.units:
		if u.dead:
			dead_at[u.hex] = u
	for c in state.corpses:
		_paint_corpse(l, c, dead_at.get(c))


func _paint_decal(l: Node2D, d: Dictionary) -> void:
	var p: Vector2 = hex_px(d["hex"]) + Vector2(float(d["ox"]), float(d["oy"]))
	var col: Color = d["col"]
	var a: float = float(d["alpha"])
	var s: float = float(d["size"])
	var rot: float = float(d["rot"])
	match str(d["kind"]):
		"blood":
			l.draw_set_transform(p, rot, Vector2(1.0, 0.55))
			l.draw_circle(Vector2.ZERO, 6.0 * s, Color(col, a * 0.75))
			l.draw_circle(Vector2(5.0, 2.0) * s, 3.2 * s, Color(col, a * 0.7))
			l.draw_circle(Vector2(-4.0, -3.0) * s, 2.4 * s, Color(col.darkened(0.2), a * 0.7))
			l.draw_circle(Vector2(9.0, -1.0) * s, 1.3 * s, Color(col, a * 0.8))
			l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"ash":
			_ellipse(l, p, 11.0 * s, 5.0 * s, Color(col, a * 0.7))
			_ellipse(l, p + Vector2(3, 1), 6.0 * s, 2.6 * s, Color(col.darkened(0.3), a))
		"arrow":
			var dir := Vector2.from_angle(rot)
			var tip: Vector2 = p + dir * 8.0
			var tail: Vector2 = p - dir * 8.0
			l.draw_line(tail + Vector2(1, 1), tip + Vector2(1, 1), Color(0, 0, 0, 0.3), 1.6)
			l.draw_line(tail, tip, Color(col, a), 1.6)
			l.draw_line(tail, tail + dir.rotated(0.5) * -4.0, Color("b04a3a"), 1.2)
			l.draw_line(tail, tail + dir.rotated(-0.5) * -4.0, Color("b04a3a"), 1.2)
			l.draw_circle(tip, 1.3, Color("8a8f94"))
		"splinter":
			for i in 4:
				var q: Vector2 = p + Vector2.from_angle(rot + i * 1.6) * (3.0 + i * 2.0)
				l.draw_line(q, q + Vector2.from_angle(rot + i * 2.3) * 4.5, Color(col, a), 1.7)


## Cadavre selon la faction et la taille ; pose stable tirée de l'identifiant. Sans unité connue : un humain.
func _paint_corpse(l: Node2D, h: Vector2i, u: Unit) -> void:
	var p: Vector2 = hex_px(h)
	var id: int = 0 if u == null else u.id
	var faction: String = "p" if u == null else u.faction
	var side: String = "p" if u == null else u.side
	var r := RandomNumberGenerator.new()
	r.seed = id * 7919 + h.x * 31 + h.y
	var flip: float = -1.0 if r.randf() < 0.5 else 1.0
	var tilt: float = r.randf_range(-0.35, 0.35)
	var k: float = 1.0
	if u != null:
		k = 1.0 + clampf((float(u.hp_max) - 60.0) / 140.0, 0.0, 0.45)
	var sprite: String = "" if u == null else str(u.get("sprite") if u.get("sprite") != null else "")
	var is_beast: bool = sprite != "" and not (sprite.begins_with("ghoul") or sprite.begins_with("skel") or sprite.begins_with("orc"))
	var blood: Color = Color(0.29, 0.086, 0.07, 0.75) if u == null else Color(blood_color(u), 0.7)
	# flaque
	_ellipse(l, p + Vector2(1, 7), 13 * k, 5 * k, blood)
	_ellipse(l, p + Vector2(6 * flip, 9), 6 * k, 2.4 * k, Color(blood.darkened(0.3), 0.8))
	l.draw_set_transform(p + Vector2(0, 5), tilt, Vector2(flip, 1.0))
	if faction == "u":  # os épars
		var bone := Color("d6cfb5")
		l.draw_circle(Vector2(-9, -1), 3.4, OL)
		l.draw_circle(Vector2(-9, -1), 2.7, bone)
		l.draw_circle(Vector2(-10, -1.5), 0.7, OL)
		l.draw_circle(Vector2(-8, -1.5), 0.7, OL)
		for b in [[-5.0, 0.0, 6.0, -2.0], [-4.0, 3.0, 8.0, 4.0], [2.0, -3.0, 9.0, 0.0], [4.0, 5.0, 12.0, 1.0]]:
			l.draw_line(Vector2(b[0], b[1]), Vector2(b[2], b[3]), OL, 3.0)
			l.draw_line(Vector2(b[0], b[1]), Vector2(b[2], b[3]), bone, 1.7)
		for i in 3:
			l.draw_arc(Vector2(-1 + i * 2.0, -1), 4.0, PI * 1.1, PI * 1.9, 6, bone, 1.2)
	elif faction == "g":  # goule : corps maigre gris-vert, bras longs
		var skin := Color("6e7a5a")
		l.draw_colored_polygon(PackedVector2Array([Vector2(-9, -4), Vector2(6, -6), Vector2(11, 0), Vector2(4, 4), Vector2(-9, 3)]), OL)
		l.draw_colored_polygon(PackedVector2Array([Vector2(-8, -3), Vector2(5, -5), Vector2(10, 0), Vector2(4, 3), Vector2(-8, 2)]), skin)
		l.draw_circle(Vector2(-12, -1), 4.4, OL)
		l.draw_circle(Vector2(-12, -1), 3.6, skin.lightened(0.08))
		l.draw_line(Vector2(-4, 3), Vector2(-6, 10), skin, 2.0)
		l.draw_line(Vector2(6, -5), Vector2(15, -9), skin, 2.0)
		l.draw_line(Vector2(15, -9), Vector2(18, -6), Color("c9c2a0"), 1.4)
	elif faction == "o":  # orc : grand corps verdâtre en armure
		l.draw_colored_polygon(PackedVector2Array([Vector2(-11, -6), Vector2(8, -8), Vector2(14, 0), Vector2(6, 6), Vector2(-11, 5)]), OL)
		l.draw_colored_polygon(PackedVector2Array([Vector2(-10, -5), Vector2(7, -7), Vector2(13, 0), Vector2(6, 5), Vector2(-10, 4)]), Color("4f3a2a"))
		l.draw_colored_polygon(PackedVector2Array([Vector2(-6, -5), Vector2(5, -6), Vector2(9, -1), Vector2(-6, 0)]), Color("6a5a48"))
		l.draw_circle(Vector2(-14, -1), 5.0, OL)
		l.draw_circle(Vector2(-14, -1), 4.2, Color("5b7a3c"))
		l.draw_line(Vector2(-16, 1), Vector2(-17, 3), Color("e8e0c0"), 1.2)
		l.draw_line(Vector2(6, 5), Vector2(14, 10), Color("5b7a3c"), 2.6)
	elif is_beast:  # bête : corps allongé, pattes repliées
		var fur := Color("5a4a3a")
		l.draw_set_transform(p + Vector2(0, 5), tilt, Vector2(flip, 0.6))
		l.draw_circle(Vector2(0, 0), 10.5 * 1.0, OL)
		l.draw_circle(Vector2(0, 0), 9.6, fur)
		l.draw_circle(Vector2(-10, -1), 5.0, OL)
		l.draw_circle(Vector2(-10, -1), 4.2, fur.lightened(0.08))
		l.draw_set_transform(p + Vector2(0, 5), tilt, Vector2(flip, 1.0))
		l.draw_line(Vector2(6, 4), Vector2(13, 8), fur.darkened(0.2), 2.2)
		l.draw_line(Vector2(-2, 5), Vector2(3, 10), fur.darkened(0.2), 2.2)
	else:  # humain tombé
		var cloth: Color = Color("7a6a4a") if side == "p" else Color("7a3a2c")
		if faction == "b":
			cloth = Color("6a3328")
		l.draw_colored_polygon(PackedVector2Array([Vector2(-8, -4), Vector2(7, -5), Vector2(10, 0), Vector2(6, 4), Vector2(-8, 3)]), OL)
		l.draw_colored_polygon(PackedVector2Array([Vector2(-7, -3), Vector2(6, -4), Vector2(9, 0), Vector2(5, 3), Vector2(-7, 2)]), cloth)
		l.draw_circle(Vector2(-11, -1), 4.4, OL)
		l.draw_circle(Vector2(-11, -1), 3.6, Color("c79a76"))
		l.draw_line(Vector2(5, 3), Vector2(13, 6), cloth.darkened(0.2), 2.6)
		l.draw_line(Vector2(5, -4), Vector2(12, -8), cloth.darkened(0.1), 2.4)
		l.draw_line(Vector2(-3, 3), Vector2(-5, 9), cloth.darkened(0.25), 2.4)
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# armes et boucliers tombés
	if u != null and not is_beast and faction != "g":
		var wp := p + Vector2(15 * flip, 9) * 1.0
		l.draw_line(wp + Vector2(-8, 1), wp + Vector2(8, -2), OL, 3.0)
		l.draw_line(wp + Vector2(-8, 1), wp + Vector2(8, -2), Color("8d8d92") if faction != "u" else Color("7a5a3a"), 1.6)
		if bool(u.get("shield") if u.get("shield") != null else false):
			var sp2 := p + Vector2(-13 * flip, 10)
			_ellipse(l, sp2, 7.5, 3.6, OL)
			_ellipse(l, sp2, 6.5, 3.0, Color("a07a3a") if side == "p" else Color("7a3a2c"))


# --- Décor animé (redessiné 20 fois par seconde au plus) ---

func _paint_anim(l: Node2D) -> void:
	if state == null:
		return
	var sway: float = BattleWeather.wind_sway(weather_kind)
	var grass_col: Color = Color("4a5230").lerp(Color("c8d0d8"), _snow())
	for tf in _tufts:
		var base: Vector2 = tf["p"]
		var s: float = sin(_ta * 1.7 + float(tf["ph"])) * 1.5 * sway
		for b in tf["b"]:
			var bv: Vector3 = b
			var root := base + Vector2(bv.x, 0.0)
			l.draw_line(root, root + Vector2(bv.z + s * bv.y * 0.22, -bv.y), grass_col, 1.1)
	# eau : vaguelettes, reflets du ciel et éclats
	for w in _waters:
		var p: Vector2 = w["p"]
		var ph: float = w["ph"]
		var ford: bool = w["ford"]
		var line_col: Color = Color("86a9ae") if ford else Color("5d8590")
		for k in 3:
			var y: float = p.y - 10.0 + k * 9.0 + float(w["y"]) + sin(_ta * 0.9 + ph + k) * 1.2
			var x: float = p.x - 12.0 + sin(_ta * 0.5 + ph * 2.0 + k * 1.3) * 4.0
			l.draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + 6, y - 2), Vector2(x + 12, y), Vector2(x + 18, y - 2), Vector2(x + 24, y)]), Color(line_col, 0.85), 1.3)
		var refl: float = 0.5 + 0.5 * sin(_ta * 0.6 + ph)
		l.draw_line(p + Vector2(-14 + refl * 6.0, -4), p + Vector2(2 + refl * 6.0, -4), Color(0.85, 0.92, 0.95, 0.22), 2.0)
		for g in 2:
			var glint: float = pow(maxf(0.0, sin(_ta * 2.1 + ph * (g + 1.3) + g * 2.0)), 8.0)
			if glint > 0.05:
				var gp: Vector2 = p + Vector2(-9 + g * 16.0, -8 + g * 11.0 + sin(ph) * 3.0)
				l.draw_line(gp + Vector2(-2.5, 0), gp + Vector2(2.5, 0), Color(1, 1, 1, glint * 0.8), 1.2)
				l.draw_line(gp + Vector2(0, -2.0), gp + Vector2(0, 2.0), Color(1, 1, 1, glint * 0.8), 1.0)
	for t in _trees:
		_tree_crown(l, t["p"], float(t["k"]), float(t["ph"]))
	# objets interactifs (feu, portes, barricades, palissades, pièges, torches)
	for h in state.cells:
		var obj: Variant = state.cells[h].get("obj")
		if obj is Dictionary:
			_paint_object(l, hex_px(h), obj, h)


func _paint_object(l: Node2D, p: Vector2, obj: Dictionary, h: Vector2i) -> void:
	var hp_ratio: float = 1.0
	var hp: Variant = obj.get("hp")
	var hp_max: Variant = obj.get("hp_max")
	if hp != null and hp_max != null and float(hp_max) > 0.0:
		hp_ratio = clampf(float(hp) / float(hp_max), 0.0, 1.0)
	var broken: bool = hp != null and float(hp) <= 0.0
	match str(obj.get("kind", "")):
		"fire":
			_ellipse(l, p + Vector2(0, 6), 14, 5, Color(0.07, 0.06, 0.05, 0.6))
			l.draw_line(p + Vector2(-9, 7), p + Vector2(8, 2), Color("3a2a1c"), 3.0)
			l.draw_line(p + Vector2(-8, 2), p + Vector2(9, 7), Color("4a3524"), 3.0)
			_draw_flame(l, p + Vector2(0, 3), 1.0 if not is_raining() else 0.35)
			_draw_smoke(l, p + Vector2(0, -6), 1.0 if not is_raining() else 1.6)
			add_ash(h)
		"torch":
			l.draw_line(p + Vector2(0, 11), p + Vector2(0, -8), OL, 4.0)
			l.draw_line(p + Vector2(0, 11), p + Vector2(0, -8), Color("6a4a2a"), 2.4)
			_draw_flame(l, p + Vector2(0, -8), 0.55 if not is_raining() else 0.3)
		"trap":
			if bool(obj.get("hidden", false)):
				return
			_ellipse(l, p + Vector2(0, 6), 12, 4, Color(0, 0, 0, 0.3))
			for i in 7:
				var x: float = -10.0 + i * 3.4
				var tri := PackedVector2Array([p + Vector2(x - 1.7, 6), p + Vector2(x, -3 - (i % 2) * 2.0), p + Vector2(x + 1.7, 6)])
				l.draw_colored_polygon(tri, Color("8d9096"))
			l.draw_line(p + Vector2(-11, 6), p + Vector2(11, 6), OL, 2.0)
		"barricade":
			_ellipse(l, p + Vector2(4, 11), 20, 5, Color(0, 0, 0, 0.3))
			var gap: float = (1.0 - hp_ratio) * 6.0
			for lg in [[-16.0, 3.0, 14.0, -7.0 - gap], [-15.0, -6.0, 15.0, 5.0 + gap], [-16.0, 9.0, 16.0, 8.0]]:
				l.draw_line(p + Vector2(lg[0], lg[1]), p + Vector2(lg[2], lg[3]), OL, 6.0)
				l.draw_line(p + Vector2(lg[0], lg[1]), p + Vector2(lg[2], lg[3]), Color("7a5a36"), 4.0)
				l.draw_line(p + Vector2(lg[0], lg[1] - 1), p + Vector2(lg[2], lg[3] - 1), Color("8e6c42"), 1.2)
			if broken:
				for i in 5:
					l.draw_line(p + Vector2(-10 + i * 5, 9), p + Vector2(-6 + i * 5, 7), Color("6a4a2a"), 2.0)
		"door":
			_paint_door(l, p, bool(obj.get("open", false)), broken, false)
		"gate":
			_paint_door(l, p, bool(obj.get("open", false)), broken, true)
		"wall":
			_paint_wall(l, p, hp_ratio, str(obj.get("style", "palisade")), broken)


func _paint_door(l: Node2D, p: Vector2, open: bool, broken: bool, gate: bool) -> void:
	var w: float = 24.0 if gate else 17.0
	var top: float = -16.0 if gate else -12.0
	_ellipse(l, p + Vector2(3, 12), w + 4.0, 4.5, Color(0, 0, 0, 0.3))
	l.draw_rect(Rect2(p + Vector2(-w - 3.0, top - 3.0), Vector2(5, 14 - top + 2.0)), OL)
	l.draw_rect(Rect2(p + Vector2(w - 2.0, top - 3.0), Vector2(5, 14 - top + 2.0)), OL)
	l.draw_rect(Rect2(p + Vector2(-w - 2.0, top - 2.0), Vector2(3, 14 - top)), Color("5a4026"))
	l.draw_rect(Rect2(p + Vector2(w - 1.0, top - 2.0), Vector2(3, 14 - top)), Color("5a4026"))
	if broken:
		for i in 6:
			var bx: float = -w + 3.0 + i * (w * 2.0 - 6.0) / 6.0
			l.draw_line(p + Vector2(bx, 11), p + Vector2(bx + 5, 9 - (i % 3) * 2.0), Color("6a4a2a"), 3.0)
		return
	if open:  # vantaux rabattus sur les côtés
		var leaf := PackedVector2Array([p + Vector2(-w, top), p + Vector2(-w + 6, top + 3), p + Vector2(-w + 6, 12), p + Vector2(-w, 14)])
		l.draw_colored_polygon(leaf, Color("7a5a36"))
		l.draw_polyline(_closed(leaf), OL, 1.2)
		if gate:
			var leaf2 := PackedVector2Array([p + Vector2(w, top), p + Vector2(w - 6, top + 3), p + Vector2(w - 6, 12), p + Vector2(w, 14)])
			l.draw_colored_polygon(leaf2, Color("7a5a36"))
			l.draw_polyline(_closed(leaf2), OL, 1.2)
		return
	var rect := Rect2(p + Vector2(-w, top), Vector2(w * 2.0, 14 - top))
	l.draw_rect(rect, Color("7a5a36"))
	var n: int = 6 if gate else 4
	for i in n:
		var x: float = rect.position.x + rect.size.x * (i + 1) / (n + 1)
		l.draw_line(Vector2(x, rect.position.y + 1), Vector2(x, rect.end.y - 1), Color("4a3420"), 1.0)
	l.draw_rect(Rect2(rect.position + Vector2(0, 4), Vector2(rect.size.x, 3)), Color("5c5f66"))
	l.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 8), Vector2(rect.size.x, 3)), Color("5c5f66"))
	l.draw_rect(rect, OL, false, 1.4)
	l.draw_circle(p + Vector2(w - 5.0, 0), 1.6, Color("c9a448"))


func _paint_wall(l: Node2D, p: Vector2, hp_ratio: float, style: String, broken: bool) -> void:
	_ellipse(l, p + Vector2(5, 12), 22, 5, Color(0, 0, 0, 0.32))
	if style == "stone":
		var blocks := Rect2(p + Vector2(-19, -8), Vector2(38, 22))
		l.draw_rect(blocks, Color("6c665a"))
		for row in 3:
			l.draw_line(Vector2(blocks.position.x, blocks.position.y + 7.0 * (row + 1)), Vector2(blocks.end.x, blocks.position.y + 7.0 * (row + 1)), Color("3e3a33"), 1.0)
			for col in 3:
				var x: float = blocks.position.x + 6.0 + col * 13.0 + (row % 2) * 6.0
				l.draw_line(Vector2(x, blocks.position.y + 7.0 * row), Vector2(x, blocks.position.y + 7.0 * (row + 1)), Color("3e3a33"), 1.0)
		l.draw_rect(Rect2(blocks.position, Vector2(blocks.size.x, 3)), Color("8f8877"))
		l.draw_rect(blocks, OL, false, 1.3)
		return
	for i in 5:
		if broken and i % 2 == 1:
			continue
		var x2: float = -17.0 + i * 8.5
		var hgt: float = 22.0 - (1.0 - hp_ratio) * 10.0 * float((i * 7) % 3) / 2.0
		var post := PackedVector2Array([p + Vector2(x2 - 3.5, 13), p + Vector2(x2 - 3.5, 13 - hgt + 5), p + Vector2(x2, 13 - hgt), p + Vector2(x2 + 3.5, 13 - hgt + 5), p + Vector2(x2 + 3.5, 13)])
		l.draw_colored_polygon(post, Color("7a5a36"))
		l.draw_line(p + Vector2(x2 - 1, 13), p + Vector2(x2 - 1, 13 - hgt + 5), Color("93714a"), 1.0)
		l.draw_polyline(_closed(post), OL, 1.1)
	l.draw_line(p + Vector2(-19, 2), p + Vector2(19, 2), Color("4a3420"), 2.0)


func _draw_flame(l: Node2D, base: Vector2, k: float) -> void:
	for i in 3:
		var ph: float = _t * (8.0 + i * 1.7) + i * 2.1
		var hgt: float = (15.0 + 5.0 * sin(ph)) * k
		var wd: float = (6.0 - i * 1.4) * k
		var off: float = sin(ph * 0.6) * 1.6 * k + (i - 1) * 3.0 * k
		var poly := PackedVector2Array([base + Vector2(off - wd, 0), base + Vector2(off - wd * 0.7, -hgt * 0.55), base + Vector2(off + sin(ph) * 1.5, -hgt), base + Vector2(off + wd * 0.7, -hgt * 0.55), base + Vector2(off + wd, 0)])
		var cols: Array = [Color("d4501c"), Color("f08a24"), Color("ffd45a")]
		l.draw_colored_polygon(poly, cols[i])


func _draw_smoke(l: Node2D, base: Vector2, k: float) -> void:
	for j in 4:
		var f: float = fmod(_t * 0.45 * k + j * 0.25, 1.0)
		var pos: Vector2 = base + Vector2(sin(_t + j * 2.0) * 3.0 + f * 5.0, -f * 28.0)
		l.draw_circle(pos, 3.0 + f * 6.0, Color(0.32, 0.31, 0.3, (1.0 - f) * 0.32))


func _paint_glow(l: Node2D) -> void:
	if state == null:
		return
	var tex: Texture2D = BattleWeather._soft()
	var raining: bool = is_raining()
	for h in state.cells:
		var obj: Variant = state.cells[h].get("obj")
		if not (obj is Dictionary):
			continue
		var kind: String = str((obj as Dictionary).get("kind", ""))
		if kind != "fire" and kind != "torch":
			continue
		var p: Vector2 = hex_px(h) + Vector2(0, -6 if kind == "fire" else -8)
		var flick: float = 0.8 + 0.2 * sin(_t * 11.0 + h.x * 3.0 + h.y)
		var r: float = (46.0 if kind == "fire" else 34.0) * flick
		var a: float = (0.55 if not is_night() else 0.8) * (0.4 if raining and kind == "fire" else 1.0)
		l.draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.55, 0.2, a * 0.5))


# --- Nuit : voile sombre avec des trous de lumière ---

func _update_night() -> void:
	_night_on = is_night()
	_night.visible = _night_on
	if not _night_on:
		return
	var sight: int = 4
	var sr: Variant = state.get("sight_radius")
	if sr != null:
		sight = int(sr)
	var lights := PackedVector3Array()
	for u in state.units:
		if u.side == "p" and u.is_live() and lights.size() < LIGHT_SLOTS:
			var q: Vector2 = views[u.id].position if views.has(u.id) else hex_px(u.hex)
			lights.append(Vector3(q.x, q.y, (sight + 0.6) * HS * Hex.SQ))
	for h in state.cells:
		var obj: Variant = state.cells[h].get("obj")
		if obj is Dictionary and str((obj as Dictionary).get("kind", "")) in ["fire", "torch"] and lights.size() < LIGHT_SLOTS:
			var q2: Vector2 = hex_px(h)
			var flick: float = 1.0 + 0.04 * sin(_t * 9.0 + h.x)
			lights.append(Vector3(q2.x, q2.y, (3.2 if str((obj as Dictionary)["kind"]) == "fire" else 2.6) * HS * Hex.SQ * flick))
	var count: int = lights.size()
	while lights.size() < LIGHT_SLOTS:
		lights.append(Vector3.ZERO)
	var m := _night.material as ShaderMaterial
	m.set_shader_parameter("lights", lights)
	m.set_shader_parameter("count", count)
	_night.queue_redraw()


# --- Surbrillances et HUD ---

func _paint_marks(l: Node2D) -> void:
	if state == null:
		return
	for k in reach:
		var pts: PackedVector2Array = Hex.corners(hex_px(k), HS - 2.0)
		if path_set.has(k):
			l.draw_colored_polygon(pts, Color(0.81, 0.66, 0.32, 0.42))
		else:
			l.draw_colored_polygon(pts, Color(0.81, 0.66, 0.32, 0.15))
			l.draw_polyline(_closed(pts), Color(0.81, 0.66, 0.32, 0.5), 1.0)
	if current_hex != null:
		l.draw_polyline(_closed(Hex.corners(hex_px(current_hex), HS - 2.0)), GameTheme.GOLD, 2.5)


func _paint_hud(l: Node2D) -> void:
	var font: Font = GameTheme.bold_font()
	if cost_hex != null and cost_text != "":
		var p: Vector2 = hex_px(cost_hex)
		l.draw_string(font, p + Vector2(-30, 4), cost_text, HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color("1c1915"))
	for t in targets:
		var p2: Vector2 = hex_px(t["hex"])
		var r := Rect2(p2.x - 16, p2.y - 60, 32, 14)
		l.draw_rect(r, Color("8f3328"))
		l.draw_rect(r, Color("f0a090"), false, 1.0)
		l.draw_string(font, Vector2(p2.x - 16, p2.y - 49), "%d %%" % t["pct"], HORIZONTAL_ALIGNMENT_CENTER, 32, 11, Color.WHITE)
