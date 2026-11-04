extends RefCounted
## Arbre de talents : structure, accès, points, migration, entraîneur, effets des nouveaux talents.
var t

const OLD_PERKS: Array[String] = [
	"garde_ferme", "frappe_vive", "pied_sur", "insaisissable", "vif", "oeil_de_lynx", "briseur", "cran",
	"second_souffle", "oeil_sur", "endurant", "montagnard", "coup_de_grace", "esquive", "dur_a_cuire", "bretteur",
]


func _veteran(level: int = 11) -> Unit:
	var u: Unit = t.mk()
	u.level = level
	u.perk_points = Perks.points_for_level(level)
	return u


# --- Structure ---

func test_tree_structure() -> void:
	t.eq(Data.PERKS.size(), 76, "76 talents")
	for k in OLD_PERKS:
		t.check(Data.PERKS.has(k), "talent existant conservé : %s" % k)
	for tier in range(1, Data.PERK_TIERS + 1):
		var row: Array[String] = Perks.in_tier(tier)
		t.eq(row.size(), int(Data.PERK_ROWS[tier - 1]), "rang %d : taille de la rangée" % tier)
		var cols: Dictionary = {}
		for k in row:
			cols[int(Data.PERKS[k]["col"])] = true
		t.eq(cols.size(), row.size(), "rang %d : colonnes distinctes" % tier)
	t.eq(Data.PERK_ROWS, [9, 8, 6, 17, 13, 17, 6], "forme de l'arbre (rang 4 : maîtrises, rang 6 : experts)")
	for k in Data.PERKS:
		var pd: Dictionary = Data.PERKS[k]
		t.check(str(pd["n"]) != "" and str(pd["d"]) != "" and str(pd["icon"]) != "", "%s : nom, description, icône" % k)
		t.check(Data.PERK_FAMILIES.has(pd["fam"]), "%s : famille connue" % k)
		var req: String = str(pd.get("req", ""))
		if req != "":
			t.check(Data.PERKS.has(req) and Perks.tier_of(req) < Perks.tier_of(str(k)), "%s : prérequis plus bas dans l'arbre" % k)


func test_access_rules() -> void:
	var u: Unit = _veteran()
	t.eq(Perks.why_not(u, "bretteur"), "", "rang 1 libre")
	t.check(Perks.why_not(u, "briseur") != "", "rang 2 : il faut 1 talent")
	t.check("1 talent avant" in Perks.why_not(u, "briseur"), "raison lisible")
	t.check("3 talents avant" in Perks.why_not(u, "spec_hache"), "rang 4 : 3 talents")
	t.check(Perks.take(u, "bretteur"), "prend un rang 1")
	t.eq(u.perk_points, 9, "point dépensé")
	t.check(not Perks.take(u, "bretteur"), "pas deux fois le même")
	t.check(not Perks.take(u, "spec_epee"), "rang 3 après 1 talent : non")
	t.check(Perks.take(u, "briseur"), "rang 2 après 1 talent")
	t.check(not Perks.take(u, "spec_epee"), "rang 4 après 2 talents : non")
	t.check(Perks.take(u, "cran"), "rang 3 après 2 talents")
	t.check(Perks.take(u, "spec_epee"), "rang 4 après 3 talents")
	# Prérequis explicite
	var v: Unit = _veteran()
	for k in ["bretteur", "vif", "endurant", "oeil_sur", "pied_sur"]:
		t.check(Perks.take(v, k), "prépare %s" % k)
	t.check(not Perks.take(v, "oeil_de_lynx"), "Œil de lynx exige Tireur d'élite")
	t.check("Tireur d'élite" in Perks.why_not(v, "oeil_de_lynx"), "raison : prérequis nommé")
	t.check(Perks.take(v, "spec_arc"), "Tireur d'élite (rang 3)")
	t.check(Perks.take(v, "second_souffle"), "rang 5 après 6 talents")
	# Sans point
	var w: Unit = _veteran()
	w.perk_points = 0
	t.check(not Perks.take(w, "bretteur"), "aucun point : refus")
	# Tout ou rien
	var z: Unit = _veteran()
	t.check(not Perks.take_all(z, ["bretteur", "spec_hache"]), "séquence invalide refusée")
	t.eq(z.perks.size(), 0, "rien appliqué")
	t.eq(z.perk_points, 10, "aucun point perdu")
	t.check(Perks.take_all(z, ["bretteur", "vif", "endurant", "briseur"]), "séquence valide")
	t.eq([z.perks.size(), z.perk_points], [4, 6], "talents et points")
	# Provisoire : le plan compte pour les rangs suivants
	var p: Unit = _veteran()
	t.eq(Perks.why_not(p, "briseur", ["bretteur"]), "", "le choix provisoire ouvre le rang 2")
	t.check(Perks.why_not(p, "briseur", []) != "", "sans lui, fermé")
	p.perk_points = 1
	t.check(Perks.why_not(p, "vif", ["bretteur"]) != "", "plus de point une fois le plan plein")


