class_name Defense
extends RefCounted
## Batailles défensives (`battle_type = "defense"`) : la compagnie défend un lieu. Avant le premier tour, elle dispose de « matériaux »
## pour poser des défenses sur sa moitié du plateau (palissades, pieux, pièges : décor de core/scenery.gd) ; des miliciens du lieu
## (alliés conduits par l'IA, faction « a ») se joignent à elle ; des villageois (immobiles, faction « v ») sont à protéger ;
## les assaillants arrivent en 2 ou 3 vagues. Victoire : détruire tous les assaillants (toutes vagues) ou tenir `hold` manches.
## Logique pure : l'aléa est celui de la bataille (`s.rng`) ou une graine dérivée.
##
## Configuration, dans `contract["def"]` (créée par défaut pour tout contrat « defense », sans vague de renfort) :
##   waves (vagues de renfort : listes de clés de Data.FOE), rounds (manche d'arrivée de chaque vague), next (vagues déjà arrivées),
##   hold (manches à tenir), mat (matériaux), civ (villageois), mil (miliciens), plan ({option: nombre}), placed ([[col,rang]…]), ready (préparation finie).

const OPTIONS: Dictionary = {
	"palissade": {"n": "Palissade", "cost": 3, "kind": "barricade", "d": "Barre le passage (50 points de structure) ; l'ennemi doit la briser."},
	"pieux": {"n": "Pieux", "cost": 1, "kind": "stakes", "d": "Une haie de pieux (30 points) : retarde l'assaut."},
	"piege": {"n": "Piège à loups", "cost": 2, "kind": "trap", "d": "Caché : blesse et retient le premier ennemi qui marche dessus."},
}
const ORDER: Array = ["palissade", "pieux", "piege"]
## Cases candidates (colonne, rangées) devant la compagnie ; les palissades laissent des brèches (rangées impaires libres).
const SPOTS: Dictionary = {
	"palissade": [6, [4, 2, 6, 0, 8]],
	"pieux": [7, [3, 5, 1, 7, 4, 2, 6]],
	"piege": [8, [4, 3, 5, 2, 6, 1, 7]],
}
const BASE_MATERIALS: int = 6
const MATERIALS_PER_DANGER: int = 2
const MAX_PER_OPTION: int = 5
const WAVE_GAP: int = 4  ## manches entre deux vagues


# --- Configuration ---

static func default_config(c: Dictionary) -> Dictionary:
	var d: int = int(c.get("d", 1))
	return {
		"waves": [], "rounds": [], "next": 0, "hold": 8 + 2 * d, "mat": BASE_MATERIALS + MATERIALS_PER_DANGER * d,
		"civ": 3, "mil": 2 + d, "plan": default_plan(BASE_MATERIALS + MATERIALS_PER_DANGER * d), "placed": [], "ready": false,
	}


## Configuration du contrat (créée au besoin). Les nombres relus du JSON sont des flottants : toujours passer par int().
static func cfg(c: Dictionary) -> Dictionary:
	if typeof(c.get("def")) != TYPE_DICTIONARY:
		c["def"] = default_config(c)
	var d: Dictionary = c["def"]
	for k in ["waves", "rounds", "placed"]:
		if typeof(d.get(k)) != TYPE_ARRAY:
			d[k] = []
	if typeof(d.get("plan")) != TYPE_DICTIONARY:
		d["plan"] = default_plan(int(d.get("mat", 8)))
	for k in ["next", "hold", "mat", "civ", "mil"]:
		d[k] = int(d.get(k, default_config(c)[k]))
	d["ready"] = bool(d.get("ready", false))
	return d


static func is_defense(s: BattleState) -> bool:
	return s.battle_type == "defense"


## Plan par défaut : une palissade, deux rangées de pieux, un piège (tient dans le budget minimal).
static func default_plan(budget: int) -> Dictionary:
	var plan: Dictionary = {"palissade": 1, "pieux": 2, "piege": 1}
	while plan_cost(plan) > budget:
		for k in ["pieux", "piege", "palissade"]:
			if int(plan[k]) > 0 and plan_cost(plan) > budget:
				plan[k] = int(plan[k]) - 1
	return plan


static func plan_cost(plan: Dictionary) -> int:
	var n: int = 0
	for k in OPTIONS:
		n += int(plan.get(k, 0)) * int(OPTIONS[k]["cost"])
	return n


# --- Contrat ---

