extends RefCounted
## Refonte des talents : 50 talents (rangs 9/8/8/12/5/4/4), icônes, migration, un test de logique pure par nouveau talent, composant PerkTree.
var t

const OLD_28: Array[String] = [
	"bretteur", "oeil_sur", "endurant", "vif", "briseur", "esquive", "souffle_long", "pied_sur", "spec_epee", "spec_arc", "garde_ferme", "cran",
	"spec_hache", "spec_javelot", "dur_a_cuire", "legerete", "spec_masse", "oeil_de_lynx", "second_souffle", "intimidant",
	"spec_lance", "coup_de_grace", "spec_bouclier", "montagnard", "frappe_vive", "insaisissable", "armure_lourde", "chef_ne",
]
const NEW_22: Array[String] = [
	"parade", "tete_froide", "marchandeur", "studieux", "infirmier", "lame_affutee", "camaraderie", "gardien", "cicatrisation",
	"archer_pose", "predateur", "voix_claire", "pilleur", "elan", "duelliste", "mur_vivant", "nuque_protegee", "armurier", "force_brute",
	"croc_en_jambe", "eclaireur", "increvable",
]
## Talents sans effet nommé ni attribut : lus par leur identifiant dans Unit / CombatRules / Pathfinding / BattleState.
const BY_ID: Array[String] = [
	"endurant", "briseur", "pied_sur", "oeil_de_lynx", "dur_a_cuire", "second_souffle", "intimidant", "coup_de_grace", "montagnard",
	"frappe_vive", "insaisissable", "armure_lourde", "chef_ne",
]


func _duel(w: String = "hache", dist: int = 1) -> Array:
	var a: Unit = t.mk(w, "p", Vector2i(0, 0))
	var d: Unit = t.mk("hache", "e", Vector2i(dist, 0))
	return [a, d]


func _has_digit(txt: String) -> bool:
	for ch in txt:
		if ch >= "0" and ch <= "9":
			return true
	return false


func _hit(a: Unit, d: Unit, units: Array = []) -> int:
	return CombatRules.hit_chance(a, d, [a, d] + units)


# --- Données ---

func test_fifty_perks_and_pyramid() -> void:
	t.eq(Data.PERKS.size(), 50, "50 talents")
	t.eq(OLD_28.size() + NEW_22.size(), 50, "28 anciens + 22 nouveaux")
	for k in OLD_28:
		t.check(Data.PERKS.has(k), "ancienne clé conservée : %s" % k)
	for k in NEW_22:
		t.check(Data.PERKS.has(k), "nouveau talent : %s" % k)
	var rows: Array = []
	for tier in range(1, Data.PERK_TIERS + 1):
		rows.append(Perks.in_tier(tier).size())
	t.eq(rows, [9, 8, 8, 12, 5, 4, 4], "rangées 9, 8, 8, 12, 5, 4, 4")
	t.eq(Data.PERK_ROWS, rows, "PERK_ROWS cohérent")
	var seen: Dictionary = {}
	for k in Data.PERKS:
		var pd: Dictionary = Data.PERKS[k]
		var key: String = "%d/%d" % [int(pd["tier"]), int(pd["col"])]
		t.check(not seen.has(key), "%s : place unique (%s)" % [k, key])
		seen[key] = true
		t.check(int(pd["col"]) >= 0 and int(pd["col"]) < Perks.row_size(int(pd["tier"])), "%s : colonne dans la rangée" % k)
		t.check(Data.PERK_FAMILIES.has(pd["fam"]) and pd.has("fx") and pd.has("icon"), "%s : famille, fx, icône déclarés" % k)
		var has_effect: bool = pd.has("stat") or pd.has("shield_stat") or pd.has("light_stat") or pd.has("wp") or not (pd["fx"] as Dictionary).is_empty() or BY_ID.has(k) or pd.has("ability")
		t.check(has_effect, "%s : un effet est déclaré" % k)
		t.check(str(pd["d"]).length() > 10 and (_has_digit(str(pd["d"])) or str(pd["d"]).begins_with("Deux fois") or str(pd["d"]).begins_with("Ignore")), "%s : description chiffrée" % k)
	# Les rangs hauts sont plus rares et plus forts : moins de talents qu'en haut.
	t.check(Perks.in_tier(7).size() < Perks.in_tier(1).size(), "rangs hauts plus rares")
	var fams: Dictionary = {}
	for k in Data.PERKS:
		fams[Data.PERKS[k]["fam"]] = true
	t.eq(fams.size(), 5, "5 familles de couleur")


