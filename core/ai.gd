class_name Ai
extends RefCounted
## Comportement des unités (ennemies, ou joueur en simulation) et des unités en fuite.
## Chaque comportement est borné : au plus 5 actions par tour (voir `next_action`), un repli au plus 3 fois par bataille.


## `field` : champ de distance (PA) vers les ennemis, calculé une fois par tour (voir `next_action`).
static func eval_pos(s: BattleState, u: Unit, h: Vector2i, field: Dictionary = {}) -> float:
	var w: Dictionary = u.weapon_data()
	var rng_u: int = u.weapon_range()
	var foes: Array[Unit] = s.foes_of(u)
	if foes.is_empty():
		return 0.0
	var md: int = 99
	var shot: bool = false
	var near: Unit = null
	for f in foes:
		var d: int = Hex.distance(h, f.hex)
		if d < md:
			md = d
			near = f
		if bool(w["ranged"]) and d <= rng_u and not CombatRules.line_blocked(h, f.hex, s.cells):
			shot = true
	var high: float = 10.0 if CombatRules.terrain_at(s.cells, h)["h"] + Scenery.height_bonus(s.cells, h) > 0 else 0.0
	if bool(w["ranged"]):
		var want: int = maxi(2, rng_u - 1)  # portée maximale (un cran en retrait de la limite)
		return (50.0 if shot else 0.0) - absf(md - want) * 3.0 - (40.0 if md == 1 else 0.0) + high
	if md > rng_u and field.has(h):  # on compte la marche réelle (rivières, obstacles), pas la distance à vol d'oiseau
		md = maxi(md, int(field[h]) / 2)
	var adj_allies: int = 0
	for a in s.allies_of(u):
		if Hex.distance(h, a.hex) == 1:
			adj_allies += 1
	var surround: float = 0.0
	if bool(u.foe_data().get("flank", false)) and near != null and Hex.distance(h, near.hex) <= rng_u:
		for a in s.allies_of(u):  # préfère les cases où plusieurs alliés encerclent déjà la cible
			if Hex.distance(a.hex, near.hex) == 1:
				surround += 4.0
	return (60.0 if md <= rng_u else 0.0) - maxf(0.0, md - rng_u) * 10.0 + adj_allies + surround + high


static func target_score(s: BattleState, u: Unit, f: Unit) -> float:
	var hc: float = s.hit_chance(u, f)
	var missing: float = 1.0 - float(f.hp) / float(f.hp_max)
	return hc * (1.6 - float(f.hp) / float(f.hp_max)) + (10.0 if f.morale == 0 else 0.0) + (missing * 40.0 if u.faction == "g" else 0.0) \
		+ (25.0 if f.is_cart() else 0.0)


## Capacité à tenter contre `f` ("" = attaque simple). Ne tire l'aléa que s'il existe une capacité utile et utilisable.
static func pick_ability(s: BattleState, u: Unit, f: Unit) -> String:
	var usable: Array[String] = []
	for id in CombatRules.abilities_of(u):
		if not s.can_use_ability(u, f, id):
			continue
		var ab: Dictionary = Data.ABILITIES[id]
		if ab.has("armor") and maxi(f.arm_h, f.arm_b) < 40:
			continue
		if ab.has("hit") and int(ab["hit"]) > 0 and s.hit_chance(u, f) >= 70 and not ab.has("tool"):
			continue
		if bool(ab.get("stun", false)) and (f.stunned or f.morale == 0):
			continue
		if bool(ab.get("expose", false)) and f.exposed:
			continue
		if bool(ab.get("net", false)) and (f.is_big() or f.rooted > 0):
			continue
		if bool(ab.get("fire", false)) or bool(ab.get("splash", false)):  # pas de feu ni de zone sur ses propres hommes
			var friendly: bool = false
			for x in s.units:
				if x.is_live() and x.side == u.side and Hex.distance(x.hex, f.hex) <= 1:
					friendly = true
			if friendly:
				continue
		if bool(ab.get("splash", false)):
			var n: int = 0
			for x in s.foes_of(u):
				if Hex.distance(x.hex, f.hex) <= 1:
					n += 1
			if n >= 2:
				return id  # une belle cible : on lance sans hésiter
		usable.append(id)
	if usable.is_empty() or s.rng.randf() >= Data.AI_ABILITY_CHANCE:
		return ""
	return usable[s.rng.randi() % usable.size()]


## Soin d'un allié blessé, ou relève d'un mort-vivant. {} si rien à faire.
static func support_action(s: BattleState, u: Unit) -> Dictionary:
	if int(u.foe_data().get("heal", 0)) > 0:
		var best: Unit = null
		for a in s.allies_of(u):
			if s.can_heal(u, a) and float(a.hp) < float(a.hp_max) * 0.7 and (best == null or a.hp < best.hp):
				best = a
		if best != null:
			return {"type": "heal", "target": best}
	var rz: Array[Unit] = s.raisable(u)
	if not rz.is_empty():
		return {"type": "raise", "target": rz[0]}
	return {}


