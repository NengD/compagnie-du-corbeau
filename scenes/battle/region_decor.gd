class_name RegionDecor
extends RefCounted
## Décor de fond d'un plateau selon l'ambiance de la région (core/region_look.gd) : teinte du sol, détails à plat sur l'herbe,
## bâtiments, clôtures, ponts et ruines posés AUTOUR du plateau. Purement visuel : ne touche ni aux cases ni aux règles.
## Appelé par BoardView._paint_floor ; coupé en qualité Bas (sol en aplats).

const OL := Color("17110c")
const STONE := Color("8a8478")
const STONE_D := Color("5e5a52")
const WOOD := Color("6a4a2c")
const THATCH := Color("a8884a")
const SNOW := Color("e8eef2")


## Ambiance de ce plateau (mise en cache sur le BoardView). Le propriétaire de région vient de l'autoload Game si présent.
static func look_for(board: BoardView) -> Dictionary:
	var st: BattleState = board.state
	var key: int = st.get_instance_id()
	if board.has_meta("rl_key") and int(board.get_meta("rl_key")) == key:
		return board.get_meta("rl_look")
	var owner: String = ""
	var tree := Engine.get_main_loop() as SceneTree
	var g: Node = tree.root.get_node_or_null("Game") if tree != null else null
	if g != null and g.get("world") != null:
		var s: Dictionary = g.get("world").settlement_by_id(str(st.contract.get("origin_id", "")))
		owner = str(s.get("owner", ""))
	var lk: Dictionary = RegionLook.for_battle(st.contract, st.biome, owner, BoardView.battle_seed(st))
	board.set_meta("rl_key", key)
	board.set_meta("rl_look", lk)
	return lk


static func enabled() -> bool:
	return int(Quality.value("ground_mode")) > 0


static func paint(l: Node2D, board: BoardView) -> void:
	if board.state == null or not enabled():
		return
	paint_look(l, board, look_for(board))


static func paint_look(l: Node2D, board: BoardView, look: Dictionary) -> void:
	var st: BattleState = board.state
	var wash: Color = look["wash"]
	var feats: Array = look["features"]
	var hi: bool = int(Quality.value("ground_mode")) >= 2
	for h in st.cells:
		var cell: Dictionary = st.cells[h]
		var t: String = str(cell["t"])
		if t != "g" and t != "hill" and t != "forest":
			continue
		var p: Vector2 = board.hex_px(h)
		if wash.a > 0.0:
			l.draw_colored_polygon(Hex.corners(p, BoardView.HS - 0.4), wash)
		if t != "g" or cell.has("obj"):
			continue
		var r := RandomNumberGenerator.new()
		r.seed = h.x * 977 + h.y * 131 + int(look["seed"]) % 9973 + 5
		_ground_detail(l, p, r, feats, hi)
	var ws: Vector2 = BoardView.world_size(st.width, st.height)
	var rr := RandomNumberGenerator.new()
	rr.seed = int(look["seed"]) + 77
	_edges(l, board, look, feats, ws, rr)


# --- détails à plat sur les cases d'herbe -------------------------------------------------------------

static func _ell(l: Node2D, c: Vector2, rx: float, ry: float, col: Color) -> void:
	l.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	l.draw_circle(Vector2.ZERO, rx, col)
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _rp(r: RandomNumberGenerator, p: Vector2, sx: float = 12.0, sy: float = 9.0) -> Vector2:
	return p + Vector2(r.randf_range(-sx, sx), r.randf_range(-sy, sy + 3.0))


