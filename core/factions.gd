class_name Factions
extends RefCounted
## Factions humaines (Data.FACTIONS) : propriété des lieux, réputation, effets de la réputation. Logique pure.
## Chaque lieu porte `settlement["owner"]` (clé de Data.FACTIONS) ; chaque contrat ordinaire porte `contract["faction"]` (l'employeur)
## et parfois `contract["vs_faction"]` (la faction rivale que la mission dessert).
## Relations : voir `relation` (alliées, rivales, neutres ; Data.FACTION_ALLIES / FACTION_RIVALS).

const LEGACY_KEYS: Array = ["roncevaux", "lys", "abbaye", "marches"]  ## factions des anciens mondes (8 lieux)
const REL_OWN: int = 2
const REL_ALLY: int = 1
const REL_NEUTRAL: int = 0
const REL_RIVAL: int = -1
const SPILL_RIVAL: int = 1  ## réputation perdue chez chaque rivale d'un employeur qu'on sert
const SPILL_ALLY: int = 1  ## réputation gagnée chez chaque alliée d'un employeur qu'on sert
const VS_CHANCE: float = 0.25  ## part des contrats de combat dirigés contre une faction rivale
const VS_PAY_MULT: float = 1.25
const GAIN_BASE: int = 3  ## réputation gagnée en remplissant un contrat : GAIN_BASE + danger
const VS_LOSS: int = 3
const ABANDON_LOSS: int = 2
const DEFEAT_LOSS: int = 1


static func keys() -> Array:
	return Data.FACTIONS.keys()


## Relation entre deux factions : REL_OWN (la même), REL_ALLY, REL_RIVAL ou REL_NEUTRAL. Symétrique.
static func relation(a: String, b: String) -> int:
	if a == b:
		return REL_OWN
	for pr in Data.FACTION_ALLIES:
		if (pr[0] == a and pr[1] == b) or (pr[0] == b and pr[1] == a):
			return REL_ALLY
	for pr in Data.FACTION_RIVALS:
		if (pr[0] == a and pr[1] == b) or (pr[0] == b and pr[1] == a):
			return REL_RIVAL
	return REL_NEUTRAL


static func rivals_of(key: String) -> Array:
	return _related(key, REL_RIVAL)


static func allies_of(key: String) -> Array:
	return _related(key, REL_ALLY)


static func _related(key: String, rel: int) -> Array:
	var out: Array = []
	for k in Data.FACTIONS:
		if k != key and relation(key, str(k)) == rel:
			out.append(k)
	return out


## Factions qui ont un territoire à défendre (hors cités libres).
static func playable_keys() -> Array:
	return Data.FACTIONS.keys().filter(func(k: Variant) -> bool: return not bool(Data.FACTIONS[k].get("neutral", false)))


## Contrecoups, sur les autres factions, d'un service rendu à `key` : {faction: delta} (rivales −, alliées +).
static func spill(key: String) -> Dictionary:
	var out: Dictionary = {}
	for r in rivals_of(key):
		out[r] = -SPILL_RIVAL
	for a in allies_of(key):
		out[a] = SPILL_ALLY
	return out


static func name_of(key: String) -> String:
	return str(Data.FACTIONS.get(key, {}).get("n", "Inconnue"))


static func color_of(key: String) -> Color:
	return Data.FACTIONS.get(key, {}).get("color", Color("a8997e"))


static func default_standing() -> Dictionary:
	var out: Dictionary = {}
	for k in Data.FACTIONS:
		out[k] = 0
	return out


## Réputations lues dans une sauvegarde : toutes les factions, bornées.
static func normalize_standing(raw: Variant) -> Dictionary:
	var out: Dictionary = default_standing()
	if typeof(raw) == TYPE_DICTIONARY:
		for k in out:
			out[k] = clampi(int((raw as Dictionary).get(k, 0)), -Data.FACTION_STAND_MAX, Data.FACTION_STAND_MAX)
	return out


static func owner_of(s: Dictionary) -> String:
	return str(s.get("owner", ""))


## Attribue un propriétaire à chaque lieu qui n'en a pas. Sans propriétaire du tout (nouvelle partie) : une graine par faction,
## espacées au maximum, puis chaque lieu rejoint la graine la plus proche (territoires d'un seul tenant). Sinon les lieux
## manquants prennent le propriétaire du lieu possédé le plus proche (migration).
static func assign_owners(world: World) -> void:
	var fk: Array = playable_keys() if world.grand else LEGACY_KEYS  ## un ancien monde (8 lieux) garde ses quatre factions d'origine
	var all: Array = world.settlements
	if all.is_empty():
		return
	var owned: Array = all.filter(func(s: Dictionary) -> bool: return Data.FACTIONS.has(owner_of(s)))
	if owned.size() == all.size():
		return
	if owned.is_empty():
		var seeds: Array = [all[0]]
		var n: int = mini(fk.size(), all.size())
		while seeds.size() < n:
			var best: Dictionary = {}
			var best_d: float = -1.0
			for s in all:
				if seeds.has(s):
					continue
				var md: float = 1e12
				for sd in seeds:
					md = minf(md, world.settlement_pos(s).distance_to(world.settlement_pos(sd)))
				if md > best_d:
					best_d = md
					best = s
			seeds.append(best)
		for i in seeds.size():
			seeds[i]["owner"] = str(fk[i])
		owned = seeds
	for s in all:
		if Data.FACTIONS.has(owner_of(s)):
			continue
		var near: Dictionary = owned[0]
		var nd: float = 1e12
		for o in owned:
			var d: float = world.settlement_pos(s).distance_to(world.settlement_pos(o))
			if d < nd:
				nd = d
				near = o
		s["owner"] = owner_of(near)


