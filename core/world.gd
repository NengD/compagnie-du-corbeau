class_name World
extends RefCounted
## La carte du monde : terrain, villes et villages, bandes errantes, déplacement de la compagnie.
## Logique pure (aucun nœud de scène). Aléa injecté. Positions en pixels du monde (1600 × 1000).

enum T { PLAIN, FOREST, HILLS, WATER, MOUNTAIN, BRIDGE, FORD }

const CELL: float = 20.0
const GW: int = 80
const GH: int = 50
const SIZE: Vector2 = Vector2(GW * CELL, GH * CELL)
const DAY_PX: float = 100.0  ## distance parcourue en un jour en terrain plat
const COST: Array[float] = [1.0, 1.5, 1.35, 0.0, 0.0, 0.9, 2.0]  ## coût en temps par type de terrain (0 = infranchissable)
const ROAD_COST: float = 0.8  ## coût d'une case de route (si elle est moins chère que le terrain)
const TERRAIN_NAMES: Array[String] = ["Plaine", "Forêt", "Collines", "Eau", "Montagne", "Pont", "Gué"]
const RIVERS_MAX: int = 4
const ARRIVE_PX: float = 26.0
const ENCOUNTER_PX: float = 26.0
const MAX_PARTIES: int = 4
const CITIES: int = 3
const VILLAGES: int = 5

var rng: RandomNumberGenerator
var terrain: PackedInt32Array = PackedInt32Array()
var settlements: Array[Dictionary] = []
var parties: Array[Dictionary] = []
var sites: Array[Dictionary] = []  ## lieux hostiles (forts, repaires, nécropoles, citadelle) : voir Campaign
var player_pos: Vector2 = Vector2.ZERO
var path: Array[Vector2] = []
var dest: Dictionary = {}  ## {"kind": "settlement"|"target"|"party"|"point", "id": ...}
var next_party_id: int = 1
var road_paths: Array[PackedVector2Array] = []  ## routes décoratives (centres de cases), recalculées à la génération et au chargement
var road_cells: Dictionary = {}  ## Vector2i -> true : cases de route (coût ROAD_COST)
var _astar: AStarGrid2D
var _elev: FastNoiseLite


# --- Génération ---

static func generate(p_rng: RandomNumberGenerator, renown: int = 0) -> World:
	var w := World.new()
	w.rng = p_rng
	w._build_terrain()
	var river_rng := RandomNumberGenerator.new()  # aléa propre : le reste du déroulé ne change pas
	river_rng.seed = p_rng.seed ^ 0x71E5
	w._build_rivers(river_rng)
	w._build_astar(false)
	w._place_settlements()
	w._ensure_connected()
	w.build_roads()
	w.player_pos = w.settlement_pos(w.settlements[0])
	w.fill_parties(renown, MAX_PARTIES)
	var site_rng := RandomNumberGenerator.new()  # aléa propre : ne modifie pas le déroulé du reste de la partie
	site_rng.seed = p_rng.seed ^ 0x51ED
	w.gen_sites(site_rng)
	return w


func _noise(freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 3
	return n


func _build_terrain() -> void:
	terrain.resize(GW * GH)
	var elev: FastNoiseLite = _noise(0.04)
	_elev = elev
	var moist: FastNoiseLite = _noise(0.06)
	for y in GH:
		for x in GW:
			var e: float = elev.get_noise_2d(x, y)
			var m: float = moist.get_noise_2d(x, y)
			var t: int = T.PLAIN
			if x < 1 or y < 1 or x >= GW - 1 or y >= GH - 1 or e > 0.5:
				t = T.MOUNTAIN
			elif e < -0.38:
				t = T.WATER
			elif e > 0.28:
				t = T.HILLS
			elif m > 0.2:
				t = T.FOREST
			terrain[y * GW + x] = t


func _build_astar(with_roads: bool = true) -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, GW, GH)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.offset = Vector2(CELL / 2.0, CELL / 2.0)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in GH:
		for x in GW:
			var c: float = _cell_cost(x, y) if with_roads else COST[terrain[y * GW + x]]
			if c <= 0.0:
				_astar.set_point_solid(Vector2i(x, y), true)
			else:
				_astar.set_point_weight_scale(Vector2i(x, y), c)


