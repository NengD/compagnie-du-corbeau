extends RefCounted
## Aventures : batailles défensives (core/defense.gd), bêtes légendaires (core/legendary.gd), explorations de ruines (core/ruins.gd).
var t


func _game(seed_value: int, renown: int = 0) -> Node:
	var g: Node = load("res://autoload/Game.gd").new()
	g.autosave = false
	g.random_events = false
	g.new_game(seed_value)
	g.renown = renown
	return g


func _reload(g: Node) -> Node:
	var g2: Node = load("res://autoload/Game.gd").new()
	g2.autosave = false
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	return g2


## Gagne la bataille en cours : tous les ennemis tombent, puis retour sur la carte.
func _win(g: Node) -> void:
	for u in g.battle.units:
		if u.side == "e":
			u.dead = true
			u.hp = 0
	g.battle.over = "win"
	g.finish_battle()


func _lose(g: Node) -> void:
	g.battle.over = "lose"
	g.finish_battle()


func _state(g: Node, c: Dictionary) -> BattleState:
	return BattleState.create(c, g.roster, g.rng, 3, 1.0, "normal", g.formation_slots())


func _defense_contract(g: Node) -> Dictionary:
	var out: Array = []
	for day in range(1, 300, Data.RESTOCK_DAYS):
		for st in g.world.settlements:
			out.append_array(Defense.gen_contracts(g.world, st, 400, day, 100))
		if out.size() >= 3:
			break
	t.check(out.size() >= 1, "des contrats défensifs sont générés (chance 100 %)")
	return out[0] if not out.is_empty() else {}


func _count(s: BattleState, fac: String) -> int:
	var n: int = 0
	for u in s.units:
		if u.faction == fac and u.is_live():
			n += 1
	return n


# --- Tâche 1 : défense ---

func test_defense_contrat_genere() -> void:
	var g: Node = _game(11, 400)
	var c: Dictionary = _defense_contract(g)
	if c.is_empty():
		return
	t.eq(c["kind"], "contract", "contrat ordinaire")
	t.eq(c["type_contract"], "defense", "type défense")
	t.eq(c["battle_type"], "defense", "type de bataille")
	t.check(str(c["title"]).begins_with("Défendre "), "titre « Défendre X »")
	t.check((c["foes"] as Array).size() >= 3 and int(c["pay"]) > 0 and int(c["d"]) >= 1, "assaillants et prime")
	var cfg: Dictionary = c["def"]
	t.check((cfg["waves"] as Array).size() >= 1 and (cfg["waves"] as Array).size() == (cfg["rounds"] as Array).size(), "vagues de renfort programmées")
	for k in c["foes"]:
		t.check(Data.FOE.has(str(k)), "clé d'ennemi connue : %s" % str(k))
	# la génération n'entame pas l'aléa de la partie
	var before: int = g.rng.state
	Defense.gen_contracts(g.world, g.world.settlements[0], 400, 5, 100)
	t.eq(g.rng.state, before, "aléa de la partie intact")


func test_defense_restock_additif() -> void:
	var g: Node = _game(12, 400)
	var total: int = 0
	var defs: int = 0
	for day in range(1, 400, Data.RESTOCK_DAYS):
		g.day = day
		for st in g.world.settlements:
			g._restock(st)
			for c in st["contracts"]:
				total += 1
				if str(c.get("type_contract", "")) == "defense":
					defs += 1
	t.check(total > 0, "des contrats sont proposés")
	t.check(defs >= 1, "des contrats « Défendre » apparaissent parmi eux (%d sur %d)" % [defs, total])


func test_defense_bataille_mise_en_place() -> void:
	var g: Node = _game(13, 400)
	var c: Dictionary = _defense_contract(g)
	if c.is_empty():
		return
	var s: BattleState = _state(g, c)
	t.eq(s.battle_type, "defense", "bataille défensive")
	t.check(_count(s, "a") >= 3, "des miliciens alliés")
	t.eq(_count(s, "v"), 3, "trois villageois à protéger")
	var cfg: Dictionary = Defense.cfg(s.contract)
	t.check((cfg["placed"] as Array).size() >= 1, "des défenses sont posées par défaut")
	var enemies: int = s.units.filter(func(u: Unit) -> bool: return u.side == "e").size()
	t.eq(enemies, (c["foes"] as Array).size(), "seule la première vague est là")
	t.check(Defense.pending_waves(s) >= 1, "des vagues attendent")
	t.check(Defense.can_prepare(s), "la préparation est ouverte avant le premier tour")
	var objs: Array = s.objectives.map(func(o: Dictionary) -> String: return str(o["kind"]))
	t.check(objs.has("civ") and objs.has("intact"), "objectifs secondaires : villageois, défenses")
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	t.check(lib.check_state(s).is_empty(), "état valide au départ : %s" % str(lib.check_state(s)))
	for u in s.units:
		if u.faction == "v":
			t.check(u.immobile and u.side == "p", "villageois immobile du camp du joueur")
		if u.faction == "a":
			t.check(u.side == "p" and not u.immobile, "milicien du camp du joueur, conduit par l'IA")


