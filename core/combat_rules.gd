class_name CombatRules
extends RefCounted

const LIGHT_ARMOR: int = 70  ## armure de la zone touchée en dessous de laquelle Coup d'estoc s'applique
## Chance de toucher, dégâts armure/PV, tests de moral. Fonctions pures (aléa injecté).


## Portée, PA et fatigue seulement (la ligne de tir se vérifie avec `line_blocked`).
static func can_attack(a: Unit, d: Unit) -> bool:
	if not d.is_live() or d.side == a.side or a.morale == 0:
		return false
	var dist: int = Hex.distance(a.hex, d.hex)
	return dist >= 1 and dist <= a.weapon_range() and a.ap >= a.attack_ap() and a.fat + a.attack_fat() <= a.fat_max_eff()


# --- Capacités ---

## Capacités disponibles pour l'arme (et le bouclier) portés.
static func abilities_of(u: Unit) -> Array[String]:
	var out: Array[String] = []
	for k in Data.ABILITIES:
		var ab: Dictionary = Data.ABILITIES[k]
		if ab.has("tool"):
			if tool_left(u, str(ab["tool"])) > 0:
				out.append(k)
		elif bool(ab.get("needs_shield", false)):
			if u.shield_ok() and not u.is_ranged():
				out.append(k)
		elif (ab["weapons"] as Array).has(u.weapon):
			out.append(k)
	return out


## Lancers restants de l'outil `key` pour `u` : exemplaires dans le sac × usages par bataille − lancers déjà faits.
static func tool_left(u: Unit, key: String) -> int:
	var n: int = 0
	for b in u.bag:
		if not (b as Dictionary).is_empty() and str(b["kind"]) == "tool" and str(b["key"]) == key:
			n += int(Data.TOOLS[key]["uses"])
	return maxi(0, n - int(u.tool_used.get(key, 0)))


static func ability_ap(u: Unit, id: String) -> int:
	var ab: Dictionary = Data.ABILITIES[id]
	return int(ab["ap"]) if ab.has("ap") else u.attack_ap() + int(ab.get("ap_extra", 0))


static func ability_fat(u: Unit, id: String) -> int:
	var ab: Dictionary = Data.ABILITIES[id]
	return int(ab["fat"]) if ab.has("fat") else u.attack_fat() + int(ab.get("fat_extra", 0))


## Portée, PA, fatigue, bouclier requis (la ligne de tir se vérifie à part, comme pour `can_attack`).
static func can_use_ability(a: Unit, d: Unit, id: String) -> bool:
	if not Data.ABILITIES.has(id) or not abilities_of(a).has(id):
		return false
	var ab: Dictionary = Data.ABILITIES[id]
	if not d.is_live() or d.side == a.side or a.morale == 0:
		return false
	if bool(ab.get("needs_target_shield", false)) and not d.shield_ok():
		return false
	var dist: int = Hex.distance(a.hex, d.hex)
	if ab.has("tool"):  # lancer : portée propre à l'outil
		if dist < int(ab["min_rng"]) or dist > int(ab["rng"]):
			return false
	elif dist < 1 or dist > a.weapon_range():
		return false
	if bool(ab.get("needs_shield", false)) and dist != 1:
		return false
	return a.ap >= ability_ap(a, id) and a.fat + ability_fat(a, id) <= a.fat_max_eff()


static func terrain_at(cells: Dictionary, h: Vector2i) -> Dictionary:
	if cells.has(h):
		return Data.TERRAIN[cells[h]["t"]]
	return Data.TERRAIN["g"]


## Cases strictement entre `a` et `b` sur la ligne droite (tracé hexagonal).
static func line_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n: int = Hex.distance(a, b)
	for i in range(1, n):
		var t: float = float(i) / float(n)
		var fq: float = lerpf(a.x + 1e-6, b.x + 2e-6, t)
		var fr: float = lerpf(a.y + 2e-6, b.y - 3e-6, t)
		var fs: float = -fq - fr
		var q: float = roundf(fq)
		var r: float = roundf(fr)
		var s: float = roundf(fs)
		var dq: float = absf(q - fq)
		var dr: float = absf(r - fr)
		var ds: float = absf(s - fs)
		if dq > dr and dq > ds:
			q = -r - s
		elif dr > ds:
			r = -q - s
		out.append(Vector2i(int(q), int(r)))
	return out


## Un obstacle (arbre, rocher, forêt) coupe-t-il la ligne entre les deux cases ?
static func line_blocked(from: Vector2i, to: Vector2i, cells: Dictionary) -> bool:
	for h in line_between(from, to):
		if bool(terrain_at(cells, h)["los"]) or Scenery.blocks_los(cells, h):
			return true
	return false


## Nombre d'unités (amies ou ennemies) qui se trouvent sur la ligne de tir.
static func line_units(a: Unit, d: Unit, units: Array) -> int:
	var mid: Array[Vector2i] = line_between(a.hex, d.hex)
	var n: int = 0
	for x in units:
		var xu: Unit = x
		if xu != a and xu != d and xu.is_live() and mid.has(xu.hex):
			n += 1
	return n


