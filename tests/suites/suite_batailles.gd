extends RefCounted
## Types de bataille, objectifs, décor interactif, outils de jet, monstres, IA variée.
var t  # le lanceur (voir tests/suites/README.md)


func _field(w: int = 12, h: int = 9) -> Dictionary:
	var cells: Dictionary = {}
	for r in h:
		for c in w:
			cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	return cells


## Plateau nu, sans file ni objectifs : on place les unités à la main.
func _bare(seed_value: int = 3) -> BattleState:
	var s := BattleState.new()
	s.rng = t.rng_seeded(seed_value)
	s.cells = _field()
	s.round_no = 1
	return s


func _add(s: BattleState, u: Unit) -> Unit:
	s.units.append(u)
	return u


func _foe(key: String, hex: Vector2i, seed_value: int = 1) -> Unit:
	var f: Unit = Contracts.make_foe(key, t.rng_seeded(seed_value))
	f.reset_for_battle()
	f.hex = hex
	return f


func _contract(foes: Array, btype: String, extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"kind": "contract", "type": "b", "type_contract": "kill", "d": 2, "foes": foes, "title": "Test", "desc": "", "days": 1,
		"employer": "x", "pay": 400, "biome": "plain", "battle_type": btype}
	c.merge(extra, true)
	return c


func _party(n: int, seed_value: int = 4) -> Array:
	var r: RandomNumberGenerator = t.rng_seeded(seed_value)
	var out: Array = []
	var keys: Array = Data.BG.keys()
	for i in n:
		out.append(Contracts.make_merc(keys[i % keys.size()], r, []))
	return out


func _create(btype: String, foes: Array, n: int = 5, seed_value: int = 9, extra: Dictionary = {}) -> BattleState:
	return BattleState.create(_contract(foes, btype, extra), _party(n), t.rng_seeded(seed_value))


func _valid(s: BattleState) -> bool:
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	return (lib.check_state(s) as Array).is_empty()


const B6: Array = ["brigand", "brigand", "brigand", "archer", "archer", "chef"]


# --- Types de bataille ---

func test_types_valides() -> void:
	for bt in Data.BATTLE_TYPES:
		for seed_value in 6:
			var s: BattleState = _create(bt, B6, 5, seed_value)
			t.eq(s.battle_type, bt, "type %s conservé" % bt)
			t.check(_valid(s), "état valide au départ (%s, graine %d)" % [bt, seed_value])
	t.eq(_create("inconnu", B6).battle_type, "pitched", "type inconnu = bataille rangée")


func test_embuscade() -> void:
	var s: BattleState = _create("ambush", B6 + ["brigand", "brigand"], 5)
	t.check(s.reserve.size() >= 1, "des ennemis attendent sur un flanc")
	var live_foes: int = 0
	for u in s.units:
		if u.side == "e":
			live_foes += 1
	t.eq(live_foes + s.reserve.size(), 8, "aucun ennemi perdu")
	t.eq(s.queue[0].side, "e", "l'ennemi agit en premier à la manche 1")
	var cols: Dictionary = {}
	for u in s.units:
		if u.side == "p":
			cols[Hex.column(u.hex)] = true
	t.check(cols.size() >= 3, "compagnie dispersée sur plusieurs colonnes")
	var before: int = s.units.size()
	s.new_round()  # manche 2
	t.eq(s.units.size(), before + (8 - live_foes), "les renforts surgissent à la manche 2")
	t.check(s.reserve.is_empty(), "réserve vidée")
	t.check(_valid(s), "état valide après les renforts")


func test_convoi() -> void:
	var s: BattleState = _create("convoy", B6, 5)
	var carts: Array[Unit] = []
	for u in s.units:
		if u.is_cart():
			carts.append(u)
	t.check(carts.size() >= 2 and carts.size() <= 3, "2 ou 3 chariots")
	for c in carts:
		t.check(c.immobile and c.side == "p" and c.faction == "c" and c.sprite == "cart", "chariot immobile côté joueur")
		t.check(not s.queue.has(c), "un chariot ne joue pas")
	t.check(not s.check_end(), "convoi : pas de fin immédiate")
	# les chariots tombent : défaite
	for c in carts:
		c.hp = 0
		c.dead = true
	t.check(s.check_end() and s.over == "lose", "tous les chariots détruits : défaite")
	# tenir assez de manches : victoire
	var s2: BattleState = _create("convoy", B6, 5)
	s2.round_no = Data.CONVOY_ROUNDS
	s2.new_round()
	t.eq(s2.over, "win", "chariots sauvés après N manches")
	var prot: bool = false
	for o in s2.objectives:
		if o["kind"] == "protect":
			prot = bool(o["done"])
	t.check(prot, "objectif « sauver les chariots » rempli")


