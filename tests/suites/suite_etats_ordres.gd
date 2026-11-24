extends RefCounted
## États de combat (core/statuses.gd), onguents et potions (core/consumables.gd), ordres de groupe (core/orders.gd).
var t  # le lanceur (voir tests/suites/README.md)


func _field(w: int = 12, h: int = 9) -> Dictionary:
	var cells: Dictionary = {}
	for r in h:
		for c in w:
			cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	return cells


func _bare(seed_value: int = 3) -> BattleState:
	var s := BattleState.new()
	s.rng = t.rng_seeded(seed_value)
	s.cells = _field()
	s.round_no = 1
	return s


func _add(s: BattleState, weapon: String, side: String, col: int, row: int = 4) -> Unit:
	var u: Unit = t.mk(weapon, side, Hex.from_col_row(col, row))
	u.reset_for_battle()
	s.units.append(u)
	return u


# --- États ---

func test_application_et_duree() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	t.check(not Statuses.any(u), "aucun état au départ")
	t.check(Statuses.apply(s, u, "bleed"), "saignement posé")
	t.eq(Statuses.turns(u, "bleed"), 3, "durée par défaut du saignement")
	t.check(not Statuses.apply(s, u, "bleed", 2), "déjà saignant : pas nouveau")
	t.eq(Statuses.turns(u, "bleed"), 3, "la durée ne raccourcit pas")
	Statuses.apply(s, u, "bleed", 5)
	t.eq(Statuses.turns(u, "bleed"), 5, "la durée se prolonge")
	t.check(not Statuses.apply(s, u, "inconnu"), "état inconnu refusé")


func test_immunites() -> void:
	var s := _bare()
	var z: Unit = _add(s, "griffes", "e", 5)
	z.faction = "u"
	t.check(not Statuses.apply(s, z, "bleed"), "un mort-vivant ne saigne pas")
	t.check(not Statuses.apply(s, z, "poison"), "ni ne s'empoisonne")
	t.check(Statuses.apply(s, z, "burn"), "mais il brûle")
	var cart: Unit = _add(s, "poings", "e", 6)
	cart.immobile = true
	t.check(not Statuses.apply(s, cart, "burn"), "un chariot est insensible")


func test_saignement_tick() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	u.hp = u.hp_max
	Statuses.apply(s, u, "bleed", 2)
	s.round_no = 2
	s.begin_turn(u)
	t.eq(u.hp, u.hp_max - 4, "le saignement coûte 4 PV")
	t.eq(Statuses.turns(u, "bleed"), 1, "un tour de moins")
	s.round_no = 3
	s.begin_turn(u)
	t.eq(u.hp, u.hp_max - 8, "deuxième tick")
	t.check(not Statuses.has(u, "bleed"), "le saignement s'arrête au bout de sa durée")
	s.round_no = 4
	s.begin_turn(u)
	t.eq(u.hp, u.hp_max - 8, "plus de perte ensuite")


func test_saignement_mortel() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	var other: Unit = _add(s, "hache", "e", 8)
	u.hp = 3
	Statuses.apply(s, u, "bleed", 3)
	s.round_no = 2
	s.begin_turn(u)
	t.check(u.dead, "il succombe au saignement")
	t.check(other.is_live(), "l'autre n'est pas touché")
	t.check(s.corpses.has(u.hex), "un cadavre reste")


func test_poison_et_initiative() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	var base: int = u.ini_eff()
	Statuses.apply(s, u, "poison")
	t.eq(u.ini_eff(), base - 15, "le poison coûte 15 d'initiative")
	var hp0: int = u.hp
	s.round_no = 2
	s.begin_turn(u)
	t.eq(u.hp, hp0 - 3, "le poison coûte 3 PV")
	t.eq(Statuses.turns(u, "poison"), 3, "durée décomptée")


