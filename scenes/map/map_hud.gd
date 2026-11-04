class_name MapHud
extends Control
## HUD discret superposé à la carte (style Battle Brothers) : jauges (vivres, moral, menace) en haut à gauche, temps et date
## en haut à droite, ligne d'état qui s'efface en bas au centre, pastille du contrat en bas à gauche, boutons ronds en bas à droite.
## Ne calcule aucune règle : lit `Game` et émet des signaux ; MapScreen agit. Style cuir/parchemin ou plat selon « Interface illustrée ».

signal speed_chosen(i: int)
signal company_pressed
signal inventory_pressed
signal details_pressed
signal legend_pressed
signal help_pressed
signal contract_go_pressed

const MARGIN := 20
const BTN := 38
const STATUS_HOLD := 6.0  ## secondes avant que la ligne d'état commence à s'effacer
const STATUS_FADE := 1.2

var legend_anchor: VBoxContainer  ## MapScreen y place le panneau de la légende (au-dessus des boutons)

var _gauges: PanelContainer
var _food: Gauge
var _morale: Gauge
var _threat: Gauge
var _time_panel: PanelContainer
var _time_icon: HudIcon
var _time_label: Label
var _speed_buttons: Array[Button] = []
var _status: Label
var _status_key: String = ""
var _status_left: float = 0.0
var _status_active: bool = false
var _pill: PanelContainer
var _pill_box: HBoxContainer
var _pill_title: Label
var _pill_line: Label
var _row: HBoxContainer
var _details_btn: Button
var _legend_btn: Button
var _styled: Array = []  ## [Control, "panel"|"round"|"pri"] à restyler quand « Interface illustrée » change
var _last_time_key: String = ""


## Pastille « icône + valeur ».
class Gauge extends HBoxContainer:
	var icon: HudIcon
	var value: Label

	func _init(kind: String) -> void:
		add_theme_constant_override("separation", 5)
		mouse_filter = Control.MOUSE_FILTER_STOP
		icon = HudIcon.new(kind, 20.0)
		add_child(icon)
		value = UiKit.label("", 15, GameTheme.INK, true)
		add_child(value)

	func set_value(text: String, col: Color) -> void:
		value.text = text
		value.add_theme_color_override("font_color", col)


# --- Styles (plat ou illustré) ---

static func panel_style() -> StyleBoxFlat:
	if GameTheme.illustrated():
		var s := GameTheme.box(Color(0.10, 0.075, 0.05, 0.8), Color("7a5f30"), 2, 9, Vector4(10, 6, 10, 6))
		s.shadow_size = 4
		s.shadow_color = Color(0, 0, 0, 0.35)
		return s
	return GameTheme.box(Color(GameTheme.PANEL, 0.86), GameTheme.LINE, 1, 3, Vector4(8, 4, 8, 4))


static func round_style(state: String, primary: bool = false) -> StyleBoxFlat:
	var illus: bool = GameTheme.illustrated()
	var bg: Color = Color(0.16, 0.115, 0.08, 0.9) if illus else Color(GameTheme.PANEL, 0.88)
	var border: Color = Color("9a7a38") if illus else GameTheme.LINE
	match state:
		"hover":
			bg = Color(0.27, 0.2, 0.12, 0.96) if illus else Color(GameTheme.PANEL2, 0.96)
			border = GameTheme.GOLD
		"pressed":
			bg = Color(0.46, 0.35, 0.15, 0.97) if illus else Color("4a3f31")
			border = GameTheme.GOLD
		"disabled":
			bg.a = 0.5
	if primary and state == "normal":
		border = GameTheme.GOLD
	var s := GameTheme.box(bg, border, 2 if illus else 1, 19 if illus else 3, Vector4(0, 0, 0, 0))
	if illus:
		s.shadow_size = 3
		s.shadow_color = Color(0, 0, 0, 0.35)
	return s


func _style_all() -> void:
	for e in _styled:
		var c: Control = e[0]
		if not is_instance_valid(c):
			continue
		if e[1] == "panel":
			c.add_theme_stylebox_override("panel", panel_style())
		else:
			for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
				var key: String = "pressed" if st == "hover_pressed" else ("normal" if st == "focus" else st)
				c.add_theme_stylebox_override(st, round_style(key, e[1] == "pri"))


func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	_styled.append([p, "panel"])
	parent.add_child(p)
	return p


func _round_button(kind: String, tip: String, px: int = BTN, toggle: bool = false) -> Button:
	var b := UiKit.button("")
	b.custom_minimum_size = Vector2(px, px)
	b.tooltip_text = tip
	b.toggle_mode = toggle
	var ic := HudIcon.new(kind, 8.0)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(px * 0.22))
	b.add_child(ic)
	_styled.append([b, "round"])
	return b


