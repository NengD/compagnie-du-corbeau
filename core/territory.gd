class_name Territory
extends RefCounted
## Territoires des factions : chaque lieu rayonne autour de lui (distance pondérée : capitale > ville > village), un bruit déforme un
## peu les frontières. Le résultat est une grille d'étiquettes (0 = terres sauvages, i + 1 = i-ème clé de `keys_list()`).
## Tout est recalculé à partir des positions et des propriétaires des lieux : rien à sauvegarder. Logique pure (aucun nœud).

const INFLUENCE: float = 430.0  ## portée maximale du rayonnement d'un lieu (px, avant pondération)
const WARP: float = 34.0  ## déformation des frontières (px)
const W_CAPITAL: float = 1.3
const W_CITY: float = 1.1
const W_VILLAGE: float = 0.9
const W_FREE: float = 0.45  ## cités libres : petites enclaves


## Clés de Data.FACTIONS dans l'ordre du jeu (index d'étiquette = position + 1).
static func keys_list() -> Array:
	return Data.FACTIONS.keys()


static func place_weight(s: Dictionary) -> float:
	var base: float = W_CAPITAL if bool(s.get("capital", false)) else (W_CITY if str(s["kind"]) == "city" else W_VILLAGE)
	if str(s.get("owner", "")) == "libres":
		base = W_FREE * (1.25 if str(s["kind"]) == "city" else 1.0)
	return base


## Grille d'étiquettes : {"step", "w", "h", "own": PackedByteArray, "keys"}. `step` = cases du monde par échantillon.
static func labels(world: World, step: int = 1) -> Dictionary:
	var keys: Array = keys_list()
	var n: int = ceili(float(world.gw) / step)
	var m: int = ceili(float(world.gh) / step)
	var own := PackedByteArray()
	own.resize(n * m)
	var pos: PackedVector2Array = PackedVector2Array()
	var wt: PackedFloat32Array = PackedFloat32Array()
	var ow: PackedInt32Array = PackedInt32Array()
	for s in world.settlements:
		var k: int = keys.find(str(s.get("owner", "")))
		if k < 0:
			continue
		pos.append(world.settlement_pos(s))
		wt.append(place_weight(s))
		ow.append(k + 1)
	if pos.is_empty():
		return {"step": step, "w": n, "h": m, "own": own, "keys": keys}
	var nx := FastNoiseLite.new()
	nx.seed = 31
	nx.frequency = 0.012
	var ny := FastNoiseLite.new()
	ny.seed = 47
	ny.frequency = 0.012
	var cell: float = World.CELL * step
	for j in m:
		for i in n:
			var p := Vector2((i + 0.5) * cell, (j + 0.5) * cell)
			var q: Vector2 = p + Vector2(nx.get_noise_2d(p.x, p.y), ny.get_noise_2d(p.x, p.y)) * WARP
			var best: float = 1e12
			var lab: int = 0
			for k in pos.size():
				var d: float = q.distance_to(pos[k]) / wt[k]
				if d < best:
					best = d
					lab = ow[k]
			own[j * n + i] = lab if best <= INFLUENCE else 0
	own = _fix_islands(own, n, m, keys)
	return {"step": step, "w": n, "h": m, "own": own, "keys": keys}


## Un territoire est d'un seul tenant : les îlots détachés (hors cités libres, qui sont des enclaves) passent au voisin qui les entoure.
static func _fix_islands(own_in: PackedByteArray, n: int, m: int, keys: Array) -> PackedByteArray:
	var own: PackedByteArray = own_in.duplicate()
	for it in 3:
		var comps: Dictionary = components({"w": n, "h": m, "own": own, "keys": keys})
		var changed: bool = false
		for key in comps:
			if str(key) == "libres":
				continue
			var list: Array = comps[key]
			if list.size() < 2:
				continue
			list.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
			for ci in range(1, list.size()):
				var members: Dictionary = {}
				for idx in list[ci]:
					members[idx] = true
				var votes: Dictionary = {}
				for idx in list[ci]:
					var x: int = int(idx) % n
					var y: int = int(idx) / n
					for off in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
						var qx: int = x + int(off[0])
						var qy: int = y + int(off[1])
						if qx < 0 or qy < 0 or qx >= n or qy >= m:
							continue
						var q: int = qy * n + qx
						if not members.has(q):
							votes[int(own[q])] = int(votes.get(int(own[q]), 0)) + 1
				var best: int = 0
				var bv: int = -1
				for v in votes:
					if int(votes[v]) > bv:
						bv = int(votes[v])
						best = int(v)
				for idx in list[ci]:
					own[idx] = best
				changed = true
		if not changed:
			break
	return own