func test_icon_coverage() -> void:
	for k in Data.PERKS:
		var f: String = "res://assets/perk_icons/%s" % str(Data.PERKS[k]["icon"])
		t.check(FileAccess.file_exists(f) or ResourceLoader.exists(f), "%s : icône %s" % [k, f])
	var dir: DirAccess = DirAccess.open("res://assets/perk_icons")
	var used: Dictionary = {}
	for k in Data.PERKS:
		used[str(Data.PERKS[k]["icon"])] = true
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".svg"):
				t.check(used.has(f), "icône sans talent : %s" % f)
	t.eq(used.size(), 50, "une icône par talent")


func test_migration_keeps_points() -> void:
	var u: Unit = t.mk()
	u.level = 6
	var d: Dictionary = u.to_dict()
	d["perks"] = ["bretteur", "talent_disparu", "bretteur", "vif"]
	d["perk_points"] = 2
	var m: Unit = Unit.from_dict(d)
	t.eq(m.perks, ["bretteur", "vif"] as Array[String], "clé inconnue et doublon retirés, les valides gardées")
	t.eq(m.perk_points, 4, "un point rendu par talent retiré : rien de perdu")
	var old: Dictionary = u.to_dict()
	old.erase("perk_points")
	old["perks"] = ["vif", "talent_disparu"]
	t.eq(Unit.from_dict(old).perk_points, Perks.points_for_level(6) - 1, "ancienne sauvegarde sans points : niveau - talents valides")
	for k in OLD_28:  # toutes les anciennes clés restent valides telles quelles
		var o: Dictionary = u.to_dict()
		o["perks"] = [k]
		o["perk_points"] = 0
		t.eq(Unit.from_dict(o).perks, [k] as Array[String], "%s : intact après chargement" % k)
	t.eq(Unit.from_dict(u.to_dict()).perks.size(), 0, "valeurs par défaut")


# --- Effets de chaque nouveau talent (logique pure) ---

func test_stat_perks() -> void:
	var u: Unit = t.mk()
	var md: int = u.eff("melee_def")
	var rs: int = u.eff("resolve")
	u.perks.append_array(["parade", "tete_froide"] as Array[String])
	t.eq(u.eff("melee_def"), md + 5, "Parade : +5 défense de mêlée")
	t.eq(u.eff("resolve"), rs + 8, "Tête froide : +8 détermination")


func test_lame_affutee() -> void:
	var tot_a: int = 0
	var tot_b: int = 0
	for i in 200:
		var a: Unit = t.mk("hache")
		var d: Unit = t.mk("hache", "e")
		d.arm_b = 100
		d.arm_h = 100
		tot_a += int(CombatRules.roll_damage(a, d, t.rng_seeded(i))["armor"])
		a.perks.append("lame_affutee")
		tot_b += int(CombatRules.roll_damage(a, d, t.rng_seeded(i))["armor"])
	t.check(tot_b > tot_a, "Lame affûtée : plus de dégâts d'armure (%d contre %d)" % [tot_b, tot_a])


func test_camaraderie_and_gardien() -> void:
	var a: Unit = t.mk("hache", "e", Vector2i(0, 0))
	var d: Unit = t.mk("hache", "p", Vector2i(1, 0))
	var f1: Unit = t.mk("hache", "p", Vector2i(2, 0))
	var f2: Unit = t.mk("hache", "p", Vector2i(1, -1))
	var units: Array = [a, d, f1, f2]
	var base: int = CombatRules.hit_chance(a, d, units)
	d.perks.append("camaraderie")
	t.eq(CombatRules.hit_chance(a, d, units), base - 6, "Camaraderie : +3 par allié adjacent (2 alliés)")
	var alone: int = CombatRules.hit_chance(a, d, [a, d])
	t.eq(alone, CombatRules.hit_chance(a, t.mk("hache", "p", Vector2i(1, 0)), [a, d]), "sans allié : aucun bonus")
	d.perks.clear()
	var before: int = CombatRules.hit_chance(a, d, units)
	f1.perks.append("gardien")
	t.eq(CombatRules.hit_chance(a, d, units), before - 5, "Gardien : +5 défense à l'allié adjacent")
	var ranged: Unit = t.mk("arc", "e", Vector2i(5, 0))
	var rb: int = CombatRules.hit_chance(ranged, d, [ranged, d, f1])
	f1.perks.clear()
	t.eq(rb, CombatRules.hit_chance(ranged, d, [ranged, d, f1]) - 5, "Gardien aussi à distance")


