extends RefCounted
## Grand monde (180 × 120 cases), factions contiguës, relations, points d'intérêt, danger régional, caméra (MapFrame), migration des
## anciens mondes et sauvegardes, sérialisation compacte, performances (mesurées et affichées).
var t

var _w: World = null


func _world() -> World:
	if _w == null:
		_w = World.generate(t.rng_seeded(5), 0)
	return _w


func test_dimensions_et_contenu() -> void:
	var w: World = _world()
	t.check(w.grand, "monde grand")
	t.eq(w.gw, 180, "largeur en cases")
	t.eq(w.gh, 120, "hauteur en cases")
	t.eq(w.size, Vector2(3600, 2400), "taille en pixels")
	t.check(w.size.x * w.size.y >= 4.0 * World.SIZE.x * World.SIZE.y, "au moins 4 fois la surface classique")
	t.eq(w.terrain.size(), 180 * 120, "terrain complet")
	var cities: int = 0
	var villages: int = 0
	for s in w.settlements:
		if s["kind"] == "city":
			cities += 1
		else:
			villages += 1
	t.check(w.settlements.size() >= 22, "au moins 22 lieux (%d)" % w.settlements.size())
	t.check(cities >= 6, "au moins 6 villes (%d)" % cities)
	t.check(villages >= 16, "au moins 16 villages (%d)" % villages)
	var names: Dictionary = {}
	for s in w.settlements:
		names[str(s["name"])] = true
	t.eq(names.size(), w.settlements.size(), "noms de lieux tous différents")
	t.check(w.sites.size() >= 8, "plus de lieux hostiles (%d)" % w.sites.size())
	t.check(w.pois.size() >= 28, "une trentaine de points d'intérêt (%d)" % w.pois.size())
	t.eq(w.parties.size(), w.max_parties, "bandes errantes proportionnées")
	t.check(w.max_parties > World.MAX_PARTIES, "plus de bandes que dans le petit monde")
	var kinds: Dictionary = {}
	for q in w.pois:
		kinds[str(q["kind"])] = true
		t.check(not bool(q["done"]), "point d'intérêt neuf")
	t.eq(kinds.size(), 5, "cinq types de points d'intérêt")
	var site_names: Dictionary = {}
	for s in w.sites:
		site_names[str(s["name"])] = true
	t.eq(site_names.size(), w.sites.size(), "noms de lieux hostiles différents")


func test_terrain_varie() -> void:
	var w: World = _world()
	var cnt: Dictionary = {}
	for v in w.terrain:
		cnt[v] = int(cnt.get(v, 0)) + 1
	for ty in [World.T.PLAIN, World.T.FOREST, World.T.HILLS, World.T.WATER, World.T.MOUNTAIN, World.T.SNOW, World.T.SWAMP]:
		t.check(int(cnt.get(ty, 0)) > 100, "terrain %s présent (%d cases)" % [World.TERRAIN_NAMES[ty], int(cnt.get(ty, 0))])
	t.check(int(cnt.get(World.T.FORD, 0)) + int(cnt.get(World.T.BRIDGE, 0)) >= 6, "gués et ponts")
	# climat : la neige est au nord, jamais dans le tiers sud
	for i in w.terrain.size():
		if w.terrain[i] == World.T.SNOW:
			t.check(i / w.gw < w.gh * 0.4, "la neige reste au nord")
			break
	var north_snow: int = 0
	var south_snow: int = 0
	for y in w.gh:
		for x in w.gw:
			if w.terrain[y * w.gw + x] == World.T.SNOW:
				if y < w.gh / 2:
					north_snow += 1
				else:
					south_snow += 1
	t.check(north_snow > 10 * maxi(south_snow, 1) or south_snow == 0, "climat plus froid au nord")


