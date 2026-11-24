class_name Orders
extends RefCounted
## Ordres de groupe (données : core/orders_data.gd). Un capitaine peut donner UN ordre par manche à ses alliés proches ; un seul ordre
## est actif par camp (`BattleState.orders[side]` = {"id", "cap": id du capitaine, "round": manche du dernier ordre}). L'ordre tombe quand
## le capitaine rejoue, tombe ou s'enfuit, ou quand un autre ordre est donné. Les effets sont des états d'ordre (core/statuses_data.gd).


## Le capitaine du camp du joueur sans talent de chef : plus haut niveau, puis détermination, puis plus petit id.
static func company_captain(s: BattleState, side: String) -> Unit:
	var best: Unit = null
	for x in s.units:
		if x.side != side or not x.is_live() or x.morale <= 0 or x.immobile or x.eff("resolve") < OrdersData.CAPTAIN_MIN_RESOLVE:
			continue
		if best == null or x.level > best.level or (x.level == best.level and (x.eff("resolve") > best.eff("resolve") or (x.eff("resolve") == best.eff("resolve") and x.id < best.id))):
			best = x
	return best


static func has_chief_perk(u: Unit) -> bool:
	for p in OrdersData.CAPTAIN_PERKS:
		if u.has_perk(p):
			return true
	return false


## `u` peut-il donner des ordres ? Camp ennemi : le chef ; compagnie : un homme à talent de chef, ou le capitaine désigné.
static func is_captain(s: BattleState, u: Unit) -> bool:
	if u == null or not u.is_live() or u.morale <= 0 or u.immobile:
		return false
	if u.side != "p":
		return u.leader
	return has_chief_perk(u) or company_captain(s, u.side) == u


static func active(s: BattleState, side: String) -> Dictionary:
	return s.orders.get(side, {})


## Alliés (vivants, valides) touchés par l'ordre, `u` compris, dans le rayon de l'ordre.
static func recipients(s: BattleState, u: Unit, id: String) -> Array[Unit]:
	var out: Array[Unit] = []
	var r: int = int(OrdersData.ORDERS[id]["radius"])
	for x in s.units:
		if x.side == u.side and x.is_live() and not x.immobile and Hex.distance(x.hex, u.hex) <= r:
			out.append(x)
	return out


## Rayon, PA, fatigue, un ordre par manche, au moins un autre allié concerné (et, pour le mur, un bouclier à lever).
static func can_give(s: BattleState, u: Unit, id: String) -> bool:
	if not OrdersData.ORDERS.has(id) or not is_captain(s, u) or s.over != "":
		return false
	var od: Dictionary = OrdersData.ORDERS[id]
	if u.ap < int(od["ap"]) or u.fat + int(od["fat"]) > u.fat_max_eff():
		return false
	if int(active(s, u.side).get("round", -1)) == s.round_no:
		return false  ## un seul ordre par manche
	var others: int = 0
	var shields: int = 0
	for x in recipients(s, u, id):
		if x == u:
			continue
		others += 1
	for x in recipients(s, u, id):
		if x.shield_ok() and not x.shield_wall:
			shields += 1
	if others < int(od["min_allies"]):
		return false
	return id != "mur" or shields > 0


## Pourquoi l'ordre est impossible (pour l'infobulle), "" s'il est possible.
static func why_not(s: BattleState, u: Unit, id: String) -> String:
	if can_give(s, u, id):
		return ""
	var od: Dictionary = OrdersData.ORDERS[id]
	if int(active(s, u.side).get("round", -1)) == s.round_no:
		return "Un seul ordre par manche."
	if u.ap < int(od["ap"]):
		return "Pas assez de PA (%d)." % int(od["ap"])
	if u.fat + int(od["fat"]) > u.fat_max_eff():
		return "Trop fatigué."
	if id == "mur":
		return "Aucun bouclier à lever à 2 cases ou moins."
	return "Aucun allié à portée (%d cases)." % int(od["radius"])


