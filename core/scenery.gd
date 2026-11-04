class_name Scenery
extends RefCounted
## Décor interactif d'une bataille : feu, portes, barricades, pièges, remparts, torches (voir Data.SCENERY).
## Un objet vit dans `cells[hex]["obj"]` = {"kind", "hp", "open", "hidden", "ttl", "top", "owner"} ; une case n'en porte qu'un.
## Logique pure : l'aléa est celui de la bataille (`s.rng`).

const FLAMMABLE: Array[String] = ["g", "forest", "hill"]


static func obj_at(cells: Dictionary, h: Vector2i) -> Dictionary:
	if cells.has(h) and (cells[h] as Dictionary).has("obj"):
		return cells[h]["obj"]
	return {}


static func kind_at(cells: Dictionary, h: Vector2i) -> String:
	return str(obj_at(cells, h).get("kind", ""))


static func data_of(o: Dictionary) -> Dictionary:
	return Data.SCENERY.get(str(o.get("kind", "")), {})


## Crée un objet sur la case (écrase le précédent). `extra` : champs en plus (owner, hidden, top, ttl, hp…).
static func place(cells: Dictionary, h: Vector2i, kind: String, extra: Dictionary = {}) -> Dictionary:
	var o: Dictionary = {"kind": kind, "hp": int(Data.SCENERY[kind]["hp"])}
	o.merge(extra, true)
	cells[h]["obj"] = o
	return o


static func remove(cells: Dictionary, h: Vector2i) -> void:
	if cells.has(h):
		(cells[h] as Dictionary).erase("obj")


## L'objet empêche-t-il de marcher sur la case ? (porte ouverte, rempart tenu par un archer : non)
static func blocks_move(cells: Dictionary, h: Vector2i) -> bool:
	var o: Dictionary = obj_at(cells, h)
	if o.is_empty():
		return false
	if bool(o.get("open", false)) or bool(o.get("top", false)):
		return false
	return bool(data_of(o).get("block", false))


static func blocks_los(cells: Dictionary, h: Vector2i) -> bool:
	var o: Dictionary = obj_at(cells, h)
	if o.is_empty() or bool(o.get("open", false)):
		return false
	return bool(data_of(o).get("los", false))


## Hauteur de la case : un chemin de ronde domine (comme une colline).
static func height_bonus(cells: Dictionary, h: Vector2i) -> int:
	return 1 if bool(obj_at(cells, h).get("top", false)) else 0


## Objet qui peut se détruire à coups d'arme (porte, barricade, porte du fort) et qui barre encore la route.
static func breakable(cells: Dictionary, h: Vector2i) -> bool:
	var o: Dictionary = obj_at(cells, h)
	return not o.is_empty() and int(data_of(o).get("hp", 0)) > 0 and blocks_move(cells, h)


## Objet que `u` sait dangereux (feu visible, piège découvert ou posé par son camp… sauf piège de son camp).
static func hazard_for(cells: Dictionary, h: Vector2i, u: Unit) -> bool:
	var o: Dictionary = obj_at(cells, h)
	match str(o.get("kind", "")):
		"fire":
			return true
		"trap":
			return str(o.get("owner", "e")) != u.side and (not bool(o.get("hidden", false)) or str(o.get("owner", "e")) == u.side)
	return false


# --- Lumière ---

static func light_radius(o: Dictionary) -> int:
	return int(data_of(o).get("light", 0))


## La case est-elle éclairée (torche ou feu à portée) ?
static func lit(cells: Dictionary, h: Vector2i) -> bool:
	for k in cells:
		var o: Dictionary = obj_at(cells, k)
		if o.is_empty():
			continue
		var r: int = light_radius(o)
		if r > 0 and Hex.distance(k, h) <= r:
			return true
	return false


# --- Feu ---

static func flammable(cells: Dictionary, h: Vector2i) -> bool:
	if not cells.has(h) or not FLAMMABLE.has(str(cells[h]["t"])):
		return false
	var o: Dictionary = obj_at(cells, h)
	return o.is_empty() or str(o.get("kind", "")) == "torch"


static func fire_ttl(s: BattleState) -> int:
	return s.rng.randi_range(3, 5) - (2 if s.rain else 0)


