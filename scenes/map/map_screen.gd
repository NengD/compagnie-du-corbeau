class_name MapScreen
extends Control
## Écran de la carte : la carte occupe tout l'écran de jeu, le HUD (MapHud) et le tiroir « Détails » (MapDrawer) se superposent.
## On clique pour se déplacer, le temps passe en marchant. Le déplacement, la solde et les rencontres sont gérés par `Game.map_step`.

signal company_requested

const DAYS_PER_SEC := 0.5  ## jours de jeu par seconde réelle à vitesse ×1

var view: MapView
var hud: MapHud
var drawer: MapDrawer

var _speed: int = 1  ## 0 pause, 1 à 3 : vitesse
var _repath_timer: float = 0.0
var _pill_timer: float = 0.0
var _event_modal: ModalOverlay
var _site_modal: ModalOverlay
var _help: ModalOverlay
var _legend_panel: PanelContainer
var _focus_i: int = -1  ## lieu mis en avant par Tab
var _focus_n: int = 0

## Pictogramme de la légende, dessiné comme sur la carte (en miniature).
class LegendIcon extends Control:
	var kind: String = ""

	func _init(k: String = "") -> void:
		kind = k
		custom_minimum_size = Vector2(26, 22)

	func _draw() -> void:
		var c := Vector2(13, 12)
		var ol := Color("17110c")
		match kind:
			"city":
				draw_rect(Rect2(c + Vector2(-10, -3), Vector2(20, 11)), Color("8f8470"))
				draw_rect(Rect2(c + Vector2(-10, -3), Vector2(20, 11)), ol, false, 1.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3), c + Vector2(0, -10), c + Vector2(5, -3)]), Color("8a3a2e"))
			"village":
				draw_rect(Rect2(c + Vector2(-6, -1), Vector2(12, 8)), Color("b08e60"))
				draw_rect(Rect2(c + Vector2(-6, -1), Vector2(12, 8)), ol, false, 1.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -1), c + Vector2(0, -8), c + Vector2(8, -1)]), Color("7a4a32"))
			"site":
				draw_rect(Rect2(c + Vector2(-6, -4), Vector2(12, 13)), Color("6b5a44"))
				draw_rect(Rect2(c + Vector2(-6, -4), Vector2(12, 13)), ol, false, 1.0)
				draw_line(c + Vector2(0, -4), c + Vector2(0, -11), ol, 2.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(7, -8), c + Vector2(0, -6)]), Color("a33a2c"))
			"party":
				draw_line(c + Vector2(0, 8), c + Vector2(0, -9), Color("c9c2b2"), 1.6)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(8, -6), c + Vector2(0, -3)]), Color("7a5e9a"))
			"contract":
				draw_line(c + Vector2(0, 8), c + Vector2(0, -9), Color("c9c2b2"), 1.6)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(8, -6), c + Vector2(0, -3)]), Color("b03a2e"))
				draw_arc(c + Vector2(0, 8), 5.0, 0.0, TAU, 12, Color(0.8, 0.25, 0.2, 0.8), 1.4)
			"company":
				draw_line(c + Vector2(0, 10), c + Vector2(0, -10), ol, 2.4)
				draw_line(c + Vector2(-6, -9), c + Vector2(6, -9), ol, 2.0)
				var cloth := PackedVector2Array([c + Vector2(-5, -8), c + Vector2(5, -8), c + Vector2(5, 3), c + Vector2(0, 0), c + Vector2(-5, 3)])
				draw_colored_polygon(cloth, Banner.primary(Game.banner))
				draw_polyline(PackedVector2Array([cloth[0], cloth[1], cloth[2], cloth[3], cloth[4], cloth[0]]), ol, 1.0)
				draw_circle(c + Vector2(0, -4), 1.8, Banner.secondary(Game.banner))
			"visited":
				draw_circle(c, 6.5, ol)
				draw_circle(c, 5.2, Color("8aa05a"))
				draw_polyline(PackedVector2Array([c + Vector2(-2.6, 0.2), c + Vector2(-0.6, 2.4), c + Vector2(2.8, -2.2)]), ol, 1.6, true)



func _ready() -> void:
	Sfx.music("map")
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	view = MapView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	view.travel_requested.connect(_travel)
	view.stop_requested.connect(_stop)
	hud = MapHud.new()
	add_child(hud)
	hud.speed_chosen.connect(_set_speed)
	hud.company_pressed.connect(func() -> void: company_requested.emit())
	hud.inventory_pressed.connect(func() -> void: InventoryScreen.open(self))
	hud.details_pressed.connect(func() -> void: drawer.toggle())
	hud.legend_pressed.connect(func() -> void:
		_legend_panel.visible = not _legend_panel.visible
		hud.set_legend_open(_legend_panel.visible)
		_sync_overlay_group())
	hud.help_pressed.connect(_open_help)
	hud.contract_go_pressed.connect(func() -> void:
		if not Game.active_contract.is_empty():
			_travel(Game.contract_target(), {"kind": "target", "title": str(Game.active_contract["target_name"])}))
	_build_legend()
	drawer = MapDrawer.new()
	add_child(drawer)
	drawer.travel_requested.connect(_travel)
	drawer.toggled.connect(func(on: bool) -> void:
		hud.set_details_open(on)
		_sync_overlay_group())
	Game.changed.connect(hud.refresh)
	hud.set_speed(_speed)
	_update_status()
	_update_time()


