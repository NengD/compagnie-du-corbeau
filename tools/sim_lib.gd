extends RefCounted
## Bibliothèque commune des simulations de régression (tools/sim_battles.gd, tools/sim_campaign.gd,
## tests/suites/suite_regression.gd). Détecte des BUGS (blocages, états invalides), pas l'équilibrage.
## Charger avec : var lib = load("res://tools/sim_lib.gd").new()

const FACTION_SETS: Array = [["b"], ["g"], ["o"], ["u"], ["m"], ["b", "g"], ["o", "u"], ["b", "o"], ["g", "u"], ["m", "b"]]
const MAX_ROUNDS: int = 150
const MAX_TURNS: int = 8000
var difficulty: String = "normal"  ## niveau de difficulté simulé (--difficulty easy|normal|hard)


## Paramètres d'une bataille, entièrement déterminés par la graine (reproductible : --seed N --count 1).
func params_for(seed_value: int) -> Dictionary:
	var biomes: Array = Data.BIOMES
	return {
		"biome": biomes[seed_value % biomes.size()],
		"factions": FACTION_SETS[(seed_value / 4) % FACTION_SETS.size()],
		"danger": (seed_value / 32) % 3 + 1,
		"men": 1 + (seed_value * 7 + seed_value / 5) % 8,
		"btype": Data.BATTLE_TYPES[(seed_value * 3 + seed_value / 7) % Data.BATTLE_TYPES.size()],
	}


func make_party(rng: RandomNumberGenerator, n: int) -> Array:
	var out: Array = []
	var keys: Array = Data.BG.keys()
	var weapons: Array = []
	for k in Data.WPN:
		if int(Data.WPN[k]["price"]) > 0:
			weapons.append(k)
	for i in n:
		var u: Unit = Contracts.make_merc(str(keys[rng.randi() % keys.size()]), rng, [])
		u.weapon = str(weapons[rng.randi() % weapons.size()])
		u.shield = bool(Data.WPN[u.weapon]["h1"]) and rng.randf() < 0.5
		u.head = str(Data.HEAD.keys()[rng.randi() % Data.HEAD.size()])
		u.body = str(Data.BODY.keys()[rng.randi() % Data.BODY.size()])
		u.arm_h = rng.randi_range(0, u.head_armor_max())  # armures abîmées
		u.arm_b = rng.randi_range(0, u.body_armor_max())
		u.level = rng.randi_range(1, 8)
		u.xp = int(Data.XP_THRESHOLDS[u.level])
		var pk: Array = Data.PERKS.keys()
		for j in rng.randi_range(0, 4):
			var p: String = str(pk[rng.randi() % pk.size()])
			if not u.has_perk(p):
				u.perks.append(p)
		var ik: Array = Data.INJURIES.keys()
		for j in rng.randi_range(0, 2):
			var inj: String = str(ik[rng.randi() % ik.size()])
			if not u.has_injury(inj):
				var perm: bool = bool(Data.INJURIES[inj]["perm"])
				u.injuries.append({"id": inj, "days_left": -1 if perm else rng.randi_range(1, 6)})
		u.hp = maxi(1, int(u.hp_max * rng.randf_range(0.3, 1.0)))
		out.append(u)
	return out


func make_contract(factions: Array, danger: int, biome: String, btype: String = "pitched") -> Dictionary:
	var foes: Array = []
	for i in factions.size():
		var list: Array = Contracts.foes_for(str(factions[i]), danger)
		var take: int = list.size() if factions.size() == 1 else (list.size() + 1) / 2
		foes.append_array(list.slice(0, take))
	return {
		"kind": "contract", "type": str(factions[0]), "type_contract": "kill", "d": danger, "foes": foes,
		"title": "Simulation", "desc": "", "employer": "x", "origin": "x", "origin_id": "", "pay": 300 * danger,
		"days": 1, "tx": 0.0, "ty": 0.0, "ox": 0.0, "oy": 0.0, "target_name": "x", "biome": biome, "battle_type": btype, "traps": btype == "ambush",
	}


