class_name Events
extends RefCounted
## Événements de route : données + résolution pure (aléa injecté). `Game` applique les effets.
##
## Un événement : {id, title, text, choices: [{id, label, cost (couronnes, optionnel), outcomes: [{w, text, <effets>}]}]}
## Effets d'une issue (tous optionnels) :
##   gold (±couronnes), hp_all (±PV à chaque homme), hp_one (±PV à un homme tiré au hasard), renown (±),
##   days (jours perdus), recruit (clé de Data.BG ou "random"), battle ({"type": faction, "d": danger}),
##   repair (true : armures réparées), xp_all (XP à chaque homme).

const CHANCE_PER_DAY: float = 0.22  ## probabilité par jour entier de route
const MIN_GAP_DAYS: int = 2  ## jours minimum entre deux événements

const DEFS: Array = [
	{
		"id": "merchant", "title": "Marchand ambulant",
		"text": "Un colporteur arrête sa charrette et déballe sa marchandise sur le bord du chemin. « Des prix d'ami, messires ! »",
		"choices": [
			{"id": "food", "label": "Acheter des provisions (35 couronnes) : +10 PV à tous", "cost": 35, "outcomes": [{"w": 1, "text": "Pain, lard et vin coupé : les hommes se remplissent la panse.", "hp_all": 10}]},
			{"id": "kit", "label": "Acheter du fil de fer et des rivets (60 couronnes) : armures réparées", "cost": 60, "outcomes": [{"w": 1, "text": "Un forgeron de fortune répare les cottes entre deux bouchées.", "repair": true}]},
			{"id": "pass", "label": "Passer son chemin", "outcomes": [{"w": 1, "text": "Le colporteur hausse les épaules et fouette son mulet."}]},
		],
	},
	{
		"id": "refugees", "title": "Réfugiés",
		"text": "Une file de paysans en haillons fuit un village brûlé. Une femme vous tend les bras, un enfant contre elle.",
		"choices": [
			{"id": "help", "label": "Les aider (50 couronnes de vivres)", "cost": 50, "outcomes": [
				{"w": 3, "text": "Vos vivres les sauvent. On parlera de la Compagnie du Corbeau dans les foyers.", "renown": 8},
				{"w": 1, "text": "Parmi eux, un jeune homme costaud demande à se battre à vos côtés.", "renown": 5, "recruit": "random"},
			]},
			{"id": "escort", "label": "Les escorter jusqu'au prochain carrefour (1 jour)", "outcomes": [
				{"w": 1, "text": "Une journée de marche lente, mais la reconnaissance est sincère.", "renown": 10, "days": 1},
			]},
			{"id": "pass", "label": "Détourner le regard", "outcomes": [{"w": 1, "text": "Vous continuez. Personne ne parle pendant une heure."}]},
		],
	},
	{
		"id": "toll", "title": "Pont à péage",
		"text": "Un pont de bois. Trois hommes armés barrent le passage : « Dix couronnes par tête, ou vous traversez à la nage. »",
		"choices": [
			{"id": "pay", "label": "Payer le péage (40 couronnes)", "cost": 40, "outcomes": [{"w": 1, "text": "Vous payez. Les gardes comptent deux fois chaque pièce."}]},
			{"id": "fight", "label": "Forcer le passage", "outcomes": [
				{"w": 1, "text": "Les péagers dégainent : à vous de les convaincre !", "battle": {"type": "b", "d": 1}},
				{"w": 1, "text": "Devant vos lames, les péagers s'écartent en grommelant.", "renown": 3},
			]},
			{"id": "ford", "label": "Chercher un gué en amont (1 jour)", "outcomes": [
				{"w": 3, "text": "Vous trouvez un gué, les bottes trempées.", "days": 1},
				{"w": 1, "text": "Le courant emporte un sac de provisions et blesse un homme.", "days": 1, "hp_one": -8},
			]},
		],
	},
	{
		"id": "corpses", "title": "Cadavres au bord du chemin",
		"text": "Un chariot renversé, des corps déjà froids. Une bourse dépasse peut-être d'une poche.",
		"choices": [
			{"id": "search", "label": "Fouiller les corps", "outcomes": [
				{"w": 5, "text": "Vous trouvez quelques pièces et un bon couteau.", "gold": 90},
				{"w": 2, "text": "Les corps étaient contaminés : un homme tombe malade.", "hp_one": -15},
				{"w": 2, "text": "C'était un appât. Les brigands sortent des fourrés !", "battle": {"type": "b", "d": 1}},
			]},
			{"id": "bury", "label": "Les enterrer (1 jour)", "outcomes": [{"w": 1, "text": "Un paysan, plus loin, saura qui remercier.", "renown": 6, "days": 1}]},
			{"id": "pass", "label": "Ne pas s'attarder", "outcomes": [{"w": 1, "text": "Les corbeaux ont fait leur travail avant vous."}]},
		],
	},
	{
		"id": "storm", "title": "Orage",
		"text": "Le ciel noircit d'un coup. La pluie tombe en rideaux, les chemins se changent en boue.",
		"choices": [
			{"id": "shelter", "label": "S'abriter jusqu'à la fin de l'orage (1 jour)", "outcomes": [{"w": 1, "text": "Vous attendez dans une grange, au sec.", "days": 1}]},
			{"id": "press", "label": "Poursuivre sous la pluie", "outcomes": [
				{"w": 3, "text": "Trempés et frigorifiques, mais vous avancez.", "hp_all": -4},
				{"w": 1, "text": "Un homme glisse dans un fossé et se blesse.", "hp_one": -14},
			]},
		],
	},
	{
		"id": "pilgrims", "title": "Pèlerins",
		"text": "Une procession de pèlerins en bure chante des psaumes sur la route. Leur prieur vous salue d'un geste las.",
		"choices": [
			{"id": "alms", "label": "Faire l'aumône (20 couronnes)", "cost": 20, "outcomes": [
				{"w": 1, "text": "Le prieur bénit la compagnie. Les hommes se sentent plus légers.", "renown": 5, "hp_all": 5},
			]},
			{"id": "share", "label": "Partager leur feu pour la nuit (1 jour)", "outcomes": [
				{"w": 1, "text": "Une veillée tranquille, des histoires de saints et de bêtes.", "days": 1, "hp_all": 8},
			]},
			{"id": "pass", "label": "Les saluer et poursuivre", "outcomes": [{"w": 1, "text": "Leurs chants vous suivent longtemps."}]},
		],
	},
	{
		"id": "deserter", "title": "Un déserteur",
		"text": "Un homme en armure dépareillée sort du bois, les mains levées : « J'ai quitté le service du seigneur. Prenez-moi avec vous. »",
		"choices": [
			{"id": "hire", "label": "L'engager (gratuitement)", "outcomes": [
				{"w": 4, "text": "Il tient parole et se révèle un bon soldat.", "recruit": "deserteur"},
				{"w": 1, "text": "Il vide votre bourse la nuit suivante et disparaît.", "gold": -60},
			]},
			{"id": "food", "label": "Lui donner du pain et le laisser partir", "outcomes": [{"w": 1, "text": "Il murmure un merci et s'enfonce dans la forêt.", "renown": 2}]},
			{"id": "pass", "label": "Le chasser", "outcomes": [{"w": 1, "text": "Il se perd dans les bois."}]},
		],
	},
	{
		"id": "spring", "title": "Source guérisseuse",
		"text": "Entre deux rochers, une source claire coule dans un bassin moussu. Les paysans parlent d'une eau qui guérit.",
		"choices": [
			{"id": "drink", "label": "Boire et remplir les gourdes", "outcomes": [
				{"w": 3, "text": "L'eau est glacée et revigorante. Les blessés respirent mieux.", "hp_all": 15},
				{"w": 1, "text": "L'eau est croupie : plusieurs hommes ont des crampes.", "hp_all": -5},
			]},
			{"id": "rest", "label": "Camper à côté (1 jour)", "outcomes": [{"w": 1, "text": "Une journée de repos sous les saules.", "days": 1, "hp_all": 25}]},
			{"id": "pass", "label": "Passer", "outcomes": [{"w": 1, "text": "La source vous regarde partir."}]},
		],
	},
	{
		"id": "shepherd", "title": "Berger égaré",
		"text": "Un vieux berger cherche son troupeau dispersé par les loups. Il a l'air d'avoir couru toute la nuit.",
		"choices": [
			{"id": "help", "label": "L'aider à rassembler les bêtes (1 jour)", "outcomes": [
				{"w": 1, "text": "Le soir, le troupeau est enclos. Il vous offre ce qu'il a : trois fromages et un peu d'argent.", "days": 1, "gold": 60, "renown": 4},
			]},
			{"id": "directions", "label": "Lui indiquer la direction des loups", "outcomes": [{"w": 1, "text": "Il vous remercie en bredouillant.", "renown": 1}]},
			{"id": "pass", "label": "Poursuivre", "outcomes": [{"w": 1, "text": "Vous laissez le vieil homme à ses bêtes."}]},
		],
	},
	{
		"id": "ambush", "title": "Embuscade de brigands",
		"text": "Des silhouettes surgissent des fourrés. « La bourse ou la vie ! »",
		"choices": [
			{"id": "fight", "label": "Dégainer !", "outcomes": [{"w": 1, "text": "Les lames sortent du fourreau.", "battle": {"type": "b", "d": 1}}]},
			{"id": "pay", "label": "Payer pour passer (80 couronnes)", "cost": 80, "outcomes": [{"w": 1, "text": "Vous payez à contrecœur. Les brigands s'effacent."}]},
			{"id": "run", "label": "Faire demi-tour et fuir", "outcomes": [{"w": 1, "text": "Vous courez. Une flèche vous blesse en chemin.", "days": 1, "hp_one": -10}]},
		],
	},
	{
		"id": "knight", "title": "Chevalier blessé",
		"text": "Un chevalier gît à côté de son cheval mort, la jambe brisée. « Au nom du seigneur de ces terres, aidez-moi. »",
		"choices": [
			{"id": "help", "label": "Le soigner et le conduire au prochain village (1 jour)", "outcomes": [
				{"w": 3, "text": "Reconnaissant, le chevalier vous remet une bourse et promet de parler de vous.", "days": 1, "gold": 110, "renown": 10},
				{"w": 1, "text": "C'était un imposteur : il vous dépouille la nuit suivante.", "days": 1, "gold": -50},
			]},
			{"id": "loot", "label": "Prendre son équipement", "outcomes": [
				{"w": 1, "text": "L'armure est de bonne facture. La honte, moins.", "gold": 90, "renown": -8},
			]},
			{"id": "pass", "label": "Passer", "outcomes": [{"w": 1, "text": "Vous ne vous retournez pas."}]},
		],
	},
	{
		"id": "fair", "title": "Foire de village",
		"text": "Un village en fête : musiciens, tripes grillées, joutes de lutte. On vous invite à poser vos armes.",
		"choices": [
			{"id": "feast", "label": "Festoyer (30 couronnes)", "cost": 30, "outcomes": [
				{"w": 1, "text": "Une nuit de bombance. Les hommes repartent frais et joyeux.", "hp_all": 12, "days": 1},
			]},
			{"id": "wrestle", "label": "Défier les lutteurs du village", "outcomes": [
				{"w": 2, "text": "Votre meilleur homme gagne la bourse du tournoi.", "gold": 70, "renown": 4},
				{"w": 1, "text": "Un taureau de lutteur écrase votre champion.", "hp_one": -10, "renown": -2},
			]},
			{"id": "pass", "label": "Traverser sans s'arrêter", "outcomes": [{"w": 1, "text": "Les ménestrels se moquent de vos mines sombres."}]},
		],
	},
	{
		"id": "wreck", "title": "Chariot abandonné",
		"text": "Un chariot sans cocher, une roue cassée, les bâches claquent dans le vent. La cargaison est encore là.",
		"choices": [
			{"id": "take", "label": "Prendre ce qu'on peut", "outcomes": [
				{"w": 3, "text": "Des étoffes, du sel et quelques outils : tout se revend.", "gold": 80},
				{"w": 1, "text": "Le chariot cache des piques : deux hommes se blessent en fouillant.", "hp_one": -8},
				{"w": 1, "text": "Le propriétaire revient, escorté de gardes. Explication musclée.", "battle": {"type": "b", "d": 1}, "renown": -3},
			]},
			{"id": "pass", "label": "Laisser tel quel", "outcomes": [{"w": 1, "text": "Mieux vaut ne pas toucher à ce qui n'est pas à soi."}]},
		],
	},
]


