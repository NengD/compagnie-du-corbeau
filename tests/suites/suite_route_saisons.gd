extends RefCounted
## Saisons (core/seasons.gd) et rencontres de route à choix (core/road_encounters.gd).
var t


func _roster(n: int = 4) -> Array:
	var out: Array = []
	for i in n:
		out.append(t.mk())
	return out


# --- Saisons ---

func test_season_calc() -> void:
	t.eq(Seasons.season_of(1), Seasons.SPRING, "jour 1 : printemps")
	t.eq(Seasons.season_of(30), Seasons.SPRING, "jour 30 : printemps")
	t.eq(Seasons.season_of(31), Seasons.SUMMER, "jour 31 : été")
	t.eq(Seasons.season_of(61), Seasons.AUTUMN, "jour 61 : automne")
	t.eq(Seasons.season_of(91), Seasons.WINTER, "jour 91 : hiver")
	t.eq(Seasons.season_of(121), Seasons.SPRING, "l'année se répète")
	t.eq(Seasons.season_of(0), Seasons.SPRING, "jour 0 toléré")
	t.eq(Seasons.name_of(100), "Hiver", "nom")
	t.eq(Seasons.day_in_season(31), 1, "premier jour de saison")
	t.check(Seasons.tooltip(95).contains("Hiver"), "infobulle")


func test_season_effects() -> void:
	t.check(Seasons.travel_mult(100) < 1.0, "hiver plus lent")
	t.check(Seasons.travel_mult(40) > 1.0, "été plus rapide")
	t.check(Seasons.food_need(100, 8) > 8, "hiver : plus de rations")
	t.eq(Seasons.food_need(40, 8), 8, "été : rations normales")
	t.check(Seasons.food_price_mult(70) < 1.0, "automne : vivres moins chers")
	var snow_w: int = 0
	var snow_s: int = 0
	var rain_sp: int = 0
	var rain_su: int = 0
	for d in range(1, 3000):
		var w: String = MapFx.weather_for_day(d)
		t.check(w in ["clear", "rain", "fog", "snow"], "météo valide")
		match Seasons.season_of(d):
			Seasons.WINTER:
				snow_w += 1 if w == "snow" else 0
			Seasons.SUMMER:
				snow_s += 1 if w == "snow" else 0
				rain_su += 1 if w == "rain" else 0
			Seasons.SPRING:
				rain_sp += 1 if w == "rain" else 0
	t.check(snow_w > 100, "neige fréquente en hiver (%d)" % snow_w)
	t.eq(snow_s, 0, "pas de neige en été")
	t.check(rain_sp > rain_su, "plus de pluie au printemps qu'en été")


func test_season_travel_and_food() -> void:
	var cost: Array = []
	for d in [40, 100]:  # été puis hiver : même durée de marche
		var g: Node = t.new_game(8)
		g.leave_settlement()
		g.day = d
		var p0: Vector2 = g.world.player_pos
		var tgt: Vector2 = g.world.random_target(p0, 300.0, 600.0)
		t.check(g.world.set_destination(tgt, {"kind": "free"}), "destination")
		g.map_step(0.5)
		cost.append(p0.distance_to(g.world.player_pos))
	t.check(cost[0] > cost[1], "on parcourt plus de chemin en été qu'en hiver (%.1f > %.1f)" % [cost[0], cost[1]])
	var eaten: Array = []
	for d in [39, 99]:
		var g2: Node = t.new_game(9)
		g2.leave_settlement()
		g2.day = d
		g2.provisions = 100
		g2.advance_time(1.0)
		eaten.append(100 - g2.provisions)
	t.check(eaten[1] > eaten[0], "l'hiver consomme plus de vivres (%d > %d)" % [eaten[1], eaten[0]])
	var g3: Node = t.new_game(10)
	g3.day = 70
	var autumn_price: int = g3.food_cost(10)
	g3.day = 40
	t.check(autumn_price < g3.food_cost(10), "vivres moins chers en automne")


# --- Rencontres ---

func _all_choices() -> Array:
	var out: Array = []
	for e in RoadEncounters.DEFS:
		for c in e["choices"]:
			out.append([e, c])
	return out


func test_encounter_content() -> void:
	t.check(RoadEncounters.DEFS.size() >= 6, "au moins 6 rencontres inédites (%d)" % RoadEncounters.DEFS.size())
	var ids: Dictionary = {}
	for e in RoadEncounters.DEFS:
		t.check(not ids.has(e["id"]) and Events.DEFS.filter(func(x: Dictionary) -> bool: return x["id"] == e["id"]).is_empty(), "id unique " + str(e["id"]))
		ids[e["id"]] = true
		t.check(Events.get_def(str(e["id"])) == e, "get_def retrouve " + str(e["id"]))
		t.check((e["choices"] as Array).size() >= 3, "au moins trois choix : " + str(e["id"]))
		for c in e["choices"]:
			var pools: Array = [c["win"], c["lose"]] if c.has("check") else [c["outcomes"]]
			for pool in pools:
				t.check(not (pool as Array).is_empty(), "issues " + str(c["id"]))
				for o in pool:
					for k in o:
						t.check(["w", "text", "gold", "hp_all", "hp_one", "renown", "days", "battle", "food", "morale", "standing", "xp_all"].has(k), "effet connu " + str(k))
					if o.has("battle"):
						t.check(Data.FACTION_NAMES.has(o["battle"]["type"]), "faction du combat")
			if c.has("check"):
				t.check(RoadEncounters.KINDS.has(c["check"]["kind"]), "type de test connu")


