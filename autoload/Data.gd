extends Node
## Tables de données du jeu (armes, armures, origines, ennemis, noms).
## Portées du prototype `prototype/corbeau.html`.

const WPN: Dictionary = {
	"gourdin": {"n": "Gourdin", "min": 20, "max": 30, "arm": 0.9, "ign": 0.4, "ap": 4, "fat": 10, "hit": 0, "rng": 1, "h1": true, "ranged": false, "price": 40, "note": "Frappe sourde, traverse un peu l'armure."},
	"fourche": {"n": "Fourche", "min": 20, "max": 30, "arm": 0.7, "ign": 0.25, "ap": 6, "fat": 12, "hit": 5, "rng": 2, "h1": false, "ranged": false, "price": 70, "note": "Allonge : frappe à 2 cases. Deux mains."},
	"lance": {"n": "Lance", "min": 25, "max": 30, "arm": 0.9, "ign": 0.25, "ap": 4, "fat": 10, "hit": 20, "rng": 1, "h1": true, "ranged": false, "price": 250, "note": "+20 % au toucher."},
	"hache": {"n": "Hache", "min": 30, "max": 45, "arm": 1.4, "ign": 0.1, "ap": 4, "fat": 12, "hit": 0, "rng": 1, "h1": true, "ranged": false, "price": 320, "note": "Détruit l'armure."},
	"masse": {"n": "Masse d'armes", "min": 30, "max": 40, "arm": 1.1, "ign": 0.4, "ap": 4, "fat": 12, "hit": 0, "rng": 1, "h1": true, "ranged": false, "price": 380, "note": "Passe en partie à travers l'armure."},
	"epee": {"n": "Épée d'armes", "min": 35, "max": 45, "arm": 0.8, "ign": 0.2, "ap": 4, "fat": 10, "hit": 10, "rng": 1, "h1": true, "ranged": false, "price": 650, "note": "+10 % au toucher, dégâts réguliers."},
	"arc": {"n": "Arc de chasse", "min": 30, "max": 50, "arm": 0.55, "ign": 0.35, "ap": 4, "fat": 12, "hit": 0, "rng": 6, "h1": false, "ranged": true, "price": 280, "note": "Portée 6. Deux mains."},
	"arbalete": {"n": "Arbalète", "min": 40, "max": 60, "arm": 0.7, "ign": 0.4, "ap": 7, "fat": 14, "hit": 0, "rng": 6, "h1": false, "ranged": true, "price": 560, "note": "Portée 6. Dégâts élevés, mais la recharge coûte 7 PA. Deux mains."},
	"hallebarde": {"n": "Hallebarde", "min": 30, "max": 42, "arm": 1.1, "ign": 0.25, "ap": 6, "fat": 14, "hit": 0, "rng": 2, "h1": false, "ranged": false, "price": 520, "vs_shield": 10, "note": "Frappe à 2 cases, +10 % au toucher contre un bouclier. Deux mains."},
	"fleau": {"n": "Fléau d'armes", "min": 30, "max": 45, "arm": 0.6, "ign": 0.4, "ap": 5, "fat": 13, "hit": 0, "rng": 1, "h1": true, "ranged": false, "price": 360, "shield_ign": 10, "note": "Contourne en partie les boucliers. Faible contre l'armure lourde."},
	"javelot": {"n": "Javelots", "min": 25, "max": 40, "arm": 0.8, "ign": 0.25, "ap": 4, "fat": 10, "hit": 0, "rng": 4, "h1": true, "ranged": true, "price": 150, "ammo": 3, "note": "Portée 4, 3 lancers par bataille. Une main."},
	"griffes": {"n": "Griffes", "min": 20, "max": 35, "arm": 0.6, "ign": 0.15, "ap": 4, "fat": 8, "hit": 0, "rng": 1, "h1": false, "ranged": false, "price": 0, "note": ""},
	"poings": {"n": "Poings nus", "min": 5, "max": 10, "arm": 0.2, "ign": 0.1, "ap": 4, "fat": 8, "hit": 0, "rng": 1, "h1": true, "ranged": false, "price": 0, "note": "Sans arme : on frappe à mains nues."},
	"griffesL": {"n": "Griffes énormes", "min": 35, "max": 55, "arm": 0.8, "ign": 0.15, "ap": 4, "fat": 10, "hit": 0, "rng": 1, "h1": false, "ranged": false, "price": 0, "note": ""},
	# Armes uniques (voir UNIQUES) : statistiques fixes, supérieures à leur modèle.
	"u_epee_corbeau": {"n": "Lame du Corbeau", "min": 38, "max": 50, "arm": 0.9, "ign": 0.25, "ap": 4, "fat": 10, "hit": 15, "rng": 1, "h1": true, "ranged": false, "price": 1700, "note": "Épée unique : +15 % au toucher."},
	"u_hache_fendcrane": {"n": "Fend-Crâne", "min": 35, "max": 52, "arm": 1.6, "ign": 0.1, "ap": 4, "fat": 12, "hit": 5, "rng": 1, "h1": true, "ranged": false, "price": 1500, "note": "Hache unique : broie l'armure."},
	"u_lance_aigle": {"n": "Lance de l'Aigle", "min": 28, "max": 36, "arm": 1.0, "ign": 0.3, "ap": 4, "fat": 9, "hit": 30, "rng": 1, "h1": true, "ranged": false, "price": 1300, "note": "Lance unique : +30 % au toucher."},
	"u_masse_glas": {"n": "Glas de fer", "min": 34, "max": 46, "arm": 1.2, "ign": 0.45, "ap": 4, "fat": 12, "hit": 5, "rng": 1, "h1": true, "ranged": false, "price": 1600, "note": "Masse unique : traverse l'armure."},
	"u_arc_ronce": {"n": "Arc des Ronces", "min": 34, "max": 54, "arm": 0.6, "ign": 0.4, "ap": 4, "fat": 11, "hit": 5, "rng": 7, "h1": false, "ranged": true, "price": 1450, "note": "Arc unique : portée 7."},
}

