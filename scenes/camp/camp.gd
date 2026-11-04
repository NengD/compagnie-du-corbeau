class_name Camp
extends VBoxContainer
## Écran de ville (Contrats, Recruter, Marché, Compagnie) ou, en route, fiche de la Compagnie seule.
## N'applique aucune règle : lit `Game` et appelle ses méthodes.

signal closed  ## « Retour à la carte » demandé en mode compagnie seule

const CARD_W := 300
const TOWN_TABS: Array[String] = ["Contrats", "Recruter", "Marché", "Compagnie", "Quartier général"]

## "town" : onglets du lieu où l'on se trouve ; "company" : seulement la Compagnie (depuis la carte).
var mode: String = "town"

var _tab_names: Array[String] = []
var _title: Label
var _kind_label: Label
var _news_box: VBoxContainer
var _tabs: TabContainer
var _scrolls: Array[ScrollContainer] = []
var _inners: Array[VBoxContainer] = []
var _over_box: VBoxContainer
var _news_panel: PanelContainer
var _head: Control
var _confirm_dismiss: int = -1
var _confirm_abandon: bool = false
var _help_open: bool = false
var _modal: ModalOverlay


func _ready() -> void:
	Sfx.music("town")
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_names.assign(TOWN_TABS if mode == "town" else ["Compagnie", "Quartier général"])
	_head = _build_head()
	add_child(_head)
	_news_panel = PanelContainer.new()
	_news_panel.theme_type_variation = "NewsPanel"
	_news_box = UiKit.vbox(3)
	_news_panel.add_child(_news_box)
	add_child(_news_panel)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)
	for n in _tab_names:
		var sc := ScrollContainer.new()
		sc.name = n
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var inner := UiKit.vbox(10)
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(inner)
		_tabs.add_child(sc)
		_scrolls.append(sc)
		_inners.append(inner)
	_over_box = UiKit.vbox(12)
	_over_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_over_box)
	_help_open = Game.day == 1 and Game.fallen.is_empty() and mode == "company"
	_tabs.tab_changed.connect(func(i: int) -> void:
		_rebuild()
		if i >= 0 and i < _tab_names.size() and _tab_names[i] == "Marché" and mode == "town":
			MarketScreen.open(self))
	Game.changed.connect(_rebuild)
	_rebuild()


func _exit_tree() -> void:
	if Game.changed.is_connected(_rebuild):
		Game.changed.disconnect(_rebuild)
	_close_modal()


func _build_head() -> Control:
	var row := UiKit.hbox(12)
	_title = UiKit.title("", 30)
	row.add_child(_title)
	_kind_label = UiKit.sub("", 14, false)
	_kind_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_kind_label)
	row.add_child(UiKit.spacer())
	if mode == "town":
		var go := UiKit.button("Quitter la ville", "pri")
		go.pressed.connect(Game.leave_settlement)
		row.add_child(go)
	else:
		var back := UiKit.button("Retour à la carte", "pri")
		back.pressed.connect(func() -> void: closed.emit())
		row.add_child(back)
	return row


func _rebuild() -> void:
	var s: Dictionary = Game.settlement()
	if mode == "town" and not s.is_empty():
		_title.text = str(s["name"])
		var st: int = Game.world.standing_of(s)
		_kind_label.text = "%s · prix ×%.2f · réputation : %s (%+d)" % ["Ville" if s["kind"] == "city" else "Village", float(s["price_mult"]) * World.standing_price_mult(st), World.standing_label(st), st]
	else:
		_title.text = "La Compagnie"
		_kind_label.text = "Jour %d" % Game.day
	for c in _news_box.get_children():
		_news_box.remove_child(c)
		c.queue_free()
	for i in Game.news.size():
		_news_box.add_child(UiKit.para(Game.news[i], 14) if i == 0 else UiKit.sub(Game.news[i], 14))
	_head.visible = not Game.game_over
	_news_panel.visible = not Game.game_over
	_tabs.visible = not Game.game_over
	_over_box.visible = Game.game_over
	for c in _over_box.get_children():
		_over_box.remove_child(c)
		c.queue_free()
	if Game.game_over:
		_build_game_over(_over_box)
		return
	if mode == "town" and s.is_empty():
		return  # on vient de quitter le lieu : l'écran va être remplacé
	var i: int = _tabs.current_tab
	var keep: int = _scrolls[i].scroll_vertical
	var inner: VBoxContainer = _inners[i]
	for c in inner.get_children():
		inner.remove_child(c)
		c.queue_free()
	match _tab_names[i]:
		"Compagnie":
			_build_company(inner)
		"Quartier général":
			HqTab.build(inner)
		"Contrats":
			_build_contracts(inner)
		"Recruter":
			_build_recruits(inner)
		"Marché":
			_build_market(inner)
	_restore_scroll(_scrolls[i], keep)