## Met le feu à la case (si elle brûle). Les unités qui s'y trouvent sont brûlées tout de suite. Renvoie true si une flamme est née.
static func ignite(s: BattleState, h: Vector2i) -> bool:
	if not flammable(s.cells, h):
		return false
	place(s.cells, h, "fire", {"ttl": maxi(1, fire_ttl(s))})
	s.say("Le feu prend.", "mor")
	var u: Unit = s.unit_at(h)
	if u != null:
		burn(s, u)
	return true


## Brûlure : dégâts légers directs aux PV, test de moral. Peut tuer.
static func burn(s: BattleState, u: Unit) -> void:
	if not u.is_live():
		return
	var d: Dictionary = Data.SCENERY["fire"]
	var dmg: int = s.rng.randi_range(int(d["dmg"][0]), int(d["dmg"][1]))
	u.hp -= dmg
	u.hit_taken = true
	s.say("%s brûle : %d PV." % [u.unit_name, dmg], "hit")
	if u.hp <= 0:
		s.kill_env(u, "les flammes")
	else:
		s.morale_test(u, int(d["morale"]), "est pris par les flammes")


## Fin de manche : les feux faiblissent, gagnent du terrain (pas sous la pluie), les eaux les éteignent.
static func tick_round(s: BattleState) -> void:
	var fires: Array[Vector2i] = []
	for h in s.cells:
		if kind_at(s.cells, h) == "fire":
			fires.append(h)
	for h in fires:
		var o: Dictionary = obj_at(s.cells, h)
		o["ttl"] = int(o.get("ttl", 3)) - (2 if s.rain else 1)
		if int(o["ttl"]) <= 0:
			remove(s.cells, h)
			continue
		if s.rain:
			continue
		for n in Hex.neighbors(h):
			if flammable(s.cells, n):
				var p: float = Data.FIRE_SPREAD * (2.0 if str(s.cells[n]["t"]) == "forest" else 1.0)
				if s.rng.randf() < p:
					ignite(s, n)


## Début de tour de `u` : brûlure si le feu l'entoure encore, détection des pièges cachés alentour.
static func start_of_turn(s: BattleState, u: Unit) -> void:
	if kind_at(s.cells, u.hex) == "fire":
		burn(s, u)
	if not u.is_live():
		return
	for h in s.cells:
		var o: Dictionary = obj_at(s.cells, h)
		if str(o.get("kind", "")) != "trap" or not bool(o.get("hidden", false)) or str(o.get("owner", "e")) == u.side:
			continue
		if Hex.distance(h, u.hex) > Data.DETECT_RANGE:
			continue
		var chance: int = int(Data.SCENERY["trap"]["detect"]) + u.eff("initiative") / 5 + (15 if u.has_perk("oeil_de_lynx") or u.has_perk("vif") else 0)
		if s.rng.randi_range(1, 100) <= clampi(chance, 5, 90):
			o["hidden"] = false
			s.say("%s repère un piège." % u.unit_name, "sys")


## `u` vient d'entrer sur sa case : feu, piège, torche renversée. Renvoie true si son déplacement doit s'arrêter là.
static func on_enter(s: BattleState, u: Unit) -> bool:
	var o: Dictionary = obj_at(s.cells, u.hex)
	if o.is_empty():
		return false
	match str(o["kind"]):
		"fire":
			burn(s, u)
			return not u.is_live()
		"trap":
			if str(o.get("owner", "e")) == u.side:
				return false  # on connaît les pièges de son camp
			var d: Dictionary = Data.SCENERY["trap"]
			var dmg: int = s.rng.randi_range(int(d["dmg"][0]), int(d["dmg"][1]))
			u.hp -= dmg
			u.hit_taken = true
			o["hidden"] = false
			s.say("%s tombe dans un piège : %d PV." % [u.unit_name, dmg], "hit")
			remove(s.cells, u.hex)
			if u.hp <= 0:
				s.kill_env(u, "le piège")
				return true
			if not u.is_big():
				u.rooted = 1
				u.ap = 0
				s.say("%s est retenu." % u.unit_name, "miss")
			return true
		"torch":
			if s.rng.randf() < 0.5:
				remove(s.cells, u.hex)
				s.say("%s renverse une torche." % u.unit_name, "mor")
				ignite(s, u.hex)
				return not u.is_live()
	return false


