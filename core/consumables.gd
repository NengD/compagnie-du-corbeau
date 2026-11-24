class_name Consumables
extends RefCounted
## Onguents et potions (données : core/consumables_data.gd). Un consommable est un objet de genre « tool » rangé dans le sac
## (`Unit.bag`) : l'utiliser en bataille le retire du sac, applique l'effet et coûte des PA. Logique pure (le journal passe par BattleState).


static func has(key: String) -> bool:
	return ConsumablesData.ITEMS.has(key)


static func is_consumable(it: Dictionary) -> bool:
	return not it.is_empty() and str(it.get("kind", "")) == "tool" and has(str(it.get("key", "")))


## Fiche d'un objet de genre « tool » : outil de jet ou consommable.
static func tool_data(key: String) -> Dictionary:
	return ConsumablesData.ITEMS[key] if has(key) else Data.TOOLS[key]


static func tool_valid(key: String) -> bool:
	return Data.TOOLS.has(key) or has(key)


static func item(key: String) -> Dictionary:
	return Loot.item("tool", key)


## Emplacements du sac de `u` qui contiennent un consommable.
static func slots_of(u: Unit) -> Array[int]:
	var out: Array[int] = []
	for i in u.bag.size():
		if is_consumable(u.bag[i]):
			out.append(i)
	return out


## Cet homme tirerait-il profit de l'objet `key` ? (un état à retirer, des PV, de la fatigue ou du moral à regagner)
static func benefits(t: Unit, key: String) -> bool:
	var d: Dictionary = ConsumablesData.ITEMS.get(key, {})
	if d.is_empty() or not t.is_live():
		return false
	for id in d.get("cure", []):
		if Statuses.has(t, str(id)):
			return true
	if int(d.get("heal", 0)) > 0 and t.hp < t.hp_max:
		return true
	if int(d.get("fat", 0)) > 0 and t.fat > 0:
		return true
	return int(d.get("morale", 0)) > 0 and t.morale < 4


## Cibles possibles de l'objet n° `slot` du sac de `u` : lui-même et, selon l'objet, les alliés au contact, tous s'ils en profitent.
static func targets(s: BattleState, u: Unit, slot: int) -> Array[Unit]:
	var out: Array[Unit] = []
	if slot < 0 or slot >= u.bag.size() or not is_consumable(u.bag[slot]):
		return out
	var key: String = str(u.bag[slot]["key"])
	var d: Dictionary = ConsumablesData.ITEMS[key]
	if benefits(u, key):
		out.append(u)
	if str(d["target"]) == "ally":
		for x in s.allies_of(u):
			if x != u and x.is_live() and Hex.distance(x.hex, u.hex) == 1 and benefits(x, key):
				out.append(x)
	return out


## Peut-on l'utiliser maintenant ? (PA, fatigue, au moins une cible qui en profite)
static func can_use(s: BattleState, u: Unit, slot: int) -> bool:
	if not u.is_live() or u.morale == 0 or slot < 0 or slot >= u.bag.size() or not is_consumable(u.bag[slot]):
		return false
	var d: Dictionary = ConsumablesData.ITEMS[str(u.bag[slot]["key"])]
	return u.ap >= int(d["ap"]) and u.fat + int(d["fat_cost"]) <= u.fat_max_eff() and not targets(s, u, slot).is_empty()


## Utilise l'objet n° `slot` du sac de `u` sur `t` (soi-même si `t` est null). Renvoie true si fait.
static func use(s: BattleState, u: Unit, slot: int, t: Unit = null) -> bool:
	var target: Unit = t if t != null else u
	if not can_use(s, u, slot) or not targets(s, u, slot).has(target):
		return false
	var key: String = str(u.bag[slot]["key"])
	var d: Dictionary = ConsumablesData.ITEMS[key]
	u.bag[slot] = {}
	u.ap -= int(d["ap"])
	u.fat += int(d["fat_cost"])
	s.undo = {}
	s.new_log_group()
	var who: String = "sur lui-même" if target == u else "sur %s" % target.unit_name
	s.say("%s utilise %s %s." % [u.unit_name, str(d["n"]).to_lower(), who], "mor")
	for id in d.get("cure", []):
		Statuses.cure(s, target, str(id), "soigné")
	var heal: int = mini(target.hp_max - target.hp, int(d.get("heal", 0)))
	if heal > 0:
		target.hp += heal
		s.say("%s regagne %d PV." % [target.unit_name, heal], "mor")
		Statuses.fx(s, target, "+%d" % heal, "heal")
	var rest: int = mini(target.fat, int(d.get("fat", 0)))
	if rest > 0:
		target.fat -= rest
		s.say("%s reprend son souffle (−%d fatigue)." % [target.unit_name, rest], "mor")
	if int(d.get("morale", 0)) > 0 and target.morale < 4:
		target.morale = mini(4, target.morale + int(d["morale"]))
		s.say("%s retrouve du cœur : %s." % [target.unit_name, str(Data.MORALE_NAMES[target.morale]).to_lower()], "mor")
		Statuses.fx(s, target, str(Data.MORALE_NAMES[target.morale]), "morale")
	return true


## Butin de bataille : un consommable de temps en temps sur les ennemis tués. Aléa dérivé de l'état des unités (ne consomme pas
## le générateur de la bataille : le butin d'équipement tiré avant reste identique).
static func roll_loot(units: Array) -> Array:
	var out: Array = []
	var g := RandomNumberGenerator.new()
	var seed_v: int = 0x5EED
	for x in units:
		var xu: Unit = x
		seed_v = (seed_v * 31 + xu.id * 7 + (1 if xu.dead else 0)) & 0x7FFFFFFF
	g.seed = seed_v
	var total: int = 0
	for e in ConsumablesData.DROP_TABLE:
		total += int(e[1])
	for x in units:
		var xu: Unit = x
		if xu.side != "e" or not xu.dead or xu.immobile or xu.faction == "u":
			continue
		if g.randf() < (ConsumablesData.DROP_CHANCE_LEADER if xu.leader else ConsumablesData.DROP_CHANCE):
			var r: int = g.randi_range(1, total)
			for e in ConsumablesData.DROP_TABLE:
				r -= int(e[1])
				if r <= 0:
					out.append(item(str(e[0])))
					break
	return out


## Lignes de boutique d'un type de lieu ("village" | "city") : entrées empilables {"kind": "tool", "key", "qty"}. Aléa injecté.
static func shop_entries(settlement_kind: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for row in ConsumablesData.SHOP.get(settlement_kind, []):
		var r: Array = row
		if rng.randi_range(1, 100) <= int(r[1]):
			var e: Dictionary = item(str(r[0]))
			e["qty"] = rng.randi_range(int(r[2]), int(r[3]))
			out.append(e)
	return out
