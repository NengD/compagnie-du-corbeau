extends RefCounted
## Monde et campagne : nouvelles factions, types de contrats, événements de route, réputation, sérialisation.
var t


func _game(seed_value: int, renown: int = 0) -> Node:
	var g: Node = load("res://autoload/Game.gd").new()
	g.autosave = false
	g.random_events = false
	g.new_game(seed_value)
	g.renown = renown
	return g


func test_factions_orcs_morts_vivants() -> void:
	var r: RandomNumberGenerator = t.rng_seeded(5)
	for key in ["orc_jeune", "orc_guerrier", "berserker", "orc_chef", "squelette", "squelette_archer", "zombie", "necro"]:
		var u: Unit = Contracts.make_foe(key, r)
		t.check(u.side == "e" and u.faction in ["o", "u"], "%s : faction %s" % [key, u.faction])
		t.check(Data.WPN.has(u.weapon), "%s : arme connue" % key)
		t.check(u.hp > 0 and u.hp_max > 0, "%s : PV" % key)
	t.check(Contracts.make_foe("orc_chef", r).leader and Contracts.make_foe("necro", r).leader, "chefs orc et nécromant")
	t.check(Contracts.make_foe("squelette_archer", r).weapon_data()["ranged"], "squelette archer à l'arc")
	t.check(Contracts.make_foe("zombie", r).weapon == "griffes", "zombie : griffes")
	t.check(Contracts.make_foe("orc_guerrier", r).hp_max > Contracts.make_foe("brigand", r).hp_max, "orc plus robuste qu'un brigand")
	for ty in ["b", "g", "o", "u"]:
		for d in [1, 2, 3]:
			var foes: Array = Contracts.foes_for(ty, d)
			t.check(foes.size() >= 3 and foes.size() <= Data.FIGHTERS, "effectif %s danger %d" % [ty, d])
			for k in foes:
				t.eq(Data.FOE[k]["fac"], ty, "%s appartient à la faction %s" % [k, ty])
		t.check(Data.TARGET_NAMES.has(ty) and Data.FACTION_PARTY_TITLES.has(ty), "textes de la faction " + ty)
	t.check(Contracts.foes_for("o", 3).has("orc_chef") and Contracts.foes_for("u", 3).has("necro"), "chef au danger 3")


func test_ia_et_bataille_nouvelles_factions() -> void:
	var g: Node = _game(2)
	for ty in ["o", "u"]:
		var c: Dictionary = {"kind": "contract", "type": ty, "d": 2, "foes": Contracts.foes_for(ty, 2), "title": "x", "pay": 0}
		var b: BattleState = BattleState.create(c, g.roster, t.rng_seeded(9))
		var n: int = 0
		while b.over == "" and b.round_no < 120 and n < 6000:
			var u: Unit = b.next_turn()
			if u == null:
				break
			b.play_ai_turn(u)
			n += 1
		t.check(b.over == "win" or b.over == "lose", "bataille contre la faction %s terminée (over=%s)" % [ty, b.over])
	g.free()


func test_apparition_des_bandes_selon_le_renom() -> void:
	var low: Array = Contracts.factions_for(0)
	t.check(not low.has("o") and not low.has("u"), "ni orcs ni morts-vivants au début")
	t.check(Contracts.factions_for(200).has("u") and not Contracts.factions_for(200).has("o"), "morts-vivants dès 200")
	t.check(Contracts.factions_for(350).has("o"), "orcs dès 350")
	var g: Node = _game(4, 500)
	g.world.parties.clear()
	g.world.fill_parties(500, 40)
	var seen: Dictionary = {}
	for p in g.world.parties:
		seen[p["faction"]] = true
		t.eq(bool(p["aggressive"]), p["faction"] == "b" or p["faction"] == "o", "agressivité de la faction " + str(p["faction"]))
		t.check(g.world.party_title(p) != "", "titre de bande")
	t.check(seen.size() >= 3, "plusieurs factions sur la carte à 500 de renom")
	g.free()


