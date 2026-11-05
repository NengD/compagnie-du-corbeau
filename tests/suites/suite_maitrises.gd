extends RefCounted
## Maîtrises d'armes et d'armures : familles (Data.WEAPON_FAMILIES / ARMOR_FAMILIES), un test par maîtrise et par talent expert, builds de Data.BUILDS.
## Tout est de la logique pure (aucune scène). `covered` : chaque talent à `family` doit avoir été testé (voir test_zzz_all_covered).
var t
var covered: Dictionary = {}


# --- Outils ---

## Petit plateau d'herbe pour que les poussées et les déplacements aient des cases.
func _bs(a: Array, b: Array) -> BattleState:
	var s := BattleState.new()
	s.rng = t.rng_seeded(5)
	for q in range(-4, 10):
		for r in range(-4, 10):
			s.cells[Vector2i(q, r)] = {"t": "g", "c": 0, "v": 0}
	for u in a:
		s.units.append(u)
	for u in b:
		s.units.append(u)
	return s


func _p(weapon: String, perks: Array, hex: Vector2i = Vector2i(0, 0), side: String = "p") -> Unit:
	var u: Unit = t.mk(weapon, side, hex)
	for k in perks:
		u.perks.append(str(k))
	covered_note(perks)
	return u


func _add(u: Unit, key: String) -> void:
	u.perks.append(key)
	covered[key] = true


func covered_note(perks: Array) -> void:
	for k in perks:
		covered[str(k)] = true


func _foe(hex: Vector2i = Vector2i(1, 0), armor: int = 0) -> Unit:
	var d: Unit = t.mk("hache", "e", hex)
	d.arm_b = armor
	d.arm_h = armor
	d.hp_max = 600
	d.hp = 600
	d.melee_def = 0
	d.ranged_def = 0
	return d


## Total des dégâts [PV, armure] de `n` coups avec des graines identiques.
func _dmg(a: Unit, d: Unit, n: int = 300, ab: Dictionary = {}) -> Array:
	var hp: int = 0
	var ar: int = 0
	for i in n:
		var r: Dictionary = CombatRules.roll_damage(a, d, t.rng_seeded(i), ab)
		hp += int(r["hp"])
		ar += int(r["armor"])
	return [hp, ar]


func _hit(a: Unit, d: Unit) -> int:
	return CombatRules.hit_chance(a, d, [a, d])


# --- Familles et garde-fou ---

func test_families_cover_all_gear() -> void:
	t.eq(Perks.uncovered_gear(), [] as Array[String], "toute arme / armure du joueur a une famille (ajouter la famille d'un nouvel objet !)")
	for w in Data.WEAPONS_NO_FAMILY:
		t.check(Data.WPN.has(w) and Perks.weapon_family(w) == "", "arme de monstre sans famille : %s" % w)
	for w in ["epee", "u_epee_corbeau"]:
		t.eq(Perks.weapon_family(w), "epee", "%s : épées" % w)
	t.eq(Perks.weapon_family("u_hache_fendcrane"), "hache", "unique hache")
	t.eq(Perks.weapon_family("u_masse_glas"), "masse", "unique masse")
	t.eq(Perks.weapon_family("u_lance_aigle"), "lance", "unique lance")
	t.eq(Perks.weapon_family("u_arc_ronce"), "arc", "unique arc")
	t.eq(Perks.weapon_family("fourche"), "hast", "fourche : armes d'hast")
	t.eq(Perks.weapon_family("hallebarde"), "hast", "hallebarde : armes d'hast")
	t.eq(Perks.weapon_base("u_epee_corbeau"), "epee", "base d'une arme unique")
	t.eq(Perks.armor_family("body", "none"), "tissu", "rien = tissu")
	t.eq(Perks.armor_family("head", "none"), "tissu", "tête nue = tissu")
	t.eq(Perks.armor_family("head", "capuchon"), "tissu", "capuchon")
	t.eq(Perks.armor_family("body", "gambison"), "matelasse", "gambison")
	t.eq(Perks.armor_family("body", "u_cotte_nuit"), "mailles", "cotte unique")
	t.eq(Perks.armor_family("head", "u_heaume_veilleur"), "plates", "heaume unique")
	t.eq(Perks.armor_family("body", "u_brigandine_roi"), "plates", "brigandine unique")
	t.eq(Perks.armor_family("head", "u_casque_loup"), "casque", "casque unique")
	for k in Data.WEAPON_FAMILIES:
		for w in Data.WEAPON_FAMILIES[k]["weapons"]:
			t.check(Data.WPN.has(w), "arme de famille connue : %s" % w)
			t.check(not Data.WEAPONS_NO_FAMILY.has(w), "%s : pas une arme de monstre" % w)


func test_masteries_per_family() -> void:
	var weapon_masteries: int = 0
	var armor_masteries: int = 0
	for fam in Data.WEAPON_FAMILIES:
		var fd: Dictionary = Data.WEAPON_FAMILIES[fam]
		var m: String = str(fd["mastery"])
		var e: String = str(fd["expert"])
		t.check(Data.PERKS.has(m) and Data.PERKS.has(e), "%s : maîtrise et expert existent" % fam)
		t.eq(Perks.family_of_perk(m), fam, "%s : la maîtrise porte la famille" % fam)
		t.eq(Perks.family_of_perk(e), fam, "%s : l'expert porte la famille" % fam)
		t.eq(str(Data.PERKS[e]["req"]), m, "%s : l'expert exige la maîtrise" % fam)
		t.eq(Perks.tier_of(m), 4, "%s : maîtrise au rang 4" % fam)
		t.eq(Perks.tier_of(e), 6, "%s : expert au rang 6" % fam)
		weapon_masteries += 1
	for fam in Data.ARMOR_FAMILIES:
		var fd2: Dictionary = Data.ARMOR_FAMILIES[fam]
		t.eq(Perks.family_of_perk(str(fd2["mastery"])), fam, "%s : maîtrise d'armure" % fam)
		t.eq(str(Data.PERKS[str(fd2["expert"])]["req"]), str(fd2["mastery"]), "%s : expert d'armure exige la maîtrise" % fam)
		armor_masteries += 1
	t.check(weapon_masteries >= 12, "au moins 12 maîtrises d'armes (%d)" % weapon_masteries)
	t.check(armor_masteries >= 4, "au moins 4 maîtrises d'armures (%d)" % armor_masteries)
	t.eq(Perks.in_tier(4).size(), weapon_masteries + armor_masteries, "le rang 4 est la rangée des maîtrises")
	var u: Unit = t.mk()
	u.perk_points = 5
	t.check("Il faut d'abord" in Perks.why_not(u, "ex_epee") or "talents avant" in Perks.why_not(u, "ex_epee"), "un expert ne s'ouvre pas sans sa maîtrise")


