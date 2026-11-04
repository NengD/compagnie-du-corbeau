class_name MapTerrain
extends RefCounted
## Dessin statique du terrain de la carte du monde : fond peint (relief, eaux, berges), routes de terre, ponts, gués,
## forêts, montagnes, collines. Fonctions statiques ; le résultat est mis en cache par la vue (couches `Layer`).
## Tout le « hasard » vient de `hf` (hachage de la case) : le dessin est stable, sans motif répétitif visible.

const PX := 6  ## pixels de texture par case
const OL := Color("17110c")
const LAND: Array[Color] = [Color("727f43"), Color("4c6133"), Color("918b57"), Color("727f43"), Color("7d7466"), Color("727f43"), Color("727f43")]
const HEIGHT: Array[float] = [0.30, 0.34, 0.58, 0.0, 1.0, 0.0, 0.0]
const WATER_FIELD: Array[float] = [0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.55]
const WATER_THR := 0.40

static var _ck: int = 0
static var _ctex: ImageTexture
static var _cmask: ImageTexture


## Hachage stable (x, y, k) -> [0, 1[.
static func hf(x: int, y: int, k: int = 0) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (k * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65536.0


static func _is_waterish(w: World, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= World.GW or c.y >= World.GH:
		return false
	var t: int = w.terrain[c.y * World.GW + c.x]
	return t == World.T.WATER or t == World.T.BRIDGE or t == World.T.FORD


# --- Fond peint ---

## [texture du fond, masque de l'eau (alpha) pour les reflets animés]. Mis en cache tant que le terrain ne change pas.
static func textures(w: World, px: int = PX) -> Array:
	var key: int = hash(w.terrain) + px * 7919
	if key == _ck and _ctex != null:
		return [_ctex, _cmask]
	var gw: int = World.GW
	var gh: int = World.GH
	var n: int = gw * gh
	var wat := PackedFloat32Array()
	var hgt := PackedFloat32Array()
	var landc := PackedColorArray()
	wat.resize(n)
	hgt.resize(n)
	landc.resize(n)
	for i in n:
		var t: int = w.terrain[i]
		wat[i] = WATER_FIELD[t]
		hgt[i] = HEIGHT[t]
		landc[i] = LAND[t]
	# distance à la terre (profondeur de l'eau)
	var dist := PackedFloat32Array()
	dist.resize(n)
	var queue: Array[int] = []
	for i in n:
		if wat[i] < 0.5:
			dist[i] = 0.0
			queue.append(i)
		else:
			dist[i] = 99.0
	var qi: int = 0
	while qi < queue.size():
		var c: int = queue[qi]
		qi += 1
		var cx: int = c % gw
		var cy: int = c / gw
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
				continue
			var ni: int = ny * gw + nx
			if dist[ni] > dist[c] + 1.0:
				dist[ni] = dist[c] + 1.0
				queue.append(ni)
	# relief adouci
	for pass_i in 2:
		var src := hgt.duplicate()
		for y in gh:
			for x in gw:
				var s: float = 0.0
				var cnt: float = 0.0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var xx: int = x + dx
						var yy: int = y + dy
						if xx >= 0 and yy >= 0 and xx < gw and yy < gh:
							s += src[yy * gw + xx]
							cnt += 1.0
				hgt[y * gw + x] = s / cnt
	var iw: int = gw * px
	var ih: int = gh * px
	var img := Image.create(iw, ih, false, Image.FORMAT_RGB8)
	var mask := Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	var nb := FastNoiseLite.new()
	nb.seed = 7
	nb.frequency = 0.009
	var nm := FastNoiseLite.new()
	nm.seed = 21
	nm.frequency = 0.035
	var nf := FastNoiseLite.new()
	nf.seed = 11
	nf.frequency = 0.4
	var db: PackedByteArray = nb.get_image(iw, ih, false, false, true).get_data()
	var dm: PackedByteArray = nm.get_image(iw, ih, false, false, true).get_data()
	var df: PackedByteArray = nf.get_image(iw, ih, false, false, true).get_data()
	var shallow := Color(0.40, 0.58, 0.60)
	var deep := Color(0.19, 0.33, 0.46)
	var sand := Color(0.74, 0.68, 0.50)
	var foam := Color(0.84, 0.90, 0.86)
	for y in ih:
		var fy: float = (y + 0.5) / px - 0.5
		var y0: int = clampi(int(floorf(fy)), 0, gh - 1)
		var y1: int = mini(y0 + 1, gh - 1)
		var ty: float = clampf(fy - y0, 0.0, 1.0)
		for x in iw:
			var fx: float = (x + 0.5) / px - 0.5
			var x0: int = clampi(int(floorf(fx)), 0, gw - 1)
			var x1: int = mini(x0 + 1, gw - 1)
			var tx: float = clampf(fx - x0, 0.0, 1.0)
			var i00: int = y0 * gw + x0
			var i10: int = y0 * gw + x1
			var i01: int = y1 * gw + x0
			var i11: int = y1 * gw + x1
			var w00: float = (1.0 - tx) * (1.0 - ty)
			var w10: float = tx * (1.0 - ty)
			var w01: float = (1.0 - tx) * ty
			var w11: float = tx * ty
			var k: int = y * iw + x
			var bn: float = float(db[k]) / 255.0 - 0.5
			var mn: float = float(dm[k]) / 255.0 - 0.5
			var gn: float = float(df[k]) / 255.0 - 0.5
			var wf: float = wat[i00] * w00 + wat[i10] * w10 + wat[i01] * w01 + wat[i11] * w11 + mn * 0.26
			var h: float = hgt[i00] * w00 + hgt[i10] * w10 + hgt[i01] * w01 + hgt[i11] * w11
			var hx: float = hgt[i10] * (1.0 - ty) + hgt[i11] * ty - (hgt[i00] * (1.0 - ty) + hgt[i01] * ty)
			var hy: float = hgt[i01] * (1.0 - tx) + hgt[i11] * tx - (hgt[i00] * (1.0 - tx) + hgt[i10] * tx)
			var lc: Color = Color(
				landc[i00].r * w00 + landc[i10].r * w10 + landc[i01].r * w01 + landc[i11].r * w11,
				landc[i00].g * w00 + landc[i10].g * w10 + landc[i01].g * w01 + landc[i11].g * w11,
				landc[i00].b * w00 + landc[i10].b * w10 + landc[i01].b * w01 + landc[i11].b * w11)
			var shade: float = bn * 0.16 + mn * 0.08 + gn * 0.05 - (hx + hy) * 0.55 + (h - 0.3) * 0.06
			var col := Color(lc.r + shade, lc.g + shade, lc.b + shade * 0.8)
			var cover: float = smoothstep(WATER_THR - 0.03, WATER_THR + 0.03, wf)
			if wf > WATER_THR - 0.24:
				# berge : sable humide puis liseré sombre
				var bank: float = smoothstep(WATER_THR - 0.24, WATER_THR - 0.05, wf)
				col = col.lerp(sand, bank * 0.55)
				var edge: float = 1.0 - clampf(absf(wf - (WATER_THR - 0.045)) / 0.05, 0.0, 1.0)
				col = col.lerp(Color(0.16, 0.13, 0.09), edge * 0.55)
			if cover > 0.0:
				var dd: float = dist[i00] * w00 + dist[i10] * w10 + dist[i01] * w01 + dist[i11] * w11
				var wc: Color = shallow.lerp(deep, clampf((dd - 0.6) / 3.2, 0.0, 1.0))
				wc = wc.lightened(gn * 0.12 + mn * 0.1)
				var near_edge: float = 1.0 - smoothstep(WATER_THR + 0.02, WATER_THR + 0.2, wf)
				wc = wc.lerp(foam, near_edge * 0.22)
				col = col.lerp(wc, cover)
				mask.set_pixel(x, y, Color(1, 1, 1, cover * (0.45 + 0.55 * clampf(dd / 3.0, 0.0, 1.0))))
			img.set_pixel(x, y, col)
	_ctex = ImageTexture.create_from_image(img)
	_cmask = ImageTexture.create_from_image(mask)
	_ck = key
	return [_ctex, _cmask]


# --- Routes ---

## Courbe lissée (Catmull-Rom) passant par les points.
static func catmull(pts: Array[Vector2], sub: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n: int = pts.size()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for s in sub:
			var t: float = float(s) / sub
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(((p1 * 2.0) + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2 + (p1 * 3.0 - p0 - p2 * 3.0 + p3) * t3) * 0.5)
	out.append(pts[n - 1])
	return out


## Les routes lissées : [{"c": points, "w": demi-largeurs}] (jitter par case : tronçons communs identiques).
static func road_curves(w: World) -> Array:
	var out: Array = []
	for path in w.road_paths:
		var pts: Array[Vector2] = []
		for i in path.size():
			var v: Vector2 = path[i]
			if i > 0 and i < path.size() - 1:
				var c: Vector2i = w.cell_of(v)
				v += Vector2(hf(c.x, c.y, 1) - 0.5, hf(c.x, c.y, 2) - 0.5) * 7.0
			pts.append(v)
		var cur: Array[Vector2] = catmull(pts, 4)
		var hw: Array[float] = []
		var run: float = 0.0
		for i in cur.size():
			if i > 0:
				run += cur[i].distance_to(cur[i - 1])
			hw.append(3.1 + 0.9 * sin(run * 0.045 + float(path.size())) + 0.5 * sin(run * 0.17))
		out.append({"c": cur, "w": hw})
	return out


static func _strip(l: Node2D, cur: Array[Vector2], hw: Array[float], extra: float, col: Color, scale: float = 1.0, jitter: float = 0.0, seed_k: int = 0) -> void:
	var m: int = cur.size()
	var left: Array[Vector2] = []
	var right: Array[Vector2] = []
	for i in m:
		var a: Vector2 = cur[maxi(i - 1, 0)]
		var b: Vector2 = cur[mini(i + 1, m - 1)]
		var dir: Vector2 = (b - a)
		if dir.length() < 0.001:
			dir = Vector2.RIGHT
		var nrm: Vector2 = dir.normalized().orthogonal()
		var wl: float = hw[i] * scale + extra
		var wr: float = wl
		if jitter > 0.0:
			wl += (hf(int(cur[i].x * 3.0), int(cur[i].y * 3.0), seed_k) - 0.5) * jitter
			wr += (hf(int(cur[i].x * 3.0), int(cur[i].y * 3.0), seed_k + 7) - 0.5) * jitter
		left.append(cur[i] + nrm * wl)
		right.append(cur[i] - nrm * wr)
	for i in m - 1:
		var q := PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]])
		if Geometry2D.triangulate_polygon(q).is_empty():
			continue
		l.draw_colored_polygon(q, col)


