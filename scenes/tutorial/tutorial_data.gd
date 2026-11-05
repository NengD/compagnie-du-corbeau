class_name TutorialData
extends RefCounted
## Étapes du tutoriel (texte et enchaînement). Logique pure, sans scène : testable en headless.
## `ctx` : l'écran où l'étape s'affiche (town, map, battle, end).

const STEPS: Array[Dictionary] = [
	{"id": "town_contract", "ctx": "town", "title": "1 · Choisir un contrat",
		"text": "Chaque ville propose des contrats dans l'onglet « Contrats ». Lisez la prime et le danger, puis acceptez-en un : on n'en suit qu'un à la fois. Les onglets Recruter et Marché servent à renforcer la compagnie."},
	{"id": "town_leave", "ctx": "town", "title": "2 · Quitter la ville",
		"text": "Une fois votre contrat accepté, cliquez sur « Quitter la ville » pour gagner la carte du monde. La solde de vos hommes est payée chaque jour."},
	{"id": "map_travel", "ctx": "map", "title": "3 · Voyager",
		"text": "Cliquez sur la carte pour marcher, ou sur « Aller » dans la pastille du contrat (en bas à gauche). Les boutons ronds en haut à droite règlent le temps (Espace : pause) ; la touche F ouvre le tiroir « Détails », L la légende. Z, Q, S, D (ou les flèches) déplacent la caméra, H la recentre sur la compagnie. Molette : zoom ; clic milieu : déplacer la carte. Méfiez-vous des bandes errantes."},
	{"id": "battle_move", "ctx": "battle", "title": "4 · Déplacement et attaque",
		"text": "Cliquez une case dorée pour avancer (2 PA par case) ou un ennemi à portée pour l'attaquer ; son pourcentage de toucher s'affiche au survol. Quitter le contact d'un ennemi lui offre une attaque gratuite. Molette : zoom du plateau (H : vue d'ensemble)."},
	{"id": "battle_stats", "ctx": "battle", "title": "5 · PA, fatigue et moral",
		"text": "Vous avez 9 PA par tour (les pastilles dorées). Chaque action fatigue : une troupe épuisée touche moins et agit plus tard. Le moral baisse quand des camarades tombent ; un homme brisé s'enfuit. Espace : fin du tour."},
	{"id": "loot_end", "ctx": "end", "title": "6 · Butin et retour au camp",
		"text": "Le butin récupéré rejoint votre inventaire : vendez-le ou équipez-le depuis l'onglet Compagnie. Soignez-vous en voyageant, réparez l'armure, recrutez, puis reprenez la route. Bonne chance, capitaine !"},
]


## Étape suivante à afficher pour l'écran `ctx` (vide s'il n'en reste pas), compte tenu des identifiants déjà vus.
static func next_step(ctx: String, seen: Array) -> Dictionary:
	for s in STEPS:
		if s["ctx"] == ctx and not seen.has(s["id"]):
			return s
	return {}


## Identifiants de toutes les étapes d'un écran.
static func ids_for(ctx: String) -> Array:
	var out: Array = []
	for s in STEPS:
		if s["ctx"] == ctx:
			out.append(s["id"])
	return out


static func all_seen(seen: Array) -> bool:
	for s in STEPS:
		if not seen.has(s["id"]):
			return false
	return true