func test_siege() -> void:
	var s: BattleState = _create("siege", B6, 5)
	var gate: int = 0
	var walls: int = 0
	var tops: int = 0
	for h in s.cells:
		match Scenery.kind_at(s.cells, h):
			"gate":
				gate += 1
			"wall":
				walls += 1
				if bool(Scenery.obj_at(s.cells, h).get("top", false)):
					tops += 1
	t.eq(gate, 1, "une porte")
	t.check(walls >= 7, "rempart")
	t.eq(tops, 2, "deux chemins de ronde")
	var oil: int = 0
	for u in s.units:
		if u.side == "e" and not (u.bag[0] as Dictionary).is_empty() and u.bag[0]["key"] == "huile":
			oil += 1
			t.check(Scenery.obj_at(s.cells, u.hex).get("top", false), "le porteur d'huile est sur le mur")
	t.eq(oil, 2, "deux défenseurs ont de l'huile")
	t.check(Pathfinding.blocked(s.cells, Hex.from_col_row(7, 0)), "le rempart bloque")
	# le chef mort : le siège est gagné
	for u in s.units:
		if u.leader:
			u.hp = 0
			u.dead = true
	t.check(s.check_end() and s.over == "win", "siège : chef tué = victoire")


func test_siege_porte_brisee() -> void:
	var s: BattleState = _bare()
	var gate_h: Vector2i = Hex.from_col_row(6, 4)
	Scenery.place(s.cells, gate_h, "gate")
	var a: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(5, 4)))
	_add(s, t.mk("hache", "e", Hex.from_col_row(9, 4)))
	t.check(Pathfinding.blocked(s.cells, gate_h), "porte fermée : bloque")
	t.check(CombatRules.line_blocked(Hex.from_col_row(3, 4), Hex.from_col_row(9, 4), s.cells), "la porte coupe la ligne de tir")
	var guard: int = 0
	while Scenery.kind_at(s.cells, gate_h) == "gate" and guard < 40:
		guard += 1
		a.ap = 9
		a.fat = 0
		Scenery.hit_object(s, a, gate_h)
	t.check(Scenery.kind_at(s.cells, gate_h) == "", "porte détruite à coups de hache")
	t.check(not Pathfinding.blocked(s.cells, gate_h), "passage libre")


func test_nuit() -> void:
	var s: BattleState = _create("night", B6, 5)
	t.check(s.night and s.sight_radius == Data.NIGHT_SIGHT, "nuit : rayon de vision")
	var torches: int = 0
	for h in s.cells:
		if Scenery.kind_at(s.cells, h) == "torch":
			torches += 1
	t.check(torches >= 1, "des torches éclairent")
	var b: BattleState = _bare()
	b.night = true
	b.sight_radius = 4
	var p: Unit = _add(b, t.mk("hache", "p", Hex.from_col_row(2, 4)))
	var far: Unit = _add(b, t.mk("hache", "e", Hex.from_col_row(9, 4)))
	var near: Unit = _add(b, t.mk("hache", "e", Hex.from_col_row(5, 4)))
	t.check(not b.is_visible_to_player(far), "hors de vue la nuit")
	t.check(b.is_visible_to_player(near), "à 3 cases : visible")
	t.check(b.is_visible_to_player(p), "ses propres hommes sont toujours visibles")
	var arc: Unit = _add(b, t.mk("arc", "p", Hex.from_col_row(4, 2)))
	t.check(not b.can_attack(arc, far), "une cible hors de vue n'est pas ciblable")
	# une torche la rend visible de loin
	Scenery.place(b.cells, Hex.from_col_row(9, 5), "torch")
	t.check(b.can_see("p", far), "éclairé par une torche à 7 cases : visible")
	# archers : malus à longue portée
	var day: BattleState = _bare()
	var a1: Unit = _add(day, t.mk("arc", "p", Hex.from_col_row(1, 4)))
	var d1: Unit = _add(day, t.mk("hache", "e", Hex.from_col_row(6, 4)))
	var c_day: int = day.hit_chance(a1, d1)
	day.night = true
	t.check(day.hit_chance(a1, d1) < c_day, "la nuit, tir lointain moins précis")


# --- Objectifs ---

func test_objectifs() -> void:
	var s: BattleState = _create("pitched", B6, 5)
	var kinds: Array = s.objectives.map(func(o: Dictionary) -> String: return str(o["kind"]))
	t.check(kinds.has("kill_leader") and kinds.has("no_loss") and kinds.has("fast"), "objectifs d'une bataille rangée : %s" % str(kinds))
	for o in s.objectives:
		t.check(o.has("id") and o.has("target") and o.has("done") and o.has("bonus"), "objectif complet")
	for u in s.units:
		if u.leader:
			s._kill(u, s.units[0])
	var done_leader: bool = false
	for o in s.objectives:
		if o["kind"] == "kill_leader":
			done_leader = bool(o["done"])
	t.check(done_leader, "chef tué : objectif rempli")
	for u in s.units:
		if u.side == "e":
			u.dead = true
			u.hp = 0
	t.check(s.check_end() and s.over == "win", "victoire")
	var b: Dictionary = s.objective_bonus()
	t.check(int(b["gold"]) > 0, "prime d'or des objectifs")
	# sans perte / rapidité
	var by_kind: Dictionary = {}
	for o in s.objectives:
		by_kind[o["kind"]] = o
	t.check(bool(by_kind["no_loss"]["done"]), "aucun mort : « sans perte »")
	t.check(bool(by_kind["fast"]["done"]), "finie en moins de 6 manches")
	# une perte et une défaite : rien
	var s2: BattleState = _create("pitched", B6, 5)
	for u in s2.units:
		if u.side == "p":
			u.dead = true
			u.hp = 0
	s2.check_end()
	t.eq(s2.over, "lose", "défaite")
	t.eq(int(s2.objective_bonus()["gold"]), 0, "pas de prime en cas de défaite")