func test_family_active_follows_gear() -> void:
	var u: Unit = t.mk("epee")
	t.check(Perks.family_active(u, "epee") and not Perks.family_active(u, "hache"), "arme tenue")
	u.weapon = "u_epee_corbeau"
	t.check(Perks.family_active(u, "epee"), "une arme unique compte pour sa famille")
	t.check(not Perks.family_active(u, "bouclier"), "sans bouclier")
	u.shield = true
	t.check(Perks.family_active(u, "bouclier"), "bouclier porté")
	u.shield_dur = 0
	t.check(not Perks.family_active(u, "bouclier"), "bouclier brisé : inactif")
	u.head = "none"
	u.body = "tunique"
	t.check(Perks.family_active(u, "tissu"), "tunique + tête nue = tissu")
	u.head = "casque"
	t.check(not Perks.family_active(u, "tissu") and Perks.family_active(u, "casque"), "casque : plus de tissu")
	u.body = "brigandine"
	t.check(Perks.family_active(u, "plates"), "brigandine : plates")
	u.head = "heaume"
	u.body = "mailles"
	t.check(Perks.family_active(u, "plates") and Perks.family_active(u, "mailles"), "heaume + mailles : les deux")
	u.body = "u_cotte_nuit"
	t.check(Perks.family_active(u, "mailles"), "cotte unique")
	var line: String = Perks.mastery_line(u, "weapon", "epee")
	t.check("Épées" in line and "non apprise" in line, "ligne de maîtrise : non apprise (%s)" % line)
	_add(u, "spec_epee")
	t.check("apprise ✓" in Perks.mastery_line(u, "weapon", "u_epee_corbeau"), "ligne : apprise")
	t.eq(Perks.mastery_line(u, "weapon", "griffes"), "", "pas de ligne pour une arme de monstre")
	t.check(Perks.family_status(u, "spec_epee").begins_with("Actif"), "statut actif")
	u.weapon = "hache"
	t.check(Perks.family_status(u, "spec_epee").begins_with("Inactif"), "statut inactif")
	t.check(Perks.mastery_summary(u).size() >= 1, "résumé de fiche")
	covered_note(["spec_epee"])


# --- Épées ---

func test_epee_mastery() -> void:
	var a: Unit = _p("epee", [])
	var d: Unit = _foe()
	var before: int = _hit(a, d)
	var fente0: int = CombatRules.ability_ap(a, "fente")
	_add(a, "spec_epee")
	t.eq(_hit(a, d), before + 10, "Escrimeur : +10 au toucher")
	t.eq(CombatRules.ability_ap(a, "fente"), fente0 - 1, "Fente : 1 PA de moins")
	t.eq(CombatRules.ability_ap(a, "fente"), a.attack_ap(), "Fente au prix d'une attaque")
	a.weapon = "u_epee_corbeau"
	t.check(CombatRules.abilities_of(a).has("fente"), "l'épée unique hérite de Fente")
	var h: Unit = _p("hache", ["spec_epee"])
	var b2: int = _hit(_p("hache", []), d)
	t.eq(_hit(h, d), b2, "hache en main : la maîtrise de l'épée ne joue pas")
	covered_note(["spec_epee"])


func test_epee_expert_riposte() -> void:
	var ripostes: int = 0
	var misses: int = 0
	for i in 120:
		var atk: Unit = _p("hache", [], Vector2i(0, 0), "e")
		atk.melee_skill = 0
		var duel: Unit = _p("epee", ["spec_epee", "ex_epee"], Vector2i(1, 0))
		duel.melee_skill = 500
		var s: BattleState = _bs([duel], [atk])
		s.rng = t.rng_seeded(i)
		var r: Dictionary = s.attack(atk, duel)
		if not r["hit"]:
			misses += 1
			if (r["extra"] as Array).size() == 1 and (r["extra"][0] as Dictionary)["attacker"] == duel:
				ripostes += 1
			var r2: Dictionary = s.attack(atk, duel)
			t.check(not r2["hit"] and (r2["extra"] as Array).is_empty() or r2["hit"], "une seule riposte par manche")
	t.check(misses > 60 and ripostes == misses, "chaque coup raté déclenche la riposte (%d/%d)" % [ripostes, misses])
	var plain: Unit = _p("epee", [], Vector2i(1, 0))
	var atk2: Unit = _p("hache", [], Vector2i(0, 0), "e")
	atk2.melee_skill = 0
	var s2: BattleState = _bs([plain], [atk2])
	var none_count: int = 0
	for i in 40:
		var r3: Dictionary = s2.attack(atk2, plain)
		none_count += (r3["extra"] as Array).size()
	t.eq(none_count, 0, "sans le talent : pas de riposte")
	var bow: Unit = _p("arc", [], Vector2i(0, 0), "e")
	var rip: Unit = _p("epee", ["ex_epee"], Vector2i(3, 0))
	var s3: BattleState = _bs([rip], [bow])
	bow.ranged_skill = 0
	var r4: Dictionary = s3.attack(bow, rip)
	t.check((r4["extra"] as Array).is_empty(), "pas de riposte contre un tir")


# --- Haches ---

func test_hache_mastery() -> void:
	var a: Unit = _p("hache", [])
	var d: Unit = _foe(Vector2i(1, 0), 120)
	var base: Array = _dmg(a, d)
	_add(a, "spec_hache")
	var with: Array = _dmg(a, d)
	t.check(float(with[1]) > float(base[1]) * 1.1, "Fendeur : dégâts d'armure +15 %% (%d contre %d)" % [with[1], base[1]])
	var s: BattleState = _bs([a], [d])
	d.shield = true
	var res: Dictionary = {"extra": []}
	s._mastery_hit_effects(a, d, res)
	t.eq(d.shield_dur_now(), d.shield_dur_max() - 4, "chaque coup abîme le bouclier de 4 points de plus")
	d.shield = false
	var plain: Unit = _p("epee", ["spec_hache"])
	t.eq(Perks.mfx(plain, "shield_wear"), 0.0, "épée en main : rien")
	covered_note(["spec_hache"])


