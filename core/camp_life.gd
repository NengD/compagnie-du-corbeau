class_name CampLife
extends RefCounted
## Camp vivant : veillées (récits, rixes, paris, chansons, disputes), duels et mutineries. Logique pure :
## l'état vit dans `extras["camp_life"]`, l'aléa est injecté, `Game` applique les effets sur l'or, le moral et les vivres.
##
## DUEL : résolu par un petit calcul (et non par `BattleState`, trop lourd pour une querelle de veillée) : au plus
## 8 passes, chacun frappe à tour de rôle avec 25 + compétence de mêlée − défense de mêlée de l'autre (15 à 85 %),
## 6 à 14 points de « sang » par coup ; le premier qui atteint 15 points de blessure perd. Personne ne meurt :
## les PV ne descendent jamais sous 1.
## MUTINERIE : seulement si le moral de la compagnie reste sous 20 pendant 4 jours (averti dès le 2e jour), jamais avant
## le jour 10, jamais à moins de 3 hommes, au plus une par 15 jours ; un mutin part avec son équipement et au plus 10 % de
## l'or (150 couronnes). Le joueur a trois réponses, dont une gratuite.

const KEY: String = "camp_life"
const FIRST_BLOOD: int = 15

const DEFAULTS: Dictionary = {
	"tale": "listen", "brawl": "split", "challenge": "guard", "bet": "forbid", "song": "listen", "food": "search", "toast": "decline", "mutiny": "speak",
}


# --- État ---

static func default_state() -> Dictionary:
	return {"last": 0, "fire": 1, "pending": {}, "low_days": 0, "warned": false, "mut_day": -999, "count": 0, "duels": 0, "mutinies": 0}