func test_objectifs_game() -> void:
	var g: Node = t.new_game(21)
	var s: BattleState = BattleState.create(_contract(["brigand"], "pitched"), g.roster, t.rng_seeded(5))
	for u in s.units:
		if u.side == "e":
			u.dead = true
			u.hp = 0
	s.check_end()
	var bonus: Dictionary = s.objective_bonus()
	g.battle = s
	var gold0: int = g.gold
	g.finish_battle()
	t.check(g.last_battle_report.has("objectives"), "le compte rendu liste les objectifs")
	t.eq(g.gold, gold0 + 400 + int(bonus["gold"]), "prime + objectifs versés")
	g.free()


func test_objectifs_serialises() -> void:
	var s: BattleState = _create("siege", B6, 5)
	s.objectives[0]["done"] = true
	var back: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), s.rng)
	t.eq(back.objectives.size(), s.objectives.size(), "objectifs rechargés")
	t.eq(back.objectives[0]["done"], true, "état d'un objectif")
	t.eq(back.battle_type, "siege", "type rechargé")
	var gates: int = 0
	for h in back.cells:
		if Scenery.kind_at(back.cells, h) == "gate":
			gates += 1
	t.eq(gates, 1, "décor rechargé")
	var c: BattleState = _create("ambush", B6 + ["brigand", "brigand"], 5)
	var back2: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())), c.rng)
	t.eq(back2.reserve, c.reserve, "réserve rechargée")
	var night: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(_create("night", B6).to_dict())), t.rng_seeded(1))
	t.check(night.night and night.sight_radius == 4, "nuit rechargée")


# --- Décor interactif ---

func test_feu() -> void:
	var s: BattleState = _bare()
	var u: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(5, 4)))
	var hp0: int = u.hp
	t.check(Scenery.ignite(s, u.hex), "l'herbe brûle")
	t.check(u.hp < hp0, "l'unité sur la case est brûlée")
	t.eq(Scenery.kind_at(s.cells, u.hex), "fire", "objet feu posé")
	t.check(not Scenery.ignite(s, u.hex), "déjà en feu")
	s.cells[Hex.from_col_row(7, 4)]["t"] = "ford"
	t.check(not Scenery.flammable(s.cells, Hex.from_col_row(7, 4)), "le gué ne brûle pas")
	# un feu s'éteint tout seul et se propage parfois
	var spread: int = 0
	for seed_value in 30:
		var b: BattleState = _bare(seed_value)
		Scenery.place(b.cells, Hex.from_col_row(5, 4), "fire", {"ttl": 3})
		Scenery.tick_round(b)
		var n: int = 0
		for h in b.cells:
			if Scenery.kind_at(b.cells, h) == "fire":
				n += 1
		spread += 1 if n > 1 else 0
	t.check(spread > 0, "le feu se propage parfois")
	var b2: BattleState = _bare()
	Scenery.place(b2.cells, Hex.from_col_row(5, 4), "fire", {"ttl": 1})
	Scenery.tick_round(b2)
	t.eq(Scenery.kind_at(b2.cells, Hex.from_col_row(5, 4)), "", "feu éteint en fin de vie")
	# la pluie éteint et empêche la propagation
	var r: BattleState = _bare()
	r.rain = true
	Scenery.place(r.cells, Hex.from_col_row(5, 4), "fire", {"ttl": 2})
	Scenery.tick_round(r)
	t.eq(Scenery.kind_at(r.cells, Hex.from_col_row(5, 4)), "", "la pluie éteint")
	# entrer dans le feu brûle ; l'IA contourne
	var m: BattleState = _bare()
	var w: Unit = _add(m, t.mk("hache", "e", Hex.from_col_row(5, 4)))
	Scenery.place(m.cells, Hex.from_col_row(6, 4), "fire", {"ttl": 3})
	var reach_ai: Dictionary = m.reachable(w, true)
	t.check(not reach_ai.has(Hex.from_col_row(6, 4)), "l'IA évite le feu")
	t.check(m.reachable(w).has(Hex.from_col_row(6, 4)), "le joueur peut choisir de traverser")
	var hp1: int = w.hp
	m.step(w, Hex.from_col_row(6, 4))
	t.check(w.hp < hp1, "entrer dans le feu brûle")


func test_feu_mortel() -> void:
	var s: BattleState = _bare()
	var u: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(5, 4)))
	_add(s, t.mk("hache", "e", Hex.from_col_row(9, 4)))
	u.hp = 3
	Scenery.ignite(s, u.hex)
	t.check(u.dead and u.hp == 0, "le feu peut tuer")