func test_hache_expert() -> void:
	var a: Unit = _p("hache", ["spec_hache", "ex_hache"])
	var heads_with: int = 0
	var heads_without: int = 0
	var d: Unit = _foe()
	var plain: Unit = _p("hache", [])
	for i in 2000:
		heads_with += 1 if CombatRules.roll_damage(a, d, t.rng_seeded(i))["head"] else 0
		heads_without += 1 if CombatRules.roll_damage(plain, d, t.rng_seeded(i))["head"] else 0
	t.check(heads_with > heads_without + 100, "Boucher : plus de coups à la tête (%d contre %d)" % [heads_with, heads_without])
	t.check(CombatRules.abilities_of(a).has("taille_lourde"), "ouvre Taille en deux")
	a.weapon = "u_hache_fendcrane"
	t.check(CombatRules.abilities_of(a).has("taille_lourde"), "la hache unique l'hérite")
	a.weapon = "epee"
	t.check(not CombatRules.abilities_of(a).has("taille_lourde"), "pas avec une épée")
	a.weapon = "hache"
	var ab: Dictionary = Data.ABILITIES["taille_lourde"]
	var arm_d: Unit = _foe(Vector2i(1, 0), 400)
	t.check(float(_dmg(a, arm_d, 200, ab)[1]) > float(_dmg(a, arm_d, 200)[1]) * 1.9, "Taille en deux : armure ×1,6 et dégâts ×1,25")
	t.eq(CombatRules.ability_ap(a, "taille_lourde"), a.attack_ap() + 2, "coût : attaque + 2 PA")


# --- Masses ---

func test_masse_mastery() -> void:
	var a: Unit = _p("masse", [])
	var d: Unit = _foe(Vector2i(1, 0), 120)
	var base: int = int(_dmg(a, d)[0])
	_add(a, "spec_masse")
	t.check(int(_dmg(a, d)[0]) > base, "Fracasseur : plus de dégâts traversent l'armure")
	var stuns: int = 0
	for i in 400:
		var s: BattleState = _bs([a], [_foe()])
		s.rng = t.rng_seeded(i)
		var tgt: Unit = s.units[1]
		s._mastery_hit_effects(a, tgt, {"extra": []})
		stuns += 1 if tgt.stunned else 0
	t.check(stuns > 15 and stuns < 80, "10 %% d'étourdir (%d/400)" % stuns)
	var fl: Unit = _p("fleau", ["spec_masse"])
	t.eq(Perks.weapon_field(fl, "ign"), 0.0, "le fléau n'est plus une masse")


func test_masse_expert() -> void:
	var a: Unit = _p("masse", ["spec_masse", "ex_masse"])
	var d: Unit = _foe()
	var base: int = int(_dmg(a, d)[0])
	d.stunned = true
	t.check(int(_dmg(a, d)[0]) > int(float(base) * 1.15), "Marteleur : +20 %% contre un étourdi")
	d.stunned = false
	d.morale = 1
	t.check(int(_dmg(a, d)[0]) > int(float(base) * 1.15), "… et contre un brisé")
	d.morale = 3
	t.check(CombatRules.abilities_of(a).has("marteler"), "ouvre Marteler")
	var stunned: bool = false
	for i in 40:
		var tgt: Unit = _foe()
		var s: BattleState = _bs([a], [tgt])
		s.rng = t.rng_seeded(i)
		a.melee_skill = 500
		var r: Dictionary = s.use_ability(a, "marteler", tgt)
		if r["hit"] and tgt.hp > 0:
			stunned = tgt.stunned
			break
	t.check(stunned, "Marteler étourdit à coup sûr")


# --- Fléaux ---

func test_fleau_mastery() -> void:
	var a: Unit = _p("fleau", [])
	var d: Unit = _foe()
	d.shield = true
	var base: int = _hit(a, d)
	_add(a, "spec_fleau")
	t.eq(_hit(a, d), base + 5, "Batteur : le bouclier ne gêne plus (15 - 10 - 10 -> 0)")
	var d2: Unit = _foe(Vector2i(0, 1))
	var s: BattleState = _bs([a], [d, d2])
	a.melee_skill = 500
	var r: Dictionary = s.attack(a, d)
	t.eq((r["extra"] as Array).size(), 1, "un second ennemi adjacent est balayé")
	t.check((r["extra"][0] as Dictionary)["target"] == d2 and (r["extra"][0] as Dictionary)["ability"] == "balayage", "le balayage vise l'autre ennemi")
	var plain: Unit = _p("fleau", [])
	var s2: BattleState = _bs([plain], [_foe(), _foe(Vector2i(0, 1))])
	t.eq((s2.attack(plain, s2.units[1])["extra"] as Array).size(), 0, "sans maîtrise : pas de balayage")


func test_fleau_expert() -> void:
	var a: Unit = _p("fleau", ["spec_fleau", "ex_fleau"])
	t.check(CombatRules.abilities_of(a).has("tourbillon"), "ouvre Moulinet")
	var foes: Array = [_foe(Vector2i(1, 0)), _foe(Vector2i(0, 1)), _foe(Vector2i(-1, 1))]
	var s: BattleState = _bs([a], foes)
	a.melee_skill = 500
	var r: Dictionary = s.use_ability(a, "tourbillon", foes[0])
	t.eq((r["extra"] as Array).size(), 2, "Moulinet frappe tous les autres ennemis adjacents")
	t.eq(CombatRules.ability_ap(a, "briser_bouclier"), a.attack_ap(), "Briser le bouclier : 1 PA de moins")


# --- Gourdins ---