static func paint_roads(l: Node2D, w: World, curves: Array) -> void:
	# 1) lisière herbeuse, 2) terre battue, 3) centre usé, 4) ornières : chaque passe pour toutes les routes d'abord (carrefours propres)
	for r in curves:
		_strip(l, r["c"], r["w"], 1.6, Color(0.30, 0.24, 0.14, 0.30), 1.0, 1.4, 11)
	for r in curves:
		_strip(l, r["c"], r["w"], 0.0, Color(0.60, 0.48, 0.30), 1.0, 0.9, 13)
	for r in curves:
		_strip(l, r["c"], r["w"], 0.0, Color(0.70, 0.58, 0.38, 0.8), 0.45, 0.0)
	for r in curves:
		var cur: Array[Vector2] = r["c"]
		var hw: Array[float] = r["w"]
		for side in [-1.0, 1.0]:
			var seg := PackedVector2Array()
			for i in cur.size():
				var a: Vector2 = cur[maxi(i - 1, 0)]
				var b: Vector2 = cur[mini(i + 1, cur.size() - 1)]
				var nrm: Vector2 = (b - a).normalized().orthogonal()
				var on: bool = hf(int(cur[i].x / 6.0), int(cur[i].y / 6.0), 31 + int(side)) > 0.22
				if on:
					seg.append(cur[i] + nrm * hw[i] * 0.42 * side)
				elif seg.size() >= 2:
					l.draw_polyline(seg, Color(0.38, 0.29, 0.18, 0.55), 0.8, true)
					seg = PackedVector2Array()
				else:
					seg = PackedVector2Array()
			if seg.size() >= 2:
				l.draw_polyline(seg, Color(0.38, 0.29, 0.18, 0.55), 0.8, true)
	# carrefours : les cases où trois tronçons ou plus se rejoignent
	var deg: Dictionary = {}
	for path in w.road_paths:
		var prev := Vector2i(-1, -1)
		for v in path:
			var c: Vector2i = w.cell_of(v)
			if prev.x >= 0 and prev != c:
				for pair in [[c, prev], [prev, c]]:
					var s: Dictionary = deg.get(pair[0], {})
					s[pair[1]] = true
					deg[pair[0]] = s
			prev = c
	for c in deg:
		if (deg[c] as Dictionary).size() >= 3:
			var cp := Vector2((c.x + 0.5) * World.CELL, (c.y + 0.5) * World.CELL)
			l.draw_circle(cp, 5.2, Color(0.60, 0.48, 0.30))
			l.draw_circle(cp, 3.0, Color(0.70, 0.58, 0.38, 0.8))
	for s in w.settlements:  # place de terre battue devant chaque lieu
		var sp: Vector2 = w.settlement_pos(s)
		l.draw_set_transform(sp + Vector2(0, 8), 0.0, Vector2(1.0, 0.45))
		l.draw_circle(Vector2.ZERO, 26.0 if s["kind"] == "city" else 20.0, Color(0.58, 0.47, 0.30, 0.85))
		l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Décor du sol (sous l'eau animée) : touffes, collines, rochers ---

static func paint_ground_decor(l: Node2D, w: World) -> void:
	var gw: int = World.GW
	for y in World.GH:
		for x in gw:
			var t: int = w.terrain[y * gw + x]
			var o := Vector2(x * World.CELL, y * World.CELL)
			var road: bool = w.road_cells.has(Vector2i(x, y))
			match t:
				World.T.PLAIN:
					if road:
						continue
					if hf(x, y, 3) < 0.30:
						var p: Vector2 = o + Vector2(2.0 + hf(x, y, 4) * 16.0, 4.0 + hf(x, y, 5) * 14.0)
						var gcol := Color(0.34, 0.45, 0.2, 0.7)
						l.draw_multiline(PackedVector2Array([p, p + Vector2(-2, -3.5), p, p + Vector2(0.5, -4.5), p, p + Vector2(2.4, -3.2)]), gcol, 1.0)
					if hf(x, y, 6) < 0.05:
						var fp: Vector2 = o + Vector2(3.0 + hf(x, y, 7) * 14.0, 3.0 + hf(x, y, 8) * 14.0)
						var fc: Color = [Color("e8d27a"), Color("e9e4d2"), Color("c97a8a")][int(hf(x, y, 9) * 3.0)]
						l.draw_circle(fp, 1.0, fc)
					if hf(x, y, 12) < 0.035:
						_rock(l, o + Vector2(4.0 + hf(x, y, 13) * 12.0, 6.0 + hf(x, y, 14) * 10.0), 0.8 + hf(x, y, 15) * 0.6, x, y)
				World.T.HILLS:
					if not road:
						_hill(l, o + Vector2(10.0 + (hf(x, y, 16) - 0.5) * 8.0, 11.0 + (hf(x, y, 17) - 0.5) * 6.0), 0.9 + hf(x, y, 18) * 0.5)
						if hf(x, y, 19) < 0.45:
							_hill(l, o + Vector2(4.0 + hf(x, y, 20) * 12.0, 3.0 + hf(x, y, 21) * 8.0), 0.55 + hf(x, y, 22) * 0.35)
					if hf(x, y, 23) < 0.10:
						_rock(l, o + Vector2(3.0 + hf(x, y, 24) * 14.0, 5.0 + hf(x, y, 25) * 12.0), 0.9, x, y)
				World.T.FOREST:
					if hf(x, y, 26) < 0.2:  # sous-bois : fougères et mousse
						var p2: Vector2 = o + Vector2(3.0 + hf(x, y, 27) * 14.0, 4.0 + hf(x, y, 28) * 12.0)
						l.draw_circle(p2, 2.4, Color(0.25, 0.36, 0.17, 0.6))
						l.draw_circle(p2 + Vector2(1.6, -1.0), 1.5, Color(0.31, 0.43, 0.2, 0.6))


static func _hill(l: Node2D, c: Vector2, s: float) -> void:
	var wd: float = 11.0 * s
	var ht: float = 6.0 * s
	var top := PackedVector2Array()
	for i in 9:
		var a: float = PI - PI * float(i) / 8.0
		top.append(c + Vector2(cos(a) * wd, -sin(a) * ht))
	var body := PackedVector2Array(top)
	body.append(c + Vector2(wd, 0.5))
	body.append(c + Vector2(-wd, 0.5))
	if Geometry2D.triangulate_polygon(body).is_empty():
		return
	l.draw_colored_polygon(body, Color("a29b62"))
	var shade := PackedVector2Array()
	for i in range(4, 9):
		shade.append(top[i])
	shade.append(c + Vector2(wd, 0.5))
	shade.append(c + Vector2(wd * 0.1, 0.5))
	shade.append(c + Vector2(wd * 0.35, -ht * 0.55))
	if not Geometry2D.triangulate_polygon(shade).is_empty():
		l.draw_colored_polygon(shade, Color("7c7646"))
	l.draw_polyline(top, Color(0.28, 0.25, 0.14, 0.7), 1.1, true)
	l.draw_arc(c + Vector2(-wd * 0.3, -ht * 0.2), wd * 0.45, PI * 1.1, PI * 1.5, 5, Color("c4bd82"), 1.0, true)


static func _rock(l: Node2D, c: Vector2, s: float, x: int, y: int) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		var r: float = (3.0 + hf(x, y, 40 + i) * 1.8) * s
		pts.append(c + Vector2(cos(a) * r * 1.2, sin(a) * r * 0.8))
	l.draw_set_transform(Vector2(1.2, 1.4), 0.0, Vector2.ONE)
	l.draw_colored_polygon(pts, Color(0, 0, 0, 0.25))
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	l.draw_colored_polygon(pts, Color("8d887c"))
	l.draw_colored_polygon(PackedVector2Array([pts[3], pts[4], pts[5], pts[0]]), Color("6c675c"))
	l.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), OL, 0.9)