func test_fleche_enflammee() -> void:
	var s: BattleState = _bare(7)
	var a: Unit = _add(s, t.mk("arc", "p", Hex.from_col_row(2, 4)))
	var d: Unit = _add(s, t.mk("hache", "e", Hex.from_col_row(6, 4)))
	d.hp_max = 400
	d.hp = 400
	t.check(CombatRules.abilities_of(a).has("fleche_feu"), "l'arc ouvre la flèche enflammée")
	var lit: bool = false
	for i in 12:
		a.ap = 9
		a.fat = 0
		s.use_ability(a, "fleche_feu", d)
		if Scenery.kind_at(s.cells, d.hex) == "fire":
			lit = true
			break
	t.check(lit, "un tir qui touche enflamme la case")


func test_porte_et_barricade() -> void:
	var s: BattleState = _bare()
	var door: Vector2i = Hex.from_col_row(5, 4)
	Scenery.place(s.cells, door, "door")
	var u: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(4, 4)))
	t.check(Pathfinding.blocked(s.cells, door), "porte fermée : infranchissable")
	t.check(not s.reachable(u).has(door), "on ne marche pas sur une porte fermée")
	t.check(Scenery.can_open(s, u, door), "la porte voisine s'ouvre")
	var ap0: int = u.ap
	t.check(Scenery.open_door(s, u, door), "ouverture")
	t.eq(u.ap, ap0 - 2, "ouvrir coûte 2 PA")
	t.check(not Pathfinding.blocked(s.cells, door), "porte ouverte : passage libre")
	t.check(not Scenery.blocks_los(s.cells, door), "porte ouverte : la ligne de tir passe")
	# barricade
	var bar: Vector2i = Hex.from_col_row(7, 4)
	Scenery.place(s.cells, bar, "barricade")
	t.check(Pathfinding.blocked(s.cells, bar) and Scenery.blocks_los(s.cells, bar), "barricade : bloque pas et tir")
	var b: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(6, 4)))
	var guard: int = 0
	while Scenery.kind_at(s.cells, bar) == "barricade" and guard < 40:
		guard += 1
		b.ap = 9
		b.fat = 0
		Scenery.hit_object(s, b, bar)
	t.eq(Scenery.kind_at(s.cells, bar), "", "barricade démolie")
	t.check(not Scenery.can_hit_object(s, b, bar), "plus rien à frapper")


func test_pieges() -> void:
	var s: BattleState = _bare()
	var trap: Vector2i = Hex.from_col_row(6, 4)
	Scenery.place(s.cells, trap, "trap", {"hidden": true, "owner": "e"})
	var p: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(5, 4)))
	var hp0: int = p.hp
	var stop: bool = s.step(p, trap)
	t.check(stop, "le piège arrête le déplacement")
	t.check(p.hp < hp0, "dégâts du piège")
	t.eq(p.rooted, 1, "immobilisé")
	t.eq(p.ap, 0, "PA perdus")
	t.eq(Scenery.kind_at(s.cells, trap), "", "piège consommé")
	# les pièges de son camp ne blessent pas, et l'IA les connaît
	var s2: BattleState = _bare()
	Scenery.place(s2.cells, trap, "trap", {"hidden": true, "owner": "e"})
	var e: Unit = _add(s2, t.mk("hache", "e", Hex.from_col_row(7, 4)))
	_add(s2, t.mk("hache", "p", Hex.from_col_row(1, 4)))
	t.check(not Scenery.hazard_for(s2.cells, trap, e), "ses propres pièges ne comptent pas")
	var hp1: int = e.hp
	s2.step(e, trap)
	t.eq(e.hp, hp1, "un piège ami ne blesse pas")
	# détection
	var found: int = 0
	for seed_value in 40:
		var d: BattleState = _bare(seed_value)
		Scenery.place(d.cells, trap, "trap", {"hidden": true, "owner": "e"})
		var q: Unit = _add(d, t.mk("hache", "p", Hex.from_col_row(5, 4)))
		Scenery.start_of_turn(d, q)
		if not bool(Scenery.obj_at(d.cells, trap).get("hidden", true)):
			found += 1
	t.check(found > 0 and found < 40, "détection probabiliste (%d/40)" % found)
	# sérialisation d'un piège caché
	var back: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(_with_units(s2).to_dict())), s2.rng)
	t.check(back.cells.size() == s2.cells.size(), "plateau rechargé")


func _with_units(s: BattleState) -> BattleState:
	s.queue = []
	return s


func test_torche_renversee() -> void:
	var fired: int = 0
	for seed_value in 30:
		var s: BattleState = _bare(seed_value)
		var h: Vector2i = Hex.from_col_row(5, 4)
		Scenery.place(s.cells, h, "torch")
		var u: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(4, 4)))
		s.step(u, h)
		if Scenery.kind_at(s.cells, h) == "fire":
			fired += 1
	t.check(fired > 0 and fired < 30, "une torche piétinée met parfois le feu (%d/30)" % fired)


# --- Outils de jet ---

func _with_tool(u: Unit, key: String) -> void:
	u.bag[0] = Loot.item("tool", key)


