extends RefCounted
## Qualité des objets (core/item_grade.gd) et entretien (core/upkeep.gd, atelier de Game) : grades bornés et par défaut = comportement
## d'origine, conservation du grade (équiper / ranger / donner / vendre / acheter / sauvegarder), bonus temporaires qui expirent,
## réparation par paliers et coûts, forgeron selon le lieu, anciennes sauvegardes.
var t  # le lanceur (voir tests/suites/README.md)


func _graded(kind: String, key: String, q: int) -> Dictionary:
	return ItemGrade.with_grade(Loot.item(kind, key), q)


func _man(weapon: String = "epee") -> Unit:
	var u: Unit = t.mk(weapon, "p")
	u.head = "none"
	u.arm_h = 0
	u.body = "tunique"
	u.arm_b = int(Data.BODY["tunique"]["a"])
	return u


# --- Grades : bornes et valeurs par défaut ---

func test_defaut_identique_a_l_ancien_comportement() -> void:
	for it in [Loot.item("weapon", "epee"), Loot.item("shield"), Loot.item("head", "casque"), Loot.item("body", "mailles")]:
		t.eq(ItemGrade.of(it), 0, "sans clé q : correcte")
		t.eq(Loot.base_price(it), int(Loot.data_of(it).get("price", 0)), "prix inchangé")
		t.eq(Loot.item_name(it), str(Loot.data_of(it)["n"]), "nom inchangé")
	t.eq(Loot.dur_max(Loot.item("weapon", "epee")), Data.WEAPON_DUR, "durabilité d'arme inchangée")
	t.eq(Loot.dur_max(Loot.item("shield")), int(Data.SHIELD["dur"]), "durabilité de bouclier inchangée")
	t.eq(Loot.armor_max(Loot.item("body", "mailles")), 130, "armure inchangée")
	var u: Unit = _man()
	u.head = "casque"
	u.arm_h = 90
	t.eq(u.weapon_dur_max(), Data.WEAPON_DUR, "homme : durabilité d'arme inchangée")
	t.eq(u.head_armor_max(), 90, "homme : armure de tête inchangée")
	t.eq(u.grade_dmg_mult(), 1.0, "pas de bonus de dégâts")
	t.check(not Loot.clean(Loot.item("weapon", "epee")).has("q"), "pas de clé q ajoutée")
	t.check(not u.to_dict().has("weapon_q") and not u.to_dict().has("upkeep"), "sauvegarde d'un homme ordinaire : aucune clé nouvelle")


func test_grades_bornes() -> void:
	t.eq(ItemGrade.of({"kind": "weapon", "key": "epee", "q": 99}), 2, "plafonné à maîtresse")
	t.eq(ItemGrade.of({"kind": "weapon", "key": "epee", "q": -9}), -1, "plancher grossière")
	t.check(not ItemGrade.with_grade(Loot.item("weapon", "epee"), 0).has("q"), "correcte : pas de clé")
	t.check(not ItemGrade.with_grade(Loot.item("tool", "pierre"), 2).has("q"), "un outil n'a pas de grade")
	t.check(not ItemGrade.with_grade(Uniques.item_of("u_epee_corbeau"), 2).has("q"), "un unique n'a pas de grade")
	t.eq(Loot.clean({"kind": "weapon", "key": "epee", "q": 9})["q"], 2, "q hors bornes ramené dans les bornes")
	var prev: float = 0.0
	for g in ItemGrade.GRADES:
		t.check(ItemGrade.price_mult(g) > prev, "le prix croît avec le grade")
		prev = ItemGrade.price_mult(g)
		t.check(ItemGrade.dmg_mult(g) > 0.5 and ItemGrade.dmg_mult(g) < 1.5, "effets modestes (dégâts)")
		t.check(ItemGrade.armor_mult(g) > 0.5 and ItemGrade.armor_mult(g) < 1.5, "effets modestes (armure)")
	t.check(ItemGrade.dmg_mult(-1) < 1.0 and ItemGrade.dmg_mult(1) > 1.0 and ItemGrade.dmg_mult(2) > ItemGrade.dmg_mult(1), "ordre des dégâts")


