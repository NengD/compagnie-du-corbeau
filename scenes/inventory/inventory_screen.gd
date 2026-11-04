class_name InventoryScreen
extends ModalOverlay
## Écran d'inventaire « à la Battle Brothers » : les hommes à gauche, la poupée d'équipement au centre, la réserve commune à droite.
## Toute la logique d'équipement est dans core/inventory.gd (via Game.inv_*) ; cet écran n'affiche que l'état et relaie les gestes.
## Gestes : glisser-déposer, double-clic (équiper / déséquiper), clic droit (menu), flèches (changer d'homme), Échap ou I (fermer).

const COLS: int = 6
const CELL: int = 58
const SLOT: int = 70

var sel_id: int = -1
var filter: String = "all"

var _roster_box: VBoxContainer
var _center: VBoxContainer
var _right: VBoxContainer
var _gold_l: Label
var _cap_l: Label
var _msg_l: Label
var _preview_box: HFlowContainer
var _hover_slot: InvSlot
var _rebuild_pending: bool = false


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
	layer.add_child(s)
	s._build_screen()
	return s


func _build_screen() -> void:
	add_to_group("inventory_screen")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ModalPanel"
	margin.add_child(panel)
	var root := UiKit.vbox(8)
	panel.add_child(root)

	var head := UiKit.hbox(10)
	head.add_child(UiKit.title("Inventaire", 32))
	head.add_child(UiKit.spacer())
	_gold_l = UiKit.label("", 18, GameTheme.GOLD, true)
	head.add_child(_gold_l)
	var close_b := UiKit.button("Fermer (Échap)")
	close_b.pressed.connect(close)
	head.add_child(close_b)
	root.add_child(head)

	var body := UiKit.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.custom_minimum_size = Vector2(230, 0)
	_roster_box = UiKit.vbox(4)
	_roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_roster_box)
	body.add_child(left_scroll)
	_center = UiKit.vbox(8)
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.custom_minimum_size = Vector2(330, 0)
	body.add_child(_center)
	_right = UiKit.vbox(6)
	_right.custom_minimum_size = Vector2(COLS * (CELL + 4) + 14, 0)
	body.add_child(_right)

	var foot := UiKit.hbox(12)
	_msg_l = UiKit.label("", 14, GameTheme.INK)
	_msg_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_msg_l)
	_cap_l = UiKit.label("", 14, GameTheme.MUTE, true)
	foot.add_child(_cap_l)
	var best := UiKit.button("Tout équiper au mieux", "", true)
	best.disabled = true  # casernement : volontairement inactif (aucun automatisme)
	best.tooltip_text = "Mode casernement : non activé. Rien n'est équipé sans votre ordre."
	foot.add_child(best)
	root.add_child(foot)

	Game.changed.connect(_queue_rebuild)
	_rebuild()


func _exit_tree() -> void:
	if Game.changed.is_connected(_queue_rebuild):
		Game.changed.disconnect(_queue_rebuild)


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
	_rebuild_right()


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


## Dépose un objet sur un homme de la liste : il le prend à son emplacement naturel (don).
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
		if Game.sell(idx):
			message("%s vendu." % Loot.item_name(it))
	elif id == 2:
		if Game.discard(idx):
			message("%s jeté." % Loot.item_name(it))


func _report(res: Dictionary, ok_text: String = "") -> void:
	if bool(res["ok"]):
		var t: String = ok_text
		if str(res["msg"]) != "":
			t = (t + " " + str(res["msg"])).strip_edges()
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
	_hover_slot = null
	_clear(_roster_box)
	_clear(_center)
	_clear(_right)
	selected()
	_build_roster()
	_build_center()
	_build_right()
	_refresh_footer()


func _rebuild_right() -> void:
	_clear(_right)
	_build_right()


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _refresh_footer() -> void:
	_gold_l.text = "Or : %d couronnes" % Game.gold
	var full: bool = Game.inventory.size() >= Data.STASH_SIZE
	_cap_l.text = "Réserve : %d/%d%s" % [Game.inventory.size(), Data.STASH_SIZE, " (pleine)" if full else ""]
	_cap_l.add_theme_color_override("font_color", GameTheme.BLOOD if full else GameTheme.MUTE)


