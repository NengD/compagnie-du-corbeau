extends RefCounted
## Touches reconfigurables, accessibilité (palettes daltoniennes) et mods JSON.
var t

const TMP: String = "user://__test_mods"

# Simulation de daltonisme (Machado et al., gravité 1) appliquée en RGB linéaire.
const SIM: Dictionary = {
	"p": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
	"d": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
	"t": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}


func _key(code: int, ctrl: bool = false, shift: bool = false, unicode: int = 0) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code as Key
	e.physical_keycode = code as Key
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	e.unicode = unicode
	return e


func test_touches_par_defaut() -> void:
	Keybinds.reset_all()
	var cases: Array = [
		["end_turn", KEY_SPACE], ["end_turn", KEY_ENTER], ["end_turn", KEY_KP_ENTER], ["wait", KEY_W],
		["undo_move", KEY_BACKSPACE], ["inspect_next", KEY_TAB], ["battle_view", KEY_H], ["battle_view", KEY_HOME],
		["help", KEY_F1], ["help", KEY_QUESTION], ["map_pause", KEY_SPACE], ["map_next_place", KEY_TAB],
		["map_center", KEY_C], ["map_center", KEY_H], ["map_center", KEY_HOME], ["map_details", KEY_F], ["map_legend", KEY_L],
		["map_minimap", KEY_M], ["inventory", KEY_I], ["journal", KEY_J], ["codex", KEY_F1],
	]
	for c in cases:
		t.check(Keybinds.matches(_key(int(c[1])), str(c[0])), "défaut : %s <- touche %d" % [c[0], c[1]])
	t.check(Keybinds.matches(_key(KEY_Z, true), "undo_move"), "Ctrl+Z annule le déplacement")
	t.check(not Keybinds.matches(_key(KEY_Z), "undo_move"), "Z seul n'annule pas")
	t.check(Keybinds.matches(_key(KEY_TAB, false, true), "inspect_prev"), "Maj+Tab : précédent")
	t.check(Keybinds.matches(_key(KEY_SLASH, false, true, 63), "help"), "« ? » par son caractère (autres claviers)")
	for i in range(1, 10):
		t.check(Keybinds.matches(_key(KEY_1 + i - 1), "slot_%d" % i), "chiffre %d : bouton %d" % [i, i])
		t.check(Keybinds.matches(_key(KEY_KP_1 + i - 1), "slot_%d" % i), "pavé %d : bouton %d" % [i, i])
		t.eq(Keybinds.slot_of(_key(KEY_1 + i - 1)), i, "slot_of %d" % i)
	for p in [["cam_up", KEY_W], ["cam_up", KEY_UP], ["cam_down", KEY_S], ["cam_down", KEY_DOWN], ["cam_left", KEY_A], ["cam_left", KEY_LEFT], ["cam_right", KEY_D], ["cam_right", KEY_RIGHT]]:
		t.check(Keybinds.matches(_key(int(p[1])), str(p[0])), "caméra %s touche physique %d" % [p[0], p[1]])
	t.check(not Keybinds.matches(_key(KEY_ESCAPE), "end_turn"), "Échap n'est liée à rien")
	t.check(Keybinds.find_conflicts().is_empty(), "aucun conflit dans la configuration par défaut")
	for a in Keybinds.action_ids():
		t.check(not Keybinds.keys_of(a).is_empty(), "action %s a une touche" % a)


