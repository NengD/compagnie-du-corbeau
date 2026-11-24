class_name AiPlan
extends RefCounted
## Plans d'ensemble de l'IA ennemie (au-delà du choix d'une action) : renforts, commandants, ruses.
## Tout est pur et déterministe : aucun aléa propre (le tirage des ruses utilise un générateur dérivé, sans consommer celui de la bataille).
## État de bataille : `BattleState.extras["ia"]` = {"lurk": [ids], "feint": [ids], "charge": {"e": manche de l'annonce}}.

const HOLD_TYPES: Array[String] = ["siege", "convoy"]  ## types de bataille qui retiennent une seconde vague (l'embuscade a la sienne)
const REINFORCE_ROUND: Dictionary = {"siege": 3, "convoy": 3}
const HOLD_MIN_FOES: int = 6  ## il faut au moins ce nombre d'ennemis pour en retenir
const HOLD_MAX: int = 3
const LEADER_INI: int = 5  ## bonus d'initiative des hommes d'un chef vivant (à 4 cases ou moins)
const CHARGE_RATIO: float = 1.5  ## le camp du chef charge quand sa force vaut au moins ce multiple de celle de l'adversaire
const LURK_RADIUS: int = 4  ## un guetteur sort de l'ombre quand un ennemi s'approche à cette distance
const LURK_UNTIL: int = 4  ## ... ou à cette manche au plus tard
const FEINT_FROM: int = 2
const FEINT_TO: int = 3
const FEINT_CHANCE: float = 0.35


# --- Renforts ---

## Manche d'arrivée de la seconde vague (0 = aucune) pour ce type de bataille.
static func reserve_round(battle_type: String) -> int:
	if battle_type == "ambush":
		return Data.AMBUSH_RESERVE_ROUND
	return int(REINFORCE_ROUND.get(battle_type, 0))


## Siège et convoi : garde quelques ennemis (jamais le chef) en réserve ; ils arriveront d'un flanc à la manche voulue.
## Appelé par `BattleState._layout` avant le déploiement ; `foes` est amputée.
static func hold_back(s: BattleState, foes: Array[Unit]) -> void:
	if not HOLD_TYPES.has(s.battle_type) or foes.size() < HOLD_MIN_FOES:
		return
	var n: int = clampi(foes.size() / 4, 1, HOLD_MAX)
	var i: int = foes.size() - 1
	while n > 0 and i >= 0:
		var f: Unit = foes[i]
		if not f.leader and f.foe_key != "":
			s.reserve.append(f.foe_key)
			foes.remove_at(i)
			n -= 1
		i -= 1


# --- Commandants ---

static func _leader_of(s: BattleState, side: String) -> Unit:
	for x in s.units:
		if x.side == side and x.leader and x.is_fighting() and not x.immobile:
			return x
	return null


## Bonus d'initiative d'un homme dont le chef (vivant, en état de combattre) est à 4 cases ou moins.
static func ini_bonus(s: BattleState, u: Unit) -> int:
	for x in s.units:
		if x != u and x.leader and x.side == u.side and x.is_fighting() and Hex.distance(x.hex, u.hex) <= 4:
			return LEADER_INI
	return 0


static func strength(s: BattleState, side: String) -> float:
	var t: float = 0.0
	for x in s.units:
		if x.side == side and x.is_fighting() and not x.immobile:
			t += float(x.hp) + 0.5 * float(x.arm_h + x.arm_b)
	return t


## Le camp `side` (dirigé par un chef vivant) a-t-il la bataille en main au point de charger ?
static func charging(s: BattleState, side: String) -> bool:
	if _leader_of(s, side) == null:
		return false
	var other: String = "p" if side == "e" else "e"
	var theirs: float = strength(s, other)
	return theirs <= 0.0 or strength(s, side) >= CHARGE_RATIO * theirs


# --- Ruses ---

static func _plan(s: BattleState) -> Dictionary:
	if not s.extras.has("ia"):
		s.extras["ia"] = {"lurk": [], "feint": [], "charge": {}}
	return s.extras["ia"]


## Choisit les ruses de la bataille (tirage dérivé de l'état du générateur, sans le consommer).
## Embuscade : les tireurs ennemis restent cachés/immobiles. Bataille rangée de brigands ou d'orcs : deux hommes feignent le repli.
static func plan_ruses(s: BattleState) -> void:
	var drng := RandomNumberGenerator.new()
	drng.seed = int(s.rng.state) ^ 0x1A2B
	var plan: Dictionary = _plan(s)
	var foes: Array[Unit] = []
	for x in s.units:
		if x.side == "e" and not x.leader and not x.immobile:
			foes.append(x)
	if s.battle_type == "ambush" and foes.size() >= 3:
		for f in foes:
			if f.is_ranged():
				(plan["lurk"] as Array).append(f.id)
	elif s.battle_type == "pitched" and foes.size() >= 5 and int(s.contract.get("d", 1)) >= 2 and drng.randf() < FEINT_CHANCE:
		var kind: String = ""
		for f in foes:
			kind = f.faction
		if kind == "b" or kind == "o":
			var melee: Array[Unit] = foes.filter(func(f: Unit) -> bool: return not f.is_ranged())
			for i in mini(2, melee.size()):
				(plan["feint"] as Array).append(melee[melee.size() - 1 - i].id)


