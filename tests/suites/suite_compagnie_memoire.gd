extends RefCounted
## Passé et objectifs personnels des hommes (core/backstory.gd), journal de campagne et mémorial (core/chronicle.gd).
var t


func test_backstory_draw() -> void:
	var g: Node = t.new_game(7)
	for m in g.roster:
		t.check(m.backstory != "", "%s a une histoire" % m.unit_name)
		t.check(not m.goal.is_empty() and Backstory.KINDS.has(str(m.goal["kind"])), "%s a un objectif valide" % m.unit_name)
		t.check(int(m.goal["target"]) > 0 and not bool(m.goal["done"]) and int(m.goal["prog"]) == 0, "objectif neuf")
		t.check(Backstory.goal_text(m.goal) != "" and Backstory.reward_text(m.goal) != "", "textes d'objectif")
	var seen: Dictionary = {}
	for k in Data.BG:  # au moins 2 variantes par origine, toutes les origines couvertes
		t.check((Backstory.STORIES[k] as Array).size() >= 2, "histoires de %s" % k)
		for i in range(1, 40):
			var u := Unit.new()
			u.id = i
			u.background = Data.BG[k]["n"]
			Backstory.assign(u)
			seen[u.backstory] = true
	t.check(seen.size() >= 14, "les variantes sont bien tirées (%d)" % seen.size())
	var a := Unit.new()
	a.id = 99
	a.background = "Bûcheron"
	Backstory.assign(a)
	var b2 := Unit.new()
	b2.id = 99
	b2.background = "Bûcheron"
	Backstory.assign(b2)
	t.eq(a.backstory, b2.backstory, "tirage stable pour un même id")
	t.eq(a.goal, b2.goal, "objectif stable pour un même id")
	var rec: Array = Contracts.gen_recruits(t.rng_seeded(3), [], [], 4)
	for r in rec:
		t.check((r["u"] as Unit).backstory != "", "recrue avec histoire")
	var e: Unit = Contracts.make_foe("brigand", t.rng_seeded(1))
	t.eq(e.backstory, "", "pas d'histoire pour un ennemi")


func test_goal_progress_and_rewards() -> void:
	var u := Unit.new()
	u.id = 5
	u.side = "p"
	u.background = "Fermier"
	u.goal = {"kind": "kills", "target": 5, "prog": 0, "done": false, "rw": {"type": "stat", "key": "melee_skill", "amt": 3}}
	u.backstory = "x"
	var ms: int = u.melee_skill
	t.eq(Backstory.progress([u], "wins", 3).size(), 0, "autre genre : rien")
	t.eq(Backstory.progress([u], "kills", 3).size(), 0, "pas encore")
	t.eq(int(u.goal["prog"]), 3, "progression")
	var res: Array = Backstory.progress([u], "kills", 4)
	t.eq(res.size(), 1, "atteint")
	t.check(bool(u.goal["done"]) and int(u.goal["prog"]) == 5, "terminé, plafonné")
	t.eq(u.melee_skill, ms + 3, "bonus de stat")
	t.eq(Backstory.progress([u], "kills", 4).size(), 0, "récompense unique")
	t.eq(u.melee_skill, ms + 3, "pas de double récompense")
	u.goal = {"kind": "level", "target": 3, "prog": 0, "done": false, "rw": {"type": "perk", "amt": 1}}
	var pts: int = u.perk_points
	Backstory.progress_one(u, "level", 3, true)
	t.eq(u.perk_points, pts + 1, "point de talent")
	u.goal = {"kind": "days", "target": 2, "prog": 0, "done": false, "rw": {"type": "hp", "key": "hp_max", "amt": 5}}
	var hp: int = u.hp_max
	Backstory.progress([u], "days", 2)
	t.eq(u.hp_max, hp + 5, "PV maximum")
	u.traits.clear()
	u.goal = {"kind": "gold", "target": 10, "prog": 0, "done": false, "rw": {"type": "trait", "key": "vif"}}
	Backstory.progress([u], "gold", 50)
	t.check(u.traits.has("vif"), "trait gagné")
	u.traits.assign(["lent"])
	u.goal = {"kind": "gold", "target": 10, "prog": 0, "done": false, "rw": {"type": "trait", "key": "vif"}}
	pts = u.perk_points
	Backstory.progress([u], "gold", 50)
	t.check(not u.traits.has("vif") and u.perk_points == pts + 1, "trait impossible : point de talent à la place")