const HEAD: Dictionary = {
	"none": {"n": "Tête nue", "a": 0, "w": 0, "price": 0},
	"capuchon": {"n": "Capuchon matelassé", "a": 30, "w": 0, "price": 60},
	"casque": {"n": "Casque à nasal", "a": 90, "w": 5, "price": 280},
	"heaume": {"n": "Heaume fermé", "a": 160, "w": 10, "price": 750},
	# Objets uniques (voir UNIQUES)
	"u_casque_loup": {"n": "Casque du Loup gris", "a": 125, "w": 4, "price": 1400},
	"u_heaume_veilleur": {"n": "Heaume du Veilleur", "a": 195, "w": 9, "price": 2200},
}

const BODY: Dictionary = {
	"none": {"n": "Rien", "a": 0, "w": 0, "price": 0},
	"tunique": {"n": "Tunique de lin", "a": 20, "w": 0, "price": 30},
	"gambison": {"n": "Gambison", "a": 65, "w": 6, "price": 220},
	"mailles": {"n": "Haubert de mailles", "a": 130, "w": 14, "price": 700},
	"brigandine": {"n": "Brigandine", "a": 190, "w": 22, "price": 1250},
	# Objets uniques (voir UNIQUES)
	"u_cotte_nuit": {"n": "Cotte de la Nuit", "a": 165, "w": 12, "price": 1900},
	"u_brigandine_roi": {"n": "Brigandine du Roi déchu", "a": 235, "w": 20, "price": 2600},
}

const SHIELD: Dictionary = {"n": "Bouclier rond", "price": 120, "w": 4, "dur": 40}

# --- Inventaire (core/inventory.gd) ---
const STASH_SIZE: int = 32  ## emplacements de la réserve commune ; le trop-plein est vendu d'office (prix de base de revente)
const BAG_SLOTS: int = 2  ## emplacements de sac par homme (armes et boucliers de rechange)
const SWAP_AP: int = 4  ## changer d'arme en bataille
const SWAP_FAT: int = 4

# --- Usure de l'équipement ---
## Durabilité d'une arme (un champ "dur" dans Data.WPN la remplace). Bouclier : Data.SHIELD["dur"].
const WEAPON_DUR: int = 60
const BROKEN_WEAPON_DMG: float = 0.75  ## multiplicateur de dégâts d'une arme ébréchée (durabilité 0)
const HEAVY_ARMOR_WEAR: int = 100  ## armure de la zone touchée à partir de laquelle l'arme s'use deux fois plus
const REPAIR_GEAR_RATE: float = 0.25  ## réparer à fond une arme ou un bouclier coûte cette part de son prix
const WORN_LOOT_RATE: float = 0.75  ## les armes et boucliers ramassés sur l'ennemi sont de seconde main

