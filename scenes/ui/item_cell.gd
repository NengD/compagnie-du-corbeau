class_name ItemCell
extends Control
## Case d'objet façon grille d'inventaire : fond en creux, icône, prix, quantité, durabilité, cadre de rareté.
## Tout est dessiné dans `_draw` (aucun nœud enfant, textures partagées) : ~200 cases restent fluides ; un redessin n'a lieu
## que si l'objet, les options ou l'état (survol, sélection) changent.
##
## Contrat : ItemCell.new(); set_item(item, opts); set_empty(slot_kind); signaux pressed / double_clicked / right_clicked /
## hovered(item) ; callables facultatifs drag_data_provider, drop_handler (+ can_drop_handler), tooltip_provider.
## opts : "price" int, "qty" int (affiché si > 1), "durability" float 0..1, "size" int (défaut 64), "selected" bool,
## "locked" bool, "slot_label" String (head, body, weapon, shield, bag, tool : silhouette fantôme si la case est vide).

signal pressed
signal double_clicked
signal right_clicked
signal hovered(item: Dictionary)

const GHOSTS: Dictionary = {
	"head": ["head", "casque"], "body": ["body", "gambison"], "weapon": ["weapon", "epee"], "shield": ["shield", ""],
	"bag": ["food", "ration"], "tool": ["tool", "pierre"],
}
const BG := Color("14100c")
const BG_HI := Color("241c13")
const EDGE := Color("3a2f22")
const GOLD := Color("e0b44a")
const COIN := Color("e4b43c")
const COIN_RIM := Color("8a5f12")
const TEXT := Color("f1e6c8")
const DUR_GOOD := Color("8fd04f")
const DUR_MID := Color("e8a23a")
const DUR_LOW := Color("e5563f")

var item: Dictionary = {}
var drag_data_provider: Callable = Callable()
var drop_handler: Callable = Callable()
var can_drop_handler: Callable = Callable()  ## facultatif : func(data) -> bool ; sinon toute valeur est acceptée si drop_handler est valide
var tooltip_provider: Callable = Callable()

var _opts: Dictionary = {}
var _slot: String = ""
var _hover: bool = false
var _icon: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(64, 64)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


## Affiche un objet ({kind, key, …} ou entrée de boutique) avec les options décrites en tête de fichier.
func set_item(new_item: Dictionary, opts: Dictionary = {}) -> void:
	item = new_item
	_opts = opts
	_slot = str(opts.get("slot_label", ""))
	_icon = ItemIcons.get_icon_for_item(item) if not item.is_empty() else null
	_apply_size()
	queue_redraw()


## Case vide ; `slot_kind` (head, body, weapon, shield, bag, tool) dessine une silhouette fantôme discrète.
func set_empty(slot_kind: String = "") -> void:
	item = {}
	_opts = {}
	_slot = slot_kind
	_icon = null
	_apply_size()
	queue_redraw()


## Change seulement la sélection (sans reconstruire la case).
func set_selected(on: bool) -> void:
	if bool(_opts.get("selected", false)) != on:
		_opts["selected"] = on
		queue_redraw()


func is_empty() -> bool:
	return item.is_empty()


func _apply_size() -> void:
	var s: int = int(_opts.get("size", 64))
	custom_minimum_size = Vector2(s, s)


func _on_enter() -> void:
	_hover = true
	queue_redraw()
	hovered.emit(item)


func _on_exit() -> void:
	_hover = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				double_clicked.emit()
			else:
				pressed.emit()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit()


func _get_tooltip(_at: Vector2) -> String:
	return str(tooltip_provider.call()) if tooltip_provider.is_valid() else ""


func _get_drag_data(_at: Vector2) -> Variant:
	if not drag_data_provider.is_valid() or item.is_empty() or bool(_opts.get("locked", false)):
		return null
	var data: Variant = drag_data_provider.call()
	if data == null:
		return null
	var prev := TextureRect.new()
	prev.texture = _icon
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.custom_minimum_size = size
	prev.size = size
	prev.modulate = Color(1, 1, 1, 0.85)
	prev.position = -size * 0.5
	var holder := Control.new()
	holder.add_child(prev)
	set_drag_preview(holder)
	return data


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not drop_handler.is_valid() or bool(_opts.get("locked", false)):
		return false
	if can_drop_handler.is_valid():
		return bool(can_drop_handler.call(data))
	return true


func _drop_data(_at: Vector2, data: Variant) -> void:
	if drop_handler.is_valid():
		drop_handler.call(data)


