extends SceneTree
## Simulation de campagnes (30-60 jours) pilotées par un bot aléatoire : voyages, contrats, rencontres, événements,
## achats, ventes, repos, sauvegarde/chargement en mémoire (jamais sur disque : les vraies sauvegardes restent intactes).
##   godot --path . --headless -s res://tools/sim_campaign.gd -- [--count 30] [--seed 0] [--days 45] [--verbose]
## Vérifie des invariants d'état ; code de sortie 1 en cas d'échec. Surveiller aussi « SCRIPT ERROR » dans la sortie.

var lib: RefCounted
var g: Node
var bot := RandomNumberGenerator.new()
var errors: Array[String] = []
var stats: Dictionary = {}
var resilient: bool = false


func _init() -> void:
	var count: int = 30
	var first: int = 0
	var days: int = 45
	var verbose: bool = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--count":
				i += 1
				count = int(args[i])
			"--seed":
				i += 1
				first = int(args[i])
			"--days":
				i += 1
				days = int(args[i])
			"--verbose":
				verbose = true
		i += 1
	lib = load("res://tools/sim_lib.gd").new()
	var t0: int = Time.get_ticks_msec()
	var failures: Array[String] = []
	for n in count:
		var seed_value: int = first + n
		if verbose:
			print("campagne %d" % seed_value)
		errors = []
		run_campaign(seed_value, days)
		if not errors.is_empty():
			failures.append("graine %d : %s" % [seed_value, " | ".join(PackedStringArray(errors.slice(0, 6)))])
	print("\n=== sim_campaign : %d campagnes en %.1f s ===" % [count, (Time.get_ticks_msec() - t0) / 1000.0])
	print("compteurs (informatif) : %s" % str(stats))
	print("échecs : %d" % failures.size())
	for f in failures:
		print("  ✗ " + f)
	quit(0 if failures.is_empty() else 1)


func bump(k: String) -> void:
	stats[k] = int(stats.get(k, 0)) + 1


func fail(msg: String) -> void:
	if errors.size() < 20:
		errors.append("jour %d : %s" % [g.day, msg])


func run_campaign(seed_value: int, max_days: int) -> void:
	g = lib.make_game(seed_value)
	g.random_events = true
	bot.seed = seed_value * 31 + 7
	resilient = seed_value % 2 == 1
	var guard: int = 0
	var day_start: int = g.day
	while g.day - day_start < max_days and not g.game_over and guard < 3000 and errors.is_empty():
		guard += 1
		step()
		check_invariants()
	if guard >= 3000 and g.day - day_start < max_days and not g.game_over:
		fail("campagne bloquée : %d étapes pour %d jours" % [guard, g.day - day_start])
	bump("campagnes")
	stats["jours_total"] = int(stats.get("jours_total", 0)) + g.day - day_start
	if g.game_over:
		bump("game_over")
		if OS.get_cmdline_user_args().has("--verbose"):
			print("  fin jour %d, or %d, news: %s" % [g.day, g.gold, str(g.news)])
	g.free()


func step() -> void:
	if resilient and g.gold < g.wages() * 5:
		g.gold += 500  # mécène : évite la faillite pour que la campagne dure
	if g.battle != null:
		fight()
	elif not g.pending_event.is_empty():
		resolve_event()
	elif g.location != "":
		town()
	else:
		travel()
	if bot.randf() < 0.08:
		save_load_roundtrip()


func fight() -> void:
	var s: BattleState = g.battle
	var r: Dictionary = lib.play(s, false)
	for e in r["errors"]:
		fail("bataille : " + e)
	if s.over == "":
		# plafond atteint : on conclut par une retraite pour poursuivre la campagne
		s.end_battle("retreat")
	var gold0: int = g.gold
	g.finish_battle()
	bump("batailles_" + s.over)
	if g.battle != null:
		fail("finish_battle n'a pas vidé la bataille")
	if g.gold < gold0 and s.over == "win":
		fail("or en baisse après une victoire")
	if resilient and g.roster.size() < 4:
		# renforts miraculeux : la campagne continue (les campagnes « résilientes » durent les 30-60 jours)
		g.game_over = false
		g.gold = maxi(g.gold, 600)
		for k in ["milicien", "bucheron", "braconnier", "fermier"]:
			if g.roster.size() < 6:
				g.roster.append(Contracts.make_merc(k, bot, g._names()))