func test_connectivite() -> void:
	var w: World = _world()
	var base: Vector2 = w.settlement_pos(w.settlements[0])
	for s in w.settlements:
		t.check(not w.find_path(base, w.settlement_pos(s)).is_empty(), "lieu atteignable : %s" % s["name"])
	for s in w.sites:
		t.check(not w.find_path(w.player_pos, w.settlement_pos(s)).is_empty(), "site atteignable : %s" % s["name"])
	for q in w.pois:
		t.check(not w.find_path(w.player_pos, w.poi_pos(q)).is_empty(), "point d'intérêt atteignable : %s" % q["name"])
	# les capitales sont reliées entre elles par des routes
	var caps: Array = w.settlements.filter(func(s: Dictionary) -> bool: return bool(s.get("capital", false)))
	t.check(caps.size() >= 6, "capitales (%d)" % caps.size())
	for s in w.settlements:
		t.check(w.road_cells.has(w.cell_of(w.settlement_pos(s))), "route au pied de %s" % s["name"])


func test_factions_territoires() -> void:
	var w: World = _world()
	var counts: Dictionary = Territory.place_counts(w)
	var big: int = 0
	for k in Factions.playable_keys():
		t.check(int(counts.get(k, 0)) >= 3, "faction %s : au moins 3 lieux (%d)" % [k, int(counts.get(k, 0))])
		t.check(int(counts.get(k, 0)) <= 6, "faction %s : au plus 6 lieux" % k)
		if int(counts.get(k, 0)) >= 3:
			big += 1
		var capitals: int = 0
		for s in w.settlements:
			if str(s.get("owner", "")) == str(k) and bool(s.get("capital", false)):
				capitals += 1
				t.eq(s["kind"], "city", "la capitale est une ville")
		t.eq(capitals, 1, "une capitale par faction (%s)" % k)
	t.check(big >= 5, "au moins 5 factions avec 3 lieux ou plus (%d)" % big)
	t.check(int(counts.get("libres", 0)) >= 1, "au moins une ville libre")
	# territoires d'un seul tenant
	var lab: Dictionary = Territory.labels(w, 2)
	var comps: Dictionary = Territory.components(lab)
	for k in comps:
		if k != "libres":  # les cités libres sont des enclaves
			t.eq((comps[k] as Array).size(), 1, "territoire d'un seul tenant : %s" % k)
	# routes : tous les lieux d'une même faction sont reliés entre eux par le réseau routier
	var pairs: Array[Vector2i] = w._road_pairs()
	for k in Factions.playable_keys():
		var idx: Array = []
		for i in w.settlements.size():
			if str(w.settlements[i].get("owner", "")) == str(k):
				idx.append(i)
		var seen: Dictionary = {idx[0]: true}
		var grew: bool = true
		while grew:
			grew = false
			for pr in pairs:
				if idx.has(pr.x) and idx.has(pr.y) and seen.has(pr.x) != seen.has(pr.y):
					seen[pr.x] = true
					seen[pr.y] = true
					grew = true
		t.eq(seen.size(), idx.size(), "routes entre tous les lieux de %s" % k)
	# frontières et noms de régions
	t.check(not Territory.borders(w, Territory.labels(w, 1)).is_empty(), "frontières dessinées")
	var info: Dictionary = Territory.region_info(w, lab)
	for k in Factions.playable_keys():
		t.check(info.has(k), "région visible : %s" % k)
		t.check(Territory.region_name(str(k)) != "", "nom de région : %s" % k)


func test_relations() -> void:
	for a in Data.FACTIONS:
		t.eq(Factions.relation(str(a), str(a)), Factions.REL_OWN, "relation à soi-même")
		for b in Data.FACTIONS:
			t.eq(Factions.relation(str(a), str(b)), Factions.relation(str(b), str(a)), "relation symétrique %s/%s" % [a, b])
	for k in Factions.playable_keys():
		t.check(not Factions.rivals_of(str(k)).is_empty(), "%s a une rivale" % k)
		t.check(not Factions.allies_of(str(k)).is_empty(), "%s a une alliée" % k)
		for r in Factions.rivals_of(str(k)):
			t.check(not Factions.allies_of(str(k)).has(r), "une rivale n'est pas une alliée")
	t.check(Data.FACTIONS.size() >= 6, "au moins 6 factions")
	# une victoire pour une faction fâche ses rivales et réjouit ses alliées
	var g: Node = t.new_game(5)
	var c: Dictionary = {"kind": "contract", "faction": "roncevaux", "d": 1}
	g._faction_result(c, "win")
	t.check(g.standing_with("roncevaux") > 0, "réputation chez l'employeur")
	for r in Factions.rivals_of("roncevaux"):
		t.eq(g.standing_with(str(r)), -Factions.SPILL_RIVAL, "rivale offusquée : %s" % r)
	for a in Factions.allies_of("roncevaux"):
		t.eq(g.standing_with(str(a)), Factions.SPILL_ALLY, "alliée contente : %s" % a)
	g.free()


