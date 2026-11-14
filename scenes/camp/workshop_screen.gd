class_name WorkshopScreen
extends RefCounted
## Atelier du forgeron (au camp, en lieu) : réparation pièce par pièce et par paliers (25 / 50 / 100 %), aiguisage des armes
## tranchantes, huilage des hauberts de mailles. Toute la logique est dans core/upkeep.gd et les fonctions d'atelier de Game ;
## cet écran n'affiche que l'état et émet des actions.

const LIST_H := 420


static func open(host: Node) -> ModalOverlay:
	var modal: ModalOverlay = ModalOverlay.open(host, 820)
	var body := UiKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.content.add_child(UiKit.title("Atelier du forgeron", 32))
	modal.content.add_child(body)
	var close_b := UiKit.button("Fermer", "pri")
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close_b.pressed.connect(func() -> void: modal.close())
	modal.content.add_child(close_b)
	var rebuild: Array = [Callable()]
	rebuild[0] = func() -> void:
		for c in body.get_children():
			body.remove_child(c)
			c.queue_free()
		build(body, func() -> void: (rebuild[0] as Callable).call_deferred())
	(rebuild[0] as Callable).call()
	return modal


## Remplit `box`. `on_change` est appelé après chaque action réussie. Testable sans fenêtre.
static func build(box: VBoxContainer, on_change: Callable) -> void:
	var sm: Dictionary = Game.smith()
	if sm.is_empty():
		box.add_child(UiKit.sub("Il faut être dans une ville ou un village pour trouver un forgeron.", 14))
		return
	var mail_txt: String = "travaille les mailles" if bool(sm["mail"]) else "ne travaille pas les mailles"
	var head := UiKit.hbox(10)
	head.add_child(UiKit.label("Vous êtes chez le %s : tarifs ×%s, %s." % [str(sm["n"]), _num(float(sm["price"]) * Game.upkeep_mult()), mail_txt], 15, GameTheme.INK, true))
	var gold := UiKit.sub("%d couronnes" % Game.gold, 14, false)
	gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(gold)
	box.add_child(head)
	var tip := UiKit.sub("Aiguisage (armes tranchantes) : +%d %% de dégâts pendant %d combats. Huile (mailles) : l'armure s'use %d %% de moins pendant %d combats." % [int(sm["edge"]), int(sm["combats"]), int(sm["oil"]), int(sm["combats"])], 13)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	var err := UiKit.sub("", 13)
	err.add_theme_color_override("font_color", GameTheme.BLOOD)
	box.add_child(err)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UiKit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)
	for m in Game.roster:
		_man_card(list, m, sm, err, on_change)


static func _num(x: float) -> String:
	return str(snappedf(x, 0.01)).replace(".", ",")


static func _man_card(list: VBoxContainer, m: Unit, sm: Dictionary, err: Label, on_change: Callable) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var v := UiKit.vbox(4)
	v.add_child(UiKit.label(m.unit_name, 16, GameTheme.INK, true))
	var any: bool = false
	for slot in Upkeep.SLOTS:
		var p: Dictionary = Upkeep.piece(m, slot)
		if not bool(p["have"]):
			continue
		any = true
		v.add_child(_piece_row(m, slot, p, sm, err, on_change))
	var extras := UiKit.hbox(6)
	var edge_b := UiKit.button("Aiguiser (%d)" % Game.sharpen_cost(m), "ghost", true)
	var why_e: String = Game.sharpen_block(m)
	edge_b.disabled = why_e != ""
	edge_b.tooltip_text = why_e if why_e != "" else "Arme aiguisée : +%d %% de dégâts pendant %d combats." % [int(sm["edge"]), int(sm["combats"])]
	edge_b.pressed.connect(func() -> void: _act(Game.sharpen(m), err, on_change))
	extras.add_child(edge_b)
	var oil_b := UiKit.button("Huiler (%d)" % Game.oil_cost(m), "ghost", true)
	var why_o: String = Game.oil_block(m)
	oil_b.disabled = why_o != ""
	oil_b.tooltip_text = why_o if why_o != "" else "Haubert huilé : l'armure s'use %d %% de moins pendant %d combats." % [int(sm["oil"]), int(sm["combats"])]
	oil_b.pressed.connect(func() -> void: _act(Game.oil(m), err, on_change))
	extras.add_child(oil_b)
	var st: String = _upkeep_text(m)
	if st != "":
		extras.add_child(UiKit.sub(st, 13, false))
	v.add_child(extras)
	if not any:
		v.add_child(UiKit.sub("Rien à réparer.", 13))
	card.add_child(v)
	list.add_child(card)


static func _upkeep_text(m: Unit) -> String:
	var parts: Array[String] = []
	if Upkeep.edge_left(m) > 0:
		parts.append("arme aiguisée (%d combat%s)" % [Upkeep.edge_left(m), "s" if Upkeep.edge_left(m) > 1 else ""])
	if Upkeep.oil_left(m) > 0:
		parts.append("haubert huilé (%d combat%s)" % [Upkeep.oil_left(m), "s" if Upkeep.oil_left(m) > 1 else ""])
	return " · ".join(parts)


static func _piece_row(m: Unit, slot: String, p: Dictionary, sm: Dictionary, err: Label, on_change: Callable) -> Control:
	var row := UiKit.hbox(6)
	var item: Dictionary
	match slot:
		"weapon":
			item = Loot.weapon_item(m)
		"shield":
			item = Loot.shield_item(m)
		"head":
			item = Loot.head_item(m)
		_:
			item = Loot.body_item(m)
	var name_l := UiKit.label("%s · %d/%d" % [Loot.item_name(item), int(p["cur"]), int(p["max"])], 14, ItemGrade.color_of(ItemGrade.of(item)) if ItemGrade.of(item) != 0 else GameTheme.INK, false)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	row.add_child(name_l)
	var why: String = Upkeep.why_not_repair(m, slot, sm)
	for step in Upkeep.STEPS:
		var cost: int = Game.repair_piece_cost(m, slot, step)
		var b := UiKit.button("%d %% · %d" % [roundi(step * 100.0), cost], "ghost", true)
		var block: String = Game.repair_piece_block(m, slot, step)
		b.disabled = block != ""
		b.tooltip_text = block if block != "" else "Rend %d points." % Upkeep.step_points(m, slot, step)
		if why != "" and why != "Déjà en bon état.":
			b.tooltip_text = why
		var st: float = step
		b.pressed.connect(func() -> void:
			var done: bool = Game.repair_piece(m, slot, st)
			if done:
				Sfx.play("repair")
			_act(done, err, on_change))
		row.add_child(b)
	return row


static func _act(ok: bool, err: Label, on_change: Callable) -> void:
	if ok:
		on_change.call()
	else:
		err.text = Game.shop_error