func test_defense_plan_et_materiaux() -> void:
	var g: Node = _game(14, 400)
	var c: Dictionary = _defense_contract(g)
	if c.is_empty():
		return
	var s: BattleState = _state(g, c)
	var mat: int = Defense.materials(s)
	var res: Dictionary = Defense.apply_plan(s, {"palissade": 5, "pieux": 5, "piege": 5})
	t.check(int(res["spent"]) <= mat, "jamais plus que les matériaux (%d <= %d)" % [int(res["spent"]), mat])
	var objs: int = 0
	for h in s.cells:
		if Scenery.kind_at(s.cells, h) in ["barricade", "stakes", "trap"]:
			objs += 1
	t.eq(objs, int(res["placed"]), "autant de décors que de pièces posées")
	var res2: Dictionary = Defense.apply_plan(s, {})
	t.eq(int(res2["placed"]), 0, "plan vide : plus rien de posé")
	objs = 0
	for h in s.cells:
		if Scenery.kind_at(s.cells, h) in ["barricade", "stakes", "trap"]:
			objs += 1
	t.eq(objs, 0, "les anciennes défenses sont retirées")
	Defense.apply_plan(s, Defense.default_plan(mat))
	t.check(Defense.plan_cost(Defense.cfg(s.contract)["plan"]) <= mat, "plan par défaut dans le budget")
	var p: Dictionary = Defense.default_plan(3)
	t.check(Defense.plan_cost(p) <= 3, "plan par défaut réduit pour un petit budget")
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	t.check(lib.check_state(s).is_empty(), "état valide après repose")


func test_defense_vagues_et_victoire() -> void:
	var g: Node = _game(15, 400)
	var c: Dictionary = _defense_contract(g)
	if c.is_empty():
		return
	var s: BattleState = _state(g, c)
	var waves: int = Defense.pending_waves(s)
	# vague décimée : la suivante arrive aussitôt
	for u in s.units:
		if u.side == "e":
			u.dead = true
	var live_before: int = s.units.filter(func(u: Unit) -> bool: return u.side == "e" and u.is_live()).size()
	t.eq(live_before, 0, "plus d'ennemi debout")
	t.check(not s.check_end() and s.over == "", "une vague en attente évite la victoire")
	t.eq(Defense.pending_waves(s), waves - 1, "la vague suivante est arrivée")
	t.check(s.units.any(func(u: Unit) -> bool: return u.side == "e" and u.is_live()), "de nouveaux assaillants")
	# toutes les vagues détruites : victoire
	var guard: int = 0
	while s.over == "" and guard < 8:
		guard += 1
		for u in s.units:
			if u.side == "e":
				u.dead = true
		s.check_end()
	t.eq(s.over, "win", "victoire une fois toutes les vagues détruites")


func test_defense_tenir_les_manches() -> void:
	var g: Node = _game(16, 400)
	var c: Dictionary = _defense_contract(g)
	if c.is_empty():
		return
	var s: BattleState = _state(g, c)
	var cfg: Dictionary = Defense.cfg(s.contract)
	cfg["next"] = (cfg["waves"] as Array).size()
	s.round_no = int(cfg["hold"]) + 1
	Defense.on_round(s)
	t.eq(s.over, "win", "tenir assez de manches donne la victoire")


func test_defense_vague_a_la_manche_prevue() -> void:
	var g: Node = _game(17, 400)
	var c: Dictionary = _defense_contract(g)
	if c.is_empty():
		return
	var s: BattleState = _state(g, c)
	var first_round: int = int((Defense.cfg(s.contract)["rounds"] as Array)[0])
	var n0: int = s.units.size()
	s.round_no = first_round - 1
	Defense.on_round(s)
	t.eq(s.units.size(), n0, "pas de vague avant la manche prévue")
	s.round_no = first_round
	Defense.on_round(s)
	t.check(s.units.size() > n0, "la vague arrive à la manche prévue")