func test_brulure_moral_et_eau() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	Statuses.apply(s, u, "burn", 3)
	var hp0: int = u.hp
	s.round_no = 2
	s.begin_turn(u)
	t.eq(u.hp, hp0 - 5, "la brûlure coûte 5 PV")
	# l'eau éteint
	var v: Unit = _add(s, "hache", "p", 4)
	Statuses.apply(s, v, "burn", 3)
	s.cells[v.hex]["t"] = "ford"
	var hp1: int = v.hp
	s.round_no = 3
	s.begin_turn(v)
	t.check(not Statuses.has(v, "burn"), "la brûlure s'éteint dans le gué")
	t.eq(v.hp, hp1, "sans dégâts")
	# un pas dans l'eau
	var w: Unit = _add(s, "hache", "p", 6)
	Statuses.apply(s, w, "burn", 3)
	s.cells[Hex.from_col_row(7, 4)]["t"] = "ford"
	s.step(w, Hex.from_col_row(7, 4))
	t.check(not Statuses.has(w, "burn"), "entrer dans l'eau éteint la brûlure")


func test_brulure_moral_baisse() -> void:
	var s := _bare(11)
	var drops: int = 0
	for i in 40:
		var u: Unit = _add(s, "hache", "p", 3, i % 9)
		u.resolve = 5
		Statuses.apply(s, u, "burn", 2, true)
		u.turn_round = 0
		s.round_no = 2 + i
		s.begin_turn(u)
		if u.morale < 3:
			drops += 1
	t.check(drops > 10, "la brûlure fait perdre le moral à un homme sans détermination (%d)" % drops)


func test_gel_reduit_les_pa() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	Statuses.apply(s, u, "frost", 2)
	s.round_no = 2
	s.begin_turn(u)
	t.eq(u.ap, Data.AP_PER_TURN - 2, "2 PA de moins")
	t.eq(Statuses.turns(u, "frost"), 1, "durée décomptée")
	var w: Unit = _add(s, "hache", "p", 4)
	s.begin_turn(w)
	t.eq(w.ap, Data.AP_PER_TURN, "sans état : PA normaux")


func test_unite_sans_etat_identique() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	var hp0: int = u.hp
	s.round_no = 2
	s.begin_turn(u)
	t.eq(u.hp, hp0, "pas de perte")
	t.eq(u.ap, Data.AP_PER_TURN, "PA pleins")
	t.check(u.statuses.is_empty(), "aucun état apparu")
	t.eq(Statuses.ini_penalty(u), 0, "pas de malus")


func test_sources_arme_et_ennemi() -> void:
	var landed: int = 0
	for i in 60:
		var s := _bare(100 + i)
		var a: Unit = _add(s, "dague", "p", 3)
		var d: Unit = _add(s, "poings", "e", 4)
		d.hp_max = 400
		d.hp = 400
		d.melee_def = 0
		a.melee_skill = 200
		var r: Dictionary = s.attack(a, d)
		if r["hit"] and Statuses.has(d, "bleed"):
			landed += 1
	t.check(landed >= 5, "une dague fait saigner de temps en temps (%d/60)" % landed)
	var poisoned: int = 0
	for i in 60:
		var s2 := _bare(300 + i)
		var g: Unit = _add(s2, "griffes", "e", 3)
		g.foe_key = "goule"
		g.melee_skill = 200
		var v: Unit = _add(s2, "poings", "p", 4)
		v.arm_h = 0
		v.arm_b = 0
		v.hp_max = 400
		v.hp = 400
		if s2.attack(g, v)["hit"] and Statuses.has(v, "poison"):
			poisoned += 1
	t.check(poisoned >= 8, "la goule empoisonne (%d/60)" % poisoned)
	# un coup que l'armure absorbe ne laisse pas de plaie
	var s3 := _bare(9)
	var a3: Unit = _add(s3, "dague", "p", 3)
	var d3: Unit = _add(s3, "poings", "e", 4)
	var res: Array[String] = Statuses.on_hit(s3, a3, d3, "", 2)
	t.check(res.is_empty(), "moins de 5 PV de dégâts : pas de saignement")