# --- Objets (au-dessus de l'eau) : gués, ponts, bornes, forêts, montagnes ---

static func paint_objects(l: Node2D, w: World, curves: Array) -> void:
	var gw: int = World.GW
	for y in World.GH:
		for x in gw:
			var t: int = w.terrain[y * gw + x]
			var cp := Vector2((x + 0.5) * World.CELL, (y + 0.5) * World.CELL)
			if t == World.T.FORD:
				_ford(l, cp, x, y)
			elif t == World.T.BRIDGE:
				_bridge(l, w, cp, x, y)
	_milestones(l, w)
	# arbres et pics triés par ordonnée : les plus au sud recouvrent les plus au nord
	var items: Array = []
	var species := FastNoiseLite.new()
	species.seed = 5
	species.frequency = 0.075
	var clearing := FastNoiseLite.new()
	clearing.seed = 9
	clearing.frequency = 0.14
	for y in World.GH:
		for x in gw:
			var t: int = w.terrain[y * gw + x]
			var o := Vector2(x * World.CELL, y * World.CELL)
			if t == World.T.FOREST:
				if w.road_cells.has(Vector2i(x, y)):
					continue
				var sp: float = species.get_noise_2d(x, y)
				var clear: bool = clearing.get_noise_2d(x, y) > 0.34
				var edge: int = 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= gw or ny >= World.GH or w.terrain[ny * gw + nx] != World.T.FOREST:
						edge += 1
				var cnt: int = 5 - edge
				if clear:
					cnt = 1
				cnt = clampi(cnt, 1, 5)
				for k in cnt:
					var p := o + Vector2(2.0 + hf(x, y, 50 + k) * 16.0, 4.0 + hf(x, y, 60 + k) * 15.0)
					var kind: int = 0 if sp > 0.12 else (1 if sp < -0.12 else int(hf(x, y, 70 + k) * 2.0))  # 0 conifère, 1 feuillu
					items.append({"y": p.y, "k": "tree", "p": p, "kind": kind, "s": 0.75 + hf(x, y, 80 + k) * 0.6, "h": hf(x, y, 90 + k)})
				if clear:
					for k in 3:
						var fp := o + Vector2(3.0 + hf(x, y, 100 + k) * 14.0, 4.0 + hf(x, y, 110 + k) * 13.0)
						items.append({"y": fp.y, "k": "flower", "p": fp, "h": hf(x, y, 120 + k)})
			elif t == World.T.MOUNTAIN:
				var nb: int = 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx: int = x + dx
						var ny: int = y + dy
						if nx >= 0 and ny >= 0 and nx < gw and ny < World.GH and w.terrain[ny * gw + nx] == World.T.MOUNTAIN:
							nb += 1
				var peaks: int = 1 + (1 if hf(x, y, 130) < 0.55 else 0)
				for k in peaks:
					var base := o + Vector2(4.0 + hf(x, y, 131 + k) * 12.0, 12.0 + hf(x, y, 133 + k) * 7.0)
					var hh: float = (13.0 + hf(x, y, 135 + k) * 8.0) * (0.8 + 0.07 * float(nb))
					items.append({"y": base.y, "k": "peak", "p": base, "hh": hh, "snow": nb >= 6 and hh > 18.0 or hh > 25.0, "h": hf(x, y, 137 + k)})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for it in items:
		match str(it["k"]):
			"tree":
				if int(it["kind"]) == 0:
					_conifer(l, it["p"], float(it["s"]), float(it["h"]))
				else:
					_broadleaf(l, it["p"], float(it["s"]), float(it["h"]))
			"flower":
				var fcol: Color = [Color("e8d27a"), Color("e9e4d2"), Color("d28ab0"), Color("9ab0e0")][int(float(it["h"]) * 4.0)]
				l.draw_circle(it["p"], 1.1, fcol)
			"peak":
				_peak(l, it["p"], float(it["hh"]), bool(it["snow"]), float(it["h"]))


