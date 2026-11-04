class_name ItemIcons
extends RefCounted
## Icônes d'objets (game-icons.net, CC-BY 3.0 : voir assets/CREDITS.md).
## `kind` : "weapon" | "head" | "body" | "shield" ; `key` : clé de Data.WPN / HEAD / BODY.

const DIR := "res://assets/icons/"

static var _cache: Dictionary = {}


static func get_icon(kind: String, key: String) -> Texture2D:
	var file: String
	match kind:
		"weapon", "head", "body":
			file = Uniques.look(key)
		"shield":
			file = "bouclier"
		_:
			return null
	if file == "" or file == "none":
		return null
	var path := DIR + file + ".svg"
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[path] = tex
	return tex
