class_name Shields
extends RefCounted
## Types de boucliers. `Unit.shield` reste un booléen (« porte un bouclier ») ; le TYPE est `Unit.shield_kind` (défaut « rondache »).
## Un objet d'inventaire de genre "shield" porte son type dans "key" ("" = rondache : anciennes sauvegardes et butin d'avant).
## `mdef` / `rdef` : défense contre la mêlée / les tirs quand le bouclier est utilisable ; `wall` : bonus du mur de boucliers.
## La rondache reprend exactement Data.SHIELD (15 / 25, mur 20) : un test vérifie la cohérence.

const DEFAULT: String = "rondache"
const ORDER: Array[String] = ["targe", "rondache", "pavois"]

const KINDS: Dictionary = {
	"rondache": {"n": "Bouclier rond", "price": 120, "w": 4, "dur": 40, "mdef": 15, "rdef": 25, "wall": 20,
		"note": "Le bouclier de la compagnie : équilibré."},
	"targe": {"n": "Targe légère", "price": 70, "w": 2, "dur": 28, "mdef": 12, "rdef": 14, "wall": 14,
		"note": "Légère et peu fatigante, mais elle protège peu des tirs."},
	"pavois": {"n": "Pavois", "price": 260, "w": 9, "dur": 70, "mdef": 18, "rdef": 40, "wall": 28,
		"note": "Grand écu lourd : une vraie muraille contre les flèches et un mur de boucliers redoutable."},
}


static func normalize(kind: Variant) -> String:
	var k: String = str(kind)
	return k if KINDS.has(k) else DEFAULT


## Clé d'un objet d'inventaire pour ce type ("" pour la rondache : identique à l'ancien format des objets et des sauvegardes).
static func item_key(kind: Variant) -> String:
	var k: String = normalize(kind)
	return "" if k == DEFAULT else k


static func data(kind: Variant) -> Dictionary:
	return KINDS[normalize(kind)]


static func label(kind: Variant) -> String:
	return str(data(kind)["n"])


## Ligne de description (défenses, poids) pour les infobulles.
static func stat_line(kind: Variant) -> String:
	var d: Dictionary = data(kind)
	return "Défense mêlée +%d, distance +%d · mur de boucliers +%d · poids %d" % [d["mdef"], d["rdef"], d["wall"], d["w"]]
