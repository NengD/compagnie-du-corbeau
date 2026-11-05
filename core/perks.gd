class_name Perks
extends RefCounted
## Arbre de talents (76 talents, 7 rangs de 9/8/6/17/13/17/6) : règles d'accès, dépense des points, bonus lus par le combat.
## Rang 4 = maîtrises (une par famille d'armes et d'armures), rang 6 = talents experts. Voir la fin du fichier (familles).
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

## Valeur cumulée d'un champ de spécialisation d'arme (`hit`, `ign`, `ammo` : somme ; `dmg`, `arm` : produit) pour l'équipement porté :
## seuls comptent les talents dont la famille (`family`) est celle de l'arme tenue (ou du bouclier porté).
static func weapon_field(u: Unit, field: String) -> float:
	var mult: bool = field == "dmg" or field == "arm"
	var v: float = 1.0 if mult else 0.0
	for p in u.perks:
		var pd: Dictionary = Data.PERKS.get(p, {})
		var wp: Dictionary = pd.get("wp", {})
		if wp.is_empty() or not wp.has(field) or not family_active(u, str(pd.get("family", ""))):
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


## Réduction de poids d'équipement (Carapace : 30 %).
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
		if xu.shield_wall and not xu.perks.is_empty():
			aura = maxf(aura, mfx(xu, "wall_aura"))  ## Bastion
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
	return fx(d, "head_safe") + mfx(d, "head_safe")


## PV rendus au début d'un tour de combat (Cicatrisation).
static func turn_heal(u: Unit) -> int:
	return int(fx(u, "turn_heal"))


## Chance (%) de survivre à un coup mortel, une fois par bataille (Sept vies).
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


# --- Familles d'armes et d'armures, maîtrises (voir Data.WEAPON_FAMILIES / ARMOR_FAMILIES, docs/builds.md) ---

## Famille d'une arme ("" pour une arme de monstre ou une clé inconnue). Les armes uniques (`u_*`) rejoignent celle de leur modèle.
static func weapon_family(weapon_key: String) -> String:
	for f in Data.WEAPON_FAMILIES:
		if (Data.WEAPON_FAMILIES[f]["weapons"] as Array).has(weapon_key):
			return str(f)
	return ""


## Arme de base d'une arme de famille (« u_epee_corbeau » -> « epee »).
static func weapon_base(weapon_key: String) -> String:
	var f: String = weapon_family(weapon_key)
	return str(Data.WEAPON_FAMILIES[f]["weapons"][0]) if f != "" else weapon_key


## Famille d'une pièce d'armure : `slot` = "head" ou "body" ("" si inconnue).
static func armor_family(slot: String, key: String) -> String:
	for f in Data.ARMOR_FAMILIES:
		if (Data.ARMOR_FAMILIES[f][slot] as Array).has(key):
			return str(f)
	return ""


## Clés de Data.WPN / HEAD / BODY sans famille (garde-fou : doit rester vide hors armes de monstres).
static func uncovered_gear() -> Array[String]:
	var out: Array[String] = []
	for k in Data.WPN:
		if not Data.WEAPONS_NO_FAMILY.has(k) and weapon_family(str(k)) == "":
			out.append("arme:" + str(k))
	for k in Data.HEAD:
		if armor_family("head", str(k)) == "":
			out.append("tête:" + str(k))
	for k in Data.BODY:
		if armor_family("body", str(k)) == "":
			out.append("corps:" + str(k))
	return out


## La famille `fam` (d'armes ou d'armures) est-elle celle de l'équipement RÉEL de `u` ?
static func family_active(u: Unit, fam: String) -> bool:
	if fam == "":
		return false
	if Data.WEAPON_FAMILIES.has(fam):
		return u.shield_ok() if fam == "bouclier" else weapon_family(u.weapon) == fam
	if Data.ARMOR_FAMILIES.has(fam):
		var af: Dictionary = Data.ARMOR_FAMILIES[fam]
		var hb: bool = armor_family("head", u.head) == fam
		var bb: bool = armor_family("body", u.body) == fam
		return (hb and bb) if str(af["rule"]) == "all" else (hb or bb)
	return false


## Maîtrise (rang 4) d'une famille d'armes ou d'armures.
static func mastery_of(fam: String) -> String:
	var d: Dictionary = Data.WEAPON_FAMILIES.get(fam, Data.ARMOR_FAMILIES.get(fam, {}))
	return str(d.get("mastery", ""))


static func family_name(fam: String) -> String:
	return str(Data.WEAPON_FAMILIES.get(fam, Data.ARMOR_FAMILIES.get(fam, {})).get("n", ""))


## Famille de maîtrise d'un talent ("" s'il n'en a pas).
static func family_of_perk(key: String) -> String:
	return str(Data.PERKS.get(key, {}).get("family", ""))


## Somme de l'effet de maîtrise `name` des talents de `u` dont la famille est portée.
static func mfx(u: Unit, name: String) -> float:
	var v: float = 0.0
	for p in u.perks:
		var pd: Dictionary = Data.PERKS.get(p, {})
		var m: Dictionary = pd.get("mfx", {})
		if m.has(name) and typeof(m[name]) != TYPE_DICTIONARY and family_active(u, str(pd.get("family", ""))):
			v += float(m[name])
	return v


## Produit des multiplicateurs de maîtrise `name` (1.0 sans talent concerné).
static func mmult(u: Unit, name: String) -> float:
	var v: float = 1.0
	for p in u.perks:
		var pd: Dictionary = Data.PERKS.get(p, {})
		var m: Dictionary = pd.get("mfx", {})
		if m.has(name) and family_active(u, str(pd.get("family", ""))):
			v *= float(m[name])
	return v


