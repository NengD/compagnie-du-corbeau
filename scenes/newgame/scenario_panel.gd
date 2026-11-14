class_name ScenarioPanel
extends RefCounted
## Étape « Départ » de la nouvelle partie (après la difficulté) : Partie libre ou un scénario, et la case « Mode fer ».
## `on_start` reçoit {"scenario": clé ("" = partie libre), "ironman": bool} ; `on_back` ramène à la difficulté.
## Aucune règle ici : tout vient de core/scenarios.gd / scenarios_data.gd / ironman.gd.

var modal: ModalOverlay
var selected: String = Scenarios.FREE
var ironman: bool = false
var on_start: Callable
var on_back: Callable


static func open(host: Node, p_on_start: Callable, p_on_back: Callable = Callable(), p_opts: Dictionary = {}) -> ScenarioPanel:
	var p := ScenarioPanel.new()
	p.on_start = p_on_start
	p.on_back = p_on_back
	p.selected = str(p_opts.get("scenario", Scenarios.FREE))
	p.ironman = bool(p_opts.get("ironman", false))
	p.modal = ModalOverlay.open(host, 700)
	p._rebuild()
	return p


func options() -> Dictionary:
	return {"scenario": selected, "ironman": ironman}


func _rebuild() -> void:
	var box: VBoxContainer = modal.content
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_child(UiKit.title("Départ", 34))
	box.add_child(UiKit.sub("Partie libre, ou un scénario avec un objectif et une limite de jours.", 14))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := UiKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)
	list.add_child(_card(Scenarios.FREE))
	for k in Scenarios.keys():
		list.add_child(_card(str(k)))
	var iron := CheckBox.new()
	iron.text = Ironman.LABEL + " — mort définitive stricte"
	iron.button_pressed = ironman
	iron.focus_mode = Control.FOCUS_ALL
	iron.tooltip_text = Ironman.HINT
	iron.toggled.connect(func(on: bool) -> void: ironman = on)
	box.add_child(iron)
	box.add_child(UiKit.sub(Ironman.HINT, 12))
	var row := UiKit.hbox(8)
	var go := UiKit.button("Suivant", "pri")
	go.pressed.connect(func() -> void:
		modal.close()
		if on_start.is_valid():
			on_start.call(options()))
	row.add_child(go)
	var back := UiKit.button("Retour", "ghost")
	back.pressed.connect(func() -> void:
		modal.close()
		if on_back.is_valid():
			on_back.call())
	row.add_child(back)
	box.add_child(row)


func _card(key: String) -> Control:
	var on: bool = key == selected
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	var v := UiKit.vbox(3)
	var head := UiKit.hbox(8)
	head.add_child(UiKit.label(Scenarios.label(key), 19, GameTheme.GOLD if on else GameTheme.INK, true))
	if key != Scenarios.FREE:
		head.add_child(UiKit.chip("%d jours" % int(Scenarios.data(key)["days"]), GameTheme.MUTE))
	head.add_child(UiKit.spacer())
	var pick := UiKit.button("Choisi" if on else "Choisir", "pri" if on else "", true)
	pick.disabled = on
	pick.pressed.connect(func() -> void:
		selected = key
		_rebuild())
	head.add_child(pick)
	v.add_child(head)
	if key == Scenarios.FREE:
		v.add_child(UiKit.para("Aucune limite : bâtissez votre légende à votre rythme, jusqu'à la crise finale.", 14))
	else:
		var d: Dictionary = Scenarios.data(key)
		v.add_child(UiKit.para(str(d["desc"]), 14))
		v.add_child(UiKit.sub("Règle : " + str(d["rule"]), 13))
		v.add_child(UiKit.sub("Objectif : %s — en %d jours. %d hommes au départ." % [Scenarios.goal_text(key), int(d["days"]), (d["men"] as Array).size()], 13))
	p.add_child(v)
	return p