func _restore_scroll(sc: ScrollContainer, value: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_vertical = value


func _flow(parent: Node) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(f)
	return f


func _build_game_over(box: VBoxContainer) -> void:
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := UiKit.title("La compagnie n'est plus", 48, GameTheme.BLOOD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var p := UiKit.para("Au jour %d, le dernier homme du Corbeau est tombé ou a déserté. Personne ne chantera leurs noms." % Game.day)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(p)
	var names: Array = []
	for f in Game.fallen:
		names.append(f["name"])
	var s := UiKit.sub(" · ".join(names) if not names.is_empty() else "—")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	var b := UiKit.button("Fonder une nouvelle compagnie", "pri")
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: DifficultyPanel.open(self, func(level: String) -> void: Game.new_game(-1, level)))
	box.add_child(b)


# --- Compagnie ---

func _build_company(root: VBoxContainer) -> void:
	var help_btn := UiKit.button("Comment jouer " + ("▴" if _help_open else "▾"), "ghost", true)
	help_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	help_btn.pressed.connect(func() -> void:
		_help_open = not _help_open
		_rebuild())
	root.add_child(help_btn)
	if _help_open:
		var hp := PanelContainer.new()
		hp.theme_type_variation = "Card"
		var hv := UiKit.vbox(4)
		for line in [
			"Sur la carte, cliquez pour vous déplacer : chaque jour de route coûte la solde de la compagnie. Villes et villages proposent des contrats, des recrues et un marchand.",
			"Acceptez un contrat, rendez-vous à l'endroit indiqué : le combat s'engage. Des bandes errantes peuvent aussi vous tomber dessus.",
			"En bataille : 9 points d'action (PA) par tour, une case coûte 2 PA, une attaque 4 à 6 PA. Cliquez une case dorée pour bouger, un ennemi marqué d'un pourcentage pour frapper.",
			"L'armure (barres grise et bleue) absorbe les coups avant les PV (barre rouge). Les haches broient l'armure, les masses passent au travers.",
			"Quitter le contact d'un ennemi lui offre une attaque gratuite. La fatigue monte à chaque action. Le moral chute quand un camarade tombe.",
			"La mort est définitive. Gagnez de l'expérience pour promouvoir vos hommes.",
		]:
			hv.add_child(UiKit.para("•  " + line, 14))
		hp.add_child(hv)
		root.add_child(hp)
	var actions := UiKit.hbox(8)
	if Game.in_settlement():
		var rest_b := UiKit.button("Se reposer un jour (+15 PV, −%d solde)" % Game.wages())
		rest_b.disabled = not Game.has_wounded()
		rest_b.pressed.connect(Game.rest)
		actions.add_child(rest_b)
		var rc: int = Game.repair_cost()
		var rep_b := UiKit.button("Réparer armures, armes et boucliers (%d couronnes)" % rc)
		rep_b.disabled = rc <= 0 or Game.gold < rc
		rep_b.pressed.connect(Game.repair)
		actions.add_child(rep_b)
	else:
		actions.add_child(UiKit.sub("Repos et réparations : dans une ville ou un village.", 13, false))
	var inv_open := UiKit.button("Inventaire (I)")
	inv_open.pressed.connect(func() -> void: InventoryScreen.open(self))
	actions.add_child(inv_open)
	var banner_open := UiKit.button("Bannière")
	banner_open.tooltip_text = "Nom, couleurs et emblème de la compagnie"
	banner_open.pressed.connect(func() -> void: BannerScreen.open(self))
	actions.add_child(banner_open)
	actions.add_child(UiKit.sub("%d/%d hommes · %d au combat (maximum %d), les autres en réserve" % [Game.roster.size(), Game.max_roster(), Formation.field_count(Game.formation_slots()), Data.FIGHTERS], 13, false))
	root.add_child(actions)
	var flow := _flow(root)
	for i in Game.roster.size():
		_roster_card(flow, Game.roster[i], i)
	if not Game.fallen.is_empty():
		var parts: Array = []
		for f in Game.fallen:
			parts.append("%s (%s, niv. %d, jour %d)" % [f["name"], f["bg"], f["lvl"], f["day"]])
		root.add_child(UiKit.sub("Tombés au combat : " + " · ".join(parts)))


func _who_header(parent: Node, m: Unit, sub_text: String, with_level: bool) -> void:
	var h := UiKit.hbox(10)
	h.add_child(PortraitView.new(m, 54))
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UiKit.hbox(6)
	var name_l := UiKit.title(m.unit_name, 22)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	top.add_child(name_l)
	if with_level:
		top.add_child(UiKit.chip("Niv. %d" % m.level))
	v.add_child(top)
	v.add_child(UiKit.sub(sub_text))
	h.add_child(v)
	parent.add_child(h)


func _roster_card(flow: Node, m: Unit, index: int) -> void:
	var c := UiKit.card(flow, CARD_W)
	var reserve: String = " · en réserve" if Formation.is_reserve(int(Game.formation_slots().get(m.id, -1))) else ""
	_who_header(c, m, "%s · %d victime%s · solde %d/jour%s" % [m.background, m.kills, "s" if m.kills > 1 else "", m.wage, reserve], true)
	var prev: int = int(Data.XP_THRESHOLDS[m.level])
	var nxt: int = int(Data.XP_THRESHOLDS[m.level + 1]) if m.level + 1 < Data.XP_THRESHOLDS.size() else prev + 1
	c.add_child(UiKit.bars(m, [StatBar.new("Exp.", m.xp - prev, nxt - prev, GameTheme.GOLD)]))
	c.add_child(UiKit.stats_grid(m))
	c.add_child(UiKit.gear_list(m))
	var tc: Control = TraitChips.row(m)
	if tc != null:
		c.add_child(tc)
	var bond_txt: String = Bonds.summary(m, Game.roster)
	if bond_txt != "":
		var bl := UiKit.sub(bond_txt, 12)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(bl)
	var pk: Control = PerkIcon.row(m)
	if pk != null:
		c.add_child(pk)
	if m.perk_points > 0:
		c.add_child(UiKit.label("%d point%s de talent à dépenser" % [m.perk_points, "s" if m.perk_points > 1 else ""], 13, GameTheme.GOLD, true))
	if not m.injuries.is_empty():
		var inj := UiKit.label("Blessures : " + ", ".join(m.injuries.map(func(i: Dictionary) -> String: return Injuries.label(i))), 13, GameTheme.BLOOD)
		inj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(inj)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	if m.pending > 0:
		var pb := UiKit.button("Promouvoir (%d)" % m.pending, "pri", true)
		pb.pressed.connect(_open_promotion.bind(m.id))
		row.add_child(pb)
	var tb := UiKit.button("Talents (%d)" % m.perk_points if m.perk_points > 0 else "Talents", "pri" if m.perk_points > 0 else "", true)
	tb.tooltip_text = "Arbre de talents : 1 point par niveau gagné."
	tb.pressed.connect(func() -> void: PerkScreen.open(self, m))
	row.add_child(tb)
	if index > 0:
		var up := UiKit.button("↑", "", true)
		up.tooltip_text = "Monter dans l'ordre"
		up.pressed.connect(Game.move_up.bind(m.id))
		row.add_child(up)
	if Game.roster.size() > 1:
		if _confirm_dismiss == m.id:
			var yes := UiKit.button("Confirmer le renvoi", "pri", true)
			yes.pressed.connect(func() -> void:
				_confirm_dismiss = -1
				Game.dismiss(m.id))
			row.add_child(yes)
			var no := UiKit.button("Garder", "", true)
			no.pressed.connect(func() -> void:
				_confirm_dismiss = -1
				_rebuild())
			row.add_child(no)
		else:
			var d := UiKit.button("Renvoyer", "ghost", true)
			d.pressed.connect(func() -> void:
				_confirm_dismiss = m.id
				_rebuild())
			row.add_child(d)
	c.add_child(row)


# --- Contrats ---

func _build_contracts(root: VBoxContainer) -> void:
	var here: Dictionary = Game.settlement()
	var origin: Vector2 = Game.world.settlement_pos(here)
	if not Game.active_contract.is_empty():
		var ac: Dictionary = Game.active_contract
		var box := UiKit.card(root)
		box.add_child(UiKit.label("Contrat en cours", 13, GameTheme.GOLD, true))
		box.add_child(UiKit.title(str(ac["title"]), 20))
		box.add_child(UiKit.sub("Rendez-vous : %s · prime %d couronnes. Un seul contrat à la fois." % [ac["target_name"], ac["pay"]]))
		var row := UiKit.hbox(6)
		if _confirm_abandon:
			var yes := UiKit.button("Confirmer l'abandon (−5 renom)", "pri", true)
			yes.pressed.connect(func() -> void:
				_confirm_abandon = false
				Game.abandon_contract())
			row.add_child(yes)
			var no := UiKit.button("Garder", "", true)
			no.pressed.connect(func() -> void:
				_confirm_abandon = false
				_rebuild())
			row.add_child(no)
		else:
			var ab := UiKit.button("Abandonner", "ghost", true)
			ab.pressed.connect(func() -> void:
				_confirm_abandon = true
				_rebuild())
			row.add_child(ab)
		box.add_child(row)
	if here["contracts"].is_empty():
		root.add_child(UiKit.sub("Aucun contrat à pourvoir pour l'instant. Revenez dans quelques jours."))
		return
	var flow := _flow(root)
	for i in here["contracts"].size():
		var ct: Dictionary = here["contracts"][i]
		var c := UiKit.card(flow, CARD_W + 20)
		var top := UiKit.hbox(6)
		var sk := UiKit.skulls(int(ct["d"]))
		sk.tooltip_text = "Danger %d sur 3" % ct["d"]
		top.add_child(sk)
		if ct.has("arc"):
			top.add_child(UiKit.chip("%s · %d/%d" % [Campaign.ARCS[ct["arc"]]["title"], int(ct["arc_step"]) + 1, Campaign.ARC_STEPS], GameTheme.GOLD))
		top.add_child(UiKit.spacer())
		var dist: float = origin.distance_to(Vector2(float(ct["tx"]), float(ct["ty"])))
		top.add_child(UiKit.sub("≈ %d jour%s de route" % [maxi(1, int(ceil(dist / World.DAY_PX))), "s" if dist > World.DAY_PX else ""], 13, false))
		c.add_child(top)
		c.add_child(UiKit.title(str(ct["title"]), 22))
		c.add_child(UiKit.sub(str(ct["employer"])))
		if Data.FACTIONS.has(str(ct.get("faction", ""))):
			var fl := UiKit.label("%s %s" % [Data.FACTIONS[ct["faction"]]["ic"], Factions.name_of(str(ct["faction"]))], 13, Factions.color_of(str(ct["faction"])), true)
			fl.tooltip_text = "Employeur : sa réputation est en jeu."
			c.add_child(fl)
			if Data.FACTIONS.has(str(ct.get("vs_faction", ""))):
				c.add_child(UiKit.sub("Dessert la cause contre : " + Factions.name_of(str(ct["vs_faction"])) + " (prime majorée)", 12))
		c.add_child(UiKit.para(str(ct["desc"])))
		var kind_txt: String = {"kill": "Éliminer", "hunt": "Chasse au chef", "escort": "Escorte", "delivery": "Livraison"}.get(str(ct.get("type_contract", "kill")), "Éliminer")
		if Contracts.is_transport(ct):
			var risk: String = "embuscade possible (%s)" % Data.FACTION_NAMES[ct["type"]] if float(ct.get("ambush_at", -1.0)) >= 0.0 else "route réputée sûre"
			c.add_child(UiKit.sub("%s · destination : %s · prime à l'arrivée · %s" % [kind_txt, ct["target_name"], "risque : " + risk]))
		else:
			c.add_child(UiKit.sub("%s · Lieu : %s · ennemis : %s, environ %d" % [kind_txt, ct["target_name"], Data.FACTION_NAMES[ct["type"]], ct["foes"].size()]))
		var foot := UiKit.hbox(6)
		foot.add_child(UiKit.label(str(ct["pay"]), 22, GameTheme.GOLD, true))
		foot.add_child(UiKit.sub("couronnes", 13, false))
		foot.add_child(UiKit.spacer())
		var acc := UiKit.button("Accepter", "pri")
		acc.disabled = not Game.active_contract.is_empty()
		acc.pressed.connect(Game.accept_contract.bind(i))
		foot.add_child(acc)
		c.add_child(foot)


# --- Recrues ---

func _build_recruits(root: VBoxContainer) -> void:
	var full: bool = Game.roster.size() >= Game.max_roster()
	var recruits: Array = Game.settlement()["recruits"]
	root.add_child(UiKit.sub("Les recrues changent avec le temps." + (" La compagnie est au complet (%d)." % Game.max_roster() if full else "")))
	if recruits.is_empty():
		root.add_child(UiKit.sub("Personne ne cherche d'engagement ici pour l'instant."))
		return
	var flow := _flow(root)
	for i in recruits.size():
		var r: Dictionary = recruits[i]
		var u: Unit = r["u"]
		var c := UiKit.card(flow, CARD_W)
		_who_header(c, u, "%s · solde %d/jour" % [u.background, u.wage], false)
		c.add_child(UiKit.stats_grid(u))
		c.add_child(UiKit.gear_list(u))
		var rt: Control = TraitChips.row(u)
		if rt != null:
			c.add_child(rt)
		var rp: Control = PerkIcon.row(u)
		if rp != null:
			c.add_child(rp)
		var foot := UiKit.hbox(6)
		foot.add_child(UiKit.label(str(r["price"]), 22, GameTheme.GOLD, true))
		foot.add_child(UiKit.sub("couronnes", 13, false))
		foot.add_child(UiKit.spacer())
		var hb := UiKit.button("Engager", "pri")
		hb.disabled = Game.gold < int(r["price"]) or full
		hb.pressed.connect(Game.hire.bind(i))
		foot.add_child(hb)
		c.add_child(foot)


# --- Marché ---

## L'onglet Marché est un raccourci : l'écran « Place du marché » (scenes/market/market_screen.gd) s'ouvre en choisissant l'onglet.
func _build_market(root: VBoxContainer) -> void:
	_section(root, "Place du marché")
	var card := UiKit.card(root)
	var st: Array = Game.shop_stock()
	card.add_child(UiKit.para("Le marchand de %s propose %d articles en rayon ; la réserve de la compagnie compte %d/%d emplacements." % [Game.settlement().get("name", ""), st.size(), Game.inventory.size(), Game.stash_size()]))
	card.add_child(UiKit.sub("Achetez et vendez par double-clic ou en glissant un objet d'un panneau à l'autre. Les objets achetés rejoignent la réserve : équipez-les ensuite depuis l'inventaire (touche I)."))
	var row := UiKit.hbox(8)
	var open_b := UiKit.button("Ouvrir le marché", "pri")
	open_b.pressed.connect(func() -> void: MarketScreen.open(self))
	row.add_child(open_b)
	var inv_b := UiKit.button("Inventaire et fiches (I)")
	inv_b.pressed.connect(func() -> void: InventoryScreen.open(self))
	row.add_child(inv_b)
	card.add_child(row)


func _section(root: Node, text: String) -> void:
	root.add_child(UiKit.title(text, 24))


# --- Promotion ---

func _close_modal() -> void:
	if _modal != null:
		_modal.close()
		_modal = null


func _open_promotion(id: int) -> void:
	var m: Unit = Game.member(id)
	if m == null or m.pending <= 0:
		return
	_close_modal()
	var rolls: Dictionary = Game.roll_promotion()
	var chosen: Array = []
	_modal = ModalOverlay.open(self, 480)
	var box: VBoxContainer = _modal.content
	box.add_child(UiKit.title(m.unit_name, 34))
	box.add_child(UiKit.sub("Niveau %d — choisissez trois attributs à améliorer." % (m.level - m.pending + 1)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var ok := UiKit.button("Valider", "pri")
	ok.disabled = true
	var refresh := func() -> void:
		ok.disabled = chosen.size() != 3
	for k in Data.STAT_NAMES:
		var b := UiKit.button("%s  %d   +%d" % [Data.STAT_NAMES[k], int(m.get(k)), rolls[k]])
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggled.connect(func(on: bool) -> void:
			if on and chosen.size() >= 3:
				b.set_pressed_no_signal(false)
				return
			if on:
				chosen.append(k)
			else:
				chosen.erase(k)
			refresh.call())
		grid.add_child(b)
	if m.perk_points > 0:
		box.add_child(UiKit.sub("Les talents se choisissent à part, depuis le bouton « Talents » (%d point%s à dépenser)." % [m.perk_points, "s" if m.perk_points > 1 else ""]))
	var row := UiKit.hbox(8)
	ok.pressed.connect(func() -> void:
		if Game.apply_promotion(m, rolls, chosen):
			_close_modal())
	row.add_child(ok)
	var later := UiKit.button("Plus tard")
	later.pressed.connect(_close_modal)
	row.add_child(later)
	box.add_child(row)