# --- Construction ---

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build_gauges()
	_build_time()
	_build_status()
	_build_pill()
	_build_buttons()
	_style_all()
	Settings.changed.connect(_style_all)
	refresh()


func _exit_tree() -> void:
	if Settings.changed.is_connected(_style_all):
		Settings.changed.disconnect(_style_all)


func _build_gauges() -> void:
	_gauges = _panel(self)
	_gauges.position = Vector2(MARGIN, MARGIN)
	var row := UiKit.hbox(14)
	_gauges.add_child(row)
	_food = Gauge.new("food")
	_morale = Gauge.new("morale")
	_threat = Gauge.new("threat")
	for g in [_food, _morale, _threat]:
		row.add_child(g)


func _build_time() -> void:
	_time_panel = _panel(self)
	_time_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_time_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_time_panel.offset_right = -MARGIN
	_time_panel.offset_top = MARGIN
	var row := UiKit.hbox(8)
	_time_panel.add_child(row)
	var group := ButtonGroup.new()
	for i in 4:
		var b := _round_button(["pause", "play1", "play2", "play3"][i], "Pause (Espace)" if i == 0 else "Vitesse ×%d (Espace : pause)" % i, 30, true)
		b.button_group = group
		b.pressed.connect(func() -> void: speed_chosen.emit(i))
		row.add_child(b)
		_speed_buttons.append(b)
	var sep := ColorRect.new()
	sep.color = Color(GameTheme.LINE, 0.9)
	sep.custom_minimum_size = Vector2(1, 22)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sep)
	_time_icon = HudIcon.new("sun", 24.0)
	row.add_child(_time_icon)
	_time_label = UiKit.label("", 16, GameTheme.INK, true)
	_time_label.custom_minimum_size = Vector2(128, 0)
	row.add_child(_time_label)
	_time_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_status() -> void:
	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -(MARGIN + 34)
	_status.offset_bottom = -(MARGIN + 6)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", GameTheme.scaled_size(17))
	_status.add_theme_color_override("font_color", Color("f3e9cf"))
	_status.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.03, 0.95))
	_status.add_theme_constant_override("outline_size", 6)
	_status.modulate.a = 0.0
	add_child(_status)


func _build_pill() -> void:
	_pill = _panel(self)
	_pill.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pill.offset_left = MARGIN
	_pill.offset_bottom = -MARGIN
	_pill_box = UiKit.hbox(10)
	_pill.add_child(_pill_box)
	var v := UiKit.vbox(0)
	v.custom_minimum_size = Vector2(250, 0)
	_pill_title = UiKit.label("", 15, GameTheme.GOLD, true)
	_pill_title.clip_text = true
	_pill_line = UiKit.label("", 13, GameTheme.MUTE)
	_pill_line.clip_text = true
	v.add_child(_pill_title)
	v.add_child(_pill_line)
	_pill_box.add_child(v)
	var go := UiKit.button("Aller", "pri", true)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.tooltip_text = "Marcher vers le lieu du contrat"
	go.pressed.connect(func() -> void: contract_go_pressed.emit())
	_pill_box.add_child(go)


func _build_buttons() -> void:
	_row = UiKit.hbox(6)
	_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.offset_right = -MARGIN
	_row.offset_bottom = -MARGIN
	add_child(_row)
	var defs: Array = [
		["company", "Compagnie : hommes, équipement, bannière", func() -> void: company_pressed.emit(), false],
		["bag", "Inventaire (I)", func() -> void: inventory_pressed.emit(), false],
		["details", "Détails : contrat, factions, menace, lieux, hommes (D)", func() -> void: details_pressed.emit(), true],
		["legend", "Légende de la carte", func() -> void: legend_pressed.emit(), true],
		["help", "Raccourcis clavier (? ou F1)", func() -> void: help_pressed.emit(), false],
	]
	for d in defs:
		var b := _round_button(str(d[0]), str(d[1]), BTN, bool(d[3]))
		b.pressed.connect(d[2])
		_row.add_child(b)
		if d[0] == "details":
			_details_btn = b
		elif d[0] == "legend":
			_legend_btn = b
	legend_anchor = UiKit.vbox(0)
	legend_anchor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	legend_anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	legend_anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	legend_anchor.offset_right = -MARGIN
	legend_anchor.offset_bottom = -(MARGIN + BTN + 8)
	add_child(legend_anchor)


# --- Mise à jour ---

func set_speed(i: int) -> void:
	for k in _speed_buttons.size():
		_speed_buttons[k].set_pressed_no_signal(k == i)


