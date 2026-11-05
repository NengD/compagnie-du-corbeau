class_name PerkTree
extends Control
## Arbre de talents d'un homme : 7 rangées de pastilles rondes centrées (9, 8, 8, 12, 5, 4, 4 ; rang 1 en haut).
## Composant autonome : `var t := PerkTree.new(); host.add_child(t); t.set_unit(u)` ; s'adapte à la taille reçue.
## Ne calcule aucune règle : lit `Perks` (accès) et appelle `Game.spend_perks` / `Game.reset_perks` (ou `Perks.take` sans Game).
## Un clic sur un talent disponible le sélectionne ; « Apprendre » (ou un second clic) le prend : un point = un talent.

signal perk_taken(perk_id: String)

const HEAD_H := 38
const FOOT_H := 56
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII"]

var unit: Unit
var game: Node  ## état de campagne (autoload Game, trouvé tout seul ; injectable pour les tests)
var _icons: Dictionary = {}
var _sel: String = ""
var _reset_confirm: bool = false
var _head: HBoxContainer
var _points_l: Label
var _count_l: Label
var _reset_b: Button
var _plane: Control
var _foot: PanelContainer
var _foot_name: Label
var _foot_msg: Label
var _learn_b: Button
var _d: float = 40.0
var _pitch: float = 46.0
var _row_h: float = 60.0


func _init() -> void:
	custom_minimum_size = Vector2(420, 280)
	clip_contents = true
	_head = UiKit.hbox(10)
	add_child(_head)
	_points_l = UiKit.label("", 19, GameTheme.GOLD, true)
	_points_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(_points_l)
	_count_l = UiKit.sub("", 13, false)
	_count_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(_count_l)
	_head.add_child(UiKit.spacer())
	_reset_b = UiKit.button("Réinit.", "ghost", true)
	_reset_b.pressed.connect(_on_reset)
	_head.add_child(_reset_b)
	_plane = Control.new()
	_plane.mouse_filter = Control.MOUSE_FILTER_PASS
	_plane.draw.connect(_draw_plane)
	add_child(_plane)
	for t in range(1, Data.PERK_TIERS + 1):
		for k in Perks.in_tier(t):
			var ic := PerkIcon.new(k, 40, "locked")
			ic.hovered.connect(_on_hover)
			ic.clicked.connect(_on_click)
			_plane.add_child(ic)
			_icons[k] = ic
	_foot = PanelContainer.new()
	_foot.theme_type_variation = "Card"
	add_child(_foot)
	var fh := UiKit.hbox(12)
	_foot.add_child(fh)
	var fv := UiKit.vbox(0)
	fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(fv)
	_foot_name = UiKit.label("", 17, GameTheme.INK, true)
	_foot_name.clip_text = true
	fv.add_child(_foot_name)
	_foot_msg = UiKit.sub("", 13, false)
	_foot_msg.clip_text = true
	_foot_msg.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_foot_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fv.add_child(_foot_msg)
	_learn_b = UiKit.button("Apprendre", "pri")
	_learn_b.pressed.connect(func() -> void: learn(_sel))
	fh.add_child(_learn_b)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Donne l'homme à afficher (null = arbre vide).
func set_unit(u: Unit) -> void:
	unit = u
	_sel = ""
	_reset_confirm = false
	refresh()


## Relit l'état de l'homme (talents, points, or) et redessine.
func refresh() -> void:
	if unit == null:
		_points_l.text = ""
		_count_l.text = ""
		_reset_b.disabled = true
		for k in _icons:
			(_icons[k] as PerkIcon).set_state("locked", false)
		_show_info()
		return
	_points_l.text = "Points de talent : %d" % unit.perk_points
	_points_l.add_theme_color_override("font_color", GameTheme.GOLD if unit.perk_points > 0 else GameTheme.MUTE)
	_count_l.text = "%d / %d appris" % [unit.perks.size(), Data.PERKS.size()]
	for k in _icons:
		var ic: PerkIcon = _icons[k]
		var st: String = state_of(str(k))
		ic.status_text = status_of(str(k))
		ic.unit = unit
		ic.set_state(st, str(k) == _sel)
	_refresh_reset()
	_show_info()