func test_effets_du_grade() -> void:
	var fine: Dictionary = _graded("weapon", "hache", 1)
	var rough: Dictionary = _graded("weapon", "hache", -1)
	t.check(Loot.dur_max(fine) > Data.WEAPON_DUR and Loot.dur_max(rough) < Data.WEAPON_DUR, "durabilité selon le grade")
	t.check(Loot.base_price(fine) > 320 and Loot.base_price(rough) < 320, "prix selon le grade")
	t.check(Loot.dmg_max(fine) > 45 and Loot.dmg_max(rough) < 45, "dégâts affichés selon le grade")
	var master_armor: Dictionary = _graded("body", "mailles", 2)
	t.check(Loot.armor_max(master_armor) > 130, "armure max d'une pièce maîtresse")
	t.eq(Loot.armor_of(master_armor), Loot.armor_max(master_armor), "armure intacte = pleine")
	t.check(Loot.sell_base(fine) > Loot.sell_base(Loot.item("weapon", "hache")), "revente plus chère")
	t.check(Loot.repair_price(Loot.worn(_graded("weapon", "hache", 2), 10)) > Loot.repair_price(Loot.worn(Loot.item("weapon", "hache"), 10)), "réparation plus chère")


func test_noms_accordes() -> void:
	t.eq(Loot.item_name(_graded("weapon", "hache", 1)), "Hache fine", "féminin")
	t.eq(Loot.item_name(_graded("head", "casque", 1)), "Casque à nasal fin", "masculin")
	t.eq(Loot.item_name(_graded("weapon", "hache", -1)), "Hache grossière", "grossière")
	t.eq(Loot.item_name(_graded("weapon", "javelot", 1)), "Javelots fins", "pluriel")
	t.eq(Loot.item_name(_graded("shield", "", 2)), "Bouclier rond de maître", "maîtresse")
	t.check(Inventory.tooltip(_graded("weapon", "epee", 2)).contains("Qualité maîtresse"), "infobulle : ligne de qualité")
	t.check(not Inventory.tooltip(Loot.item("weapon", "epee")).contains("Qualité"), "infobulle ordinaire inchangée")


func test_tirage_borne_et_biaise() -> void:
	var r: RandomNumberGenerator = t.rng_seeded(5)
	var n_hi_plain: int = 0
	var n_hi_bias: int = 0
	for i in 1500:
		var g0: int = ItemGrade.roll(r, 0.0)
		var g1: int = ItemGrade.roll(r, 0.8)
		t.check(g0 >= -1 and g0 <= 2 and g1 >= -1 and g1 <= 2, "grade dans les bornes")
		n_hi_plain += 1 if g0 >= 1 else 0
		n_hi_bias += 1 if g1 >= 1 else 0
		t.check(ItemGrade.roll(r, 0.0, ItemGrade.OK) >= 0, "plancher respecté")
	t.check(n_hi_bias > n_hi_plain, "le biais donne plus de fin / maîtresse")
	t.check(n_hi_plain > 0, "les fines existent même sans biais")


# --- Conservation du grade ---

