extends RefCounted
## Règles d'équipement : types de dégâts × matériaux, une main / deux mains, boucliers différenciés, munitions (carquois).
var t  # le lanceur (voir tests/suites/README.md)


func _state(a: Unit, d: Unit, seed_value: int = 5) -> BattleState:
	var s := BattleState.new()
	s.rng = t.rng_seeded(seed_value)
	for r in 9:
		for c in 12:
			s.cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	s.units.append(a)
	s.units.append(d)
	return s


func _armored(body: String, weapon: String = "gourdin") -> Unit:
	var d: Unit = t.mk(weapon, "e", Hex.from_col_row(5, 4))
	d.body = body
	d.head = "none"
	d.arm_b = int(Data.BODY[body]["a"])
	d.arm_h = 0
	d.hp_max = 400
	d.hp = 400
	return d


## Dégâts d'armure et de PV moyens de `a` sur `d` (corps seulement : la tête est forcée hors de portée du tirage).
func _avg(a: Unit, d: Unit, n: int = 60) -> Dictionary:
	var arm: float = 0.0
	var hp: float = 0.0
	var k: int = 0
	for s in n:
		var r: RandomNumberGenerator = t.rng_seeded(1000 + s)
		var dmg: Dictionary = CombatRules.roll_damage(a, d, r)
		if bool(dmg["head"]):
			continue
		arm += float(dmg["armor"])
		hp += float(dmg["hp"])
		k += 1
	return {"armor": arm / maxf(1.0, float(k)), "hp": hp / maxf(1.0, float(k))}


# --- Types de dégâts et matériaux ---

func test_matrice_bornee_et_neutre() -> void:
	for mat in MaterialsData.MATRIX:
		for ty in MaterialsData.TYPES:
			t.check(MaterialsData.MATRIX[mat].has(ty), "matrice : %s × %s définie" % [mat, ty])
			var m: Dictionary = Materials.mods(str(mat), ty)
			for k in ["arm", "ign"]:
				t.check(float(m[k]) >= MaterialsData.MULT_MIN and float(m[k]) <= MaterialsData.MULT_MAX, "matrice bornée %s × %s (%s)" % [mat, ty, k])
				t.check(absf(float(MaterialsData.MATRIX[mat][ty][k]) - 1.0) <= 0.2, "matrice : écart modeste %s × %s" % [mat, ty])
	var neutral: Dictionary = Materials.mods("inconnu", "tranchant")
	t.eq(neutral, {"arm": 1.0, "ign": 1.0}, "matériau inconnu : neutre")
	t.eq(Materials.mods("mailles", ""), {"arm": 1.0, "ign": 1.0}, "type vide : neutre")
	t.eq(Materials.mods("mailles", "magique"), {"arm": 1.0, "ign": 1.0}, "type inconnu : neutre")
	t.eq(Materials.mods("tissu", "tranchant"), {"arm": 1.0, "ign": 1.0}, "tissu contre lame : référence du prototype")


func test_materiaux_de_chaque_piece() -> void:
	for k in Data.HEAD:
		var m: String = Materials.of("head", str(k))
		t.check(m == "nu" or MaterialsData.MATRIX.has(m), "casque %s : matériau connu (%s)" % [k, m])
	for k in Data.BODY:
		var m: String = Materials.of("body", str(k))
		t.check(m == "nu" or MaterialsData.MATRIX.has(m), "armure %s : matériau connu (%s)" % [k, m])
	t.eq(Materials.of("body", "mailles"), "mailles", "haubert de mailles")
	t.eq(Materials.of("body", "gambison"), "matelasse", "gambison")
	t.eq(Materials.of("head", "heaume"), "plates", "heaume")
	t.eq(Materials.of("body", "none"), "nu", "rien")
	t.eq(Materials.of("body", "inexistante"), "nu", "clé inconnue : sans effet")