func test_max_level_capacity() -> void:
	var u: Unit = _veteran()
	var order: Array[String] = []
	for tier in range(1, 8):
		for k in Perks.in_tier(tier):
			if Perks.can_take(u, k):
				Perks.take(u, k)
	t.eq(u.perks.size(), 10, "10 points = 10 talents au niveau 11")
	t.eq(u.perk_points, 0, "tous dépensés")
	t.eq(Perks.points_for_level(1), 0, "niveau 1 : aucun point")
	t.eq(Perks.points_for_level(11), 10, "niveau 11 : 10 points")


# --- Jeu : niveaux, dépense, entraîneur, sauvegarde ---

func test_level_up_gives_points() -> void:
	var g: Node = t.new_game(31)
	var m: Unit = g.roster[0]
	t.eq(m.perk_points, 0, "départ : aucun point")
	m.xp = 190
	g.level_check(m)
	t.eq([m.level, m.perk_points, m.pending], [4, 3, 3], "niveau 4 : 3 points, 3 promotions d'attributs")
	t.check(g.spend_perks(m, ["bretteur", "vif"]), "dépense 2 points")
	t.eq([m.perks.size(), m.perk_points], [2, 1], "restent")
	t.check(not g.spend_perks(m, ["spec_hache"]), "rang 4 refusé")
	t.check(not g.spend_perks(m, []), "rien à dépenser")
	var rolls: Dictionary = g.roll_promotion()
	t.check(g.apply_promotion(m, rolls, ["hp_max", "resolve", "melee_def"]), "les attributs restent comme avant")
	t.eq(m.perk_points, 1, "la promotion d'attributs ne touche pas aux points de talent")
	g.free()


func test_trainer_reset() -> void:
	var g: Node = t.new_game(32)
	var m: Unit = g.roster[0]
	m.level = 6
	m.perk_points = 5
	g.spend_perks(m, ["bretteur", "vif", "endurant"])
	t.eq(m.perk_points, 2, "reste 2")
	var cost: int = g.perk_reset_cost(m)
	t.eq(cost, Data.PERK_RESET_BASE + Data.PERK_RESET_PER_LEVEL * 6, "coût selon le niveau")
	var cheap: Unit = t.mk()
	cheap.level = 3
	t.check(Perks.reset_cost(cheap) < cost, "coût croissant avec le niveau")
	g.gold = cost - 1
	t.check(not g.reset_perks(m), "pas assez d'or")
	g.gold = cost + 10
	t.check(g.reset_perks(m), "réinitialisation payée")
	t.eq(g.gold, 10, "or déduit")
	t.eq([m.perks.size(), m.perk_points], [0, 5], "points rendus")
	t.check(not g.reset_perks(m), "plus rien à réinitialiser")
	g.spend_perks(m, ["bretteur"])
	g.location = ""
	g.gold = 1000
	t.check(not g.reset_perks(m), "seulement en ville")
	g.free()