static func get_def(id: String) -> Dictionary:
	for e in DEFS:
		if e["id"] == id:
			return e
	return {}


## Tire un événement au hasard (hors le dernier, pour éviter les répétitions).
static func pick(rng: RandomNumberGenerator, last_id: String = "") -> Dictionary:
	var pool: Array = []
	for e in DEFS:
		if e["id"] != last_id:
			pool.append(e)
	return pool[rng.randi() % pool.size()]


## Faut-il tirer un événement pour ce jour entier de route ?
static func roll_day(rng: RandomNumberGenerator, days_since_last: int) -> bool:
	return days_since_last >= MIN_GAP_DAYS and rng.randf() < CHANCE_PER_DAY


static func choice_of(def: Dictionary, choice_id: String) -> Dictionary:
	for c in def.get("choices", []):
		if c["id"] == choice_id:
			return c
	return {}


## Tire l'issue du choix : renvoie une copie de l'issue ({text, effets...}), ou {} si le choix est inconnu.
static func resolve(event_id: String, choice_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var c: Dictionary = choice_of(get_def(event_id), choice_id)
	if c.is_empty():
		return {}
	var outcomes: Array = c["outcomes"]
	var total: int = 0
	for o in outcomes:
		total += int(o.get("w", 1))
	var r: int = rng.randi_range(1, maxi(1, total))
	for o in outcomes:
		r -= int(o.get("w", 1))
		if r <= 0:
			return (o as Dictionary).duplicate(true)
	return (outcomes[outcomes.size() - 1] as Dictionary).duplicate(true)
