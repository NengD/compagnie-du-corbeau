extends RefCounted
## Corps de tools/sim_maitrises.gd (séparé pour que les autoloads soient résolus au chargement).

const GEAR: Dictionary = {  # famille d'armure -> [tête, corps]
	"tissu": ["capuchon", "tunique"], "matelasse": ["capuchon", "gambison"], "mailles": ["none", "mailles"],
	"plates": ["heaume", "brigandine"], "casque": ["casque", "tunique"],
}
const WEAPON_OF: Dictionary = {"hast": "hallebarde", "bouclier": "epee"}


func _weapon_for(fam: String) -> String:
	if WEAPON_OF.has(fam):
		return str(WEAPON_OF[fam])
	return str(Data.WEAPON_FAMILIES[fam]["weapons"][0])


## Une unité de test équipée pour une famille d'armes et une famille d'armure, avec ou sans les talents de la liste.
func _unit(weapon_fam: String, armor_fam: String, keys: Array, with_perks: bool, hex: Vector2i = Vector2i.ZERO, side: String = "p") -> Unit:
	var u := Unit.new()
	u.id = Unit.alloc_id()
	u.unit_name = "T%d" % u.id
	u.side = side
	u.faction = side
	u.weapon = _weapon_for(weapon_fam)
	u.shield = weapon_fam == "bouclier"
	u.head = str(GEAR[armor_fam][0])
	u.body = str(GEAR[armor_fam][1])
	u.arm_h = u.head_armor_max()
	u.arm_b = u.body_armor_max()
	u.hp_max = 60
	u.hp = 60
	u.melee_skill = 55
	u.ranged_skill = 55
	u.melee_def = 5
	u.ranged_def = 5
	u.fat_max = 100
	u.initiative = 100
	u.resolve = 50
	u.hex = hex
	u.ap = 9
	if with_perks:
		for k in keys:
			u.perks.append(str(k))
	u.reset_for_battle()
	return u


func _avg_dmg(a: Unit, d: Unit, n: int = 400) -> Array:
	var hp: float = 0.0
	var ar: float = 0.0
	for i in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var r: Dictionary = CombatRules.roll_damage(a, d, rng)
		hp += float(r["hp"])
		ar += float(r["armor"])
	return [hp / n, ar / n]


