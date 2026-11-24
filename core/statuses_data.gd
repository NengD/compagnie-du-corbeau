class_name StatusesData
extends RefCounted
## Tables des états de combat (saignement, poison, brûlure, engourdissement) et de leurs sources. Voir core/statuses.gd.
## Un état = {id: tours restants} dans `Unit.statuses`. Les états ne durent que le temps de la bataille.
## Les « états d'ordre » (ord_*) sont donnés par un capitaine (core/orders.gd) : ils durent jusqu'à son prochain tour.

## `dmg` : PV perdus au début du tour de l'unité (l'armure n'y peut rien) ; `turns` : durée par défaut ; `ini` : malus d'initiative ;
## `ap` : PA perdus au début du tour ; `morale` : test de moral à chaque tick ; `immune` : factions insensibles.
const STATUSES: Dictionary = {
	"bleed": {"n": "Saignement", "tag": "Sai", "color": Color("c0392b"), "dmg": 4, "turns": 3, "immune": ["u"],
		"d": "Perd 4 PV au début de chaque tour, l'armure n'y peut rien. S'arrête avec un bandage, un soin, ou au bout de quelques tours."},
	"poison": {"n": "Poison", "tag": "Poi", "color": Color("6fa84a"), "dmg": 3, "turns": 4, "ini": 15, "immune": ["u"],
		"d": "Perd 3 PV au début de chaque tour et 15 d'initiative. Un antidote le guérit."},
	"burn": {"n": "Brûlure", "tag": "Brû", "color": Color("e8892b"), "dmg": 5, "turns": 2, "morale": -10, "immune": [],
		"d": "Perd 5 PV au début de chaque tour et risque de perdre le moral. S'éteint dans l'eau (gué, rivière) ou avec un onguent."},
	"frost": {"n": "Engourdissement", "tag": "Gel", "color": Color("7fb6d8"), "ap": 2, "turns": 2, "immune": ["u"],
		"d": "Les membres s'engourdissent : 2 PA de moins au début de chaque tour."},
	# États d'ordre (core/orders.gd) : pas de décompte par tour, ils tombent quand l'ordre expire.
	"ord_tenir": {"n": "Tient la ligne", "tag": "Lig", "color": Color("d9c27a"), "order": true, "def": 10,
		"d": "Ordre « Tenez la ligne » : +10 en défense, ne peut plus être mis en fuite."},
	"ord_charge": {"n": "Chargez !", "tag": "Cha", "color": Color("e07a5f"), "order": true, "hit": 10, "ini": -15,
		"d": "Ordre « Chargez ! » : +10 % au toucher et +15 d'initiative."},
	"ord_repli": {"n": "Repli coordonné", "tag": "Rep", "color": Color("9bb7d4"), "order": true,
		"d": "Ordre « Repli coordonné » : quitte le contact sans attaque gratuite."},
}

## Ordre d'affichage des pastilles.
const ORDER: Array[String] = ["bleed", "poison", "burn", "frost", "ord_tenir", "ord_charge", "ord_repli"]

## Un coup qui laisse au moins ce nombre de PV de dégâts peut infliger l'état d'une arme ou d'un ennemi (pas de plaie si l'armure a tout pris).
const MIN_HP_FOR_STATUS: int = 5

## Armes : [état, chance en %, tours]. Lames qui entaillent profondément.
const WEAPON_HIT: Dictionary = {
	"dague": ["bleed", 30, 3],
	"epee_courte": ["bleed", 25, 3],
	"rapiere": ["bleed", 25, 3],
	"epee": ["bleed", 20, 3],
	"hache": ["bleed", 15, 3],
	"hache_bataille": ["bleed", 25, 3],
	"u_dague_veuve": ["bleed", 45, 4],
	"u_epee_corbeau": ["bleed", 25, 3],
	"u_hache_fendcrane": ["bleed", 20, 3],
	"u_hache_aurore": ["bleed", 30, 3],
	"morsure": ["bleed", 40, 3],
	"griffesL": ["bleed", 30, 3],
}

## Ennemis précis (clé de Data.FOE) : [état, chance en %, tours]. Prioritaire sur l'arme quand l'ennemi a une entrée.
const FOE_HIT: Dictionary = {
	"goule": ["poison", 35, 4],
	"vorace": ["poison", 50, 4],
	"zombie": ["poison", 25, 3],
	"archer": ["poison", 20, 3],  ## flèches empoisonnées des archers brigands
	"necro": ["frost", 40, 2],
	"troll": ["bleed", 40, 3],
	"berserker": ["bleed", 30, 3],
}

## Capacités et jets : [état, chance en %, tours]. Sans clé, aucun état.
const ABILITY_HIT: Dictionary = {
	"fleche_feu": ["burn", 70, 2],
	"lancer_huile": ["burn", 100, 3],
	"fleche_venimeuse": ["poison", 100, 4],
}

## Objets du sol : « feu » (torche renversée, huile) enflamme celui qui y entre ou y reste. [état, tours]
const FIRE_CELL: Array = ["burn", 2]


static func has(id: String) -> bool:
	return STATUSES.has(id)


static func name_of(id: String) -> String:
	return str(STATUSES.get(id, {}).get("n", id))