func test_gourdin_mastery() -> void:
	var a: Unit = _p("gourdin", [])
	var fat0: int = a.attack_fat()
	var ap0: int = CombatRules.ability_ap(a, "assommer")
	_add(a, "spec_gourdin")
	t.eq(a.attack_fat(), fat0 - 3, "Assommeur : 3 fatigue de moins")
	t.eq(CombatRules.ability_ap(a, "assommer"), ap0 - 1, "Assommer : 1 PA de moins")
	var stuns: int = 0
	for i in 400:
		var s: BattleState = _bs([a], [_foe()])
		s.rng = t.rng_seeded(i)
		var tgt: Unit = s.units[1]
		s._mastery_hit_effects(a, tgt, {"extra": []})
		stuns += 1 if tgt.stunned else 0
	t.check(stuns > 25 and stuns < 90, "12 %% d'étourdir (%d/400)" % stuns)
	var m: Unit = _p("masse", ["spec_gourdin"])
	t.eq(m.attack_fat(), 12, "masse en main : rien")


func test_gourdin_expert() -> void:
	var a: Unit = _p("gourdin", ["spec_gourdin", "ex_gourdin"])
	var plain: Unit = _p("gourdin", [])
	var d: Unit = _foe()
	t.check(int(_dmg(a, d)[0]) > int(float(_dmg(plain, d)[0]) * 1.05), "Matraqueur : +10 % de dégâts")
	t.check(CombatRules.abilities_of(a).has("matraquer"), "ouvre Matraquer")
	var stunned: bool = false
	for i in 40:
		var tgt: Unit = _foe()
		var s: BattleState = _bs([a], [tgt])
		s.rng = t.rng_seeded(i)
		a.melee_skill = 500
		var r: Dictionary = s.use_ability(a, "matraquer", tgt)
		if r["hit"] and tgt.hp > 0:
			stunned = tgt.stunned
			break
	t.check(stunned, "Matraquer étourdit à coup sûr")
	t.eq(CombatRules.ability_ap(a, "matraquer"), a.attack_ap() + 1, "coût : attaque + 1 PA")


# --- Lances ---

func test_lance_mastery() -> void:
	var a: Unit = _p("lance", [])
	var d: Unit = _foe()
	var b: int = _hit(a, d)
	var recul0: int = CombatRules.ability_ap(a, "recul")
	_add(a, "spec_lance")
	t.eq(_hit(a, d), b + 10, "Lancier : +10 au toucher")
	t.eq(CombatRules.ability_ap(a, "recul"), recul0 - 1, "Recul : 1 PA de moins")
	a.weapon = "hallebarde"
	t.eq(Perks.weapon_field(a, "hit"), 0.0, "la hallebarde n'est plus une lance")


func test_lance_expert_wall() -> void:
	var hits: int = 0
	for i in 30:
		var lancier: Unit = _p("lance", ["spec_lance", "ex_lance"], Vector2i(3, 0))
		lancier.melee_skill = 500
		var walker: Unit = _foe(Vector2i(6, 0))
		var s: BattleState = _bs([lancier], [walker])
		s.rng = t.rng_seeded(i)
		s.step(walker, Vector2i(5, 0))
		t.eq(lancier.wall_round, -1, "pas d'attaque tant qu'il n'est pas au contact")
		s.step(walker, Vector2i(4, 0))  # entre au contact
		t.eq(lancier.wall_round, s.round_no, "a frappé à l'entrée au contact")
		if walker.hp < walker.hp_max:
			hits += 1
		walker.hp = walker.hp_max
		s.step(walker, Vector2i(5, 0))  # s'éloigne puis revient dans la même manche
		s.step(walker, Vector2i(4, 0))
		t.eq(walker.hp, walker.hp_max, "une seule attaque de mur de lances par manche")
	t.check(hits > 20, "le mur de lances touche (%d/30)" % hits)
	var plain: Unit = _p("lance", [], Vector2i(3, 0))
	var w2: Unit = _foe(Vector2i(5, 0))
	var s2: BattleState = _bs([plain], [w2])
	s2.step(w2, Vector2i(4, 0))
	t.eq(plain.wall_round, -1, "sans le talent : aucune attaque")
	var other: Unit = _p("epee", ["ex_lance"], Vector2i(3, 0))
	var w3: Unit = _foe(Vector2i(5, 0))
	var s3: BattleState = _bs([other], [w3])
	s3.step(w3, Vector2i(4, 0))
	t.eq(other.wall_round, -1, "épée en main : le mur de lances ne joue pas")
	# La première attaque repousse l'ennemi touché
	var pushed: bool = false
	for i in 30:
		var l4: Unit = _p("lance", ["ex_lance"], Vector2i(3, 0))
		l4.melee_skill = 500
		var w4: Unit = _foe(Vector2i(5, 0))
		var s4: BattleState = _bs([l4], [w4])
		s4.rng = t.rng_seeded(i)
		s4.step(w4, Vector2i(4, 0))
		if w4.hex.x == 5:
			pushed = true
			break
	t.check(pushed, "l'ennemi touché est repoussé")


# --- Armes d'hast ---

func test_hast_mastery() -> void:
	for w in ["fourche", "hallebarde"]:
		var a: Unit = _p(w, [])
		var d: Unit = _foe(Vector2i(1, 0))
		var d2: Unit = _foe(Vector2i(2, 0))
		var h1: int = _hit(a, d)
		var h2: int = _hit(a, d2)
		var ap0: int = a.attack_ap()
		_add(a, "spec_hast")
		t.eq(_hit(a, d), h1 + 8, "Piquier : +8 au contact (%s)" % w)
		t.eq(_hit(a, d2), h2 + 18, "Piquier : +8 et +10 à deux cases (%s)" % w)
		t.eq(a.attack_ap(), ap0 - 1, "un PA de moins (%s)" % w)
	var h: Unit = _p("hallebarde", ["spec_hast"])
	t.eq(CombatRules.ability_ap(h, "croc"), h.attack_ap(), "Croc : 1 PA de moins")
	var l: Unit = _p("lance", ["spec_hast"])
	t.eq(l.attack_ap(), 4, "lance : pas de réduction")


func test_hast_expert() -> void:
	var a: Unit = _p("hallebarde", ["spec_hast", "ex_hast"])
	var d2: Unit = _foe(Vector2i(2, 0))
	var plain: Unit = _p("hallebarde", ["spec_hast"])
	t.eq(_hit(a, d2), _hit(plain, d2) + 5, "Faucheur : +5 à deux cases")
	t.check(CombatRules.abilities_of(a).has("faucher"), "ouvre Faucher")
	var rooted: bool = false
	for i in 40:
		var tgt: Unit = _foe(Vector2i(2, 0))
		var s: BattleState = _bs([a], [tgt])
		s.rng = t.rng_seeded(i)
		a.melee_skill = 500
		var r: Dictionary = s.use_ability(a, "faucher", tgt)
		if r["hit"] and tgt.hp > 0:
			rooted = tgt.rooted == 1
			break
	t.check(rooted, "Faucher cloue la cible")
	a.weapon = "fourche"
	t.check(CombatRules.abilities_of(a).has("faucher"), "la fourche aussi")
	a.weapon = "lance"
	t.check(not CombatRules.abilities_of(a).has("faucher"), "pas avec une lance")