## Origines des recrues. Plages [min, max]. `w` = armes possibles, `sh` = proba de bouclier,
## `wt` = poids dans le tirage des recrues.
const BG: Dictionary = {
	"milicien": {"n": "Ancien milicien", "hp": [50, 60], "fat": [90, 100], "res": [40, 50], "mSk": [50, 58], "rSk": [30, 40], "mDef": [3, 8], "rDef": [2, 6], "ini": [100, 110], "w": ["lance"], "sh": 1.0, "head": ["capuchon"], "body": ["gambison"], "wage": 12, "price": 220, "wt": 3},
	"bucheron": {"n": "Bûcheron", "hp": [60, 70], "fat": [105, 115], "res": [35, 45], "mSk": [50, 58], "rSk": [25, 35], "mDef": [0, 5], "rDef": [0, 5], "ini": [95, 105], "w": ["hache"], "sh": 0.0, "head": ["none"], "body": ["tunique"], "wage": 11, "price": 200, "wt": 3},
	"braconnier": {"n": "Braconnier", "hp": [45, 55], "fat": [95, 105], "res": [35, 45], "mSk": [40, 48], "rSk": [56, 66], "mDef": [0, 5], "rDef": [3, 8], "ini": [110, 125], "w": ["arc"], "sh": 0.0, "head": ["capuchon"], "body": ["tunique"], "wage": 12, "price": 210, "wt": 3},
	"fermier": {"n": "Fermier", "hp": [58, 68], "fat": [100, 112], "res": [35, 45], "mSk": [45, 52], "rSk": [30, 40], "mDef": [0, 5], "rDef": [0, 5], "ini": [95, 105], "w": ["fourche"], "sh": 0.0, "head": ["none"], "body": ["tunique"], "wage": 7, "price": 95, "wt": 4},
	"mendiant": {"n": "Mendiant", "hp": [40, 50], "fat": [80, 90], "res": [25, 35], "mSk": [40, 47], "rSk": [30, 38], "mDef": [0, 4], "rDef": [0, 4], "ini": [100, 110], "w": ["gourdin"], "sh": 0.0, "head": ["none"], "body": ["tunique"], "wage": 4, "price": 45, "wt": 3},
	"deserteur": {"n": "Déserteur", "hp": [55, 62], "fat": [95, 105], "res": [28, 38], "mSk": [55, 62], "rSk": [35, 45], "mDef": [5, 10], "rDef": [5, 10], "ini": [100, 110], "w": ["masse"], "sh": 1.0, "head": ["casque"], "body": ["gambison"], "wage": 16, "price": 380, "wt": 2},
	"reitre": {"n": "Reître", "hp": [58, 66], "fat": [98, 108], "res": [50, 60], "mSk": [60, 68], "rSk": [40, 48], "mDef": [8, 14], "rDef": [6, 10], "ini": [102, 112], "w": ["epee"], "sh": 1.0, "head": ["casque"], "body": ["mailles"], "wage": 28, "price": 1100, "wt": 1},
}

