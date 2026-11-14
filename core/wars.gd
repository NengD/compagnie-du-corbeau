class_name Wars
extends RefCounted
## Guerres entre factions humaines hostiles (Factions.relation == REL_RIVAL). Logique pure, aléa injecté.
## État persistant : `Game.extras["wars"]` = {"list": [{"a", "b", "start", "len", "score", "flips"}], "next": jour avant lequel
## aucune guerre ne naît}. `score` > 0 : `a` l'emporte ; ±FLIP_AT et un lieu frontalier du perdant change de mains.
## Garde-fous : au plus MAX_WARS guerres, une seule par faction, un perdant garde toujours MIN_KEEP lieux (jamais de faction sans lieu).

const MAX_WARS: int = 2
const FIRST_DAY: int = 6  ## pas de guerre avant ce jour
const BIRTH_ALONE: float = 0.07  ## chance quotidienne de naissance sans guerre en cours
const BIRTH_SECOND: float = 0.025  ## avec une guerre déjà en cours
const LEN_MIN: int = 20
const LEN_MAX: int = 40
const PEACE_MIN: int = 8
const PEACE_MAX: int = 16
const MIN_KEEP: int = 2  ## lieux qu'une faction conserve quoi qu'il arrive
const MIN_TO_FIGHT: int = 3  ## lieux nécessaires pour entrer en guerre
const CLASH_CHANCE: float = 0.4
const FLIP_AT: int = 5
const SCORE_MAX: int = 9
const PAY_MULT: float = 1.1  ## prime des contrats d'une faction en guerre
const PRICE_MULT: float = 1.08  ## prix d'un lieu dont le maître est en guerre contre une faction qui vous estime


