class_name InventoryScreen
extends ModalOverlay
## Fiche de personnage « à la Battle Brothers » : à gauche l'homme choisi (portrait, niveau, XP, poupée d'équipement, talents appris,
## statistiques en barres) ; à droite deux onglets, « Inventaire » (réserve commune en grille, filtres, tri, compteurs) et « Talents »
## (arbre de talents) ; en bas, la formation de combat (FormationPanel) qui sert aussi à choisir l'homme affiché.
## Toute la logique d'équipement est dans core/inventory.gd (via Game.inv_*) ; cet écran n'affiche que l'état et relaie les gestes.
## Gestes : glisser-déposer, double-clic (équiper / déséquiper), clic droit (menu), flèches (changer d'homme), Échap ou I (fermer).

const SLOT: int = 62
const GAP: int = 4
const LEFT_W: int = 404
const FORMATION_H: int = 212

static var last_tab: String = "inventory"  ## onglet retenu pendant la session ("inventory" | "perks")

var sel_id: int = -1
var filter: String = "all"
var tab: String = "inventory"

var _left: VBoxContainer
var _tab_btns: Dictionary = {}
var _inv_view: VBoxContainer
var _perk_tree: PerkTree
var _formation: FormationPanel
var _scroll: ScrollContainer
var _grid: GridContainer
var _cap_l: Label
var _men_l: Label
var _msg_l: Label
var _preview_box: HFlowContainer
var _filter_btns: Dictionary = {}
var _rebuild_pending: bool = false
var _cols: int = 8
var _cell: int = 64
var _tree_unit: int = -2


## Ouvre l'écran (une seule instance à la fois). `member_id` : homme à sélectionner (-1 = le premier).
static func open(host: Node, member_id: int = -1) -> InventoryScreen:
	for n in host.get_tree().get_nodes_in_group("inventory_screen"):
		return n as InventoryScreen
	var layer := CanvasLayer.new()
	layer.layer = 50
	host.add_child(layer)
	var s := InventoryScreen.new()
	s._layer = layer
	s.theme = GameTheme.get_theme()
	s.sel_id = member_id
	s.tab = last_tab
	layer.add_child(s)
	s._build_screen()
	return s


func _build_screen() -> void:
	add_to_group("inventory_screen")
	Sfx.play("paper_open")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var root_panel := PanelContainer.new()
	root_panel.add_theme_stylebox_override("panel", GameTheme.box(Color("17130e"), Color("6b5630"), 2, 4, Vector4(8, 8, 8, 8)))
	margin.add_child(root_panel)
	var root := UiKit.vbox(6)
	root_panel.add_child(root)

	var body := UiKit.hbox(8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# Gauche : le personnage
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(LEFT_W, 0)
	left_panel.add_theme_stylebox_override("panel", GameTheme.box(Color("1d1812"), Color("4a3f31"), 1, 3, Vector4(8, 8, 8, 6)))
	_left = UiKit.vbox(5)
	left_panel.add_child(_left)
	body.add_child(left_panel)

	# Droite : onglets et contenu
	var right := UiKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(_build_tab_bar())
	var content := PanelContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_stylebox_override("panel", GameTheme.box(Color("1d1812"), Color("4a3f31"), 1, 3, Vector4(8, 8, 8, 8)))
	right.add_child(content)
	var stack := UiKit.vbox(0)
	content.add_child(stack)
	_inv_view = _build_inventory_view()
	_inv_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_inv_view)
	_perk_tree = PerkTree.new()
	_perk_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_perk_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_perk_tree)

	# Bas : la formation
	_formation = FormationPanel.new()
	_formation.custom_minimum_size = Vector2(0, FORMATION_H)
	_formation.size_flags_vertical = Control.SIZE_SHRINK_END
	_formation.unit_selected.connect(select)
	root.add_child(_formation)

	_scroll.resized.connect(_fit_grid)
	Game.changed.connect(_queue_rebuild)
	_apply_tab()
	_rebuild()
	_fit_grid.call_deferred()


func _exit_tree() -> void:
	if Game.changed.is_connected(_queue_rebuild):
		Game.changed.disconnect(_queue_rebuild)


