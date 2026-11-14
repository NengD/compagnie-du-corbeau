class_name CaptivesScreen
extends RefCounted
## Sort des prisonniers après une victoire : rançon, libération ou exécution. Aucune règle ici (voir `Captives`, `Game.apply_captives`).


## (L'autoload est lu par chemin : ce script doit se compiler aussi dans un test `-s`.)
static func _game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/Game")


## Ouvre l'écran s'il y a des captifs en attente ; renvoie la fenêtre ou null.
static func open_if_pending(host: Node) -> ModalOverlay:
	var cap: Dictionary = _game().pending_captives()
	if cap.is_empty():
		return null
	var m := ModalOverlay.open(host, 520)
	build(m.content, cap, func(_line: String) -> void: m.close())
	return m


## Remplit `box` (testable sans fenêtre). `on_done(line)` est appelé après application du choix.
static func build(box: VBoxContainer, cap: Dictionary, on_done: Callable) -> void:
	var men: Array = cap.get("men", [])
	box.add_child(UiKit.title("Prisonniers", 34, GameTheme.GOLD))
	box.add_child(UiKit.sub("%d ennemi%s brisé%s ou en fuite se rend%s." % [men.size(), "s" if men.size() > 1 else "", "s" if men.size() > 1 else "", "ent" if men.size() > 1 else ""], 14))
	for m in men:
		var tag: String = " (chef)" if bool(m.get("leader", false)) else ""
		box.add_child(UiKit.label("• %s — niveau %d%s" % [str(m["name"]), int(m["level"]), tag], 15))
	var fk: String = str(cap.get("faction", ""))
	if fk != "":
		box.add_child(UiKit.sub("Ils relèvent de : %s." % Factions.name_of(fk), 13))
	for choice in Captives.CHOICES:
		var row := UiKit.vbox(2)
		var b := UiKit.button(Captives.choice_label(choice), "pri" if choice == "ransom" else "")
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func() -> void:
			var line: String = _game().apply_captives(choice)
			on_done.call(line))
		row.add_child(b)
		row.add_child(UiKit.sub(Captives.effect_hint(cap, choice), 12))
		box.add_child(row)
