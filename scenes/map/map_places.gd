class_name MapPlaces
extends RefCounted
## Lieux de la carte du monde : villes fortifiées, villages (champs, moulin), forts hostiles, bannières de faction,
## territoires (zones par plus proche propriétaire, frontières en pointillés), marqueurs des bandes et de la compagnie.

const OL := Color("17110c")


static func hf(x: int, y: int, k: int = 0) -> float:
	return MapTerrain.hf(x, y, k)


static func _poly(l: CanvasItem, pts: PackedVector2Array, col: Color, outline: bool = true) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	l.draw_colored_polygon(pts, col)
	if outline:
		var ring := PackedVector2Array(pts)
		ring.append(pts[0])
		l.draw_polyline(ring, OL, 1.1)


## Échelle courante des dessins de lieux (voir `begin_scaled`) : les ellipses recomposent leur transformation avec elle.
static var _bpos: Vector2 = Vector2.ZERO
static var _bk: float = 1.0


static func _ellipse(l: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	l.draw_set_transform(_bpos + c * _bk, 0.0, Vector2(_bk, _bk * ry / rx))
	l.draw_circle(Vector2.ZERO, rx, col)
	l.draw_set_transform(_bpos, 0.0, Vector2(_bk, _bk))


## Dessine ce qui suit autour de `p` à l'échelle `k` : appeler les fonctions `paint_*` avec `Vector2.ZERO` comme position.
static func begin_scaled(l: CanvasItem, p: Vector2, k: float) -> void:
	_bpos = p
	_bk = k
	l.draw_set_transform(p, 0.0, Vector2(k, k))


static func end_scaled(l: CanvasItem) -> void:
	_bpos = Vector2.ZERO
	_bk = 1.0
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Villes et villages ---

## Dessine le lieu ; ajoute à `lights` ses fenêtres et torches : {"p": Vector2, "k": "win"|"torch"}.
## `k` : échelle du dessin (1 = taille d'origine). Une capitale est dessinée plus grande (`CAPITAL_K`).
static func paint_settlement(l: CanvasItem, s: Dictionary, p: Vector2, lights: Array, k: float = 1.0) -> void:
	var seed_i: int = int(p.x) * 31 + int(p.y)
	var kk: float = k * settlement_k(s)
	if is_equal_approx(kk, 1.0):
		if s["kind"] == "city":
			_city(l, p, lights)
		else:
			_village(l, p, seed_i, lights)
		return
	var local: Array = []
	begin_scaled(l, p, kk)
	if s["kind"] == "city":
		_city(l, Vector2.ZERO, local)
	else:
		_village(l, Vector2.ZERO, seed_i, local)
	end_scaled(l)
	for e in local:
		lights.append({"p": p + (e["p"] as Vector2) * kk, "k": e["k"]})


const CAPITAL_K: float = 1.3


## Agrandissement propre au lieu (capitale de faction : plus grande, avec ses étendards).
static func settlement_k(s: Dictionary) -> float:
	return CAPITAL_K if bool(s.get("capital", false)) else 1.0


static func _win(l: CanvasItem, lights: Array, at: Vector2) -> void:
	l.draw_rect(Rect2(at - Vector2(1.0, 1.2), Vector2(2.0, 2.6)), Color(0.36, 0.26, 0.12))
	lights.append({"p": at, "k": "win"})


static func _city(l: CanvasItem, p: Vector2, lights: Array) -> void:
	_ellipse(l, p + Vector2(0, 14), 38, 9, Color(0, 0, 0, 0.32))
	# toits des maisons visibles derrière le rempart
	for i in 7:
		var hx: float = -20.0 + i * 6.8
		var top: float = -11.0 - (i % 3) * 3.0
		_poly(l, PackedVector2Array([p + Vector2(hx - 4.5, top + 5), p + Vector2(hx, top - 3), p + Vector2(hx + 4.5, top + 5)]), Color("8a4a30") if i % 2 == 0 else Color("7a5a3a"))
	# rempart
	var wall := Rect2(p + Vector2(-26, -5), Vector2(52, 18))
	l.draw_rect(wall, Color("a39a86"))
	l.draw_rect(Rect2(wall.position + Vector2(0, 10), Vector2(wall.size.x, 8)), Color("857d6b"))
	l.draw_rect(wall, OL, false, 1.4)
	for i in 11:
		var cx: float = -26.0 + i * 5.0
		l.draw_rect(Rect2(p + Vector2(cx, -8.5), Vector2(3.2, 3.6)), Color("b4ab96"))
		l.draw_rect(Rect2(p + Vector2(cx, -8.5), Vector2(3.2, 3.6)), OL, false, 0.8)
	for i in 5:  # appareil de pierre
		l.draw_line(p + Vector2(-24 + i * 10, 2), p + Vector2(-20 + i * 10, 2), Color(0.35, 0.31, 0.25, 0.5), 0.8)
		l.draw_line(p + Vector2(-19 + i * 10, 7), p + Vector2(-15 + i * 10, 7), Color(0.35, 0.31, 0.25, 0.5), 0.8)
	# tours d'angle
	for tx in [-29.0, 29.0]:
		var tr := Rect2(p + Vector2(tx - 5.5, -14), Vector2(11, 27))
		l.draw_rect(tr, Color("b0a790"))
		l.draw_rect(Rect2(tr.position + Vector2(6, 0), Vector2(5, 27)), Color("8c8471"))
		l.draw_rect(tr, OL, false, 1.3)
		_poly(l, PackedVector2Array([p + Vector2(tx - 7.5, -14), p + Vector2(tx, -27), p + Vector2(tx + 7.5, -14)]), Color("9a3a2c"))
		_win(l, lights, p + Vector2(tx, -6))
	# donjon et clocher
	var keep := Rect2(p + Vector2(-7, -26), Vector2(14, 22))
	l.draw_rect(keep, Color("b8af98"))
	l.draw_rect(Rect2(keep.position + Vector2(8, 0), Vector2(6, 22)), Color("918874"))
	l.draw_rect(keep, OL, false, 1.4)
	_poly(l, PackedVector2Array([p + Vector2(-9.5, -26), p + Vector2(0, -38), p + Vector2(9.5, -26)]), Color("8a2e24"))
	_win(l, lights, p + Vector2(-2.5, -19))
	_win(l, lights, p + Vector2(3.0, -13))
	l.draw_rect(Rect2(p + Vector2(-16, -22), Vector2(5, 14)), Color("a89f8a"))
	l.draw_rect(Rect2(p + Vector2(-16, -22), Vector2(5, 14)), OL, false, 1.1)
	_poly(l, PackedVector2Array([p + Vector2(-17.5, -22), p + Vector2(-13.5, -32), p + Vector2(-9.5 - 1.0, -22)]), Color("5a4a40"))
	# porte
	l.draw_rect(Rect2(p + Vector2(-4.5, 4), Vector2(9, 9)), Color("241a12"))
	l.draw_arc(p + Vector2(0, 4), 4.5, PI, TAU, 8, Color("241a12"), 2.0, true)
	lights.append({"p": p + Vector2(-8, 3), "k": "torch"})
	lights.append({"p": p + Vector2(8, 3), "k": "torch"})
	for tp in [p + Vector2(-8, 3), p + Vector2(8, 3)]:
		l.draw_line(tp, tp + Vector2(0, 6), Color("3b2c1a"), 1.4)


static func _village(l: CanvasItem, p: Vector2, seed_i: int, lights: Array) -> void:
	_ellipse(l, p + Vector2(0, 9), 26, 7, Color(0, 0, 0, 0.26))
	# champs en patchwork
	var fields: Array = [[Vector2(-34, 10), Vector2(18, 10), 0.18, Color("b79f4a"), Color("8f7a34")], [Vector2(-22, 20), Vector2(24, 9), -0.12, Color("7f9a47"), Color("5f7a33")],
		[Vector2(14, 14), Vector2(18, 11), 0.1, Color("a6a14a"), Color("807c34")]]
	for f in fields:
		var o: Vector2 = p + f[0]
		var sz: Vector2 = f[1]
		var rot: float = f[2]
		var pts := PackedVector2Array()
		for c in [Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(0, sz.y)]:
			pts.append(o + (c - sz * 0.5).rotated(rot) + sz * 0.5)
		_poly(l, pts, f[3])
		for k in 4:
			var a: Vector2 = o + (Vector2(2, sz.y * (k + 0.5) / 4.0) - sz * 0.5).rotated(rot) + sz * 0.5
			var b: Vector2 = o + (Vector2(sz.x - 2, sz.y * (k + 0.5) / 4.0) - sz * 0.5).rotated(rot) + sz * 0.5
			l.draw_line(a, b, f[4], 1.0)
	# maisons
	var spots: Array[Vector2] = [Vector2(-12, 0), Vector2(2, -3), Vector2(-2, 6), Vector2(-20, 5), Vector2(10, 4)]
	for i in spots.size():
		var b: Vector2 = p + spots[i]
		var wd: float = 9.0 + hf(seed_i, i, 3) * 3.0
		l.draw_rect(Rect2(b + Vector2(-wd * 0.5, -3), Vector2(wd, 8)), Color("b7946a"))
		l.draw_rect(Rect2(b + Vector2(-wd * 0.5, -3), Vector2(wd, 8)), OL, false, 1.0)
		var roof: Color = Color("8a6a3a") if i % 2 == 0 else Color("7a4a32")
		_poly(l, PackedVector2Array([b + Vector2(-wd * 0.5 - 1.5, -3), b + Vector2(0, -10), b + Vector2(wd * 0.5 + 1.5, -3)]), roof)
		_win(l, lights, b + Vector2(1.5, 0.5))
	# moulin
	var m: Vector2 = p + Vector2(20, -2)
	_poly(l, PackedVector2Array([m + Vector2(-5, 8), m + Vector2(-3, -10), m + Vector2(3, -10), m + Vector2(5, 8)]), Color("c4b79a"))
	_poly(l, PackedVector2Array([m + Vector2(-4.5, -10), m + Vector2(0, -16), m + Vector2(4.5, -10)]), Color("7a4a32"))
	l.draw_rect(Rect2(m + Vector2(-1.5, 2), Vector2(3, 6)), Color("2a2118"))
	lights.append({"p": p + Vector2(-5, 7), "k": "torch"})
	l.draw_line(p + Vector2(-5, 7), p + Vector2(-5, 12), Color("3b2c1a"), 1.3)


## Moyeu du moulin d'un village (pour les ailes animées), ou Vector2.ZERO pour une ville.
static func windmill_hub(s: Dictionary, p: Vector2, k: float = 1.0) -> Vector2:
	return p + Vector2(20, -9) * k if s["kind"] != "city" else Vector2.ZERO


static func paint_blades(l: CanvasItem, hub: Vector2, ang: float, k: float = 1.0) -> void:
	for i in 4:
		var a: float = ang + PI * 0.5 * i
		var d := Vector2(cos(a), sin(a)) * k
		var n := d.orthogonal()
		l.draw_line(hub, hub + d * 9.0, OL, 2.2 * k)
		_poly(l, PackedVector2Array([hub + d * 3.0 + n * 0.5, hub + d * 9.0 + n * 0.5, hub + d * 9.0 + n * 3.4, hub + d * 3.0 + n * 3.4]), Color("d9cfb4"), true)
	l.draw_circle(hub, 1.8 * k, OL)


static func paint_label(l: CanvasItem, s: Dictionary, p: Vector2, font: Font) -> void:
	var city: bool = s["kind"] == "city"
	var size: int = 28 if city else 22
	var at: Vector2 = p + Vector2(-90, 36 if city else 30)
	l.draw_string_outline(font, at, str(s["name"]), HORIZONTAL_ALIGNMENT_CENTER, 180, size, 6, Color("120f0c"))
	l.draw_string(font, at, str(s["name"]), HORIZONTAL_ALIGNMENT_CENTER, 180, size, GameTheme.INK)
	if Visits.day_of(s) > 0:
		paint_visited_mark(l, p + Vector2(34 if city else 26, -14))


## Pastille verte « lieu déjà visité ».
static func paint_visited_mark(l: CanvasItem, vp: Vector2, k: float = 1.0) -> void:
	l.draw_circle(vp, 6.5 * k, OL)
	l.draw_circle(vp, 5.2 * k, Color("8aa05a"))
	l.draw_polyline(PackedVector2Array([vp + Vector2(-2.6, 0.2) * k, vp + Vector2(-0.6, 2.4) * k, vp + Vector2(2.8, -2.2) * k]), OL, 1.6 * k, true)


## Drapeau rouge planté sur le lieu du contrat, cerclé d'un anneau qui pulse (`pulse` de 0 à 1).
static func paint_contract_flag(l: CanvasItem, tp: Vector2, pulse: float) -> void:
	l.draw_arc(tp, 16.0 + pulse * 5.0, 0.0, TAU, 28, Color(0.8, 0.25, 0.2, 0.7 - pulse * 0.4), 2.0, true)
	l.draw_line(tp, tp + Vector2(0, -26), OL, 3.0)
	l.draw_line(tp, tp + Vector2(0, -26), Color("c9c2b2"), 1.5)
	var flag := PackedVector2Array([tp + Vector2(0, -26), tp + Vector2(14, -21), tp + Vector2(0, -16)])
	l.draw_colored_polygon(flag, Color("b03a2e"))
	l.draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), OL, 1.0)


