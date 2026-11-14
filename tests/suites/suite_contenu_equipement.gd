extends RefCounted
## Contenu d'équipement : nouvelles armes par famille, armures au style des factions, armes uniques à histoire (compteur de victimes).
var t  # le lanceur (voir tests/suites/README.md)

const NEW_WEAPONS: Array[String] = ["dague", "epee_courte", "rapiere", "hache_bataille", "marteau_guerre", "baton_ferre", "pique", "fronde", "arbalete_legere", "arc_long"]
const NEW_HEADS: Array[String] = ["cagoule_cuir", "barbute", "heaume_crete", "casque_orque", "casque_rouille"]
const NEW_BODIES: Array[String] = ["cuir_cloute", "haubert_surcot", "cuirasse_peaux", "plastron_orque", "cotte_rouillee"]
const LEGENDS: Array[String] = ["u_dague_veuve", "u_marteau_forgeron", "u_hache_aurore", "u_arc_mirelune", "u_pique_gardien"]
const FOE_STYLES: Dictionary = {  ## pièce -> ennemis qui doivent la porter (cohérence des rôles)
	"cuir_cloute": ["brigand", "archer"], "cagoule_cuir": ["brigand", "archer"], "barbute": ["balafre"], "heaume_crete": ["chef"],
	"haubert_surcot": ["balafre", "chef"], "casque_orque": ["orc_jeune", "orc_guerrier", "orc_chef"], "cuirasse_peaux": ["orc_jeune", "orc_guerrier"],
	"plastron_orque": ["orc_guerrier", "orc_chef"], "casque_rouille": ["squelette", "squelette_archer"], "cotte_rouillee": ["squelette"],
}


# --- Armes ordinaires ---

func test_nouvelles_armes_ont_famille_icone_calque() -> void:
	for k in NEW_WEAPONS:
		t.check(Data.WPN.has(k), "arme %s présente" % k)
		t.check(Perks.weapon_family(k) != "", "%s : une famille" % k)
		t.check(ItemIcons.get_icon("weapon", k) != null, "%s : icône d'objet" % k)
		t.check(ResourceLoader.exists("res://assets/icons/%s.svg" % k), "%s : icône assets/icons" % k)
		for layer in ["weapon_", "arm_", "hand_", "skel_arm_", "skel_hand_"]:
			t.check(Figure.texture(layer + k) != null, "calque %s%s" % [layer, k])
		t.check(AttackAnims.TABLE.has(k), "%s : animation d'attaque" % k)


func test_statistiques_dans_des_bornes_saines() -> void:
	for k in NEW_WEAPONS + LEGENDS:
		var w: Dictionary = Data.WPN[k]
		t.check(int(w["min"]) >= 10 and int(w["max"]) <= 80 and int(w["min"]) <= int(w["max"]), "%s : dégâts" % k)
		t.check(float(w["arm"]) >= 0.3 and float(w["arm"]) <= 1.7, "%s : efficacité contre l'armure" % k)
		t.check(float(w["ign"]) >= 0.05 and float(w["ign"]) <= 0.55, "%s : traversée" % k)
		t.check(int(w["ap"]) >= 3 and int(w["ap"]) <= 7, "%s : PA" % k)
		t.check(int(w["fat"]) >= 4 and int(w["fat"]) <= 18, "%s : fatigue" % k)
		t.check(int(w["hit"]) >= -10 and int(w["hit"]) <= 30, "%s : toucher" % k)
		t.check(int(w["rng"]) >= 1 and int(w["rng"]) <= 7, "%s : portée" % k)
		t.check(int(w["price"]) >= 50 and int(w["price"]) <= 2500, "%s : prix" % k)
		t.check(str(w["note"]) != "", "%s : note en français" % k)
		t.check(bool(w["ranged"]) == (int(w["rng"]) >= 4), "%s : tir <=> portée >= 4" % k)
	for k in LEGENDS:
		var base: String = str(Data.UNIQUES[k]["look"])
		t.check(Data.WPN[k]["price"] > Data.WPN[base]["price"], "%s : plus chère que son modèle %s" % [k, base])


