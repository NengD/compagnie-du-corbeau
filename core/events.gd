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
			{"id": "food", "label": "Acheter des provisions (35 couronnes) : +10 PV à tous, +12 rations", "cost": 35, "outcomes": [{"w": 1, "text": "Pain, lard et vin coupé : les hommes se remplissent la panse.", "hp_all": 10, "food": 12}]},
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
	{
		"id": "healer", "title": "Herboriste",
		"text": "Une vieille femme cueille des plantes à l'orée du bois. Elle vous jauge : « Vos hommes ont l'air de ceux qui saignent beaucoup. »",
		"choices": [
			{"id": "buy", "label": "Acheter des onguents (45 couronnes) : +14 PV à tous", "cost": 45, "outcomes": [
				{"w": 4, "text": "Les baumes sentent mauvais mais les plaies se ferment.", "hp_all": 14},
				{"w": 1, "text": "Elle vous glisse un flacon de plus, pour l'amour de la route.", "hp_all": 20},
			]},
			{"id": "talk", "label": "Bavarder avec elle (1 jour)", "outcomes": [
				{"w": 2, "text": "Elle vous apprend à reconnaître les herbes qui tuent, et celles qui sauvent.", "days": 1, "xp_all": 4},
				{"w": 1, "text": "Elle disparaît au matin, laissant une tisane encore tiède.", "days": 1, "hp_all": 8},
			]},
			{"id": "pass", "label": "Passer", "outcomes": [{"w": 1, "text": "Elle crache par terre, sans rancune."}]},
		],
	},
	{
		"id": "wolves", "title": "Meute de loups",
		"text": "Des yeux jaunes dans le sous-bois, des silhouettes grises qui vous suivent depuis une heure. La meute se resserre.",
		"choices": [
			{"id": "fire", "label": "Allumer de grands feux et veiller", "outcomes": [
				{"w": 3, "text": "Les loups tournent autour du feu toute la nuit, puis s'en vont.", "hp_all": -3},
				{"w": 1, "text": "Un loup plus hardi se jette sur un homme avant de fuir.", "hp_one": -12},
			]},
			{"id": "hunt", "label": "Les traquer et les abattre", "outcomes": [
				{"w": 2, "text": "Quelques peaux, un peu de gloire de paysan.", "gold": 50, "renown": 3},
				{"w": 1, "text": "La traque tourne mal : un homme se fait mordre à la jambe.", "hp_one": -16},
			]},
			{"id": "pass", "label": "Presser le pas", "outcomes": [{"w": 1, "text": "Les loups vous laissent filer, ou vous accompagnent un temps."}]},
		],
	},
	{
		"id": "bard", "title": "Ménestrel",
		"text": "Un jongleur accorde son luth sur une borne. « Une ballade pour trois sous, et un nom qui fera le tour des auberges ! »",
		"choices": [
			{"id": "pay", "label": "Lui payer une ballade (25 couronnes)", "cost": 25, "outcomes": [
				{"w": 3, "text": "Il chante le Corbeau et ses lames. Les hommes redressent l'échine.", "renown": 10},
				{"w": 1, "text": "Les vers sont pitoyables, mais le refrain restera.", "renown": 4},
			]},
			{"id": "sing", "label": "Chanter avec lui autour du feu (1 jour)", "outcomes": [
				{"w": 1, "text": "Une soirée de chants gaillards. Tout le monde dort mieux ensuite.", "days": 1, "hp_all": 10, "renown": 2},
			]},
			{"id": "pass", "label": "Poursuivre", "outcomes": [{"w": 1, "text": "Le ménestrel lève un sourcil et reprend son luth."}]},
		],
	},
	{
		"id": "lost_child", "title": "Enfant égaré",
		"text": "Un petit garçon pleure au bord du chemin, sa mère introuvable. Les bois sont profonds.",
		"choices": [
			{"id": "search", "label": "Chercher la mère (1 jour)", "outcomes": [
				{"w": 3, "text": "La mère, folle d'angoisse, vous bénit à genoux. On le dira au village.", "days": 1, "renown": 9},
				{"w": 1, "text": "Son père, plus pratique, vous remet une bourse bien lourde.", "days": 1, "gold": 70, "renown": 4},
			]},
			{"id": "carry", "label": "Le confier au prochain hameau", "outcomes": [{"w": 1, "text": "Une femme sort en courant et l'arrache à vos bras.", "renown": 4}]},
			{"id": "pass", "label": "Ne pas s'en mêler", "outcomes": [{"w": 1, "text": "Le sanglot vous suit longtemps."}]},
		],
	},
	{
		"id": "bridge_out", "title": "Pont effondré",
		"text": "Le pont de pierre a cédé sous les pluies. Le torrent gronde en contrebas, brun et rapide.",
		"choices": [
			{"id": "cross", "label": "Traverser à gué", "outcomes": [
				{"w": 3, "text": "Les hommes passent la corde à la main, trempés jusqu'aux hanches.", "hp_all": -3},
				{"w": 1, "text": "Un homme perd pied. On le repêche à moitié noyé.", "hp_one": -18},
			]},
			{"id": "detour", "label": "Faire le détour (1 jour)", "outcomes": [{"w": 1, "text": "Une longue marche sur des chemins de chèvres.", "days": 1}]},
			{"id": "build", "label": "Bâtir une passerelle (1 jour, 20 couronnes de cordages)", "cost": 20, "outcomes": [
				{"w": 1, "text": "Les villageois voisins, impressionnés, vous offrent à boire.", "days": 1, "renown": 6},
			]},
		],
	},
	{
		"id": "inn_brawl", "title": "Rixe d'auberge",
		"text": "Vous faites halte dans une auberge de bord de route quand une bagarre éclate. Les bancs volent.",
		"choices": [
			{"id": "join", "label": "Se mêler à la mêlée", "outcomes": [
				{"w": 2, "text": "Poings et rires : vos hommes sortent bleus, fiers et un peu plus soudés.", "xp_all": 3, "hp_all": -4},
				{"w": 1, "text": "Un couteau jaillit. Un homme est piqué avant que la salle ne se calme.", "hp_one": -12, "xp_all": 2},
			]},
			{"id": "calm", "label": "Imposer le calme (15 couronnes de dégâts)", "cost": 15, "outcomes": [
				{"w": 1, "text": "Le patron vous remercie d'un tonneau de bière.", "renown": 5, "hp_all": 5},
			]},
			{"id": "pass", "label": "Boire dans son coin", "outcomes": [{"w": 1, "text": "Vous finissez vos chopes sous la table, sans histoire."}]},
		],
	},
	{
		"id": "tax_collector", "title": "Percepteur du seigneur",
		"text": "Un percepteur à cheval, flanqué de deux archers, exige le tribut de passage au nom du seigneur de ces terres.",
		"choices": [
			{"id": "pay", "label": "Payer l'impôt (55 couronnes)", "cost": 55, "outcomes": [{"w": 1, "text": "Il note la somme d'un air satisfait. Le reçu est même lisible."}]},
			{"id": "bribe", "label": "Lui glisser une bourse en secret (25 couronnes)", "cost": 25, "outcomes": [
				{"w": 2, "text": "Il fait mine de ne rien avoir vu. L'économie est affaire d'oreilles discrètes."},
				{"w": 1, "text": "Il empoche et exige le reste : à vous de vous expliquer.", "battle": {"type": "b", "d": 1}},
			]},
			{"id": "refuse", "label": "Refuser et passer outre", "outcomes": [
				{"w": 1, "text": "Les archers se ravisent. Le percepteur jure de se plaindre à son maître.", "renown": -4},
			]},
		],
	},
	{
		"id": "ruins", "title": "Ruines envahies",
		"text": "Les murs d'une ancienne chapelle émergent du lierre. Il y a des traces de pas récentes dans la cendre du foyer.",
		"choices": [
			{"id": "explore", "label": "Fouiller les ruines", "outcomes": [
				{"w": 3, "text": "Sous une dalle, un coffret de chandeliers d'argent.", "gold": 100},
				{"w": 2, "text": "Un effondrement : deux hommes sont blessés dans la poussière.", "hp_one": -14},
				{"w": 1, "text": "Les ruines sont habitées : des brigands vous attendaient.", "battle": {"type": "b", "d": 1}},
			]},
			{"id": "camp", "label": "S'y abriter pour la nuit (1 jour)", "outcomes": [{"w": 1, "text": "Un abri de pierre sous un ciel noir. Chacun repart reposé.", "days": 1, "hp_all": 10}]},
			{"id": "pass", "label": "Passer son chemin", "outcomes": [{"w": 1, "text": "Mieux vaut laisser les ruines aux fantômes."}]},
		],
	},
	{
		"id": "drowned", "title": "Noyé dans le gué",
		"text": "Un cadavre gonflé flotte contre les roseaux. Il porte une bonne cotte, et à sa ceinture, un pli cacheté.",
		"choices": [
			{"id": "loot", "label": "Prendre la cotte et le pli", "outcomes": [
				{"w": 3, "text": "Le pli était une lettre de change. Le banquier de la ville la rachètera.", "gold": 85},
				{"w": 1, "text": "La cotte est vérolée. Plusieurs hommes en pâtissent.", "hp_all": -5},
			]},
			{"id": "bury", "label": "Lui donner une sépulture (1 jour)", "outcomes": [{"w": 1, "text": "Un prêtre de passage vous bénit pour ce geste.", "days": 1, "renown": 5}]},
			{"id": "pass", "label": "Passer", "outcomes": [{"w": 1, "text": "Le courant le reprend et l'emporte."}]},
		],
	},
	{
		"id": "poacher", "title": "Braconnier acculé",
		"text": "Un homme accroupi dans un fossé tient un daim sur ses épaules. Les gardes du seigneur battent le bois non loin.",
		"choices": [
			{"id": "hide", "label": "Le cacher dans le chariot", "outcomes": [
				{"w": 2, "text": "Les gardes passent. Il vous offre un bon morceau de venaison.", "hp_all": 8},
				{"w": 1, "text": "Un garde en sait plus qu'il n'en dit. Explication tendue.", "renown": -4},
			]},
			{"id": "hire", "label": "Lui proposer de se joindre à la compagnie", "outcomes": [
				{"w": 2, "text": "Il lance son daim dans les fourrés et vous suit.", "recruit": "braconnier"},
				{"w": 1, "text": "Il préfère sa liberté. Il vous laisse seulement un conseil sur la route."},
			]},
			{"id": "give", "label": "Le livrer aux gardes", "outcomes": [{"w": 1, "text": "Les gardes vous remercient. L'homme crache à vos pieds.", "gold": 30, "renown": -3}]},
		],
	},
	{
		"id": "plague_cart", "title": "Charrette de pestiférés",
		"text": "Une charrette couverte avance au pas, un chiffon noué sur le visage du conducteur. L'odeur est écœurante.",
		"choices": [
			{"id": "keep_away", "label": "S'écarter largement (1 jour)", "outcomes": [{"w": 1, "text": "Vous contournez les champs par prudence.", "days": 1}]},
			{"id": "help", "label": "Aider à creuser une fosse", "outcomes": [
				{"w": 2, "text": "Un dur labeur. Les familles gardent mémoire de votre aide.", "hp_all": -4, "renown": 8},
				{"w": 1, "text": "La fièvre, ou la fatigue : un homme s'effondre.", "hp_one": -20, "renown": 8},
			]},
			{"id": "pass", "label": "Passer sous le vent", "outcomes": [{"w": 1, "text": "Vous vous lavez à la prochaine source, sans un mot."}]},
		],
	},
	{
		"id": "duel", "title": "Défi en duel",
		"text": "Un champion de village, torse nu sur la place, défie la compagnie : « Un seul de vous contre moi, pour une bourse ! »",
		"choices": [
			{"id": "accept", "label": "Envoyer votre meilleur homme", "outcomes": [
				{"w": 3, "text": "L'affaire est rondement menée. La foule applaudit à contrecœur.", "gold": 80, "renown": 6, "xp_all": 2},
				{"w": 2, "text": "Le champion tient bon. Votre homme finit au sol, la mâchoire démise.", "hp_one": -16, "renown": -2},
			]},
			{"id": "bet", "label": "Parier sur le champion (30 couronnes)", "cost": 30, "outcomes": [
				{"w": 1, "text": "Il gagne, vous aussi.", "gold": 70},
				{"w": 1, "text": "Il perd. Les couronnes aussi."},
			]},
			{"id": "pass", "label": "Décliner poliment", "outcomes": [{"w": 1, "text": "On rit un peu de vous. Un peu."}]},
		],
	},
	{
		"id": "deserters_camp", "title": "Soldats en maraude",
		"text": "Une troupe de soldats en loques fouille un hameau. Leur capitaine vous remarque et lève la main : « Compagnons, pas d'histoire. »",
		"choices": [
			{"id": "talk", "label": "Négocier un passage en paix", "outcomes": [
				{"w": 2, "text": "On trinque. Ils vous cèdent même un peu de leur butin.", "gold": 40},
				{"w": 1, "text": "La discussion tourne vinaigre : on sort les lames.", "battle": {"type": "b", "d": 1}},
			]},
			{"id": "protect", "label": "Protéger le hameau", "outcomes": [
				{"w": 1, "text": "Vos lames sortent. Les maraudeurs cherchent noise.", "battle": {"type": "b", "d": 2}, "renown": 4},
			]},
			{"id": "pass", "label": "Ne pas s'en mêler", "outcomes": [{"w": 1, "text": "Vous passez la tête basse. Les paysans murmurent."}]},
		],
	},
	{
		"id": "smith", "title": "Forgeron itinérant",
		"text": "Un forgeron installe son enclume sur le bas-côté. Il cogne une lame rouge, la trempe, la brandit. « Qui a du métal à redresser ? »",
		"choices": [
			{"id": "repair", "label": "Faire réparer le matériel (50 couronnes)", "cost": 50, "outcomes": [
				{"w": 1, "text": "Des coups précis, des étincelles : tout est remis à neuf.", "repair": true},
			]},
			{"id": "help", "label": "L'aider au soufflet contre menue monnaie (1 jour)", "outcomes": [
				{"w": 2, "text": "Il vous rémunère de quelques pièces et de précieux conseils.", "days": 1, "gold": 35, "xp_all": 3},
				{"w": 1, "text": "Un éclat de métal fait sauter la flamme : une brûlure.", "days": 1, "gold": 35, "hp_one": -8},
			]},
			{"id": "pass", "label": "Passer", "outcomes": [{"w": 1, "text": "Le marteau reprend sa chanson derrière vous."}]},
		],
	},
	{
		"id": "orphan_mill", "title": "Moulin hanté",
		"text": "Un meunier apeuré vous arrête. « Depuis trois nuits, on gratte sous le moulin. Faites-moi taire cette chose, et je vous paie. »",
		"choices": [
			{"id": "inspect", "label": "Inspecter les caves", "outcomes": [
				{"w": 2, "text": "Des rats gros comme des chats. Vous les chassez, il vous paie.", "gold": 60, "renown": 3},
				{"w": 1, "text": "Pas des rats : des goules sortent de la cave !", "battle": {"type": "g", "d": 1}},
			]},
			{"id": "sleep", "label": "Passer la nuit au moulin (1 jour)", "outcomes": [
				{"w": 1, "text": "Rien ne bouge, mais le meunier dort enfin. Vous êtes nourris et logés.", "days": 1, "hp_all": 10},
			]},
			{"id": "pass", "label": "Passer", "outcomes": [{"w": 1, "text": "Il se signe en vous regardant partir."}]},
		],
	},
	{
		"id": "stray_horse", "title": "Cheval sans cavalier",
		"text": "Un cheval sellé broute au bord du chemin. Ni cavalier ni blessure, seulement du sang sur la bride.",
		"choices": [
			{"id": "take", "label": "Le prendre avec ses fontes", "outcomes": [
				{"w": 2, "text": "Dans les fontes : des vivres, une bourse, un livre d'heures.", "gold": 65, "hp_all": 4},
				{"w": 1, "text": "Le cavalier revient avec ses amis, peu enclins à plaisanter.", "battle": {"type": "b", "d": 1}},
			]},
			{"id": "search", "label": "Chercher le cavalier (1 jour)", "outcomes": [
				{"w": 2, "text": "Vous le trouvez blessé sous un arbre. Il paiera bien sa dette.", "days": 1, "gold": 55, "renown": 6},
				{"w": 1, "text": "Vous ne trouvez que ses ennemis.", "days": 1, "battle": {"type": "b", "d": 1}},
			]},
			{"id": "pass", "label": "Laisser le cheval", "outcomes": [{"w": 1, "text": "Le cheval vous regarde partir, sans mot dire."}]},
		],
	},
]