static func rng_for_day(day: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = day * 104729 + 7717
	return r


## État normalisé ; stocké dans `extras` seulement si `store` ou si la clé existe déjà.
static func state(extras: Dictionary, store: bool = false) -> Dictionary:
	var raw: Variant = extras.get("wars", {})
	var st: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var list: Array = []
	var rl: Variant = st.get("list", [])
	if typeof(rl) == TYPE_ARRAY:
		for w in rl:
			if typeof(w) != TYPE_DICTIONARY:
				continue
			var a: String = str((w as Dictionary).get("a", ""))
			var b: String = str((w as Dictionary).get("b", ""))
			if not Data.FACTIONS.has(a) or not Data.FACTIONS.has(b) or a == b:
				continue
			list.append({"a": a, "b": b, "start": int((w as Dictionary).get("start", 0)), "len": clampi(int((w as Dictionary).get("len", LEN_MIN)), 5, 80),
				"score": clampi(int((w as Dictionary).get("score", 0)), -SCORE_MAX, SCORE_MAX), "flips": maxi(0, int((w as Dictionary).get("flips", 0)))})
	var out: Dictionary = {"list": list, "next": int(st.get("next", 0))}
	if store or extras.has("wars"):  ## une simple lecture ne crée pas la clé (sauvegarde idempotente)
		extras["wars"] = out
	return out


static func list_of(extras: Dictionary) -> Array:
	return state(extras)["list"]


static func is_at_war(st: Dictionary, a: String, b: String) -> bool:
	for w in st["list"]:
		if (w["a"] == a and w["b"] == b) or (w["a"] == b and w["b"] == a):
			return true
	return false


## Factions contre lesquelles `k` est en guerre.
static func enemies_of(st: Dictionary, k: String) -> Array:
	var out: Array = []
	for w in st["list"]:
		if w["a"] == k:
			out.append(w["b"])
		elif w["b"] == k:
			out.append(w["a"])
	return out


static func in_war(st: Dictionary, k: String) -> bool:
	return not enemies_of(st, k).is_empty()


## Nombre de lieux par faction.
static func counts(world: World) -> Dictionary:
	var out: Dictionary = {}
	for s in world.settlements:
		var o: String = Factions.owner_of(s)
		out[o] = int(out.get(o, 0)) + 1
	return out


## Distance minimale entre un lieu de `a` et un lieu de `b` (1e12 si l'une n'a rien).
static func front_distance(world: World, a: String, b: String) -> float:
	var best: float = 1e12
	for s in world.settlements:
		if Factions.owner_of(s) != a:
			continue
		for t in world.settlements:
			if Factions.owner_of(t) == b:
				best = minf(best, world.settlement_pos(s).distance_to(world.settlement_pos(t)))
	return best


## Paires de factions qui peuvent entrer en guerre : rivales, assez grandes, libres de toute autre guerre.
static func eligible_pairs(st: Dictionary, world: World) -> Array:
	var cnt: Dictionary = counts(world)
	var keys: Array = Factions.playable_keys()
	var out: Array = []
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: String = str(keys[i])
			var b: String = str(keys[j])
			if Factions.relation(a, b) != Factions.REL_RIVAL:
				continue
			if int(cnt.get(a, 0)) < MIN_TO_FIGHT or int(cnt.get(b, 0)) < MIN_TO_FIGHT:
				continue
			if in_war(st, a) or in_war(st, b):
				continue
			out.append([a, b])
	return out


## Fait vivre les guerres pour le jour `day` : naissances, escarmouches, changements de propriétaire, paix.
## `protect` : ids de lieux qui ne changent pas de mains ce jour-là (celui où se trouve la compagnie). Renvoie des lignes de nouvelles.
static func daily(extras: Dictionary, world: World, rng: RandomNumberGenerator, day: int, protect: Array = []) -> Array:
	var lines: Array = []
	if world == null or world.settlements.is_empty():
		return lines
	var st: Dictionary = state(extras, true)
	# 1. Escarmouches et frontières
	var ended: Array = []
	for w in st["list"]:
		var line: String = _advance_war(w, world, rng, day, protect)
		if line != "":
			lines.append(line)
		if day >= int(w["start"]) + int(w["len"]) or _exhausted(w, world):
			ended.append(w)
	# 2. Paix
	for w in ended:
		(st["list"] as Array).erase(w)
		st["next"] = day + rng.randi_range(PEACE_MIN, PEACE_MAX)
		lines.append(_peace_text(w))
	# 3. Naissance
	if day >= FIRST_DAY and day >= int(st["next"]) and (st["list"] as Array).size() < MAX_WARS:
		var chance: float = BIRTH_ALONE if (st["list"] as Array).is_empty() else BIRTH_SECOND
		if rng.randf() < chance:
			var pairs: Array = eligible_pairs(st, world)
			if not pairs.is_empty():
				pairs.sort_custom(func(x: Array, y: Array) -> bool: return front_distance(world, x[0], x[1]) < front_distance(world, y[0], y[1]))
				var pick: Array = pairs[rng.randi() % mini(2, pairs.size())]  ## l'une des deux paires les plus proches
				var w: Dictionary = {"a": pick[0], "b": pick[1], "start": day, "len": rng.randi_range(LEN_MIN, LEN_MAX), "score": 0, "flips": 0}
				(st["list"] as Array).append(w)
				lines.append("Guerre ! %s et %s en viennent aux armes. Leurs marches s'embrasent." % [Factions.name_of(w["a"]), Factions.name_of(w["b"])])
	return lines


## Une guerre est épuisée quand un camp ne peut plus rien perdre et que l'autre mène nettement.
static func _exhausted(w: Dictionary, world: World) -> bool:
	var cnt: Dictionary = counts(world)
	var loser: String = w["b"] if int(w["score"]) > 0 else w["a"]
	return absi(int(w["score"])) >= FLIP_AT and int(cnt.get(loser, 0)) <= MIN_KEEP


static func _peace_text(w: Dictionary) -> String:
	var lead: String = ""
	if int(w["score"]) >= 2:
		lead = " %s a eu le dessus." % Factions.name_of(w["a"])
	elif int(w["score"]) <= -2:
		lead = " %s a eu le dessus." % Factions.name_of(w["b"])
	return "La paix est signée entre %s et %s.%s" % [Factions.name_of(w["a"]), Factions.name_of(w["b"]), lead]


static func _advance_war(w: Dictionary, world: World, rng: RandomNumberGenerator, day: int, protect: Array) -> String:
	if rng.randf() < CLASH_CHANCE:
		var cnt: Dictionary = counts(world)
		var bias: float = 0.0
		var ca: int = int(cnt.get(w["a"], 0))
		var cb: int = int(cnt.get(w["b"], 0))
		if ca != cb:
			bias = 0.3 if ca > cb else -0.3
		var step: int = rng.randi_range(-2, 2)
		if rng.randf() < absf(bias):
			step += 1 if bias > 0.0 else -1
		w["score"] = clampi(int(w["score"]) + step, -SCORE_MAX, SCORE_MAX)
	if absi(int(w["score"])) < FLIP_AT:
		return ""
	var winner: String = w["a"] if int(w["score"]) > 0 else w["b"]
	var loser: String = w["b"] if winner == w["a"] else w["a"]
	var cnt2: Dictionary = counts(world)
	if int(cnt2.get(loser, 0)) <= MIN_KEEP:
		return ""
	var target: Dictionary = frontier_target(world, winner, loser, protect)
	if target.is_empty():
		return ""
	flip(target, winner)
	w["flips"] = int(w["flips"]) + 1
	w["score"] = int(w["score"]) - (FLIP_AT if winner == w["a"] else -FLIP_AT)
	return "%s tombe aux mains de %s, qui l'arrache à %s." % [str(target["name"]), Factions.name_of(winner), Factions.name_of(loser)]


## Le lieu de `loser` le plus proche d'un lieu de `winner` (hors lieux protégés).
static func frontier_target(world: World, winner: String, loser: String, protect: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = 1e12
	for s in world.settlements:
		if Factions.owner_of(s) != loser or protect.has(str(s.get("id", ""))):
			continue
		for t in world.settlements:
			if Factions.owner_of(t) != winner:
				continue
			var d: float = world.settlement_pos(s).distance_to(world.settlement_pos(t))
			if d < best_d:
				best_d = d
				best = s
	return best


## Change le propriétaire du lieu ; ses contrats affichés passent au nouvel employeur.
static func flip(s: Dictionary, new_owner: String) -> void:
	s["owner"] = new_owner
	for c in s.get("contracts", []):
		if c.has("faction"):
			c["faction"] = new_owner
			c.erase("vs_faction")
	s["rare"] = []


# --- Effets sur le joueur ---

## Prime majorée pour un contrat dont l'employeur est en guerre (une seule fois par contrat).
static func apply_pay(st: Dictionary, c: Dictionary) -> void:
	var f: String = str(c.get("faction", ""))
	if f == "" or bool(c.get("war_bonus", false)) or not in_war(st, f):
		return
	c["war_bonus"] = true
	c["pay"] = int(round(float(c.get("pay", 0)) * PAY_MULT / 5.0)) * 5


## Un contrat rempli pour `faction` fait peser la balance de sa guerre en sa faveur. Renvoie une ligne de nouvelles ou "".
static func contract_done(extras: Dictionary, faction: String, danger: int) -> String:
	var st: Dictionary = state(extras)
	for w in st["list"]:
		if w["a"] != faction and w["b"] != faction:
			continue
		var d: int = clampi(danger, 1, 3)
		w["score"] = clampi(int(w["score"]) + (d if w["a"] == faction else -d), -SCORE_MAX, SCORE_MAX)
		var foe: String = w["b"] if w["a"] == faction else w["a"]
		return "Votre service pèse dans la guerre de %s contre %s." % [Factions.name_of(faction), Factions.name_of(foe)]
	return ""


## Majoration de prix dans un lieu de `owner` : en guerre contre une faction qui vous estime (et dont il n'est pas lui-même l'ami), il se méfie.
static func price_mult(st: Dictionary, owner: String, standing: Dictionary) -> float:
	if owner == "" or int(standing.get(owner, 0)) >= Data.FACTION_STAND_GOOD:
		return 1.0
	for e in enemies_of(st, owner):
		if int(standing.get(e, 0)) >= Data.FACTION_STAND_GOOD:
			return PRICE_MULT
	return 1.0


## Les deux factions de chaque guerre, pour la carte : [[a, b], ...].
static func pairs(extras: Dictionary) -> Array:
	var out: Array = []
	for w in state(extras)["list"]:
		out.append([w["a"], w["b"]])
	return out


static func describe(w: Dictionary, day: int) -> String:
	var left: int = maxi(0, int(w["start"]) + int(w["len"]) - day)
	var lead: String = "équilibre"
	if int(w["score"]) >= 2:
		lead = "%s mène" % Factions.name_of(w["a"])
	elif int(w["score"]) <= -2:
		lead = "%s mène" % Factions.name_of(w["b"])
	return "%s contre %s · %s · encore ~%d j" % [Factions.name_of(w["a"]), Factions.name_of(w["b"]), lead, left]
