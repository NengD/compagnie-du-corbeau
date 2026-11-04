class_name Difficulty
extends RefCounted
## Niveaux de difficulté : lecture pure des coefficients de Data.DIFFICULTY. « normal » (ou une clé inconnue) est strictement neutre :
## chaque fonction rend alors la valeur d'origine, sans arrondi différent.


static func clean(key: Variant) -> String:
	var k: String = str(key)
	return k if Data.DIFFICULTY.has(k) else Data.DIFFICULTY_DEFAULT


static func keys() -> Array:
	var out: Array = Data.DIFFICULTY.keys()
	out.sort_custom(func(a: String, b: String) -> bool: return int(Data.DIFFICULTY[a]["order"]) < int(Data.DIFFICULTY[b]["order"]))
	return out


static func label(key: String) -> String:
	return str(Data.DIFFICULTY[clean(key)]["name"])


static func desc(key: String) -> String:
	return str(Data.DIFFICULTY[clean(key)]["desc"])


static func coef(key: String, what: String) -> float:
	return float(Data.DIFFICULTY[clean(key)][what])


static func start_gold(key: String) -> int:
	return int(Data.DIFFICULTY[clean(key)]["gold"])


## PV max et compétences d'un ennemi à sa création.
static func foe_stat(key: String, v: int) -> int:
	var m: float = coef(key, "foe_stats")
	return v if m == 1.0 else maxi(1, int(round(float(v) * m)))


## Liste d'ennemis d'un contrat ajustée : facile −1 (danger ≥ 2), difficile +1 (copie du plus fréquent non-chef).
static func adjust_foes(foes: Array, danger: int, key: String) -> Array:
	var delta: int = int(Data.DIFFICULTY[clean(key)]["foe_count"])
	if delta == 0 or danger < 2 or foes.is_empty():
		return foes
	var out: Array = foes.duplicate()
	if delta < 0:
		for i in range(out.size() - 1, -1, -1):  # retire le dernier combattant qui n'est pas un chef
			if out.size() > 1 and not bool(Data.FOE[str(out[i])]["leader"]):
				out.remove_at(i)
				break
		return out
	var best: String = ""
	var best_n: int = 0
	for k in out:
		if bool(Data.FOE[str(k)]["leader"]):
			continue
		var n: int = out.count(k)
		if n > best_n:
			best = str(k)
			best_n = n
	if best != "":
		out.append(best)
	return out


static func pay(key: String, v: int) -> int:
	var m: float = coef(key, "pay")
	return v if m == 1.0 else int(round(float(v) * m / 5.0)) * 5


static func price(key: String, v: int) -> int:
	var m: float = coef(key, "price")
	return v if m == 1.0 else int(round(float(v) * m))


static func xp(key: String, v: int) -> int:
	var m: float = coef(key, "xp")
	return v if m == 1.0 else int(round(float(v) * m))


## Pourcentage de chance de blessure (0-100) une fois les autres modificateurs appliqués.
static func wound_chance(key: String, pct: int) -> int:
	var m: float = coef(key, "wound")
	return pct if m == 1.0 else clampi(int(round(float(pct) * m)), 0, 100)


## Rations consommées par jour de route pour `men` hommes.
static func food_need(key: String, men: int) -> int:
	var m: float = coef(key, "food")
	return men if m == 1.0 else maxi(1, int(round(float(men) * m)))


## Variation de moral de compagnie : seules les pertes sont modulées.
static func morale_delta(key: String, n: float) -> float:
	return n if n >= 0.0 else n * coef(key, "morale_loss")


## Chance de récupérer une pièce de butin (multiplicateur, 1.0 = inchangé).
static func loot_mult(key: String) -> float:
	return coef(key, "loot")


## Menace de la crise finale ajoutée par jour.
static func threat_mult(key: String) -> float:
	return coef(key, "threat")


## Phrases courtes du résumé (cartes du panneau de difficulté), tirées des coefficients.
static func summary_lines(key: String) -> Array:
	var d: Dictionary = Data.DIFFICULTY[clean(key)]
	var out: Array = ["Or de départ : %d couronnes" % int(d["gold"])]
	out.append("Ennemis : %s, %s" % [_pct(float(d["foe_stats"]), "PV et compétences"), "effectif %+d (danger 2+)" % int(d["foe_count"])])
	out.append("Primes %s · achats %s" % [_pct(float(d["pay"]), ""), _pct(float(d["price"]), "")])
	out.append("Expérience %s · butin %s" % [_pct(float(d["xp"]), ""), _pct(float(d["loot"]), "")])
	out.append("Blessures %s · vivres %s · menace %s" % [_pct(float(d["wound"]), ""), _pct(float(d["food"]), ""), _pct(float(d["threat"]), "")])
	return out


static func _pct(m: float, what: String) -> String:
	var p: int = int(round((m - 1.0) * 100.0))
	var s: String = "normaux" if p == 0 else "%+d %%" % p
	return ("%s %s" % [what, s]).strip_edges()