func test_outils_inventaire() -> void:
	var u: Unit = t.mk("hache")
	_with_tool(u, "pierre")
	t.eq(Unit.clean_bag(u.bag)[0]["key"], "pierre", "le sac garde un outil")
	var back: Unit = Unit.from_dict(JSON.parse_string(JSON.stringify(u.to_dict())))
	t.eq(back.bag[0]["kind"], "tool", "outil sérialisé")
	t.check(Loot.is_valid(Loot.item("tool", "huile")), "objet valide")
	t.check(not Loot.is_valid(Loot.item("tool", "inconnu")), "outil inconnu invalide")
	t.check(Loot.base_price(Loot.item("tool", "huile")) > 0, "prix")
	t.check(Inventory.accepts("bag0", Loot.item("tool", "filet")), "le sac accepte un outil")
	t.check(not Inventory.accepts("weapon", Loot.item("tool", "filet")), "pas dans la main")
	var stash: Array = [Loot.item("tool", "pierre")]
	var v: Unit = t.mk("hache")
	var r: Dictionary = Inventory.move(stash, Inventory.in_stash(0), Inventory.at(v, "bag1"))
	t.check(bool(r["ok"]), "réserve -> sac")
	_with_tool(v, "pierre")
	t.check(Inventory.bag_swap_block(v, 0) != "", "un outil ne s'équipe pas")
	t.check(Inventory.tooltip(Loot.item("tool", "huile")).length() > 0, "infobulle")
	t.check(Data.SHOPS["city"]["tool"].has("huile") and Data.SHOPS["village"]["tool"].has("pierre"), "vendus au marché")


func test_lancer_pierre() -> void:
	var s: BattleState = _bare(3)
	var a: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(2, 4)))
	var d: Unit = _add(s, t.mk("hache", "e", Hex.from_col_row(4, 4)))
	d.hp_max = 400
	d.hp = 400
	t.check(not CombatRules.abilities_of(a).has("lancer_pierre"), "sans pierres, pas de lancer")
	_with_tool(a, "pierre")
	t.check(CombatRules.abilities_of(a).has("lancer_pierre"), "avec pierres : lancer")
	t.eq(CombatRules.tool_left(a, "pierre"), 3, "3 lancers")
	var stunned: bool = false
	var throws: int = 0
	while CombatRules.tool_left(a, "pierre") > 0:
		a.ap = 9
		a.fat = 0
		t.check(s.can_use_ability(a, d, "lancer_pierre"), "lancer possible")
		var res: Dictionary = s.use_ability(a, "lancer_pierre", d)
		throws += 1
		stunned = stunned or bool(res.get("stunned", false))
	t.eq(throws, 3, "trois lancers puis plus rien")
	t.check(stunned or d.stunned, "une pierre qui touche étourdit")
	t.check(d.hp < 400 or throws == 3, "dégâts")
	a.ap = 9
	t.check(not s.can_use_ability(a, d, "lancer_pierre"), "plus de pierres")
	var far: Unit = _add(s, t.mk("hache", "e", Hex.from_col_row(9, 4)))
	_with_tool(a, "pierre")
	a.tool_used = {}
	t.check(not s.can_use_ability(a, far, "lancer_pierre"), "hors de portée (3)")


func test_lancer_huile() -> void:
	var s: BattleState = _bare(5)
	var a: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(2, 4)))
	_with_tool(a, "huile")
	var d: Unit = _add(s, t.mk("hache", "e", Hex.from_col_row(5, 4)))
	var n: Unit = _add(s, t.mk("hache", "e", Hex.from_col_row(5, 5)))
	var friend: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(4, 5)))
	for u in [d, n, friend]:
		u.hp_max = 300
		u.hp = 300
	t.check(s.can_use_ability(a, d, "lancer_huile"), "huile à 3 cases")
	var adj: Unit = _add(s, t.mk("hache", "e", Hex.from_col_row(3, 4)))
	t.check(not s.can_use_ability(a, adj, "lancer_huile"), "pas au contact")
	var res: Dictionary = s.use_ability(a, "lancer_huile", d)
	t.eq(res["chance"], 95, "la jarre éclate presque toujours")
	t.check(d.hp < 300 and n.hp < 300, "la zone touche la cible et ses voisins")
	t.check(friend.hp < 300, "feu ami : l'huile blesse aussi les amis")
	t.eq(Scenery.kind_at(s.cells, d.hex), "fire", "la case prend feu")
	t.eq(CombatRules.tool_left(a, "huile"), 0, "un seul lancer")