static func _ground_detail(l: Node2D, p: Vector2, r: RandomNumberGenerator, feats: Array, hi: bool) -> void:
	var roll: float = r.randf()
	if feats.has("puddles") and roll < 0.2:
		var c: Vector2 = _rp(r, p)
		_ell(l, c, 7.0, 3.4, Color(0.18, 0.26, 0.3, 0.8))
		_ell(l, c + Vector2(-1, -0.8), 4.6, 2.0, Color(0.46, 0.58, 0.62, 0.7))
	elif feats.has("snow_patches") and roll < 0.45:
		var c2: Vector2 = _rp(r, p)
		_ell(l, c2, r.randf_range(5.0, 9.0), r.randf_range(2.6, 4.0), Color(SNOW, 0.85))
		if hi and roll < 0.1:
			l.draw_line(c2 + Vector2(-3, 4), c2 + Vector2(3, 5), Color(0.6, 0.7, 0.8, 0.7), 1.0)
	elif feats.has("rubble") and roll < 0.3:
		var c3: Vector2 = _rp(r, p)
		for i in 3:
			_ell(l, c3 + Vector2(i * 3.2 - 3.0, (i % 2) * 2.0), 2.4, 1.6, STONE_D)
			_ell(l, c3 + Vector2(i * 3.2 - 3.4, (i % 2) * 2.0 - 0.5), 1.6, 1.0, STONE)
	elif feats.has("cracks") and roll < 0.42:
		var c4: Vector2 = _rp(r, p)
		l.draw_polyline(PackedVector2Array([c4, c4 + Vector2(5, 2), c4 + Vector2(8, -1), c4 + Vector2(11, 3)]), Color(0.1, 0.09, 0.07, 0.6), 1.0)
	elif feats.has("furrows") and roll < 0.55:
		var c5: Vector2 = p + Vector2(0, r.randf_range(-6, 6))
		for i in 3:
			l.draw_line(c5 + Vector2(-13, i * 3.4 - 3), c5 + Vector2(13, i * 3.4 - 3), Color(0.36, 0.26, 0.14, 0.55), 1.6)
	elif feats.has("ripples") and roll < 0.45:
		var c6: Vector2 = _rp(r, p)
		l.draw_arc(c6, 7.0, PI * 1.1, PI * 1.9, 8, Color(0.62, 0.48, 0.28, 0.55), 1.2)
		l.draw_arc(c6 + Vector2(0, 3), 5.0, PI * 1.1, PI * 1.9, 8, Color(0.95, 0.85, 0.6, 0.4), 1.0)
	elif feats.has("litter") and roll < 0.5:
		var c7: Vector2 = _rp(r, p)
		for i in 4:
			var q: Vector2 = c7 + Vector2(r.randf_range(-5, 5), r.randf_range(-3, 3))
			_ell(l, q, 1.8, 1.0, [Color(0.5, 0.34, 0.14, 0.8), Color(0.36, 0.3, 0.12, 0.8)][i % 2])
	elif feats.has("heather") and roll < 0.5:
		var c8: Vector2 = _rp(r, p)
		for i in 5:
			l.draw_circle(c8 + Vector2(r.randf_range(-4, 4), r.randf_range(-2.5, 2.5)), 1.1, Color(0.56, 0.34, 0.6, 0.9))
	elif (feats.has("pebbles") or feats.has("lichen")) and roll < 0.4:
		var c9: Vector2 = _rp(r, p)
		_ell(l, c9, 2.8, 1.8, Color(0.34, 0.32, 0.28, 0.9))
		_ell(l, c9 + Vector2(-0.5, -0.6), 1.9, 1.1, Color(0.62, 0.58, 0.5, 0.9))
		if feats.has("lichen"):
			_ell(l, c9 + Vector2(4, 1), 2.4, 1.2, Color(0.55, 0.6, 0.3, 0.6))
	elif feats.has("moss") and roll < 0.3:
		_ell(l, _rp(r, p), 6.0, 3.0, Color(0.2, 0.36, 0.16, 0.5))
	elif feats.has("tufts") and roll < 0.25:
		var c10: Vector2 = _rp(r, p)
		for i in 3:
			l.draw_line(c10 + Vector2(i * 1.6 - 1.6, 0), c10 + Vector2(i * 1.6 - 2.2, -4.2), Color(0.36, 0.5, 0.2, 0.9), 1.2)
	elif feats.has("hay") and roll < 0.62:
		var c11: Vector2 = _rp(r, p)
		l.draw_line(c11, c11 + Vector2(3, -3), Color(0.8, 0.7, 0.38, 0.9), 1.4)
		l.draw_line(c11 + Vector2(2, 1), c11 + Vector2(5, -2), Color(0.8, 0.7, 0.38, 0.9), 1.4)
	if feats.has("reeds") and roll > 0.88:
		var c12: Vector2 = _rp(r, p)
		for i in 4:
			l.draw_line(c12 + Vector2(i * 1.8, 0), c12 + Vector2(i * 1.8 + 0.6 * (i - 2), -7.0 - (i % 2) * 2.0), Color(0.38, 0.46, 0.2), 1.3)
			l.draw_circle(c12 + Vector2(i * 1.8 + 0.6 * (i - 2), -7.0 - (i % 2) * 2.0), 0.9, Color(0.4, 0.26, 0.14))


