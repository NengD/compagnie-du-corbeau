class_name MapLife
extends RefCounted
## Carte vivante : caravanes sur les routes, fumée des villages, oiseaux, bateaux sur les rivières, colonnes et bannières des
## guerres de factions, traces de combat sur les villes du front. PUREMENT VISUEL : aucune règle, rien n'est sauvegardé, aucun
## tirage au sort (tout vient d'un hachage entier du jour et de l'indice : le même jour donne la même image).
## Les animations ne sont dessinées que si `animate` ; les colonnes de guerre et les traces restent visibles (information).

const OL := Color("17110c")
const MAX_CARAVANS := 12
const MAX_BOATS := 4
const MAX_FLOCKS := 3
const CARAVAN_SPEED := 9.0  ## px de monde par seconde
const BOAT_SPEED := 5.0
const SMOKE_PUFFS := 3

var _w: World = null
var _curves: Array = []
var _road_len: Array[float] = []
var _boats: Array = []  ## [{"pts": PackedVector2Array, "len": float}]
var _built: bool = false


## Hachage entier déterministe (pas de générateur : aucune dépendance à l'état de la partie).
static func hsh(a: int, b: int, c: int = 0) -> int:
	var x: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return x & 0x7fffffff


static func unit(a: int, b: int, c: int = 0) -> float:
	return float(hsh(a, b, c) % 10000) / 10000.0


## Va-et-vient : position le long d'un tronçon de longueur `length` (0..length..0).
static func pingpong(s: float, length: float) -> float:
	if length <= 0.0:
		return 0.0
	var m: float = fposmod(s, length * 2.0)
	return m if m <= length else length * 2.0 - m


## Point et direction à la distance `d` le long d'une ligne brisée : {"p": Vector2, "dir": Vector2}.
static func sample(pts: PackedVector2Array, d: float) -> Dictionary:
	var left: float = d
	for i in pts.size() - 1:
		var seg: float = pts[i].distance_to(pts[i + 1])
		if left <= seg or i == pts.size() - 2:
			var k: float = clampf(left / maxf(seg, 0.001), 0.0, 1.0)
			return {"p": pts[i].lerp(pts[i + 1], k), "dir": (pts[i + 1] - pts[i]).normalized()}
		left -= seg
	return {"p": pts[0] if not pts.is_empty() else Vector2.ZERO, "dir": Vector2.RIGHT}


static func line_length(pts: PackedVector2Array) -> float:
	var n: float = 0.0
	for i in pts.size() - 1:
		n += pts[i].distance_to(pts[i + 1])
	return n


## À appeler quand le monde ou ses routes changent (reconstruction de la carte).
func setup(w: World, curves: Array) -> void:
	_w = w
	_curves = curves
	_road_len.clear()
	for c in curves:
		_road_len.append(line_length(PackedVector2Array(c["c"])))
	_boats = _find_boats(w)
	_built = true


## Rivières : chaînes de cases d'eau choisies par hachage (positions stables pour un monde donné).
static func _find_boats(w: World) -> Array:
	var out: Array = []
	if w == null or w.terrain.size() != w.gw * w.gh:
		return out
	var tries: int = 0
	while tries < 160 and out.size() < MAX_BOATS:
		var idx: int = hsh(tries, w.gw, 17) % (w.gw * w.gh)
		tries += 1
		if w.terrain[idx] != World.T.WATER:
			continue
		var start := Vector2i(idx % w.gw, idx / w.gw)
		var chain: Array[Vector2i] = _walk_water(w, start, hsh(tries, 5))
		if chain.size() < 8:
			continue
		var pts := PackedVector2Array()
		for c in chain:
			pts.append((Vector2(c) + Vector2(0.5, 0.5)) * World.CELL)
		var near: bool = false
		for b in out:
			if (b["pts"] as PackedVector2Array)[0].distance_to(pts[0]) < 260.0:
				near = true
		if not near:
			out.append({"pts": pts, "len": line_length(pts)})
	return out


static func _walk_water(w: World, start: Vector2i, salt: int) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var chain: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var dir: Vector2i = dirs[salt % 4]
	var cur: Vector2i = start
	for _i in 18:
		var next := Vector2i(-1, -1)
		var order: Array[Vector2i] = [dir, Vector2i(-dir.y, dir.x), Vector2i(dir.y, -dir.x)]  # tout droit d'abord, puis les côtés
		for d in order:
			var q: Vector2i = cur + d
			if q.x < 0 or q.y < 0 or q.x >= w.gw or q.y >= w.gh or seen.has(q):
				continue
			if w.terrain[q.y * w.gw + q.x] == World.T.WATER:
				next = q
				dir = d
				break
		if next.x < 0:
			break
		seen[next] = true
		chain.append(next)
		cur = next
	return chain