func test_conflits_et_echange() -> void:
	Keybinds.reset_all()
	var r: Dictionary = Keybinds.assign("map_legend", 0, KEY_F)
	t.check(not bool(r["ok"]) and (r["conflict"] as Array).has("map_details"), "F déjà prise par Détails : refus")
	t.check(Keybinds.keys_of("map_legend") == [KEY_L], "refus : rien n'a changé")
	r = Keybinds.assign("map_legend", 0, KEY_F, true)
	t.check(bool(r["ok"]), "échange accepté")
	t.check(Keybinds.keys_of("map_legend") == [KEY_F] and Keybinds.keys_of("map_details") == [KEY_L], "touches échangées")
	t.check(Keybinds.find_conflicts().is_empty(), "plus aucun conflit après échange")
	r = Keybinds.assign("map_minimap", 0, KEY_SPACE)
	t.check(not bool(r["ok"]), "Espace pris par la pause de la carte")
	t.check(bool(Keybinds.assign("wait", 0, KEY_X)["ok"]), "X libre en bataille")
	t.check(bool(Keybinds.assign("map_minimap", 0, KEY_X)["ok"]), "X libre sur la carte (autre contexte)")
	t.check(not bool(Keybinds.assign("wait", 0, KEY_ESCAPE)["ok"]), "Échap réservée")
	t.check(not bool(Keybinds.assign("wait", 0, KEY_ENTER)["ok"]), "Entrée réservée à la validation (fin de tour seulement)")
	t.check(bool(Keybinds.assign("end_turn", 1, KEY_ENTER)["ok"]), "…mais fin de tour la garde")
	Keybinds.reset_all()
	t.check(Keybinds.overrides.is_empty() and Keybinds.keys_of("map_legend") == [KEY_L], "remise aux valeurs par défaut")


func test_sauvegarde_des_touches() -> void:
	Keybinds.reset_all()
	var s: Node = load("res://autoload/Settings.gd").new()
	s.persist = false
	Keybinds.assign("map_details", 0, KEY_G)
	Keybinds.assign("undo_move", 1, KEY_U)
	var c: ConfigFile = s.to_config()
	t.check(c.has_section_key("keys", "map_details"), "touches écrites dans la section keys")
	Keybinds.reset_all()
	var s2: Node = load("res://autoload/Settings.gd").new()
	s2.persist = false
	s2.from_config(c)
	t.check(Keybinds.keys_of("map_details") == [KEY_G], "touche rechargée")
	t.check(Keybinds.keys_of("undo_move") == [KEY_Z | KEY_MASK_CTRL, KEY_U], "seconde touche rechargée")
	var bad := ConfigFile.new()
	bad.set_value("keys", "map_details", "pas un tableau")
	bad.set_value("keys", "inconnue", [65])
	bad.set_value("keys", "map_legend", [KEY_ESCAPE])
	bad.set_value("keys", "wait", [-5])
	bad.set_value("keys", "map_minimap", [KEY_G, KEY_G])
	bad.set_value("keys", "journal", [KEY_I])
	s2.from_config(bad)
	t.check(Keybinds.overrides.is_empty(), "valeurs invalides ou en conflit ignorées -> défauts")
	s2.from_config(ConfigFile.new())
	t.check(Keybinds.overrides.is_empty(), "ancien fichier : défauts")
	Keybinds.reset_all()
	s.free()
	s2.free()


func _sim(c: Color, mode: String) -> Color:
	if mode == "n":
		return c
	var l := c.srgb_to_linear()
	var m: Array = SIM[mode]
	var o := Color(0, 0, 0)
	o.r = clampf(m[0][0] * l.r + m[0][1] * l.g + m[0][2] * l.b, 0.0, 1.0)
	o.g = clampf(m[1][0] * l.r + m[1][1] * l.g + m[1][2] * l.b, 0.0, 1.0)
	o.b = clampf(m[2][0] * l.r + m[2][1] * l.g + m[2][2] * l.b, 0.0, 1.0)
	return o.linear_to_srgb()


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _min_dist(cols: Array, modes: Array) -> float:
	var best: float = 9.0
	for m in modes:
		for i in cols.size():
			for j in range(i + 1, cols.size()):
				best = minf(best, _dist(_sim(cols[i], str(m)), _sim(cols[j], str(m))))
	return best