func _build_tab_bar() -> Control:
	var bar := UiKit.hbox(8)
	bar.add_child(UiKit.spacer())
	var group := ButtonGroup.new()
	for pair in [["inventory", "Inventaire"], ["perks", "Talents"]]:
		var b := UiKit.button(pair[1], "pri" if pair[0] == tab else "")
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(190, 0)
		b.focus_mode = Control.FOCUS_NONE
		var key: String = pair[0]
		b.pressed.connect(func() -> void: set_tab(key))
		bar.add_child(b)
		_tab_btns[key] = b
	bar.add_child(UiKit.spacer())
	var x := UiKit.button("X", "", true)
	x.custom_minimum_size = Vector2(36, 0)
	x.tooltip_text = "Fermer (Échap)"
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(close)
	bar.add_child(x)
	return bar


func _build_inventory_view() -> VBoxContainer:
	var v := UiKit.vbox(6)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	MarketScreen.style_scrollbar(_scroll)
	var zone := StashZone.new()  # déposer ici (hors case) range l'objet dans la réserve
	zone.screen = self
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.columns = _cols
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	zone.add_child(_grid)
	_scroll.add_child(zone)
	v.add_child(_scroll)

	# Filtres, tri, compteurs
	var row := UiKit.hbox(6)
	var group := ButtonGroup.new()
	var reps: Dictionary = {"weapon": ["weapon", "epee"], "body": ["body", "gambison"], "head": ["head", "casque"], "shield": ["shield", ""], "tool": ["tool", "pierre"]}
	for f in ["all", "weapon", "body", "head", "shield", "tool"]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(46, 38)
		b.tooltip_text = str(Market.FILTER_NAMES[f])
		if f == "all":
			b.text = "Tout"
			b.add_theme_font_size_override("font_size", 13)
		else:
			var tex: Texture2D = ItemIcons.get_icon(str(reps[f][0]), str(reps[f][1]))
			if tex != null:
				b.icon = tex
				b.expand_icon = true
				b.add_theme_constant_override("icon_max_width", 28)
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				b.text = str(Market.FILTER_NAMES[f]).substr(0, 3)
		b.set_pressed_no_signal(f == filter)
		var key: String = f
		b.pressed.connect(func() -> void: set_filter(key))
		row.add_child(b)
		_filter_btns[f] = b
	row.add_child(UiKit.sub("Trier :", 13, false))
	for pair in [["type", "Type"], ["value", "Valeur"], ["wear", "Usure"]]:
		var b2 := UiKit.button(pair[1], "ghost", true)
		var mode: String = pair[0]
		b2.focus_mode = Control.FOCUS_NONE
		b2.pressed.connect(func() -> void:
			if editable():
				Game.inv_sort(mode))
		row.add_child(b2)
	row.add_child(UiKit.spacer())
	_cap_l = UiKit.label("", 15, GameTheme.INK, true)
	row.add_child(_cap_l)
	_men_l = UiKit.label("", 15, GameTheme.INK, true)
	row.add_child(_men_l)
	v.add_child(row)
	_msg_l = UiKit.label("", 14, GameTheme.INK)
	_msg_l.clip_text = true
	_msg_l.custom_minimum_size = Vector2(0, 20)
	v.add_child(_msg_l)
	return v


# --- État ---

func selected() -> Unit:
	var m: Unit = Game.member(sel_id)
	if m == null and not Game.roster.is_empty():
		m = Game.roster[0]
		sel_id = m.id
	return m


func editable() -> bool:
	return Game.can_edit_inventory()


## Prix de vente affiché dans l'infobulle d'un objet de la réserve (-1 hors réserve ou hors lieu).
func sell_value(loc: Dictionary) -> int:
	if not Inventory.is_stash(loc) or not Game.in_settlement():
		return -1
	var it: Dictionary = Inventory.get_item(Game.inventory, loc)
	return Game.sell_price(it) if not it.is_empty() else -1


func select(id: int) -> void:
	sel_id = id
	_rebuild()


## Homme suivant (+1) ou précédent (-1).
func step(d: int) -> void:
	if Game.roster.is_empty():
		return
	var i: int = Game.roster.find(selected())
	select(Game.roster[posmod(i + d, Game.roster.size())].id)


