class_name LegacyScreen
extends RefCounted
## Retraite d'un vétéran (instructeur ou retraité honoré, objet de famille légué) et panneau « Héritage » de la compagnie
## (instructeur, retraités, objets de famille à remettre, recrues « fils / fille de »). Règles dans core/legacy.gd ;
## cet écran ne fait que lire `Game` et appeler `Game.retire_man / bestow_heirloom / hire_heir`.


## Fenêtre de retraite de l'homme `id` (confirmation en deux temps : choix puis bouton « Confirmer »).
static func open_retire(host: Node, id: int) -> ModalOverlay:
	var m: Unit = Game.member(id)
	if m == null:
		return null
	var modal: ModalOverlay = ModalOverlay.open(host, 540)
	var state: Array = [("instructor" if not Legacy.has_instructor(Game.extras) else "memorial"), ""]  ## [rôle, pièce léguée]
	var rebuild: Array = [Callable()]
	rebuild[0] = func() -> void:
		_clear(modal.content)
		build_retire(modal, m, state, rebuild[0])
	(rebuild[0] as Callable).call()
	return modal


static func build_retire(modal: ModalOverlay, m: Unit, state: Array, rebuild: Callable) -> void:
	var box: VBoxContainer = modal.content
	box.add_child(UiKit.title("Retraite de %s" % m.unit_name, 28))
	var why: String = Legacy.retire_block(m, Game.roster.size(), Game.battle != null)
	box.add_child(UiKit.para("%s, niveau %d, %d victime%s. Il ne combattra plus et ne coûtera plus de solde. Sa retraite sera inscrite au mémorial." % [m.background, m.level, m.kills, "s" if m.kills > 1 else ""]))
	if why != "":
		box.add_child(UiKit.label(why, 14, GameTheme.BLOOD))
	box.add_child(UiKit.label("Son rôle", 15, GameTheme.GOLD, true))
	var roles := UiKit.hbox(6)
	var inst_ok: bool = not Legacy.has_instructor(Game.extras)
	for r in [["instructor", "Instructeur du camp (+%d %% d'XP pour tous)" % int(Legacy.XP_BONUS * 100.0)], ["memorial", "Retraite honorée"]]:
		var key: String = str(r[0])
		var b := UiKit.button(str(r[1]), "pri" if str(state[0]) == key else "", true)
		b.disabled = key == "instructor" and not inst_ok
		if key == "instructor" and not inst_ok:
			b.tooltip_text = "Le camp a déjà un instructeur."
		b.pressed.connect(func() -> void:
			state[0] = key
			rebuild.call_deferred())
		roles.add_child(b)
	box.add_child(roles)
	box.add_child(UiKit.label("Objet de famille légué", 15, GameTheme.GOLD, true))
	box.add_child(UiKit.sub("La pièce choisie devient un objet de famille nommé, avec un petit bonus pour celui qui la recevra. Le reste de l'équipement rejoint la réserve.", 12))
	var pieces := HFlowContainer.new()
	pieces.add_theme_constant_override("h_separation", 6)
	pieces.add_theme_constant_override("v_separation", 6)
	var opts: Array = [{"kind": "", "label": "Aucun"}]
	opts.append_array(Legacy.heirloom_choices(m))
	for o in opts:
		var k: String = str(o["kind"])
		var txt: String = str(o["label"])
		if k != "":
			txt += " (%s)" % Legacy.bonus_text(Legacy.bonus_for(o["item"]))
		var pb := UiKit.button(txt, "pri" if str(state[1]) == k else "", true)
		pb.pressed.connect(func() -> void:
			state[1] = k
			rebuild.call_deferred())
		pieces.add_child(pb)
	box.add_child(pieces)
	var row := UiKit.hbox(8)
	var ok := UiKit.button("Confirmer la retraite", "pri")
	ok.disabled = why != ""
	ok.pressed.connect(func() -> void:
		if Game.retire_man(m.id, str(state[0]), str(state[1])):
			modal.close())
	row.add_child(ok)
	var no := UiKit.button("Annuler")
	no.pressed.connect(func() -> void: modal.close())
	row.add_child(no)
	box.add_child(row)


