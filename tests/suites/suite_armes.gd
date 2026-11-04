extends RefCounted
## Nouvelles armes, capacités actives, usure de l'équipement.
var t  # le lanceur (voir tests/suites/README.md)

const NEW_WEAPONS: Array[String] = ["arbalete", "hallebarde", "fleau", "javelot"]
const WPN_FIELDS: Array[String] = ["n", "min", "max", "arm", "ign", "ap", "fat", "hit", "rng", "h1", "ranged", "price", "note"]


func _state(a: Unit, d: Unit, seed_value: int = 5) -> BattleState:
	var s := BattleState.new()
	s.rng = t.rng_seeded(seed_value)
	for r in 9:
		for c in 12:
			s.cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	s.units.append(a)
	s.units.append(d)
	return s


func _duel(wa: String, wd: String = "gourdin", dist: int = 1) -> Array:
	var a: Unit = t.mk(wa, "p", Hex.from_col_row(4, 4))
	var d: Unit = t.mk(wd, "e", Hex.from_col_row(4 + dist, 4))
	a.reset_for_battle()
	d.reset_for_battle()
	return [a, d, _state(a, d)]


# --- Données ---

func test_donnees_armes() -> void:
	for k in NEW_WEAPONS:
		t.check(Data.WPN.has(k), "arme %s présente" % k)
		for f in WPN_FIELDS:
			t.check(Data.WPN[k].has(f), "%s a le champ %s" % [k, f])
		t.check(ItemIcons.get_icon("weapon", k) != null, "icône de %s" % k)
		for layer in ["weapon_", "arm_", "hand_"]:
			t.check(ResourceLoader.exists("res://assets/sprites/%s%s.svg" % [layer, k]), "calque %s%s" % [layer, k])
		var sold: bool = (Data.SHOPS["city"]["weapon"] as Array).has(k)
		t.check(sold, "%s vendue en ville" % k)
	var roll: bool = false
	for foe in Data.FOE.values():
		for w in foe["w"]:
			roll = roll or NEW_WEAPONS.has(w)
	t.check(roll, "au moins un ennemi peut porter une nouvelle arme")
	for id in Data.ABILITIES:
		var ab: Dictionary = Data.ABILITIES[id]
		for w in ab["weapons"]:
			t.check(Data.WPN.has(w), "capacité %s : arme %s existe" % [id, w])


func test_arbalete_recharge() -> void:
	var duel: Array = _duel("arbalete", "gourdin", 6)
	var a: Unit = duel[0]
	var d: Unit = duel[1]
	t.check(a.weapon_range() == 6 and a.is_ranged(), "arbalète : portée 6, à distance")
	t.check(Data.WPN["arbalete"]["ap"] > Data.WPN["arc"]["ap"], "recharge : plus de PA qu'un arc")
	t.check(Data.WPN["arbalete"]["min"] > Data.WPN["arc"]["min"], "dégâts plus élevés qu'un arc")
	a.ap = int(Data.WPN["arbalete"]["ap"]) - 1
	t.check(not CombatRules.can_attack(a, d), "pas assez de PA pour recharger et tirer")
	a.ap = 9
	t.check(CombatRules.can_attack(a, d), "9 PA suffisent")


func test_javelots_munitions() -> void:
	var duel: Array = _duel("javelot", "gourdin", 4)
	var a: Unit = duel[0]
	var d: Unit = duel[1]
	var s: BattleState = duel[2]
	t.eq(a.ammo, 3, "3 javelots au départ")
	for i in 3:
		a.ap = 9
		a.fat = 0
		t.check(s.can_attack(a, d), "lancer %d possible à portée 4" % (i + 1))
		s.attack(a, d)
		d.hp = 60
	t.eq(a.ammo, 0, "plus de javelots")
	a.ap = 9
	t.check(not s.can_attack(a, d), "plus de lancer à distance")
	d.hex = Hex.from_col_row(5, 4)
	t.check(s.can_attack(a, d), "au contact, on frappe encore")
	var b: Unit = Unit.from_combat_dict(a.combat_dict())
	t.eq(b.ammo, 0, "munitions sauvegardées")
	var fresh: Unit = Unit.from_combat_dict({"weapon": "javelot", "id": 99})
	t.eq(fresh.ammo, 3, "ancienne sauvegarde : munitions pleines")