## Invariants d'un état de bataille. Renvoie la liste des violations (vide = OK).
func check_state(s: BattleState) -> Array[String]:
	var bad: Array[String] = []
	var occ: Dictionary = {}
	for u in s.units:
		var tag: String = "%s#%d" % [u.unit_name, u.id]
		if u.hp > u.hp_max or u.hp < 0:
			bad.append("%s PV hors bornes (%d/%d)" % [tag, u.hp, u.hp_max])
		if u.dead and u.hp != 0:
			bad.append("%s mort avec %d PV" % [tag, u.hp])
		if not u.dead and u.hp <= 0:
			bad.append("%s vivant avec %d PV" % [tag, u.hp])
		if u.arm_h < 0 or u.arm_h > u.head_armor_max():
			bad.append("%s armure de tête hors bornes (%d/%d)" % [tag, u.arm_h, u.head_armor_max()])
		if u.arm_b < 0 or u.arm_b > u.body_armor_max():
			bad.append("%s armure de corps hors bornes (%d/%d)" % [tag, u.arm_b, u.body_armor_max()])
		if u.fat < 0 or u.fat > 1000:
			bad.append("%s fatigue invalide (%d)" % [tag, u.fat])
		if u.ap < 0 or u.ap > 30:
			bad.append("%s PA invalides (%d)" % [tag, u.ap])
		if u.morale < 0 or u.morale > 4:
			bad.append("%s moral invalide (%d)" % [tag, u.morale])
		if u.is_live():
			if not s.cells.has(u.hex):
				bad.append("%s hors du plateau %s" % [tag, str(u.hex)])
			elif Pathfinding.blocked(s.cells, u.hex) and not bool(Scenery.obj_at(s.cells, u.hex).get("top", false)):
				bad.append("%s sur une case bloquée %s (%s)" % [tag, str(u.hex), str(s.cells[u.hex]["t"])])
			if occ.has(u.hex):
				bad.append("%s et %s sur la même case %s" % [tag, occ[u.hex], str(u.hex)])
			occ[u.hex] = tag
	return bad


## Compare deux états de bataille (aller-retour de sérialisation).
func diff_states(a: BattleState, b: BattleState) -> Array[String]:
	var bad: Array[String] = []
	if a.units.size() != b.units.size():
		return ["nombre d'unités %d ≠ %d" % [a.units.size(), b.units.size()]]
	if a.round_no != b.round_no or a.over != b.over or a.biome != b.biome:
		bad.append("manche/état/biome différents")
	if a.cells.size() != b.cells.size() or a.queue.size() != b.queue.size() or a.corpses.size() != b.corpses.size():
		bad.append("cases/file/cadavres différents")
	if (a.current.id if a.current else -1) != (b.current.id if b.current else -1):
		bad.append("unité courante différente")
	for i in a.units.size():
		var x: Unit = a.units[i]
		var y: Unit = b.units[i]
		for k in ["id", "hp", "hp_max", "ap", "fat", "morale", "dead", "escaped", "shield_wall", "hex", "weapon", "shield", "head", "body", "arm_h", "arm_b", "side", "faction", "level", "kills", "turn_round", "leader", "xp_value"]:
			if x.get(k) != y.get(k):
				bad.append("unité %d : %s %s ≠ %s" % [x.id, k, str(x.get(k)), str(y.get(k))])
		if x.perks != y.perks or x.injuries != y.injuries:
			bad.append("unité %d : talents/blessures différents" % x.id)
	return bad


## Joue une bataille IA contre IA. Renvoie {over, rounds, turns, errors:[...]}.
## `roundtrip` : à la manche 2, sérialise (JSON), recharge et continue sur la copie rechargée.
## Renvoie aussi "state" (BattleState final).
func play(s: BattleState, roundtrip: bool, max_rounds: int = MAX_ROUNDS) -> Dictionary:
	var errors: Array[String] = []
	var turns: int = 0
	var did_roundtrip: bool = false
	while s.over == "" and s.round_no <= max_rounds and turns < MAX_TURNS:
		var u: Unit = s.next_turn()
		if u == null:
			break
		if roundtrip and not did_roundtrip and s.round_no >= 2:
			did_roundtrip = true
			var back: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), s.rng)
			errors.append_array(diff_states(s, back))
			s = back
			u = s.current if s.current != null else u
		s.play_ai_turn(u)
		turns += 1
		for e in check_state(s):
			if errors.size() < 12:
				errors.append("manche %d : %s" % [s.round_no, e])
		if errors.size() >= 12:
			break
	if s.over == "" and errors.is_empty():
		errors.append("bataille non terminée (manche %d, %d tours) : blocage probable" % [s.round_no, turns])
	return {"over": s.over, "rounds": s.round_no, "turns": turns, "errors": errors, "state": s}


