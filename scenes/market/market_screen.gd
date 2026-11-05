class_name MarketScreen
extends ModalOverlay
## « Place du marché » : la réserve du joueur (à gauche) et le rayon du marchand (à droite) en grilles de cases `ItemCell`,
## une colonne de filtres au centre, la barre de ressources en haut, « Partir » en bas.
## Achat / vente : double-clic ou glisser-déposer d'un panneau à l'autre. La logique est dans core/market.gd et
## Game.buy_item / Game.sell_item ; cet écran n'affiche que l'état et relaie les gestes.

const CELL: int = 64
const GAP: int = 4
const MIN_ROWS: int = 4

var filter: String = "all"

var _res_box: HBoxContainer
var _inv_scroll: ScrollContainer
var _shop_scroll: ScrollContainer
var _inv_grid: GridContainer
var _shop_grid: GridContainer
var _filter_btns: Dictionary = {}
var _cap_l: Label
var _msg_l: Label
var _desc_l: Label
var _rebuild_pending: bool = false
var _cols: int = 6
var _last_msg: String = ""


## Ouvre le marché du lieu (une seule instance à la fois).
static func open(host: Node, _min_width: int = 0) -> MarketScreen:
	for n in host.get_tree().get_nodes_in_group("market_screen"):
		return n as MarketScreen
	var layer := CanvasLayer.new()
	layer.layer = 50
	host.add_child(layer)
	var s := MarketScreen.new()
	s._layer = layer
	s.theme = GameTheme.get_theme()
	layer.add_child(s)
	s._build_screen()
	return s