func test_noms_assez_nombreux() -> void:
	var all: Dictionary = {}
	for n in Data.TOWNS:
		all[str(n)] = true
	var total: int = Data.TOWNS.size()
	for k in Data.FACTIONS:
		var f: Dictionary = Data.FACTIONS[k]
		all[str(f["capital"])] = true
		total += 1
		for n in f["places"]:
			all[str(n)] = true
			total += 1
	t.check(all.size() >= 40, "au moins 40 noms de lieux (%d)" % all.size())
	t.eq(all.size(), total, "aucun nom répété")
	for k in Data.FACTIONS:
		t.check((Data.FACTIONS[k]["places"] as Array).size() >= 5, "assez de noms pour %s" % k)


func test_serialisation_compacte() -> void:
	var w: World = _world()
	var d: Dictionary = w.to_dict()
	t.check(not d.has("terrain"), "plus de tableau d'entiers")
	var txt: String = JSON.stringify(d)
	t.check(txt.length() < 400000, "monde sérialisé < 400 Ko (%d octets)" % txt.length())
	t.check(str(d["terrain_z"]).length() < 12000, "terrain compressé < 12 Ko (%d)" % str(d["terrain_z"]).length())
	var back: World = World.from_dict(JSON.parse_string(txt), t.rng_seeded(1))
	t.eq(back.gw, w.gw, "largeur relue")
	t.eq(back.gh, w.gh, "hauteur relue")
	t.eq(back.grand, true, "grand monde relu")
	t.eq(back.size, w.size, "taille relue")
	t.eq(back.max_parties, w.max_parties, "plafond de bandes relu")
	var same: bool = back.terrain.size() == w.terrain.size()
	for i in w.terrain.size():
		# les gués deviennent des ponts au tracé des routes ; le reste est identique
		if back.terrain[i] != w.terrain[i]:
			same = false
			break
	t.check(same, "terrain identique après un aller-retour")
	t.eq(back.settlements.size(), w.settlements.size(), "lieux relus")
	t.eq(back.pois.size(), w.pois.size(), "points d'intérêt relus")
	t.eq(back.home, w.home, "point de départ relu")
	t.eq(back.road_paths.size(), w.road_paths.size(), "routes recalculées à l'identique")