# --- Bannières ---

static func _hex(s: Variant, fallback: Color) -> Color:
	var str_: String = str(s)
	return Color(str_) if str_.length() == 6 and str_.is_valid_hex_number(false) else fallback


## Étendard planté en `base` : mât, étoffe qui flotte, emblème (index de Data.BANNER_EMBLEMS, dessiné par forme simple).
static func paint_banner(l: CanvasItem, base: Vector2, banner: Dictionary, t: float, animate: bool, k: float = 1.0) -> void:
	var prim: Color = _hex(banner.get("primary", ""), Color("a33a2c"))
	var sec: Color = _hex(banner.get("secondary", ""), Color("d8cfb8"))
	var h: float = 18.0 * k
	l.draw_line(base, base + Vector2(0, -h), OL, 2.6 * k)
	l.draw_line(base, base + Vector2(0, -h), Color("c9c2b2"), 1.2 * k)
	l.draw_circle(base + Vector2(0, -h - 1), 1.4 * k, Color("d9b84a"))
	var top: Vector2 = base + Vector2(0, -h + 1.0)
	var wid: float = 12.0 * k
	var hei: float = 9.0 * k
	var up := PackedVector2Array()
	var dn := PackedVector2Array()
	for i in 6:
		var u: float = float(i) / 5.0
		var wave: float = sin(t * 4.0 - u * 3.5) * 1.6 * u * k if animate else u * 0.6
		up.append(top + Vector2(u * wid, wave))
		dn.append(top + Vector2(u * wid, hei + wave))
	var cloth := PackedVector2Array(up)
	var rev := PackedVector2Array(dn)
	rev.reverse()
	cloth.append_array(rev)
	_poly(l, cloth, prim)
	var cen: Vector2 = (up[2] + dn[2]) * 0.5
	var r: float = 2.4 * k
	match int(banner.get("emblem", 0)) % 6:
		0:
			l.draw_circle(cen, r, sec)
		1:
			l.draw_line(cen + Vector2(-r, 0), cen + Vector2(r, 0), sec, 1.4 * k)
			l.draw_line(cen + Vector2(0, -r), cen + Vector2(0, r), sec, 1.4 * k)
		2:
			l.draw_colored_polygon(PackedVector2Array([cen + Vector2(0, -r), cen + Vector2(r, 0), cen + Vector2(0, r), cen + Vector2(-r, 0)]), sec)
		3:
			l.draw_polyline(PackedVector2Array([cen + Vector2(-r, r * 0.6), cen + Vector2(0, -r * 0.7), cen + Vector2(r, r * 0.6)]), sec, 1.5 * k)
		4:
			l.draw_line(cen + Vector2(-r, -r), cen + Vector2(r, r), sec, 1.3 * k)
			l.draw_line(cen + Vector2(-r, r), cen + Vector2(r, -r), sec, 1.3 * k)
		_:
			l.draw_rect(Rect2(cen + Vector2(-r, -r * 0.4), Vector2(r * 2.0, r * 0.8)), sec)


