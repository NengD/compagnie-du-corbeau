extends RefCounted
## Difficulté : coefficients appliqués, « Normal » strictement neutre, sérialisation et migration.
var t


func _contract(foes: Array, d: int) -> Dictionary:
	return {"kind": "contract", "type": "b", "type_contract": "kill", "d": d, "foes": foes, "title": "Test", "biome": "plain", "pay": 100}


func _party(n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var out: Array = []
	for i in n:
		out.append(Contracts.make_merc("milicien", rng, []))
	return out


func _game(seed_value: int, lvl: String) -> Node:
	var g: Node = load("res://autoload/Game.gd").new()
	g.autosave = false
	g.random_events = false
	g.new_game(seed_value, lvl)
	return g


func test_table_and_neutral_normal() -> void:
	t.eq(Difficulty.keys(), ["easy", "normal", "hard"], "ordre des niveaux")
	t.eq(Difficulty.clean("inconnu"), "normal", "clé inconnue -> normal")
	t.eq(Difficulty.start_gold("easy"), 1000, "or facile")
	t.eq(Difficulty.start_gold("normal"), 800, "or normal")
	t.eq(Difficulty.start_gold("hard"), 600, "or difficile")
	for what in ["foe_stats", "pay", "price", "xp", "wound", "food", "morale_loss", "loot", "threat"]:
		t.eq(Difficulty.coef("normal", what), 1.0, "normal neutre : " + what)
	t.eq(int(Data.DIFFICULTY["normal"]["foe_count"]), 0, "normal : effectif inchangé")
	for v in [1, 7, 33, 125, 999]:
		t.eq(Difficulty.foe_stat("normal", v), v, "stat ennemie neutre")
		t.eq(Difficulty.pay("normal", v), v, "prime neutre")
		t.eq(Difficulty.price("normal", v), v, "prix neutre")
		t.eq(Difficulty.xp("normal", v), v, "xp neutre")
		t.eq(Difficulty.wound_chance("normal", v), v, "blessure neutre")
		t.eq(Difficulty.food_need("normal", v), v, "vivres neutres")
		t.eq(Difficulty.morale_delta("normal", -float(v)), -float(v), "moral neutre")
	t.eq(Difficulty.morale_delta("hard", 6.0), 6.0, "les gains de moral ne changent pas")
	for k in Difficulty.keys():
		t.check(Difficulty.label(k) != "" and Difficulty.desc(k) != "" and Difficulty.summary_lines(k).size() == 5, "textes de " + k)


func test_coefficients() -> void:
	t.eq(Difficulty.foe_stat("easy", 100), 92, "PV ennemis facile")
	t.eq(Difficulty.foe_stat("hard", 100), 112, "PV ennemis difficile")
	t.eq(Difficulty.pay("easy", 1000), 1150, "prime facile")
	t.eq(Difficulty.pay("hard", 1000), 900, "prime difficile")
	t.eq(Difficulty.price("easy", 100), 90, "prix facile")
	t.eq(Difficulty.price("hard", 100), 110, "prix difficile")
	t.eq(Difficulty.xp("easy", 100), 120, "xp facile")
	t.eq(Difficulty.xp("hard", 100), 90, "xp difficile")
	t.eq(Difficulty.wound_chance("easy", 50), 35, "blessure facile")
	t.eq(Difficulty.wound_chance("hard", 50), 65, "blessure difficile")
	t.eq(Difficulty.wound_chance("hard", 90), 100, "blessure bornée à 100")
	t.eq(Difficulty.food_need("easy", 10), 8, "vivres facile")
	t.eq(Difficulty.food_need("hard", 8), 10, "vivres difficile")
	t.eq(Difficulty.morale_delta("easy", -10.0), -7.5, "perte de moral facile")
	t.eq(Difficulty.morale_delta("hard", -10.0), -12.5, "perte de moral difficile")
	t.eq(Difficulty.loot_mult("easy"), 1.2, "butin facile")
	t.eq(Difficulty.threat_mult("hard"), 1.2, "menace difficile")


func test_foe_creation() -> void:
	for key in ["brigand", "chef", "goule", "orc_chef"]:
		var a: Unit = Contracts.make_foe(key, t.rng_seeded(9))
		var b: Unit = Contracts.make_foe(key, t.rng_seeded(9), "normal")
		t.check(a.hp_max == b.hp_max and a.melee_skill == b.melee_skill and a.ranged_skill == b.ranged_skill, "normal = défaut : " + key)
		var e: Unit = Contracts.make_foe(key, t.rng_seeded(9), "easy")
		var h: Unit = Contracts.make_foe(key, t.rng_seeded(9), "hard")
		t.eq(e.hp_max, Difficulty.foe_stat("easy", a.hp_max), "PV facile : " + key)
		t.eq(h.hp_max, Difficulty.foe_stat("hard", a.hp_max), "PV difficile : " + key)
		t.eq(h.hp, h.hp_max, "PV pleins")
		t.eq(h.melee_skill, Difficulty.foe_stat("hard", a.melee_skill), "compétence difficile")
		t.check(e.hp_max < a.hp_max and a.hp_max < h.hp_max, "ordre des PV : " + key)
		t.eq(h.melee_def, a.melee_def, "défense inchangée")


func test_foe_count() -> void:
	var foes: Array = ["brigand", "brigand", "brigand", "archer", "archer", "balafre"]
	t.eq(Difficulty.adjust_foes(foes, 2, "normal").size(), 6, "normal : effectif")
	t.eq(Difficulty.adjust_foes(foes, 2, "easy").size(), 5, "facile : -1")
	t.eq(Difficulty.adjust_foes(foes, 2, "hard").size(), 7, "difficile : +1")
	t.eq(Difficulty.adjust_foes(foes, 1, "easy").size(), 6, "danger 1 : inchangé (facile)")
	t.eq(Difficulty.adjust_foes(foes, 1, "hard").size(), 6, "danger 1 : inchangé (difficile)")
	t.eq(foes.size(), 6, "liste d'origine intacte")
	var with_chef: Array = ["brigand", "brigand", "chef"]
	t.check(Difficulty.adjust_foes(with_chef, 3, "easy").has("chef"), "le chef n'est pas retiré")
	for lvl in ["easy", "normal", "hard"]:
		var s: BattleState = BattleState.create(_contract(foes, 3), _party(5), t.rng_seeded(4), 3, 1.0, lvl)
		var n_foes: int = 0
		for u in s.units:
			if u.side == "e":
				n_foes += 1
		t.eq(n_foes, 6 + int(Data.DIFFICULTY[lvl]["foe_count"]), "ennemis en bataille : " + lvl)
		t.eq(s.difficulty, lvl, "difficulté mémorisée")
		var back: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), t.rng_seeded(4))
		t.eq(back.difficulty, lvl, "difficulté sérialisée : " + lvl)
	var old: Dictionary = BattleState.create(_contract(foes, 3), _party(5), t.rng_seeded(4)).to_dict()
	old.erase("difficulty")
	t.eq(BattleState.from_dict(JSON.parse_string(JSON.stringify(old)), t.rng_seeded(4)).difficulty, "normal", "ancienne bataille -> normal")


