class_name Legendary
extends RefCounted
## Bêtes légendaires (voir core/legendary_data.gd) : contrats de chasse, phases de combat, butin unique garanti.
## Logique pure : l'aléa vient de la bataille (`s.rng`) ou d'une graine dérivée ; l'état de partie vit dans `Game.extras["legendary"]`
## = {slain: [clés vaincues], looted: [clés dont le butin est sorti], posted: {clé: jour de la dernière offre}}.
## En bataille, l'état de phase est dans `contract["leg"]` = {phase: {id d'unité: phases franchies}, burn: {id: manche de la dernière brûlure}}.

const POST_CHANCE: int = 22  ## % par réassort de lieu (tirage dérivé : l'aléa de la partie n'est pas touché)
const REPOST_DAYS: int = 14  ## délai avant qu'une même bête soit de nouveau proposée
const SUMMON_MAX: int = 4  ## renforts appelés d'un coup au plus
const BURN_MEMORY: int = 2  ## manches pendant lesquelles une brûlure bloque la régénération du troll


# --- État de partie ---

static func state(extras: Dictionary) -> Dictionary:
	var st: Variant = extras.get("legendary")
	if typeof(st) != TYPE_DICTIONARY:
		st = {}
	var d: Dictionary = st
	for k in ["slain", "looted"]:
		if typeof(d.get(k)) != TYPE_ARRAY:
			d[k] = []
	if typeof(d.get("posted")) != TYPE_DICTIONARY:
		d["posted"] = {}
	extras["legendary"] = d
	return d


## Lecture seule de l'état (ne crée rien dans `extras` : une partie sans bête garde des extras vides).
static func _list(extras: Dictionary, k: String) -> Array:
	var st: Variant = extras.get("legendary")
	if typeof(st) == TYPE_DICTIONARY and typeof((st as Dictionary).get(k)) == TYPE_ARRAY:
		return (st as Dictionary)[k]
	return []


static func is_slain(extras: Dictionary, key: String) -> bool:
	return _list(extras, "slain").has(key)


## Bêtes encore en vie dont le renom `renown` permet de croiser la route.
static func available(extras: Dictionary, renown: int) -> Array:
	var out: Array = []
	for k in LegendaryData.ORDER:
		if not is_slain(extras, str(k)) and renown >= int(LegendaryData.LEGENDS[k]["min_renown"]):
			out.append(k)
	return out


# --- Reconnaissance d'une unité ---

static func is_legend(u: Unit) -> bool:
	return u.foe_key.begins_with("leg_")


## Clé de LegendaryData d'une unité légendaire ("" sinon).
static func key_of(u: Unit) -> String:
	for k in LegendaryData.LEGENDS:
		if str(LegendaryData.LEGENDS[k]["foe"]) == u.foe_key:
			return str(k)
	return ""


static func def_of(u: Unit) -> Dictionary:
	return LegendaryData.LEGENDS.get(key_of(u), {})


## Taille de la figurine (1 = normale).
static func scale_of(u: Unit) -> float:
	return float(def_of(u).get("scale", 1.0))


static func tag(u: Unit) -> String:
	return str(def_of(u).get("short", "Légendaire")) if is_legend(u) else ""


# --- Contrats ---

## Contrat « Chasser la bête de … » pour la bête `key`. `target` : lieu du repaire (monde).
static func make_contract(key: String, town: String, origin_id: String, origin: Vector2, target: Vector2, biome: String, days: int) -> Dictionary:
	var d: Dictionary = LegendaryData.LEGENDS[key]
	var foes: Array = [str(d["foe"])]
	foes.append_array(d["pack"])
	return {
		"kind": "contract", "type": str(Data.FOE[str(d["foe"])]["fac"]), "type_contract": "legend", "legend": key, "d": int(d["danger"]), "foes": foes,
		"title": str(d["hunt_title"]).replace("{town}", town), "desc": str(d["hunt_desc"]).replace("{town}", town),
		"employer": str(Data.EMPLOYERS[(hash(key + town)) % Data.EMPLOYERS.size()]) + " de " + town, "origin": town, "origin_id": origin_id,
		"pay": int(d["pay"]), "days": days, "tx": target.x, "ty": target.y, "ox": origin.x, "oy": origin.y,
		"target_name": "Antre de " + str(d["title"]).split(",")[0], "biome": biome if Data.BIOMES.has(biome) else str(d["biome"]),
		"battle_type": "pitched",
	}