func _build_roster() -> void:
	for m in Game.roster:
		var row := RosterRow.new()
		row.screen = self
		row.unit = m
		var on: bool = m.id == sel_id
		row.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.PANEL2 if on else GameTheme.PANEL, GameTheme.GOLD if on else GameTheme.LINE, 2 if on else 1, 3, Vector4(6, 4, 6, 4)))
		var h := UiKit.hbox(8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(PortraitView.new(m, 40))
		var v := UiKit.vbox(1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label(m.unit_name, 14, GameTheme.INK, true))
		v.add_child(StatBar.new("PV", maxi(0, m.hp), m.hp_max, GameTheme.BLOOD))
		h.add_child(v)
		row.add_child(h)
		_roster_box.add_child(row)


func _slot(u: Unit, slot: String) -> Control:
	var v := UiKit.vbox(1)
	v.add_child(InvSlot.new(self, Inventory.at(u, slot), Inventory.get_item(Game.inventory, Inventory.at(u, slot)), Inventory.slot_label(slot), SLOT))
	var cap := UiKit.sub(Inventory.slot_label(slot), 11, false)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	return v


func _build_center() -> void:
	var u: Unit = selected()
	if u == null:
		_center.add_child(UiKit.sub("Personne dans la compagnie."))
		return
	var top := UiKit.hbox(10)
	top.add_child(PortraitView.new(u, 64))
	var tv := UiKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UiKit.title(u.unit_name, 26))
	tv.add_child(UiKit.sub("%s · niveau %d" % [u.background, u.level]))
	tv.add_child(StatBar.new("PV", maxi(0, u.hp), u.hp_max, GameTheme.BLOOD))
	top.add_child(tv)
	_center.add_child(top)

	# Poupée d'équipement
	var doll := UiKit.vbox(2)
	doll.alignment = BoxContainer.ALIGNMENT_CENTER
	var r1 := UiKit.hbox(6)
	r1.alignment = BoxContainer.ALIGNMENT_CENTER
	r1.add_child(_slot(u, "head"))
	var r2 := UiKit.hbox(6)
	r2.alignment = BoxContainer.ALIGNMENT_CENTER
	r2.add_child(_slot(u, "weapon"))
	r2.add_child(_slot(u, "body"))
	r2.add_child(_slot(u, "shield"))
	var r3 := UiKit.hbox(6)
	r3.alignment = BoxContainer.ALIGNMENT_CENTER
	r3.add_child(_slot(u, "bag0"))
	r3.add_child(_slot(u, "bag1"))
	doll.add_child(r1)
	doll.add_child(r2)
	doll.add_child(r3)
	_center.add_child(doll)

	# Statistiques
	var card := UiKit.card(_center)
	var st: Dictionary = Inventory.stats(u)
	card.add_child(UiKit.kv_row("Poids porté", str(st["weight"])))
	card.add_child(UiKit.kv_row("Endurance", str(st["fat"])))
	card.add_child(UiKit.kv_row("Initiative", str(st["ini"])))
	card.add_child(UiKit.kv_row("Armure tête / corps", "%d/%d · %d/%d" % [u.arm_h, u.head_armor_max(), u.arm_b, u.body_armor_max()]))
	if u.weapon_wears():
		card.add_child(UiKit.kv_row("Usure de l'arme", "%d/%d" % [u.weapon_dur_now(), u.weapon_dur_max()]))
	if u.shield:
		card.add_child(UiKit.kv_row("Usure du bouclier", "%d/%d" % [u.shield_dur_now(), u.shield_dur_max()]))
	_preview_box = HFlowContainer.new()
	_preview_box.add_theme_constant_override("h_separation", 12)
	card.add_child(_preview_box)
	_show_preview_hint()


func _build_right() -> void:
	var f := UiKit.hbox(4)
	var group := ButtonGroup.new()
	for pair in [["all", "Tout"], ["weapon", "Armes"], ["head", "Casques"], ["body", "Armures"], ["shield", "Boucliers"]]:
		var b := UiKit.button(pair[1], "", true)
		b.toggle_mode = true
		b.button_group = group
		b.set_pressed_no_signal(filter == pair[0])
		var key: String = pair[0]
		b.pressed.connect(func() -> void: set_filter(key))
		f.add_child(b)
	_right.add_child(f)
	var s := UiKit.hbox(4)
	s.add_child(UiKit.sub("Trier :", 13, false))
	for pair in [["type", "Type"], ["value", "Valeur"], ["wear", "Usure"]]:
		var b2 := UiKit.button(pair[1], "ghost", true)
		var mode: String = pair[0]
		b2.disabled = not editable()
		b2.pressed.connect(func() -> void: Game.inv_sort(mode))
		s.add_child(b2)
	_right.add_child(s)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var idxs: Array[int] = Inventory.filtered(Game.inventory, filter)
	var cells: int = maxi(Data.STASH_SIZE, int(ceil(Game.inventory.size() / float(COLS))) * COLS)
	for k in cells:
		if k < idxs.size():
			var real: int = idxs[k]
			grid.add_child(InvSlot.new(self, Inventory.in_stash(real), Game.inventory[real], "", CELL))
		else:
			grid.add_child(InvSlot.new(self, Inventory.in_stash(-1), {}, "", CELL))
	scroll.add_child(grid)
	_right.add_child(scroll)
	if Game.inventory.is_empty():
		_right.add_child(UiKit.sub("Réserve vide. Le butin des batailles arrive ici."))


# --- Aperçu des statistiques ---

func _show_preview_hint() -> void:
	_clear(_preview_box)
	_preview_box.add_child(UiKit.sub("Survolez un objet pour voir son effet sur les statistiques.", 12, false))


## Survol d'une case : aperçu avant → après pour l'homme choisi.
func hover(slot: InvSlot) -> void:
	_hover_slot = slot
	if _preview_box == null or not is_instance_valid(_preview_box):
		return
	var u: Unit = selected()
	if slot == null or slot.item.is_empty() or u == null:
		_show_preview_hint()
		return
	var from: Dictionary = slot.loc
	var to: Dictionary
	if Inventory.is_stash(from):
		var dest: String = Inventory.auto_slot(u, slot.item)
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


## Ligne de la liste des hommes : sélection au clic, cible de dépôt (don).
class RosterRow extends PanelContainer:
	var screen: InventoryScreen
	var unit: Unit

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			screen.select(unit.id)
			accept_event()

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("loc") and screen.can_drop_on_member(data["loc"], unit)

	func _drop_data(_at: Vector2, data: Variant) -> void:
		screen.drop_on_member(data["loc"], unit)