## Événements de la vie de la compagnie (vivres, querelles, amitiés), tirés comme les autres.
const CAMP_DEFS: Array = [
	{
		"id": "quarrel", "title": "Querelle au bivouac",
		"text": "Deux de vos hommes en viennent aux mains pour une part de lard. Le reste de la troupe fait cercle.",
		"choices": [
			{"id": "split", "label": "Les séparer et les punir", "outcomes": [{"w": 2, "text": "Quelques jours de corvée calment les esprits.", "morale": -1}, {"w": 1, "text": "L'affaire laisse des rancunes.", "bond": "rivals"}]},
			{"id": "duel", "label": "Les laisser régler ça", "outcomes": [{"w": 1, "text": "Les poings parlent. L'un des deux se jure de ne jamais pardonner.", "bond": "rivals", "hp_one": -6}]},
		],
	},
	{
		"id": "songs", "title": "Veillée chantée",
		"text": "Autour du feu, un vieux refrain fait le tour de la troupe. Deux hommes finissent la nuit à trinquer ensemble.",
		"choices": [
			{"id": "join", "label": "Chanter avec eux", "outcomes": [{"w": 1, "text": "La nuit est courte, le moral meilleur.", "bond": "friends", "morale": 4}]},
		],
	},
	{
		"id": "hunt_game", "title": "Gibier en vue",
		"text": "Un cerf paît à la lisière du bois. Les braconniers de la troupe se lèchent déjà les babines.",
		"choices": [
			{"id": "hunt", "label": "Chasser (1 jour)", "outcomes": [{"w": 3, "text": "Le cerf finit à la broche. On mangera bien.", "days": 1, "food": 18, "morale": 3}, {"w": 1, "text": "La bête s'échappe, une heure perdue.", "days": 1}]},
			{"id": "pass", "label": "Continuer", "outcomes": [{"w": 1, "text": "Le cerf lève la tête et disparaît."}]},
		],
	},
	{
		"id": "spoiled", "title": "Vivres gâtés",
		"text": "L'humidité a eu raison d'un sac de provisions : le lard est vert, le pain moisi.",
		"choices": [
			{"id": "sort", "label": "Trier ce qui reste", "outcomes": [{"w": 1, "text": "On sauve ce qu'on peut.", "food": -6}]},
		],
	},
]