# --- Arcs ---

func test_arc_mastery() -> void:
	var a: Unit = _p("arc", [], Vector2i(0, 0))
	var d: Unit = _foe(Vector2i(1, 0))
	var close0: int = _hit(a, d)
	var tir0: int = CombatRules.ability_ap(a, "tir_ajuste")
	var naked: Unit = _foe(Vector2i(3, 0))
	var base: int = int(_dmg(a, naked)[0])
	_add(a, "spec_arc")
	t.eq(_hit(a, d), close0 + 10, "Tireur d'élite : aucun malus au contact")
	t.eq(CombatRules.ability_ap(a, "tir_ajuste"), tir0 - 1, "Tir ajusté : 1 PA de moins")
	t.check(float(_dmg(a, naked)[0]) > float(base) * 1.08, "+10 %% de dégâts")
	var cb: Unit = _p("arbalete", ["spec_arc"], Vector2i(0, 0))
	var close_cb: int = _hit(cb, d)
	var plain_cb: Unit = _p("arbalete", [], Vector2i(0, 0))
	t.eq(close_cb, _hit(plain_cb, d), "l'arbalète n'est plus un arc")


func test_arc_expert_oeil_de_lynx() -> void:
	var a: Unit = _p("arc", ["spec_arc"])
	var r0: int = a.weapon_range()
	var far: Unit = _foe(Vector2i(6, 0))
	var h0: int = _hit(a, far)
	_add(a, "oeil_de_lynx")
	t.eq(a.weapon_range(), r0 + 2, "Œil de lynx : portée +2")
	t.eq(_hit(a, far), h0 + 4, "malus de distance réduit (4 cases au-delà de 2)")
	t.check(CombatRules.abilities_of(a).has("tir_precis"), "ouvre Tir précis")
	t.eq(Data.ABILITIES["tir_precis"]["hit"], 20, "+20 % au toucher")
	var heads: int = 0
	var base_heads: int = 0
	for i in 1500:
		heads += 1 if CombatRules.roll_damage(a, far, t.rng_seeded(i), Data.ABILITIES["tir_precis"])["head"] else 0
		base_heads += 1 if CombatRules.roll_damage(a, far, t.rng_seeded(i))["head"] else 0
	t.check(heads > base_heads + 150, "plus de coups à la tête (%d contre %d)" % [heads, base_heads])
	var j: Unit = _p("javelot", ["oeil_de_lynx"])
	j.reset_for_battle()
	t.eq(j.weapon_range(), 4, "javelot : pas de portée en plus")


# --- Arbalètes ---

func test_arbalete_mastery() -> void:
	var a: Unit = _p("arbalete", [])
	var ap0: int = a.attack_ap()
	var fat0: int = a.attack_fat()
	var naked: Unit = _foe(Vector2i(3, 0), 100)
	var base: int = int(_dmg(a, naked)[0])
	_add(a, "spec_arbalete")
	t.eq(a.attack_ap(), ap0 - 2, "Arbalétrier : recharge à 5 PA")
	t.eq(a.attack_fat(), fat0 - 3, "3 fatigue de moins")
	t.check(int(_dmg(a, naked)[0]) > base, "traverse davantage l'armure")
	t.eq(_p("arc", ["spec_arbalete"]).attack_ap(), 4, "arc : pas de réduction")


func test_arbalete_expert() -> void:
	var a: Unit = _p("arbalete", ["spec_arbalete", "ex_arbalete"])
	var plain: Unit = _p("arbalete", ["spec_arbalete"])
	var d: Unit = _foe(Vector2i(3, 0), 120)
	t.eq(_hit(a, d), _hit(plain, d) + 5, "Perce-armure : +5 au toucher")
	t.check(CombatRules.abilities_of(a).has("carreau_perce"), "ouvre Carreau perforant")
	t.check(int(_dmg(a, d, 300, Data.ABILITIES["carreau_perce"])[1]) > int(float(_dmg(a, d)[1]) * 1.2), "armure ×1,3")
	t.check(int(_dmg(a, d, 300, Data.ABILITIES["carreau_perce"])[0]) > int(_dmg(a, d)[0]), "traverse 15 points de plus")
	t.eq(CombatRules.ability_ap(a, "tir_ajuste"), a.attack_ap() + 1, "Tir ajusté : 1 PA de moins")


# --- Javelots ---

func test_javelot_mastery_and_expert() -> void:
	var a: Unit = _p("javelot", [])
	t.eq(a.full_ammo(), 3, "3 javelots")
	_add(a, "spec_javelot")
	t.eq(a.full_ammo(), 5, "Lanceur : 5 javelots")
	var d: Unit = _foe(Vector2i(2, 0))
	var plain: Unit = _p("javelot", [])
	t.eq(_hit(a, d), _hit(plain, d) + 10, "+10 au toucher")
	t.check(float(_dmg(a, d)[0]) > float(_dmg(plain, d)[0]) * 1.08, "+10 %% de dégâts")
	_add(a, "ex_javelot")
	t.eq(a.full_ammo(), 7, "Volée : 7 javelots")
	a.reset_for_battle()
	t.check(CombatRules.abilities_of(a).has("double_lancer"), "ouvre Double lancer")
	var tgt: Unit = _foe(Vector2i(2, 0))
	var s: BattleState = _bs([a], [tgt])
	a.melee_skill = 200
	a.ranged_skill = 200
	var r: Dictionary = s.use_ability(a, "double_lancer", tgt)
	t.eq(a.ammo, 5, "Double lancer : deux javelots dépensés")
	t.eq((r["extra"] as Array).size(), 1, "second jet")
	t.eq(str((r["extra"][0] as Dictionary)["ability"]), "second_jet", "le second jet est tracé")
	var m: Unit = _p("epee", ["spec_javelot"])
	t.eq(m.full_ammo(), -1, "pas de munitions pour une épée")