# --- décor autour du plateau ---------------------------------------------------------------------------

static func _edges(l: Node2D, board: BoardView, look: Dictionary, feats: Array, ws: Vector2, r: RandomNumberGenerator) -> void:
	var top_y: float = BoardView.MARGIN + 2.0
	var bot_y: float = ws.y - BoardView.MARGIN - 2.0
	var n: int = int(ws.x / 90.0)
	if feats.has("fences"):
		_fence(l, Vector2(10, top_y), Vector2(ws.x - 10, top_y))
		_fence(l, Vector2(10, bot_y), Vector2(ws.x - 10, bot_y))
	if feats.has("farm"):
		_house(l, Vector2(ws.x * 0.22, top_y - 2), 1.0, THATCH, Color("c9b48a"))
		_house(l, Vector2(ws.x * 0.7, bot_y + 30), 0.8, Color("8a4a30"), Color("c0aa84"))
	if feats.has("hay"):
		_haystack(l, Vector2(ws.x * 0.45, top_y - 4))
		_haystack(l, Vector2(ws.x * 0.88, bot_y + 14))
	if feats.has("ruin_walls"):
		for i in n:
			if r.randf() < 0.7:
				_ruin_wall(l, Vector2(30.0 + i * 90.0 + r.randf_range(-12, 12), top_y), r)
		for i in n:
			if r.randf() < 0.45:
				_ruin_wall(l, Vector2(50.0 + i * 90.0, bot_y + 26.0), r)
	if feats.has("graves"):
		for i in 6:
			_grave(l, Vector2(r.randf_range(20, ws.x - 20), bot_y + r.randf_range(6, 24)))
	if feats.has("treeline"):
		for i in n * 2:
			_pine(l, Vector2(12.0 + i * 46.0 + r.randf_range(-8, 8), top_y - 4 + r.randf_range(-4, 6)), 0.9 + r.randf() * 0.5, false, Color("2e4a28"))
		for i in n:
			_pine(l, Vector2(30.0 + i * 92.0, bot_y + 18 + r.randf_range(-3, 5)), 0.8 + r.randf() * 0.4, false, Color("2e4a28"))
	if feats.has("pines"):
		for i in n * 2:
			_pine(l, Vector2(14.0 + i * 48.0 + r.randf_range(-8, 8), top_y - 4 + r.randf_range(-4, 6)), 0.8 + r.randf() * 0.5, true, Color("36503a"))
		for i in n:
			_pine(l, Vector2(34.0 + i * 94.0, bot_y + 18), 0.7 + r.randf() * 0.4, true, Color("36503a"))
	if feats.has("deadwood"):
		for i in n:
			_dead_tree(l, Vector2(24.0 + i * 92.0 + r.randf_range(-10, 10), top_y - 2 + r.randf_range(-2, 6)))
	if feats.has("boulders"):
		for i in n:
			if r.randf() < 0.6:
				_boulder(l, Vector2(r.randf_range(20, ws.x - 20), top_y - 3 + r.randf_range(-3, 4)), 0.8 + r.randf() * 0.8, Color("7a766a"))
	if feats.has("mesas"):
		for i in n:
			_mesa(l, Vector2(20.0 + i * 96.0 + r.randf_range(-14, 14), top_y), 0.8 + r.randf() * 0.8)
	if feats.has("standing_stones"):
		for i in 5:
			_standing_stone(l, Vector2(r.randf_range(20, ws.x - 20), top_y - 4 + (0 if i % 2 == 0 else bot_y - top_y + 20)))
	if feats.has("bridge"):
		_bridge(l, board)