func set_filter(f: String) -> void:
	filter = f
	if _filter_btns.has(f):
		(_filter_btns[f] as Button).set_pressed_no_signal(true)
	_fill_grid()


## Change d'onglet ("inventory" ou "perks") ; le choix est gardé pour les ouvertures suivantes de la session.
func set_tab(t: String) -> void:
	tab = t if t == "perks" else "inventory"
	last_tab = tab
	_apply_tab()


func _apply_tab() -> void:
	_inv_view.visible = tab == "inventory"
	_perk_tree.visible = tab == "perks"
	for k in _tab_btns:
		(_tab_btns[k] as Button).set_pressed_no_signal(k == tab)
	if tab == "perks":
		_sync_tree()


func message(text: String, good: bool = true) -> void:
	_msg_l.text = text
	_msg_l.add_theme_color_override("font_color", GameTheme.INK if good else GameTheme.BLOOD)


# --- Gestes ---

func can_drop(src: Dictionary, dst: Dictionary) -> bool:
	if not editable() or Inventory.same_loc(src, dst):
		return false
	var it: Dictionary = Inventory.get_item(Game.inventory, src)
	if it.is_empty():
		return false
	if Inventory.is_stash(dst):
		return not Inventory.is_stash(src)
	return Inventory.why_not(dst, it) == ""


func drop(src: Dictionary, dst: Dictionary) -> void:
	_report(Game.inv_move(src, dst))


## Dépose un objet sur un homme : il le prend à son emplacement naturel (don).
func can_drop_on_member(src: Dictionary, m: Unit) -> bool:
	var it: Dictionary = Inventory.get_item(Game.inventory, src)
	if it.is_empty() or not editable() or (not Inventory.is_stash(src) and src["u"] == m):
		return false
	var slot: String = Inventory.auto_slot(m, it)
	return slot != "" and Inventory.why_not(Inventory.at(m, slot), it) == ""


func drop_on_member(src: Dictionary, m: Unit) -> void:
	var it: Dictionary = Inventory.get_item(Game.inventory, src)
	if it.is_empty():
		return
	var slot: String = Inventory.auto_slot(m, it)
	if slot == "":
		message("%s ne peut pas porter cet objet." % m.unit_name, false)
		return
	var res: Dictionary = Game.inv_move(src, Inventory.at(m, slot))
	_report(res, "%s reçoit : %s." % [m.unit_name, Loot.item_name(it)])


## Double-clic : un objet de la réserve est équipé sur l'homme choisi ; un objet porté retourne à la réserve.
func quick(loc: Dictionary) -> void:
	var m: Unit = selected()
	if m == null:
		return
	if Inventory.is_stash(loc):
		var it: Dictionary = Inventory.get_item(Game.inventory, loc)
		_report(Game.inv_equip(m, int(loc["i"])), "%s s'équipe : %s." % [m.unit_name, Loot.item_name(it)])
	else:
		var u: Unit = loc["u"]
		var it2: Dictionary = Inventory.get_item(Game.inventory, loc)
		_report(Game.inv_unequip(u, str(loc["slot"])), "%s range : %s." % [u.unit_name, Loot.item_name(it2)])


## Menu du clic droit.
func show_menu(loc: Dictionary, pos: Vector2) -> void:
	var it: Dictionary = Inventory.get_item(Game.inventory, loc)
	var m: Unit = selected()
	if it.is_empty() or m == null:
		return
	var pm := PopupMenu.new()
	add_child(pm)
	pm.popup_hide.connect(pm.queue_free)
	if Inventory.is_stash(loc):
		pm.add_item("Équiper sur %s" % m.unit_name, 0)
		pm.set_item_disabled(0, Inventory.auto_slot(m, it) == "" or not editable())
		if Game.in_settlement():
			pm.add_item("Vendre pour %d couronnes" % Game.sell_price(it), 1)
		else:
			pm.add_item("Vendre (dans un lieu seulement)", 1)
			pm.set_item_disabled(1, true)
		pm.add_item("Jeter", 2)
		pm.set_item_disabled(2, not editable())
		var idx: int = int(loc["i"])
		pm.id_pressed.connect(_stash_action.bind(idx, it))
	else:
		pm.add_item("Ranger dans la réserve", 10)
		pm.set_item_disabled(0, not editable())
		var is_bag: bool = str(loc["slot"]).begins_with("bag")
		if is_bag:
			pm.add_item("Prendre en main", 11)
			pm.set_item_disabled(1, not editable())
		pm.id_pressed.connect(_slot_action.bind(loc, it))
	pm.popup(Rect2i(Vector2i(pos), Vector2i.ZERO))


