extends RefCounted
## Emplacements d'armure « Bras » et « Jambes » (core/limbs.gd, Data.ARMS / Data.LEGS) : un homme SANS pièce se bat exactement comme avant
## (mêmes tirages, mêmes dégâts), zones de touche bornées, poids, équiper / déséquiper / vendre / réparer, familles et maîtrises,
## grades, anciennes sauvegardes, ennemis d'élite, calques de figurine.
var t  # le lanceur (voir tests/suites/README.md)


func _attacker() -> Unit:
	return t.mk("hache", "p")


func _target(body: String = "mailles", head: String = "casque") -> Unit:
	var d: Unit = t.mk("hache", "e")
	d.body = body
	d.head = head
	d.arm_b = int(Data.BODY[body]["a"])
	d.arm_h = int(Data.HEAD[head]["a"])
	return d


func _wear(u: Unit, arms: String, legs: String) -> Unit:
	u.arms = arms
	u.legs = legs
	u.arm_a = int(Data.ARMS[arms]["a"])
	u.arm_l = int(Data.LEGS[legs]["a"])
	return u


## Formule d'origine (tête 25 %, sinon corps ; matériau de la pièce ; aucun talent) rejouée sur le même flux de tirages.
func _oracle(a: Unit, d: Unit, rng: RandomNumberGenerator) -> Dictionary:
	var w: Dictionary = a.weapon_data()
	var head: bool = rng.randf() < 0.25
	var raw: float = float(rng.randi_range(int(w["min"]), int(w["max"]))) * (1.5 if head else 1.0)
	var arm: int = d.arm_h if head else d.arm_b
	var hp_d: float
	var arm_d: float = 0.0
	if arm <= 0:
		hp_d = raw
	else:
		var mm: Dictionary = Materials.mods(Materials.of("head" if head else "body", d.head if head else d.body), DamageTypes.of_unit(a))
		var eff: float = float(w["arm"]) * float(mm["arm"])
		var ign: float = float(w["ign"]) * float(mm["ign"])
		var ad: float = raw * eff
		arm_d = minf(float(arm), ad)
		hp_d = maxf(0.0, raw * ign - float(arm) * 0.1)
		if ad > float(arm):
			hp_d += (ad - float(arm)) / eff * (1.0 - ign)
	return {"head": head, "hp": roundi(hp_d), "armor": roundi(arm_d)}


# --- Sans pièce : comportement identique ---

func test_sans_piece_identique() -> void:
	var a: Unit = _attacker()
	for body in ["tunique", "gambison", "mailles", "brigandine"]:
		for s in 60:
			var d: Unit = _target(body)
			var r1: RandomNumberGenerator = t.rng_seeded(s)
			var dmg: Dictionary = CombatRules.roll_damage(a, d, r1)
			var r2: RandomNumberGenerator = t.rng_seeded(s)
			var want: Dictionary = _oracle(a, d, r2)
			t.eq(dmg["head"], want["head"], "zone (tête / corps) comme avant")
			t.eq(dmg["zone"], "head" if want["head"] else "body", "jamais bras ni jambes sans pièce")
			t.eq(dmg["hp"], want["hp"], "PV comme avant (%s, graine %d)" % [body, s])
			t.eq(dmg["armor"], want["armor"], "armure comme avant")
			t.eq(r1.randi(), r2.randi(), "aucun tirage de plus (flux identique)")
	var v: Unit = _target()
	var arm_b: int = v.arm_b
	CombatRules.apply_damage(v, {"head": false, "hp": 1, "armor": 10})
	t.eq(v.arm_b, arm_b - 10, "apply_damage ancienne forme (sans clé zone)")
	t.eq(v.arm_a, 0, "bras intacts")