## `u` guette : il tient sa place tant qu'aucun ennemi n'approche, qu'il n'est pas blessé et que la charge n'est pas ordonnée.
static func lurking(s: BattleState, u: Unit) -> bool:
	if u.side != "e" or s.round_no > LURK_UNTIL or not s.extras.has("ia"):
		return false
	if not (s.extras["ia"]["lurk"] as Array).has(u.id) or u.hp < u.hp_max or charging(s, "e"):
		return false
	for f in s.foes_of(u):
		if Hex.distance(f.hex, u.hex) <= LURK_RADIUS:
			return false
	return true


## `u` feint de se replier : pendant les manches FEINT_FROM..FEINT_TO, loin de tout contact, hors charge.
static func feinting(s: BattleState, u: Unit) -> bool:
	if u.side != "e" or s.round_no < FEINT_FROM or s.round_no > FEINT_TO or not s.extras.has("ia"):
		return false
	if not (s.extras["ia"]["feint"] as Array).has(u.id) or u.hp < u.hp_max or charging(s, "e"):
		return false
	for f in s.foes_of(u):
		if Hex.distance(f.hex, u.hex) <= 1:
			return false
	return true


## Au début du tour d'une unité de l'IA : annonce (une fois) la charge groupée du chef.
static func on_turn(s: BattleState, u: Unit) -> void:
	if u.leader or not s.extras.has("ia"):
		return
	var plan: Dictionary = s.extras["ia"]
	var announced: Dictionary = plan["charge"]
	if announced.has(u.side) or not charging(s, u.side):
		return
	var ld: Unit = _leader_of(s, u.side)
	if ld == null:
		return
	announced[u.side] = s.round_no
	s.say("%s sonne la charge !" % ld.unit_name, "sys")


# --- Tactique ---

## Nombre d'ennemis de `u` au contact de la case `h`.
static func foes_adjacent(s: BattleState, u: Unit, h: Vector2i) -> int:
	var n: int = 0
	for f in s.foes_of(u):
		if Hex.distance(f.hex, h) == 1:
			n += 1
	return n


## Bonus/malus de position : éviter l'encerclement, protéger soigneurs et chefs.
static func position_bonus(s: BattleState, u: Unit, h: Vector2i) -> float:
	var sc: float = 0.0
	var around: int = foes_adjacent(s, u, h)
	if around >= 3:
		sc -= 7.0 * float(around - 2)  # entouré : on évite
	var precious: bool = u.leader or int(u.foe_data().get("heal", 0)) > 0
	if precious:
		for f in s.foes_of(u):
			if Hex.distance(f.hex, h) <= 2 and not f.is_ranged():
				sc -= 12.0
	else:
		for a in s.allies_of(u):
			if (a.leader or int(a.foe_data().get("heal", 0)) > 0) and Hex.distance(a.hex, h) <= 2:
				for f in s.foes_of(a):
					if Hex.distance(f.hex, a.hex) <= 4:
						sc += 3.0  # garde du corps : reste près de celui qu'on menace
						break
				break
	return sc


## Bonus de ciblage : cibles sans armure, soigneurs et chefs ; une cible presque imprenable pèse moins.
static func target_bonus(s: BattleState, u: Unit, f: Unit, hit_chance: float) -> float:
	var sc: float = 0.0
	var armor: int = f.arm_h + f.arm_b
	sc += 12.0 if armor == 0 else maxf(0.0, 12.0 - float(armor) / 10.0)
	if int(f.foe_data().get("heal", 0)) > 0 or f.leader:
		sc += 8.0
	if hit_chance <= 20.0:
		sc -= 25.0
	return sc


## `extras` relu d'un JSON : entiers rétablis, clés manquantes comblées.
static func clean_extras(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw.get("ia", null)) == TYPE_DICTIONARY:
		var ia: Dictionary = raw["ia"]
		var charge: Dictionary = {}
		if typeof(ia.get("charge", null)) == TYPE_DICTIONARY:
			for k in ia["charge"]:
				charge[str(k)] = int(ia["charge"][k])
		var lurk: Array = []
		var feint: Array = []
		for v in ia.get("lurk", []):
			lurk.append(int(v))
		for v in ia.get("feint", []):
			feint.append(int(v))
		out["ia"] = {"lurk": lurk, "feint": feint, "charge": charge}
	if bool(raw.get("turn_undo_used", false)):
		out["turn_undo_used"] = true
	return out