func test_defense_sauvegarde_en_bataille() -> void:
	var g: Node = _game(18, 400)
	var c: Dictionary = _defense_contract(g)
	if c.is_empty():
		return
	g.start_battle(c)
	var g2: Node = _reload(g)
	t.check(g2.battle != null and g2.battle.battle_type == "defense", "bataille défensive rechargée")
	var cfg: Dictionary = Defense.cfg(g2.battle.contract)
	t.check((cfg["waves"] as Array).size() >= 1 and int(cfg["mat"]) > 0, "configuration rechargée")
	t.check(not (cfg["placed"] as Array).is_empty(), "défenses rechargées")
	var kinds: int = 0
	for h in g2.battle.cells:
		if Scenery.kind_at(g2.battle.cells, h) != "":
			kinds += 1
	t.check(kinds >= 1, "décor rechargé")
	var civ: int = 0
	for u in g2.battle.units:
		if u.faction == "v":
			civ += 1
	t.eq(civ, 3, "villageois rechargés")


func test_defense_victoire_et_reputation() -> void:
	var g: Node = _game(19, 400)
	var c: Dictionary = _defense_contract(g)
	if c.is_empty():
		return
	var origin: String = str(c["origin_id"])
	g.active_contract = c.duplicate(true)
	var gold0: int = g.gold
	var stand0: int = g.world.standing_of(g.world.settlement_by_id(origin))
	g.start_battle(g.active_contract)
	var cfg: Dictionary = Defense.cfg(g.battle.contract)
	cfg["waves"] = []
	_win(g)
	t.check(g.gold >= gold0 + int(c["pay"]), "la prime est versée")
	t.check(g.world.standing_of(g.world.settlement_by_id(origin)) >= stand0 + 2, "réputation en hausse (villageois saufs)")
	t.check(g.last_battle_report["lines"].any(func(l: Variant) -> bool: return str(l).contains("sauf")), "compte rendu : village sauf")


func test_defense_defaite() -> void:
	var g: Node = _game(20, 400)
	var c: Dictionary = _defense_contract(g)
	if c.is_empty():
		return
	g.active_contract = c.duplicate(true)
	g.start_battle(g.active_contract)
	_lose(g)
	t.check(g.active_contract.is_empty(), "contrat perdu")
	t.check(g.battle == null, "retour sur la carte")


func test_defense_simulations_ia() -> void:
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	for seed_value in 6:
		var g: Node = _game(30 + seed_value, 400)
		var c: Dictionary = _defense_contract(g)
		if c.is_empty():
			return
		var s: BattleState = _state(g, c)
		var r: Dictionary = lib.play(s, seed_value % 2 == 0)
		t.check((r["errors"] as Array).is_empty(), "défense graine %d : %s" % [seed_value, str((r["errors"] as Array).slice(0, 2))])
		t.check(r["over"] == "win" or r["over"] == "lose", "défense graine %d terminée" % seed_value)


func test_defense_sans_configuration() -> void:
	# un contrat « defense » sans clé `def` (simulations) reçoit une configuration par défaut
	var g: Node = _game(21, 0)
	var c: Dictionary = {"kind": "contract", "type": "b", "type_contract": "kill", "d": 2, "foes": ["brigand", "brigand", "archer", "chef"], "title": "Sim", "desc": "", "employer": "x", "origin": "x",
		"origin_id": "", "pay": 100, "days": 1, "tx": 0.0, "ty": 0.0, "ox": 0.0, "oy": 0.0, "target_name": "x", "biome": "plain", "battle_type": "defense"}
	var s: BattleState = _state(g, c)
	t.eq(s.battle_type, "defense", "défense sans configuration")
	t.eq(Defense.pending_waves(s), 0, "une seule vague")
	t.check(not (Defense.cfg(s.contract)["placed"] as Array).is_empty(), "défenses par défaut")


# --- Tâche 2 : légendaires ---