func test_materiau_par_defaut_selon_armure() -> void:
	# Une pièce nouvelle sans « mat » ni entrée de table prend le matériau de sa valeur d'armure.
	t.eq(Materials.of_entry("body", "test_a", {"a": 30}), "tissu", "défaut léger")
	t.eq(Materials.of_entry("body", "test_b", {"a": 70}), "matelasse", "défaut moyen")
	t.eq(Materials.of_entry("body", "test_c", {"a": 120}), "mailles", "défaut lourd")
	t.eq(Materials.of_entry("body", "test_d", {"a": 300}), "plates", "défaut très lourd")
	t.eq(Materials.of_entry("body", "test_e", {"a": 100, "mat": "cuir"}), "cuir", "champ « mat » prioritaire")
	t.eq(Materials.of_entry("body", "test_f", {"a": 100, "mat": "inconnu"}), "mailles", "« mat » inconnu : repli sur l'armure")
	t.eq(Materials.of_entry("body", "mailles", {"a": 1}), "mailles", "table par clé avant la valeur d'armure")


func test_types_des_armes() -> void:
	for k in Data.WPN:
		if Data.WEAPONS_NO_FAMILY.has(k):
			continue
		if int(Data.WPN[k].get("price", 0)) <= 0:
			continue
		t.check(MaterialsData.TYPES.has(DamageTypes.of_weapon(str(k))), "arme %s : type de dégât valide" % k)
	t.eq(DamageTypes.of_weapon("hache"), "tranchant", "hache")
	t.eq(DamageTypes.of_weapon("masse"), "contondant", "masse")
	t.eq(DamageTypes.of_weapon("lance"), "perforant", "lance")
	t.eq(DamageTypes.of_weapon("u_epee_corbeau"), "tranchant", "arme unique : famille de son modèle")
	t.eq(DamageTypes.of_weapon("morsure"), "perforant", "monstre sans famille")
	t.eq(DamageTypes.of_weapon("n_importe_quoi"), "", "arme inconnue : neutre")


func test_effet_du_type_sur_le_materiau() -> void:
	var hache: Unit = t.mk("hache", "p", Hex.from_col_row(4, 4))
	var lance: Unit = t.mk("lance", "p", Hex.from_col_row(4, 4))
	var masse: Unit = t.mk("masse", "p", Hex.from_col_row(4, 4))
	# Haubert de mailles : résiste à la lame, laisse passer la pointe.
	var tr_mail: Dictionary = _avg(hache, _armored("mailles"))
	var tr_tissu: Dictionary = _avg(hache, _armored("tunique"))
	var cible_mail: Unit = _armored("mailles")
	cible_mail.arm_b = 500  # armure énorme : on mesure les dégâts à l'armure sans traversée du surplus
	var cible_tissu: Unit = _armored("tunique")
	cible_tissu.arm_b = 500
	t.check(float(_avg(hache, cible_mail)["armor"]) < float(_avg(hache, cible_tissu)["armor"]) * 0.9, "mailles : la hache abîme moins l'armure que sur du tissu")
	var m40: Unit = _armored("mailles")
	m40.arm_b = 40
	var t40: Unit = _armored("tunique")
	t40.arm_b = 40
	t.check(float(_avg(lance, m40)["hp"]) > float(_avg(lance, t40)["hp"]), "lance contre mailles : plus de PV passent que sur du tissu")
	var pl: Unit = _armored("u_brigandine_roi")
	pl.arm_b = 500
	t.check(float(_avg(lance, pl)["armor"]) < float(_avg(lance, cible_tissu)["armor"]) * 0.97, "plates : la pointe abîme moins l'armure")
	var co_mat: Unit = _armored("gambison")
	co_mat.arm_b = 500
	t.check(float(_avg(masse, co_mat)["armor"]) > float(_avg(masse, cible_tissu)["armor"]) * 1.0, "matelassé : le contondant porte mieux")
	# Sans armure : aucun effet de matériau.
	var nu: Unit = _armored("mailles")
	nu.arm_b = 0
	var nu2: Unit = _armored("tunique")
	nu2.arm_b = 0
	t.eq(_avg(hache, nu), _avg(hache, nu2), "sans armure : le matériau ne compte pas")
	t.check(tr_mail["armor"] != null and tr_tissu["armor"] != null, "moyennes calculées")


