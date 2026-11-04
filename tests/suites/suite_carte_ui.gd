extends RefCounted
## Carte plein cadre, HUD et bannière de compagnie : logique pure (validation, tirage, application à la nouvelle partie,
## anciennes sauvegardes, cadrage de la carte, libellés du temps). Sans fenêtre.
var t


func test_banner_content_sizes() -> void:
	t.check(Data.BANNER_EMBLEMS.size() >= 10, "au moins 10 emblèmes (%d)" % Data.BANNER_EMBLEMS.size())
	t.check(Data.BANNER_COLORS.size() >= 12, "au moins 12 teintes (%d)" % Data.BANNER_COLORS.size())
	t.eq(Data.BANNER_COLORS.size(), Data.BANNER_COLOR_NAMES.size(), "un nom par teinte")
	t.eq(Data.BANNER_PATTERNS.size(), 5, "cinq motifs de champ")
	t.check(Data.COMPANY_NAME_SUGGESTIONS.size() >= 10, "suggestions de noms")
	for n in Data.COMPANY_NAME_SUGGESTIONS:
		t.check(Banner.is_valid_name(str(n)), "suggestion valide : %s" % n)


func test_pattern_clean() -> void:
	t.eq(Banner.clean({})["pattern"], 0, "motif par défaut : uni")
	t.eq(Banner.clean({"pattern": 3})["pattern"], 3, "motif conservé")
	t.eq(Banner.clean({"pattern": 99})["pattern"], Data.BANNER_PATTERNS.size() - 1, "motif borné en haut")
	t.eq(Banner.clean({"pattern": -4})["pattern"], 0, "motif borné en bas")
	t.eq(Banner.clean("n'importe quoi")["pattern"], 0, "entrée invalide -> défaut")
	t.eq(Banner.pattern({"pattern": 2}), 2, "Banner.pattern")
	t.check(Banner.pattern_color({"primary": "b03a2e"}) != Banner.primary({"primary": "b03a2e"}), "le motif a une teinte distincte")
	t.check(Banner.pattern_color({"primary": "2b2622"}).get_luminance() > Banner.primary({"primary": "2b2622"}).get_luminance(), "champ sombre : motif plus clair")


func test_name_validation() -> void:
	t.check(not Banner.is_valid_name(""), "nom vide invalide")
	t.check(not Banner.is_valid_name("  ab  "), "2 caractères : invalide")
	t.check(Banner.is_valid_name("Les Loups"), "nom normal valide")
	t.check(Banner.is_valid_name("abc"), "3 caractères : valide")
	t.check(Banner.is_valid_name("x".repeat(28)), "28 caractères : valide")
	t.check(not Banner.is_valid_name("x".repeat(29)), "29 caractères : invalide")
	t.eq(Banner.clean_name("x".repeat(80)).length(), 28, "nom borné à 28")


func test_random_banner_and_name() -> void:
	var r1: RandomNumberGenerator = t.rng_seeded(11)
	var r2: RandomNumberGenerator = t.rng_seeded(11)
	var seen: Dictionary = {}
	var rn: RandomNumberGenerator = t.rng_seeded(5)
	for i in 60:
		var a: Dictionary = Banner.random_banner(r1)
		var b: Dictionary = Banner.random_banner(r2)
		t.eq(a, b, "tirage reproductible avec la même graine")
		t.eq(Banner.clean(a), a, "bannière tirée déjà valide")
		t.check(Banner.is_custom(a), "couleur principale toujours choisie")
		t.check(absf(Banner.primary(a).get_luminance() - Banner.secondary(a).get_luminance()) > 0.3, "couleurs contrastées")
		seen["%s%d%d" % [a["primary"], a["emblem"], a["pattern"]]] = true
		var nm: String = Banner.random_name(rn, "Les Loups")
		t.check(Banner.is_valid_name(nm), "nom tiré valide")
	t.check(seen.size() > 20, "le tirage est varié (%d)" % seen.size())
	t.check(Banner.random_name(t.rng_seeded(3), Data.COMPANY_NAME_SUGGESTIONS[0]) != Data.COMPANY_NAME_SUGGESTIONS[0], "ne répète pas le nom exclu")


func test_resolve_setup() -> void:
	var r: Dictionary = Banner.resolve_setup({"name": "   ", "banner": {"primary": "ZZZ", "emblem": 500, "pattern": 77}})
	t.eq(r["name"], Data.COMPANY_NAME_DEFAULT, "nom vide -> nom d'origine")
	t.eq(r["banner"]["emblem"], Data.BANNER_EMBLEMS.size() - 1, "emblème borné")
	t.eq(r["banner"]["pattern"], Data.BANNER_PATTERNS.size() - 1, "motif borné")
	t.eq(r["banner"]["primary"], "", "teinte invalide -> ocre d'origine")
	var ok: Dictionary = Banner.resolve_setup({"name": "  Les Lames Grises ", "banner": {"primary": "3E526A", "secondary": "d8cfb8", "emblem": 8, "pattern": 4}})
	t.eq(ok["name"], "Les Lames Grises", "nom nettoyé")
	t.eq(ok["banner"], {"primary": "3e526a", "secondary": "d8cfb8", "emblem": 8, "pattern": 4}, "bannière normalisée")
	t.eq(Banner.resolve_setup(Banner.default_setup())["name"], Data.COMPANY_NAME_DEFAULT, "fiche par défaut")


