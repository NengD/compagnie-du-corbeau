class_name Achievements
extends RefCounted
## Succès (conservés entre les parties dans user://achievements.json) et statistiques de campagne (Game.stats, dans la sauvegarde).
## Logique pure : `Game` incrémente les compteurs et appelle `newly_met` ; l'écran lit DEFS / STAT_LABELS.

const FILE_PATH: String = "user://achievements.json"

## Statistiques de campagne : clé → libellé (l'ordre est celui de l'écran).
const STAT_LABELS: Dictionary = {
	"battles_won": "Batailles gagnées", "battles_lost": "Batailles perdues", "retreats": "Retraites", "perfect_wins": "Victoires sans perte",
	"kills": "Ennemis abattus", "men_fallen": "Hommes tombés", "men_hired": "Hommes engagés",
	"contracts_done": "Contrats remplis", "hunts_done": "Chefs abattus (chasses)", "transports_done": "Escortes et livraisons",
	"gold_earned": "Couronnes gagnées", "gold_spent": "Couronnes dépensées",
	"travel_days": "Journées de marche", "events_seen": "Événements de route", "perks_taken": "Talents appris",
}

## Succès : `src` = "stats" (compteur de Game.stats) ou "ctx" (état courant de la partie, voir Game.achievement_context) ; `min` = seuil.
const DEFS: Array = [
	{"id": "first_blood", "n": "Premier sang", "d": "Abattre un premier ennemi.", "src": "stats", "key": "kills", "min": 1},
	{"id": "won_1", "n": "Baptême du feu", "d": "Gagner une bataille.", "src": "stats", "key": "battles_won", "min": 1},
	{"id": "kills_100", "n": "Centurion", "d": "Abattre 100 ennemis.", "src": "stats", "key": "kills", "min": 100},
	{"id": "kills_500", "n": "La Faucheuse", "d": "Abattre 500 ennemis.", "src": "stats", "key": "kills", "min": 500},
	{"id": "flawless", "n": "Pas un de moins", "d": "Gagner une bataille sans perdre un seul homme.", "src": "stats", "key": "perfect_wins", "min": 1},
	{"id": "flawless_5", "n": "Compagnie soudée", "d": "Gagner cinq batailles sans aucune perte.", "src": "stats", "key": "perfect_wins", "min": 5},
	{"id": "won_25", "n": "Habitués du champ", "d": "Gagner 25 batailles.", "src": "stats", "key": "battles_won", "min": 25},
	{"id": "renown_500", "n": "Un nom qui circule", "d": "Atteindre 500 de renom.", "src": "ctx", "key": "renown", "min": 500},
	{"id": "renown_1500", "n": "Une légende vivante", "d": "Atteindre 1 500 de renom.", "src": "ctx", "key": "renown", "min": 1500},
	{"id": "site_1", "n": "Le fort est à nous", "d": "Prendre un fort ou un repaire hostile.", "src": "ctx", "key": "sites", "min": 1},
	{"id": "site_5", "n": "Briseurs de murailles", "d": "Prendre cinq lieux hostiles.", "src": "ctx", "key": "sites", "min": 5},
	{"id": "arc_1", "n": "Fin d'histoire", "d": "Terminer un arc de trois contrats liés.", "src": "ctx", "key": "arcs", "min": 1},
	{"id": "perks_10", "n": "Hommes de talent", "d": "Apprendre 10 talents au total.", "src": "stats", "key": "perks_taken", "min": 10},
	{"id": "contract_1", "n": "Première prime", "d": "Remplir un contrat.", "src": "stats", "key": "contracts_done", "min": 1},
	{"id": "contract_10", "n": "Hommes de parole", "d": "Remplir 10 contrats.", "src": "stats", "key": "contracts_done", "min": 10},
	{"id": "contract_30", "n": "Maîtres mercenaires", "d": "Remplir 30 contrats.", "src": "stats", "key": "contracts_done", "min": 30},
	{"id": "hunt_1", "n": "Chasseurs de têtes", "d": "Abattre un chef lors d'une chasse au chef.", "src": "stats", "key": "hunts_done", "min": 1},
	{"id": "transport_5", "n": "Convoyeurs", "d": "Mener à bon port cinq escortes ou livraisons.", "src": "stats", "key": "transports_done", "min": 5},
	{"id": "gold_earned_5000", "n": "Bourse bien remplie", "d": "Gagner 5 000 couronnes au total.", "src": "stats", "key": "gold_earned", "min": 5000},
	{"id": "gold_3000", "n": "Coffre-fort", "d": "Détenir 3 000 couronnes à la fois.", "src": "ctx", "key": "gold", "min": 3000},
	{"id": "days_100", "n": "Cent jours de route", "d": "Tenir 100 jours.", "src": "ctx", "key": "days", "min": 100},
	{"id": "days_365", "n": "Une année entière", "d": "Tenir 365 jours.", "src": "ctx", "key": "days", "min": 365},
	{"id": "level_6", "n": "Vétéran", "d": "Amener un homme au niveau 6.", "src": "ctx", "key": "max_level", "min": 6},
	{"id": "level_11", "n": "Au sommet", "d": "Amener un homme au niveau 11.", "src": "ctx", "key": "max_level", "min": 11},
	{"id": "roster_full", "n": "Compagnie au complet", "d": "Avoir dix hommes sous la bannière.", "src": "ctx", "key": "roster", "min": 10},
	{"id": "fallen_10", "n": "Le prix du sang", "d": "Perdre dix hommes au combat.", "src": "stats", "key": "men_fallen", "min": 10},
	{"id": "retreat_1", "n": "Sagesse du retrait", "d": "Battre en retraite plutôt que mourir.", "src": "stats", "key": "retreats", "min": 1},
	{"id": "unique_1", "n": "Pièce d'exception", "d": "Posséder un objet unique.", "src": "ctx", "key": "uniques", "min": 1},
	{"id": "events_10", "n": "Routes imprévues", "d": "Vivre dix événements de route.", "src": "stats", "key": "events_seen", "min": 10},
	{"id": "travel_50", "n": "Grands voyageurs", "d": "Marcher 50 jours sur les routes.", "src": "stats", "key": "travel_days", "min": 50},
	{"id": "ending", "n": "La menace est écartée", "d": "Mettre fin à la crise qui pèse sur le royaume.", "src": "ctx", "key": "ending", "min": 1},
]


