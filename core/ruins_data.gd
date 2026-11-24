class_name RuinsData
extends RefCounted
## Données des explorations de ruines (voir core/ruins.gd) : thèmes, textes d'étape, tables de trouvailles.

## `fac` : faction des occupants (clé de Contracts.foes_for) ; `stages` : nombre de combats enchaînés (2 ou 3) ;
## `night_from` : premier niveau (0, 1, 2…) qui se joue de nuit (couloirs sombres, torches) ; `intro` : texte d'entrée ;
## `levels` : nom de chaque niveau ; `descend` : texte quand on avance ; `chest` : texte du coffre.
const THEMES: Dictionary = {
	"crypte": {
		"n": "Crypte oubliée", "fac": "u", "stages": 3, "night_from": 1, "min_renown": 0, "biome": "plain",
		"intro": "Sous les pierres écroulées, un escalier descend vers une crypte. L'air y est froid, et des os craquent dans le noir.",
		"levels": ["Le narthex effondré", "Les galeries des tombes", "La chambre du gardien"],
		"descend": ["Un escalier humide s'enfonce plus bas.", "Un couloir de niches funéraires mène à une porte de bronze."],
		"chest": "Au fond de la chambre, un coffre de fer repose sur un sarcophage.",
	},
	"fortin": {
		"n": "Fortin en ruine", "fac": "b", "stages": 2, "night_from": 9, "min_renown": 0, "biome": "hills",
		"intro": "Un vieux fortin dont les remparts s'écroulent. Des feux de camp récents noircissent la cour : on y a élu domicile.",
		"levels": ["La cour d'armes", "Le donjon éventré"],
		"descend": ["Une porte vermoulue donne sur le donjon."],
		"chest": "Dans la salle du capitaine, un coffre a échappé aux pillards.",
	},
	"temple": {
		"n": "Temple écroulé", "fac": "g", "stages": 3, "night_from": 1, "min_renown": 60, "biome": "forest",
		"intro": "Les racines ont avalé un temple. Quelque chose s'y est installé : on entend gratter sous les dalles.",
		"levels": ["Le parvis envahi", "La nef aux racines", "Le sanctuaire souterrain"],
		"descend": ["Les dalles du chœur ont cédé : un trou mène plus bas.", "Un passage étroit s'ouvre derrière l'autel."],
		"chest": "Sous l'autel, un reliquaire oublié luit dans la poussière.",
	},
	"citadelle": {
		"n": "Citadelle orque", "fac": "o", "stages": 3, "night_from": 2, "min_renown": 350, "biome": "hills",
		"intro": "Les murs d'une forteresse ancienne ont été rafistolés de palissades et de crânes. Les orcs y gardent un butin.",
		"levels": ["Les palissades", "La salle des trophées", "Le repaire du chef"],
		"descend": ["Une herse levée laisse passer vers l'intérieur.", "Un escalier en colimaçon monte vers la tour."],
		"chest": "Le coffre du chef de guerre, hérissé de pointes, est ouvert d'un coup de hache.",
	},
}
const ORDER: Array = ["crypte", "fortin", "temple", "citadelle"]

## Fouille d'un niveau : tirage pondéré (w). `kind` : gold | item | trap | ambush | nothing.
const SEARCH: Array = [
	{"w": 3, "kind": "gold", "text": "Sous des gravats, une bourse moisie : quelques couronnes."},
	{"w": 3, "kind": "item", "text": "Un râtelier oublié porte une pièce d'équipement encore bonne."},
	{"w": 2, "kind": "trap", "text": "Un piège à pression ! Une dalle s'abaisse et des pointes jaillissent."},
	{"w": 1, "kind": "ambush", "text": "Le bruit attire des occupants : ils fondent sur vous !"},
	{"w": 2, "kind": "nothing", "text": "On retourne chaque pierre. Rien, sinon de la poussière."},
]

## En avançant (un niveau plus bas) : chance de piège.
const ADVANCE_TRAP_CHANCE: float = 0.25
const TRAP_TEXTS: Array = [
	"Une dalle bascule : un homme chute et se meurtrit.",
	"Une volée de fléchettes rouillées jaillit d'un mur.",
	"Le plafond lâche quelques blocs sur la colonne.",
]

## Indices d'histoire cachés dans le coffre final (un par exploration).
const CLUES: Array = [
	"Un carnet moisi décrit une bête qui hante encore la région : un nom y est souligné trois fois.",
	"Une carte à demi effacée marque des repères que seuls les anciens du pays reconnaîtraient.",
	"Une lettre scellée promet une récompense à qui rapportera « ce qui dort sous la colline ».",
	"Un journal de fouilleur s'achève sur ces mots : « Ils sont tous remontés, sauf lui. »",
]