func test_boucliers_hallebarde_fleau() -> void:
	var base: Dictionary = {}
	for w in ["hache", "hallebarde", "fleau"]:
		var duel: Array = _duel(w, "gourdin", 1 if w != "hallebarde" else 2)
		var a: Unit = duel[0]
		var d: Unit = duel[1]
		var plain: int = CombatRules.hit_chance(a, d, duel[2].units, duel[2].cells)
		d.shield = true
		var with_shield: int = CombatRules.hit_chance(a, d, duel[2].units, duel[2].cells)
		base[w] = with_shield - plain
	t.eq(base["hache"], -15, "bouclier : −15 contre une hache")
	t.eq(base["hallebarde"], -5, "hallebarde : bonus contre les boucliers")
	t.eq(base["fleau"], -5, "fléau : ignore une partie du bonus de bouclier")
	# Fléau : mauvais contre l'armure lourde
	var r: RandomNumberGenerator = t.rng_seeded(3)
	var heavy: Unit = t.mk("gourdin", "e")
	heavy.arm_b = 190
	heavy.arm_h = 190
	var att_f: Unit = t.mk("fleau", "p")
	var att_h: Unit = t.mk("hache", "p")
	var armor_f: int = 0
	var armor_h: int = 0
	for i in 200:
		armor_f += int(CombatRules.roll_damage(att_f, heavy, r)["armor"])
		armor_h += int(CombatRules.roll_damage(att_h, heavy, r)["armor"])
	t.check(armor_f < armor_h, "fléau : dégâts d'armure plus faibles qu'une hache")


# --- Capacités ---

func test_capacites_par_arme() -> void:
	var u: Unit = t.mk("epee", "p")
	t.eq(CombatRules.abilities_of(u), ["fente"] as Array[String], "épée : fente")
	u.shield = true
	t.check(CombatRules.abilities_of(u).has("coup_bouclier"), "bouclier : coup de bouclier")
	u.shield_dur = 0
	t.check(not CombatRules.abilities_of(u).has("coup_bouclier"), "bouclier brisé : plus de coup de bouclier")
	t.check(CombatRules.abilities_of(t.mk("arc")).has("tir_ajuste"), "arc : tir ajusté")
	t.check(CombatRules.abilities_of(t.mk("hache")).has("fendre"), "hache : fendre l'armure")
	t.check(CombatRules.abilities_of(t.mk("griffes")).is_empty(), "griffes : aucune capacité")
	var bow: Unit = t.mk("arc")
	t.eq(CombatRules.ability_ap(bow, "tir_ajuste"), int(Data.WPN["arc"]["ap"]) + 2, "tir ajusté : +2 PA")


func test_fente_et_tir_ajuste_toucher() -> void:
	var duel: Array = _duel("epee")
	var a: Unit = duel[0]
	var d: Unit = duel[1]
	var s: BattleState = duel[2]
	t.eq(s.hit_chance(a, d, "fente"), s.hit_chance(a, d) + 15, "fente : +15 au toucher")
	var res: Dictionary = s.use_ability(a, "fente", d)
	t.eq(res["ability"], "fente", "résultat : capacité")
	t.eq(a.ap, 9 - 5, "fente : 4 PA + 1")
	var duel2: Array = _duel("arc", "gourdin", 4)
	t.eq(duel2[2].hit_chance(duel2[0], duel2[1], "tir_ajuste"), duel2[2].hit_chance(duel2[0], duel2[1]) + 15, "tir ajusté +15")


func test_fendre_l_armure() -> void:
	var a: Unit = t.mk("hache", "p")
	var d: Unit = t.mk("gourdin", "e")
	d.arm_b = 200
	d.arm_h = 200
	var ab: Dictionary = Data.ABILITIES["fendre"]
	var base_sum: int = 0
	var cleave: int = 0
	var r1: RandomNumberGenerator = t.rng_seeded(8)
	var r2: RandomNumberGenerator = t.rng_seeded(8)
	for i in 100:
		base_sum += int(CombatRules.roll_damage(a, d, r1)["armor"])
		cleave += int(CombatRules.roll_damage(a, d, r2, ab)["armor"])
	t.check(cleave > base_sum * 1.4 and cleave < base_sum * 1.6, "dégâts d'armure ×1,5 (%d → %d)" % [base_sum, cleave])
	var duel: Array = _duel("hache")
	t.eq(duel[2].hit_chance(duel[0], duel[1], "fendre"), duel[2].hit_chance(duel[0], duel[1]) - 10, "fendre : −10 au toucher")


func test_assommer_moral() -> void:
	var dropped: int = 0
	for i in 40:
		var duel: Array = _duel("masse")
		var a: Unit = duel[0]
		var d: Unit = duel[1]
		var s: BattleState = duel[2]
		s.rng = t.rng_seeded(100 + i)
		d.resolve = 5
		d.hp_max = 400
		d.hp = 400
		a.melee_skill = 500
		var res: Dictionary = s.use_ability(a, "assommer", d)
		if res["hit"] and d.morale < 3:
			dropped += 1
	t.check(dropped > 25, "assommer : cible sans détermination perd presque toujours un cran (%d/40)" % dropped)


