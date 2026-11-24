class_name ModsPanel
extends RefCounted
## Options > Mods : liste des mods trouvés dans user://mods, leur état, leurs avertissements ; activation / désactivation
## (prise en compte au prochain lancement). Aucun mod n'exécute de code : voir core/mods.gd et docs/mods.md.

const STATE_LABELS: Dictionary = {"ok": "Chargé", "warn": "Chargé avec avertissements", "error": "Ignoré (erreur)", "disabled": "Désactivé"}


static func open(host: Node) -> ModalOverlay:
	var m := ModalOverlay.open(host, 600)
	var box: VBoxContainer = m.content
	box.add_child(UiKit.title("Mods", 34))
	box.add_child(UiKit.sub("Dossier : %s\nUn mod ne contient que des données JSON (aucun script). Les changements s'appliquent au prochain lancement du jeu." % ProjectSettings.globalize_path(ModsData.ROOT)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 300)
	box.add_child(scroll)
	var list := UiKit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if Mods.reports.is_empty():
		list.add_child(UiKit.para("Aucun mod trouvé. Créez un dossier dans le dossier ci-dessus avec un fichier mod.json (voir docs/mods.md)."))
	for rep in Mods.reports:
		list.add_child(_card(rep))
	var foot := UiKit.hbox(8)
	var folder := UiKit.button("Ouvrir le dossier", "ghost", true)
	folder.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ModsData.ROOT))
		OS.shell_open(ProjectSettings.globalize_path(ModsData.ROOT)))
	foot.add_child(folder)
	foot.add_child(UiKit.spacer())
	var close := UiKit.button("Fermer", "pri")
	close.pressed.connect(m.close)
	foot.add_child(close)
	box.add_child(foot)
	return m


static func _card(rep: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var v := UiKit.vbox(3)
	card.add_child(v)
	var st: String = str(rep["state"])
	var col: Color = GameTheme.status_bad() if st == "error" else (GameTheme.GOLD if st == "warn" else (GameTheme.MUTE if st == "disabled" else GameTheme.GOOD))
	var head := UiKit.hbox(8)
	head.add_child(UiKit.label("%s  v%s" % [rep["name"], rep["version"]] if str(rep["version"]) != "" else str(rep["name"]), 17, GameTheme.INK, true))
	head.add_child(UiKit.spacer())
	head.add_child(UiKit.chip(str(STATE_LABELS.get(st, st)), col))
	v.add_child(head)
	if str(rep["author"]) != "":
		v.add_child(UiKit.sub("Auteur : %s" % rep["author"], 13))
	if str(rep["description"]) != "":
		v.add_child(UiKit.sub(str(rep["description"]), 13))
	var parts: PackedStringArray = []
	for k in rep["counts"]:
		parts.append("%s : %d" % [ModsData.CATEGORIES.get(k, k), int(rep["counts"][k])])
	if not parts.is_empty():
		v.add_child(UiKit.sub("Contenu — " + " · ".join(parts), 12))
	for w in rep["warnings"]:
		var wl := UiKit.sub("• " + str(w), 12)
		wl.add_theme_color_override("font_color", GameTheme.status_bad() if st == "error" else GameTheme.GOLD)
		v.add_child(wl)
	if st != "error":
		var tog := CheckButton.new()
		tog.text = "Activé"
		tog.button_pressed = bool(rep["enabled"])
		tog.toggled.connect(func(on: bool) -> void:
			var dis: Array = Mods.read_disabled()
			dis.erase(str(rep["dir"]))
			if not on:
				dis.append(str(rep["dir"]))
			Mods.write_disabled(dis))
		v.add_child(tog)
	return card
