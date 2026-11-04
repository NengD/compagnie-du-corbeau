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
	["Échap", "S'arrêter (ou ouvrir le menu pause à l'arrêt)"],
	["Tab / Maj+Tab", "Aller au lieu suivant / précédent (centre la vue)"],
	["H / C / Début", "Recentrer sur la compagnie"],
	["I", "Inventaire"],
	["Molette · clic milieu/droit", "Zoom · déplacer la carte"],
	["? / F1", "Cette aide"],
]


## Texte « [touche] » à ajouter à un bouton.
static func tag(key: String) -> String:
	return " [%s]" % key


## Ouvre l'aide ; `focus` = "battle" ou "map" (cette section est listée en premier).
static func open(host: Node, focus: String = "battle") -> ModalOverlay:
	var m := ModalOverlay.open(host, 520)
	var box: VBoxContainer = m.content
	box.add_child(UiKit.title("Raccourcis clavier", 30))
	var sections: Array = [["Bataille", BATTLE], ["Carte", MAP]]
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
	var b := UiKit.button("Fermer", "pri")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func() -> void: m.close())
	box.add_child(b)
	return m