## « Neutre », « Estimé »… d'après la réputation `n` auprès d'une faction.
static func label(n: int) -> String:
	if n >= Data.FACTION_STAND_BEST:
		return "Allié"
	if n >= Data.FACTION_STAND_GOOD:
		return "Estimé"
	if n <= Data.FACTION_STAND_WORST:
		return "Ennemi"
	if n <= Data.FACTION_STAND_BAD:
		return "Méfiant"
	return "Neutre"


## Prime majorée avec une bonne réputation.
static func pay_mult(n: int) -> float:
	if n >= Data.FACTION_STAND_BEST:
		return 1.2
	if n >= Data.FACTION_STAND_GOOD:
		return 1.1
	return 1.0


## Prix majorés avec une mauvaise réputation.
static func price_mult(n: int) -> float:
	if n <= Data.FACTION_STAND_WORST:
		return 1.25
	if n <= Data.FACTION_STAND_BAD:
		return 1.1
	return 1.0


## Texte résumant les effets de la réputation `n`.
static func effects_text(n: int) -> String:
	if n >= Data.FACTION_STAND_BEST:
		return "Primes +20 %, recrues d'élite, marchand rare sur ses terres."
	if n >= Data.FACTION_STAND_GOOD:
		return "Primes +10 %, recrues d'élite sur ses terres."
	if n <= Data.FACTION_STAND_WORST:
		return "Prix +25 % sur ses terres, patrouilles hostiles."
	if n <= Data.FACTION_STAND_BAD:
		return "Prix +10 % sur ses terres."
	return "Aucun effet particulier."


## Marque un contrat de l'employeur `owner` ; certains combats servent en secret la faction rivale (prime majorée, réputation en baisse chez elle).
static func tag_contract(c: Dictionary, owner: String, rng: RandomNumberGenerator) -> void:
	if not Data.FACTIONS.has(owner):
		return
	c["faction"] = owner
	var tk: String = str(c.get("type_contract", "kill"))
	var rivals: Array = rivals_of(owner)
	if (tk == "kill" or tk == "hunt") and not c.has("arc") and not rivals.is_empty() and rng.randf() < VS_CHANCE:
		var vs: String = str(rivals[rng.randi() % rivals.size()])
		c["vs_faction"] = vs
		c["pay"] = int(round(float(c["pay"]) * VS_PAY_MULT / 5.0)) * 5
		c["desc"] = str(c.get("desc", "")) + " Le commanditaire précise que %s tient la bande en sous-main." % name_of(vs)


## Majore la prime d'un contrat selon la réputation de son employeur.
static func apply_pay(c: Dictionary, standing: int) -> void:
	var m: float = pay_mult(standing)
	if m > 1.0:
		c["pay"] = int(round(float(c["pay"]) * m / 5.0)) * 5


## Une recrue d'élite (niveau 3, un talent, meilleur prix) pour les lieux d'une faction amie.
static func make_elite_recruit(rng: RandomNumberGenerator, taken: Array) -> Dictionary:
	var rec: Array = Contracts.gen_recruits(rng, taken, ["milicien", "deserteur", "reitre"], 1)
	var u: Unit = rec[0]["u"]
	u.level = 3
	u.xp = int(Data.XP_THRESHOLDS[3])
	u.perk_points = 1
	u.hp_max += 6
	u.hp = u.hp_max
	u.melee_skill += 5
	u.resolve += 4
	u.wage = int(round(float(u.wage) * 1.3))
	return {"u": u, "price": int(round(float(rec[0]["price"]) * 1.7 / 5.0)) * 5}


## Objets rares forcés chez un allié (`taken` : uniques déjà sortis). Graine stable par lieu et par jour.
static func forced_rare(s: Dictionary, day: int, taken: Array) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = day * 1291 + int(str(s["id"]).trim_prefix("s")) * 211 + 5
	var pool: Array = Uniques.available(taken)
	var out: Array = []
	for i in mini(pool.size(), 2):
		var k: String = str(pool.pop_at(r.randi() % pool.size()))
		out.append({"item": Uniques.item_of(k), "price": Uniques.rare_price(k)})
	return out