func test_game_hooks() -> void:
	var g: Node = t.new_game(11)
	var m: Unit = g.roster[0]
	m.goal = {"kind": "days", "target": 2, "prog": 0, "done": false, "rw": {"type": "hp", "key": "hp_max", "amt": 5}}
	g.advance_time(2.0)
	t.check(bool(m.goal["done"]), "les jours font avancer l'objectif")
	t.check(Chronicle.entries(g.extras, "goal").size() >= 1, "objectif consigné au journal")
	t.check(g.news.any(func(l: String) -> bool: return l.contains("a tenu son pari")), "ligne dans les nouvelles")
	var m2: Unit = g.roster[1]
	m2.goal = {"kind": "level", "target": 2, "prog": 0, "done": false, "rw": {"type": "perk", "amt": 1}}
	m2.xp = 100
	g.level_check(m2)
	t.check(bool(m2.goal["done"]), "montée de niveau : objectif atteint")
	t.check(Chronicle.entries(g.extras, "level").size() >= 1, "niveau consigné")
	g.enter_settlement(g.world.settlements[0]["id"])
	g.gold = 5000
	var n_roster: int = g.roster.size()
	g.world.settlements[0]["recruits"] = Contracts.gen_recruits(t.rng_seeded(2), [], [], 3)
	t.check(g.hire(0), "embauche")
	t.eq(g.roster.size(), n_roster + 1, "recrue engagée")
	t.check(g.roster.back().backstory != "", "histoire conservée à l'embauche")
	t.check(Chronicle.entries(g.extras, "hire").size() >= 1, "embauche consignée")


func test_battle_hooks() -> void:
	var g: Node = t.new_game(33)
	var fighter: Unit = g.roster[0]
	fighter.goal = {"kind": "wins", "target": 1, "prog": 0, "done": false, "rw": {"type": "stat", "key": "resolve", "amt": 4}}
	g.accept_contract(0)
	g.leave_settlement()
	g.start_battle(g.active_contract)
	for u in g.battle.units:
		if u.side == "e":
			u.dead = true
			u.hp = 0
	g.battle.check_end()
	g.finish_battle()
	t.check(Chronicle.entries(g.extras, "battle").size() >= 1, "bataille consignée")
	t.check(Chronicle.entries(g.extras, "contract").size() >= 1, "contrat consigné")
	var found: Unit = g.member(fighter.id)
	if found != null:
		t.check(bool(found.goal["done"]), "victoire : objectif de batailles atteint")
		t.check((g.last_battle_report["goals"] as Array).size() >= 1, "objectif dans le résumé de bataille")


func test_chronicle_cap_and_save() -> void:
	var ex: Dictionary = {}
	for i in 350:
		Chronicle.record(ex, i, "battle", "Bataille %d" % i)
	t.eq(Chronicle.entries(ex).size(), Chronicle.MAX_ENTRIES, "journal borné")
	t.eq(str(Chronicle.entries(ex)[0]["x"]), "Bataille 349", "le plus récent d'abord")
	t.eq(str(Chronicle.entries(ex)[Chronicle.MAX_ENTRIES - 1]["x"]), "Bataille 50", "les plus anciens sont écartés")
	Chronicle.record(ex, 3, "inconnu", "Genre inconnu")
	t.eq(str(Chronicle.entries(ex, "event")[0]["x"]), "Genre inconnu", "genre inconnu -> événement")
	Chronicle.record(ex, 3, "battle", "")
	t.eq(Chronicle.entries(ex).size(), Chronicle.MAX_ENTRIES, "texte vide ignoré")
	var g: Node = t.new_game(21)
	Chronicle.record(g.extras, 4, "death", "Un brave tombe.")
	var json: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = t.new_game(5)
	g2.from_dict(json)
	t.eq(str(Chronicle.entries(g2.extras, "death")[0]["x"]), "Un brave tombe.", "journal sauvegardé et rechargé")
	t.eq(int(Chronicle.entries(g2.extras)[0]["d"]), 4, "jour entier après JSON")
	t.eq(g2.roster[0].backstory, g.roster[0].backstory, "histoire sauvegardée")
	t.eq(g2.roster[0].goal["kind"], g.roster[0].goal["kind"], "objectif sauvegardé")
	var junk: Dictionary = {"chronicle": [{"x": "ok"}, 5, {"nope": 1}, {"d": "7", "k": 3, "x": "bizarre"}]}
	t.eq(Chronicle.entries(junk).size(), 2, "entrées abîmées écartées ou réparées")
	t.eq(Chronicle.entries({}).size(), 0, "clé absente : journal vide")


func test_old_saves() -> void:
	var g: Node = t.new_game(9)
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	d.erase("extras")
	for m in d["roster"]:
		m.erase("backstory")
		m.erase("goal")
	var g2: Node = t.new_game(1)
	g2.from_dict(d)
	t.eq(g2.roster.size(), g.roster.size(), "ancienne sauvegarde chargée")
	for i in g2.roster.size():
		t.check(g2.roster[i].backstory != "" and not g2.roster[i].goal.is_empty(), "histoire tirée à la volée")
		t.eq(g2.roster[i].backstory, g.roster[i].backstory, "tirage déterministe depuis l'id")
	t.eq(Chronicle.entries(g2.extras).size(), 0, "ancien journal vide")
	t.check(g2.roster[0].to_dict().has("goal"), "réécrit à la prochaine sauvegarde")