func test_recul() -> void:
	var duel: Array = _duel("lance")
	var a: Unit = duel[0]
	var d: Unit = duel[1]
	var s: BattleState = duel[2]
	a.melee_skill = 500
	d.hp_max = 400
	d.hp = 400
	var before: int = Hex.distance(a.hex, d.hex)
	var res: Dictionary = s.use_ability(a, "recul", d)
	t.check(res["hit"], "touché")
	t.check(res.has("pushed"), "événement de repoussé")
	t.eq(Hex.distance(a.hex, d.hex), before + 1, "la cible recule d'une case")
	# Bloquée : pas de recul
	var duel2: Array = _duel("lance")
	var a2: Unit = duel2[0]
	var d2: Unit = duel2[1]
	var s2: BattleState = duel2[2]
	a2.melee_skill = 500
	d2.hp_max = 400
	d2.hp = 400
	for n in Hex.neighbors(d2.hex):
		if Hex.distance(a2.hex, n) == 2 and s2.cells.has(n):
			s2.cells[n]["t"] = "rock"
	var here: Vector2i = d2.hex
	var res2: Dictionary = s2.use_ability(a2, "recul", d2)
	t.check(not res2.has("pushed") and d2.hex == here, "recul impossible derrière un obstacle")


func test_coup_de_bouclier_etourdit() -> void:
	var duel: Array = _duel("epee")
	var a: Unit = duel[0]
	var d: Unit = duel[1]
	var s: BattleState = duel[2]
	a.shield = true
	a.melee_skill = 500
	d.hp_max = 400
	d.hp = 400
	t.check(s.can_use_ability(a, d, "coup_bouclier"), "coup de bouclier possible")
	var hp0: int = d.hp
	var res: Dictionary = s.use_ability(a, "coup_bouclier", d)
	t.check(res["hit"] and d.stunned, "cible étourdie")
	t.eq(d.hp, hp0, "aucun dégât")
	t.eq(a.ap, 9 - 4, "4 PA")
	s.round_no = 1
	s.begin_turn(d)
	t.eq(d.ap, 9 - Data.STUN_AP, "étourdi : PA réduits au tour suivant")
	t.check(not d.stunned, "étourdissement consommé")


func test_croc_desarconne() -> void:
	var duel: Array = _duel("hallebarde", "gourdin", 2)
	var a: Unit = duel[0]
	var d: Unit = duel[1]
	var s: BattleState = duel[2]
	a.melee_skill = 500
	d.hp_max = 400
	d.hp = 400
	var def0: int = d.eff("melee_def")
	t.check(s.can_use_ability(a, d, "croc"), "croc à 2 cases")
	var res: Dictionary = s.use_ability(a, "croc", d)
	t.check(res["hit"] and d.exposed, "désarçonné")
	t.eq(d.eff("melee_def"), def0 - Data.EXPOSE_DEF, "−10 en défense")
	s.round_no = 1
	s.begin_turn(d)
	t.eq(d.eff("melee_def"), def0, "effet dissipé au tour suivant")


func test_briser_bouclier() -> void:
	var duel: Array = _duel("fleau")
	var a: Unit = duel[0]
	var d: Unit = duel[1]
	var s: BattleState = duel[2]
	a.melee_skill = 500
	d.hp_max = 400
	d.hp = 400
	t.check(not s.can_use_ability(a, d, "briser_bouclier"), "il faut un bouclier en face")
	d.shield = true
	t.check(s.can_use_ability(a, d, "briser_bouclier"), "bouclier en face : possible")
	var res: Dictionary = s.use_ability(a, "briser_bouclier", d)
	t.check(res["hit"], "touché")
	t.check(d.shield_dur_now() <= d.shield_dur_max() - 30, "bouclier très abîmé")