func test_cicatrisation() -> void:
	var u: Unit = t.mk()
	u.hp_max = 60
	u.hp = 40
	var s: BattleState = BattleState.new()
	s.rng = t.rng_seeded(1)
	s.units.append(u)
	s.round_no = 1
	s.begin_turn(u)
	t.eq(u.hp, 40, "sans talent : pas de soin")
	var v: Unit = t.mk()
	v.hp_max = 60
	v.hp = 40
	v.perks.append("cicatrisation")
	s.units.append(v)
	s.begin_turn(v)
	t.eq(v.hp, 43, "Cicatrisation : +3 PV au début du tour")
	var w: Unit = t.mk()
	w.hp_max = 60
	w.hp = 59
	w.perks.append("cicatrisation")
	s.units.append(w)
	s.begin_turn(w)
	t.eq(w.hp, 60, "jamais au-delà du maximum")


func test_position_hit_perks() -> void:
	# Tireur posté
	var duel: Array = _duel("arc", 4)
	var a: Unit = duel[0]
	var d: Unit = duel[1]
	var base: int = _hit(a, d)
	a.perks.append("archer_pose")
	t.eq(_hit(a, d), base + 10, "Tireur posté : +10 sans avoir bougé")
	a.moved_cells = 2
	t.eq(_hit(a, d), base, "Tireur posté : rien après un déplacement")
	# Prédateur
	var duel2: Array = _duel()
	var b: Unit = duel2[0]
	var e: Unit = duel2[1]
	e.morale = 3
	var b0: int = _hit(b, e)
	b.perks.append("predateur")
	t.eq(_hit(b, e), b0, "Prédateur : rien contre un ennemi stable")
	e.morale = 1
	var pre: int = _hit(b, e)
	b.perks.erase("predateur")
	t.eq(pre, _hit(b, e) + 10, "Prédateur : +10 contre un ennemi brisé")
	e.morale = 0
	b.perks.append("predateur")
	var pre0: int = _hit(b, e)
	b.perks.erase("predateur")
	t.eq(pre0, _hit(b, e) + 10, "Prédateur : +10 contre un fuyard")
	# Élan
	var duel3: Array = _duel()
	var c: Unit = duel3[0]
	var f: Unit = duel3[1]
	var c0: int = _hit(c, f)
	c.perks.append("elan")
	c.moved_cells = 1
	t.eq(_hit(c, f), c0, "Élan : rien après 1 case")
	c.moved_cells = 2
	t.eq(_hit(c, f), c0 + 10, "Élan : +10 après 2 cases")
	var tot_a: int = 0
	var tot_b: int = 0
	f.arm_b = 0
	f.arm_h = 0
	for i in 100:
		c.moved_cells = 0
		tot_a += int(CombatRules.roll_damage(c, f, t.rng_seeded(i))["hp"])
		c.moved_cells = 3
		tot_b += int(CombatRules.roll_damage(c, f, t.rng_seeded(i))["hp"])
	t.check(tot_b > tot_a, "Élan : plus de dégâts après avoir couru (%d contre %d)" % [tot_b, tot_a])
	# Duelliste
	var duel4: Array = _duel()
	var g: Unit = duel4[0]
	var h: Unit = duel4[1]
	var ally: Unit = t.mk("hache", "p", Vector2i(-1, 0))
	var g0: int = _hit(g, h, [ally])
	var h0: int = _hit(h, g, [ally])
	g.perks.append("duelliste")
	t.eq(_hit(g, h, [ally]), g0, "Duelliste : rien avec un allié adjacent")
	var g_alone: int = _hit(g, h)
	g.perks.erase("duelliste")
	t.eq(g_alone, _hit(g, h) + 8, "Duelliste : +8 en attaque quand il est seul")
	g.perks.append("duelliste")
	t.eq(_hit(h, g, [ally]), h0 - 0, "Duelliste : (attaque d'un ennemi avec allié, sans effet sur lui)")
	var defended: int = _hit(h, g)
	g.perks.erase("duelliste")
	t.eq(defended, _hit(h, g) - 8, "Duelliste : +8 en défense quand il est seul")