func test_huile_et_fleche_feu() -> void:
	var s := _bare(5)
	var a: Unit = _add(s, "hache", "p", 2)
	a.bag[0] = Loot.item("tool", "huile")
	var d: Unit = _add(s, "poings", "e", 5)
	d.hp_max = 500
	d.hp = 500
	var burnt: bool = false
	for i in 8:
		a.tool_used = {}
		a.ap = 9
		a.fat = 0
		var r: Dictionary = s.attack(a, d, false, "lancer_huile")
		if r["hit"] and Statuses.has(d, "burn"):
			burnt = true
			break
	t.check(burnt, "l'huile enflamme la cible touchée")


func test_torche_renversee() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	Scenery.burn(s, u)
	t.check(Statuses.has(u, "burn"), "le feu du décor laisse une brûlure")


func test_soin_arrete_le_saignement() -> void:
	var s := _bare()
	var h: Unit = _add(s, "gourdin", "e", 5)
	h.foe_key = "chaman_orc"
	h.ap = 9
	var t2: Unit = _add(s, "hache", "e", 6)
	t2.hp = 10
	Statuses.apply(s, t2, "bleed")
	t.check(s.heal_ally(h, t2), "le chaman soigne")
	t.check(not Statuses.has(t2, "bleed"), "et le saignement s'arrête")


func test_fleche_empoisonnee() -> void:
	var s := _bare(21)
	var a: Unit = _add(s, "arc", "p", 2)
	var d: Unit = _add(s, "poings", "e", 5)
	d.hp_max = 500
	d.hp = 500
	t.check(not CombatRules.abilities_of(a).has("fleche_venimeuse"), "pas de fiole : pas de tir empoisonné")
	a.bag[0] = Loot.item("tool", "venin")
	t.check(CombatRules.abilities_of(a).has("fleche_venimeuse"), "avec une fiole : tir empoisonné disponible")
	var got: bool = false
	for i in 10:
		a.ap = 9
		a.fat = 0
		a.ammo = 20
		a.tool_used = {}
		var r: Dictionary = s.attack(a, d, false, "fleche_venimeuse")
		if r["hit"]:
			got = Statuses.has(d, "poison")
			break
	t.check(got, "la flèche touchée empoisonne")
	a.tool_used = {"venin": 2}
	t.check(not CombatRules.abilities_of(a).has("fleche_venimeuse"), "fiole épuisée")


func test_fin_de_bataille_aucun_etat() -> void:
	var u: Unit = t.mk("hache", "p", Vector2i.ZERO)
	u.statuses = {"bleed": 2, "poison": 1}
	t.check(not u.to_dict().has("statuses"), "les états ne passent pas par la fiche de l'homme")
	t.check(Unit.from_dict(u.to_dict()).statuses.is_empty(), "une copie de la compagnie n'a aucun état")
	var cd: Dictionary = u.combat_dict()
	t.check(cd.has("statuses"), "une bataille en cours les garde")
	u.reset_for_battle()
	t.check(u.statuses.is_empty(), "nouvelle bataille : propre")


func test_serialisation_unite() -> void:
	var u: Unit = t.mk("hache", "p", Vector2i.ZERO)
	u.statuses = {"bleed": 2, "burn": 1, "ord_charge": 1}
	var back: Unit = Unit.from_combat_dict(JSON.parse_string(JSON.stringify(u.combat_dict())))
	t.eq(back.statuses, {"bleed": 2, "burn": 1, "ord_charge": 1}, "états conservés (aller-retour JSON)")
	var old: Dictionary = u.combat_dict()
	old.erase("statuses")
	t.check(Unit.from_combat_dict(old).statuses.is_empty(), "ancienne sauvegarde : aucun état")
	var bad: Dictionary = u.combat_dict()
	bad["statuses"] = {"truc": 3, "bleed": -1, "poison": 2}
	t.eq(Unit.from_combat_dict(bad).statuses, {"poison": 2}, "états inconnus ou nuls ignorés")
	bad["statuses"] = "n'importe quoi"
	t.check(Unit.from_combat_dict(bad).statuses.is_empty(), "format invalide toléré")


