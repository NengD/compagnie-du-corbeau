class_name RuinsScreen
extends RefCounted
## Fenêtre d'exploration de ruines (ModalOverlay) : entrée, choix entre deux niveaux (avancer / fouiller / se replier), coffre final.
## Aucune dépendance à l'autoload Game : `RuinsFlow` (ruins_flow.gd) branche les actions. Testable sans partie (`build`).


## Fenêtre pour une exploration en cours. `last` : {"text", "lines"} du dernier résultat (ou {}). `on_choice(id)` reçoit l'identifiant du choix.
static func open_run(host: Node, run: Dictionary, last: Dictionary, on_choice: Callable) -> ModalOverlay:
	var m: ModalOverlay = ModalOverlay.open(host, 520)
	build_run(m.content, run, last, on_choice)
	return m


## Remplit `box` pour une exploration en cours.
static func build_run(box: VBoxContainer, run: Dictionary, last: Dictionary, on_choice: Callable) -> void:
	var t: Dictionary = RuinsData.THEMES[str(run["theme"])]
	box.add_child(UiKit.label("Exploration de ruines", 13, GameTheme.GOLD, true))
	box.add_child(UiKit.title(str(run["name"]), 26))
	var stage: int = int(run["stage"])
	var stages: int = int(run["stages"])
	var chest: bool = str(run.get("phase", "")) == "chest"
	box.add_child(UiKit.sub("%s · niveau %s · danger %d/3" % [str(t["n"]), "final" if chest else "%d/%d" % [mini(stage + 1, stages), stages], int(run["d"])]))
	if not last.is_empty() and str(last.get("text", "")) != "":
		box.add_child(UiKit.label(str(last["text"]), 15, GameTheme.GOLD))
	for l in last.get("lines", []):
		if str(l) != "":
			box.add_child(UiKit.sub("• " + str(l)))
	box.add_child(UiKit.para(Ruins.level_text(run)))
	box.add_child(UiKit.sub("Pas de soin entre les niveaux : les blessures restent."))
	for ch in Ruins.choices(run):
		var row: VBoxContainer = UiKit.vbox(2)
		var b: Button = UiKit.button(str(ch["label"]), "pri" if str(ch["id"]) in ["advance", "open"] else "")
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var id: String = str(ch["id"])
		b.pressed.connect(func() -> void: on_choice.call(id))
		row.add_child(b)
		row.add_child(UiKit.sub(str(ch["hint"]), 12))
		box.add_child(row)


## Fenêtre d'entrée : le joueur décide d'entrer ou de passer son chemin. `on_enter` / `on_skip` sans argument.
static func open_entry(host: Node, poi_name: String, theme: String, danger: int, on_enter: Callable, on_skip: Callable) -> ModalOverlay:
	var m: ModalOverlay = ModalOverlay.open(host, 520)
	build_entry(m.content, poi_name, theme, danger, on_enter, on_skip)
	return m


static func build_entry(box: VBoxContainer, poi_name: String, theme: String, danger: int, on_enter: Callable, on_skip: Callable) -> void:
	var t: Dictionary = RuinsData.THEMES[theme]
	box.add_child(UiKit.label("Ruines", 13, GameTheme.GOLD, true))
	box.add_child(UiKit.title(poi_name, 26))
	box.add_child(UiKit.para(str(t["intro"])))
	box.add_child(UiKit.sub("%s : %d niveaux enchaînés, sans soin entre eux. On peut se replier entre deux niveaux. Danger %d/3." % [str(t["n"]), int(t["stages"]), danger]))
	var go: Button = UiKit.button("Entrer dans les ruines", "pri")
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(func() -> void: on_enter.call())
	box.add_child(go)
	var skip: Button = UiKit.button("Passer son chemin", "ghost")
	skip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	skip.pressed.connect(func() -> void: on_skip.call())
	box.add_child(skip)


## Fenêtre d'antre de bête légendaire.
static func open_lair(host: Node, beast: String, on_attack: Callable, on_skip: Callable) -> ModalOverlay:
	var m: ModalOverlay = ModalOverlay.open(host, 520)
	build_lair(m.content, beast, on_attack, on_skip)
	return m


static func build_lair(box: VBoxContainer, beast: String, on_attack: Callable, on_skip: Callable) -> void:
	var d: Dictionary = LegendaryData.LEGENDS[beast]
	box.add_child(UiKit.label("Bête légendaire", 13, GameTheme.GOLD, true))
	box.add_child(UiKit.title(str(d["title"]), 26, GameTheme.GOLD))
	box.add_child(UiKit.para(str(d["legend"])))
	box.add_child(UiKit.sub("Un butin unique attend celui qui l'abattra. Cette bête change de comportement à mesure qu'elle saigne."))
	var go: Button = UiKit.button("Affronter la bête", "pri")
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(func() -> void: on_attack.call())
	box.add_child(go)
	var skip: Button = UiKit.button("Passer son chemin", "ghost")
	skip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	skip.pressed.connect(func() -> void: on_skip.call())
	box.add_child(skip)


## Fin d'exploration : un dernier texte et un bouton de retour.
static func build_end(box: VBoxContainer, last: Dictionary, on_close: Callable) -> void:
	box.add_child(UiKit.title("Retour à la lumière", 26))
	if str(last.get("text", "")) != "":
		box.add_child(UiKit.para(str(last["text"])))
	for l in last.get("lines", []):
		if str(l) != "":
			box.add_child(UiKit.sub("• " + str(l)))
	var b: Button = UiKit.button("Retour à la carte", "pri")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func() -> void: on_close.call())
	box.add_child(b)