func test_armes_vendues_ou_butin() -> void:
	for k in NEW_WEAPONS:
		var shops: bool = (Data.SHOPS["village"]["weapon"] as Array).has(k) or (Data.SHOPS["city"]["weapon"] as Array).has(k)
		var rare: bool = false
		for d in Loot.RARE:
			for p in Loot.RARE[d]:
				if p[0] == "weapon" and p[1] == k:
					rare = true
		var foes: bool = false
		for f in Data.FOE:
			if (Data.FOE[f]["w"] as Array).has(k):
				foes = true
		t.check(shops or rare or foes, "%s : en vente, en butin rare ou portée par un ennemi" % k)
	var rng: RandomNumberGenerator = t.rng_seeded(11)
	var seen: Dictionary = {}
	for i in 60:
		for e in Market.generate("city", rng):
			seen[str(e["key"])] = true
	for k in ["rapiere", "hache_bataille", "pique", "arc_long", "heaume_crete", "haubert_surcot"]:
		t.check(seen.has(k), "marché de ville : %s en rayon" % k)


func test_abilities_des_nouvelles_armes() -> void:
	var r: Unit = t.mk("rapiere", "p", Vector2i(2, 2))
	var ab: Array = CombatRules.abilities_of(r)
	t.check(ab.has("estoc"), "rapière : Estoc")
	t.check(ab.has("fente"), "rapière hérite de Fente (famille des épées)")
	var m: Unit = t.mk("marteau_guerre", "p", Vector2i(2, 2))
	t.check(CombatRules.abilities_of(m).has("brise_heaume"), "marteau : Brise-heaume")
	t.check(CombatRules.abilities_of(m).has("assommer"), "marteau hérite d'Assommer (masses)")
	var h: Unit = t.mk("hache_bataille", "p", Vector2i(2, 2))
	t.check(CombatRules.abilities_of(h).has("fendre"), "hache de bataille hérite de Fendre l'armure")
	var f: Unit = t.mk("fronde", "p", Vector2i(2, 2))
	t.check(f.is_ranged(), "fronde : arme de tir")
	t.check(not CombatRules.abilities_of(f).has("fleche_feu"), "fronde : pas de flèche enflammée")


func test_nouvelles_armes_se_battent() -> void:
	for k in NEW_WEAPONS + LEGENDS:
		var s := BattleState.new()
		s.rng = t.rng_seeded(5)
		for r in 9:
			for c in 12:
				s.cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
		var a: Unit = t.mk(k, "p", Hex.from_col_row(4, 4))
		var d: Unit = t.mk("gourdin", "e", Hex.from_col_row(5 if int(Data.WPN[k]["rng"]) == 1 else 4 + mini(2, int(Data.WPN[k]["rng"])), 4))
		a.reset_for_battle()
		d.reset_for_battle()
		s.units.append(a)
		s.units.append(d)
		var hp0: int = d.hp
		for i in 12:
			if d.hp < hp0:
				break
			a.ap = 9
			a.fat = 0
			s.attack(a, d)
		t.check(d.hp < hp0 or d.arm_b < 20, "%s : frappe (PV ou armure de la cible entamés)" % k)


# --- Armures de faction ---

func test_armures_ont_famille_icone_calque() -> void:
	for k in NEW_HEADS:
		t.check(Data.HEAD.has(k), "casque %s présent" % k)
		t.check(Perks.armor_family("head", k) != "", "casque %s : une famille" % k)
		t.check(ItemIcons.get_icon("head", k) != null, "casque %s : icône" % k)
		t.check(ResourceLoader.exists("res://assets/icons/%s.svg" % k), "casque %s : icône assets/icons" % k)
		t.check(Figure.texture("helm_" + k) != null, "casque %s : calque" % k)
	for k in NEW_BODIES:
		t.check(Data.BODY.has(k), "armure %s présente" % k)
		t.check(Perks.armor_family("body", k) != "", "armure %s : une famille" % k)
		t.check(ItemIcons.get_icon("body", k) != null, "armure %s : icône" % k)
		t.check(ResourceLoader.exists("res://assets/icons/%s.svg" % k), "armure %s : icône assets/icons" % k)
		t.check(Figure.texture("torso_" + k) != null, "armure %s : calque" % k)
		t.check(Figure.SLEEVES.has(k), "armure %s : couleur de manche" % k)
	t.eq(Perks.uncovered_gear().size(), 0, "aucune pièce d'équipement sans famille")


