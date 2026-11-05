class_name Campaign
extends RefCounted
## Contenu de campagne : lieux hostiles (forts, repaires, nécropoles, citadelle), marchand rare, arcs de contrats liés
## et crise finale (jauge de menace, escalade, contrat final). Logique pure : l'aléa est injecté, l'état vit dans un
## dictionnaire (`Game.campaign`) sérialisable tel quel.
##
## État (`Game.campaign`) :
##   threat (0-100), faction ("o" ou "u" : la menace), stage (0-3), final ("locked" | "open" | "won"), free_mode,
##   ending_pending (l'écran de fin doit s'afficher), uniques_taken (clés d'objets uniques sortis), sites_taken,
##   arcs : {id d'arc: {phase "posted"|"taken"|"done", step, origin_id, origin, contract, log}}, log (récit des arcs terminés).

const START_SITES: Array = ["fort", "lair", "necropolis"]
const GRAND_SITES: Dictionary = {"fort": 4, "lair": 4, "necropolis": 3}  ## lieux hostiles de départ dans le grand monde (par type)
const THREAT_PER_DAY: float = 0.45
const THREAT_PER_RENOWN: float = 0.0004  ## en plus, par jour et par point de renom
const THREAT_MAX: float = 100.0
const STAGES: Array = [25.0, 50.0, 75.0]
const FINAL_RENOWN: int = 600  ## renom qui ouvre le contrat final (menace d'au moins FINAL_MIN_THREAT) ; menace 100 = ouvert d'office
const FINAL_MIN_THREAT: float = 50.0
const SITE_THREAT_RELIEF: float = 6.0  ## menace en moins quand on prend un lieu de la faction menaçante
const ARC_THREAT_RELIEF: float = 4.0
const RESPAWN_DAYS: int = 45  ## délai avant qu'un lieu libéré (« cleared ») soit réoccupé
const SITE_REST_HEAL: int = 15
const ARC_STEPS: int = 3

## Lieux hostiles. `after` : « friendly » (base amie : on s'y repose) ou « cleared » (libéré, puis réoccupé).
const SITE_TYPES: Dictionary = {
	"fort": {
		"faction": "b", "label": "Fort de brigands", "after": "friendly", "pay": 900, "renown": 120, "loot": 2, "unique": 0.35,
		"names": ["Fort-aux-Pendus", "Donjon de la Couleuvre", "Fortin des Écorcheurs", "Tour du Péager"],
	},
	"lair": {
		"faction": "o", "label": "Repaire d'orcs", "after": "cleared", "pay": 1100, "renown": 150, "loot": 2, "unique": 0.4,
		"names": ["Palissade de Krag", "Camp des Dents-Rouges", "Hutte-aux-Crânes", "Repaire de Gor-Maug"],
	},
	"necropolis": {
		"faction": "u", "label": "Nécropole", "after": "cleared", "pay": 1100, "renown": 150, "loot": 2, "unique": 0.4,
		"names": ["Nécropole de Morteval", "Cryptes de Val-Cendre", "Tertre des Veilleurs", "Ossuaire d'Ombrelune"],
	},
	"citadel": {
		"faction": "", "label": "Citadelle", "after": "cleared", "pay": 3500, "renown": 500, "loot": 3, "unique": 1.0,
		"names": [],
	},
}
const CITADEL_NAMES: Dictionary = {"o": "Forteresse de Gor-Khan", "u": "Nécropole du Roi blême"}
const THREAT_TITLES: Dictionary = {"o": "Seigneur de guerre orc", "u": "Culte de la nécropole"}
const STAGE_NAMES: Array = ["Rumeurs", "Éclaireurs", "Levée en masse", "Marche sur le royaume"]
const STAGE_TEXT: Dictionary = {
	"o": [
		"Des éclaireurs orcs ont été vus loin au nord. Un nom court dans les tavernes : Gor-Khan, le seigneur de guerre.",
		"Gor-Khan unit les hordes sous un seul étendard. Des fermes brûlent, des villages se vident.",
		"La horde de Gor-Khan se met en marche : tambours de guerre, fumées sur toutes les collines. Le royaume tremble.",
	],
	"u": [
		"Des tombes se sont ouvertes dans trois paroisses. On murmure qu'un culte veille dans l'ombre.",
		"Le Culte de la nécropole relève ses morts par centaines. Les prêtres ferment leurs chapelles et s'enfuient.",
		"Le Roi blême appelle à lui tous les squelettes du pays. L'armée des morts quitte ses cryptes.",
	],
}