func run(count: int) -> int:
	print("=== 1. Statistiques avant / après (unité de test contre un fantassin : 70 d'armure, défense 5) ===")
	print("%-34s %6s %6s | %-13s %-13s | %-13s | %5s | %-s" % ["Build (famille d'armes + armure)", "toucher", "après", "PV/coup arm.", "armure/coup", "PV/coup nu", "PA/atq", "autres effets mesurés"])
	for b in Data.BUILDS:
		var bd: Dictionary = b
		var keys: Array = []
		for st in bd["steps"]:
			keys.append(str(st[0]))
		var wf: String = str(bd["weapon"])
		var af: String = str(bd["armor"])
		var dist: int = 3 if Data.WPN[_weapon_for(wf)]["ranged"] else 1
		var tgt: Unit = _unit("hache", "matelasse", [], false, Vector2i(dist, 0), "e")
		tgt.arm_b = 70
		tgt.arm_h = 70
		var a0: Unit = _unit(wf, af, keys, false)
		var a1: Unit = _unit(wf, af, keys, true)
		var h0: int = CombatRules.hit_chance(a0, tgt, [a0, tgt])
		var h1: int = CombatRules.hit_chance(a1, tgt, [a1, tgt])
		var d0: Array = _avg_dmg(a0, tgt)
		var d1: Array = _avg_dmg(a1, tgt)
		var bare: Unit = _unit("hache", "tissu", [], false, Vector2i(dist, 0), "e")
		bare.arm_b = 0
		bare.arm_h = 0
		var n0: Array = _avg_dmg(a0, bare)
		var n1: Array = _avg_dmg(a1, bare)
		var extra: Array[String] = []
		if a1.fat_max_eff() != a0.fat_max_eff():
			extra.append("endurance %d→%d" % [a0.fat_max_eff(), a1.fat_max_eff()])
		if a1.ini_eff() != a0.ini_eff():
			extra.append("initiative %d→%d" % [a0.ini_eff(), a1.ini_eff()])
		if a1.eff("melee_def") != a0.eff("melee_def") or a1.eff("ranged_def") != a0.eff("ranged_def"):
			extra.append("déf %d/%d→%d/%d" % [a0.eff("melee_def"), a0.eff("ranged_def"), a1.eff("melee_def"), a1.eff("ranged_def")])
		if a1.weight() != a0.weight():
			extra.append("poids %d→%d" % [a0.weight(), a1.weight()])
		if a1.weapon_range() != a0.weapon_range():
			extra.append("portée %d→%d" % [a0.weapon_range(), a1.weapon_range()])
		if a1.full_ammo() != a0.full_ammo():
			extra.append("munitions %d→%d" % [a0.full_ammo(), a1.full_ammo()])
		var abs1: Array = CombatRules.abilities_of(a1)
		var abs0: Array = CombatRules.abilities_of(a0)
		for ab in abs1:
			if not abs0.has(ab):
				extra.append("capacité « %s »" % Data.ABILITIES[ab]["n"])
		# armure : dégâts reçus d'un attaquant de test
		var foe_hit: Unit = _unit("epee", "tissu", [], false, Vector2i(1, 0), "e")
		var e0: Array = _avg_dmg(foe_hit, a0)
		var e1: Array = _avg_dmg(foe_hit, a1)
		if absf(float(e1[0]) - float(e0[0])) > 0.05 or absf(float(e1[1]) - float(e0[1])) > 0.05:
			extra.append("coup d'épée reçu %.1f→%.1f PV, %.1f→%.1f armure" % [e0[0], e1[0], e0[1], e1[1]])
		print("%-34s %6d %6d | %5.1f→%-6.1f %5.1f→%-6.1f | %5.1f→%-6.1f | %2d→%-2d | %s" % [
			"%s + %s" % [Perks.family_name(wf), Perks.family_name(af)], h0, h1, d0[0], d1[0], d0[1], d1[1], n0[0], n1[0], a0.attack_ap(), a1.attack_ap(), ", ".join(extra)])
	print("\n=== 2. Batailles IA contre IA : 5 hommes, mêmes ennemis, avec ou sans les 10 talents du build (%d graines par build) ===" % count)
	print("%-28s %12s %12s | %-s" % ["Build", "victoires avec", "sans", "PV moyens perdus par homme (avec / sans)"])
	var sim: RefCounted = load("res://tools/sim_lib.gd").new()
	var bad: int = 0
	for b in Data.BUILDS:
		var bd2: Dictionary = b
		var keys2: Array = []
		for st in bd2["steps"]:
			keys2.append(str(st[0]))
		var res: Array = []
		for with_perks in [true, false]:
			var wins: int = 0
			var lost: float = 0.0
			for n in count:
				var rng := RandomNumberGenerator.new()
				rng.seed = 1000 + n
				var party: Array = []
				for i in 5:
					var u: Unit = _unit(str(bd2["weapon"]), str(bd2["armor"]), keys2, with_perks)
					u.level = 8
					u.melee_def = 5 + (i % 3)
					u.hp_max = 62
					u.hp = 62
					party.append(u)
				var p: Dictionary = sim.params_for(1000 + n)
				var contract: Dictionary = sim.make_contract(p["factions"], int(p["danger"]), str(p["biome"]), "pitched")
				var s: BattleState = BattleState.create(contract, party, rng, 3, 1.0, "normal")
				var r: Dictionary = sim.play(s, false)
				if not (r["errors"] as Array).is_empty():
					bad += 1
					print("  ✗ %s graine %d : %s" % [bd2["id"], n, str(r["errors"][0])])
				if s.over == "win":
					wins += 1
				for u2 in s.units:  # BattleState joue des copies des hommes
					if u2.side == "p":
						lost += float(u2.hp_max - maxi(0, u2.hp))
			res.append([wins, lost / float(count * 5)])
		print("%-28s %9d/%-3d %9d/%-3d | %.1f / %.1f" % [bd2["n"], res[0][0], count, res[1][0], count, res[0][1], res[1][1]])
	print("\nanomalies : %d (les taux de victoire sont informatifs ; aucun réglage d'équilibrage n'en découle)" % bad)
	return bad