func _place_settlements() -> void:
	var names: Array = Data.TOWNS.duplicate()
	for i in names.size():
		var j: int = rng.randi() % names.size()
		var t: Variant = names[i]
		names[i] = names[j]
		names[j] = t
	var min_dist: float = 260.0
	var tries: int = 0
	var total: int = CITIES + VILLAGES
	while settlements.size() < total:
		tries += 1
		if tries % 150 == 0:
			min_dist = maxf(120.0, min_dist - 20.0)
		var p := Vector2(rng.randf_range(80.0, SIZE.x - 80.0), rng.randf_range(80.0, SIZE.y - 80.0))
		if terrain_at(p) != T.PLAIN:
			continue
		var ok: bool = true
		for s in settlements:
			if settlement_pos(s).distance_to(p) < min_dist:
				ok = false
				break
		if not ok:
			continue
		var i: int = settlements.size()
		settlements.append({
			"id": "s%d" % i, "name": str(names[i]), "kind": "city" if i < CITIES else "village",
			"x": p.x, "y": p.y, "price_mult": snappedf(rng.randf_range(0.9, 1.15), 0.01),
			"restock_day": 0, "contracts": [], "recruits": [], "standing": 0,
		})


## Rivières : lignes sinueuses de cases d'eau qui descendent des hauteurs vers un lac ou la mer, par le gradient du bruit
## de hauteur (largeur 1-2 cases). Quelques gués les rendent franchissables. Aléa propre (`rr`).
func _build_rivers(rr: RandomNumberGenerator) -> void:
	if _elev == null:
		return
	var made: int = 0
	var sources: Array[Vector2i] = []
	for attempt in 60:
		if made >= RIVERS_MAX:
			break
		var sx: int = rr.randi_range(4, GW - 5)
		var sy: int = rr.randi_range(4, GH - 5)
		if _elev.get_noise_2d(sx, sy) < 0.28:
			continue
		var near: bool = false
		for o in sources:
			if absi(o.x - sx) + absi(o.y - sy) < 22:
				near = true
		if near:
			continue
		var line: Array[Vector2i] = _river_line(Vector2i(sx, sy), rr)
		if line.size() < 12:
			continue
		sources.append(Vector2i(sx, sy))
		made += 1
		_carve_river(line, rr)


## Descend du point `start` : à chaque pas, le voisin le plus bas encore inconnu (un peu de hasard). Vide si elle n'atteint pas l'eau.
func _river_line(start: Vector2i, rr: RandomNumberGenerator) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	var seen: Dictionary = {}
	var cur: Vector2i = start
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for step in 260:
		line.append(cur)
		seen[cur] = true
		if step > 3 and _elev.get_noise_2d(cur.x, cur.y) < -0.38:
			return line  # un lac ou la mer
		var best := Vector2i(-1, -1)
		var best_e: float = 99.0
		for d in dirs:
			var n: Vector2i = cur + d
			if n.x < 1 or n.y < 1 or n.x >= GW - 1 or n.y >= GH - 1 or seen.has(n):
				continue
			var e: float = _elev.get_noise_2d(n.x, n.y) + rr.randf_range(0.0, 0.035)
			if e < best_e:
				best_e = e
				best = n
		if best.x < 0:
			break
		cur = best
	var none: Array[Vector2i] = []
	return none


func _carve_river(line: Array[Vector2i], rr: RandomNumberGenerator) -> void:
	var groups: Array = []  # une entrée par pas : les cases d'eau de ce pas (pour poser un gué en travers)
	var wide: bool = false
	for i in line.size():
		var c: Vector2i = line[i]
		if i % 9 == 0:
			wide = rr.randf() < 0.4  # le lit s'élargit par endroits
		var cells: Array[Vector2i] = [c]
		if wide and i > 2:
			var dl: Vector2i = c - line[i - 1]
			var o: Vector2i = c + Vector2i(-dl.y, dl.x)
			if o.x > 0 and o.y > 0 and o.x < GW - 1 and o.y < GH - 1:
				cells.append(o)
		for q in cells:
			terrain[q.y * GW + q.x] = T.WATER
		groups.append(cells)
	# gués : un à trois par rivière
	var fords: int = clampi(line.size() / 28 + 1, 1, 3)
	for k in fords:
		var idx: int = int(float(line.size()) * (float(k) + rr.randf_range(0.25, 0.75)) / float(fords))
		idx = clampi(idx, 2, line.size() - 3)
		for q in groups[idx]:
			terrain[q.y * GW + q.x] = T.FORD


