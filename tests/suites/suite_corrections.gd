extends RefCounted
## Corrections issues du premier audit : sauvegarde sûre (écriture atomique, copie de secours, validation),
## chargement tolérant aux clés manquantes, chaman orc présent dans les compositions.
var t

const TMP := "user://test_audit_save.json"


func _cleanup() -> void:
	for p in [TMP, TMP + ".bak", TMP + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_chaman_orc_dans_les_compositions() -> void:
	t.check((Contracts.foes_for("o", 2) as Array).has("chaman_orc"), "orcs danger 2 : un chaman")
	t.check((Contracts.foes_for("o", 3) as Array).has("chaman_orc"), "orcs danger 3 : un chaman")
	t.eq(Contracts.foes_for("o", 2).size(), 6, "effectif orcs danger 2 inchangé")
	t.eq(Contracts.foes_for("o", 3).size(), 8, "effectif orcs danger 3 inchangé")
	var found: bool = false
	for wave in Campaign.citadel_waves("o"):
		if (wave as Array).has("chaman_orc"):
			found = true
	t.check(found, "citadelle orque : un chaman dans une vague")
	for k in Contracts.foes_for("o", 3):
		t.check(Data.FOE.has(k), "clé d'ennemi connue : %s" % k)


func test_sauvegarde_sure() -> void:
	_cleanup()
	var g: Node = t.new_game(7)
	var d: Dictionary = g.to_dict()
	t.check(g._write_json_safe(TMP, d), "première écriture")
	t.check(not FileAccess.file_exists(TMP + ".tmp"), "pas de fichier temporaire restant")
	t.check(not g._read_save(TMP).is_empty(), "relecture valide")
	# Deuxième écriture : l'ancienne version devient la copie de secours.
	d["gold"] = 1234
	t.check(g._write_json_safe(TMP, d), "deuxième écriture")
	t.check(FileAccess.file_exists(TMP + ".bak"), "copie de secours créée")
	t.eq(int(g._read_save(TMP)["gold"]), 1234, "la sauvegarde principale est la plus récente")
	# Fichier principal tronqué (coupure pendant l'écriture) : on retombe sur la copie de secours.
	var text: String = FileAccess.get_file_as_string(TMP)
	_write_raw(TMP, text.substr(0, text.length() / 2))
	var rescued: Dictionary = g._read_save(TMP)
	t.check(not rescued.is_empty(), "repli sur la copie de secours")
	t.eq(int(rescued["gold"]), int(g.to_dict()["gold"]), "la copie de secours contient la version précédente")
	# Principal absent, copie présente : la partie reste « continuable ».
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	t.check(not g._read_save(TMP).is_empty(), "principal absent : copie de secours lue")
	# Tout illisible : rien, sans erreur de script.
	_write_raw(TMP, "{pas du json")
	_write_raw(TMP + ".bak", "")
	t.check(g._read_save(TMP).is_empty(), "tout est illisible : dictionnaire vide")
	g.free()
	_cleanup()


func test_validation_des_cles() -> void:
	_cleanup()
	var g: Node = t.new_game(8)
	var d: Dictionary = g.to_dict()
	for k in ["gold", "day", "roster", "world"]:
		var broken: Dictionary = d.duplicate()
		broken.erase(k)
		_write_raw(TMP, JSON.stringify(broken))
		t.check(g._read_save(TMP).is_empty(), "clé obligatoire manquante : %s" % k)
	var bad_types: Dictionary = d.duplicate()
	bad_types["roster"] = "nope"
	_write_raw(TMP, JSON.stringify(bad_types))
	t.check(g._read_save(TMP).is_empty(), "roster de mauvais type")
	var old: Dictionary = d.duplicate()
	old["version"] = 1
	_write_raw(TMP, JSON.stringify(old))
	t.check(g._read_save(TMP).is_empty(), "ancienne version refusée")
	g.free()
	_cleanup()


func test_chargement_tolerant() -> void:
	var g: Node = t.new_game(9)
	var d: Dictionary = g.to_dict()
	# Une sauvegarde valide mais pauvre (clés secondaires absentes) se charge sans erreur, avec des valeurs par défaut.
	var poor: Dictionary = {"version": 2, "gold": 321, "day": 5, "roster": d["roster"], "world": d["world"]}
	var g2: Node = load("res://autoload/Game.gd").new()
	g2.autosave = false
	g2.from_dict(JSON.parse_string(JSON.stringify(poor)))
	t.eq(g2.gold, 321, "or conservé")
	t.eq(g2.day, 5, "jour conservé")
	t.eq(g2.roster.size(), g.roster.size(), "compagnie conservée")
	t.check(g2.battle == null, "pas de bataille par défaut")
	t.eq(g2.location, "", "lieu par défaut")
	g.free()
	g2.free()


func test_liste_des_tailles_inclut_le_2k() -> void:
	var SettingsScript: GDScript = load("res://autoload/Settings.gd")
	var list: Array = SettingsScript.resolution_list(Vector2i(2560, 1440))
	t.check(list.has(Vector2i(2560, 1440)), "2K (2560×1440) proposé sur un écran 2560×1440")
	t.check(list.has(Vector2i(1920, 1080)) and list.has(Vector2i(1280, 720)), "les tailles plus petites restent proposées")
	t.check(not SettingsScript.resolution_list(Vector2i(1920, 1080)).has(Vector2i(2560, 1440)), "pas de 2K sur un écran trop petit")