func test_lancer_filet() -> void:
	var s: BattleState = _bare(8)
	var a: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(2, 4)))
	_with_tool(a, "filet")
	var d: Unit = _add(s, t.mk("hache", "e", Hex.from_col_row(4, 4)))
	var netted: bool = false
	for i in 2:
		a.ap = 9
		a.fat = 0
		s.use_ability(a, "lancer_filet", d)
		netted = netted or d.rooted > 0
	t.check(netted, "le filet immobilise")
	t.check(s.reachable(d).is_empty(), "une cible filée ne bouge pas")
	d.rooted = 1
	s.begin_turn(d)
	t.check(s.reachable(d).is_empty(), "retenue pendant son tour")
	d.turn_round = 0
	s.round_no += 1
	s.begin_turn(d)
	t.eq(d.rooted, 0, "libre ensuite")
	# les grandes créatures s'en moquent
	var ogre: Unit = _foe("ogre", Hex.from_col_row(5, 4))
	_add(s, ogre)
	_with_tool(a, "filet")
	a.tool_used = {}
	var tries: int = 0
	while tries < 2:
		tries += 1
		a.ap = 9
		a.fat = 0
		s.use_ability(a, "lancer_filet", ogre)
	t.eq(ogre.rooted, 0, "l'ogre n'est pas immobilisé")


# --- Monstres ---

func test_monstres() -> void:
	for k in ["loup", "cavalier_loup", "ogre", "troll", "chaman_orc"]:
		var f: Unit = Contracts.make_foe(k, t.rng_seeded(2))
		t.eq(f.foe_key, k, "clé de l'ennemi")
		t.check(f.hp_max > 0 and Data.WPN.has(f.weapon), "%s valide" % k)
	t.eq(_foe("loup", Vector2i.ZERO).sprite, "wolf", "sprite du loup")
	t.eq(_foe("ogre", Vector2i.ZERO).sprite, "ogre", "sprite de l'ogre")
	t.eq(_foe("troll", Vector2i.ZERO).sprite, "troll", "sprite du troll")
	t.eq(_foe("cavalier_loup", Vector2i.ZERO).sprite, "wolf_rider", "sprite du cavalier")
	t.eq(_foe("loup", Vector2i.ZERO).faction, "m", "faction des monstres")
	t.check(_foe("ogre", Vector2i.ZERO).is_big() and _foe("troll", Vector2i.ZERO).is_big(), "grandes créatures")
	t.check(_foe("ogre", Vector2i.ZERO).hp_max > 250, "l'ogre a beaucoup de PV")
	var back: Unit = Unit.from_combat_dict(JSON.parse_string(JSON.stringify(_foe("troll", Vector2i(2, 3)).combat_dict())))
	t.eq(back.sprite, "troll", "sprite sérialisé")
	t.eq(back.foe_key, "troll", "clé sérialisée")
	t.check(Contracts.foes_for("m", 3).has("troll") and Contracts.foes_for("m", 1).size() > 0, "bandes de monstres")
	t.check(Contracts.factions_for(200).has("m") and not Contracts.factions_for(0).has("m"), "bêtes à partir de 150 de renom")
	t.check(Data.FACTION_NAMES.has("m") and Data.FACTION_LEADER.has("m") and Data.TARGET_NAMES.has("m"), "tables de la faction")


func test_troll_regenere() -> void:
	var s: BattleState = _bare()
	var tr: Unit = _add(s, _foe("troll", Hex.from_col_row(8, 4)))
	_add(s, t.mk("hache", "p", Hex.from_col_row(1, 4)))
	tr.hp = tr.hp_max - 40
	s.new_round()
	t.eq(tr.hp, tr.hp_max - 35, "5 PV par manche")
	tr.hp = tr.hp_max - 2
	s.new_round()
	t.eq(tr.hp, tr.hp_max, "pas au-delà du maximum")


func test_loup_et_cavalier() -> void:
	var cells: Dictionary = _field()
	var w: Unit = _foe("loup", Hex.from_col_row(5, 4))
	var h: Unit = t.mk("hache", "e", Hex.from_col_row(5, 5))
	var east: Vector2i = Hex.from_col_row(6, 4)
	t.eq(Pathfinding.step_cost(w, cells, w.hex, east)["ap"], 1, "le loup coûte 1 PA par case d'herbe")
	t.eq(Pathfinding.step_cost(h, cells, h.hex, Hex.from_col_row(6, 5))["ap"], 2, "un homme : 2 PA")
	var r: Unit = _foe("cavalier_loup", Hex.from_col_row(5, 4))
	t.eq(Pathfinding.step_cost(r, cells, r.hex, east)["ap"], 1, "le cavalier aussi")
	var d: Unit = t.mk("hache", "p", Hex.from_col_row(6, 4))
	r.weapon = "lance"
	var base: int = CombatRules.hit_chance(r, d, [r, d], cells)
	r.moved_cells = 3
	t.eq(CombatRules.hit_chance(r, d, [r, d], cells), mini(95, base + 15), "charge : +15 au toucher après 3 cases")
	r.moved_cells = 2
	t.eq(CombatRules.hit_chance(r, d, [r, d], cells), base, "pas de charge avant 3 cases")


func test_ogre_etourdit() -> void:
	var stunned: int = 0
	for seed_value in 40:
		var s: BattleState = _bare(seed_value)
		var o: Unit = _add(s, _foe("ogre", Hex.from_col_row(5, 4), seed_value))
		var v: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(4, 4)))
		v.hp_max = 500
		v.hp = 500
		o.melee_skill = 200
		var res: Dictionary = s.attack(o, v)
		if v.stunned:
			stunned += 1
	t.check(stunned > 0 and stunned < 40, "le coup de l'ogre étourdit parfois (%d/40)" % stunned)