## Prix du percement d'un passage : l'eau et la montagne sont chères mais franchissables ; gués et ponts existants peu chers.
func _carve_cost(t: int) -> float:
	match t:
		T.WATER:
			return 9.0
		T.MOUNTAIN:
			return 14.0
	return COST[t] if COST[t] > 0.0 else 1.0


## Relie chaque lieu isolé par l'eau ou la montagne : le passage le moins cher pose un pont sur l'eau (ou ouvre un col).
func _ensure_connected() -> void:
	var base: Vector2 = settlement_pos(settlements[0])
	for i in range(1, settlements.size()):
		var p: Vector2 = settlement_pos(settlements[i])
		if not find_path(base, p).is_empty():
			continue
		var carve := AStarGrid2D.new()
		carve.region = Rect2i(1, 1, GW - 2, GH - 2)
		carve.cell_size = Vector2(CELL, CELL)
		carve.offset = Vector2(CELL / 2.0, CELL / 2.0)
		carve.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		carve.update()
		for y in range(1, GH - 1):
			for x in range(1, GW - 1):
				carve.set_point_weight_scale(Vector2i(x, y), _carve_cost(terrain[y * GW + x]))
		var pts: PackedVector2Array = carve.get_point_path(cell_of(base), cell_of(p))
		for v in pts:
			var c: Vector2i = cell_of(v)
			var k: int = c.y * GW + c.x
			if terrain[k] == T.WATER:
				terrain[k] = T.BRIDGE
			elif terrain[k] == T.MOUNTAIN:
				terrain[k] = T.HILLS
		_build_astar(false)
		if find_path(base, p).is_empty():  # repli : l'ancien creusage en ligne droite
			_carve_straight(base, p)
			_build_astar(false)


func _carve_straight(base: Vector2, p: Vector2) -> void:
	var steps: int = int(base.distance_to(p) / (CELL * 0.5))
	for k in steps + 1:
		var q: Vector2 = base.lerp(p, float(k) / steps)
		var c: Vector2i = cell_of(q)
		for dx in [-1, 0, 1]:
			for dy in [-1, 0]:
				var n := Vector2i(c.x + dx, c.y + dy)
				if n.x > 0 and n.y > 0 and n.x < GW - 1 and n.y < GH - 1 and COST[terrain[n.y * GW + n.x]] <= 0.0:
					terrain[n.y * GW + n.x] = T.PLAIN


# --- Routes ---

func _cell_cost(x: int, y: int) -> float:
	var c: float = COST[terrain[y * GW + x]]
	if c > 0.0 and road_cells.has(Vector2i(x, y)):
		return minf(c, ROAD_COST)
	return c


## Réseau routier décoratif : chaque lieu est relié à ses deux plus proches voisins par le chemin le moins cher.
## Un gué traversé par une route devient un pont. Fixe `road_paths` et `road_cells` puis reconstruit la grille de chemins
## (cases de route moins chères). Déterministe : même résultat à la génération et au chargement d'une sauvegarde.
func build_roads() -> void:
	road_paths.clear()
	road_cells.clear()
	_build_astar(false)
	for y in GH:  # gués et ponts au même prix, pour que la transformation gué -> pont ne change pas les routes
		for x in GW:
			var t: int = terrain[y * GW + x]
			if t == T.FORD or t == T.BRIDGE:
				_astar.set_point_weight_scale(Vector2i(x, y), 1.5)
	var done: Dictionary = {}
	for i in settlements.size():
		var a: Vector2 = settlement_pos(settlements[i])
		var order: Array = range(settlements.size())
		order.erase(i)
		order.sort_custom(func(p: int, q: int) -> bool: return a.distance_to(settlement_pos(settlements[p])) < a.distance_to(settlement_pos(settlements[q])))
		for j in order.slice(0, 2):
			var key: String = "%d-%d" % [mini(i, j), maxi(i, j)]
			if done.has(key):
				continue
			done[key] = true
			var pts: PackedVector2Array = _astar.get_point_path(cell_of(a), cell_of(settlement_pos(settlements[j])))
			if pts.size() < 2:
				continue
			pts[0] = a
			pts[pts.size() - 1] = settlement_pos(settlements[j])
			road_paths.append(pts)
			for v in pts:
				var c: Vector2i = cell_of(v)
				road_cells[c] = true
				if terrain[c.y * GW + c.x] == T.FORD:
					terrain[c.y * GW + c.x] = T.BRIDGE
	_build_astar(true)


func is_road(p: Vector2) -> bool:
	return road_cells.has(cell_of(p))


