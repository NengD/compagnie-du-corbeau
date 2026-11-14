class_name Scenarios
extends RefCounted
## Scénarios et défis (logique pure, sans scène). Tables : core/scenarios_data.gd. État : Game.extras["scenario"] =
## {"key": id, "result": "" | "won" | "lost", "seen": bool}. Partie libre = pas d'entrée ; clé absente = comportement inchangé.
## Le jeu appelle : init_extras (nouvelle partie), start_men + apply_start (compagnie de départ), adjust_contracts (marchés),
## evaluate (à chaque jour écoulé / fin de bataille). Les écrans lisent progress() / summary().

const FREE := ""


static func keys() -> Array:
	return ScenariosData.ORDER.duplicate()


static func has(key: String) -> bool:
	return ScenariosData.SCENARIOS.has(key)


static func data(key: String) -> Dictionary:
	return ScenariosData.SCENARIOS.get(key, {})


static func label(key: String) -> String:
	return "Partie libre" if key == FREE else str(data(key).get("n", key))


## Prépare `extras` d'une nouvelle partie. `opts` : {"scenario": clé, "ironman": bool}.
static func init_extras(extras: Dictionary, opts: Dictionary) -> void:
	var key: String = str(opts.get("scenario", FREE))
	if has(key):
		extras["scenario"] = {"key": key, "result": "", "seen": false}
	if bool(opts.get("ironman", false)):
		Ironman.init_extras(extras)


static func active(extras: Dictionary) -> String:
	var s: Variant = extras.get("scenario", null)
	if typeof(s) != TYPE_DICTIONARY:
		return FREE
	var key: String = str((s as Dictionary).get("key", ""))
	return key if has(key) else FREE


## Origines des hommes de départ (la compagnie classique en partie libre).
static func start_men(extras: Dictionary) -> Array:
	var key: String = active(extras)
	if key == FREE:
		return ["milicien", "bucheron", "braconnier", "fermier", "deserteur"]
	return (data(key)["men"] as Array).duplicate()


## Or de départ : celui du scénario, ou `fallback` (difficulté) s'il n'en fixe pas.
static func start_gold(extras: Dictionary, fallback: int) -> int:
	var key: String = active(extras)
	if key == FREE:
		return fallback
	var g: int = int(data(key)["gold"])
	return fallback if g < 0 else g


## Applique le départ du scénario à une compagnie fraîchement créée : solde, tenue, vivres, moral, or, nouvelle d'ouverture.
## `g` est l'autoload Game (accès dynamique : core/ ne peut pas le typer).
static func apply_start(g: Object, extras: Dictionary) -> void:
	var key: String = active(extras)
	if key == FREE:
		return
	var d: Dictionary = data(key)
	g.set("gold", start_gold(extras, int(g.get("gold"))))
	var roster: Array = g.get("roster")
	for u in roster:
		(u as Unit).wage = maxi(1, int(round(float((u as Unit).wage) * float(d["wage_mult"]))))
		if str(d["gear"]) == "noble":
			dress_noble(u as Unit)
	g.set("provisions", int(g.get("provisions")) + int(d["provisions"]))
	g.set("company_morale", clampf(float(g.get("company_morale")) + float(d["morale"]), 0.0, 100.0))
	var news: Array = g.get("news")
	news.clear()
	news.append(str(d["intro"]))
	news.append("Scénario « %s » : %s en %d jours." % [d["n"], goal_text(key), int(d["days"])])


## Casque à nasal, haubert de mailles et bouclier (si l'arme est à une main), armure pleine.
static func dress_noble(u: Unit) -> void:
	u.head = "casque"
	u.body = "mailles"
	if bool(Data.WPN[u.weapon]["h1"]):
		u.shield = true
	u.arm_h = u.head_armor_max()
	u.arm_b = u.body_armor_max()


static func goal_text(key: String) -> String:
	var g: Dictionary = data(key).get("goal", {})
	return "%s : %d" % [str(g.get("label", "Objectif")), int(g.get("target", 0))]