## `units` : toutes les unités du combat (encerclement, ligne de tir). `cells` : terrain (collines, gués) ; vide = herbe partout.
## `bonus` : modificateur de toucher d'une capacité.
static func hit_chance(a: Unit, d: Unit, units: Array, cells: Dictionary = {}, bonus: int = 0) -> int:
	var w: Dictionary = a.weapon_data()
	var dist: int = Hex.distance(a.hex, d.hex)
	var ch: int
	var ter_def: int = 0
	if not d.has_perk("montagnard"):
		ter_def = int(terrain_at(cells, d.hex)["def"])
	if bool(w["ranged"]):
		var sh: int = (25 if d.shield_ok() else 0) + (20 if d.shield_wall else 0)
		ch = a.eff("ranged_skill") + int(w["hit"]) - (d.eff("ranged_def") + ter_def + sh + int(Data.MDEF[d.morale])) - 3 * maxi(0, dist - 2)
		if dist == 1:
			ch -= 10
		ch -= Data.LINE_UNIT_MALUS * line_units(a, d, units)
	else:
		var sh: int = (maxi(0, 15 - int(w.get("shield_ign", 0))) if d.shield_ok() else 0) + (20 if d.shield_wall else 0)
		ch = a.eff("melee_skill") + int(w["hit"]) - (d.eff("melee_def") + ter_def + sh + int(Data.MDEF[d.morale]))
		if d.shield_ok():
			ch += int(w.get("vs_shield", 0))
		for x in units:
			var xu: Unit = x
			if xu != a and xu.side == a.side and xu.is_live() and xu.morale > 0 and Hex.distance(xu.hex, d.hex) == 1:
				ch += 5
		var ha: int = int(terrain_at(cells, a.hex)["h"]) + Scenery.height_bonus(cells, a.hex)
		var hd: int = int(terrain_at(cells, d.hex)["h"]) + Scenery.height_bonus(cells, d.hex)
		if ha > hd:
			ch += Data.HILL_MELEE_BONUS
		elif ha < hd:
			ch -= Data.HILL_MELEE_BONUS
	return clampi(ch + bonus + charge_bonus(a) + int(Perks.weapon_field(a, "hit")) + int(Data.MSK[a.morale]) + Bonds.hit_bonus(a, units), 5, 95)


## Tire les dégâts d'un coup qui touche. Retour : {head, hp, armor} (ne modifie pas la cible).
## `ab` : capacité utilisée (multiplicateurs `dmg` et `armor`). Arme ébréchée : dégâts réduits.
static func roll_damage(a: Unit, d: Unit, rng: RandomNumberGenerator, ab: Dictionary = {}) -> Dictionary:
	var w: Dictionary = a.weapon_data()
	var head: bool = rng.randf() < (0.35 if a.has_perk("coup_de_grace") else 0.25)
	var raw: float = float(rng.randi_range(int(w["min"]), int(w["max"]))) * (1.5 if head else 1.0)
	raw *= float(ab.get("dmg", 1.0)) * Perks.weapon_field(a, "dmg")
	if a.weapon_broken():
		raw *= Data.BROKEN_WEAPON_DMG
	var arm: int = d.arm_h if head else d.arm_b
	if a.has_perk("briseur") and arm < LIGHT_ARMOR:
		raw *= 1.1
	var hp_d: float
	var arm_d: float
	if arm <= 0:
		hp_d = raw
		arm_d = 0.0
	else:
		var eff_arm: float = float(w["arm"]) * Perks.weapon_field(a, "arm")
		var ign: float = float(w["ign"]) + Perks.weapon_field(a, "ign")
		var ad: float = raw * eff_arm * float(ab.get("armor", 1.0))
		arm_d = minf(float(arm), ad)
		hp_d = maxf(0.0, raw * ign - float(arm) * 0.1)
		if ad > float(arm):
			hp_d += (ad - float(arm)) / (eff_arm * float(ab.get("armor", 1.0))) * (1.0 - ign)
	return {"head": head, "hp": roundi(hp_d), "armor": roundi(arm_d), "zone_armor": arm}


static func apply_damage(d: Unit, dmg: Dictionary) -> void:
	if bool(dmg["head"]):
		d.arm_h = maxi(0, d.arm_h - int(dmg["armor"]))
	else:
		d.arm_b = maxi(0, d.arm_b - int(dmg["armor"]))
	d.hp -= int(dmg["hp"])


## Test de moral : renvoie true si l'unité perd un cran.
static func morale_test_fails(u: Unit, modifier: int, rng: RandomNumberGenerator) -> bool:
	if not u.is_live() or u.morale == 0:
		return false
	var chance: int = clampi(u.eff("resolve") + modifier, 5, 95)
	if rng.randi_range(1, 100) > chance:
		u.morale -= 1
		return true
	return false


## Voir tomber un ennemi : chance de remonter d'un cran. Renvoie true si l'unité est galvanisée (morale 4).
static func morale_rally_up(u: Unit, rng: RandomNumberGenerator) -> bool:
	if not u.is_live() or u.morale == 0 or u.morale >= 4:
		return false
	if rng.randi_range(1, 100) <= u.eff("resolve") - 10:
		u.morale += 1
		return u.morale == 4
	return false


## Charge (cavalier de loup) : bonus au toucher de mêlée après 3 cases parcourues ou plus ce tour.
static func charge_bonus(a: Unit) -> int:
	if a.is_ranged() or a.moved_cells < 3:
		return 0
	return int(a.foe_data().get("charge", 0))