## Nom du terrain sous le point (« Route » si une route le traverse).
func terrain_label(p: Vector2) -> String:
	var t: int = terrain_at(p)
	if is_road(p) and t != T.BRIDGE:
		return "Route"
	return TERRAIN_NAMES[t]


# --- Lieux hostiles ---

func site_by_id(id: String) -> Dictionary:
	for s in sites:
		if s["id"] == id:
			return s
	return {}


func site_near(p: Vector2, radius: float) -> Dictionary:
	for s in sites:
		if settlement_pos(s).distance_to(p) <= radius:
			return s
	return {}


## Un point accessible, à l'écart des lieux et du joueur, relié à la compagnie par un chemin (Vector2.ZERO sinon).
func free_spot(srng: RandomNumberGenerator, min_gap: float = 150.0) -> Vector2:
	for i in 120:
		var p := Vector2(srng.randf_range(80.0, SIZE.x - 80.0), srng.randf_range(80.0, SIZE.y - 80.0))
		if not passable(p) or p.distance_to(player_pos) < 200.0:
			continue
		var ok: bool = true
		for s in settlements:
			if settlement_pos(s).distance_to(p) < min_gap:
				ok = false
		for s in sites:
			if settlement_pos(s).distance_to(p) < min_gap:
				ok = false
		if ok and not find_path(player_pos, p).is_empty():
			return p
	return Vector2.ZERO


## Ajoute un lieu hostile de ce type ; renvoie-le ({} si aucune place).
func add_site(kind: String, srng: RandomNumberGenerator, faction: String = "", gap: float = 150.0) -> Dictionary:
	var p: Vector2 = free_spot(srng, gap)
	if p == Vector2.ZERO:
		return {}
	var s: Dictionary = Campaign.make_site(kind, "h%d" % sites.size(), p, srng, faction)
	sites.append(s)
	return s


func gen_sites(srng: RandomNumberGenerator) -> void:
	for kind in Campaign.START_SITES:
		add_site(str(kind), srng)


# --- Terrain ---

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, GW - 1), clampi(int(p.y / CELL), 0, GH - 1))


func terrain_at(p: Vector2) -> int:
	var c: Vector2i = cell_of(p)
	return terrain[c.y * GW + c.x]


## Biome du plateau de combat à cette position : "plain", "forest", "hills" ou "water".
func biome_at(p: Vector2) -> String:
	match terrain_at(p):
		T.FOREST:
			return "forest"
		T.HILLS, T.MOUNTAIN:
			return "hills"
		T.WATER, T.FORD:
			return "water"
	return "plain"


func cost_at(p: Vector2) -> float:
	var c: Vector2i = cell_of(p)
	return _cell_cost(c.x, c.y)


func passable(p: Vector2) -> bool:
	return p.x > CELL and p.y > CELL and p.x < SIZE.x - CELL and p.y < SIZE.y - CELL and cost_at(p) > 0.0


func find_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not passable(from) or not passable(to):
		return out
	var pts: PackedVector2Array = _astar.get_point_path(cell_of(from), cell_of(to))
	if pts.is_empty():
		return out
	for i in pts.size():
		out.append(pts[i])
	out[0] = from
	out[out.size() - 1] = to
	return out


## Un point accessible à une distance comprise entre `lo` et `hi` de `origin` (Vector2.ZERO si introuvable).
func random_target(origin: Vector2, lo: float, hi: float) -> Vector2:
	for i in 60:
		var p: Vector2 = origin + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(lo, hi)
		if passable(p) and not find_path(origin, p).is_empty():
			return p
	return Vector2.ZERO


# --- Lieux ---

func settlement_pos(s: Dictionary) -> Vector2:
	return Vector2(float(s["x"]), float(s["y"]))


func settlement_by_id(id: String) -> Dictionary:
	for s in settlements:
		if s["id"] == id:
			return s
	return {}


const STANDING_MAX: int = 10


## Réputation de la compagnie dans un lieu, bornée à [−10, 10].
func standing_of(s: Dictionary) -> int:
	return int(s.get("standing", 0))


func change_standing(id: String, delta: int) -> void:
	var s: Dictionary = settlement_by_id(id)
	if not s.is_empty():
		s["standing"] = clampi(standing_of(s) + delta, -STANDING_MAX, STANDING_MAX)