# --- Territoires ---

static func _clip(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	# garde les points plus proches de `a` que de `b`
	var out := PackedVector2Array()
	var mid: Vector2 = (a + b) * 0.5
	var nrm: Vector2 = b - a
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		var dp: float = (p - mid).dot(nrm)
		var dq: float = (q - mid).dot(nrm)
		if dp <= 0.0:
			out.append(p)
		if (dp < 0.0 and dq > 0.0) or (dp > 0.0 and dq < 0.0):
			out.append(p.lerp(q, dp / (dp - dq)))
	return out


## Zones par plus proche propriétaire : {"cells": [{"owner", "poly"}], "edges": [{"a","b","oa","ob","line"}]} (rien sans propriétaires).
static func territories(w: World) -> Dictionary:
	var owned: Array[Dictionary] = []
	for s in w.settlements:
		if str(s.get("owner", "")) != "":
			owned.append(s)
	var res: Dictionary = {"cells": [], "edges": []}
	if owned.size() < 1:
		return res
	var noise_x := FastNoiseLite.new()
	noise_x.seed = 31
	noise_x.frequency = 0.012
	var noise_y := FastNoiseLite.new()
	noise_y.seed = 47
	noise_y.frequency = 0.012
	var rect := PackedVector2Array([Vector2.ZERO, Vector2(w.size.x, 0), w.size, Vector2(0, w.size.y)])
	var polys: Array[PackedVector2Array] = []
	for i in owned.size():
		var poly: PackedVector2Array = rect
		var pi: Vector2 = w.settlement_pos(owned[i])
		for j in owned.size():
			if j != i and poly.size() > 2:
				poly = _clip(poly, pi, w.settlement_pos(owned[j]))
		polys.append(poly)
	var wob := func(v: Vector2) -> Vector2:
		if v.x < 1.0 or v.y < 1.0 or v.x > w.size.x - 1.0 or v.y > w.size.y - 1.0:
			return v
		return v + Vector2(noise_x.get_noise_2d(v.x, v.y), noise_y.get_noise_2d(v.x, v.y)) * 34.0
	var sub := func(a: Vector2, b: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		var n: int = maxi(1, int(a.distance_to(b) / 12.0))
		for k in n:
			out.append(wob.call(a.lerp(b, float(k) / n)))
		return out
	for i in owned.size():
		var poly: PackedVector2Array = polys[i]
		if poly.size() < 3:
			continue
		var wp := PackedVector2Array()
		for k in poly.size():
			wp.append_array(sub.call(poly[k], poly[(k + 1) % poly.size()]))
		res["cells"].append({"owner": str(owned[i]["owner"]), "poly": wp})
		for j in range(i + 1, owned.size()):
			if str(owned[j]["owner"]) == str(owned[i]["owner"]):
				continue
			var a: Vector2 = w.settlement_pos(owned[i])
			var b: Vector2 = w.settlement_pos(owned[j])
			var mid: Vector2 = (a + b) * 0.5
			var nrm: Vector2 = (b - a).normalized()
			var on: Array[Vector2] = []
			for v in poly:
				if absf((v - mid).dot(nrm)) < 0.5:
					on.append(v)
			if on.size() >= 2:
				var line: PackedVector2Array = sub.call(on[0], on[on.size() - 1])
				line.append(wob.call(on[on.size() - 1]))
				res["edges"].append({"oa": str(owned[i]["owner"]), "ob": str(owned[j]["owner"]), "line": line})
	return res


## Data.FACTIONS (fournies par la session « compagnie ») lues sans dépendre du nom d'autoload : {} si absentes.
static func _factions() -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {}
	var d: Node = tree.root.get_node_or_null("/root/Data")
	return d.get("FACTIONS") if d != null else {}


static func faction_color(owner: String) -> Color:
	var fs: Variant = _factions()
	if typeof(fs) == TYPE_DICTIONARY and (fs as Dictionary).has(owner):
		return (fs as Dictionary)[owner].get("color", Color.WHITE)
	return Color.WHITE


static func faction_name(owner: String) -> String:
	var fs: Variant = _factions()
	if typeof(fs) == TYPE_DICTIONARY and (fs as Dictionary).has(owner):
		return str((fs as Dictionary)[owner].get("n", owner))
	return ""


static func faction_banner(owner: String) -> Dictionary:
	var fs: Variant = _factions()
	if typeof(fs) == TYPE_DICTIONARY and (fs as Dictionary).has(owner):
		var b: Variant = (fs as Dictionary)[owner].get("banner", {})
		if typeof(b) == TYPE_DICTIONARY:
			return b
	return {}


static func paint_territories(l: CanvasItem, terr: Dictionary) -> void:
	for c in terr["cells"]:
		var col: Color = faction_color(str(c["owner"]))
		_poly(l, c["poly"], Color(col.r, col.g, col.b, 0.17), false)
	for e in terr["edges"]:
		var ca: Color = faction_color(str(e["oa"]))
		var cb: Color = faction_color(str(e["ob"]))
		var line: PackedVector2Array = e["line"]
		var run: float = 0.0
		for i in line.size() - 1:
			var seg: float = line[i].distance_to(line[i + 1])
			if int(run / 7.0) % 2 == 0:
				l.draw_line(line[i], line[i + 1], Color(0.16, 0.11, 0.07, 0.75), 2.0)
				l.draw_line(line[i], line[i + 1], ca.lerp(cb, 0.5).lightened(0.2), 0.8)
			run += seg


## Nom de chaque faction en lettres espacées, au centre de son territoire.
static func paint_territory_names(l: CanvasItem, terr: Dictionary, w: World, font: Font) -> void:
	var acc: Dictionary = {}
	for c in terr["cells"]:
		var poly: PackedVector2Array = c["poly"]
		var area: float = absf(_area(poly))
		var cen := Vector2.ZERO
		for v in poly:
			cen += v
		cen /= float(poly.size())
		var d: Dictionary = acc.get(c["owner"], {"w": 0.0, "p": Vector2.ZERO})
		d["w"] = float(d["w"]) + area
		d["p"] = (d["p"] as Vector2) + cen * area
		acc[c["owner"]] = d
	for owner in acc:
		var nm: String = faction_name(str(owner)).to_upper()
		if nm == "":
			continue
		var d: Dictionary = acc[owner]
		var cp: Vector2 = (d["p"] as Vector2) / maxf(float(d["w"]), 1.0)
		cp = Vector2(clampf(cp.x, 140.0, w.size.x - 140.0), clampf(cp.y, 60.0, w.size.y - 60.0))
		for s in w.settlements:  # écarte le nom des lieux
			if w.settlement_pos(s).distance_to(cp) < 70.0:
				cp += (cp - w.settlement_pos(s)).normalized() * 55.0 if cp != w.settlement_pos(s) else Vector2(0, 60)
		var col: Color = faction_color(str(owner)).darkened(0.35)
		var size: int = 17
		var total: float = 0.0
		for ch in nm:
			total += font.get_char_size(ch.unicode_at(0), size).x + 7.0
		var x: float = cp.x - total * 0.5
		for ch in nm:
			var cw: float = font.get_char_size(ch.unicode_at(0), size).x
			var arc_y: float = pow((x + cw * 0.5 - cp.x) / 420.0, 2.0) * 60.0
			l.draw_char_outline(font, Vector2(x, cp.y + arc_y), ch, size, 3, Color(0.93, 0.88, 0.7, 0.35))
			l.draw_char(font, Vector2(x, cp.y + arc_y), ch, size, Color(col.r, col.g, col.b, 0.8))
			x += cw + 7.0


static func _area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


# --- Lieux hostiles ---

static func paint_site(l: CanvasItem, s: Dictionary, p: Vector2, col: Color, font: Font, t: float, animate: bool, with_label: bool = true) -> void:
	var seed_x: int = int(float(s.get("x", p.x)))  # graine stable même si `p` est l'origine d'un dessin mis à l'échelle
	var state: String = str(s["state"])
	var big: bool = s["kind"] == "citadel"
	var k: float = 1.45 if big else 1.0
	var fade: float = 1.0 if state == "hostile" else 0.6
	_ellipse(l, p + Vector2(0, 11 * k), 22 * k, 6 * k, Color(0, 0, 0, 0.4))
	if state == "hostile":
		var pulse: float = 0.5 + 0.5 * sin(t * (4.0 if big else 2.5)) if animate else 0.5
		l.draw_arc(p, (22.0 + pulse * 4.0) * k, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.5 - pulse * 0.3), 2.0, true)
	var wall: Color = Color("4a3e30") if s["kind"] != "necropolis" else Color("5c5f66")
	if s["kind"] == "lair":
		wall = Color("3e3220")
	wall = Color(wall.r, wall.g, wall.b, fade)
	# pieux et crânes
	for i in 7:
		var sx: float = (-18.0 + i * 6.0) * k
		var hh: float = (7.0 + hf(seed_x, i, 5) * 3.0) * k
		l.draw_line(p + Vector2(sx, 12 * k), p + Vector2(sx, 12 * k - hh), OL, 2.4)
		l.draw_line(p + Vector2(sx, 12 * k), p + Vector2(sx, 12 * k - hh), Color(0.42, 0.32, 0.2, fade), 1.2)
		if i % 3 == 1 and state == "hostile":
			var sk: Vector2 = p + Vector2(sx, 12 * k - hh - 2.0)
			l.draw_circle(sk, 2.8, OL)
			l.draw_circle(sk, 2.2, Color("d8d2c0"))
			l.draw_circle(sk + Vector2(-0.8, -0.2), 0.6, OL)
			l.draw_circle(sk + Vector2(0.8, -0.2), 0.6, OL)
	var base := Rect2(p + Vector2(-10, -9) * k, Vector2(20, 20) * k)
	l.draw_rect(base, wall)
	l.draw_rect(Rect2(base.position + Vector2(base.size.x * 0.55, 0), Vector2(base.size.x * 0.45, base.size.y)), Color(0, 0, 0, 0.25))
	l.draw_rect(base, OL, false, 1.5)
	for i in 3:
		var cx: float = (-10.0 + i * 7.0) * k
		var cren := Rect2(p + Vector2(cx, -14 * k), Vector2(5 * k, 5 * k))
		l.draw_rect(cren, wall)
		l.draw_rect(cren, OL, false, 1.0)
	l.draw_rect(Rect2(p + Vector2(-3, 3) * k, Vector2(6, 8) * k), Color("120d09"))
	if state == "hostile":
		var glow: float = 0.7 + 0.3 * sin(t * 7.0) if animate else 0.8
		l.draw_rect(Rect2(p + Vector2(-1.5, -4) * k, Vector2(3, 3.5) * k), Color(1.0, 0.45, 0.15, glow))
	if s["kind"] == "necropolis":
		l.draw_line(p + Vector2(0, -28), p + Vector2(0, -17), OL, 3.0)
		l.draw_line(p + Vector2(-4, -24), p + Vector2(4, -24), OL, 3.0)
	var flag_col: Color = col if state == "hostile" else (Color("4a7a9a") if state == "friendly" else Color("8a8f86"))
	var top: Vector2 = p + Vector2(0, -14 * k)
	l.draw_line(top, top + Vector2(0, -14 * k), OL, 3.0)
	var wv: float = sin(t * 5.0) * 1.2 if animate else 0.0
	var fl := PackedVector2Array([top + Vector2(0, -14 * k), top + Vector2(12 * k, -10 * k + wv), top + Vector2(0, -6 * k)])
	_poly(l, fl, flag_col)
	if not with_label:
		return
	var label: String = str(s["name"]) + (" ◆◆◆" if state == "hostile" else (" ✓" if state == "friendly" else ""))
	var lc: Color = col.lerp(Color.WHITE, 0.55) if state == "hostile" else Color(GameTheme.INK, 0.8)
	l.draw_string_outline(font, p + Vector2(-90, 30 * k), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 17, 5, Color("120f0c"))
	l.draw_string(font, p + Vector2(-90, 30 * k), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 17, lc)


# --- Bandes et compagnie ---

static func paint_party(l: CanvasItem, pp: Vector2, col: Color, label: String, font: Font, t: float, animate: bool, alpha: float, id: int) -> void:
	_ellipse(l, pp + Vector2(0, 6), 13, 4, Color(0, 0, 0, 0.35 * alpha))
	for i in 3:
		var o := Vector2((i - 1) * 6.0, 1.0 + (i % 2) * 2.0)
		var bob: float = absf(sin(t * 6.0 + float(i + id))) * 1.4 if animate else 0.0
		var b: Vector2 = pp + o - Vector2(0, bob)
		l.draw_line(b + Vector2(2.5, 3), b + Vector2(2.5, -12), Color(0.35, 0.28, 0.2, alpha), 1.0)
		l.draw_colored_polygon(PackedVector2Array([b + Vector2(-2.6, 4), b + Vector2(-1.8, -3), b + Vector2(1.8, -3), b + Vector2(2.6, 4)]), Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, alpha))
		l.draw_circle(b + Vector2(0, -5), 1.9, Color(0.82, 0.68, 0.5, alpha))
	var top: Vector2 = pp + Vector2(0, -8)
	l.draw_line(pp + Vector2(0, 3), top + Vector2(0, -12), Color(OL, alpha), 2.6)
	l.draw_line(pp + Vector2(0, 3), top + Vector2(0, -12), Color(0.79, 0.76, 0.7, alpha), 1.2)
	var wv: float = sin(t * 5.0 + id) * 1.4 if animate else 0.0
	var fl := PackedVector2Array([top + Vector2(0, -12), top + Vector2(12, -9 + wv), top + Vector2(7, -6.5 + wv * 0.5), top + Vector2(12, -3 + wv), top + Vector2(0, -3)])
	l.draw_colored_polygon(fl, Color(col, alpha))
	l.draw_polyline(PackedVector2Array([fl[0], fl[1], fl[2], fl[3], fl[4], fl[0]]), Color(OL, alpha), 1.0)
	l.draw_string_outline(font, pp + Vector2(-70, 19), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, 4, Color(0.07, 0.06, 0.05, alpha))
	l.draw_string(font, pp + Vector2(-70, 19), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(col.lerp(Color.WHITE, 0.55), alpha))


