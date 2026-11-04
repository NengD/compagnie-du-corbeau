class_name Traits
extends RefCounted
## Traits de caractère des hommes (Data.TRAITS). Tirés une fois à la génération (ou à la migration d'une ancienne sauvegarde),
## jamais gagnés en combat. Logique pure : les effets d'attributs sont lus par Unit.eff(), le reste par les hooks ci-dessous.


## Tire 1 ou 2 traits pour `u`, de façon stable (graine dérivée de son id : ne touche pas à l'aléa de la partie).
static func roll_for(u: Unit) -> Array[String]:
	var r := RandomNumberGenerator.new()
	r.seed = u.id * 7919 + 104729
	var keys: Array = Data.TRAITS.keys()
	var out: Array[String] = []
	var n: int = 2 if r.randf() < Data.TRAIT_CHANCE_SECOND else 1
	var tries: int = 0
	while out.size() < n and tries < 40:
		tries += 1
		var k: String = str(keys[r.randi() % keys.size()])
		if out.has(k) or _conflicts(out, k):
			continue
		out.append(k)
	return out


static func _conflicts(have: Array, k: String) -> bool:
	var fam: String = str(Data.TRAITS[k].get("ex", ""))
	for h in have:
		if str(Data.TRAITS[str(h)].get("ex", "")) == fam and fam != "":
			return true
	return false


## Donne ses traits à une recrue neuve et applique leurs effets de génération (PV max, solde).
static func assign(u: Unit) -> void:
	u.traits = roll_for(u)
	_apply_gen_effects(u)


## Donne à `u` des traits précis (recrues uniques des histoires) et applique leurs effets de génération.
static func set_fixed(u: Unit, ids: Array) -> void:
	u.traits.clear()
	for k in ids:
		if Data.TRAITS.has(str(k)):
			u.traits.append(str(k))
	_apply_gen_effects(u)


## Ancienne sauvegarde : un homme sans traits en reçoit (et ses PV / sa solde suivent). Sans effet s'il en a déjà.
static func migrate(u: Unit) -> void:
	if not u.traits.is_empty():
		return
	var hp_before: int = u.hp_max
	assign(u)
	u.hp = clampi(u.hp + (u.hp_max - hp_before), 1, u.hp_max)


static func _apply_gen_effects(u: Unit) -> void:
	var mult: float = 1.0
	for k in u.traits:
		var d: Dictionary = Data.TRAITS.get(k, {})
		u.hp_max = maxi(20, u.hp_max + int(d.get("hp", 0)))
		mult *= float(d.get("wage", 1.0))
	u.hp = u.hp_max
	if mult != 1.0 and u.wage > 0:
		u.wage = maxi(1, int(round(float(u.wage) * mult)))


static func has(u: Unit, id: String) -> bool:
	return u.traits.has(id)


static func name_of(id: String) -> String:
	return str(Data.TRAITS.get(id, {}).get("n", id))


static func names(u: Unit) -> Array:
	return u.traits.map(func(k: String) -> String: return name_of(k))


## Modificateur au test de moral de `u` quand un camarade tombe près de lui (Peureux).
static func ally_fall_mod(u: Unit) -> int:
	var m: int = 0
	for k in u.traits:
		m += int(Data.TRAITS.get(k, {}).get("ally_fall", 0))
	return m


## Bonus de moral reçu d'un allié adjacent « sociable » : le plus fort seulement.
static func aura(u: Unit, units: Array) -> int:
	var best: int = 0
	for x in units:
		var xu: Unit = x
		if xu == u or not xu.is_live() or xu.side != u.side or Hex.distance(xu.hex, u.hex) != 1:
			continue
		for k in xu.traits:
			best = maxi(best, int(Data.TRAITS.get(k, {}).get("aura", 0)))
	return best


## PV de repos en plus (Gourmand).
static func rest_bonus(u: Unit) -> int:
	var b: int = 0
	for k in u.traits:
		b += int(Data.TRAITS.get(k, {}).get("rest", 0))
	return b


## Chanceux : le coup mortel est-il évité ? Une fois par bataille ; n'utilise l'aléa que pour qui a le trait.
static func lucky_save(u: Unit, rng: RandomNumberGenerator) -> bool:
	if u.lucky_used:
		return false
	var chance: int = 0
	for k in u.traits:
		chance = maxi(chance, int(Data.TRAITS.get(k, {}).get("lucky", 0)))
	if chance <= 0:
		return false
	u.lucky_used = true
	return rng.randi_range(1, 100) <= chance