# --- Lecture de l'état (sans effet de bord) ---

## "taken" | "open" (prenable maintenant) | "reach" (rang atteint, plus de point) | "locked" (rang ou prérequis manquant).
func state_of(k: String) -> String:
	if unit == null:
		return "locked"
	if unit.has_perk(k):
		return "taken"
	if unit.perks.size() < Perks.needed_before(k):
		return "locked"
	var req: String = str(Data.PERKS[k].get("req", ""))
	if req != "" and not unit.has_perk(req):
		return "locked"
	return "open" if unit.perk_points > 0 else "reach"


## Phrase d'état affichée dans l'infobulle et le pied.
func status_of(k: String) -> String:
	if unit == null:
		return ""
	match state_of(k):
		"taken":
			return "Talent appris."
		"open":
			return "Disponible : cliquez pour le choisir."
		"reach":
			return "Aucun point de talent à dépenser."
	var need: int = Perks.needed_before(k)
	if unit.perks.size() < need:
		return "Il faut %d talent%s pour ce rang (%d appris)." % [need, "s" if need > 1 else "", unit.perks.size()]
	return "Il faut d'abord : %s." % str(Data.PERKS[str(Data.PERKS[k]["req"])]["n"])


func icon_of(k: String) -> PerkIcon:
	return _icons.get(k)


func selected_key() -> String:
	return _sel


func _game() -> Node:
	if game == null and is_inside_tree():
		game = get_node_or_null("/root/Game")
	return game


# --- Actions ---

func select(k: String) -> void:
	_sel = k if Data.PERKS.has(k) else ""
	_reset_confirm = false
	refresh()


## Prend le talent `k` (un point). Renvoie false si impossible.
func learn(k: String) -> bool:
	if unit == null or not Data.PERKS.has(k) or Perks.why_not(unit, k) != "":
		return false
	var g: Node = _game()
	var ok: bool = bool(g.call("spend_perks", unit, [k])) if g != null else Perks.take(unit, k)
	if not ok:
		return false
	_sel = ""
	_reset_confirm = false
	refresh()
	(_icons[k] as PerkIcon).ignite()
	Sfx.play("perk")
	perk_taken.emit(k)
	return true


func _on_click(k: String) -> void:
	if k == _sel and state_of(k) == "open":
		learn(k)  # second clic sur le talent choisi = l'apprendre
	else:
		select(k)


func _on_hover(_k: String) -> void:
	pass  # l'infobulle riche suffit ; le pied suit la sélection


func _on_reset() -> void:
	var g: Node = _game()
	if unit == null or g == null:
		return
	if not _reset_confirm:
		_reset_confirm = true
		_refresh_reset()
		if is_inside_tree():
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				if is_instance_valid(self) and _reset_confirm:
					_reset_confirm = false
					_refresh_reset())
		return
	_reset_confirm = false
	if bool(g.call("reset_perks", unit)):
		_sel = ""
		refresh()


func _refresh_reset() -> void:
	var g: Node = _game()
	var cost: int = Perks.reset_cost(unit) if unit != null else 0
	var can: bool = g != null and unit != null and bool(g.call("can_reset_perks", unit))
	_reset_b.disabled = not can
	_reset_b.text = ("Confirmer (%d cr.)" % cost) if _reset_confirm else "Réinit."
	if unit == null or g == null:
		_reset_b.tooltip_text = "Réinitialisation indisponible."
	elif str(g.get("location")) == "":
		_reset_b.tooltip_text = "Seul l'entraîneur d'une ville ou d'un village peut réinitialiser les talents (en route, c'est impossible)."
	elif unit.perks.is_empty():
		_reset_b.tooltip_text = "Aucun talent à réinitialiser."
	elif int(g.get("gold")) < cost:
		_reset_b.tooltip_text = "Il faut %d couronnes pour que l'entraîneur rende tous les talents." % cost
	else:
		_reset_b.tooltip_text = "L'entraîneur rend tous les talents sous forme de points, contre %d couronnes." % cost


