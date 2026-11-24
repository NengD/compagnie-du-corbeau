class_name Ruins
extends RefCounted
## Explorations de ruines : sur un point d'intérêt « ruines » de la carte, la compagnie s'enfonce par niveaux (2 ou 3 combats enchaînés,
## SANS soin entre eux : les blessures restent). Entre deux niveaux, un choix : avancer, fouiller (une fois par niveau) ou se replier.
## Au bout, un coffre (butin riche, objet rare, indice d'histoire). Se replier ou perdre ramène sur la carte avec les pertes subies.
## Logique pure (aléa injecté) ; Game.ruins_* applique les effets. État dans `Game.extras["ruins"]` :
##   {"done": [ids de points explorés], "explored": n, "clues": n, "run": {...} (exploration en cours)}.
## `run` : {poi, name, theme, d, stage (niveaux franchis), stages, phase ("battle" | "choice" | "chest"), searched, extra (combat de fouille en cours), log}.

const KEY: String = "ruins"
const DEEP_PERCENT: int = 60  ## part des points « ruines » qui s'explorent en profondeur (tirage stable par identifiant)


# --- État ---

static func state(extras: Dictionary) -> Dictionary:
	var st: Variant = extras.get(KEY)
	if typeof(st) != TYPE_DICTIONARY:
		st = {}
	var d: Dictionary = st
	if typeof(d.get("done")) != TYPE_ARRAY:
		d["done"] = []
	d["explored"] = int(d.get("explored", 0))
	d["clues"] = int(d.get("clues", 0))
	extras[KEY] = d
	return d


static func run_of(extras: Dictionary) -> Dictionary:
	var st: Variant = extras.get(KEY)  ## lecture seule : ne crée rien dans `extras`
	if typeof(st) == TYPE_DICTIONARY and typeof((st as Dictionary).get("run")) == TYPE_DICTIONARY:
		return (st as Dictionary)["run"]
	return {}


static func active(extras: Dictionary) -> bool:
	return not run_of(extras).is_empty()


## L'exploration attend-elle une décision du joueur (hors combat) ?
static func pending(extras: Dictionary) -> bool:
	var r: Dictionary = run_of(extras)
	return not r.is_empty() and str(r.get("phase", "")) in ["choice", "chest"]


## Ce point d'intérêt est-il une ruine qu'on peut explorer en profondeur ?
static func is_deep(q: Dictionary) -> bool:
	return str(q.get("kind", "")) == "ruins" and absi(hash("ruin|" + str(q.get("id", "")))) % 100 < DEEP_PERCENT


static func explorable(extras: Dictionary, q: Dictionary) -> bool:
	var st: Variant = extras.get(KEY)
	var done: Array = (st as Dictionary).get("done", []) if typeof(st) == TYPE_DICTIONARY and typeof((st as Dictionary).get("done", [])) == TYPE_ARRAY else []
	return is_deep(q) and not done.has(str(q.get("id", ""))) and not active(extras)


## Thème d'une ruine (stable par identifiant), parmi ceux que le renom permet.
static func theme_for(q: Dictionary, renown: int) -> String:
	var ok: Array = []
	for k in RuinsData.ORDER:
		if renown >= int(RuinsData.THEMES[k]["min_renown"]):
			ok.append(k)
	return str(ok[absi(hash("rtheme|" + str(q.get("id", "")))) % ok.size()])


static func danger_for(renown: int, region_danger: int = 0) -> int:
	return clampi(1 + renown / 200 + region_danger, 1, 3)


## Nouvelle exploration (phase « battle » : le premier combat suit aussitôt).
static func start(extras: Dictionary, q: Dictionary, renown: int, region_danger: int = 0) -> Dictionary:
	var theme: String = theme_for(q, renown)
	var run: Dictionary = {
		"poi": str(q["id"]), "name": str(q.get("name", "Ruines")), "theme": theme, "d": danger_for(renown, region_danger),
		"stage": 0, "stages": int(RuinsData.THEMES[theme]["stages"]), "phase": "battle", "searched": false, "extra": false, "log": [],
	}
	state(extras)["run"] = run
	return run


