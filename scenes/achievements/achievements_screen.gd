class_name AchievementsScreen
extends RefCounted
## Écran « Succès et statistiques » : compteurs de la partie en cours et liste des succès (conservés entre les parties).


static func open(host: Node) -> ModalOverlay:
	var modal: ModalOverlay = ModalOverlay.open(host, 760)
	var box: VBoxContainer = modal.content
	var total: int = Achievements.DEFS.size()
	var got: int = 0
	for d in Achievements.DEFS:
		if Game.unlocked.has(d["id"]):
			got += 1
	box.add_child(UiKit.title("Succès et statistiques", 32))
	box.add_child(UiKit.sub("%d succès sur %d débloqués. Ils sont conservés d'une partie à l'autre." % [got, total], 14))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := UiKit.vbox(8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	box.add_child(scroll)

	inner.add_child(UiKit.label("Statistiques de la campagne", 17, GameTheme.GOLD, true))
	if Game.roster.is_empty() and Game.world == null:
		inner.add_child(UiKit.sub("Aucune partie en cours.", 14))
	else:
		inner.add_child(_stats_grid())
	inner.add_child(UiKit.label("Succès", 17, GameTheme.GOLD, true))
	var ctx: Dictionary = Game.achievement_context() if (not Game.roster.is_empty()) else {}
	for d in Achievements.DEFS:
		inner.add_child(_row(d, ctx))
	var close := UiKit.button("Fermer", "pri")
	close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(modal.close)
	box.add_child(close)
	return modal


static func _stats_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 3)
	var rows: Array = [["Jour", str(Game.day)]]
	for k in Achievements.STAT_LABELS:
		var v: Variant = Game.stats.get(k, 0)
		rows.append([str(Achievements.STAT_LABELS[k]), ("%.1f" % float(v)) if k == "travel_days" else str(int(v))])
	for r in rows:
		var kl := UiKit.sub(str(r[0]), 13, false)
		kl.custom_minimum_size = Vector2(200, 0)
		g.add_child(kl)
		g.add_child(UiKit.label(str(r[1]), 14, GameTheme.INK, true))
	return g


static func _row(d: Dictionary, ctx: Dictionary) -> Control:
	var done: bool = Game.unlocked.has(d["id"])
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	var h := UiKit.hbox(10)
	h.add_child(UiKit.label("★" if done else "☆", 22, GameTheme.GOLD if done else GameTheme.LINE, true))
	var v := UiKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label(str(d["n"]), 16, GameTheme.INK if done else GameTheme.MUTE, true))
	v.add_child(UiKit.sub(str(d["d"]), 13))
	h.add_child(v)
	if done:
		h.add_child(UiKit.sub("jour %d" % int(Game.unlocked[d["id"]]), 12, false))
	elif int(d["min"]) > 1:
		var cur: float = Achievements.value_of(d, Game.stats, ctx)
		h.add_child(UiKit.sub("%d / %d" % [mini(int(cur), int(d["min"])), int(d["min"])], 13, false))
	p.add_child(h)
	if not done:
		p.modulate = Color(1, 1, 1, 0.8)
	return p