## Action choisie dans le menu d'un objet porté (10 ranger, 11 prendre en main depuis le sac).
func _slot_action(id: int, loc: Dictionary, it: Dictionary) -> void:
	var u: Unit = loc["u"]
	if id == 10:
		quick(loc)
	else:
		var dest: String = "weapon" if str(it["kind"]) == "weapon" else "shield"
		_report(Game.inv_move(loc, Inventory.at(u, dest)), "%s prend en main : %s." % [u.unit_name, Loot.item_name(it)])


## Action choisie dans le menu d'un objet de la réserve (0 équiper, 1 vendre, 2 jeter).
func _stash_action(id: int, idx: int, it: Dictionary) -> void:
	if id == 0:
		quick(Inventory.in_stash(idx))
	elif id == 1:
		if Game.sell_item(idx):
			Sfx.play("sell")
			message("%s vendu." % Loot.item_name(it))
	elif id == 2:
		if Game.discard(idx):
			message("%s jeté." % Loot.item_name(it))


func _report(res: Dictionary, ok_text: String = "") -> void:
	if bool(res["ok"]):
		var t: String = ok_text
		if str(res["msg"]) != "":
			t = (t + " " + str(res["msg"])).strip_edges()
		Sfx.play("drop")
		message(t)
	else:
		message(str(res["msg"]), false)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE, KEY_I:
			close()
		KEY_LEFT, KEY_UP:
			step(-1)
		KEY_RIGHT, KEY_DOWN:
			step(1)
		_:
			return
	get_viewport().set_input_as_handled()


func close() -> void:
	remove_from_group("inventory_screen")
	Sfx.play("paper_close")
	super.close()


# --- Construction ---

func _queue_rebuild() -> void:
	if not _rebuild_pending:
		_rebuild_pending = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_pending = false
	if not is_inside_tree():
		return
	selected()
	_formation.set_selected(sel_id)
	_build_left()
	_fill_grid()
	_refresh_counters()
	_sync_tree()


func _sync_tree() -> void:
	var u: Unit = selected()
	if tab != "perks" and _tree_unit == (u.id if u != null else -1):
		return
	if _tree_unit != (u.id if u != null else -1):
		_tree_unit = u.id if u != null else -1
		_perk_tree.set_unit(u)
	else:
		_perk_tree.refresh()


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _refresh_counters() -> void:
	var full: bool = Game.inventory.size() >= Game.stash_size()
	_cap_l.text = "Réserve %d/%d" % [Game.inventory.size(), Game.stash_size()]
	_cap_l.add_theme_color_override("font_color", GameTheme.BLOOD if full else GameTheme.INK)
	_men_l.text = "   Hommes %d/%d" % [Game.roster.size(), Game.max_roster()]


# --- Panneau du personnage ---