## Arcs de contrats : 3 étapes liées, même employeur. `kind` : kill ou hunt ; `pay` croissante ; `outro` : récit à la victoire.
const ARCS: Dictionary = {
	"bande_noire": {
		"title": "La Bande noire", "faction": "b", "min_renown": 0,
		"steps": [
			{"title": "Traquer la Bande noire", "kind": "kill", "d": 1, "pay": 380,
				"desc": "Une bande de brigands masqués dévalise les convois. Retrouvez-les et faites-en un exemple.",
				"outro": "Les masques tombent : ils obéissaient à un certain « Corbeau Noir », qui rançonne la région depuis un refuge secret."},
			{"title": "Le repaire de la Bande noire", "kind": "kill", "d": 2, "pay": 640,
				"desc": "Un prisonnier a parlé : le repaire de la Bande noire est dans les bois. Allez le détruire.",
				"outro": "Dans les décombres du repaire, des lettres de change et une carte : le Corbeau Noir tient encore son dernier fortin."},
			{"title": "Abattre le Corbeau Noir", "kind": "hunt", "d": 3, "pay": 1050,
				"desc": "Le chef de la Bande noire est acculé dans son dernier retranchement. Pas de quartier.",
				"outro": "Le Corbeau Noir est tombé. La Bande noire est brisée, et les routes sont enfin sûres."},
		],
		"epilogue": "La Bande noire n'est plus qu'un mauvais souvenir ; on vous doit les routes libres.",
	},
	"charnier": {
		"title": "Le Charnier de Saint-Hilaire", "faction": "g", "min_renown": 80,
		"steps": [
			{"title": "Les profanations", "kind": "kill", "d": 1, "pay": 420,
				"desc": "Des goules déterrent les morts de la paroisse. Chassez-les du cimetière.",
				"outro": "Les goules fuyaient quelque chose : un charnier ancien, rouvert par des fouilles imprudentes."},
			{"title": "Le charnier", "kind": "kill", "d": 2, "pay": 700,
				"desc": "Le charnier grouille de charognards. Nettoyez-le avant que le mal ne gagne les villages.",
				"outro": "Au fond du charnier, une tanière immense : une goule vorace y règne sur la meute."},
			{"title": "La Vorace", "kind": "hunt", "d": 3, "pay": 1150,
				"desc": "La goule vorace et sa meute doivent mourir pour que la paroisse retrouve la paix.",
				"outro": "La Vorace est abattue. Le prêtre bénit enfin la terre, et vous remet sa gratitude."},
		],
		"epilogue": "Le charnier de Saint-Hilaire est purifié. Les paroissiens vous tiennent pour leurs sauveurs.",
	},
	"tribut": {
		"title": "Le Tribut du Sang", "faction": "o", "min_renown": 350,
		"steps": [
			{"title": "Les éclaireurs de la horde", "kind": "kill", "d": 2, "pay": 700,
				"desc": "Des orcs lèvent un tribut de sang sur les hameaux. Brisez leurs éclaireurs.",
				"outro": "Les éclaireurs avouent, avant de mourir, que leur chef campe sur une palissade plus au large."},
			{"title": "La palissade", "kind": "kill", "d": 2, "pay": 1000,
				"desc": "Les orcs ont dressé une palissade pour rançonner la région. Brûlez-la.",
				"outro": "La palissade en cendres, le chef de guerre a juré de se venger en personne."},
			{"title": "Le chef de guerre", "kind": "hunt", "d": 3, "pay": 1500,
				"desc": "Le chef de guerre orc vous attend avec sa garde. L'un de vous deux ne rentrera pas.",
				"outro": "Le chef orc gît dans la boue. Sa horde se disperse : le tribut du sang ne sera plus levé."},
		],
		"epilogue": "Le Tribut du Sang est aboli. Les hameaux vous accueillent désormais en héros.",
	},
}


# --- État ---

static func new_state(faction: String = "o") -> Dictionary:
	return {
		"threat": 0.0, "faction": faction if faction in ["o", "u"] else "o", "stage": 0, "final": "locked", "free_mode": false,
		"ending_pending": false, "uniques_taken": [], "sites_taken": 0, "arcs": {}, "log": [],
	}