static func _fence(l: Node2D, a: Vector2, b: Vector2) -> void:
	var len: float = a.distance_to(b)
	var steps: int = int(len / 14.0)
	var dir: Vector2 = (b - a) / maxf(1.0, len)
	l.draw_line(a + Vector2(0, -6), b + Vector2(0, -6), OL, 3.2)
	l.draw_line(a + Vector2(0, -6), b + Vector2(0, -6), Color("8a6a40"), 1.8)
	l.draw_line(a + Vector2(0, -2), b + Vector2(0, -2), OL, 3.2)
	l.draw_line(a + Vector2(0, -2), b + Vector2(0, -2), Color("7a5a34"), 1.8)
	for i in steps + 1:
		var p: Vector2 = a + dir * (i * 14.0)
		l.draw_line(p + Vector2(0, 1), p + Vector2(0, -9), OL, 3.6)
		l.draw_line(p + Vector2(0, 1), p + Vector2(0, -9), Color("6a4a2c"), 2.2)


static func _house(l: Node2D, base: Vector2, k: float, roof: Color, wall: Color) -> void:
	var w: float = 44.0 * k
	var h: float = 22.0 * k
	_ell(l, base + Vector2(w * 0.5 + 6, 2), w * 0.6, 4.0, Color(0, 0, 0, 0.25))
	var walls := PackedVector2Array([base + Vector2(0, 0), base + Vector2(w, 0), base + Vector2(w, -h), base + Vector2(0, -h)])
	l.draw_colored_polygon(walls, wall)
	l.draw_polyline(PackedVector2Array([walls[0], walls[1], walls[2], walls[3], walls[0]]), OL, 1.6)
	l.draw_line(base + Vector2(0, -h), base + Vector2(w, 0), Color(0.3, 0.2, 0.1, 0.35), 1.0)  # colombage
	l.draw_line(base + Vector2(w, -h), base + Vector2(0, 0), Color(0.3, 0.2, 0.1, 0.35), 1.0)
	var rf := PackedVector2Array([base + Vector2(-5, -h + 2), base + Vector2(w * 0.5, -h - 18 * k), base + Vector2(w + 5, -h + 2)])
	l.draw_colored_polygon(rf, roof)
	l.draw_polyline(PackedVector2Array([rf[0], rf[1], rf[2], rf[0]]), OL, 1.6)
	l.draw_line(rf[1], rf[0] + Vector2(10, 0), Color(0, 0, 0, 0.25), 1.0)
	l.draw_rect(Rect2(base + Vector2(w * 0.18, -h * 0.55), Vector2(8 * k, 11 * k)), Color("3a2a1a"))
	l.draw_rect(Rect2(base + Vector2(w * 0.62, -h * 0.7), Vector2(8 * k, 7 * k)), Color("e0c878"))
	l.draw_rect(Rect2(base + Vector2(w * 0.62, -h * 0.7), Vector2(8 * k, 7 * k)), OL, false, 1.0)


static func _haystack(l: Node2D, base: Vector2) -> void:
	_ell(l, base + Vector2(2, 3), 11.0, 3.4, Color(0, 0, 0, 0.25))
	var pts := PackedVector2Array([base + Vector2(-10, 2), base + Vector2(-8, -9), base + Vector2(0, -15), base + Vector2(8, -9), base + Vector2(10, 2)])
	l.draw_colored_polygon(pts, Color("c4a850"))
	l.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4]]), OL, 1.4)
	l.draw_line(base + Vector2(-4, -6), base + Vector2(-3, 1), Color(0.5, 0.4, 0.16, 0.6), 1.0)
	l.draw_line(base + Vector2(3, -8), base + Vector2(4, 1), Color(0.5, 0.4, 0.16, 0.6), 1.0)