## Contrats « Défendre X » additionnels d'un lieu (liste vide la plupart du temps). Graine stable par lieu et par réassort :
## l'aléa de la partie n'est pas consommé. `renown` règle le danger de base.
static func gen_contracts(world: World, s: Dictionary, renown: int, day: int, chance: int = 25) -> Array:
	var h: int = absi(hash("def|%s|%d" % [str(s["id"]), day / Data.RESTOCK_DAYS]))
	if h % 100 >= chance:
		return []
	var r := RandomNumberGenerator.new()
	r.seed = h
	var origin: Vector2 = world.settlement_pos(s)
	var dests: Array = []
	for o in world.settlements:
		if str(o["id"]) != str(s["id"]) and origin.distance_to(world.settlement_pos(o)) <= world.target_hi and origin.distance_to(world.settlement_pos(o)) >= 100.0 and not world.find_path(origin, world.settlement_pos(o)).is_empty():
			dests.append(o)
	if dests.is_empty():
		return []
	var dest: Dictionary = dests[r.randi() % dests.size()]
	var d: int = clampi(1 + renown / 160 + world.region_danger(world.settlement_pos(dest)), 1, 3)
	return [make_contract(r, d, renown, str(s["name"]), str(s["id"]), origin, dest, world)]


## Contrat défensif vers le lieu `dest` : la vague 1 est dans `foes`, les suivantes dans `def.waves`.
static func make_contract(r: RandomNumberGenerator, d: int, renown: int, town: String, origin_id: String, origin: Vector2, dest: Dictionary, world: World) -> Dictionary:
	var type: String = str(Contracts.pick(Contracts.factions_for(renown), r))
	if type == "o":
		d = maxi(d, 2)
	var first: Array = Contracts.foes_for(type, d)
	var second: Array = first.slice(0, first.size() / 2 + 1)
	var waves: Array = [second]
	var rounds: Array = [1 + WAVE_GAP]
	if d >= 2:
		waves.append(Contracts.foes_for(type, d - 1))
		rounds.append(1 + 2 * WAVE_GAP)
	var target: Vector2 = world.settlement_pos(dest)
	var days: int = maxi(1, int(ceil(origin.distance_to(target) / World.DAY_PX)))
	var dname: String = str(dest["name"])
	var pay: int = int(round((d * 330 + days * 25 + r.randi_range(0, 20) * 5) * 1.25 / 5.0)) * 5
	var c: Dictionary = {
		"kind": "contract", "type": type, "type_contract": "defense", "battle_type": "defense", "d": d, "foes": first,
		"title": "Défendre " + dname, "desc": str(Contracts.pick(DESCS, r)).replace("{dest}", dname),
		"employer": str(Contracts.pick(Data.EMPLOYERS, r)) + " de " + town, "origin": town, "origin_id": origin_id,
		"pay": pay, "days": days, "tx": target.x, "ty": target.y, "ox": origin.x, "oy": origin.y, "target_name": dname,
		"dest_id": str(dest["id"]), "biome": world.biome_at(target),
	}
	var dc: Dictionary = default_config(c)
	dc["waves"] = waves
	dc["rounds"] = rounds
	dc["hold"] = int(rounds[rounds.size() - 1]) + WAVE_GAP
	c["def"] = dc
	return c


const DESCS: Array = [
	"Des assaillants marchent sur {dest}. Les miliciens sont peu nombreux : il faut tenir le village et protéger les paysans.",
	"On annonce un assaut sur {dest} avant la nuit. Dressez des défenses, la milice vous prêtera main-forte.",
	"{dest} appelle à l'aide : une bande approche, par vagues. Les villageois comptent sur votre acier.",
]


# --- Mise en place ---

## Déploiement d'une bataille défensive : compagnie et miliciens à gauche, villageois derrière, assaillants à droite, défenses du plan.
static func layout(s: BattleState, party: Array[Unit], foes: Array[Unit], drng: RandomNumberGenerator) -> void:
	var c: Dictionary = cfg(s.contract)
	s._deploy_party(party, 3, 2)
	s._deploy(foes, s.width - 2, s.width - 1)
	var used: Dictionary = {}
	for u in party + foes:
		used[u.hex] = true
	# villageois : colonne 0, immobiles
	var civ_rows: Array = [3, 5, 4, 2, 6]
	for i in int(c["civ"]):
		var h: Vector2i = Hex.from_col_row(0, int(civ_rows[i % civ_rows.size()]))
		if not s._free_cell(h, used):
			continue
		var v: Unit = make_villager(s.rng, i)
		v.hex = h
		used[h] = true
		s.cells[h]["t"] = "g"
		s.units.append(v)
	# miliciens : colonne 4-5, devant la compagnie
	var mil_rows: Array = [4, 2, 6, 3, 5, 1, 7]
	var placed: int = 0
	for i in mil_rows.size():
		if placed >= int(c["mil"]):
			break
		var h2: Vector2i = Hex.from_col_row(4 + (i % 2), int(mil_rows[i]))
		if not s._free_cell(h2, used):
			continue
		var m: Unit = make_militia(s.rng, placed)
		m.hex = h2
		used[h2] = true
		s.units.append(m)
		placed += 1
	apply_plan(s, c["plan"])


