class_name MaterialsData
extends RefCounted
## Tables des matériaux d'armure et matrice « type de dégât × matériau » (lues par core/materials.gd et core/damage_types.gd).
##
## Principe : le type de dégât d'une arme (tranchant, contondant ou perforant : `Data.WEAPON_FAMILIES[...]["dmg_type"]`, ou un champ
## `dmg_type` de l'arme) rencontre le matériau de la pièce d'armure touchée. La matrice donne deux multiplicateurs :
##   "arm" : multiplie l'efficacité de l'arme contre l'armure (dégâts retirés à la barre d'armure) ;
##   "ign" : multiplie la part des dégâts qui traverse l'armure (dégâts directs aux PV).
## Chaque multiplicateur reste dans [MULT_MIN, MULT_MAX] : l'effet est un infléchissement, jamais un bouleversement.
## Un type inconnu ou vide (griffes sans type, arme future sans famille) et un matériau inconnu sont NEUTRES (×1, ×1).
##
## Lecture de la matrice (ligne = matériau) :
##   tissu       : référence (la lame passe comme dans les règles du prototype) ; le choc s'y amortit un peu, la pointe passe un peu mieux.
##   cuir        : neutre partout, la pointe s'y enfonce un peu plus.
##   cuir_cloute : un peu plus dur à la lame et à la pointe.
##   matelasse   : amortit lames et pointes, mais le contondant y fait des dégâts profonds (le rembourrage ne protège pas des os).
##   mailles     : résistent bien au tranchant ; la pointe s'insinue entre les maillons ; le contondant écrase les anneaux.
##   ecailles    : bonne tenue au tranchant, tenue correcte à la pointe, neutre contre le choc.
##   plates      : arrêtent bien la pointe et un peu la lame ; le contondant les bosse et fait passer le choc.

const MULT_MIN: float = 0.75
const MULT_MAX: float = 1.25

const TYPES: Array[String] = ["tranchant", "contondant", "perforant"]
const TYPE_NAMES: Dictionary = {"tranchant": "Tranchant", "contondant": "Contondant", "perforant": "Perforant"}

const MATERIAL_NAMES: Dictionary = {
	"nu": "Rien", "tissu": "Tissu", "cuir": "Cuir", "cuir_cloute": "Cuir clouté", "matelasse": "Matelassé",
	"mailles": "Mailles", "ecailles": "Écailles", "plates": "Plates",
}

## MATRIX[matériau][type] = {"arm": ×, "ign": ×}
const MATRIX: Dictionary = {
	"tissu": {
		"tranchant": {"arm": 1.0, "ign": 1.0},
		"contondant": {"arm": 0.95, "ign": 0.95},
		"perforant": {"arm": 1.0, "ign": 1.05},
	},
	"cuir": {
		"tranchant": {"arm": 1.0, "ign": 1.0},
		"contondant": {"arm": 1.0, "ign": 1.0},
		"perforant": {"arm": 1.05, "ign": 1.0},
	},
	"cuir_cloute": {
		"tranchant": {"arm": 0.95, "ign": 0.95},
		"contondant": {"arm": 1.0, "ign": 1.0},
		"perforant": {"arm": 1.0, "ign": 0.95},
	},
	"matelasse": {
		"tranchant": {"arm": 1.0, "ign": 1.0},
		"contondant": {"arm": 1.08, "ign": 1.08},
		"perforant": {"arm": 0.95, "ign": 1.0},
	},
	"mailles": {
		"tranchant": {"arm": 0.85, "ign": 0.9},
		"contondant": {"arm": 1.05, "ign": 1.0},
		"perforant": {"arm": 1.0, "ign": 1.15},
	},
	"ecailles": {
		"tranchant": {"arm": 0.9, "ign": 0.9},
		"contondant": {"arm": 1.0, "ign": 1.0},
		"perforant": {"arm": 0.95, "ign": 1.0},
	},
	"plates": {
		"tranchant": {"arm": 0.95, "ign": 0.95},
		"contondant": {"arm": 1.1, "ign": 1.1},
		"perforant": {"arm": 0.85, "ign": 0.9},
	},
}

## Matériau des pièces actuelles par clé (Data.HEAD / Data.BODY). Un champ `"mat"` dans l'entrée de Data l'emporte sur cette table ;
## pour une clé inconnue des deux, `Materials.of` déduit le matériau de la valeur d'armure (voir DEFAULT_BY_ARMOR).
const HEAD_MATERIAL: Dictionary = {
	"capuchon": "tissu", "casque": "plates", "heaume": "plates", "u_casque_loup": "plates", "u_heaume_veilleur": "plates",
	"cagoule_cuir": "cuir_cloute", "barbute": "plates", "heaume_crete": "plates", "casque_orque": "plates", "casque_rouille": "plates",
}
const BODY_MATERIAL: Dictionary = {
	"tunique": "tissu", "gambison": "matelasse", "mailles": "mailles", "brigandine": "ecailles",
	"u_cotte_nuit": "mailles", "u_brigandine_roi": "plates",
	"cuir_cloute": "cuir_cloute", "haubert_surcot": "mailles", "cuirasse_peaux": "cuir", "plastron_orque": "plates", "cotte_rouillee": "mailles",
}

## Repli par valeur d'armure max (seuil inclusif -> matériau), pour une pièce nouvelle sans `mat` ni entrée de table.
const DEFAULT_BY_ARMOR: Array = [[35, "tissu"], [80, "matelasse"], [145, "mailles"], [185, "ecailles"], [100000, "plates"]]

## Type de dégât des armes sans famille (monstres) et des armes dont ni `dmg_type` ni la famille ne le disent.
const WEAPON_TYPE_FALLBACK: Dictionary = {"griffes": "tranchant", "griffesL": "tranchant", "morsure": "perforant", "massue_geant": "contondant"}