static func standing_label(n: int) -> String:
	if n >= 7:
		return "Admirée"
	if n >= 3:
		return "Estimée"
	if n > -3:
		return "Inconnue" if n == 0 else "Neutre"
	if n > -7:
		return "Méfiante"
	return "Haïe"


## Coefficient de prix selon la réputation : de ×0,90 (+10) à ×1,10 (−10).
static func standing_price_mult(n: int) -> float:
	return 1.0 - clampf(float(n) * 0.01, -0.1, 0.1)


func settlement_near(p: Vector2, radius: float = ARRIVE_PX) -> Dictionary:
	for s in settlements:
		if settlement_pos(s).distance_to(p) <= radius:
			return s
	return {}


func party_pos(p: Dictionary) -> Vector2:
	return Vector2(float(p["x"]), float(p["y"]))


func party_by_id(id: int) -> Dictionary:
	for p in parties:
		if int(p["id"]) == id:
			return p
	return {}


func party_near(p: Vector2, radius: float) -> Dictionary:
	for q in parties:
		if party_pos(q).distance_to(p) <= radius:
			return q
	return {}


# --- Déplacement de la compagnie ---

func set_destination(target: Vector2, info: Dictionary) -> bool:
	var p: Array[Vector2] = find_path(player_pos, target)
	if p.is_empty():
		return false
	path = p
	dest = info
	return true


func stop() -> void:
	path.clear()
	dest = {}


## Durée en jours d'un chemin (coût du terrain compris).
func path_days(pts: Array[Vector2]) -> float:
	var total: float = 0.0
	for i in range(1, pts.size()):
		var mult: float = cost_at(pts[i - 1].lerp(pts[i], 0.5))
		total += pts[i - 1].distance_to(pts[i]) * (mult if mult > 0.0 else 1.0) / DAY_PX
	return total


## Avance le long du chemin pendant `days` jours. Renvoie le temps réellement utilisé.
func step_player(days: float) -> float:
	var remaining: float = days
	while remaining > 0.00001 and not path.is_empty():
		var wp: Vector2 = path[0]
		var seg: Vector2 = wp - player_pos
		var length: float = seg.length()
		if length < 0.01:
			path.pop_front()
			continue
		var mult: float = cost_at(player_pos.lerp(wp, 0.5))
		if mult <= 0.0:
			mult = 1.0
		var need: float = length * mult / DAY_PX
		if need <= remaining:
			player_pos = wp
			path.pop_front()
			remaining -= need
		else:
			player_pos += seg * (remaining / need)
			remaining = 0.0
	return days - remaining


# --- Bandes errantes ---

func fill_parties(renown: int, count: int) -> void:
	var tries: int = 0
	while parties.size() < count and tries < 200:
		tries += 1
		var p := Vector2(rng.randf_range(60.0, SIZE.x - 60.0), rng.randf_range(60.0, SIZE.y - 60.0))
		if not passable(p) or p.distance_to(player_pos) < 220.0:
			continue
		var near_town: bool = false
		for s in settlements:
			if settlement_pos(s).distance_to(p) < 140.0:
				near_town = true
		if near_town:
			continue
		var type: String = str(Contracts.pick(Contracts.factions_for(renown), rng))
		var d: int = clampi(mini(3, 1 + renown / 160) + int(Contracts.pick([-1, 0, 0, 1], rng)), 1, 3)
		parties.append({
			"id": next_party_id, "faction": type, "d": d, "foes": Contracts.foes_for(type, d),
			"x": p.x, "y": p.y, "gx": p.x, "gy": p.y, "aggressive": type == "b" or type == "o", "cooldown": 0.0,
		})
		next_party_id += 1


## Une bande de plus (événements d'escalade) loin de la compagnie ; renvoie-la ({} si aucune place).
func spawn_party(type: String, d: int, srng: RandomNumberGenerator) -> Dictionary:
	for i in 60:
		var p := Vector2(srng.randf_range(60.0, SIZE.x - 60.0), srng.randf_range(60.0, SIZE.y - 60.0))
		if not passable(p) or p.distance_to(player_pos) < 260.0 or not settlement_near(p, 140.0).is_empty():
			continue
		var party: Dictionary = {
			"id": next_party_id, "faction": type, "d": d, "foes": Contracts.foes_for(type, d),
			"x": p.x, "y": p.y, "gx": p.x, "gy": p.y, "aggressive": type == "b" or type == "o", "cooldown": 0.0,
		}
		next_party_id += 1
		parties.append(party)
		return party
	return {}


