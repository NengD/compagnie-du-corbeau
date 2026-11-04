extends RefCounted
## Quartier général, vivres, moral, relations, factions humaines, histoires.
var t


func test_buildings() -> void:
	var g: Node = t.new_game(5)
	t.eq(g.max_roster(), Data.MAX_ROSTER, "capacité de base")
	g.gold = 5000
	t.check(g.buy_building("tentes"), "achat tentes")
	t.eq(g.max_roster(), Data.MAX_ROSTER + 1, "+1 homme")
	for i in 5:
		g.buy_building("tentes")
	t.eq(g.building_level("tentes"), 3, "niveau maximal")
	t.eq(g.max_roster(), 13, "13 hommes au plus")
	g.buy_building("entrepot")
	t.eq(g.stash_size(), Data.STASH_SIZE + 8, "entrepôt")
	g.buy_building("guet")
	t.check(absf(g.vision_radius() - Data.MAP_VISION * 1.2) < 0.01, "poste de guet +20 %")
	var cost: int = g.repair_cost()
	g.roster[0].arm_b = 0
	var before: int = g.repair_cost()
	g.buy_building("forge")
	t.check(g.repair_cost() < before, "la forge réduit le prix (%d -> %d)" % [before, g.repair_cost()])
	g.gold = 0
	t.check(not g.buy_building("cuisine"), "pas d'or, pas de bâtiment")
	var g2: Node = t.new_game(5)
	g2.from_dict(g.to_dict())
	t.eq(g2.building_level("tentes"), 3, "bâtiments sauvegardés")


func test_provisions_and_morale() -> void:
	var g: Node = t.new_game(6)
	var p0: int = g.provisions
	g.location = ""
	g.advance_time(2.0)
	t.eq(g.provisions, p0 - 2 * g.roster.size(), "une ration par homme et par jour de route")
	g.provisions = 0
	var hp0: int = g.roster[0].hp
	var m0: float = g.company_morale
	g.advance_time(1.0)
	t.check(g.company_morale < m0, "la faim abat le moral")
	t.check(g.roster[g.roster.size() - 1].hp < g.roster[g.roster.size() - 1].hp_max or hp0 <= 1, "la faim coûte des PV")
	g.company_morale = 10.0
	t.eq(g.battle_start_morale(), 2, "abattus : Hésitants")
	g.company_morale = 90.0
	t.eq(g.battle_start_morale(), 4, "enthousiastes : Confiants")
	g.company_morale = 50.0
	t.eq(g.battle_start_morale(), 3, "Stables")
	var g2: Node = t.new_game(6)
	g2.leave_settlement()
	var p1: int = g2.provisions
	g2.enter_settlement(str(g2.world.settlements[0]["id"]))
	g2.advance_time(1.0)
	t.eq(g2.provisions, p1, "en ville on mange sur place")
	g2.gold = 1000
	g2.provisions = 0
	t.check(g2.buy_provisions(10), "achat de vivres")
	t.eq(g2.provisions, 10, "10 rations")


func test_bonds() -> void:
	var a: Unit = t.mk("lance", "p")
	var b: Unit = t.mk("lance", "p")
	Bonds.add(a, b, 15)
	t.check(Bonds.is_friend(a, b, [a, b]), "amis")
	t.eq(Bonds.get_bond(b, a.id), 15, "lien symétrique")
	a.hex = Vector2i(2, 2)
	b.hex = Hex.neighbors(a.hex)[0]
	t.eq(Bonds.hit_bonus(a, [a, b]), 5, "ami adjacent : +5 %")
	t.eq(Bonds.morale_mod(a, [a, b]), 5, "ami adjacent : moral")
	t.eq(Bonds.fall_mod(a, b), -10, "voir tomber un ami")
	Bonds.set_bond(a, b, -10)
	t.eq(Bonds.morale_mod(a, [a, b]), -5, "rival adjacent")
	var c: Unit = Unit.from_dict(a.to_dict())
	t.eq(c.bonds.size(), 1, "liens sérialisés")
	Bonds.set_bond(a, b, 0)
	Bonds.battle_gain([a, b], true)
	t.eq(Bonds.get_bond(a, b.id), 2, "gain après une victoire")


