class_name Ai
extends RefCounted
## Comportement des unités ennemies (brigands, goules) et des unités en fuite. Pas d'effet de bord.


## `field` : champ de distance (PA) vers les ennemis, calculé une fois par tour (voir `next_action`).
static func eval_pos(s: BattleState, u: Unit, h: Vector2i, field: Dictionary = {}) -> float:
	var w: Dictionary = u.weapon_data()
	var rng_u: int = u.weapon_range()
	var foes: Array[Unit] = s.foes_of(u)
	if foes.is_empty():
		return 0.0
	var md: int = 99
	var shot: bool = false
	for f in foes:
		var d: int = Hex.distance(h, f.hex)
		md = mini(md, d)
		if bool(w["ranged"]) and d <= rng_u and not CombatRules.line_blocked(h, f.hex, s.cells):
			shot = true
	if bool(w["ranged"]):
		return (50.0 if shot else 0.0) - absf(md - 4) * 3.0 - (40.0 if md == 1 else 0.0)
	if md > rng_u and field.has(h):  # on compte la marche réelle (rivières, obstacles), pas la distance à vol d'oiseau
		md = maxi(md, int(field[h]) / 2)
	var adj_allies: int = 0
	for a in s.allies_of(u):
		if Hex.distance(h, a.hex) == 1:
			adj_allies += 1
	return (60.0 if md <= rng_u else 0.0) - maxf(0.0, md - rng_u) * 10.0 + adj_allies


static func target_score(s: BattleState, u: Unit, f: Unit) -> float:
	var hc: float = s.hit_chance(u, f)
	var missing: float = 1.0 - float(f.hp) / float(f.hp_max)
	return hc * (1.6 - float(f.hp) / float(f.hp_max)) + (10.0 if f.morale == 0 else 0.0) + (missing * 40.0 if u.faction == "g" else 0.0)


## Capacité à tenter contre `f` ("" = attaque simple). Ne tire l'aléa que s'il existe une capacité utile et utilisable.
static func pick_ability(s: BattleState, u: Unit, f: Unit) -> String:
	var usable: Array[String] = []
	for id in CombatRules.abilities_of(u):
		if not s.can_use_ability(u, f, id):
			continue
		var ab: Dictionary = Data.ABILITIES[id]
		if ab.has("armor") and maxi(f.arm_h, f.arm_b) < 40:
			continue
		if ab.has("hit") and int(ab["hit"]) > 0 and s.hit_chance(u, f) >= 70:
			continue
		if bool(ab.get("stun", false)) and (f.stunned or f.morale == 0):
			continue
		if bool(ab.get("expose", false)) and f.exposed:
			continue
		usable.append(id)
	if usable.is_empty() or s.rng.randf() >= Data.AI_ABILITY_CHANCE:
		return ""
	return usable[s.rng.randi() % usable.size()]


## Prochaine action de l'unité. `memo` garde l'état du tour entre deux appels (passer le même dictionnaire).
## Retour : {"type": "attack", "target": Unit} | {"type": "ability", "id": String, "target": Unit} | {"type": "move", "path": Array[Vector2i]} | {"type": "shield"} | {"type": "end"}
static func next_action(s: BattleState, u: Unit, memo: Dictionary) -> Dictionary:
	var n: int = int(memo.get("n", 0))
	while n < 5:
		var targets: Array[Unit] = []
		for f in s.foes_of(u):
			if s.can_attack(u, f):
				targets.append(f)
		if not targets.is_empty():
			targets.sort_custom(func(a: Unit, b: Unit) -> bool: return target_score(s, u, a) > target_score(s, u, b))
			memo["n"] = n + 1
			memo["attacked"] = true
			var ab_id: String = pick_ability(s, u, targets[0])
			if ab_id != "":
				return {"type": "ability", "id": ab_id, "target": targets[0]}
			return {"type": "attack", "target": targets[0]}
		if memo.get("attacked", false) or memo.get("moved", false):
			break
		var reach: Dictionary = s.reachable(u)
		if not memo.has("field"):
			var foe_hexes: Array = []
			for f in s.foes_of(u):
				foe_hexes.append(f.hex)
			memo["field"] = Pathfinding.distance_field(s.cells, foe_hexes)
		var field: Dictionary = memo["field"]
		var best: Variant = null
		var best_score: float = eval_pos(s, u, u.hex, field)
		for k in reach:
			var sc: float = eval_pos(s, u, k, field) - int(reach[k]["ap"]) * 0.15
			if sc > best_score:
				best_score = sc
				best = k
		if best == null:
			break
		memo["n"] = n + 1
		memo["moved"] = true
		return {"type": "move", "path": Pathfinding.path_to(reach, best)}
	memo["n"] = 5
	if not memo.get("shielded", false) and u.is_live() and u.shield_ok() and not u.shield_wall and u.ap >= 4:
		for f in s.foes_of(u):
			if Hex.distance(f.hex, u.hex) <= 2:
				memo["shielded"] = true
				return {"type": "shield"}
	return {"type": "end"}


## Chemin de fuite vers le bord de carte (vide si on ne peut pas mieux faire sur place).
static func flee_path(s: BattleState, u: Unit) -> Array[Vector2i]:
	var edge: int = s.edge_column(u)
	var reach: Dictionary = s.reachable(u)
	var score := func(h: Vector2i) -> float:
		var md: int = 99
		for f in s.foes_of(u):
			md = mini(md, Hex.distance(h, f.hex))
		return -absf(Hex.column(h) - edge) * 3.0 + mini(md, 6) * 2.0
	var best: Variant = null
	var best_score: float = score.call(u.hex)
	for k in reach:
		var sc: float = score.call(k)
		if sc > best_score:
			best_score = sc
			best = k
	if best == null:
		return []
	return Pathfinding.path_to(reach, best)