func test_legendaires_donnees() -> void:
	t.eq(LegendaryData.ORDER.size(), 5, "cinq bêtes")
	for k in LegendaryData.ORDER:
		var d: Dictionary = LegendaryData.LEGENDS[k]
		t.check(Data.FOE.has(str(d["foe"])) and str(d["foe"]).begins_with("leg_"), "%s : fiche d'ennemi" % k)
		t.check(Data.UNIQUES.has(str(d["loot"])), "%s : butin unique déclaré" % k)
		t.check(str(d["legend"]).length() > 30 and not (d["phases"] as Array).is_empty(), "%s : légende et phases" % k)
		var last: float = 1.0
		for ph in d["phases"]:
			t.check(float(ph["hp"]) < last, "%s : seuils décroissants" % k)
			last = float(ph["hp"])
			t.check(str(ph["say"]).contains("{n}"), "%s : phrase de phase" % k)
			for sk in ph.get("summon", []):
				t.check(Data.FOE.has(str(sk)), "%s : renfort connu" % k)
		for pk in d["pack"]:
			t.check(Data.FOE.has(str(pk)), "%s : escorte connue" % k)
		t.check(Data.FOE[str(d["foe"])]["leader"], "%s : chef de bande" % k)
	var names: Array = []
	for k in LegendaryData.ORDER:
		names.append(Data.FOE[str(LegendaryData.LEGENDS[k]["foe"])]["n"])
	t.eq(names.size(), (names as Array).duplicate().size(), "noms distincts")


func _legend_battle(g: Node, key: String) -> BattleState:
	var c: Dictionary = Legendary.make_contract(key, "Test", "s0", Vector2.ZERO, Vector2.ZERO, "plain", 1)
	return _state(g, c)


func _legend_unit(s: BattleState) -> Unit:
	for u in s.units:
		if Legendary.is_legend(u):
			return u
	return null


func test_legendaire_phases_ogre() -> void:
	var g: Node = _game(41, 400)
	var s: BattleState = _legend_battle(g, "ogre")
	var o: Unit = _legend_unit(s)
	t.check(o != null and Legendary.key_of(o) == "ogre", "l'ogre légendaire est là")
	t.eq(Legendary.phase_of(s, o), 0, "phase 0 au départ")
	var sk: int = o.melee_skill
	o.hp = int(o.hp_max * 0.45)
	s.round_no = 3
	s.begin_turn(o)
	t.eq(Legendary.phase_of(s, o), 1, "phase 1 sous la moitié des PV")
	t.eq(o.melee_skill, sk + 8, "l'ogre s'enrage : compétence en hausse")
	t.eq(o.ap, Data.AP_PER_TURN + 3, "PA de rage")
	var sk2: int = o.melee_skill
	s.round_no = 4
	s.begin_turn(o)
	t.eq(o.melee_skill, sk2, "une phase ne s'applique qu'une fois")
	o.hp = int(o.hp_max * 0.2)
	s.round_no = 5
	s.begin_turn(o)
	t.eq(Legendary.phase_of(s, o), 2, "phase 2 au quart des PV")
	t.eq(o.ap, Data.AP_PER_TURN + 5, "PA de rage cumulés")
	t.check(Legendary.tag(o) != "", "indicateur « Légendaire »")
	t.check(Legendary.scale_of(o) > 1.0, "figurine plus grande")


func test_legendaire_troll_regeneration_et_feu() -> void:
	var g: Node = _game(42, 400)
	var s: BattleState = _legend_battle(g, "troll")
	var tr: Unit = _legend_unit(s)
	tr.hp = int(tr.hp_max * 0.8)
	var hp0: int = tr.hp
	s.round_no = 2
	Legendary.on_round(s)
	t.eq(tr.hp, hp0 + 10, "le troll se régénère")
	Legendary.note_burn(s, tr)
	var hp1: int = tr.hp
	s.round_no = 3
	Legendary.on_round(s)
	t.eq(tr.hp, hp1, "le feu bloque la régénération")
	s.round_no = 3 + Legendary.BURN_MEMORY + 1
	Legendary.on_round(s)
	t.check(tr.hp > hp1, "elle reprend quand le feu s'éteint")
	tr.hp = int(tr.hp_max * 0.4)
	var before: int = tr.hp
	s.round_no += 1
	Legendary.on_round(s)
	t.eq(Legendary.phase_of(s, tr), 1, "phase de rage du troll")
	t.eq(tr.hp, before + 14, "régénération accrue en phase 2")
	# un vrai feu : brûlure par le décor
	var s2: BattleState = _legend_battle(g, "troll")
	var tr2: Unit = _legend_unit(s2)
	tr2.hp = int(tr2.hp_max * 0.8)
	Scenery.burn(s2, tr2)
	var h2: int = tr2.hp
	s2.round_no = 2
	Legendary.on_round(s2)
	t.eq(tr2.hp, h2, "brûlure du décor : pas de régénération")