func resolve_event() -> void:
	var def: Dictionary = Events.get_def(str(g.pending_event["id"]))
	if def.is_empty():
		fail("événement en attente inconnu")
		g.pending_event = {}
		return
	var choices: Array = def["choices"]
	var c: Dictionary = choices[bot.randi() % choices.size()]
	var res: Dictionary = g.resolve_event(str(c["id"]))
	bump("evenements")
	if not bool(res["ok"]):
		# choix trop cher : le dernier choix doit toujours être gratuit, sinon blocage
		for cc in choices:
			if int(cc.get("cost", 0)) <= g.gold:
				res = g.resolve_event(str(cc["id"]))
				break
		if not bool(res["ok"]):
			fail("aucun choix possible pour l'événement %s (or %d)" % [str(def["id"]), g.gold])
			g.pending_event = {}


func town() -> void:
	var s: Dictionary = g.settlement()
	if s.is_empty():
		fail("lieu inconnu : %s" % g.location)
		g.location = ""
		return
	# routine prudente : se soigner, réparer, regarnir la compagnie (pour que les campagnes durent)
	var rests: int = 0
	while g.has_wounded() and rests < 4 and g.gold > g.wages() * 2:
		g.rest()
		rests += 1
	g.repair()
	if g.game_over or g.roster.is_empty():
		return
	while g.roster.size() < 6 and s["recruits"].size() > 0 and int(s["recruits"][0]["price"]) <= g.gold:
		g.hire(0)
		bump("recrues")
	for k in bot.randi_range(0, 5):
		if g.roster.is_empty():
			return
		match bot.randi() % 9:
			0:
				g.rest()
			1:
				g.repair()
			2:
				if s["recruits"].size() > 0:
					bump("recrues")
					g.hire(bot.randi() % s["recruits"].size())
			3:
				var m: Unit = g.roster[bot.randi() % g.roster.size()]
				var kinds: Array = ["weapon", "shield", "head", "body"]
				var kind: String = str(kinds[bot.randi() % 4])
				var shop: Dictionary = Data.SHOPS[s["kind"]]
				var key: String = ""
				if kind != "shield":
					key = str((shop[kind] as Array)[bot.randi() % (shop[kind] as Array).size()])
				g.gold += 300  # le bot est riche : on veut exercer les achats
				if g.buy(m, kind, key):
					bump("achats")
			4:
				if g.inventory.size() > 0:
					g.sell(bot.randi() % g.inventory.size())
					bump("ventes")
			5:
				if g.inventory.size() > 0:
					var m2: Unit = g.roster[bot.randi() % g.roster.size()]
					var ix: int = bot.randi() % g.inventory.size()
					if g.can_equip_from_inventory(m2, ix) and g.equip_from_inventory(m2, ix):
						bump("equipements")
			6:
				if g.active_contract.is_empty() and s["contracts"].size() > 0:
					if g.accept_contract(bot.randi() % s["contracts"].size()):
						bump("contrats")
			7:
				for m3 in g.roster:
					if m3.pending > 0:
						var rolls: Dictionary = g.roll_promotion()
						var keys: Array = rolls.keys()
						keys.shuffle()
						if g.apply_promotion(m3, rolls, keys.slice(0, 3)):
							bump("promotions")
						break
			8:
				for m4 in g.roster:  # dépense les points de talent au hasard
					var pk: Array = Data.PERKS.keys()
					pk.shuffle()
					for pkey in pk:
						if m4.perk_points > 0 and Perks.can_take(m4, str(pkey)):
							g.spend_perks(m4, [str(pkey)])
				if g.roster.size() > 3 and bot.randf() < 0.15:
					g.dismiss(g.roster[bot.randi() % g.roster.size()].id)
	if g.game_over:
		return
	g.leave_settlement()


func travel() -> void:
	# destination : cible du contrat actif, sinon un lieu au hasard
	if g.world.path.is_empty():
		var ok: bool = false
		if not g.active_contract.is_empty() and not Contracts.is_transport(g.active_contract):
			ok = g.world.set_destination(g.contract_target(), {"kind": "target"})
		elif not g.active_contract.is_empty() and Contracts.is_transport(g.active_contract):
			var d: Dictionary = g.world.settlement_by_id(str(g.active_contract["dest_id"]))
			ok = g.world.set_destination(g.world.settlement_pos(d), {"kind": "settlement", "id": d["id"]})
		if not ok:
			var sl: Array = g.world.settlements
			var d2: Dictionary = sl[bot.randi() % sl.size()]
			ok = g.world.set_destination(g.world.settlement_pos(d2), {"kind": "settlement", "id": d2["id"]})
		if not ok:
			# position de départ inatteignable : bug de carte
			fail("aucune route vers aucun lieu depuis %s" % str(g.world.player_pos))
			g.world.player_pos = g.world.settlement_pos(g.world.settlements[0])
			return
	var ev: Dictionary = g.map_step(0.5)
	match str(ev.get("type", "")):
		"encounter":
			bump("rencontres")
			g.engage_party(int(ev["party"]["id"]))
			if g.battle == null:
				fail("engage_party n'a pas lancé de bataille")
		"target":
			g.engage_target()
			if g.battle == null:
				fail("engage_target n'a pas lancé de bataille")
		"ambush":
			g.engage_ambush()
			if g.battle == null:
				fail("engage_ambush n'a pas lancé de bataille")
		"settlement":
			bump("arrivees")
		"over":
			pass


