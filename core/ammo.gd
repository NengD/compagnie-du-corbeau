class_name Ammo
extends RefCounted
## Munitions des arcs et arbalètes (carquois). Les javelots gardent leur mécanisme propre (`Data.WPN[..]["ammo"]`, rechargés à chaque bataille).
##
## Un homme porte un CARQUOIS : `Unit.quiver` (pièces restantes, -1 = plein) et `Unit.ammo_kind` (type de munition). Le carquois se vide en
## bataille (`Unit.ammo` est le compteur de la bataille, repris du carquois au début ; `Game` le recopie à la fin) et se remplit au camp
## contre quelques couronnes (inclus dans « Réparer ») ou avec les lots achetés au marché (réserve `Game.extras["ammo"]["reserve"]`).
## Les ennemis ont toujours ENEMY_AMMO pièces : l'IA ne manque jamais de munitions. Sans munitions, tirer est impossible.
## Une arme peut porter `ammo_type` ("fleche" | "carreau") et `quiver` (capacité) dans Data.WPN ; sinon c'est sa famille qui décide.
## Logique pure (aucune scène).

const LOT: int = 12  ## pièces par lot du marché
const ENEMY_AMMO: int = 60
const DEFAULT_KIND: String = "chasse"

## Types de munitions : `piece` = prix de recharge au camp par pièce ; `lot_price` = prix d'un lot de LOT au marché (avant coefficient de lieu).
## `arm` multiplie l'efficacité contre l'armure, `ign_add` s'ajoute à la traversée, `dmg` multiplie les dégâts.
const KINDS: Dictionary = {
	"chasse": {"n": "de chasse", "piece": 1, "lot_price": 12, "arm": 1.0, "ign_add": 0.0, "dmg": 1.0, "note": "Munitions ordinaires."},
	"perforante": {"n": "perforantes", "piece": 3, "lot_price": 36, "arm": 1.2, "ign_add": 0.08, "dmg": 0.95,
		"note": "Pointe étroite et trempée : abîme davantage l'armure et passe un peu mieux, au prix de dégâts légèrement moindres."},
}

## Lanceurs : `cap` = capacité du carquois.
const LAUNCHERS: Dictionary = {
	"fleche": {"one": "flèche", "many": "flèches", "cap": 24},
	"carreau": {"one": "carreau", "many": "carreaux", "cap": 16},
}
const FAMILY_LAUNCHER: Dictionary = {"arc": "fleche", "arbalete": "carreau"}


static func normalize_kind(kind: Variant) -> String:
	var k: String = str(kind)
	return k if KINDS.has(k) else DEFAULT_KIND


## "fleche" | "carreau" | "" (arme sans carquois).
static func launcher_of(weapon_key: String) -> String:
	var w: Dictionary = Data.WPN.get(weapon_key, {})
	if w.has("ammo_type"):
		return str(w["ammo_type"]) if LAUNCHERS.has(str(w["ammo_type"])) else ""
	return str(FAMILY_LAUNCHER.get(Perks.weapon_family(weapon_key), ""))


static func capacity(weapon_key: String) -> int:
	var l: String = launcher_of(weapon_key)
	if l == "":
		return 0
	var w: Dictionary = Data.WPN[weapon_key]
	return int(w["quiver"]) if w.has("quiver") else int(LAUNCHERS[l]["cap"])


static func item_key(launcher: String, kind: String) -> String:
	return "%s_%s" % [launcher, normalize_kind(kind)]


## Toutes les clés d'objets de marché (lot de munitions).
static func item_keys() -> Array[String]:
	var out: Array[String] = []
	for l in LAUNCHERS:
		for k in KINDS:
			out.append(item_key(str(l), str(k)))
	return out


static func has_item(key: String) -> bool:
	return item_keys().has(key)