static func make_militia(r: RandomNumberGenerator, n: int) -> Unit:
	var u: Unit = Contracts.make_merc("milicien", r, [])
	u.unit_name = "Milicien %d" % (n + 1)
	u.faction = "a"
	u.wage = 0
	u.backstory = ""
	u.goal = {}
	u.traits.clear()
	return u


static func make_villager(r: RandomNumberGenerator, n: int) -> Unit:
	var u: Unit = Contracts.make_merc("fermier", r, [])
	u.unit_name = "Villageois %d" % (n + 1)
	u.faction = "v"
	u.wage = 0
	u.backstory = ""
	u.goal = {}
	u.traits.clear()
	u.immobile = true
	u.weapon = "poings"
	u.head = "none"
	u.body = "tunique"
	u.shield = false
	u.arm_h = 0
	u.arm_b = u.body_armor_max()
	u.hp_max = 40
	u.hp = 40
	u.resolve = 95
	return u


static func is_ally_ai(u: Unit) -> bool:
	return u.faction == "a"


static func is_civilian(u: Unit) -> bool:
	return u.faction == "v"


# --- Préparation ---

## La préparation est-elle encore ouverte (avant le premier tour) ?
static func can_prepare(s: BattleState) -> bool:
	return is_defense(s) and s.round_no <= 1 and s.current == null and s.over == "" and not bool(cfg(s.contract)["ready"])


static func finish_prepare(s: BattleState) -> void:
	cfg(s.contract)["ready"] = true


static func materials(s: BattleState) -> int:
	return int(cfg(s.contract)["mat"])