func party_title(p: Dictionary) -> String:
	if p.has("title"):
		return str(p["title"])
	return str(Data.FACTION_PARTY_TITLES.get(str(p["faction"]), "Bande errante"))


func _new_goal(p: Dictionary) -> void:
	var pos: Vector2 = party_pos(p)
	for i in 8:
		var g: Vector2 = pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60.0, 220.0)
		if passable(g):
			p["gx"] = g.x
			p["gy"] = g.y
			return
	p["gx"] = pos.x
	p["gy"] = pos.y


func update_parties(dt: float) -> void:
	for p in parties:
		p["cooldown"] = maxf(0.0, float(p["cooldown"]) - dt)
		var pos: Vector2 = party_pos(p)
		var goal: Vector2 = Vector2(float(p["gx"]), float(p["gy"]))
		var speed: float = 55.0
		if float(p["cooldown"]) <= 0.0 and p["aggressive"] and pos.distance_to(player_pos) < 170.0:
			goal = player_pos
			speed = 75.0
		elif pos.distance_to(goal) < 12.0:
			_new_goal(p)
			continue
		var dir: Vector2 = goal - pos
		if dir.length() < 1.0:
			continue
		var step: Vector2 = dir.normalized() * speed * dt
		if passable(pos + step):
			pos += step
		elif passable(pos + Vector2(step.x, 0.0)):
			pos.x += step.x
		elif passable(pos + Vector2(0.0, step.y)):
			pos.y += step.y
		else:
			_new_goal(p)
		p["x"] = pos.x
		p["y"] = pos.y


## Bande engageant la compagnie (au contact et pas en repos), ou {}.
func encounter() -> Dictionary:
	for p in parties:
		if float(p["cooldown"]) <= 0.0 and party_pos(p).distance_to(player_pos) <= ENCOUNTER_PX:
			return p
	return {}


# --- Sérialisation ---

func to_dict() -> Dictionary:
	var sl: Array = []
	for s in settlements:
		var d: Dictionary = s.duplicate()
		var rec: Array = []
		for r in s["recruits"]:
			rec.append({"u": r["u"].to_dict(), "price": r["price"]})
		d["recruits"] = rec
		sl.append(d)
	var pts: Array = []
	for v in path:
		pts.append([v.x, v.y])
	return {
		"terrain": Array(terrain), "settlements": sl, "parties": parties, "px": player_pos.x, "py": player_pos.y,
		"path": pts, "dest": dest, "next_party_id": next_party_id, "sites": sites.duplicate(true),
	}


static func from_dict(d: Dictionary, p_rng: RandomNumberGenerator) -> World:
	var w := World.new()
	w.rng = p_rng
	w.terrain.resize(GW * GH)
	var t: Array = d["terrain"]
	for i in t.size():
		w.terrain[i] = int(t[i])
	for sd in d["settlements"]:
		var s: Dictionary = sd.duplicate()
		for k in ["x", "y", "price_mult"]:
			s[k] = float(sd[k])
		s["restock_day"] = int(sd["restock_day"])
		s["standing"] = int(sd.get("standing", 0))
		var rec: Array = []
		for r in sd["recruits"]:
			rec.append({"u": Unit.from_dict(r["u"]), "price": int(r["price"])})
		s["recruits"] = rec
		s["rare"] = Campaign.clean_rare(sd.get("rare", []))
		if sd.has("stock"):
			s["stock"] = Market.clean(sd["stock"])  ## absent d'une ancienne sauvegarde : généré à la demande (Game.shop_stock)
		s["contracts"] = []
		for c in sd["contracts"]:
			s["contracts"].append(Contracts.normalize(c))
		w.settlements.append(s)
	for pd in d["parties"]:
		var p: Dictionary = pd.duplicate()
		p["id"] = int(pd["id"])
		p["d"] = int(pd["d"])
		for k in ["x", "y", "gx", "gy", "cooldown"]:
			p[k] = float(pd[k])
		w.parties.append(p)
	w.player_pos = Vector2(float(d["px"]), float(d["py"]))
	for v in d["path"]:
		w.path.append(Vector2(float(v[0]), float(v[1])))
	w.dest = d["dest"]
	w.next_party_id = int(d["next_party_id"])
	for sd in d.get("sites", []):
		w.sites.append(Campaign.clean_site(sd))
	w.build_roads()  # les routes se recalculent (anciennes sauvegardes comprises) ; le terrain enregistré reste tel quel
	return w
