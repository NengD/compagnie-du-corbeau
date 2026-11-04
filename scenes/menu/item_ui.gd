class_name ItemUi
extends RefCounted
## Affichage d'un objet de l'inventaire (icône facultative + nom + description).

const ICONS_PATH: String = "res://scenes/ui/item_icons.gd"
static var _icons: Object = null
static var _icons_checked: bool = false


## Icône fournie par ItemIcons (session ressources) si elle existe, sinon null.
static func icon(it: Dictionary) -> Texture2D:
	if not _icons_checked:
		_icons_checked = true
		if ResourceLoader.exists(ICONS_PATH):
			_icons = load(ICONS_PATH)
	if _icons == null or not _icons.has_method("get_icon"):
		return null
	return _icons.call("get_icon", str(it["kind"]), str(it["key"])) as Texture2D


static func row(it: Dictionary, with_desc: bool = true) -> HBoxContainer:
	var h := UiKit.hbox(8)
	var tex: Texture2D = icon(it)
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(32, 32)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(r)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label(Loot.item_name(it), 15, GameTheme.INK, true))
	if with_desc:
		v.add_child(UiKit.sub(Loot.describe(it)))
	h.add_child(v)
	return h
