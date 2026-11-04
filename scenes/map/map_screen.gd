class_name MapScreen
extends HBoxContainer
## Écran de la carte : on clique pour se déplacer, le temps passe en marchant.
## Le déplacement, la solde et les rencontres sont gérés par `Game.map_step`.

signal company_requested

const DAYS_PER_SEC := 0.5  ## jours de jeu par seconde réelle à vitesse ×1
const SIDE_W := 330

var view: MapView

var _speed: int = 1  ## 0 pause, 1 à 3 : vitesse
var _side: VBoxContainer
var _status: Label
var _speed_buttons: Array[Button] = []
var _repath_timer: float = 0.0
var _confirm_abandon: bool = false
var _event_modal: ModalOverlay
var _site_modal: ModalOverlay
var _help: ModalOverlay
var _legend_panel: PanelContainer
var _legend_btn: Button
var _focus_i: int = -1  ## lieu mis en avant par Tab

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
				draw_circle(c, 9.0, ol)
				draw_circle(c, 7.8, GameTheme.GOLD)
			"visited":
				draw_circle(c, 6.5, ol)
				draw_circle(c, 5.2, Color("8aa05a"))
				draw_polyline(PackedVector2Array([c + Vector2(-2.6, 0.2), c + Vector2(-0.6, 2.4), c + Vector2(2.8, -2.2)]), ol, 1.6, true)


func _ready() -> void:
	Sfx.music("map")
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	var frame := PanelContainer.new()
	frame.theme_type_variation = "Card"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(frame)
	view = MapView.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(420, 300)
	frame.add_child(view)
	view.travel_requested.connect(_travel)
	view.stop_requested.connect(_stop)
	_build_legend()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(SIDE_W, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_side = UiKit.vbox(10)
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_side)
	Game.changed.connect(_refresh_side)
	_refresh_side()


func _exit_tree() -> void:
	if Game.changed.is_connected(_refresh_side):
		Game.changed.disconnect(_refresh_side)


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
		elif event.keycode == KEY_SPACE:
			_set_speed(0 if _speed > 0 else 1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
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
	if _status != null:
		var v: int = Visits.day_of(s)
		_status.text = "%s%s" % [s["name"], " — visité le jour %d." % v if v > 0 else ""]


func _build_legend() -> void:
	var box := UiKit.vbox(4)
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.position = Vector2(8, -8)
	view.add_child(box)
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
	box.add_child(_legend_panel)
	var row2 := UiKit.hbox(4)
	_legend_btn = UiKit.button("Légende ▸", "ghost", true)
	_legend_btn.pressed.connect(func() -> void:
		_legend_panel.visible = not _legend_panel.visible
		_legend_btn.text = "Légende ▾" if _legend_panel.visible else "Légende ▸")
	row2.add_child(_legend_btn)
	var hb := UiKit.button("?", "ghost", true)
	hb.tooltip_text = "Raccourcis clavier (? ou F1)"
	hb.pressed.connect(_open_help)
	row2.add_child(hb)
	box.add_child(row2)


func _process(delta: float) -> void:
	if Game.battle != null or Game.location != "" or Game.world == null:
		return
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


func _travel_to_site(id: String) -> void:
	var s: Dictionary = Game.world.site_by_id(id)
	if not s.is_empty():
		_travel(Game.world.settlement_pos(s), {"kind": "site", "id": id, "title": str(s["name"])})


func _travel(target: Vector2, info: Dictionary) -> void:
	if Game.world.set_destination(target, info):
		_update_status()


func _stop() -> void:
	Game.world.stop()
	_update_status()


func _set_speed(v: int) -> void:
	_speed = v
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == v)


func _eta_days() -> float:
	var pts: Array[Vector2] = [Game.world.player_pos]
	pts.append_array(Game.world.path)
	return Game.world.path_days(pts)


func _update_status() -> void:
	if _status == null:
		return
	if Game.world.path.is_empty():
		_status.text = "Halte. Cliquez sur la carte pour avancer (clic droit ou Échap : s'arrêter, Espace : pause, Tab : lieu suivant, H : recentrer, ? : raccourcis)."
	else:
		var d: Dictionary = Game.world.dest
		var where: String = str(d.get("title", "")) if d.get("title", "") != "" else "un point de la carte"
		_status.text = "En route vers %s — encore ≈ %.1f jour%s." % [where, _eta_days(), "s" if _eta_days() >= 1.5 else ""]


