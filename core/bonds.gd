class_name Bonds
extends RefCounted
## Relations entre hommes de la compagnie. `Unit.bonds` : {id d'un autre homme (int) -> valeur}, symétrique.
## Au-dessus de FRIEND : « amis » ; en dessous de RIVAL : « rivaux ». Logique pure.

const FRIEND: int = 12
const RIVAL: int = -8
const LIMIT: int = 40  ## les valeurs restent dans [-LIMIT, LIMIT]
const MAX_FRIENDS: int = 3  ## au plus ce nombre d'amis comptent pour un homme (les liens les plus forts)
const HIT_BONUS: int = 5  ## % de toucher en plus avec un ami adjacent
const FRIEND_MORALE: int = 5  ## modificateur aux tests de moral avec un ami adjacent
const RIVAL_MORALE: int = -5  ## idem avec un rival adjacent
const FRIEND_FALL: int = -10  ## test de moral en voyant tomber un ami
const GAIN_WIN: int = 2
const GAIN_OTHER: int = 1


static func get_bond(a: Unit, b_id: int) -> int:
	return int(a.bonds.get(b_id, 0))


## Modifie le lien entre deux hommes (dans les deux sens).
static func add(a: Unit, b: Unit, delta: int) -> void:
	if a == null or b == null or a == b or a.id == b.id or delta == 0:
		return
	var v: int = clampi(get_bond(a, b.id) + delta, -LIMIT, LIMIT)
	a.bonds[b.id] = v
	b.bonds[a.id] = v


static func set_bond(a: Unit, b: Unit, v: int) -> void:
	add(a, b, v - get_bond(a, b.id))


## Amis de `a` : ceux dont le lien dépasse le seuil, au plus MAX_FRIENDS, les plus forts d'abord. `pool` : unités possibles (la compagnie).
static func friends_of(a: Unit, pool: Array) -> Array[Unit]:
	var cand: Array[Unit] = []
	for x in pool:
		var xu: Unit = x
		if xu != a and xu.id != a.id and get_bond(a, xu.id) >= FRIEND:
			cand.append(xu)
	cand.sort_custom(func(p: Unit, q: Unit) -> bool: return get_bond(a, p.id) > get_bond(a, q.id))
	return cand.slice(0, MAX_FRIENDS)


static func rivals_of(a: Unit, pool: Array) -> Array[Unit]:
	var out: Array[Unit] = []
	for x in pool:
		var xu: Unit = x
		if xu != a and xu.id != a.id and get_bond(a, xu.id) <= RIVAL:
			out.append(xu)
	return out


static func is_friend(a: Unit, b: Unit, pool: Array) -> bool:
	return friends_of(a, pool).has(b)


## Texte de la pastille « Amis : X · Rivaux : Y » ("" si personne).
static func summary(a: Unit, pool: Array) -> String:
	var parts: Array[String] = []
	var fr: Array[Unit] = friends_of(a, pool)
	if not fr.is_empty():
		parts.append("Amis : " + ", ".join(fr.map(func(u: Unit) -> String: return u.unit_name)))
	var rv: Array[Unit] = rivals_of(a, pool)
	if not rv.is_empty():
		parts.append("Rivaux : " + ", ".join(rv.map(func(u: Unit) -> String: return u.unit_name)))
	return " · ".join(parts)


## Un ami (ou rival) de `u` est-il vivant et adjacent dans la bataille ?
static func _adjacent(u: Unit, units: Array, friend: bool) -> bool:
	if u.bonds.is_empty():
		return false
	for x in units:
		var xu: Unit = x
		if xu == u or not xu.is_live() or xu.side != u.side or Hex.distance(xu.hex, u.hex) != 1:
			continue
		var v: int = get_bond(u, xu.id)
		if friend and v >= FRIEND or not friend and v <= RIVAL:
			return true
	return false


## Bonus de toucher (en %) pour `a` : un ami adjacent.
static func hit_bonus(a: Unit, units: Array) -> int:
	return HIT_BONUS if _adjacent(a, units, true) else 0


## Modificateur aux tests de moral de `u` : ami adjacent (+), rival adjacent (−).
static func morale_mod(u: Unit, units: Array) -> int:
	var m: int = 0
	if _adjacent(u, units, true):
		m += FRIEND_MORALE
	if _adjacent(u, units, false):
		m += RIVAL_MORALE
	return m


## Test de moral de `x` quand `dead` tombe : plus dur si c'était son ami.
static func fall_mod(x: Unit, dead: Unit) -> int:
	return FRIEND_FALL if get_bond(x, dead.id) >= FRIEND else 0


## Les hommes qui ont combattu ensemble et survécu se rapprochent.
static func battle_gain(survivors: Array, win: bool) -> void:
	var d: int = GAIN_WIN if win else GAIN_OTHER
	for i in survivors.size():
		for j in range(i + 1, survivors.size()):
			add(survivors[i], survivors[j], d)


## Tire deux hommes au hasard (de préférence sans lien déjà établi) et change leur lien. Renvoie [a, b] ou [].
static func random_pair(roster: Array, rng: RandomNumberGenerator, delta: int) -> Array:
	if roster.size() < 2:
		return []
	var a: Unit = roster[rng.randi() % roster.size()]
	var b: Unit = a
	for i in 8:
		b = roster[rng.randi() % roster.size()]
		if b != a and get_bond(a, b.id) == 0:
			break
	if b == a:
		b = roster[(roster.find(a) + 1) % roster.size()]
	add(a, b, delta)
	return [a, b]


## Liens lus dans une sauvegarde : clés/valeurs entières, bornées.
static func clean(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:
			var v: int = clampi(int(raw[k]), -LIMIT, LIMIT)
			if v != 0:
				out[int(str(k))] = v
	return out


## Retire de tous les hommes les liens vers les ids absents de `roster`.
static func prune(roster: Array) -> void:
	var ids: Dictionary = {}
	for u in roster:
		ids[(u as Unit).id] = true
	for u in roster:
		for k in (u as Unit).bonds.keys():
			if not ids.has(k):
				(u as Unit).bonds.erase(k)
