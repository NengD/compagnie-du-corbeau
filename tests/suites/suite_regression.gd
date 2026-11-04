extends RefCounted
## Régression : version courte des simulations (tools/sim_battles.gd et tools/sim_campaign.gd).
## Cherche des blocages et des états invalides, pas l'équilibrage.
var t


func test_batailles_ia_variees() -> void:
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	var g: Node = lib.make_game(1)
	for seed_value in 32:
		var r: Dictionary = lib.run_battle(g, seed_value * 7)
		t.check((r["errors"] as Array).is_empty(), "bataille graine %d (%s, %d hommes) : %s" % [seed_value * 7, r["factions"], r["men"], str((r["errors"] as Array).slice(0, 3))])
		t.check(r["over"] == "win" or r["over"] == "lose", "bataille graine %d terminée" % (seed_value * 7))
	g.free()


func test_campagne_courte() -> void:
	var errs: Array[String] = []
	for seed_value in 6:
		errs.append_array(_mini_campaign(seed_value))
	t.check(errs.is_empty(), "campagnes : %s" % str(errs.slice(0, 4)))


## Voyage / contrats / combats / sauvegarde en mémoire, ~25 jours, sans hasard d'événements imprévus.
func _mini_campaign(seed_value: int) -> Array[String]:
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	var g: Node = lib.make_game(seed_value)
	g.random_events = true
	var bot := RandomNumberGenerator.new()
	bot.seed = seed_value + 99
	var errs: Array[String] = []
	var guard: int = 0
	while g.day < 25 and not g.game_over and guard < 800 and errs.is_empty():
		guard += 1
		g.gold = maxi(g.gold, 500)
		if g.battle != null:
			var r: Dictionary = lib.play(g.battle, false)
			errs.append_array(r["errors"])
			if g.battle.over == "":
				g.battle.end_battle("retreat")
			g.finish_battle()
		elif not g.pending_event.is_empty():
			var def: Dictionary = Events.get_def(str(g.pending_event["id"]))
			var res: Dictionary = {"ok": false}
			for c in def["choices"]:
				if int(c.get("cost", 0)) <= g.gold:
					res = g.resolve_event(str(c["id"]))
					break
			if not bool(res["ok"]):
				errs.append("événement %s sans issue" % str(def["id"]))
		elif g.location != "":
			g.repair()
			var s: Dictionary = g.settlement()
			if g.active_contract.is_empty() and s["contracts"].size() > 0:
				g.accept_contract(0)
			g.leave_settlement()
		else:
			if g.world.path.is_empty():
				var ok: bool = false
				if not g.active_contract.is_empty() and not Contracts.is_transport(g.active_contract):
					ok = g.world.set_destination(g.contract_target(), {"kind": "target"})
				if not ok:
					var d: Dictionary = g.world.settlements[bot.randi() % g.world.settlements.size()]
					ok = g.world.set_destination(g.world.settlement_pos(d), {"kind": "settlement", "id": d["id"]})
				if not ok:
					errs.append("aucune route depuis %s" % str(g.world.player_pos))
					break
			var ev: Dictionary = g.map_step(0.5)
			match str(ev.get("type", "")):
				"encounter":
					g.engage_party(int(ev["party"]["id"]))
				"target":
					g.engage_target()
				"ambush":
					g.engage_ambush()
		if g.gold < 0:
			errs.append("or négatif")
		if g.location == "" and not g.world.passable(g.world.player_pos):
			errs.append("terrain impraticable %s" % str(g.world.player_pos))
		for m in g.roster:
			if g.battle == null and (m.hp < 1 or m.hp > m.hp_max):
				errs.append("PV invalides")
		if bot.randf() < 0.1:
			var gold: int = g.gold
			var day: int = g.day
			var men: int = g.roster.size()
			g.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
			if g.gold != gold or g.day != day or g.roster.size() != men:
				errs.append("sauvegarde/chargement incohérent")
	if guard >= 800 and g.day < 25 and not g.game_over:
		errs.append("campagne bloquée")
	g.free()
	return errs
