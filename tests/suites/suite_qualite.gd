extends RefCounted
## Qualité graphique : préréglages, bornes, ancien fichier de réglages, suggestion automatique. Sans fenêtre.
var t


func _mk() -> Node:
	var s: Node = load("res://autoload/Settings.gd").new()
	s.persist = false
	return s


func test_presets_table() -> void:
	t.eq(Quality.PRESETS.size(), 4, "quatre préréglages")
	for lv in 4:
		var p: Dictionary = Quality.preset_values(lv)
		for k in Quality.KEYS:
			t.check(p.has(k), "préréglage %d : clé %s" % [lv, k])
		t.eq(Quality.identify(p), lv, "préréglage %d reconnu" % lv)
	t.eq(Quality.PRESETS[0]["msaa"], 0, "Bas : sans MSAA")
	t.eq(Quality.PRESETS[1]["msaa"], 1, "Moyen : 2×")
	t.eq(Quality.PRESETS[3]["msaa"], 2, "Ultra : 4×")
	t.eq(Quality.PRESETS[0]["ground_mode"], 0, "Bas : aplats")
	t.eq(Quality.PRESETS[1]["ground_mode"], 1, "Moyen : textures sans fondus")
	t.eq(Quality.PRESETS[2]["ground_mode"], 2, "Élevé : fondus")
	t.eq(Quality.PARTICLE_FACTORS, [0.0, 0.4, 1.0, 1.5], "densités de particules")
	t.eq(Quality.DECAL_CAPS, [0, 30, 80, 200], "plafonds de décalcomanies")
	t.check(not Quality.PRESETS[1]["map_anim"] and Quality.PRESETS[2]["map_anim"], "ambiance : Moyen off, Élevé on")
	t.check(not Quality.PRESETS[0]["day_night"] and Quality.PRESETS[1]["day_night"], "jour/nuit : Bas off")
	t.eq(Quality.PRESETS[0]["map_tex"], 0, "carte réduite en Bas")
	t.eq(Quality.PRESETS[3]["map_tex"], 2, "carte haute en Ultra")


func test_identify_custom() -> void:
	var p: Dictionary = Quality.preset_values(Quality.HIGH)
	p["shadows"] = 0
	t.eq(Quality.identify(p), Quality.CUSTOM, "un réglage modifié -> Personnalisé")
	t.eq(Quality.nearest(p), Quality.HIGH, "préréglage le plus proche")
	t.eq(Quality.identify({}), Quality.CUSTOM, "valeurs absentes -> Personnalisé")
	t.eq(Quality.scaled_count(240, 0.4), 96, "particules réduites")
	t.eq(Quality.scaled_count(5, 0.0), 0, "densité nulle -> aucune")
	t.eq(Quality.scaled_count(1, 0.4), 1, "au moins une particule si la densité n'est pas nulle")


func test_settings_apply_and_custom() -> void:
	var s: Node = _mk()
	t.eq(s.quality, Quality.HIGH, "défaut : Élevé")
	s.apply_quality(Quality.LOW)
	t.eq(s.quality, Quality.LOW, "Bas appliqué")
	t.eq(s.msaa, 0, "Bas : MSAA coupé")
	t.check(not s.weather_fx and not s.day_night and not s.illustrated_ui and not s.map_anim and not s.screen_shake, "Bas : options existantes pilotées")
	t.eq(Quality.identify(s.detail_values()), Quality.LOW, "valeurs de Bas reconnues")
	s.apply_quality(Quality.ULTRA)
	t.eq(s.msaa, 2, "Ultra : 4×")
	t.check(s.weather_fx and s.weather_level == 2, "Ultra : météo complète")
	s.set_value("shadows", 0)
	t.eq(s.quality, Quality.CUSTOM, "réglage manuel -> Personnalisé")
	s.set_value("shadows", 2)
	t.eq(s.quality, Quality.ULTRA, "retour aux valeurs d'Ultra -> Ultra")
	s.set_value("weather_level", 0)
	t.check(not s.weather_fx, "météo à 0 coupe les effets météo")
	t.eq(s.quality, Quality.CUSTOM, "météo coupée -> Personnalisé")
	s.set_value("weather_level", 1)
	t.check(s.weather_fx, "météo > 0 les rallume")
	s.set_value("quality", 1)
	t.eq(s.quality, Quality.MEDIUM, "clé quality = préréglage")
	t.eq(s.particles, 1, "Moyen : particules à 40 %")
	s.set_value("decals", 99)
	t.eq(s.decals, 3, "décalcomanies bornées")
	s.set_value("map_tex", -4)
	t.eq(s.map_tex, 0, "carte bornée")
	s.reset_defaults()
	t.eq(s.quality, Quality.HIGH, "valeurs par défaut = Élevé")
	s.free()


