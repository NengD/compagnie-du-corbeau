class_name PerkScreen
extends Control
## Écran de l'arbre de talents d'un homme : 7 rangs (lignes) x 4 colonnes, choix provisoires jusqu'à « Confirmer ».
## Ouverture : `PerkScreen.open(host, unit)`. N'applique aucune règle : lit `Perks` et appelle `Game.spend_perks` / `Game.reset_perks`.

signal closed

const CELL_W := 118
const CELL_H := 78
const ICON := 46
const LABEL_W := 78

class Links extends Control:
	## Fond de l'arbre : filets entre les rangs et liens de prérequis explicites.
	var screen: PerkScreen

	func _draw() -> void:
		if screen == null:
			return
		for t in range(1, Data.PERK_TIERS + 1):
			var y: float = (t - 1) * CELL_H
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(GameTheme.LINE, 0.5), 1.0)
		for k in Data.PERKS:
			var req: String = str(Data.PERKS[k].get("req", ""))
			if req == "":
				continue
			var a: Vector2 = screen.cell_center(req)
			var b: Vector2 = screen.cell_center(str(k))
			var on: bool = screen.unit.has_perk(req) or screen._plan.has(req)
			var col: Color = GameTheme.GOLD if on else Color(GameTheme.MUTE, 0.55)
			var w: float = 3.0 if on else 2.0
			var gx: float = maxf(a.x, b.x) + CELL_W * 0.45  # couloir à droite de la colonne : le lien évite pastilles et noms
			var half: float = ICON * 0.5
			draw_polyline(PackedVector2Array([Vector2(a.x + half, a.y), Vector2(gx, a.y), Vector2(gx, b.y), Vector2(b.x + half, b.y)]), col, w)

var unit: Unit
var game: Node  ## l'état de campagne (autoload Game ; injectable pour les tests)
var _layer: CanvasLayer
var _plan: Array[String] = []
var _focus: String = ""
var _icons: Dictionary = {}
var _reset_confirm: bool = false
var _points_l: Label
var _side: VBoxContainer
var _ok: Button
var _reset_b: Button
var _links: Links


static func open(host: Node, u: Unit, game_node: Node = null) -> PerkScreen:
	var layer := CanvasLayer.new()
	layer.layer = 55
	host.add_child(layer)
	var s := PerkScreen.new()
	s.unit = u
	s.game = game_node if game_node != null else host.get_node("/root/Game")
	s._layer = layer
	s.theme = GameTheme.get_theme()
	layer.add_child(s)
	s._build()
	return s


func cell_center(key: String) -> Vector2:
	var pd: Dictionary = Data.PERKS[key]
	return Vector2(LABEL_W + int(pd["col"]) * CELL_W + CELL_W * 0.5, (int(pd["tier"]) - 1) * CELL_H + 4 + ICON * 0.5)


func _left() -> int:
	return unit.perk_points - _plan.size()


func _state_of(k: String) -> String:
	if unit.has_perk(k):
		return "taken"
	if _plan.has(k):
		return "picked"
	return "open" if Perks.why_not(unit, k, _plan) == "" else "locked"


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_icons.clear()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ModalPanel"
	margin.add_child(panel)
	var root := UiKit.vbox(8)
	panel.add_child(root)
	# En-tête
	var head := UiKit.hbox(12)
	head.add_child(PortraitView.new(unit, 56))
	var who := UiKit.vbox(0)
	who.add_child(UiKit.title(unit.unit_name, 30))
	who.add_child(UiKit.sub("%s · niveau %d · %d talent%s pris" % [unit.background, unit.level, unit.perks.size(), "s" if unit.perks.size() > 1 else ""], 14, false))
	head.add_child(who)
	head.add_child(UiKit.spacer())
	_points_l = UiKit.label("", 20, GameTheme.GOLD, true)
	_points_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_points_l)
	root.add_child(head)
	# Corps : arbre + description
	var body := UiKit.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(LABEL_W + Data.PERK_COLS * CELL_W, Data.PERK_TIERS * CELL_H + 4)
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sc.add_child(canvas)
	_links = Links.new()
	_links.screen = self
	_links.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_links)
	for t in range(1, Data.PERK_TIERS + 1):
		var rl := UiKit.label("Rang %d" % t, 15, GameTheme.GOLD, true)
		rl.position = Vector2(2, (t - 1) * CELL_H + 8)
		canvas.add_child(rl)
		var need := UiKit.sub("dès %d talent%s" % [t - 1, "s" if t > 2 else ""] if t > 1 else "libre", 11, false)
		need.position = Vector2(2, (t - 1) * CELL_H + 28)
		canvas.add_child(need)
		for k in Perks.in_tier(t):
			var pd: Dictionary = Data.PERKS[k]
			var cx: float = LABEL_W + int(pd["col"]) * CELL_W
			var ic := PerkIcon.new(k, ICON, "open")
			ic.tooltip_text = ""  # l'infobulle est remplacée par le panneau de droite + sa raison
			ic.position = Vector2(cx + (CELL_W - ICON) * 0.5, (t - 1) * CELL_H + 4)
			ic.hovered.connect(_on_hover)
			ic.clicked.connect(_on_click)
			canvas.add_child(ic)
			_icons[k] = ic
			var nl := UiKit.label(str(pd["n"]), 12, GameTheme.INK)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl.custom_minimum_size = Vector2(CELL_W - 6, 0)
			nl.position = Vector2(cx + 3, (t - 1) * CELL_H + 4 + ICON + 1)
			nl.clip_text = true
			nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas.add_child(nl)
	var side_p := PanelContainer.new()
	side_p.theme_type_variation = "Card"
	side_p.custom_minimum_size = Vector2(300, 0)
	body.add_child(side_p)
	_side = UiKit.vbox(8)
	side_p.add_child(_side)
	# Pied
	var foot := UiKit.hbox(8)
	_reset_b = UiKit.button("", "ghost")
	_reset_b.pressed.connect(_on_reset)
	foot.add_child(_reset_b)
	foot.add_child(UiKit.spacer())
	var cancel := UiKit.button("Annuler")
	cancel.pressed.connect(close)
	foot.add_child(cancel)
	_ok = UiKit.button("Confirmer", "pri")
	_ok.pressed.connect(_on_confirm)
	foot.add_child(_ok)
	root.add_child(foot)
	if _focus == "":
		_focus = _first_open()
	_refresh()