## État lu depuis du JSON (ou {} d'une ancienne sauvegarde) : valeurs par défaut et types numériques corrects.
static func normalize_state(raw: Variant) -> Dictionary:
	var st: Dictionary = new_state()
	if typeof(raw) != TYPE_DICTIONARY:
		return st
	var d: Dictionary = raw
	st["threat"] = clampf(float(d.get("threat", 0.0)), 0.0, THREAT_MAX)
	st["faction"] = str(d.get("faction", "o")) if str(d.get("faction", "o")) in ["o", "u"] else "o"
	st["stage"] = clampi(int(d.get("stage", 0)), 0, STAGES.size())
	st["final"] = str(d.get("final", "locked")) if str(d.get("final", "locked")) in ["locked", "open", "won"] else "locked"
	st["free_mode"] = bool(d.get("free_mode", false))
	st["ending_pending"] = bool(d.get("ending_pending", false))
	st["sites_taken"] = int(d.get("sites_taken", 0))
	st["uniques_taken"] = []
	for k in d.get("uniques_taken", []):
		st["uniques_taken"].append(str(k))
	st["log"] = []
	for l in d.get("log", []):
		st["log"].append(str(l))
	var arcs: Dictionary = {}
	var raw_arcs: Variant = d.get("arcs", {})
	if typeof(raw_arcs) == TYPE_DICTIONARY:
		for id in raw_arcs:
			if not ARCS.has(id):
				continue
			var a: Dictionary = raw_arcs[id]
			arcs[str(id)] = {
				"phase": str(a.get("phase", "posted")), "step": int(a.get("step", 0)), "origin_id": str(a.get("origin_id", "")),
				"origin": str(a.get("origin", "")), "contract": Contracts.normalize(a.get("contract", {})), "log": _strings(a.get("log", [])),
			}
	st["arcs"] = arcs
	return st