func _build_left() -> void:
	_clear(_left)
	var u: Unit = selected()
	if u == null:
		_left.add_child(UiKit.sub("Personne dans la compagnie."))
		return
	# En-tête : portrait, nom, niveau, XP
	var top := UiKit.hbox(10)
	top.add_child(PortraitView.new(u, 74))
	var tv := UiKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := UiKit.title(u.unit_name.to_upper(), 24, GameTheme.GOLD)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nm)
	tv.add_child(UiKit.sub("%s · niveau %d" % [u.background, u.level], 13, true))
	var nxt: int = int(Data.XP_THRESHOLDS[mini(u.level + 1, Data.XP_THRESHOLDS.size() - 1)])
	var cur0: int = int(Data.XP_THRESHOLDS[mini(u.level, Data.XP_THRESHOLDS.size() - 1)])
	var xp_row := StatRow.new("", float(u.xp - cur0), float(maxi(1, nxt - cur0)), Color("e08a1e"), "%d / %d" % [u.xp, nxt], "Expérience : %d points, prochain niveau à %d." % [u.xp, nxt], "Expérience")
	tv.add_child(xp_row)
	top.add_child(tv)
	_left.add_child(top)

	# Poupée d'équipement
	var doll := UiKit.vbox(GAP)
	doll.alignment = BoxContainer.ALIGNMENT_CENTER
	var r1 := UiKit.hbox(GAP)
	r1.alignment = BoxContainer.ALIGNMENT_CENTER
	r1.add_child(_slot_cell(u, "bag0"))
	r1.add_child(_slot_cell(u, "head"))
	r1.add_child(_slot_cell(u, "bag1"))
	var r2 := UiKit.hbox(GAP)
	r2.alignment = BoxContainer.ALIGNMENT_CENTER
	r2.add_child(_slot_cell(u, "weapon"))
	r2.add_child(_slot_cell(u, "body"))
	r2.add_child(_slot_cell(u, "shield"))
	doll.add_child(r1)
	doll.add_child(r2)
	_left.add_child(doll)

	# Talents appris
	var perks := HFlowContainer.new()
	perks.add_theme_constant_override("h_separation", 3)
	perks.add_theme_constant_override("v_separation", 3)
	perks.alignment = FlowContainer.ALIGNMENT_CENTER
	if u.perks.is_empty():
		perks.add_child(UiKit.sub("Aucun talent appris%s." % (" · %d point(s) à dépenser" % u.perk_points if u.perk_points > 0 else ""), 12, false))
	for k in u.perks:
		var pic := PerkIcon.new(k, 26, "taken")
		pic.unit = u
		perks.add_child(pic)
	_left.add_child(perks)
	var masteries: Array[String] = Perks.mastery_summary(u)  # maîtrises de l'équipement porté : dans l'infobulle de la rangée (pas de ligne en plus : la fiche doit tenir en 1280x720)
	if not masteries.is_empty():
		perks.tooltip_text = "Maîtrises de l'équipement porté :
" + "
".join(masteries)
		perks.mouse_filter = Control.MOUSE_FILTER_STOP

	# Aperçu avant → après d'un changement d'équipement
	_preview_box = HFlowContainer.new()
	_preview_box.add_theme_constant_override("h_separation", 10)
	_preview_box.alignment = FlowContainer.ALIGNMENT_CENTER
	_preview_box.custom_minimum_size = Vector2(0, 20)
	_left.add_child(_preview_box)
	_show_preview_hint()

	# Statistiques en deux colonnes de barres
	var cols := UiKit.hbox(8)
	var c1 := UiKit.vbox(3)
	var c2 := UiKit.vbox(3)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rows: Array = _stat_rows(u)
	for r in rows[0]:
		c1.add_child(r)
	for r in rows[1]:
		c2.add_child(r)
	cols.add_child(c1)
	cols.add_child(c2)
	_left.add_child(cols)


func _slot_cell(u: Unit, slot: String) -> Control:
	var loc: Dictionary = Inventory.at(u, slot)
	var it: Dictionary = Inventory.get_item(Game.inventory, loc)
	var kind: String = "bag" if slot.begins_with("bag") else slot
	return _make_cell(loc, it, SLOT, kind)


