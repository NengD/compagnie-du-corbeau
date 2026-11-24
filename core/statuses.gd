class_name Statuses
extends RefCounted
## États de combat : saignement, poison, brûlure, engourdissement (et états d'ordre). Logique pure, sauf les journaux
## (BattleState.say) et les chiffres flottants (BattleState.fx_events). Données : core/statuses_data.gd.
## Une unité sans état n'est jamais touchée par ce code (`statuses` vide : retour immédiat partout).

const FX_MAX: int = 60  ## événements d'affichage en attente au plus (une simulation sans écran ne les vide jamais)


static func has(u: Unit, id: String) -> bool:
	return int(u.statuses.get(id, 0)) > 0


static func turns(u: Unit, id: String) -> int:
	return int(u.statuses.get(id, 0))


static func any(u: Unit) -> bool:
	return not u.statuses.is_empty()


## Insensible à l'état (morts-vivants au sang et au poison, chariots).
static func immune(u: Unit, id: String) -> bool:
	if u.immobile:
		return true
	var sd: Dictionary = StatusesData.STATUSES.get(id, {})
	return (sd.get("immune", []) as Array).has(u.faction) if not sd.is_empty() else true


## Lit un dictionnaire d'états de sauvegarde : ids connus, durées entières positives.
static func clean(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in raw:
		if StatusesData.has(str(k)) and int(raw[k]) > 0:
			out[str(k)] = int(raw[k])
	return out


## Pose l'état sur `u` (ou prolonge sa durée au plus fort). Renvoie true si l'état est nouveau pour lui.
static func apply(s: BattleState, u: Unit, id: String, n_turns: int = 0, quiet: bool = false) -> bool:
	if not StatusesData.has(id) or not u.is_live() or immune(u, id):
		return false
	var sd: Dictionary = StatusesData.STATUSES[id]
	var n: int = n_turns if n_turns > 0 else int(sd.get("turns", 2))
	var fresh: bool = not has(u, id)
	u.statuses[id] = maxi(n, turns(u, id))
	if fresh and not quiet:
		s.say("%s : %s." % [u.unit_name, str(sd["n"]).to_lower()], "mor")
		fx(s, u, str(sd["n"]), id)
	return fresh


static func remove(u: Unit, id: String) -> bool:
	return u.statuses.erase(id)


## Retire un état en le disant (soin, bandage, eau).
static func cure(s: BattleState, u: Unit, id: String, why: String = "") -> bool:
	if not remove(u, id):
		return false
	s.say("%s : %s%s." % [u.unit_name, str(StatusesData.STATUSES[id]["n"]).to_lower(), " (%s)" % why if why != "" else " cesse"], "mor")
	return true


static func clear_all(u: Unit) -> void:
	u.statuses = {}


## Efface les états d'ordre d'un camp (l'ordre expire, le capitaine tombe ou un autre ordre est donné).
static func clear_orders(units: Array, side: String) -> void:
	for x in units:
		var xu: Unit = x
		if xu.side != side or xu.statuses.is_empty():
			continue
		for id in xu.statuses.keys():
			if bool(StatusesData.STATUSES.get(str(id), {}).get("order", false)):
				xu.statuses.erase(id)


static func fx(s: BattleState, u: Unit, text: String, kind: String) -> void:
	s.fx_events.append({"hex": u.hex, "text": text, "kind": kind})
	while s.fx_events.size() > FX_MAX:
		s.fx_events.pop_front()


## Somme d'une clé numérique des états actifs de `u` ("def", "hit", "ini", "ap").
static func sum(u: Unit, key: String) -> int:
	if u.statuses.is_empty():
		return 0
	var t: int = 0
	for id in u.statuses:
		t += int(StatusesData.STATUSES.get(str(id), {}).get(key, 0))
	return t


static func ap_penalty(u: Unit) -> int:
	return sum(u, "ap")


## Malus d'initiative (négatif = bonus) : poison, ordre « Chargez ! ».
static func ini_penalty(u: Unit) -> int:
	return sum(u, "ini")


static func def_bonus(u: Unit) -> int:
	return sum(u, "def")


static func hit_bonus(u: Unit) -> int:
	return sum(u, "hit")


## Début du tour de `u` (appelé par BattleState.begin_turn après le feu du décor) : dégâts, moral, PA, décompte, extinction.
static func on_turn_start(s: BattleState, u: Unit) -> void:
	if u.statuses.is_empty():
		return
	if has(u, "burn") and in_water(s, u):
		cure(s, u, "burn", "s'éteint dans l'eau")
	for id in StatusesData.ORDER:
		if not has(u, id) or not u.is_live():
			continue
		var sd: Dictionary = StatusesData.STATUSES[id]
		if bool(sd.get("order", false)):
			continue
		var dmg: int = int(sd.get("dmg", 0))
		if dmg > 0:
			u.hp -= dmg
			u.hit_taken = true
			s.say("%s subit %s : %d PV." % [u.unit_name, str(sd["n"]).to_lower(), dmg], "hit")
			fx(s, u, "−%d" % dmg, id)
			if u.hp <= 0:
				s._kill(u, null, "le saignement" if id == "bleed" else ("le poison" if id == "poison" else "ses brûlures"))
				return
		if sd.has("morale"):
			s.morale_test(u, int(sd["morale"]), "est pris par les flammes")
		if int(sd.get("ap", 0)) > 0:
			u.ap = maxi(0, u.ap - int(sd["ap"]))
			s.say("%s est engourdi : -%d PA." % [u.unit_name, int(sd["ap"])], "mor")
		u.statuses[id] = turns(u, id) - 1
		if turns(u, id) <= 0:
			u.statuses.erase(id)
			s.say("%s : %s cesse." % [u.unit_name, str(sd["n"]).to_lower()], "miss")


## `u` vient de faire un pas : l'eau éteint la brûlure.
static func on_move(s: BattleState, u: Unit) -> void:
	if has(u, "burn") and u.is_live() and in_water(s, u):
		cure(s, u, "burn", "s'éteint dans l'eau")


static func in_water(s: BattleState, u: Unit) -> bool:
	if not s.cells.has(u.hex):
		return false
	var t: String = str(s.cells[u.hex]["t"])
	return t == "ford" or t == "river"


## Une unité vient de recevoir un coup qui lui a laissé `hp_lost` PV de dégâts (et la laisse en vie) : état de l'arme, de l'ennemi ou de la capacité.
## Renvoie les ids posés. N'utilise l'aléa que s'il existe une source.
static func on_hit(s: BattleState, a: Unit, d: Unit, ability: String, hp_lost: int) -> Array[String]:
	var out: Array[String] = []
	if not d.is_live():
		return out
	var src: Array = []
	if ability != "" and StatusesData.ABILITY_HIT.has(ability):
		src.append(StatusesData.ABILITY_HIT[ability])
	if hp_lost >= StatusesData.MIN_HP_FOR_STATUS and ability != "riposte":
		if StatusesData.FOE_HIT.has(a.foe_key):
			src.append(StatusesData.FOE_HIT[a.foe_key])
		elif StatusesData.WEAPON_HIT.has(a.weapon):
			src.append(StatusesData.WEAPON_HIT[a.weapon])
	for e in src:
		var row: Array = e
		if immune(d, str(row[0])):
			continue
		if int(row[1]) >= 100 or s.rng.randi_range(1, 100) <= int(row[1]):
			if apply(s, d, str(row[0]), int(row[2])):
				out.append(str(row[0]))
	return out


## Jet d'un outil (huile) : l'état de la capacité sur `d`.
static func on_throw(s: BattleState, d: Unit, ability: String) -> void:
	if StatusesData.ABILITY_HIT.has(ability) and d.is_live():
		var row: Array = StatusesData.ABILITY_HIT[ability]
		if not immune(d, str(row[0])) and (int(row[1]) >= 100 or s.rng.randi_range(1, 100) <= int(row[1])):
			apply(s, d, str(row[0]), int(row[2]))


## Le soin d'un allié (chaman, bandage) arrête aussi le saignement.
static func on_heal(s: BattleState, t: Unit) -> void:
	if has(t, "bleed"):
		cure(s, t, "bleed", "soigné")


## Texte court pour les infobulles : « Saignement (2), Poison (3) ».
static func summary(u: Unit) -> String:
	var parts: PackedStringArray = []
	for id in StatusesData.ORDER:
		if has(u, id):
			var sd: Dictionary = StatusesData.STATUSES[id]
			parts.append(str(sd["n"]) if bool(sd.get("order", false)) else "%s (%d)" % [sd["n"], turns(u, id)])
	return ", ".join(parts)


## Liste des états actifs, dans l'ordre d'affichage.
static func active(u: Unit) -> Array[String]:
	var out: Array[String] = []
	for id in StatusesData.ORDER:
		if has(u, id):
			out.append(id)
	return out