func test_legendaire_reine_invoque() -> void:
	var g: Node = _game(43, 400)
	var s: BattleState = _legend_battle(g, "reine")
	var q: Unit = _legend_unit(s)
	t.check(q.foe_data().get("raise", false), "la reine relève les morts")
	var n0: int = s.units.size()
	q.hp = int(q.hp_max * 0.65)
	s.round_no = 2
	s.begin_turn(q)
	t.check(s.units.size() >= n0 + 2, "la reine appelle sa meute")
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	t.check(lib.check_state(s).is_empty(), "état valide après invocation : %s" % str(lib.check_state(s)))
	var arrived: Array = []
	s.reinforced.connect(func(a: Array) -> void: arrived.append_array(a))
	q.hp = int(q.hp_max * 0.3)
	s.round_no = 3
	s.begin_turn(q)
	t.check(not arrived.is_empty(), "signal de renfort émis")


func test_legendaire_alpha_et_geant() -> void:
	var g: Node = _game(44, 400)
	var s: BattleState = _legend_battle(g, "alpha")
	var loups: int = s.units.filter(func(u: Unit) -> bool: return u.foe_key == "loup").size()
	t.eq(loups, 4, "le loup alpha vient avec sa meute")
	var a: Unit = _legend_unit(s)
	t.eq(a.sprite, "wolf", "figurine de loup")
	a.hp = int(a.hp_max * 0.55)
	s.round_no = 2
	s.begin_turn(a)
	t.check(s.units.filter(func(u: Unit) -> bool: return u.foe_key == "loup").size() >= 6, "hurlement : des loups accourent")
	var sg: BattleState = _legend_battle(g, "geant")
	var gi: Unit = _legend_unit(sg)
	t.check(gi.arm_h + gi.arm_b >= 300, "armure énorme (%d)" % (gi.arm_h + gi.arm_b))
	t.check(gi.is_big(), "géant : insensible au filet")


func test_legendaire_sauvegarde_et_phases() -> void:
	var g: Node = _game(45, 400)
	var s: BattleState = _legend_battle(g, "ogre")
	var o: Unit = _legend_unit(s)
	o.hp = int(o.hp_max * 0.4)
	s.round_no = 2
	s.begin_turn(o)
	var back: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), g.rng)
	var o2: Unit = _legend_unit(back)
	t.eq(Legendary.phase_of(back, o2), 1, "phase conservée à travers la sauvegarde")
	t.eq(o2.melee_skill, o.melee_skill, "statistiques de phase conservées")
	back.round_no = 9
	back.begin_turn(o2)
	t.eq(Legendary.phase_of(back, o2), 1, "la phase n'est pas rejouée")


func test_legendaire_butin_unique_une_fois() -> void:
	var g: Node = _game(46, 400)
	var c: Dictionary = Legendary.make_contract("ogre", "Test", "s0", g.world.player_pos, g.world.player_pos + Vector2(200, 0), "plain", 1)
	g.active_contract = c.duplicate(true)
	g.start_battle(g.active_contract)
	_win(g)
	var key: String = "u_brise_os"
	var n1: int = g.inventory.filter(func(it: Dictionary) -> bool: return str(it.get("key", "")) == key).size()
	t.eq(n1, 1, "le butin unique est dans la réserve")
	t.check(Legendary.is_slain(g.extras, "ogre"), "bête notée comme vaincue")
	t.check((Legendary.state(g.extras)["looted"] as Array).has("ogre"), "butin noté comme sorti")
	t.check(g.last_battle_report["lines"].any(func(l: Variant) -> bool: return str(l).contains("légendaire")), "compte rendu : trophée légendaire")
	# la même bête, de nouveau (autre contrat) : plus de butin unique
	g.active_contract = c.duplicate(true)
	g.start_battle(g.active_contract)
	_win(g)
	var n2: int = g.inventory.filter(func(it: Dictionary) -> bool: return str(it.get("key", "")) == key).size()
	t.eq(n2, 1, "le butin unique ne sort qu'une fois par partie")
	t.check(not Legendary.available(g.extras, 9999).has("ogre"), "la bête vaincue n'est plus proposée")
	var g2: Node = _reload(g)
	t.check(Legendary.is_slain(g2.extras, "ogre"), "état conservé à la sauvegarde")


