class_name MapDrawer
extends Control
## Tiroir « Détails » de la carte : glisse depuis la droite (340 px) et reprend tout l'ancien panneau latéral — contrat en cours,
## vivres et moral, réputation des factions, menace montante et affaires en cours, lieux (avec itinéraire) et hommes.
## Fermé par défaut ; se ferme au clic hors du tiroir (ou Échap / touche D, gérés par MapScreen). Ne calcule aucune règle.

signal travel_requested(target: Vector2, info: Dictionary)
signal toggled(open: bool)

const W := 340
const EDGE := 10  ## marge entre le tiroir et le bord de la fenêtre
const SLIDE := 0.18

var is_open: bool = false

var _catcher: Control
var _panel: PanelContainer
var _box: VBoxContainer
var _confirm_abandon: bool = false
var _tween: Tween
var _ratio: float = 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.visible = false
	_catcher.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close()
			_catcher.accept_event())
	add_child(_catcher)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style())
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = EDGE
	_panel.offset_bottom = -EDGE
	_panel.visible = false
	add_child(_panel)
	_apply_ratio(0.0)
	var outer := UiKit.vbox(8)
	_panel.add_child(outer)
	outer.add_child(_build_head())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_box = UiKit.vbox(10)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	Game.changed.connect(_on_game_changed)
	Settings.changed.connect(_restyle)


func _exit_tree() -> void:
	if Game.changed.is_connected(_on_game_changed):
		Game.changed.disconnect(_on_game_changed)
	if Settings.changed.is_connected(_restyle):
		Settings.changed.disconnect(_restyle)


func _style() -> StyleBoxFlat:
	var s: StyleBoxFlat
	if GameTheme.illustrated():
		s = GameTheme.box(Color(0.12, 0.09, 0.065, 1.0), Color("8a6a30"), 2, 10, Vector4(14, 12, 10, 12))
		s.shadow_size = 8
		s.shadow_color = Color(0, 0, 0, 0.5)
	else:
		s = GameTheme.box(Color(GameTheme.PANEL, 1.0), GameTheme.GOLD, 1, 4, Vector4(14, 12, 10, 12))
	return s


func _restyle() -> void:
	if _panel != null:
		_panel.add_theme_stylebox_override("panel", _style())


func _build_head() -> Control:
	var row := UiKit.hbox(8)
	var bv := BannerView.new(Game.banner, Vector2(22, 30))
	row.add_child(bv)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UiKit.title(Game.company_name, 22, GameTheme.GOLD)
	nm.clip_text = true
	v.add_child(nm)
	v.add_child(UiKit.sub("Détails · jour %d · difficulté %s" % [Game.day, Difficulty.label(Game.difficulty)], 12))
	row.add_child(v)
	var x := UiKit.button("✕", "ghost", true)
	x.tooltip_text = "Fermer (D ou Échap)"
	x.pressed.connect(close)
	row.add_child(x)
	row.set_meta("banner", bv)
	row.set_meta("name", nm)
	return row