func test_armures_bornes_et_echelle() -> void:
	for k in NEW_HEADS:
		var d: Dictionary = Data.HEAD[k]
		t.check(int(d["a"]) >= 30 and int(d["a"]) <= 200 and int(d["w"]) >= 0 and int(d["w"]) <= 12 and int(d["price"]) > 0, "casque %s : bornes" % k)
		t.check(float(d["a"]) / float(maxi(1, int(d["price"]))) < 1.2, "casque %s : prix cohérent" % k)
	for k in NEW_BODIES:
		var d: Dictionary = Data.BODY[k]
		t.check(int(d["a"]) >= 40 and int(d["a"]) <= 240 and int(d["w"]) >= 0 and int(d["w"]) <= 24 and int(d["price"]) > 0, "armure %s : bornes" % k)
	# plus lourd = plus protecteur (ordre des armures du jeu conservé)
	t.check(int(Data.BODY["cuir_cloute"]["a"]) > int(Data.BODY["tunique"]["a"]) and int(Data.BODY["cuir_cloute"]["a"]) < int(Data.BODY["mailles"]["a"]), "cuir clouté entre tunique et mailles")
	t.check(int(Data.BODY["plastron_orque"]["a"]) > int(Data.BODY["mailles"]["a"]) and int(Data.BODY["plastron_orque"]["a"]) < int(Data.BODY["brigandine"]["a"]), "plastron orque entre mailles et brigandine")


func test_ennemis_portent_leur_style() -> void:
	for piece in FOE_STYLES:
		for foe in FOE_STYLES[piece]:
			var d: Dictionary = Data.FOE[foe]
			t.check((d["head"] as Array).has(piece) or (d["body"] as Array).has(piece), "%s peut porter %s" % [foe, piece])
	# aucun ennemi d'une autre faction ne porte les pièces propres aux orcs et aux morts-vivants
	for foe in Data.FOE:
		var d: Dictionary = Data.FOE[foe]
		for piece in ["casque_orque", "cuirasse_peaux", "plastron_orque"]:
			if (d["head"] as Array).has(piece) or (d["body"] as Array).has(piece):
				t.eq(str(d["fac"]), "o", "%s (%s) : pièce orque réservée aux orcs" % [foe, piece])
		for piece in ["casque_rouille", "cotte_rouillee"]:
			if (d["head"] as Array).has(piece) or (d["body"] as Array).has(piece):
				t.eq(str(d["fac"]), "u", "%s (%s) : pièce de revenant réservée aux morts-vivants" % [foe, piece])


func test_ennemis_equipes_se_generent_et_se_dessinent() -> void:
	var rng: RandomNumberGenerator = t.rng_seeded(77)
	var worn: Dictionary = {}
	for foe in Data.FOE:
		for i in 40:
			var u: Unit = Contracts.make_foe(str(foe), rng)
			t.check(Data.WPN.has(u.weapon) and (u.head == "none" or Data.HEAD.has(u.head)) and Data.BODY.has(u.body), "%s : équipement valide" % foe)
			t.check(u.arm_h == u.head_armor_max() and u.arm_b == u.body_armor_max(), "%s : armure pleine" % foe)
			t.check(not (u.shield and not bool(u.weapon_data()["h1"])), "%s : pas de bouclier avec une arme à deux mains" % foe)
			worn[u.head] = true
			worn[u.body] = true
			if i < 4:
				var f: Figure = Figure.new().setup(u)
				t.check(f.get_child_count() > 0, "%s : figurine construite (%s / %s)" % [foe, u.head, u.body])
				f.free()
	for piece in NEW_HEADS + NEW_BODIES:
		t.check(worn.has(piece), "%s est portée par au moins un ennemi généré" % piece)


func test_butin_des_armures_de_faction() -> void:
	var rng: RandomNumberGenerator = t.rng_seeded(5)
	var got: Dictionary = {}
	for i in 200:
		var foes: Array = []
		for key in ["orc_guerrier", "orc_chef", "balafre", "chef", "squelette", "brigand"]:
			var u: Unit = Contracts.make_foe(key, rng)
			u.dead = true
			foes.append(u)
		for it in Loot.roll_battle(foes, rng, 1.0):
			got[str(it["key"])] = true
			t.check(Loot.is_valid(it), "butin valide : %s" % str(it["key"]))
	for piece in ["cuirasse_peaux", "plastron_orque", "casque_orque", "cotte_rouillee", "cuir_cloute", "heaume_crete", "haubert_surcot", "barbute"]:
		t.check(got.has(piece), "%s peut tomber en butin" % piece)