func test_save_and_migration() -> void:
	var g: Node = t.new_game(33)
	var m: Unit = g.roster[0]
	m.level = 5
	m.perk_points = 3
	m.perks.append("vif")
	var d: Dictionary = JSON.parse_string(JSON.stringify(m.to_dict()))
	var m2: Unit = Unit.from_dict(d)
	t.eq([m2.perk_points, m2.perks], [3, ["vif"] as Array[String]], "points et talents sauvegardés")
	# Ancienne sauvegarde : pas de perk_points
	var old: Dictionary = m.to_dict()
	old.erase("perk_points")
	var u: Unit = Unit.from_dict(old)
	t.eq(u.perk_points, 3, "niveau 5 (4 niveaux gagnés) - 1 talent pris = 3 points")
	old["level"] = 11
	old["perks"] = ["vif", "cran", "oeil_sur", "bretteur", "endurant", "esquive", "dur_a_cuire", "pied_sur", "briseur", "montagnard"]
	t.eq(Unit.from_dict(old).perk_points, 0, "tous les talents pris : aucun point")
	old["level"] = 1
	old["perks"] = []
	t.eq(Unit.from_dict(old).perk_points, 0, "niveau 1 : aucun point")
	var cp: Unit = m.duplicate_unit()
	t.eq(cp.perk_points, 3, "copie de bataille")
	g.free()


func test_foe_perks() -> void:
	var r: RandomNumberGenerator = t.rng_seeded(3)
	var chef: Unit = Contracts.make_foe("chef", r)
	t.check(chef.has_perk("spec_epee") and chef.has_perk("garde_ferme"), "le chef brigand a des talents fixes")
	t.check(Contracts.make_foe("brigand", r).perks.is_empty(), "les soldats n'en ont pas")
	for k in Data.FOE:
		for p in Data.FOE[k].get("perks", []):
			t.check(Data.PERKS.has(p), "talent d'ennemi connu : %s" % p)
	var rec: Array = Contracts.gen_recruits(r, [], [], 4)
	for x in rec:
		t.check((x["u"] as Unit).perks.is_empty() and (x["u"] as Unit).perk_points == 0, "recrue sans talent")


# --- Effets des talents ajoutés ---

func test_new_stat_perks() -> void:
	var u: Unit = t.mk()
	var fat: int = u.eff("fat_max")
	u.perks.append("souffle_long")
	t.eq(u.eff("fat_max"), fat + 15, "Souffle long : +15 endurance")
	var s: Unit = t.mk()
	s.shield = true
	var md: int = s.eff("melee_def")
	var rd: int = s.eff("ranged_def")
	s.perks.append("spec_bouclier")
	t.eq([s.eff("melee_def"), s.eff("ranged_def")], [md + 5, rd + 10], "Rempart avec bouclier")
	s.shield = false
	t.eq(s.eff("melee_def"), md, "Rempart sans bouclier : rien")


func test_light_and_heavy_gear() -> void:
	var u: Unit = t.mk()
	u.body = "tunique"
	u.head = "none"
	var ini: int = u.eff("initiative")
	var md: int = u.eff("melee_def")
	u.perks.append("legerete")
	t.eq(u.eff("initiative"), ini + 15, "Pas léger : +15 initiative")
	t.eq(u.eff("melee_def"), md + 5, "Pas léger : +5 déf.")
	u.body = "brigandine"
	t.eq(u.eff("initiative"), ini, "équipement lourd : plus de bonus")
	var h: Unit = t.mk()
	h.body = "brigandine"
	h.head = "heaume"
	var w: int = h.weight()
	var mv: int = h.move_fat()
	var fm: int = h.fat_max_eff()
	h.perks.append("armure_lourde")
	t.eq(h.weight(), w - w * 3 / 10, "Port d'armure : poids -30 %")
	t.check(h.move_fat() < mv and h.fat_max_eff() > fm, "moins de fatigue de déplacement, plus d'endurance utile")
	t.check(h.ini_eff() > t.mk().ini_eff() - 100, "initiative recalculée")