func test_mur_vivant() -> void:
	var a: Unit = t.mk("hache", "e", Vector2i(0, 0))
	var d: Unit = t.mk("hache", "p", Vector2i(1, 0))
	d.shield = true
	d.shield_wall = true
	var base: int = _hit(a, d)
	d.perks.append("mur_vivant")
	t.eq(_hit(a, d), base - 10, "Mur vivant : +10 défense avec le mur de boucliers")
	d.shield_wall = false
	var open: int = _hit(a, d)
	d.perks.clear()
	t.eq(open, _hit(a, d), "Mur vivant : sans mur levé, aucun bonus")
	var ranged: Unit = t.mk("arc", "e", Vector2i(4, 0))
	ranged.ranged_skill = 95
	d.shield_wall = true
	var rb: int = CombatRules.hit_chance(ranged, d, [ranged, d])
	d.perks.append("mur_vivant")
	t.eq(CombatRules.hit_chance(ranged, d, [ranged, d]), rb - 10, "Mur vivant aussi contre les tirs")


func test_nuque_protegee() -> void:
	var heads_a: int = 0
	var heads_b: int = 0
	for i in 1000:
		var a: Unit = t.mk("hache")
		var d: Unit = t.mk("hache", "e")
		if bool(CombatRules.roll_damage(a, d, t.rng_seeded(i))["head"]):
			heads_a += 1
		d.perks.append("nuque_protegee")
		if bool(CombatRules.roll_damage(a, d, t.rng_seeded(i))["head"]):
			heads_b += 1
	t.check(heads_b < heads_a and heads_b > 0, "Nuque protégée : moins de coups à la tête (%d contre %d)" % [heads_b, heads_a])
	t.check(absf(float(heads_a - heads_b) / 1000.0 - 0.10) < 0.03, "environ 10 points de moins")


func test_voix_claire() -> void:
	var leader: Unit = t.mk("hache", "p", Vector2i(3, 3))
	var near: Unit = t.mk("hache", "p", Vector2i(6, 3))
	var far: Unit = t.mk("hache", "p", Vector2i(8, 3))
	var foe: Unit = t.mk("hache", "e", Vector2i(4, 3))
	var units: Array = [leader, near, far, foe]
	t.eq(Perks.morale_aura(near, units), 0, "sans talent : rien")
	leader.perks.append("voix_claire")
	t.eq(Perks.morale_aura(near, units), 5, "Voix claire : +5 à 3 cases")
	t.eq(Perks.morale_aura(far, units), 0, "plus loin : rien")
	t.eq(Perks.morale_aura(leader, units), 0, "pas pour soi-même")
	t.eq(Perks.morale_aura(foe, units), 0, "pas pour l'ennemi")
	var adj: Unit = t.mk("hache", "p", Vector2i(4, 3))
	units.append(adj)
	t.eq(Perks.morale_aura(adj, units), 5, "adjacent : +5 seulement avec la voix")
	leader.perks.append("chef_ne")
	t.eq(Perks.morale_aura(adj, units), 10, "Chef-né adjacent l'emporte (pas de cumul)")