func test_types_de_contrats() -> void:
	var kinds: Dictionary = {}
	for seed_value in range(60, 72):
		var g: Node = _game(seed_value, 400)
		for s in g.world.settlements:
			t.eq(s["contracts"][0]["type_contract"], "kill", "premier contrat classique")
			for c in s["contracts"]:
				var tc: String = c["type_contract"]
				kinds[tc] = true
				t.check(c["biome"] in ["plain", "forest", "hills", "water"], "biome renseigné (%s)" % c["biome"])
				t.eq(c["origin_id"], s["id"], "origine du contrat")
				if tc == "hunt":
					t.eq((c["foes"] as Array).count(Data.FACTION_LEADER[c["type"]]), 1, "un seul chef")
					t.eq(c["foes"][0], Data.FACTION_LEADER[c["type"]], "le chef est la cible")
					t.check(c["foes"].size() <= 2 + c["d"], "escorte réduite")
				elif tc == "escort" or tc == "delivery":
					t.check(c["dest_id"] != s["id"], "destination différente de l'origine")
					t.check(g.world.settlement_by_id(c["dest_id"])["name"] == c["target_name"], "cible = ville de destination")
					t.check(float(c["ambush_at"]) == -1.0 or (float(c["ambush_at"]) >= 0.3 and float(c["ambush_at"]) <= 0.7), "point d'embuscade")
					t.check(c["pay"] > 0, "prime de transport")
		g.free()
	for k in ["kill", "hunt", "escort", "delivery"]:
		t.check(kinds.has(k), "type de contrat généré : " + k)


func _first_of(g: Node, kind: String) -> int:
	var s: Dictionary = g.settlement()
	for i in s["contracts"].size():
		if s["contracts"][i]["type_contract"] == kind:
			return i
	return -1


func _transport_game(ambush: bool) -> Node:
	for seed_value in range(100, 200):
		var g: Node = _game(seed_value)
		g.world.parties.clear()
		for s in g.world.settlements:
			g.location = s["id"]
			var i: int = _first_of(g, "delivery")
			if i >= 0 and (float(s["contracts"][i]["ambush_at"]) >= 0.0) == ambush:
				return g
		g.free()
	return null


func test_livraison_sans_embuscade() -> void:
	var g: Node = _transport_game(false)
	t.check(g != null, "livraison sans embuscade trouvée")
	if g == null:
		return
	var i: int = _first_of(g, "delivery")
	t.check(g.accept_contract(i), "livraison acceptée")
	var c: Dictionary = g.active_contract
	var origin_id: String = c["origin_id"]
	var gold0: int = g.gold
	g.leave_settlement()
	g.world.set_destination(g.contract_target(), {"kind": "target"})
	var ev: Dictionary = {}
	var guard: int = 0
	while ev.get("type", "") == "" and guard < 800:
		ev = g.map_step(0.25)
		guard += 1
	t.eq(ev.get("type", ""), "settlement", "arrivée en ville de destination")
	t.eq(g.location, c["dest_id"], "on est dans la ville cible")
	t.check(g.active_contract.is_empty(), "contrat terminé")
	t.check(g.gold > gold0 - g.wages() * (g.day - 1) and g.gold >= gold0 - g.wages() * 40 + int(c["pay"]) - 1, "prime versée à l'arrivée")
	t.eq(g.world.standing_of(g.world.settlement_by_id(origin_id)), 2, "réputation +2 chez le client")
	g.free()


func test_livraison_avec_embuscade() -> void:
	var g: Node = _transport_game(true)
	t.check(g != null, "livraison avec embuscade trouvée")
	if g == null:
		return
	t.check(g.accept_contract(_first_of(g, "delivery")), "livraison acceptée")
	var origin_id: String = g.active_contract["origin_id"]
	g.leave_settlement()
	g.world.set_destination(g.contract_target(), {"kind": "target"})
	var ev: Dictionary = {}
	var guard: int = 0
	while ev.get("type", "") == "" and guard < 800:
		ev = g.map_step(0.25)
		guard += 1
	t.eq(ev.get("type", ""), "ambush", "embuscade en route")
	t.check(float(g.active_contract["ambush_at"]) >= 0.0 and g.active_contract["ambush_done"], "embuscade marquée comme jouée")
	g.engage_ambush()
	t.check(g.battle != null and g.battle.contract["kind"] == "ambush", "bataille d'embuscade")
	# défaite : le contrat est perdu
	for u in g.battle.units:
		if u.side == "p":
			u.dead = true
	g.battle.check_end()
	g.finish_battle()
	t.check(g.active_contract.is_empty(), "contrat perdu après la défaite")
	t.eq(g.world.standing_of(g.world.settlement_by_id(origin_id)), -1, "réputation −1 après l'échec")
	g.free()