func test_legendaires_objets_uniques_valides() -> void:
	for k in LegendaryData.ORDER:
		var key: String = str(LegendaryData.LEGENDS[k]["loot"])
		var it: Dictionary = Uniques.item_of(key)
		t.check(Loot.is_valid(it), "%s : objet valide" % key)
		var kind: String = str(Data.UNIQUES[key]["kind"])
		if kind == "weapon":
			t.check(Perks.weapon_family(key) != "", "%s : famille d'arme" % key)
		else:
			t.check(Perks.armor_family(kind, key) != "", "%s : famille d'armure" % key)


func test_legendaire_contrat_de_chasse() -> void:
	var g: Node = _game(47, 400)
	var found: Array = []
	for day in range(1, 600, Data.RESTOCK_DAYS):
		for st in g.world.settlements:
			var extras_probe: Dictionary = {}
			var got: Array = Legendary.gen_contract(extras_probe, g.world, st, 400, day)
			found.append_array(got)
		if found.size() >= 2:
			break
	t.check(found.size() >= 1, "des chasses légendaires sont proposées")
	if found.is_empty():
		return
	var c: Dictionary = found[0]
	t.eq(c["type_contract"], "legend", "type de contrat")
	t.check(str(c["title"]).begins_with("Chasser") or str(c["title"]).begins_with("Abattre"), "titre « Chasser la bête de … »")
	t.check(str(c["title"]).contains("{") == false, "titre sans marque de substitution")
	t.check(Data.FOE.has(str((c["foes"] as Array)[0])), "bête en tête de liste")
	t.check(not str(c.get("legend", "")).is_empty() and LegendaryData.LEGENDS.has(str(c["legend"])), "clé de légende")
	var s: BattleState = _state(g, c)
	t.check(_legend_unit(s) != null, "la bataille contient la bête")
	# renom insuffisant : aucune offre
	var none: Array = []
	for day in range(1, 600, Data.RESTOCK_DAYS):
		for st in g.world.settlements:
			none.append_array(Legendary.gen_contract({}, g.world, st, 0, day))
	for c2 in none:
		t.check(int(LegendaryData.LEGENDS[str(c2["legend"])]["min_renown"]) <= 0, "bête trop forte pour un renom nul")


func test_legendaire_lieux_hostiles_et_grottes() -> void:
	var g: Node = _game(48, 400)
	var boss_sites: int = 0
	for s in g.world.sites:
		var b: String = Legendary.site_boss(g.extras, s)
		if b != "":
			boss_sites += 1
			var c: Dictionary = Campaign.assault_contract(s, g.world, g.extras)
			t.check((c["foes"] as Array).has(str(LegendaryData.LEGENDS[b]["foe"])), "la bête garde le lieu")
		else:
			t.eq((Campaign.assault_contract(s, g.world, g.extras)["foes"] as Array).size(), (Campaign.assault_contract(s, g.world)["foes"] as Array).size(), "sans bête : garnison habituelle")
	var caves: int = 0
	for q in g.world.pois:
		if Legendary.poi_beast(g.extras, q) != "":
			caves += 1
			t.eq(q["kind"], "cave", "seule une grotte abrite une bête")
	t.check(boss_sites + caves >= 1, "au moins un repaire ou une grotte abrite une bête (%d + %d)" % [boss_sites, caves])


# --- Tâche 3 : ruines ---

func _ruin_poi(g: Node) -> Dictionary:
	for i in 80:
		var q: Dictionary = {"id": "pr%d" % i, "kind": "ruins", "name": "Ruines de Test %d" % i, "x": g.world.player_pos.x, "y": g.world.player_pos.y, "done": false}
		if Ruins.is_deep(q):
			g.world.pois.append(q)
			return q
	return {}


