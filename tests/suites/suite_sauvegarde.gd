extends RefCounted
## Sauvegarde : module SaveIO (version, migration, copie de secours sûre, échec d'écriture signalé).
var t

const TMP := "user://test_saveio.json"


func _cleanup() -> void:
	SaveIO.remove_all(TMP)


func _raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_version_courante_ecrite() -> void:
	var g: Node = t.new_game(5)
	t.eq(int(g.to_dict()["version"]), SaveIO.VERSION, "la sauvegarde porte la version du schéma")
	t.check(SaveIO.VERSION >= SaveIO.MIN_VERSION, "version courante >= version minimale lisible")


func test_aller_retour() -> void:
	_cleanup()
	var g: Node = t.new_game(6)
	g.gold = 4321
	t.check(SaveIO.write_safe(TMP, g.to_dict()), "écriture")
	var back: Dictionary = SaveIO.read_save(TMP)
	t.eq(int(back.get("gold", -1)), 4321, "relecture identique")
	_cleanup()


func test_ancienne_sauvegarde_figee_se_charge() -> void:
	# Sauvegarde minimale au format v2 d'origine : sans bannière, vivres, bâtiments, formation, factions, histoires…
	var g: Node = t.new_game(8)
	var d: Dictionary = g.to_dict()
	for k in ["banner", "company_name", "provisions", "company_morale", "starve_days", "buildings", "formation", "faction_standing", "story_flags", "pending_events", "difficulty", "stats", "campaign", "last_battle_report"]:
		d.erase(k)
	d["version"] = 2
	_cleanup()
	_raw(TMP, JSON.stringify(d))
	var rd: Dictionary = SaveIO.read_save(TMP)
	t.check(not rd.is_empty(), "l'ancien format est accepté")
	var g2: Node = t.new_game(9)
	g2.from_dict(rd)
	t.eq(g2.gold, g.gold, "l'or est restauré")
	t.eq(g2.roster.size(), g.roster.size(), "la compagnie est restaurée")
	t.check(g2.provisions >= 0, "valeurs par défaut pour les clés absentes")
	t.eq(g2.difficulty, "normal", "difficulté par défaut : Normal")
	_cleanup()


func test_version_trop_recente_refusee() -> void:
	var g: Node = t.new_game(10)
	var d: Dictionary = g.to_dict()
	d["version"] = SaveIO.VERSION + 1
	_cleanup()
	_raw(TMP, JSON.stringify(d))
	t.check(SaveIO.read_one(TMP).is_empty(), "sauvegarde d'une version plus récente : refusée sans planter")
	_cleanup()


func test_bak_jamais_ecrase_par_un_fichier_abime() -> void:
	_cleanup()
	var g: Node = t.new_game(11)
	var d: Dictionary = g.to_dict()
	d["gold"] = 111
	t.check(SaveIO.write_safe(TMP, d), "écriture 1")
	d["gold"] = 222
	t.check(SaveIO.write_safe(TMP, d), "écriture 2 (le .bak contient 111)")
	t.eq(int(SaveIO.read_one(TMP + ".bak")["gold"]), 111, "copie de secours = version précédente")
	# Le fichier principal est abîmé : l'écriture suivante ne doit PAS écraser la bonne copie de secours.
	_raw(TMP, "{ tronque")
	d["gold"] = 333
	t.check(SaveIO.write_safe(TMP, d), "écriture 3 sur un principal abîmé")
	t.eq(int(SaveIO.read_one(TMP + ".bak")["gold"]), 111, "la bonne copie de secours est conservée")
	t.eq(int(SaveIO.read_one(TMP)["gold"]), 333, "le principal est réparé")
	_cleanup()


func test_echec_d_ecriture_signale() -> void:
	var g: Node = t.new_game(12)
	var ok: bool = SaveIO.write_safe("user://dossier_inexistant_xyz/s.json", g.to_dict())
	t.check(not ok, "écriture dans un dossier absent : échec")
	t.check(SaveIO.last_error != "", "la raison de l'échec est disponible")
	var seen: Array = [""]
	g.save_failed.connect(func(r: String) -> void: seen[0] = r)
	g.save_failed.emit("test")
	t.eq(seen[0], "test", "le signal save_failed existe")