static func _strings(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for x in raw:
			out.append(str(x))
	return out


# --- Lieux hostiles ---

static func make_site(kind: String, id: String, pos: Vector2, srng: RandomNumberGenerator, faction: String = "") -> Dictionary:
	var t: Dictionary = SITE_TYPES[kind]
	var f: String = faction if faction != "" else str(t["faction"])
	var nm: String = str(CITADEL_NAMES.get(f, "Citadelle")) if kind == "citadel" else str((t["names"] as Array)[srng.randi() % (t["names"] as Array).size()])
	return {"id": id, "kind": kind, "name": nm, "faction": f, "x": pos.x, "y": pos.y, "state": "hostile", "respawn_day": 0, "conquered": 0}


static func clean_site(sd: Dictionary) -> Dictionary:
	var s: Dictionary = sd.duplicate()
	s["x"] = float(sd["x"])
	s["y"] = float(sd["y"])
	s["respawn_day"] = int(sd.get("respawn_day", 0))
	s["conquered"] = int(sd.get("conquered", 0))
	s["state"] = str(sd.get("state", "hostile"))
	return s


## Garnison d'un lieu ordinaire (10 hommes, danger 3).
static func garrison(kind: String) -> Array:
	match kind:
		"fort":
			return Contracts.foes_for("b", 3) + ["brigand", "archer"]
		"lair":
			return Contracts.foes_for("o", 3) + ["orc_guerrier", "berserker"]
		"necropolis":
			return Contracts.foes_for("u", 3) + ["squelette", "zombie"]
	return []


## Vagues de la citadelle (la dernière porte le chef).
static func citadel_waves(faction: String) -> Array:
	if faction == "u":
		return [
			["squelette", "squelette", "squelette", "squelette", "squelette_archer", "squelette_archer"],
			["squelette", "squelette", "squelette", "squelette_archer", "squelette_archer", "zombie", "zombie"],
			["necro", "zombie", "zombie", "squelette", "squelette", "squelette", "squelette_archer", "squelette_archer"],
		]
	return [
		["orc_jeune", "orc_jeune", "orc_jeune", "orc_jeune", "orc_guerrier", "orc_guerrier"],
		["orc_guerrier", "orc_guerrier", "orc_guerrier", "berserker", "berserker", "chaman_orc"],
		["orc_chef", "orc_guerrier", "orc_guerrier", "berserker", "berserker", "orc_jeune", "orc_jeune"],
	]


static func site_label(s: Dictionary) -> String:
	return str(SITE_TYPES[s["kind"]]["label"])


## Le contrat de bataille « assaut » d'un lieu hostile (vague 0).
static func assault_contract(s: Dictionary, world: World) -> Dictionary:
	var t: Dictionary = SITE_TYPES[s["kind"]]
	var waves: Array = citadel_waves(str(s["faction"])) if s["kind"] == "citadel" else []
	var foes: Array = (waves[0] as Array).duplicate() if not waves.is_empty() else garrison(str(s["kind"]))
	return {
		"kind": "assault", "battle_type": "siege", "site_id": str(s["id"]), "type": str(s["faction"]), "d": 3, "foes": foes, "waves": waves, "wave": 0,
		"final": s["kind"] == "citadel", "title": "Assaut : " + str(s["name"]), "desc": "", "employer": "", "origin": "",
		"pay": int(t["pay"]), "renown": int(t["renown"]), "days": 0, "biome": world.biome_at(world.settlement_pos(s)),
	}


## Contrat de la vague suivante d'un assaut en plusieurs vagues ({} s'il n'y en a plus).
static func next_wave(c: Dictionary) -> Dictionary:
	var waves: Array = c.get("waves", [])
	var w: int = int(c.get("wave", 0))
	if w + 1 >= waves.size():
		return {}
	var n: Dictionary = c.duplicate(true)
	n["wave"] = w + 1
	n["foes"] = (waves[w + 1] as Array).duplicate()
	var base: String = str(c["title"]).split(" (vague")[0]
	n["title"] = "%s (vague %d/%d)" % [base, w + 2, waves.size()]
	return n


## Un lieu est pris : change son état. Renvoie les lignes de nouvelles.
static func site_conquered(st: Dictionary, s: Dictionary, day: int) -> Array:
	var lines: Array = []
	var t: Dictionary = SITE_TYPES[s["kind"]]
	s["conquered"] = int(s.get("conquered", 0)) + 1
	st["sites_taken"] = int(st["sites_taken"]) + 1
	if s["kind"] == "citadel":
		s["state"] = "cleared"
		s["respawn_day"] = 1 << 30
		st["final"] = "won"
		st["ending_pending"] = true
		st["threat"] = 0.0
		lines.append("%s est tombée. La menace est écrasée !" % s["name"])
	elif t["after"] == "friendly":
		s["state"] = "friendly"
		lines.append("%s est à vous : un poste où la compagnie peut se reposer." % s["name"])
	else:
		s["state"] = "cleared"
		s["respawn_day"] = day + RESPAWN_DAYS
		lines.append("%s est libéré. Il sera peut-être réoccupé d'ici %d jours." % [s["name"], RESPAWN_DAYS])
	if str(s["faction"]) == str(st["faction"]) and st["final"] != "won":
		st["threat"] = maxf(0.0, float(st["threat"]) - SITE_THREAT_RELIEF)
	return lines


## Objets du butin d'un assaut remporté : 2 ou 3 pièces de haute qualité, parfois un objet unique.
static func assault_loot(kind: String, srng: RandomNumberGenerator, taken: Array) -> Array:
	var t: Dictionary = SITE_TYPES[kind]
	var out: Array = []
	for i in int(t["loot"]):
		var pool: Array = Loot.RARE[3]
		var pk: Array = pool[srng.randi() % pool.size()]
		out.append(Loot.item(str(pk[0]), str(pk[1])))
	if srng.randf() < float(t["unique"]):
		var avail: Array = Uniques.available(taken)
		if not avail.is_empty():
			out.append(Uniques.item_of(str(avail[srng.randi() % avail.size()])))
	return out


static func site_tooltip(s: Dictionary, renown: int) -> String:
	var t: Dictionary = SITE_TYPES[s["kind"]]
	var head: String = "%s — %s" % [s["name"], t["label"]]
	match str(s["state"]):
		"friendly":
			return head + "\nPoste libéré : la compagnie peut s'y reposer."
		"cleared":
			return head + "\nLibéré. Réoccupation prévue au jour %d." % int(s["respawn_day"]) if s["kind"] != "citadel" else head + "\nTombée."
	var n: int = (citadel_waves(str(s["faction"]))[0] as Array).size() if s["kind"] == "citadel" else garrison(str(s["kind"])).size()
	var txt: String = head + "\nHostile · %s · danger ◆◆◆\nGarnison : ≈ %d hommes%s" % [
		Data.FACTION_NAMES[s["faction"]], n, " en %d vagues" % citadel_waves(str(s["faction"])).size() if s["kind"] == "citadel" else ""]
	txt += "\nRécompense : %d couronnes, +%d renom, butin de qualité" % [int(t["pay"]), int(t["renown"])]
	if renown < 200 and s["kind"] != "citadel":
		txt += "\nDéconseillé en dessous de 200 de renom."
	return txt


# --- Menace et crise finale ---

static func threat_title(st: Dictionary) -> String:
	return str(THREAT_TITLES.get(st["faction"], "Menace"))


static func stage_name(st: Dictionary) -> String:
	return str(STAGE_NAMES[clampi(int(st["stage"]), 0, STAGE_NAMES.size() - 1)])


## Un jour de plus : menace, escalade, réoccupation des lieux libérés, ouverture du contrat final.
## Renvoie les lignes de nouvelles. `srng` : aléa de campagne (distinct de l'aléa de combat).
static func daily(st: Dictionary, world: World, srng: RandomNumberGenerator, day: int, renown: int, threat_mult: float = 1.0) -> Array:
	var lines: Array = []
	for s in world.sites:
		if s["state"] == "cleared" and s["kind"] != "citadel" and day >= int(s["respawn_day"]):
			s["state"] = "hostile"
			lines.append("%s est de nouveau occupé." % s["name"])
	if bool(st["free_mode"]) or st["final"] == "won":
		return lines
	var before: float = float(st["threat"])
	st["threat"] = minf(THREAT_MAX, before + (THREAT_PER_DAY + float(renown) * THREAT_PER_RENOWN) * threat_mult)
	for i in STAGES.size():
		if before < float(STAGES[i]) and float(st["threat"]) >= float(STAGES[i]) and int(st["stage"]) <= i:
			st["stage"] = i + 1
			lines.append_array(escalate(st, world, srng, i + 1))
	if st["final"] == "locked" and (float(st["threat"]) >= THREAT_MAX or (renown >= FINAL_RENOWN and float(st["threat"]) >= FINAL_MIN_THREAT)):
		lines.append_array(open_final(st, world, srng))
	return lines


## Effets d'un palier d'escalade (1 à 3).
static func escalate(st: Dictionary, world: World, srng: RandomNumberGenerator, stage: int) -> Array:
	var f: String = str(st["faction"])
	var lines: Array = [str((STAGE_TEXT[f] as Array)[stage - 1])]
	match stage:
		1:
			world.spawn_party(f, 2, srng)
		2:
			world.spawn_party(f, 3, srng)
			world.spawn_party(f, 2, srng)
			var villages: Array = []
			for s in world.settlements:
				if s["kind"] == "village":
					villages.append(s)
			if not villages.is_empty():
				var v: Dictionary = villages[srng.randi() % villages.size()]
				world.change_standing(str(v["id"]), -2)
				lines.append("%s a été pillé : sa confiance en la compagnie en souffre." % v["name"])
		3:
			world.spawn_party(f, 3, srng)
			world.spawn_party(f, 3, srng)
			for s in world.sites:
				if s["state"] == "cleared" and str(s["faction"]) == f and s["kind"] != "citadel":
					s["state"] = "hostile"
					lines.append("%s est réoccupé." % s["name"])
	return lines


static func open_final(st: Dictionary, world: World, srng: RandomNumberGenerator) -> Array:
	st["final"] = "open"
	var s: Dictionary = world.add_site("citadel", srng, str(st["faction"]))
	if s.is_empty():
		s = world.add_site("citadel", srng, str(st["faction"]), 70.0)
	if s.is_empty():
		st["final"] = "locked"  # pas de place sur la carte : on réessaiera demain
		return []
	return ["Le moment est venu : %s est signalée sur la carte. Son seigneur se prépare à frapper — en finir est votre seule chance." % s["name"]]


static func final_site(world: World) -> Dictionary:
	for s in world.sites:
		if s["kind"] == "citadel":
			return s
	return {}


# --- Marchand rare ---

static func _idx(id: String) -> int:
	return int(str(id).substr(1)) if str(id).length() > 1 else 0


## Stock du marchand rare d'un lieu : [{"item": {kind, key}, "price": int}] ([] = pas de marchand rare en ce moment).
static func rare_stock(s: Dictionary, day: int, taken: Array) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = day * 977 + _idx(str(s["id"])) * 131 + 17
	if r.randf() >= (0.7 if s["kind"] == "city" else 0.15):
		return []
	var pool: Array = Uniques.available(taken)
	var out: Array = []
	var n: int = mini(pool.size(), 2 + (1 if r.randf() < 0.4 else 0))
	for i in n:
		var k: String = str(pool.pop_at(r.randi() % pool.size()))
		out.append({"item": Uniques.item_of(k), "price": Uniques.rare_price(k)})
	return out


static func clean_rare(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for r in raw:
			if typeof(r) == TYPE_DICTIONARY and r.has("item") and r.has("price") and Loot.is_valid(r["item"]):
				out.append({"item": Loot.item(str(r["item"]["kind"]), str(r["item"]["key"])), "price": int(r["price"])})
	return out


# --- Arcs de contrats ---

static func _arc_target(world: World, origin: Vector2, srng: RandomNumberGenerator) -> Vector2:
	for i in 80:
		var p: Vector2 = origin + Vector2.from_angle(srng.randf() * TAU) * srng.randf_range(150.0, 480.0)
		if world.passable(p) and not world.find_path(origin, p).is_empty():
			return p
	return world.free_spot(srng, 100.0)


## Contrat de l'étape `step` (0-2) de l'arc `arc_id`, proposé par le lieu `origin` ({} si la carte n'a pas de place).
static func make_arc_contract(arc_id: String, step: int, origin: Dictionary, world: World, srng: RandomNumberGenerator) -> Dictionary:
	var a: Dictionary = ARCS[arc_id]
	var sd: Dictionary = (a["steps"] as Array)[step]
	var pos: Vector2 = world.settlement_pos(origin)
	var target: Vector2 = _arc_target(world, pos, srng)
	if target == Vector2.ZERO:
		return {}
	var f: String = str(a["faction"])
	var d: int = int(sd["d"])
	var hunt: bool = sd["kind"] == "hunt"
	return {
		"kind": "contract", "type": f, "type_contract": str(sd["kind"]), "d": d, "foes": Contracts.hunt_foes(f, d) if hunt else Contracts.foes_for(f, d),
		"title": "%s (%d/%d)" % [sd["title"], step + 1, ARC_STEPS], "desc": str(sd["desc"]),
		"employer": "%s de %s" % [str(Contracts.pick(Data.EMPLOYERS, srng)), origin["name"]], "origin": str(origin["name"]), "origin_id": str(origin["id"]),
		"pay": int(sd["pay"]), "days": maxi(1, int(ceil(pos.distance_to(target) / World.DAY_PX))), "tx": target.x, "ty": target.y, "ox": pos.x, "oy": pos.y,
		"target_name": str(Contracts.pick(Data.TARGET_NAMES[f], srng)), "biome": world.biome_at(target),
		"arc": arc_id, "arc_step": step,
	}


static func _post(world: World, a: Dictionary) -> void:
	var s: Dictionary = world.settlement_by_id(str(a["origin_id"]))
	if s.is_empty():
		return
	var c: Dictionary = a["contract"]
	for x in s["contracts"]:
		if x.get("arc", "") == c.get("arc", "!") and int(x.get("arc_step", -1)) == int(c.get("arc_step", -2)):
			return
	s["contracts"].insert(0, c.duplicate(true))


## À appeler quand un lieu renouvelle son stock : y remet les contrats d'arc en attente et peut y proposer un nouvel arc.
static func post_arcs(st: Dictionary, world: World, s: Dictionary, day: int, renown: int) -> void:
	for id in st["arcs"]:
		var a: Dictionary = st["arcs"][id]
		if a["phase"] == "posted" and a["origin_id"] == s["id"]:
			_post(world, a)
	if s["kind"] != "city":
		return
	for id in st["arcs"]:
		if st["arcs"][id]["phase"] == "posted" and int(st["arcs"][id]["step"]) == 0:
			return  # une offre d'arc attend déjà preneur
	var cand: Array = []
	for id in ARCS:
		if not st["arcs"].has(id) and renown >= int(ARCS[id]["min_renown"]):
			cand.append(id)
	if cand.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = day * 53 + _idx(str(s["id"])) * 7 + 3
	if r.randf() > 0.5:
		return
	var arc_id: String = str(cand[r.randi() % cand.size()])
	var c: Dictionary = make_arc_contract(arc_id, 0, s, world, r)
	if c.is_empty():
		return
	st["arcs"][arc_id] = {"phase": "posted", "step": 0, "origin_id": str(s["id"]), "origin": str(s["name"]), "contract": c, "log": []}
	_post(world, st["arcs"][arc_id])


## Le joueur accepte un contrat : s'il appartient à un arc, l'étape est « prise ».
static func on_accept(st: Dictionary, c: Dictionary) -> void:
	if c.has("arc") and st["arcs"].has(c["arc"]):
		st["arcs"][c["arc"]]["phase"] = "taken"


## Résultat d'un contrat d'arc. Victoire : étape suivante postée chez l'employeur (ou fin de l'arc). Échec / abandon :
## l'étape est reproposée. Renvoie {"lines": [...], "renown": int, "item": Dictionary ({} si aucun)}.
static func on_result(st: Dictionary, world: World, c: Dictionary, win: bool, srng: RandomNumberGenerator) -> Dictionary:
	var res: Dictionary = {"lines": [], "renown": 0, "item": {}}
	if not c.has("arc") or not st["arcs"].has(c["arc"]):
		return res
	var arc_id: String = str(c["arc"])
	var a: Dictionary = st["arcs"][arc_id]
	var def: Dictionary = ARCS[arc_id]
	var step: int = int(c["arc_step"])
	if not win:
		a["phase"] = "posted"
		_post(world, a)
		res["lines"].append("L'affaire « %s » n'est pas close : %s vous reproposera l'étape." % [def["title"], a["origin"]])
		return res
	var outro: String = str(((def["steps"] as Array)[step] as Dictionary)["outro"])
	a["log"].append(outro)
	res["lines"].append(outro)
	if step + 1 < ARC_STEPS:
		var origin: Dictionary = world.settlement_by_id(str(a["origin_id"]))
		var nxt: Dictionary = make_arc_contract(arc_id, step + 1, origin, world, srng) if not origin.is_empty() else {}
		if nxt.is_empty():
			a["phase"] = "done"
		else:
			a["step"] = step + 1
			a["phase"] = "posted"
			a["contract"] = nxt
			_post(world, a)
			res["lines"].append("%s vous attend à %s pour la suite : « %s »." % [str(nxt["employer"]).split(" de ")[0], a["origin"], nxt["title"]])
		return res
	a["phase"] = "done"
	res["renown"] = 100
	res["lines"].append(str(def["epilogue"]) + " (+100 renom)")
	st["log"].append("%s : %s" % [def["title"], " ".join(a["log"])])
	var avail: Array = Uniques.available(st["uniques_taken"])
	if not avail.is_empty():
		var k: String = str(avail[srng.randi() % avail.size()])
		res["item"] = Uniques.item_of(k)
		res["lines"].append("En remerciement, on vous remet : %s." % Loot.item_name(res["item"]))
	if str(def["faction"]) == str(st["faction"]) and st["final"] != "won":
		st["threat"] = maxf(0.0, float(st["threat"]) - ARC_THREAT_RELIEF)
	return res


## Arcs connus pour l'affichage : [{"id", "title", "phase", "step", "total", "text"}] (terminés compris).
static func arc_summary(st: Dictionary) -> Array:
	var out: Array = []
	for id in st["arcs"]:
		var a: Dictionary = st["arcs"][id]
		var def: Dictionary = ARCS[id]
		var text: String
		if a["phase"] == "done":
			text = str(def["epilogue"])
		else:
			var c: Dictionary = a["contract"]
			text = "%s — %s" % [str(c.get("title", "")), "à rendre : " + str(c.get("target_name", "")) if a["phase"] == "taken" else "à reprendre chez " + str(a["origin"])]
		out.append({"id": str(id), "title": str(def["title"]), "phase": str(a["phase"]), "step": int(a["step"]) + (1 if a["phase"] == "done" else 0), "total": ARC_STEPS, "text": text})
	return out