func _apply_ratio(r: float) -> void:
	_ratio = r
	_panel.offset_left = lerpf(float(EDGE + 30), -float(W + EDGE), r)
	_panel.offset_right = _panel.offset_left + W


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or Game.world == null:
		return
	is_open = true
	_confirm_abandon = false
	rebuild()
	_panel.visible = true
	_catcher.visible = true
	_slide(1.0)
	toggled.emit(true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_catcher.visible = false
	_slide(0.0)
	toggled.emit(false)


func _slide(target: float) -> void:
	if _tween != null:
		_tween.kill()
	if BattleScreen.speed <= 0.0 or not is_inside_tree():
		_apply_ratio(target)
		_panel.visible = target > 0.0
		return
	_tween = create_tween()
	_tween.tween_method(_apply_ratio, _ratio, target, SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if target <= 0.0:
		_tween.tween_callback(func() -> void: _panel.visible = is_open)


func _on_game_changed() -> void:
	if is_open:
		rebuild()


func _go(target: Vector2, info: Dictionary) -> void:
	travel_requested.emit(target, info)
	close()


## Reconstruit tout le contenu à partir de l'état du jeu.
func rebuild() -> void:
	if _box == null or Game.world == null:
		return
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var head: Control = _panel.get_child(0).get_child(0)
	(head.get_meta("banner") as BannerView).set_banner(Game.banner)
	(head.get_meta("name") as Label).text = Game.company_name
	_build_contract()
	_build_company()
	_build_campaign()
	_build_places()
	_build_men()


func _build_contract() -> void:
	if Game.active_contract.is_empty():
		return
	var ac: Dictionary = Game.active_contract
	var c := UiKit.card(_box)
	c.add_child(UiKit.label("Contrat en cours", 13, GameTheme.GOLD, true))
	c.add_child(UiKit.title(str(ac["title"]), 19))
	var to: Vector2 = Game.contract_target()
	var pts: Array[Vector2] = Game.world.find_path(Game.world.player_pos, to)
	var kind_name: String = {"kill": "Éliminer", "hunt": "Chasse au chef", "escort": "Escorte", "delivery": "Livraison"}.get(str(ac.get("type_contract", "kill")), "Éliminer")
	c.add_child(UiKit.sub("%s · %s : %s · ≈ %.1f j · prime %d couronnes%s" % [kind_name, "Destination" if Contracts.is_transport(ac) else "Lieu", ac["target_name"], Game.world.path_days(pts), ac["pay"], " (à l'arrivée)" if Contracts.is_transport(ac) else ""]))
	var r2 := UiKit.hbox(6)
	var go := UiKit.button("Aller sur place", "pri", true)
	go.pressed.connect(func() -> void: _go(to, {"kind": "target", "title": str(ac["target_name"])}))
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
			rebuild())
		r2.add_child(ab)
	c.add_child(r2)


## Vivres, moral de compagnie et réputation des factions.
func _build_company() -> void:
	var c := UiKit.card(_box)
	c.add_child(UiKit.label("Compagnie", 13, GameTheme.GOLD, true))
	var low: bool = Game.provisions_days() <= float(Data.PROVISIONS_WARN_DAYS)
	var food := StatBar.new("Vivres", Game.provisions, Game.provisions_cap(), GameTheme.BLOOD if low else GameTheme.GOLD)
	food.tooltip_text = "%d rations, ≈ %.1f jours de route. Une ration par homme et par jour de route ; achat au marché." % [Game.provisions, Game.provisions_days()]
	c.add_child(food)
	if low:
		c.add_child(UiKit.label("Vivres presque épuisés !", 13, GameTheme.BLOOD, true))
	var mo := StatBar.new("Moral", int(Game.company_morale), 100, GameTheme.GOLD)
	mo.tooltip_text = "Moral de la compagnie : %s. Il fixe le moral de départ des hommes en bataille (< 25 : Hésitant, > 80 : Confiant)." % Game.morale_label()
	c.add_child(mo)
	for k in Factions.keys():
		var n: int = Game.standing_with(str(k))
		var l := UiKit.label("%s %s : %s (%+d)" % [Data.FACTIONS[k]["ic"], Factions.name_of(str(k)), Factions.label(n), n], 12, Factions.color_of(str(k)))
		l.tooltip_text = Factions.effects_text(n)
		c.add_child(l)


## Cartes « Menace » (crise finale) et « Affaires en cours » (contrats liés).
func _build_campaign() -> void:
	var st: Dictionary = Game.campaign
	var c := UiKit.card(_box)
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
				go.pressed.connect(_go_site.bind(str(fs["id"])))
				c.add_child(go)
		else:
			c.add_child(UiKit.sub("Le contrat final s'ouvre à %d de renom (menace ≥ %d) ou si la menace atteint 100. Prendre les lieux de %s la fait reculer." % [Campaign.FINAL_RENOWN, int(Campaign.FINAL_MIN_THREAT), Data.FACTION_NAMES[st["faction"]]], 12))
	var arcs: Array = Campaign.arc_summary(st)
	if not arcs.is_empty():
		var a := UiKit.card(_box)
		a.add_child(UiKit.label("Affaires en cours", 13, GameTheme.GOLD, true))
		for ar in arcs:
			a.add_child(UiKit.label("%s — étape %d/%d%s" % [ar["title"], mini(int(ar["step"]) + (0 if ar["phase"] == "done" else 1), int(ar["total"])), ar["total"], " ✓" if ar["phase"] == "done" else ""], 14, GameTheme.INK, true))
			a.add_child(UiKit.sub(str(ar["text"]), 12))


func _go_site(id: String) -> void:
	var s: Dictionary = Game.world.site_by_id(id)
	if not s.is_empty():
		_go(Game.world.settlement_pos(s), {"kind": "site", "id": id, "title": str(s["name"])})


func _go_settlement(id: String) -> void:
	var s: Dictionary = Game.world.settlement_by_id(id)
	_go(Game.world.settlement_pos(s), {"kind": "settlement", "id": id, "title": str(s["name"])})


func _build_places() -> void:
	_box.add_child(UiKit.title("Lieux", 20))
	var places: Array[Dictionary] = []
	places.assign(Game.world.settlements)
	places.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Game.world.player_pos.distance_squared_to(Game.world.settlement_pos(a)) < Game.world.player_pos.distance_squared_to(Game.world.settlement_pos(b)))
	for s in places:
		var pts: Array[Vector2] = Game.world.find_path(Game.world.player_pos, Game.world.settlement_pos(s))
		var b := UiKit.button("%s %s · ≈ %.1f j" % ["▣" if s["kind"] == "city" else "⌂", s["name"], Game.world.path_days(pts)], "", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var st: int = Game.world.standing_of(s)
		var vd: int = Visits.day_of(s)
		b.tooltip_text = ("Visité le jour %d\n" % vd if vd > 0 else "Jamais visité\n") + "%s · %d contrat(s) · prix ×%.2f\nRéputation : %s (%+d)" % ["Ville" if s["kind"] == "city" else "Village", s["contracts"].size(), float(s["price_mult"]) * World.standing_price_mult(st), World.standing_label(st), st]
		b.pressed.connect(_go_settlement.bind(str(s["id"])))
		_box.add_child(b)
	if not Game.world.sites.is_empty():
		_box.add_child(UiKit.title("Lieux hostiles", 20))
		for site in Game.world.sites:
			var spts: Array[Vector2] = Game.world.find_path(Game.world.player_pos, Game.world.settlement_pos(site))
			var mark: String = {"hostile": "☠", "friendly": "⚑", "cleared": "✓"}.get(str(site["state"]), "☠")
			var sb := UiKit.button("%s %s · ≈ %.1f j" % [mark, site["name"], Game.world.path_days(spts)], "", true)
			sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			sb.tooltip_text = Campaign.site_tooltip(site, Game.renown)
			sb.pressed.connect(_go_site.bind(str(site["id"])))
			_box.add_child(sb)


func _build_men() -> void:
	_box.add_child(UiKit.title("Hommes", 20))
	for m in Game.roster:
		var h := UiKit.hbox(8)
		h.add_child(PortraitView.new(m, 34))
		var v := UiKit.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label(m.unit_name, 14, GameTheme.INK, true))
		v.add_child(StatBar.new("PV", m.hp, m.hp_max, GameTheme.BLOOD))
		h.add_child(v)
		_box.add_child(h)
