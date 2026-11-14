class_name TradePanel
extends VBoxContainer
## Onglet « Marchandises » du marché : cargaison de la compagnie, prix du lieu, prix connus ailleurs.
## Lecture seule de l'état ; achats et ventes passent par Game.trade_buy / Game.trade_sell (logique : core/trade.gd).

signal said(text: String, good: bool)

var _cap_l: Label
var _rows: VBoxContainer


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_cap_l = UiKit.label("", 17, GameTheme.GOLD, true)
	_cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_cap_l)
	var hint := UiKit.sub("Achetez où c'est bon marché (« produit ici »), revendez là où c'est « très demandé ». Les marchandises voyagent dans vos chariots, pas dans la réserve.", 13, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ListPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	GameTheme.style_scrollbar(sc)
	_rows = UiKit.vbox(6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_rows)
	panel.add_child(sc)
	add_child(panel)


func refresh() -> void:
	if not is_inside_tree():
		return
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var st: Dictionary = Trade.state(Game.extras)
	var used: int = Trade.total(st)
	var cap: int = Game.cargo_capacity()
	_cap_l.text = "Cargaison : %d / %d" % [used, cap]
	_cap_l.add_theme_color_override("font_color", GameTheme.BLOOD if used >= cap else GameTheme.GOLD)
	var view: Array = Game.trade_view()
	for e in view:
		_rows.add_child(_row(e, used < cap))


func _row(e: Dictionary, room: bool) -> Control:
	var g: String = str(e["good"])
	var box := PanelContainer.new()
	box.theme_type_variation = "InsetPanel"
	var v := UiKit.vbox(2)
	box.add_child(v)
	var h := UiKit.hbox(10)
	v.add_child(h)
	var info := UiKit.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var role: String = str(e["role"])
	var role_txt: String = "  · produit ici (bon marché)" if role == "make" else ("  · très demandé (se vend cher)" if role == "want" else "")
	var role_col: Color = GameTheme.INK
	info.add_child(UiKit.label("%s %s%s" % [str(TradeData.GOODS[g]["ic"]), str(e["name"]), role_txt], 16, GameTheme.GOLD if role == "want" else role_col, true))
	var line: String = "Achat %d · Revente %d" % [int(e["buy"]), int(e["sell"])]
	if int(e["have"]) > 0:
		line += " · en cale : %d (payé %d)" % [int(e["have"]), int(e["paid"])]
	info.add_child(UiKit.sub(line, 13, true))
	h.add_child(info)
	var by1 := UiKit.button("Acheter 1", "", true)
	by1.disabled = not room or Game.gold < int(e["buy"])
	by1.pressed.connect(func() -> void: _act(true, g, 1))
	h.add_child(by1)
	var by5 := UiKit.button("×5", "", true)
	by5.disabled = by1.disabled
	by5.pressed.connect(func() -> void: _act(true, g, 5))
	h.add_child(by5)
	var sl1 := UiKit.button("Vendre 1", "", true)
	sl1.disabled = int(e["have"]) <= 0
	sl1.pressed.connect(func() -> void: _act(false, g, 1))
	h.add_child(sl1)
	var sla := UiKit.button("Tout", "", true)
	sla.disabled = sl1.disabled
	var all_n: int = int(e["have"])
	sla.pressed.connect(func() -> void: _act(false, g, all_n))
	h.add_child(sla)
	# Prix connus : les trois meilleurs lieux déjà visités
	var known: Array = e["known"]
	var parts: PackedStringArray = []
	for k in known.slice(0, 3):
		parts.append("%s %d (j.%d)" % [str(k["name"]), int(k["price"]), int(k["day"])])
	var kl := UiKit.sub("Prix connus : " + (" · ".join(parts) if not parts.is_empty() else "aucun"), 12, true)
	kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(kl)
	var tip: PackedStringArray = [str(TradeData.GOODS[g]["d"])]
	for k in known:
		tip.append("%s : %d couronnes (vu au jour %d)" % [str(k["name"]), int(k["price"]), int(k["day"])])
	box.tooltip_text = "\n".join(tip)
	return box


func _act(buy: bool, g: String, n: int) -> void:
	var ok: bool = Game.trade_buy(g, n) if buy else Game.trade_sell(g, n)
	if not ok:
		said.emit(Game.shop_error, false)