# --- Dessin ---

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var r := Rect2(Vector2.ZERO, size)
	var selected: bool = bool(_opts.get("selected", false))
	var illustrated: bool = GameTheme.illustrated()
	var rarity: String = ItemIcons.rarity(item) if not item.is_empty() else "common"
	var tint: Color = ItemIcons.quality_tint(item) if not item.is_empty() else EDGE
	# fond en creux
	draw_rect(r, BG, true)
	if illustrated:
		var col_top := Color(0, 0, 0, 0.55)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.22), Vector2(0, h * 0.22)]),
			PackedColorArray([col_top, col_top, Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		var hi := Color(1, 0.9, 0.7, 0.07)
		draw_polygon(PackedVector2Array([Vector2(0, h * 0.5), Vector2(w, h * 0.5), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), hi, hi]))
	if rarity == "unique":
		draw_rect(r.grow(-2), Color(0.88, 0.67, 0.18, 0.13), true)
	elif rarity == "quality":
		draw_rect(r.grow(-2), Color(0.5, 0.7, 0.3, 0.08), true)
	var fs: int = clampi(roundi(w * 0.19), 10, 22)
	if item.is_empty():
		_draw_ghost()
	else:
		_draw_icon()
		_draw_labels(w, h, fs)
	if illustrated:  # léger reflet de coin
		draw_line(Vector2(2, 1.5), Vector2(w - 2, 1.5), Color(1, 0.92, 0.75, 0.10), 1.0)
	# liseré : rareté, survol, sélection
	var edge: Color = tint if not item.is_empty() and rarity != "common" else EDGE
	var bw: float = 2.0 if rarity != "common" and not item.is_empty() else 1.0
	if _hover:
		edge = GOLD.lerp(edge, 0.25)
		draw_rect(r, Color(1, 0.9, 0.55, 0.08), true)
	if selected:
		edge = GOLD
		bw = 2.0
		draw_rect(r, Color(1, 0.85, 0.4, 0.14), true)
	draw_rect(r.grow(-bw * 0.5), edge, false, bw)
	if bool(_opts.get("locked", false)):
		draw_rect(r, Color(0, 0, 0, 0.5), true)
		_draw_lock(w, h)


func _draw_icon() -> void:
	if _icon == null:
		return
	var pad: float = size.x * 0.07
	var box := Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)
	var mod := Color(1, 1, 1, 0.45) if bool(_opts.get("locked", false)) else Color.WHITE
	draw_texture_rect(_icon, box, false, mod)


func _draw_ghost() -> void:
	if not GHOSTS.has(_slot):
		return
	var g: Array = GHOSTS[_slot]
	var tex: Texture2D = ItemIcons.get_icon(str(g[0]), str(g[1]))
	if tex == null:
		return
	var pad: float = size.x * 0.16
	draw_texture_rect(tex, Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0), false, Color(0.55, 0.5, 0.42, 0.16))


func _draw_labels(w: float, h: float, fs: int) -> void:
	var font: Font = GameTheme.bold_font()
	var price: int = int(_opts.get("price", -1))
	var qty: int = int(_opts.get("qty", 0))
	var base_y: float = h - 3.0
	if price >= 0:
		var cr: float = fs * 0.36
		var cx: float = 4.0 + cr
		var cy: float = base_y - fs * 0.34
		draw_circle(Vector2(cx, cy), cr + 1.0, Color(0, 0, 0, 0.6))
		draw_circle(Vector2(cx, cy), cr, COIN_RIM)
		draw_circle(Vector2(cx, cy), cr * 0.72, COIN)
		_text(font, Vector2(cx + cr + 3.0, base_y), _fmt(price), HORIZONTAL_ALIGNMENT_LEFT, fs, GOLD.lerp(TEXT, 0.4))
	if _opts.has("durability"):
		var d: float = clampf(float(_opts["durability"]), 0.0, 1.0)
		var col: Color = DUR_GOOD if d >= 0.6 else (DUR_MID if d >= 0.3 else DUR_LOW)
		var y: float = base_y - (fs + 1.0 if price >= 0 else 0.0)
		_text(font, Vector2(2.0, y), "%d %%" % roundi(d * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, fs - 1, col, w - 5.0)
	if qty > 1:
		_text(font, Vector2(2.0, fs + 2.0), str(qty), HORIZONTAL_ALIGNMENT_RIGHT, fs, TEXT, w - 5.0)


func _text(font: Font, pos: Vector2, s: String, align: HorizontalAlignment, fs: int, col: Color, width: float = -1.0) -> void:
	draw_string_outline(font, pos, s, align, width, fs, maxi(3, fs / 3), Color(0.04, 0.03, 0.02, 0.95))
	draw_string(font, pos, s, align, width, fs, col)


func _draw_lock(w: float, h: float) -> void:
	var s: float = minf(w, h) * 0.16
	var c := Vector2(w * 0.5, h * 0.5)
	draw_rect(Rect2(c - Vector2(s, 0.0), Vector2(s * 2.0, s * 1.4)), Color(0.8, 0.7, 0.45, 0.9), true)
	draw_arc(c + Vector2(0, 0), s * 0.7, PI, TAU, 12, Color(0.8, 0.7, 0.45, 0.9), maxf(2.0, s * 0.25))


## 12345 -> « 12 345 » (espace insécable fine).
static func _fmt(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	var i: int = s.length()
	while i > 3:
		out = " " + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if n < 0 else "") + out
