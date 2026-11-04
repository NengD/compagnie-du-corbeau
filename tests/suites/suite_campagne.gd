extends RefCounted
## Contenu de campagne : lieux hostiles, objets uniques et marchand rare, arcs de contrats, menace et crise finale.
var t


func _game(seed_value: int, renown: int = 0) -> Node:
	var g: Node = load("res://autoload/Game.gd").new()
	g.autosave = false
	g.random_events = false
	g.new_game(seed_value)
	g.renown = renown
	return g


func _reload(g: Node) -> Node:
	var g2: Node = load("res://autoload/Game.gd").new()
	g2.autosave = false
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	return g2


## Gagne la bataille en cours : tous les ennemis tombent, puis retour sur la carte.
func _win(g: Node) -> void:
	for u in g.battle.units:
		if u.side == "e":
			u.dead = true
	g.battle.over = "win"
	g.finish_battle()


# --- A) Lieux hostiles ---

func test_lieux_hostiles_generes() -> void:
	var g: Node = _game(21)
	t.eq(g.world.sites.size(), 3, "fort, repaire et nécropole")
	var kinds: Array = []
	for s in g.world.sites:
		kinds.append(s["kind"])
		t.eq(s["state"], "hostile", "lieu hostile au départ")
		t.check(not g.world.find_path(g.world.player_pos, g.world.settlement_pos(s)).is_empty(), "%s est atteignable" % s["name"])
		t.check(g.world.settlement_near(g.world.settlement_pos(s), 120.0).is_empty(), "%s est à l'écart des villes" % s["name"])
		t.check(Campaign.garrison(s["kind"]).size() >= 9, "garnison étoffée")
		for k in Campaign.garrison(s["kind"]):
			t.eq(Data.FOE[k]["fac"], s["faction"], "%s appartient à la faction du lieu" % k)
	t.check(kinds.has("fort") and kinds.has("lair") and kinds.has("necropolis"), "trois types de lieux")
	t.check(g.world.settlement_by_id(g.world.sites[0]["id"]).is_empty(), "un lieu hostile n'est pas une ville (aucune entrée)")


func test_assaut_fort_devient_base_amie() -> void:
	var g: Node = _game(21)
	var fort: Dictionary = {}
	for s in g.world.sites:
		if s["kind"] == "fort":
			fort = s
	var gold0: int = g.gold
	var renown0: int = g.renown
	t.check(g.engage_site(fort["id"]), "assaut lancé")
	t.eq(g.battle.contract["kind"], "assault", "contrat d'assaut")
	t.check(g.battle.units.size() >= 5 + 9, "garnison engagée")
	g.battle.units[0].hp = 5  # un blessé
	_win(g)
	t.eq(fort["state"], "friendly", "le fort pris devient un poste ami")
	t.eq(g.gold, gold0 + Campaign.SITE_TYPES["fort"]["pay"], "prime versée")
	t.eq(g.renown, renown0 + Campaign.SITE_TYPES["fort"]["renown"], "renom gagné")
	t.check(g.inventory.size() >= 2, "butin de qualité (≥ 2 pièces)")
	t.check(not g.engage_site(fort["id"]), "on n'attaque pas un poste ami")
	# repos au poste
	g.leave_settlement()
	g.world.player_pos = g.world.settlement_pos(fort)
	g.roster[0].hp = 3
	var day: int = g.day
	t.check(g.rest_at_site(fort["id"]), "repos au poste")
	t.check(g.day > day and g.roster[0].hp >= 3 + Campaign.SITE_REST_HEAL - 5, "un jour passé, PV rendus")
	g.world.player_pos = Vector2(100, 100)
	t.check(not g.rest_at_site(fort["id"]), "pas de repos loin du poste")


func test_lieu_libere_reapparait() -> void:
	var g: Node = _game(22)
	var lair: Dictionary = {}
	for s in g.world.sites:
		if s["kind"] == "lair":
			lair = s
	g.engage_site(lair["id"])
	_win(g)
	t.eq(lair["state"], "cleared", "repaire libéré")
	var due: int = int(lair["respawn_day"])
	t.check(due > g.day + 30, "long délai de réapparition")
	g.advance_time(float(due - g.day) + 1.0)
	t.eq(lair["state"], "hostile", "le repaire est réoccupé")


func test_defaite_assaut_laisse_le_lieu() -> void:
	var g: Node = _game(23)
	var s: Dictionary = g.world.sites[0]
	g.engage_site(s["id"])
	g.battle.over = "lose"
	for u in g.battle.units:
		if u.side == "p":
			u.dead = true
	g.finish_battle()
	t.eq(s["state"], "hostile", "défaite : le lieu reste hostile")
	t.check(g.game_over, "compagnie anéantie : game over")