func _stat_rows(u: Unit) -> Array:
	var w: Dictionary = u.weapon_data()
	var morale: int = clampi(u.morale, 0, Data.MORALE_NAMES.size() - 1)
	var left: Array = [
		StatRow.new("heart", maxi(0, u.hp), u.hp_max, GameTheme.BLOOD, "%d / %d" % [maxi(0, u.hp), u.hp_max], "Points de vie", "PV"),
		StatRow.new("head:casque", u.arm_h, maxi(1, u.head_armor_max()), Color("9a948a"), "%d / %d" % [u.arm_h, u.head_armor_max()], "Armure de la tête", "Armure tête"),
		StatRow.new("body:gambison", u.arm_b, maxi(1, u.body_armor_max()), GameTheme.STEEL, "%d / %d" % [u.arm_b, u.body_armor_max()], "Armure du corps", "Armure corps"),
		StatRow.new("hourglass", u.fat, maxi(1, u.fat_max_eff()), Color("8a6a3a"), "%d / %d" % [u.fat, u.fat_max_eff()], "Fatigue actuelle / endurance (réduite par le poids porté : %d)" % u.weight(), "Fatigue"),
		StatRow.new("chevrons", u.ini_eff(), 160, Color("6f8f8a"), str(u.ini_eff()), "Initiative effective (réduite par le poids et la fatigue)", "Initiative"),
		StatRow.new("ring", u.eff("resolve"), 100, Color("7a5a9a"), str(u.eff("resolve")), "Détermination : résiste aux tests de moral", "Détermination"),
		StatRow.new("flag", morale + 1, 5, GameTheme.MORALE_COLORS[morale].darkened(0.2), str(Data.MORALE_NAMES[morale]), "Moral", "Moral"),
		StatRow.new("weight", u.weight(), 40, Color("7a6a50"), str(u.weight()), "Poids de l'équipement porté", "Poids"),
	]
	var right: Array = [
		StatRow.new("weapon:epee", u.eff("melee_skill"), 100, Color("a86a3a"), str(u.eff("melee_skill")), "Compétence de mêlée", "Mêlée"),
		StatRow.new("weapon:arc", u.eff("ranged_skill"), 100, Color("9a8a3a"), str(u.eff("ranged_skill")), "Compétence à distance", "Distance"),
		StatRow.new("shield:", u.eff("melee_def"), 60, Color("4a7a9a"), str(u.eff("melee_def")), "Défense contre la mêlée (bouclier non compris)", "Déf. mêlée"),
		StatRow.new("shield:", u.eff("ranged_def"), 60, Color("3a6a8a"), str(u.eff("ranged_def")), "Défense contre les tirs (bouclier non compris)", "Déf. distance"),
		StatRow.new("weapon:hache", int(w["max"]), 80, Color("a04a3a"), "%d – %d" % [w["min"], w["max"]], "Dégâts de l'arme : %s" % w["n"], "Dégâts"),
		StatRow.new("percent", float(w["arm"]) * 100.0, 150, Color("7a7a8a"), "%d %%" % roundi(float(w["arm"]) * 100.0), "Efficacité contre l'armure", "Vs armure"),
		StatRow.new("percent", float(w["ign"]) * 100.0, 100, Color("7a8a6a"), "%d %%" % roundi(float(w["ign"]) * 100.0), "Part des dégâts qui traverse l'armure", "Traversée"),
		StatRow.new("eye", int(w["rng"]), 6, Color("5a7a5a"), str(w["rng"]), "Portée de l'arme (en cases)", "Portée"),
	]
	return [left, right]


# --- Réserve ---

## Colonnes (6 à 9) et taille des cases selon la largeur disponible.
func _fit_grid() -> void:
	if _scroll == null or not is_inside_tree():
		return
	var w: float = _scroll.size.x - 18.0
	if w < 120.0:
		return
	var cols: int = clampi(int(floor((w + GAP) / (56.0 + GAP))), 6, 9)
	var cell: int = clampi(int(floor((w - GAP * (cols - 1)) / cols)), 52, 84)
	if cols != _cols or cell != _cell:
		_cols = cols
		_cell = cell
		_fill_grid()


func _fill_grid() -> void:
	_clear(_grid)
	_grid.columns = _cols
	var idxs: Array[int] = Market.inventory_filtered(Game.inventory, filter)
	var shown: int = idxs.size() if filter != "all" else maxi(Game.stash_size(), Game.inventory.size())
	var cells: int = maxi(4, int(ceil(shown / float(_cols)))) * _cols
	for k in cells:
		if k < idxs.size():
			var real: int = idxs[k]
			_grid.add_child(_make_cell(Inventory.in_stash(real), Game.inventory[real], _cell))
		else:
			_grid.add_child(_make_cell(Inventory.in_stash(-1), {}, _cell))
	if Game.inventory.is_empty():
		message("Réserve vide. Le butin des batailles arrive ici.")