func test_attaque_de_bataille_comme_avant() -> void:
	# BattleState.attack avec une graine fixe : le coup se déroule comme l'ancienne formule
	for seed_value in 25:
		var roster: Array = [t.mk("hache", "p", Vector2i(3, 3))]
		var foe: Unit = _target("mailles", "casque")
		foe.hex = Vector2i(4, 3)
		var s: BattleState = BattleState.create({"type": "b", "d": 1, "foes": ["brigand"], "title": "T", "desc": "", "days": 1, "employer": "x", "pay": 1}, roster, t.rng_seeded(seed_value))
		var a: Unit = s.units[0]
		var d: Unit = s.units[1]
		a.hex = Vector2i(3, 3)
		d.hex = Vector2i(4, 3)
		d.body = "mailles"
		d.head = "casque"
		d.arm_b = 130
		d.arm_h = 90
		d.perks.clear()
		a.perks.clear()
		a.weapon = "hache"
		a.shield = false
		a.ap = 9
		d.shield = false
		d.shield_wall = false
		s.rng = t.rng_seeded(seed_value)
		var ch: int = s.hit_chance(a, d, "")
		var r2: RandomNumberGenerator = t.rng_seeded(seed_value)
		var hit: bool = r2.randi_range(1, 100) <= ch
		var before_b: int = d.arm_b
		var before_h: int = d.arm_h
		var hp0: int = d.hp
		var res: Dictionary = s.attack(a, d)
		t.eq(res["hit"], hit, "touche ou non, comme avant")
		if hit:
			var want: Dictionary = _oracle_from(a, d, before_b, before_h, r2)
			t.eq(res["head"], want["head"], "zone")
			t.eq(res["hp"], want["hp"], "PV du coup")
			t.eq(res["armor"], want["armor"], "armure du coup")
			t.eq(d.arm_a + d.arm_l, 0, "bras et jambes inchangés")
			t.eq(d.arm_b if not want["head"] else d.arm_h, (before_b if not want["head"] else before_h) - int(want["armor"]), "armure de la zone retranchée")
		else:
			t.eq(d.hp, hp0, "raté : aucun dégât")


## Même chose que `_oracle`, mais avec les armures d'avant le coup (`attack` les a déjà entamées).
func _oracle_from(a: Unit, d: Unit, arm_b: int, arm_h: int, rng: RandomNumberGenerator) -> Dictionary:
	var keep_b: int = d.arm_b
	var keep_h: int = d.arm_h
	d.arm_b = arm_b
	d.arm_h = arm_h
	var out: Dictionary = _oracle(a, d, rng)
	d.arm_b = keep_b
	d.arm_h = keep_h
	return out


func test_sauvegarde_sans_piece_sans_cle_nouvelle() -> void:
	var u: Unit = t.mk("epee", "p")
	var d: Dictionary = u.to_dict()
	for k in ["arms", "legs", "arm_a", "arm_l", "arms_q", "legs_q"]:
		t.check(not d.has(k), "aucune clé « %s » pour un homme sans pièce" % k)
	t.eq(u.weight(), int(Data.BODY["tunique"]["w"]), "poids inchangé sans pièce")
	t.eq(Limbs.total_max(u), 0, "aucune armure de membres")


# --- Zones de touche ---

func test_zones_bornees() -> void:
	var a: Unit = _attacker()
	var counts: Dictionary = {"head": 0, "body": 0, "arms": 0, "legs": 0}
	var d: Unit = _wear(_target(), "manches_mailles", "chausses_mailles")
	var r: RandomNumberGenerator = t.rng_seeded(4242)
	var n: int = 6000
	for i in n:
		var dmg: Dictionary = CombatRules.roll_damage(a, d, r)
		counts[str(dmg["zone"])] += 1
		t.check(["head", "body", "arms", "legs"].has(str(dmg["zone"])), "zone connue")
		t.eq(dmg["head"], dmg["zone"] == "head", "« head » cohérent avec la zone")
	t.check(absf(float(counts["head"]) / n - 0.25) < 0.03, "tête ≈ 25 %% (%d)" % counts["head"])
	t.check(absf(float(counts["arms"]) / n - 0.75 * Data.LIMB_HIT_ARMS) < 0.03, "bras ≈ 11 %% (%d)" % counts["arms"])
	t.check(absf(float(counts["legs"]) / n - 0.75 * Data.LIMB_HIT_LEGS) < 0.03, "jambes ≈ 11 %% (%d)" % counts["legs"])
	t.check(counts["body"] > counts["arms"] and counts["body"] > counts["legs"], "le corps reste la zone principale")
	# une seule pièce : l'autre zone retombe sur le corps
	var only_arms: Unit = _wear(_target(), "manches_mailles", "none")
	var seen: Dictionary = {}
	for i in 1500:
		seen[str(CombatRules.roll_damage(a, only_arms, r)["zone"])] = true
	t.check(seen.has("arms") and not seen.has("legs"), "sans jambière : jamais « jambes »")
	var only_legs: Unit = _wear(_target(), "none", "chausses_mailles")
	seen.clear()
	for i in 1500:
		seen[str(CombatRules.roll_damage(a, only_legs, r)["zone"])] = true
	t.check(seen.has("legs") and not seen.has("arms"), "sans brassard : jamais « bras »")