func _travel_to_settlement(id: String) -> void:
	var s: Dictionary = Game.world.settlement_by_id(id)
	_travel(Game.world.settlement_pos(s), {"kind": "settlement", "id": id, "title": str(s["name"])})


## Cartes « Menace » (crise finale) et « Arcs » (contrats liés) du panneau latéral.
func _build_campaign_panels() -> void:
	var st: Dictionary = Game.campaign
	var c := UiKit.card(_side)
	if st["final"] == "won" or bool(st["free_mode"]):
		c.add_child(UiKit.label("Menace écrasée", 13, GameTheme.GOLD, true))
		c.add_child(UiKit.sub("%s est vaincu. Le monde est à vous : mode libre." % Campaign.threat_title(st)))
	else:
		c.add_child(UiKit.label("Menace montante", 13, GameTheme.GOLD, true))
		c.add_child(UiKit.title(Campaign.threat_title(st), 19))
		c.add_child(StatBar.new("Menace", int(float(st["threat"])), 100.0, GameTheme.BLOOD))
		c.add_child(UiKit.sub("Palier %d/%d : %s" % [int(st["stage"]), Campaign.STAGES.size(), Campaign.stage_name(st)]))
		if st["final"] == "open":
			var fs: Dictionary = Campaign.final_site(Game.world)
			if not fs.is_empty():
				c.add_child(UiKit.para("Contrat final : abattre %s." % fs["name"], 14))
				var go := UiKit.button("Marcher sur " + str(fs["name"]), "pri", true)
				go.pressed.connect(_travel_to_site.bind(str(fs["id"])))
				c.add_child(go)
		else:
			c.add_child(UiKit.sub("Le contrat final s'ouvre à %d de renom (menace ≥ %d) ou si la menace atteint 100. Prendre les lieux de %s la fait reculer." % [Campaign.FINAL_RENOWN, int(Campaign.FINAL_MIN_THREAT), Data.FACTION_NAMES[st["faction"]]], 12))
	var arcs: Array = Campaign.arc_summary(st)
	if not arcs.is_empty():
		var a := UiKit.card(_side)
		a.add_child(UiKit.label("Affaires en cours", 13, GameTheme.GOLD, true))
		for ar in arcs:
			a.add_child(UiKit.label("%s — étape %d/%d%s" % [ar["title"], mini(int(ar["step"]) + (0 if ar["phase"] == "done" else 1), int(ar["total"])), ar["total"], " ✓" if ar["phase"] == "done" else ""], 14, GameTheme.INK, true))
			a.add_child(UiKit.sub(str(ar["text"]), 12))