func test_serialisation_bataille() -> void:
	var s := _bare()
	var a: Unit = _add(s, "hache", "p", 3)
	var b: Unit = _add(s, "hache", "p", 4)
	b.level = 3
	b.resolve = 70
	Statuses.apply(s, a, "poison")
	t.check(Orders.give(s, b, "tenir"), "ordre donné")
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict_for_test() if s.has_method("to_dict_for_test") else _roundtrip_dict(s)))
	var s2: BattleState = BattleState.from_dict(d, t.rng_seeded(1))
	t.eq(s2.unit_by_id(a.id).statuses, a.statuses, "états de bataille conservés")
	t.eq(s2.orders, s.orders, "ordre actif conservé")
	t.check(Statuses.has(s2.unit_by_id(a.id), "ord_tenir"), "état d'ordre conservé")
	var old: Dictionary = d.duplicate(true)
	old.erase("orders")
	t.check(BattleState.from_dict(old, t.rng_seeded(1)).orders.is_empty(), "ancienne sauvegarde de bataille sans ordres")


func _roundtrip_dict(s: BattleState) -> Dictionary:
	return s.to_dict()


# --- Consommables ---

func test_consommables_donnees() -> void:
	for k in ConsumablesData.ITEMS:
		var it: Dictionary = Consumables.item(str(k))
		t.check(Loot.is_valid(it), "objet valide : %s" % k)
		t.check(Loot.base_price(it) > 0, "prix : %s" % k)
		t.check(Consumables.is_consumable(it), "reconnu : %s" % k)
		t.check(ItemIcons.get_icon("tool", str(k)) != null, "icône : %s" % k)
		t.check(Inventory.accepts("bag0", it), "le sac l'accepte : %s" % k)
		t.check(Inventory.tooltip(it).length() > 0, "infobulle : %s" % k)
		t.check(Loot.clean(it) == it, "nettoyage stable : %s" % k)
	t.check(not Consumables.is_consumable(Loot.item("tool", "huile")), "l'huile n'est pas un consommable")
	t.check(ItemIcons.get_icon("tool", "venin") != null, "icône de la fiole de venin")


func test_bandage() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	u.hp = u.hp_max - 20
	Statuses.apply(s, u, "bleed")
	u.bag[0] = Consumables.item("bandage")
	t.check(Consumables.can_use(s, u, 0), "utilisable")
	var ap0: int = u.ap
	t.check(Consumables.use(s, u, 0), "bandage utilisé sur soi")
	t.check(not Statuses.has(u, "bleed"), "le saignement est arrêté")
	t.eq(u.hp, u.hp_max - 14, "6 PV rendus")
	t.eq(u.ap, ap0 - 3, "3 PA")
	t.check((u.bag[0] as Dictionary).is_empty(), "le bandage est consommé")
	t.check(not Consumables.use(s, u, 0), "plus rien dans le sac")


func test_bandage_sur_un_allie() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	var ally: Unit = _add(s, "hache", "p", 4)
	var far: Unit = _add(s, "hache", "p", 8)
	Statuses.apply(s, ally, "bleed")
	Statuses.apply(s, far, "bleed")
	u.bag[1] = Consumables.item("bandage")
	t.check(Consumables.targets(s, u, 1).has(ally), "l'allié au contact est une cible")
	t.check(not Consumables.targets(s, u, 1).has(far), "pas celui qui est loin")
	t.check(not Consumables.targets(s, u, 1).has(u), "ni soi-même s'il va bien")
	t.check(Consumables.use(s, u, 1, ally), "soigne l'allié")
	t.check(not Statuses.has(ally, "bleed"), "son saignement s'arrête")
	t.check(Statuses.has(far, "bleed"), "l'autre saigne toujours")


func test_inutile_refuse() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	u.bag[0] = Consumables.item("antidote")
	t.check(not Consumables.can_use(s, u, 0), "pas empoisonné : l'antidote reste dans le sac")
	t.check(not Consumables.use(s, u, 0), "refusé")
	t.check(not (u.bag[0] as Dictionary).is_empty(), "rien de consommé")
	Statuses.apply(s, u, "poison")
	t.check(Consumables.use(s, u, 0), "empoisonné : utilisé")
	t.check(not Statuses.has(u, "poison"), "poison guéri")