func test_arrivee_sur_un_lieu_hostile() -> void:
	var g: Node = _game(24)
	g.leave_settlement()
	g.world.parties.clear()
	var s: Dictionary = g.world.sites[0]
	t.check(g.world.set_destination(g.world.settlement_pos(s), {"kind": "site", "id": s["id"], "title": s["name"]}), "route vers le lieu")
	var ev: Dictionary = {}
	var guard: int = 0
	while ev.get("type", "") == "" and guard < 800:
		ev = g.map_step(0.25)
		guard += 1
	t.eq(ev.get("type", ""), "site", "arrivée signalée (pas d'entrée en ville)")
	t.eq(g.location, "", "toujours sur la carte")


func test_sauvegarde_lieux_et_campagne() -> void:
	var g: Node = _game(25)
	g.world.sites[0]["state"] = "friendly"
	g.campaign["threat"] = 42.5
	g.campaign["uniques_taken"].append("u_epee_corbeau")
	var g2: Node = _reload(g)
	t.eq(g2.world.sites.size(), g.world.sites.size(), "lieux restaurés")
	t.eq(g2.world.sites[0]["state"], "friendly", "état du lieu")
	t.check(absf(float(g2.campaign["threat"]) - 42.5) < 0.01, "menace")
	t.eq(g2.campaign["uniques_taken"], ["u_epee_corbeau"], "uniques sortis")
	# ancienne sauvegarde (sans campagne ni lieux)
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	d.erase("campaign")
	d["world"].erase("sites")
	for s in d["world"]["settlements"]:
		s.erase("rare")
	var g3: Node = load("res://autoload/Game.gd").new()
	g3.autosave = false
	g3.from_dict(d)
	t.eq(g3.campaign["final"], "locked", "campagne par défaut")
	t.eq(g3.world.sites.size(), 3, "lieux ajoutés à une ancienne sauvegarde")
	t.eq(g3.world.settlements[0]["rare"], [], "pas de marchand rare par défaut")


# --- B) Objets uniques et marchand rare ---

func test_objets_uniques() -> void:
	for k in Data.UNIQUES:
		var u: Dictionary = Data.UNIQUES[k]
		var table: Dictionary = {"weapon": Data.WPN, "head": Data.HEAD, "body": Data.BODY}[u["kind"]]
		t.check(table.has(k), "%s : statistiques présentes" % k)
		t.check(table.has(u["look"]), "%s : modèle visuel %s" % [k, u["look"]])
		t.check(int(table[k]["price"]) > int(table[u["look"]]["price"]), "%s : plus cher que son modèle" % k)
		t.check(Loot.is_valid(Uniques.item_of(k)), "%s : objet d'inventaire valide" % k)
	t.eq(Uniques.alias_layer("weapon_u_epee_corbeau"), "weapon_epee", "calque emprunté")
	t.eq(Uniques.alias_layer("torso_mailles"), "torso_mailles", "calque ordinaire inchangé")
	t.check(int(Data.WPN["u_epee_corbeau"]["max"]) > int(Data.WPN["epee"]["max"]), "épée unique plus forte")
	# équipé sur un homme : les stats de l'unique s'appliquent (sans toucher à eff)
	var u := Unit.new()
	u.weapon = "epee"
	u.head = "none"
	u.body = "tunique"
	var removed: Array = Loot.equip(u, Uniques.item_of("u_cotte_nuit"))
	t.eq(u.body, "u_cotte_nuit", "cotte équipée")
	t.eq(u.arm_b, 165, "armure de l'unique")
	t.eq(u.body_armor_max(), 165, "armure max")
	t.eq(removed.size(), 1, "tunique rendue")
	Loot.equip(u, Uniques.item_of("u_epee_corbeau"))
	t.eq(u.weapon_data()["hit"], 15, "bonus de toucher fixe")