# --- Mains nues ---

func test_poings_mastery_and_expert() -> void:
	var a: Unit = _p("poings", [])
	var naked: Unit = _foe(Vector2i(1, 0))
	var base: Array = _dmg(a, naked)
	var def0: int = a.eff("melee_def")
	var hit0: int = _hit(a, naked)
	_add(a, "spec_poings")
	var with: Array = _dmg(a, naked)
	t.check(absi(int(with[0]) - 2 * int(base[0])) <= int(base[0]) / 20, "Pugiliste : dégâts doublés (%d contre %d)" % [with[0], base[0]])
	t.eq(a.eff("melee_def"), def0 + 6, "+6 en défense")
	t.eq(a.eff("ranged_def"), 11, "+6 à distance")
	t.eq(_hit(a, naked), hit0 + 5, "+5 au toucher")
	var armored: Unit = _foe(Vector2i(1, 0), 40)
	var plain_f: Unit = _p("poings", [])
	t.check(int(_dmg(a, armored)[0]) > int(_dmg(plain_f, armored)[0]), "traverse davantage l'armure")
	t.check(int(_dmg(a, armored)[1]) >= 3 * int(_dmg(plain_f, armored)[1]), "détruit l'armure bien plus vite")
	var h: Unit = _p("hache", ["spec_poings"])
	t.eq(h.eff("melee_def"), 5, "arme en main : pas de défense de pugiliste")
	var ap0: int = a.attack_ap()
	_add(a, "ex_poings")
	t.eq(a.attack_ap(), ap0 - 1, "Poing d'acier : un PA de moins")
	t.check(CombatRules.abilities_of(a).has("uppercut"), "ouvre Direct au menton")
	var stunned: bool = false
	for i in 40:
		var tgt: Unit = _foe()
		var s: BattleState = _bs([a], [tgt])
		s.rng = t.rng_seeded(i)
		a.melee_skill = 500
		var r: Dictionary = s.use_ability(a, "uppercut", tgt)
		if r["hit"] and tgt.hp > 0:
			stunned = tgt.stunned
			break
	t.check(stunned, "Direct au menton étourdit à coup sûr")


# --- Boucliers ---

func test_bouclier_mastery() -> void:
	var a: Unit = _p("epee", [])
	a.shield = true
	var ap0: int = a.wall_ap()
	var fat0: int = a.wall_fat()
	var def0: int = a.eff("melee_def")
	var bash0: int = CombatRules.ability_ap(a, "coup_bouclier")
	_add(a, "spec_bouclier")
	t.eq(a.wall_ap(), ap0 - 1, "Rempart : mur à 3 PA")
	t.eq(a.wall_fat(), fat0 - 4, "mur : 4 fatigue de moins")
	t.eq(a.eff("melee_def"), def0 + 5, "+5 en défense de mêlée")
	t.eq(CombatRules.ability_ap(a, "coup_bouclier"), bash0 - 1, "coup de bouclier : 3 PA")
	var s: BattleState = _bs([a], [_foe()])
	a.fat = 0
	var ap_before: int = a.ap
	s.raise_shield(a)
	t.eq(ap_before - a.ap, 3, "le mur coûte bien 3 PA")
	a.shield_dur = 0
	t.check(a.wall_ap() == 4, "bouclier brisé : le coût du mur redevient normal")


func test_bouclier_expert() -> void:
	var a: Unit = _p("epee", ["spec_bouclier", "ex_bouclier"])
	a.shield = true
	var s: BattleState = _bs([a], [_foe()])
	a.shield_wall = true
	var wear0: int = a.shield_dur_now()
	s._wear_on_block(s.units[1], a, true)
	t.eq(wear0 - a.shield_dur_now(), 1, "Bastion : le mur n'use plus deux fois plus vite")
	var plain: Unit = _p("epee", ["spec_bouclier"])
	plain.shield = true
	plain.shield_wall = true
	s._wear_on_block(s.units[1], plain, true)
	t.eq(plain.shield_dur_max() - plain.shield_dur_now(), 2, "sans Bastion : double usure")
	var friend: Unit = _p("lance", [], Vector2i(0, 1))
	var foe: Unit = _foe(Vector2i(1, 1))
	var before: int = Perks.def_bonus(friend, [a, friend, foe], false)
	t.eq(before, 5, "Bastion : voisin +5 en défense dans le mur")
	a.shield_wall = false
	t.eq(Perks.def_bonus(friend, [a, friend, foe], false), 0, "sans mur : rien")
	a.shield_wall = true
	# Le coup de bouclier repousse
	var pushed: bool = false
	for i in 60:
		var tgt: Unit = _foe(Vector2i(1, 0))
		var b: BattleState = _bs([a], [tgt])
		b.rng = t.rng_seeded(i)
		a.melee_skill = 500
		a.ap = 9
		var r: Dictionary = b.use_ability(a, "coup_bouclier", tgt)
		if r["hit"] and r.has("pushed"):
			pushed = true
			break
	t.check(pushed, "le coup de bouclier repousse")
	var p2: Unit = _p("epee", ["spec_bouclier"])
	p2.shield = true
	var tg2: Unit = _foe(Vector2i(1, 0))
	var b2: BattleState = _bs([p2], [tg2])
	p2.melee_skill = 500
	var any_push: bool = false
	for i in 40:
		b2.rng = t.rng_seeded(i)
		tg2.hex = Vector2i(1, 0)
		p2.ap = 9
		if b2.use_ability(p2, "coup_bouclier", tg2).has("pushed"):
			any_push = true
	t.check(not any_push, "sans Bastion : pas de poussée")


# --- Armures ---

