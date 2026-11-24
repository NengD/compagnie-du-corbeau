class_name CampLifeData
extends RefCounted
## Tables du camp vivant : événements de veillée, seuils de mutinerie. Textes originaux en français.
## Les gabarits utilisent {a} et {b} (noms des deux hommes) et {story} (histoire de {a}).

const REST_CHANCE: float = 0.35  ## chance d'une veillée à chaque repos en lieu
const ROAD_CHANCE: float = 0.30  ## chance d'une veillée une fois la route assez longue
const ROAD_DAYS: int = 4  ## jours de route (sans feu) avant qu'une veillée soit possible
const MIN_GAP: int = 3  ## jours minimum entre deux veillées
const EXPIRE_DAYS: int = 3  ## un événement laissé sans réponse est tranché d'office après ce délai (jamais bloquant)

const MUTINY_MORALE: float = 20.0  ## moral de compagnie « très bas »
const MUTINY_WARN_DAYS: int = 2  ## jours consécutifs au plus bas : premier avertissement
const MUTINY_DAYS: int = 4  ## jours consécutifs au plus bas : la mutinerie éclate
const MUTINY_MIN_DAY: int = 10  ## jamais avant ce jour de la campagne
const MUTINY_COOLDOWN: int = 15  ## jours de répit après une mutinerie
const MUTINY_MIN_MEN: int = 3  ## en dessous, aucune mutinerie
const MUTINY_GOLD_SHARE: float = 0.1  ## part de l'or emportée par le mutin (plafonnée)
const MUTINY_GOLD_CAP: int = 150

const DUEL_BOND: int = -20  ## lien à partir duquel une querelle réclame un duel

const EVENTS: Dictionary = {
	"tale": {
		"title": "Une histoire au coin du feu",
		"text": "La nuit tombe et le feu craque. {a} se met à parler de lui, la voix basse : « {story} »",
		"choices": [
			{"id": "listen", "label": "L'écouter jusqu'au bout", "hint": "Moral +2, liens +1 avec {a}"},
			{"id": "round", "label": "Offrir une tournée", "hint": "−20 couronnes, moral +4, liens +2 ; parfois un bon trait"},
			{"id": "mock", "label": "Se moquer gentiment", "hint": "Moral +1, lien −2 avec {a}"},
		],
	},
	"brawl": {
		"title": "Rixe autour du feu",
		"text": "{a} et {b} ne se supportent plus. Un mot de trop, et les voilà qui s'empoignent devant toute la compagnie.",
		"choices": [
			{"id": "split", "label": "Les séparer", "hint": "Moral −1, lien +2"},
			{"id": "let", "label": "Les laisser s'expliquer", "hint": "Quelques PV perdus ; rancune ou respect"},
			{"id": "duel", "label": "Exiger un duel réglé", "hint": "Jusqu'au premier sang, sans mort"},
		],
	},
	"challenge": {
		"title": "Un défi",
		"text": "{a} jette sa ceinture aux pieds de {b} : leur querelle ne s'éteindra pas autrement. Toute la compagnie retient son souffle.",
		"choices": [
			{"id": "duel", "label": "Autoriser le duel", "hint": "Jusqu'au premier sang, sans mort"},
			{"id": "guard", "label": "Les envoyer monter la garde ensemble", "hint": "Peut les rapprocher… ou envenimer les choses"},
			{"id": "pay", "label": "Les réconcilier par une prime", "hint": "−40 couronnes, lien +6"},
		],
	},
	"bet": {
		"title": "Un pari",
		"text": "{a} et {b} se sont lancé un défi à la lueur du feu, et tous les yeux se tournent vers vous : la mise est de {stake} couronnes.",
		"choices": [
			{"id": "in", "label": "Miser avec eux", "hint": "±{stake} couronnes (une chance sur deux environ), moral +1"},
			{"id": "hold", "label": "Tenir la cagnotte", "hint": "+{cut} couronnes, liens −1 avec les deux"},
			{"id": "forbid", "label": "Interdire le pari", "hint": "Moral −1"},
		],
	},
	"song": {
		"title": "Une chanson",
		"text": "{a} entonne une vieille chanson de marche, un peu faux. Quelques voix la reprennent, puis d'autres.",
		"choices": [
			{"id": "join", "label": "Chanter avec eux", "hint": "Moral +5, liens +1 avec {a}"},
			{"id": "listen", "label": "Les laisser faire", "hint": "Moral +3"},
			{"id": "quiet", "label": "Réclamer le silence", "hint": "Moral −2, lien −1 avec {a}"},
		],
	},
	"food": {
		"title": "Dispute sur les vivres",
		"text": "{a} accuse {b} d'avoir gardé pour lui une part de rations. Les voix montent.",
		"choices": [
			{"id": "punish", "label": "Punir {b}", "hint": "Vivres +2, moral −1, lien −4 entre eux"},
			{"id": "share", "label": "Doubler les rations ce soir", "hint": "Vivres −3, moral +4, lien +1"},
			{"id": "search", "label": "Fouiller les sacs", "hint": "Un coupable, ou une fausse accusation"},
		],
	},
	"toast": {
		"title": "Un toast entre amis",
		"text": "{a} et {b}, inséparables, proposent de mettre en commun leurs économies pour offrir une tournée à la compagnie.",
		"choices": [
			{"id": "pool", "label": "Mettre aussi une pièce", "hint": "−15 couronnes, moral +4, liens +1"},
			{"id": "fallen", "label": "Boire à la mémoire des tombés", "hint": "Moral +3, liens +1 (si des hommes sont tombés)"},
			{"id": "decline", "label": "Les remercier, sans plus", "hint": "Rien"},
		],
	},
	"mutiny": {
		"title": "Les hommes grondent",
		"text": "Le moral est au plus bas depuis des jours. {a} parle tout haut de partir, avec sa part de l'or et son équipement, et d'autres l'écoutent.",
		"choices": [
			{"id": "pay", "label": "Verser une prime à chacun", "hint": "−{cost} couronnes, moral +12"},
			{"id": "speak", "label": "Haranguer la compagnie", "hint": "Environ une chance sur deux ; sinon {a} s'en va"},
			{"id": "let", "label": "Le laisser partir", "hint": "{a} emporte son équipement et une part de l'or, moral +4"},
		],
	},
}

const DAUGHTER_NAMES: Array = ["Aëlis", "Mahaut", "Ysabeau", "Hersende", "Béatrix", "Alais", "Sibylle", "Aliénor", "Éluarde", "Gersende"]
