class_name Injuries
extends RefCounted
## Blessures des hommes de la compagnie (les ennemis ne se blessent pas durablement). Logique pure, aléa injecté.
## Une blessure : {"id": clé de Data.INJURIES, "days_left": jours restants, -1 = permanente}.


static func _chance(u: Unit, base: int) -> int:
	return base / 2 if u.has_perk("dur_a_cuire") else base


static func _add(u: Unit, id: String, rng: RandomNumberGenerator) -> void:
	var def: Dictionary = Data.INJURIES[id]
	var days: int = -1
	if not bool(def["perm"]):
		days = rng.randi_range(int(def["days"][0]), int(def["days"][1]))
	u.injuries.append({"id": id, "days_left": days})


static func _pool(u: Unit, perm: bool) -> Array[String]:
	var out: Array[String] = []
	for k in Data.INJURIES:
		if bool(Data.INJURIES[k]["perm"]) == perm and not u.has_injury(str(k)):
			out.append(str(k))
	return out


## Après un coup qui a laissé `u` en vie : blessure temporaire si le coup a retiré assez de PV. Renvoie l'id, ou "".
static func roll_wound(u: Unit, hp_lost: int, rng: RandomNumberGenerator, difficulty: String = "normal") -> String:
	if u.side != "p" or u.dead or float(hp_lost) < Data.WOUND_HP_FRAC * float(u.hp_max):
		return ""
	var pool: Array[String] = _pool(u, false)
	if pool.is_empty() or rng.randi_range(1, 100) > Difficulty.wound_chance(difficulty, _chance(u, Data.WOUND_CHANCE)):
		return ""
	var id: String = pool[rng.randi_range(0, pool.size() - 1)]
	_add(u, id, rng)
	return id


## Fin de combat : un survivant resté à `PERM_HP_FRAC` de ses PV max ou moins peut garder une séquelle. Renvoie l'id, ou "".
static func roll_permanent(u: Unit, rng: RandomNumberGenerator, difficulty: String = "normal") -> String:
	if u.dead or float(u.hp) > Data.PERM_HP_FRAC * float(u.hp_max):
		return ""
	var pool: Array[String] = _pool(u, true)
	if pool.is_empty() or rng.randi_range(1, 100) > Difficulty.wound_chance(difficulty, _chance(u, Data.PERM_CHANCE)):
		return ""
	var id: String = pool[rng.randi_range(0, pool.size() - 1)]
	_add(u, id, rng)
	return id


## Un jour (ou `amount` jours de soins) passe. Renvoie les noms des blessures guéries.
static func heal(u: Unit, amount: int) -> Array[String]:
	var healed: Array[String] = []
	var kept: Array = []
	for i in u.injuries:
		var left: int = int(i["days_left"])
		if left < 0:
			kept.append(i)
			continue
		left -= amount
		if left > 0:
			i["days_left"] = left
			kept.append(i)
		else:
			healed.append(str(Data.INJURIES[str(i["id"])]["n"]))
	u.injuries = kept
	return healed


static func label(i: Dictionary) -> String:
	var def: Dictionary = Data.INJURIES.get(str(i["id"]), {})
	var days: int = int(i["days_left"])
	return "%s (%s)" % [def.get("n", "?"), "permanente" if days < 0 else "%d j" % days]