func test_apply_to_new_game() -> void:
	var g: Node = t.new_game(21)
	t.eq(g.company_name, Data.COMPANY_NAME_DEFAULT, "nom par défaut")
	t.eq(g.banner, Data.BANNER_DEFAULT, "bannière par défaut")
	g.set_company_identity({"name": "Les Corbeaux de Fer", "banner": {"primary": "b03a2e", "secondary": "d8cfb8", "emblem": 11, "pattern": 2}})
	t.eq(g.company_name, "Les Corbeaux de Fer", "nom appliqué")
	t.eq(g.banner["emblem"], 11, "emblème appliqué")
	t.eq(g.banner["pattern"], 2, "motif appliqué")
	g.set_banner("3e526a", "d8cfb8", 3)
	t.eq(g.banner["pattern"], 2, "set_banner garde le motif quand il n'est pas précisé")
	g.set_banner("3e526a", "d8cfb8", 3, 4)
	t.eq(g.banner["pattern"], 4, "set_banner change le motif")
	g.set_company_identity({"name": "", "banner": {}})
	t.eq(g.company_name, Data.COMPANY_NAME_DEFAULT, "identité vide -> défauts")
	g.set_company_identity({"name": "Autre", "banner": {"primary": "4b5a3a"}})
	g.new_game(22)
	t.eq(g.company_name, Data.COMPANY_NAME_DEFAULT, "nouvelle partie : nom réinitialisé")
	t.eq(g.banner, Data.BANNER_DEFAULT, "nouvelle partie : bannière réinitialisée")
	g.free()


func test_save_roundtrip_and_old_saves() -> void:
	var g: Node = t.new_game(5)
	g.set_company_identity({"name": "La Main Rouge", "banner": {"primary": "6f2f2f", "secondary": "d8cfb8", "emblem": 12, "pattern": 3}})
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = load("res://autoload/Game.gd").new()
	g2.autosave = false
	g2.from_dict(d)
	t.eq(g2.company_name, "La Main Rouge", "nom sauvegardé")
	t.eq(g2.banner, g.banner, "bannière sauvegardée avec son motif")
	# ancienne sauvegarde : bannière sans motif
	var old: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	old["banner"] = {"primary": "b03a2e", "secondary": "d8cfb8", "emblem": 4}
	var g3: Node = load("res://autoload/Game.gd").new()
	g3.autosave = false
	g3.from_dict(old)
	t.eq(g3.banner["pattern"], 0, "ancienne bannière : motif uni")
	t.eq(g3.banner["emblem"], 4, "ancienne bannière : emblème gardé")
	# très ancienne sauvegarde : aucune bannière
	old.erase("banner")
	old.erase("company_name")
	var g4: Node = load("res://autoload/Game.gd").new()
	g4.autosave = false
	g4.from_dict(old)
	t.eq(g4.banner, Data.BANNER_DEFAULT, "sans bannière : défaut")
	t.eq(g4.company_name, Data.COMPANY_NAME_DEFAULT, "sans nom : défaut")
	for x in [g, g2, g3, g4]:
		x.free()


func test_map_framing() -> void:
	var w: Vector2 = World.SIZE
	# 1280×720 : zone de carte plein cadre (marges de 8 px, en-tête compact) ≈ 1264×658
	var k: float = MapFrame.base_scale(Vector2(1264, 658))
	t.check(k >= minf(1264.0 / w.x, 658.0 / w.y) - 0.0001, "échelle au moins égale à « ajuster »")
	t.check(w.x * k >= 1264.0 - 0.01 and w.y * k >= 658.0 - 0.01, "fenêtre large : la carte couvre toute la vue (remplir)")
	# fenêtre très large : on préfère tout montrer (ajuster)
	var wide: float = MapFrame.base_scale(Vector2(2400, 500))
	t.check(is_equal_approx(wide, minf(2400.0 / w.x, 500.0 / w.y)), "ratio extrême : ajuster")
	# fenêtre de même ratio que le monde : identique
	t.check(is_equal_approx(MapFrame.base_scale(Vector2(800, 500)), 0.5), "même ratio : 0,5")
	t.eq(MapFrame.base_scale(Vector2.ZERO), 0.0, "vue vide : échelle nulle")


func test_time_labels() -> void:
	t.eq(MapFx.time_label(0.0), "aube", "aube")
	t.eq(MapFx.time_label(0.2), "matin", "matin")
	t.eq(MapFx.time_label(0.4), "midi", "midi")
	t.eq(MapFx.time_label(0.55), "après-midi", "après-midi")
	t.eq(MapFx.time_label(0.7), "soir", "soir")
	t.eq(MapFx.time_label(0.9), "nuit", "nuit")
	t.eq(MapFx.time_label(1.2), "matin", "fraction bouclée")


func test_banner_pattern_polygons() -> void:
	t.eq(BannerView.pattern_polys(0).size(), 0, "uni : aucune zone")
	for p in range(1, Data.BANNER_PATTERNS.size()):
		t.check(BannerView.pattern_polys(p).size() >= 1, "motif %d : zones définies" % p)
		for ov in BannerView.pattern_polys(p):
			t.check(not Geometry2D.intersect_polygons(BannerView.CLOTH, ov).is_empty(), "motif %d : recouvre l'étoffe" % p)