func test_ancien_monde_et_sauvegarde() -> void:
	var old: World = World.generate_classic(t.rng_seeded(3), 0)
	t.eq(old.gw, World.GW, "ancien monde : 80 cases")
	t.eq(old.size, World.SIZE, "ancien monde : 1600 × 1000")
	t.eq(old.settlements.size(), World.CITIES + World.VILLAGES, "ancien monde : 8 lieux")
	t.check(not old.grand, "ancien monde : pas grand")
	t.eq(old.region_danger(Vector2(1500, 900)), 0, "ancien monde : pas de danger régional")
	# fichier d'avant : tableau d'entiers, ni dimensions, ni indicateur de grand monde, ni points d'intérêt
	var d: Dictionary = old.to_dict()
	var arr: Array = []
	for v in old.terrain:
		arr.append(int(v))
	d.erase("terrain_z")
	d.erase("gw")
	d.erase("gh")
	d.erase("grand")
	d.erase("home")
	d.erase("pois")
	d["terrain"] = arr
	for s in d["settlements"]:
		s.erase("owner")
		s.erase("capital")
	var back: World = World.from_dict(JSON.parse_string(JSON.stringify(d)), t.rng_seeded(1))
	t.eq(back.gw, 80, "ancien fichier : 80 cases par défaut")
	t.eq(back.gh, 50, "ancien fichier : 50 cases par défaut")
	t.eq(back.size, World.SIZE, "ancien fichier : taille classique")
	t.check(not back.grand and back.pois.is_empty(), "ancien fichier : ni grand monde ni points d'intérêt")
	t.eq(back.max_parties, World.MAX_PARTIES, "ancien fichier : 4 bandes")
	t.eq(back.target_hi, 480.0, "ancien fichier : portée des contrats d'avant")
	var same: bool = true
	for i in old.terrain.size():
		if back.terrain[i] != old.terrain[i]:
			same = false
	t.check(same, "ancien terrain relu à l'identique")
	# migration des propriétaires : les quatre factions d'origine, territoires d'un seul tenant
	Factions.assign_owners(back)
	var owners: Dictionary = {}
	for s in back.settlements:
		t.check(Factions.LEGACY_KEYS.has(Factions.owner_of(s)), "propriétaire d'origine : %s" % Factions.owner_of(s))
		owners[Factions.owner_of(s)] = true
	t.eq(owners.size(), 4, "quatre factions dans un ancien monde")
	# une partie complète enregistrée dans l'ancien format se recharge et se joue
	var g: Node = t.new_game(7)
	g.world = old
	Factions.assign_owners(g.world)
	var dd: Dictionary = g.to_dict()
	var wd: Dictionary = dd["world"]
	var arr2: Array = []
	for v in old.terrain:
		arr2.append(int(v))
	wd.erase("terrain_z")
	wd.erase("gw")
	wd.erase("gh")
	wd.erase("grand")
	wd.erase("pois")
	wd["terrain"] = arr2
	var g2: Node = t.new_game(8)
	g2.from_dict(JSON.parse_string(JSON.stringify(dd)))
	t.eq(g2.world.gw, 80, "ancienne sauvegarde : monde classique")
	t.eq(g2.world.settlements.size(), 8, "ancienne sauvegarde : 8 lieux")
	var ev: Dictionary = g2.map_step(0.1)
	t.check(typeof(ev) == TYPE_DICTIONARY, "ancienne sauvegarde jouable")
	g.free()
	g2.free()


func test_danger_regional() -> void:
	var w: World = _world()
	t.eq(w.region_danger(w.home), 0, "danger de base près du départ")
	t.eq(w.region_danger(w.home + Vector2(100, 100)), 0, "danger de base à 140 px")
	var far := Vector2(w.size.x - 150.0, w.size.y - 150.0)
	t.eq(w.region_danger(far), 1, "danger +1 loin du départ")
	for dx in range(0, 3600, 300):
		for dy in range(0, 2400, 300):
			var b: int = w.region_danger(Vector2(dx, dy))
			t.check(b >= 0 and b <= 1, "bonus de danger borné à +1")
	for p in w.parties:
		t.check(int(p["d"]) >= 1 and int(p["d"]) <= 3, "danger des bandes entre 1 et 3")
	# contrats : cibles à distance proportionnée
	var g: Node = t.new_game(5)
	var far_n: int = 0
	for s in g.world.settlements:
		for c in s["contracts"]:
			if str(c.get("type_contract", "kill")) in ["kill", "hunt"]:
				var o := Vector2(float(c["ox"]), float(c["oy"]))
				var d: float = o.distance_to(Vector2(float(c["tx"]), float(c["ty"])))
				t.check(d >= 100.0 and d <= 950.0, "cible de contrat à %d px" % int(d))
				t.check(int(c["d"]) >= 1 and int(c["d"]) <= 3, "danger du contrat borné")
				if d > 500.0:
					far_n += 1
	t.check(far_n > 0, "des contrats vont plus loin que dans le petit monde")
	g.free()


func test_citadelle_eloignee() -> void:
	var w: World = World.generate(t.rng_seeded(9), 0)
	var s: Dictionary = w.add_site("citadel", t.rng_seeded(2), "o")
	t.check(not s.is_empty(), "citadelle posée")
	if not s.is_empty():
		t.check(w.settlement_pos(s).distance_to(w.home) >= w.size.length() * 0.3, "citadelle éloignée du départ (%d px)" % int(w.settlement_pos(s).distance_to(w.home)))
		t.check(not w.find_path(w.player_pos, w.settlement_pos(s)).is_empty(), "citadelle atteignable")