static func owner_at(lab: Dictionary, p: Vector2) -> String:
	var cell: float = World.CELL * int(lab["step"])
	var i: int = clampi(int(p.x / cell), 0, int(lab["w"]) - 1)
	var j: int = clampi(int(p.y / cell), 0, int(lab["h"]) - 1)
	var v: int = (lab["own"] as PackedByteArray)[j * int(lab["w"]) + i]
	return str((lab["keys"] as Array)[v - 1]) if v > 0 else ""


## Composantes connexes (4 voisins) de chaque propriétaire : {clé: [[indices de cases], …]}.
static func components(lab: Dictionary) -> Dictionary:
	var n: int = int(lab["w"])
	var m: int = int(lab["h"])
	var own: PackedByteArray = lab["own"]
	var seen := PackedByteArray()
	seen.resize(n * m)
	var out: Dictionary = {}
	for start in n * m:
		if own[start] == 0 or seen[start] == 1:
			continue
		var v: int = own[start]
		var comp: Array = []
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var c: int = stack.pop_back()
			comp.append(c)
			var cx: int = c % n
			var cy: int = c / n
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var x: int = cx + int(d[0])
				var y: int = cy + int(d[1])
				if x < 0 or y < 0 or x >= n or y >= m:
					continue
				var k: int = y * n + x
				if seen[k] == 0 and own[k] == v:
					seen[k] = 1
					stack.append(k)
		var key: String = str((lab["keys"] as Array)[v - 1])
		if not out.has(key):
			out[key] = []
		(out[key] as Array).append(comp)
	return out


## Nombre de lieux par propriétaire : {clé: n}.
static func place_counts(world: World) -> Dictionary:
	var out: Dictionary = {}
	for s in world.settlements:
		var o: String = str(s.get("owner", ""))
		out[o] = int(out.get(o, 0)) + 1
	return out


# --- Frontières ---

## Lignes de frontière entre deux territoires voisins : [{"a": clé, "b": clé, "pts": PackedVector2Array}], adoucies (Chaikin).
## Les segments qui ne bordent que de l'eau sont ignorés. `world` sert à reconnaître l'eau.
static func borders(world: World, lab: Dictionary) -> Array:
	var n: int = int(lab["w"])
	var m: int = int(lab["h"])
	var step: int = int(lab["step"])
	var own: PackedByteArray = lab["own"]
	var cell: float = World.CELL * step
	var groups: Dictionary = {}  ## "a|b" -> {sommet: [voisins]}
	var vid := func(x: int, y: int) -> int:
		return y * (n + 1) + x
	var add_seg := func(a: int, b: int, va: int, vb: int) -> void:
		var lo: int = mini(a, b)
		var hi: int = maxi(a, b)
		var key: String = "%d|%d" % [lo, hi]
		if not groups.has(key):
			groups[key] = {}
		var adj: Dictionary = groups[key]
		if not adj.has(va):
			adj[va] = []
		if not adj.has(vb):
			adj[vb] = []
		(adj[va] as Array).append(vb)
		(adj[vb] as Array).append(va)
	for y in m:
		for x in n:
			var a: int = own[y * n + x]
			if a == 0:
				continue
			if x + 1 < n:
				var b: int = own[y * n + x + 1]
				if b != 0 and b != a and not _both_water(world, x, y, x + 1, y, step):
					add_seg.call(a, b, vid.call(x + 1, y), vid.call(x + 1, y + 1))
			if y + 1 < m:
				var b2: int = own[(y + 1) * n + x]
				if b2 != 0 and b2 != a and not _both_water(world, x, y, x, y + 1, step):
					add_seg.call(a, b2, vid.call(x, y + 1), vid.call(x + 1, y + 1))
	var out: Array = []
	var keys: Array = lab["keys"]
	for gk in groups:
		var parts: PackedStringArray = str(gk).split("|")
		var ka: String = str(keys[int(parts[0]) - 1])
		var kb: String = str(keys[int(parts[1]) - 1])
		var adj: Dictionary = groups[gk]
		var used: Dictionary = {}
		var starts: Array = []
		for v in adj:
			if (adj[v] as Array).size() != 2:
				starts.append(v)
		for v in adj:
			if (adj[v] as Array).size() == 2:
				starts.append(v)
		for s0 in starts:
			for nb in adj[s0]:
				var ek: String = "%d,%d" % [mini(s0, nb), maxi(s0, nb)]
				if used.has(ek):
					continue
				used[ek] = true
				var chain: Array[int] = [s0]
				var cur: int = nb
				while true:
					chain.append(cur)
					var nxt: int = -1
					for c in adj[cur]:
						var k2: String = "%d,%d" % [mini(cur, c), maxi(cur, c)]
						if not used.has(k2):
							used[k2] = true
							nxt = c
							break
					if nxt < 0:
						break
					cur = nxt
				if chain.size() < 3:
					continue
				var pts := PackedVector2Array()
				for v in chain:
					pts.append(Vector2(float(v % (n + 1)) * cell, float(v / (n + 1)) * cell))
				out.append({"a": ka, "b": kb, "pts": _chaikin(_chaikin(pts))})
	return out