func test_weapon_specialisations() -> void:
	# Toucher : épée et lances
	for pair in [["epee", "spec_epee", 10], ["lance", "spec_lance", 10], ["hallebarde", "spec_hast", 8], ["fourche", "spec_hast", 8], ["javelot", "spec_javelot", 10]]:
		var a: Unit = t.mk(pair[0], "p", Vector2i(0, 0))
		var d: Unit = t.mk("hache", "e", Vector2i(2, 0) if pair[0] == "javelot" else Vector2i(1, 0))
		var before: int = CombatRules.hit_chance(a, d, [a, d])
		a.perks.append(pair[1])
		t.eq(CombatRules.hit_chance(a, d, [a, d]), before + int(pair[2]), "%s : +%d au toucher avec %s" % [pair[1], int(pair[2]), pair[0]])
	# Ne s'applique pas à une autre arme
	var other: Unit = t.mk("hache", "p", Vector2i(0, 0))
	var foe: Unit = t.mk("hache", "e", Vector2i(1, 0))
	var b0: int = CombatRules.hit_chance(other, foe, [other, foe])
	other.perks.append("spec_epee")
	t.eq(CombatRules.hit_chance(other, foe, [other, foe]), b0, "Maître d'épée sans épée : rien")
	# Javelots en plus
	var j: Unit = t.mk("javelot")
	t.eq(j.full_ammo(), 3, "3 javelots")
	j.perks.append("spec_javelot")
	t.eq(j.full_ammo(), 5, "Lanceur : 2 javelots de plus")
	j.reset_for_battle()
	t.eq(j.ammo, 5, "munitions de bataille")
	t.eq(t.mk("hache").full_ammo(), -1, "arme sans munitions")
	# Dégâts : Tireur d'élite, Fendeur, Fracasseur (même graine => comparaison directe)
	var tests: Array = [["arc", "spec_arc", "hp"], ["hache", "spec_hache", "armor"], ["masse", "spec_masse", "hp"]]
	for tc in tests:
		var tot_a: int = 0
		var tot_b: int = 0
		for i in 300:
			var x: Unit = t.mk(tc[0])
			var y: Unit = t.mk("hache", "e")
			y.arm_b = 120
			y.arm_h = 120
			var r1: RandomNumberGenerator = t.rng_seeded(i)
			tot_a += int(CombatRules.roll_damage(x, y, r1)[tc[2]])
			x.perks.append(tc[1])
			var r2: RandomNumberGenerator = t.rng_seeded(i)
			tot_b += int(CombatRules.roll_damage(x, y, r2)[tc[2]])
		t.check(tot_b > tot_a, "%s augmente les dégâts « %s » (%d contre %d)" % [tc[1], tc[2], tot_b, tot_a])
	# Tireur d'élite : +10 % exactement sur des dégâts sans armure
	var bow: Unit = t.mk("arc")
	var naked: Unit = t.mk("hache", "e")
	naked.arm_b = 0
	naked.arm_h = 0
	var ra: Dictionary = CombatRules.roll_damage(bow, naked, t.rng_seeded(9))
	bow.perks.append("spec_arc")
	var rb: Dictionary = CombatRules.roll_damage(bow, naked, t.rng_seeded(9))
	t.eq(rb["hp"], roundi(float(ra["hp"]) * 1.1), "Tireur d'élite : +10 %")


func _mini_battle(a: Array, b: Array) -> BattleState:
	var s := BattleState.new()
	s.rng = t.rng_seeded(11)
	for u in a:
		s.units.append(u)
	for u in b:
		s.units.append(u)
	return s