static func paint_company(l: CanvasItem, me: Vector2, banner: Dictionary, t: float, animate: bool, moving: bool, vision: float) -> void:
	l.draw_arc(me, vision, 0.0, TAU, 72, Color(1, 1, 1, 0.07), 1.5, true)
	var bob: float = absf(sin(t * 7.0)) * 2.0 if animate and moving else 0.0
	var pulse: float = 0.5 + 0.5 * sin(t * 2.5) if animate else 0.5
	l.draw_arc(me, 17.0 + pulse * 2.0, 0.0, TAU, 28, Color(GameTheme.GOLD, 0.35 - pulse * 0.2), 1.6, true)
	_ellipse(l, me + Vector2(0, 12), 14, 4, Color(0, 0, 0, 0.4))
	var c: Vector2 = me - Vector2(0, bob)
	l.draw_circle(c, 14.5, OL)
	l.draw_circle(c, 12.8, GameTheme.GOLD)
	l.draw_arc(c, 10.5, 0.0, TAU, 20, Color("8a6a20"), 1.0, true)
	var raven := PackedVector2Array([
		Vector2(-8, 3), Vector2(-4, -3), Vector2(1, -6), Vector2(5, -4), Vector2(10, -5), Vector2(6, -1),
		Vector2(5, 2), Vector2(8, 7), Vector2(1, 5), Vector2(-5, 7),
	])
	var moved := PackedVector2Array()
	for v in raven:
		moved.append(c + v)
	l.draw_colored_polygon(moved, Color("1c1915"))
	paint_banner(l, c + Vector2(-9, -8), banner, t, animate, 0.8)