## Fiche d'un lot du marché (même forme que les entrées de Data : "n", "price", "note").
static func item_data(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split("_", true, 1)
	if parts.size() < 2 or not LAUNCHERS.has(parts[0]) or not KINDS.has(parts[1]):
		return {"n": "?", "price": 0, "note": ""}
	var k: Dictionary = KINDS[parts[1]]
	return {"n": "Lot de %d %s %s" % [LOT, LAUNCHERS[parts[0]]["many"], k["n"]], "price": int(k["lot_price"]), "launcher": parts[0], "kind": parts[1],
		"note": "Remplit les carquois au camp (« Réparer ») avant de payer à la pièce. %s" % k["note"]}


static func kind_of_item(key: String) -> String:
	return key.split("_", true, 1)[1] if key.contains("_") else DEFAULT_KIND


static func launcher_of_item(key: String) -> String:
	return key.split("_", true, 1)[0]


# --- Homme ---

## Multiplicateurs de la munition de `a` ({} si son arme n'a pas de carquois).
static func mods_of(a: Unit) -> Dictionary:
	if not a.has_quiver():
		return {}
	return KINDS[normalize_kind(a.ammo_kind)]


static func piece_price(kind: String) -> int:
	return int(KINDS[normalize_kind(kind)]["piece"])


## Texte « 12/24 flèches perforantes » (carquois en cours : `ammo` en bataille, sinon `quiver`).
static func describe(u: Unit, in_battle: bool = false) -> String:
	if not u.has_quiver():
		return ""
	var l: Dictionary = LAUNCHERS[launcher_of(u.weapon)]
	var n: int = u.ammo if in_battle and u.ammo >= 0 else u.quiver_now()
	return "%d/%d %s %s" % [n, u.quiver_cap(), l["many"], KINDS[normalize_kind(u.ammo_kind)]["n"]]


## Message affiché quand un tireur n'a plus rien à tirer.
static func empty_message(u: Unit) -> String:
	var l: Dictionary = LAUNCHERS.get(launcher_of(u.weapon), {"many": "munitions"})
	return "Plus de %s : tirer est impossible." % l["many"]


# --- Camp : recharge des carquois ---

## Réserve (lots achetés, en pièces) lue dans Game.extras, sans la créer.
static func reserve_of(extras: Dictionary) -> Dictionary:
	var a: Variant = extras.get("ammo", {})
	var r: Variant = (a as Dictionary).get("reserve", {}) if typeof(a) == TYPE_DICTIONARY else {}
	var out: Dictionary = {}
	if typeof(r) == TYPE_DICTIONARY:
		for k in r:
			if has_item(str(k)) and int(r[k]) > 0:
				out[str(k)] = int(r[k])
	return out


static func store_reserve(extras: Dictionary, reserve: Dictionary) -> void:
	var clean: Dictionary = {}
	for k in reserve:
		if int(reserve[k]) > 0:
			clean[str(k)] = int(reserve[k])
	if clean.is_empty():
		extras.erase("ammo")
	else:
		extras["ammo"] = {"reserve": clean}


static func reserve_total(extras: Dictionary) -> int:
	var n: int = 0
	var r: Dictionary = reserve_of(extras)
	for k in r:
		n += int(r[k])
	return n


## Recharge des carquois de `roster` : {"cost": couronnes, "pieces": pièces ajoutées, "from_reserve": pièces prises dans la réserve}.
## Avec `apply`, remplit vraiment les carquois et débite `reserve` (le coût reste à payer par l'appelant).
static func refill(roster: Array, reserve: Dictionary, apply: bool = false) -> Dictionary:
	var left: Dictionary = reserve.duplicate()
	var cost: int = 0
	var pieces: int = 0
	var from_reserve: int = 0
	for m in roster:
		var u: Unit = m
		if not u.has_quiver():
			continue
		var need: int = u.quiver_cap() - u.quiver_now()
		if need <= 0:
			continue
		var key: String = item_key(launcher_of(u.weapon), u.ammo_kind)
		var take: int = mini(int(left.get(key, 0)), need)
		left[key] = int(left.get(key, 0)) - take
		cost += (need - take) * piece_price(u.ammo_kind)
		pieces += need
		from_reserve += take
		if apply:
			u.quiver = -1
	if apply:
		reserve.clear()
		for k in left:
			if int(left[k]) > 0:
				reserve[k] = int(left[k])
	return {"cost": cost, "pieces": pieces, "from_reserve": from_reserve}


## Change le type de munition de `u` : les pièces restantes retournent à la réserve (sous leur ancien type), puis le carquois se remplit
## autant que la réserve du nouveau type le permet (le reste se complète au camp contre couronnes). Renvoie false si rien ne change.
static func set_kind(u: Unit, kind: String, reserve: Dictionary) -> bool:
	var k: String = normalize_kind(kind)
	if not u.has_quiver() or k == normalize_kind(u.ammo_kind):
		return false
	var old_key: String = item_key(launcher_of(u.weapon), u.ammo_kind)
	reserve[old_key] = int(reserve.get(old_key, 0)) + u.quiver_now()
	u.ammo_kind = k
	var new_key: String = item_key(launcher_of(u.weapon), k)
	var take: int = mini(int(reserve.get(new_key, 0)), u.quiver_cap())
	reserve[new_key] = int(reserve.get(new_key, 0)) - take
	u.quiver = take
	if take >= u.quiver_cap():
		u.quiver = -1
	return true
