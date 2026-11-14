extends RefCounted
## Scénarios, mode fer et encyclopédie.
var t


func _game(seed_value: int, opts: Dictionary) -> Node:
	var g: Node = load("res://autoload/Game.gd").new()
	g.autosave = false
	g.random_events = false
	g.new_game(seed_value, "normal", opts)
	t._games.append(g)
	return g


func test_free_game_unchanged() -> void:
	var g: Node = _game(11, {})
	t.eq(g.roster.size(), 5, "partie libre : 5 hommes")
	t.eq(g.gold, 800, "partie libre : 800 couronnes")
	t.check(not g.extras.has("scenario") and not g.extras.has("ironman"), "partie libre : aucun état de scénario ni de mode fer")
	t.eq(Scenarios.summary(g.extras, g.scenario_context()), "", "partie libre : pas de suivi")


func test_each_scenario_start_valid() -> void:
	t.eq(Scenarios.keys().size(), 4, "quatre scénarios")
	for k in Scenarios.keys():
		var d: Dictionary = Scenarios.data(k)
		var g: Node = _game(21, {"scenario": k})
		t.eq(g.roster.size(), (d["men"] as Array).size(), k + " : effectif de départ")
		t.check(g.roster.size() >= 3 and g.roster.size() <= Data.MAX_ROSTER, k + " : effectif valide")
		t.eq(Scenarios.active(g.extras), k, k + " : état enregistré")
		var want_gold: int = 800 if int(d["gold"]) < 0 else int(d["gold"])
		t.eq(g.gold, want_gold, k + " : or de départ")
		t.check(g.wages() > 0, k + " : solde positive")
		for u in g.roster:
			t.check(u.hp > 0 and Data.WPN.has(u.weapon), k + " : homme valide")
		var p: Dictionary = Scenarios.progress(g.extras, g.scenario_context())
		t.eq(int(p["cur"]), 0, k + " : progression à zéro")
		t.check(int(p["days_left"]) == int(d["days"]), k + " : jours restants")
		t.check(str(d["win"]) != "" and str(d["lose"]) != "" and str(d["intro"]) != "", k + " : textes présents")


func test_each_scenario_ends_reachable() -> void:
	for k in Scenarios.keys():
		var d: Dictionary = Scenarios.data(k)
		# victoire
		var g: Node = _game(31, {"scenario": k})
		t.eq(Scenarios.evaluate(g.extras, g.scenario_context()), "", k + " : pas fini au départ")
		var goal: Dictionary = d["goal"]
		if str(goal["stat"]) == "renown":
			g.renown = int(goal["target"])
		else:
			g.stats[str(goal["stat"])] = int(goal["target"])
		g.scenario_tick()
		t.eq(Scenarios.result(g.extras), "won", k + " : victoire atteignable")
		t.check(Scenarios.end_pending(g.extras), k + " : écran de fin en attente")
		Scenarios.acknowledge(g.extras)
		t.check(not Scenarios.end_pending(g.extras), k + " : écran de fin vu")
		# défaite
		var h: Node = _game(32, {"scenario": k})
		h.day = 1 + int(d["days"])
		h.scenario_tick()
		t.eq(Scenarios.result(h.extras), "lost", k + " : défaite par délai")
		t.check(Scenarios.end_text(h.extras) != "", k + " : texte de fin")
		# victoire prioritaire le dernier jour
		var w: Node = _game(33, {"scenario": k})
		w.day = 1 + int(d["days"])
		if str(goal["stat"]) == "renown":
			w.renown = int(goal["target"])
		else:
			w.stats[str(goal["stat"])] = int(goal["target"])
		w.scenario_tick()
		t.eq(Scenarios.result(w.extras), "won", k + " : victoire prioritaire le dernier jour")


func test_scenario_rules() -> void:
	var free: Node = _game(41, {})
	var nob: Node = _game(41, {"scenario": "nobles"})
	t.check(nob.wages() > free.wages() * 1.3, "nobles : solde bien plus élevée")
	for u in nob.roster:
		t.eq(u.body, "mailles", "nobles : haubert")
		t.eq(u.arm_b, u.body_armor_max(), "nobles : armure pleine")
	var ch: Node = _game(42, {"scenario": "chasseurs"})
	var n: int = 0
	for s in ch.world.settlements:
		for c in s["contracts"]:
			if not c.has("arc"):
				n += 1
				t.eq(str(c["type_contract"]), "hunt", "chasseurs : que des chasses")
				t.check(not c.has("dest_id"), "chasseurs : pas de trace de transport")
	t.check(n > 0, "chasseurs : des contrats existent")


func test_scenario_and_ironman_saved() -> void:
	var g: Node = _game(51, {"scenario": "course", "ironman": true})
	var d: Dictionary = g.to_dict()
	var g2: Node = _game(52, {})
	g2.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq(Scenarios.active(g2.extras), "course", "scénario relu")
	t.check(Ironman.is_on(g2.extras), "mode fer relu")


func test_ironman_rules() -> void:
	var g: Node = _game(61, {"ironman": true})
	t.check(Ironman.is_on(g.extras), "mode fer actif")
	t.check(not g.save_to_slot(1), "mode fer : emplacement manuel interdit")
	t.check(not g.load_slot(2), "mode fer : chargement d'emplacement interdit")
	t.check(Ironman.should_wipe(g.extras, true), "mode fer : suppression à la fin")
	t.check(not Ironman.should_wipe(g.extras, false), "mode fer : rien tant que la compagnie vit")
	var free: Node = _game(62, {})
	t.check(not Ironman.should_wipe(free.extras, true), "partie ordinaire : jamais supprimée")


func test_codex_coverage() -> void:
	var weapons: Array = Codex.entries("weapons").map(func(e: Dictionary) -> String: return str(e["id"]))
	for k in Data.WPN:
		t.check(weapons.has(str(k)), "encyclopédie : arme " + str(k))
	var perks: Array = Codex.entries("perks").map(func(e: Dictionary) -> String: return str(e["id"]))
	for k in Data.PERKS:
		t.check(perks.has(str(k)), "encyclopédie : talent " + str(k))
	var ids: Dictionary = {}
	for c in Codex.categories():
		var cid: String = str(c["id"])
		var es: Array = Codex.entries(cid)
		t.check(not es.is_empty(), "catégorie non vide : " + cid)
		ids[cid] = es.map(func(e: Dictionary) -> String: return str(e["id"]))
	for c in Codex.categories():
		var cid: String = str(c["id"])
		for e in Codex.entries(cid):
			var d: Dictionary = Codex.detail(cid, str(e["id"]))
			t.check(not Codex.is_empty_detail(d), "fiche non vide : %s/%s" % [cid, e["id"]])
			t.check(str(d["title"]) == str(e["n"]), "titre de fiche : %s/%s" % [cid, e["id"]])
			for l in d["links"]:
				t.check((ids.get(str(l["cat"]), []) as Array).has(str(l["id"])), "lien valide : %s/%s -> %s/%s" % [cid, e["id"], l["cat"], l["id"]])
	t.eq(Codex.search("weapons", "hache").size() >= 1, true, "recherche : hache")
	t.eq(Codex.search("weapons", "zzzzz").size(), 0, "recherche sans résultat")