func test_ruines_exploration_enchainee() -> void:
	var g: Node = _game(51, 100)
	g.location = ""
	var q: Dictionary = _ruin_poi(g)
	t.check(not q.is_empty(), "une ruine explorable existe")
	var ev: Dictionary = g.visit_poi(str(q["id"]))
	t.eq(ev.get("type", ""), "ruins", "arrivée : proposition d'explorer")
	t.check(not bool(q["done"]), "rien d'engagé tant que le joueur n'a pas choisi")
	t.check(g.ruins_enter(str(q["id"])), "on entre dans les ruines")
	t.check(g.battle != null and g.battle.contract["kind"] == "ruins", "premier combat")
	var run: Dictionary = Ruins.run_of(g.extras)
	t.eq(int(run["stage"]), 0, "niveau 0")
	var stages: int = int(run["stages"])
	t.check(stages >= 2 and stages <= 3, "2 à 3 niveaux")
	var day0: int = g.day
	var hurt: Unit = g.roster[0]
	hurt.hp = 20
	var levels: int = 0
	while Ruins.run_of(g.extras).get("phase", "") != "chest" and levels < 5:
		levels += 1
		if g.battle == null:
			t.check(Ruins.pending(g.extras), "décision attendue entre deux niveaux")
			var res: Dictionary = g.ruins_act("advance")
			t.check(bool(res["ok"]) and bool(res["battle"]), "avancer lance le combat suivant")
		var live: Unit = g.member(hurt.id)
		_win(g)
		var after: Unit = g.member(hurt.id)
		if after != null and live != null:
			t.check(after.hp <= after.hp_max, "pas de soin entre deux niveaux")
	t.eq(levels, stages, "autant de combats que de niveaux")
	t.eq(g.day, day0, "aucun jour ne passe entre les niveaux")
	t.eq(str(Ruins.run_of(g.extras)["phase"]), "chest", "le coffre est atteint")
	var gold0: int = g.gold
	var inv0: int = g.inventory.size()
	var res2: Dictionary = g.ruins_act("open")
	t.check(bool(res2["ok"]) and g.gold > gold0, "le coffre donne de l'or")
	t.check(g.inventory.size() > inv0, "et des objets")
	t.check(not Ruins.active(g.extras), "exploration terminée")
	var st: Dictionary = Ruins.state(g.extras)
	t.check((st["done"] as Array).has(str(q["id"])) and int(st["explored"]) == 1 and int(st["clues"]) == 1, "ruine notée comme explorée, indice trouvé")
	t.check(g.story_flags.has("ruin_clue_" + str(q["id"])), "indice d'histoire noté")
	t.check(not Ruins.explorable(g.extras, q), "on ne peut pas refaire la même ruine")


func test_ruines_choix_et_fouille() -> void:
	var g: Node = _game(52, 100)
	var q: Dictionary = _ruin_poi(g)
	g.ruins_enter(str(q["id"]))
	_win(g)
	t.check(Ruins.pending(g.extras), "choix après le premier niveau")
	var ids: Array = Ruins.choices(Ruins.run_of(g.extras)).map(func(c: Dictionary) -> String: return str(c["id"]))
	t.check(ids.has("advance") and ids.has("search") and ids.has("retreat"), "avancer / fouiller / se replier")
	var gold0: int = g.gold
	var res: Dictionary = g.ruins_act("search")
	t.check(bool(res["ok"]) and str(res["text"]) != "", "la fouille donne un résultat")
	t.check(not (Ruins.run_of(g.extras).get("searched", false) == false), "niveau noté comme fouillé")
	if not bool(res["battle"]):
		var ids2: Array = Ruins.choices(Ruins.run_of(g.extras)).map(func(c: Dictionary) -> String: return str(c["id"]))
		t.check(not ids2.has("search"), "une seule fouille par niveau")
	else:
		t.check(g.battle.contract["extra"] == true, "embuscade de fouille")
		_win(g)
		t.check(Ruins.pending(g.extras) and int(Ruins.run_of(g.extras)["stage"]) == 1, "l'embuscade ne fait pas avancer d'un niveau")
	t.check(g.gold >= gold0, "or jamais perdu")
	t.check(not bool(g.ruins_act("n_importe_quoi")["ok"]), "choix inconnu refusé")


func test_ruines_fouille_table() -> void:
	var seen: Dictionary = {}
	for seed_value in 200:
		var r := RandomNumberGenerator.new()
		r.seed = seed_value
		var o: Dictionary = Ruins.search(r, 2)
		seen[str(o["kind"])] = true
		if o["kind"] == "item":
			t.check(Loot.is_valid(o["item"]), "objet trouvé valide")
		if o["kind"] == "trap":
			t.check(int(o["hp_one"]) < 0, "piège : dégâts")
	for k in ["gold", "item", "trap", "ambush", "nothing"]:
		t.check(seen.has(k), "la fouille peut donner : %s" % k)
	var r2 := RandomNumberGenerator.new()
	r2.seed = 5
	var ch: Dictionary = Ruins.chest(r2, 3, [])
	t.check(int(ch["gold"]) > 0 and (ch["items"] as Array).size() >= 4 and str(ch["clue"]) != "", "coffre riche")
	for it in ch["items"]:
		t.check(Loot.is_valid(it), "objet du coffre valide")