func test_active_abilities() -> void:
	var m: Unit = t.mk("hache")
	t.check(not CombatRules.abilities_of(m).has("coup_puissant") and not CombatRules.abilities_of(m).has("croc_jambe"), "sans talent : capacités fermées")
	m.perks.append_array(["force_brute", "croc_en_jambe"] as Array[String])
	t.check(CombatRules.abilities_of(m).has("coup_puissant") and CombatRules.abilities_of(m).has("croc_jambe"), "les talents ouvrent les capacités")
	t.eq(Perks.abilities(m), ["coup_puissant", "croc_jambe"] as Array[String], "liste des capacités de talent")
	var bow: Unit = t.mk("arc")
	bow.perks.append_array(["force_brute", "croc_en_jambe"] as Array[String])
	t.check(not CombatRules.abilities_of(bow).has("coup_puissant"), "pas à distance")
	for id in ["coup_puissant", "croc_jambe"]:
		t.check(CombatRules.ability_ap(m, id) == m.attack_ap() + 1, "%s : 1 PA de plus" % id)
	var d: Unit = t.mk("hache", "e", Vector2i(1, 0))
	m.hex = Vector2i(0, 0)
	m.ap = 9
	t.check(CombatRules.can_use_ability(m, d, "coup_puissant"), "utilisable au contact")
	m.ap = m.attack_ap()
	t.check(not CombatRules.can_use_ability(m, d, "coup_puissant"), "pas assez de PA")
	# Dégâts et effet
	var ab: Dictionary = Data.ABILITIES["coup_puissant"]
	var tot_a: int = 0
	var tot_b: int = 0
	d.arm_b = 0
	d.arm_h = 0
	for i in 100:
		tot_a += int(CombatRules.roll_damage(m, d, t.rng_seeded(i))["hp"])
		tot_b += int(CombatRules.roll_damage(m, d, t.rng_seeded(i), ab)["hp"])
	t.check(tot_b > tot_a * 1.25, "Coup puissant : environ +35 %% de dégâts (%d contre %d)" % [tot_b, tot_a])
	var exposed: bool = false
	for i in 30:
		var s: BattleState = BattleState.new()
		s.rng = t.rng_seeded(i)
		var x: Unit = t.mk("hache", "p", Vector2i(0, 0))
		x.perks.append("croc_en_jambe")
		x.melee_skill = 200
		x.ap = 9
		var y: Unit = t.mk("hache", "e", Vector2i(1, 0))
		y.hp_max = 500
		y.hp = 500
		s.units.append(x)
		s.units.append(y)
		var r: Dictionary = s.use_ability(x, "croc_jambe", y)
		if bool(r["hit"]) and y.exposed:
			exposed = true
	t.check(exposed, "Croc-en-jambe : la cible touchée est déséquilibrée")


func test_increvable() -> void:
	var saved: int = 0
	for i in 400:
		var u: Unit = t.mk()
		u.perks.append("increvable")
		if Traits.lucky_save(u, t.rng_seeded(i)):
			saved += 1
		t.check(u.lucky_used, "une seule chance par bataille")
		t.check(not Traits.lucky_save(u, t.rng_seeded(i)), "pas deux fois")
	t.check(saved > 120 and saved < 200, "Increvable : environ 40 %% de survies (%d sur 400)" % saved)
	t.check(not Traits.lucky_save(t.mk(), t.rng_seeded(1)), "sans talent ni trait : jamais")


# --- Talents de campagne (Game) ---

func test_campaign_perks() -> void:
	var g: Node = t.new_game(77)
	var m: Unit = g.roster[0]
	var buy0: int = g.price_of(500)
	var sell0: int = g.price_of(500, false)
	var repair0: int = g.repair_cost()
	var vis0: float = g.vision_radius()
	m.arm_b = 0
	m.arm_h = 0
	var repair_dmg: int = g.repair_cost()
	m.perks.append_array(["marchandeur", "armurier", "eclaireur", "infirmier", "pilleur", "studieux"] as Array[String])
	t.check(g.price_of(500) < buy0, "Marchandeur : achats moins chers")
	t.eq(g.price_of(500), int(round(buy0 * 0.95)), "−5 %")
	t.eq(g.price_of(500, false), int(round(sell0 * 1.05)), "+5 % sur les ventes")
	t.check(g.repair_cost() < repair_dmg, "Armurier : réparations moins chères")
	t.check(repair0 <= repair_dmg, "(témoin)")
	t.check(g.vision_radius() > vis0 * 1.14 and g.vision_radius() < vis0 * 1.16, "Éclaireur : +15 % de vue")
	t.eq(Perks.roster_mult(g.roster, "loot_mult"), 1.15, "Pilleur : +15 % de butin")
	t.eq(Perks.fx_mult(m, "xp_mult"), 1.1, "Studieux : +10 % d'expérience")
	t.eq(Perks.fx_mult(g.roster[1], "xp_mult"), 1.0, "…seulement pour lui")
	# Repos : toute la compagnie profite du meilleur infirmier
	for x in g.roster:
		x.hp = 1
	m.perks.erase("infirmier")
	g.rest()
	var base_hp: int = g.roster[1].hp
	for x in g.roster:
		x.hp = 1
	m.perks.append("infirmier")
	g.rest()
	t.eq(g.roster[1].hp, base_hp + 4, "Mains douces : +4 PV de repos pour tous")
	g.free()