func test_marche_rare() -> void:
	var found: bool = false
	for seed_value in range(1, 40):
		var g: Node = _game(seed_value)
		for s in g.world.settlements:
			var rare: Array = s["rare"]
			if rare.is_empty():
				continue
			found = true
			t.check(rare.size() >= 2 and rare.size() <= 3, "stock limité (2 à 3 objets)")
			for r in rare:
				t.check(Uniques.is_unique(str(r["item"]["key"])), "article unique")
				t.check(int(r["price"]) >= 1000, "prix élevé")
			# achat
			g.location = s["id"]
			g.gold = 20000
			var key: String = str(rare[0]["item"]["key"])
			var n: int = rare.size()
			var inv: int = g.inventory.size()
			t.check(g.buy_rare(0), "achat chez le marchand rare")
			t.eq(s["rare"].size(), n - 1, "stock réduit")
			t.eq(g.inventory.size(), inv + 1, "objet en inventaire")
			t.check(g.campaign["uniques_taken"].has(key), "unique noté comme sorti")
			t.check(not Campaign.rare_stock(s, g.day + 1, g.campaign["uniques_taken"]).any(func(r: Dictionary) -> bool: return r["item"]["key"] == key), "ne ressort plus")
			g.gold = 0
			if not s["rare"].is_empty():
				t.check(not g.buy_rare(0), "pas assez d'or")
			# rechargement
			var g2: Node = _reload(g)
			t.eq(g2.world.settlement_by_id(s["id"])["rare"].size(), s["rare"].size(), "stock sérialisé")
			break
		if found:
			break
	t.check(found, "au moins un marchand rare sur 40 cartes")


# --- C) Arcs de contrats ---

func test_arc_trois_etapes() -> void:
	var g: Node = _game(31, 400)
	var home: Dictionary = {}
	var arc_id: String = ""
	# on cherche une offre d'arc dans une ville (le tirage dépend du jour) : on force des réassortiments
	for attempt in 40:
		for s in g.world.settlements:
			if s["kind"] == "city":
				g.day += 1
				g._restock(s)
				for a in g.campaign["arcs"]:
					if g.campaign["arcs"][a]["phase"] == "posted":
						home = g.world.settlement_by_id(str(g.campaign["arcs"][a]["origin_id"]))
						arc_id = str(a)
		if arc_id != "":
			break
	t.check(arc_id != "", "un arc est proposé")
	if arc_id == "":
		return
	g.location = home["id"]
	var idx: int = -1
	for i in home["contracts"].size():
		if home["contracts"][i].get("arc", "") == arc_id:
			idx = i
	t.check(idx >= 0, "contrat d'arc dans la ville")
	var pays: Array = []
	var employer_town: String = str(home["name"])
	for step in 3:
		if step > 0:
			idx = -1
			for i in home["contracts"].size():
				var c: Dictionary = home["contracts"][i]
				if c.get("arc", "") == arc_id and int(c["arc_step"]) == step:
					idx = i
			t.check(idx >= 0, "étape %d débloquée chez le même employeur" % (step + 1))
			if idx < 0:
				return
		t.eq(home["contracts"][idx]["origin"], employer_town, "même ville employeuse")
		pays.append(int(home["contracts"][idx]["pay"]))
		t.check(g.accept_contract(idx), "étape %d acceptée" % (step + 1))
		t.eq(g.campaign["arcs"][arc_id]["phase"], "taken", "étape prise")
		g.leave_settlement()
		g.start_battle(g.active_contract)
		var gold0: int = g.gold
		_win(g)
		t.check(g.gold >= gold0 + pays[step], "prime de l'étape versée")
		t.check(g.active_contract.is_empty(), "contrat terminé")
		g.location = home["id"]
	t.check(pays[0] < pays[1] and pays[1] < pays[2], "primes croissantes")
	t.eq(g.campaign["arcs"][arc_id]["phase"], "done", "arc terminé")
	t.eq(g.campaign["arcs"][arc_id]["log"].size(), 3, "récit de chaque étape")
	t.check(g.campaign["log"].size() == 1, "récit final consigné")
	var has_unique: bool = false
	for it in g.inventory:
		if Uniques.is_unique(str(it["key"])):
			has_unique = true
	t.check(has_unique, "objet unique offert à la fin de l'arc")
	t.eq(Campaign.arc_summary(g.campaign)[0]["phase"], "done", "résumé de l'arc")
	var g2: Node = _reload(g)
	t.eq(g2.campaign["arcs"][arc_id]["phase"], "done", "arc sérialisé")