func test_ia_utilise_une_capacite() -> void:
	var used: int = 0
	var plain: int = 0
	for i in 60:
		var duel: Array = _duel("epee")
		var a: Unit = duel[0]
		var d: Unit = duel[1]
		var s: BattleState = duel[2]
		s.rng = t.rng_seeded(500 + i)
		a.melee_skill = 40
		var act: Dictionary = Ai.next_action(s, a, {})
		if act["type"] == "ability":
			used += 1
			t.eq(act["id"], "fente", "l'IA choisit une capacité de son arme")
			s.execute(a, act)
			t.eq(a.ap, 4, "capacité exécutée")
		else:
			t.eq(act["type"], "attack", "sinon attaque simple")
			plain += 1
	t.check(used > 5 and plain > 20, "l'IA tente parfois une capacité (%d capacités, %d attaques)" % [used, plain])
	# Une bataille complète avec capacités se termine sans erreur.
	var rng: RandomNumberGenerator = t.rng_seeded(77)
	var roster: Array = []
	for k in ["milicien", "deserteur", "reitre", "bucheron"]:
		roster.append(Contracts.make_merc(k, rng, []))
	var s2: BattleState = BattleState.create({"type": "b", "d": 2, "foes": ["balafre", "brigand", "archer", "brigand"], "title": "T", "desc": "", "days": 1, "employer": "x", "pay": 1, "biome": "plain"}, roster, rng)
	var guard: int = 0
	while s2.over == "" and guard < 400:
		var u: Unit = s2.next_turn()
		if u == null:
			break
		s2.play_ai_turn(u)
		guard += 1
	t.check(s2.over != "", "bataille complète terminée")


# --- Usure ---

func test_usure_bouclier() -> void:
	var duel: Array = _duel("epee")
	var a: Unit = duel[0]
	var d: Unit = duel[1]
	var s: BattleState = duel[2]
	d.shield = true
	d.hp_max = 5000
	d.hp = 5000
	t.eq(d.shield_dur_now(), Data.SHIELD["dur"], "bouclier neuf")
	var chance_with: int = s.hit_chance(a, d)
	var g: int = 0
	while d.shield_dur_now() > 0 and g < 200:
		a.ap = 9
		a.fat = 0
		s.attack(a, d)
		g += 1
	t.eq(d.shield_dur_now(), 0, "le bouclier finit par se briser")
	t.check(not d.shield_ok(), "bouclier brisé inutilisable")
	t.check(s.hit_chance(a, d) > chance_with, "plus de bonus de bouclier")
	var wall: Unit = t.mk("epee", "e")
	wall.shield = true
	wall.shield_wall = true
	var norm: Unit = t.mk("epee", "e")
	norm.shield = true
	var s2: BattleState = _state(a, wall)
	s2._wear_on_block(a, wall, true)
	s2._wear_on_block(a, norm, true)
	t.eq(wall.shield_dur_max() - wall.shield_dur_now(), 2, "mur de boucliers : usure doublée")
	t.eq(norm.shield_dur_max() - norm.shield_dur_now(), 1, "coup normal : 1 point")


func test_usure_arme() -> void:
	var a: Unit = t.mk("hache", "p")
	var d: Unit = t.mk("gourdin", "e")
	d.arm_b = 200
	d.arm_h = 200
	d.hp_max = 5000
	d.hp = 5000
	var s: BattleState = _state(a, d)
	a.melee_skill = 500
	d.hex = Hex.from_col_row(5, 4)
	a.hex = Hex.from_col_row(4, 4)
	s.attack(a, d)
	t.check(a.weapon_dur_now() < a.weapon_dur_max(), "toucher une armure use l'arme")
	var plain: Unit = t.mk("hache", "e")
	plain.arm_b = 0
	plain.arm_h = 0
	var before: int = a.weapon_dur_now()
	var s2: BattleState = _state(a, plain)
	plain.hex = Hex.from_col_row(5, 4)
	s2.attack(a, plain)
	t.eq(a.weapon_dur_now(), before, "pas d'usure contre une cible sans armure")
	# Arme ébréchée : moins de dégâts
	var r1: RandomNumberGenerator = t.rng_seeded(1)
	var r2: RandomNumberGenerator = t.rng_seeded(1)
	var tgt: Unit = t.mk("gourdin", "e")
	tgt.arm_b = 0
	tgt.arm_h = 0
	var fresh: Unit = t.mk("hache", "p")
	var dull: Unit = t.mk("hache", "p")
	dull.weapon_dur = 0
	t.check(dull.weapon_broken(), "arme ébréchée")
	var sum_f: int = 0
	var sum_d: int = 0
	for i in 50:
		sum_f += int(CombatRules.roll_damage(fresh, tgt, r1)["hp"])
		sum_d += int(CombatRules.roll_damage(dull, tgt, r2)["hp"])
	t.check(sum_d < sum_f * 0.8, "arme ébréchée : dégâts réduits (%d vs %d)" % [sum_d, sum_f])
	var claws: Unit = t.mk("griffes", "e")
	t.check(not claws.weapon_wears() and not claws.wear_weapon(5), "les griffes ne s'usent pas")