func _show_info() -> void:
	if _sel == "" or unit == null:
		_foot_name.text = "Talents"
		_foot_msg.text = "Survolez un talent pour son détail ; cliquez sur un talent disponible pour le choisir."
		_learn_b.visible = false
		return
	var pd: Dictionary = Data.PERKS[_sel]
	_foot_name.text = "%s — rang %d" % [pd["n"], int(pd["tier"])]
	_foot_msg.text = "%s  %s" % [pd["d"], status_of(_sel)]
	_learn_b.visible = state_of(_sel) == "open"
	_learn_b.text = "Apprendre"


# --- Géométrie ---

func _layout() -> void:
	if _plane == null:
		return
	var w: float = size.x
	var h: float = size.y
	_head.position = Vector2(4, 0)
	_head.size = Vector2(maxf(0.0, w - 8.0), HEAD_H)
	_foot.position = Vector2(0, maxf(HEAD_H, h - FOOT_H))
	_foot.size = Vector2(w, minf(FOOT_H, h - HEAD_H))
	_plane.position = Vector2(0, HEAD_H)
	_plane.size = Vector2(w, maxf(10.0, h - HEAD_H - FOOT_H - 4.0))
	var pw: float = _plane.size.x
	var ph: float = _plane.size.y
	_row_h = ph / Data.PERK_TIERS
	var widest: int = 0
	for n in Data.PERK_ROWS:
		widest = maxi(widest, int(n))
	_d = maxf(16.0, minf(_row_h * 0.84, pw / (widest * 1.14 + 0.6)))
	_pitch = _d * 1.14
	for t in range(1, Data.PERK_TIERS + 1):
		var row: Array[String] = Perks.in_tier(t)
		for i in row.size():
			var ic: PerkIcon = _icons[row[i]]
			var x: float = pw * 0.5 + (i - (row.size() - 1) * 0.5) * _pitch
			var y: float = (t - 0.5) * _row_h
			ic.custom_minimum_size = Vector2(_d, _d)
			ic.size = Vector2(_d, _d)
			ic.position = Vector2(x - _d * 0.5, y - _d * 0.5)
			ic.queue_redraw()
	_plane.queue_redraw()


func center_of(k: String) -> Vector2:
	var ic: PerkIcon = _icons[k]
	return ic.position + ic.size * 0.5


func _draw_plane() -> void:
	var pw: float = _plane.size.x
	for t in range(1, Data.PERK_TIERS + 1):
		var y0: float = (t - 1) * _row_h
		if t % 2 == 0:
			_plane.draw_rect(Rect2(0, y0, pw, _row_h), Color(1, 1, 1, 0.025))
		if pw * 0.5 - 6.2 * _pitch > 30.0:  # place pour le numéro de rang à gauche
			var f: Font = GameTheme.title_font()
			var fs: int = clampi(int(_d * 0.42), 11, 22)
			_plane.draw_string(f, Vector2(10, y0 + _row_h * 0.5 + fs * 0.35), ROMAN[t - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(GameTheme.MUTE, 0.6))
	if unit == null:
		return
	for k in _icons:  # liens de prérequis explicites
		var req: String = str(Data.PERKS[k].get("req", ""))
		if req == "" or not _icons.has(req):
			continue
		var on: bool = unit.has_perk(req)
		var col: Color = Color(GameTheme.GOLD, 0.85) if on else Color(GameTheme.MUTE, 0.35)
		_plane.draw_line(center_of(req) , center_of(str(k)), col, 2.0 if on else 1.5, true)