func test_roundtrip_and_old_file() -> void:
	var s: Node = _mk()
	s.apply_quality(Quality.MEDIUM)
	s.set_value("show_fps", true)
	var c: ConfigFile = s.to_config()
	t.eq(int(c.get_value("video", "quality", -1)), Quality.MEDIUM, "clé quality écrite")
	var s2: Node = _mk()
	s2.from_config(c)
	t.eq(s2.quality, Quality.MEDIUM, "Moyen relu")
	t.check(s2.show_fps, "compteur d'images relu")
	# ancien fichier : aucune clé de qualité, réglages d'avant (MSAA 4× par défaut) -> Personnalisé
	var old := ConfigFile.new()
	old.set_value("video", "msaa", 2)
	old.set_value("game", "weather_fx", true)
	var s3: Node = _mk()
	s3.from_config(old)
	t.eq(s3.quality, Quality.CUSTOM, "ancien MSAA 4× différent d'Élevé -> Personnalisé")
	t.eq(s3.msaa, 2, "réglage existant respecté")
	# ancien fichier sans MSAA ni détails : Élevé
	var old2 := ConfigFile.new()
	old2.set_value("audio", "master", 0.5)
	var s4: Node = _mk()
	s4.from_config(old2)
	t.eq(s4.quality, Quality.HIGH, "ancien fichier sans clé quality -> Élevé")
	# ancien fichier avec météo coupée : Personnalisé, météo respectée
	var old3 := ConfigFile.new()
	old3.set_value("game", "weather_fx", false)
	var s5: Node = _mk()
	s5.from_config(old3)
	t.eq(s5.quality, Quality.CUSTOM, "météo coupée -> Personnalisé")
	t.check(not s5.weather_fx, "météo coupée respectée")
	# valeurs abîmées
	var bad := ConfigFile.new()
	bad.set_value("video", "quality", "énorme")
	bad.set_value("video", "particles", 77)
	var s6: Node = _mk()
	s6.from_config(bad)
	t.eq(s6.particles, 3, "particules bornées")
	for n in [s, s2, s3, s4, s5, s6]:
		n.free()


func test_suggest() -> void:
	t.eq(Quality.suggest("llvmpipe (LLVM 15.0.7, 256 bits)"), Quality.LOW, "rendu logiciel -> Bas")
	t.eq(Quality.suggest("Microsoft Basic Render Driver"), Quality.LOW, "pilote de base -> Bas")
	t.eq(Quality.suggest("SwiftShader Device"), Quality.LOW, "SwiftShader -> Bas")
	t.eq(Quality.suggest("Intel(R) GMA 4500"), Quality.LOW, "très ancienne -> Bas")
	t.eq(Quality.suggest("Intel(R) UHD Graphics 620"), Quality.MEDIUM, "Intel UHD -> Moyen")
	t.eq(Quality.suggest("Intel(R) Iris(R) Xe Graphics"), Quality.MEDIUM, "Iris -> Moyen")
	t.eq(Quality.suggest("AMD Radeon(TM) Vega 8 Graphics"), Quality.MEDIUM, "Vega mobile -> Moyen")
	t.eq(Quality.suggest("NVIDIA GeForce RTX 3060"), Quality.HIGH, "carte dédiée -> Élevé")
	t.eq(Quality.suggest("AMD Radeon RX 6700 XT"), Quality.HIGH, "Radeon RX -> Élevé")
	t.eq(Quality.suggest("Radeon RX Vega 56"), Quality.HIGH, "Vega de bureau -> Élevé")
	t.eq(Quality.suggest("Intel(R) Arc(TM) A770 Graphics"), Quality.HIGH, "Intel Arc -> Élevé")
	t.eq(Quality.suggest(""), Quality.HIGH, "nom inconnu -> Élevé")


func test_accessors() -> void:
	t.check(Quality.value("inconnu") == null, "clé inconnue -> null")
	t.check(Quality.particle_factor() >= 0.0, "facteur de particules lisible")
	t.check(int(Quality.value("decals")) >= 0, "plafond lisible")
	t.check(int(Quality.value("map_px")) in Quality.MAP_PX, "définition de carte valide")