func test_factions() -> void:
	var g: Node = t.new_game(7)
	for s in g.world.settlements:
		t.check(Data.FACTIONS.has(Factions.owner_of(s)), "propriétaire de %s" % s["name"])
	var owners: Dictionary = {}
	for s in g.world.settlements:
		owners[Factions.owner_of(s)] = true
	t.check(owners.size() >= 2, "plusieurs territoires")
	for s in g.world.settlements:
		for c in s["contracts"]:
			t.check(c.has("faction"), "contrat avec employeur")
	var g2: Node = t.new_game(7)
	var d: Dictionary = g.to_dict()
	for sd in d["world"]["settlements"]:
		sd.erase("owner")
	g2.from_dict(d)
	for s in g2.world.settlements:
		t.check(Data.FACTIONS.has(Factions.owner_of(s)), "migration : propriétaire attribué")
	g.change_faction_standing("lys", 60)
	t.eq(Factions.label(g.standing_with("lys")), "Allié", "réputation haute")
	g.change_faction_standing("lys", -200)
	t.eq(Factions.label(g.standing_with("lys")), "Ennemi", "réputation basse")
	t.check(Factions.price_mult(-60) > 1.0, "prix majorés")
	var old: Dictionary = g.to_dict()
	for k in ["provisions", "company_morale", "buildings", "faction_standing", "story_flags", "pending_events"]:
		old.erase(k)
	g2.from_dict(old)
	t.eq(g2.provisions, Data.PROVISIONS_START, "ancienne sauvegarde : vivres par défaut")
	t.eq(int(g2.company_morale), int(Data.MORALE_START), "moral par défaut")
	t.check(g2.buildings.is_empty(), "aucun bâtiment")


func test_stories() -> void:
	t.check(Data.STORIES.size() >= 6, "au moins 6 histoires")
	for sid in Data.STORIES:
		var story: Dictionary = Data.STORIES[sid]
		t.check((story["steps"] as Array).size() >= 2, "%s : 2 étapes au moins" % sid)
		for st in story["steps"]:
			t.check(not Events.get_def(str(st["id"])).is_empty(), "étape trouvable " + str(st["id"]))
			for ch in st["choices"]:
				for o in ch["outcomes"]:
					if o.has("schedule"):
						t.check(not Events.get_def(str(o["schedule"]["id"])).is_empty(), "suite existante " + str(o["schedule"]["id"]))
					if o.has("recruit_story"):
						t.check(Data.STORY_RECRUITS.has(str(o["recruit_story"])), "recrue " + str(o["recruit_story"]))
	var g: Node = t.new_game(8)
	g.gold = 1000
	g.pending_event = {"id": "dst_1"}
	var res: Dictionary = g.resolve_event("hide")
	t.check(bool(res["ok"]), "choix résolu")
	t.eq(g.pending_events.size(), 1, "suite programmée")
	t.check(g.story_flags.has("story_deserteur"), "histoire commencée")
	g.location = ""
	t.eq(g.pop_due_event().size(), 0, "pas encore due")
	g.day += 4
	var ev: Dictionary = g.pop_due_event()
	t.eq(str(ev.get("event", {}).get("id", "")), "dst_2", "suite due")
	g.gold = 500
	var n0: int = g.roster.size()
	var r2: Dictionary = g.resolve_event("pay")
	t.check(bool(r2["ok"]) and g.roster.size() == n0 + 1, "recrue unique")
	var u: Unit = g.roster[g.roster.size() - 1]
	t.check(u.perks.has("garde_ferme") and u.level == 3, "talents et niveau de la recrue")
	var g2: Node = t.new_game(8)
	g2.from_dict(g.to_dict())
	t.eq(g2.story_flags.size(), g.story_flags.size(), "drapeaux sauvegardés")