# --- Armes uniques à histoire ---

func test_uniques_a_histoire_donnees() -> void:
	for k in LEGENDS:
		t.check(Data.UNIQUES.has(k) and Data.WPN.has(k), "%s : unique déclarée" % k)
		t.check(str(Data.UNIQUES[k]["story"]).length() > 30, "%s : légende" % k)
		t.check(Perks.weapon_family(k) != "", "%s : famille" % k)
		t.eq(Perks.weapon_family(k), Perks.weapon_family(str(Data.UNIQUES[k]["look"])), "%s : même famille que son modèle" % k)
		t.check(Legends.tracks(k), "%s : compteur de victimes" % k)
		var steps: Array = Legends.steps(k)
		t.check(steps.size() >= 2, "%s : au moins deux paliers" % k)
		var last: int = 0
		for s in steps:
			t.check(int(s["kills"]) > last, "%s : paliers croissants" % k)
			last = int(s["kills"])
			t.check(str(s["t"]) != "" and not (s["wp"] as Dictionary).is_empty(), "%s : palier décrit" % k)
		t.check(ItemIcons.get_icon("weapon", k) != ItemIcons.get_icon("weapon", str(Data.UNIQUES[k]["look"])), "%s : icône propre" % k)
		t.check(Figure.texture("weapon_" + str(Data.UNIQUES[k]["look"])) != null, "%s : calque de son modèle" % k)


func test_uniques_progression_et_bonus() -> void:
	var u: Unit = t.mk("u_hache_aurore", "p", Vector2i(2, 2))
	t.eq(Legends.field(u, "arm"), 1.0, "0 victime : aucun bonus de dégâts d'armure")
	u.weapon_kills = 10
	t.check(is_equal_approx(Legends.field(u, "arm"), 1.10), "10 victimes : armure +10 %")
	t.check(is_equal_approx(Legends.field(u, "dmg"), 1.0), "10 victimes : pas encore de dégâts")
	u.weapon_kills = 30
	t.check(is_equal_approx(Legends.field(u, "dmg"), 1.08), "30 victimes : dégâts +8 %")
	u.weapon_kills = 80
	t.eq(Legends.field(u, "hit"), 5.0, "80 victimes : +5 % au toucher")
	t.check(is_equal_approx(Perks.weapon_field(u, "dmg"), 1.08), "Perks.weapon_field relaie le bonus")
	var plain: Unit = t.mk("hache", "p", Vector2i(2, 2))
	plain.weapon_kills = 99
	t.eq(Legends.field(plain, "hit"), 0.0, "une arme ordinaire ne progresse pas")
	var dag: Unit = t.mk("u_dague_veuve", "p", Vector2i(2, 2))
	dag.weapon_kills = 20
	t.check(is_equal_approx(Legends.field(dag, "ign"), 0.10), "dague à 20 victimes : traversée +10 points")
	t.eq(Legends.reached("u_dague_veuve", 20), 2, "deux paliers à 20 victimes")


func test_uniques_bataille_compte_les_victimes() -> void:
	var s := BattleState.new()
	s.rng = t.rng_seeded(3)
	for r in 9:
		for c in 12:
			s.cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	var a: Unit = t.mk("u_pique_gardien", "p", Hex.from_col_row(4, 4))
	var d: Unit = t.mk("gourdin", "e", Hex.from_col_row(5, 4))
	a.reset_for_battle()
	d.reset_for_battle()
	s.units.append(a)
	s.units.append(d)
	s._kill(d, a)
	t.eq(a.weapon_kills, 1, "une victime de plus au compteur de l'arme")
	t.eq(a.kills, 1, "et à celui de l'homme")