func _build_screen() -> void:
	add_to_group("market_screen")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ModalPanel"
	margin.add_child(panel)
	var root := UiKit.vbox(8)
	panel.add_child(root)

	# Titre et description du lieu
	var s: Dictionary = Game.settlement()
	var city: bool = str(s.get("kind", "village")) == "city"
	var head := UiKit.vbox(0)
	var t := UiKit.title("Place du marché", 38, GameTheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	var desc_text: String = "Étals, forgerons et colporteurs : tout ce qu'une compagnie peut désirer se vend ici, pour qui en paie le prix." if city \
		else "Quelques étals sous les halles : peu de choix, mais des prix honnêtes pour qui passe."
	var d := UiKit.sub("%s — %s" % [str(s.get("name", "")), desc_text], 15, false)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(d)
	root.add_child(head)

	# Barre de ressources
	var res_panel := PanelContainer.new()
	res_panel.add_theme_stylebox_override("panel", GameTheme.box(Color("14100c"), GameTheme.LINE, 1, 3, Vector4(10, 5, 10, 5)))
	_res_box = UiKit.hbox(34)
	_res_box.alignment = BoxContainer.ALIGNMENT_CENTER
	res_panel.add_child(_res_box)
	root.add_child(res_panel)

	# Corps : inventaire | filtres | magasin
	var body := UiKit.hbox(8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var left := _make_panel("Inventaire", "inv")
	body.add_child(left["panel"])
	_inv_scroll = left["scroll"]
	_inv_grid = left["grid"]
	body.add_child(_build_filters())
	var right := _make_panel("Magasin", "shop")
	body.add_child(right["panel"])
	_shop_scroll = right["scroll"]
	_shop_grid = right["grid"]

	# Pied : description, message, Partir
	var info := UiKit.vbox(0)
	_desc_l = UiKit.sub("", 14, true)
	_desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_l.custom_minimum_size = Vector2(0, 20)
	info.add_child(_desc_l)
	_msg_l = UiKit.label("", 15, GameTheme.INK, true)
	_msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_l.custom_minimum_size = Vector2(0, 22)
	info.add_child(_msg_l)
	root.add_child(info)
	var foot := UiKit.hbox(0)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := UiKit.button("Partir", "pri")
	go.custom_minimum_size = Vector2(220, 0)
	go.pressed.connect(close)
	foot.add_child(go)
	root.add_child(foot)

	_inv_scroll.resized.connect(_fit_cols)
	_shop_scroll.resized.connect(_fit_cols)
	Game.shop_error = ""
	_last_msg = Game.news[0] if not Game.news.is_empty() else ""
	Game.changed.connect(_queue_rebuild)
	_rebuild()
	_fit_cols.call_deferred()


func _exit_tree() -> void:
	if Game.changed.is_connected(_queue_rebuild):
		Game.changed.disconnect(_queue_rebuild)


func close() -> void:
	remove_from_group("market_screen")
	super.close()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# --- Panneaux ---

## Panneau à cadre sombre : titre, zone de défilement, grille. Sert aussi de cible de dépôt (`zone` : "inv" ou "shop").
func _make_panel(title: String, zone: String) -> Dictionary:
	var p := DropZone.new()
	p.screen = self
	p.zone = zone
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(250, 0)
	p.add_theme_stylebox_override("panel", GameTheme.box(Color("1a1510"), Color("5a4a30"), 2, 3, Vector4(10, 8, 6, 8)))
	var v := UiKit.vbox(6)
	var t := UiKit.title(title, 26, GameTheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	style_scrollbar(sc)
	var holder := MarginContainer.new()  # centre la grille et laisse la place de la barre
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := GridContainer.new()
	g.columns = _cols
	g.add_theme_constant_override("h_separation", GAP)
	g.add_theme_constant_override("v_separation", GAP)
	holder.add_child(g)
	sc.add_child(holder)
	v.add_child(sc)
	p.add_child(v)
	return {"panel": p, "scroll": sc, "grid": g}


static func style_scrollbar(sc: ScrollContainer) -> void:
	var bar: VScrollBar = sc.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(14, 0)
	bar.add_theme_stylebox_override("scroll", GameTheme.box(Color("0e0b08"), Color("3a2f22"), 1, 6, Vector4(0, 0, 0, 0)))
	bar.add_theme_stylebox_override("grabber", GameTheme.box(Color("8a6a2c"), Color("cfa851"), 1, 6, Vector4(0, 0, 0, 0)))
	bar.add_theme_stylebox_override("grabber_highlight", GameTheme.box(Color("b08a3a"), Color("e8c56a"), 1, 6, Vector4(0, 0, 0, 0)))
	bar.add_theme_stylebox_override("grabber_pressed", GameTheme.box(Color("c89a40"), Color("f0d27a"), 1, 6, Vector4(0, 0, 0, 0)))


func _build_filters() -> Control:
	var col := UiKit.vbox(6)
	col.custom_minimum_size = Vector2(66, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var group := ButtonGroup.new()
	var reps: Dictionary = {"weapon": ["weapon", "epee"], "body": ["body", "gambison"], "head": ["head", "casque"], "shield": ["shield", ""], "tool": ["tool", "pierre"], "food": ["food", "ration"]}
	for f in Market.FILTERS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(56, 52)
		b.tooltip_text = str(Market.FILTER_NAMES[f])
		if f == "all":
			b.text = "Tout"
			b.add_theme_font_size_override("font_size", 14)
		else:
			var tex: Texture2D = ItemIcons.get_icon(str(reps[f][0]), str(reps[f][1]))
			if tex != null:
				b.icon = tex
				b.expand_icon = true
				b.add_theme_constant_override("icon_max_width", 36)
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				b.text = str(Market.FILTER_NAMES[f]).substr(0, 4)
		b.set_pressed_no_signal(f == filter)
		var key: String = f
		b.pressed.connect(func() -> void: set_filter(key))
		col.add_child(b)
		_filter_btns[f] = b
	col.add_child(UiKit.spacer())
	_cap_l = UiKit.sub("", 13, false)
	_cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_cap_l)
	return col


func set_filter(f: String) -> void:
	filter = f
	_rebuild()


# --- Construction ---

func _queue_rebuild() -> void:
	if not _rebuild_pending:
		_rebuild_pending = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_pending = false
	if not is_inside_tree():
		return
	_build_resources()
	_fill_inventory()
	_fill_shop()
	_cap_l.text = "Réserve\n%d/%d" % [Game.inventory.size(), Game.stash_size()]
	_cap_l.add_theme_color_override("font_color", GameTheme.BLOOD if Game.inventory.size() >= Game.stash_size() else GameTheme.MUTE)
	if not Game.news.is_empty() and Game.news[0] != _last_msg:
		_last_msg = Game.news[0]
		_say(_last_msg, true)
	_fit_cols()


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _say(text: String, good: bool) -> void:
	_msg_l.text = text
	_msg_l.add_theme_color_override("font_color", GameTheme.INK if good else GameTheme.BLOOD)


## Nombre de colonnes selon la largeur disponible (la hauteur se règle seule par le défilement).
func _fit_cols() -> void:
	if _inv_scroll == null or not is_inside_tree():
		return
	var w: float = minf(_inv_scroll.size.x, _shop_scroll.size.x) - 18.0
	var n: int = clampi(int(floor((w + GAP) / float(CELL + GAP))), 3, 12)
	if n != _cols:
		_cols = n
		_fill_inventory()
		_fill_shop()
	else:
		_inv_grid.columns = _cols
		_shop_grid.columns = _cols


func _build_resources() -> void:
	_clear(_res_box)
	_res_box.add_child(_res_chip(true, "%s" % ItemCell._fmt(Game.gold), "Couronnes", GameTheme.GOLD))
	var food_col: Color = GameTheme.BLOOD if Game.provisions <= 0 else GameTheme.INK
	_res_box.add_child(_res_chip(false, "%d / %d" % [Game.provisions, Game.provisions_cap()], "Vivres (rations) · %.1f jours de route" % Game.provisions_days(), food_col, "food", "ration", "Vivres"))
	_res_box.add_child(_res_chip(false, "%d / %d" % [Game.inventory.size(), Game.stash_size()], "Emplacements de la réserve", GameTheme.INK, "tool", "pierre", "Réserve"))
	_res_box.add_child(_res_chip(false, "%d / %d" % [Game.roster.size(), Game.max_roster()], "Hommes dans la compagnie", GameTheme.INK, "", ""))


## Pastille de ressource : pièce dorée ou petite icône, puis la valeur.
func _res_chip(coin: bool, text: String, tip: String, col: Color, kind: String = "", key: String = "", label: String = "") -> Control:
	var h := UiKit.hbox(6)
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	if coin:
		h.add_child(CoinIcon.new())
	elif kind != "":
		var tex: Texture2D = ItemIcons.get_icon(kind, key)
		if tex != null:
			var r := TextureRect.new()
			r.texture = tex
			r.custom_minimum_size = Vector2(28, 28)
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(r)
		if label != "":
			h.add_child(UiKit.label(label, 14, GameTheme.MUTE))
	else:
		h.add_child(UiKit.label("Hommes", 14, GameTheme.MUTE))
	var l := UiKit.label(text, 18, col, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return h


func _fill_inventory() -> void:
	_clear(_inv_grid)
	_inv_grid.columns = _cols
	var idxs: Array[int] = Market.inventory_filtered(Game.inventory, filter)
	var total: int = maxi(Game.stash_size(), Game.inventory.size())
	var shown: int = total if filter == "all" else idxs.size()
	var cells: int = _round_cells(shown)
	for k in cells:
		var cell := ItemCell.new()
		if k < idxs.size():
			var i: int = idxs[k]
			var it: Dictionary = Game.inventory[i]
			var price: int = Game.sell_price(it)
			cell.set_item(it, _opts(it, price, 1))
			cell.tooltip_provider = func() -> String: return Inventory.tooltip(it, price)
			cell.drag_data_provider = func() -> Variant: return {"src": "inv", "index": i}
			cell.double_clicked.connect(func() -> void: act_sell(i))
			cell.hovered.connect(func(_x: Dictionary) -> void: _hint(it, "Revente : %d couronnes (double-clic pour vendre)" % price))
		else:
			cell.set_empty()
			cell.custom_minimum_size = Vector2(CELL, CELL)
		_inv_grid.add_child(cell)


func _fill_shop() -> void:
	_clear(_shop_grid)
	_shop_grid.columns = _cols
	var view: Array = Game.shop_view()
	var shown: Array = []
	for e in view:
		if filter == "all" or str(e["item"]["kind"]) == filter:
			shown.append(e)
	var cells: int = _round_cells(shown.size())
	for k in cells:
		var cell := ItemCell.new()
		if k < shown.size():
			var e: Dictionary = shown[k]
			var it: Dictionary = e["item"]
			var idx: int = int(e["index"])
			var price: int = int(e["price"])
			var o: Dictionary = _opts(it, price, int(e["qty"]))
			if bool(e["food"]):
				o["qty"] = int(e["qty"])
			cell.set_item(it, o)
			cell.tooltip_provider = func() -> String: return _shop_tip(e)
			cell.drag_data_provider = func() -> Variant: return {"src": "shop", "index": idx}
			cell.double_clicked.connect(func() -> void: act_buy(idx))
			cell.hovered.connect(func(_x: Dictionary) -> void: _hint(it, "Prix : %d couronnes (double-clic pour acheter)" % price))
		else:
			cell.set_empty()
			cell.custom_minimum_size = Vector2(CELL, CELL)
		_shop_grid.add_child(cell)


## Nombre de cases à dessiner : un multiple de la largeur, au moins `MIN_ROWS` rangées.
func _round_cells(n: int) -> int:
	return maxi(MIN_ROWS, int(ceil(n / float(_cols)))) * _cols


func _opts(it: Dictionary, price: int, qty: int) -> Dictionary:
	var o: Dictionary = {"price": price, "size": CELL}
	if qty > 1:
		o["qty"] = qty
	if str(it["kind"]) != Market.FOOD and (Loot.dur_max(it) > 0 or Loot.armor_max(it) > 0):
		o["durability"] = Loot.wear_ratio(it)
	return o


func _hint(it: Dictionary, price_line: String) -> void:
	var name: String = "Vivres" if str(it["kind"]) == Market.FOOD else Loot.item_name(it)
	var d: String = "Rations : un homme en mange une par jour de route." if str(it["kind"]) == Market.FOOD else Loot.describe(it)
	_desc_l.text = "%s — %s · %s" % [name, d, price_line]


## Infobulle détaillée d'une entrée du rayon : caractéristiques, durabilité, prix d'achat.
func _shop_tip(e: Dictionary) -> String:
	var it: Dictionary = e["item"]
	if bool(e["food"]):
		var lot: int = Game.food_lot(it)
		return "Vivres ×%d\nUne ration nourrit un homme pour un jour de route.\nUn achat prend %d rations pour %d couronnes.\nVous en avez %d sur %d." % [int(e["qty"]), lot, int(e["price"]), Game.provisions, Game.provisions_cap()]
	var lines: PackedStringArray = Inventory.tooltip(it, 0).split("\n")
	lines.remove_at(lines.size() - 1)  # la ligne « valeur de revente » n'a pas de sens ici
	if int(e["qty"]) > 1:
		lines.append("%d en rayon" % int(e["qty"]))
	if bool(e["rare"]):
		lines.append("Marchand rare : pièce d'exception, un seul exemplaire.")
	lines.append("Prix : %d couronnes" % int(e["price"]))
	return "\n".join(lines)


# --- Glisser-déposer ---

func can_drop_on(zone: String, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("src"):
		return false
	return (zone == "shop" and data["src"] == "inv") or (zone == "inv" and data["src"] == "shop")


func drop_on(zone: String, data: Dictionary) -> void:
	if zone == "shop":
		act_sell(int(data["index"]))
	else:
		act_buy(int(data["index"]))


## Achat / vente demandés par un geste : le refus s'affiche en rouge dans le pied de l'écran.
func act_buy(index: int) -> bool:
	var ok: bool = Game.buy_item(index)
	if ok:
		Sfx.play("buy")
	else:
		_say(Game.shop_error, false)
	return ok


func act_sell(index: int) -> bool:
	var ok: bool = Game.sell_item(index)
	if ok:
		Sfx.play("sell")
	else:
		_say(Game.shop_error, false)
	return ok


## Panneau qui accepte l'objet venu de l'autre panneau (vente ou achat).
class DropZone extends PanelContainer:
	var screen: MarketScreen
	var zone: String = ""

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return screen != null and screen.can_drop_on(zone, data)

	func _drop_data(_at: Vector2, data: Variant) -> void:
		screen.drop_on(zone, data)


## Petite pièce dorée dessinée par code (pas d'image).
class CoinIcon extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(26, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.46
		draw_circle(c + Vector2(0, 1), r, Color(0, 0, 0, 0.5))
		draw_circle(c, r, Color("8a5f12"))
		draw_circle(c, r * 0.78, Color("e4b43c"))
		draw_arc(c, r * 0.55, 0.0, TAU, 20, Color("a8741a"), 1.5)
