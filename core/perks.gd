class_name Perks
extends RefCounted
## Arbre de talents (50 talents, 7 rangs de 9/8/8/12/5/4/4) : règles d'accès, dépense des points, bonus lus par le combat.
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


## Bonus de moral reçu d'un chef-né adjacent (+10) ou d'une voix claire à 3 cases ou moins (+5) : le plus fort seulement.
static func morale_aura(u: Unit, units: Array) -> int:
	var best: int = 0
	for x in units:
		var xu: Unit = x
		if xu == u or not xu.is_live() or xu.side != u.side or xu.perks.is_empty():
			continue
		var dist: int = Hex.distance(xu.hex, u.hex)
		if xu.has_perk("chef_ne") and dist == 1:
			best = maxi(best, 10)
		if xu.has_perk("voix_claire") and dist <= int(fx(xu, "voice_rng")):
			best = maxi(best, int(fx(xu, "voice")))
	return best


## Réduction de poids d'équipement (Port d'armure : 30 %).
static func weight_cut(u: Unit, w: int) -> int:
	return w * 3 / 10 if u.has_perk("armure_lourde") else 0


## Texte d'effet chiffré affiché dans le panneau de description.
static func effect_text(key: String) -> String:
	return str(Data.PERKS[key]["d"])


# --- Effets nommés (`fx` des talents) ---

## Valeur de l'effet `name` du talent `key` (0 s'il n'existe pas).
static func fx_of(key: String, name: String) -> float:
	return float(Data.PERKS.get(key, {}).get("fx", {}).get(name, 0.0))


## Somme de l'effet `name` sur tous les talents de `u`.
static func fx(u: Unit, name: String) -> float:
	var v: float = 0.0
	for p in u.perks:
		v += fx_of(str(p), name)
	return v


## Produit des multiplicateurs `name` de `u` (1.0 sans talent concerné).
static func fx_mult(u: Unit, name: String) -> float:
	var v: float = 1.0
	for p in u.perks:
		var f: float = fx_of(str(p), name)
		if f > 0.0:
			v *= f
	return v


## Meilleur multiplicateur de la compagnie : le plus fort (`lowest` = false) ou le plus bas (`lowest` = true) ; 1.0 sans talent.
static func roster_mult(roster: Array, name: String, lowest: bool = false) -> float:
	var best: float = 1.0
	for m in roster:
		var f: float = fx_mult(m as Unit, name)
		if f != 1.0 and ((f < best) if lowest else (f > best)):
			best = f
	return best


## Meilleur bonus entier de la compagnie (PV de repos supplémentaires…).
static func roster_best(roster: Array, name: String) -> int:
	var best: float = 0.0
	for m in roster:
		best = maxf(best, fx(m as Unit, name))
	return int(best)


## Alliés vivants adjacents à `u`.
static func adjacent_allies(u: Unit, units: Array) -> int:
	var n: int = 0
	for x in units:
		var xu: Unit = x
		if xu != u and xu.is_live() and xu.side == u.side and Hex.distance(xu.hex, u.hex) == 1:
			n += 1
	return n


## Bonus au toucher de `a` contre `d` venant de ses talents (position, élan, cible brisée).
static func hit_bonus(a: Unit, d: Unit, units: Array) -> int:
	if a.perks.is_empty():
		return 0
	var b: float = 0.0
	if a.is_ranged():
		if a.moved_cells == 0:
			b += fx(a, "still_ranged_hit")
	else:
		for p in a.perks:
			var cells: float = fx_of(str(p), "charge_cells")
			if cells > 0.0 and a.moved_cells >= int(cells):
				b += fx_of(str(p), "charge_hit")
		if fx(a, "solo_hit") > 0.0 and adjacent_allies(a, units) == 0:
			b += fx(a, "solo_hit")
	if d.morale <= 1:
		b += fx(a, "vs_broken_hit")
	return int(b)


## Bonus de défense de `d` venant de ses talents et de ceux de ses voisins (à retrancher au toucher de l'attaquant).
static func def_bonus(d: Unit, units: Array, ranged: bool) -> int:
	var b: float = 0.0
	var adj: int = 0
	var aura: float = 0.0
	for x in units:
		var xu: Unit = x
		if xu == d or not xu.is_live() or xu.side != d.side or Hex.distance(xu.hex, d.hex) != 1:
			continue
		adj += 1
		aura = maxf(aura, fx(xu, "aura_def"))
	b += aura
	if not d.perks.is_empty():
		if not ranged:
			b += mini(adj, int(fx(d, "adj_max"))) * fx(d, "adj_def")
			if adj == 0:
				b += fx(d, "solo_def")
		if d.shield_wall:
			b += fx(d, "wall_def")
	return int(b)


## Multiplicateur de dégâts de l'attaquant (Élan).
static func dmg_mult(a: Unit) -> float:
	if a.perks.is_empty() or a.is_ranged():
		return 1.0
	var m: float = 1.0
	for p in a.perks:
		var cells: float = fx_of(str(p), "charge_cells")
		if cells > 0.0 and a.moved_cells >= int(cells):
			m *= maxf(1.0, fx_of(str(p), "charge_dmg"))
	return m


## Multiplicateur de dégâts d'armure de l'attaquant (Lame affûtée).
static func arm_mult(a: Unit) -> float:
	return fx_mult(a, "arm_dmg")


## Réduction de la chance d'être visé à la tête (Nuque protégée).
static func head_shield(d: Unit) -> float:
	return fx(d, "head_safe")


## PV rendus au début d'un tour de combat (Cicatrisation).
static func turn_heal(u: Unit) -> int:
	return int(fx(u, "turn_heal"))


## Chance (%) de survivre à un coup mortel, une fois par bataille (Increvable).
static func survive_chance(u: Unit) -> int:
	return int(fx(u, "survive"))


## Capacités actives ouvertes par les talents de `u`.
static func abilities(u: Unit) -> Array[String]:
	var out: Array[String] = []
	for p in u.perks:
		var ab: String = str(Data.PERKS.get(p, {}).get("ability", ""))
		if ab != "" and not out.has(ab):
			out.append(ab)
	return out


## Migration des sauvegardes : remplace les clés disparues (`Data.PERK_MIGRATE`), retire les inconnues. Renvoie le nombre de points rendus.
static func migrate(u: Unit) -> int:
	var kept: Array[String] = []
	var refund: int = 0
	for p in u.perks:
		var k: String = str(p)
		if Data.PERK_MIGRATE.has(k):
			k = str(Data.PERK_MIGRATE[k])
		if Data.PERKS.has(k) and not kept.has(k):
			kept.append(k)
		else:
			refund += 1
	u.perks = kept
	return refund


## Nombre de talents du rang `tier` (voir Data.PERK_ROWS).
static func row_size(tier: int) -> int:
	return int(Data.PERK_ROWS[tier - 1])