## Cases libres candidates pour l'option `opt`, dans l'ordre de préférence (puis le reste des colonnes 5 à 8).
static func spots_for(s: BattleState, opt: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var sp: Array = SPOTS[opt]
	for r in sp[1]:
		out.append(Hex.from_col_row(int(sp[0]), int(r)))
	for c in range(5, 9):
		for r in s.height:
			var h: Vector2i = Hex.from_col_row(c, r)
			if not out.has(h):
				out.append(h)
	return out


static func _free(s: BattleState, h: Vector2i) -> bool:
	return s.cells.has(h) and not Pathfinding.blocked(s.cells, h) and s.unit_at(h) == null and Scenery.obj_at(s.cells, h).is_empty()


## Pose les défenses du plan (en retirant d'abord les précédentes), dans la limite des matériaux. Renvoie {placed, spent, skipped}.
static func apply_plan(s: BattleState, plan: Dictionary) -> Dictionary:
	var c: Dictionary = cfg(s.contract)
	for pr in c["placed"]:
		var h: Vector2i = Vector2i(int(pr[0]), int(pr[1]))
		var k: String = Scenery.kind_at(s.cells, h)
		if k == "barricade" or k == "stakes" or k == "trap":
			Scenery.remove(s.cells, h)
	c["placed"] = []
	var left: int = int(c["mat"])
	var placed: int = 0
	var skipped: int = 0
	var kept: Dictionary = {}
	for opt in ORDER:
		var want: int = clampi(int(plan.get(opt, 0)), 0, MAX_PER_OPTION)
		var cost: int = int(OPTIONS[opt]["cost"])
		var done: int = 0
		for h in spots_for(s, str(opt)):
			if done >= want:
				break
			if cost > left:
				break
			if not _free(s, h):
				continue
			var extra: Dictionary = {}
			if opt == "piege":
				extra = {"owner": "p", "hidden": true}
			Scenery.place(s.cells, h, str(OPTIONS[opt]["kind"]), extra)
			(c["placed"] as Array).append([h.x, h.y])
			left -= cost
			done += 1
			placed += 1
		skipped += want - done
		kept[opt] = done
	c["plan"] = kept
	return {"placed": placed, "spent": int(c["mat"]) - left, "skipped": skipped}


# --- Vagues et fin ---

static func pending_waves(s: BattleState) -> int:
	var c: Dictionary = cfg(s.contract)
	return maxi(0, (c["waves"] as Array).size() - int(c["next"]))


## Fait arriver la prochaine vague par le bord droit. Renvoie le nombre d'assaillants posés.
static func spawn_next(s: BattleState) -> int:
	var c: Dictionary = cfg(s.contract)
	var idx: int = int(c["next"])
	if idx >= (c["waves"] as Array).size():
		return 0
	c["next"] = idx + 1
	var n: int = 0
	var arrivals: Array = []
	var slots: Array[Vector2i] = []
	for col in [s.width - 1, s.width - 2, s.width - 3]:
		for r in BattleState.DEPLOY_ROWS:
			slots.append(Hex.from_col_row(col, r))
	for k in c["waves"][idx]:
		var f: Unit = Contracts.make_foe(str(k), s.rng, s.difficulty)
		f.reset_for_battle()
		var spot: Variant = null
		for h in slots:
			if s.cells.has(h) and not Pathfinding.blocked(s.cells, h) and s.unit_at(h) == null:
				spot = h
				break
		if spot == null:
			continue
		f.hex = spot
		slots.erase(spot)
		s.units.append(f)
		arrivals.append(f)
		n += 1
	if n > 0:
		s.say("Nouvelle vague d'assaillants : %d hommes arrivent !" % n, "sys")
		s.reinforced.emit(arrivals)
	return n


## Début de manche (à partir de la 2e) : vagues programmées, et victoire en tenant `hold` manches.
static func on_round(s: BattleState) -> void:
	var c: Dictionary = cfg(s.contract)
	while int(c["next"]) < (c["waves"] as Array).size() and s.round_no >= int((c["rounds"] as Array)[mini(int(c["next"]), (c["rounds"] as Array).size() - 1)]):
		spawn_next(s)
	if s.over == "" and pending_waves(s) == 0 and s.round_no > int(c["hold"]):
		s.say("Le village a tenu : les assaillants se retirent.", "sys")
		s.end_battle("win")


## Plus d'ennemi debout : une vague en attente arrive aussitôt. Renvoie true si des renforts sont arrivés.
static func reinforce(s: BattleState) -> bool:
	return pending_waves(s) > 0 and spawn_next(s) > 0


# --- Objectifs et suites ---

static func add_objectives(s: BattleState) -> void:
	var d: int = int(s.contract.get("d", 1))
	s._add_obj("civ", 0, "Aucun villageois tué", 50 * d, 10 * d)
	s._add_obj("intact", 0, "Défenses en grande partie intactes", 30 * d, 5 * d)


static func civilians(s: BattleState) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in s.units:
		if is_civilian(u):
			out.append(u)
	return out


## Évalue les objectifs propres à la défense (appelé à la fin de la bataille).
static func evaluate(s: BattleState, result: String) -> void:
	if not is_defense(s) or result != "win":
		return
	var civ_ok: bool = true
	for u in civilians(s):
		if u.dead:
			civ_ok = false
	var c: Dictionary = cfg(s.contract)
	var total: int = (c["placed"] as Array).size()
	var alive: int = 0
	for pr in c["placed"]:
		if not Scenery.obj_at(s.cells, Vector2i(int(pr[0]), int(pr[1]))).is_empty():
			alive += 1
	var intact: bool = total == 0 or alive * 2 >= total
	for o in s.objectives:
		if str(o["kind"]) == "civ":
			o["done"] = civ_ok
		elif str(o["kind"]) == "intact":
			o["done"] = intact


## Répercussions de la bataille : {"standing": variation de réputation du lieu qui a engagé la compagnie, "renown": renom en plus, "lines": [...]}.
static func aftermath(s: BattleState, win: bool) -> Dictionary:
	var civ_dead: int = 0
	var civ_all: int = 0
	for u in civilians(s):
		civ_all += 1
		if u.dead:
			civ_dead += 1
	var out: Dictionary = {"standing": 0, "renown": 0, "lines": []}
	if win:
		if civ_dead == 0:
			out["standing"] = 2
			out["renown"] = 10 * int(s.contract.get("d", 1))
			out["lines"].append("Le village est sauf : on vous acclame (réputation et renom en hausse).")
		else:
			out["standing"] = 0
			out["lines"].append("Le village est sauvé, mais %d villageois sont tombés : la joie est amère." % civ_dead)
	elif civ_all > 0:
		out["standing"] = -2
		out["lines"].append("Le village a été pillé : on vous reprochera longtemps cet échec.")
	return out