func test_indication_d_efficacite() -> void:
	var hache: Unit = t.mk("hache", "p", Hex.from_col_row(4, 4))
	var lance: Unit = t.mk("lance", "p", Hex.from_col_row(4, 4))
	var masse: Unit = t.mk("masse", "p", Hex.from_col_row(4, 4))
	var mail: Unit = _armored("mailles")
	var plates: Unit = _armored("u_brigandine_roi")
	var nu: Unit = _armored("tunique")
	nu.arm_b = 0
	t.eq(DamageTypes.versus(hache, mail)["verdict"], "peu efficace", "hache contre mailles")
	t.eq(DamageTypes.versus(lance, mail)["verdict"], "efficace", "lance contre mailles")
	t.eq(DamageTypes.versus(lance, plates)["verdict"], "peu efficace", "lance contre plates")
	t.eq(DamageTypes.versus(masse, plates)["verdict"], "efficace", "masse contre plates")
	t.eq(DamageTypes.versus(hache, nu)["verdict"], "", "cible sans armure : pas d'indication")
	t.eq(DamageTypes.versus(hache, nu)["type"], "Tranchant", "libellé du type")
	t.check(DamageTypes.hint_line(hache, mail).contains("peu efficace"), "ligne d'infobulle")
	t.check(DamageTypes.strengths_line("tranchant") != "", "ligne de fiche d'arme")
	t.check(Inventory.tooltip(Loot.item("weapon", "hache")).contains("tranchant"), "fiche d'arme : type affiché")
	t.check(Inventory.tooltip(Loot.item("weapon", "hallebarde")).contains("Deux mains"), "fiche d'arme : étiquette deux mains")


# --- Deux mains ---

func test_deux_mains() -> void:
	t.check(Handedness.is_two_handed("hallebarde") and Handedness.is_two_handed("arc"), "étiquette deux mains (h1 faux)")
	t.check(not Handedness.is_two_handed("epee") and not Handedness.is_two_handed("griffes"), "une main / monstre : pas d'étiquette")
	t.eq(Handedness.label("hallebarde"), "Deux mains", "libellé")
	t.check(Handedness.has_bonus("hallebarde") and not Handedness.has_bonus("arc") and not Handedness.has_bonus("epee"), "bonus : mêlée à deux mains seulement")
	var h: Unit = t.mk("hallebarde")
	var base: int = int(Data.WPN["hallebarde"]["fat"])
	t.eq(h.attack_fat(), base + Handedness.FAT_EXTRA, "fatigue d'attaque : surcoût deux mains")
	t.eq(t.mk("epee").attack_fat(), int(Data.WPN["epee"]["fat"]), "une main : fatigue inchangée")
	t.eq(t.mk("arc").attack_fat(), int(Data.WPN["arc"]["fat"]), "arc : fatigue inchangée")
	# Dégâts : même tirage, cible sans armure.
	var d: Unit = _armored("tunique")
	d.arm_b = 0
	var dmg: Dictionary = CombatRules.roll_damage(h, d, t.rng_seeded(7))
	var r: RandomNumberGenerator = t.rng_seeded(7)
	var head: bool = r.randf() < 0.25
	var raw: float = float(r.randi_range(int(Data.WPN["hallebarde"]["min"]), int(Data.WPN["hallebarde"]["max"]))) * (1.5 if head else 1.0)
	t.eq(int(dmg["hp"]), roundi(raw * Handedness.DMG_MULT), "dégâts deux mains : léger bonus")
	var ab_mult: float = Handedness.ability_mult("hallebarde")
	t.check(ab_mult > Handedness.dmg_mult("hallebarde"), "capacités deux mains plus fortes que le coup simple")
	# Une main + bouclier : défense gardée, deux mains : pas de bouclier.
	var e: Unit = t.mk("epee")
	e.shield = true
	t.check(Loot.can_equip(t.mk("epee"), Loot.item("shield")), "une main : bouclier permis")
	t.check(not Loot.can_equip(t.mk("hallebarde"), Loot.item("shield")), "deux mains : pas de bouclier")
	t.eq(e.shield_data()["mdef"], 15, "bouclier d'une main : défense gardée")


# --- Boucliers ---

