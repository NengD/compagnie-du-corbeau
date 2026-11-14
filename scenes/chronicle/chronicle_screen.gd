class_name ChronicleScreen
extends RefCounted
## Journal de campagne (chronologie filtrable) et Mémorial (les hommes tombés). Lecture seule :
## les données viennent de `Game.extras["chronicle"]` (core/chronicle.gd) et de `Game.fallen`.

const LIST_H := 400

## État de l'onglet et du filtre (par fenêtre) : [onglet, filtre].
static func open(host: Node, tab: String = "journal") -> ModalOverlay:
	var modal: ModalOverlay = ModalOverlay.open(host, 760)
	var state: Array = [tab, ""]
	var body := UiKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.content.add_child(UiKit.title("Journal de la compagnie", 32))
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
		build(body, str(state[0]), str(state[1]), func(t: String, f: String) -> void:
			state[0] = t
			state[1] = f
			(rebuild[0] as Callable).call_deferred())
	(rebuild[0] as Callable).call()
	return modal


## Remplit `box` pour l'onglet `tab` ("journal" | "memorial") et le filtre `kind` (genre de Chronicle.KINDS, "" = tout).
## `on_change(tab, kind)` est appelé quand le joueur change d'onglet ou de filtre. Testable sans fenêtre.
static func build(box: VBoxContainer, tab: String, kind: String, on_change: Callable) -> void:
	var tabs := UiKit.hbox(6)
	for t in [["journal", "Journal"], ["memorial", "Mémorial"]]:
		var b := UiKit.button(str(t[1]), "pri" if tab == str(t[0]) else "ghost", true)
		var key: String = str(t[0])
		b.pressed.connect(func() -> void: on_change.call(key, ""))
		tabs.add_child(b)
	box.add_child(tabs)
	if tab == "memorial":
		_build_memorial(box)
	else:
		_build_journal(box, kind, on_change)


static func _scroll(box: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := UiKit.vbox(4)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	box.add_child(scroll)
	return inner


static func _build_journal(box: VBoxContainer, kind: String, on_change: Callable) -> void:
	var counts: Dictionary = Chronicle.counts(Game.extras)
	var total: int = 0
	for k in counts:
		total += int(counts[k])
	var flt := HFlowContainer.new()
	flt.add_theme_constant_override("h_separation", 6)
	flt.add_theme_constant_override("v_separation", 4)
	var all_b := UiKit.button("Tout (%d)" % total, "pri" if kind == "" else "ghost", true)
	all_b.pressed.connect(func() -> void: on_change.call("journal", ""))
	flt.add_child(all_b)
	for k in Chronicle.KINDS:
		var key: String = str(k)
		var fb := UiKit.button("%s (%d)" % [Chronicle.KINDS[k], int(counts.get(k, 0))], "pri" if kind == key else "ghost", true)
		fb.pressed.connect(func() -> void: on_change.call("journal", key))
		flt.add_child(fb)
	box.add_child(flt)
	var list: VBoxContainer = _scroll(box)
	var entries: Array = Chronicle.entries(Game.extras, kind)
	if entries.is_empty():
		list.add_child(UiKit.sub("Rien à signaler pour l'instant. Les batailles, les morts et les exploits seront consignés ici.", 14))
		return
	for e in entries:
		var row := UiKit.hbox(10)
		var day := UiKit.label("Jour %d" % int(e["d"]), 13, GameTheme.MUTE)
		day.custom_minimum_size = Vector2(62, 0)
		row.add_child(day)
		var txt := UiKit.para(str(e["x"]), 14)
		var k: String = str(e["k"])
		if k == "death":
			txt.add_theme_color_override("font_color", Color("ff8a78"))
		elif k == "goal" or k == "level":
			txt.add_theme_color_override("font_color", GameTheme.GOLD)
		row.add_child(txt)
		list.add_child(row)


static func _build_memorial(box: VBoxContainer) -> void:
	var fallen: Array = Game.fallen
	box.add_child(UiKit.sub("%d homme%s tombé%s au service de la compagnie." % [fallen.size(), "s" if fallen.size() > 1 else "", "s" if fallen.size() > 1 else ""] if not fallen.is_empty() else "Personne n'est encore tombé. Cela ne durera pas.", 14))
	var list: VBoxContainer = _scroll(box)
	for i in range(fallen.size() - 1, -1, -1):
		var f: Dictionary = fallen[i]
		var p := PanelContainer.new()
		p.theme_type_variation = "Card"
		var v := UiKit.vbox(2)
		var top := UiKit.hbox(8)
		top.add_child(UiKit.label("✝ " + str(f["name"]), 17, GameTheme.INK, true))
		top.add_child(UiKit.spacer())
		top.add_child(UiKit.label("Jour %d" % int(f["day"]), 13, GameTheme.MUTE))
		v.add_child(top)
		v.add_child(UiKit.sub("%s · niveau %d · %d victime%s" % [str(f["bg"]), int(f["lvl"]), int(f["kills"]), "s" if int(f["kills"]) > 1 else ""], 13))
		v.add_child(UiKit.sub(Chronicle.epitaph(str(f["name"])), 12))
		p.add_child(v)
		list.add_child(p)