func test_equiper_desequiper_conserve_le_grade() -> void:
	for spec in [["weapon", "hache"], ["shield", ""], ["head", "casque"], ["body", "mailles"]]:
		var u: Unit = _man("epee")
		var stash: Array = [_graded(str(spec[0]), str(spec[1]), 2)]
		t.check(Inventory.equip(stash, u, 0)["ok"], "équiper %s" % spec[0])
		var field: String = "%s_q" % spec[0]
		t.eq(u.get(field), 2, "le porteur garde le grade (%s)" % spec[0])
		var back: Dictionary = Inventory.get_item(stash, Inventory.at(u, str(spec[0])))
		t.eq(ItemGrade.of(back), 2, "l'emplacement reconstruit l'objet avec son grade (%s)" % spec[0])
		t.check(Inventory.unequip(stash, u, str(spec[0]))["ok"], "ranger %s" % spec[0])
		t.eq(u.get(field), 0, "plus de grade une fois ôté (%s)" % spec[0])
		t.eq(ItemGrade.of(stash[stash.size() - 1]) if stash.size() >= 1 else -9, 2, "la réserve garde le grade (%s)" % spec[0])


func test_armure_abimee_et_grade() -> void:
	var u: Unit = _man()
	var stash: Array = [_graded("head", "casque", 2)]
	Inventory.equip(stash, u, 0)
	t.eq(u.head_armor_max(), Loot.armor_max(_graded("head", "casque", 2)), "armure max de la pièce maîtresse")
	t.eq(u.arm_h, u.head_armor_max(), "neuve : pleine")
	u.arm_h = 50
	Inventory.unequip(stash, u, "head")
	t.eq(int(stash[0].get("arm", -1)), 50, "l'armure abîmée est notée")
	t.eq(ItemGrade.of(stash[0]), 2, "et le grade aussi")
	Inventory.equip(stash, u, 0)
	t.eq(u.arm_h, 50, "armure abîmée remise telle quelle")
	t.eq(u.head_q, 2, "grade remis")


func test_echange_et_don_conservent_le_grade() -> void:
	var a: Unit = _man("epee")
	a.weapon_q = 1
	var b: Unit = _man("gourdin")
	b.weapon_q = -1
	var stash: Array = []
	t.check(Inventory.give(stash, a, "weapon", b)["ok"], "don d'une arme")
	t.eq(b.weapon, "epee", "b reçoit l'épée")
	t.eq(b.weapon_q, 1, "avec son grade")
	t.eq(a.weapon_q, -1, "a reçoit le gourdin grossier en échange")
	t.eq(a.weapon, "gourdin", "échange complet")
	# sac -> main
	var c: Unit = _man("epee")
	c.weapon_q = 2
	c.bag[0] = _graded("weapon", "hache", 1)
	t.check(Inventory.bag_swap(c, 0)["ok"], "changement d'arme")
	t.eq(c.weapon, "hache", "hache en main")
	t.eq(c.weapon_q, 1, "grade de la hache")
	t.eq(ItemGrade.of(c.bag[0]), 2, "l'épée rangée dans le sac garde son grade")
	t.eq(c.bag[0]["key"], "epee", "épée dans le sac")


func test_jeu_vente_achat_conservent_le_grade() -> void:
	var g: Node = t.new_game(901)
	g.gold = 99999
	g.inventory = [_graded("weapon", "epee", 2)]
	var plain: int = g.sell_price(Loot.item("weapon", "epee"))
	var price: int = g.sell_price(g.inventory[0])
	t.check(price > plain, "la maîtresse se vend plus cher")
	var n: int = g.shop_stock().size()
	t.check(g.sell_item(0), "vente")
	var last: Dictionary = g.shop_stock()[g.shop_stock().size() - 1]
	t.check(g.shop_stock().size() >= n, "l'objet rejoint le rayon")
	var found: int = -1
	for i in g.shop_stock().size():
		var e: Dictionary = g.shop_stock()[i]
		if str(e["kind"]) == "weapon" and str(e["key"]) == "epee" and ItemGrade.of(e) == 2:
			found = i
	t.check(found >= 0 or last.is_empty(), "le rayon garde le grade vendu")
	t.check(found >= 0, "épée maîtresse en rayon")
	if found >= 0:
		var sp: int = g.stock_price(g.shop_stock()[found])
		t.check(sp > g.stock_price(Loot.item("weapon", "epee")), "plus chère à l'achat aussi")
		t.check(g.buy_item(found), "rachat")
		var bought: Dictionary = g.inventory[g.inventory.size() - 1]
		t.eq(ItemGrade.of(bought), 2, "le grade survit à l'achat")
		var m: Unit = g.roster[0]
		t.check(g.equip_from_inventory(m, g.inventory.size() - 1), "équipement depuis la réserve")
		t.eq(m.weapon_q, 2, "grade porté")
		t.eq(g.inv_unequip(m, "weapon")["ok"], true, "déséquiper")
		t.eq(ItemGrade.of(g.inventory[g.inventory.size() - 1]), 2, "grade conservé à la réserve")
	# renvoi d'un homme : son équipement garde son grade
	var m2: Unit = g.roster[1]
	m2.head = "casque"
	m2.head_q = 1
	m2.arm_h = m2.head_armor_max()
	g.dismiss(m2.id)
	var seen: bool = false
	for it in g.inventory:
		if str(it["kind"]) == "head" and ItemGrade.of(it) == 1:
			seen = true
	t.check(seen, "renvoi : le casque fin revient à la réserve avec son grade")