func test_game_state_and_migration() -> void:
	var g: Node = t.new_game(5)
	t.eq(g.difficulty, "normal", "défaut normal")
	t.eq(g.gold, 800, "or normal")
	var h: Node = _game(5, "hard")
	t.eq(h.difficulty, "hard", "difficulté choisie")
	t.eq(h.gold, 600, "or difficile")
	var e: Node = _game(5, "easy")
	t.eq(e.gold, 1000, "or facile")
	var d: Dictionary = JSON.parse_string(JSON.stringify(h.to_dict()))
	t.eq(d["difficulty"], "hard", "sérialisé")
	var r: Node = t.new_game(6)
	r.from_dict(d)
	t.eq(r.difficulty, "hard", "rechargé")
	d.erase("difficulty")
	r.from_dict(d)
	t.eq(r.difficulty, "normal", "ancienne sauvegarde -> normal")
	d["difficulty"] = "nimportequoi"
	r.from_dict(d)
	t.eq(r.difficulty, "normal", "valeur invalide -> normal")
	for n in [g, h, e, r]:
		n.free()


func test_game_effects() -> void:
	var n: Node = t.new_game(7)
	var h: Node = _game(7, "hard")
	var e: Node = _game(7, "easy")
	var p_n: int = n.price_of(200)
	t.eq(e.price_of(200), Difficulty.price("easy", p_n), "prix facile appliqué")
	t.eq(h.price_of(200), Difficulty.price("hard", p_n), "prix difficile appliqué")
	t.check(e.price_of(200) < p_n and p_n < h.price_of(200), "prix ordonnés")
	var cn: Array = n.settlement()["contracts"]
	var ch: Array = h.settlement()["contracts"]
	t.eq(cn.size(), ch.size(), "mêmes contrats")
	for i in cn.size():
		t.eq(int(ch[i]["pay"]), Difficulty.pay("hard", int(cn[i]["pay"])), "prime difficile du contrat %d" % i)
	for g in [n, h, e]:
		g.company_morale = 50.0
		g.morale_add(-10.0)
	t.eq(n.company_morale, 40.0, "moral normal")
	t.eq(h.company_morale, 37.5, "moral difficile")
	t.eq(e.company_morale, 42.5, "moral facile")
	for g in [n, h, e]:
		g.provisions = 100
		g.roster.append(g.roster[0])  # 6 hommes : la liste ne sert qu'à compter
		g._eat_on_road()
	t.eq(100 - n.provisions, 6, "vivres normal")
	t.eq(100 - h.provisions, Difficulty.food_need("hard", 6), "vivres difficile")
	t.eq(100 - e.provisions, Difficulty.food_need("easy", 6), "vivres facile")
	t.check(100 - e.provisions < 100 - n.provisions and 100 - n.provisions < 100 - h.provisions, "vivres ordonnés")
	var w: World = n.world
	var st_n: Dictionary = Campaign.new_state("o")
	var st_h: Dictionary = Campaign.new_state("o")
	var st_e: Dictionary = Campaign.new_state("o")
	Campaign.daily(st_n, w, t.rng_seeded(1), 3, 0)
	Campaign.daily(st_h, w, t.rng_seeded(1), 3, 0, Difficulty.threat_mult("hard"))
	Campaign.daily(st_e, w, t.rng_seeded(1), 3, 0, Difficulty.threat_mult("easy"))
	t.check(float(st_e["threat"]) < float(st_n["threat"]) and float(st_n["threat"]) < float(st_h["threat"]), "menace ordonnée")
	t.check(is_equal_approx(float(st_h["threat"]), float(st_n["threat"]) * 1.2), "menace difficile ×1,2")
	for g in [n, h, e]:
		g.free()


