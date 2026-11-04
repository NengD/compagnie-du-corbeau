class_name Loot
extends RefCounted
## Butin et objets de l'inventaire. Un objet = {"kind": "weapon" | "head" | "body" | "shield", "key": clé de Data}.
## Logique pure : l'aléa est injecté.

const KINDS: Array[String] = ["weapon", "shield", "head", "body", "tool"]
const SELL_RATE: float = 0.4  ## part du prix de base reçue à la vente
const BASE_CHANCE: float = 0.15  ## chance de récupérer une armure entièrement détruite
const WEAPON_CHANCE: float = 0.45
const SHIELD_CHANCE: float = 0.4
const ARMOR_CHANCE: float = 0.6  ## ajoutée à BASE_CHANCE × (armure restante / armure max)

## Objets rares offerts par un contrat gagné, par danger (1 à 3).
const RARE: Dictionary = {
	1: [["weapon", "lance"], ["head", "casque"], ["body", "gambison"]],
	2: [["weapon", "hache"], ["weapon", "masse"], ["head", "casque"], ["body", "mailles"]],
	3: [["weapon", "epee"], ["head", "heaume"], ["body", "mailles"], ["body", "brigandine"]],
}


static func item(kind: String, key: String = "") -> Dictionary:
	return {"kind": kind, "key": key}


static func data_of(it: Dictionary) -> Dictionary:
	match str(it["kind"]):
		"weapon":
			return Data.WPN[it["key"]]
		"head":
			return Data.HEAD[it["key"]]
		"body":
			return Data.BODY[it["key"]]
		"shield":
			return Data.SHIELD
		"tool":
			return Data.TOOLS[it["key"]]
	return {}


static func item_name(it: Dictionary) -> String:
	return str(data_of(it).get("n", "?"))


static func base_price(it: Dictionary) -> int:
	return int(data_of(it).get("price", 0))


static func sell_base(it: Dictionary) -> int:
	return int(round(base_price(it) * SELL_RATE * (0.5 + 0.5 * wear_ratio(it))))


# --- Usure : un objet peut porter "dur" (durabilité restante) ; absent = neuf ---

static func dur_max(it: Dictionary) -> int:
	match str(it["kind"]):
		"weapon":
			return int(Data.WPN[it["key"]].get("dur", Data.WEAPON_DUR))
		"shield":
			return int(Data.SHIELD["dur"])
	return 0


static func dur_of(it: Dictionary) -> int:
	var m: int = dur_max(it)
	return m if not it.has("dur") else clampi(int(it["dur"]), 0, m)


## Armure maximale d'un casque ou d'une armure (0 pour les autres objets).
static func armor_max(it: Dictionary) -> int:
	var k: String = str(it["kind"])
	return int(data_of(it).get("a", 0)) if k == "head" or k == "body" else 0


## Armure actuelle d'un casque ou d'une armure : la clé facultative "arm" (absente = intacte).
static func armor_of(it: Dictionary) -> int:
	var m: int = armor_max(it)
	return m if not it.has("arm") else clampi(int(it["arm"]), 0, m)


## Marque la pièce d'armure `it` avec son armure actuelle (n'ajoute "arm" que si elle est abîmée).
static func with_armor(it: Dictionary, cur: int) -> Dictionary:
	if cur < armor_max(it):
		it["arm"] = maxi(0, cur)
	return it


## Copie propre d'un objet lu dans une sauvegarde (clés connues seulement).
static func clean(it: Dictionary) -> Dictionary:
	var out: Dictionary = item(str(it["kind"]), str(it["key"]))
	if it.has("dur"):
		out["dur"] = int(it["dur"])
	if it.has("arm"):
		out["arm"] = int(it["arm"])
	return out


## 1 = neuf (ou sans usure), 0 = cassé.
static func wear_ratio(it: Dictionary) -> float:
	var m: int = dur_max(it)
	if m <= 0:
		var am: int = armor_max(it)
		return 1.0 if am <= 0 else float(armor_of(it)) / float(am)
	return float(dur_of(it)) / float(m)


## Points de durabilité manquants (armes et boucliers).
static func dur_missing(it: Dictionary) -> int:
	return dur_max(it) - dur_of(it) if dur_max(it) > 0 else 0


## Prix de la remise en état complète d'un objet.
static func repair_price(it: Dictionary) -> int:
	return int(ceil(float(base_price(it)) * Data.REPAIR_GEAR_RATE * (1.0 - wear_ratio(it))))


## Description courte pour les listes.
static func describe(it: Dictionary) -> String:
	var d: Dictionary = data_of(it)
	match str(it["kind"]):
		"weapon":
			return "%d–%d dégâts · %d PA%s" % [d["min"], d["max"], d["ap"], _wear_text(it)]
		"head", "body":
			return "Armure %d · poids %d%s" % [d["a"], d["w"], " · abîmée %d/%d" % [armor_of(it), armor_max(it)] if wear_ratio(it) < 1.0 else ""]
		"shield":
			return "+15 déf. mêlée, +25 déf. distance · poids %d%s" % [d["w"], _wear_text(it)]
		"tool":
			return str(d.get("note", ""))
	return ""


static func _wear_text(it: Dictionary) -> String:
	return " · usure %d/%d" % [dur_of(it), dur_max(it)] if wear_ratio(it) < 1.0 else ""


