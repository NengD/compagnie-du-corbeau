class_name TradeData
extends RefCounted
## Tables du négoce entre villes : marchandises, spécialités des factions et des types de lieu. Données seulement (logique : core/trade.gd).
## Une marchandise prend 1 unité de cargaison ; elle n'occupe PAS la réserve d'objets.

## `base` : prix de base (couronnes l'unité). `ic` : pictogramme. Les noms sont propres à ce jeu.
const GOODS: Dictionary = {
	"sel": {"n": "Sel gris", "base": 22, "ic": "◇", "d": "Le sel des marais : il conserve la viande et vaut son poids de monnaie loin de la mer."},
	"fourrures": {"n": "Fourrures", "base": 48, "ic": "❖", "d": "Peaux de loup et de renard, rudes et chaudes, très prisées des villes."},
	"vin": {"n": "Vin de coteau", "base": 36, "ic": "♨", "d": "Des fûts de vin rouge cloutés de cerceaux de chêne."},
	"fer": {"n": "Barres de fer", "base": 40, "ic": "▬", "d": "Le fer brut des forges, vendu en barres liées par dix."},
	"grain": {"n": "Grain", "base": 14, "ic": "♣", "d": "Des sacs de blé et d'orge : peu de valeur, mais toujours demandés."},
	"epices": {"n": "Épices", "base": 78, "ic": "✦", "d": "Poivre, safran et clous de girofle : petits ballots, gros profits."},
	"draps": {"n": "Draps de laine", "base": 30, "ic": "▤", "d": "De grandes pièces de laine teinte, pliées en balles."},
	"ambre": {"n": "Ambre du nord", "base": 66, "ic": "●", "d": "Des perles d'ambre roulées dans la paille ; les dames des villes les adorent."},
}
const ORDER: Array = ["grain", "sel", "draps", "vin", "fer", "fourrures", "ambre", "epices"]

## Spécialités par faction : produit (prix bas) et demande (prix haut) en plus de ce que le type de lieu apporte.
const FACTION_MAKES: Dictionary = {
	"roncevaux": ["fer", "grain"],
	"lys": ["vin", "draps", "epices"],
	"abbaye": ["vin", "sel"],
	"marches": ["grain", "fourrures"],
	"givre": ["fourrures", "ambre"],
	"sablefer": ["fer", "epices", "sel"],
	"libres": ["draps"],
}
const FACTION_WANTS: Dictionary = {
	"roncevaux": ["epices", "vin", "ambre"],
	"lys": ["fourrures", "fer"],
	"abbaye": ["grain", "ambre", "draps"],
	"marches": ["fer", "sel"],
	"givre": ["grain", "vin", "sel"],
	"sablefer": ["fourrures", "grain", "vin"],
	"libres": ["epices", "fer"],
}
## Par type de lieu : ce qu'on y produit / désire en plus. Les villes consomment le luxe, les villages produisent le brut.
const KIND_MAKES: Dictionary = {
	"village": ["grain", "fourrures", "sel"],
	"city": ["draps", "fer"],
	"fort": ["fer"],
}
const KIND_WANTS: Dictionary = {
	"village": ["fer", "draps"],
	"city": ["epices", "ambre", "vin", "fourrures"],
	"fort": ["grain", "vin", "sel"],
}

const MAKE_MULT: float = 0.65  ## prix d'un produit local
const WANT_MULT: float = 1.5  ## prix d'un produit demandé
const WOBBLE: float = 0.08  ## variation de ±8 % selon le jour (par période de WOBBLE_DAYS)
const WOBBLE_DAYS: int = 3
const SPREAD: float = 0.88  ## on revend à 88 % du prix de la place (marge du négociant)
const MIN_MULT: float = 0.5
const MAX_MULT: float = 2.0
const CARGO_PER_MAN: int = 5
const CARGO_BASE: int = 5
const CARGO_PER_STORE_LEVEL: int = 12  ## par niveau de l'Entrepôt du camp
const CARAVAN_CHANCE: float = 0.4  ## part des escortes qui sont des caravanes
const CARAVAN_BONUS: float = 0.3  ## prime en plus si la caravane arrive intacte
