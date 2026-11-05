class_name Contracts
extends RefCounted
## Génération des recrues, des ennemis et des contrats. Aléa injecté.


static func pick(arr: Array, rng: RandomNumberGenerator) -> Variant:
	return arr[rng.randi() % arr.size()]


static func _roll(range_: Array, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(int(range_[0]), int(range_[1]))


static func random_name(taken: Array, rng: RandomNumberGenerator) -> String:
	for i in 30:
		var n: String = str(pick(Data.FIRST_NAMES, rng))
		if rng.randf() < 0.65:
			n += " " + str(pick(Data.NICKNAMES, rng))
		if not taken.has(n):
			return n
	return str(pick(Data.FIRST_NAMES, rng)) + " " + str(rng.randi_range(2, 9))


static func make_unit(t: Dictionary, side: String, unit_name: String, rng: RandomNumberGenerator) -> Unit:
	var u := Unit.new()
	u.id = Unit.alloc_id()
	u.unit_name = unit_name
	u.background = t["n"]
	u.side = side
	u.head = str(pick(t["head"], rng))
	u.body = str(pick(t["body"], rng))
	u.weapon = str(pick(t["w"], rng))
	u.hp_max = _roll(t["hp"], rng)
	u.fat_max = _roll(t["fat"], rng)
	u.resolve = _roll(t["res"], rng)
	u.melee_skill = _roll(t["mSk"], rng)
	u.ranged_skill = _roll(t["rSk"], rng)
	u.melee_def = _roll(t["mDef"], rng)
	u.ranged_def = _roll(t["rDef"], rng)
	u.initiative = _roll(t["ini"], rng)
	u.shield = bool(Data.WPN[u.weapon]["h1"]) and rng.randf() < float(t["sh"])
	u.hp = u.hp_max
	u.arm_h = u.head_armor_max()
	u.arm_b = u.body_armor_max()
	return u


static func make_merc(key: String, rng: RandomNumberGenerator, taken: Array) -> Unit:
	var t: Dictionary = Data.BG[key]
	var u: Unit = make_unit(t, "p", random_name(taken, rng), rng)
	u.faction = "p"
	u.wage = int(t["wage"])
	Traits.assign(u)  ## 1 ou 2 traits de caractère (graine dérivée de l'id : l'aléa de la partie n'est pas touché)
	return u


static func make_foe(key: String, rng: RandomNumberGenerator, difficulty: String = "normal") -> Unit:
	var t: Dictionary = Data.FOE[key]
	var u: Unit = make_unit(t, "e", t["n"], rng)
	if Difficulty.coef(difficulty, "foe_stats") != 1.0:  ## niveau de difficulté : PV et compétences
		u.hp_max = Difficulty.foe_stat(difficulty, u.hp_max)
		u.hp = u.hp_max
		u.melee_skill = Difficulty.foe_stat(difficulty, u.melee_skill)
		u.ranged_skill = Difficulty.foe_stat(difficulty, u.ranged_skill)
	u.faction = t["fac"]
	u.xp_value = int(t["xp"])
	u.leader = bool(t["leader"])
	u.perks.assign(t.get("perks", []))  ## chefs : talents fixes
	u.foe_key = key
	u.sprite = str(t.get("sprite", ""))
	return u


## `count` recrues tirées parmi les origines `keys` : [{"u": Unit, "price": int}].
static func gen_recruits(rng: RandomNumberGenerator, taken: Array, keys: Array = [], count: int = 4) -> Array:
	if keys.is_empty():
		keys = Data.BG.keys()
	var pool: Array = []
	for k in keys:
		for i in int(Data.BG[k]["wt"]):
			pool.append(k)
	var out: Array = []
	var names: Array = taken.duplicate()
	for i in count:
		var k: String = str(pick(pool, rng))
		var u: Unit = make_merc(k, rng, names)
		names.append(u.unit_name)
		var price: int = int(round(float(Data.BG[k]["price"]) * (0.85 + rng.randf() * 0.3) / 5.0)) * 5
		out.append({"u": u, "price": price})
	return out


const _BANDITS: Array = [
	[],
	["brigand", "brigand", "brigand", "archer"],
	["brigand", "brigand", "brigand", "archer", "archer", "balafre"],
	["brigand", "brigand", "brigand", "archer", "archer", "balafre", "balafre", "chef"],
]
const _GHOULS: Array = [
	[],
	["goule", "goule", "goule"],
	["goule", "goule", "goule", "goule", "vorace"],
	["goule", "goule", "goule", "goule", "goule", "vorace", "vorace"],
]
const _ORCS: Array = [
	[],
	["orc_jeune", "orc_jeune", "orc_jeune", "orc_guerrier"],
	["orc_jeune", "orc_jeune", "chaman_orc", "orc_guerrier", "orc_guerrier", "berserker"],
	["orc_jeune", "chaman_orc", "orc_guerrier", "orc_guerrier", "orc_guerrier", "berserker", "berserker", "orc_chef"],
]
const _BEASTS: Array = [
	[],
	["loup", "loup", "loup", "loup"],
	["loup", "loup", "loup", "loup", "cavalier_loup", "cavalier_loup"],
	["loup", "loup", "loup", "cavalier_loup", "cavalier_loup", "ogre", "troll"],
]
const _UNDEAD: Array = [
	[],
	["squelette", "squelette", "squelette", "zombie"],
	["squelette", "squelette", "squelette", "squelette_archer", "squelette_archer", "zombie", "zombie"],
	["squelette", "squelette", "squelette", "squelette_archer", "squelette_archer", "zombie", "zombie", "necro"],
]

const KINDS: Array = ["kill", "hunt", "escort", "delivery"]  ## valeurs de contract["type_contract"]


## Effectif d'une bande de faction `type` ("b", "g", "o", "u") au danger 1-3.
static func foes_for(type: String, danger: int) -> Array:
	var table: Array
	match type:
		"g":
			table = _GHOULS
		"o":
			table = _ORCS
		"u":
			table = _UNDEAD
		"m":
			table = _BEASTS
		_:
			table = _BANDITS
	return (table[clampi(danger, 1, 3)] as Array).duplicate()


## Chasse au chef : un seul chef puissant, flanqué d'une petite escorte (2 + danger hommes en tout).
static func hunt_foes(type: String, danger: int) -> Array:
	var leader: String = str(Data.FACTION_LEADER[type])
	var out: Array = [leader]
	for k in foes_for(type, danger):
		if out.size() >= 2 + danger:
			break
		if not bool(Data.FOE[k]["leader"]) and k != leader:
			out.append(k)
	return out


## Factions que le renom permet de rencontrer (liste à tirer : les doublons pèsent).
static func factions_for(renown: int) -> Array:
	var out: Array = ["b", "b", "g"]
	if renown >= int(Data.FACTION_MIN_RENOWN["u"]):
		out.append("u")
	if renown >= int(Data.FACTION_MIN_RENOWN["o"]):
		out.append("o")
	if renown >= int(Data.FACTION_MIN_RENOWN["m"]):
		out.append("m")
	return out


const _BEAST_TITLES: Array = ["Chasse aux monstres : la meute de {town}", "Bêtes sur les chemins de {town}", "Les loups de {town}"]
const _BEAST_DESCS: Array = [
	"Des bêtes énormes rôdent autour de {town}. Les bergers n'osent plus sortir.",
	"On a retrouvé des troupeaux entiers dévorés. Le syndic paie pour qu'on en finisse.",
	"Quelque chose hurle la nuit près de {town}. Rapportez des preuves.",
]


## Type de bataille d'un contrat : convoi pour une escorte, nuit pour environ un contrat sur six (tirage déterministe, sans toucher à l'aléa de la partie).
static func battle_type_for(c: Dictionary) -> String:
	if str(c.get("type_contract", "kill")) == "escort":
		return "convoy"
	if (hash(str(c.get("title", ""))) + int(c.get("pay", 0))) % 100 < 16:
		return "night"
	return "pitched"


## Rend un contrat lu depuis du JSON utilisable (nombres entiers / flottants).
static func normalize(c: Dictionary) -> Dictionary:
	var cc: Dictionary = c.duplicate()
	for k in ["d", "days", "pay", "arc_step", "wave", "renown"]:
		if cc.has(k):
			cc[k] = int(c[k])
	for k in ["tx", "ty", "ox", "oy", "ambush_at"]:
		if cc.has(k):
			cc[k] = float(c[k])
	if cc.has("party_id"):
		cc["party_id"] = int(c["party_id"])
	if not cc.is_empty() and cc.get("kind", "contract") == "contract" and not cc.has("type_contract"):
		cc["type_contract"] = "kill"  # anciennes sauvegardes
	return cc


static func is_transport(c: Dictionary) -> bool:
	return str(c.get("type_contract", "kill")) in ["escort", "delivery"]


static func _flavor(type: String, town: String, rng: RandomNumberGenerator) -> Array:
	var f: Array = pick(ContractTexts.FLAVOR.get(type, ContractTexts.FLAVOR["b"]), rng)
	return [str(f[0]).replace("{town}", town), str(f[1]).replace("{town}", town)]


## Un contrat de transport (escorte / livraison) vers `ds`.
static func _transport(kind: String, type: String, d: int, town: String, origin_id: String, origin: Vector2, ds: Dictionary, pay_mult: float, rng: RandomNumberGenerator, world: World) -> Dictionary:
	var target: Vector2 = world.settlement_pos(ds)
	var days: int = maxi(1, int(ceil(world.path_days(world.find_path(origin, target)))))
	var escort: bool = kind == "escort"
	var ambush: bool = rng.randf() < 0.2 + 0.15 * d + (0.1 if escort else 0.0)
	var at: float = rng.randf_range(0.3, 0.7) if ambush else -1.0
	var pay: int = int(round((d * 90 + days * (45 if escort else 35) + rng.randi_range(0, 20) * 5) * pay_mult / 5.0)) * 5
	var desc_txt: String = str(pick(ContractTexts.ESCORT if escort else ContractTexts.DELIVERY, rng)).replace("{dest}", str(ds["name"]))
	return {
		"kind": "contract", "type": type, "type_contract": kind, "d": d, "foes": foes_for(type, d),
		"title": ("Escorte vers " if escort else "Livraison à ") + str(ds["name"]), "desc": desc_txt,
		"employer": str(pick(Data.EMPLOYERS, rng)) + " de " + town, "origin": town, "origin_id": origin_id,
		"pay": pay, "days": days, "tx": target.x, "ty": target.y, "target_name": str(ds["name"]),
		"dest_id": str(ds["id"]), "ambush_at": at, "ox": origin.x, "oy": origin.y,
		"biome": world.biome_at(origin.lerp(target, at if ambush else 0.5)),
	}


## Contrats proposés par un lieu. Un contrat :
## {kind, type (faction), type_contract ("kill"|"hunt"|"escort"|"delivery"), d, foes, title, desc, employer, origin,
##  origin_id, pay, days (estimation), tx, ty, ox, oy, target_name, biome}
## Transports (escort/delivery) : + dest_id, ambush_at (part du trajet [0..1] où tombe l'embuscade, -1 = aucune).
## `standing` (réputation du lieu) joue sur le danger et la prime.
static func gen_contracts(renown: int, rng: RandomNumberGenerator, town: String, origin: Vector2, world: World, count: int, standing: int = 0, origin_id: String = "") -> Array:
	var out: Array = []
	var base: int = mini(3, 1 + renown / 160)
	if standing >= 5:
		base = mini(3, base + 1)
	elif standing <= -5:
		base = maxi(1, base - 1)
	var pay_mult: float = 1.0 + clampf(float(standing) * 0.01, -0.1, 0.1)
	for i in count:
		var kind: String = "kill" if i == 0 else str(pick(["kill", "kill", "hunt", "escort", "delivery"], rng))  ## le premier est toujours une mission classique
		var d: int = clampi(base + int(pick([-1, 0, 0, 1], rng)), 1, 3)
		var type: String = str(pick(factions_for(renown), rng))
		if type == "o":
			d = maxi(d, 2)
		var c: Dictionary = {}
		if kind == "escort" or kind == "delivery":
			var dests: Array = []
			if origin_id != "":
				for s in world.settlements:
					if str(s["id"]) != origin_id and (not world.grand or origin.distance_to(world.settlement_pos(s)) <= world.target_hi) and not world.find_path(origin, world.settlement_pos(s)).is_empty():
						dests.append(s)
			if dests.is_empty():
				kind = "kill"
			else:
				c = _transport(kind, type, d, town, origin_id, origin, pick(dests, rng), pay_mult, rng, world)
		if c.is_empty():
			var target: Vector2 = world.random_target(origin, world.target_lo, world.target_hi)
			if target == Vector2.ZERO:
				continue
			d = clampi(d + world.region_danger(target), 1, 3)  ## danger régional : +1 loin du départ (grand monde)
			var fl: Array = _flavor(type, town, rng)
			var title: String = fl[0]
			var desc: String = fl[1]
			var foes: Array = foes_for(type, d)
			if type == "m":
				title = str(pick(_BEAST_TITLES, rng)).replace("{town}", town)
				desc = str(pick(_BEAST_DESCS, rng)).replace("{town}", town)
			var days: int = maxi(1, int(ceil(origin.distance_to(target) / World.DAY_PX)))
			var pay: int = d * 320 + rng.randi_range(0, 30) * 5 + (d * 60 if type != "b" else 0) + days * 20
			if kind == "hunt":
				var leader: String = str(Data.FACTION_LEADER[type])
				title = "Chasse au chef : " + str(Data.FOE[leader]["n"])
				desc = str(pick(ContractTexts.HUNT, rng)) % str(Data.FOE[leader]["n"]).to_lower()
				foes = hunt_foes(type, d)
				pay = int(pay * 1.6)
			pay = int(round(pay * pay_mult / 5.0)) * 5
			c = {
				"kind": "contract", "type": type, "type_contract": kind, "d": d, "foes": foes, "title": title, "desc": desc,
				"employer": str(pick(Data.EMPLOYERS, rng)) + " de " + town, "origin": town, "origin_id": origin_id,
				"pay": pay, "days": days, "tx": target.x, "ty": target.y, "ox": origin.x, "oy": origin.y,
				"target_name": str(pick(Data.TARGET_NAMES[type], rng)), "biome": world.biome_at(target),
			}
		c["battle_type"] = battle_type_for(c)
		out.append(c)
	return out