## Donne l'ordre. Renvoie true si fait. Remplace l'ordre précédent du camp.
static func give(s: BattleState, u: Unit, id: String) -> bool:
	if not can_give(s, u, id):
		return false
	var od: Dictionary = OrdersData.ORDERS[id]
	expire(s, u.side)
	u.ap -= int(od["ap"])
	u.fat += int(od["fat"])
	s.undo = {}
	s.new_log_group()
	s.say("%s ordonne : « %s »" % [u.unit_name, str(od["n"])], "mor")
	var n: int = 0
	for x in recipients(s, u, id):
		if id == "mur":
			if x.shield_ok() and not x.shield_wall:
				x.shield_wall = true
				n += 1
				Statuses.fx(s, x, "Mur", "order")
		else:
			x.statuses[str(od["status"])] = 1
			n += 1
			Statuses.fx(s, x, str(StatusesData.STATUSES[str(od["status"])]["n"]), "order")
	s.orders[u.side] = {"id": id, "cap": u.id, "round": s.round_no}
	s.say("%d homme%s concerné%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""], "miss")
	return true


## Retire les effets de l'ordre actif du camp (l'enregistrement de la manche reste : un ordre par manche).
static func expire(s: BattleState, side: String) -> void:
	Statuses.clear_orders(s.units, side)
	if s.orders.has(side):
		s.orders[side]["id"] = ""
		s.orders[side]["cap"] = -1


## Début du tour de `u` : s'il était le capitaine de l'ordre actif, l'ordre prend fin.
static func on_turn_start(s: BattleState, u: Unit) -> void:
	if not s.orders.is_empty() and int(active(s, u.side).get("cap", -1)) == u.id:
		expire(s, u.side)


## Le capitaine tombe ou s'enfuit : l'ordre est annulé.
static func on_unit_lost(s: BattleState, u: Unit) -> void:
	if not s.orders.is_empty() and int(active(s, u.side).get("cap", -1)) == u.id:
		expire(s, u.side)
		if u.dead:
			s.say("L'ordre de %s tombe avec lui." % u.unit_name, "mor")


## Ordre que l'IA donnerait ("" = aucun). N'utilise l'aléa que si une situation s'y prête.
static func ai_pick(s: BattleState, u: Unit) -> String:
	if not is_captain(s, u) or int(active(s, u.side).get("round", -1)) == s.round_no:
		return ""
	var foes: Array[Unit] = s.foes_of(u)
	if foes.is_empty():
		return ""
	var cands: Array[String] = []
	var engaged: int = 0
	var near_contact: int = 0
	var hurt: int = 0
	for x in recipients(s, u, "charge"):
		if x == u or not x.is_fighting():
			continue
		var dmin: int = 99
		for f in foes:
			dmin = mini(dmin, Hex.distance(f.hex, x.hex))
		if dmin == 1:
			engaged += 1
		elif dmin <= 6:
			near_contact += 1
		if x.hp < x.hp_max * 0.35:
			hurt += 1
	if near_contact >= 2 and engaged == 0:
		cands.append("charge")
	if engaged >= 2:
		cands.append("tenir")
	if can_give(s, u, "mur") and (engaged + near_contact) >= 1:
		cands.append("mur")
	if hurt >= 2 and u.hp < u.hp_max * 0.5:
		cands.append("repli")
	var ok: Array[String] = []
	for id in cands:
		if can_give(s, u, id):
			ok.append(id)
	if ok.is_empty() or s.rng.randf() >= OrdersData.AI_ORDER_CHANCE:
		return ""
	return ok[s.rng.randi() % ok.size()]


## Sérialisation de BattleState.orders (clés absentes tolérées).
static func clean(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in raw:
		var e: Variant = raw[k]
		if typeof(e) == TYPE_DICTIONARY:
			var id: String = str(e.get("id", ""))
			out[str(k)] = {"id": id if OrdersData.ORDERS.has(id) else "", "cap": int(e.get("cap", -1)), "round": int(e.get("round", -1))}
	return out
