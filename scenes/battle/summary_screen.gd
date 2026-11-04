class_name SummaryScreen
extends RefCounted
## Résumé affiché après une bataille : par homme (PV avant/après, XP, victimes, niveau, blessures), butin, prime et renom, tombés.
## Les données viennent de `Game.last_battle_report` (rempli par `Game.finish_battle`) ; aucune règle ici.

const MAX_LIST_H := 330


## Ouvre le résumé de `report` dans une fenêtre modale sur `host`. Renvoie la fenêtre, ou null si le compte rendu est vide.
static func open(host: Node, report: Dictionary) -> ModalOverlay:
	if report.is_empty():
		return null
	var m := ModalOverlay.open(host, 600)
	build(m.content, report, func() -> void: m.close())
	return m


## Remplit `box` (testable sans fenêtre). `on_close` est appelé par le bouton « Continuer ».
static func build(box: VBoxContainer, report: Dictionary, on_close: Callable) -> void:
	var result: String = str(report.get("result", ""))
	var win: bool = result == "win"
	var heading: String = "Victoire" if win else ("Retraite" if result == "retreat" else "Défaite")
	box.add_child(Illustrations.banner("victory" if win else "defeat", 90))
	box.add_child(UiKit.title(heading, 38, GameTheme.GOLD if win else GameTheme.BLOOD))
	box.add_child(UiKit.sub(str(report.get("title", "")), 14))
	var gold: int = int(report.get("gold", 0))
	var renown: int = int(report.get("renown", 0))
	var rewards := UiKit.hbox(18)
	rewards.add_child(UiKit.label("Prime : %+d couronnes" % gold if gold != 0 else "Prime : aucune", 16, GameTheme.GOLD if gold > 0 else GameTheme.MUTE, true))
	rewards.add_child(UiKit.label("Renom : %+d" % renown, 16, GameTheme.GOLD if renown > 0 else (GameTheme.BLOOD if renown < 0 else GameTheme.MUTE), true))
	box.add_child(rewards)
	var fallen: Array = report.get("fallen", [])
	if fallen.is_empty():
		box.add_child(UiKit.sub("Aucun mort à déplorer."))
	else:
		box.add_child(UiKit.label("Tombés : " + ", ".join(fallen), 15, Color("ff8a78")))
	box.add_child(UiKit.label("La compagnie", 15, GameTheme.GOLD, true))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := UiKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for r in report.get("men", []):
		list.add_child(_man_row(r))
	box.add_child(scroll)
	var loot: Array = report.get("loot", [])
	if win or not loot.is_empty():
		if loot.is_empty():
			box.add_child(UiKit.sub("Rien de récupérable sur les dépouilles."))
		else:
			box.add_child(UiKit.label("Butin récupéré (%d)" % loot.size(), 15, GameTheme.GOLD, true))
			var ls := ScrollContainer.new()
			ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			ls.custom_minimum_size = Vector2(0, mini(loot.size(), 3) * 34)
			var lb := UiKit.vbox(4)
			lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for it in loot:
				lb.add_child(ItemUi.row(it, false))
			ls.add_child(lb)
			box.add_child(ls)
	var b := UiKit.button("Continuer", "pri")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(on_close)
	box.add_child(b)


static func _man_row(r: Dictionary) -> Control:
	var u: Unit = Unit.from_dict(r["u"])
	var dead: bool = bool(r.get("dead", false))
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	var h := UiKit.hbox(10)
	var pv := PortraitView.new(u, 44)
	if dead:
		pv.modulate = Color(0.6, 0.55, 0.55, 0.8)
	h.add_child(pv)
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UiKit.hbox(6)
	top.add_child(UiKit.label(u.unit_name, 16, GameTheme.MUTE if dead else GameTheme.INK, true))
	if dead:
		top.add_child(UiKit.chip("Tombé", GameTheme.BLOOD))
	else:
		if int(r.get("lvl_after", 0)) > int(r.get("lvl_before", 0)):
			top.add_child(UiKit.chip("Niveau %d !" % int(r["lvl_after"]), GameTheme.GOLD))
		for w in r.get("wounds", []):
			top.add_child(UiKit.chip(str(w), Color("e08a6a")))
	v.add_child(top)
	var hp_after: int = int(r.get("hp_after", 0))
	var line: String
	if dead:
		line = "PV %d → 0 · %d victime%s" % [int(r.get("hp_before", 0)), int(r.get("kills", 0)), "s" if int(r.get("kills", 0)) > 1 else ""]
	else:
		line = "PV %d → %d / %d · XP +%d · %d victime%s" % [int(r.get("hp_before", 0)), hp_after, u.hp_max, int(r.get("xp", 0)), int(r.get("kills", 0)), "s" if int(r.get("kills", 0)) > 1 else ""]
	v.add_child(UiKit.sub(line, 13))
	h.add_child(v)
	p.add_child(h)
	return p