## Vérifie la cohérence de `Game.finish_battle` pour la bataille terminée `s` jouée par `roster` (Array[Unit]).
## `g` : une instance de Game (autosave faux).
func check_finish(g: Node, s: BattleState, roster: Array) -> Array[String]:
	var bad: Array[String] = []
	g.roster.clear()
	for m in roster:
		g.roster.append(m)
	g.fallen.clear()
	g.inventory.clear()  # réserve pleine = trop-plein vendu d'office, ce qui fausse le compte d'or
	g.active_contract = s.contract.duplicate(true)
	g.battle = s
	g.game_over = false
	var gold0: int = g.gold
	var renown0: int = g.renown
	var xp0: Dictionary = {}
	var ids_before: Array = []
	for m in g.roster:
		xp0[m.id] = m.xp
		ids_before.append(m.id)
	var dead_ids: Array = []
	for u in s.units:
		if u.side == "p" and u.dead and not u.immobile:
			dead_ids.append(u.id)
	var win: bool = s.over == "win"
	var obj: Dictionary = s.objective_bonus() if win else {"gold": 0, "renown": 0}
	g.finish_battle()
	if g.battle != null:
		bad.append("finish_battle n'a pas vidé la bataille")
	if g.roster.size() != ids_before.size() - dead_ids.size():
		bad.append("effectif après combat %d, attendu %d" % [g.roster.size(), ids_before.size() - dead_ids.size()])
	if g.fallen.size() != dead_ids.size():
		bad.append("mémorial %d, morts %d" % [g.fallen.size(), dead_ids.size()])
	var pay: int = int(s.contract["pay"])
	if win and g.gold != gold0 + pay + int(obj["gold"]):
		bad.append("or après victoire %d, attendu %d (prime %d, objectifs %d)" % [g.gold, gold0 + pay + int(obj["gold"]), pay, int(obj["gold"])])
	if not win and g.gold != gold0:
		bad.append("or modifié par une défaite (%d → %d)" % [gold0, g.gold])
	var want_renown: int = renown0 + 40 * int(s.contract["d"]) if win else maxi(0, renown0 - 15)
	if g.renown < want_renown or g.renown > want_renown + 3 * int(obj["renown"]):
		bad.append("renom %d, attendu %d" % [g.renown, want_renown])
	if not g.active_contract.is_empty():
		bad.append("contrat actif non vidé")
	if g.game_over != g.roster.is_empty():
		bad.append("game_over (%s) incohérent avec l'effectif (%d)" % [str(g.game_over), g.roster.size()])
	var seen: Dictionary = {}
	for m in g.roster:
		if dead_ids.has(m.id):
			bad.append("%s est mort mais reste dans la compagnie" % m.unit_name)
		if seen.has(m.id):
			bad.append("id en double %d" % m.id)
		seen[m.id] = true
		if m.hp < 1 or m.hp > m.hp_max:
			bad.append("%s PV %d/%d après combat" % [m.unit_name, m.hp, m.hp_max])
		if m.arm_h < 0 or m.arm_h > m.head_armor_max() or m.arm_b < 0 or m.arm_b > m.body_armor_max():
			bad.append("%s armure hors bornes après combat" % m.unit_name)
		if m.xp < int(xp0.get(m.id, 0)):
			bad.append("%s a perdu de l'XP" % m.unit_name)
		for inj in m.injuries:
			if not Data.INJURIES.has(str(inj["id"])):
				bad.append("%s blessure inconnue %s" % [m.unit_name, str(inj["id"])])
	return bad


## Une bataille complète + finish_battle. Renvoie {ok, errors, over, rounds, factions, men, ...}.
func run_battle(g: Node, seed_value: int) -> Dictionary:
	var p: Dictionary = params_for(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var party: Array = make_party(rng, int(p["men"]))
	var contract: Dictionary = make_contract(p["factions"], int(p["danger"]), str(p["biome"]), str(p["btype"]))
	var s: BattleState = BattleState.create(contract, party, rng, 3, 1.0, difficulty)
	var errors: Array[String] = check_state(s)
	var r: Dictionary = play(s, seed_value % 2 == 0)
	errors.append_array(r["errors"])
	var fin: BattleState = r["state"]
	if fin.over != "":
		errors.append_array(check_finish(g, fin, party))
	return {
		"errors": errors, "over": fin.over, "rounds": fin.round_no, "turns": r["turns"],
		"factions": "+".join(PackedStringArray(p["factions"])), "men": p["men"], "danger": p["danger"], "biome": p["biome"],
	}


## Instance de Game pour les vérifications (aucune écriture disque).
func make_game(seed_value: int = 1) -> Node:
	var g: Node = load("res://autoload/Game.gd").new()
	g.autosave = false
	g.random_events = false
	g.new_game(seed_value, difficulty)
	return g