func test_boucliers_differencies() -> void:
	t.eq(Shields.ORDER.size(), 3, "trois types de boucliers")
	var r: Dictionary = Shields.data("rondache")
	t.eq(r["w"], Data.SHIELD["w"], "rondache : poids = Data.SHIELD")
	t.eq(r["dur"], Data.SHIELD["dur"], "rondache : durabilité = Data.SHIELD")
	t.eq(r["price"], Data.SHIELD["price"], "rondache : prix = Data.SHIELD")
	t.eq(r["n"], Data.SHIELD["n"], "rondache : nom = Data.SHIELD")
	t.eq([r["mdef"], r["rdef"], r["wall"]], [15, 25, 20], "rondache : défenses de référence")
	var ta: Dictionary = Shields.data("targe")
	var pa: Dictionary = Shields.data("pavois")
	t.check(int(ta["w"]) < int(r["w"]) and int(r["w"]) < int(pa["w"]), "poids : targe < rondache < pavois")
	t.check(int(ta["price"]) < int(r["price"]) and int(r["price"]) < int(pa["price"]), "prix croissants")
	t.check(int(ta["dur"]) < int(r["dur"]) and int(r["dur"]) < int(pa["dur"]), "durabilité croissante")
	t.check(int(pa["rdef"]) > int(r["rdef"]) and int(r["rdef"]) > int(ta["rdef"]), "défense à distance : pavois > rondache > targe")
	t.check(int(pa["wall"]) > int(r["wall"]) and int(r["wall"]) > int(ta["wall"]), "mur de boucliers : selon le bouclier")
	t.eq(Shields.normalize("n_importe_quoi"), "rondache", "type inconnu : bouclier rond")
	t.eq(Shields.normalize(""), "rondache", "clé vide (anciens objets) : bouclier rond")
	t.eq(Shields.item_key("rondache"), "", "format historique de l'objet")


func test_boucliers_en_combat() -> void:
	var archer: Unit = t.mk("arc", "p", Hex.from_col_row(0, 4))
	var results: Dictionary = {}
	for kind in Shields.ORDER:
		var d: Unit = t.mk("gourdin", "e", Hex.from_col_row(4, 4))
		d.shield = true
		d.shield_kind = kind
		results[kind] = CombatRules.hit_chance(archer, d, [archer, d])
	t.check(int(results["pavois"]) < int(results["rondache"]) and int(results["rondache"]) < int(results["targe"]), "tirs : le pavois protège le plus (%s)" % str(results))
	var e: Unit = t.mk("hache", "p", Hex.from_col_row(3, 4))
	var melee: Dictionary = {}
	for kind in Shields.ORDER:
		var d2: Unit = t.mk("gourdin", "e", Hex.from_col_row(4, 4))
		d2.shield = true
		d2.shield_kind = kind
		melee[kind] = CombatRules.hit_chance(e, d2, [e, d2])
	t.check(int(melee["pavois"]) <= int(melee["rondache"]) and int(melee["rondache"]) <= int(melee["targe"]), "mêlée : ordre des défenses")
	# Rondache : identique aux anciennes règles (15 en mêlée, 25 à distance, mur 20).
	var d3: Unit = t.mk("gourdin", "e", Hex.from_col_row(3, 4))
	d3.shield = true
	var ref_melee: int = clampi(e.eff("melee_skill") + int(Data.WPN["hache"]["hit"]) - (d3.eff("melee_def") + 15 + int(Data.MDEF[d3.morale])) + int(Data.MSK[e.morale]), 5, 95)
	t.eq(CombatRules.hit_chance(e, d3, [e, d3]), ref_melee, "rondache : mêlée inchangée")
	d3.shield_wall = true
	d3.shield_kind = "pavois"
	var wall_pa: int = CombatRules.hit_chance(e, d3, [e, d3])
	d3.shield_kind = "targe"
	var wall_ta: int = CombatRules.hit_chance(e, d3, [e, d3])
	t.check(wall_pa < wall_ta, "mur de boucliers : le pavois protège plus que la targe")
	# Poids et durabilité.
	var u: Unit = t.mk("epee")
	u.shield = true
	u.shield_kind = "rondache"
	var w0: int = u.weight()
	u.shield_kind = "pavois"
	t.eq(u.weight() - w0, int(Shields.data("pavois")["w"]) - int(Shields.data("rondache")["w"]), "poids du pavois")
	t.eq(u.shield_dur_max(), int(Shields.data("pavois")["dur"]), "durabilité du pavois")
	u.shield_kind = "targe"
	t.check(u.shield_ok(), "targe utilisable")


