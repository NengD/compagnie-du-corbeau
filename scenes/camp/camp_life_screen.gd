class_name CampLifeScreen
extends RefCounted
## Fenêtre d'une veillée au camp (core/camp_life.gd) : un récit, deux ou trois choix avec leurs conséquences annoncées,
## puis l'issue. N'applique aucune règle : lit `Game.camp_life_view()` et appelle `Game.camp_life_choose`.

static var _current: ModalOverlay = null


## Ouvre la fenêtre de la veillée en attente (null s'il n'y en a pas ou si une fenêtre est déjà ouverte).
static func open(host: Node, on_done: Callable = Callable()) -> ModalOverlay:
	if _current != null and is_instance_valid(_current):
		return null
	var view: Dictionary = Game.camp_life_view()
	if view.is_empty():
		return null
	var modal: ModalOverlay = ModalOverlay.open(host, 520)
	_current = modal
	build_choices(modal, view, on_done)
	return modal


static func is_open() -> bool:
	return _current != null and is_instance_valid(_current)


static func build_choices(modal: ModalOverlay, view: Dictionary, on_done: Callable) -> void:
	var box: VBoxContainer = modal.content
	_clear(box)
	box.add_child(UiKit.label("Veillée au camp", 13, GameTheme.GOLD, true))
	box.add_child(UiKit.title(str(view["title"]), 26))
	box.add_child(UiKit.para(str(view["text"])))
	for c in view["choices"]:
		var v := UiKit.vbox(1)
		var b := UiKit.button(str(c["label"]), "", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = bool(c["disabled"])
		var id: String = str(c["id"])
		b.pressed.connect(func() -> void:
			var lines: Array = Game.camp_life_choose(id)
			build_result(modal, lines, on_done))
		v.add_child(b)
		v.add_child(UiKit.sub(str(c["hint"]) + (" (impossible : pas assez de ressources)" if bool(c["disabled"]) else ""), 12))
		box.add_child(v)


static func build_result(modal: ModalOverlay, lines: Array, on_done: Callable) -> void:
	var box: VBoxContainer = modal.content
	_clear(box)
	box.add_child(UiKit.title("Au petit matin", 26))
	for l in lines:
		box.add_child(UiKit.para(str(l)))
	if lines.is_empty():
		box.add_child(UiKit.para("La nuit passe, sans suite."))
	var ok := UiKit.button("Continuer", "pri")
	ok.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ok.pressed.connect(func() -> void:
		modal.close()
		if on_done.is_valid():
			on_done.call())
	box.add_child(ok)


static func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