func test_ruines_repli() -> void:
	var g: Node = _game(53, 100)
	var q: Dictionary = _ruin_poi(g)
	g.ruins_enter(str(q["id"]))
	_win(g)
	var hp: int = g.roster[0].hp
	var res: Dictionary = g.ruins_act("retreat")
	t.check(bool(res["ok"]), "repli accepté")
	t.check(not Ruins.active(g.extras), "retour sur la carte")
	t.check((Ruins.state(g.extras)["done"] as Array).has(str(q["id"])), "ruine consommée")
	t.eq(g.roster[0].hp, hp, "les blessures restent après le repli")
	t.check(not Ruins.explorable(g.extras, q), "plus explorable")
	t.check(g.battle == null and not Ruins.pending(g.extras), "rien en attente")


func test_ruines_defaite() -> void:
	var g: Node = _game(54, 100)
	var q: Dictionary = _ruin_poi(g)
	g.ruins_enter(str(q["id"]))
	_lose(g)
	t.check(not Ruins.active(g.extras), "la déroute ferme l'exploration")
	t.check(g.battle == null, "retour sur la carte")


func test_ruines_sauvegarde_en_cours() -> void:
	var g: Node = _game(55, 100)
	var q: Dictionary = _ruin_poi(g)
	g.ruins_enter(str(q["id"]))
	var g1: Node = _reload(g)
	t.check(g1.battle != null and Ruins.active(g1.extras), "combat de ruines rechargé")
	_win(g)
	var g2: Node = _reload(g)
	t.check(Ruins.pending(g2.extras) and int(Ruins.run_of(g2.extras)["stage"]) == 1, "décision en attente rechargée")
	t.check(g2.ruins_act("retreat")["ok"], "on peut se replier après rechargement")


func test_ruines_themes_et_contrats() -> void:
	var g: Node = _game(56, 0)
	for k in RuinsData.ORDER:
		var th: Dictionary = RuinsData.THEMES[k]
		t.check(Data.FACTION_NAMES.has(str(th["fac"])) and int(th["stages"]) >= 2 and int(th["stages"]) <= 3, "%s : thème valide" % k)
		t.eq((th["levels"] as Array).size(), int(th["stages"]), "%s : un nom par niveau" % k)
		t.check((th["descend"] as Array).size() >= int(th["stages"]) - 1, "%s : texte de descente" % k)
		for d in range(1, 4):
			for stage in int(th["stages"]):
				var foes: Array = Ruins.foes_for_stage(str(k), d, stage, int(th["stages"]))
				t.check(not foes.is_empty(), "%s d%d niveau %d : des occupants" % [k, d, stage])
				for f in foes:
					t.check(Data.FOE.has(str(f)), "clé connue %s" % str(f))
	var q: Dictionary = {"id": "p0", "kind": "ruins", "name": "X"}
	t.check(RuinsData.THEMES[Ruins.theme_for(q, 0)]["min_renown"] <= 0, "pas de citadelle orque sans renom")
	var run: Dictionary = Ruins.start({}, q, 0)
	var c: Dictionary = Ruins.battle_contract(run, g.world)
	var s: BattleState = _state(g, c)
	t.check(s.units.size() > 4, "bataille de ruines créable")
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	var r: Dictionary = lib.play(s, true)
	t.check((r["errors"] as Array).is_empty(), "ruines : simulation sans erreur %s" % str((r["errors"] as Array).slice(0, 2)))


func test_poi_non_profonds_inchanges() -> void:
	var g: Node = _game(57, 0)
	g.location = ""
	var n_ruins: int = 0
	var n_deep: int = 0
	for q in g.world.pois:
		if str(q["kind"]) == "ruins":
			n_ruins += 1
			if Ruins.is_deep(q):
				n_deep += 1
		else:
			t.check(not Ruins.is_deep(q), "seules les ruines s'explorent en profondeur")
	t.check(n_ruins >= 1, "des ruines sur la carte")
	var other: Dictionary = {"id": "px", "kind": "shrine", "name": "S", "x": g.world.player_pos.x, "y": g.world.player_pos.y, "done": false}
	g.world.pois.append(other)
	var ev: Dictionary = g.visit_poi("px")
	t.eq(ev.get("type", ""), "event", "un sanctuaire garde sa rencontre habituelle")
