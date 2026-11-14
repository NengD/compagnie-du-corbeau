class_name Seasons
extends RefCounted
## Saisons : quatre saisons de `SEASON_DAYS` jours, l'année se répète. La saison dérive du jour courant (rien à sauvegarder).
## Effets modestes et lisibles : voir `SEASONS`. Logique pure, sans scène.

const SEASON_DAYS: int = 30
const SPRING := 0
const SUMMER := 1
const AUTUMN := 2
const WINTER := 3

## Effets par saison. travel : multiplicateur de vitesse de marche ; food : multiplicateur des rations consommées par jour ;
## food_price : multiplicateur du prix des vivres ; weather : seuils cumulés [dégagé, pluie, brume] sur 100 (le reste = neige) ;
## tint : teinte légère de la carte.
const SEASONS: Array = [
	{"id": "spring", "n": "Printemps", "travel": 0.96, "food": 1.0, "food_price": 1.0, "weather": [38, 70, 90], "tint": Color(0.97, 1.0, 0.97),
		"d": "Boue et averses : marche un peu plus lente (−4 %), pluie plus fréquente."},
	{"id": "summer", "n": "Été", "travel": 1.06, "food": 1.0, "food_price": 1.0, "weather": [78, 88, 100], "tint": Color(1.0, 0.985, 0.93),
		"d": "Jours longs et chemins secs : marche un peu plus rapide (+6 %), ciel le plus souvent dégagé."},
	{"id": "autumn", "n": "Automne", "travel": 1.0, "food": 1.0, "food_price": 0.85, "weather": [50, 70, 93], "tint": Color(1.0, 0.95, 0.88),
		"d": "Les récoltes sont rentrées : vivres moins chers (−15 %). Brumes matinales."},
	{"id": "winter", "n": "Hiver", "travel": 0.9, "food": 1.25, "food_price": 1.0, "weather": [34, 42, 55], "tint": Color(0.93, 0.96, 1.0),
		"d": "Le froid ralentit la marche (−10 %) et creuse l'appétit : +25 % de rations consommées. Neige fréquente."},
]


## Numéro de saison (0 printemps, 1 été, 2 automne, 3 hiver) du jour `day` (les jours commencent à 1).
static func season_of(day: int) -> int:
	return (maxi(day - 1, 0) / SEASON_DAYS) % 4


static func info(day: int) -> Dictionary:
	return SEASONS[season_of(day)]


static func name_of(day: int) -> String:
	return str(info(day)["n"])


## Jour de la saison (1 à SEASON_DAYS).
static func day_in_season(day: int) -> int:
	return (maxi(day - 1, 0) % SEASON_DAYS) + 1


static func is_winter(day: int) -> bool:
	return season_of(day) == WINTER


## Multiplicateur de vitesse de marche.
static func travel_mult(day: int) -> float:
	return float(info(day)["travel"])


## Rations consommées par jour de route pour `need` rations de base : jamais moins que `need`.
static func food_need(day: int, need: int) -> int:
	var m: float = float(info(day)["food"])
	return need if m == 1.0 else maxi(need, int(round(float(need) * m)))


static func food_price_mult(day: int) -> float:
	return float(info(day)["food_price"])


static func tint(day: int) -> Color:
	return info(day)["tint"]


## Météo du jour selon la saison, à partir d'un tirage 0..99.
static func weather_from_roll(day: int, r: int) -> String:
	var w: Array = info(day)["weather"]
	if r < int(w[0]):
		return "clear"
	if r < int(w[1]):
		return "rain"
	if r < int(w[2]):
		return "fog"
	return "snow"


## Texte d'infobulle : saison, avancement et effets.
static func tooltip(day: int) -> String:
	var s: Dictionary = info(day)
	return "%s (jour %d/%d de la saison)\n%s" % [s["n"], day_in_season(day), SEASON_DAYS, s["d"]]
