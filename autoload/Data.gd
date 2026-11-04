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
	"morsure": {"n": "Morsure", "min": 20, "max": 32, "arm": 0.5, "ign": 0.2, "ap": 4, "fat": 8, "hit": 0, "rng": 1, "h1": false, "ranged": false, "price": 0, "note": ""},
	"massue_geant": {"n": "Massue de géant", "min": 45, "max": 70, "arm": 1.2, "ign": 0.3, "ap": 5, "fat": 14, "hit": 0, "rng": 1, "h1": false, "ranged": false, "price": 0, "note": ""},
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
	"goule": {"n": "Goule", "fac": "g", "hp": [110, 130], "fat": [150, 150], "res": [48, 55], "mSk": [50, 55], "rSk": [0, 0], "mDef": [0, 5], "rDef": [0, 5], "ini": [110, 120], "w": ["griffes"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 25, "leader": false, "flank": true},
	"vorace": {"n": "Goule vorace", "fac": "g", "hp": [220, 240], "fat": [160, 160], "res": [65, 70], "mSk": [58, 64], "rSk": [0, 0], "mDef": [0, 5], "rDef": [0, 5], "ini": [90, 95], "w": ["griffesL"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 60, "leader": false, "flank": true},
	# Orcs ("o") : plus de PV, de défense et de compétence que les brigands.
	"orc_jeune": {"n": "Jeune orc", "fac": "o", "hp": [75, 90], "fat": [110, 120], "res": [45, 55], "mSk": [55, 62], "rSk": [30, 40], "mDef": [3, 9], "rDef": [3, 8], "ini": [95, 105], "w": ["gourdin", "hache", "lance"], "sh": 0.4, "head": ["none", "capuchon"], "body": ["tunique", "gambison"], "xp": 25, "leader": false},
	"orc_guerrier": {"n": "Guerrier orc", "fac": "o", "hp": [100, 115], "fat": [120, 130], "res": [55, 65], "mSk": [62, 68], "rSk": [30, 40], "mDef": [8, 14], "rDef": [6, 12], "ini": [90, 100], "w": ["hache", "masse", "epee", "hallebarde"], "sh": 0.6, "head": ["casque"], "body": ["gambison", "mailles"], "xp": 45, "leader": false},
	"berserker": {"n": "Berserker orc", "fac": "o", "hp": [110, 125], "fat": [130, 140], "res": [70, 80], "mSk": [66, 72], "rSk": [20, 30], "mDef": [0, 4], "rDef": [0, 4], "ini": [105, 115], "w": ["hache"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 50, "leader": false},
	"orc_chef": {"n": "Chef de guerre orc", "fac": "o", "hp": [160, 180], "fat": [140, 150], "res": [75, 85], "mSk": [72, 78], "rSk": [35, 45], "mDef": [14, 20], "rDef": [10, 15], "ini": [100, 108], "w": ["hache", "epee"], "sh": 1.0, "head": ["heaume"], "body": ["brigandine"], "xp": 100, "leader": true, "perks": ["cran", "spec_hache"]},
	# Morts-vivants ("u")
	"squelette": {"n": "Squelette", "fac": "u", "hp": [45, 55], "fat": [110, 120], "res": [80, 90], "mSk": [48, 56], "rSk": [30, 36], "mDef": [0, 6], "rDef": [10, 16], "ini": [100, 110], "w": ["lance", "epee", "gourdin"], "sh": 0.6, "head": ["none", "casque"], "body": ["none"], "xp": 20, "leader": false},
	"squelette_archer": {"n": "Squelette archer", "fac": "u", "hp": [40, 50], "fat": [100, 110], "res": [80, 90], "mSk": [40, 46], "rSk": [50, 58], "mDef": [0, 4], "rDef": [8, 14], "ini": [105, 115], "w": ["arc"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 20, "leader": false},
	"zombie": {"n": "Zombie", "fac": "u", "hp": [90, 110], "fat": [120, 130], "res": [90, 95], "mSk": [44, 50], "rSk": [0, 0], "mDef": [0, 0], "rDef": [0, 0], "ini": [60, 75], "w": ["griffes"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 20, "leader": false},
	"necro": {"n": "Nécromant", "fac": "u", "hp": [85, 100], "fat": [100, 110], "res": [75, 85], "mSk": [58, 64], "rSk": [40, 48], "mDef": [8, 14], "rDef": [10, 16], "ini": [105, 112], "w": ["masse"], "sh": 0.0, "head": ["capuchon"], "body": ["gambison"], "xp": 70, "leader": true, "perks": ["cran"], "raise": true},
	# Soigneur orc : soigne un allié blessé (heal = PV rendus).
	"chaman_orc": {"n": "Chaman orc", "fac": "o", "hp": [70, 85], "fat": [100, 110], "res": [65, 75], "mSk": [50, 56], "rSk": [30, 40], "mDef": [4, 9], "rDef": [6, 12], "ini": [100, 110], "w": ["gourdin"], "sh": 0.0, "head": ["none"], "body": ["tunique"], "xp": 50, "leader": false, "heal": 30},
	# Monstres ("m"). Champs facultatifs lus par Unit.foe_data() : sprite (figurine), big (grande créature : insensible au filet),
	# swift (PA de déplacement en moins par case), regen (PV rendus à chaque manche), stun_hit (% d'étourdir sur un coup),
	# charge (bonus au toucher après 3 cases ou plus), flank (cherche à encercler), fearless (ne se replie jamais),
	# drop ([[genre, clé, chance]] : butin propre).
	"loup": {"n": "Loup", "fac": "m", "hp": [40, 50], "fat": [150, 160], "res": [50, 60], "mSk": [48, 55], "rSk": [0, 0], "mDef": [5, 12], "rDef": [5, 10], "ini": [120, 135], "w": ["morsure"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 20, "leader": false, "sprite": "wolf", "swift": 1, "flank": true},
	"cavalier_loup": {"n": "Cavalier de loup", "fac": "m", "hp": [80, 95], "fat": [130, 140], "res": [55, 65], "mSk": [60, 66], "rSk": [30, 40], "mDef": [6, 12], "rDef": [6, 10], "ini": [115, 125], "w": ["lance", "hache"], "sh": 0.3, "head": ["none", "capuchon"], "body": ["tunique", "gambison"], "xp": 45, "leader": false, "sprite": "wolf_rider", "swift": 1, "charge": 15, "flank": true},
	"ogre": {"n": "Ogre", "fac": "m", "hp": [260, 300], "fat": [170, 180], "res": [70, 80], "mSk": [55, 62], "rSk": [0, 0], "mDef": [0, 4], "rDef": [0, 4], "ini": [70, 80], "w": ["massue_geant"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 120, "leader": false, "sprite": "ogre", "big": true, "stun_hit": 35, "fearless": true, "drop": [["body", "gambison", 0.4], ["weapon", "masse", 0.3]]},
	"troll": {"n": "Troll", "fac": "m", "hp": [320, 360], "fat": [180, 190], "res": [75, 85], "mSk": [60, 66], "rSk": [0, 0], "mDef": [0, 4], "rDef": [0, 4], "ini": [80, 90], "w": ["griffesL"], "sh": 0.0, "head": ["none"], "body": ["none"], "xp": 150, "leader": true, "sprite": "troll", "big": true, "regen": 5, "fearless": true, "drop": [["head", "casque", 0.4], ["body", "mailles", 0.25]]},
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
	"fleche_feu": {"n": "Flèche enflammée", "weapons": ["arc"], "ap_extra": 1, "fat_extra": 3, "hit": -5, "dmg": 0.8, "fire": true, "d": "Si le tir touche, enflamme la case de la cible (herbe et forêt)."},
	# Lancers : un outil du sac (voir TOOLS). `tool` : clé de l'outil ; `rng` / `min_rng` : portée ; `dmg_range` : dégâts fixes aux PV (l'armure ne compte pas) ;
	# `splash` : touche aussi les cases voisines (amis compris) ; `net` : immobilise ; `fire` : enflamme.
	"lancer_pierre": {"n": "Lancer : pierre", "weapons": [], "tool": "pierre", "ap": 4, "fat": 8, "rng": 3, "min_rng": 1, "hit": 10, "dmg_range": [8, 14], "stun": true, "d": "Portée 3. Si la pierre touche, la cible est étourdie."},
	"lancer_huile": {"n": "Lancer : huile", "weapons": [], "tool": "huile", "ap": 5, "fat": 10, "rng": 3, "min_rng": 2, "splash": true, "dmg_range": [15, 25], "fire": true, "d": "Portée 3 (pas au contact). La case visée et ses voisines : dégâts et feu. Amis compris !"},
	"lancer_filet": {"n": "Lancer : filet", "weapons": [], "tool": "filet", "ap": 4, "fat": 8, "rng": 3, "min_rng": 1, "hit": 5, "net": true, "d": "Portée 3. Si le filet touche, la cible ne peut pas bouger à son prochain tour. Sans effet sur les grandes créatures."},
}

## Outils de jet et de siège (objets du sac, genre "tool"). `uses` : lancers par bataille et par exemplaire.
const TOOLS: Dictionary = {
	"pierre": {"n": "Pierres de jet", "price": 25, "uses": 3, "ab": "lancer_pierre", "note": "3 lancers par bataille : étourdissent."},
	"huile": {"n": "Huile bouillante", "price": 90, "uses": 1, "ab": "lancer_huile", "note": "1 lancer par bataille : zone, dégâts et feu."},
	"filet": {"n": "Filet de chasse", "price": 60, "uses": 2, "ab": "lancer_filet", "note": "2 lancers par bataille : immobilise une cible."},
}
const STUN_AP: int = 4
const EXPOSE_DEF: int = 10
const AI_ABILITY_CHANCE: float = 0.3  ## chance qu'une unité de l'IA tente une capacité utilisable au lieu d'une attaque simple

## Chef de chaque faction (cible des « chasses au chef »).
const FACTION_LEADER: Dictionary = {"b": "chef", "g": "vorace", "o": "orc_chef", "u": "necro", "m": "troll"}
const FACTION_NAMES: Dictionary = {"b": "brigands", "g": "goules", "o": "orcs", "u": "morts-vivants", "m": "monstres"}
const FACTION_PARTY_TITLES: Dictionary = {"b": "Bande de brigands", "g": "Meute de goules", "o": "Horde d'orcs", "u": "Cohorte de morts-vivants", "m": "Meute de bêtes"}
## Renom minimal pour croiser / se voir proposer une faction.
const FACTION_MIN_RENOWN: Dictionary = {"b": 0, "g": 0, "u": 200, "o": 350, "m": 150}

const FIRST_NAMES: Array = ["Aldric", "Bertrand", "Guillaume", "Hugues", "Arnaud", "Gautier", "Thibaut", "Renaud", "Enguerrand", "Jehan", "Martin", "Odon", "Foulques", "Baudouin", "Raoul", "Godefroy", "Simon", "Lancelin", "Gérard", "Anselme", "Mathieu", "Perceval", "Amaury", "Josselin", "Clément", "Barthélemy", "Évrard", "Tristan", "Gilles", "Herbert", "Thierry", "Bastien", "Colin", "Eudes", "Garin", "Hervé", "Ingelger", "Lambert", "Maheu", "Néel", "Olivier", "Pons", "Quentin", "Robin", "Sigebert", "Thomas", "Urbain", "Vivien", "Wilfrid", "Yvon", "Aymeric", "Béranger", "Conrad", "Drogon", "Émeric", "Fulbert", "Gaucher", "Hugonet", "Jocelin", "Landry"]
const NICKNAMES: Array = ["le Borgne", "la Brute", "Sans-Terre", "Trois-Doigts", "le Rouge", "Tête-de-Fer", "le Pieux", "l'Ours", "le Muet", "Belle-Gueule", "le Bâtard", "Poing-Lourd", "le Gris", "Courte-Paille", "le Boiteux", "Pied-de-Chêne", "la Fouine", "le Vieux", "Mauvaise-Herbe", "le Chanceux", "Dent-Creuse", "Longue-Échine", "le Sournois", "Bras-de-Fer", "la Pie", "Coupe-Gorge", "le Taciturne", "Face-de-Lune", "le Cadet", "Sept-Doigts", "Œil-de-Chat", "le Bavard", "Corne-de-Bœuf", "Pas-Perdu", "la Belette", "le Blême"]
const TOWNS: Array = ["Vieux-Moulin", "Saint-Aubin-des-Ronces", "Hautefage", "Bourg-sur-Lys", "Les Marches", "Roncevaux-le-Bas", "Fontfroide", "Malbosc", "Gué-aux-Loups", "Pierrecourbe",
	"Brumevalle", "Sainte-Colombe-les-Eaux", "Châtel-Ardent", "Combe-Noire", "Aubépine", "Mont-Corbin", "Val-de-Cendre", "Bellerive", "Tourbière", "Saint-Gildas-du-Gué",
	"Haute-Ronce", "Écorcheval", "Pontlevis", "Clairefontaine", "Montfaucon-le-Sec", "La Rochebrune", "Épinoy", "Noirmoutel", "Saint-Aigulf", "Terre-Rouge"]
const EMPLOYERS: Array = ["Le bailli", "Le prévôt", "Le marchand", "L'abbé", "Le meunier", "La dame", "Le châtelain", "Le sénéchal", "La prieure", "Le maître de guilde", "Le seigneur", "Le syndic"]

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
		"recruits": ["mendiant", "fermier", "bucheron", "braconnier"], "contracts": 2, "tool": ["pierre", "filet"],
	},
	"city": {
		"weapon": ["gourdin", "fourche", "lance", "hache", "masse", "epee", "arc", "fleau", "javelot", "hallebarde", "arbalete"], "head": ["capuchon", "casque", "heaume"],
		"body": ["tunique", "gambison", "mailles", "brigandine"], "shield": true,
		"recruits": ["mendiant", "fermier", "bucheron", "braconnier", "milicien", "deserteur", "reitre"], "contracts": 3, "tool": ["pierre", "filet", "huile"],
	},
}
const TARGET_NAMES: Dictionary = {
	"b": ["Campement de brigands", "Repaire dans les bois", "Embuscade au gué", "Péage illégal"],
	"g": ["Charnier", "Cimetière profané", "Ossuaire", "Grange hantée"],
	"o": ["Camp de guerre orc", "Palissade orque", "Gué des Écorcheurs", "Tour de guet prise"],
	"u": ["Crypte profanée", "Tertre maudit", "Chapelle en ruines", "Nécropole oubliée"],
	"m": ["Tanière de loups", "Antre de l'ogre", "Pont du troll", "Bois des hurlements"],
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
# --- Types de bataille, décor interactif, nuit ---
const BATTLE_TYPES: Array = ["pitched", "ambush", "convoy", "siege", "night"]
const BATTLE_TYPE_NAMES: Dictionary = {"pitched": "Bataille rangée", "ambush": "Embuscade", "convoy": "Convoi", "siege": "Siège", "night": "Nuit"}
const NIGHT_SIGHT: int = 4  ## rayon de vision de chaque camp la nuit
const NIGHT_FAR_PENALTY: int = 3  ## malus au toucher à distance, par case au-delà de 3, la nuit
const CONVOY_ROUNDS: int = 8  ## manches à tenir pour sauver le convoi
const CART: Dictionary = {"n": "Chariot", "hp": 140}
const FIRE_SPREAD: float = 0.25  ## chance par manche de gagner une case d'herbe voisine (forêt : ×2)
const AMBUSH_RESERVE_ROUND: int = 2  ## manche à laquelle surgissent les renforts d'une embuscade
const LEADER_AURA: int = 8  ## bonus aux tests de moral des alliés à 4 cases ou moins d'un chef vivant
const DETECT_RANGE: int = 2  ## distance à laquelle on peut repérer un piège caché
## Objets de décor posés dans `cells[hex]["obj"]` = {"kind": clé, "hp", "open", "hidden", "ttl", "top", "owner"}.
## `block` : infranchissable tant qu'intact ; `los` : coupe la ligne de tir ; `hp` : points de structure (0 = indestructible) ;
## `dmg` : dégâts aux PV de qui y entre ou y reste ; `light` : rayon d'éclairage de nuit.
const SCENERY: Dictionary = {
	"fire": {"n": "Feu", "hp": 0, "block": false, "los": false, "dmg": [5, 10], "light": 2, "morale": -10},
	"door": {"n": "Porte", "hp": 40, "block": true, "los": true, "open_ap": 2},
	"barricade": {"n": "Barricade", "hp": 50, "block": true, "los": true},
	"trap": {"n": "Piège", "hp": 0, "block": false, "los": false, "dmg": [10, 20], "detect": 10},
	"wall": {"n": "Rempart", "hp": 0, "block": true, "los": false},
	"gate": {"n": "Porte du fort", "hp": 90, "block": true, "los": true, "open_ap": 2},
	"torch": {"n": "Torche", "hp": 0, "block": false, "los": false, "light": 3},
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


# --- Traits de caractère (core/traits.gd) ---
## Chaque recrue tire 1 ou 2 traits (jamais deux traits de la même famille `ex`). `stat` : modificateurs permanents d'attributs (lus par
## Unit.eff) ; `hit_stat` : modificateurs une fois qu'il a encaissé un coup dans la bataille ; `hp` : PV max ajoutés à la génération ;
## `wage` : multiplicateur de solde ; `rest` : PV de repos en plus ; `ally_fall` : modificateur au test de moral quand un camarade tombe ;
## `aura` : modificateur de moral des alliés adjacents ; `lucky` : chance (%) d'échapper à la mort une fois par bataille (reste à 1 PV).
## `tone` : "good" | "bad" | "mixed" (couleur de la pastille).
const TRAIT_CHANCE_SECOND: float = 0.35
const TRAITS: Dictionary = {
	"brave": {"n": "Brave", "d": "+10 en détermination après le premier coup encaissé dans une bataille.", "hit_stat": {"resolve": 10}, "tone": "good", "ex": "cran"},
	"peureux": {"n": "Peureux", "d": "−10 à son test de moral quand un camarade tombe près de lui.", "ally_fall": -10, "tone": "bad", "ex": "cran"},
	"avare": {"n": "Avare", "d": "Réclame une solde plus élevée (+25 %).", "wage": 1.25, "tone": "bad", "ex": "pay"},
	"frugal": {"n": "Frugal", "d": "Se contente d'une solde réduite (−20 %).", "wage": 0.8, "tone": "good", "ex": "pay"},
	"robuste": {"n": "Robuste", "d": "+8 PV maximum.", "hp": 8, "tone": "good", "ex": "body"},
	"fragile": {"n": "Fragile", "d": "−8 PV maximum.", "hp": -8, "tone": "bad", "ex": "body"},
	"costaud": {"n": "Costaud", "d": "+10 d'endurance.", "stat": {"fat_max": 10}, "tone": "good", "ex": "fat"},
	"myope": {"n": "Myope", "d": "−8 en attaque à distance.", "stat": {"ranged_skill": -8}, "tone": "bad", "ex": "eye"},
	"bon_oeil": {"n": "Bon œil", "d": "+6 en attaque à distance.", "stat": {"ranged_skill": 6}, "tone": "good", "ex": "eye"},
	"chanceux": {"n": "Chanceux", "d": "Une fois par bataille, 35 % de chances d'échapper à un coup mortel (il survit avec 1 PV).", "lucky": 35, "tone": "good", "ex": "luck"},
	"rancunier": {"n": "Rancunier", "d": "+6 en attaque de mêlée une fois blessé dans la bataille.", "hit_stat": {"melee_skill": 6}, "tone": "mixed", "ex": "grudge"},
	"sociable": {"n": "Sociable", "d": "Les alliés adjacents ont +5 à leurs tests de moral.", "aura": 5, "tone": "good", "ex": "social"},
	"gourmand": {"n": "Gourmand", "d": "Récupère 5 PV de plus à chaque jour de repos en ville.", "rest": 5, "tone": "mixed", "ex": "greed"},
	"vif": {"n": "Vif", "d": "+6 d'initiative.", "stat": {"initiative": 6}, "tone": "good", "ex": "speed"},
	"lent": {"n": "Lent", "d": "−6 d'initiative.", "stat": {"initiative": -6}, "tone": "bad", "ex": "speed"},
	"tete_brulee": {"n": "Tête brûlée", "d": "+5 en attaque de mêlée, −5 en défense de mêlée.", "stat": {"melee_skill": 5, "melee_def": -5}, "tone": "mixed", "ex": "style"},
	"prudent": {"n": "Prudent", "d": "+4 en défense de mêlée, −3 en attaque de mêlée.", "stat": {"melee_def": 4, "melee_skill": -3}, "tone": "mixed", "ex": "style"},
}

# --- Bannière de compagnie (écran « Bannière ») ---
const COMPANY_NAME_DEFAULT: String = "Compagnie du Corbeau"
const COMPANY_NAME_MAX: int = 26
const BANNER_COLORS: Array = ["b8862e", "b03a2e", "3e526a", "4b5a3a", "5a4a6a", "2b2622", "d8cfb8", "7a4e2a", "8a3a6a", "3f7f7a"]
const BANNER_COLOR_NAMES: Array = ["Ocre", "Rouge sang", "Bleu acier", "Vert mousse", "Violet", "Noir", "Parchemin", "Brun", "Prune", "Sarcelle"]
const BANNER_EMBLEMS: Array = ["Corbeau", "Épées croisées", "Étoile", "Croix", "Tour", "Couronne", "Lune", "Chevron"]
const BANNER_DEFAULT: Dictionary = {"primary": "", "secondary": "1d1a17", "emblem": 0}  ## primary "" = ocre d'origine des boucliers
const ELITE_LEVEL: int = 6  ## niveau à partir duquel un homme porte une tenue de vétéran


# --- Vie de la compagnie : quartier général, vivres, moral, factions humaines, histoires (voir core/camp_buildings.gd, bonds.gd, factions.gd) ---
const MAP_VISION: float = 240.0  ## rayon de vue de base sur la carte (Game.vision_radius() ajoute le poste de guet)
const MAX_ROSTER_CAP: int = 13  ## capacité maximale de la compagnie avec les tentes au niveau 3
const BUILDING_ORDER: Array = ["tentes", "entrepot", "forge", "infirmerie", "cuisine", "guet", "enseigne"]
## Bâtiments du camp : niveaux 1 à 3, `costs` = prix de chaque niveau, `fx` = valeur de chaque effet à ce niveau.
const CAMP_BUILDINGS: Dictionary = {
	"forge": {"n": "Forge de campagne", "ic": "⚒", "d": "Une enclume sur un chariot : l'armurier remet les cottes en état et ménage les lames.",
		"costs": [300, 700, 1400], "fx": {"repair_mult": [0.85, 0.7, 0.55], "wear_mult": [0.85, 0.7, 0.55]}},
	"infirmerie": {"n": "Infirmerie", "ic": "✚", "d": "Une tente de soins, des bandages propres et un barbier qui sait coudre.",
		"costs": [250, 600, 1200], "fx": {"road_heal": [1, 2, 3], "rest_heal": [5, 10, 15], "injury_days": [1, 1, 2]}},
	"cuisine": {"n": "Cantine", "ic": "♨", "d": "Une marmite, un cuisinier et du sel : on mange mieux pour moins cher.",
		"costs": [200, 500, 1000], "fx": {"food_mult": [0.9, 0.8, 0.7], "meal_morale": [0.5, 1.0, 1.5]}},
	"tentes": {"n": "Tentes", "ic": "⛺", "d": "Des toiles solides et des paillasses : la compagnie peut accueillir un homme de plus par niveau.",
		"costs": [350, 800, 1500], "fx": {"roster": [1, 2, 3]}},
	"entrepot": {"n": "Entrepôt", "ic": "▤", "d": "Un chariot couvert et des caisses cloutées : huit emplacements de réserve par niveau.",
		"costs": [200, 450, 900], "fx": {"stash": [8, 16, 24]}},
	"guet": {"n": "Poste de guet", "ic": "♜", "d": "Un mât de vigie et un éclaireur : on repère les bandes de plus loin sur la carte.",
		"costs": [250, 550, 1100], "fx": {"vision": [0.2, 0.4, 0.6]}},
	"enseigne": {"n": "Enseigne et étendard", "ic": "⚑", "d": "Une bannière bien visible : le renom de vos exploits voyage plus vite.",
		"costs": [300, 700, 1300], "fx": {"renown": [0.05, 0.1, 0.15]}},
}

const PROVISIONS_START: int = 40  ## rations au départ d'une nouvelle partie
const PROVISIONS_PRICE: int = 3  ## couronnes la ration, avant coefficient de lieu
const PROVISIONS_PER_MAN_CAP: int = 14  ## stock maximal : ce nombre de rations par homme
const PROVISIONS_PACK: int = 10  ## lot d'achat au marché
const PROVISIONS_WARN_DAYS: int = 2
const STARVE_HP: int = 4  ## PV perdus par homme affamé et par jour
const STARVE_MORALE: float = 6.0
const STARVE_DESERT_CHANCE: float = 0.2  ## par jour de disette à partir du deuxième
const MORALE_START: float = 60.0
const MORALE_LOW: float = 25.0  ## en dessous : les hommes partent Hésitants au combat
const MORALE_HIGH: float = 80.0  ## au-dessus : ils partent Confiants

## Factions humaines : seigneuries et ligues qui possèdent les lieux et emploient la compagnie.
## `banner` : même format que la bannière de compagnie ({primary, secondary, emblem} → Data.BANNER_EMBLEMS).
const FACTIONS: Dictionary = {
	"roncevaux": {"n": "Maison de Roncevaux", "color": Color("b03a2e"), "desc": "Une vieille maison de chevaliers : fière, rancunière, généreuse avec ceux qui servent sa bannière.",
		"banner": {"primary": "b03a2e", "secondary": "d8cfb8", "emblem": 1}, "ic": "⚔"},
	"lys": {"n": "Ligue marchande du Lys", "color": Color("c9a23a"), "desc": "Des guildes de marchands qui paient bien et comptent chaque couronne. Les routes sûres sont leur fortune.",
		"banner": {"primary": "b8862e", "secondary": "2b2622", "emblem": 5}, "ic": "⚜"},
	"abbaye": {"n": "Ordre de l'Abbaye", "color": Color("6a7fb0"), "desc": "Des moines-soldats qui veillent sur les reliques et les nécropoles. Ils n'oublient ni un service ni une offense.",
		"banner": {"primary": "3e526a", "secondary": "d8cfb8", "emblem": 3}, "ic": "✠"},
	"marches": {"n": "Conseil des marches", "color": Color("6f9a52"), "desc": "Les bourgs libres des confins, qui se gouvernent eux-mêmes et se méfient des grands seigneurs.",
		"banner": {"primary": "4b5a3a", "secondary": "d8cfb8", "emblem": 4}, "ic": "☘"},
}
const FACTION_STAND_MAX: int = 100
const FACTION_STAND_GOOD: int = 20  ## « Estimé » : prime majorée, recrues d'élite
const FACTION_STAND_BEST: int = 50  ## « Allié » : marchand rare partout sur ses terres
const FACTION_STAND_BAD: int = -20  ## « Méfiant » : prix majorés
const FACTION_STAND_WORST: int = -50  ## « Ennemi » : patrouilles hostiles
const FACTION_PATROL_CHANCE: float = 0.12  ## par jour de route, si ennemi d'une faction sans patrouille déjà sur la carte

## Recrues uniques des histoires : origine (Data.BG), nom, traits, talents, niveau, bonus d'attributs.
const STORY_RECRUITS: Dictionary = {
	"dst_soldat": {"bg": "deserteur", "name": "Aymeric le Fuyard", "traits": ["prudent", "chanceux"], "perks": ["garde_ferme"], "level": 3, "stats": {"melee_def": 3, "resolve": 4}},
	"meunier_fils": {"bg": "fermier", "name": "Tom du Moulin", "traits": ["costaud", "frugal"], "perks": ["endurant"], "level": 2, "stats": {"hp_max": 6}},
	"chevalier": {"bg": "reitre", "name": "Sire Gaspard de Montfaucon", "traits": ["brave", "robuste"], "perks": ["spec_epee", "cran", "garde_ferme"], "level": 5, "stats": {"melee_skill": 4, "resolve": 6}},
	"jumeau_a": {"bg": "braconnier", "name": "Aelis la Rousse", "traits": ["bon_oeil", "vif"], "perks": ["oeil_sur"], "level": 2, "stats": {"ranged_skill": 4}},
	"jumeau_b": {"bg": "bucheron", "name": "Aldric la Rousse", "traits": ["robuste", "sociable"], "perks": ["bretteur"], "level": 2, "stats": {"hp_max": 4}},
	"relique_moine": {"bg": "milicien", "name": "Frère Anselme", "traits": ["brave", "sociable"], "perks": ["cran", "endurant"], "level": 3, "stats": {"resolve": 6, "hp_max": 4}},
	"necro_apostat": {"bg": "braconnier", "name": "Ysolde la Pâle", "traits": ["bon_oeil", "chanceux"], "perks": ["oeil_sur", "esquive"], "level": 3, "stats": {"ranged_skill": 6, "ranged_def": 3}},
}

## Histoires à plusieurs étapes. Une histoire : {n, min_day (jour minimal du début), start (id de la 1re étape), steps: [événement...]}.
## Une étape a la forme d'un événement de route (voir core/events.gd) ; ses issues acceptent en plus :
##   food (±rations), morale (±moral de compagnie), standing ({faction: ±}), bond ("friends" | "rivals" : deux hommes tirés au hasard),
##   flag (clé posée dans Game.story_flags), schedule ({id, days}: étape suivante dans N jours), recruit_story (clé de STORY_RECRUITS),
##   contract (contrat spécial posté dans le lieu le plus proche), unique (clé de Data.UNIQUES), threat (±menace de la campagne).
const STORIES: Dictionary = {
	"deserteur": {"n": "Le déserteur de Roncevaux", "min_day": 4, "start": "dst_1", "steps": [
		{"id": "dst_1", "title": "Un soldat sans bannière",
			"text": "Au détour d'un fossé, un homme en livrée déchirée lève les mains. Les couleurs de la Maison de Roncevaux sont encore visibles sous la boue. « J'ai quitté mon rang avant le massacre du gué, messire. Des cavaliers me cherchent. Cachez-moi. »",
			"choices": [
				{"id": "hide", "label": "Le cacher dans un chariot", "outcomes": [{"w": 1, "text": "Vous le glissez sous une bâche. Il vous remercie à voix basse. Reste à savoir qui le suit.", "flag": "dst_cache", "schedule": {"id": "dst_2", "days": 3}}]},
				{"id": "give", "label": "Le livrer aux cavaliers de Roncevaux", "outcomes": [{"w": 1, "text": "Les cavaliers le ligotent sans un mot et vous jettent une bourse. La Maison saura s'en souvenir.", "gold": 90, "standing": {"roncevaux": 6}, "morale": -3}]},
				{"id": "pass", "label": "Passer son chemin", "outcomes": [{"w": 1, "text": "Vous détournez les yeux. Derrière vous, il maudit le ciel à mi-voix."}]},
			]},
		{"id": "dst_2", "title": "Les cavaliers de Roncevaux",
			"text": "Trois jours plus tard, un galop fait trembler la route. Une dizaine de cavaliers aux armes de Roncevaux encerclent la compagnie. Leur sergent regarde vos chariots, puis vous. « On cherche un lâche. Qu'avez-vous à dire ? »",
			"choices": [
				{"id": "lie", "label": "Mentir : « Nous n'avons vu personne. »", "outcomes": [
					{"w": 2, "text": "Le sergent plisse les yeux, puis lève la main : la troupe repart. Le soldat sort de sa cachette, livide, et jure de vous suivre jusqu'en enfer.", "recruit_story": "dst_soldat", "standing": {"roncevaux": -2}, "bond": "friends"},
					{"w": 1, "text": "Un cavalier soulève la bâche. Les lames sortent !", "battle": {"type": "b", "d": 2}, "standing": {"roncevaux": -8}},
				]},
				{"id": "pay", "label": "Acheter le silence du sergent (120 couronnes)", "cost": 120, "outcomes": [{"w": 1, "text": "Le sergent compte les pièces, tourne bride sans un mot. Le déserteur, sauvé, s'engage dans la compagnie.", "recruit_story": "dst_soldat", "standing": {"roncevaux": -1}}]},
				{"id": "yield", "label": "Livrer l'homme", "outcomes": [{"w": 1, "text": "Le sergent hoche la tête. Le fuyard hurle votre nom quand on l'emmène. Roncevaux vous récompense.", "gold": 60, "standing": {"roncevaux": 5}, "morale": -4}]},
			]},
	]},
	"veuve": {"n": "La veuve du meunier", "min_day": 6, "start": "veu_1", "steps": [
		{"id": "veu_1", "title": "Le moulin silencieux",
			"text": "Un moulin à eau dont la roue ne tourne plus. Sur le seuil, une femme en noir tient un enfant par la main. « Mon mari est mort le mois dernier. Le bailli veut la dette ou le moulin. Aidez-nous, au nom de Dieu. »",
			"choices": [
				{"id": "pay", "label": "Payer la dette (150 couronnes)", "cost": 150, "outcomes": [{"w": 1, "text": "Elle pleure en vous serrant les mains. « Revenez dans une semaine, je vous le rendrai. »", "renown": 6, "flag": "veu_paye", "schedule": {"id": "veu_2", "days": 6}}]},
				{"id": "talk", "label": "Aller parler au bailli (1 jour)", "outcomes": [
					{"w": 2, "text": "Le bailli rechigne, puis cède quand vos hommes s'adossent au mur. La dette est effacée.", "days": 1, "renown": 8, "flag": "veu_menace", "schedule": {"id": "veu_2", "days": 5}},
					{"w": 1, "text": "Le bailli appelle ses gardes. Il faut s'expliquer à coups de gourdin.", "days": 1, "battle": {"type": "b", "d": 1}, "flag": "veu_menace", "schedule": {"id": "veu_2", "days": 5}},
				]},
				{"id": "pass", "label": "Murmurer vos regrets et repartir", "outcomes": [{"w": 1, "text": "Vous poursuivez. Le moulin reste muet.", "morale": -2}]},
			]},
		{"id": "veu_2", "title": "Le moulin tourne de nouveau",
			"text": "La roue clapote quand la compagnie repasse. La veuve vous attend sur le seuil avec un pain tout chaud, son fils à côté d'elle. L'adolescent a ramassé une vieille hache de son père : « Je veux apprendre à me battre, comme eux. »",
			"choices": [
				{"id": "take", "label": "Prendre le garçon dans la compagnie", "outcomes": [{"w": 1, "text": "La veuve hésite, puis hoche la tête. Tom a de bons bras, et le cœur sur la main.", "recruit_story": "meunier_fils", "renown": 4, "flag": "veu_fils"}]},
				{"id": "flour", "label": "Accepter les provisions qu'elle offre", "outcomes": [{"w": 1, "text": "Vous repartez avec des sacs de farine et des galettes encore tièdes.", "food": 30, "morale": 4}]},
				{"id": "pass", "label": "Refuser avec reconnaissance", "outcomes": [{"w": 1, "text": "Elle sourit, les yeux brillants. « Que Dieu garde la Compagnie. »", "renown": 5}]},
			]},
	]},
	"chevalier": {"n": "Le chevalier déchu", "min_day": 14, "start": "chv_1", "steps": [
		{"id": "chv_1", "title": "Un chevalier au bord de la route",
			"text": "Un homme en cotte rouillée est assis près d'un cheval mort, un heaume cabossé sur les genoux. Il se redresse avec dignité. « Sire Gaspard de Montfaucon. Dépouillé de mes terres par un cousin, abandonné par mes hommes. Je ne demande rien... qu'un peu de pain. »",
			"choices": [
				{"id": "feed", "label": "Lui donner à manger et l'écouter (1 jour)", "outcomes": [{"w": 1, "text": "Il parle toute la nuit de son fief perdu, de la trahison de son cousin. Il pourrait être utile... ou dangereux.", "days": 1, "food": -4, "flag": "chv_ecoute", "schedule": {"id": "chv_2", "days": 4}}]},
				{"id": "hire", "label": "Lui proposer une place dans la compagnie", "outcomes": [
					{"w": 1, "text": "Il refuse d'abord, par fierté. Puis il tend la main : « Je me battrai pour votre bannière, capitaine, jusqu'à ce que je puisse reprendre la mienne. »", "recruit_story": "chevalier", "flag": "chv_engage", "schedule": {"id": "chv_3", "days": 8}},
				]},
				{"id": "pass", "label": "Passer", "outcomes": [{"w": 1, "text": "Vous laissez le chevalier à son deuil."}]},
			]},
		{"id": "chv_2", "title": "Le message du cousin",
			"text": "Un messager vous rattrape, porteur d'un parchemin scellé de cire verte. Le cousin de Sire Gaspard offre 300 couronnes pour que la compagnie « oublie » le chevalier et le livre à ses gardes. De son côté, Gaspard propose en secret de partager le trésor de sa cave, s'il retrouve ses terres.",
			"choices": [
				{"id": "betray", "label": "Livrer le chevalier au cousin", "outcomes": [{"w": 1, "text": "Le chevalier vous regarde sans colère, puis se laisse emmener. 300 couronnes tintent dans votre bourse. Elles pèsent lourd.", "gold": 300, "morale": -6, "standing": {"marches": -4}}]},
				{"id": "help", "label": "Accepter le marché de Gaspard (contrat spécial)", "outcomes": [{"w": 1, "text": "Vous rendez le parchemin au messager, sans réponse. Un nouveau contrat vous attend bientôt.", "renown": 6, "contract": {"type": "b", "d": 2, "title": "Reprendre Montfaucon", "desc": "Les gardes du cousin tiennent la tour de Montfaucon. Chassez-les et rendez au chevalier ce qui lui revient.", "employer": "Sire Gaspard de Montfaucon", "pay": 520, "faction": "marches"}}]},
				{"id": "pass", "label": "Ne répondre à personne", "outcomes": [{"w": 1, "text": "Vous brûlez le parchemin. Le messager repart, vexé.", "renown": 2}]},
			]},
		{"id": "chv_3", "title": "Le fief de Montfaucon",
			"text": "Sire Gaspard vous attend à l'écart du camp, son heaume sous le bras. « Capitaine, j'ai reçu des nouvelles. Mon cousin marche vers la frontière avec une petite escorte. Je ne puis laver mon honneur seul. Me suivrez-vous ? »",
			"choices": [
				{"id": "ride", "label": "Le suivre : tendre une embuscade au cousin", "outcomes": [
					{"w": 2, "text": "L'embuscade est un modèle du genre. Le chevalier en larmes reprend sa bannière, vous donne une part du trésor familial.", "gold": 280, "renown": 20, "standing": {"marches": 6}, "xp_all": 10},
					{"w": 1, "text": "L'escorte est plus nombreuse que prévu : la bataille est dure.", "battle": {"type": "b", "d": 3}, "renown": 15, "standing": {"marches": 4}},
				]},
				{"id": "refuse", "label": "Refuser de se mêler d'une querelle de famille", "outcomes": [{"w": 1, "text": "Le chevalier incline la tête. Il restera, mais plus rien ne sera comme avant.", "morale": -3}]},
			]},
	]},
	"relique": {"n": "La relique volée", "min_day": 10, "start": "rel_1", "steps": [
		{"id": "rel_1", "title": "Le reliquaire",
			"text": "Un moine de l'Abbaye, hors d'haleine, vous barre le chemin. « On a volé la relique de saint Aldegonde ! Les voleurs ont pris la route des marais. Aidez-nous, et l'Ordre ne l'oubliera pas. Ils sont trois, peut-être davantage. »",
			"choices": [
				{"id": "chase", "label": "Partir sur leurs traces (1 jour)", "outcomes": [
					{"w": 2, "text": "Vous trouvez un campement abandonné et des traces menant à un moulin en ruine.", "days": 1, "flag": "rel_piste", "schedule": {"id": "rel_2", "days": 1}},
					{"w": 1, "text": "Vous tombez sur les voleurs avant d'avoir flairé le piège !", "days": 1, "battle": {"type": "b", "d": 2}, "flag": "rel_piste", "schedule": {"id": "rel_2", "days": 1}},
				]},
				{"id": "price", "label": "Réclamer d'abord une avance (60 couronnes)", "outcomes": [{"w": 1, "text": "Le moine soupire, vide sa bourse, et vous indique la piste. L'Ordre goûte peu le marchandage.", "gold": 60, "standing": {"abbaye": -3}, "flag": "rel_piste", "schedule": {"id": "rel_2", "days": 2}}]},
				{"id": "pass", "label": "Refuser : ce n'est pas votre affaire", "outcomes": [{"w": 1, "text": "Le moine s'éloigne, courbé. L'Ordre n'oubliera pas ce refus.", "standing": {"abbaye": -3}}]},
			]},
		{"id": "rel_2", "title": "Le moulin des marais",
			"text": "Dans la brume, un moulin à demi effondré. Une lueur tremble sous la porte. À l'intérieur, trois voleurs se disputent. L'un d'eux tient le reliquaire. Un moine, jeune et pâle, est ligoté dans un coin.",
			"choices": [
				{"id": "strike", "label": "Donner l'assaut", "outcomes": [
					{"w": 3, "text": "La surprise est totale. Les voleurs jettent leurs armes. Le moine en larmes baise le reliquaire.", "recruit_story": "relique_moine", "standing": {"abbaye": 10}, "renown": 20, "flag": "rel_sauve", "schedule": {"id": "rel_3", "days": 4}},
					{"w": 1, "text": "Le chef des voleurs a prévu votre venue : combat !", "battle": {"type": "b", "d": 2}, "standing": {"abbaye": 8}, "flag": "rel_sauve", "schedule": {"id": "rel_3", "days": 4}},
				]},
				{"id": "bargain", "label": "Marchander avec les voleurs (150 couronnes)", "cost": 150, "outcomes": [{"w": 1, "text": "Les voleurs rendent le reliquaire contre une bourse. Le moine est libéré. L'Ordre est reconnaissant, sans plus.", "standing": {"abbaye": 6}, "renown": 8, "flag": "rel_sauve", "schedule": {"id": "rel_3", "days": 4}}]},
				{"id": "keep", "label": "Garder la relique pour la revendre", "outcomes": [{"w": 1, "text": "Un reliquaire d'or et de cristal... Vos hommes ne disent rien, mais certains détournent le regard.", "gold": 350, "standing": {"abbaye": -15}, "morale": -8, "bond": "rivals"}]},
			]},
		{"id": "rel_3", "title": "La reconnaissance de l'Abbaye",
			"text": "Un abbé à barbe grise vous attend sur le parvis d'une chapelle. L'Ordre n'est pas riche, mais il est reconnaissant : il propose un don, ou une bénédiction qui réchauffera le cœur de la compagnie.",
			"choices": [
				{"id": "gold", "label": "Accepter le don de l'Abbaye", "outcomes": [{"w": 1, "text": "Une bourse pesante et une promesse d'hospitalité en tout lieu de l'Ordre.", "gold": 220, "standing": {"abbaye": 5}}]},
				{"id": "bless", "label": "Demander la bénédiction", "outcomes": [{"w": 1, "text": "L'abbé trace un signe sur chaque front. Les hommes se tiennent plus droit, et vos blessés respirent mieux.", "morale": 12, "hp_all": 12, "standing": {"abbaye": 5}}]},
			]},
	]},
	"jumeaux": {"n": "Les jumeaux disparus", "min_day": 8, "start": "jum_1", "steps": [
		{"id": "jum_1", "title": "Deux enfants, deux ombres",
			"text": "Sur le seuil d'une ferme, un vieux fermier vous arrête en pleurant. « Mes petits-enfants, Aelis et Aldric, ont disparu dans la forêt avant la tombée du soir. Les loups hurlent. Pitié ! »",
			"choices": [
				{"id": "search", "label": "Fouiller la forêt (1 jour)", "outcomes": [
					{"w": 3, "text": "Vous trouvez les jumeaux au pied d'un chêne, grelottants. Ils ont de bonnes jambes et de grands yeux.", "days": 1, "renown": 8, "flag": "jum_trouves", "schedule": {"id": "jum_2", "days": 5}},
					{"w": 1, "text": "Des loups vous attendaient dans la clairière.", "days": 1, "battle": {"type": "g", "d": 1}, "flag": "jum_trouves", "schedule": {"id": "jum_2", "days": 5}},
				]},
				{"id": "coin", "label": "Laisser quelques pièces et partir", "outcomes": [{"w": 1, "text": "Le fermier ferme la porte sans un mot.", "morale": -2}]},
			]},
		{"id": "jum_2", "title": "Les jumeaux roux",
			"text": "Cinq jours plus tard, deux silhouettes rousses courent à votre rencontre sur la route, un baluchon sur le dos. Aelis sait tirer à l'arc, Aldric manie la hache comme un grand. « On veut venir avec vous, pour de bon ! »",
			"choices": [
				{"id": "both", "label": "Les engager tous les deux", "outcomes": [{"w": 1, "text": "Les deux frères sautent dans un chariot, ravis. Ils ne se quitteront plus, et les hommes les adopteront vite.", "recruit_story": "jumeau_a", "renown": 5, "flag": "jum_engages", "schedule": {"id": "jum_3", "days": 1}}]},
				{"id": "one", "label": "N'engager qu'Aelis, l'archère", "outcomes": [{"w": 1, "text": "Aldric boude, mais Aelis a déjà bouclé son sac.", "recruit_story": "jumeau_a"}]},
				{"id": "none", "label": "Les renvoyer chez leur grand-père", "outcomes": [{"w": 1, "text": "Les jumeaux repartent, la tête basse, mais le fermier vous envoie un jambon.", "food": 12}]},
			]},
		{"id": "jum_3", "title": "Le frère qui s'attarde",
			"text": "Aldric marche à la traîne, tête basse. Il n'a pas encore quitté son village du regard. « Capitaine, je ne sais pas si je serai assez bon... »",
			"choices": [
				{"id": "enc", "label": "L'encourager devant la compagnie", "outcomes": [{"w": 1, "text": "Quelques vétérans lui donnent une tape dans le dos. Il rit, s'ébroue, et vient de gagner sa place.", "recruit_story": "jumeau_b", "morale": 5, "bond": "friends"}]},
				{"id": "hard", "label": "Le laisser faire ses preuves seul", "outcomes": [{"w": 1, "text": "Aldric serre les dents et suit. Il se fera ses amis plus tard.", "recruit_story": "jumeau_b"}]},
			]},
	]},
	"necropole": {"n": "Le pacte de la nécropole", "min_day": 18, "start": "nec_1", "steps": [
		{"id": "nec_1", "title": "L'émissaire pâle",
			"text": "Un cavalier en cape grise barre la route à la tombée de la nuit. Son visage est blanc comme la cire, sa voix douce. « Capitaine, je viens de la nécropole. Mon maître ne veut pas de votre mal. Il cherche un allié qui entende raison. En échange de votre bienveillance, il offre un présent. »",
			"choices": [
				{"id": "listen", "label": "Écouter son offre", "outcomes": [{"w": 1, "text": "Il dépose un coffret ancien devant vous. « Une preuve de sincérité. Nous nous reverrons. »", "unique": "u_heaume_veilleur", "flag": "nec_ecoute", "schedule": {"id": "nec_2", "days": 5}}]},
				{"id": "fight", "label": "Dégainer : on ne parle pas aux morts", "outcomes": [{"w": 1, "text": "L'émissaire s'évapore dans la brume en ricanant. Une cohorte d'ombres vous tombe dessus !", "battle": {"type": "u", "d": 2}, "renown": 10, "standing": {"abbaye": 4}}]},
				{"id": "flee", "label": "Faire demi-tour sans un mot", "outcomes": [{"w": 1, "text": "Vous contournez le cavalier. Son regard vous brûle le dos.", "morale": -2}]},
			]},
		{"id": "nec_2", "title": "Le prix du cadeau",
			"text": "L'émissaire revient, plus pâle encore. Il demande un service : laisser passer un convoi de chariots couverts, sans poser de questions. Dans l'un d'eux, vous entendez des gémissements. L'Abbaye offre de son côté de l'argent pour que vous le dénonciez.",
			"choices": [
				{"id": "allow", "label": "Laisser passer le convoi", "outcomes": [{"w": 1, "text": "Les chariots défilent dans le silence. Vos hommes évitent de se regarder. La menace grandit quelque part.", "gold": 250, "threat": 8, "standing": {"abbaye": -8}, "morale": -6, "flag": "nec_complice", "schedule": {"id": "nec_3", "days": 6}}]},
				{"id": "block", "label": "Barrer la route au convoi", "outcomes": [
					{"w": 1, "text": "Les chariots s'immobilisent. Des morts-vivants en jaillissent !", "battle": {"type": "u", "d": 2}, "renown": 20, "threat": -6, "standing": {"abbaye": 8}, "flag": "nec_rompu", "schedule": {"id": "nec_3", "days": 5}},
				]},
				{"id": "report", "label": "Prévenir l'Abbaye (1 jour)", "outcomes": [{"w": 1, "text": "Les moines-soldats interceptent le convoi. Ils vous remercient et vous remettent une bourse.", "days": 1, "gold": 150, "renown": 15, "standing": {"abbaye": 10}, "threat": -4, "flag": "nec_rompu"}]},
			]},
		{"id": "nec_3", "title": "La dette de la nécropole",
			"text": "Une jeune femme, transie, s'est glissée parmi vos hommes. Ysolde, ancienne servante du nécromant : elle jure être lasse des morts. « Il vous croit lié à lui, capitaine. Il viendra bientôt réclamer son dû. Je peux vous aider à rompre le pacte. »",
			"choices": [
				{"id": "take", "label": "L'accueillir et rompre le pacte", "outcomes": [{"w": 1, "text": "Ysolde brise l'amulette de cendre du nécromant sur une pierre. Elle ne vous quittera plus.", "recruit_story": "necro_apostat", "threat": -4, "morale": 4}]},
				{"id": "turn", "label": "La livrer à l'émissaire", "outcomes": [{"w": 1, "text": "Elle ne crie même pas. L'émissaire s'incline et disparaît dans la nuit. Vos hommes sont livides.", "gold": 180, "morale": -10, "bond": "rivals", "threat": 4}]},
				{"id": "send", "label": "La renvoyer sans l'aide de la compagnie", "outcomes": [{"w": 1, "text": "Elle repart seule dans la nuit. Personne ne sait ce qu'elle est devenue."}]},
			]},
	]},
}