static func _ruin_wall(l: Node2D, base: Vector2, r: RandomNumberGenerator) -> void:
	var w: float = r.randf_range(34.0, 62.0)
	var pts := PackedVector2Array([base + Vector2(0, 2)])
	var x: float = 0.0
	while x < w:
		pts.append(base + Vector2(x, -r.randf_range(8.0, 24.0)))
		x += r.randf_range(6.0, 12.0)
	pts.append(base + Vector2(w, -r.randf_range(4.0, 14.0)))
	pts.append(base + Vector2(w, 2))
	l.draw_colored_polygon(pts, STONE)
	l.draw_polyline(pts, OL, 1.5)
	for i in 3:  # joints de pierre
		var yy: float = -5.0 * (i + 1)
		l.draw_line(base + Vector2(2, yy), base + Vector2(w - 2, yy), Color(0.15, 0.13, 0.1, 0.45), 1.0)
	_boulder(l, base + Vector2(w + 6, 1), 0.5, STONE_D)


static func _grave(l: Node2D, p: Vector2) -> void:
	_ell(l, p + Vector2(1, 1), 5.0, 1.8, Color(0, 0, 0, 0.25))
	var pts := PackedVector2Array([p + Vector2(-3.4, 0), p + Vector2(-3.4, -8), p + Vector2(0, -10.4), p + Vector2(3.4, -8), p + Vector2(3.4, 0)])
	l.draw_colored_polygon(pts, Color("9a968a"))
	l.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4]]), OL, 1.2)
	l.draw_line(p + Vector2(0, -8), p + Vector2(0, -4), Color(0.2, 0.18, 0.14, 0.7), 1.0)
	l.draw_line(p + Vector2(-1.6, -6.4), p + Vector2(1.6, -6.4), Color(0.2, 0.18, 0.14, 0.7), 1.0)


static func _pine(l: Node2D, base: Vector2, k: float, snowy: bool, leaf: Color) -> void:
	_ell(l, base + Vector2(4, 1), 9.0 * k, 2.8 * k, Color(0, 0, 0, 0.22))
	l.draw_rect(Rect2(base + Vector2(-1.6, -5) * k, Vector2(3.2, 6) * k), Color("4a3424"))
	for i in 3:
		var w: float = (13.0 - i * 2.6) * k
		var y: float = (-4.0 - i * 8.0) * k
		var tri := PackedVector2Array([base + Vector2(-w, y), base + Vector2(w, y), base + Vector2(0, y - 13.0 * k)])
		l.draw_colored_polygon(tri, leaf)
		l.draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), OL, 1.2)
		if snowy:
			l.draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.55, y - 6.0 * k), base + Vector2(w * 0.55, y - 6.0 * k), base + Vector2(0, y - 13.0 * k)]), SNOW)


static func _dead_tree(l: Node2D, base: Vector2) -> void:
	l.draw_line(base, base + Vector2(0, -20), OL, 4.0)
	l.draw_line(base, base + Vector2(0, -20), Color("5a4a3a"), 2.4)
	for d in [[Vector2(0, -12), Vector2(-9, -20)], [Vector2(0, -15), Vector2(8, -23)], [Vector2(0, -8), Vector2(7, -13)]]:
		l.draw_line(base + d[0], base + d[1], OL, 3.0)
		l.draw_line(base + d[0], base + d[1], Color("5a4a3a"), 1.6)