func test_palettes_daltoniennes() -> void:
	var modes_for: Array = [["n"], ["p", "d"], ["t"]]
	for mode in 3:
		GameTheme.apply_accessibility(mode, false, false)
		var morale: Array = []
		for i in 5:
			morale.append(GameTheme.morale_color(i))
		var thr: float = 0.1 if mode == 0 else 0.2
		t.check(_min_dist(morale, modes_for[mode]) >= thr, "moral : couleurs distinctes (mode %d, %.2f)" % [mode, _min_dist(morale, modes_for[mode])])
		t.check(_min_dist([GameTheme.side_color("p"), GameTheme.side_color("e")], modes_for[mode]) >= 0.2, "camps distincts (mode %d)" % mode)
		var bars: Array = [GameTheme.bar_color("head"), GameTheme.bar_color("body"), GameTheme.bar_color("hp")]
		t.check(_min_dist(bars, modes_for[mode]) >= thr, "barres distinctes (mode %d, %.2f)" % [mode, _min_dist(bars, modes_for[mode])])
		t.check(_min_dist([GameTheme.status_bad(), GameTheme.status_ok()], modes_for[mode]) >= 0.2 or mode == 0, "statuts distincts (mode %d)" % mode)
		t.eq(GameTheme.morale_symbol(3) == "", mode == 0, "symboles du moral seulement en mode daltonien (%d)" % mode)
	var syms: Array = []
	GameTheme.apply_accessibility(1, false, false)
	for i in 5:
		syms.append(GameTheme.morale_symbol(i))
	for i in 5:
		t.check(syms.count(syms[i]) == 1, "symbole du moral %d unique" % i)
	GameTheme.apply_accessibility(0, true, false)
	t.check(GameTheme.text_color(GameTheme.MUTE) != GameTheme.MUTE, "texte contrasté : le gris s'éclaircit")
	t.check(GameTheme.text_color(GameTheme.BLOOD) == GameTheme.BLOOD, "texte contrasté : les autres couleurs inchangées")
	GameTheme.apply_accessibility(0, false, false)
	t.check(GameTheme.text_color(GameTheme.MUTE) == GameTheme.MUTE, "contraste coupé : inchangé")
	var s: Node = load("res://autoload/Settings.gd").new()
	s.persist = false
	t.eq(s.colorblind, 0, "daltonisme : aucun par défaut")
	t.check(not s.reduce_motion and not s.high_contrast, "accessibilité coupée par défaut")
	s.set_value("tooltip_scale", 9)
	t.check(is_equal_approx(s.tooltip_factor(), 1.5), "infobulles bornées à 150 %")
	s.set_value("colorblind", 7)
	t.eq(s.colorblind, 2, "daltonisme borné")
	s.set_value("reduce_motion", true)
	t.check(not s.shake_enabled(), "animations réduites : plus de tremblement")
	s.free()
	GameTheme.apply_accessibility(0, false, false)
	GameTheme.apply_tooltip_scale(1.0)


# --- Mods ---

func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean_tmp() -> void:
	var root: String = ProjectSettings.globalize_path(TMP)
	if DirAccess.dir_exists_absolute(root):
		_rm(root)