## Chasseurs de primes : toute offre devient une chasse au chef (sauf les contrats d'arc), prime majorée.
static func adjust_contracts(extras: Dictionary, contracts: Array) -> void:
	var key: String = active(extras)
	if key == FREE or not bool(data(key)["hunt_only"]):
		return
	var mult: float = float(data(key)["hunt_pay"])
	for c in contracts:
		if c.has("arc"):
			continue
		if str(c.get("type_contract", "kill")) == "hunt":
			c["pay"] = _round5(float(c["pay"]) * mult)
			continue
		var type: String = str(c.get("type", "b"))
		if not Data.FACTION_LEADER.has(type):
			continue
		var r := RandomNumberGenerator.new()
		r.seed = int(c.get("pay", 0)) * 31 + int(c.get("d", 1)) * 7 + str(c.get("title", "")).hash() % 9973
		var leader: String = str(Data.FACTION_LEADER[type])
		var d: int = int(c.get("d", 1))
		c["type_contract"] = "hunt"
		c["title"] = "Chasse au chef : " + str(Data.FOE[leader]["n"])
		c["desc"] = str(Contracts.pick(ContractTexts.HUNT, r)) % str(Data.FOE[leader]["n"]).to_lower()
		c["foes"] = Contracts.hunt_foes(type, d)
		c["pay"] = _round5(float(c["pay"]) * 1.4 * mult)
		for k in ["dest_id", "ambush_at", "ambush_done"]:
			c.erase(k)
		c["battle_type"] = Contracts.battle_type_for(c)


static func _round5(v: float) -> int:
	return int(round(v / 5.0)) * 5


## Valeur actuelle de l'objectif. `ctx` : {day, renown, gold, stats}.
static func current(key: String, ctx: Dictionary) -> int:
	var stat: String = str(data(key)["goal"]["stat"])
	match stat:
		"renown":
			return int(ctx.get("renown", 0))
		"gold":
			return int(ctx.get("gold", 0))
	return int((ctx.get("stats", {}) as Dictionary).get(stat, 0))


static func days_left(key: String, ctx: Dictionary) -> int:
	return int(data(key)["days"]) - (int(ctx.get("day", 1)) - 1)


## {key, label, cur, target, days_left, done, text} ; {} en partie libre.
static func progress(extras: Dictionary, ctx: Dictionary) -> Dictionary:
	var key: String = active(extras)
	if key == FREE:
		return {}
	var g: Dictionary = data(key)["goal"]
	var cur: int = current(key, ctx)
	var left: int = days_left(key, ctx)
	var res: String = result(extras)
	var txt: String = "%s : %d/%d · %d j restants" % [g["label"], mini(cur, int(g["target"])), int(g["target"]), maxi(0, left)]
	if res == "won":
		txt = "%s — objectif atteint" % data(key)["n"]
	elif res == "lost":
		txt = "%s — échec" % data(key)["n"]
	return {"key": key, "label": str(g["label"]), "cur": cur, "target": int(g["target"]), "days_left": left, "done": cur >= int(g["target"]), "text": txt}


## Court texte de suivi (en-tête, nouvelles) ; "" en partie libre.
static func summary(extras: Dictionary, ctx: Dictionary) -> String:
	var p: Dictionary = progress(extras, ctx)
	if p.is_empty():
		return ""
	return "%s — %s" % [label(str(p["key"])), str(p["text"])]


static func result(extras: Dictionary) -> String:
	var s: Variant = extras.get("scenario", null)
	return str((s as Dictionary).get("result", "")) if typeof(s) == TYPE_DICTIONARY else ""


## Évalue victoire / défaite ; renvoie le nouveau résultat s'il vient de changer, sinon "". Victoire prioritaire (même le dernier jour).
static func evaluate(extras: Dictionary, ctx: Dictionary) -> String:
	var key: String = active(extras)
	if key == FREE or result(extras) != "" or bool(ctx.get("over", false)):
		return ""
	var out: String = ""
	if current(key, ctx) >= int(data(key)["goal"]["target"]):
		out = "won"
	elif days_left(key, ctx) <= 0:
		out = "lost"
	if out != "":
		(extras["scenario"] as Dictionary)["result"] = out
	return out


## Un résultat est acquis mais l'écran de fin n'a pas encore été vu.
static func end_pending(extras: Dictionary) -> bool:
	var s: Variant = extras.get("scenario", null)
	return typeof(s) == TYPE_DICTIONARY and active(extras) != FREE and str((s as Dictionary).get("result", "")) != "" and not bool((s as Dictionary).get("seen", false))


static func acknowledge(extras: Dictionary) -> void:
	if extras.get("scenario", null) is Dictionary:
		(extras["scenario"] as Dictionary)["seen"] = true


## Texte de l'écran de fin (victoire ou défaite).
static func end_text(extras: Dictionary) -> String:
	var key: String = active(extras)
	if key == FREE:
		return ""
	return str(data(key)["win" if result(extras) == "won" else "lose"])