# --- Composant PerkTree ---

func test_perk_tree_logic() -> void:
	var tr := PerkTree.new()
	var u: Unit = t.mk()
	u.level = 4
	u.perk_points = 3
	tr.set_unit(u)
	tr.size = Vector2(900, 520)
	tr._layout()
	t.eq(tr.state_of("bretteur"), "open", "rang 1 disponible")
	t.eq(tr.state_of("briseur"), "locked", "rang 2 : il faut 1 talent")
	t.check("1 talent pour ce rang" in tr.status_of("briseur"), "raison : « Il faut N talents pour ce rang »")
	t.check("3 talents pour ce rang" in tr.status_of("spec_hache"), "rang 4 : 3 talents")
	t.eq(tr.state_of("oeil_de_lynx"), "locked", "prérequis explicite")
	var taken: Array = []
	tr.perk_taken.connect(func(k: String) -> void: taken.append(k))
	tr._on_click("bretteur")
	t.eq(tr.selected_key(), "bretteur", "premier clic : sélection")
	t.eq(u.perks.size(), 0, "rien d'appris au premier clic")
	t.check(tr._learn_b.visible, "bouton Apprendre visible")
	tr._on_click("bretteur")
	t.eq([u.perks.size(), u.perk_points, taken], [1, 2, ["bretteur"]], "second clic : appris, signal émis")
	t.eq(tr.state_of("bretteur"), "taken", "état appris")
	t.eq(tr.state_of("briseur"), "open", "le rang 2 s'ouvre")
	t.check(tr.learn("briseur") and tr.learn("vif"), "apprendre au bouton")
	t.eq(u.perk_points, 0, "tous les points dépensés")
	t.eq(tr.state_of("endurant"), "reach", "plus de point : rang atteint mais grisé")
	t.check(not tr.learn("endurant"), "impossible sans point")
	t.check(tr._reset_b.disabled, "sans Game : réinitialisation désactivée")
	# 50 pastilles, positions dans le cadre, rangées centrées
	t.eq(tr._icons.size(), 50, "50 pastilles")
	for tier in range(1, 8):
		var xs: Array = []
		for k in Perks.in_tier(tier):
			var c: Vector2 = tr.center_of(k)
			xs.append(c.x)
			t.check(c.x > 0 and c.x < tr.size.x and c.y > 0 and c.y < tr.size.y, "%s : dans le cadre" % k)
		t.check(absf((float(xs.min()) + float(xs.max())) * 0.5 - tr.size.x * 0.5) < 1.0, "rang %d centré" % tier)
	tr.free()


func test_perk_tree_scales() -> void:
	for sz in [Vector2(640, 420), Vector2(1280, 720), Vector2(2200, 1100)]:
		var tr := PerkTree.new()
		tr.set_unit(t.mk())
		tr.size = sz
		tr._layout()
		var ic: PerkIcon = tr.icon_of("bretteur")
		var w12: float = tr.center_of(Perks.in_tier(4)[11]).x - tr.center_of(Perks.in_tier(4)[0]).x
		t.check(ic.size.x >= 16.0 and w12 < sz.x, "taille %s : pastilles et rangée de 12 tiennent" % str(sz))
		tr.free()
	# Avec une partie : le reset passe par Game et n'est permis qu'en ville
	var g: Node = t.new_game(81)
	var m: Unit = g.roster[0]
	m.perk_points = 2
	var tr2 := PerkTree.new()
	tr2.game = g
	tr2.set_unit(m)
	tr2.learn("bretteur")
	t.check(m.has_perk("bretteur"), "appris via Game.spend_perks")
	g.gold = 5000
	tr2.refresh()
	t.check(not tr2._reset_b.disabled, "en ville avec de l'or : Réinit. possible")
	tr2._on_reset()
	t.check(m.has_perk("bretteur"), "premier clic : demande de confirmation seulement")
	tr2._on_reset()
	t.eq([m.perks.size(), m.perk_points], [0, 2], "second clic : talents rendus")
	m.perks.append("vif")
	g.location = ""
	tr2.refresh()
	t.check(tr2._reset_b.disabled and "ville" in tr2._reset_b.tooltip_text, "hors d'une ville : désactivé avec explication")
	tr2.free()
	g.free()