static func _both_water(world: World, x0: int, y0: int, x1: int, y1: int, step: int) -> bool:
	var a: int = world.terrain[mini(y0 * step, world.gh - 1) * world.gw + mini(x0 * step, world.gw - 1)]
	var b: int = world.terrain[mini(y1 * step, world.gh - 1) * world.gw + mini(x1 * step, world.gw - 1)]
	return (a == World.T.WATER or a == World.T.MOUNTAIN) and (b == World.T.WATER or b == World.T.MOUNTAIN)


static func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i in pts.size() - 1:
		out.append(pts[i].lerp(pts[i + 1], 0.25))
		out.append(pts[i].lerp(pts[i + 1], 0.75))
	out.append(pts[pts.size() - 1])
	return out


## Bornes frontières : un point tous les `every` px le long des frontières : [{"p": Vector2, "a": clé, "b": clé}].
static func border_stones(lines: Array, every: float = 190.0) -> Array:
	var out: Array = []
	for ln in lines:
		var pts: PackedVector2Array = ln["pts"]
		var run: float = every * 0.5
		for i in pts.size() - 1:
			run += pts[i].distance_to(pts[i + 1])
			if run >= every:
				run = 0.0
				out.append({"p": pts[i + 1], "a": ln["a"], "b": ln["b"]})
	return out


# --- Noms de régions ---

## Position et largeur de chaque territoire : {clé: {"pos": Vector2, "w": largeur en px, "n": nombre de cases}} (terres sauvages exclues).
static func region_info(world: World, lab: Dictionary) -> Dictionary:
	var n: int = int(lab["w"])
	var cell: float = World.CELL * int(lab["step"])
	var own: PackedByteArray = lab["own"]
	var keys: Array = lab["keys"]
	var acc: Dictionary = {}
	for idx in own.size():
		var v: int = own[idx]
		if v == 0:
			continue
		var p := Vector2((idx % n + 0.5) * cell, (idx / n + 0.5) * cell)
		var t: int = world.terrain_at(p)
		if t == World.T.WATER:
			continue
		var key: String = str(keys[v - 1])
		var d: Dictionary = acc.get(key, {"sum": Vector2.ZERO, "n": 0, "lo": p, "hi": p})
		d["sum"] = (d["sum"] as Vector2) + p
		d["n"] = int(d["n"]) + 1
		d["lo"] = Vector2(minf(p.x, (d["lo"] as Vector2).x), minf(p.y, (d["lo"] as Vector2).y))
		d["hi"] = Vector2(maxf(p.x, (d["hi"] as Vector2).x), maxf(p.y, (d["hi"] as Vector2).y))
		acc[key] = d
	var places: PackedVector2Array = PackedVector2Array()
	for st in world.settlements:
		places.append(world.settlement_pos(st))
	for st in world.sites:
		places.append(world.settlement_pos(st))
	var out: Dictionary = {}
	for key in acc:
		var d: Dictionary = acc[key]
		var cen: Vector2 = (d["sum"] as Vector2) / float(d["n"])
		var best: Vector2 = cen
		var bd: float = 1e12
		for pass_i in 2:  # 1re passe : à l'écart des lieux (pour que le nom n'écrase aucune étiquette) ; 2e : n'importe où
			for idx in own.size():  # une case du territoire proche du centre (le centre d'une forme creuse peut tomber dehors)
				if own[idx] == 0 or str(keys[own[idx] - 1]) != str(key):
					continue
				var p := Vector2((idx % n + 0.5) * cell, (idx / n + 0.5) * cell)
				var dd: float = p.distance_squared_to(cen)
				if dd >= bd or world.terrain_at(p) == World.T.WATER:
					continue
				if pass_i == 0:
					var clear: bool = true
					for q in places:
						if p.distance_squared_to(q) < 150.0 * 150.0:
							clear = false
							break
					if not clear:
						continue
				bd = dd
				best = p
			if bd < 1e11:
				break
		out[key] = {"pos": best, "w": ((d["hi"] as Vector2) - (d["lo"] as Vector2)).x, "n": int(d["n"])}
	return out


## Nom écrit sur la carte pour une faction (Data.FACTIONS[clé]["region"], sinon son nom).
static func region_name(key: String) -> String:
	var f: Dictionary = Data.FACTIONS.get(key, {})
	return str(f.get("region", f.get("n", "")))