func test_degats_sur_la_piece() -> void:
	var a: Unit = _attacker()
	var found: Dictionary = {}
	for s in 400:
		var d: Unit = _wear(_target(), "epaulieres_fer", "greves_fer")
		var dmg: Dictionary = CombatRules.roll_damage(a, d, t.rng_seeded(s))
		var zone: String = str(dmg["zone"])
		if zone != "arms" and zone != "legs":
			continue
		found[zone] = true
		var slot_arm: int = d.arm_a if zone == "arms" else d.arm_l
		t.eq(dmg["zone_armor"], slot_arm, "l'armure lue est celle de la pièce touchée")
		# même formule que le corps : matériau de la pièce, armure de la pièce
		var w: Dictionary = a.weapon_data()
		var r2: RandomNumberGenerator = t.rng_seeded(s)
		r2.randf()  # tirage « tête ? »
		var raw: float = float(r2.randi_range(int(w["min"]), int(w["max"])))  # puis les dégâts bruts ; le tirage de zone vient après
		var mm: Dictionary = Materials.mods(Materials.of(zone, d.arms if zone == "arms" else d.legs), DamageTypes.of_unit(a))
		var eff: float = float(w["arm"]) * float(mm["arm"])
		var ign: float = float(w["ign"]) * float(mm["ign"])
		var ad: float = raw * eff
		t.eq(dmg["armor"], roundi(minf(float(slot_arm), ad)), "dégâts d'armure de la pièce")
		var hp_d: float = maxf(0.0, raw * ign - float(slot_arm) * 0.1)
		if ad > float(slot_arm):
			hp_d += (ad - float(slot_arm)) / eff * (1.0 - ign)
		t.eq(dmg["hp"], roundi(hp_d), "PV du coup sur la pièce")
		var b0: int = d.arm_b
		var h0: int = d.arm_h
		CombatRules.apply_damage(d, dmg)
		t.eq(d.arm_b, b0, "le corps n'est pas entamé")
		t.eq(d.arm_h, h0, "la tête non plus")
		t.eq(d.arm_a if zone == "arms" else d.arm_l, maxi(0, slot_arm - int(dmg["armor"])), "la pièce touchée perd son armure")
	t.check(found.has("arms") and found.has("legs"), "des coups aux bras et aux jambes sont tirés")
	# pièce détruite : le coup passe directement aux PV (même formule que le corps nu)
	var d2: Unit = _wear(_target(), "manchettes", "none")
	d2.arm_a = 0
	for s in 200:
		var dm: Dictionary = CombatRules.roll_damage(a, d2, t.rng_seeded(s))
		if dm["zone"] == "arms":
			t.eq(dm["armor"], 0, "pièce détruite : rien à l'armure")
			t.check(dm["hp"] > 0, "tout va aux PV")
			break


func test_bataille_complete_avec_pieces() -> void:
	# une bataille IA complète où les deux camps portent des pièces : bornes respectées, aucune erreur
	for seed_value in 6:
		var roster: Array = []
		for i in 6:
			var u: Unit = Contracts.make_merc(["milicien", "deserteur", "reitre"][i % 3], t.rng_seeded(seed_value + i), [])
			_wear(u, "manches_mailles" if i % 2 == 0 else "brassards_cuir", "greves_fer" if i % 3 == 0 else "jambieres_cuir")
			roster.append(u)
		var s: BattleState = BattleState.create({"type": "b", "d": 2, "foes": ["brigand", "balafre", "balafre", "chef"], "title": "T", "desc": "", "days": 1, "employer": "x", "pay": 1}, roster, t.rng_seeded(seed_value))
		var turns: int = 0
		while s.over == "" and s.round_no < 120 and turns < 6000:
			var u2: Unit = s.next_turn()
			if u2 == null:
				break
			s.play_ai_turn(u2)
			turns += 1
		t.check(s.over == "win" or s.over == "lose", "la bataille %d se termine" % seed_value)
		for u3 in s.units:
			t.check(u3.arm_a >= 0 and u3.arm_a <= maxi(u3.arms_armor_max(), 0) and u3.arm_l >= 0 and u3.arm_l <= u3.legs_armor_max(), "armures de membres bornées")
		# la sauvegarde de bataille garde les pièces et leur état
		var back: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), t.rng_seeded(1))
		for i in s.units.size():
			t.eq(back.units[i].arms, s.units[i].arms, "bras restaurés")
			t.eq(back.units[i].legs, s.units[i].legs, "jambes restaurées")
			t.eq(back.units[i].arm_a, s.units[i].arm_a, "armure des bras restaurée")
			t.eq(back.units[i].arm_l, s.units[i].arm_l, "armure des jambes restaurée")


# --- Poids ---