func _refresh_side() -> void:
	if _side == null or Game.world == null:
		return
	for c in _side.get_children():
		_side.remove_child(c)
		c.queue_free()
	_speed_buttons.clear()
	_side.add_child(UiKit.title("En route", 26))
	var row := UiKit.hbox(6)
	row.add_child(UiKit.sub("Temps", 13, false))
	var group := ButtonGroup.new()
	for i in 4:
		var b := UiKit.button(["II", "▶", "▶▶", "▶▶▶"][i], "", true)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == _speed
		b.pressed.connect(_set_speed.bind(i))
		b.tooltip_text = "Pause (Espace)" if i == 0 else "Vitesse ×%d" % i
		row.add_child(b)
		_speed_buttons.append(b)
	_side.add_child(row)
	_status = UiKit.sub("")
	_side.add_child(_status)
	_update_status()
	# Contrat en cours
	if not Game.active_contract.is_empty():
		var ac: Dictionary = Game.active_contract
		var c := UiKit.card(_side)
		c.add_child(UiKit.label("Contrat en cours", 13, GameTheme.GOLD, true))
		c.add_child(UiKit.title(str(ac["title"]), 19))
		var to: Vector2 = Game.contract_target()
		var pts: Array[Vector2] = Game.world.find_path(Game.world.player_pos, to)
		var kind_name: String = {"kill": "Éliminer", "hunt": "Chasse au chef", "escort": "Escorte", "delivery": "Livraison"}.get(str(ac.get("type_contract", "kill")), "Éliminer")
		c.add_child(UiKit.sub("%s · %s : %s · ≈ %.1f j · prime %d couronnes%s" % [kind_name, "Destination" if Contracts.is_transport(ac) else "Lieu", ac["target_name"], Game.world.path_days(pts), ac["pay"], " (à l'arrivée)" if Contracts.is_transport(ac) else ""]))
		var r2 := UiKit.hbox(6)
		var go := UiKit.button("Aller sur place", "pri", true)
		go.pressed.connect(func() -> void: _travel(to, {"kind": "target", "title": str(ac["target_name"])}))
		r2.add_child(go)
		if _confirm_abandon:
			var yes := UiKit.button("Confirmer (−5 renom)", "pri", true)
			yes.pressed.connect(func() -> void:
				_confirm_abandon = false
				Game.abandon_contract())
			r2.add_child(yes)
		else:
			var ab := UiKit.button("Abandonner", "ghost", true)
			ab.pressed.connect(func() -> void:
				_confirm_abandon = true
				_refresh_side())
			r2.add_child(ab)
		c.add_child(r2)
	_build_campaign_panels()
	# Destinations
	_side.add_child(UiKit.title("Lieux", 20))
	var places: Array[Dictionary] = []
	places.assign(Game.world.settlements)
	places.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Game.world.player_pos.distance_squared_to(Game.world.settlement_pos(a)) < Game.world.player_pos.distance_squared_to(Game.world.settlement_pos(b)))
	for s in places:
		var pts2: Array[Vector2] = Game.world.find_path(Game.world.player_pos, Game.world.settlement_pos(s))
		var b := UiKit.button("%s %s · ≈ %.1f j" % ["▣" if s["kind"] == "city" else "⌂", s["name"], Game.world.path_days(pts2)], "", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var st: int = Game.world.standing_of(s)
		var vd: int = Visits.day_of(s)
		b.tooltip_text = ("Visité le jour %d\n" % vd if vd > 0 else "Jamais visité\n") + "%s · %d contrat(s) · prix ×%.2f\nRéputation : %s (%+d)" % ["Ville" if s["kind"] == "city" else "Village", s["contracts"].size(), float(s["price_mult"]) * World.standing_price_mult(st), World.standing_label(st), st]
		b.pressed.connect(_travel_to_settlement.bind(str(s["id"])))
		_side.add_child(b)
	if not Game.world.sites.is_empty():
		_side.add_child(UiKit.title("Lieux hostiles", 20))
		for site in Game.world.sites:
			var spts: Array[Vector2] = Game.world.find_path(Game.world.player_pos, Game.world.settlement_pos(site))
			var mark: String = {"hostile": "☠", "friendly": "⚑", "cleared": "✓"}.get(str(site["state"]), "☠")
			var sb := UiKit.button("%s %s · ≈ %.1f j" % [mark, site["name"], Game.world.path_days(spts)], "", true)
			sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			sb.tooltip_text = Campaign.site_tooltip(site, Game.renown)
			sb.pressed.connect(_travel_to_site.bind(str(site["id"])))
			_side.add_child(sb)
	var comp := UiKit.button("Compagnie", "pri")
	comp.pressed.connect(func() -> void: company_requested.emit())
	_side.add_child(comp)
	var inv_b := UiKit.button("Inventaire (I)")
	inv_b.pressed.connect(func() -> void: InventoryScreen.open(self))
	_side.add_child(inv_b)
	# Hommes
	_side.add_child(UiKit.title("Hommes", 20))
	for m in Game.roster:
		var h := UiKit.hbox(8)
		h.add_child(PortraitView.new(m, 34))
		var v := UiKit.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label(m.unit_name, 14, GameTheme.INK, true))
		v.add_child(StatBar.new("PV", m.hp, m.hp_max, GameTheme.BLOOD))
		h.add_child(v)
		_side.add_child(h)