func save_load_roundtrip() -> void:
	bump("sauvegardes")
	var before: Dictionary = {
		"gold": g.gold, "day": g.day, "renown": g.renown, "men": g.roster.size(), "loc": g.location,
		"inv": g.inventory.size(), "contract": str(g.active_contract.get("title", "")), "battle": g.battle != null,
		"event": str(g.pending_event.get("id", "")), "fallen": g.fallen.size(),
	}
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	g.from_dict(d)
	var after: Dictionary = {
		"gold": g.gold, "day": g.day, "renown": g.renown, "men": g.roster.size(), "loc": g.location,
		"inv": g.inventory.size(), "contract": str(g.active_contract.get("title", "")), "battle": g.battle != null,
		"event": str(g.pending_event.get("id", "")), "fallen": g.fallen.size(),
	}
	if before != after:
		fail("sauvegarde/chargement : %s ≠ %s" % [str(before), str(after)])
	var d2: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	if JSON.stringify(d2) != JSON.stringify(d):
		fail("sauvegarde non idempotente après rechargement")


func check_invariants() -> void:
	if g.gold < 0:
		fail("or négatif (%d)" % g.gold)
	if g.roster.size() > Data.MAX_ROSTER:
		fail("compagnie trop grande (%d)" % g.roster.size())
	if g.roster.is_empty() and not g.game_over:
		fail("compagnie vide sans game_over")
	if g.renown < 0:
		fail("renom négatif")
	var ids: Dictionary = {}
	for m in g.roster:
		if ids.has(m.id):
			fail("id d'homme en double %d" % m.id)
		ids[m.id] = true
		if g.battle == null and (m.hp < 1 or m.hp > m.hp_max):
			fail("%s PV %d/%d" % [m.unit_name, m.hp, m.hp_max])
		if m.arm_h < 0 or m.arm_h > m.head_armor_max() or m.arm_b < 0 or m.arm_b > m.body_armor_max():
			fail("%s armure hors bornes (%d/%d, %d/%d)" % [m.unit_name, m.arm_h, m.head_armor_max(), m.arm_b, m.body_armor_max()])
		if m.shield and not bool(m.weapon_data()["h1"]):
			fail("%s bouclier avec une arme à deux mains (%s)" % [m.unit_name, m.weapon])
		if m.level < 1 or m.level > 11 or m.pending < 0:
			fail("%s niveau/promotions invalides" % m.unit_name)
		if m.wage < 0:
			fail("%s solde négative" % m.unit_name)
	if g.location == "" and not g.world.passable(g.world.player_pos):
		fail("compagnie sur un terrain impraticable %s" % str(g.world.player_pos))
	if g.location != "" and g.world.settlement_by_id(g.location).is_empty():
		fail("lieu courant inexistant %s" % g.location)
	for it in g.inventory:
		if not Loot.is_valid(it):
			fail("objet d'inventaire invalide %s" % str(it))
	if not g.active_contract.is_empty():
		var c: Dictionary = g.active_contract
		if not (c.has("foes") and c.has("pay") and c.has("tx")):
			fail("contrat actif incomplet")
		for k in c["foes"]:
			if not Data.FOE.has(str(k)):
				fail("ennemi inconnu dans le contrat : %s" % str(k))
	for p in g.world.parties:
		if not g.world.passable(g.world.party_pos(p)):
			fail("bande errante sur un terrain impraticable %s" % str(g.world.party_pos(p)))
	for s in g.world.settlements:
		for c2 in s["contracts"]:
			if int(c2["pay"]) <= 0 or (c2["foes"] as Array).is_empty():
				fail("contrat invalide à %s" % str(s["name"]))
	if g.day_fraction < 0.0 or g.day_fraction >= 1.0001:
		fail("fraction de jour invalide %f" % g.day_fraction)