func test_chances_bounded() -> void:
	var rosters: Array = [[], _roster(1), _roster(8)]
	var strong: Unit = t.mk()
	strong.resolve = 200
	strong.initiative = 300
	rosters.append([strong])
	var weak: Unit = t.mk()
	weak.resolve = 1
	weak.initiative = 1
	rosters.append([weak])
	for r in rosters:
		for st in [-10, 0, 10]:
			var ctx: Dictionary = RoadEncounters.context(r, st, st)
			for pair in _all_choices():
				var c: Dictionary = pair[1]
				if not c.has("check"):
					continue
				var p: int = RoadEncounters.chance(c["check"], ctx)
				var s: int = RoadEncounters.shown_chance(c["check"], ctx)
				t.check(p >= RoadEncounters.CHANCE_MIN and p <= RoadEncounters.CHANCE_MAX, "chance bornée (%d)" % p)
				t.check(s >= RoadEncounters.CHANCE_MIN and s <= RoadEncounters.CHANCE_MAX and s % RoadEncounters.CHANCE_STEP == 0, "chance affichée bornée (%d)" % s)
				var d: Dictionary = RoadEncounters.describe(c, ctx)
				t.check(str(d["label"]).contains("environ %d %%" % s), "libellé avec la chance")
				if int(c.get("cost", 0)) > 0:
					t.check(str(d["label"]).contains("couronnes"), "libellé avec le coût")


func test_chance_depends_on_roster() -> void:
	var nego: Dictionary = {"kind": "negotiate", "base": 50}
	var firm: Unit = t.mk()
	firm.resolve = 80
	var meek: Unit = t.mk()
	meek.resolve = 30
	t.check(RoadEncounters.chance(nego, RoadEncounters.context([firm])) > RoadEncounters.chance(nego, RoadEncounters.context([meek])), "la détermination aide à négocier")
	t.check(RoadEncounters.chance(nego, RoadEncounters.context([meek], 8, 0)) > RoadEncounters.chance(nego, RoadEncounters.context([meek], -8, 0)), "la réputation aide")
	var social: Unit = t.mk()
	social.resolve = 30
	social.traits = ["sociable"]
	t.check(RoadEncounters.chance(nego, RoadEncounters.context([social])) > RoadEncounters.chance(nego, RoadEncounters.context([meek])), "un trait aide")
	var bribe: Dictionary = {"kind": "bribe", "base": 90}
	t.check(RoadEncounters.chance(bribe, RoadEncounters.context([firm])) >= 90, "soudoyer : presque sûr")
	var flee: Dictionary = {"kind": "flee", "base": 50}
	var fast: Unit = t.mk()
	fast.initiative = 130
	var slow: Unit = t.mk()
	slow.initiative = 70
	t.check(RoadEncounters.chance(flee, RoadEncounters.context([fast])) > RoadEncounters.chance(flee, RoadEncounters.context([slow])), "l'initiative aide à fuir")
	var trap: Dictionary = {"kind": "trap", "base": 45}
	var hunter: Unit = t.mk()
	hunter.perks = ["oeil_sur"]
	var trap_choice: Dictionary = {"id": "x", "label": "Piège", "requires": "hunter", "check": trap}
	t.check(RoadEncounters.locked_reason(trap_choice, RoadEncounters.context([firm])) != "", "piège impossible sans chasseur")
	t.eq(RoadEncounters.locked_reason(trap_choice, RoadEncounters.context([firm, hunter])), "", "piège possible avec un tireur")
	t.check(RoadEncounters.chance(trap, RoadEncounters.context([hunter])) > RoadEncounters.chance(trap, RoadEncounters.context([firm])), "un chasseur améliore le piège")


func test_resolve_deterministic_with_rng() -> void:
	var ctx: Dictionary = RoadEncounters.context(_roster(3), 2, 1)
	var a: Dictionary = Events.resolve("r_barrage", "talk", t.rng_seeded(5), ctx)
	var b: Dictionary = Events.resolve("r_barrage", "talk", t.rng_seeded(5), ctx)
	t.eq(a, b, "même graine, même issue")
	t.check(a.has("success") and a.has("chance"), "issue marquée réussite/échec")
	var wins: int = 0
	var r: RandomNumberGenerator = t.rng_seeded(1)
	for i in 400:
		if bool(Events.resolve("r_barrage", "bribe", r, ctx)["success"]):
			wins += 1
	t.check(wins > 320, "soudoyer réussit presque toujours (%d/400)" % wins)


func test_all_road_encounters_resolve() -> void:
	for e in RoadEncounters.DEFS:
		for c in e["choices"]:
			for with_hunter in [false, true]:
				var g: Node = t.new_game(5)
				g.gold = 1000
				g.leave_settlement()
				if with_hunter:
					g.roster[0].perks.append("oeil_sur")
				g.pending_event = {"id": e["id"]}
				var locked: bool = RoadEncounters.locked_reason(c, g.event_ctx()) != ""
				var res: Dictionary = g.resolve_event(str(c["id"]))
				if locked:
					t.check(not bool(res["ok"]), "choix verrouillé refusé %s/%s" % [e["id"], c["id"]])
					t.check(not g.pending_event.is_empty(), "la rencontre reste en attente")
				else:
					t.check(bool(res["ok"]), "résolution %s/%s" % [e["id"], c["id"]])
					t.check(g.pending_event.is_empty(), "rencontre résolue")
				g.free()


func test_flee_failure_starts_battle() -> void:
	var found: bool = false
	for sd in 40:
		var g: Node = t.new_game(12)
		g.leave_settlement()
		g.rng.seed = sd
		g.pending_event = {"id": "r_fosse"}
		var res: Dictionary = g.resolve_event("flee")
		if bool(res["ok"]) and res["success"] == false:
			t.check(bool(res["battle"]) and g.battle != null, "échec de la fuite : embuscade subie")
			found = true
		g.free()
		if found:
			break
	t.check(found, "un échec de fuite a été observé")