func test_poids() -> void:
	var u: Unit = t.mk("epee", "p")
	var w0: int = u.weight()
	var f0: int = u.fat_max_eff()
	var i0: int = u.ini_eff()
	_wear(u, "epaulieres_fer", "greves_fer")
	t.eq(u.weight(), w0 + int(Data.ARMS["epaulieres_fer"]["w"]) + int(Data.LEGS["greves_fer"]["w"]), "le poids s'ajoute (comme tête et corps)")
	t.eq(u.fat_max_eff(), f0 - (u.weight() - w0), "endurance réduite du poids ajouté")
	t.eq(u.ini_eff(), i0 - (u.weight() - w0), "initiative réduite du poids ajouté")
	u.arms = "none"
	u.legs = "none"
	t.eq(u.weight(), w0, "retirées : poids d'origine")
	for k in Data.ARMS:
		t.check(int(Data.ARMS[k]["w"]) >= 0 and int(Data.ARMS[k]["a"]) >= 0 and int(Data.ARMS[k]["price"]) >= 0, "bras %s : valeurs positives" % k)
	for k in Data.LEGS:
		t.check(int(Data.LEGS[k]["w"]) >= 0 and int(Data.LEGS[k]["a"]) >= 0 and int(Data.LEGS[k]["price"]) >= 0, "jambes %s : valeurs positives" % k)


# --- Inventaire ---

func test_equiper_deseequiper() -> void:
	var u: Unit = t.mk("epee", "p")
	var stash: Array = [Loot.item("arms", "manicles_cloutees"), Loot.item("legs", "chausses_mailles"), Loot.item("body", "gambison")]
	var res: Dictionary = Inventory.equip(stash, u, 0)
	t.check(bool(res["ok"]), "équiper des brassards")
	t.eq(u.arms, "manicles_cloutees", "brassards portés")
	t.eq(u.arm_a, int(Data.ARMS["manicles_cloutees"]["a"]), "armure pleine")
	t.eq(stash.size(), 2, "retirés de la réserve")
	t.eq(Inventory.auto_slot(u, stash[0]), "legs", "emplacement automatique : jambes")
	t.check(bool(Inventory.equip(stash, u, 0)["ok"]), "équiper des jambières")
	t.eq(u.legs, "chausses_mailles", "jambières portées")
	t.check(not bool(Inventory.move(stash, Inventory.in_stash(0), Inventory.at(u, "arms"))["ok"]), "un gambison ne va pas aux bras")
	t.check(not Inventory.why_not(Inventory.at(u, "legs"), Loot.item("arms", "manchettes")).is_empty(), "des brassards ne vont pas aux jambes")
	# échange : l'ancienne pièce retourne dans la réserve (son état est conservé)
	u.arm_a = 7
	stash.append(Loot.item("arms", "epaulieres_fer"))
	var idx: int = stash.size() - 1
	t.check(bool(Inventory.equip(stash, u, idx)["ok"]), "échanger les brassards")
	t.eq(u.arms, "epaulieres_fer", "nouvelles pièces")
	t.eq(stash.back()["key"], "manicles_cloutees", "anciennes pièces rangées")
	t.eq(int(stash.back()["arm"]), 7, "usure conservée dans la réserve")
	# déséquiper
	t.check(bool(Inventory.unequip(stash, u, "arms")["ok"]), "déséquiper")
	t.eq(u.arms, "none", "bras nus")
	t.eq(u.arm_a, 0, "plus d'armure de bras")
	t.eq(Inventory.get_item(stash, Inventory.at(u, "arms")), {}, "emplacement vide")
	t.check(not bool(Inventory.unequip(stash, u, "arms")["ok"]), "déjà vide")
	# réserve pleine : l'opération échoue sans rien changer
	var full: Array = []
	for i in 3:
		full.append(Loot.item("head", "casque"))
	var snap_arms: String = u.legs
	var r2: Dictionary = Inventory.unequip(full, u, "legs", 3)
	t.check(not bool(r2["ok"]) and u.legs == snap_arms, "réserve pleine : rien ne bouge")
	# don à un autre homme
	var v: Unit = t.mk("epee", "p")
	t.check(bool(Inventory.give(stash, u, "legs", v)["ok"]), "donner des jambières")
	t.eq(v.legs, "chausses_mailles", "reçues")
	t.eq(u.legs, "none", "perdues")
	t.eq(Inventory.slot_label("arms"), "Bras", "libellé")
	t.eq(Inventory.slot_label("legs"), "Jambes", "libellé")
	# aperçu avant / après
	var w: Unit = t.mk("epee", "p")
	var st: Array = [Loot.item("legs", "greves_genouilleres")]
	var after: Dictionary = Inventory.preview(st, w, Inventory.in_stash(0), Inventory.at(w, "legs"))
	t.eq(int(after["arm_l"]), int(Data.LEGS["greves_genouilleres"]["a"]), "aperçu : armure des jambes")
	t.check(int(after["weight"]) > Inventory.stats(w)["weight"], "aperçu : poids en hausse")
	t.eq(w.legs, "none", "l'aperçu ne touche pas l'homme")
	# filtre « Armures » : corps, bras et jambes
	var mix: Array = [Loot.item("body", "gambison"), Loot.item("arms", "manchettes"), Loot.item("legs", "bandes_toile"), Loot.item("head", "casque"), Loot.item("weapon", "epee")]
	t.eq(Inventory.filtered(mix, "body"), [0, 1, 2], "Armures = corps + bras + jambes")
	t.eq(Market.filtered(mix, "body"), [0, 1, 2], "marché : même filtre")
	t.eq(Inventory.filtered(mix, "head"), [3], "Casques seuls")
	Inventory.sort_stash(mix, "type")
	t.eq(str(mix[0]["kind"]), "weapon", "tri par type : armes d'abord")