func test_usure_sauvegarde_et_combat() -> void:
	var u: Unit = t.mk("epee", "p")
	u.shield = true
	u.weapon_dur = 12
	u.shield_dur = 7
	var b: Unit = Unit.from_dict(JSON.parse_string(JSON.stringify(u.to_dict())))
	t.eq(b.weapon_dur, 12, "usure d'arme sauvegardée")
	t.eq(b.shield_dur, 7, "usure de bouclier sauvegardée")
	var old: Dictionary = u.to_dict()
	old.erase("weapon_dur")
	old.erase("shield_dur")
	var c: Unit = Unit.from_dict(old)
	t.eq(c.weapon_dur_now(), c.weapon_dur_max(), "ancienne sauvegarde : arme neuve")
	t.eq(c.shield_dur_now(), c.shield_dur_max(), "ancienne sauvegarde : bouclier neuf")
	var cd: Unit = Unit.from_combat_dict(JSON.parse_string(JSON.stringify(u.combat_dict())))
	t.eq(cd.shield_dur, 7, "état de combat conserve l'usure")


func test_reparation_armes_et_boucliers() -> void:
	var g: Node = t.new_game(21)
	var m: Unit = g.roster[0]
	t.eq(g.gear_repair_cost(m), 0, "équipement neuf : rien à réparer")
	var cost0: int = g.repair_cost()
	m.weapon_dur = 0
	var wc: int = g.gear_repair_cost(m)
	t.check(wc > 0, "arme usée : coût > 0")
	t.eq(wc, int(ceil(float(Data.WPN[m.weapon]["price"]) * Data.REPAIR_GEAR_RATE)), "coût proportionnel au prix")
	m.weapon_dur = Data.WEAPON_DUR / 2
	t.check(g.gear_repair_cost(m) < wc, "demi-usure : moins cher")
	m.weapon_dur = 0
	if not m.shield:
		m.shield = true
	m.shield_dur = 0
	t.check(g.repair_cost() > cost0, "le total du camp inclut armes et boucliers")
	g.gold = 5000
	g.location = g.world.settlements[0]["id"]
	var gold0: int = g.gold
	var c: int = g.repair_cost()
	g.repair()
	t.eq(g.gold, gold0 - c, "réparation payée")
	t.eq(m.weapon_dur_now(), m.weapon_dur_max(), "arme réparée")
	t.eq(m.shield_dur_now(), m.shield_dur_max(), "bouclier réparé")
	t.eq(g.repair_cost(), 0, "plus rien à réparer")
	g.free()


func test_butin_use() -> void:
	var foe: Unit = t.mk("hache", "e")
	foe.shield = true
	foe.dead = true
	foe.head = "none"
	foe.body = "none"
	var got_worn: bool = false
	for i in 40:
		for it in Loot.roll_battle([foe], t.rng_seeded(i)):
			if Loot.dur_max(it) > 0:
				t.check(Loot.dur_of(it) < Loot.dur_max(it), "butin d'arme ou de bouclier : seconde main")
				got_worn = true
	t.check(got_worn, "du butin usé est tombé")
	var it: Dictionary = Loot.item("weapon", "epee")
	t.eq(Loot.dur_of(it), Data.WEAPON_DUR, "objet sans champ dur : neuf")
	var price_new: int = Loot.sell_base(it)
	it["dur"] = 0
	t.check(Loot.sell_base(it) < price_new, "objet usé : se vend moins cher")
	# Équipement : l'usure suit l'objet
	var u: Unit = t.mk("gourdin", "p")
	u.weapon_dur = 20
	var removed: Array = Loot.equip(u, {"kind": "weapon", "key": "epee", "dur": 9})
	t.eq(u.weapon_dur, 9, "arme équipée : usure de l'objet")
	t.eq(int(removed[0]["dur"]), 20, "ancienne arme rendue avec son usure")
	var sh: Array = Loot.equip(u, {"kind": "shield", "key": "", "dur": 11})
	t.eq(u.shield_dur, 11, "bouclier équipé : usure de l'objet")
	t.check(sh.is_empty(), "rien de retiré")


func test_inventaire_conserve_usure_en_sauvegarde() -> void:
	var g: Node = t.new_game(5)
	g.inventory.append({"kind": "weapon", "key": "fleau", "dur": 17})
	g.inventory.append({"kind": "shield", "key": "", "dur": 3})
	var g2: Node = load("res://autoload/Game.gd").new()
	g2.autosave = false
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	t.eq(int(g2.inventory[g2.inventory.size() - 2]["dur"]), 17, "usure de l'inventaire conservée")
	t.eq(int(g2.inventory[g2.inventory.size() - 1]["dur"]), 3, "usure du bouclier conservée")
	g.free()
	g2.free()
