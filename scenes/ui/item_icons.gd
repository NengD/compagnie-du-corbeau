class_name ItemIcons
extends RefCounted
## Icônes d'objets : un fichier par objet dans assets/icons_items/ (voir tools/gen_item_icons.py, crédits dans assets/CREDITS.md).
## `kind` : "weapon" | "head" | "body" | "shield" | "tool" | "food" ; `key` : clé de Data.WPN / HEAD / BODY / TOOLS / FOOD.
## Textures partagées (cache) ; `get_icon_for_item` ne renvoie jamais null (repli : icône « ? »).

const DIR := "res://assets/icons_items/"
const UNKNOWN := "unknown"
const COL_COMMON := Color("6b6254")
const COL_QUALITY := Color("7fae52")
const COL_UNIQUE := Color("e0aa2e")

static var _cache: Dictionary = {}


## Nom de fichier (sans extension) d'un objet, ou "" si le genre est inconnu.
static func file_of(kind: String, key: String) -> String:
	match kind:
		"weapon", "head", "body", "tool", "food":
			return "%s_%s" % [kind, key]
		"shield":
			return "shield_bouclier"
	return ""


static func _load(file: String) -> Texture2D:
	var path := DIR + file + ".svg"
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[path] = tex
	return tex


## Icône d'un objet, ou null si le genre ou la clé n'existe pas (« none » : pas d'objet).
static func get_icon(kind: String, key: String) -> Texture2D:
	if key == "none":
		return null
	var file := file_of(kind, key)
	if file == "":
		return null
	return _load(file)


## Icône « ? » de repli.
static func unknown() -> Texture2D:
	return _load(UNKNOWN)


## Icône d'un objet d'inventaire ({kind, key, …}) ou d'une entrée de boutique ; jamais null.
static func get_icon_for_item(item: Dictionary) -> Texture2D:
	var tex: Texture2D = null
	if item.has("kind"):
		tex = get_icon(str(item["kind"]), str(item.get("key", "")))
	return tex if tex != null else unknown()


## "unique" | "quality" | "common" : rareté d'un objet (unique de Data.UNIQUES, ou clé "quality" > 0 / "q" > 0).
static func rarity(item: Dictionary) -> String:
	if item.has("key") and Data.UNIQUES.has(str(item["key"])):
		return "unique"
	if float(item.get("quality", item.get("q", 0))) > 0.0:
		return "quality"
	return "common"


## Couleur du cadre de rareté : gris commun, vert qualité, or unique.
static func quality_tint(item: Dictionary) -> Color:
	match rarity(item):
		"unique":
			return COL_UNIQUE
		"quality":
			return COL_QUALITY
	return COL_COMMON