func test_uniques_le_compteur_suit_l_arme() -> void:
	var u: Unit = t.mk("u_dague_veuve", "p", Vector2i(2, 2))
	u.weapon_kills = 12
	var it: Dictionary = Loot.weapon_item(u)
	t.eq(int(it.get("kills", 0)), 12, "l'objet porte le compteur")
	t.eq(Legends.kills_of(Loot.clean(it)), 12, "Loot.clean conserve les victimes")
	t.check(Loot.is_valid(it), "objet valide avec la clé « kills »")
	t.check(not Loot.weapon_item(t.mk("hache", "p", Vector2i(2, 2))).has("kills"), "arme ordinaire : pas de clé")
	# déplacement vers la réserve puis vers un autre homme : le compteur voyage avec l'arme
	var stash: Array = []
	var res: Dictionary = Inventory.move(stash, Inventory.at(u, "weapon"), Inventory.in_stash(-1))
	t.check(bool(res["ok"]), "arme rangée dans la réserve")
	t.eq(int(stash[0].get("kills", 0)), 12, "réserve : compteur conservé")
	t.eq(u.weapon_kills, 0, "l'homme n'a plus de compteur sans l'arme")
	var v: Unit = t.mk("gourdin", "p", Vector2i(3, 2))
	var res2: Dictionary = Inventory.move(stash, Inventory.in_stash(0), Inventory.at(v, "weapon"))
	t.check(bool(res2["ok"]), "arme passée à un autre homme")
	t.eq(v.weapon, "u_dague_veuve", "arme équipée")
	t.eq(v.weapon_kills, 12, "le compteur suit l'arme chez son nouveau porteur")
	t.check(is_equal_approx(Legends.field(v, "hit"), 5.0), "et ses bonus aussi")
	# Loot.equip (équipement direct depuis un objet)
	var w: Unit = t.mk("gourdin", "p", Vector2i(4, 2))
	Loot.equip(w, {"kind": "weapon", "key": "u_dague_veuve", "kills": 25})
	t.eq(w.weapon_kills, 25, "Loot.equip lit les victimes")
	var removed: Array = Loot.equip(w, Loot.item("weapon", "hache"))
	t.eq(int(removed[0].get("kills", 0)), 25, "arme retirée : victimes conservées")
	t.eq(w.weapon_kills, 0, "hache ordinaire : compteur remis à zéro")


func test_uniques_sauvegarde() -> void:
	var u: Unit = t.mk("u_marteau_forgeron", "p", Vector2i(2, 2))
	u.weapon_kills = 27
	var back: Unit = Unit.from_dict(u.to_dict())
	t.eq(back.weapon_kills, 27, "Unit.to_dict/from_dict : compteur conservé")
	var old: Dictionary = u.to_dict()
	old.erase("weapon_kills")
	t.eq(Unit.from_dict(old).weapon_kills, 0, "ancienne sauvegarde : 0 victime")
	var stock: Array = Market.clean([{"kind": "weapon", "key": "u_arc_mirelune", "kills": 7}])
	t.eq(int(stock[0].get("kills", 0)), 7, "Market.clean conserve les victimes")


func test_uniques_infobulle() -> void:
	var it: Dictionary = {"kind": "weapon", "key": "u_pique_gardien", "kills": 12}
	var tip: String = Inventory.tooltip(it)
	t.check(tip.contains("Objet unique"), "légende présente")
	t.check(tip.contains("Victimes de l'arme : 12"), "compteur affiché")
	t.check(tip.contains("Prochain palier à 25"), "prochain palier annoncé")
	t.check(tip.contains("10 victimes"), "palier atteint listé")
	var done: String = Inventory.tooltip({"kind": "weapon", "key": "u_pique_gardien", "kills": 60})
	t.check(done.contains("Légende accomplie"), "légende accomplie")
	t.check(not Inventory.tooltip({"kind": "weapon", "key": "hache"}).contains("Victimes"), "arme ordinaire : rien de plus")


func test_uniques_rare_et_figure() -> void:
	for k in LEGENDS:
		t.check(Uniques.available([]).has(k), "%s : proposable par le marchand rare / les arcs" % k)
		t.check(Uniques.rare_price(k) > 0, "%s : prix de marchand rare" % k)
		var u: Unit = t.mk(k, "p", Vector2i(2, 2))
		var f: Figure = Figure.new().setup(u)
		t.check(f.get_child_count() > 0, "%s : figurine construite" % k)
		f.free()