func test_wounds_and_loot() -> void:
	var counts: Dictionary = {}
	for lvl in ["easy", "normal", "hard"]:
		var c: int = 0
		var rng: RandomNumberGenerator = t.rng_seeded(11)
		for i in 600:
			var u: Unit = t.mk("hache", "p")
			u.hp_max = 60
			u.hp = 60
			if Injuries.roll_wound(u, 40, rng, lvl) != "":
				c += 1
		counts[lvl] = c
	t.check(counts["easy"] < counts["normal"] and counts["normal"] < counts["hard"], "blessures ordonnées %s" % str(counts))
	var u1: Unit = t.mk("hache", "p")
	var u2: Unit = t.mk("hache", "p")
	for u in [u1, u2]:
		u.hp_max = 60
		u.hp = 60
	t.eq(Injuries.roll_wound(u1, 40, t.rng_seeded(5)), Injuries.roll_wound(u2, 40, t.rng_seeded(5), "normal"), "normal = comportement d'origine")
	var loots: Dictionary = {}
	for lvl in ["easy", "normal", "hard"]:
		var total: int = 0
		var rng: RandomNumberGenerator = t.rng_seeded(21)
		for i in 80:
			var foe: Unit = Contracts.make_foe("brigand", rng)
			foe.dead = true
			total += Loot.roll_battle([foe], rng, Difficulty.loot_mult(lvl)).size()
		loots[lvl] = total
	t.check(loots["easy"] > loots["hard"] and loots["easy"] >= loots["normal"] and loots["normal"] >= loots["hard"], "butin ordonné %s" % str(loots))
	var ra: RandomNumberGenerator = t.rng_seeded(8)
	var rb: RandomNumberGenerator = t.rng_seeded(8)
	var f1: Unit = Contracts.make_foe("balafre", ra)
	var f2: Unit = Contracts.make_foe("balafre", rb)
	f1.dead = true
	f2.dead = true
	t.eq(Loot.roll_battle([f1], ra).size(), Loot.roll_battle([f2], rb, 1.0).size(), "butin normal = d'origine")


func test_xp_in_finish_battle() -> void:
	var xps: Dictionary = {}
	for lvl in ["easy", "normal", "hard"]:
		var g: Node = _game(9, lvl)
		var c: Dictionary = _contract(["brigand", "brigand"], 2)
		g.active_contract = c
		g.battle = BattleState.create(c, g.roster, g.rng, 3, 1.0, g.difficulty)
		for u in g.battle.units:
			if u.side == "e":
				u.dead = true
				u.hp = 0
		g.battle.over = "win"
		var before: int = g.roster[0].xp
		g.finish_battle()
		xps[lvl] = g.roster[0].xp - before
		g.free()
	t.eq(xps["normal"], 30, "xp normale : 15 × danger 2")
	t.eq(xps["easy"], 36, "xp facile")
	t.eq(xps["hard"], 27, "xp difficile")


func test_simulated_battles_end() -> void:
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	for lvl in ["easy", "normal", "hard"]:
		lib.difficulty = lvl
		var g: Node = lib.make_game(1)
		for s in range(0, 12):
			var r: Dictionary = lib.run_battle(g, s)
			t.eq(r["errors"], [], "bataille simulée %s graine %d sans erreur" % [lvl, s])
			t.check(str(r["over"]) != "", "bataille terminée (%s, %d)" % [lvl, s])
		g.free()