## État lu dans `extras` (tolérant : clé absente ou abîmée -> valeurs par défaut) ; réécrit dans `extras`.
static func _is_clean(raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = raw
	for k in ["last", "fire", "low_days", "mut_day", "count", "duels", "mutinies"]:
		if typeof(d.get(k)) != TYPE_INT:
			return false
	if typeof(d.get("warned")) != TYPE_BOOL or typeof(d.get("pending")) != TYPE_DICTIONARY:
		return false
	var p: Dictionary = d["pending"]
	if p.is_empty():
		return true
	if not CampLifeData.EVENTS.has(str(p.get("id", ""))):
		return false
	for k in ["a", "b", "day", "stake", "cost"]:
		if typeof(p.get(k)) != TYPE_INT:
			return false
	return true


## L'objet renvoyé est celui qui est conservé dans `extras` (stable d'un appel à l'autre : on peut le modifier) ;
## une valeur absente, abîmée ou lue dans une sauvegarde JSON est d'abord remise en forme.
static func state(extras: Dictionary) -> Dictionary:
	if _is_clean(extras.get(KEY)):
		return extras[KEY]
	var raw: Variant = extras.get(KEY, {})
	var st: Dictionary = default_state()
	if typeof(raw) == TYPE_DICTIONARY:
		for k in ["last", "fire", "low_days", "mut_day", "count", "duels", "mutinies"]:
			st[k] = int((raw as Dictionary).get(k, st[k]))
		st["warned"] = bool((raw as Dictionary).get("warned", false))
		var p: Variant = (raw as Dictionary).get("pending", {})
		if typeof(p) == TYPE_DICTIONARY and CampLifeData.EVENTS.has(str((p as Dictionary).get("id", ""))):
			var e: Dictionary = p
			st["pending"] = {"id": str(e["id"]), "a": int(e.get("a", -1)), "b": int(e.get("b", -1)), "day": int(e.get("day", 1)),
				"stake": int(e.get("stake", 0)), "cost": int(e.get("cost", 0))}
	extras[KEY] = st
	return st


static func rng_for(day: int, salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = day * 40503 + salt * 7919 + 1013
	return r


static func pending(extras: Dictionary) -> Dictionary:
	return (state(extras)["pending"] as Dictionary).duplicate()


static func has_pending(extras: Dictionary) -> bool:
	return not (state(extras)["pending"] as Dictionary).is_empty()


## Nombre d'événements de veillée déjà vécus (succès, statistiques).
static func events_seen(extras: Dictionary) -> int:
	return int(state(extras)["count"])


# --- Tirage ---

static func _by_id(roster: Array, id: int) -> Unit:
	for u in roster:
		if (u as Unit).id == id:
			return u
	return null


static func _pairs(roster: Array, pred: Callable) -> Array:
	var out: Array = []
	for i in roster.size():
		for j in range(i + 1, roster.size()):
			if pred.call(roster[i], roster[j]):
				out.append([roster[i], roster[j]])
	return out


static func _event(id: String, a: Unit, b: Unit, day: int) -> Dictionary:
	return {"id": id, "a": a.id if a != null else -1, "b": b.id if b != null else -1, "day": day, "stake": 0, "cost": 0}


## Un événement de veillée adapté à la compagnie, ou {} (moins de deux hommes). N'écrit rien.
static func pick(roster: Array, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	if roster.size() < 2:
		return {}
	var day: int = int(ctx.get("day", 1))
	var cands: Array = []  ## [poids, événement]
	var duel_pairs: Array = _pairs(roster, func(a: Unit, b: Unit) -> bool: return Bonds.get_bond(a, b.id) <= CampLifeData.DUEL_BOND)
	if not duel_pairs.is_empty():
		var p: Array = duel_pairs[rng.randi() % duel_pairs.size()]
		cands.append([5, _event("challenge", p[0], p[1], day)])
	var rival_pairs: Array = _pairs(roster, func(a: Unit, b: Unit) -> bool: return Bonds.get_bond(a, b.id) <= Bonds.RIVAL and Bonds.get_bond(a, b.id) > CampLifeData.DUEL_BOND)
	if not rival_pairs.is_empty():
		var p2: Array = rival_pairs[rng.randi() % rival_pairs.size()]
		cands.append([4, _event("brawl", p2[0], p2[1], day)])
	var friend_pairs: Array = _pairs(roster, func(a: Unit, b: Unit) -> bool: return Bonds.get_bond(a, b.id) >= Bonds.FRIEND)
	if not friend_pairs.is_empty() and int(ctx.get("gold", 0)) >= 15:
		var p3: Array = friend_pairs[rng.randi() % friend_pairs.size()]
		cands.append([1, _event("toast", p3[0], p3[1], day)])
	var a: Unit = roster[rng.randi() % roster.size()]
	var b: Unit = roster[(roster.find(a) + 1 + rng.randi() % (roster.size() - 1)) % roster.size()]
	var storytellers: Array = roster.filter(func(u: Unit) -> bool: return u.backstory != "")
	if not storytellers.is_empty():
		cands.append([3, _event("tale", storytellers[rng.randi() % storytellers.size()], null, day)])
	if int(ctx.get("gold", 0)) >= 40:
		var bet: Dictionary = _event("bet", a, b, day)
		bet["stake"] = [15, 25, 40][rng.randi() % 3]
		cands.append([2, bet])
	cands.append([2, _event("song", a, null, day)])
	if int(ctx.get("provisions", 0)) >= 3:
		cands.append([2, _event("food", a, b, day)])
	var total: int = 0
	for c in cands:
		total += int(c[0])
	var r: int = rng.randi() % total
	for c in cands:
		r -= int(c[0])
		if r < 0:
			return c[1]
	return cands[0][1]


## Tire et enregistre une veillée avec la probabilité `chance` (au plus une à la fois, écart minimal entre deux).
## `force` : tire sans jet de dé (tests). Renvoie l'événement posé ou {}.
static func roll(extras: Dictionary, roster: Array, rng: RandomNumberGenerator, ctx: Dictionary, chance: float, force: bool = false) -> Dictionary:
	var st: Dictionary = state(extras)
	var day: int = int(ctx.get("day", 1))
	st["fire"] = day
	if not (st["pending"] as Dictionary).is_empty() or day - int(st["last"]) < CampLifeData.MIN_GAP and not force:
		return {}
	if not force and rng.randf() >= chance:
		return {}
	var ev: Dictionary = pick(roster, rng, ctx)
	if ev.is_empty():
		return {}
	st["pending"] = ev
	st["last"] = day
	return ev


## Suivi quotidien : moral bas prolongé (avertissement, mutinerie) et veillée de route. Renvoie les lignes de nouvelles.
## ctx : day, morale, gold, provisions, road (bool : en route), random (bool : événements imprévus permis).
static func daily(extras: Dictionary, roster: Array, rng: RandomNumberGenerator, ctx: Dictionary) -> Array:
	var st: Dictionary = state(extras)
	var lines: Array = []
	var day: int = int(ctx.get("day", 1))
	var morale: float = float(ctx.get("morale", 50.0))
	if morale < CampLifeData.MUTINY_MORALE:
		st["low_days"] = int(st["low_days"]) + 1
	elif morale >= CampLifeData.MUTINY_MORALE + 10.0:
		st["low_days"] = 0
		st["warned"] = false
	if int(st["low_days"]) >= CampLifeData.MUTINY_WARN_DAYS and not bool(st["warned"]) and roster.size() >= CampLifeData.MUTINY_MIN_MEN:
		st["warned"] = true
		lines.append("Les hommes murmurent : le moral est au plus bas. Une prime, du repos ou une victoire apaiserait les esprits.")
	var pend: Dictionary = st["pending"]
	if int(st["low_days"]) >= CampLifeData.MUTINY_DAYS and pend.is_empty() and day >= CampLifeData.MUTINY_MIN_DAY \
			and day - int(st["mut_day"]) >= CampLifeData.MUTINY_COOLDOWN and roster.size() >= CampLifeData.MUTINY_MIN_MEN:
		var leader: Unit = mutineer(roster)
		var ev: Dictionary = _event("mutiny", leader, null, day)
		ev["cost"] = mutiny_cost(roster.size(), int(ctx.get("gold", 0)))
		st["pending"] = ev
		st["mut_day"] = day
		st["low_days"] = 0
		st["warned"] = false
		lines.append("%s menace de quitter la compagnie : les hommes grondent." % leader.unit_name)
	elif bool(ctx.get("road", false)) and bool(ctx.get("random", true)) and pend.is_empty() and day - int(st["fire"]) >= CampLifeData.ROAD_DAYS:
		var ev2: Dictionary = roll(extras, roster, rng, ctx, CampLifeData.ROAD_CHANCE)
		if not ev2.is_empty():
			lines.append("Au bivouac, il se passe quelque chose autour du feu.")
		else:
			st["fire"] = day - CampLifeData.ROAD_DAYS + 1  ## prochaine chance dans un jour
	return lines


## Le mutin : l'homme le moins lié aux autres (somme des liens la plus basse), puis le moins déterminé.
static func mutineer(roster: Array) -> Unit:
	var best: Unit = null
	var best_score: int = 1 << 30
	for u in roster:
		var s: int = 0
		for v in (u as Unit).bonds.values():
			s += int(v)
		s = s * 100 + (u as Unit).resolve
		if s < best_score:
			best_score = s
			best = u
	return best


static func mutiny_cost(men: int, gold: int) -> int:
	return clampi(men * 15, 30, 250)


## Choix à prendre d'office si l'événement reste sans réponse trop longtemps ; "" s'il n'y a rien à trancher.
static func expired_choice(extras: Dictionary, day: int) -> String:
	var ev: Dictionary = state(extras)["pending"]
	if ev.is_empty() or day - int(ev["day"]) < CampLifeData.EXPIRE_DAYS:
		return ""
	return str(DEFAULTS.get(str(ev["id"]), ""))


# --- Description et issues ---

static func _fill(text: String, ev: Dictionary, roster: Array) -> String:
	var a: Unit = _by_id(roster, int(ev.get("a", -1)))
	var b: Unit = _by_id(roster, int(ev.get("b", -1)))
	var stake: int = int(ev.get("stake", 0))
	return text.replace("{a}", a.unit_name if a != null else "un homme").replace("{b}", b.unit_name if b != null else "un autre").replace("{story}", a.backstory if a != null else "") \
		.replace("{stake}", str(stake)).replace("{cut}", str(maxi(2, stake / 5))).replace("{cost}", str(int(ev.get("cost", 0))))


## Fenêtre à choix : {"title", "text", "choices": [{"id", "label", "hint", "disabled"}]}. Vide si les protagonistes sont partis.
static func describe(ev: Dictionary, roster: Array, ctx: Dictionary) -> Dictionary:
	if ev.is_empty() or not CampLifeData.EVENTS.has(str(ev["id"])):
		return {}
	var def: Dictionary = CampLifeData.EVENTS[str(ev["id"])]
	var out_choices: Array = []
	var gold: int = int(ctx.get("gold", 0))
	for c in def["choices"]:
		var id: String = str(c["id"])
		var blocked: bool = false
		match str(ev["id"]) + ":" + id:
			"tale:round":
				blocked = gold < 20
			"bet:in":
				blocked = gold < int(ev.get("stake", 0))
			"toast:pool":
				blocked = gold < 15
			"toast:fallen":
				blocked = int(ctx.get("fallen", 0)) <= 0
			"challenge:pay":
				blocked = gold < 40
			"food:share":
				blocked = int(ctx.get("provisions", 0)) < 3
			"mutiny:pay":
				blocked = gold < int(ev.get("cost", 0))
		out_choices.append({"id": id, "label": _fill(str(c["label"]), ev, roster), "hint": _fill(str(c["hint"]), ev, roster), "disabled": blocked})
	return {"title": str(def["title"]), "text": _fill(str(def["text"]), ev, roster), "choices": out_choices}


static func _bond_all(a: Unit, roster: Array, d: int) -> void:
	for x in roster:
		Bonds.add(a, x, d)


static func _gift_trait(u: Unit, rng: RandomNumberGenerator) -> String:
	var ok: Array = []
	for k in Data.TRAITS:
		if Backstory._eligible_trait(u, str(k)):
			ok.append(str(k))
	ok.sort()
	if ok.is_empty():
		return ""
	var k2: String = "sociable" if ok.has("sociable") and rng.randf() < 0.5 else str(ok[rng.randi() % ok.size()])
	u.traits.append(k2)
	return k2


## Duel « jusqu'au premier sang » (voir l'en-tête). Applique les PV perdus ; renvoie {winner, loser, rounds, dmg_a, dmg_b, lines}.
static func duel(a: Unit, b: Unit, rng: RandomNumberGenerator) -> Dictionary:
	var da: int = 0  ## sang perdu par a
	var db: int = 0
	var rounds: int = 0
	while rounds < 8 and da < FIRST_BLOOD and db < FIRST_BLOOD:
		rounds += 1
		if rng.randi_range(1, 100) <= clampi(25 + a.eff("melee_skill") - b.eff("melee_def"), 15, 85):
			db += rng.randi_range(6, 14)
		if rng.randi_range(1, 100) <= clampi(25 + b.eff("melee_skill") - a.eff("melee_def"), 15, 85):
			da += rng.randi_range(6, 14)
	var a_wins: bool = db > da or (db == da and rng.randi() % 2 == 0)
	var win: Unit = a if a_wins else b
	var lose: Unit = b if a_wins else a
	a.hp = maxi(1, a.hp - da)
	b.hp = maxi(1, b.hp - db)
	return {"winner": win, "loser": lose, "rounds": rounds, "dmg_a": da, "dmg_b": db,
		"lines": ["%s l'emporte sur %s en %d passes (%d et %d points de sang perdus)." % [win.unit_name, lose.unit_name, rounds, da if a_wins else db, db if a_wins else da]]}


static func _do_duel(st: Dictionary, a: Unit, b: Unit, rng: RandomNumberGenerator, res: Dictionary) -> void:
	var d: Dictionary = duel(a, b, rng)
	res["lines"].append_array(d["lines"])
	Bonds.set_bond(a, b, 3)  ## l'affaire est réglée : un respect distant
	res["morale"] = float(res["morale"]) + 2.0
	st["duels"] = int(st["duels"]) + 1
	res["chron"] = "Duel au camp : %s l'emporte sur %s." % [(d["winner"] as Unit).unit_name, (d["loser"] as Unit).unit_name]


## Applique le choix `choice` à l'événement en attente et le retire. `roster` est modifié seulement par `res["leave"]`
## (ids des hommes qui partent : à retirer par l'appelant) ; liens, PV et traits sont modifiés ici.
## Renvoie {"ok", "lines", "gold", "morale", "provisions", "leave", "chron"} (gold négatif = dépense).
static func resolve(extras: Dictionary, choice: String, roster: Array, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	var st: Dictionary = state(extras)
	var ev: Dictionary = st["pending"]
	var res: Dictionary = {"ok": false, "lines": [], "gold": 0, "morale": 0.0, "provisions": 0, "leave": [], "chron": ""}
	if ev.is_empty():
		return res
	var info: Dictionary = describe(ev, roster, ctx)
	var allowed: bool = false
	for c in info.get("choices", []):
		if str(c["id"]) == choice and not bool(c["disabled"]):
			allowed = true
	if not allowed:
		return res
	var a: Unit = _by_id(roster, int(ev.get("a", -1)))
	var b: Unit = _by_id(roster, int(ev.get("b", -1)))
	res["ok"] = true
	var lines: Array = res["lines"]
	var id: String = str(ev["id"])
	var an: String = a.unit_name if a != null else "Un homme"
	var bn: String = b.unit_name if b != null else "un autre"
	if (a == null and id != "song") or (b == null and ["brawl", "challenge", "bet", "food", "toast"].has(id)):
		lines.append("L'affaire s'éteint d'elle-même : l'un des deux hommes n'est plus là.")  ## protagoniste parti : rien à trancher
	else:
		match id + ":" + choice:
			"tale:listen":
				res["morale"] = 2.0
				_bond_all(a, roster, 1)
				lines.append("La compagnie écoute %s jusqu'au bout. On le regarde autrement ensuite." % an)
			"tale:round":
				res["gold"] = -20
				res["morale"] = 4.0
				_bond_all(a, roster, 2)
				lines.append("Une tournée pour %s, et la veillée dure tard (−20 couronnes)." % an)
				if rng.randf() < 0.2:
					var t: String = _gift_trait(a, rng)
					if t != "":
						lines.append("%s en sort grandi : nouveau trait, %s." % [an, str(Data.TRAITS[t]["n"]).to_lower()])
			"tale:mock":
				res["morale"] = 1.0
				Bonds.add(a, a, 0)
				_bond_all(a, roster, -1)
				lines.append("On rit, %s un peu moins que les autres." % an)
			"brawl:split":
				res["morale"] = -1.0
				Bonds.add(a, b, 2)
				lines.append("Vous les séparez. %s et %s se jettent un dernier regard noir." % [an, bn])
			"brawl:let":
				a.hp = maxi(1, a.hp - rng.randi_range(4, 10))
				b.hp = maxi(1, b.hp - rng.randi_range(4, 10))
				if rng.randf() < 0.5:
					Bonds.add(a, b, -3)
					lines.append("%s et %s s'empoignent jusqu'à épuisement ; la rancune n'en est que plus vive." % [an, bn])
				else:
					Bonds.add(a, b, 4)
					lines.append("%s et %s s'expliquent à coups de poing, puis se serrent la main." % [an, bn])
			"brawl:duel", "challenge:duel":
				_do_duel(st, a, b, rng, res)
			"challenge:guard":
				if rng.randf() < 0.65:
					Bonds.add(a, b, 5)
					lines.append("Une nuit de garde côte à côte : %s et %s finissent par parler." % [an, bn])
				else:
					Bonds.add(a, b, -2)
					res["morale"] = -1.0
					lines.append("La garde tourne mal : %s et %s ne s'adressent pas un mot." % [an, bn])
			"challenge:pay":
				res["gold"] = -40
				Bonds.add(a, b, 6)
				lines.append("Une bourse pour sceller la paix : %s et %s topent là (−40 couronnes)." % [an, bn])
			"bet:in":
				var stake: int = int(ev.get("stake", 0))
				res["morale"] = 1.0
				if rng.randf() < 0.45:
					res["gold"] = stake
					lines.append("Le pari tourne en votre faveur : +%d couronnes." % stake)
				else:
					res["gold"] = -stake
					lines.append("Le pari est perdu : −%d couronnes." % stake)
				Bonds.add(a, b, 1)
			"bet:hold":
				var cut: int = maxi(2, int(ev.get("stake", 0)) / 5)
				res["gold"] = cut
				Bonds.add(a, b, 0)
				_bond_pair_minus(a, b, 1)
				lines.append("Vous tenez la cagnotte et prélevez votre part : +%d couronnes." % cut)
			"bet:forbid":
				res["morale"] = -1.0
				lines.append("Pari interdit. %s et %s ravalent leur défi." % [an, bn])
			"song:join":
				res["morale"] = 5.0
				Bonds.add(a, a, 0)
				_bond_all(a, roster, 1)
				lines.append("Vous reprenez le refrain avec %s. On en parlera longtemps." % an)
			"song:listen":
				res["morale"] = 3.0
				lines.append("La chanson de %s monte dans la nuit, et les visages se détendent." % an)
			"song:quiet":
				res["morale"] = -2.0
				_bond_all(a, roster, -1)
				lines.append("Silence. %s se tait, vexé, et la veillée s'éteint." % an)
			"food:punish":
				res["provisions"] = 2
				res["morale"] = -1.0
				Bonds.add(a, b, -4)
				lines.append("%s rend ce qu'il avait gardé (+2 rations) ; il n'oubliera pas l'accusation." % bn)
			"food:share":
				res["provisions"] = -3
				res["morale"] = 4.0
				Bonds.add(a, b, 1)
				lines.append("Double ration ce soir (−3 rations) : les querelles se perdent dans la soupe.")
			"food:search":
				if rng.randf() < 0.5:
					res["provisions"] = 3
					res["morale"] = -1.0
					Bonds.add(a, b, -3)
					lines.append("On trouve des rations dans le sac de %s (+3). Il baisse les yeux." % bn)
				else:
					res["morale"] = -1.0
					Bonds.add(a, b, -3)
					lines.append("Rien dans le sac de %s : c'est %s qui perd la face." % [bn, an])
					_bond_all(a, roster, -1)
			"toast:pool":
				res["gold"] = -15
				res["morale"] = 4.0
				Bonds.add(a, b, 1)
				_bond_all(a, roster, 1)
				lines.append("Vous mettez une pièce de plus (−15 couronnes) : on trinque à la compagnie.")
			"toast:fallen":
				res["morale"] = 3.0
				_bond_all(a, roster, 1)
				lines.append("On boit en silence à ceux qui ne sont plus là. Le nom des tombés passe de bouche en bouche.")
			"toast:decline":
				lines.append("%s et %s trinquent entre eux et ne vous en veulent pas." % [an, bn])
			"mutiny:pay":
				var cost: int = int(ev.get("cost", 0))
				res["gold"] = -cost
				res["morale"] = 12.0
				lines.append("Une prime pour chacun (−%d couronnes) : les murmures cessent. Pour l'instant." % cost)
			"mutiny:speak":
				if rng.randf() < 0.5:
					res["morale"] = 8.0
					_bond_all(a, roster, 1)
					lines.append("Vous parlez de la route faite, des primes à venir. %s baisse la tête et reste." % an)
				else:
					_leave(a, roster, int(ctx.get("gold", 0)), res)
					lines.append("Vos mots tombent à plat : %s s'en va avec sa part." % an)
			"mutiny:let":
				_leave(a, roster, int(ctx.get("gold", 0)), res)
				res["morale"] = float(res["morale"]) + 4.0
				lines.append("Vous laissez partir %s, sans haine. Les autres respirent." % an)
	if not (res["leave"] as Array).is_empty():
		st["mutinies"] = int(st["mutinies"]) + 1
		res["chron"] = "Mutinerie : %s quitte la compagnie avec son équipement et %d couronnes." % [an, -int(res["gold"])]
	st["pending"] = {}
	st["count"] = int(st["count"]) + 1
	return res


static func _bond_pair_minus(a: Unit, b: Unit, d: int) -> void:
	if a != null and b != null:
		Bonds.add(a, b, -d)


## Le mutin part : son équipement l'accompagne (rien n'est repris à la réserve) et il emporte au plus 10 % de l'or.
static func _leave(a: Unit, roster: Array, gold: int, res: Dictionary) -> void:
	if a == null or roster.size() < CampLifeData.MUTINY_MIN_MEN:
		return
	(res["leave"] as Array).append(a.id)
	res["gold"] = -mini(CampLifeData.MUTINY_GOLD_CAP, int(float(maxi(0, gold)) * CampLifeData.MUTINY_GOLD_SHARE))