static func _conifer(l: Node2D, p: Vector2, s: float, h: float) -> void:
	var th: float = 15.0 * s
	var tw: float = 10.0 * s
	var dark: Color = Color("2c4026").lerp(Color("37522a"), h)
	l.draw_circle(p + Vector2(1.5, 0.3), tw * 0.42, Color(0, 0, 0, 0.18))
	var pts := PackedVector2Array([
		p + Vector2(0, -th), p + Vector2(tw * 0.42, -th * 0.5), p + Vector2(tw * 0.22, -th * 0.5), p + Vector2(tw * 0.6, -th * 0.14),
		p + Vector2(tw * 0.13, -th * 0.14), p + Vector2(tw * 0.13, 0), p + Vector2(-tw * 0.13, 0), p + Vector2(-tw * 0.13, -th * 0.14),
		p + Vector2(-tw * 0.6, -th * 0.14), p + Vector2(-tw * 0.22, -th * 0.5), p + Vector2(-tw * 0.42, -th * 0.5),
	])
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	l.draw_colored_polygon(pts, dark)
	l.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -th), p + Vector2(-tw * 0.42, -th * 0.5), p + Vector2(-tw * 0.1, -th * 0.5)]), dark.lightened(0.28))
	l.draw_colored_polygon(PackedVector2Array([p + Vector2(-tw * 0.3, -th * 0.17), p + Vector2(-tw * 0.58, -th * 0.15), p + Vector2(-tw * 0.1, -th * 0.15)]), dark.lightened(0.18))
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	l.draw_polyline(ring, OL, 0.9)