func test_infobulle_et_texte() -> void:
	var tip: String = Inventory.tooltip(Loot.item("arms", "manches_mailles"))
	t.check(tip.contains("Armure 62/62") and tip.contains("poids 5"), "infobulle : armure et poids")
	t.check(tip.contains("Maîtrise : Mailles"), "infobulle : famille d'armure")
	t.check(Loot.describe(Loot.item("legs", "greves_fer")).contains("Armure 96"), "description courte")
	t.check(Loot.is_valid(Loot.item("arms", "manchettes")) and not Loot.is_valid(Loot.item("arms", "inconnu")), "validité des clés")
	t.check(not Loot.is_valid(Loot.item("legs", "none")), "« none » n'est pas un objet")


# --- Marché, vente, réparation ---

func test_marche_vente_reparation() -> void:
	var g: Node = t.new_game(4001)
	g.gold = 6000
	g.settlement()["kind"] = "city"
	var stock: Array = Market.generate("city", t.rng_seeded(5))
	var kinds: Dictionary = {}
	for e in stock:
		kinds[str(e["kind"])] = true
	t.check(kinds.has("arms") and kinds.has("legs"), "le marché d'une ville propose bras et jambes")
	var vstock: Array = Market.generate("village", t.rng_seeded(6))
	for e in vstock:
		if str(e["kind"]) == "arms" or str(e["kind"]) == "legs":
			t.check(Loot.is_valid(e), "entrée valide")
			t.check(Data.SHOPS["village"][str(e["kind"])].has(str(e["key"])), "village : seulement ses pièces simples")
	# achat
	var shelf: Array = g.shop_stock()
	shelf.clear()
	shelf.append(Loot.item("arms", "manicles_cloutees"))
	shelf.append(Loot.item("legs", "greves_fer"))
	var gold: int = g.gold
	t.check(g.buy_item(0), "achat de brassards")
	t.check(g.gold < gold, "or débité")
	t.eq(str(g.inventory.back()["kind"]), "arms", "dans la réserve")
	# équipement via Game, puis vente d'une pièce abîmée
	var m: Unit = g.roster[0]
	t.check(g.equip_from_inventory(m, g.inventory.size() - 1), "équipée par Game")
	t.eq(m.arms, "manicles_cloutees", "portée")
	t.check(bool(g.inv_unequip(m, "arms")["ok"]), "rangée")
	var it: Dictionary = g.inventory.back()
	var price_new: int = g.sell_price(it)
	Loot.with_armor(it, 5)
	t.check(g.sell_price(it) < price_new, "pièce abîmée : revente moindre")
	t.check(g.sell_item(g.inventory.size() - 1), "vente")
	t.check(not g.inventory.has(it), "vendue")
	# réparation globale et par pièce
	_wear(m, "epaulieres_fer", "greves_fer")
	m.arm_a = 10
	m.arm_l = 20
	var cost: int = g.repair_cost()
	var before: int = g.gold
	var c_one: int = g.repair_piece_cost(m, "arms", 1.0)
	t.eq(c_one, int(ceil(float(int(Data.ARMS["epaulieres_fer"]["a"]) - 10) * Upkeep.ARMOR_POINT_PRICE * float(g.smith()["price"]) * g.upkeep_mult())), "coût par pièce : 0,5 couronne le point")
	t.check(g.repair_piece(m, "arms", 1.0), "réparer les bras")
	t.eq(m.arm_a, m.arms_armor_max(), "bras réparés")
	t.eq(m.arm_l, 20, "jambes intactes")
	t.check(g.gold == before - c_one, "or débité")
	var cost2: int = g.repair_cost()
	t.check(cost2 < cost and cost2 > 0, "le coût global inclut encore les jambes")
	g.repair()
	t.eq(m.arm_l, m.legs_armor_max(), "réparation globale : jambes remplies")
	t.eq(g.repair_cost(), 0, "plus rien à payer")
	# grade : réparer à fond atteint le maximum du grade
	m.legs_q = 2
	m.arm_l = 1
	g.repair()
	t.eq(m.arm_l, m.legs_armor_max(), "jambières maîtresses réparées")
	t.check(m.legs_armor_max() > int(Data.LEGS["greves_fer"]["a"]), "le grade augmente le maximum")
	# village : pas de mailles
	m.arms = "manches_mailles"
	m.arm_a = 5
	g.settlement()["kind"] = "village"
	t.check(not g.repair_piece(m, "arms", 1.0), "village : mailles refusées")
	t.check(g.shop_error.contains("mailles"), "message en français")
	g.free()