func test_moral_perks() -> void:
	var leader: Unit = t.mk("hache", "p", Vector2i(3, 3))
	var ally: Unit = t.mk("hache", "p", Vector2i(4, 3))
	var far: Unit = t.mk("hache", "p", Vector2i(8, 3))
	var foe: Unit = t.mk("hache", "e", Vector2i(9, 3))
	var units: Array = [leader, ally, far, foe]
	t.eq(Perks.morale_aura(ally, units), 0, "sans Chef-né : rien")
	leader.perks.append("chef_ne")
	t.eq(Perks.morale_aura(ally, units), 10, "allié adjacent : +10")
	t.eq(Perks.morale_aura(far, units), 0, "allié éloigné : rien")
	t.eq(Perks.morale_aura(leader, units), 0, "pas pour soi-même")
	t.eq(Perks.morale_aura(foe, units), 0, "pas pour l'ennemi")
	# Effet statistique sur les tests de moral
	var fails_a: int = 0
	var fails_b: int = 0
	for i in 600:
		var s: BattleState = _mini_battle([t.mk("hache", "p", Vector2i(3, 3)), t.mk("hache", "p", Vector2i(4, 3))], [])
		s.rng = t.rng_seeded(i)
		var x: Unit = s.units[1]
		x.resolve = 50
		s._morale_down(x, 0, "test")
		fails_a += 1 if x.morale < 3 else 0
		var s2: BattleState = _mini_battle([t.mk("hache", "p", Vector2i(3, 3)), t.mk("hache", "p", Vector2i(4, 3))], [])
		s2.units[0].perks.append("chef_ne")
		s2.rng = t.rng_seeded(i)
		var y: Unit = s2.units[1]
		y.resolve = 50
		s2._morale_down(y, 0, "test")
		fails_b += 1 if y.morale < 3 else 0
	t.check(fails_b < fails_a, "l'aura réduit les échecs de moral (%d contre %d)" % [fails_b, fails_a])


func test_intimidation() -> void:
	var fails_a: int = 0
	var fails_b: int = 0
	for i in 400:
		for with_perk in [false, true]:
			var a: Unit = t.mk("hache", "p", Vector2i(3, 3))
			var d: Unit = t.mk("hache", "e", Vector2i(4, 3))
			d.hp_max = 100
			d.hp = 100
			d.resolve = 50
			d.arm_b = 0
			d.arm_h = 0
			a.melee_skill = 200
			if with_perk:
				a.perks.append("intimidant")
			var s: BattleState = _mini_battle([a], [d])
			s.rng = t.rng_seeded(i)
			d.hp = 50  # sous 60 % après le coup
			s.attack(a, d)
			if d.hp > 0 and d.morale < 3:
				if with_perk:
					fails_b += 1
				else:
					fails_a += 1
	t.check(fails_b > fails_a, "Regard glaçant : plus de chutes de moral (%d contre %d)" % [fails_b, fails_a])


# --- Interface ---

func test_perk_screen_builds() -> void:
	var host := Control.new()
	var u: Unit = _veteran(6)
	var g: Node = t.new_game(40)
	g.roster[0].perk_points = 2
	var scr: PerkScreen = PerkScreen.open(host, g.roster[0], g)
	t.check(scr != null and scr.tree != null, "écran créé avec son arbre")
	var tr: PerkTree = scr.tree
	tr._on_click("briseur")
	t.eq(tr.selected_key(), "briseur", "sélection d'un talent")
	t.eq(g.roster[0].perks.size(), 0, "rien d'acquis tant qu'on n'a pas appris")
	tr._on_click("bretteur")
	tr._on_click("bretteur")
	t.eq(g.roster[0].perks, ["bretteur"] as Array[String], "second clic : appris")
	t.eq(g.roster[0].perk_points, 1, "un point dépensé")
	tr._on_click("vif")
	tr.learn("vif")
	tr._on_click("endurant")
	tr.learn("endurant")
	t.eq(g.roster[0].perks.size(), 2, "pas plus de talents que de points")
	t.eq(g.roster[0].perk_points, 0, "points dépensés")
	var row: Control = PerkIcon.row(g.roster[0])
	t.check(row != null and row.get_child_count() == 2, "rangée d'icônes des talents pris")
	t.check(PerkIcon.row(u) == null, "aucune icône sans talent")
	row.free()
	host.free()
	g.free()