func test_boucliers_sauvegarde_et_butin() -> void:
	var u: Unit = t.mk("epee")
	u.shield = true
	u.shield_kind = "pavois"
	var back: Unit = Unit.from_dict(u.to_dict())
	t.eq(back.shield_kind, "pavois", "type de bouclier sauvegardé")
	var old: Dictionary = u.to_dict()
	old.erase("shield_kind")
	old.erase("quiver")
	old.erase("ammo_kind")
	var o: Unit = Unit.from_dict(old)
	t.eq(o.shield_kind, "rondache", "ancienne sauvegarde : bouclier rond")
	var bad: Dictionary = u.to_dict()
	bad["shield_kind"] = "zzz"
	t.eq(Unit.from_dict(bad).shield_kind, "rondache", "type inconnu : bouclier rond")
	# Butin : le bouclier d'un ennemi est de son type.
	var it: Dictionary = Loot.shield_item(u)
	t.eq(str(it["key"]), "pavois", "objet de butin : clé du type")
	var v: Unit = t.mk("epee")
	var removed: Array = Loot.equip(v, it)
	t.check(removed.is_empty() and v.shield and v.shield_kind == "pavois", "équipé depuis un objet")
	t.eq(Loot.item_name(it), "Pavois", "nom de l'objet")
	t.check(Loot.is_valid(Loot.item("shield", "")) and Loot.is_valid(Loot.item("shield", "targe")), "objets valides (ancien format compris)")
	t.eq(Loot.item_name(Loot.item("shield", "")), str(Data.SHIELD["n"]), "ancien objet : bouclier rond")
	for k in Shields.ORDER:
		t.check(ItemIcons.get_icon("shield", Shields.item_key(k)) != null, "icône du bouclier %s" % k)
	t.check(Loot.describe(Loot.item("shield", "pavois")).contains("40"), "description : défense à distance")


# --- Munitions ---

func test_munitions_donnees() -> void:
	t.check(Ammo.capacity("arc") > 0 and Ammo.capacity("arbalete") > 0, "arc et arbalète ont un carquois")
	t.eq(Ammo.capacity("epee"), 0, "épée : pas de carquois")
	t.eq(Ammo.capacity("javelot"), 0, "javelots : mécanisme propre")
	t.eq(Ammo.capacity("u_arc_ronce"), Ammo.capacity("arc"), "arme unique : carquois de son modèle")
	t.check(Ammo.piece_price("perforante") > Ammo.piece_price("chasse"), "perforantes plus chères")
	for k in Ammo.item_keys():
		t.check(Loot.is_valid(Loot.item("ammo", k)), "lot %s valide" % k)
		t.check(int(Loot.data_of(Loot.item("ammo", k))["price"]) > 0, "lot %s a un prix" % k)
		t.check(ItemIcons.get_icon("ammo", k) != null, "icône du lot %s" % k)
	t.eq(Ammo.normalize_kind("zzz"), "chasse", "type inconnu : chasse")


func test_munitions_defaut_carquois_plein() -> void:
	var u: Unit = t.mk("arc")
	t.eq(u.quiver_now(), Ammo.capacity("arc"), "homme existant : carquois plein")
	u.reset_for_battle()
	t.eq(u.ammo, Ammo.capacity("arc"), "début de bataille : carquois plein")
	var e: Unit = t.mk("arc", "e")
	e.reset_for_battle()
	t.eq(e.ammo, Ammo.ENEMY_AMMO, "ennemi : munitions largement suffisantes")
	var ancient: Dictionary = u.to_dict()
	ancient.erase("quiver")
	t.eq(Unit.from_dict(ancient).quiver_now(), Ammo.capacity("arc"), "ancienne sauvegarde : plein")