static func default_stats() -> Dictionary:
	var d: Dictionary = {}
	for k in STAT_LABELS:
		d[k] = 0.0 if k == "travel_days" else 0
	return d


## Statistiques lues dans une sauvegarde (clés manquantes à zéro, nombres convertis).
static func normalize_stats(raw: Variant) -> Dictionary:
	var out: Dictionary = default_stats()
	if typeof(raw) == TYPE_DICTIONARY:
		for k in out:
			if (raw as Dictionary).has(k):
				out[k] = float((raw as Dictionary)[k]) if k == "travel_days" else int((raw as Dictionary)[k])
	return out


static func def_of(id: String) -> Dictionary:
	for d in DEFS:
		if d["id"] == id:
			return d
	return {}


## Valeur courante du compteur d'un succès.
static func value_of(def: Dictionary, stats: Dictionary, ctx: Dictionary) -> float:
	var src: Dictionary = stats if def["src"] == "stats" else ctx
	return float(src.get(def["key"], 0))


static func is_met(def: Dictionary, stats: Dictionary, ctx: Dictionary) -> bool:
	return value_of(def, stats, ctx) >= float(def["min"])


## Succès atteints qui ne sont pas encore débloqués (ids).
static func newly_met(stats: Dictionary, ctx: Dictionary, unlocked: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for d in DEFS:
		if not unlocked.has(d["id"]) and is_met(d, stats, ctx):
			out.append(str(d["id"]))
	return out


# --- Fichier (indépendant des sauvegardes) : {"unlocked": {id: jour}} ---

static func load_unlocked(path: String = FILE_PATH) -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY and typeof((parsed as Dictionary).get("unlocked", null)) == TYPE_DICTIONARY:
		for k in parsed["unlocked"]:
			if not def_of(str(k)).is_empty():
				out[str(k)] = int(parsed["unlocked"][k])
	return out


static func save_unlocked(unlocked: Dictionary, path: String = FILE_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"unlocked": unlocked}))
	return true
