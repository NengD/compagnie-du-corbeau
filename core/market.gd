class_name Market
extends RefCounted
## Stock fini d'une boutique (logique pure, sans scène). Chaque lieu garde `settlement["stock"]` : une liste d'entrées
## {"kind", "key", ["dur" | "arm" si abîmé], ["qty" si empilable]}. Un objet ordinaire est une entrée de l'inventaire (voir Loot) ;
## les outils s'empilent (« qty ») ; les vivres sont l'entrée {"kind": "food", "key": "rations", "qty": n}.
## Les prix ne sont PAS calculés ici (ce sont ceux de Game.price_of) : on fournit seulement la base et la fonction de prix.

const FOOD: String = "food"
const FOOD_KEY: String = "ration"
const FILTERS: Array[String] = ["all", "weapon", "body", "head", "shield", "tool", "food"]
const FILTER_NAMES: Dictionary = {"all": "Tout", "weapon": "Armes", "body": "Armures", "head": "Casques", "shield": "Boucliers", "tool": "Outils", "food": "Vivres"}
const MAX_ENTRIES: int = 72  ## au-delà, les plus anciennes entrées (hors vivres) sont écartées
const WEAR_MIN: float = 0.5  ## durabilité minimale d'un objet d'occasion
const NEW_CHANCE: float = 0.55  ## part des objets neufs
const PRESENCE: float = 0.85  ## chance qu'un modèle du catalogue soit en rayon
const ORDER: Dictionary = {"food": 0, "weapon": 1, "shield": 2, "head": 3, "body": 4, "tool": 5}


static func food(qty: int) -> Dictionary:
	return {"kind": FOOD, "key": FOOD_KEY, "qty": qty}


static func is_food(e: Dictionary) -> bool:
	return str(e.get("kind", "")) == FOOD


static func is_stackable(e: Dictionary) -> bool:
	return e.has("qty")


## Génère le stock d'un lieu de type `settlement_kind` ("village" | "city") à partir de Data.SHOPS. Aléa injecté.
static func generate(settlement_kind: String, rng: RandomNumberGenerator) -> Array:
	var shop: Dictionary = Data.SHOPS[settlement_kind]
	var city: bool = settlement_kind == "city"
	var out: Array = []
	out.append(food(rng.randi_range(70, 130) if city else rng.randi_range(35, 75)))
	for key in shop["weapon"]:
		for e in _copies("weapon", str(key), rng, 2):
			out.append(e)
	if bool(shop["shield"]):
		for e in _copies("shield", "", rng, 3):
			out.append(e)
	for key in shop["head"]:
		for e in _copies("head", str(key), rng, 2):
			out.append(e)
	for key in shop["body"]:
		for e in _copies("body", str(key), rng, 2):
			out.append(e)
	for key in shop.get("tool", []):
		if rng.randf() < PRESENCE:
			var t: Dictionary = Loot.item("tool", str(key))
			t["qty"] = rng.randi_range(2, 5)
			out.append(t)
	sort(out)
	return out


static func _copies(kind: String, key: String, rng: RandomNumberGenerator, most: int) -> Array:
	var out: Array = []
	if rng.randf() >= PRESENCE:
		return out
	var n: int = 1 + (1 if most >= 2 and rng.randf() < 0.35 else 0) + (1 if most >= 3 and rng.randf() < 0.3 else 0)
	for i in n:
		out.append(roll_wear(Loot.item(kind, key), rng))
	return out


## Rend l'objet neuf (55 %) ou d'occasion (durabilité entre 50 % et 98 %). Sans usure possible (outils) : inchangé.
static func roll_wear(it: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < NEW_CHANCE:
		return it
	var r: float = rng.randf_range(WEAR_MIN, 0.98)
	if Loot.dur_max(it) > 0:
		Loot.worn(it, maxi(1, roundi(r * Loot.dur_max(it))))
	elif Loot.armor_max(it) > 0:
		Loot.with_armor(it, maxi(1, roundi(r * Loot.armor_max(it))))
	return it


## Tri d'affichage : vivres, armes, boucliers, casques, armures, outils ; puis du plus cher au moins cher.
static func sort(stock: Array) -> void:
	stock.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka: int = int(ORDER.get(str(a["kind"]), 9))
		var kb: int = int(ORDER.get(str(b["kind"]), 9))
		if ka != kb:
			return ka < kb
		var pa: int = base_price(a)
		var pb: int = base_price(b)
		if pa != pb:
			return pa > pb
		return str(a["key"]) < str(b["key"]))


## Prix de base d'une entrée avant coefficient de lieu : prix du catalogue × (0,5 + 0,5 × durabilité), comme à la revente.
static func base_price(e: Dictionary) -> int:
	if is_food(e):
		return Data.PROVISIONS_PRICE
	return int(round(Loot.base_price(e) * (0.5 + 0.5 * Loot.wear_ratio(e))))


## L'objet unitaire d'une entrée (sans « qty »), tel qu'il entre dans l'inventaire.
static func as_item(e: Dictionary) -> Dictionary:
	return Loot.clean(e)


## Retire une unité de l'entrée n° `index` et renvoie l'objet unitaire ({} si l'indice est invalide ou si ce sont des vivres).
static func take(stock: Array, index: int) -> Dictionary:
	if index < 0 or index >= stock.size() or is_food(stock[index]):
		return {}
	var e: Dictionary = stock[index]
	var it: Dictionary = as_item(e)
	if is_stackable(e) and int(e["qty"]) > 1:
		e["qty"] = int(e["qty"]) - 1
	else:
		stock.remove_at(index)
	return it


## Reprend un objet vendu par le joueur : les outils s'empilent, le reste s'ajoute à la fin du rayon.
static func add_sold(stock: Array, it: Dictionary) -> void:
	var item: Dictionary = Loot.clean(it)
	if str(item["kind"]) == "tool":
		for e in stock:
			if str(e["kind"]) == "tool" and str(e["key"]) == str(item["key"]):
				e["qty"] = int(e["qty"]) + 1
				return
		item["qty"] = 1
	stock.append(item)
	while stock.size() > MAX_ENTRIES:
		var drop: int = -1
		for i in stock.size():
			if not is_food(stock[i]):
				drop = i
				break
		if drop < 0:
			break
		stock.remove_at(drop)


## Indices des entrées qui passent le filtre ("all", "weapon", "body", "head", "shield", "tool", "food").
static func filtered(stock: Array, filter: String) -> Array[int]:
	var out: Array[int] = []
	for i in stock.size():
		if filter == "all" or str(stock[i]["kind"]) == filter:
			out.append(i)
	return out


## Filtre de la réserve du joueur (mêmes catégories ; les vivres n'y figurent pas).
static func inventory_filtered(inventory: Array, filter: String) -> Array[int]:
	if filter == FOOD:
		return []
	return Inventory.filtered(inventory, filter) if filter != "tool" else _tools(inventory)


static func _tools(inventory: Array) -> Array[int]:
	var out: Array[int] = []
	for i in inventory.size():
		if str(inventory[i]["kind"]) == "tool":
			out.append(i)
	return out


## Copie propre d'un stock lu dans une sauvegarde (entrées invalides ignorées).
static func clean(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in raw:
		if typeof(e) != TYPE_DICTIONARY or not e.has("kind") or not e.has("key"):
			continue
		if str(e["kind"]) == FOOD:
			out.append(food(maxi(0, int(e.get("qty", 0)))))
		elif Loot.is_valid(e):
			var it: Dictionary = Loot.clean(e)
			if e.has("qty"):
				it["qty"] = maxi(1, int(e["qty"]))
			out.append(it)
	return out