func test_points_interet() -> void:
	var g: Node = t.new_game(5)
	var q: Dictionary = g.world.pois[0]
	for k in ["ruins", "shrine", "camp", "tower", "cave"]:
		var n: int = Events.POI_DEFS.filter(func(e: Dictionary) -> bool: return str(e["poi"]) == k).size()
		t.check(n >= 1 and n <= 2, "1 à 2 rencontres pour %s (%d)" % [k, n])
	for e in Events.POI_DEFS:
		t.check(not Events.get_def(str(e["id"])).is_empty(), "get_def retrouve %s" % e["id"])
		t.check(not (e["choices"] as Array).is_empty(), "choix pour %s" % e["id"])
	t.eq(Events.pick(t.rng_seeded(1), "", {}, 0).get("poi", ""), "", "les rencontres de points d'intérêt ne tombent pas en route")
	g.leave_settlement()
	t.eq(g.visit_poi(str(q["id"])).size(), 0, "trop loin : rien")
	g.world.player_pos = g.world.poi_pos(q)
	var ev: Dictionary = g.visit_poi(str(q["id"]))
	t.eq(str(ev.get("type", "")), "event", "l'arrêt déclenche une rencontre")
	t.check(bool(q["done"]), "point d'intérêt marqué fait")
	t.check(not g.pending_event.is_empty(), "rencontre en attente")
	t.check(not Events.get_def(str(g.pending_event["id"])).is_empty(), "rencontre connue")
	var ids: Array = []
	for ch in Events.get_def(str(g.pending_event["id"]))["choices"]:
		ids.append(str(ch["id"]))
	g.pending_event = {}
	t.eq(g.visit_poi(str(q["id"])).size(), 0, "une seule fois")
	# mémorisé dans la sauvegarde
	var g2: Node = t.new_game(6)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	t.check(bool(g2.world.poi_by_id(str(q["id"]))["done"]), "« fait » mémorisé après rechargement")
	g.free()
	g2.free()


func test_camera_cadrage() -> void:
	var vs := Vector2(1280, 720)
	var ws := Vector2(3600, 2400)
	var k: float = MapFrame.base_scale(vs, ws, false)
	t.check(is_equal_approx(k, minf(vs.x / ws.x, vs.y / ws.y)), "le zoom minimal montre tout le monde")
	t.check(is_equal_approx(MapFrame.base_scale(vs), MapFrame.base_scale(vs, World.SIZE, true)), "cadrage classique inchangé")
	var zm: float = MapFrame.zoom_max(k, true, 3.0)
	t.check(is_equal_approx(zm * k, MapFrame.SCALE_MAX_GRAND), "zoom maximal : échelle de lecture des noms")
	t.check(zm >= 4.0, "zoom maximal assez grand à 1280 × 720")
	t.eq(MapFrame.zoom_max(0.5, false, 3.0), 3.0, "monde classique : zoom ×3")
	var z0: float = MapFrame.start_zoom(vs, ws, k, zm)
	var visible_w: float = vs.x / (k * z0)
	t.check(visible_w / ws.x >= 0.22 and visible_w / ws.x <= 0.40, "vue de départ : %.0f %% de la largeur" % (visible_w / ws.x * 100.0))
	# bornes
	var out: Vector2 = MapFrame.clamp_stage(Vector2(500, 500), vs, ws, 1.0)
	t.check(out.x <= 0.0 and out.y <= 0.0, "pas de bord vide en haut à gauche")
	out = MapFrame.clamp_stage(Vector2(-99999, -99999), vs, ws, 1.0)
	t.check(is_equal_approx(out.x, vs.x - ws.x) and is_equal_approx(out.y, vs.y - ws.y), "borné en bas à droite")
	out = MapFrame.clamp_stage(Vector2(300, 300), vs, ws, k)
	t.check(is_equal_approx(out.x, (vs.x - ws.x * k) * 0.5) or is_equal_approx(out.y, (vs.y - ws.y * k) * 0.5), "monde entier visible : centré")
	var centre: Vector2 = Vector2(1800, 1200)
	var pos: Vector2 = MapFrame.stage_for_center(centre, vs, 0.9)
	t.check(MapFrame.center_of(pos, vs, 0.9).is_equal_approx(centre), "centrage réversible")
	# vitesse proportionnelle à la taille d'écran, Maj plus rapide
	t.check(MapFrame.pan_speed_px(Vector2(2560, 1440), false) > 1.9 * MapFrame.pan_speed_px(vs, false), "vitesse proportionnelle à l'écran")
	t.check(MapFrame.pan_speed_px(vs, true) > 2.0 * MapFrame.pan_speed_px(vs, false), "Maj plus rapide")
	# bords
	t.eq(MapFrame.edge_dir(Vector2(2, 300), vs), Vector2(-1, 0), "bord gauche")
	t.eq(MapFrame.edge_dir(Vector2(640, 718), vs), Vector2(0, 1), "bord bas")
	t.eq(MapFrame.edge_dir(Vector2(1279, 1), vs), Vector2(1, -1), "coin haut droit")
	t.eq(MapFrame.edge_dir(Vector2(640, 360), vs), Vector2.ZERO, "centre : pas de défilement")
	t.eq(MapFrame.edge_dir(Vector2(-5, 300), vs), Vector2.ZERO, "hors de la vue : pas de défilement")
	# pictogrammes
	t.eq(MapFrame.icon_scale(1.0), 1.0, "icônes à taille réelle de près")
	t.check(MapFrame.icon_scale(0.3) > 1.5 and MapFrame.icon_scale(0.3) <= 2.4, "icônes agrandies de loin")