func test_sauvegarde_conserve_grades_et_entretien() -> void:
	var g: Node = t.new_game(902)
	var m: Unit = g.roster[0]
	m.weapon = "hache"
	m.weapon_q = 2
	m.body = "mailles"
	m.body_q = -1
	m.arm_b = m.body_armor_max()
	m.bag[0] = _graded("shield", "", 1)
	g.inventory = [_graded("body", "brigandine", 1)]
	Upkeep.apply_sharpen(m, Upkeep.smith("city"))
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = t.new_game(903)
	g2.from_dict(d)
	var m2: Unit = g2.roster[0]
	t.eq(m2.weapon_q, 2, "grade de l'arme")
	t.eq(m2.body_q, -1, "grade de l'armure")
	t.eq(m2.arm_b, m2.body_armor_max(), "armure pleine = maximum du grade")
	t.eq(ItemGrade.of(m2.bag[0]), 1, "grade dans le sac")
	t.eq(ItemGrade.of(g2.inventory[0]), 1, "grade en réserve")
	t.eq(int(m2.upkeep["edge"]), int(m.upkeep["edge"]), "arme aiguisée conservée")
	t.check(Upkeep.edge_mult(m2) > 1.0, "bonus encore actif")
	# ancienne sauvegarde : aucune clé de grade ni d'entretien
	for ud in d["roster"]:
		for k in ["weapon_q", "shield_q", "head_q", "body_q", "upkeep"]:
			(ud as Dictionary).erase(k)
	var g3: Node = t.new_game(904)
	g3.from_dict(d)
	t.eq(g3.roster[0].weapon_q, 0, "ancienne sauvegarde : correcte")
	t.check(g3.roster[0].upkeep.is_empty(), "ancienne sauvegarde : sans entretien")
	t.eq(Upkeep.clean("n'importe quoi"), {}, "entretien illisible : ignoré")
	t.eq(Upkeep.clean({"edge": 2, "edge_w": ""}), {}, "entretien sans arme : ignoré")


# --- Tirage au butin, au marché ---

func test_butin_et_bonus_de_contrat() -> void:
	var seen: Dictionary = {}
	for s in 120:
		var e: Unit = t.mk("hache", "e")
		e.dead = true
		e.leader = s % 2 == 0
		e.shield = true
		e.head = "casque"
		e.body = "mailles"
		e.arm_h = 90
		e.arm_b = 130
		for it in Loot.roll_battle([e], t.rng_seeded(s), 50.0):
			t.check(Loot.is_valid(it), "objet de butin valide")
			var q: int = ItemGrade.of(it)
			t.check(q >= -1 and q <= 2, "grade du butin borné")
			t.check(Loot.dur_of(it) <= maxi(Loot.dur_max(it), 0) or Loot.dur_max(it) == 0, "durabilité bornée")
			t.check(Loot.armor_of(it) <= Loot.armor_max(it), "armure bornée")
			seen[q] = true
	t.check(seen.has(0) and (seen.has(1) or seen.has(2)) and seen.has(-1), "le butin comporte des grades variés")
	for s in 300:
		var it2: Dictionary = Loot.roll_contract_bonus(3, t.rng_seeded(s))
		if not it2.is_empty():
			t.check(ItemGrade.of(it2) >= 0, "un bonus de contrat n'est jamais grossier")


