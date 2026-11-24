extends RefCounted
## Carte vivante (MapLife), contrats illustrés (ContractCard), ambiance du plateau (BoardLife), icônes harmonisées.
## Tout est visuel : on vérifie le déterminisme par jour, l'absence de `Game.rng`, les coupures de qualité et la couverture des icônes.
var t

var _w: World = null


func _world() -> World:
	if _w == null:
		_w = World.generate(t.rng_seeded(5), 0)
	return _w


func _life() -> MapLife:
	var life := MapLife.new()
	life.setup(_world(), MapTerrain.road_curves(_world()))
	return life


func test_caravanes_deterministes_par_jour() -> void:
	var life: MapLife = _life()
	var a: Array = life.caravans(12, 40.0)
	var b: Array = life.caravans(12, 40.0)
	t.eq(a.size(), b.size(), "même jour, même nombre de caravanes")
	for i in a.size():
		t.check((a[i]["p"] as Vector2).is_equal_approx(b[i]["p"]), "même position")
	t.check(a.size() <= MapLife.MAX_CARAVANS, "caravanes bornées")
	t.check(not a.is_empty(), "au moins une caravane sur le grand monde")
	var differ: bool = false
	for d in range(2, 40, 2):
		var o: Array = life.caravans(d, 40.0)
		if o.size() != a.size() or (not o.is_empty() and not (o[0]["p"] as Vector2).is_equal_approx(a[0]["p"])):
			differ = true
	t.check(differ, "les caravanes varient selon les jours")
	var moved: Array = life.caravans(12, 80.0)
	t.check(moved.size() == a.size() and not (moved[0]["p"] as Vector2).is_equal_approx(a[0]["p"]), "elles avancent avec le temps")


func test_bateaux_sur_l_eau_et_oiseaux() -> void:
	var life: MapLife = _life()
	var w: World = _world()
	for day in [1, 7, 20]:
		for b in life.boats(day, 30.0):
			var c: Vector2i = w.cell_of(b["p"])
			t.check(c.x >= 0 and c.y >= 0 and c.x < w.gw and c.y < w.gh, "bateau dans le monde")
	for fl in life.flocks(5):
		t.check(int(fl["n"]) >= 3 and int(fl["n"]) <= 5, "volée de 3 à 5 oiseaux")
	t.check(life.flocks(5).size() <= MapLife.MAX_FLOCKS, "volées bornées")
	t.check(MapLife.unit(3, 4, 5) >= 0.0 and MapLife.unit(3, 4, 5) < 1.0, "hachage dans [0, 1[")
	t.check(MapLife.unit(3, 4, 5) == MapLife.unit(3, 4, 5), "hachage stable")


func test_colonnes_de_guerre() -> void:
	var life: MapLife = _life()
	var w: World = _world()
	var owners: Array = []
	for s in w.settlements:
		var o: String = str(s.get("owner", ""))
		if o != "" and not owners.has(o):
			owners.append(o)
	t.check(owners.size() >= 2, "au moins deux factions")
	var cols: Array = life.war_columns([[owners[0], owners[1]]], 10.0)
	t.eq(cols.size(), 2, "deux colonnes par guerre")
	t.eq(life.war_columns([], 10.0).size(), 0, "sans guerre, aucune colonne")
	t.eq(life.front_places([]).size(), 0, "sans guerre, aucune trace")


func test_aucun_acces_a_game_rng() -> void:
	for f in ["res://scenes/map/map_life.gd", "res://scenes/battle/board_life.gd", "res://scenes/camp/contract_card.gd"]:
		var src: String = FileAccess.get_file_as_string(f)
		t.check(src != "", f + " lisible")
		t.check(not src.contains("Game.rng") and not src.contains("RandomNumberGenerator") and not src.contains("randf") and not src.contains("randi"), f + " : aucun tirage aléatoire")


func test_coupures_par_qualite() -> void:
	t.eq(Quality.PARTICLE_FACTORS[0], 0.0, "Bas : aucune particule")
	t.eq(BoardLife.count_for(0.0), 0, "densité nulle : aucune particule d'ambiance")
	t.check(BoardLife.count_for(1.0) > 0 and BoardLife.count_for(100.0) <= BoardLife.MAX_COUNT, "densité bornée")
	t.check(not bool(Quality.PRESETS[Quality.LOW]["map_anim"]), "Bas : animations d'ambiance coupées")
	t.check(bool(Quality.PRESETS[Quality.HIGH]["map_anim"]), "Élevé : animations d'ambiance actives")


