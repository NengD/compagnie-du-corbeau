class_name RegionLook
extends RefCounted
## Ambiance visuelle d'un plateau de bataille, déduite du biome du contrat et de la faction qui tient la région (logique pure,
## déterministe). Elle ne change ni les cases franchissables ni les règles : c'est un décor de fond (voir scenes/battle/region_decor.gd).

const KINDS: Array[String] = ["meadow", "farmland", "dense_forest", "marsh", "snow", "ruins", "bridge", "rocky", "desert", "heath"]

## Décor de chaque ambiance (clés lues par RegionDecor) et teinte de sol appliquée par-dessus l'herbe (alpha = force).
const SPECS: Dictionary = {
	"meadow": {"n": "Prairie", "wash": Color(0.5, 0.62, 0.3, 0.0), "features": ["flowers", "tufts", "boulders"]},
	"farmland": {"n": "Plaine cultivée", "wash": Color(0.72, 0.62, 0.3, 0.12), "features": ["furrows", "farm", "fences", "hay"]},
	"dense_forest": {"n": "Forêt dense", "wash": Color(0.12, 0.26, 0.12, 0.2), "features": ["litter", "moss", "treeline"]},
	"marsh": {"n": "Marais", "wash": Color(0.22, 0.3, 0.2, 0.26), "features": ["puddles", "reeds", "deadwood"]},
	"snow": {"n": "Terres gelées", "wash": Color(0.86, 0.9, 0.94, 0.5), "features": ["snow_patches", "frost", "pines"]},
	"ruins": {"n": "Ruines", "wash": Color(0.3, 0.3, 0.28, 0.16), "features": ["rubble", "cracks", "ruin_walls", "graves"]},
	"bridge": {"n": "Pont et rivière", "wash": Color(0.3, 0.45, 0.5, 0.1), "features": ["puddles", "bridge", "reeds"]},
	"rocky": {"n": "Roche et éboulis", "wash": Color(0.5, 0.48, 0.42, 0.2), "features": ["pebbles", "lichen", "boulders"]},
	"desert": {"n": "Désert de roche", "wash": Color(0.82, 0.68, 0.42, 0.42), "features": ["ripples", "pebbles", "mesas"]},
	"heath": {"n": "Lande", "wash": Color(0.5, 0.36, 0.5, 0.12), "features": ["heather", "tufts", "standing_stones"]},
}


## Ambiance pour un biome ("plain" | "forest" | "hills" | "water"), un propriétaire de région (clé de Data.FACTIONS, "" = terres sauvages),
## le type d'ennemis du contrat ("b", "g", "o", "u", "m") et une graine (variante). Toujours une ambiance valide.
static func derive(biome: String, owner: String, foe_type: String = "b", seed_value: int = 0) -> Dictionary:
	var kind: String = _kind(biome, owner, foe_type)
	var spec: Dictionary = SPECS[kind]
	return {"kind": kind, "name": str(spec["n"]), "biome": biome, "owner": owner, "variant": absi(seed_value) % 3,
		"features": (spec["features"] as Array).duplicate(), "wash": spec["wash"], "seed": absi(seed_value)}


static func _kind(biome: String, owner: String, foe_type: String) -> String:
	match owner:
		"givre":
			return "snow"
		"sablefer":
			return "desert" if biome != "water" else "bridge"
	if foe_type == "u" and (biome == "plain" or biome == "hills"):
		return "ruins"
	if owner == "abbaye" and biome == "plain":
		return "ruins"
	match biome:
		"water":
			return "bridge" if (owner == "lys" or owner == "roncevaux" or owner == "marches") else "marsh"
		"forest":
			return "dense_forest"
		"hills":
			return "heath" if owner == "marches" else "rocky"
		_:
			if owner == "lys" or owner == "roncevaux":
				return "farmland"
			if owner == "marches":
				return "heath"
			return "meadow"


## Ambiance d'une bataille : `contract` (clés "biome", "origin_id", "type") ; `owner` est celui du lieu d'origine (déjà résolu par l'appelant).
static func for_battle(contract: Dictionary, biome: String, owner: String, seed_value: int) -> Dictionary:
	return derive(biome, owner, str(contract.get("type", "b")), seed_value)


static func has_feature(look: Dictionary, feature: String) -> bool:
	return (look.get("features", []) as Array).has(feature)
