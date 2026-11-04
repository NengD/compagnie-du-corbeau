class_name DifficultyPanel
extends RefCounted
## Fenêtre de choix de la difficulté, ouverte avant « Nouvelle partie ». Aucune règle ici : tout vient de core/difficulty.gd.
## `on_start` reçoit la clé choisie (« easy », « normal », « hard »). « Normal » est présélectionné (recommandé).

var modal: ModalOverlay
var selected: String = Data.DIFFICULTY_DEFAULT
var on_start: Callable


static func open(host: Node, p_on_start: Callable) -> DifficultyPanel:
	var p := DifficultyPanel.new()
	p.on_start = p_on_start
	p.modal = ModalOverlay.open(host, 640)
	p._rebuild()
	return p


func _rebuild() -> void:
	var box: VBoxContainer = modal.content
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_child(UiKit.title("Difficulté", 34))
	box.add_child(UiKit.sub("Le niveau se choisit maintenant et ne pourra plus être changé en cours de partie.", 14))
	for k in Difficulty.keys():
		box.add_child(_card(str(k)))
	var row := UiKit.hbox(8)
	var go := UiKit.button("Commencer", "pri")
	go.pressed.connect(func() -> void:
		modal.close()
		if on_start.is_valid():
			on_start.call(selected))
	row.add_child(go)
	var cancel := UiKit.button("Annuler", "ghost")
	cancel.pressed.connect(modal.close)
	row.add_child(cancel)
	box.add_child(row)


func _card(key: String) -> Control:
	var on: bool = key == selected
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	var v := UiKit.vbox(3)
	var head := UiKit.hbox(8)
	head.add_child(UiKit.label(Difficulty.label(key), 20, GameTheme.GOLD if on else GameTheme.INK, true))
	if key == Data.DIFFICULTY_DEFAULT:
		head.add_child(UiKit.chip("Recommandé", GameTheme.GOLD))
	head.add_child(UiKit.spacer())
	var pick := UiKit.button("Choisi" if on else "Choisir", "pri" if on else "", true)
	pick.disabled = on
	pick.pressed.connect(func() -> void:
		selected = key
		_rebuild())
	head.add_child(pick)
	v.add_child(head)
	v.add_child(UiKit.para(Difficulty.desc(key), 14))
	for l in Difficulty.summary_lines(key):
		v.add_child(UiKit.sub(str(l), 13))
	p.add_child(v)
	return p