func test_ambiance_du_plateau() -> void:
	t.eq(BoardLife.mode_for(Seasons.AUTUMN, "meadow", "clear"), "leaves", "automne : feuilles")
	t.eq(BoardLife.mode_for(Seasons.WINTER, "meadow", "clear"), "snow", "hiver : neige légère")
	t.eq(BoardLife.mode_for(Seasons.SUMMER, "desert", "clear"), "dust", "désert : poussière")
	t.eq(BoardLife.mode_for(Seasons.AUTUMN, "meadow", "rain"), "none", "pluie : la météo suffit")
	var a: Array = BoardLife.particles("leaves", 10, 5.0, Vector2(800, 500), 42)
	var b: Array = BoardLife.particles("leaves", 10, 5.0, Vector2(800, 500), 42)
	t.eq(a.size(), 10, "dix particules")
	for i in a.size():
		t.check((a[i]["p"] as Vector2) == (b[i]["p"] as Vector2), "particules déterministes")
		t.check((a[i]["p"] as Vector2).x >= 0.0 and (a[i]["p"] as Vector2).x <= 800.0, "dans le plateau")
	t.eq(BoardLife.particles("none", 10, 1.0, Vector2(800, 500), 1).size(), 0, "mode none : rien")
	var morning: Dictionary = BoardLife.sun(0.15, false)
	var evening: Dictionary = BoardLife.sun(0.65, false)
	t.check(float(morning["dx"]) > 0.0 and float(evening["dx"]) < 0.0, "ombres vers la droite le matin, vers la gauche le soir")
	t.check(float(BoardLife.sun(0.4, false)["len"]) < float(morning["len"]), "ombres plus courtes à midi")
	t.check(float(BoardLife.sun(0.4, true)["a"]) < float(morning["a"]), "ombres faibles la nuit")


func test_cartes_de_contrat() -> void:
	var origin := Vector2(100, 100)
	var kinds: Array = ["kill", "hunt", "escort", "delivery", "defense", "legend", "ruins"]
	for k in kinds:
		t.check(ContractCard.KINDS.has(k), "type " + k + " connu")
		var host := VBoxContainer.new()
		var ct: Dictionary = {"kind": "contract", "type": "b", "type_contract": k, "d": 2, "foes": [1, 2, 3], "title": "Titre", "desc": "Texte",
			"employer": "Un marchand", "target_name": "Là-bas", "pay": 321, "tx": 400.0, "ty": 300.0, "faction": "lys"}
		var acc: Button = ContractCard.build(host, ct, origin, true, Callable())
		t.check(acc != null and not acc.disabled and acc.focus_mode == Control.FOCUS_ALL, "carte %s : bouton focalisable" % k)
		var locked: Button = ContractCard.build(host, ct, origin, false, Callable())
		t.check(locked.disabled, "carte %s : bouton inactif si un contrat est déjà pris" % k)
		t.eq(host.get_child_count(), 2, "deux cartes ajoutées")
		host.free()
	t.eq(ContractCard.kind_of({}), "kill", "ancienne sauvegarde : élimination")
	t.eq(ContractCard.kind_of({"type_contract": "inconnu"}), "kill", "type inconnu : élimination")


func test_icones_harmonisees_et_perks() -> void:
	var dir: DirAccess = DirAccess.open("res://assets/icons_items")
	t.check(dir != null, "dossier d'icônes")
	var n: int = 0
	for f in dir.get_files():
		if f.ends_with(".svg"):
			n += 1
			t.check(FileAccess.get_file_as_string("res://assets/icons_items/" + f).contains("<!--plaque-->"), f + " : fond encadré par catégorie")
	t.check(n >= 90, "icônes d'objets présentes (%d)" % n)
	for k in Data.PERKS:
		t.check(PerkIcon.texture_of(str(k)) != null, "icône du talent " + str(k))