## Rencontres des points d'intérêt de la carte (ruines, sanctuaires, camps abandonnés, tours de guet, grottes) : une par visite,
## tirées parmi celles du type (`poi`). Elles ne tombent jamais en route : voir `poi_pick` et `Game.visit_poi`.
const POI_DEFS: Array = [
	{
		"id": "poi_ruins_a", "poi": "ruins", "title": "Ruines : la crypte effondrée",
		"text": "Sous un pan de mur écroulé, un escalier s'enfonce dans le noir. Des armes rouillées jonchent les premières marches.",
		"choices": [
			{"id": "dig", "label": "Descendre fouiller la crypte", "outcomes": [
				{"w": 3, "text": "Une cassette scellée : quelques couronnes d'un autre âge.", "gold": 140},
				{"w": 2, "text": "Le plafond cède : un homme est blessé, mais on sauve de quoi réparer les armures.", "hp_one": -10, "repair": true},
				{"w": 1, "text": "Des ossements se redressent dans le noir !", "battle": {"type": "u", "d": 1}},
			]},
			{"id": "camp", "label": "Y passer la nuit à l'abri des murs (1 jour)", "outcomes": [{"w": 1, "text": "Les vieilles pierres coupent le vent. Chacun reprend des forces.", "days": 1, "hp_all": 8}]},
			{"id": "pass", "label": "Passer son chemin", "outcomes": [{"w": 1, "text": "Mieux vaut ne pas réveiller ce qui dort là."}]},
		],
	},
	{
		"id": "poi_ruins_b", "poi": "ruins", "title": "Ruines : les graffitis du déserteur",
		"text": "Sur un mur noirci, un soldat a gravé une carte grossière, avec une croix : « Ici, ma solde. »",
		"choices": [
			{"id": "follow", "label": "Suivre la carte", "outcomes": [
				{"w": 2, "text": "La croix désigne un tas de pierres. Dessous : une bourse moisie, mais pleine.", "gold": 110},
				{"w": 1, "text": "Un piège à loup se referme sur la jambe d'un homme.", "hp_one": -14},
			]},
			{"id": "copy", "label": "Recopier la carte pour la vendre en ville", "outcomes": [{"w": 1, "text": "Un érudit paiera cher ce croquis. Pour l'heure, la nouvelle fait parler de vous.", "renown": 6}]},
		],
	},
	{
		"id": "poi_shrine_a", "poi": "shrine", "title": "Sanctuaire : la source bénite",
		"text": "Un filet d'eau claire coule d'une stèle moussue. Des rubans de laine pendent aux branches : on prie ici depuis longtemps.",
		"choices": [
			{"id": "drink", "label": "Boire et laver les blessures", "outcomes": [
				{"w": 3, "text": "L'eau est glaciale et étrangement revigorante.", "hp_all": 14},
				{"w": 1, "text": "L'eau a un goût de fer ; la fatigue, elle, ne revient pas.", "hp_all": 6, "xp_all": 8},
			]},
			{"id": "offer", "label": "Laisser une offrande (40 couronnes)", "cost": 40, "outcomes": [
				{"w": 2, "text": "Un sentiment de paix descend sur la troupe. La route sera clémente.", "morale": 8},
				{"w": 1, "text": "Une vieille prêtresse sort de l'ombre et bénit vos armes.", "renown": 8, "xp_all": 10},
			]},
			{"id": "pass", "label": "Respecter le lieu et poursuivre", "outcomes": [{"w": 1, "text": "Quelques hommes se signent en passant."}]},
		],
	},
	{
		"id": "poi_shrine_b", "poi": "shrine", "title": "Sanctuaire : l'ermite",
		"text": "Un vieillard maigre garde la stèle depuis, dit-il, quarante hivers. Il demande du pain, et promet de la sagesse.",
		"choices": [
			{"id": "bread", "label": "Partager vos vivres (−8 rations)", "outcomes": [
				{"w": 2, "text": "L'ermite parle des routes, des gués, des bêtes. Vos hommes écoutent, et retiennent.", "food": -8, "xp_all": 14},
				{"w": 1, "text": "Le vieillard tire de sa besace une vieille bague d'argent : « Pour celui qui partage. »", "food": -8, "gold": 120},
			]},
			{"id": "rob", "label": "Le dépouiller", "outcomes": [{"w": 1, "text": "Il n'avait rien. La honte pèse sur la troupe.", "renown": -6, "morale": -6}]},
			{"id": "pass", "label": "Passer son chemin", "outcomes": [{"w": 1, "text": "L'ermite hausse les épaules et se rassoit."}]},
		],
	},
	{
		"id": "poi_camp_a", "poi": "camp", "title": "Camp abandonné : le convoi pillé",
		"text": "Des chariots brisés, des feux froids. Quelqu'un est parti en hâte, laissant des caisses éventrées.",
		"choices": [
			{"id": "search", "label": "Fouiller les chariots", "outcomes": [
				{"w": 3, "text": "Entre deux caisses : des vivres encore sains et quelques pièces.", "food": 14, "gold": 60},
				{"w": 1, "text": "Une caisse piégée explose : un homme est brûlé.", "hp_one": -12},
				{"w": 1, "text": "Les pillards reviennent chercher leur butin !", "battle": {"type": "b", "d": 1}},
			]},
			{"id": "pass", "label": "Ne pas s'attarder", "outcomes": [{"w": 1, "text": "Mieux vaut ne pas être là quand les propriétaires reviendront."}]},
		],
	},
	{
		"id": "poi_camp_b", "poi": "camp", "title": "Camp abandonné : l'infirmerie de fortune",
		"text": "Des paillasses alignées sous une toile, des bandages propres, une marmite encore tiède. Un camp de blessés, déserté depuis peu.",
		"choices": [
			{"id": "rest", "label": "Soigner les hommes (1 jour)", "outcomes": [{"w": 1, "text": "Les bandages, l'herbe à plaies, une nuit d'abri : tout le monde s'en trouve mieux.", "days": 1, "hp_all": 16}]},
			{"id": "take", "label": "Emporter le matériel", "outcomes": [{"w": 1, "text": "Fil, aiguilles et rivets : de quoi réparer les cottes en route.", "repair": true}]},
		],
	},
	{
		"id": "poi_tower_a", "poi": "tower", "title": "Tour de guet : la vue d'en haut",
		"text": "La tour est vide, mais l'escalier tient encore. Du sommet, on voit tout le pays alentour.",
		"choices": [
			{"id": "climb", "label": "Monter observer les routes", "outcomes": [
				{"w": 3, "text": "Du haut, vous repérez les sentiers sûrs et les fumées suspectes. La compagnie y gagne en prudence.", "xp_all": 12},
				{"w": 1, "text": "Une planche cède sous un homme : belle chute.", "hp_one": -9},
			]},
			{"id": "pass", "label": "Passer son chemin", "outcomes": [{"w": 1, "text": "La tour garde ses secrets."}]},
		],
	},
	{
		"id": "poi_tower_b", "poi": "tower", "title": "Tour de guet : le guetteur oublié",
		"text": "Un vieux soldat mal rasé garde la tour au nom d'un seigneur mort depuis des années. Il vous prend pour des relèves.",
		"choices": [
			{"id": "play", "label": "Jouer les relèves et lui demander ses cartes", "outcomes": [
				{"w": 2, "text": "Content d'être enfin relevé, le vieux vous confie ses notes de patrouille et sa solde cachée.", "gold": 90, "renown": 4},
			]},
			{"id": "recruit", "label": "Lui proposer de vous suivre", "outcomes": [
				{"w": 1, "text": "Le vieux soldat boucle son sac : « Enfin, un capitaine ! »", "recruit": "deserteur"},
				{"w": 1, "text": "Il refuse en riant et vous offre une gourde de vin.", "morale": 5},
			]},
			{"id": "pass", "label": "Ne rien dire et partir", "outcomes": [{"w": 1, "text": "Le vieux salue encore un moment, seul sur sa tour."}]},
		],
	},
	{
		"id": "poi_cave_a", "poi": "cave", "title": "Grotte : l'antre du loup",
		"text": "Des os rongés, des traces de pattes. Quelque chose a élu domicile ici, et vous sentez son haleine dans la pénombre.",
		"choices": [
			{"id": "enter", "label": "Entrer, armes en main", "outcomes": [
				{"w": 2, "text": "Une portée de louveteaux et des restes de voyageurs : on récupère quelques pièces.", "gold": 80},
				{"w": 2, "text": "La mère rentre de la chasse !", "battle": {"type": "m", "d": 1}},
			]},
			{"id": "smoke", "label": "Enfumer l'entrée (1 jour)", "outcomes": [{"w": 1, "text": "Les bêtes fuient dans la nuit. La grotte est à vous : on s'y repose.", "days": 1, "hp_all": 8}]},
			{"id": "pass", "label": "Laisser dormir les loups", "outcomes": [{"w": 1, "text": "Vous reculez sans bruit."}]},
		],
	},
	{
		"id": "poi_cave_b", "poi": "cave", "title": "Grotte : la veine du mineur fou",
		"text": "Des étais à demi pourris, une lanterne éteinte, des coups de pioche sur la paroi. Un filon luit encore dans la roche.",
		"choices": [
			{"id": "mine", "label": "Piocher un jour dans le filon (1 jour)", "outcomes": [
				{"w": 3, "text": "Du minerai, du vrai : un forgeron de passage vous le rachètera.", "days": 1, "gold": 150},
				{"w": 1, "text": "Un éboulement. Personne n'est mort, mais la journée est perdue.", "days": 1, "hp_one": -12},
			]},
			{"id": "pass", "label": "Ne pas toucher aux étais", "outcomes": [{"w": 1, "text": "La prudence est la mère des vieux mercenaires."}]},
		],
	},
]


