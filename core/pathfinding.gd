class_name Pathfinding
extends RefCounted
## Parcours avec zones de contrôle et coût de terrain. `cells` : Vector2i -> {"t": clé de Data.TERRAIN, ...}


static func occupied(units: Array, except: Unit = null) -> Dictionary:
	var s: Dictionary = {}
	for x in units:
		var u: Unit = x
		if u.is_live() and u != except:
			s[u.hex] = true
	return s


## Cases adjacentes à un ennemi de mêlée en état de combattre (ignorées s'il n'y en a qu'une avec Anguille).
static func zoc_cells(u: Unit, units: Array) -> Dictionary:
	var count: Dictionary = {}
	for x in units:
		var f: Unit = x
		if f.is_live() and f.side != u.side and f.morale > 0 and not f.is_ranged():
			for n in Hex.neighbors(f.hex):
				count[n] = int(count.get(n, 0)) + 1
	if u.has_perk("insaisissable"):
		for k in count.keys():
			if int(count[k]) <= 1:
				count.erase(k)
	return count


## Coût pour passer de `from` à `to` (case voisine) : {"ap", "fat"}.
static func step_cost(u: Unit, cells: Dictionary, from: Vector2i, to: Vector2i) -> Dictionary:
	var base_fat: int = u.move_fat()
	if not cells.has(to) or u.has_perk("montagnard"):
		return {"ap": 2, "fat": base_fat}
	var t: Dictionary = Data.TERRAIN[cells[to]["t"]]
	var ap: int = int(t["ap"])
	if cells.has(from) and int(t["h"]) + Scenery.height_bonus(cells, to) > int(Data.TERRAIN[cells[from]["t"]]["h"]) + Scenery.height_bonus(cells, from):
		ap += Data.HILL_CLIMB_AP
	ap = maxi(1, ap - u.swift())  # loups et cavaliers : un PA de moins par case
	return {"ap": ap, "fat": base_fat * int(t["fat_mult"]) + int(t["fat"])}


## Case infranchissable : terrain bloquant ou objet de décor intact (porte fermée, barricade, rempart).
static func blocked(cells: Dictionary, h: Vector2i) -> bool:
	return not cells.has(h) or bool(Data.TERRAIN[cells[h]["t"]]["block"]) or Scenery.blocks_move(cells, h)


## Cases atteignables ce tour (Dijkstra sur les PA, limité par PA et fatigue).
## Retour : Vector2i -> {"s": nb de cases, "ap": PA dépensés, "fat": fatigue, "p": case précédente (Vector2i ou null)}.
## `avoid` : l'unité contourne feu et pièges connus (IA) au lieu de les traverser. Une unité retenue (filet, piège) ne bouge pas.
static func reachable(u: Unit, cells: Dictionary, units: Array, avoid: bool = false) -> Dictionary:
	if u.rooted > 0:
		return {}
	var fat_left: int = u.fat_max_eff() - u.fat
	var occ: Dictionary = occupied(units, u)
	var zoc: Dictionary = zoc_cells(u, units) if u.morale > 0 else {}
	var start: Vector2i = u.hex
	var best: Dictionary = {start: {"s": 0, "ap": 0, "fat": 0, "p": null}}
	var done: Dictionary = {}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var bi: int = 0
		for i in range(1, open.size()):
			var a: Dictionary = best[open[i]]
			var b: Dictionary = best[open[bi]]
			if int(a["ap"]) < int(b["ap"]) or (int(a["ap"]) == int(b["ap"]) and int(a["fat"]) < int(b["fat"])):
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		if done.has(cur):
			continue
		done[cur] = true
		if cur != start and zoc.has(cur):
			continue
		var cb: Dictionary = best[cur]
		for n in Hex.neighbors(cur):
			if blocked(cells, n) or occ.has(n) or done.has(n):
				continue
			if avoid and Scenery.hazard_for(cells, n, u):
				continue
			var c: Dictionary = step_cost(u, cells, cur, n)
			var ap: int = int(cb["ap"]) + int(c["ap"])
			var fat: int = int(cb["fat"]) + int(c["fat"])
			if ap > u.ap or fat > fat_left:
				continue
			if best.has(n):
				var old: Dictionary = best[n]
				if ap > int(old["ap"]) or (ap == int(old["ap"]) and fat >= int(old["fat"])):
					continue
			best[n] = {"s": int(cb["s"]) + 1, "ap": ap, "fat": fat, "p": cur}
			open.append(n)
	best.erase(start)
	return best


static func path_to(reach: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var k: Variant = target
	while k != null and reach.has(k):
		out.push_front(k)
		k = reach[k]["p"]
	return out


## Coût en PA (unités et zones de contrôle ignorées) pour rejoindre une des `targets` depuis chaque case.
## Sert à l'IA de mêlée pour contourner rivières et obstacles.
static func distance_field(cells: Dictionary, targets: Array) -> Dictionary:
	var dist: Dictionary = {}
	var open: Array[Vector2i] = []
	for t in targets:
		dist[t] = 0
		open.append(t)
	while not open.is_empty():
		var bi: int = 0
		for i in range(1, open.size()):
			if int(dist[open[i]]) < int(dist[open[bi]]):
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		for n in Hex.neighbors(cur):
			if blocked(cells, n):
				continue
			var nd: int = int(dist[cur]) + int(Data.TERRAIN[cells[cur]["t"]]["ap"])
			if not dist.has(n) or nd < int(dist[n]):
				dist[n] = nd
				open.append(n)
	return dist
