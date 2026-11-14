class_name Handedness
extends RefCounted
## Une main contre deux mains. `Data.WPN[..]["h1"] == false` = deux mains (donc pas de bouclier ; la règle est dans Loot.can_equip / Inventory).
## Une arme de mêlée à deux mains coûte plus de fatigue par attaque mais frappe un peu plus fort, et ses capacités sont plus puissantes ;
## une arme à une main garde la possibilité du bouclier (défense en plus). Les armes de tir et les armes de monstres (prix 0) sont exclues
## des bonus (un arc se tient forcément à deux mains), mais portent quand même l'étiquette « Deux mains ».
## Champs facultatifs d'une arme : `th_fat` (fatigue en plus), `th_dmg` (multiplicateur de dégâts), `th_ab` (multiplicateur des capacités).

const LABEL_TWO: String = "Deux mains"
const LABEL_ONE: String = "Une main"
const FAT_EXTRA: int = 2
const DMG_MULT: float = 1.06
const ABILITY_DMG_MULT: float = 1.12


## Arme tenue à deux mains (étiquette).
static func is_two_handed(key: String) -> bool:
	var w: Dictionary = Data.WPN.get(key, {})
	return not w.is_empty() and not bool(w["h1"]) and int(w.get("price", 0)) > 0


## L'arme reçoit-elle les bonus/malus des deux mains ? (mêlée seulement)
static func has_bonus(key: String) -> bool:
	return is_two_handed(key) and not bool(Data.WPN[key]["ranged"])


static func label(key: String) -> String:
	return LABEL_TWO if is_two_handed(key) else LABEL_ONE


static func fat_extra(key: String) -> int:
	return int(Data.WPN[key].get("th_fat", FAT_EXTRA)) if has_bonus(key) else 0


static func dmg_mult(key: String) -> float:
	return float(Data.WPN[key].get("th_dmg", DMG_MULT)) if has_bonus(key) else 1.0


## Multiplicateur appliqué aux dégâts d'une capacité (multiplicateur `dmg` > 0 seulement : le coup de bouclier, qui ne blesse pas, ne change pas).
static func ability_mult(key: String) -> float:
	return float(Data.WPN[key].get("th_ab", ABILITY_DMG_MULT)) if has_bonus(key) else 1.0
