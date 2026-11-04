class_name CampBuildings
extends RefCounted
## Bâtiments du camp de la compagnie (Data.CAMP_BUILDINGS) : niveaux 0 (absent) à 3, achetés avec de l'or.
## Logique pure : `levels` est le dictionnaire {clé: niveau} que `Game.buildings` conserve.

const MAX_LEVEL: int = 3


## Dictionnaire de niveaux lu dans une sauvegarde : seules les clés connues, niveaux bornés.
static func normalize(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:  # l'ordre des clés de la sauvegarde est conservé
			if not Data.CAMP_BUILDINGS.has(str(k)):
				continue
			var lv: int = clampi(int(raw[k]), 0, MAX_LEVEL)
			if lv > 0:
				out[str(k)] = lv
	return out


static func level_of(levels: Dictionary, key: String) -> int:
	return int(levels.get(key, 0))


## Prix du niveau suivant, ou -1 si le bâtiment est au maximum.
static func next_cost(levels: Dictionary, key: String) -> int:
	var lv: int = level_of(levels, key)
	if lv >= MAX_LEVEL or not Data.CAMP_BUILDINGS.has(key):
		return -1
	return int(Data.CAMP_BUILDINGS[key]["costs"][lv])


## Valeur de l'effet `fx` du bâtiment `key` à son niveau actuel (`default` s'il n'est pas construit).
static func value(levels: Dictionary, key: String, fx: String, default: float = 0.0) -> float:
	var lv: int = level_of(levels, key)
	if lv <= 0 or not Data.CAMP_BUILDINGS.has(key):
		return default
	return float(Data.CAMP_BUILDINGS[key]["fx"][fx][lv - 1])


## Valeur de l'effet à un niveau donné (affichage de l'effet actuel / suivant).
static func value_at(key: String, fx: String, lv: int, default: float = 0.0) -> float:
	if lv <= 0:
		return default
	return float(Data.CAMP_BUILDINGS[key]["fx"][fx][clampi(lv, 1, MAX_LEVEL) - 1])


## Texte de l'effet du bâtiment au niveau `lv` (0 : « aucun effet »).
static func effect_text(key: String, lv: int) -> String:
	if lv <= 0:
		return "Aucun effet (non construit)."
	match key:
		"forge":
			return "Réparations −%d %%, usure des armes et boucliers −%d %%." % [roundi((1.0 - value_at(key, "repair_mult", lv)) * 100.0), roundi((1.0 - value_at(key, "wear_mult", lv)) * 100.0)]
		"infirmerie":
			return "+%d PV par jour de route, +%d PV au repos, blessures guéries %d jour%s plus vite par jour." % [int(value_at(key, "road_heal", lv)), int(value_at(key, "rest_heal", lv)), int(value_at(key, "injury_days", lv)), "s" if int(value_at(key, "injury_days", lv)) > 1 else ""]
		"cuisine":
			return "Vivres −%d %%, +%s de moral de compagnie par jour de bon repas." % [roundi((1.0 - value_at(key, "food_mult", lv)) * 100.0), str(value_at(key, "meal_morale", lv))]
		"tentes":
			return "+%d homme%s dans la compagnie (jusqu'à %d)." % [int(value_at(key, "roster", lv)), "s" if int(value_at(key, "roster", lv)) > 1 else "", Data.MAX_ROSTER + int(value_at(key, "roster", lv))]
		"entrepot":
			return "+%d emplacements de réserve (%d au total)." % [int(value_at(key, "stash", lv)), Data.STASH_SIZE + int(value_at(key, "stash", lv))]
		"guet":
			return "Rayon de vue sur la carte +%d %%." % roundi(value_at(key, "vision", lv) * 100.0)
		"enseigne":
			return "Renom gagné +%d %%." % roundi(value_at(key, "renown", lv) * 100.0)
	return ""


## Coefficient de réparation (forge).
static func repair_mult(levels: Dictionary) -> float:
	return value(levels, "forge", "repair_mult", 1.0)


## Probabilité qu'un point d'usure compte vraiment (forge) : 1.0 sans forge.
static func wear_mult(levels: Dictionary) -> float:
	return value(levels, "forge", "wear_mult", 1.0)


static func road_heal_bonus(levels: Dictionary) -> int:
	return int(value(levels, "infirmerie", "road_heal"))


static func rest_heal_bonus(levels: Dictionary) -> int:
	return int(value(levels, "infirmerie", "rest_heal"))


static func injury_days_bonus(levels: Dictionary) -> int:
	return int(value(levels, "infirmerie", "injury_days"))


static func food_mult(levels: Dictionary) -> float:
	return value(levels, "cuisine", "food_mult", 1.0)


static func meal_morale(levels: Dictionary) -> float:
	return value(levels, "cuisine", "meal_morale")


static func roster_bonus(levels: Dictionary) -> int:
	return int(value(levels, "tentes", "roster"))


static func stash_bonus(levels: Dictionary) -> int:
	return int(value(levels, "entrepot", "stash"))


static func vision_mult(levels: Dictionary) -> float:
	return 1.0 + value(levels, "guet", "vision")


static func renown_mult(levels: Dictionary) -> float:
	return 1.0 + value(levels, "enseigne", "renown")