func _rm(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		_rm(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _rep(reports: Array, id: String) -> Dictionary:
	for r in reports:
		if r["dir"] == id:
			return r
	return {}


func test_mod_valide_invalide_hostile() -> void:
	_clean_tmp()
	_write(TMP + "/bon/mod.json", JSON.stringify({"name": "Bon", "version": "1", "author": "x", "description": "d"}))
	_write(TMP + "/bon/a.json", JSON.stringify({"first_names": ["Zéphyrin", "Aldric", 5, "X"], "nicknames": ["le Test"], "epitaphs": ["Une épitaphe assez longue."], "inconnue": [1]}))
	_write(TMP + "/sansmanifeste/a.json", "{}")
	_write(TMP + "/casse/mod.json", '{"name": ')
	_write(TMP + "/mauvaistype/mod.json", '{"name": 12}')
	_write(TMP + "/hostile/mod.json", JSON.stringify({"name": "Hostile", "files": ["../../evil.json", "/etc/x.json", "C:/x.json", "a\\b.json", "ok.txt", "ok.json", 5]}))
	_write(TMP + "/hostile/ok.json", JSON.stringify({"first_names": "pas une liste", "scenarios": {"BAD ID": {}, "ok": {"n": "N", "men": ["inexistant"]}}, "events": [{"id": "e", "title": "t"}, 3]}))
	_write(TMP + "/gros/mod.json", JSON.stringify({"name": "Gros"}))
	_write(TMP + "/gros/big.json", '{"first_names": ["' + "A".repeat(300000) + '"]}')
	_write(TMP + "/profond/mod.json", JSON.stringify({"name": "Profond"}))
	_write(TMP + "/profond/p.json", '{"first_names": ' + "[".repeat(200) + "]".repeat(200) + "}")
	var rs: Array = Mods.load_all(TMP, [])
	t.eq(_rep(rs, "bon")["state"], "warn", "mod valide (avertissements pour les entrées invalides)")
	var fn: Array = Mods.content["first_names"]
	t.check(fn.has("Zéphyrin") and not fn.has("Aldric") and not fn.has("X"), "prénoms : valides gardés, doublon du jeu et trop court écartés")
	t.eq(Mods.first_names().size(), Data.FIRST_NAMES.size() + 1, "first_names() complète la table du jeu")
	t.check(Mods.nicknames().has("le Test") and Mods.epitaphs().has("Une épitaphe assez longue."), "surnoms et épitaphes ajoutés")
	t.eq(_rep(rs, "sansmanifeste")["state"], "error", "sans mod.json : erreur")
	t.eq(_rep(rs, "casse")["state"], "error", "JSON cassé : erreur sans plantage")
	t.eq(_rep(rs, "mauvaistype")["state"], "error", "name de mauvais type : erreur")
	var h: Dictionary = _rep(rs, "hostile")
	t.check(h["state"] != "error", "mod hostile : se charge sans plantage")
	t.check("refusé" in " ".join(h["warnings"]), "chemins hostiles refusés (avertissement)")
	t.eq(h["files"], ["ok.json"], "seul le fichier sûr est lu")
	t.check((Mods.content["scenarios"] as Dictionary).is_empty() and (Mods.content["events"] as Array).is_empty(), "scénario/événements invalides écartés")
	t.check("trop gros" in " ".join(_rep(rs, "gros")["warnings"]), "fichier énorme refusé")
	t.check(" ".join(_rep(rs, "profond")["warnings"]) != "", "JSON trop profond refusé avec avertissement")
	for p in ["../a.json", "/a.json", "C:/a.json", "a\\b.json", "a/../b.json", ".cache.json", "a.txt", "a//b.json", "a/b/c/d.json", "é.json", ""]:
		t.check(not Mods.safe_rel_path(p), "chemin refusé : " + p)
	for p in ["a.json", "sous/dossier.json", "noms_2-fr.json"]:
		t.check(Mods.safe_rel_path(p), "chemin accepté : " + p)
	t.eq(Mods.make_id("Mon Mod!"), "mon_mod_", "identifiant sûr")
	Mods.load_all(TMP, ["bon"])
	t.eq(_rep(Mods.reports, "bon")["state"], "disabled", "mod désactivé")
	t.eq(Mods.first_names().size(), Data.FIRST_NAMES.size(), "mod désactivé : aucune fusion")
	Mods.reset()
	_clean_tmp()


func test_mod_evenements_et_scenarios() -> void:
	_clean_tmp()
	_write(TMP + "/m/mod.json", JSON.stringify({"name": "M"}))
	_write(TMP + "/m/c.json", JSON.stringify({
		"scenarios": {"sc": {"n": "Test", "men": ["milicien", "inexistant"], "goal": {"stat": "renown", "target": 99999999, "label": "[b]R[/b]"}, "days": 5000, "gold": 10}},
		"events": [
			{"id": "ev", "title": "Titre", "text": "Un texte assez long.", "choices": [
				{"id": "a", "label": "Choix A", "outcomes": [{"w": 1, "text": "Ok", "gold": 99999, "battle": {"type": "zzz"}}]},
				{"id": "b", "label": "Choix B", "check": {"kind": "negotiate", "base": 50}, "win": [{"text": "Gagné"}], "lose": [{"text": "Perdu"}]}]},
			{"id": "payant", "title": "Titre", "text": "Un texte assez long.", "choices": [{"id": "a", "label": "Payer", "cost": 10, "outcomes": [{"text": "Ok"}]}]}],
		"backstories": {"milicien": ["Une histoire assez longue pour passer."], "nimporte": ["Une histoire assez longue."]}}))
	Mods.load_all(TMP, [])
	var sc: Dictionary = Mods.scenario_data("mod_m_sc")
	t.check(not sc.is_empty(), "scénario du mod disponible sous un identifiant préfixé")
	t.eq(sc["men"], ["milicien"], "origines inconnues écartées")
	t.eq(int(sc["goal"]["target"]), 100000, "objectif borné")
	t.eq(sc["goal"]["label"], "bR/b", "crochets retirés des textes")
	t.eq(int(sc["days"]), 400, "durée bornée")
	t.check(Scenarios.has("mod_m_sc") and Scenarios.keys().has("mod_m_sc") and Scenarios.keys().size() == ScenariosData.ORDER.size() + 1, "Scenarios voit le scénario du mod")
	t.check(not Scenarios.has("sc"), "pas de collision d'identifiant")
	t.eq(Mods.events().size(), 1, "un seul événement valide (l'autre n'a aucun choix gratuit)")
	var ev: Dictionary = Events.get_def("mod_m_ev")
	t.check(not ev.is_empty(), "Events.get_def trouve l'événement du mod")
	t.eq(int(ev["choices"][0]["outcomes"][0]["gold"]), 500, "effets bornés")
	t.check(not (ev["choices"][0]["outcomes"][0] as Dictionary).has("battle"), "bataille invalide retirée")
	t.check(ev["choices"][1].has("check") and ev["choices"][1]["win"].size() == 1, "choix à test conservé")
	t.check(Mods.backstory_pool("milicien", ["x"]).size() == 2 and Mods.backstory_pool("fermier", ["x"]).size() == 1, "histoires ajoutées par origine")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var o: Dictionary = Events.resolve("mod_m_ev", "b", rng, RoadEncounters.context([]))
	t.check(o.has("text"), "résolution d'un choix à test d'un mod")
	Mods.reset()
	t.check(Events.get_def("mod_m_ev").is_empty(), "mod retiré : événement inconnu (pas d'erreur)")
	_clean_tmp()


func test_exemple_de_mod() -> void:
	var rs: Array = Mods.load_all("res://docs/mods_exemple", [])
	t.eq(rs.size(), 1, "l'exemple est trouvé")
	var r: Dictionary = rs[0]
	t.check(r["state"] == "ok", "l'exemple se charge sans avertissement : %s" % str(r["warnings"]))
	t.eq(r["name"], "Compagnie des marais", "nom lu")
	t.eq((r["files"] as Array).size(), 3, "3 fichiers de contenu")
	t.check(not Mods.scenario_data("mod_compagnie_des_marais_marais").is_empty(), "scénario de l'exemple")
	t.eq(Mods.events().size(), 2, "2 événements")
	t.check(Mods.towns().has("Roselière") and Mods.company_names().has("Les Roseaux Noirs"), "lieux et noms de compagnie")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var seen: bool = false
	for i in 400:
		var n: String = str(Contracts.random_name([], rng))
		if n.contains("Mirabel") or n.contains("Aubin") or n.contains("Tancrède") or n.contains("Joinville"):
			seen = true
			break
	t.check(seen, "Contracts.random_name utilise les prénoms du mod")
	Mods.reset()
	t.check(Mods.first_names() == Data.FIRST_NAMES, "sans mod : tables d'origine inchangées")
