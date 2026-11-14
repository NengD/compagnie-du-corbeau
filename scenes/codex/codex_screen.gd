class_name CodexScreen
extends RefCounted
## Encyclopédie en jeu (lecture seule) : catégories à gauche, liste filtrable au centre, fiche à droite.
## Tout vient de core/codex.gd (donc des tables). Clavier : Tab/flèches entre les boutons, Échap ferme, F1 ouvre.

## Capte Échap pour fermer la fenêtre (les touches non traitées par l'interface remontent jusqu'ici).
class EscCatcher extends Node:
	var screen: CodexScreen

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			screen.modal.close()
			get_viewport().set_input_as_handled()


var modal: ModalOverlay
var cat: String = "weapons"
var selected: String = ""
var query: String = ""
var _list_box: VBoxContainer
var _detail_box: VBoxContainer
var _cat_box: VBoxContainer
var _count_label: Label
var _search: LineEdit


## F1 : seulement hors bataille, sans autre fenêtre ouverte et hors saisie de texte.
static func can_open(host: Node) -> bool:
	if Game.battle != null or ModalOverlay.open_count > 0:
		return false
	var vp: Viewport = host.get_viewport() if host != null and host.is_inside_tree() else null
	return not (vp != null and vp.gui_get_focus_owner() is LineEdit)


static func open(host: Node, p_cat: String = "", p_id: String = "") -> CodexScreen:
	var s := CodexScreen.new()
	s.modal = ModalOverlay.open(host, 1120)
	if p_cat != "":
		s.cat = p_cat
	s.selected = p_id
	s._build()
	var esc := EscCatcher.new()
	esc.screen = s
	s.modal.add_child(esc)
	return s


func _build() -> void:
	var box: VBoxContainer = modal.content
	var head := UiKit.hbox(10)
	head.add_child(UiKit.title("Encyclopédie", 32))
	_count_label = UiKit.sub("", 13)
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_count_label)
	head.add_child(UiKit.spacer())
	var close := UiKit.button("Fermer", "ghost", true)
	close.pressed.connect(modal.close)
	head.add_child(close)
	box.add_child(head)
	var cols := UiKit.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(cols)
	_cat_box = UiKit.vbox(4)
	_cat_box.custom_minimum_size = Vector2(200, 0)
	cols.add_child(_cat_box)
	var mid := UiKit.vbox(6)
	mid.custom_minimum_size = Vector2(280, 0)
	cols.add_child(mid)
	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(t: String) -> void:
		query = t
		_fill_list())
	mid.add_child(_search)
	var ls := ScrollContainer.new()
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ls.custom_minimum_size = Vector2(0, 430)
	ls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_box = UiKit.vbox(2)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(_list_box)
	mid.add_child(ls)
	var ds := ScrollContainer.new()
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.custom_minimum_size = Vector2(430, 0)
	_detail_box = UiKit.vbox(8)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.add_child(_detail_box)
	cols.add_child(ds)
	_fill_cats()
	_fill_list()


func _fill_cats() -> void:
	for c in _cat_box.get_children():
		_cat_box.remove_child(c)
		c.queue_free()
	for c in Codex.categories():
		var id: String = str(c["id"])
		var b := UiKit.button(str(c["n"]), "pri" if id == cat else "", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: goto(id, ""))
		_cat_box.add_child(b)


## Va à une catégorie (et une fiche si `id` n'est pas vide) ; vide la recherche.
func goto(p_cat: String, id: String) -> void:
	cat = p_cat
	selected = id
	query = ""
	_search.text = ""
	_fill_cats()
	_fill_list()


func _fill_list() -> void:
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	var items: Array = Codex.search(cat, query)
	_count_label.text = "%s · %d fiche%s" % [Codex.cat_name(cat), items.size(), "s" if items.size() > 1 else ""]
	if selected == "" or not items.any(func(e: Dictionary) -> bool: return str(e["id"]) == selected):
		selected = str(items[0]["id"]) if not items.is_empty() else ""
	for e in items:
		var id: String = str(e["id"])
		var b := UiKit.button(str(e["n"]) + ("   · " + str(e["sub"]) if str(e["sub"]) != "" else ""), "pri" if id == selected else "", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var tex: Texture2D = _icon(str(e["ik"]), str(e["ikey"]))
		if tex != null:
			b.icon = tex
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 22)
		b.pressed.connect(func() -> void:
			selected = id
			_fill_list())
		_list_box.add_child(b)
	if items.is_empty():
		_list_box.add_child(UiKit.sub("Aucune fiche ne correspond."))
	_fill_detail()


static func _icon(ik: String, key: String) -> Texture2D:
	match ik:
		"perk":
			return PerkIcon.texture_of(key)
		"weapon", "head", "body", "shield", "tool":
			return ItemIcons.get_icon(ik, key)
	return null


func _fill_detail() -> void:
	for c in _detail_box.get_children():
		_detail_box.remove_child(c)
		c.queue_free()
	if selected == "":
		return
	var d: Dictionary = Codex.detail(cat, selected)
	var head := UiKit.hbox(10)
	var tex: Texture2D = _icon(str(d["ik"]), str(d["ikey"]))
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(56, 56)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(tr)
	var tv := UiKit.vbox(2)
	tv.add_child(UiKit.title(str(d["title"]), 26, GameTheme.GOLD))
	if str(d["sub"]) != "":
		tv.add_child(UiKit.sub(str(d["sub"]), 14))
	head.add_child(tv)
	_detail_box.add_child(head)
	var rows: Array = d["rows"]
	if not rows.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 3)
		for r in rows:
			grid.add_child(UiKit.label(str(r[0]), 14, GameTheme.MUTE))
			var v := UiKit.label(str(r[1]), 14, GameTheme.INK, true)
			v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.custom_minimum_size = Vector2(220, 0)
			grid.add_child(v)
		_detail_box.add_child(grid)
	for t in d["text"]:
		_detail_box.add_child(UiKit.para(str(t), 14))
	var links: Array = d["links"]
	if not links.is_empty():
		_detail_box.add_child(UiKit.label("Voir aussi", 14, GameTheme.GOLD, true))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 4)
		for l in links:
			var lc: String = str(l["cat"])
			var li: String = str(l["id"])
			var b := UiKit.button(str(l["n"]), "ghost", true)
			b.pressed.connect(func() -> void: goto(lc, li))
			flow.add_child(b)
		_detail_box.add_child(flow)