func test_onguent_tonique_courage() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	Statuses.apply(s, u, "burn")
	u.hp = u.hp_max - 30
	u.bag[0] = Consumables.item("onguent")
	t.check(Consumables.use(s, u, 0), "onguent")
	t.check(not Statuses.has(u, "burn"), "brûlure éteinte")
	t.eq(u.hp, u.hp_max - 22, "8 PV")
	u.fat = 60
	u.bag[0] = Consumables.item("tonique")
	t.check(Consumables.use(s, u, 0), "tonique")
	t.eq(u.fat, 20, "40 de fatigue en moins")
	u.ap = 9
	u.morale = 1
	u.bag[0] = Consumables.item("fiole_courage")
	t.check(Consumables.use(s, u, 0), "fiole de courage")
	t.eq(u.morale, 2, "un cran de moral")
	u.morale = 4
	u.bag[0] = Consumables.item("fiole_courage")
	t.check(not Consumables.can_use(s, u, 0), "moral au maximum : refusé")


func test_pa_insuffisants() -> void:
	var s := _bare()
	var u: Unit = _add(s, "hache", "p", 3)
	u.hp = 10
	u.ap = 2
	u.bag[0] = Consumables.item("bandage")
	t.check(not Consumables.can_use(s, u, 0), "2 PA : pas assez")


func test_butin_et_marche() -> void:
	var s := _bare()
	var any_drop: bool = false
	for i in 40:
		var e: Unit = _add(s, "hache", "e", 5, i % 9)
		e.dead = true
		e.leader = true
	var drops: Array = Consumables.roll_loot(s.units)
	any_drop = not drops.is_empty()
	t.check(any_drop, "des consommables tombent sur des chefs")
	for it in drops:
		t.check(Consumables.is_consumable(it), "butin valide")
	t.check(Consumables.roll_loot(s.units) == drops, "tirage reproductible")
	var city: Array = Consumables.shop_entries("city", t.rng_seeded(7))
	t.check(not city.is_empty(), "la ville vend des soins")
	for e in city:
		t.check(Loot.is_valid(e) and int(e["qty"]) >= 1, "entrée de boutique valide")
	var stock: Array = Market.generate("city", t.rng_seeded(5))
	var has_c: bool = false
	for e in stock:
		if Consumables.is_consumable(e):
			has_c = true
	t.check(has_c, "le stock d'une ville contient un consommable")
	var first: Dictionary = Loot.item("tool", "bandage")
	first["qty"] = 1
	var sold: Array = [first]
	Market.add_sold(sold, Consumables.item("bandage"))
	t.check(sold.size() == 1 and int(sold[0]["qty"]) == 2, "un consommable vendu s'empile")


func test_sac_ancienne_sauvegarde() -> void:
	var u: Unit = t.mk("hache", "p", Vector2i.ZERO)
	u.bag[0] = Consumables.item("antidote")
	var back: Unit = Unit.from_dict(JSON.parse_string(JSON.stringify(u.to_dict())))
	t.eq(back.bag[0]["key"], "antidote", "le sac garde le consommable")
	var d: Dictionary = u.to_dict()
	d["bag"] = [{"kind": "tool", "key": "poison_inconnu"}, {}]
	t.check((Unit.from_dict(d).bag[0] as Dictionary).is_empty(), "consommable inconnu écarté")


# --- Ordres ---

func _company(s: BattleState) -> Array:
	var cap: Unit = _add(s, "epee", "p", 4)
	cap.level = 4
	cap.resolve = 70
	cap.shield = true
	var a: Unit = _add(s, "lance", "p", 4, 3)
	a.shield = true
	var b: Unit = _add(s, "hache", "p", 5, 5)
	var far: Unit = _add(s, "hache", "p", 0, 0)
	var foe: Unit = _add(s, "hache", "e", 8)
	return [cap, a, b, far, foe]


func test_capitaine() -> void:
	var s := _bare()
	var c: Array = _company(s)
	t.eq(Orders.company_captain(s, "p"), c[0], "le plus haut niveau est capitaine")
	t.check(Orders.is_captain(s, c[0]), "capitaine reconnu")
	t.check(not Orders.is_captain(s, c[1]), "les autres non")
	c[1].perks.append("chef_ne")
	t.check(Orders.is_captain(s, c[1]), "un talent de chef suffit")
	t.check(not Orders.is_captain(s, c[4]), "un ennemi ordinaire n'est pas capitaine")
	c[4].leader = true
	t.check(Orders.is_captain(s, c[4]), "le chef ennemi l'est")
	c[0].resolve = 20
	c[1].perks.clear()
	t.check(Orders.company_captain(s, "p") != c[0], "détermination insuffisante : pas capitaine")