# --- Calcul des positions (testable sans dessin) ---

## Caravanes du jour : [{"p": Vector2, "dir": Vector2, "road": int}]. Une route sur deux environ en porte une, changeant tous les 2 jours.
func caravans(day: int, t: float) -> Array:
	var out: Array = []
	for i in _curves.size():
		if out.size() >= MAX_CARAVANS:
			break
		var length: float = _road_len[i] if i < _road_len.size() else 0.0
		if length < 80.0:
			continue
		var h: int = hsh(day / 2, i, 3)
		if h % 100 >= 55:
			continue
		var phase: float = float(h % 1000) / 1000.0 * length
		var d: float = pingpong(phase + t * CARAVAN_SPEED, length)
		var fwd: bool = fposmod(phase + t * CARAVAN_SPEED, length * 2.0) <= length
		var s: Dictionary = sample(PackedVector2Array(_curves[i]["c"]), d)
		var dir: Vector2 = s["dir"] if fwd else -(s["dir"] as Vector2)
		out.append({"p": s["p"], "dir": dir, "road": i})
	return out


func boats(day: int, t: float) -> Array:
	var out: Array = []
	for i in _boats.size():
		if hsh(day / 3, i, 9) % 100 >= 75:
			continue
		var pts: PackedVector2Array = _boats[i]["pts"]
		var length: float = _boats[i]["len"]
		var phase: float = unit(day / 3, i, 4) * length
		var s: Dictionary = sample(pts, pingpong(phase + t * BOAT_SPEED, length))
		var fwd: bool = fposmod(phase + t * BOAT_SPEED, length * 2.0) <= length
		out.append({"p": s["p"], "dir": s["dir"] if fwd else -(s["dir"] as Vector2)})
	return out


## Volées d'oiseaux : [{"c": centre, "r": rayon, "n": nombre}] ; chaque volée tourne autour d'un lieu choisi par hachage.
func flocks(day: int) -> Array:
	var out: Array = []
	if _w == null or _w.settlements.is_empty():
		return out
	for i in MAX_FLOCKS:
		var s: Dictionary = _w.settlements[hsh(day / 4, i, 21) % _w.settlements.size()]
		out.append({"c": _w.settlement_pos(s) + Vector2(0, -30), "r": 26.0 + 18.0 * unit(day / 4, i, 22), "n": 3 + hsh(day, i, 23) % 3, "i": i})
	return out


## Colonnes de guerre : [{"p": Vector2, "dir": Vector2, "faction": String, "front": Vector2}] (deux par guerre : une par camp).
func war_columns(war_pairs: Array, t: float) -> Array:
	var out: Array = []
	if _w == null:
		return out
	for pr in war_pairs:
		var best: float = 1e12
		var pa := Vector2.ZERO
		var pb := Vector2.ZERO
		for s in _w.settlements:
			if str(s.get("owner", "")) != str(pr[0]):
				continue
			for u in _w.settlements:
				if str(u.get("owner", "")) != str(pr[1]):
					continue
				var d: float = _w.settlement_pos(s).distance_to(_w.settlement_pos(u))
				if d < best:
					best = d
					pa = _w.settlement_pos(s)
					pb = _w.settlement_pos(u)
		if best >= 1e11:
			continue
		var axis: Vector2 = (pb - pa).normalized()
		var sw: float = 0.5 + 0.5 * sin(t * 0.05 + float(hsh(int(pa.x), int(pb.y)) % 100))  # lent va-et-vient
		var ka: float = 0.2 + 0.12 * sw
		var kb: float = 0.8 - 0.12 * sw
		out.append({"p": pa.lerp(pb, ka), "dir": axis, "faction": str(pr[0]), "front": pa.lerp(pb, 0.5)})
		out.append({"p": pa.lerp(pb, kb), "dir": -axis, "faction": str(pr[1]), "front": pa.lerp(pb, 0.5)})
	return out


