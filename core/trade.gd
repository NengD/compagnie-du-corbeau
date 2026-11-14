class_name Trade
extends RefCounted
## Négoce de marchandises entre lieux (logique pure, sans scène ni aléa partagé). Tables : core/trade_data.gd.
## État persistant : `Game.extras["trade"]` = {"cargo": {bien: qté}, "paid": {bien: couronnes dépensées pour la cargaison actuelle},
## "seen": {id du lieu: {"name", "day", "p": {bien: prix}}}}. Clé absente (ancienne sauvegarde) = cale vide, aucun prix connu.
## Les prix d'un lieu dépendent seulement de (lieu, bien, jour) : aucun hasard consommé.


static func goods() -> Array:
	return TradeData.ORDER


static func name_of(g: String) -> String:
	return str(TradeData.GOODS.get(g, {}).get("n", g))


## État normalisé (créé au besoin) dans le dictionnaire `extras`.
static func state(extras: Dictionary) -> Dictionary:
	var raw: Variant = extras.get("trade", {})
	var st: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var cargo: Dictionary = {}
	var paid: Dictionary = {}
	var rc: Variant = st.get("cargo", {})
	var rp: Variant = st.get("paid", {})
	for g in TradeData.GOODS:
		var q: int = maxi(0, int((rc as Dictionary).get(g, 0))) if typeof(rc) == TYPE_DICTIONARY else 0
		if q > 0:
			cargo[g] = q
			paid[g] = maxi(0, int((rp as Dictionary).get(g, 0))) if typeof(rp) == TYPE_DICTIONARY else 0
	var seen: Dictionary = {}
	var rs: Variant = st.get("seen", {})
	if typeof(rs) == TYPE_DICTIONARY:
		for sid in rs:
			var e: Variant = rs[sid]
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var p: Dictionary = {}
			var rpp: Variant = (e as Dictionary).get("p", {})
			if typeof(rpp) == TYPE_DICTIONARY:
				for g in TradeData.GOODS:
					if (rpp as Dictionary).has(g):
						p[g] = maxi(1, int(rpp[g]))
			seen[str(sid)] = {"name": str((e as Dictionary).get("name", "")), "day": int((e as Dictionary).get("day", 0)), "p": p}
	var out: Dictionary = {"cargo": cargo, "paid": paid, "seen": seen}
	extras["trade"] = out
	return out


static func total(st: Dictionary) -> int:
	var n: int = 0
	for g in st["cargo"]:
		n += int(st["cargo"][g])
	return n


## Capacité de la cargaison : un peu de base, plus un lot par homme, plus l'Entrepôt du camp (niveau 0 à 3).
static func capacity(men: int, store_level: int) -> int:
	return TradeData.CARGO_BASE + men * TradeData.CARGO_PER_MAN + store_level * TradeData.CARGO_PER_STORE_LEVEL


static func qty_of(st: Dictionary, g: String) -> int:
	return int(st["cargo"].get(g, 0))


# --- Prix ---

