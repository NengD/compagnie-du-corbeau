extends RefCounted
## Carte du monde : rivières, gués, ponts, routes, connexité, lumière, météo, territoires, anciennes sauvegardes.
var t


func _world(seed_value: int) -> World:
	return World.generate(t.rng_seeded(seed_value), 0)


func test_terrain_nouveaux_types() -> void:
	t.eq(World.COST.size(), World.TERRAIN_NAMES.size(), "un coût et un nom par terrain")
	t.eq(World.COST[World.T.BRIDGE], 0.9, "coût d'un pont")
	t.eq(World.COST[World.T.FORD], 2.0, "coût d'un gué")
	t.eq(World.ROAD_COST, 0.8, "coût d'une route")


func test_rivieres_gues_et_connexite() -> void:
	var fords: int = 0
	var water: int = 0
	for sd in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		var w: World = _world(sd)
		for v in w.terrain:
			if v == World.T.FORD or v == World.T.BRIDGE:
				fords += 1
			elif v == World.T.WATER:
				water += 1
		for s in w.settlements:
			t.check(not w.find_path(w.settlement_pos(w.settlements[0]), w.settlement_pos(s)).is_empty(), "graine %d : %s atteignable" % [sd, s["name"]])
		for s in w.sites:
			t.check(w.passable(w.settlement_pos(s)), "lieu hostile accessible")
	t.check(fords > 0, "des gués ou ponts existent")
	t.check(water > 0, "de l'eau existe")


func test_routes_plus_rapides() -> void:
	var w: World = _world(3)
	t.check(w.road_paths.size() > 0 and w.road_cells.size() > 0, "des routes existent")
	var c: Vector2i = w.road_cells.keys()[0]
	var p := Vector2((c.x + 0.5) * World.CELL, (c.y + 0.5) * World.CELL)
	t.check(w.is_road(p), "case de route reconnue")
	t.check(w.cost_at(p) <= World.ROAD_COST + 0.0001, "coût de route appliqué")
	t.eq(w.terrain_label(p) in ["Route", "Pont"], true, "infobulle : route ou pont")
	# régénération identique : routes recalculées au chargement
	var w2: World = World.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())), t.rng_seeded(1))
	t.eq(w2.road_cells.size(), w.road_cells.size(), "routes recalculées au chargement")
	t.eq(w2.terrain, w.terrain, "terrain inchangé au chargement")


func test_vieille_sauvegarde_sans_routes() -> void:
	var w: World = _world(4)
	var d: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	var w2: World = World.from_dict(d, t.rng_seeded(1))
	for s in w2.settlements:
		t.check(not w2.find_path(w2.player_pos, w2.settlement_pos(s)).is_empty(), "monde chargé connexe")


func test_lumiere_et_meteo() -> void:
	var dawn: Dictionary = MapFx.light_at(0.0)
	var day: Dictionary = MapFx.light_at(0.3)
	var night: Dictionary = MapFx.light_at(0.9)
	t.check(float(night["night"]) > 0.9 and float(day["night"]) == 0.0, "niveau de nuit")
	t.check((night["mul"] as Color).b > (night["mul"] as Color).r, "nuit bleutée")
	t.check((dawn["mul"] as Color).r > (dawn["mul"] as Color).b, "aube dorée")
	t.eq(MapFx.light_at(1.0)["mul"], MapFx.light_at(0.0)["mul"], "cycle continu")
	for d in 60:
		t.eq(MapFx.weather_for_day(d), MapFx.weather_for_day(d), "météo déterministe")
		t.check(MapFx.weather_for_day(d) in ["clear", "rain", "fog", "snow"], "météo valide")
	var fx := MapFx.new()
	fx.night = 1.0
	t.eq(fx.vision_scale(), 0.75, "vue réduite de 25 % la nuit")
	fx.night = 0.0
	t.eq(fx.vision_scale(), 1.0, "vue normale le jour")


func test_territoires() -> void:
	var w: World = _world(5)
	var owners: Array = ["a", "b"]
	for i in w.settlements.size():
		w.settlements[i]["owner"] = owners[i % 2]
	var terr: Dictionary = MapPlaces.territories(w)
	t.check(terr["cells"].size() == w.settlements.size(), "une zone par lieu")
	t.check(terr["edges"].size() > 0, "des frontières entre factions")
	for s in w.settlements:
		s.erase("owner")
	t.check(MapPlaces.territories(w)["cells"].is_empty(), "sans propriétaire : carte inchangée")


func test_reglages_carte() -> void:
	var s: Node = load("res://autoload/Settings.gd").new()
	t.check(s.day_night and s.weather_fx and s.map_anim, "jour/nuit, météo et animations activés par défaut")
	s.free()