func test_marche_grand_bourg_meilleur_que_village() -> void:
	var good_city: int = 0
	var good_village: int = 0
	var total_city: int = 0
	var total_village: int = 0
	for s in 120:
		for kind in ["city", "village"]:
			for e in Market.generate(kind, t.rng_seeded(s)):
				if not ItemGrade.gradable(e):
					continue
				t.check(Loot.is_valid(e), "entrée valide")
				t.check(Loot.wear_ratio(e) <= 1.0 and Loot.wear_ratio(e) > 0.0, "usure bornée")
				var q: int = ItemGrade.of(e)
				if kind == "city":
					total_city += 1
					good_city += 1 if q >= 1 else 0
				else:
					total_village += 1
					good_village += 1 if q >= 1 else 0
	t.check(total_city > 0 and total_village > 0, "des objets gradables en rayon")
	t.check(float(good_city) / float(total_city) > float(good_village) / float(total_village), "un grand bourg a plus de fin / maîtresse")
	# le stock gradé survit à la sauvegarde
	var stock: Array = Market.generate("city", t.rng_seeded(3))
	var back: Array = Market.clean(JSON.parse_string(JSON.stringify(stock)))
	t.eq(back.size(), stock.size(), "relecture du stock")
	var q_before: Array = stock.map(func(e: Dictionary) -> int: return ItemGrade.of(e))
	var q_after: Array = back.map(func(e: Dictionary) -> int: return ItemGrade.of(e))
	t.eq(q_after, q_before, "grades du rayon conservés par la sauvegarde")


# --- Effets en combat ---

func test_degats_selon_le_grade() -> void:
	var sum: Dictionary = {-1: 0, 0: 0, 2: 0}
	for q in sum:
		for s in 60:
			var a: Unit = _man("hache")
			a.weapon_q = q
			var d: Unit = _man("gourdin")
			d.arm_h = 0
			d.arm_b = 0
			var res: Dictionary = CombatRules.roll_damage(a, d, t.rng_seeded(s))
			sum[q] = int(sum[q]) + int(res["hp"])
	t.check(int(sum[-1]) < int(sum[0]) and int(sum[0]) < int(sum[2]), "dégâts : grossière < correcte < maîtresse (mêmes tirages)")


func test_aiguiser_et_huiler_en_combat() -> void:
	var a: Unit = _man("epee")
	var d: Unit = _man("gourdin")
	d.arm_h = 0
	d.arm_b = 0
	var base: int = 0
	var sharp: int = 0
	for s in 60:
		base += int(CombatRules.roll_damage(a, d, t.rng_seeded(s))["hp"])
	Upkeep.apply_sharpen(a, Upkeep.smith("city"))
	for s in 60:
		sharp += int(CombatRules.roll_damage(a, d, t.rng_seeded(s))["hp"])
	t.check(sharp > base, "arme aiguisée : plus de dégâts")
	# haubert huilé : l'armure encaisse moins
	var armor_plain: float = 0.0
	var armor_oiled: float = 0.0
	var def_plain: Unit = _man()
	def_plain.body = "mailles"
	def_plain.arm_b = 130
	var def_oiled: Unit = _man()
	def_oiled.body = "mailles"
	def_oiled.arm_b = 130
	Upkeep.apply_oil(def_oiled, Upkeep.smith("city"))
	var att: Unit = _man("hache")
	for s in 80:
		var r1: Dictionary = CombatRules.roll_damage(att, def_plain, t.rng_seeded(s))
		var r2: Dictionary = CombatRules.roll_damage(att, def_oiled, t.rng_seeded(s))
		if not bool(r1["head"]):
			armor_plain += float(r1["armor"])
			armor_oiled += float(r2["armor"])
	t.check(armor_oiled < armor_plain, "haubert huilé : l'armure s'use moins")