# --- Territoires du grand monde (grille d'étiquettes de Territory) ---

## Texture de teinte des territoires : une case = un pixel (lissée à l'affichage). Les eaux ne sont pas teintées.
static func territory_image(w: World, lab: Dictionary, alpha: float = 0.2) -> Image:
	var n: int = int(lab["w"])
	var m: int = int(lab["h"])
	var img := Image.create(n, m, false, Image.FORMAT_RGBA8)
	var own: PackedByteArray = lab["own"]
	var keys: Array = lab["keys"]
	var step: int = int(lab["step"])
	var cols: Array[Color] = []
	for k in keys:
		var c: Color = faction_color(str(k))
		cols.append(Color(c.r, c.g, c.b, alpha))
	for j in m:
		for i in n:
			var v: int = own[j * n + i]
			if v == 0:
				continue
			var t: int = w.terrain[mini(j * step, w.gh - 1) * w.gw + mini(i * step, w.gw - 1)]
			if t == World.T.WATER:
				continue
			img.set_pixel(i, j, cols[v - 1])
	return img


## Frontières en pointillés (traits d'ombre et fil de la couleur des deux factions) ; `k` épaissit à petit zoom.
## Tous les tirets d'une couleur sont regroupés en un seul appel de dessin (draw_multiline).
static func paint_borders(l: CanvasItem, lines: Array, k: float = 1.0) -> void:
	var shadow := PackedVector2Array()
	var by_col: Dictionary = {}
	for ln in lines:
		var mix: Color = faction_color(str(ln["a"])).lerp(faction_color(str(ln["b"])), 0.5).lightened(0.25)
		var pts: PackedVector2Array = ln["pts"]
		var run: float = 0.0
		var arr: PackedVector2Array = by_col.get(mix, PackedVector2Array())
		for i in pts.size() - 1:
			if int(run / (8.0 * k)) % 2 == 0:
				shadow.append(pts[i])
				shadow.append(pts[i + 1])
				arr.append(pts[i])
				arr.append(pts[i + 1])
			run += pts[i].distance_to(pts[i + 1])
		by_col[mix] = arr
	if not shadow.is_empty():
		l.draw_multiline(shadow, Color(0.16, 0.11, 0.07, 0.8), 2.6 * k)
	for c in by_col:
		if not (by_col[c] as PackedVector2Array).is_empty():
			l.draw_multiline(by_col[c], c, 1.1 * k)