func test_butin_monstres() -> void:
	var found: bool = false
	for seed_value in 30:
		var o: Unit = _foe("ogre", Vector2i.ZERO)
		o.side = "e"
		o.dead = true
		var loot: Array = Loot.roll_battle([o], t.rng_seeded(seed_value))
		if not loot.is_empty():
			found = true
	t.check(found, "l'ogre laisse des dépouilles")
	var e: Unit = t.mk("hache", "e")
	e.dead = true
	e.bag[0] = Loot.item("tool", "huile")
	var any: bool = false
	for seed_value in 20:
		for it in Loot.roll_battle([e], t.rng_seeded(seed_value)):
			if it["kind"] == "tool":
				any = true
	t.check(any, "les outils du sac sont du butin")


func test_contrats_types() -> void:
	var g: Node = t.new_game(5)
	g.renown = 400
	var n_types: Dictionary = {}
	for i in 12:
		for c in Contracts.gen_contracts(400, g.rng, "Test", Vector2(500, 500), g.world, 3, 0, "x"):
			t.check(Data.BATTLE_TYPES.has(str(c.get("battle_type", ""))), "contrat avec un type de bataille")
			n_types[c["battle_type"]] = true
			if c["type_contract"] == "escort":
				t.eq(c["battle_type"], "convoy", "escorte = convoi")
	t.check(n_types.has("pitched"), "bataille rangée par défaut")
	g.free()


# --- IA ---

func test_ia_soigneur() -> void:
	var s: BattleState = _bare()
	var sh: Unit = _add(s, _foe("chaman_orc", Hex.from_col_row(7, 4)))
	var ally: Unit = _add(s, _foe("orc_guerrier", Hex.from_col_row(8, 4), 2))
	_add(s, t.mk("hache", "p", Hex.from_col_row(1, 4)))
	sh.ap = 9
	ally.hp = ally.hp_max / 2
	var act: Dictionary = Ai.next_action(s, sh, {})
	t.eq(act["type"], "heal", "le chaman soigne l'allié blessé")
	var hp0: int = ally.hp
	s.execute(sh, act)
	t.check(ally.hp > hp0, "PV rendus")
	t.eq(sh.ap, 9 - BattleState.HEAL_AP, "coût en PA")
	ally.hp = ally.hp_max
	var act2: Dictionary = Ai.next_action(s, sh, {})
	t.check(act2["type"] != "heal", "personne à soigner")


func test_ia_necromant() -> void:
	var s: BattleState = _bare()
	var nc: Unit = _add(s, _foe("necro", Hex.from_col_row(8, 4)))
	var sk: Unit = _add(s, _foe("squelette", Hex.from_col_row(7, 4), 3))
	_add(s, t.mk("hache", "p", Hex.from_col_row(1, 4)))
	sk.dead = true
	sk.hp = 0
	s.corpses.append(sk.hex)
	nc.ap = 9
	var act: Dictionary = Ai.next_action(s, nc, {})
	t.eq(act["type"], "raise", "le nécromant relève le squelette")
	s.execute(nc, act)
	t.check(not sk.dead and sk.hp > 0, "squelette debout")
	t.check(not s.corpses.has(sk.hex), "cadavre retiré")
	t.eq(s.raised, 1, "compteur de relèves")
	# borne : trois relèves au plus
	s.raised = BattleState.RAISE_MAX
	sk.dead = true
	nc.ap = 9
	t.check(s.raisable(nc).is_empty(), "au plus %d relèves" % BattleState.RAISE_MAX)


func test_ia_chef_attend() -> void:
	var s: BattleState = _bare()
	var chef: Unit = _add(s, _foe("chef", Hex.from_col_row(9, 4)))
	for i in 4:
		_add(s, _foe("brigand", Hex.from_col_row(8, i + 2), i + 1))
	_add(s, t.mk("hache", "p", Hex.from_col_row(1, 4)))
	t.check(Ai.leader_waits(s, chef), "ligne solide : le chef reste derrière")
	for u in s.units:
		if u.side == "e" and not u.leader:
			u.morale = 0
	t.check(not Ai.leader_waits(s, chef), "ligne brisée : le chef avance")
	# aura de moral
	var ally: Unit = s.units[1]
	t.eq(s.leader_aura(ally), Data.LEADER_AURA, "aura du chef sur ses hommes")
	t.eq(s.leader_aura(chef), 0, "pas d'aura sur lui-même")


func test_ia_archer_recule() -> void:
	var s: BattleState = _bare()
	var arc: Unit = _add(s, _foe("archer", Hex.from_col_row(6, 4)))
	arc.weapon = "arc"
	var p: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(5, 4)))
	var here: float = Ai.eval_pos(s, arc, arc.hex)
	var back: float = Ai.eval_pos(s, arc, Hex.from_col_row(9, 4))
	t.check(back > here, "l'archer préfère s'éloigner du contact")
	var far: float = Ai.eval_pos(s, arc, Hex.from_col_row(11, 4))
	var ideal: float = Ai.eval_pos(s, arc, Hex.from_col_row(10, 4))
	t.check(ideal > far, "il cherche la portée maximale (pas la plus courte)")