func test_ordre_tenir() -> void:
	var s := _bare()
	var c: Array = _company(s)
	var cap: Unit = c[0]
	var a: Unit = c[1]
	var far: Unit = c[3]
	var def0: int = a.eff("melee_def")
	var ap0: int = cap.ap
	t.check(Orders.give(s, cap, "tenir"), "ordre donné")
	t.eq(cap.ap, ap0 - 3, "coût en PA du capitaine")
	t.eq(a.eff("melee_def"), def0 + 10, "+10 en défense")
	t.check(Statuses.has(cap, "ord_tenir"), "le capitaine aussi")
	t.check(not Statuses.has(far, "ord_tenir"), "pas hors du rayon")
	a.morale = 1
	a.resolve = 1
	for i in 30:
		CombatRules.morale_test_fails(a, -50, s.rng)
	t.check(a.morale >= 1, "ne peut plus être mis en fuite")
	t.check(not Orders.can_give(s, cap, "charge"), "un seul ordre par manche")
	s.round_no = 2
	cap.ap = 9
	cap.fat = 0
	s.begin_turn(cap)
	t.check(not Statuses.has(a, "ord_tenir"), "l'ordre prend fin au tour du capitaine")
	t.check(Orders.can_give(s, cap, "charge"), "nouvel ordre possible à la manche suivante")


func test_ordre_charge() -> void:
	var s := _bare()
	var c: Array = _company(s)
	var a: Unit = c[1]
	var foe: Unit = c[4]
	var hit0: int = CombatRules.hit_chance(a, foe, s.units, s.cells)
	var ini0: int = a.ini_eff()
	t.check(Orders.give(s, c[0], "charge"), "Chargez !")
	t.eq(CombatRules.hit_chance(a, foe, s.units, s.cells), clampi(hit0 + 10, 5, 95), "+10 % au toucher")
	t.eq(a.ini_eff(), ini0 + 15, "+15 d'initiative")


func test_ordre_mur() -> void:
	var s := _bare()
	var c: Array = _company(s)
	var cap: Unit = c[0]
	var a: Unit = c[1]
	var b: Unit = c[2]
	t.check(Orders.give(s, cap, "mur"), "mur collectif")
	t.check(cap.shield_wall and a.shield_wall, "les porteurs de bouclier proches forment le mur")
	t.check(not b.shield_wall, "pas celui qui n'a pas de bouclier")
	t.check(not c[3].shield_wall, "ni celui qui est loin")
	var s2 := _bare()
	var c2: Array = _company(s2)
	for u in c2:
		u.shield = false
	t.check(not Orders.can_give(s2, c2[0], "mur"), "sans bouclier : impossible")
	t.check(Orders.why_not(s2, c2[0], "mur") != "", "raison donnée")


func test_ordre_repli() -> void:
	var s := _bare()
	var c: Array = _company(s)
	var a: Unit = c[1]
	var foe: Unit = c[4]
	foe.hex = Hex.neighbors(a.hex)[0]
	t.check(s.free_attackers(a).has(foe), "sans ordre : attaque gratuite")
	t.check(Orders.give(s, c[0], "repli"), "repli coordonné")
	t.check(s.free_attackers(a).is_empty(), "plus d'attaque gratuite")
	t.check(s.free_attackers(c[3]).size() == 0, "(hors contact de toute façon)")