func test_tissu_mastery_and_expert() -> void:
	var u: Unit = _p("epee", [])
	u.head = "capuchon"
	u.body = "tunique"
	var ini0: int = u.eff("initiative")
	var md0: int = u.eff("melee_def")
	var rd0: int = u.eff("ranged_def")
	_add(u, "ma_tissu")
	t.eq(u.eff("initiative"), ini0 + 12, "Foulée légère : +12 d'initiative")
	t.eq(u.eff("melee_def"), md0 + 4, "+4 en défense de mêlée")
	t.eq(u.eff("ranged_def"), rd0 + 6, "+6 à distance")
	u.head = "casque"
	t.eq(u.eff("initiative"), ini0, "un casque : plus de tissu")
	u.head = "none"
	u.body = "none"
	t.eq(u.eff("initiative"), ini0 + 12, "rien du tout compte comme du tissu")
	u.body = "gambison"
	t.eq(u.eff("initiative"), ini0, "gambison : plus de tissu")
	u.body = "tunique"
	u.head = "capuchon"
	var mv0: int = u.move_fat()
	_add(u, "ex_tissu")
	t.eq(u.eff("initiative"), ini0 + 20, "Feu follet : +8 d'initiative de plus")
	t.eq(u.move_fat(), maxi(1, mv0 - 1), "une fatigue de moins par pas")
	var att: Unit = _foe(Vector2i(0, 0))
	att.melee_skill = 60
	u.hex = Vector2i(1, 0)
	var s: BattleState = _bs([u], [att])
	var norm: int = s.hit_chance(att, u)
	var res: Dictionary = s.attack(att, u, true)
	t.eq(int(res["chance"]), clampi(norm - 25, 5, 95), "attaque d'opportunité : 25 % de chances en moins")
	var res2: Dictionary = s.attack(att, u, false)
	t.eq(int(res2["chance"]), norm, "attaque normale : inchangée")


func test_matelasse_mastery_and_expert() -> void:
	var u: Unit = _p("epee", [])
	u.body = "gambison"
	u.arm_b = 65
	u.head = "none"
	u.arm_h = 0
	var att: Unit = _p("hache", [], Vector2i(1, 0), "e")
	var fat0: int = u.eff("fat_max")
	var att_m: Unit = _p("masse", [], Vector2i(1, 0), "e")
	var hp0: int = int(_dmg(att_m, u)[0])
	_add(u, "ma_matelasse")
	t.eq(u.eff("fat_max"), fat0 + 12, "Bourre épaisse : +12 d'endurance")
	t.eq(Perks.armor_soak(u, false), 12, "12 points d'armure effective")
	t.check(int(_dmg(att_m, u)[0]) < hp0, "moins de PV perdus")
	u.arm_b = 0
	var naked: Unit = _p("epee", [])
	naked.arm_b = 0
	naked.arm_h = 0
	t.eq(int(_dmg(att, u)[0]), int(_dmg(att, naked)[0]), "armure détruite : plus de bonus")
	u.arm_b = 65
	_add(u, "ex_matelasse")
	t.eq(Perks.armor_soak(u, false), 22, "Double bourre : 22 au total")
	t.eq(Injuries._chance(u, 50), 25, "moitié moins de blessures")
	t.eq(Injuries._chance(_p("epee", []), 50), 50, "sans le talent : normal")
	u.body = "tunique"
	t.check(not Perks.family_active(u, "matelasse"), "tunique : la famille s'éteint")


func test_mailles_mastery_and_expert() -> void:
	var u: Unit = _p("epee", [])
	u.body = "mailles"
	u.arm_b = 130
	u.arm_h = 130
	var w0: int = u.weight()
	var edged: Unit = _p("epee", [], Vector2i(1, 0), "e")
	var blunt: Unit = _p("masse", [], Vector2i(1, 0), "e")
	var ea0: int = int(_dmg(edged, u)[1])
	var ba0: int = int(_dmg(blunt, u)[1])
	_add(u, "ma_mailles")
	t.eq(u.weight(), w0 - 3, "Maillons serrés : 3 de poids en moins")
	t.check(int(_dmg(edged, u)[1]) < int(float(ea0) * 0.9), "armure moins entamée par une lame (%d contre %d)" % [int(_dmg(edged, u)[1]), ea0])
	t.eq(int(_dmg(blunt, u)[1]), ba0, "arme contondante : inchangée")
	u.arm_b = 40
	u.arm_h = 40
	var hp_a: int = int(_dmg(edged, u)[0])
	_add(u, "ex_mailles")
	t.eq(u.weight(), w0 - 5, "Cotte maîtresse : 5 de poids en moins au total")
	t.check(int(_dmg(edged, u)[0]) < hp_a, "moins de PV traversants")
	u.body = "gambison"
	t.eq(u.weight(), 6, "gambison : aucune réduction")
	u.body = "u_cotte_nuit"
	t.eq(u.weight(), 12 - 5, "cotte unique : la réduction s'applique")


func test_plates_mastery_and_expert() -> void:
	var u: Unit = _p("epee", [])
	u.body = "brigandine"
	u.head = "heaume"
	var fat0: int = u.fat_max_eff()
	var ini0: int = u.ini_eff()
	var mv0: int = u.move_fat()
	_add(u, "ma_plates")
	t.eq(u.fat_max_eff(), u.eff("fat_max"), "Porteur de plates : le poids ne pèse plus sur l'endurance")
	t.check(u.fat_max_eff() > fat0, "plus d'endurance qu'avant")
	t.check(u.move_fat() < mv0 and u.move_fat() == 2, "déplacement sans surcoût de poids")
	t.eq(u.ini_eff(), ini0 - int(float(u.weight()) * 0.3), "initiative plus lourde (-30 % du poids)")
	u.body = "gambison"
	u.head = "none"
	t.eq(u.fat_max_eff(), u.eff("fat_max") - 6, "gambison : poids normal")
	u.body = "brigandine"
	u.head = "heaume"
	_add(u, "ex_plates")
	t.eq(Perks.armor_soak(u, true), 8, "Forteresse : 8 d'armure effective")
	var a: Unit = _p("epee", [], Vector2i(1, 0), "e")
	var s: BattleState = _bs([u], [a])
	t.eq(s.push_target(a, u), Vector2i(-999, -999), "impossible à repousser")
	var stuns: int = 0
	for i in 400:
		var s2: BattleState = _bs([u], [a])
		s2.rng = t.rng_seeded(i)
		u.stunned = false
		stuns += 1 if s2._try_stun(u) else 0
	t.check(stuns > 190 and stuns < 290, "40 %% de résistance à l'étourdissement (%d/400 étourdis)" % stuns)
	var plain: Unit = _p("epee", [])
	t.check(s._try_stun(plain), "sans le talent : toujours étourdi")