# --- Familles et maîtrises ---

func test_familles() -> void:
	t.eq(Perks.uncovered_gear(), [] as Array[String], "aucune pièce sans famille")
	for k in Data.ARMS:
		t.check(Perks.armor_family("arms", str(k)) != "", "bras %s : une famille" % k)
		t.check(k == "none" or Materials.of("arms", str(k)) != "nu", "bras %s : un matériau" % k)
	for k in Data.LEGS:
		t.check(Perks.armor_family("legs", str(k)) != "", "jambes %s : une famille" % k)
		t.check(k == "none" or Materials.of("legs", str(k)) != "nu", "jambes %s : un matériau" % k)
	t.eq(Perks.armor_family("arms", "inconnu"), "", "clé inconnue : aucune famille (le test de cohérence échouerait)")
	t.eq(Perks.armor_family("arms", "manches_mailles"), "mailles", "manches de mailles")
	t.eq(Perks.armor_family("legs", "greves_fer"), "plates", "grèves de fer")
	t.eq(Materials.of("legs", "greves_fer"), "plates", "matériau des grèves")
	t.eq(Materials.of("arms", "none"), "nu", "bras nus")
	for k in Data.ARMS:
		if k != "none":
			t.check(int(Data.ARMS[k]["a"]) > 0 and int(Data.ARMS[k]["price"]) > 0, "bras %s : armure et prix" % k)
	t.check(Data.ARMS.size() - 1 >= 4 and Data.LEGS.size() - 1 >= 4, "au moins 4 pièces par emplacement")
	# « effets seulement avec l'équipement RÉEL de la famille »
	var u: Unit = t.mk("epee", "p")
	u.head = "capuchon"
	u.body = "tunique"
	t.check(Perks.family_active(u, "tissu"), "tête et corps légers, rien d'autre : tissu léger (comme avant)")
	_wear(u, "manchettes", "bandes_toile")
	t.check(Perks.family_active(u, "tissu"), "pièces de toile : toujours tissu léger")
	_wear(u, "none", "greves_fer")
	t.check(not Perks.family_active(u, "tissu"), "des grèves de fer cassent le tissu léger")
	t.check(Perks.family_active(u, "plates"), "des grèves de fer comptent pour les plates (règle « un seul emplacement »)")
	t.check(not Perks.family_active(u, "mailles"), "pas de mailles")
	var v: Unit = t.mk("epee", "p")
	v.head = "none"
	v.body = "tunique"
	t.check(not Perks.family_active(v, "mailles"), "rien en mailles")
	_wear(v, "manches_mailles", "none")
	t.check(Perks.family_active(v, "mailles"), "manches de mailles : famille des mailles")
	# les effets suivent : maîtrise des mailles
	var base: float = Perks.mfx(v, "weight_cut")
	v.perks.assign(["ma_mailles"])
	t.check(Perks.family_active(v, "mailles") and v.has_perk("ma_mailles"), "maîtrise des mailles active avec la pièce réelle")
	v.arms = "none"
	v.arm_a = 0
	t.check(not Perks.family_active(v, "mailles"), "retirée : l'effet s'arrête")
	t.check(Perks.mfx(v, "weight_cut") <= base + 0.0001, "plus d'effet de maîtrise sans la pièce")
	t.check(Perks.mastery_line(null, "arms", "manches_mailles").contains("Mailles"), "ligne de maîtrise d'un brassard")
	t.check(Perks.family_members("plates").contains("Épaulières de fer"), "membres de la famille listés")


# --- Grades ---