static func is_valid(it: Variant) -> bool:
	if typeof(it) != TYPE_DICTIONARY or not it.has("kind") or not it.has("key"):
		return false
	match str(it["kind"]):
		"weapon":
			return Data.WPN.has(it["key"])
		"head":
			return Data.HEAD.has(it["key"])
		"body":
			return Data.BODY.has(it["key"])
		"shield":
			return true
		"tool":
			return Data.TOOLS.has(it["key"])
	return false


## Équipement d'une unité sous forme d'objets. Les griffes, la tête nue et l'absence d'armure n'en sont pas.
## `damaged` : la chance de récupération de chaque pièce (armure restante / armure max, 1 pour arme et bouclier).
static func pieces_of(u: Unit) -> Array:
	var out: Array = []
	if Data.WPN[u.weapon]["price"] > 0:
		out.append({"item": worn(item("weapon", u.weapon), u.weapon_dur_now()), "ratio": 1.0})
	if u.shield:
		out.append({"item": worn(item("shield"), u.shield_dur_now()), "ratio": 1.0})
	if u.head != "none":
		out.append({"item": with_armor(item("head", u.head), u.arm_h), "ratio": clampf(float(u.arm_h) / maxf(1.0, float(Data.HEAD[u.head]["a"])), 0.0, 1.0)})
	if u.body != "none":
		out.append({"item": with_armor(item("body", u.body), u.arm_b), "ratio": clampf(float(u.arm_b) / maxf(1.0, float(Data.BODY[u.body]["a"])), 0.0, 1.0)})
	return out


## Objet portant une usure (n'ajoute "dur" que s'il n'est pas neuf).
static func worn(it: Dictionary, dur: int) -> Dictionary:
	if dur < dur_max(it):
		it["dur"] = dur
	return it


static func recover_chance(piece: Dictionary) -> float:
	match str(piece["item"]["kind"]):
		"weapon":
			return WEAPON_CHANCE
		"shield":
			return SHIELD_CHANCE
	return BASE_CHANCE + ARMOR_CHANCE * float(piece["ratio"])


## Butin d'une bataille gagnée : l'équipement des ennemis tués (ils sont `dead`, côté "e").
static func roll_battle(units: Array, rng: RandomNumberGenerator, loot_mult: float = 1.0) -> Array:
	var out: Array = []
	for u in units:
		if u.side != "e" or not u.dead:
			continue
		for piece in pieces_of(u):
			if rng.randf() < recover_chance(piece) * loot_mult:
				var it: Dictionary = piece["item"]
				it.erase("arm")  # armure récupérée remise en état (la chance dépend déjà des dégâts)
				if dur_max(it) > 0:  # seconde main : usé en combat, puis par l'ennemi lui-même
					worn(it, int(round(dur_of(it) * Data.WORN_LOOT_RATE)))
				out.append(it)
		for b in u.bag:  # outils du sac (huile des défenseurs d'un fort…)
			if not (b as Dictionary).is_empty() and str(b["kind"]) == "tool" and rng.randf() < 0.6:
				out.append(clean(b))
		for dr in u.foe_data().get("drop", []):  # dépouilles des monstres
			if rng.randf() < float(dr[2]) * loot_mult:
				out.append(item(str(dr[0]), str(dr[1])))
	return out


## Objet rare éventuel d'un contrat gagné (danger 1 à 3). Renvoie {} si rien.
static func roll_contract_bonus(danger: int, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= 0.12 + 0.1 * danger:
		return {}
	var pool: Array = RARE[clampi(danger, 1, 3)]
	var pick: Array = pool[rng.randi() % pool.size()]
	return item(str(pick[0]), str(pick[1]))


## Peut-on équiper cet objet sur cette unité ? (arme à deux mains : pas de bouclier ; bouclier : arme à une main.)
static func can_equip(u: Unit, it: Dictionary) -> bool:
	if str(it["kind"]) == "shield":
		return bool(u.weapon_data()["h1"]) and not u.shield
	return true


## Équipe l'objet et renvoie les objets retirés (à remettre dans l'inventaire). Vérifier can_equip avant.
static func equip(u: Unit, it: Dictionary) -> Array:
	var removed: Array = []
	match str(it["kind"]):
		"weapon":
			if Data.WPN[u.weapon]["price"] > 0:
				removed.append(worn(item("weapon", u.weapon), u.weapon_dur_now()))
			u.weapon = str(it["key"])
			u.weapon_dur = dur_of(it) if it.has("dur") else -1
			u.ammo = int(Data.WPN[u.weapon].get("ammo", -1))
			if not bool(Data.WPN[u.weapon]["h1"]) and u.shield:
				u.shield = false
				removed.append(worn(item("shield"), u.shield_dur_now()))
		"shield":
			u.shield = true
			u.shield_dur = dur_of(it) if it.has("dur") else -1
		"head":
			if u.head != "none":
				removed.append(item("head", u.head))
			u.head = str(it["key"])
			u.arm_h = int(Data.HEAD[u.head]["a"])
		"body":
			if u.body != "none":
				removed.append(item("body", u.body))
			u.body = str(it["key"])
			u.arm_b = int(Data.BODY[u.body]["a"])
	return removed


## Tout l'équipement d'une unité sous forme d'objets (renvoi d'un homme).
static func gear_items(u: Unit) -> Array:
	var out: Array = []
	for p in pieces_of(u):
		out.append(p["item"])
	for b in u.bag:
		if not (b as Dictionary).is_empty():
			out.append(b)
	return out