func test_munitions_consommation_et_vide() -> void:
	var a: Unit = t.mk("arc", "p", Hex.from_col_row(2, 4))
	var d: Unit = t.mk("gourdin", "e", Hex.from_col_row(5, 4))
	d.hp_max = 900
	d.hp = 900
	a.reset_for_battle()
	d.reset_for_battle()
	a.ammo = 2
	var s: BattleState = _state(a, d)
	s.queue = [a]
	a.ap = 9
	var before: int = a.ap
	t.check(s.can_attack(a, d), "tir possible avec des munitions")
	s.attack(a, d)
	t.eq(a.ammo, 1, "un tir consomme une flèche")
	a.ap = 9
	a.fat = 0
	s.attack(a, d)
	t.eq(a.ammo, 0, "deuxième flèche")
	a.ap = 9
	a.fat = 0
	t.check(a.out_of_ammo(), "carquois vide")
	t.check(not s.can_attack(a, d), "tir impossible sans munitions")
	var adj: Unit = t.mk("gourdin", "e", Hex.from_col_row(3, 4))
	t.check(not CombatRules.can_attack(a, adj), "même au contact : pas de tir")
	t.check(Ammo.empty_message(a).contains("flèches"), "message clair : %s" % Ammo.empty_message(a))
	t.check(before == 9, "PA de départ")
	# Le carquois de l'homme garde ce qui reste après la bataille.
	a.sync_quiver()
	t.eq(a.quiver, 0, "reste synchronisé dans le carquois")


func test_munitions_perforantes() -> void:
	var a: Unit = t.mk("arc", "p", Hex.from_col_row(2, 4))
	var d: Unit = _armored("mailles")
	d.arm_b = 500
	var chasse: Dictionary = _avg(a, d)
	a.ammo_kind = "perforante"
	var perf: Dictionary = _avg(a, d)
	t.check(float(perf["armor"]) > float(chasse["armor"]), "perforantes : plus de dégâts d'armure (%s / %s)" % [str(perf["armor"]), str(chasse["armor"])])
	t.check(Ammo.describe(a).contains("perforantes"), "description du carquois")


func test_munitions_recharge_et_reserve() -> void:
	var a: Unit = t.mk("arc")
	var b: Unit = t.mk("arbalete")
	var e: Unit = t.mk("epee")
	a.quiver = 4
	b.quiver = 16
	var roster: Array = [a, b, e]
	var plan: Dictionary = Ammo.refill(roster, {})
	t.eq(plan["cost"], (Ammo.capacity("arc") - 4) * Ammo.piece_price("chasse"), "coût de recharge : à la pièce")
	t.eq(plan["pieces"], Ammo.capacity("arc") - 4, "pièces à remettre")
	# La réserve achetée passe avant les couronnes.
	var reserve: Dictionary = {Ammo.item_key("fleche", "chasse"): 10}
	var plan2: Dictionary = Ammo.refill(roster, reserve)
	t.eq(plan2["from_reserve"], 10, "réserve utilisée d'abord")
	t.eq(plan2["cost"], (Ammo.capacity("arc") - 4 - 10) * Ammo.piece_price("chasse"), "coût réduit par la réserve")
	Ammo.refill(roster, reserve, true)
	t.eq(a.quiver, -1, "carquois plein après recharge")
	t.eq(reserve.get("fleche_chasse", 0), 0, "réserve consommée")
	# Changement de munition : les pièces retournent à la réserve.
	var res2: Dictionary = {}
	a.quiver = 10
	t.check(Ammo.set_kind(a, "perforante", res2), "changement de type")
	t.eq(res2.get("fleche_chasse", 0), 10, "pièces restantes rendues à la réserve")
	t.eq(a.quiver_now(), 0, "carquois vidé pour le nouveau type")
	t.check(not Ammo.set_kind(a, "perforante", res2), "même type : rien")