# --- Combats ---

## Occupants du niveau `stage` (0 = entrée) : plus nombreux en profondeur ; le dernier niveau est tenu par un chef et sa garde.
static func foes_for_stage(theme: String, d: int, stage: int, stages: int) -> Array:
	var fac: String = str(RuinsData.THEMES[theme]["fac"])
	if stage >= stages - 1:
		return Contracts.hunt_foes(fac, d)
	var base: Array = Contracts.foes_for(fac, clampi(d + stage - (1 if stage == 0 else 0), 1, 3))
	return base.slice(0, maxi(3, base.size() - (1 if stage == 0 else 0)))


## Contrat de bataille du niveau en cours (`extra` : embuscade déclenchée par une fouille, même niveau, effectif réduit).
static func battle_contract(run: Dictionary, world: World, extra: bool = false) -> Dictionary:
	var theme: String = str(run["theme"])
	var t: Dictionary = RuinsData.THEMES[theme]
	var stage: int = int(run["stage"])
	var d: int = int(run["d"])
	var foes: Array = foes_for_stage(theme, d, stage, int(run["stages"]))
	if extra:
		foes = foes.slice(0, maxi(2, foes.size() / 2))
	var dark: bool = stage >= int(t["night_from"])
	var title: String = "%s — %s (niveau %d/%d)" % [str(run["name"]), str((t["levels"] as Array)[mini(stage, (t["levels"] as Array).size() - 1)]), stage + 1, int(run["stages"])]
	if extra:
		title = "%s — embuscade dans les décombres" % str(run["name"])
	return {
		"kind": "ruins", "battle_type": "night" if dark else "pitched", "ruins": str(run["poi"]), "stage": stage, "extra": extra,
		"party_id": -1, "type": str(t["fac"]), "d": d, "foes": foes, "title": title, "desc": "", "employer": "", "origin": "",
		"pay": 0, "days": 0, "biome": str(t["biome"]),
		"traps": str(t["fac"]) == "b" and stage > 0,
	}


## Résultat d'un combat de ruines : met l'exploration à jour. Renvoie une ligne de récit.
static func on_battle_end(extras: Dictionary, win: bool, c: Dictionary) -> String:
	var run: Dictionary = run_of(extras)
	if run.is_empty():
		return ""
	if not win:
		abandon(extras)
		return "L'exploration s'achève dans la déroute : les ruines gardent leurs secrets."
	if bool(c.get("extra", false)):
		run["extra"] = false
		run["phase"] = "choice"
		return "Les occupants sont mis en fuite : on peut reprendre l'exploration."
	run["stage"] = int(run["stage"]) + 1
	run["searched"] = false
	if int(run["stage"]) >= int(run["stages"]):
		run["phase"] = "chest"
		return "Le dernier gardien est tombé. Le coffre est à portée."
	run["phase"] = "choice"
	return "Niveau franchi (%d/%d). Les hommes reprennent leur souffle, sans pouvoir se soigner." % [int(run["stage"]), int(run["stages"])]


## Termine l'exploration en cours (repli, déroute ou coffre ouvert) : le point est noté comme exploré.
static func abandon(extras: Dictionary) -> void:
	var st: Dictionary = state(extras)
	var run: Dictionary = run_of(extras)
	if not run.is_empty() and not (st["done"] as Array).has(str(run["poi"])):
		(st["done"] as Array).append(str(run["poi"]))
	st.erase("run")


# --- Choix ---

