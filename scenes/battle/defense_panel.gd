class_name DefensePanel
extends RefCounted
## Phase de préparation d'une bataille défensive : choisir combien de palissades, de pieux et de pièges poser sur la moitié
## de la compagnie, dans la limite des matériaux. Les cases sont choisies par `Defense.apply_plan` ; la bataille ne commence
## qu'à « Commencer la bataille ». Les widgets ne sont jamais reconstruits (seuls leurs textes changent).


## Ouvre le panneau sur `host`. `on_done` est appelé une fois la préparation terminée (la fenêtre est alors fermée).
static func open(host: Node, s: BattleState, on_done: Callable) -> ModalOverlay:
	var m: ModalOverlay = ModalOverlay.open(host, 480)
	var box: VBoxContainer = m.content
	var c: Dictionary = Defense.cfg(s.contract)
	box.add_child(UiKit.label("Préparation de la défense", 13, GameTheme.GOLD, true))
	box.add_child(UiKit.title(str(s.contract.get("title", "Défense")), 26))
	var waves: int = 1 + (c["waves"] as Array).size()
	box.add_child(UiKit.para("Les assaillants arriveront en %d vague%s. La milice du lieu se joint à vous ; %d villageois sont à protéger. Posez des défenses devant votre ligne avant le premier coup." % [waves, "s" if waves > 1 else "", int(c["civ"])]))
	var mat_label: Label = UiKit.label("", 16, GameTheme.GOLD, true)
	box.add_child(mat_label)
	var plan: Dictionary = (c["plan"] as Dictionary).duplicate()
	var counts: Dictionary = {}  ## option -> Label du compteur
	var state_ref: Array = [plan]  ## (conteneur : les lambdas capturent par valeur)

	var refresh: Callable = func() -> void:
		var p: Dictionary = state_ref[0]
		var left: int = Defense.materials(s) - Defense.plan_cost(p)
		mat_label.text = "Matériaux : %d / %d" % [left, Defense.materials(s)]
		for k in Defense.ORDER:
			(counts[k] as Label).text = str(int(p.get(k, 0)))

	var apply: Callable = func() -> void:
		var res: Dictionary = Defense.apply_plan(s, state_ref[0])
		state_ref[0] = (Defense.cfg(s.contract)["plan"] as Dictionary).duplicate()
		if int(res["skipped"]) > 0:
			mat_label.tooltip_text = "Certaines défenses n'ont pas trouvé de place ou de matériaux."
		refresh.call()

	for k in Defense.ORDER:
		var o: Dictionary = Defense.OPTIONS[k]
		var row: HBoxContainer = UiKit.hbox(8)
		var info: VBoxContainer = UiKit.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label("%s  (%d)" % [str(o["n"]), int(o["cost"])], 16, GameTheme.INK, true))
		info.add_child(UiKit.sub(str(o["d"])))
		row.add_child(info)
		var minus: Button = UiKit.button("−", "ghost", true)
		var cnt: Label = UiKit.label("0", 16, GameTheme.INK, true)
		cnt.custom_minimum_size = Vector2(28, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus: Button = UiKit.button("+", "ghost", true)
		counts[k] = cnt
		var key: String = str(k)
		minus.pressed.connect(func() -> void:
			var p: Dictionary = state_ref[0]
			p[key] = maxi(0, int(p.get(key, 0)) - 1)
			apply.call())
		plus.pressed.connect(func() -> void:
			var p: Dictionary = state_ref[0]
			var cost: int = int(Defense.OPTIONS[key]["cost"])
			if Defense.plan_cost(p) + cost <= Defense.materials(s) and int(p.get(key, 0)) < Defense.MAX_PER_OPTION:
				p[key] = int(p.get(key, 0)) + 1
				apply.call())
		row.add_child(minus)
		row.add_child(cnt)
		row.add_child(plus)
		box.add_child(row)

	var go: Button = UiKit.button("Commencer la bataille", "pri")
	go.pressed.connect(func() -> void:
		Defense.finish_prepare(s)
		m.close()
		on_done.call())
	var reset: Button = UiKit.button("Disposition par défaut", "ghost", true)
	reset.pressed.connect(func() -> void:
		state_ref[0] = Defense.default_plan(Defense.materials(s))
		apply.call())
	var foot: HBoxContainer = UiKit.hbox(8)
	foot.add_child(reset)
	foot.add_child(UiKit.spacer())
	foot.add_child(go)
	box.add_child(foot)
	refresh.call()
	return m