func test_embuscade_gagnee_ne_paie_pas() -> void:
	var g: Node = _transport_game(true)
	if g == null:
		return
	g.accept_contract(_first_of(g, "delivery"))
	g.leave_settlement()
	var gold0: int = g.gold
	g.engage_ambush()
	for u in g.battle.units:
		if u.side == "e":
			u.morale = 0
	g.battle.check_end()
	g.finish_battle()
	t.check(not g.active_contract.is_empty(), "le contrat continue après une embuscade repoussée")
	t.eq(g.gold, gold0, "pas de prime avant l'arrivée")
	g.free()


func test_chasse_au_chef_et_reputation() -> void:
	var g: Node = _game(70, 300)
	var found: bool = false
	for seed_value in range(70, 120):
		g.free()
		g = _game(seed_value, 300)
		var i: int = _first_of(g, "hunt")
		if i >= 0:
			found = true
			var c: Dictionary = g.settlement()["contracts"][i]
			g.accept_contract(i)
			g.leave_settlement()
			g.start_battle(g.active_contract)
			for u in g.battle.units:
				if u.side == "e":
					u.morale = 0
			g.battle.check_end()
			var gold0: int = g.gold
			g.finish_battle()
			t.eq(g.gold, gold0 + int(c["pay"]), "prime de la chasse au chef")
			t.eq(g.world.standing_of(g.world.settlement_by_id(c["origin_id"])), 3, "réputation +3 pour une chasse")
			break
	t.check(found, "chasse au chef trouvée")
	g.free()


func test_reputation_prix_et_contrats() -> void:
	var g: Node = _game(7)
	var s: Dictionary = g.settlement()
	var base: int = g.price_of(100)
	g.world.change_standing(s["id"], 10)
	t.check(g.price_of(100) < base, "bonne réputation : prix plus bas")
	t.check(g.price_of(100) >= int(round(base * 0.89)), "remise bornée à 10 %")
	g.world.change_standing(s["id"], 50)
	t.eq(g.world.standing_of(s), 10, "réputation bornée à +10")
	g.world.change_standing(s["id"], -100)
	t.eq(g.world.standing_of(s), -10, "réputation bornée à −10")
	t.check(g.price_of(100) > base, "mauvaise réputation : prix plus hauts")
	# nombre de contrats
	g.world.settlements[0]["standing"] = 6
	g._restock(g.world.settlements[0])
	t.check(g.world.settlements[0]["contracts"].size() >= 2, "bonne réputation : plus de contrats")
	g.world.settlements[0]["standing"] = -6
	g._restock(g.world.settlements[0])
	t.check(g.world.settlements[0]["contracts"].size() <= 2, "mauvaise réputation : moins de contrats")
	# abandon
	g.world.settlements[0]["standing"] = 0
	g._restock(g.world.settlements[0])
	g.accept_contract(0)
	g.abandon_contract()
	t.eq(g.world.standing_of(g.world.settlements[0]), -2, "abandon : −2")
	g.free()


func test_evenements_donnees() -> void:
	t.check(Events.DEFS.size() >= 10 and Events.DEFS.size() <= 14, "10 à 14 événements (%d)" % Events.DEFS.size())
	var ids: Dictionary = {}
	for e in Events.DEFS:
		t.check(not ids.has(e["id"]), "id unique " + e["id"])
		ids[e["id"]] = true
		t.check(e["choices"].size() >= 2 and e["choices"].size() <= 3, "2-3 choix : " + e["id"])
		for c in e["choices"]:
			t.check(not (c["outcomes"] as Array).is_empty(), "issues de %s/%s" % [e["id"], c["id"]])
			for o in c["outcomes"]:
				t.check(str(o.get("text", "")) != "", "texte d'issue")
				if o.has("recruit") and o["recruit"] != "random":
					t.check(Data.BG.has(o["recruit"]), "origine de recrue connue")
				if o.has("battle"):
					t.check(Data.FOE.has(Data.FACTION_LEADER[o["battle"]["type"]]), "faction de combat connue")
	var r: RandomNumberGenerator = t.rng_seeded(1)
	var out: Dictionary = Events.resolve("toll", "ford", r)
	t.check(out.has("days"), "résolution pure")
	t.eq(Events.resolve("inconnu", "x", r), {}, "événement inconnu")
	var days: int = 0
	var r2: RandomNumberGenerator = t.rng_seeded(3)
	for i in 1000:
		if Events.roll_day(r2, 5):
			days += 1
	t.check(days > 120 and days < 320, "fréquence des événements (%d/1000)" % days)
	t.check(not Events.roll_day(r2, 1), "jamais deux jours de suite")