## Un contrat de chasse légendaire éventuel pour le lieu `s` (liste vide la plupart du temps). Graine stable par lieu et par réassort.
static func gen_contract(extras: Dictionary, world: World, s: Dictionary, renown: int, day: int) -> Array:
	var h: int = absi(hash("leg|%s|%d" % [str(s["id"]), day / Data.RESTOCK_DAYS]))
	if h % 100 >= POST_CHANCE:
		return []
	var posted: Variant = (extras.get("legendary", {}) as Dictionary).get("posted", {}) if typeof(extras.get("legendary", {})) == TYPE_DICTIONARY else {}
	var cands: Array = []
	for k in available(extras, renown):
		if day - int((posted as Dictionary).get(str(k), -999) if typeof(posted) == TYPE_DICTIONARY else -999) >= REPOST_DAYS:
			cands.append(k)
	if cands.is_empty():
		return []
	var key: String = str(cands[(h / 100) % cands.size()])
	var origin: Vector2 = world.settlement_pos(s)
	var r := RandomNumberGenerator.new()
	r.seed = h
	var target: Vector2 = Vector2.ZERO
	for i in 40:
		var p: Vector2 = origin + Vector2.from_angle(r.randf() * TAU) * r.randf_range(world.target_lo, world.target_hi)
		if world.passable(p) and not world.find_path(origin, p).is_empty():
			target = p
			break
	if target == Vector2.ZERO:
		return []
	(state(extras)["posted"] as Dictionary)[key] = day
	var days: int = maxi(1, int(ceil(origin.distance_to(target) / World.DAY_PX)))
	return [make_contract(key, str(s["name"]), str(s["id"]), origin, target, world.biome_at(target), days)]


## Une bête qui garde le lieu hostile `site` (tirage stable par lieu) : clé, ou "" si aucune ou déjà vaincue.
static func site_boss(extras: Dictionary, site: Dictionary) -> String:
	var h: int = absi(hash("legsite|" + str(site.get("id", ""))))
	if h % 100 >= 35:
		return ""
	var fits: Array = []
	for k in LegendaryData.ORDER:
		if not is_slain(extras, str(k)) and (LegendaryData.LEGENDS[k]["lairs"] as Array).has(str(site.get("kind", ""))):
			fits.append(k)
	return "" if fits.is_empty() else str(fits[(h / 100) % fits.size()])


## Une bête qui gîte au point d'intérêt `q` (grotte) : clé, ou "".
static func poi_beast(extras: Dictionary, q: Dictionary) -> String:
	if str(q.get("kind", "")) != "cave":
		return ""
	var h: int = absi(hash("legpoi|" + str(q.get("id", ""))))
	if h % 100 >= 40:
		return ""
	var fits: Array = available(extras, 99999)  ## les grottes abritent toutes les bêtes : le renom ne compte que pour les contrats
	return "" if fits.is_empty() else str(fits[(h / 100) % fits.size()])


## Contrat de bataille contre la bête de la grotte / du repaire.
static func lair_contract(key: String, title: String, biome: String) -> Dictionary:
	var c: Dictionary = make_contract(key, "", "", Vector2.ZERO, Vector2.ZERO, biome, 0)
	c["kind"] = "ambush"
	c["battle_type"] = "pitched"
	c["title"] = title
	c["desc"] = ""
	c["employer"] = ""
	c["origin"] = ""
	c["pay"] = 0
	c["party_id"] = -1
	return c


# --- Phases en bataille ---

static func _bstate(s: BattleState) -> Dictionary:
	var lg: Variant = s.contract.get("leg")
	if typeof(lg) != TYPE_DICTIONARY:
		lg = {}
	var d: Dictionary = lg
	for k in ["phase", "burn"]:
		if typeof(d.get(k)) != TYPE_DICTIONARY:
			d[k] = {}
	s.contract["leg"] = d
	return d


## Phases déjà franchies par `u`.
static func phase_of(s: BattleState, u: Unit) -> int:
	return int((_bstate(s)["phase"] as Dictionary).get(str(u.id), 0))


## Franchit les phases dont le seuil de PV est atteint (une unité à la fois, dans l'ordre).
static func check_phases(s: BattleState, u: Unit) -> void:
	if not is_legend(u) or not u.is_live():
		return
	var d: Dictionary = def_of(u)
	var phases: Array = d.get("phases", [])
	var reached: int = phase_of(s, u)
	while reached < phases.size() and float(u.hp) <= float(phases[reached]["hp"]) * float(u.hp_max):
		var ph: Dictionary = phases[reached]
		reached += 1
		(_bstate(s)["phase"] as Dictionary)[str(u.id)] = reached
		s.say(str(ph["say"]).replace("{n}", u.unit_name), "mor")
		var st: Dictionary = ph.get("stat", {})
		for k in st:
			u.set(str(k), int(u.get(str(k))) + int(st[k]))
		if ph.has("summon"):
			summon(s, u, ph["summon"])