static func _h(a: int, b: int, c: int) -> int:
	return ((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0x7fffffff


static func _sid(s: Dictionary) -> int:
	return int(str(s.get("id", "s0")).trim_prefix("s"))


static func _gi(g: String) -> int:
	return TradeData.ORDER.find(g) + 1


## Les `n` biens de `pool` que ce lieu retient (classés par une empreinte stable du lieu).
static func _pick(pool: Array, s: Dictionary, salt: int, n: int) -> Array:
	var a: Array = pool.duplicate()
	var sid: int = _sid(s)
	a.sort_custom(func(x: Variant, y: Variant) -> bool:
		var hx: int = _h(sid, _gi(str(x)), salt)
		var hy: int = _h(sid, _gi(str(y)), salt)
		return hx < hy if hx != hy else str(x) < str(y))
	return a.slice(0, mini(n, a.size()))


static func _union(a: Array, b: Array) -> Array:
	var out: Array = a.duplicate()
	for g in b:
		if not out.has(g):
			out.append(g)
	return out


## Biens produits localement (prix bas) selon le type de lieu et la faction propriétaire.
static func makes(s: Dictionary) -> Array:
	var kind: String = str(s.get("kind", "village"))
	var pool: Array = _union(TradeData.KIND_MAKES.get(kind, TradeData.KIND_MAKES["village"]), TradeData.FACTION_MAKES.get(str(s.get("owner", "")), []))
	return _pick(pool, s, 11, 3)


## Biens demandés localement (prix haut) ; ce qu'un lieu produit n'y est jamais demandé.
static func wants(s: Dictionary) -> Array:
	var kind: String = str(s.get("kind", "village"))
	var pool: Array = _union(TradeData.KIND_WANTS.get(kind, TradeData.KIND_WANTS["village"]), TradeData.FACTION_WANTS.get(str(s.get("owner", "")), []))
	var mk: Array = makes(s)
	pool = pool.filter(func(g: Variant) -> bool: return not mk.has(g))
	return _pick(pool, s, 29, 3)


## "make" | "want" | "" pour le bien `g` dans le lieu `s`.
static func role(s: Dictionary, g: String) -> String:
	if makes(s).has(g):
		return "make"
	if wants(s).has(g):
		return "want"
	return ""


## Prix « de la place » (milieu) : base × rôle × variation du jour, borné.
static func mid_price(s: Dictionary, g: String, day: int) -> int:
	if not TradeData.GOODS.has(g):
		return 0
	var base: float = float(TradeData.GOODS[g]["base"])
	var m: float = 1.0
	match role(s, g):
		"make":
			m = TradeData.MAKE_MULT
		"want":
			m = TradeData.WANT_MULT
	var w: float = (float(_h(_sid(s), _gi(g), day / TradeData.WOBBLE_DAYS) % 2001) / 1000.0 - 1.0) * TradeData.WOBBLE
	m = clampf(m * (1.0 + w), TradeData.MIN_MULT, TradeData.MAX_MULT)
	return maxi(1, int(round(base * m)))


## Prix d'achat à la place ; `mult` : majoration de réputation / de guerre.
static func buy_price(s: Dictionary, g: String, day: int, mult: float = 1.0) -> int:
	return maxi(1, int(round(float(mid_price(s, g, day)) * maxf(mult, 0.0))))


static func sell_price(s: Dictionary, g: String, day: int) -> int:
	return maxi(1, int(floor(float(mid_price(s, g, day)) * TradeData.SPREAD)))


# --- Opérations ---

## Achat de `qty` unités à `unit` l'une. `free` : place restante. Renvoie {"ok", "qty", "cost", "err"} ; ne touche pas à l'or.
static func buy(st: Dictionary, g: String, qty: int, unit: int, gold: int, free: int) -> Dictionary:
	if not TradeData.GOODS.has(g) or qty <= 0:
		return {"ok": false, "qty": 0, "cost": 0, "err": "Marchandise inconnue."}
	var n: int = mini(qty, free)
	if n <= 0:
		return {"ok": false, "qty": 0, "cost": 0, "err": "La cargaison est pleine."}
	n = mini(n, gold / maxi(1, unit))
	if n <= 0:
		return {"ok": false, "qty": 0, "cost": 0, "err": "Pas assez de couronnes."}
	var cost: int = n * unit
	st["cargo"][g] = qty_of(st, g) + n
	st["paid"][g] = int(st["paid"].get(g, 0)) + cost
	return {"ok": true, "qty": n, "cost": cost, "err": ""}


## Vente de `qty` unités à `unit` l'une. Renvoie {"ok", "qty", "gain", "profit", "err"} ; le profit compare au prix moyen payé.
static func sell(st: Dictionary, g: String, qty: int, unit: int) -> Dictionary:
	var have: int = qty_of(st, g)
	var n: int = mini(qty, have)
	if n <= 0:
		return {"ok": false, "qty": 0, "gain": 0, "profit": 0, "err": "Vous n'en avez pas en cargaison."}
	var paid: int = int(st["paid"].get(g, 0))
	var cost_share: int = int(round(float(paid) * float(n) / float(have)))
	var gain: int = n * unit
	if n >= have:
		st["cargo"].erase(g)
		st["paid"].erase(g)
	else:
		st["cargo"][g] = have - n
		st["paid"][g] = paid - cost_share
	return {"ok": true, "qty": n, "gain": gain, "profit": gain - cost_share, "err": ""}


## Mémorise les prix vus dans le lieu `s` (appelé quand on ouvre le rayon des marchandises).
static func remember(st: Dictionary, s: Dictionary, day: int) -> void:
	var p: Dictionary = {}
	for g in TradeData.ORDER:
		p[g] = mid_price(s, g, day)
	st["seen"][str(s.get("id", ""))] = {"name": str(s.get("name", "")), "day": day, "p": p}


## Prix connus d'un bien, du plus cher au moins cher : [{"id", "name", "price", "day"}].
static func known(st: Dictionary, g: String) -> Array:
	var out: Array = []
	for sid in st["seen"]:
		var e: Dictionary = st["seen"][sid]
		if (e["p"] as Dictionary).has(g):
			out.append({"id": sid, "name": str(e["name"]), "price": int(e["p"][g]), "day": int(e["day"])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["price"]) > int(b["price"]) if int(a["price"]) != int(b["price"]) else str(a["id"]) < str(b["id"]))
	return out


# --- Caravanes (escortes) ---

## Certaines escortes deviennent des caravanes : même trajet, prime majorée si tout le monde arrive vivant. Aléa injecté.
static func tag_caravans(contracts: Array, rng: RandomNumberGenerator) -> void:
	for c in contracts:
		if str(c.get("type_contract", "")) != "escort" or c.has("caravan"):
			continue
		if rng.randf() >= TradeData.CARAVAN_CHANCE:
			continue
		c["caravan"] = true
		c["title"] = str(c.get("title", "")).replace("Escorte vers ", "Caravane vers ")
		c["desc"] = str(c.get("desc", "")) + " Une prime s'ajoute si la caravane arrive intacte, sans un seul homme perdu."


static func is_caravan(c: Dictionary) -> bool:
	return bool(c.get("caravan", false))


## À l'acceptation : retient l'effectif de départ.
static func on_accept(c: Dictionary, men: int) -> void:
	if is_caravan(c):
		c["caravan_men"] = men


## À l'arrivée : majore la prime si personne n'est mort en route. Renvoie une ligne de nouvelles (ou "").
static func settle_caravan(c: Dictionary, men_now: int) -> String:
	if not is_caravan(c) or bool(c.get("caravan_paid", false)):
		return ""
	c["caravan_paid"] = true
	if men_now < int(c.get("caravan_men", 0)):
		return "La caravane arrive, mais des hommes sont tombés en route : pas de prime."
	var bonus: int = int(round(float(c.get("pay", 0)) * TradeData.CARAVAN_BONUS / 5.0)) * 5
	c["pay"] = int(c.get("pay", 0)) + bonus
	return "Caravane intacte : prime de %d couronnes." % bonus