## Une rencontre au hasard pour un point d'intérêt de type `kind` (ruins, shrine, camp, tower, cave).
static func poi_pick(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = POI_DEFS.filter(func(e: Dictionary) -> bool: return str(e["poi"]) == kind)
	if pool.is_empty():
		return {}
	return pool[rng.randi() % pool.size()]


static func get_def(id: String) -> Dictionary:
	for e in POI_DEFS:
		if e["id"] == id:
			return e
	for e in CAMP_DEFS:
		if e["id"] == id:
			return e
	for e in DEFS:
		if e["id"] == id:
			return e
	for sid in Data.STORIES:
		for st in Data.STORIES[sid]["steps"]:
			if st["id"] == id:
				return st
	return {}


## Histoire (clé de Data.STORIES) dont `step_id` est une étape, ou "".
static func story_of(step_id: String) -> String:
	for sid in Data.STORIES:
		for st in Data.STORIES[sid]["steps"]:
			if st["id"] == step_id:
				return str(sid)
	return ""


## Tire un événement au hasard (hors le dernier, pour éviter les répétitions).
## `flags` (Game.story_flags) et `day` : les histoires pas encore commencées et assez tardives entrent aussi dans le tirage (à poids double).
static func pick(rng: RandomNumberGenerator, last_id: String = "", flags: Dictionary = {}, day: int = 0) -> Dictionary:
	var pool: Array = []
	for e in DEFS + CAMP_DEFS:
		if e["id"] != last_id:
			pool.append(e)
	if day > 0:
		for sid in Data.STORIES:
			var story: Dictionary = Data.STORIES[sid]
			if not flags.has("story_" + str(sid)) and day >= int(story["min_day"]) and story["start"] != last_id:
				var first: Dictionary = get_def(str(story["start"]))
				pool.append(first)
				pool.append(first)
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