## Le fort tient-il encore (siège) ? Ses défenseurs restent derrière le rempart tant que la porte est debout, jusqu'à la manche 12.
static func holds_position(s: BattleState, u: Unit) -> bool:
	if s.battle_type != "siege" or u.side != "e" or s.round_no > 12:
		return false
	for h in s.cells:
		if Scenery.kind_at(s.cells, h) == "gate":
			return true
	return false


## Un chef reste derrière sa ligne tant qu'elle tient, puis rejoint le combat.
static func leader_waits(s: BattleState, u: Unit) -> bool:
	if not u.leader or u.is_ranged():
		return false
	var total: int = 0
	var fighting: int = 0
	for x in s.units:
		if x.side == u.side and x != u and not x.immobile:
			total += 1
			if x.is_fighting():
				fighting += 1
	if total == 0 or float(fighting) < float(total) * 0.6:
		return false
	for f in s.foes_of(u):
		if Hex.distance(f.hex, u.hex) <= 2:
			return false
	return true


## Prochaine action de l'unité. `memo` garde l'état du tour entre deux appels (passer le même dictionnaire).
## Retour : {"type": "attack", "target": Unit} | {"type": "ability", "id": String, "target": Unit} | {"type": "move", "path": Array[Vector2i]}
## | {"type": "shield"} | {"type": "heal"|"raise", "target": Unit} | {"type": "hit_object"|"open", "hex": Vector2i} | {"type": "end"}
static func next_action(s: BattleState, u: Unit, memo: Dictionary) -> Dictionary:
	var n: int = int(memo.get("n", 0))
	while n < 5:
		var sup: Dictionary = support_action(s, u)
		if not sup.is_empty():
			memo["n"] = n + 1
			memo["attacked"] = true
			return sup
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
		if not memo.get("tooled", false):  # lancer d'un outil / tir spécial sur une cible hors de portée de l'arme
			memo["tooled"] = true
			for f in s.foes_of(u):
				var tid: String = pick_ability(s, u, f)
				if tid != "" and Data.ABILITIES[tid].has("tool"):
					memo["n"] = n + 1
					memo["attacked"] = true
					memo["tooled"] = false
					return {"type": "ability", "id": tid, "target": f}
		if memo.get("attacked", false) or memo.get("moved", false):
			break
		if holds_position(s, u) or leader_waits(s, u):
			break
		var reach: Dictionary = s.reachable(u, true)
		if not memo.has("field"):
			var foe_hexes: Array = []
			for f in s.foes_of(u):
				foe_hexes.append(f.hex)
			memo["field"] = Pathfinding.distance_field(s.cells, foe_hexes)
		var field: Dictionary = memo["field"]
		# Blessé : se replie vers son bord (borné à 3 fois par bataille).
		if u.hp < u.hp_max * 0.3 and not u.leader and not bool(u.foe_data().get("fearless", false)) and u.faction != "u" and u.faction != "c" \
				and u.retreats < 3 and not reach.is_empty() and _enemy_near(s, u, 3) and s.rng.randf() < 0.5:
			u.retreats += 1
			var rp: Array[Vector2i] = flee_path(s, u)
			if not rp.is_empty():
				memo["n"] = n + 1
				memo["moved"] = true
				return {"type": "move", "path": rp}
		# Rempart ou porte entre nous et l'ennemi : on l'ouvre ou on le fracasse.
		if not field.has(u.hex) and not u.is_ranged():
			var br: Dictionary = _breach_action(s, u, reach)
			if not br.is_empty():
				memo["n"] = n + 1
				if br["type"] == "move":
					memo["moved"] = true
				return br
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
	if not memo.get("shielded", false) and u.is_live() and u.shield_ok() and not u.shield_wall and u.ap >= u.wall_ap():
		for f in s.foes_of(u):
			if Hex.distance(f.hex, u.hex) <= 2:
				memo["shielded"] = true
				return {"type": "shield"}
	return {"type": "end"}


static func _enemy_near(s: BattleState, u: Unit, r: int) -> bool:
	for f in s.foes_of(u):
		if Hex.distance(f.hex, u.hex) <= r:
			return true
	return false


## Aucun chemin vers l'ennemi : ouvrir une porte voisine, frapper l'obstacle le plus proche, ou s'en approcher.
static func _breach_action(s: BattleState, u: Unit, reach: Dictionary) -> Dictionary:
	for h in Scenery.openable_near(s, u):
		if Scenery.can_open(s, u, h):
			return {"type": "open", "hex": h}
	var targets: Array[Vector2i] = Scenery.breach_targets(s, u)
	if targets.is_empty():
		return {}
	var t: Vector2i = targets[0]
	if Scenery.can_hit_object(s, u, t):
		return {"type": "hit_object", "hex": t}
	var best: Variant = null
	var best_d: int = Hex.distance(u.hex, t)
	for k in reach:
		var d: int = Hex.distance(k, t)
		if d < best_d:
			best_d = d
			best = k
	if best == null:
		return {}
	return {"type": "move", "path": Pathfinding.path_to(reach, best)}


## Chemin de fuite vers le bord de carte (vide si on ne peut pas mieux faire sur place).
static func flee_path(s: BattleState, u: Unit) -> Array[Vector2i]:
	var edge: int = s.edge_column(u)
	var reach: Dictionary = s.reachable(u, true)
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