func test_munitions_marche_et_camp() -> void:
	var g: Node = t.new_game(77)
	t.check(g.in_settlement(), "départ en ville")
	var stock: Array = g.shop_stock()
	# Une entrée de munitions est vendue en ville.
	var found: bool = false
	for e in stock:
		if Market.is_ammo(e):
			found = true
	if not found:
		stock.append({"kind": "ammo", "key": "fleche_chasse", "qty": 2})
	var idx: int = -1
	for i in stock.size():
		if Market.is_ammo(stock[i]) and str(stock[i]["key"]) == "fleche_chasse":
			idx = i
	if idx < 0:
		stock.append({"kind": "ammo", "key": "fleche_chasse", "qty": 2})
		idx = stock.size() - 1
	g.gold = 1000
	var gold0: int = g.gold
	var inv0: int = g.inventory.size()
	t.check(g.buy_item(idx), "achat d'un lot de munitions : %s" % g.shop_error)
	t.check(g.gold < gold0, "or débité")
	t.eq(g.inventory.size(), inv0, "le lot ne va pas dans l'inventaire")
	t.eq(Ammo.reserve_of(g.extras).get("fleche_chasse", 0), Ammo.LOT, "réserve de munitions remplie")
	# Un archer à moitié vide : « Réparer » remplit le carquois en puisant dans la réserve.
	var m: Unit = g.roster[0]
	m.weapon = "arc"
	m.quiver = Ammo.capacity("arc") - 5
	var cost: int = g.quiver_cost()
	t.eq(cost, 0, "5 pièces manquantes, 12 en réserve : rien à payer")
	g.gold = 1000
	m.arm_b = maxi(0, m.arm_b - 1)  # force un coût de réparation > 0 pour déclencher repair()
	if g.repair_cost() <= 0:
		m.weapon_dur = 1
	g.repair()
	t.eq(m.quiver, -1, "carquois plein après réparation")
	t.eq(Ammo.reserve_of(g.extras).get("fleche_chasse", 0), Ammo.LOT - 5, "réserve entamée de 5")
	# Sauvegarde : la réserve et le carquois survivent.
	var d: Dictionary = g.to_dict()
	var g2: Node = t.new_game(5)
	g2.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq(Ammo.reserve_of(g2.extras).get("fleche_chasse", 0), Ammo.LOT - 5, "réserve sauvegardée")


func test_munitions_ia_ne_se_bloque_pas() -> void:
	# Un tireur du joueur à sec, puis une IA qui joue : le tour se termine toujours.
	var a: Unit = t.mk("arc", "p", Hex.from_col_row(1, 4))
	var d: Unit = t.mk("hache", "e", Hex.from_col_row(8, 4))
	a.reset_for_battle()
	d.reset_for_battle()
	a.ammo = 0
	var s: BattleState = _state(a, d)
	s.queue = [a]
	var memo: Dictionary = {}
	var guard: int = 0
	var ended: bool = false
	while guard < 12:
		guard += 1
		var act: Dictionary = Ai.next_action(s, a, memo)
		if str(act["type"]) == "end":
			ended = true
			break
		s.execute(a, act)
	t.check(ended, "IA sans munitions : le tour s'achève")
	# Un archer ennemi tire bien plus de flèches qu'un carquois du joueur.
	var foe: Unit = t.mk("arc", "e", Hex.from_col_row(5, 4))
	foe.reset_for_battle()
	t.check(foe.ammo >= 50, "archer ennemi : au moins 50 pièces")
	# Duel entier à l'IA : se termine, les munitions du tireur du joueur baissent.
	var p: Unit = t.mk("arc", "p", Hex.from_col_row(1, 4))
	var q: Unit = t.mk("gourdin", "e", Hex.from_col_row(9, 4))
	q.hp_max = 200
	q.hp = 200
	p.reset_for_battle()
	q.reset_for_battle()
	var s2: BattleState = _state(p, q, 11)
	var shots: int = 0
	for turn in 14:
		if not q.is_live():
			break
		p.ap = 9
		p.fat = 0
		var m2: Dictionary = {}
		var g2: int = 0
		while g2 < 8:
			g2 += 1
			var act2: Dictionary = Ai.next_action(s2, p, m2)
			if str(act2["type"]) == "end":
				break
			if str(act2["type"]) == "attack":
				shots += 1
			s2.execute(p, act2)
	t.check(shots > 0 and p.ammo < Ammo.capacity("arc"), "le tireur a tiré et vidé une partie du carquois")