func test_evenement_en_route() -> void:
	var g: Node = _game(21)
	g.random_events = true
	g.world.parties.clear()
	g.leave_settlement()
	var seen: bool = false
	for k in 400:
		g.world.set_destination(g.world.random_target(g.world.player_pos, 120.0, 300.0), {"kind": "point"})
		var guard: int = 0
		while not g.world.path.is_empty() and guard < 100:
			var ev: Dictionary = g.map_step(0.3)
			guard += 1
			if ev.get("type", "") == "event":
				seen = true
				t.check(not g.pending_event.is_empty(), "événement en attente")
				t.eq(g.map_step(1.0), {}, "le temps est en pause pendant l'événement")
				var day0: int = g.day
				g.map_step(5.0)
				t.eq(g.day, day0, "aucun jour ne passe tant que le choix n'est pas fait")
				break
		if seen:
			break
	t.check(seen, "un événement survient en route")
	if seen:
		# round-trip de la sauvegarde avec événement en attente
		var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
		var g2: Node = load("res://autoload/Game.gd").new()
		g2.autosave = false
		g2.from_dict(d)
		t.eq(g2.pending_event, g.pending_event, "événement en attente sauvegardé")
		t.eq(g2.last_event_day, g.last_event_day, "dernier jour d'événement sauvegardé")
		g2.free()
		var def: Dictionary = Events.get_def(g.pending_event["id"])
		var pick_id: String = ""
		for c in def["choices"]:
			if int(c.get("cost", 0)) == 0:
				pick_id = c["id"]
				break
		g.gold = 5000
		var res: Dictionary = g.resolve_event(pick_id)
		t.check(res["ok"], "choix appliqué")
		t.check(g.pending_event.is_empty() or g.battle != null, "événement résolu")
		t.check(not g.resolve_event(pick_id)["ok"], "un événement ne se résout qu'une fois")
	g.free()


func test_evenement_jamais_en_ville() -> void:
	var g: Node = _game(8)
	g.random_events = true
	for i in 200:
		t.eq(g.map_step(1.0), {}, "pas de déplacement ni d'événement en ville")
	g.free()


func test_effets_evenements() -> void:
	var g: Node = _game(9)
	g.leave_settlement()
	g.pending_event = {"id": "merchant"}
	g.gold = 100
	g.roster[0].hp = 10
	var res: Dictionary = g.resolve_event("food")
	t.check(res["ok"], "provisions achetées")
	t.eq(g.gold, 65, "35 couronnes dépensées")
	t.eq(g.roster[0].hp, 20, "+10 PV")
	g.pending_event = {"id": "merchant"}
	g.gold = 10
	t.check(not g.resolve_event("food")["ok"], "pas assez d'or")
	t.check(not g.pending_event.is_empty(), "l'événement reste en attente")
	g.pending_event = {"id": "deserter"}
	var n: int = g.roster.size()
	var seen_recruit: bool = false
	for k in 30:
		g.pending_event = {"id": "deserter"}
		var before: int = g.roster.size()
		g.resolve_event("hire")
		if g.roster.size() > before:
			seen_recruit = true
		if g.roster.size() >= Data.MAX_ROSTER:
			break
	t.check(seen_recruit, "le déserteur peut rejoindre la compagnie")
	g.free()


func test_biome_et_carte() -> void:
	var g: Node = _game(12)
	var seen: Dictionary = {}
	for y in range(0, World.SIZE.y, 20.0):
		for x in range(0, World.SIZE.x, 20.0):
			seen[g.world.biome_at(Vector2(x + 5, y + 5))] = true
	for k in seen:
		t.check(k in ["plain", "forest", "hills", "water"], "biome valide " + k)
	t.check(seen.has("plain") and seen.size() >= 2, "plusieurs biomes sur la carte")
	g.free()


func test_sauvegarde_ancienne_sans_monde_recent() -> void:
	var g: Node = _game(13)
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	for s in d["world"]["settlements"]:
		s.erase("standing")
	for k in ["pending_event", "last_event_day", "last_event_id"]:
		d.erase(k)
	var c: Dictionary = d["active_contract"]
	var g2: Node = load("res://autoload/Game.gd").new()
	g2.autosave = false
	g2.from_dict(d)
	t.eq(g2.world.standing_of(g2.world.settlements[0]), 0, "réputation par défaut")
	t.check(g2.pending_event.is_empty(), "pas d'événement en attente")
	var old: Dictionary = Contracts.normalize({"kind": "contract", "type": "b", "d": 2, "pay": 700, "tx": 10, "ty": 12, "days": 2})
	t.eq(old["type_contract"], "kill", "ancien contrat = éliminer")
	g2.free()
	g.free()
