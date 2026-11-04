class_name Uniques
extends RefCounted
## Objets uniques (Data.UNIQUES) : armes et armures nommées aux statistiques fixes. Leurs statistiques vivent dans
## Data.WPN / HEAD / BODY sous la même clé ; ce fichier gère l'emprunt de sprite et le tirage. Logique pure.


static func is_unique(key: String) -> bool:
	return Data.UNIQUES.has(key)


## Clé de l'objet ordinaire dont on emprunte l'apparence (la clé elle-même pour un objet ordinaire).
static func look(key: String) -> String:
	return str(Data.UNIQUES[key]["look"]) if Data.UNIQUES.has(key) else key


## Nom de calque d'une figurine : « weapon_u_epee_corbeau » -> « weapon_epee » (inchangé si rien à remplacer).
static func alias_layer(layer_name: String) -> String:
	for k in Data.UNIQUES:
		var suffix: String = "_" + str(k)
		if layer_name.ends_with(suffix):
			return layer_name.trim_suffix(suffix) + "_" + str(Data.UNIQUES[k]["look"])
	return layer_name


## Objet de l'inventaire correspondant à une clé unique.
static func item_of(key: String) -> Dictionary:
	return Loot.item(str(Data.UNIQUES[key]["kind"]), key)


## Clés d'uniques pas encore sorties (`taken` : clés déjà données au joueur durant la partie), dans l'ordre des données.
static func available(taken: Array) -> Array:
	var out: Array = []
	for k in Data.UNIQUES:
		if not taken.has(k):
			out.append(str(k))
	return out


static func story(key: String) -> String:
	return str(Data.UNIQUES.get(key, {}).get("story", ""))


## Prix d'un unique chez le marchand rare (coefficient sur le prix de base).
const RARE_MARKUP: float = 1.25


static func rare_price(key: String) -> int:
	return int(round(Loot.base_price(item_of(key)) * RARE_MARKUP / 10.0)) * 10
