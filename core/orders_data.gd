class_name OrdersData
extends RefCounted
## Ordres de groupe donnés par un capitaine (core/orders.gd). `ap` / `fat` : coût pour le capitaine ; `radius` : rayon d'effet en cases
## autour de lui (alliés vivants, lui compris selon l'ordre) ; `status` : état d'ordre posé (StatusesData) ; `min_allies` : alliés requis.

const ORDERS: Dictionary = {
	"tenir": {"n": "Tenez la ligne !", "ap": 3, "fat": 4, "radius": 4, "status": "ord_tenir", "min_allies": 1,
		"d": "Les alliés à 4 cases ou moins gagnent +10 en défense et ne peuvent plus être mis en fuite, jusqu'au prochain tour du capitaine."},
	"mur": {"n": "Mur de boucliers !", "ap": 4, "fat": 6, "radius": 2, "status": "", "min_allies": 1,
		"d": "Tous les porteurs de bouclier à 2 cases ou moins (le capitaine compris) forment un mur de boucliers gratuitement."},
	"repli": {"n": "Repli coordonné !", "ap": 3, "fat": 4, "radius": 3, "status": "ord_repli", "min_allies": 1,
		"d": "Les alliés à 3 cases ou moins quittent le contact sans subir d'attaque gratuite, jusqu'au prochain tour du capitaine."},
	"charge": {"n": "Chargez !", "ap": 4, "fat": 6, "radius": 4, "status": "ord_charge", "min_allies": 1,
		"d": "Les alliés à 4 cases ou moins gagnent +10 % au toucher et +15 d'initiative, jusqu'au prochain tour du capitaine."},
}

const ORDER_IDS: Array[String] = ["tenir", "mur", "repli", "charge"]

## Règle du capitaine : un homme du joueur qui a un talent de chef (`chef_ne`, `voix_claire`), sinon celui qui a le plus haut niveau
## (puis la plus haute détermination, puis le plus petit id) parmi ceux dont la détermination atteint ce seuil. Camp ennemi : son chef.
const CAPTAIN_MIN_RESOLVE: int = 50
const CAPTAIN_PERKS: Array[String] = ["chef_ne", "voix_claire"]

## IA : chance qu'un chef ennemi donne l'ordre qui convient quand la situation s'y prête.
const AI_ORDER_CHANCE: float = 0.55