## Panneau « Héritage » : instructeur, retraités, objets de famille.
static func open_family(host: Node) -> ModalOverlay:
	var modal: ModalOverlay = ModalOverlay.open(host, 620)
	var rebuild: Array = [Callable()]
	rebuild[0] = func() -> void:
		_clear(modal.content)
		build_family(modal, rebuild[0])
	(rebuild[0] as Callable).call()
	return modal


static func build_family(modal: ModalOverlay, rebuild: Callable) -> void:
	var box: VBoxContainer = modal.content
	var st: Dictionary = Legacy.state(Game.extras)
	box.add_child(UiKit.title("Héritage de la compagnie", 28))
	var ins: Dictionary = st["instructor"]
	box.add_child(UiKit.para("Instructeur du camp : %s (+%d %% d'XP pour tous après chaque bataille)." % [str(ins["name"]), int(Legacy.XP_BONUS * 100.0)] if not ins.is_empty() else "Pas d'instructeur. Un vétéran (niveau %d ou gravement blessé) peut prendre sa retraite depuis sa fiche de la Compagnie." % Legacy.MIN_LEVEL))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := UiKit.vbox(6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	box.add_child(scroll)
	inner.add_child(UiKit.label("Objets de famille", 16, GameTheme.GOLD, true))
	var hls: Array = st["heirlooms"]
	if hls.is_empty():
		inner.add_child(UiKit.sub("Aucun pour l'instant : un vétéran en lègue un en prenant sa retraite.", 13))
	for h in hls:
		var card := UiKit.card(inner)
		card.add_child(UiKit.label("%s · %s" % [str(h["name"]), Legacy.bonus_text(h)], 15, GameTheme.INK, true))
		var holder: Unit = Game.member(int(h["holder"]))
		if holder != null:
			card.add_child(UiKit.sub("Porté par %s." % holder.unit_name, 13))
			continue
		card.add_child(UiKit.sub("À remettre à un homme de la même origine (%s)." % str(h["bg"]), 13))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		var heirs: Array = Legacy.eligible_heirs(Game.extras, Game.roster, h)
		for u in heirs:
			var hb := UiKit.button("Remettre à %s" % (u as Unit).unit_name, "", true)
			var hid: int = int(h["id"])
			var uid: int = (u as Unit).id
			hb.pressed.connect(func() -> void:
				Game.bestow_heirloom(hid, uid)
				rebuild.call_deferred())
			flow.add_child(hb)
		var price: int = Legacy.heir_price(h)
		var sb := UiKit.button("Engager un fils ou une fille (%d couronnes)" % price, "", true)
		sb.disabled = Game.gold < price or Game.roster.size() >= Game.max_roster() or price <= 0
		var hid2: int = int(h["id"])
		sb.pressed.connect(func() -> void:
			Game.hire_heir(hid2)
			rebuild.call_deferred())
		flow.add_child(sb)
		card.add_child(flow)
	inner.add_child(UiKit.label("Retraités (%d)" % (st["retired"] as Array).size(), 16, GameTheme.GOLD, true))
	var rl: Array = st["retired"]
	for i in range(rl.size() - 1, -1, -1):
		var r: Dictionary = rl[i]
		inner.add_child(UiKit.sub("%s · %s niv. %d · %s, jour %d%s" % [str(r["name"]), str(r["bg"]), int(r["lvl"]), str(Legacy.ROLES.get(str(r["role"]), "retraité")), int(r["day"]), (" · lègue « %s »" % str(r["hl"])) if str(r["hl"]) != "" else ""], 13))
	var close := UiKit.button("Fermer", "pri")
	close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func() -> void: modal.close())
	box.add_child(close)


static func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