## Ennemis. `fac` : "b" brigands, "g" goules.
const FOE: Dictionary = {
	"brigand": {"n": "Détrousseur", "fac": "b", "hp": [55, 65], "fat": [100, 110], "res": [40, 50], "mSk": [52, 58], "rSk": [30, 40], "mDef": [2, 8], "rDef": [2, 8], "ini": [95, 105], "w": ["gourdin", "fourche", "hache", "lance", "javelot"], "sh": 0.4, "head": ["none", "capuchon"], "body": ["tunique", "gambison"], "xp": 15, "leader": false},
	"archer": {"n": "Archer brigand", "fac": "b", "hp": [50, 58], "fat": [95, 105], "res": [38, 46], "mSk": [42, 48], "rSk": [52, 60], "mDef": [0, 5], "rDef": [3, 8], "ini": [105, 115], "w": ["arc", "arbalete"], "sh": 0.0, "head": ["capuchon"], "body": ["tunique"], "xp": 15, "leader": false},
	"balafre": {"n": "Balafré", "fac": "b", "hp": [70, 80], "fat": [110, 120], "res": [50, 60], "mSk": [60, 66], "rSk": [35, 45], "mDef": [8, 14], "rDef": [8, 12], "ini": [100, 108], "w": ["hache", "masse", "epee", "fleau"], "sh": 0.6, "head": ["casque"], "body": ["mailles"], "xp": 30, "leader": false},
	"chef": {"n": "Chef brigand", "fac": "b", "hp": [95, 110], "fat": [120, 130], "res": [65, 75], "mSk": [68, 75], "rSk": [40, 50], "mDef": [12, 18], "rDef": [10, 15], "ini": [105, 112], "w": ["epee"], "sh": 1.0, "head": ["heaume"], "body": ["mailles"], "xp": 60, "leader": true, "perks": ["spec_epee", "garde_ferme"]},
	"goule": {"n": "Goule", "fac": "g", "hp": [110, 130], "fat": [150, 150], "res": [48, 55], "mSk": [50, 55], "rSk": [0, 0], "mDef": [0, 5], "rDef": [0, 5], "ini": [110, 120], "w": ["griffes"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 25, "leader": false},
	"vorace": {"n": "Goule vorace", "fac": "g", "hp": [220, 240], "fat": [160, 160], "res": [65, 70], "mSk": [58, 64], "rSk": [0, 0], "mDef": [0, 5], "rDef": [0, 5], "ini": [90, 95], "w": ["griffesL"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 60, "leader": false},
	# Orcs ("o") : plus de PV, de défense et de compétence que les brigands.
	"orc_jeune": {"n": "Jeune orc", "fac": "o", "hp": [75, 90], "fat": [110, 120], "res": [45, 55], "mSk": [55, 62], "rSk": [30, 40], "mDef": [3, 9], "rDef": [3, 8], "ini": [95, 105], "w": ["gourdin", "hache", "lance"], "sh": 0.4, "head": ["none", "capuchon"], "body": ["tunique", "gambison"], "xp": 25, "leader": false},
	"orc_guerrier": {"n": "Guerrier orc", "fac": "o", "hp": [100, 115], "fat": [120, 130], "res": [55, 65], "mSk": [62, 68], "rSk": [30, 40], "mDef": [8, 14], "rDef": [6, 12], "ini": [90, 100], "w": ["hache", "masse", "epee", "hallebarde"], "sh": 0.6, "head": ["casque"], "body": ["gambison", "mailles"], "xp": 45, "leader": false},
	"berserker": {"n": "Berserker orc", "fac": "o", "hp": [110, 125], "fat": [130, 140], "res": [70, 80], "mSk": [66, 72], "rSk": [20, 30], "mDef": [0, 4], "rDef": [0, 4], "ini": [105, 115], "w": ["hache"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 50, "leader": false},
	"orc_chef": {"n": "Chef de guerre orc", "fac": "o", "hp": [160, 180], "fat": [140, 150], "res": [75, 85], "mSk": [72, 78], "rSk": [35, 45], "mDef": [14, 20], "rDef": [10, 15], "ini": [100, 108], "w": ["hache", "epee"], "sh": 1.0, "head": ["heaume"], "body": ["brigandine"], "xp": 100, "leader": true, "perks": ["cran", "spec_hache"]},
	# Morts-vivants ("u")
	"squelette": {"n": "Squelette", "fac": "u", "hp": [45, 55], "fat": [110, 120], "res": [80, 90], "mSk": [48, 56], "rSk": [30, 36], "mDef": [0, 6], "rDef": [10, 16], "ini": [100, 110], "w": ["lance", "epee", "gourdin"], "sh": 0.6, "head": ["none", "casque"], "body": ["none"], "xp": 20, "leader": false},
	"squelette_archer": {"n": "Squelette archer", "fac": "u", "hp": [40, 50], "fat": [100, 110], "res": [80, 90], "mSk": [40, 46], "rSk": [50, 58], "mDef": [0, 4], "rDef": [8, 14], "ini": [105, 115], "w": ["arc"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 20, "leader": false},
	"zombie": {"n": "Zombie", "fac": "u", "hp": [90, 110], "fat": [120, 130], "res": [90, 95], "mSk": [44, 50], "rSk": [0, 0], "mDef": [0, 0], "rDef": [0, 0], "ini": [60, 75], "w": ["griffes"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 20, "leader": false},
	"necro": {"n": "Nécromant", "fac": "u", "hp": [85, 100], "fat": [100, 110], "res": [75, 85], "mSk": [58, 64], "rSk": [40, 48], "mDef": [8, 14], "rDef": [10, 16], "ini": [105, 112], "w": ["masse"], "sh": 0.0, "head": ["capuchon"], "body": ["gambison"], "xp": 70, "leader": true, "perks": ["cran"]},
}

# --- Capacités actives (liées à l'arme ou au bouclier) ---
## `weapons` : armes qui l'ouvrent ([] = toute arme de mêlée avec `needs_shield`) ; `ap_extra` / `fat_extra` : coût en plus de celui de l'attaque
## (`ap` / `fat` : coût fixe à la place) ; `hit` : bonus au toucher ; `dmg` : multiplicateur de dégâts ; `armor` : multiplicateur de dégâts d'armure ;
## `morale` : modificateur du test de moral de la cible touchée ; `push` : repousse d'une case ; `stun` : la cible perd des PA à son prochain tour ;
## `expose` : la cible a −10 en défense jusqu'à la fin de son prochain tour ; `shield_break` : points d'usure retirés au bouclier adverse.
const ABILITIES: Dictionary = {
	"fente": {"n": "Fente", "weapons": ["epee"], "ap_extra": 1, "fat_extra": 4, "hit": 15, "d": "+15 % au toucher."},
	"fendre": {"n": "Fendre l'armure", "weapons": ["hache"], "ap_extra": 1, "fat_extra": 6, "hit": -10, "armor": 1.5, "d": "Dégâts d'armure ×1,5, −10 % au toucher."},
	"assommer": {"n": "Assommer", "weapons": ["masse", "gourdin"], "ap_extra": 1, "fat_extra": 5, "dmg": 0.85, "morale": -15, "d": "Si le coup touche, test de moral de la cible à −15."},
	"recul": {"n": "Recul", "weapons": ["lance", "fourche"], "ap_extra": 1, "fat_extra": 4, "dmg": 0.7, "push": true, "d": "Repousse la cible d'une case si la place est libre."},
	"tir_ajuste": {"n": "Tir ajusté", "weapons": ["arc", "arbalete", "javelot"], "ap_extra": 2, "fat_extra": 3, "hit": 15, "d": "+15 % au toucher pour 2 PA de plus."},
	"coup_bouclier": {"n": "Coup de bouclier", "weapons": [], "needs_shield": true, "ap": 4, "fat": 12, "dmg": 0.0, "stun": true, "d": "Ne blesse pas ; si le coup touche, la cible perd 4 PA à son prochain tour."},
	"croc": {"n": "Croc", "weapons": ["hallebarde"], "ap_extra": 1, "fat_extra": 5, "dmg": 0.7, "expose": true, "d": "Si le coup touche, la cible est désarçonnée : −10 en défense jusqu'au début de son prochain tour."},
	"briser_bouclier": {"n": "Briser le bouclier", "weapons": ["fleau"], "ap_extra": 1, "fat_extra": 5, "dmg": 0.9, "shield_break": 30, "needs_target_shield": true, "d": "Si le coup touche, abîme fortement le bouclier de la cible."},
}
const STUN_AP: int = 4
const EXPOSE_DEF: int = 10
const AI_ABILITY_CHANCE: float = 0.3  ## chance qu'une unité de l'IA tente une capacité utilisable au lieu d'une attaque simple

## Chef de chaque faction (cible des « chasses au chef »).
const FACTION_LEADER: Dictionary = {"b": "chef", "g": "vorace", "o": "orc_chef", "u": "necro"}
const FACTION_NAMES: Dictionary = {"b": "brigands", "g": "goules", "o": "orcs", "u": "morts-vivants"}
const FACTION_PARTY_TITLES: Dictionary = {"b": "Bande de brigands", "g": "Meute de goules", "o": "Horde d'orcs", "u": "Cohorte de morts-vivants"}
## Renom minimal pour croiser / se voir proposer une faction.
const FACTION_MIN_RENOWN: Dictionary = {"b": 0, "g": 0, "u": 200, "o": 350}

const FIRST_NAMES: Array = ["Aldric", "Bertrand", "Guillaume", "Hugues", "Arnaud", "Gautier", "Thibaut", "Renaud", "Enguerrand", "Jehan", "Martin", "Odon", "Foulques", "Baudouin", "Raoul", "Godefroy", "Simon", "Lancelin", "Gérard", "Anselme", "Mathieu", "Perceval", "Amaury", "Josselin", "Clément", "Barthélemy", "Évrard", "Tristan", "Gilles", "Herbert"]
const NICKNAMES: Array = ["le Borgne", "la Brute", "Sans-Terre", "Trois-Doigts", "le Rouge", "Tête-de-Fer", "le Pieux", "l'Ours", "le Muet", "Belle-Gueule", "le Bâtard", "Poing-Lourd", "le Gris", "Courte-Paille", "le Boiteux", "Pied-de-Chêne", "la Fouine", "le Vieux"]
const TOWNS: Array = ["Vieux-Moulin", "Saint-Aubin-des-Ronces", "Hautefage", "Bourg-sur-Lys", "Les Marches", "Roncevaux-le-Bas", "Fontfroide", "Malbosc", "Gué-aux-Loups", "Pierrecourbe"]
const EMPLOYERS: Array = ["Le bailli", "Le prévôt", "Le marchand", "L'abbé", "Le meunier", "La dame"]

const MORALE_NAMES: Array = ["En fuite", "Brisé", "Hésitant", "Stable", "Confiant"]
const MSK: Array = [-30, -20, -10, 0, 10]
const MDEF: Array = [-20, -15, -10, 0, 5]
const XP_THRESHOLDS: Array = [0, 0, 40, 100, 180, 280, 400, 540, 700, 900, 1150, 1450]

## Libellés des attributs et gain tiré à la promotion.
const STAT_NAMES: Dictionary = {
	"hp_max": "PV", "fat_max": "Endurance", "resolve": "Détermination", "initiative": "Initiative",
	"melee_skill": "Att. mêlée", "ranged_skill": "Att. distance", "melee_def": "Déf. mêlée", "ranged_def": "Déf. distance",
}
const STAT_SHORT: Dictionary = {
	"hp_max": "PV", "fat_max": "Endurance", "resolve": "Détermin.", "initiative": "Initiative",
	"melee_skill": "Att. mêlée", "ranged_skill": "Att. dist.", "melee_def": "Déf. mêlée", "ranged_def": "Déf. dist.",
}
const PROMO_RANGES: Dictionary = {
	"hp_max": [2, 4], "fat_max": [2, 4], "resolve": [2, 4], "initiative": [3, 5],
	"melee_skill": [1, 3], "ranged_skill": [1, 3], "melee_def": [1, 3], "ranged_def": [2, 4],
}

## Ce que vend chaque type de lieu (clés de WPN / HEAD / BODY) et qui s'y engage.
const SHOPS: Dictionary = {
	"village": {
		"weapon": ["gourdin", "fourche", "lance", "arc", "fleau", "javelot"], "head": ["capuchon", "casque"], "body": ["tunique", "gambison"], "shield": true,
		"recruits": ["mendiant", "fermier", "bucheron", "braconnier"], "contracts": 2,
	},
	"city": {
		"weapon": ["gourdin", "fourche", "lance", "hache", "masse", "epee", "arc", "fleau", "javelot", "hallebarde", "arbalete"], "head": ["capuchon", "casque", "heaume"],
		"body": ["tunique", "gambison", "mailles", "brigandine"], "shield": true,
		"recruits": ["mendiant", "fermier", "bucheron", "braconnier", "milicien", "deserteur", "reitre"], "contracts": 3,
	},
}
const TARGET_NAMES: Dictionary = {
	"b": ["Campement de brigands", "Repaire dans les bois", "Embuscade au gué", "Péage illégal"],
	"g": ["Charnier", "Cimetière profané", "Ossuaire", "Grange hantée"],
	"o": ["Camp de guerre orc", "Palissade orque", "Gué des Écorcheurs", "Tour de guet prise"],
	"u": ["Crypte profanée", "Tertre maudit", "Chapelle en ruines", "Nécropole oubliée"],
}
const RESTOCK_DAYS: int = 7

## Objets uniques : clé = clé dans WPN / HEAD / BODY (leurs statistiques fixes y vivent). `kind` : "weapon" | "head" | "body" ;
## `look` : clé de l'objet ordinaire dont on emprunte le sprite / l'icône ; `story` : une ligne d'histoire.
const UNIQUES: Dictionary = {
	"u_epee_corbeau": {"kind": "weapon", "look": "epee", "story": "Forgée pour un capitaine dont le nom s'est perdu. Le pommeau porte un corbeau."},
	"u_hache_fendcrane": {"kind": "weapon", "look": "hache", "story": "Elle a fendu plus de heaumes que n'importe quelle hache du royaume."},
	"u_lance_aigle": {"kind": "weapon", "look": "lance", "story": "Une hampe de frêne, une pointe d'acier de montagne. Elle ne manque jamais sa cible."},
	"u_masse_glas": {"kind": "weapon", "look": "masse", "story": "On l'entend sonner trois rues plus loin. Les os n'y résistent pas."},
	"u_arc_ronce": {"kind": "weapon", "look": "arc", "story": "Un if sauvage, courbé par un maître archer qui ne l'a jamais vendu de son vivant."},
	"u_casque_loup": {"kind": "head", "look": "casque", "story": "Un casque à nasal orné d'une gueule de loup gravée."},
	"u_heaume_veilleur": {"kind": "head", "look": "heaume", "story": "Porté par les veilleurs de la tour d'Os, qui ne dormaient jamais."},
	"u_cotte_nuit": {"kind": "body", "look": "mailles", "story": "Des mailles noircies à l'huile, silencieuses comme une nuit sans lune."},
	"u_brigandine_roi": {"kind": "body", "look": "brigandine", "story": "Elle habillait un roi déchu. Les rivets d'or ont été arrachés, pas la solidité."},
}

const MAX_ROSTER: int = 10
const FIGHTERS: int = 8
const BOARD_W: int = 12
const BOARD_H: int = 9
const AP_PER_TURN: int = 9

# --- Terrains de bataille ---
## `ap` : PA pour entrer dans la case ; `fat` : fatigue en plus par case ; `fat_mult` : multiplicateur de fatigue ;
## `block` : infranchissable ; `los` : bloque la ligne de tir ; `h` : hauteur (les collines dominent) ;
## `def` : modificateur de défense de qui s'y tient.
const TERRAIN: Dictionary = {
	"g": {"n": "Herbe", "ap": 2, "fat": 0, "fat_mult": 1, "block": false, "los": false, "h": 0, "def": 0},
	"tree": {"n": "Arbre", "ap": 2, "fat": 0, "fat_mult": 1, "block": true, "los": true, "h": 0, "def": 0},
	"rock": {"n": "Rocher", "ap": 2, "fat": 0, "fat_mult": 1, "block": true, "los": true, "h": 0, "def": 0},
	"forest": {"n": "Forêt", "ap": 3, "fat": 2, "fat_mult": 1, "block": false, "los": true, "h": 0, "def": 0},
	"hill": {"n": "Colline", "ap": 2, "fat": 1, "fat_mult": 1, "block": false, "los": false, "h": 1, "def": 0},
	"ford": {"n": "Gué", "ap": 4, "fat": 0, "fat_mult": 2, "block": false, "los": false, "h": 0, "def": -10},
	"river": {"n": "Rivière profonde", "ap": 2, "fat": 0, "fat_mult": 1, "block": true, "los": false, "h": 0, "def": 0},
}
const HILL_CLIMB_AP: int = 1  ## PA en plus pour monter sur une case plus haute
const HILL_MELEE_BONUS: int = 10  ## au toucher en mêlée depuis une position plus haute (malus si plus basse)
const LINE_UNIT_MALUS: int = 15  ## par unité sur la ligne de tir
const BIOMES: Array = ["plain", "forest", "hills", "water"]
const BIOME_WEIGHTS: Dictionary = {"plain": 4, "forest": 2, "hills": 2, "water": 2}

# --- Talents : arbre de 7 rangs x 4 colonnes (voir core/perks.gd) ---
## Chaque niveau (2 à 11) donne 1 point de talent. Un talent du rang N exige d'avoir déjà pris N-1 talents.
## `tier` : rang 1..7 ; `col` : colonne 0..3 ; `req` : talent précis à avoir pris avant (facultatif) ; `fam` : famille (couleur) ;
## `ic` : sigle de la pastille. Effets : `stat` (attributs), `shield_stat` (avec un bouclier utilisable), `light_stat` (équipement léger,
## poids <= PERK_LIGHT_WEIGHT), `wp` (spécialisation d'arme : `weapons`, `hit`, `dmg`, `arm`, `ign`, `ammo`) ; le reste est lu par `Unit.has_perk`.
const PERK_TIERS: int = 7
const PERK_COLS: int = 4
const PERK_LIGHT_WEIGHT: int = 10
const PERK_RESET_BASE: int = 50  ## entraîneur : coût de réinitialisation = base + par niveau x niveau
const PERK_RESET_PER_LEVEL: int = 30
const PERK_FAMILIES: Dictionary = {
	"melee": {"n": "Mêlée", "c": "c0553f"}, "ranged": {"n": "Distance", "c": "7f9a4f"}, "def": {"n": "Défense", "c": "5f84a8"},
	"move": {"n": "Mobilité", "c": "b98a3e"}, "moral": {"n": "Moral", "c": "9a6aa0"}, "weapon": {"n": "Arme", "c": "a8997e"},
	"gear": {"n": "Équipement", "c": "6f8f8a"},
}
const PERKS: Dictionary = {
	# Rang 1
	"bretteur": {"n": "Bretteur", "d": "+5 en attaque de mêlée.", "stat": {"melee_skill": 5}, "tier": 1, "col": 0, "fam": "melee", "ic": "Br"},
	"oeil_sur": {"n": "Œil sûr", "d": "+10 en attaque à distance.", "stat": {"ranged_skill": 10}, "tier": 1, "col": 1, "fam": "ranged", "ic": "Œs"},
	"endurant": {"n": "Endurant", "d": "Chaque attaque coûte 3 fatigue de moins.", "tier": 1, "col": 2, "fam": "def", "ic": "En"},
	"vif": {"n": "Vif", "d": "+10 d'initiative.", "stat": {"initiative": 10}, "tier": 1, "col": 3, "fam": "move", "ic": "Vf"},
	# Rang 2
	"briseur": {"n": "Coup d'estoc", "d": "+10 % de dégâts contre une armure légère (moins de 70).", "tier": 2, "col": 0, "fam": "melee", "ic": "Es"},
	"esquive": {"n": "Esquive", "d": "+10 en défense à distance.", "stat": {"ranged_def": 10}, "tier": 2, "col": 1, "fam": "def", "ic": "Eq"},
	"souffle_long": {"n": "Souffle long", "d": "+15 d'endurance.", "stat": {"fat_max": 15}, "tier": 2, "col": 2, "fam": "def", "ic": "Sl"},
	"pied_sur": {"n": "Pied sûr", "d": "Chaque case parcourue coûte 1 fatigue de moins.", "tier": 2, "col": 3, "fam": "move", "ic": "Ps"},
	# Rang 3
	"spec_epee": {"n": "Maître d'épée", "d": "Épées : +10 % au toucher.", "wp": {"weapons": ["epee", "u_epee_corbeau"], "hit": 10}, "tier": 3, "col": 0, "fam": "weapon", "ic": "Ép"},
	"spec_arc": {"n": "Tireur d'élite", "d": "Arcs et arbalètes : +10 % de dégâts.", "wp": {"weapons": ["arc", "arbalete", "u_arc_ronce"], "dmg": 1.1}, "tier": 3, "col": 1, "fam": "weapon", "ic": "Ta"},
	"garde_ferme": {"n": "Garde ferme", "d": "+10 en défense de mêlée avec un bouclier.", "shield_stat": {"melee_def": 10}, "tier": 3, "col": 2, "fam": "def", "ic": "Gf"},
	"cran": {"n": "Cran", "d": "+15 aux tests de moral.", "stat": {"resolve": 15}, "tier": 3, "col": 3, "fam": "moral", "ic": "Cr"},
	# Rang 4
	"spec_hache": {"n": "Fendeur", "d": "Haches : +15 % de dégâts à l'armure.", "wp": {"weapons": ["hache", "u_hache_fendcrane"], "arm": 1.15}, "tier": 4, "col": 0, "fam": "weapon", "ic": "Fd"},
	"spec_javelot": {"n": "Lanceur", "d": "Javelots : +10 % au toucher et 2 javelots de plus.", "wp": {"weapons": ["javelot"], "hit": 10, "ammo": 2}, "tier": 4, "col": 1, "fam": "weapon", "ic": "Jv"},
	"dur_a_cuire": {"n": "Dur à cuire", "d": "Deux fois moins de risques d'être blessé.", "tier": 4, "col": 2, "fam": "def", "ic": "Dc"},
	"legerete": {"n": "Pas léger", "d": "+15 d'initiative et +5 en défense tant que le poids de l'équipement est de 10 ou moins.", "light_stat": {"initiative": 15, "melee_def": 5, "ranged_def": 5}, "tier": 4, "col": 3, "fam": "gear", "ic": "Pl"},
	# Rang 5
	"spec_masse": {"n": "Fracasseur", "d": "Masses, gourdins et fléaux : traversent 10 points de plus l'armure.", "wp": {"weapons": ["masse", "gourdin", "fleau", "u_masse_glas"], "ign": 0.1}, "tier": 5, "col": 0, "fam": "weapon", "ic": "Fr"},
	"oeil_de_lynx": {"n": "Œil de lynx", "d": "+2 de portée avec un arc.", "req": "spec_arc", "tier": 5, "col": 1, "fam": "ranged", "ic": "Lx"},
	"second_souffle": {"n": "Second souffle", "d": "Récupère 5 points de fatigue de plus par tour.", "tier": 5, "col": 2, "fam": "def", "ic": "Ss"},
	"intimidant": {"n": "Regard glaçant", "d": "Un coup qui laisse l'ennemi sous 60 % de ses PV lui impose un test de moral à −10.", "tier": 5, "col": 3, "fam": "moral", "ic": "Rg"},
	# Rang 6
	"spec_lance": {"n": "Lancier", "d": "Lances, fourches et hallebardes : +10 % au toucher.", "wp": {"weapons": ["lance", "fourche", "hallebarde", "u_lance_aigle"], "hit": 10}, "tier": 6, "col": 0, "fam": "weapon", "ic": "Ln"},
	"coup_de_grace": {"n": "Coup de grâce", "d": "35 % de chances de viser la tête au lieu de 25 %.", "tier": 6, "col": 1, "fam": "melee", "ic": "Cg"},
	"spec_bouclier": {"n": "Rempart", "d": "Avec un bouclier : +5 en défense de mêlée et +10 en défense à distance.", "req": "garde_ferme", "shield_stat": {"melee_def": 5, "ranged_def": 10}, "tier": 6, "col": 2, "fam": "weapon", "ic": "Rp"},
	"montagnard": {"n": "Montagnard", "d": "Ignore les pénalités de forêt, de colline et de gué.", "tier": 6, "col": 3, "fam": "move", "ic": "Mt"},
	# Rang 7
	"frappe_vive": {"n": "Frappe vive", "d": "La première attaque de chaque tour coûte 1 PA de moins.", "tier": 7, "col": 0, "fam": "melee", "ic": "Fv"},
	"insaisissable": {"n": "Insaisissable", "d": "Ignore une zone de contrôle ennemie isolée.", "tier": 7, "col": 1, "fam": "move", "ic": "In"},
	"armure_lourde": {"n": "Port d'armure", "d": "Le poids de l'équipement est réduit de 30 % (fatigue, initiative, déplacement).", "req": "dur_a_cuire", "tier": 7, "col": 2, "fam": "gear", "ic": "Pa"},
	"chef_ne": {"n": "Chef-né", "d": "Les alliés adjacents ont +10 à leurs tests de moral.", "req": "cran", "tier": 7, "col": 3, "fam": "moral", "ic": "Ch"},
}

# --- Blessures ---
## `fx` : malus d'attributs ; `perm` : définitive. Les blessures temporaires durent `days` jours [min, max].
const INJURIES: Dictionary = {
	"bras": {"n": "Bras blessé", "perm": false, "days": [4, 8], "fx": {"melee_skill": -10}},
	"jambe": {"n": "Jambe blessée", "perm": false, "days": [4, 8], "fx": {"fat_max": -15, "initiative": -15}},
	"commotion": {"n": "Commotion", "perm": false, "days": [3, 6], "fx": {"resolve": -10}},
	"flanc": {"n": "Flanc entaillé", "perm": false, "days": [3, 7], "fx": {"melee_def": -5, "ranged_def": -5}},
	"oeil": {"n": "Œil perdu", "perm": true, "fx": {"ranged_skill": -15, "ranged_def": -3}},
	"boiteux": {"n": "Boiteux", "perm": true, "fx": {"initiative": -10}},
	"cicatrice": {"n": "Cicatrice profonde", "perm": true, "fx": {"resolve": -5, "fat_max": -5}},
	"main": {"n": "Main abîmée", "perm": true, "fx": {"melee_skill": -5}},
}
const WOUND_HP_FRAC: float = 0.30  ## coup qui retire au moins cette part des PV max : test de blessure
const WOUND_CHANCE: int = 50
const PERM_HP_FRAC: float = 0.25  ## homme à ce niveau de PV ou moins en fin de combat : risque de blessure permanente
const PERM_CHANCE: int = 35
