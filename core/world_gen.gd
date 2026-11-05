class_name WorldGen
extends RefCounted
## Génération du grand monde des nouvelles parties : 180 × 120 cases (3600 × 2400 px), relief en chaînes de montagnes, forêts,
## marais, plaines, côtes et lacs à l'ouest et au sud, grands fleuves à gués, toundra au nord et pays sec au sud.
## Six factions (+ des cités libres) occupent des territoires d'un seul tenant autour de leur capitale ; chaque lieu est relié par
## route aux autres lieux de sa faction, les capitales entre elles. Lieux hostiles, points d'intérêt et bandes errantes suivent.
## Logique pure ; l'aléa vient d'un générateur propre (le reste du déroulé de la partie ne change pas).

const GW: int = 180
const GH: int = 120
## Position approximative des capitales (fractions du monde). « marches » en premier : la compagnie y débute, au centre.
const ORDER: Array = ["marches", "roncevaux", "lys", "abbaye", "givre", "sablefer"]
const ANCHORS: Dictionary = {
	"marches": Vector2(0.50, 0.50), "roncevaux": Vector2(0.23, 0.40), "lys": Vector2(0.20, 0.72), "abbaye": Vector2(0.80, 0.34),
	"givre": Vector2(0.50, 0.12), "sablefer": Vector2(0.72, 0.80),
}
const PLACE_GAP: float = 240.0  ## distance minimale entre deux lieux
const FREE_CITIES: int = 2
const POI_COUNT: int = 30
const POI_KINDS: Array = ["ruins", "shrine", "camp", "tower", "cave"]
const POI_LABEL: Dictionary = {"ruins": "Ruines", "shrine": "Sanctuaire", "camp": "Camp abandonné", "tower": "Tour de guet", "cave": "Grotte"}
const POI_NAMES: Dictionary = {
	"ruins": ["de Vieille-Garde", "du Roi Oublié", "de Pierre-Sèche", "des Trois Tours", "de Haut-Verger", "d'Ombrecoeur", "de l'Ancien Pont"],
	"shrine": ["de la Dame des Eaux", "du Saint Pendu", "des Quatre Vents", "de Sainte-Orcanie", "du Rocher Bénit", "de la Veilleuse"],
	"camp": ["des Déserteurs", "du Convoi Perdu", "des Chasseurs de Loups", "du Colporteur", "des Brûleurs de Charbon", "du Régiment Fantôme"],
	"tower": ["du Guetteur Borgne", "de la Frontière", "du Corbeau Blanc", "de Haut-Regard", "des Cendres", "de la Vigie Brisée"],
	"cave": ["du Loup Gris", "de l'Ours Noir", "des Échos", "du Mineur Fou", "de la Source Froide", "de l'Ermite"],
}