# --- Portes et structures ---

## `u` est-elle voisine d'un objet qui s'ouvre (porte fermée ; la porte du fort aussi) ?
static func openable_near(s: BattleState, u: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for n in Hex.neighbors(u.hex):
		var o: Dictionary = obj_at(s.cells, n)
		if not o.is_empty() and Data.SCENERY.get(str(o["kind"]), {}).has("open_ap") and not bool(o.get("open", false)) and str(o["kind"]) == "door":
			out.append(n)
	return out


static func can_open(s: BattleState, u: Unit, h: Vector2i) -> bool:
	return u.is_live() and u.morale > 0 and u.ap >= int(Data.SCENERY["door"]["open_ap"]) and Hex.distance(u.hex, h) == 1 \
		and kind_at(s.cells, h) == "door" and not bool(obj_at(s.cells, h).get("open", false))


## Ouvre la porte : coûte 2 PA. Renvoie true si fait.
static func open_door(s: BattleState, u: Unit, h: Vector2i) -> bool:
	if not can_open(s, u, h):
		return false
	obj_at(s.cells, h)["open"] = true
	u.ap -= int(Data.SCENERY["door"]["open_ap"])
	s.undo = {}
	s.new_log_group()
	s.say("%s ouvre la porte." % u.unit_name, "miss")
	return true


static func can_hit_object(s: BattleState, a: Unit, h: Vector2i) -> bool:
	return a.is_live() and a.morale > 0 and Hex.distance(a.hex, h) >= 1 and Hex.distance(a.hex, h) <= maxi(1, a.weapon_range()) \
		and not a.is_ranged() and breakable(s.cells, h) and a.ap >= a.attack_ap() and a.fat + a.attack_fat() <= a.fat_max_eff()


## Frappe un objet destructible (unité-décor : touche 80 %, dégâts de l'arme × efficacité contre l'armure). Renvoie {hit, dmg, destroyed}.
static func hit_object(s: BattleState, a: Unit, h: Vector2i) -> Dictionary:
	var res: Dictionary = {"hit": false, "dmg": 0, "destroyed": false}
	if not can_hit_object(s, a, h):
		return res
	var o: Dictionary = obj_at(s.cells, h)
	var w: Dictionary = a.weapon_data()
	s.undo = {}
	s.new_log_group()
	a.ap -= a.attack_ap()
	a.fat += a.attack_fat()
	a.attacked_turn = true
	var nm: String = str(data_of(o)["n"]).to_lower()
	if s.rng.randi_range(1, 100) > 80:
		s.say("%s manque la %s." % [a.unit_name, nm] if kind_at(s.cells, h) != "door" else "%s manque la porte." % a.unit_name, "miss")
		return res
	var raw: float = float(s.rng.randi_range(int(w["min"]), int(w["max"]))) * float(w["arm"])
	var dmg: int = maxi(1, roundi(raw))
	o["hp"] = int(o["hp"]) - dmg
	res["hit"] = true
	res["dmg"] = dmg
	s.say("%s frappe : %s (−%d)." % [a.unit_name, nm, dmg], "hit")
	if int(o["hp"]) <= 0:
		res["destroyed"] = true
		remove(s.cells, h)
		s.say("%s est détruite." % str(data_of(o)["n"]), "death")
	return res


## Obstacles destructibles qui séparent `u` des ennemis (cases de porte / barricade / porte du fort), du plus proche au plus lointain.
static func breach_targets(s: BattleState, u: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h in s.cells:
		if breakable(s.cells, h):
			out.append(h)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Hex.distance(a, u.hex) < Hex.distance(b, u.hex))
	return out


## Cases à côté d'un obstacle destructible `h` d'où `u` peut le frapper (libres, praticables).
static func approach_cells(s: BattleState, u: Unit, h: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: int = maxi(1, u.weapon_range())
	for k in s.cells:
		if Hex.distance(k, h) <= r and Hex.distance(k, h) >= 1 and not Pathfinding.blocked(s.cells, k) and (s.unit_at(k) == null or s.unit_at(k) == u):
			out.append(k)
	return out
