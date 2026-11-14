class_name ScenariosData
extends RefCounted
## Tables des scénarios et défis (texte original). Aucune logique ici : voir core/scenarios.gd.
##
## Un scénario :
##   n, tag (accroche courte), desc (présentation), intro (nouvelle du premier jour), rule (règle spéciale, une phrase)
##   men : origines de départ (clés de Data.BG) ; gold : couronnes de départ (-1 = celles de la difficulté)
##   gear : "" ou "noble" (tenue bien équipée) ; wage_mult : multiplicateur de solde des hommes de départ
##   provisions / morale : bonus de départ (vivres, moral de compagnie)
##   hunt_only : tous les contrats proposés deviennent des chasses au chef (prime × hunt_pay)
##   days : limite de jours ; goal : {stat, target, label} — stat = "renown" | "gold" | une clé de Game.stats
##   win / lose : texte des écrans de fin

const ORDER: Array = ["survivants", "nobles", "course", "chasseurs"]

const SCENARIOS: Dictionary = {
	"survivants": {
		"n": "Les trois survivants",
		"tag": "Trois hommes, peu d'or, 90 jours.",
		"desc": "Votre ancienne compagnie a été fauchée dans un fossé de la route royale. Il reste trois hommes, une bourse maigre et un nom à relever avant que l'hiver ne ferme les chemins.",
		"intro": "Trois hommes sortent du fossé, couverts de boue. Le reste de la compagnie y est resté. Il faudra tout rebâtir.",
		"rule": "Vous partez avec des vivres en plus, mais sans personne pour tenir la ligne.",
		"men": ["milicien", "bucheron", "braconnier"], "gold": 350, "gear": "", "wage_mult": 1.0,
		"provisions": 20, "morale": 0, "hunt_only": false, "hunt_pay": 1.0,
		"days": 90, "goal": {"stat": "renown", "target": 150, "label": "Renom"},
		"win": "Trois lames sont devenues une compagnie. On dit désormais que le Corbeau ne tombe jamais deux fois au même endroit.",
		"lose": "L'hiver est venu et le nom n'est pas relevé. Les survivants se dispersent, l'un après l'autre, sans bruit.",
	},
	"nobles": {
		"n": "Compagnie de nobles",
		"tag": "Équipés comme des seigneurs, ruinés comme des mendiants.",
		"desc": "Des cadets de grande maison, armés de pied en cap, ont fondé une compagnie par ennui et par orgueil. Leurs armures sont belles. Leur solde est une insulte au bon sens.",
		"intro": "Les cadets de bonne maison astiquent leurs hauberts. Le trésorier, lui, pleure sur les livres de comptes.",
		"rule": "Les hommes de départ réclament une solde presque doublée, mais portent mailles, casque et bouclier.",
		"men": ["reitre", "reitre", "deserteur", "milicien", "reitre"], "gold": 150, "gear": "noble", "wage_mult": 1.8,
		"provisions": 0, "morale": 10, "hunt_only": false, "hunt_pay": 1.0,
		"days": 120, "goal": {"stat": "renown", "target": 250, "label": "Renom"},
		"win": "Les blasons ont payé leurs dettes dans le sang des autres. Les chansons parlent de vous, et la famille a cessé de nier votre existence.",
		"lose": "Les créanciers ont saisi les hauberts. La compagnie finit en cortège de valets, aux ordres de ceux qu'elle méprisait.",
	},
	"course": {
		"n": "Course contre la montre",
		"tag": "Cinq contrats en 60 jours.",
		"desc": "Un commanditaire anonyme parie sur votre compagnie : cinq contrats honorés en soixante jours, sans quoi son or ira à un concurrent. Chaque journée perdue sur la route se paie.",
		"intro": "Une bourse scellée vous attend avec un billet : cinq contrats, soixante jours. Le sablier est déjà retourné.",
		"rule": "Vous touchez quelques vivres de plus ; ne perdez pas de temps à vous reposer.",
		"men": ["milicien", "bucheron", "braconnier", "fermier", "deserteur"], "gold": -1, "gear": "", "wage_mult": 1.0,
		"provisions": 10, "morale": 0, "hunt_only": false, "hunt_pay": 1.0,
		"days": 60, "goal": {"stat": "contracts_done", "target": 5, "label": "Contrats honorés"},
		"win": "Le sablier s'est vidé trop tard pour vos rivaux. Le parieur inconnu envoie sa bourse, et un second billet.",
		"lose": "Le dernier grain est tombé. Le pari est perdu, et la rumeur dit que votre compagnie préfère la taverne à la route.",
	},
	"chasseurs": {
		"n": "Chasseurs de primes",
		"tag": "Rien que des chasses au chef, mieux payées.",
		"desc": "Les seigneurs ne veulent plus de simples escarmouches : ils paient pour la tête des chefs de guerre. Vous ne vivrez que de ces primes, grasses mais dangereuses.",
		"intro": "Sur la place, les crieurs annoncent des primes pour des têtes de chefs. Vous n'accepterez rien d'autre.",
		"rule": "Tous les contrats proposés sont des chasses au chef, payées un tiers de plus.",
		"men": ["braconnier", "braconnier", "milicien", "bucheron", "fermier"], "gold": 700, "gear": "", "wage_mult": 1.0,
		"provisions": 0, "morale": 0, "hunt_only": true, "hunt_pay": 1.3,
		"days": 100, "goal": {"stat": "hunts_done", "target": 4, "label": "Chefs abattus"},
		"win": "Quatre têtes de chefs ornent la salle d'un seigneur reconnaissant. Plus personne ne vous demande de preuve.",
		"lose": "Les chefs courent toujours. Les primes sont passées à d'autres, plus rapides ou plus chanceux.",
	},
}