static func _broadleaf(l: Node2D, p: Vector2, s: float, h: float) -> void:
	var r: float = 5.4 * s
	var base: Color = Color("3c5a2a").lerp(Color("5a7430"), h)
	if h > 0.86:
		base = Color("8a7a2c")  # quelques arbres jaunissants
	l.draw_circle(p + Vector2(1.6, 1.0), r * 0.9, Color(0, 0, 0, 0.18))
	l.draw_rect(Rect2(p + Vector2(-0.9, -r * 0.5), Vector2(1.8, r * 0.9)), Color("4a3524"))
	var c: Vector2 = p + Vector2(0, -r * 1.05)
	l.draw_circle(c, r + 0.9, OL)
	l.draw_circle(c, r, base)
	l.draw_circle(c + Vector2(r * 0.42, r * 0.3), r * 0.62, base.darkened(0.22))
	l.draw_circle(c + Vector2(-r * 0.32, -r * 0.34), r * 0.5, base.lightened(0.26))


static func _peak(l: Node2D, p: Vector2, h: float, snow: bool, j: float) -> void:
	var hw: float = h * 0.68
	var a := p + Vector2(0, -h)
	var bl := p + Vector2(-hw, 0)
	var br := p + Vector2(hw, 0)
	var m := p + Vector2((j - 0.5) * hw * 0.5, 1.0)
	l.draw_colored_polygon(PackedVector2Array([a, bl, m]), Color("93897a"))
	l.draw_colored_polygon(PackedVector2Array([a, m, br]), Color("5d5549"))
	l.draw_line(a, m, Color(0.2, 0.17, 0.13, 0.8), 1.0)
	l.draw_line(a.lerp(bl, 0.45), a.lerp(m, 0.5), Color(0.34, 0.3, 0.25, 0.6), 0.8)  # arête secondaire
	if snow:
		var sl: Vector2 = a.lerp(bl, 0.4)
		var sr: Vector2 = a.lerp(br, 0.4)
		var sm: Vector2 = a.lerp(m, 0.42) + Vector2(hw * 0.05, 0)
		l.draw_colored_polygon(PackedVector2Array([a, sl, a.lerp(m, 0.3) + Vector2(-hw * 0.1, h * 0.1), sm]), Color("ece9e0"))
		l.draw_colored_polygon(PackedVector2Array([a, sm, a.lerp(br, 0.22) + Vector2(0, h * 0.12), sr]), Color("b5b9c0"))
	l.draw_polyline(PackedVector2Array([bl, a, br]), OL, 1.1)