func test_grades() -> void:
	var fine: Dictionary = ItemGrade.with_grade(Loot.item("arms", "brassards_cuir"), 1)
	t.eq(int(fine["q"]), 1, "grade fin porté par l'objet")
	t.check(Loot.armor_max(fine) > int(Data.ARMS["brassards_cuir"]["a"]), "armure maximale en hausse")
	t.check(Loot.base_price(fine) > int(Data.ARMS["brassards_cuir"]["price"]), "prix en hausse")
	t.eq(Loot.item_name(fine), "Brassards de cuir fins", "accord au pluriel masculin")
	t.eq(Loot.item_name(ItemGrade.with_grade(Loot.item("legs", "greves_fer"), -1)), "Grèves de fer grossières", "accord au pluriel féminin")
	t.eq(Loot.item_name(ItemGrade.with_grade(Loot.item("legs", "greves_fer"), 2)), "Grèves de fer de maître", "maîtresse")
	t.check(ItemGrade.describe(fine).contains("armure +8 %"), "description du grade")
	t.check(not ItemGrade.with_grade(Loot.item("arms", "none"), 1).has("q"), "pas de grade sur « none »")
	var s: Array = [fine]
	var u: Unit = t.mk("epee", "p")
	Inventory.equip(s, u, 0)
	t.eq(u.arms_q, 1, "le grade passe à l'homme")
	t.eq(u.arm_a, u.arms_armor_max(), "armure pleine au maximum du grade")
	Inventory.unequip(s, u, "arms")
	t.eq(int(s[0]["q"]), 1, "le grade revient dans la réserve")
	t.eq(u.arms_q, 0, "remis à zéro")
	for i in 30:
		var it: Dictionary = ItemGrade.roll_item(Loot.item("legs", "chausses_mailles"), t.rng_seeded(i))
		t.check(ItemGrade.of(it) >= -1 and ItemGrade.of(it) <= 2, "grade tiré borné")
	# stock de marché : l'armure d'une pièce de grade ≠ correcte suit le ratio d'usure
	var stock: Array = [Loot.item("arms", "garde_bras_plaques")]
	Market.grade_stock(stock, t.rng_seeded(3), 1.0)
	t.check(Loot.armor_of(stock[0]) <= Loot.armor_max(stock[0]), "armure bornée par le maximum du grade")


# --- Sauvegarde ---

func test_sauvegarde() -> void:
	var u: Unit = t.mk("epee", "p")
	_wear(u, "garde_bras_plaques", "jambieres_cuir")
	u.arms_q = 2
	u.arm_a = 33
	u.arm_l = 12
	var d: Dictionary = u.to_dict()
	t.eq(d["arms"], "garde_bras_plaques", "clé bras écrite")
	t.eq(int(d["arm_l"]), 12, "armure des jambes écrite")
	t.check(not d.has("legs_q"), "grade correct : pas de clé")
	var back: Unit = Unit.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq(back.arms, "garde_bras_plaques", "bras relus")
	t.eq(back.legs, "jambieres_cuir", "jambes relues")
	t.eq(back.arms_q, 2, "grade relu")
	t.eq(back.arm_a, 33, "armure relue")
	t.eq(back.arm_l, 12, "armure relue (jambes)")
	t.eq(back.weight(), u.weight(), "poids identique après relecture")
	var dup: Unit = u.duplicate_unit()
	t.eq(dup.arm_a, 33, "copie profonde (envoi au combat)")
	# ancienne sauvegarde : aucune clé
	var old: Dictionary = t.mk("epee", "p").to_dict()
	var o: Unit = Unit.from_dict(old)
	t.eq(o.arms, "none", "ancienne sauvegarde : bras nus")
	t.eq(o.legs, "none", "ancienne sauvegarde : jambes nues")
	t.eq(o.arm_a, 0, "armure nulle")
	# valeurs absurdes : ramenées dans les bornes
	var bad: Dictionary = t.mk("epee", "p").to_dict()
	bad["arms"] = "pièce_inexistante"
	bad["legs"] = "greves_fer"
	bad["arm_l"] = 99999
	bad["legs_q"] = 77
	var b2: Unit = Unit.from_dict(bad)
	t.eq(b2.arms, "none", "clé inconnue -> pas de pièce")
	t.check(b2.arm_l <= b2.legs_armor_max() and b2.legs_q <= 2, "armure et grade bornés")
	# partie complète : la réserve garde les nouveaux objets
	var g: Node = t.new_game(4002)
	g.inventory.append(ItemGrade.with_grade(Loot.item("arms", "brassards_orques"), 1))
	g.inventory.append(Loot.item("legs", "inconnue"))  # invalide : écartée à la relecture
	_wear(g.roster[0], "manicles_cloutees", "greves_fer")
	var g2: Node = load("res://autoload/Game.gd").new()
	g2.autosave = false
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	t.eq(g2.roster[0].arms, "manicles_cloutees", "partie : bras relus")
	t.eq(g2.roster[0].arm_l, g.roster[0].arm_l, "partie : armure des jambes")
	var kept: int = 0
	for it in g2.inventory:
		if str(it["kind"]) == "arms":
			kept += 1
			t.eq(int(it["q"]), 1, "grade de la réserve conservé")
		t.check(Loot.is_valid(it), "réserve : objets valides")
	t.eq(kept, 1, "objet de bras conservé")
	g.free()
	g2.free()