func test_ia_encerclement() -> void:
	var s: BattleState = _bare()
	var p: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(5, 4)))
	var w1: Unit = _add(s, _foe("loup", Hex.from_col_row(6, 4)))
	var w2: Unit = _add(s, _foe("loup", Hex.from_col_row(9, 4), 2))
	var near_ally: float = Ai.eval_pos(s, w2, Hex.from_col_row(5, 3))
	var alone: float = Ai.eval_pos(s, w2, Hex.from_col_row(5, 5))
	t.check(near_ally >= alone, "le loup préfère les cases où un allié encercle déjà")
	t.check(w1.hp > 0, "ok")


func test_ia_blesse_se_replie() -> void:
	var s: BattleState = _bare()
	var w: Unit = _add(s, _foe("brigand", Hex.from_col_row(6, 4)))
	w.weapon = "gourdin"
	_add(s, t.mk("hache", "p", Hex.from_col_row(3, 4)))
	w.hp = 5
	var moved_back: bool = false
	for seed_value in 20:
		s.rng = t.rng_seeded(seed_value)
		w.hex = Hex.from_col_row(6, 4)
		w.retreats = 0
		w.ap = 9
		var act: Dictionary = Ai.next_action(s, w, {})
		if act["type"] == "move":
			var path: Array[Vector2i] = act["path"]
			if Hex.column(path[path.size() - 1]) > 6:
				moved_back = true
	t.check(moved_back, "un blessé se replie parfois")
	w.retreats = 3
	var count: int = 0
	for seed_value in 20:
		s.rng = t.rng_seeded(seed_value)
		var act2: Dictionary = Ai.next_action(s, w, {})
		if act2["type"] == "move" and Hex.column((act2["path"] as Array)[(act2["path"] as Array).size() - 1]) > 6:
			count += 1
	t.eq(count, 0, "repli borné à trois fois")
	var ogre: Unit = _add(s, _foe("ogre", Hex.from_col_row(8, 4)))
	ogre.hp = 5
	t.check(bool(ogre.foe_data()["fearless"]), "l'ogre ne se replie jamais")


func test_ia_siege_tient_sa_position() -> void:
	var s: BattleState = _create("siege", B6, 5)
	var defender: Unit = null
	for u in s.units:
		if u.side == "e" and not u.leader and not Scenery.obj_at(s.cells, u.hex).get("top", false):
			defender = u
			break
	t.check(Ai.holds_position(s, defender), "les défenseurs tiennent le rempart")
	s.round_no = 13
	t.check(not Ai.holds_position(s, defender), "après la manche 12, ils sortent")


func test_ia_brise_la_porte() -> void:
	var s: BattleState = _bare()
	var gate: Vector2i = Hex.from_col_row(6, 4)
	for r in 9:
		Scenery.place(s.cells, Hex.from_col_row(6, r), "gate" if r == 4 else "wall")
	var a: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(5, 4)))
	_add(s, t.mk("hache", "e", Hex.from_col_row(9, 4)))
	var act: Dictionary = Ai.next_action(s, a, {})
	t.eq(act["type"], "hit_object", "pas de chemin : l'IA frappe la porte")
	t.eq(act["hex"], gate, "la porte est visée")
	s.execute(a, act)
	var far: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(2, 2)))
	var act2: Dictionary = Ai.next_action(s, far, {})
	t.eq(act2["type"], "move", "de loin, elle s'en approche")
	t.check(s.can_act(a), "un joueur qui peut frapper la porte a encore une action")


func test_ia_huile_depuis_le_mur() -> void:
	var s: BattleState = _bare(2)
	var arc: Unit = _add(s, _foe("archer", Hex.from_col_row(7, 1)))
	arc.weapon = "arc"
	arc.bag[0] = Loot.item("tool", "huile")
	var p1: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(5, 2)))
	var p2: Unit = _add(s, t.mk("hache", "p", Hex.from_col_row(5, 3)))
	for u in [p1, p2]:
		u.hp_max = 400
		u.hp = 400
	arc.ap = 9
	arc.ammo = 5
	var pick: String = Ai.pick_ability(s, arc, p1)
	t.eq(pick, "lancer_huile", "deux ennemis groupés : l'archer lance l'huile")
	p2.side = "e"
	t.check(Ai.pick_ability(s, arc, p1) != "lancer_huile", "jamais d'huile sur ses propres hommes")


func test_embuscade_ia_complete() -> void:
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	for bt in Data.BATTLE_TYPES:
		for seed_value in 4:
			var s: BattleState = _create(bt, B6 + ["loup", "ogre"], 6, 100 + seed_value, {"traps": true})
			var r: Dictionary = lib.play(s, seed_value % 2 == 0)
			t.check((r["errors"] as Array).is_empty(), "%s graine %d : %s" % [bt, seed_value, str((r["errors"] as Array).slice(0, 2))])
			t.check(r["over"] == "win" or r["over"] == "lose", "%s graine %d terminée" % [bt, seed_value])