func test_ordre_annule_par_la_mort() -> void:
	var s := _bare()
	var c: Array = _company(s)
	var cap: Unit = c[0]
	var a: Unit = c[1]
	Orders.give(s, cap, "tenir")
	t.check(Statuses.has(a, "ord_tenir"), "ordre actif")
	s.kill_env(cap, "un test")
	t.check(not Statuses.has(a, "ord_tenir"), "annulé par la mort du capitaine")
	t.eq(int(Orders.active(s, "p")["cap"]), -1, "plus de capitaine actif")
	# un seul ordre actif à la fois
	var s2 := _bare()
	var c2: Array = _company(s2)
	Orders.give(s2, c2[0], "tenir")
	s2.round_no = 2
	c2[0].ap = 9
	c2[0].fat = 0
	t.check(Orders.give(s2, c2[0], "charge"), "nouvel ordre")
	t.check(not Statuses.has(c2[1], "ord_tenir") and Statuses.has(c2[1], "ord_charge"), "le nouvel ordre remplace l'ancien")


func test_ordre_limites() -> void:
	var s := _bare()
	var c: Array = _company(s)
	var cap: Unit = c[0]
	cap.ap = 2
	t.check(not Orders.can_give(s, cap, "tenir"), "pas assez de PA")
	t.check(not Orders.can_give(s, c[1], "tenir"), "pas capitaine")
	var alone := _bare()
	var l: Unit = _add(alone, "epee", "p", 3)
	l.level = 5
	l.resolve = 80
	t.check(not Orders.can_give(alone, l, "tenir"), "seul : personne à commander")


func test_ia_ordres() -> void:
	var given: int = 0
	for i in 50:
		var s := _bare(500 + i)
		var boss: Unit = _add(s, "epee", "e", 8)
		boss.leader = true
		boss.shield = true
		var e1: Unit = _add(s, "hache", "e", 7, 3)
		e1.shield = true
		var e2: Unit = _add(s, "hache", "e", 7, 5)
		e2.shield = true
		var p1: Unit = _add(s, "hache", "p", 3)
		var act: Dictionary = Ai.next_action(s, boss, {})
		if act["type"] == "order":
			given += 1
			s.execute(boss, act)
			t.check(Orders.active(s, "e").has("id") and str(Orders.active(s, "e")["id"]) != "", "l'ordre de l'IA est enregistré")
	t.check(given > 5, "un chef ennemi donne parfois un ordre (%d/50)" % given)
	var s3 := _bare()
	var grunt: Unit = _add(s3, "hache", "e", 8)
	_add(s3, "hache", "p", 3)
	t.eq(Orders.ai_pick(s3, grunt), "", "un simple soldat n'en donne pas")


func test_ordres_serialisation() -> void:
	t.eq(Orders.clean({"p": {"id": "tenir", "cap": 3, "round": 2}, "e": {"id": "bidon", "cap": 1}}), {"p": {"id": "tenir", "cap": 3, "round": 2}, "e": {"id": "", "cap": 1, "round": -1}}, "ordres nettoyés")
	t.eq(Orders.clean("x"), {}, "format invalide")
	for id in OrdersData.ORDER_IDS:
		var od: Dictionary = OrdersData.ORDERS[id]
		t.check(od["status"] == "" or StatusesData.has(str(od["status"])), "état d'ordre connu : %s" % id)


func test_bataille_complete_sans_blocage() -> void:
	# batailles IA contre IA : les états et les ordres ne bloquent jamais le déroulement
	for seed_value in 12:
		var rng: RandomNumberGenerator = t.rng_seeded(900 + seed_value)
		var roster: Array = []
		for i in 6:
			var u: Unit = t.mk("epee" if i == 0 else ("dague" if i == 1 else "hache"), "p", Vector2i.ZERO)
			u.level = 4 if i == 0 else 1
			u.resolve = 60
			roster.append(u)
		var contract: Dictionary = Contracts.normalize({"kind": "contract", "title": "Test", "employer": "X", "pay": 100, "d": 2, "foes": ["brigand", "brigand", "archer", "goule", "chef", "balafre"], "biome": "plain"})
		var s: BattleState = BattleState.create(contract, roster, rng, 3, 1.0, "normal", {})
		var guard: int = 0
		while s.over == "" and guard < 600:
			guard += 1
			var u: Unit = s.next_turn()
			if u == null:
				break
			s.play_ai_turn(u)
		t.check(s.over != "" or guard < 600, "bataille %d terminée sans blocage" % seed_value)