# --- Ennemis d'élite ---

func test_ennemis_elite() -> void:
	var r: RandomNumberGenerator = t.rng_seeded(11)
	for key in ["chef", "balafre", "orc_chef", "orc_guerrier", "necro"]:
		var f: Unit = Contracts.make_foe(key, r)
		t.check(Limbs.any_worn(f), "%s porte une pièce de membre" % key)
		for s in Limbs.SLOTS:
			if Limbs.worn(f, s):
				t.eq(Limbs.cur(f, s), Limbs.armor_max(f, s), "%s : %s neuve" % [key, s])
				t.check(Perks.armor_family(s, Limbs.key_of(f, s)) != "", "famille")
	for key in ["brigand", "archer", "goule", "orc_jeune", "squelette", "loup"]:
		var f2: Unit = Contracts.make_foe(key, r)
		t.check(not Limbs.any_worn(f2), "%s : aucune pièce (comportement d'avant)" % key)
	# cohérence de faction
	var chef: Unit = Contracts.make_foe("orc_chef", r)
	t.eq(Perks.armor_family("arms", chef.arms), "plates", "chef orc : plates")
	for key in Data.FOE:
		var td: Dictionary = Data.FOE[key]
		for s in Limbs.SLOTS:
			if td.has(s):
				for k in td[s]:
					t.check(Limbs.table(s).has(str(k)) and str(k) != "none", "FOE %s : %s connu" % [key, k])
	# butin : les pièces d'un ennemi mort peuvent être ramassées (aucune n'est jamais invalide)
	var seen_limb: bool = false
	for s in 60:
		var e: Unit = Contracts.make_foe("balafre", t.rng_seeded(s))
		e.dead = true
		e.arm_a = 0 if s % 2 == 0 else e.arm_a
		var loot: Array = Loot.roll_battle([e], t.rng_seeded(s + 1000), 1.0)
		for it in loot:
			t.check(Loot.is_valid(it), "butin valide")
			if str(it["kind"]) == "arms" or str(it["kind"]) == "legs":
				seen_limb = true
	t.check(seen_limb, "des pièces de bras ou de jambes tombent en butin")
	var pieces: Array = Loot.pieces_of(Contracts.make_foe("chef", r))
	var kinds: Array = []
	for p in pieces:
		kinds.append(str(p["item"]["kind"]))
	t.check(kinds.has("arms") and kinds.has("legs"), "pieces_of liste les nouvelles pièces")


# --- Figurine et interface ---

func test_calques_et_barres() -> void:
	for fam in ["tissu", "matelasse", "mailles", "plates"]:
		t.check(Figure.texture("limb_off_" + fam) != null, "calque du bras libre : " + fam)
		t.check(Figure.texture("limb_legs_" + fam) != null, "calque des jambes : " + fam)
		for pose in ["std", "bow", "xbow"]:
			t.check(Figure.texture("limb_arm_%s_%s" % [fam, pose]) != null, "calque du bras armé : %s %s" % [fam, pose])
	for k in Data.ARMS:
		if k != "none":
			t.check(ItemIcons.get_icon("arms", str(k)) != null, "icône bras " + str(k))
	for k in Data.LEGS:
		if k != "none":
			t.check(ItemIcons.get_icon("legs", str(k)) != null, "icône jambes " + str(k))
	var bare: Unit = t.mk("epee", "p")
	bare.id = 901
	var f0 := Figure.new().setup(bare)
	var n0: int = f0.get_child_count()
	var dressed: Unit = t.mk("epee", "p")
	dressed.id = 901
	_wear(dressed, "garde_bras_plaques", "greves_genouilleres")
	var f1 := Figure.new().setup(dressed)
	t.check(f1.get_child_count() > n0, "la figurine gagne des calques de bras et de jambes")
	var shielded: Unit = t.mk("epee", "p")
	shielded.id = 901
	shielded.shield = true
	_wear(shielded, "manchettes", "none")
	var f2 := Figure.new().setup(shielded)
	var plain_sh: Unit = t.mk("epee", "p")
	plain_sh.id = 901
	plain_sh.shield = true
	t.check(f2.get_child_count() > Figure.new().setup(plain_sh).get_child_count(), "bouclier : le bras armé porte quand même son brassard")
	f0.free()
	f1.free()
	f2.free()
	# vue d'unité : la barre fusionnée n'apparaît que pour un homme qui porte une pièce
	t.eq(Limbs.total_max(bare), 0, "pas de barre sans pièce")
	t.eq(Limbs.total_max(dressed), dressed.arms_armor_max() + dressed.legs_armor_max(), "somme des pièces")
