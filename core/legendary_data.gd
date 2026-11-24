class_name LegendaryData
extends RefCounted
## Bêtes légendaires : créatures uniques (une seule de chaque par partie) avec des PHASES. Les statistiques de base sont dans
## Data.FOE (clés « leg_* ») ; ici : légende, phases, butin garanti, lieux de chasse. Logique appliquée par core/legendary.gd.
##
## `phases` : liste ordonnée par seuil de PV décroissant. Chaque phase : `hp` (fraction des PV max à partir de laquelle elle s'applique),
##   `say` (ligne du journal), et des effets : `stat` {attribut: delta}, `ap` (PA en plus à chaque tour), `summon` (clés de Data.FOE appelées en renfort),
##   `regen` (PV rendus par manche, remplace la régénération de base).
## `regen` / `regen_off_if_burned` : régénération de base (PV par manche), coupée si la bête a brûlé dans les 2 dernières manches.
## `pack` : escorte présente dès le début. `loot` : objet unique garanti à la première victoire. `lairs` : sites hostiles qui peuvent l'abriter.
## `scale` : taille de la figurine (1 = normale). `biome` : terrain préféré du combat.

const LEGENDS: Dictionary = {
	"ogre": {
		"foe": "leg_ogre", "title": "Grosse-Mâchoire, l'ogre des marais", "short": "Ogre légendaire",
		"legend": "Un ogre si vieux que les pères racontent sa légende à leurs fils. Il s'enrage quand on le blesse vraiment.",
		"hunt_title": "Chasser la bête des marais de {town}", "hunt_desc": "Un ogre énorme a éventré des charrettes entières. Les paysans parlent de Grosse-Mâchoire, qui ne meurt jamais.",
		"scale": 1.3, "biome": "water", "pack": [], "min_renown": 150,
		"loot": "u_brise_os", "lairs": ["lair"], "danger": 3, "pay": 1500,
		"phases": [
			{"hp": 0.5, "say": "{n} hurle, les yeux injectés de sang : il s'enrage !", "stat": {"melee_skill": 8, "melee_def": -6}, "ap": 3},
			{"hp": 0.25, "say": "{n} est pris de fureur : plus rien ne l'arrête !", "stat": {"initiative": 15}, "ap": 2},
		],
	},
	"troll": {
		"foe": "leg_troll", "title": "Écorche-Gué, le troll qui se relève", "short": "Troll légendaire",
		"legend": "Un troll dont les plaies se referment à vue d'œil. Seul le feu l'empêche de guérir.",
		"hunt_title": "Chasser le troll du gué de {town}", "hunt_desc": "Un troll tient le gué et écorche quiconque le franchit. On dit qu'il guérit de tout, sauf du feu.",
		"scale": 1.3, "biome": "water", "pack": [], "min_renown": 200,
		"loot": "u_peau_troll", "lairs": ["lair"], "danger": 3, "pay": 1600,
		"regen": 10, "regen_off_if_burned": true,
		"phases": [
			{"hp": 0.5, "say": "{n} grogne : ses chairs se ressoudent plus vite encore.", "stat": {"initiative": 10, "melee_skill": 6}, "regen": 14},
		],
	},
	"reine": {
		"foe": "leg_reine", "title": "La Reine pâle, souveraine des goules", "short": "Goule-reine légendaire",
		"legend": "Une goule gigantesque et pâle, qui relève les morts et appelle les affamés des cimetières.",
		"hunt_title": "Chasser la Reine pâle de {town}", "hunt_desc": "Les tombes de {town} s'ouvrent la nuit. Une reine des goules mène la meute et relève les morts derrière elle.",
		"scale": 1.25, "biome": "plain", "pack": ["goule", "goule"], "min_renown": 100,
		"loot": "u_couronne_pale", "lairs": ["necropolis"], "danger": 3, "pay": 1400,
		"phases": [
			{"hp": 0.7, "say": "{n} pousse un long cri : la meute répond !", "summon": ["goule", "goule"]},
			{"hp": 0.35, "say": "{n} appelle ses plus voraces !", "summon": ["goule", "vorace"], "stat": {"melee_skill": 5}},
		],
	},
	"alpha": {
		"foe": "leg_alpha", "title": "Croc-Gris, le loup alpha", "short": "Loup alpha légendaire",
		"legend": "Un loup immense au pelage de cendre. Il ne chasse jamais seul, et il hurle quand le sang coule.",
		"hunt_title": "Chasser le loup alpha de {town}", "hunt_desc": "Une meute descend des collines chaque nuit, conduite par un loup gris énorme que les bergers nomment Croc-Gris.",
		"scale": 1.55, "biome": "forest", "pack": ["loup", "loup", "loup", "loup"], "min_renown": 150,
		"loot": "u_croc_alpha", "lairs": ["lair", "fort"], "danger": 3, "pay": 1300,
		"phases": [
			{"hp": 0.6, "say": "{n} hurle à la mort : d'autres loups accourent !", "summon": ["loup", "loup"]},
			{"hp": 0.3, "say": "{n}, acculé, devient fou de rage.", "stat": {"melee_skill": 10}, "ap": 2},
		],
	},
	"geant": {
		"foe": "leg_geant", "title": "Le Géant de pierre", "short": "Géant légendaire",
		"legend": "Un géant bardé de plaques de fer martelées dans la pierre. Ses coups étourdissent les plus braves.",
		"hunt_title": "Abattre le Géant de pierre de {town}", "hunt_desc": "Un géant cuirassé descend de la montagne et écrase les hameaux. Les flèches ricochent sur sa carapace.",
		"scale": 1.45, "biome": "hills", "pack": [], "min_renown": 300,
		"loot": "u_cuirasse_roc", "lairs": ["lair", "fort"], "danger": 3, "pay": 1900,
		"phases": [
			{"hp": 0.66, "say": "{n} gronde : la pierre craque, il marche plus vite.", "ap": 2},
			{"hp": 0.33, "say": "{n} brandit sa massue à deux mains !", "stat": {"melee_skill": 8, "initiative": 10}, "ap": 1},
		],
	},
}
const ORDER: Array = ["ogre", "troll", "reine", "alpha", "geant"]