## Bornes frontières : petite pierre dressée, coiffée des couleurs des deux voisins.
static func paint_border_stones(l: CanvasItem, stones: Array, k: float = 1.0) -> void:
	for st in stones:
		var p: Vector2 = st["p"]
		var ca: Color = faction_color(str(st["a"]))
		var cb: Color = faction_color(str(st["b"]))
		var h: float = 11.0 * k
		var wd: float = 4.2 * k
		l.draw_circle(p + Vector2(1.5, 1.0) * k, 3.4 * k, Color(0, 0, 0, 0.25))
		var body := PackedVector2Array([p + Vector2(-wd, 1.5 * k), p + Vector2(-wd, -h * 0.7), p + Vector2(-wd * 0.5, -h), p + Vector2(wd * 0.5, -h), p + Vector2(wd, -h * 0.7), p + Vector2(wd, 1.5 * k)])
		l.draw_colored_polygon(body, Color("a9a495"))
		l.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -h), p + Vector2(wd * 0.5, -h), p + Vector2(wd, -h * 0.7), p + Vector2(wd, 1.5 * k), p + Vector2(0, 1.5 * k)]), Color("807b6e"))
		l.draw_rect(Rect2(p + Vector2(-wd, -h * 0.55), Vector2(wd, 2.6 * k)), ca)
		l.draw_rect(Rect2(p + Vector2(0, -h * 0.55), Vector2(wd, 2.6 * k)), cb)
		l.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[5], body[0]]), OL, 0.9 * k)


