class_name InvSlot
extends Control
## Une case d'inventaire : emplacement d'un homme (tête, corps, mains, sac) ou case de la réserve.
## Glisser-déposer natif de Godot ; toute la logique vit dans InventoryScreen / core/inventory.gd.

var screen: InventoryScreen
var loc: Dictionary = {}  ## voir Inventory.at / Inventory.in_stash
var item: Dictionary = {}  ## objet contenu ({} = vide)
var caption: String = ""  ## nom de l'emplacement (affiché quand il est vide)
var _hover: bool = false
var _drop: int = 0  ## 0 neutre, 1 dépôt possible, -1 dépôt refusé


func _init(p_screen: InventoryScreen = null, p_loc: Dictionary = {}, p_item: Dictionary = {}, p_caption: String = "", px: int = 64) -> void:
	screen = p_screen
	loc = p_loc
	item = p_item
	caption = p_caption
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not item.is_empty() and screen != null:
		tooltip_text = Inventory.tooltip(item, screen.sell_value(loc))
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw()
		if screen != null:
			screen.hover(self))
	mouse_exited.connect(func() -> void:
		_hover = false
		_drop = 0
		queue_redraw()
		if screen != null:
			screen.hover(null))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drop = 0
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var border: Color = GameTheme.LINE
	if not item.is_empty() and Uniques.is_unique(str(item["key"])):
		border = GameTheme.GOLD.darkened(0.25)
	if _drop == 1:
		border = GameTheme.GOOD
	elif _drop == -1:
		border = GameTheme.BLOOD
	elif _hover:
		border = GameTheme.GOLD
	draw_rect(r, GameTheme.PANEL2 if not item.is_empty() else GameTheme.BG)
	draw_rect(r, border, false, 2.0 if (_hover or _drop != 0) else 1.0)
	var font: Font = GameTheme.bold_font()
	if item.is_empty():
		if caption != "":
			var w: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2((size.x - w) * 0.5, size.y * 0.5 + 4.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GameTheme.MUTE.darkened(0.35))
		return
	var tex: Texture2D = ItemUi.icon(item)
	if tex != null:
		var m: float = 6.0
		draw_texture_rect(tex, Rect2(m, m, size.x - 2.0 * m, size.y - 2.0 * m - 4.0), false, Color(0.92, 0.88, 0.78))
	else:
		var nm: String = Loot.item_name(item)
		draw_string(font, Vector2(4.0, size.y * 0.5), nm.substr(0, 9), HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 11, GameTheme.INK)
	var ratio: float = Loot.wear_ratio(item)
	if ratio < 1.0:  # barre d'usure / d'armure abîmée
		var bar := Rect2(4.0, size.y - 6.0, size.x - 8.0, 3.0)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), GameTheme.GOOD.lerp(GameTheme.BLOOD, 1.0 - ratio))


func _get_drag_data(_at: Vector2) -> Variant:
	if item.is_empty() or screen == null or not screen.editable():
		return null
	var prev := TextureRect.new()
	prev.texture = ItemUi.icon(item)
	prev.custom_minimum_size = Vector2(48, 48)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(prev)
	return {"loc": loc, "item": item}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("loc") and screen != null and screen.can_drop(data["loc"], loc)
	_drop = 1 if ok else -1
	queue_redraw()
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	_drop = 0
	queue_redraw()
	screen.drop(data["loc"], loc)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or item.is_empty():
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
		screen.quick(loc)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		screen.show_menu(loc, mb.global_position)
		accept_event()