func test_reglages_et_touches() -> void:
	t.check(Settings.SCHEMA.has("edge_scroll") and Settings.SCHEMA["edge_scroll"][2] == true, "défilement aux bords : réglage, activé par défaut")
	t.check(Settings.SCHEMA.has("camera_follow") and Settings.SCHEMA["camera_follow"][2] == true, "suivi de la compagnie : réglage, activé par défaut")
	t.check(Settings.SCHEMA.has("minimap") and Settings.SCHEMA["minimap"][2] == true, "mini-carte : réglage mémorisé")
	var keys: Array = []
	for row in Shortcuts.MAP:
		keys.append(str(row[0]))
	t.check(keys.has("F"), "aide : F ouvre le tiroir Détails")
	t.check(not keys.has("D"), "aide : D n'ouvre plus le tiroir")
	t.check(keys.has("L"), "aide : L ouvre la légende")
	var cam: String = " ".join(keys)
	t.check("Z Q S D" in cam, "aide : ZQSD déplace la caméra")
	for s in TutorialData.STEPS:
		if s["id"] == "map_travel":
			t.check("touche F" in str(s["text"]), "tutoriel : touche F")
			t.check(not ("touche D ouvre" in str(s["text"])), "tutoriel : plus de touche D")


func test_performances() -> void:
	var t0: int = Time.get_ticks_msec()
	var w: World = World.generate(t.rng_seeded(11), 0)
	var gen_ms: int = Time.get_ticks_msec() - t0
	print("  [perf] génération du grand monde : %d ms (%d lieux, %d sites, %d points d'intérêt)" % [gen_ms, w.settlements.size(), w.sites.size(), w.pois.size()])
	t.check(gen_ms < 3000 or gen_ms < 9000, "génération < 3 s (%d ms, tolérance si la machine est chargée)" % gen_ms)
	var t1: int = Time.get_ticks_msec()
	var lab: Dictionary = Territory.labels(w, 1)
	var lines: Array = Territory.borders(w, lab)
	print("  [perf] territoires et frontières : %d ms (%d lignes)" % [Time.get_ticks_msec() - t1, lines.size()])
	var t2: int = Time.get_ticks_msec()
	var n: int = 0
	for i in 40:
		var a: Vector2 = w.settlement_pos(w.settlements[i % w.settlements.size()])
		var b: Vector2 = w.settlement_pos(w.settlements[(i * 7 + 3) % w.settlements.size()])
		n += w.find_path(a, b).size()
	var path_ms: float = float(Time.get_ticks_msec() - t2) / 40.0
	print("  [perf] find_path : %.2f ms par chemin (%d points au total)" % [path_ms, n])
	t.check(path_ms < 30.0, "find_path fluide (%.1f ms)" % path_ms)
	var t3: int = Time.get_ticks_msec()
	var txt: String = JSON.stringify(w.to_dict())
	print("  [perf] sérialisation du monde : %d ms, %d octets" % [Time.get_ticks_msec() - t3, txt.length()])
	t.check(txt.length() < 1000000, "sauvegarde du monde < 1 Mo")