func test_casque_mastery_and_expert() -> void:
	var u: Unit = _p("epee", [])
	u.head = "casque"
	u.arm_h = 90
	var att: Unit = _p("hache", [], Vector2i(1, 0), "e")
	_add(u, "ma_casque")
	t.eq(Perks.armor_soak(u, true), 15, "Tête dure : 15 à la tête")
	t.eq(Perks.armor_soak(u, false), 0, "rien au corps")
	t.eq(Perks.head_shield(u), 0.08, "8 points de moins de chances d'être visé")
	var heads: int = 0
	var plain: Unit = _p("epee", [])
	plain.head = "casque"
	plain.arm_h = 90
	var heads_plain: int = 0
	for i in 2000:
		heads += 1 if CombatRules.roll_damage(att, u, t.rng_seeded(i))["head"] else 0
		heads_plain += 1 if CombatRules.roll_damage(att, plain, t.rng_seeded(i))["head"] else 0
	t.check(heads < heads_plain - 100, "moins de coups à la tête (%d contre %d)" % [heads, heads_plain])
	u.head = "heaume"
	t.eq(Perks.armor_soak(u, true), 0, "heaume : ce n'est pas un casque")
	u.head = "u_casque_loup"
	t.eq(Perks.armor_soak(u, true), 15, "casque unique")
	var r0: int = u.eff("resolve")
	_add(u, "ex_casque")
	t.eq(u.eff("resolve"), r0 + 8, "Heaume vissé : +8 en détermination")
	t.eq(Perks.armor_soak(u, true), 25, "25 à la tête")
	var stuns: int = 0
	var s: BattleState = _bs([u], [att])
	for i in 300:
		s.rng = t.rng_seeded(i)
		u.stunned = false
		stuns += 1 if s._try_stun(u) else 0
	t.check(stuns > 140 and stuns < 220, "résiste à l'étourdissement (%d/300 étourdis)" % stuns)


# --- Rangs, migration, sérialisation ---

func test_old_keys_and_serialization() -> void:
	for k in ["spec_epee", "spec_arc", "spec_hache", "spec_javelot", "spec_masse", "spec_lance", "spec_bouclier", "oeil_de_lynx"]:
		t.check(Data.PERKS.has(k), "clé conservée : %s" % k)
	var u: Unit = _p("epee", ["bretteur", "spec_epee", "ex_epee", "oeil_de_lynx", "spec_lance", "spec_masse"])
	u.perk_points = 3
	var back: Unit = Unit.from_dict(u.to_dict())
	t.eq(back.perks, u.perks, "talents conservés par la sauvegarde")
	t.eq(back.perk_points, 3, "aucun point perdu")
	u.riposte_round = 4
	u.wall_round = 2
	var c: Unit = Unit.from_combat_dict(u.combat_dict())
	t.eq([c.riposte_round, c.wall_round], [4, 2], "états de combat sérialisés")
	var old: Dictionary = u.combat_dict()
	old.erase("riposte_round")
	old.erase("wall_round")
	var o: Unit = Unit.from_combat_dict(old)
	t.eq([o.riposte_round, o.wall_round], [-1, -1], "ancienne sauvegarde : valeurs par défaut")
	var s: BattleState = _bs([u], [_foe()])
	var s2: BattleState = BattleState.from_dict(s.to_dict(), t.rng_seeded(1))
	t.eq(s2.units.size(), 2, "bataille sérialisée avec des talents de maîtrise")


# --- Builds ---

func test_builds_reachable() -> void:
	t.check(Data.BUILDS.size() >= 8, "au moins 8 archétypes (%d)" % Data.BUILDS.size())
	var ids: Dictionary = {}
	var fams: Dictionary = {}
	var doc: String = FileAccess.get_file_as_string("res://docs/builds.md") if FileAccess.file_exists("res://docs/builds.md") else ""
	t.check(doc.length() > 2000, "docs/builds.md présent (relancer tools/gen_builds_doc.gd)")
	for b in Data.BUILDS:
		var bd: Dictionary = b
		var keys: Array = []
		for st in bd["steps"]:
			keys.append(str(st[0]))
			t.check(Data.PERKS.has(str(st[0])) and str(st[1]) != "", "%s : étape valide (%s)" % [bd["id"], st[0]])
		t.eq(keys.size(), 10, "%s : 10 talents (niveau 11)" % bd["id"])
		t.eq(Perks.build_problem(keys, 11), "", "%s : atteignable au niveau 11" % bd["id"])
		t.check(Perks.build_problem(keys, 10) != "", "%s : pas avant le niveau 11" % bd["id"])
		var seen: Dictionary = {}
		for k in keys:
			t.check(not seen.has(k), "%s : %s une seule fois" % [bd["id"], k])
			seen[k] = true
		var wf: String = str(bd["weapon"])
		t.check(keys.has(Perks.mastery_of(wf)), "%s : contient la maîtrise de sa famille" % bd["id"])
		t.check(keys.has(str(Data.WEAPON_FAMILIES[wf]["expert"])), "%s : contient l'expert de sa famille" % bd["id"])
		var af: String = str(bd["armor"])
		t.check(keys.has(Perks.mastery_of(af)), "%s : contient la maîtrise d'armure" % bd["id"])
		var hits: int = 0
		for k in keys:
			var kf: String = Perks.family_of_perk(str(k))
			if kf == wf or kf == af:
				hits += 1
		t.check(hits >= 3, "%s : au moins 3 talents de famille (%d)" % [bd["id"], hits])
		t.check(not ids.has(bd["id"]), "%s : identifiant unique" % bd["id"])
		ids[bd["id"]] = true
		fams[wf] = true
		t.check(doc.find(str(bd["n"])) >= 0, "%s : cité dans docs/builds.md" % bd["id"])
	t.check(fams.size() >= 8, "builds sur au moins 8 familles d'armes différentes (%d)" % fams.size())
	t.check(not Perks.build_problem(["spec_epee"], 11).is_empty(), "build invalide détecté (rang 4 au premier talent)")
	t.check(not Perks.build_problem(["bretteur", "vif", "parade", "ex_epee"], 11).is_empty(), "expert sans maîtrise refusé")


func test_zzz_all_covered() -> void:
	for k in Data.PERKS:
		if str(Data.PERKS[k].get("family", "")) != "":
			t.check(covered.has(k), "talent de maîtrise testé : %s" % k)