## Lieux du front : lieux dont le maître est en guerre et qui sont proches d'une ville de l'ennemi (traces de combat).
func front_places(war_pairs: Array) -> Array:
	var out: Array = []
	if _w == null:
		return out
	for s in _w.settlements:
		var o: String = str(s.get("owner", ""))
		for pr in war_pairs:
			var foe: String = ""
			if o == str(pr[0]):
				foe = str(pr[1])
			elif o == str(pr[1]):
				foe = str(pr[0])
			if foe == "":
				continue
			for u in _w.settlements:
				if str(u.get("owner", "")) == foe and _w.settlement_pos(s).distance_to(_w.settlement_pos(u)) < 330.0:
					if not out.has(s):
						out.append(s)
	return out


# --- Dessin ---

## `view` : rectangle de monde visible ; `k` : échelle des pictogrammes ; `war_pairs` : `Wars.pairs(Game.extras)`.
func paint(l: CanvasItem, view: Rect2, k: float, day: int, t: float, animate: bool, war_pairs: Array) -> void:
	if not _built or _w == null:
		return
	var f: float = Quality.particle_factor()
	# traces et colonnes de guerre : toujours visibles (une information), même sans animation
	for s in front_places(war_pairs):
		var p: Vector2 = _w.settlement_pos(s)
		if view.grow(40.0).has_point(p):
			_paint_scars(l, p, k, s["kind"] == "city", t, animate)
	for col in war_columns(war_pairs, t if animate else 0.0):
		if view.grow(40.0).has_point(col["p"]):
			_paint_column(l, col, k, t, animate)
	if not animate:
		return
	for c in caravans(day, t):
		if view.grow(20.0).has_point(c["p"]):
			_paint_caravan(l, c["p"], c["dir"], k * 1.5, t)
	for b in boats(day, t):
		if view.grow(20.0).has_point(b["p"]):
			_paint_boat(l, b["p"], b["dir"], k * 1.4, t)
	if f <= 0.0:
		return
	for s in _w.settlements:
		if s["kind"] == "city":
			continue
		var sp: Vector2 = _w.settlement_pos(s)
		if view.grow(30.0).has_point(sp):
			_paint_smoke(l, sp + Vector2(7.0, -9.0) * k, k, t, int(sp.x) + int(sp.y) * 7, mini(SMOKE_PUFFS, maxi(1, roundi(SMOKE_PUFFS * f))), Color(0.78, 0.76, 0.72))
	for fl in flocks(day):
		if view.grow(80.0).has_point(fl["c"]):
			_paint_flock(l, fl, k, t)


static func _paint_smoke(l: CanvasItem, base: Vector2, k: float, t: float, seed_i: int, n: int, col: Color) -> void:
	for j in n:
		var ph: float = fposmod(t * 0.22 + float(j) / float(n) + float(seed_i % 17) * 0.06, 1.0)
		var p: Vector2 = base + Vector2(sin(ph * 5.0 + float(seed_i)) * 2.0 + ph * 5.0, -ph * 20.0) * k
		l.draw_circle(p, (1.2 + ph * 2.6) * k, Color(col.r, col.g, col.b, 0.5 * (1.0 - ph)))


static func _paint_caravan(l: CanvasItem, p: Vector2, dir: Vector2, k: float, t: float) -> void:
	var back: Vector2 = -dir * 5.0 * k
	var bob: Vector2 = Vector2(0, -absf(sin(t * 6.0 + p.x)) * 0.5 * k)
	# cheval puis chariot bâché
	var horse: Vector2 = p + bob
	l.draw_circle(horse + Vector2(0, 1.2 * k), 2.0 * k, Color(0, 0, 0, 0.2))
	l.draw_circle(horse, 1.7 * k, Color("5b3d26"))
	l.draw_circle(horse + dir * 1.6 * k + Vector2(0, -0.8 * k), 1.0 * k, Color("4a3020"))
	var cart: Vector2 = p + back * 1.6
	l.draw_circle(cart + Vector2(0, 1.2 * k), 2.6 * k, Color(0, 0, 0, 0.2))
	l.draw_rect(Rect2(cart + Vector2(-2.6, -2.8) * k, Vector2(5.2, 3.2) * k), Color("e6dcc0"))
	l.draw_rect(Rect2(cart + Vector2(-2.6, -2.8) * k, Vector2(5.2, 3.2) * k), OL, false, 0.8 * k)
	l.draw_circle(cart + Vector2(-1.6, 0.6) * k, 0.9 * k, OL)
	l.draw_circle(cart + Vector2(1.6, 0.6) * k, 0.9 * k, OL)
	l.draw_line(horse, cart, OL, 0.7 * k)