# --- Aiguiser / huiler : règles, coût, expiration ---

func test_aiguisage_regles_et_expiration() -> void:
	var city: Dictionary = Upkeep.smith("city")
	var village: Dictionary = Upkeep.smith("village")
	var u: Unit = _man("epee")
	t.eq(Upkeep.why_not_sharpen(u, city), "", "une épée s'aiguise")
	t.check(Upkeep.why_not_sharpen(_man("masse"), city) != "", "une masse (contondante) non")
	t.check(Upkeep.why_not_sharpen(_man("arc"), city) != "", "un arc non")
	t.check(Upkeep.why_not_sharpen(_man("poings"), city) != "", "les poings non")
	var cost_city: int = Upkeep.sharpen_cost(u, city)
	var cost_village: int = Upkeep.sharpen_cost(u, village)
	t.check(cost_village < cost_city and cost_city > 0, "le village est moins cher")
	t.check(cost_city < 100, "petit coût")
	Upkeep.apply_sharpen(u, city)
	t.check(Upkeep.edge_mult(u) > 1.0, "bonus actif")
	t.eq(Upkeep.edge_left(u), 3, "3 combats en ville")
	t.check(Upkeep.why_not_sharpen(u, city) != "", "déjà aiguisée")
	for i in 2:
		Upkeep.tick_battle(u)
	t.eq(Upkeep.edge_left(u), 1, "il reste un combat")
	Upkeep.tick_battle(u)
	t.eq(Upkeep.edge_mult(u), 1.0, "bonus expiré")
	t.check(u.upkeep.is_empty(), "état nettoyé")
	t.eq(Upkeep.why_not_sharpen(u, village), "", "à refaire")
	Upkeep.apply_sharpen(u, village)
	t.eq(Upkeep.edge_left(u), 2, "2 combats au village")
	t.check(Upkeep.edge_mult(u) < 1.0 + float(city["edge"]) / 100.0, "bonus moindre au village")
	u.weapon = "hache"  # changer d'arme annule le bonus (il suit l'arme aiguisée)
	t.eq(Upkeep.edge_mult(u), 1.0, "l'autre arme n'en profite pas")


func test_huile_regles() -> void:
	var city: Dictionary = Upkeep.smith("city")
	var village: Dictionary = Upkeep.smith("village")
	var u: Unit = _man()
	t.check(Upkeep.why_not_oil(u, city) != "", "une tunique ne s'huile pas")
	u.body = "mailles"
	u.arm_b = 130
	t.check(Upkeep.why_not_oil(u, village).contains("mailles"), "le village ne travaille pas les mailles")
	t.eq(Upkeep.why_not_oil(u, Upkeep.smith("village", 1)), "", "…sauf avec la forge du QG")
	t.eq(Upkeep.why_not_oil(u, city), "", "la ville oui")
	Upkeep.apply_oil(u, city)
	t.check(Upkeep.oil_mult(u, false) < 1.0, "corps huilé")
	t.eq(Upkeep.oil_mult(u, true), 1.0, "la tête n'est pas concernée")
	for i in int(city["combats"]):
		Upkeep.tick_battle(u)
	t.eq(Upkeep.oil_mult(u, false), 1.0, "huile expirée")


