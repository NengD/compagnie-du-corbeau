class_name Perks
extends RefCounted
## Arbre de talents (7 rangs x 4 colonnes) : règles d'accès, dépense des points, bonus lus par le combat.
## Données : `Data.PERKS`. Fonctions pures, sans scène.


static func tier_of(key: String) -> int:
	return int(Data.PERKS[key]["tier"])


## Talents déjà pris requis avant d'accéder à ce rang (rang N : N-1 talents).
static func needed_before(key: String) -> int:
	return tier_of(key) - 1


## Talents d'un rang, triés par colonne.
static func in_tier(tier: int) -> Array[String]:
	var out: Array[String] = []
	for k in Data.PERKS:
		if tier_of(str(k)) == tier:
			out.append(str(k))
	out.sort_custom(func(a: String, b: String) -> bool: return int(Data.PERKS[a]["col"]) < int(Data.PERKS[b]["col"]))
	return out


## Raison pour laquelle `u` ne peut pas prendre `key` (en comptant `extra` : talents choisis mais pas encore confirmés,
## et `points` : points disponibles). Chaîne vide = possible.
static func why_not(u: Unit, key: String, extra: Array = [], points: int = -1) -> String:
	if not Data.PERKS.has(key):
		return "Talent inconnu."
	if u.has_perk(key) or extra.has(key):
		return "Déjà pris."
	var have: int = u.perks.size() + extra.size()
	var left: int = (u.perk_points if points < 0 else points) - extra.size()
	if left <= 0:
		return "Aucun point de talent disponible."
	var need: int = needed_before(key)
	if have < need:
		return "Il faut %d talent%s avant de choisir ce rang." % [need, "s" if need > 1 else ""]
	var req: String = str(Data.PERKS[key].get("req", ""))
	if req != "" and not (u.has_perk(req) or extra.has(req)):
		return "Il faut d'abord : %s." % str(Data.PERKS[req]["n"])
	return ""


static func can_take(u: Unit, key: String) -> bool:
	return why_not(u, key) == ""


## Prend un talent en dépensant un point. Renvoie false si impossible.
static func take(u: Unit, key: String) -> bool:
	if not can_take(u, key):
		return false
	u.perks.append(key)
	u.perk_points -= 1
	return true


## Prend plusieurs talents d'un coup, dans l'ordre ; tout ou rien.
static func take_all(u: Unit, keys: Array) -> bool:
	var done: Array = []
	for k in keys:
		if why_not(u, str(k), done) != "":
			return false
		done.append(str(k))
	for k in done:
		take(u, str(k))
	return true


## Rend tous les talents sous forme de points.
static func refund_all(u: Unit) -> void:
	u.perk_points += u.perks.size()
	u.perks.clear()


static func reset_cost(u: Unit) -> int:
	return Data.PERK_RESET_BASE + Data.PERK_RESET_PER_LEVEL * u.level


## Points acquis en tout (niveaux 2 à 11) : sert à la migration des anciennes sauvegardes.
static func points_for_level(level: int) -> int:
	return maxi(0, mini(level, 11) - 1)


# --- Bonus lus par le combat (Unit.eff() reste la source des attributs) ---

## Valeur cumulée d'un champ de spécialisation d'arme (`hit`, `ign`, `ammo` : somme ; `dmg`, `arm` : produit) pour l'arme portée.
static func weapon_field(u: Unit, field: String) -> float:
	var mult: bool = field == "dmg" or field == "arm"
	var v: float = 1.0 if mult else 0.0
	for p in u.perks:
		var wp: Dictionary = Data.PERKS.get(p, {}).get("wp", {})
		if wp.is_empty() or not (wp["weapons"] as Array).has(u.weapon) or not wp.has(field):
			continue
		if mult:
			v *= float(wp[field])
		else:
			v += float(wp[field])
	return v


## Bonus de moral reçu de l'aura (Chef-né) d'un allié adjacent : +10 au plus.
static func morale_aura(u: Unit, units: Array) -> int:
	for x in units:
		var xu: Unit = x
		if xu != u and xu.is_live() and xu.side == u.side and xu.has_perk("chef_ne") and Hex.distance(xu.hex, u.hex) == 1:
			return 10
	return 0


## Réduction de poids d'équipement (Port d'armure : 30 %).
static func weight_cut(u: Unit, w: int) -> int:
	return w * 3 / 10 if u.has_perk("armure_lourde") else 0


## Texte d'effet chiffré affiché dans le panneau de description.
static func effect_text(key: String) -> String:
	return str(Data.PERKS[key]["d"])