func set_details_open(on: bool) -> void:
	if _details_btn != null:
		_details_btn.set_pressed_no_signal(on)


func set_legend_open(on: bool) -> void:
	if _legend_btn != null:
		_legend_btn.set_pressed_no_signal(on)


## Jauges et pastille du contrat.
func refresh() -> void:
	if Game.world == null or _food == null:
		return
	var low: bool = Game.provisions_days() <= float(Data.PROVISIONS_WARN_DAYS)
	_food.set_value("%d j" % int(floor(Game.provisions_days())), GameTheme.BLOOD.lightened(0.25) if low else GameTheme.INK)
	_food.tooltip_text = "Vivres : %d rations, ≈ %.1f jours de route.%s\nUne ration par homme et par jour de route ; achat au marché." % [Game.provisions, Game.provisions_days(), "\nVivres presque épuisés !" if low else ""]
	_morale.set_value(str(int(Game.company_morale)), GameTheme.GOLD if Game.company_morale >= Data.MORALE_LOW else GameTheme.BLOOD.lightened(0.25))
	_morale.tooltip_text = "Moral de la compagnie : %s (%d/100).\nIl fixe le moral de départ des hommes en bataille (< %d : Hésitant, > %d : Confiant)." % [Game.morale_label(), int(Game.company_morale), int(Data.MORALE_LOW), int(Data.MORALE_HIGH)]
	var st: Dictionary = Game.campaign
	var threat: float = float(st.get("threat", 0.0))
	var over: bool = st.get("final", "") == "won" or bool(st.get("free_mode", false))
	_threat.visible = threat > 0.0 and not over
	if _threat.visible:
		_threat.set_value("%d%%" % int(threat), GameTheme.BLOOD.lightened(0.3))
		_threat.tooltip_text = "Menace montante : %s\nPalier %d/%d : %s\nOuvrez « Détails » (D) pour le contrat final et les affaires en cours." % [Campaign.threat_title(st), int(st.get("stage", 0)), Campaign.STAGES.size(), Campaign.stage_name(st)]
	refresh_pill()


func refresh_pill() -> void:
	if Game.world == null or _pill == null:
		return
	var ac: Dictionary = Game.active_contract
	_pill.visible = not ac.is_empty()
	if ac.is_empty():
		return
	var pts: Array[Vector2] = Game.world.find_path(Game.world.player_pos, Game.contract_target())
	var kind_name: String = {"kill": "Éliminer", "hunt": "Chasse", "escort": "Escorte", "delivery": "Livraison"}.get(str(ac.get("type_contract", "kill")), "Éliminer")
	_pill_title.text = str(ac["title"])
	_pill_title.tooltip_text = str(ac["title"])
	_pill_line.text = "%s · %s · ≈ %.1f j" % [kind_name, ac["target_name"], Game.world.path_days(pts)]
	_pill.tooltip_text = "Contrat en cours : %s\nPrime : %d couronnes%s" % [ac["title"], int(ac["pay"]), " (à l'arrivée)" if Contracts.is_transport(ac) else ""]


## Date et icône du moment (soleil, lune, pluie…). N'écrit que si le texte change.
func set_time(day: int, frac: float, weather_on: bool) -> void:
	var phase: String = MapFx.time_label(frac)
	var kind: String = "moon" if phase == "nuit" else "sun"
	if kind == "sun" and weather_on:
		kind = {"clear": "sun", "rain": "rain", "fog": "fog", "snow": "snow"}.get(MapFx.weather_for_day(day), "sun")
	var key: String = "%d|%s|%s" % [day, phase, kind]
	if key == _last_time_key:
		return
	_last_time_key = key
	_time_label.text = "Jour %d, %s" % [day, phase]
	_time_icon.set_kind(kind)
	_time_panel.tooltip_text = "Météo : %s" % {"clear": "dégagé", "rain": "pluie", "fog": "brume", "snow": "neige"}.get(MapFx.weather_for_day(day), "dégagé")


## Ligne d'état : réaffichée en plein à chaque nouvelle `key` (nouvelle destination, halte…), puis s'efface.
func say(text: String, key: String) -> void:
	if _status == null:
		return
	_status.text = text
	if key != _status_key:
		_status_key = key
		_status_left = STATUS_HOLD
		_status_active = true
		_status.modulate.a = 1.0


func status_text() -> String:
	return _status.text if _status != null else ""


func _process(delta: float) -> void:
	if _status == null or not _status_active:
		return
	_status_left -= delta
	if _status_left <= 0.0:
		_status.modulate.a = clampf(1.0 + _status_left / STATUS_FADE, 0.0, 1.0)
		if _status_left < -STATUS_FADE:
			_status_active = false
			_status.modulate.a = 0.0