# --- Gués, ponts, bornes ---

static func _ford(l: Node2D, c: Vector2, x: int, y: int) -> void:
	l.draw_set_transform(c, 0.0, Vector2(1.0, 0.62))
	l.draw_circle(Vector2.ZERO, 9.5, Color(0.72, 0.65, 0.46, 0.85))
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 6:
		var sp: Vector2 = c + Vector2((hf(x, y, 140 + k) - 0.5) * 14.0, (hf(x, y, 150 + k) - 0.5) * 8.0)
		l.draw_circle(sp, 1.5 + hf(x, y, 160 + k), Color("7d7a70"))
		l.draw_circle(sp + Vector2(-0.4, -0.5), 0.8, Color("a8a499"))
	l.draw_arc(c + Vector2(-5, 4), 4.0, PI * 1.1, PI * 1.9, 6, Color(0.85, 0.92, 0.9, 0.7), 1.0, true)


static func _bridge(l: Node2D, w: World, c: Vector2, x: int, y: int) -> void:
	var cell := Vector2i(x, y)
	var ns: bool = _is_waterish(w, cell + Vector2i(0, -1)) and _is_waterish(w, cell + Vector2i(0, 1))
	var ew: bool = _is_waterish(w, cell + Vector2i(-1, 0)) and _is_waterish(w, cell + Vector2i(1, 0))
	var ang: float = 0.0  # tablier horizontal : la rivière coule du nord au sud
	if ew and not ns:
		ang = PI * 0.5
	var stone: bool = hf(x, y, 170) < 0.35
	l.draw_set_transform(c, ang, Vector2.ONE)
	var len_: float = 25.0
	var wd: float = 8.5
	if stone:
		l.draw_rect(Rect2(Vector2(-len_ * 0.5, -wd * 0.5 + 1.5), Vector2(len_, wd)), Color(0, 0, 0, 0.25))
		l.draw_rect(Rect2(Vector2(-len_ * 0.5, -wd * 0.5), Vector2(len_, wd)), Color("a39d8f"))
		l.draw_rect(Rect2(Vector2(-len_ * 0.5, -wd * 0.5), Vector2(len_, wd)), OL, false, 1.1)
		l.draw_line(Vector2(-len_ * 0.5, -wd * 0.5 + 1.2), Vector2(len_ * 0.5, -wd * 0.5 + 1.2), Color("c9c3b4"), 1.0)
		l.draw_line(Vector2(-len_ * 0.5, wd * 0.5 - 1.2), Vector2(len_ * 0.5, wd * 0.5 - 1.2), Color("6e695e"), 1.0)
		l.draw_arc(Vector2(0, wd * 0.5), 5.0, PI, TAU, 8, Color("2a2620"), 1.6, true)
	else:
		l.draw_rect(Rect2(Vector2(-len_ * 0.5, -wd * 0.5 + 1.5), Vector2(len_, wd)), Color(0, 0, 0, 0.25))
		l.draw_rect(Rect2(Vector2(-len_ * 0.5, -wd * 0.5), Vector2(len_, wd)), Color("8a6a40"))
		for k in 9:
			var px: float = -len_ * 0.5 + 1.5 + k * 2.8
			l.draw_line(Vector2(px, -wd * 0.5), Vector2(px, wd * 0.5), Color("5c4527"), 0.8)
		l.draw_line(Vector2(-len_ * 0.5, -wd * 0.5), Vector2(len_ * 0.5, -wd * 0.5), OL, 1.5)
		l.draw_line(Vector2(-len_ * 0.5, wd * 0.5), Vector2(len_ * 0.5, wd * 0.5), OL, 1.5)
		for px in [-len_ * 0.5, len_ * 0.5]:
			l.draw_rect(Rect2(Vector2(px - 1.2, -wd * 0.5 - 1.2), Vector2(2.4, 2.4)), Color("3b2c1a"))
			l.draw_rect(Rect2(Vector2(px - 1.2, wd * 0.5 - 1.2), Vector2(2.4, 2.4)), Color("3b2c1a"))
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Bornes de pierre là où une route longe l'eau, tous les 70 px environ.
static func _milestones(l: Node2D, w: World) -> void:
	var placed: Dictionary = {}
	for path in w.road_paths:
		var since: float = 40.0
		var prev: Vector2 = path[0]
		for v in path:
			since += v.distance_to(prev)
			prev = v
			if since < 70.0:
				continue
			var c: Vector2i = w.cell_of(v)
			var toward: Vector2 = Vector2.ZERO
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var nc: Vector2i = c + d
				if nc.x >= 0 and nc.y >= 0 and nc.x < World.GW and nc.y < World.GH and w.terrain[nc.y * World.GW + nc.x] == World.T.WATER:
					toward += Vector2(d)
			if toward == Vector2.ZERO or placed.has(c) or w.terrain[c.y * World.GW + c.x] != World.T.PLAIN and w.terrain[c.y * World.GW + c.x] != World.T.HILLS:
				continue
			placed[c] = true
			since = 0.0
			var sp: Vector2 = v - toward.normalized() * 8.5
			l.draw_circle(sp + Vector2(0.8, 0.6), 2.6, Color(0, 0, 0, 0.22))
			var stone := PackedVector2Array([sp + Vector2(-2.2, 1.5), sp + Vector2(-2.2, -3.0), sp + Vector2(-1.0, -4.5), sp + Vector2(1.0, -4.5), sp + Vector2(2.2, -3.0), sp + Vector2(2.2, 1.5)])
			l.draw_colored_polygon(stone, Color("a9a495"))
			l.draw_colored_polygon(PackedVector2Array([sp + Vector2(0.6, -4.5), sp + Vector2(2.2, -3.0), sp + Vector2(2.2, 1.5), sp + Vector2(0.6, 1.5)]), Color("807b6e"))
			l.draw_polyline(PackedVector2Array([stone[0], stone[1], stone[2], stone[3], stone[4], stone[5], stone[0]]), OL, 0.8)
			l.draw_line(sp + Vector2(-1.0, -2.0), sp + Vector2(1.0, -2.0), Color("55514a"), 0.7)
