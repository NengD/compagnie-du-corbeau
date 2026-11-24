class_name ModsData
extends RefCounted
## Limites et tables de validation des mods (voir core/mods.gd et docs/mods.md). Aucune logique ici.

const ROOT: String = "user://mods"
const STATE_FILE: String = "user://mods_state.json"  ## liste des mods désactivés par le joueur (écrite par le jeu, jamais par un mod)

const MAX_MODS: int = 32
const MAX_FILES_PER_MOD: int = 16
const MAX_MANIFEST_BYTES: int = 16384
const MAX_FILE_BYTES: int = 262144  ## 256 Kio par fichier de contenu
const MAX_JSON_DEPTH: int = 10
const MAX_JSON_NODES: int = 30000
const MAX_WARNINGS: int = 40  ## par mod (au-delà, les avertissements sont comptés mais plus listés)

## Catégories de contenu reconnues (clé de premier niveau d'un fichier de contenu) -> description.
const CATEGORIES: Dictionary = {
	"first_names": "Prénoms de recrues",
	"nicknames": "Surnoms de recrues",
	"company_names": "Noms de compagnie suggérés",
	"place_names": "Noms de lieux (en renfort des listes du jeu)",
	"epitaphs": "Épitaphes du mémorial",
	"backstories": "Histoires de recrues (par origine)",
	"scenarios": "Scénarios de départ",
	"events": "Événements et rencontres de route",
}

const NAME_LEN: Array = [2, 24]
const NICK_LEN: Array = [2, 30]
const PLACE_LEN: Array = [2, 30]
const EPITAPH_LEN: Array = [10, 160]
const STORY_LEN: Array = [10, 300]
const LIST_MAX: int = 500
const STORIES_PER_ORIGIN_MAX: int = 20
const SCENARIOS_MAX: int = 8
const EVENTS_MAX: int = 40

const ID_CHARS: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
const ID_MAX: int = 32

## Effets d'une issue d'événement -> [min, max] (entiers).
const EFFECT_RANGES: Dictionary = {
	"gold": [-500, 500], "hp_all": [-30, 30], "hp_one": [-40, 40], "renown": [-30, 30],
	"days": [0, 5], "food": [-20, 30], "xp_all": [0, 30],
}
const CHECK_KINDS: Array = ["negotiate", "bribe", "flee", "trap"]
const BATTLE_FACTIONS: Array = ["b", "g", "o", "u"]

## Valeurs par défaut d'un scénario de mod (champs absents).
const SCENARIO_DEFAULTS: Dictionary = {
	"tag": "", "desc": "", "intro": "", "rule": "", "gold": -1, "gear": "", "wage_mult": 1.0,
	"provisions": 0, "morale": 0, "hunt_only": false, "hunt_pay": 1.0, "win": "", "lose": "",
}