## Attributs ajoutés par les maîtrises dont la famille est portée (`fstat`).
static func family_stat(u: Unit, k: String) -> int:
	var v: int = 0
	for p in u.perks:
		var pd: Dictionary = Data.PERKS.get(p, {})
		var fs: Dictionary = pd.get("fstat", {})
		if fs.has(k) and family_active(u, str(pd.get("family", ""))):
			v += int(fs[k])
	return v


## PA retirés au coût de la capacité `id` par les maîtrises de `u` (Fente d'un maître d'épée…).
static func ability_cut(u: Unit, id: String) -> int:
	var v: int = 0
	for p in u.perks:
		var pd: Dictionary = Data.PERKS.get(p, {})
		var cuts: Dictionary = pd.get("mfx", {}).get("ab_ap", {})
		if cuts.has(id) and family_active(u, str(pd.get("family", ""))):
			v += int(cuts[id])
	return v


## Armure effective ajoutée à la zone touchée (Bourre épaisse, Tête dure…) : ne joue que s'il reste de l'armure réelle.
static func armor_soak(d: Unit, head: bool) -> int:
	if d.perks.is_empty():
		return 0
	return int(mfx(d, "soak") + mfx(d, "soak_h" if head else "soak_b"))


## Le type de dégâts de l'arme tenue par `a` est-il « tranchant » ? (Maillons serrés)
static func is_edged(a: Unit) -> bool:
	var f: String = weapon_family(a.weapon)
	return f != "" and str(Data.WEAPON_FAMILIES[f]["dmg_type"]) == "tranchant"


## Bonus au toucher de `a` contre `d` venant de sa maîtrise (arme d'hast contre une cible à 2 cases).
static func family_hit(a: Unit, d: Unit) -> int:
	if a.perks.is_empty():
		return 0
	var b: float = 0.0
	if not a.is_ranged() and Hex.distance(a.hex, d.hex) == 2:
		b += mfx(a, "reach_hit")
	return int(b)


## Texte « Maîtrise : Épées — Maître d'épée (apprise ✓) » pour une arme (kind "weapon"), un bouclier ("shield") ou une armure ("head" / "body") ; "" sans famille.
static func mastery_line(u: Unit, kind: String, key: String) -> String:
	var fam: String = ""
	match kind:
		"weapon":
			fam = weapon_family(key)
		"shield":
			fam = "bouclier"
		"head", "body":
			fam = armor_family(kind, key)
	if fam == "":
		return ""
	var m: String = mastery_of(fam)
	var learned: bool = u != null and u.has_perk(m)
	return "Maîtrise : %s — %s (%s)" % [family_name(fam), str(Data.PERKS[m]["n"]), "apprise ✓" if learned else "non apprise"]


## Résumé pour la fiche de personnage : la famille de l'arme, du bouclier et de l'armure portés avec l'état de la maîtrise.
static func mastery_summary(u: Unit) -> Array[String]:
	var out: Array[String] = []
	var fams: Array[String] = []
	var wf: String = weapon_family(u.weapon)
	if wf != "":
		fams.append(wf)
	if u.shield_ok():
		fams.append("bouclier")
	for f in Data.ARMOR_FAMILIES:
		if family_active(u, str(f)):
			fams.append(str(f))
	for f in fams:
		var m: String = mastery_of(f)
		out.append("%s : %s %s" % [family_name(f), str(Data.PERKS[m]["n"]), "✓" if u.has_perk(m) else "(non apprise)"])
	return out


## Phrase d'état d'une maîtrise ou d'un talent expert pour l'homme `u` : « Actif… » / « Inactif… » ("" si le talent n'a pas de famille).
static func family_status(u: Unit, key: String) -> String:
	var fam: String = family_of_perk(key)
	if fam == "" or u == null:
		return ""
	if family_active(u, fam):
		return "Actif : vous tenez ici un équipement de cette famille."
	if fam == "bouclier":
		return "Inactif : aucun bouclier intact."
	if Data.WEAPON_FAMILIES.has(fam):
		return "Inactif : l'arme actuelle est hors famille."
	return "Inactif : l'armure actuelle est hors famille."


## Liste lisible de ce qui compose la famille (« Épée d'armes, Lame du Corbeau »).
static func family_members(fam: String) -> String:
	var names: Array[String] = []
	if Data.WEAPON_FAMILIES.has(fam):
		for w in Data.WEAPON_FAMILIES[fam]["weapons"]:
			names.append(str(Data.WPN[w]["n"]))
		if fam == "bouclier":
			names.append(str(Data.SHIELD["n"]))
	elif Data.ARMOR_FAMILIES.has(fam):
		var af: Dictionary = Data.ARMOR_FAMILIES[fam]
		for k in af["head"]:
			names.append(str(Data.HEAD[k]["n"]))
		for k in af["body"]:
			names.append(str(Data.BODY[k]["n"]))
	return ", ".join(names)


## Un build (liste ordonnée de clés) est-il atteignable au niveau `level` (1 point par niveau à partir du niveau 2) ? Renvoie "" ou la raison.
static func build_problem(keys: Array, level: int) -> String:
	if keys.size() > maxi(0, level - 1):
		return "%d talents pour %d points" % [keys.size(), maxi(0, level - 1)]
	var u := Unit.new()
	u.perk_points = keys.size()
	for k in keys:
		var why: String = why_not(u, str(k))
		if why != "":
			return "%s : %s" % [str(k), why]
		take(u, str(k))
	return ""