static func _paint_boat(l: CanvasItem, p: Vector2, dir: Vector2, k: float, t: float) -> void:
	var bob: float = sin(t * 1.6 + p.x * 0.1) * 0.6 * k
	var o: Vector2 = p + Vector2(0, bob)
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var hull := PackedVector2Array([o + dir * 5.0 * k, o + side * 2.0 * k - dir * 4.0 * k, o - side * 2.0 * k - dir * 4.0 * k])
	l.draw_circle(o + Vector2(0, 1.5 * k), 3.6 * k, Color(1, 1, 1, 0.12))
	l.draw_colored_polygon(hull, Color("6d4a2c"))
	l.draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[0]]), OL, 0.8 * k)
	l.draw_line(o, o + Vector2(0, -7.0 * k), OL, 0.9 * k)
	l.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -7.0 * k), o + Vector2(0, -1.0 * k) + dir * 3.2 * k, o + Vector2(0, -1.0 * k) - dir * 2.0 * k]), Color("e6dcc0"))


static func _paint_flock(l: CanvasItem, fl: Dictionary, k: float, t: float) -> void:
	var n: int = int(fl["n"])
	for j in n:
		var a: float = t * 0.35 + float(j) * 0.55 + float(int(fl["i"])) * 2.1
		var p: Vector2 = (fl["c"] as Vector2) + Vector2(cos(a), sin(a) * 0.55) * float(fl["r"]) * k
		var flap: float = sin(t * 9.0 + float(j) * 1.7) * 1.4 * k
		var w: float = 2.6 * k
		l.draw_polyline(PackedVector2Array([p + Vector2(-w, flap), p, p + Vector2(w, flap)]), Color(0.1, 0.08, 0.07, 0.75), 0.9 * k)


static func _paint_column(l: CanvasItem, col: Dictionary, k: float, t: float, animate: bool) -> void:
	var p: Vector2 = col["p"]
	var dir: Vector2 = col["dir"]
	var c: Color = MapPlaces.faction_color(str(col["faction"]))
	var pulse: float = 0.5 + 0.5 * sin(t * 3.0) if animate else 0.5
	l.draw_arc(p, (11.0 + pulse * 3.0) * k, 0.0, TAU, 20, Color(0.78, 0.16, 0.12, 0.35 + 0.25 * pulse), 1.4 * k, true)
	var side := Vector2(-dir.y, dir.x)
	for j in 5:
		var q: Vector2 = p - dir * float(j) * 3.0 * k + side * (float(j % 2) - 0.5) * 3.0 * k
		var step: float = sin(t * 5.0 + float(j) * 1.3) * 0.4 * k if animate else 0.0
		l.draw_circle(q + Vector2(0, 0.8 * k), 1.3 * k, Color(0, 0, 0, 0.22))
		l.draw_circle(q + Vector2(0, -step), 1.3 * k, c.darkened(0.15))
		l.draw_line(q + Vector2(0.8, 0.0) * k, q + Vector2(0.8, -5.0) * k, OL, 0.7 * k)
	var pole: Vector2 = p + Vector2(0, -2.0 * k)
	l.draw_line(pole, pole + Vector2(0, -10.0 * k), OL, 1.1 * k)
	var wave: float = sin(t * 4.0) * 1.2 * k if animate else 0.0
	l.draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -10.0 * k), pole + Vector2(5.0 * k, -8.5 * k + wave), pole + Vector2(0, -6.0 * k)]), c)


static func _paint_scars(l: CanvasItem, p: Vector2, k: float, city: bool, t: float, animate: bool) -> void:
	var r: float = (20.0 if city else 12.0) * k
	for j in 3:
		var a: float = float(j) * 2.1 + 0.6
		var q: Vector2 = p + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.5 - 2.0 * k)
		l.draw_circle(q, 3.4 * k, Color(0.07, 0.05, 0.04, 0.4))
		l.draw_line(q + Vector2(-2.0, -1.0) * k, q + Vector2(2.0, 1.2) * k, Color(0.05, 0.04, 0.03, 0.6), 0.9 * k)
	if animate:
		_paint_smoke(l, p + Vector2(r * 0.4, -4.0 * k), k, t, int(p.x), 3, Color(0.25, 0.22, 0.2))