## Points d'action en plus de la bête, selon les phases franchies.
static func ap_bonus(s: BattleState, u: Unit) -> int:
	var phases: Array = def_of(u).get("phases", [])
	var n: int = 0
	for i in mini(phase_of(s, u), phases.size()):
		n += int(phases[i].get("ap", 0))
	return n


## Appelé au début du tour de `u` (après ses PA de base) : phases et PA de rage.
static func on_turn(s: BattleState, u: Unit) -> void:
	if not is_legend(u):
		return
	check_phases(s, u)
	u.ap = mini(30, u.ap + ap_bonus(s, u))


## Appelé à chaque nouvelle manche : phases (si un coup les a franchies hors de son tour) et régénération.
static func on_round(s: BattleState) -> void:
	for u in s.units:
		if not is_legend(u) or not u.is_live():
			continue
		check_phases(s, u)
		var d: Dictionary = def_of(u)
		var rg: int = int(d.get("regen", 0))
		var phases: Array = d.get("phases", [])
		for i in mini(phase_of(s, u), phases.size()):
			if phases[i].has("regen"):
				rg = int(phases[i]["regen"])
		if rg <= 0 or u.hp >= u.hp_max:
			continue
		var burned: int = int((_bstate(s)["burn"] as Dictionary).get(str(u.id), -99))
		if bool(d.get("regen_off_if_burned", false)) and (s.round_no - burned <= BURN_MEMORY or Statuses.has(u, "burn")):
			s.say("%s : ses plaies fument, le feu l'empêche de guérir." % u.unit_name, "miss")
			continue
		u.hp = mini(u.hp_max, u.hp + rg)
		s.say("%s se régénère." % u.unit_name, "miss")


## Une brûlure vient de toucher `u` : la régénération du troll s'arrête quelques manches.
static func note_burn(s: BattleState, u: Unit) -> void:
	if is_legend(u):
		(_bstate(s)["burn"] as Dictionary)[str(u.id)] = s.round_no


## Appelle des renforts autour de `u` (cases libres les plus proches). Renvoie le nombre arrivé.
static func summon(s: BattleState, u: Unit, keys: Array) -> int:
	var n: int = 0
	var arrivals: Array = []
	var ring: Array[Vector2i] = []
	for r in range(1, 4):
		for c in s.cells:
			if Hex.distance(c, u.hex) == r:
				ring.append(c)
	for k in keys:
		if n >= SUMMON_MAX:
			break
		var spot: Variant = null
		for h in ring:
			if s.cells.has(h) and not Pathfinding.blocked(s.cells, h) and s.unit_at(h) == null:
				spot = h
				break
		if spot == null:
			break
		var f: Unit = Contracts.make_foe(str(k), s.rng, s.difficulty)
		f.reset_for_battle()
		f.hex = spot
		s.units.append(f)
		ring.erase(spot)
		arrivals.append(f)
		n += 1
		s.say("%s surgit près de %s !" % [f.unit_name, u.unit_name], "sys")
	if not arrivals.is_empty():
		s.reinforced.emit(arrivals)
	return n


# --- Butin ---

## Butin unique de la bataille `b` (déjà gagnée) : l'objet de chaque bête légendaire tuée, une seule fois par partie. Note l'état.
static func loot_for(b: BattleState, extras: Dictionary) -> Array:
	var out: Array = []
	for u in b.units:
		if not is_legend(u) or not u.dead:
			continue
		var key: String = key_of(u)
		if key == "":
			continue
		var st: Dictionary = state(extras)  ## (créé seulement quand une bête est tombée)
		if not (st["slain"] as Array).has(key):
			(st["slain"] as Array).append(key)
		if not (st["looted"] as Array).has(key):
			(st["looted"] as Array).append(key)
			out.append(Uniques.item_of(str(LegendaryData.LEGENDS[key]["loot"])))
	return out


## Lignes de compte rendu pour les légendes tuées dans `b`.
static func report_lines(b: BattleState) -> Array:
	var out: Array = []
	for u in b.units:
		if is_legend(u) and u.dead:
			out.append("%s est abattu : un trophée légendaire." % u.unit_name)
	return out
