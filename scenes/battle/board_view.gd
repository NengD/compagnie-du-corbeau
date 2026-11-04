class_name BoardView
extends Node2D
## Plateau hexagonal : terrain, surbrillances, figurines, pourcentages, effets. Ne calcule aucune règle.

const HS := 30.0
const MARGIN := 6.0
const OL := Color("17110c")
const FOREST_BASE := Color("46562f")
const HILL_BASE := Color("7d7c46")
const WATER_DEEP := Color("34525f")
const WATER_FORD := Color("5a7d84")
const GRASS: Array[Color] = [Color("606a3e"), Color("68723f"), Color("58623a")]

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

var _terrain: Layer
var _marks: Layer
var _units: Node2D
var _hud: Layer
var _fx: Node2D
var fx: BattleFx  ## particules : impacts, poussière, mort (voir effects.gd)


func _init() -> void:
	_terrain = Layer.new()
	_terrain.painter = _paint_terrain
	add_child(_terrain)
	_marks = Layer.new()
	_marks.painter = _paint_marks
	add_child(_marks)
	_units = Node2D.new()
	_units.y_sort_enabled = true
	add_child(_units)
	_hud = Layer.new()
	_hud.painter = _paint_hud
	add_child(_hud)
	_fx = Node2D.new()
	add_child(_fx)
	fx = BattleFx.new()
	_fx.add_child(fx)


static func world_size(width: int, height: int) -> Vector2:
	return Vector2(HS * Hex.SQ * (width + 0.5) + 2.0 * MARGIN, HS * 1.5 * (height - 1) + 2.0 * HS + 2.0 * MARGIN)


func hex_px(h: Vector2i) -> Vector2:
	return Hex.to_pixel(h, HS, MARGIN)


func hex_at(local: Vector2) -> Vector2i:
	return Hex.from_pixel(local, HS, MARGIN)


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
	_terrain.queue_redraw()
	refresh_units()


func view_of(u: Unit) -> UnitView:
	return views.get(u.id)


## Replace les figurines sur leurs cases et met à jour barres, moral et unité active.
func refresh_units() -> void:
	for u in state.units:
		var v: UnitView = views[u.id]
		if v.get_parent() and not v.has_meta("moving"):
			v.position = hex_px(u.hex)
		v.refresh()
		v.set_current(u == state.current and state.over == "")
	_marks.queue_redraw()
	_hud.queue_redraw()


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


# --- Effets ---

func float_text(h: Vector2i, text: String, color: Color, dy: float = 0.0, size: int = 15) -> void:
	var l := Label.new()
	l.text = text
	l.size = Vector2(120, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameTheme.bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("120f0c"))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: Vector2 = hex_px(h)
	l.position = Vector2(p.x - 60.0, p.y - 52.0 + dy)
	_fx.add_child(l)
	var tw: Tween = l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 28.0, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


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


# --- Dessin ---

func _ellipse(l: Node2D, center: Vector2, rx: float, ry: float, col: Color) -> void:
	l.draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	l.draw_circle(Vector2.ZERO, rx, col)
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c: PackedVector2Array = pts.duplicate()
	c.append(pts[0])
	return c


func _paint_terrain(l: Node2D) -> void:
	if state == null:
		return
	var objects: Array[Vector2i] = []
	for h in state.cells:
		var cell: Dictionary = state.cells[h]
		var p: Vector2 = hex_px(h)
		var r := RandomNumberGenerator.new()
		r.seed = h.x * 131 + h.y * 7 + 1
		var kind: String = str(cell["t"])
		var col: Color = GRASS[int(cell["v"])].lightened(r.randf_range(-0.03, 0.03))
		match kind:
			"forest":
				col = FOREST_BASE.lightened(r.randf_range(-0.03, 0.03))
			"hill":
				col = HILL_BASE.lightened(r.randf_range(-0.03, 0.03))
			"river":
				col = WATER_DEEP
			"ford":
				col = WATER_FORD
		var pts: PackedVector2Array = Hex.corners(p, HS - 0.5)
		l.draw_colored_polygon(pts, col)
		l.draw_polyline(_closed(pts), Color(0.08, 0.09, 0.04, 0.4), 1.0)
		if kind == "river" or kind == "ford":
			_paint_water(l, p, kind == "ford", r)
		elif kind == "hill":
			_paint_hill(l, p)
		elif kind == "g" and r.randf() < 0.35:
			var t := Vector2(p.x + r.randf_range(-12, 12), p.y + r.randf_range(-10, 12))
			for tip in [Vector2(-2, -5), Vector2(0.5, -6), Vector2(3, -4.5)]:
				l.draw_line(t, t + tip, Color("4a5230"), 1.1)
		if kind == "tree" or kind == "rock" or kind == "forest":
			objects.append(h)
	objects.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for h in objects:
		var ot: String = str(state.cells[h]["t"])
		if ot == "tree":
			_paint_tree(l, hex_px(h))
		elif ot == "forest":
			_paint_forest(l, hex_px(h))
		else:
			_paint_rock(l, hex_px(h))