func test_jeu_aiguiser_huiler() -> void:
	var g: Node = t.new_game(905)
	g.gold = 1000
	var m: Unit = g.roster[0]
	m.weapon = "epee"
	m.body = "mailles"
	m.arm_b = m.body_armor_max()
	g.settlement()["kind"] = "city"
	var c: int = g.sharpen_cost(m)
	t.check(c > 0, "coût d'aiguisage")
	t.check(g.sharpen(m), "aiguisage")
	t.eq(g.gold, 1000 - c, "or débité")
	t.check(Upkeep.edge_mult(m) > 1.0, "arme aiguisée")
	t.check(not g.sharpen(m), "déjà fait")
	var oc: int = g.oil_cost(m)
	t.check(g.oil(m), "huilage en ville")
	t.eq(g.gold, 1000 - c - oc, "or débité (huile)")
	g.settlement()["kind"] = "village"
	m.upkeep = {}
	t.check(not g.oil(m), "pas d'huilage de mailles au village")
	t.check(g.shop_error.contains("mailles"), "message en français")
	g.gold = 0
	t.check(not g.sharpen(m), "pas d'argent")
	t.eq(g.shop_error, "Pas assez de couronnes.", "message d'or")
	g.leave_settlement()
	t.check(not g.sharpen(m), "hors d'un lieu : impossible")


# --- Réparation par paliers ---

func test_reparation_par_paliers() -> void:
	var city: Dictionary = Upkeep.smith("city")
	var u: Unit = _man()
	u.body = "gambison"
	u.arm_b = 15  # manque 50 sur 65
	t.eq(Upkeep.missing(u, "body"), 50, "points manquants")
	t.eq(Upkeep.step_points(u, "body", 0.25), 17, "25 % de 65 = 17 points")
	t.eq(Upkeep.step_points(u, "body", 0.5), 33, "50 % de 65 = 33 points")
	t.eq(Upkeep.step_points(u, "body", 1.0), 50, "100 % = tout ce qui manque")
	var c25: int = Upkeep.step_cost(u, "body", 0.25, city)
	var c50: int = Upkeep.step_cost(u, "body", 0.5, city)
	var c100: int = Upkeep.step_cost(u, "body", 1.0, city)
	t.check(c25 < c50 and c50 < c100, "coût proportionnel")
	t.eq(c100, int(ceil(50 * Upkeep.ARMOR_POINT_PRICE)), "100 % = 0,5 par point comme la réparation globale")
	t.eq(Upkeep.apply_repair(u, "body", 0.25), 17, "réparation de 17 points")
	t.eq(u.arm_b, 32, "armure relevée")
	Upkeep.apply_repair(u, "body", 0.5)
	Upkeep.apply_repair(u, "body", 1.0)
	t.eq(u.arm_b, 65, "tout réparé, jamais au-delà")
	t.eq(Upkeep.step_cost(u, "body", 1.0, city), 0, "rien à payer quand c'est neuf")
	t.check(Upkeep.why_not_repair(u, "body", city) != "", "déjà en bon état")
	# arme : le plein tarif égale la réparation globale existante
	var w: Unit = _man("epee")
	w.weapon_dur = 20
	t.eq(Upkeep.step_cost(w, "weapon", 1.0, city), Loot.repair_price(Loot.weapon_item(w)), "arme : 100 % = prix de réparation globale")
	Upkeep.apply_repair(w, "weapon", 0.5)
	t.eq(w.weapon_dur_now(), 50, "50 % de 60 = 30 points rendus (20 -> 50)")
	Upkeep.apply_repair(w, "weapon", 1.0)
	t.eq(w.weapon_dur, -1, "arme neuve : marqueur « neuve »")
	# bouclier gradé : le maximum suit le grade
	var s: Unit = _man()
	s.shield = true
	s.shield_q = 1
	s.shield_dur = 10
	t.eq(Upkeep.missing(s, "shield"), s.shield_dur_max() - 10, "manque selon le maximum du grade")
	Upkeep.apply_repair(s, "shield", 1.0)
	t.eq(s.shield_dur_now(), s.shield_dur_max(), "bouclier remis à neuf")