## Choix possibles dans la phase en cours : [{id, label, hint}].
static func choices(run: Dictionary) -> Array:
	var out: Array = []
	if str(run.get("phase", "")) == "chest":
		out.append({"id": "open", "label": "Ouvrir le coffre", "hint": "Le butin de la ruine : de l'or, des pièces de qualité, peut-être un objet rare."})
		return out
	if int(run["stage"]) < int(run["stages"]):
		out.append({"id": "advance", "label": "Avancer vers le niveau suivant", "hint": "Un nouveau combat, sans soin entre les deux. Un piège peut surprendre la colonne."})
	if not bool(run.get("searched", false)):
		out.append({"id": "search", "label": "Fouiller ce niveau", "hint": "Une fois par niveau : or, équipement… mais aussi pièges et embuscades."})
	out.append({"id": "retreat", "label": "Se replier", "hint": "Retour à la carte avec ce qu'on a déjà trouvé et les blessures subies."})
	return out


## Texte d'ambiance du niveau en cours.
static func level_text(run: Dictionary) -> String:
	var t: Dictionary = RuinsData.THEMES[str(run["theme"])]
	if str(run.get("phase", "")) == "chest":
		return str(t["chest"])
	var descend: Array = t["descend"]
	if int(run["stage"]) == 0:
		return str(t["intro"])
	return str(descend[mini(int(run["stage"]) - 1, descend.size() - 1)])


## Effet d'une marche en avant : {text, hp_one} (piège) ou {text:""}.
static func advance_event(rng: RandomNumberGenerator, d: int) -> Dictionary:
	if rng.randf() < RuinsData.ADVANCE_TRAP_CHANCE:
		return {"text": str(RuinsData.TRAP_TEXTS[rng.randi() % RuinsData.TRAP_TEXTS.size()]), "hp_one": -(6 + 4 * d)}
	return {"text": ""}


## Fouille d'un niveau : {kind, text, gold?, item?, hp_one?, battle?}. `rng` injecté.
static func search(rng: RandomNumberGenerator, d: int) -> Dictionary:
	var total: int = 0
	for e in RuinsData.SEARCH:
		total += int(e["w"])
	var roll: int = rng.randi_range(1, total)
	for e in RuinsData.SEARCH:
		roll -= int(e["w"])
		if roll <= 0:
			var out: Dictionary = {"kind": str(e["kind"]), "text": str(e["text"])}
			match out["kind"]:
				"gold":
					out["gold"] = 40 * d + rng.randi_range(0, 8) * 5
				"item":
					var pool: Array = Loot.RARE[clampi(d, 1, 3)]
					var pk: Array = pool[rng.randi() % pool.size()]
					out["item"] = ItemGrade.roll_item(Loot.item(str(pk[0]), str(pk[1])), rng, ItemGrade.BIAS_CONTRACT * float(d), ItemGrade.OK)
				"trap":
					out["hp_one"] = -(8 + 4 * d)
				"ambush":
					out["battle"] = true
			return out
	return {"kind": "nothing", "text": "Rien."}


## Contenu du coffre final : {gold, items, unique (bool), clue}. `taken` : objets uniques déjà sortis.
static func chest(rng: RandomNumberGenerator, d: int, taken: Array) -> Dictionary:
	var items: Array = []
	for i in 1 + d:
		var pool: Array = Loot.RARE[3] if i == 0 or d >= 3 else Loot.RARE[clampi(d + 1, 1, 3)]
		var pk: Array = pool[rng.randi() % pool.size()]
		items.append(ItemGrade.roll_item(Loot.item(str(pk[0]), str(pk[1])), rng, ItemGrade.BIAS_CONTRACT * 3.0, ItemGrade.OK))
	var unique: bool = false
	if rng.randf() < 0.5:
		var avail: Array = Uniques.available(taken)
		if not avail.is_empty():
			items.append(Uniques.item_of(str(avail[rng.randi() % avail.size()])))
			unique = true
	return {"gold": 180 * d + rng.randi_range(0, 20) * 5, "items": items, "unique": unique, "clue": str(RuinsData.CLUES[rng.randi() % RuinsData.CLUES.size()])}