static func _boulder(l: Node2D, p: Vector2, k: float, col: Color) -> void:
	_ell(l, p + Vector2(3, 2), 10.0 * k, 3.0 * k, Color(0, 0, 0, 0.25))
	var pts := PackedVector2Array([p + Vector2(-9, 1) * k, p + Vector2(-7, -8) * k, p + Vector2(1, -12) * k, p + Vector2(9, -7) * k, p + Vector2(10, 1) * k])
	l.draw_colored_polygon(pts, col)
	l.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), OL, 1.3)
	l.draw_line(p + Vector2(-5, -6) * k, p + Vector2(0, -10) * k, Color(1, 1, 1, 0.35), 1.2)


static func _mesa(l: Node2D, p: Vector2, k: float) -> void:
	var col := Color("9a7a52")
	var pts := PackedVector2Array([p + Vector2(-16, 2) * k, p + Vector2(-12, -18) * k, p + Vector2(-4, -22) * k, p + Vector2(8, -20) * k, p + Vector2(14, -10) * k, p + Vector2(18, 2) * k])
	l.draw_colored_polygon(pts, col)
	l.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5]]), OL, 1.4)
	l.draw_line(p + Vector2(-10, -12) * k, p + Vector2(14, -10) * k, Color(0.4, 0.28, 0.14, 0.5), 1.2)
	l.draw_line(p + Vector2(-13, -5) * k, p + Vector2(16, -4) * k, Color(0.4, 0.28, 0.14, 0.5), 1.2)


static func _standing_stone(l: Node2D, p: Vector2) -> void:
	_ell(l, p + Vector2(2, 1), 6.0, 2.0, Color(0, 0, 0, 0.25))
	var pts := PackedVector2Array([p + Vector2(-4, 0), p + Vector2(-5, -14), p + Vector2(-1, -19), p + Vector2(4, -13), p + Vector2(4, 0)])
	l.draw_colored_polygon(pts, Color("7e7a72"))
	l.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4]]), OL, 1.3)
	l.draw_line(p + Vector2(-2, -12), p + Vector2(-2, -4), Color(0.2, 0.3, 0.14, 0.6), 1.4)


## Pont de pierre décoratif au-dessus de la rivière, côté haut du plateau (ne remplace aucune case).
static func _bridge(l: Node2D, board: BoardView) -> void:
	var st: BattleState = board.state
	var xs: Array[float] = []
	var top: float = 1.0e9
	for h in st.cells:
		var tt: String = str(st.cells[h]["t"])
		if tt == "river" or tt == "ford":
			top = minf(top, board.hex_px(h).y)
	for h in st.cells:
		var t2: String = str(st.cells[h]["t"])
		if (t2 == "river" or t2 == "ford") and absf(board.hex_px(h).y - top) < 2.0:
			xs.append(board.hex_px(h).x)
	if xs.is_empty():
		return
	var x0: float = xs.min() - 34.0
	var x1: float = xs.max() + 34.0
	var y: float = BoardView.MARGIN - 6.0
	var deck := Rect2(x0, y - 8.0, x1 - x0, 8.0)
	for i in 3:
		var cx: float = x0 + (x1 - x0) * (i + 0.5) / 3.0
		l.draw_colored_polygon(PackedVector2Array([Vector2(cx - 14, y), Vector2(cx - 12, y + 8), Vector2(cx + 12, y + 8), Vector2(cx + 14, y)]), Color("34525f"))
	l.draw_rect(deck, STONE)
	l.draw_rect(deck, OL, false, 1.4)
	l.draw_rect(Rect2(x0, y - 12.0, x1 - x0, 4.0), Color("a09a8c"))
	l.draw_rect(Rect2(x0, y - 12.0, x1 - x0, 4.0), OL, false, 1.2)
	for i in 3:
		var cx2: float = x0 + (x1 - x0) * (i + 0.5) / 3.0
		l.draw_arc(Vector2(cx2, y), 12.0, 0.0, PI, 10, OL, 1.6)
	l.draw_line(Vector2(x0 - 4, y - 14), Vector2(x0 + 6, y - 14), STONE_D, 3.0)
	l.draw_line(Vector2(x1 - 6, y - 14), Vector2(x1 + 4, y - 14), STONE_D, 3.0)