## Case d'objet reliée à tous les gestes (glisser, déposer, double-clic, clic droit, aperçu).
func _make_cell(loc: Dictionary, it: Dictionary, px: int, slot_kind: String = "") -> ItemCell:
	var c := ItemCell.new()
	if it.is_empty():
		c.set_empty(slot_kind)
		c.custom_minimum_size = Vector2(px, px)
		if slot_kind != "":
			var cap: String = Inventory.slot_label(str(loc.get("slot", "")))
			c.tooltip_provider = func() -> String: return cap
	else:
		var o: Dictionary = {"size": px, "slot_label": slot_kind}
		if Loot.wear_ratio(it) < 1.0:
			o["durability"] = Loot.wear_ratio(it)
		c.set_item(it, o)
		var tip: String = Inventory.tooltip(it, sell_value(loc), selected())
		c.tooltip_provider = func() -> String: return tip
		c.drag_data_provider = func() -> Variant: return {"loc": loc, "item": it} if editable() else null
		c.double_clicked.connect(func() -> void: quick(loc))
		c.right_clicked.connect(func() -> void: show_menu(loc, c.get_global_mouse_position()))
	c.can_drop_handler = func(data: Variant) -> bool: return typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("loc") and can_drop(data["loc"], loc)
	c.drop_handler = func(data: Variant) -> void: drop(data["loc"], loc)
	c.hovered.connect(func(_i: Dictionary) -> void: hover(loc))
	c.mouse_exited.connect(func() -> void: hover(null))
	return c


## Cible de dépôt du fond de la réserve : l'objet porté revient dans la réserve.
class StashZone extends MarginContainer:
	var screen: InventoryScreen

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("loc") and screen.can_drop(data["loc"], Inventory.in_stash(-1))

	func _drop_data(_at: Vector2, data: Variant) -> void:
		screen.drop(data["loc"], Inventory.in_stash(-1))


# --- Aperçu des statistiques ---

func _show_preview_hint() -> void:
	if _preview_box == null or not is_instance_valid(_preview_box):
		return
	_clear(_preview_box)
	_preview_box.add_child(UiKit.sub("Survolez un objet pour voir son effet sur les statistiques.", 12, false))


## Survol d'une case (`loc` : emplacement, null = plus de survol) : aperçu avant → après pour l'homme choisi.
func hover(loc: Variant = null) -> void:
	if _preview_box == null or not is_instance_valid(_preview_box):
		return
	var u: Unit = selected()
	if typeof(loc) != TYPE_DICTIONARY or u == null:
		_show_preview_hint()
		return
	var from: Dictionary = loc
	var item: Dictionary = Inventory.get_item(Game.inventory, from)
	if item.is_empty():
		_show_preview_hint()
		return
	var to: Dictionary
	if Inventory.is_stash(from):
		var dest: String = Inventory.auto_slot(u, item)
		if dest == "":
			_clear(_preview_box)
			_preview_box.add_child(UiKit.sub("Impossible à équiper ici.", 12, false))
			return
		to = Inventory.at(u, dest)
	else:
		u = from["u"]
		to = Inventory.in_stash()
	var after: Dictionary = Inventory.preview(Game.inventory, u, from, to)
	_clear(_preview_box)
	if after.is_empty():
		_preview_box.add_child(UiKit.sub("Changement impossible.", 12, false))
		return
	var before: Dictionary = Inventory.stats(u)
	for pair in [["weight", "Poids", true], ["fat", "Endurance", false], ["ini", "Initiative", false], ["arm_h", "Armure tête", false], ["arm_b", "Armure corps", false]]:
		var k: String = pair[0]
		if int(before[k]) == int(after[k]) and k != "weight":
			continue
		_preview_box.add_child(_delta_label(str(pair[1]), int(before[k]), int(after[k]), bool(pair[2])))


## « Endurance 98 → 90 » : vert si meilleur, rouge si pire (pour le poids, moins est mieux).
func _delta_label(name: String, a: int, b: int, lower_better: bool) -> Label:
	var col: Color = GameTheme.MUTE
	if a != b:
		col = GameTheme.GOOD if ((b < a) == lower_better) else GameTheme.BLOOD
	return UiKit.label("%s %d → %d" % [name, a, b], 13, col, true)
