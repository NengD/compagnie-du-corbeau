class_name Shortcuts
extends RefCounted
## Liste des raccourcis clavier du jeu et fenêtre d'aide (touche « ? » ou F1, ou bouton « ? »).

const BATTLE: Array = [
	["Espace / Entrée", "Fin du tour"],
	["W", "Attendre (repasser en fin de file)"],
	["1 – 9", "Capacités, mur de boucliers, changement d'arme (dans l'ordre des boutons)"],
	["Échap", "Annuler la capacité armée"],
	["Retour arrière / Ctrl+Z", "Annuler le dernier déplacement"],
	["Tab / Maj+Tab", "Inspecter l'unité suivante / précédente"],
	["H / Début", "Vue d'ensemble du plateau"],
	["Molette · clic milieu", "Zoom · déplacer le plateau"],
	["? / F1", "Cette aide"],
]

const MAP: Array = [
	["Espace", "Pause / reprise du temps"],
	["Échap", "Fermer le tiroir ou la légende, sinon s'arrêter (ou ouvrir le menu pause à l'arrêt)"],
	["Tab / Maj+Tab", "Aller au lieu suivant / précédent (centre la vue)"],
	["Z Q S D / flèches", "Déplacer la caméra (touches W A S D d'un clavier QWERTY) ; Maj : plus vite"],
	["Bords de l'écran", "Faire défiler la carte (réglable dans les options)"],
	["H / C / Début", "Recentrer sur la compagnie (la caméra la suit pendant les trajets)"],
	["I", "Inventaire"],
	["F", "Tiroir « Détails » (contrat, factions, lieux, hommes)"],
	["L", "Légende de la carte"],
	["M", "Replier / déplier la mini-carte"],
	["Molette · clic milieu/droit", "Zoom · déplacer la carte"],
	["Clic sur la mini-carte", "Aller à cet endroit du monde"],
	["? / F1", "Cette aide"],
]


## Lignes d'aide construites d'après les touches ACTUELLES (reconfigurables : voir Keybinds / KeysPanel).
## Les constantes BATTLE et MAP ci-dessus ne documentent que les touches par défaut.
static func battle_rows() -> Array:
	var slots: String = "%s – %s" % [Keybinds.short_name("slot_1"), Keybinds.short_name("slot_9")]
	return [
		[Keybinds.names_of("end_turn"), "Fin du tour"],
		[Keybinds.names_of("wait"), "Attendre (repasser en fin de file)"],
		[slots, "Capacités, mur de boucliers, changement d'arme (dans l'ordre des boutons)"],
		["Échap", "Annuler la capacité armée"],
		[Keybinds.names_of("undo_move"), "Annuler le dernier déplacement"],
		["%s / %s" % [Keybinds.names_of("inspect_next"), Keybinds.names_of("inspect_prev")], "Inspecter l'unité suivante / précédente"],
		[Keybinds.names_of("battle_view"), "Vue d'ensemble du plateau"],
		["Molette · clic milieu", "Zoom · déplacer le plateau"],
		[Keybinds.names_of("help"), "Cette aide"],
	]


static func _camera_keys() -> String:
	var acts: Array = ["cam_up", "cam_left", "cam_down", "cam_right"]
	var first: PackedStringArray = []
	var second: PackedStringArray = []
	for a in acts:
		var ks: Array = Keybinds.keys_of(a)
		first.append(Keybinds.spec_name(int(ks[0])))
		if ks.size() > 1:
			second.append(Keybinds.spec_name(int(ks[1])))
	var out: String = " ".join(first)
	if second.size() == 4:
		out += " / flèches" if "".join(second) == "↑←↓→" else " / " + " ".join(second)
	return out


static func map_rows() -> Array:
	return [
		[Keybinds.names_of("map_pause"), "Pause / reprise du temps"],
		["Échap", "Fermer le tiroir ou la légende, sinon s'arrêter (ou ouvrir le menu pause à l'arrêt)"],
		["%s / %s" % [Keybinds.names_of("map_next_place"), Keybinds.names_of("map_prev_place")], "Aller au lieu suivant / précédent (centre la vue)"],
		[_camera_keys(), "Déplacer la caméra ; %s : plus vite" % Keybinds.names_of("cam_fast")],
		["Bords de l'écran", "Faire défiler la carte (réglable dans les options)"],
		[Keybinds.names_of("map_center"), "Recentrer sur la compagnie (la caméra la suit pendant les trajets)"],
		[Keybinds.names_of("inventory"), "Inventaire"],
		[Keybinds.names_of("journal"), "Journal de campagne et mémorial"],
		[Keybinds.names_of("codex"), "Encyclopédie"],
		[Keybinds.names_of("map_details"), "Tiroir « Détails » (contrat, factions, lieux, hommes)"],
		[Keybinds.names_of("map_legend"), "Légende de la carte"],
		[Keybinds.names_of("map_minimap"), "Replier / déplier la mini-carte"],
		["Molette · clic milieu/droit", "Zoom · déplacer la carte"],
		["Clic sur la mini-carte", "Aller à cet endroit du monde"],
		[Keybinds.names_of("help"), "Cette aide"],
	]


## Texte « [touche] » à ajouter à un bouton.
static func tag(key: String) -> String:
	return " [%s]" % key


## Ouvre l'aide ; `focus` = "battle" ou "map" (cette section est listée en premier).
static func open(host: Node, focus: String = "battle") -> ModalOverlay:
	var m := ModalOverlay.open(host, 520)
	var box: VBoxContainer = m.content
	box.add_child(UiKit.title("Raccourcis clavier", 30))
	var sections: Array = [["Bataille", battle_rows()], ["Carte", map_rows()]]
	if focus == "map":
		sections.reverse()
	for sec in sections:
		box.add_child(UiKit.label(str(sec[0]), 16, GameTheme.GOLD, true))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 3)
		for row in sec[1]:
			grid.add_child(UiKit.label(str(row[0]), 14, GameTheme.INK, true))
			var d := UiKit.sub(str(row[1]), 14)
			grid.add_child(d)
		box.add_child(grid)
	var foot := UiKit.hbox(8)
	var b := UiKit.button("Fermer", "pri")
	b.pressed.connect(func() -> void: m.close())
	foot.add_child(b)
	var cfg := UiKit.button("Configurer les touches…", "ghost", true)
	cfg.pressed.connect(func() -> void:
		m.close()
		KeysPanel.open(host))
	foot.add_child(cfg)
	box.add_child(foot)
	return m