static func _noise(g: RandomNumberGenerator, freq: float, octaves: int = 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = g.randi()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## Point d'entrée : le grand monde complet (terrain, fleuves, lieux, routes, lieux hostiles, points d'intérêt, bandes).
static func generate(p_rng: RandomNumberGenerator, renown: int = 0) -> World:
	var w := World.new()
	w.rng = p_rng
	w.gw = GW
	w.gh = GH
	w.size = Vector2(GW, GH) * World.CELL
	w.configure_grand()
	var g := RandomNumberGenerator.new()
	g.seed = p_rng.randi() ^ 0x6A09E667
	var anchors: Dictionary = {}
	for k in ORDER:
		anchors[k] = (ANCHORS[k] as Vector2) * w.size
	var elev: FastNoiseLite = _terrain(w, g, anchors)
	w._elev = elev
	_rivers(w, g, elev)
	w._build_astar(false)
	_places(w, g, anchors)
	w._build_astar(false)
	w._ensure_connected()
	_repair_territories(w)
	w.build_roads()
	w.player_pos = w.settlement_pos(w.settlements[0])
	w.home = w.player_pos
	var site_rng := RandomNumberGenerator.new()
	site_rng.seed = g.randi()
	w.gen_sites(site_rng)
	gen_pois(w, site_rng)
	w.fill_parties(renown, w.max_parties)
	return w


# --- Relief ---

static func _terrain(w: World, g: RandomNumberGenerator, anchors: Dictionary) -> FastNoiseLite:
	var gw: int = w.gw
	var gh: int = w.gh
	w.terrain.resize(gw * gh)
	var elev: FastNoiseLite = _noise(g, 0.020, 4)
	var ridge: FastNoiseLite = _noise(g, 0.013, 2)
	var moist: FastNoiseLite = _noise(g, 0.028, 3)
	var temp: FastNoiseLite = _noise(g, 0.015, 2)
	var coast: FastNoiseLite = _noise(g, 0.05, 2)
	var acells: Array[Vector2] = []
	for k in anchors:
		acells.append((anchors[k] as Vector2) / World.CELL)
	for y in gh:
		for x in gw:
			var e: float = elev.get_noise_2d(x, y)
			var r: float = 1.0 - absf(ridge.get_noise_2d(x, y)) * 2.2
			var mo: float = moist.get_noise_2d(x, y)
			var infl: float = 0.0  # autour d'une capitale : terrain dégagé
			for a in acells:
				infl = maxf(infl, 1.0 - clampf(Vector2(x, y).distance_to(a) / 15.0, 0.0, 1.0))
			infl = smoothstep(0.0, 0.55, infl)
			e = lerpf(e, 0.0, infl)
			r = lerpf(r, 0.0, infl)
			var chain: float = r + 0.3 * e
			var tmp: float = float(y) / gh + 0.08 * temp.get_noise_2d(x, y) - 0.07 * maxf(e, 0.0)
			var t: int = World.T.PLAIN
			var west: float = 3.0 + 8.0 * (0.5 + 0.5 * coast.get_noise_2d(0.0, y * 1.7))
			var south: float = float(gh) - 3.0 - 6.0 * (0.5 + 0.5 * coast.get_noise_2d(x * 1.7, 500.0))
			if x < 1 or y < 1 or x >= gw - 1 or y >= gh - 1 or x >= gw - 2 - int(3.0 * (0.5 + 0.5 * coast.get_noise_2d(900.0, y * 1.3))):
				t = World.T.MOUNTAIN
			elif (float(x) < west or float(y) > south) and infl < 0.2:
				t = World.T.WATER
			elif e < -0.34 and infl < 0.2:
				t = World.T.WATER
			elif chain > 0.93 or e > 0.55:
				t = World.T.MOUNTAIN
			elif chain > 0.80 or e > 0.30:
				t = World.T.HILLS
			elif e < -0.14 and mo > 0.06 and tmp > 0.25 and tmp < 0.8:
				t = World.T.SWAMP
			elif mo > 0.14 + (0.3 if tmp > 0.78 else 0.0):
				t = World.T.FOREST
			elif tmp < 0.22:
				t = World.T.SNOW
			w.terrain[y * gw + x] = t
	return elev


## Fleuves longs : ils descendent des hauteurs vers un lac ou la mer en suivant le gradient du bruit de hauteur ; plusieurs gués.
static func _rivers(w: World, g: RandomNumberGenerator, elev: FastNoiseLite) -> void:
	var made: int = 0
	var sources: Array[Vector2i] = []
	for attempt in 200:
		if made >= 7:
			break
		var sx: int = g.randi_range(8, w.gw - 9)
		var sy: int = g.randi_range(8, w.gh - 9)
		if elev.get_noise_2d(sx, sy) < 0.22 or w.terrain[sy * w.gw + sx] == World.T.WATER:
			continue
		var near: bool = false
		for o in sources:
			if absi(o.x - sx) + absi(o.y - sy) < 40:
				near = true
		if near:
			continue
		var line: Array[Vector2i] = _river_line(w, Vector2i(sx, sy), g, elev)
		if line.size() < 40:
			continue
		sources.append(Vector2i(sx, sy))
		made += 1
		w._carve_river(line, g)


static func _river_line(w: World, start: Vector2i, g: RandomNumberGenerator, elev: FastNoiseLite) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	var seen: Dictionary = {}
	var cur: Vector2i = start
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for step in 700:
		line.append(cur)
		seen[cur] = true
		if step > 6 and w.terrain[cur.y * w.gw + cur.x] == World.T.WATER:
			return line  # un lac ou la mer
		var best := Vector2i(-1, -1)
		var best_e: float = 99.0
		for d in dirs:
			var n: Vector2i = cur + d
			if n.x < 2 or n.y < 2 or n.x >= w.gw - 2 or n.y >= w.gh - 2 or seen.has(n):
				continue
			var e: float = elev.get_noise_2d(n.x, n.y) + g.randf_range(0.0, 0.03)
			if w.terrain[n.y * w.gw + n.x] == World.T.WATER:
				e -= 1.0  # l'eau attire
			if e < best_e:
				best_e = e
				best = n
		if best.x < 0:
			break
		cur = best
	var none: Array[Vector2i] = []
	return none


# --- Lieux et factions ---

static func _land_ok(w: World, p: Vector2) -> bool:
	if p.x < 100.0 or p.y < 100.0 or p.x > w.size.x - 100.0 or p.y > w.size.y - 100.0:
		return false
	var t: int = w.terrain_at(p)
	return t != World.T.WATER and t != World.T.MOUNTAIN and t != World.T.FORD and t != World.T.BRIDGE


## Dégage la case du lieu et ses voisines : plaine (neige au grand nord), pour que le lieu soit toujours accessible.
static func _clear_around(w: World, p: Vector2) -> void:
	var c: Vector2i = w.cell_of(p)
	var cold: bool = float(c.y) / w.gh < 0.22
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x: int = c.x + dx
			var y: int = c.y + dy
			if x > 0 and y > 0 and x < w.gw - 1 and y < w.gh - 1:
				w.terrain[y * w.gw + x] = World.T.SNOW if cold else World.T.PLAIN


static func _nearest_key(p: Vector2, caps: Dictionary) -> String:
	var best: String = ""
	var bd: float = 1e12
	for k in caps:
		var d: float = p.distance_to(caps[k] as Vector2) / (1.3 if k == "marches" else 1.0)
		if d < bd:
			bd = d
			best = str(k)
	return best


static func _places(w: World, g: RandomNumberGenerator, anchors: Dictionary) -> void:
	var caps: Dictionary = {}
	var used_names: Dictionary = {}
	# 1. capitales : la case praticable la plus proche du point visé
	for k in ORDER:
		var a: Vector2 = anchors[k]
		var best: Vector2 = a
		var bd: float = 1e12
		for dy in range(-14, 15):
			for dx in range(-14, 15):
				var p: Vector2 = a + Vector2(dx, dy) * World.CELL
				if _land_ok(w, p) and p.distance_to(a) < bd:
					bd = p.distance_to(a)
					best = p
		caps[k] = best
		_clear_around(w, best)
		_add_place(w, g, str(k), "city", best, true, used_names)
	# 2. autres lieux de chaque faction : dans sa zone, proches de la capitale
	for k in ORDER:
		var want: int = g.randi_range(3, 5)
		var city_left: int = 1 if g.randf() < 0.55 else 0
		var tries: int = 0
		var placed: int = 0
		var gap: float = PLACE_GAP
		while placed < want and tries < 1500:
			tries += 1
			if tries % 300 == 0:
				gap = maxf(150.0, gap - 25.0)
			var p := Vector2(g.randf_range(100.0, w.size.x - 100.0), g.randf_range(100.0, w.size.y - 100.0))
			if not _land_ok(w, p) or p.distance_to(caps[k] as Vector2) > 860.0 or _nearest_key(p, caps) != str(k):
				continue
			if not _gap_ok(w, p, gap):
				continue
			_clear_around(w, p)
			_add_place(w, g, str(k), "city" if city_left > 0 else "village", p, false, used_names)
			city_left = 0
			placed += 1
	# 3. cités libres : près des frontières entre deux capitales
	var frees: int = 0
	var tries2: int = 0
	var gap2: float = 300.0
	while frees < FREE_CITIES and tries2 < 2500:
		tries2 += 1
		if tries2 % 500 == 0:
			gap2 = maxf(160.0, gap2 - 40.0)
		var p2 := Vector2(g.randf_range(140.0, w.size.x - 140.0), g.randf_range(140.0, w.size.y - 140.0))
		if not _land_ok(w, p2) or not _gap_ok(w, p2, gap2):
			continue
		var ds: Array[float] = []
		for k in caps:
			ds.append(p2.distance_to(caps[k] as Vector2))
		ds.sort()
		if ds[1] - ds[0] > 220.0 or ds[0] < 330.0:
			continue
		var apart: bool = true
		for s in w.settlements:
			if str(s.get("owner", "")) == "libres" and w.settlement_pos(s).distance_to(p2) < 800.0:
				apart = false
		if not apart:
			continue
		_clear_around(w, p2)
		_add_place(w, g, "libres", "city", p2, frees == 0, used_names)
		frees += 1


static func _gap_ok(w: World, p: Vector2, gap: float) -> bool:
	for s in w.settlements:
		if w.settlement_pos(s).distance_to(p) < gap:
			return false
	return true


static func _add_place(w: World, g: RandomNumberGenerator, owner: String, kind: String, p: Vector2, capital: bool, used: Dictionary) -> void:
	var f: Dictionary = Data.FACTIONS[owner]
	var nm: String = ""
	if capital and not used.has(str(f["capital"])):
		nm = str(f["capital"])
	else:
		var pool: Array = (f["places"] as Array).duplicate()
		pool.shuffle()
		for c in pool:
			if not used.has(str(c)):
				nm = str(c)
				break
	if nm == "":  # liste épuisée : on pioche dans la liste générale
		for c in Data.TOWNS:
			if not used.has(str(c)):
				nm = str(c)
				break
	used[nm] = true
	var i: int = w.settlements.size()
	w.settlements.append({
		"id": "s%d" % i, "name": nm, "kind": kind, "owner": owner, "capital": capital,
		"x": p.x, "y": p.y, "price_mult": snappedf(g.randf_range(0.9, 1.15), 0.01),
		"restock_day": 0, "contracts": [], "recruits": [], "standing": 0,
	})


## Chaque faction doit former un territoire d'un seul tenant : un lieu isolé de sa faction passe à la faction qui l'entoure.
static func _repair_territories(w: World) -> void:
	for it in 6:
		var lab: Dictionary = Territory.labels(w, 2)
		var comps: Dictionary = Territory.components(lab)
		var changed: bool = false
		var n: int = int(lab["w"])
		var cell: float = World.CELL * 2.0
		var own: PackedByteArray = lab["own"]
		for key in comps:
			var list: Array = comps[key]
			if list.size() < 2:
				continue
			list.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
			for ci in range(1, list.size()):
				var members: Dictionary = {}
				var votes: Dictionary = {}
				for idx in list[ci]:
					members[idx] = true
					for off in [1, -1, n, -n]:
						var q: int = int(idx) + int(off)
						if q >= 0 and q < own.size() and own[q] != 0 and not members.has(q):
							var kk: String = str((lab["keys"] as Array)[own[q] - 1])
							if kk != str(key):
								votes[kk] = int(votes.get(kk, 0)) + 1
				if votes.is_empty():
					continue
				var best: String = ""
				var bv: int = -1
				var counts: Dictionary = Territory.place_counts(w)
				for kk in votes:
					var score: int = int(votes[kk]) - (100000 if int(counts.get(kk, 0)) >= 6 else 0)  # on évite les factions déjà au complet
					if score > bv:
						bv = score
						best = str(kk)
				for s in w.settlements:
					if str(s.get("owner", "")) != str(key):
						continue
					var sp: Vector2 = w.settlement_pos(s)
					var idx2: int = clampi(int(sp.y / cell), 0, int(lab["h"]) - 1) * n + clampi(int(sp.x / cell), 0, n - 1)
					if members.has(idx2) and not bool(s.get("capital", false)):
						s["owner"] = best
						changed = true
		if not changed:
			return


# --- Points d'intérêt ---

## Une trentaine de points d'intérêt (ruines, sanctuaires, camps abandonnés, tours de guet, grottes) accessibles, espacés.
static func gen_pois(w: World, srng: RandomNumberGenerator) -> void:
	var names_used: Dictionary = {}
	var tries: int = 0
	while w.pois.size() < POI_COUNT and tries < POI_COUNT * 6:
		tries += 1
		var p: Vector2 = w.free_spot(srng, 170.0)
		if p == Vector2.ZERO:
			continue
		var kind: String = str(POI_KINDS[w.pois.size() % POI_KINDS.size()])
		var pool: Array = POI_NAMES[kind]
		var nm: String = "%s %s" % [POI_LABEL[kind], pool[srng.randi() % pool.size()]]
		if names_used.has(nm):
			continue
		names_used[nm] = true
		w.pois.append({"id": "p%d" % w.pois.size(), "kind": kind, "name": nm, "x": p.x, "y": p.y, "done": false})