func _first_open() -> String:
	for t in range(1, Data.PERK_TIERS + 1):
		for k in Perks.in_tier(t):
			if _state_of(k) == "open":
				return k
	return str(Perks.in_tier(1)[0])


func _refresh() -> void:
	_points_l.text = "Points de talent : %d" % _left()
	_points_l.add_theme_color_override("font_color", GameTheme.GOLD if _left() > 0 else GameTheme.MUTE)
	for k in _icons:
		var ic: PerkIcon = _icons[k]
		ic.set_state(_state_of(str(k)), str(k) == _focus)
		var why: String = Perks.why_not(unit, str(k), _plan) if _state_of(str(k)) == "locked" else ""
		ic.tooltip_text = "%s\n%s%s" % [Data.PERKS[k]["n"], Data.PERKS[k]["d"], ("\n" + why) if why != "" else ""]
	_links.queue_redraw()
	_ok.text = "Confirmer (%d)" % _plan.size() if not _plan.is_empty() else "Confirmer"
	_ok.disabled = _plan.is_empty()
	var cost: int = Perks.reset_cost(unit)
	_reset_b.visible = not unit.perks.is_empty()
	if _reset_confirm:
		_reset_b.text = "Confirmer : tout réinitialiser (%d cr.)" % cost
	else:
		_reset_b.text = "Réinitialiser les talents (%d cr.)" % cost
	var here: bool = str(game.get("location")) != ""
	_reset_b.disabled = not here or int(game.get("gold")) < cost or not _plan.is_empty()
	_reset_b.tooltip_text = "L'entraîneur rend tous les talents sous forme de points, contre %d couronnes (en ville seulement)." % cost if here else "Seul l'entraîneur d'une ville ou d'un village peut réinitialiser les talents."
	_refresh_side()


func _refresh_side() -> void:
	for c in _side.get_children():
		c.queue_free()
	if _focus == "" or not Data.PERKS.has(_focus):
		return
	var pd: Dictionary = Data.PERKS[_focus]
	var top := UiKit.hbox(10)
	top.add_child(PerkIcon.new(_focus, 56, _state_of(_focus)))
	var tv := UiKit.vbox(0)
	tv.add_child(UiKit.title(str(pd["n"]), 26))
	tv.add_child(UiKit.sub("Rang %d · %s" % [int(pd["tier"]), Data.PERK_FAMILIES[pd["fam"]]["n"]], 13, false))
	top.add_child(tv)
	_side.add_child(top)
	_side.add_child(UiKit.para(Perks.effect_text(_focus), 16))
	var req: String = str(pd.get("req", ""))
	if int(pd["tier"]) > 1:
		_side.add_child(UiKit.sub("Exige %d talent%s déjà pris%s." % [Perks.needed_before(_focus), "s" if Perks.needed_before(_focus) > 1 else "", (" et « %s »" % Data.PERKS[req]["n"]) if req != "" else ""], 13))
	var st: String = _state_of(_focus)
	var msg: String
	var col: Color = GameTheme.MUTE
	match st:
		"taken":
			msg = "Talent acquis."
			col = GameTheme.GOLD
		"picked":
			msg = "Choisi : il sera acquis à la confirmation. Cliquez pour annuler."
			col = GameTheme.GOLD
		"open":
			msg = "Disponible : cliquez sur la pastille pour le choisir."
			col = GameTheme.GOOD
		_:
			msg = Perks.why_not(unit, _focus, _plan)
			col = GameTheme.BLOOD
	var ml := UiKit.label(msg, 14, col, true)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size = Vector2(250, 0)
	_side.add_child(ml)
	_side.add_child(UiKit.spacer())
	_side.add_child(UiKit.sub("Chaque niveau (2 à 11) donne un point. Les choix restent provisoires jusqu'à « Confirmer ».", 12))


func _on_hover(k: String) -> void:
	if k == _focus:
		return
	_focus = k
	for ik in _icons:
		(_icons[ik] as PerkIcon).selected = str(ik) == _focus
		(_icons[ik] as PerkIcon).queue_redraw()
	_refresh_side()


func _on_click(k: String) -> void:
	_focus = k
	_reset_confirm = false
	match _state_of(k):
		"open":
			_plan.append(k)
		"picked":
			_plan.erase(k)
			_revalidate()
	_refresh()


## Après un retrait, ne garde que les choix encore valides dans l'ordre.
func _revalidate() -> void:
	var kept: Array[String] = []
	for k in _plan:
		if Perks.why_not(unit, k, kept, unit.perk_points) == "":
			kept.append(k)
	_plan = kept


func _on_confirm() -> void:
	if game.call("spend_perks", unit, _plan):
		close()


func _on_reset() -> void:
	if not _reset_confirm:
		_reset_confirm = true
		_refresh()
		return
	_reset_confirm = false
	if game.call("reset_perks", unit):
		_plan.clear()
		_build()


func _input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	if is_instance_valid(_layer):
		_layer.queue_free()