func _exit_tree() -> void:
	if Game.changed.is_connected(hud.refresh):
		Game.changed.disconnect(hud.refresh)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _help != null and is_instance_valid(_help):
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_F1 or event.keycode == KEY_QUESTION:
				_help.close()
				_help = null
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F1 or event.keycode == KEY_QUESTION or event.unicode == 63:
			_open_help()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_D:
			drawer.toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			_set_speed(0 if _speed > 0 else 1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if drawer.is_open:
				drawer.close()
				get_viewport().set_input_as_handled()
			elif _legend_panel.visible:
				_legend_panel.visible = false
				hud.set_legend_open(false)
				_sync_overlay_group()
				get_viewport().set_input_as_handled()
			else:
				_stop()
		elif event.keycode == KEY_C or event.keycode == KEY_H or event.keycode == KEY_HOME:
			view.center_on_player()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			_focus_next_place(-1 if event.shift_pressed else 1)
			get_viewport().set_input_as_handled()


func _open_help() -> void:
	if _help == null or not is_instance_valid(_help):
		_help = Shortcuts.open(self, "map")


## Tab : centre la vue sur le lieu suivant (villes et villages, puis lieux hostiles) et l'entoure d'un anneau.
func _focus_next_place(dir: int) -> void:
	var places: Array[Dictionary] = []
	places.assign(Game.world.settlements)
	places.append_array(Game.world.sites)
	if places.is_empty():
		return
	_focus_i = posmod(_focus_i + dir, places.size())
	var s: Dictionary = places[_focus_i]
	view.center_on(Game.world.settlement_pos(s), true)
	var v: int = Visits.day_of(s)
	_focus_n += 1
	hud.say("%s%s" % [s["name"], " — visité le jour %d." % v if v > 0 else ""], "focus%d" % _focus_n)


func _build_legend() -> void:
	_legend_panel = PanelContainer.new()
	_legend_panel.theme_type_variation = "Card"
	_legend_panel.visible = false
	var lv := UiKit.vbox(3)
	_legend_panel.add_child(lv)
	for e in [["city", "Ville"], ["village", "Village"], ["site", "Fort, repaire, nécropole"], ["party", "Bande errante"],
			["contract", "Lieu du contrat"], ["company", "Votre compagnie"], ["visited", "Lieu déjà visité"]]:
		var row := UiKit.hbox(8)
		row.add_child(LegendIcon.new(str(e[0])))
		row.add_child(UiKit.label(str(e[1]), 13))
		lv.add_child(row)
	var terr_cb := CheckBox.new()
	terr_cb.text = "Territoires des factions"
	terr_cb.button_pressed = view.show_territories
	terr_cb.add_theme_font_size_override("font_size", 13)
	terr_cb.toggled.connect(view.set_show_territories)
	lv.add_child(terr_cb)
	hud.legend_anchor.add_child(_legend_panel)


func _update_time() -> void:
	hud.set_time(Game.day, Game.day_fraction, int(Quality.value("weather")) > 0)


func _process(delta: float) -> void:
	if Game.battle != null or Game.location != "" or Game.world == null:
		return
	_update_time()
	_pill_timer += delta
	if _pill_timer > 0.5:
		_pill_timer = 0.0
		hud.refresh_pill()
	if not Game.pending_event.is_empty():
		_open_event()  ## le temps est en pause tant qu'un événement attend un choix
		return
	if _speed == 0 or Game.world.path.is_empty():
		return
	var d: Dictionary = Game.world.dest
	if d.get("kind", "") == "party":
		_repath_timer += delta
		if _repath_timer > 0.25:
			_repath_timer = 0.0
			var p: Dictionary = Game.world.party_by_id(int(d["id"]))
			if p.is_empty():
				Game.world.stop()
			else:
				Game.world.set_destination(Game.world.party_pos(p), d)
	var ev: Dictionary = Game.map_step(minf(delta, 0.1) * DAYS_PER_SEC * _speed)
	match ev.get("type", ""):
		"target":
			Game.add_news(["La compagnie arrive à : %s." % Game.active_contract["target_name"]])
			Game.engage_target()
		"encounter":
			Game.add_news(["Embuscade ! %s vous tombe dessus." % Game.world.party_title(ev["party"])])
			Game.engage_party(int(ev["party"]["id"]))
		"ambush":
			Game.add_news(["Embuscade sur la route de %s !" % Game.active_contract["target_name"]])
			Game.engage_ambush()
		"event":
			_open_event()
		"site":
			_open_site(str(ev["id"]))
	_update_status()


# --- Événements de route ---

func _open_event() -> void:
	if (_event_modal != null and is_instance_valid(_event_modal)) or Game.pending_event.is_empty():
		return
	var def: Dictionary = Events.get_def(str(Game.pending_event["id"]))
	if def.is_empty():
		Game.pending_event = {}
		return
	_event_modal = ModalOverlay.open(self, 520)
	_fill_event(def)


func _fill_event(def: Dictionary) -> void:
	var box: VBoxContainer = _event_modal.content
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_child(UiKit.label("Événement de route", 13, GameTheme.GOLD, true))
	box.add_child(UiKit.title(str(def["title"]), 26))
	box.add_child(UiKit.para(str(def["text"])))
	for ch in def["choices"]:
		var cost: int = int(ch.get("cost", 0))
		var b := UiKit.button(str(ch["label"]), "pri" if cost == 0 and ch["id"] != "pass" else "", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = Game.gold < cost
		if b.disabled:
			b.tooltip_text = "Pas assez de couronnes."
		b.pressed.connect(_choose_event.bind(str(ch["id"])))
		box.add_child(b)


func _choose_event(choice_id: String) -> void:
	var res: Dictionary = Game.resolve_event(choice_id)
	if not bool(res.get("ok", false)):
		return
	if bool(res.get("battle", false)):
		_close_event()
		return
	var box: VBoxContainer = _event_modal.content
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_child(UiKit.para(str(res["text"])))
	if not (res["effects"] as Array).is_empty():
		box.add_child(UiKit.sub(" · ".join(res["effects"])))
	var ok := UiKit.button("Poursuivre la route", "pri")
	ok.pressed.connect(_close_event)
	box.add_child(ok)


func _close_event() -> void:
	if _event_modal != null and is_instance_valid(_event_modal):
		_event_modal.close()
	_event_modal = null


# --- Lieux hostiles : assaut, repos au poste libéré ---

func _open_site(id: String) -> void:
	var s: Dictionary = Game.world.site_by_id(id)
	if s.is_empty() or (_site_modal != null and is_instance_valid(_site_modal)):
		return
	_site_modal = ModalOverlay.open(self, 520)
	var box: VBoxContainer = _site_modal.content
	box.add_child(UiKit.label(Campaign.site_label(s), 13, GameTheme.GOLD, true))
	box.add_child(UiKit.title(str(s["name"]), 28))
	box.add_child(UiKit.para("\n".join(Array(Campaign.site_tooltip(s, Game.renown).split("\n")).slice(1))))
	var row := UiKit.hbox(8)
	match str(s["state"]):
		"hostile":
			var atk := UiKit.button("Donner l'assaut", "pri")
			atk.pressed.connect(func() -> void:
				_close_site()
				Game.engage_site(id))
			row.add_child(atk)
			if s["kind"] == "citadel":
				box.add_child(UiKit.sub("Trois vagues enchaînées, sans soin entre elles. Une défaite ou une retraite laisse la citadelle debout."))
			else:
				box.add_child(UiKit.sub("Une garnison nombreuse. Pas de soin avant le combat : préparez-vous."))
		"friendly":
			var rest := UiKit.button("Se reposer un jour (+%d PV, −%d solde)" % [Campaign.SITE_REST_HEAL, Game.wages()], "pri")
			rest.disabled = not Game.has_wounded()
			rest.pressed.connect(func() -> void:
				Game.rest_at_site(id)
				_close_site())
			row.add_child(rest)
	var leave := UiKit.button("Repartir", "ghost")
	leave.pressed.connect(_close_site)
	row.add_child(leave)
	box.add_child(row)


func _close_site() -> void:
	if _site_modal != null and is_instance_valid(_site_modal):
		_site_modal.close()
	_site_modal = null


func _travel(target: Vector2, info: Dictionary) -> void:
	if Game.world.set_destination(target, info):
		_update_status()


func _stop() -> void:
	Game.world.stop()
	_update_status()


func _set_speed(v: int) -> void:
	_speed = v
	hud.set_speed(v)


func _eta_days() -> float:
	var pts: Array[Vector2] = [Game.world.player_pos]
	pts.append_array(Game.world.path)
	return Game.world.path_days(pts)


func _update_status() -> void:
	if hud == null or Game.world == null:
		return
	if Game.world.path.is_empty():
		hud.say("Halte. Cliquez sur la carte pour avancer.", "halt")
	else:
		var d: Dictionary = Game.world.dest
		var where: String = str(d.get("title", "")) if d.get("title", "") != "" else "un point de la carte"
		hud.say("En route vers %s — encore ≈ %.1f jour%s." % [where, _eta_days(), "s" if _eta_days() >= 1.5 else ""], "route:" + where)


## Le menu pause (Main) ne doit pas prendre Échap quand le tiroir ou la légende est ouvert : la carte les ferme d'abord.
func _sync_overlay_group() -> void:
	var open: bool = (drawer != null and drawer.is_open) or (_legend_panel != null and _legend_panel.visible)
	if open:
		add_to_group("map_overlay_open")
	elif is_in_group("map_overlay_open"):
		remove_from_group("map_overlay_open")