# --- Points d'intérêt ---

const POI_COLORS: Dictionary = {"ruins": Color("b9b2a0"), "shrine": Color("e6d9a0"), "camp": Color("c9a070"), "tower": Color("b0a88e"), "cave": Color("6a5a48")}


## Petit pictogramme d'un point d'intérêt, centré sur `p` (pied au sol), à l'échelle `k`. `done` : déjà exploré (estompé).
static func paint_poi(l: CanvasItem, kind: String, p: Vector2, k: float, done: bool, t: float = 0.0, animate: bool = false) -> void:
	var a: float = 0.5 if done else 1.0
	var stone := Color(0.66, 0.62, 0.55, a)
	var dark := Color(0.40, 0.37, 0.33, a)
	l.draw_set_transform(p + Vector2(0, 5.0 * k), 0.0, Vector2(1.0, 0.4))
	l.draw_circle(Vector2.ZERO, 9.0 * k, Color(0, 0, 0, 0.3 * a))
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match kind:
		"ruins":  # colonnes brisées
			for i in 3:
				var x: float = (-7.0 + i * 7.0) * k
				var h: float = (6.0 + 5.0 * float((i * 5) % 3)) * k
				l.draw_rect(Rect2(p + Vector2(x - 2.2 * k, 4.0 * k - h), Vector2(4.4 * k, h)), stone)
				l.draw_rect(Rect2(p + Vector2(x - 2.2 * k, 4.0 * k - h), Vector2(4.4 * k, h)), OL, false, 0.9 * k)
				l.draw_colored_polygon(PackedVector2Array([p + Vector2(x - 2.2 * k, 4.0 * k - h), p + Vector2(x - 0.5 * k, 4.0 * k - h - 2.0 * k), p + Vector2(x + 2.2 * k, 4.0 * k - h)]), dark)
		"shrine":  # stèle et lueur
			var glow: float = 0.55 + 0.25 * sin(t * 2.0) if animate else 0.6
			l.draw_circle(p + Vector2(0, -5.0 * k), 8.5 * k, Color(1.0, 0.9, 0.5, 0.18 * glow * a))
			l.draw_rect(Rect2(p + Vector2(-2.6 * k, -11.0 * k), Vector2(5.2 * k, 15.0 * k)), stone)
			l.draw_rect(Rect2(p + Vector2(-2.6 * k, -11.0 * k), Vector2(5.2 * k, 15.0 * k)), OL, false, 0.9 * k)
			l.draw_line(p + Vector2(0, -9.0 * k), p + Vector2(0, -3.0 * k), Color(0.9, 0.78, 0.3, a), 1.2 * k)
			l.draw_line(p + Vector2(-2.0 * k, -6.5 * k), p + Vector2(2.0 * k, -6.5 * k), Color(0.9, 0.78, 0.3, a), 1.2 * k)
			l.draw_circle(p + Vector2(0, -12.5 * k), 1.5 * k, Color(1.0, 0.92, 0.55, a))
		"camp":  # tente et feu éteint
			var tent := PackedVector2Array([p + Vector2(-8.0 * k, 4.0 * k), p + Vector2(0, -9.0 * k), p + Vector2(8.0 * k, 4.0 * k)])
			l.draw_colored_polygon(tent, Color(0.72, 0.62, 0.46, a))
			l.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9.0 * k), p + Vector2(8.0 * k, 4.0 * k), p + Vector2(1.5 * k, 4.0 * k)]), Color(0.52, 0.43, 0.32, a))
			l.draw_polyline(PackedVector2Array([tent[0], tent[1], tent[2], tent[0]]), OL, 1.0 * k)
			l.draw_circle(p + Vector2(10.0 * k, 3.5 * k), 2.0 * k, Color(0.2, 0.17, 0.15, a))
		"tower":  # tour de guet
			var body := PackedVector2Array([p + Vector2(-4.5 * k, 4.0 * k), p + Vector2(-3.5 * k, -12.0 * k), p + Vector2(3.5 * k, -12.0 * k), p + Vector2(4.5 * k, 4.0 * k)])
			l.draw_colored_polygon(body, stone)
			l.draw_colored_polygon(PackedVector2Array([p + Vector2(1.0 * k, -12.0 * k), p + Vector2(3.5 * k, -12.0 * k), p + Vector2(4.5 * k, 4.0 * k), p + Vector2(1.5 * k, 4.0 * k)]), dark)
			l.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), OL, 1.0 * k)
			for i in 3:
				l.draw_rect(Rect2(p + Vector2((-4.6 + i * 3.3) * k, -15.0 * k), Vector2(2.4 * k, 3.4 * k)), stone)
			l.draw_rect(Rect2(p + Vector2(-1.0 * k, -6.0 * k), Vector2(2.0 * k, 3.5 * k)), Color(0.12, 0.1, 0.08, a))
		"cave":  # arche sombre dans la roche
			var rock := PackedVector2Array([p + Vector2(-10.0 * k, 4.0 * k), p + Vector2(-8.0 * k, -5.0 * k), p + Vector2(-2.0 * k, -10.0 * k), p + Vector2(5.0 * k, -8.0 * k), p + Vector2(10.0 * k, 4.0 * k)])
			l.draw_colored_polygon(rock, Color(0.5, 0.46, 0.4, a))
			l.draw_polyline(PackedVector2Array([rock[0], rock[1], rock[2], rock[3], rock[4]]), OL, 1.1 * k)
			l.draw_circle(p + Vector2(0, 0.5 * k), 4.6 * k, Color(0.08, 0.06, 0.05, a))
			l.draw_rect(Rect2(p + Vector2(-4.6 * k, 0.5 * k), Vector2(9.2 * k, 3.5 * k)), Color(0.08, 0.06, 0.05, a))
		_:
			l.draw_circle(p, 4.0 * k, stone)