func test_arc_echec_reproposé() -> void:
	var g: Node = _game(31, 400)
	var home: Dictionary = {}
	var arc_id: String = ""
	for attempt in 40:
		for s in g.world.settlements:
			if s["kind"] == "city":
				g.day += 1
				g._restock(s)
				for a in g.campaign["arcs"]:
					home = g.world.settlement_by_id(str(g.campaign["arcs"][a]["origin_id"]))
					arc_id = str(a)
		if arc_id != "":
			break
	if arc_id == "":
		t.check(false, "un arc est proposé")
		return
	g.location = home["id"]
	var idx: int = -1
	for i in home["contracts"].size():
		if home["contracts"][i].get("arc", "") == arc_id:
			idx = i
	g.accept_contract(idx)
	g.abandon_contract()
	t.eq(g.campaign["arcs"][arc_id]["phase"], "posted", "abandon : l'étape redevient disponible")
	var back: bool = false
	for c in home["contracts"]:
		if c.get("arc", "") == arc_id:
			back = true
	t.check(back, "contrat d'arc reproposé")
	# un contrat d'arc survit à la sauvegarde avec des types corrects
	var g2: Node = _reload(g)
	for c in g2.world.settlement_by_id(home["id"])["contracts"]:
		if c.get("arc", "") == arc_id:
			t.eq(typeof(c["arc_step"]), TYPE_INT, "arc_step entier après chargement")


# --- D) Menace et crise finale ---

func test_menace_monte_et_escalade() -> void:
	var g: Node = _game(41)
	var parties0: int = g.world.parties.size()
	t.check(float(g.campaign["threat"]) == 0.0, "menace nulle au départ")
	g.advance_time(30.0)
	t.check(float(g.campaign["threat"]) > 10.0, "la menace monte avec le temps")
	t.check(float(g.campaign["threat"]) < 25.0 or int(g.campaign["stage"]) >= 1, "palier 1 si 25 atteint")
	g.gold = 999999
	g.advance_time(90.0)
	t.check(int(g.campaign["stage"]) >= 2, "paliers d'escalade franchis")
	t.check(g.world.parties.size() >= parties0, "des bandes en plus")
	var big: Node = _game(42, 800)
	big.advance_time(60.0)
	t.check(float(big.campaign["threat"]) > float(g.campaign["threat"]) * 0.5, "le renom accélère la menace")


func test_contrat_final_et_ecran_de_fin() -> void:
	var g: Node = _game(43, 700)
	g.campaign["threat"] = 49.0
	t.eq(g.campaign["final"], "locked", "contrat final fermé")
	g.advance_time(3.0)
	t.eq(g.campaign["final"], "open", "contrat final ouvert (renom + menace)")
	var cit: Dictionary = Campaign.final_site(g.world)
	t.check(not cit.is_empty() and cit["faction"] == g.campaign["faction"], "citadelle sur la carte")
	var waves: Array = Campaign.citadel_waves(g.campaign["faction"])
	t.eq(waves.size(), 3, "trois vagues")
	t.check(waves[2].has("orc_chef") or waves[2].has("necro"), "le chef à la dernière vague")
	# assaut en trois vagues
	g.gold = 0
	t.check(g.engage_site(cit["id"]), "assaut de la citadelle")
	t.eq(g.battle.contract["wave"], 0, "vague 1")
	_win(g)
	t.check(g.battle != null and g.battle.contract["wave"] == 1, "la vague 2 enchaîne")
	t.eq(g.gold, 0, "pas de prime avant la fin")
	_win(g)
	t.check(g.battle != null and g.battle.contract["wave"] == 2, "la vague 3 enchaîne")
	t.eq(g.campaign["final"], "open", "pas encore gagné")
	_win(g)
	t.eq(g.battle, null, "fin des vagues")
	t.eq(g.campaign["final"], "won", "campagne gagnée")
	t.check(g.ending_pending(), "écran de fin demandé")
	t.eq(g.gold, int(Campaign.SITE_TYPES["citadel"]["pay"]), "grosse prime")
	var st: Dictionary = g.ending_stats()
	t.check(st["day"] == g.day and st["men"] == g.roster.size(), "récapitulatif")
	# la sauvegarde garde l'écran de fin en attente
	t.check(_reload(g).ending_pending(), "écran de fin sérialisé")
	g.continue_free()
	t.check(not g.ending_pending() and g.campaign["free_mode"], "mode libre")
	var threat: float = float(g.campaign["threat"])
	g.advance_time(20.0)
	t.check(float(g.campaign["threat"]) == threat, "plus de menace en mode libre")


func test_defaite_de_vague_laisse_la_citadelle() -> void:
	var g: Node = _game(44, 700)
	g.campaign["threat"] = 100.0
	g.advance_time(1.0)
	t.eq(g.campaign["final"], "open", "menace 100 : contrat final ouvert d'office")
	var cit: Dictionary = Campaign.final_site(g.world)
	g.engage_site(cit["id"])
	g.battle.over = "retreat"
	g.finish_battle()
	t.eq(g.campaign["final"], "open", "retraite : la citadelle reste à prendre")
	t.eq(cit["state"], "hostile", "citadelle toujours hostile")
	t.eq(g.battle, null, "pas de vague suivante après une retraite")