func test_forgeron_selon_le_lieu() -> void:
	var u: Unit = _man()
	u.body = "mailles"
	u.arm_b = 30
	var village: Dictionary = Upkeep.smith("village")
	var city: Dictionary = Upkeep.smith("city")
	t.check(Upkeep.why_not_repair(u, "body", village).contains("mailles"), "village : pas de mailles")
	t.eq(Upkeep.why_not_repair(u, "body", city), "", "ville : tout")
	t.eq(Upkeep.why_not_repair(u, "body", Upkeep.smith("village", 2)), "", "forge du QG : le village peut aussi")
	var g_village: int = Upkeep.step_cost(u, "body", 1.0, village)
	var g_city: int = Upkeep.step_cost(u, "body", 1.0, city)
	t.check(g_village < g_city, "village moins cher")
	var gam: Unit = _man()
	gam.body = "gambison"
	gam.arm_b = 10
	t.eq(Upkeep.why_not_repair(gam, "body", village), "", "le village répare un gambison")


func test_jeu_reparation_par_paliers() -> void:
	var g: Node = t.new_game(906)
	g.gold = 5000
	var m: Unit = g.roster[0]
	m.body = "gambison"
	m.arm_b = 10
	m.weapon = "epee"
	m.weapon_dur = 20
	g.settlement()["kind"] = "city"
	var cost: int = g.repair_piece_cost(m, "body", 0.5)
	t.check(cost > 0, "coût positif")
	t.check(g.repair_piece(m, "body", 0.5), "palier de 50 %")
	t.eq(g.gold, 5000 - cost, "or débité")
	t.eq(m.arm_b, 10 + 33, "33 points rendus")
	t.check(g.repair_piece(m, "weapon", 1.0), "arme entière")
	t.eq(m.weapon_dur, -1, "arme neuve")
	# forge du QG : la remise existante est conservée
	var base: int = g.repair_piece_cost(m, "body", 1.0)
	g.buildings["forge"] = 2
	t.check(g.repair_piece_cost(m, "body", 1.0) <= base, "la forge du QG ne renchérit pas")
	g.buildings.erase("forge")
	# village et mailles
	m.body = "mailles"
	m.arm_b = 10
	g.settlement()["kind"] = "village"
	t.check(not g.repair_piece(m, "body", 1.0), "village : mailles refusées")
	t.check(g.shop_error.contains("mailles"), "message en français")
	g.buildings["forge"] = 1
	t.check(g.repair_piece(m, "body", 1.0), "avec la forge du QG, le village accepte")
	g.buildings.erase("forge")
	# argent
	m.arm_b = 10
	g.gold = 0
	t.check(not g.repair_piece(m, "body", 0.25) or g.repair_piece_cost(m, "body", 0.25) == 0, "sans argent")
	g.leave_settlement()
	t.check(not g.repair_piece(m, "body", 0.25), "hors d'un lieu")


func test_reparation_globale_inchangee() -> void:
	var g: Node = t.new_game(907)
	g.gold = 5000
	var m: Unit = g.roster[0]
	m.body = "gambison"
	m.arm_b = 20
	m.weapon_dur = 10
	var c: int = g.repair_cost()
	t.check(c > 0, "coût global positif")
	var gold: int = g.gold
	g.repair()
	t.eq(g.gold, gold - c, "or débité du coût annoncé")
	t.eq(m.arm_b, m.body_armor_max(), "armure réparée")
	t.eq(m.weapon_dur, -1, "arme réparée")
	t.eq(g.repair_cost(), 0, "plus rien à payer")
	# avec des grades : réparer à fond atteint le maximum du grade
	m.body_q = 2
	m.arm_b = 5
	g.repair()
	t.eq(m.arm_b, m.body_armor_max(), "armure maîtresse réparée jusqu'à son maximum")