func _paint_tree(l: Node2D, p: Vector2, k: float = 1.0) -> void:
	_ellipse(l, p + Vector2(4, 12) * k, 19 * k, 6 * k, Color(0, 0, 0, 0.32))
	var trunk := PackedVector2Array([p + Vector2(-2.5, 12) * k, p + Vector2(-1.5, -2) * k, p + Vector2(2.5, -2) * k, p + Vector2(3.5, 12) * k])
	l.draw_colored_polygon(trunk, Color("4a3424"))
	l.draw_polyline(_closed(trunk), OL, 1.0)
	for c in [[-9.0, -6.0, 10.0], [9.0, -5.0, 10.0], [0.0, -17.0, 12.0], [0.0, -5.0, 10.0]]:
		l.draw_circle(p + Vector2(c[0], c[1]) * k, (c[2] + 1.2) * k, OL)
	for c in [[-9.0, -6.0, 10.0], [9.0, -5.0, 10.0], [0.0, -17.0, 12.0], [0.0, -5.0, 10.0]]:
		l.draw_circle(p + Vector2(c[0], c[1]) * k, c[2] * k, Color("28361c"))
	for c in [[-5.0, -10.0, 7.0], [5.0, -14.0, 7.0], [7.0, -4.0, 5.0]]:
		l.draw_circle(p + Vector2(c[0], c[1]) * k, c[2] * k, Color("3a4d27"))
	for c in [[-7.0, -13.0, 3.6], [1.0, -21.0, 4.0], [3.0, -9.0, 2.6]]:
		l.draw_circle(p + Vector2(c[0], c[1]) * k, c[2] * k, Color("52683a"))


## Forêt : trois arbres serrés, plus petits qu'un arbre isolé.
func _paint_forest(l: Node2D, p: Vector2) -> void:
	_paint_tree(l, p + Vector2(-9, -5), 0.62)
	_paint_tree(l, p + Vector2(10, -3), 0.62)
	_paint_tree(l, p + Vector2(0, 8), 0.7)


func _paint_hill(l: Node2D, p: Vector2) -> void:
	_ellipse(l, p + Vector2(0, 9), 22, 7, Color(0.1, 0.1, 0.03, 0.35))
	var mound := PackedVector2Array()
	for i in 13:
		var a: float = PI + PI * i / 12.0
		mound.append(p + Vector2(cos(a) * 22.0, 8.0 + sin(a) * 18.0))
	l.draw_colored_polygon(mound, Color("8d8c52"))
	var hi := PackedVector2Array()
	for i in 13:
		var a2: float = PI + PI * i / 12.0
		hi.append(p + Vector2(cos(a2) * 13.0 - 3.0, 4.0 + sin(a2) * 11.0))
	l.draw_colored_polygon(hi, Color("a2a063"))
	l.draw_polyline(mound, Color(0.09, 0.09, 0.03, 0.7), 1.2)


func _paint_water(l: Node2D, p: Vector2, ford: bool, r: RandomNumberGenerator) -> void:
	var line_col: Color = Color("86a9ae") if ford else Color("5d8590")
	for k in 3:
		var y: float = p.y - 10.0 + k * 9.0 + r.randf_range(-2, 2)
		var x: float = p.x - 12.0 + r.randf_range(-3, 3)
		l.draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + 6, y - 2), Vector2(x + 12, y), Vector2(x + 18, y - 2), Vector2(x + 24, y)]), line_col, 1.3)
	if ford:  # pierres du gué
		for c in [[-9.0, 5.0, 4.0], [3.0, -6.0, 3.5], [10.0, 7.0, 4.5], [-2.0, 9.0, 3.0]]:
			l.draw_circle(p + Vector2(c[0], c[1]), c[2] + 1.0, OL)
			l.draw_circle(p + Vector2(c[0], c[1]), c[2], Color("8a8372"))

func _paint_rock(l: Node2D, p: Vector2) -> void:
	_ellipse(l, p + Vector2(2, 10), 16, 5, Color(0, 0, 0, 0.3))
	var body := PackedVector2Array([Vector2(-14, 9), Vector2(-11, -4), Vector2(-3, -11), Vector2(8, -9), Vector2(14, 1), Vector2(12, 9)])
	var top := PackedVector2Array([Vector2(-3, -11), Vector2(8, -9), Vector2(4, -1), Vector2(-8, -2)])
	var side := PackedVector2Array([Vector2(4, -1), Vector2(14, 1), Vector2(12, 9), Vector2(3, 9)])
	for poly in [[body, Color("6c665a")], [top, Color("8f8877")], [side, Color("514c43")]]:
		var pts := PackedVector2Array()
		for v in poly[0]:
			pts.append(p + v)
		l.draw_colored_polygon(pts, poly[1])
		if poly[0] == body:
			l.draw_polyline(_closed(pts), OL, 1.1)


func _paint_marks(l: Node2D) -> void:
	if state == null:
		return
	for c in state.corpses:
		var p: Vector2 = hex_px(c)
		_ellipse(l, p + Vector2(0, 6), 13, 5, Color(0.29, 0.086, 0.07, 0.75))
		_ellipse(l, p + Vector2(5, 8), 6, 2.4, Color(0.18, 0.05, 0.035, 0.8))
		l.draw_line(p + Vector2(-9, 4), p + Vector2(7, -1), Color(0.16, 0.13, 0.125, 0.7), 2.0)
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
		var p: Vector2 = hex_px(t["hex"])
		var r := Rect2(p.x - 16, p.y - 60, 32, 14)
		l.draw_rect(r, Color("8f3328"))
		l.draw_rect(r, Color("f0a090"), false, 1.0)
		l.draw_string(font, Vector2(p.x - 16, p.y - 49), "%d %%" % t["pct"], HORIZONTAL_ALIGNMENT_CENTER, 32, 11, Color.WHITE)
