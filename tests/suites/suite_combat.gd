extends RefCounted
## Mécanique de combat : terrains, ligne de tir, talents, blessures.
var t  # le lanceur (voir tests/suites/README.md)


func _field(w: int = 12, h: int = 9) -> Dictionary:
	var cells: Dictionary = {}
	for r in h:
		for c in w:
			cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	return cells


func _put(cells: Dictionary, h: Vector2i, kind: String) -> void:
	cells[h]["t"] = kind


func _contract(foes: Array, biome: String = "") -> Dictionary:
	return {"type": "b", "d": 1, "foes": foes, "title": "Test", "desc": "", "days": 1, "employer": "x", "pay": 400, "biome": biome}


func _roster(n: int, seed_value: int) -> Array:
	var r: RandomNumberGenerator = t.rng_seeded(seed_value)
	var out: Array = []
	var keys: Array = Data.BG.keys()
	for i in n:
		out.append(Contracts.make_merc(keys[i % keys.size()], r, []))
	return out


# --- Terrains ---

func test_terrain_costs() -> void:
	var cells: Dictionary = _field()
	var start: Vector2i = Hex.from_col_row(5, 4)
	var u: Unit = t.mk("hache", "p", start)
	var east: Vector2i = start + Vector2i(1, 0)
	_put(cells, east, "forest")
	var c: Dictionary = Pathfinding.step_cost(u, cells, start, east)
	t.eq(c["ap"], 3, "forêt : 3 PA")
	t.eq(c["fat"], u.move_fat() + 2, "forêt : fatigue accrue")
	_put(cells, east, "ford")
	c = Pathfinding.step_cost(u, cells, start, east)
	t.eq(c["ap"], 4, "gué : 4 PA")
	t.eq(c["fat"], u.move_fat() * 2, "gué : fatigue x2")
	_put(cells, east, "hill")
	c = Pathfinding.step_cost(u, cells, start, east)
	t.eq(c["ap"], 3, "monter sur une colline : 3 PA")
	var east2: Vector2i = east + Vector2i(1, 0)
	_put(cells, east2, "hill")
	c = Pathfinding.step_cost(u, cells, east, east2)
	t.eq(c["ap"], 2, "colline à colline : 2 PA")
	c = Pathfinding.step_cost(u, cells, east, start)
	t.eq(c["ap"], 2, "descendre : 2 PA")
	_put(cells, east, "river")
	t.check(Pathfinding.blocked(cells, east), "rivière profonde infranchissable")
	var reach: Dictionary = Pathfinding.reachable(u, cells, [u])
	t.check(not reach.has(east), "rivière non atteignable")
	# Avec 9 PA : une forêt (3) + 3 cases d'herbe (6) = 4 cases ; deux gués (8) = 2 cases seulement.
	cells = _field()
	for k in [1, 2, 3, 4]:
		_put(cells, start + Vector2i(k, 0), "ford")
	reach = Pathfinding.reachable(u, cells, [u])
	t.check(reach.has(start + Vector2i(2, 0)), "deux gués = 8 PA : atteignable")
	t.check(not reach.has(start + Vector2i(3, 0)), "trois gués = 12 PA : hors de portée en ligne droite")
	t.eq(reach[start + Vector2i(2, 0)]["ap"], 8, "coût en PA enregistré")
	# La fatigue limite aussi
	u.fat = u.fat_max_eff() - 3
	_put(cells, start + Vector2i(1, 0), "ford")
	reach = Pathfinding.reachable(u, cells, [u])
	t.check(not reach.has(start + Vector2i(1, 0)), "gué : fatigue x2 dépasse l'endurance restante")
	# Dijkstra : contourne un gué coûteux si c'est moins cher
	cells = _field()
	_put(cells, start + Vector2i(1, 0), "ford")
	u.fat = 0
	reach = Pathfinding.reachable(u, cells, [u])
	var tgt: Vector2i = start + Vector2i(2, 0)
	t.check(reach.has(tgt) and int(reach[tgt]["ap"]) <= 6, "chemin le moins coûteux en PA (%d)" % int(reach[tgt]["ap"]))
	# step() applique le coût du terrain
	var s: BattleState = BattleState.create(_contract(["brigand"], "plain"), _roster(2, 1), t.rng_seeded(3))
	var w: Unit = s.units[0]
	var nb: Vector2i = w.hex + Vector2i(1, 0)
	s.cells[nb]["t"] = "ford"
	w.ap = 9
	w.fat = 0
	s.step(w, nb)
	t.eq(w.ap, 5, "le déplacement dans un gué coûte 4 PA")
	t.eq(w.fat, w.move_fat() * 2, "et double la fatigue")


func test_terrain_combat_modifiers() -> void:
	var cells: Dictionary = _field()
	var a: Unit = t.mk("hache", "p", Hex.from_col_row(4, 4))
	var d: Unit = t.mk("hache", "e", Hex.from_col_row(5, 4))
	var all: Array = [a, d]
	var base: int = CombatRules.hit_chance(a, d, all, cells)
	t.eq(CombatRules.hit_chance(a, d, all), base, "sans carte = herbe")
	_put(cells, a.hex, "hill")
	t.eq(CombatRules.hit_chance(a, d, all, cells), base + 10, "attaquant en hauteur : +10")
	_put(cells, a.hex, "g")
	_put(cells, d.hex, "hill")
	t.eq(CombatRules.hit_chance(a, d, all, cells), base - 10, "attaquant en contrebas : -10")
	_put(cells, a.hex, "hill")
	t.eq(CombatRules.hit_chance(a, d, all, cells), base, "même hauteur : neutre")
	_put(cells, a.hex, "g")
	_put(cells, d.hex, "ford")
	t.eq(CombatRules.hit_chance(a, d, all, cells), base + 10, "cible dans un gué : -10 en défense")
	d.perks.append("montagnard")
	t.eq(CombatRules.hit_chance(a, d, all, cells), base, "Montagnard ignore le malus du gué")
	# Une colline ne change rien à distance
	var b: Unit = t.mk("arc", "p", Hex.from_col_row(2, 4))
	var d2: Unit = t.mk("hache", "e", Hex.from_col_row(6, 4))
	cells = _field()
	var rb: int = CombatRules.hit_chance(b, d2, [b, d2], cells)
	_put(cells, b.hex, "hill")
	t.eq(CombatRules.hit_chance(b, d2, [b, d2], cells), rb, "la hauteur ne joue qu'en mêlée")


# --- Ligne de tir ---

func test_line_of_sight() -> void:
	var cells: Dictionary = _field()
	var a: Vector2i = Hex.from_col_row(2, 4)
	var b: Vector2i = Hex.from_col_row(7, 4)
	t.eq(CombatRules.line_between(a, b).size(), Hex.distance(a, b) - 1, "cases intermédiaires")
	t.eq(CombatRules.line_between(a, a + Vector2i(1, 0)).size(), 0, "voisins : aucune case entre eux")
	for i in 20:
		var p: Vector2i = Vector2i(i % 6, i / 3)
		var q: Vector2i = Vector2i(9 - i % 5, 6 - i % 4)
		for h in CombatRules.line_between(p, q):
			t.check(Hex.distance(p, h) + Hex.distance(h, q) == Hex.distance(p, q), "la ligne reste sur un plus court chemin")
	t.check(not CombatRules.line_blocked(a, b, cells), "herbe : ligne dégagée")
	var mid: Vector2i = CombatRules.line_between(a, b)[2]
	for kind in ["tree", "rock", "forest"]:
		_put(cells, mid, kind)
		t.check(CombatRules.line_blocked(a, b, cells), "%s bloque la ligne de tir" % kind)
	for kind in ["river", "ford", "hill"]:
		_put(cells, mid, kind)
		t.check(not CombatRules.line_blocked(a, b, cells), "%s ne bloque pas le tir" % kind)
	_put(cells, mid, "g")
	# Les extrémités ne bloquent pas
	_put(cells, b, "forest")
	t.check(not CombatRules.line_blocked(a, b, cells), "la forêt de la cible ne bloque pas")
	# Unités sur la ligne : -15 chacune, alliées ou ennemies
	var archer: Unit = t.mk("arc", "p", a)
	var target: Unit = t.mk("hache", "e", b)
	cells = _field()
	var base: int = CombatRules.hit_chance(archer, target, [archer, target], cells)
	var line: Array[Vector2i] = CombatRules.line_between(a, b)
	var friend: Unit = t.mk("hache", "p", line[1])
	t.eq(CombatRules.hit_chance(archer, target, [archer, target, friend], cells), base - 15, "allié sur la ligne : -15")
	var foe: Unit = t.mk("hache", "e", line[3])
	t.eq(CombatRules.hit_chance(archer, target, [archer, target, friend, foe], cells), base - 30, "deux unités : -30")
	foe.dead = true
	t.eq(CombatRules.hit_chance(archer, target, [archer, target, friend, foe], cells), base - 15, "un mort ne gêne pas")
	# Une arme de mêlée ignore tout cela
	var melee: Unit = t.mk("hache", "p", Hex.from_col_row(5, 4))
	var tm: Unit = t.mk("hache", "e", Hex.from_col_row(6, 4))
	t.eq(CombatRules.hit_chance(melee, tm, [melee, tm, friend], cells), CombatRules.hit_chance(melee, tm, [melee, tm], cells), "mêlée : pas de malus de ligne")


func test_line_of_sight_in_battle() -> void:
	var s: BattleState = BattleState.create(_contract(["brigand"], "plain"), _roster(2, 4), t.rng_seeded(6))
	for h in s.cells:
		s.cells[h]["t"] = "g"
	var archer: Unit = s.units[0]
	var foe: Unit = s.units[s.units.size() - 1]
	archer.weapon = "arc"
	archer.hex = Hex.from_col_row(2, 4)
	foe.hex = Hex.from_col_row(6, 4)
	for u in s.units:
		if u != archer and u != foe:
			u.dead = true
	archer.ap = 9
	archer.fat = 0
	t.check(s.can_attack(archer, foe), "tir possible en terrain dégagé")
	var mid: Vector2i = CombatRules.line_between(archer.hex, foe.hex)[1]
	s.cells[mid]["t"] = "forest"
	t.check(not s.can_attack(archer, foe), "ligne bloquée : tir impossible")
	t.check(s.line_blocked(archer, foe), "line_blocked signalé à l'interface")
	t.check(CombatRules.can_attack(archer, foe), "portée et PA corrects par ailleurs")
	# L'IA n'essaie pas de tirer à travers la forêt : elle se déplace pour dégager la ligne.
	var memo: Dictionary = {}
	var act: Dictionary = Ai.next_action(s, archer, memo)
	t.eq(act["type"], "move", "l'archer cherche une case avec ligne dégagée")
	if act["type"] == "move":
		var dest: Vector2i = (act["path"] as Array)[-1]
		t.check(not CombatRules.line_blocked(dest, foe.hex, s.cells), "case choisie : ligne dégagée")
	# Pourcentage affiché reflète le malus d'un allié sur la ligne
	s.cells[mid]["t"] = "g"
	var base: int = s.hit_chance(archer, foe)
	var ally: Unit = s.units[1] if s.units[1] != archer and s.units[1] != foe else s.units[2]
	ally.dead = false
	ally.hex = mid
	t.eq(s.hit_chance(archer, foe), base - 15, "le pourcentage reflète l'unité sur la ligne")


# --- Génération ---

func test_terrain_generation() -> void:
	var kinds_seen: Dictionary = {}
	for biome in Data.BIOMES:
		for seed_value in 25:
			var cells: Dictionary = TerrainGen.generate(12, 9, biome, t.rng_seeded(seed_value * 7 + 1))
			t.eq(cells.size(), 108, "toutes les cases existent")
			var passable: int = 0
			for h in cells:
				var c: int = int(cells[h]["c"])
				var kind: String = str(cells[h]["t"])
				kinds_seen[kind] = true
				if c <= 2 or c >= 9:
					t.eq(kind, "g", "zone de déploiement dégagée (%s)" % biome)
				if not Pathfinding.blocked(cells, h):
					passable += 1
			var seen: Dictionary = TerrainGen._flood(cells, Hex.from_col_row(0, 4))
			t.eq(seen.size(), passable, "aucune case praticable isolée (%s, graine %d)" % [biome, seed_value])
			t.check(seen.has(Hex.from_col_row(11, 4)), "les deux camps communiquent (%s)" % biome)
			if biome == "water":
				var river: int = 0
				var ford: int = 0
				for h in cells:
					river += 1 if cells[h]["t"] == "river" else 0
					ford += 1 if cells[h]["t"] == "ford" else 0
				t.check(river >= 10 and ford >= 2, "rivière avec au moins un gué (%d/%d)" % [river, ford])
			if biome == "forest":
				var n: int = 0
				for h in cells:
					n += 1 if cells[h]["t"] == "forest" else 0
				t.check(n >= 3, "des bosquets (%d)" % n)
			if biome == "hills":
				var n2: int = 0
				for h in cells:
					n2 += 1 if cells[h]["t"] == "hill" else 0
				t.check(n2 >= 3, "des collines (%d)" % n2)
	for k in Data.TERRAIN:
		t.check(kinds_seen.has(k), "le terrain %s apparaît" % k)
	# Biome d'un contrat ; tirage aléatoire sinon
	var s: BattleState = BattleState.create(_contract(["brigand"], "water"), _roster(3, 2), t.rng_seeded(11))
	t.eq(s.biome, "water", "biome du contrat")
	var s2: BattleState = BattleState.create(_contract(["brigand"], ""), _roster(3, 2), t.rng_seeded(11))
	t.check(Data.BIOMES.has(s2.biome), "biome tiré au hasard")
	var s3: BattleState = BattleState.create(_contract(["brigand"], "inconnu"), _roster(3, 2), t.rng_seeded(11))
	t.check(Data.BIOMES.has(s3.biome), "biome inconnu : tirage")
	var back: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), t.rng_seeded(1))
	t.eq(back.biome, "water", "biome sérialisé")
	var legacy: Dictionary = s.to_dict()
	legacy.erase("biome")
	t.eq(BattleState.from_dict(JSON.parse_string(JSON.stringify(legacy)), t.rng_seeded(1)).biome, "plain", "ancienne sauvegarde : plaine")


func test_ai_battles_on_all_biomes() -> void:
	var done: int = 0
	for biome in Data.BIOMES:
		for seed_value in 6:
			var foes: Array = [["brigand", "brigand", "archer", "archer"], ["goule", "goule", "vorace"], ["brigand", "archer", "balafre", "chef"]][seed_value % 3]
			var s: BattleState = BattleState.create(_contract(foes, biome), _roster(8, seed_value + 3), t.rng_seeded(seed_value + 40))
			var turns: int = 0
			while s.over == "" and s.round_no < 120 and turns < 6000:
				var u: Unit = s.next_turn()
				if u == null:
					break
				s.play_ai_turn(u)
				turns += 1
			t.check(s.over == "win" or s.over == "lose", "bataille %s/%d terminée (manche %d)" % [biome, seed_value, s.round_no])
			done += 1
			var occ: Dictionary = {}
			for u in s.units:
				if u.is_live():
					t.check(not Pathfinding.blocked(s.cells, u.hex), "unité sur une case praticable (%s)" % biome)
					t.check(not occ.has(u.hex), "pas deux unités sur la même case")
					occ[u.hex] = true
				t.check(u.fat >= 0 and u.ap >= -1, "valeurs bornées")
	t.eq(done, 24, "24 batailles jouées")


func test_ai_crosses_river() -> void:
	# Une rivière sépare les camps, un seul gué : l'IA de mêlée doit finir par atteindre l'ennemi.
	var s: BattleState = BattleState.create(_contract(["brigand", "brigand"], "plain"), _roster(2, 5), t.rng_seeded(9))
	for h in s.cells:
		s.cells[h]["t"] = "g"
	for r in 9:
		for col in [5, 6]:
			s.cells[Hex.from_col_row(col, r)]["t"] = "river"
	for col in [5, 6]:
		s.cells[Hex.from_col_row(col, 1)]["t"] = "ford"
	var turns: int = 0
	var met: bool = false
	while s.over == "" and s.round_no < 40 and turns < 2000:
		var u: Unit = s.next_turn()
		if u == null:
			break
		s.play_ai_turn(u)
		turns += 1
		for x in s.units:
			if x.is_live() and x.side == "p":
				for f in s.foes_of(x):
					if Hex.distance(x.hex, f.hex) == 1:
						met = true
	t.check(met or s.over != "", "les camps finissent par s'affronter malgré la rivière")


# --- Talents ---

func test_perk_data() -> void:
	t.check(Data.PERKS.size() >= 14, "au moins 14 talents")
	for k in Data.PERKS:
		t.check(str(Data.PERKS[k]["n"]) != "" and str(Data.PERKS[k]["d"]) != "", "talent %s décrit" % k)


func test_perk_stats() -> void:
	var u: Unit = t.mk()
	var base_ini: int = u.ini_eff()
	u.perks.append("vif")
	t.eq(u.ini_eff(), base_ini + 10, "Vif : +10 initiative")
	t.eq(u.initiative, 100, "la base n'est pas modifiée")
	u.shield = true
	var md: int = u.eff("melee_def")
	u.perks.append("garde_ferme")
	t.eq(u.eff("melee_def"), md + 10, "Garde ferme avec un bouclier")
	u.shield = false
	t.eq(u.eff("melee_def"), md - 0, "Garde ferme inactive sans bouclier")
	u.perks.append("cran")
	t.eq(u.eff("resolve"), 65, "Nerfs d'acier : +15 détermination")
	var r: RandomNumberGenerator = t.rng_seeded(5)
	var fails_a: int = 0
	var fails_b: int = 0
	for i in 2000:
		var x: Unit = t.mk()
		x.resolve = 50
		var y: Unit = t.mk()
		y.resolve = 50
		y.perks.append("cran")
		fails_a += 1 if CombatRules.morale_test_fails(x, 0, r) else 0
		fails_b += 1 if CombatRules.morale_test_fails(y, 0, r) else 0
	t.check(fails_b < fails_a * 0.7, "Nerfs d'acier réduit les échecs de moral (%d contre %d)" % [fails_b, fails_a])
	var e: Unit = t.mk()
	e.perks.append("esquive")
	e.perks.append("oeil_sur")
	e.perks.append("bretteur")
	t.eq(e.eff("ranged_def"), 15, "Cible mouvante : +10 déf. distance")
	t.eq(e.eff("ranged_skill"), 70, "Œil sûr : +10")
	t.eq(e.eff("melee_skill"), 60, "Bretteur : +5")
	# les talents modifient bien le toucher
	var a: Unit = t.mk("hache", "p", Vector2i(0, 0))
	var d: Unit = t.mk("hache", "e", Vector2i(1, 0))
	var before: int = CombatRules.hit_chance(a, d, [a, d])
	a.perks.append("bretteur")
	t.eq(CombatRules.hit_chance(a, d, [a, d]), before + 5, "Bretteur dans la chance de toucher")


func test_perk_action_costs() -> void:
	var u: Unit = t.mk("hache")
	t.eq(u.attack_ap(), 4, "attaque de base : 4 PA")
	u.perks.append("frappe_vive")
	t.eq(u.attack_ap(), 3, "Frappe vive : première attaque -1 PA")
	var s: BattleState = BattleState.create(_contract(["brigand"], "plain"), _roster(2, 7), t.rng_seeded(2))
	var a: Unit = s.units[0]
	var d: Unit = s.units[s.units.size() - 1]
	a.perks.append("frappe_vive")
	s.begin_turn(a)
	t.eq(a.ap, 9, "9 PA au début du tour")
	d.hex = a.hex + Vector2i(1, 0)
	var w: int = a.attack_ap()
	s.attack(a, d)
	t.eq(a.ap, 9 - w, "première attaque : coût réduit")
	t.check(a.attacked_turn, "attaque notée")
	t.eq(a.attack_ap(), int(a.weapon_data()["ap"]), "seconde attaque : plein tarif")
	s.round_no += 1
	s.begin_turn(a)
	t.check(not a.attacked_turn, "réinitialisé au tour suivant")
	# Endurant, Jarret solide, Poumons de forge
	var e: Unit = t.mk("hache")
	var fat_w: int = e.attack_fat()
	e.perks.append("endurant")
	t.eq(e.attack_fat(), fat_w - 3, "Endurant : -3 fatigue par attaque")
	var mv: int = e.move_fat()
	e.perks.append("pied_sur")
	t.eq(e.move_fat(), mv - 1, "Jarret solide : -1 fatigue par case")
	var f: Unit = s.units[1]
	f.fat = 40
	f.turn_round = 0
	var g2: Unit = s.units[2] if s.units.size() > 3 else s.units[1]
	f.perks.append("second_souffle")
	s.begin_turn(f)
	t.eq(f.fat, 20, "Poumons de forge : -15 puis -5")
	f.turn_round = 0
	f.fat = 40
	f.perks.clear()
	s.begin_turn(f)
	t.eq(f.fat, 25, "sans le talent : -15")
	# Œil de lynx
	var bow: Unit = t.mk("arc")
	t.eq(bow.weapon_range(), 6, "arc : portée 6")
	bow.perks.append("oeil_de_lynx")
	t.eq(bow.weapon_range(), 8, "Œil de lynx : +2")
	var axe: Unit = t.mk("hache")
	axe.perks.append("oeil_de_lynx")
	t.eq(axe.weapon_range(), 1, "sans effet en mêlée")
	var tg: Unit = t.mk("hache", "e", bow.hex + Vector2i(8, 0))
	t.check(CombatRules.can_attack(bow, tg), "cible à 8 cases atteignable")
	bow.perks.clear()
	t.check(not CombatRules.can_attack(bow, tg), "hors de portée sans le talent")


func test_perk_movement_and_damage() -> void:
	var cells: Dictionary = _field()
	var u: Unit = t.mk("hache", "p", Hex.from_col_row(3, 4))
	var f1: Unit = t.mk("hache", "e", Hex.from_col_row(5, 4))
	var reach: Dictionary = Pathfinding.reachable(u, cells, [u, f1])
	# Sans talent, on ne traverse pas la ZdC : la case derrière l'ennemi est inaccessible
	var behind: Vector2i = Hex.from_col_row(6, 4)
	t.check(not reach.has(behind), "ZdC : on ne passe pas")
	u.perks.append("insaisissable")
	reach = Pathfinding.reachable(u, cells, [u, f1])
	t.check(reach.has(Hex.from_col_row(5, 3)) or reach.has(Hex.from_col_row(4, 3)), "Anguille : traverse la ZdC d'un seul ennemi")
	var f2: Unit = t.mk("hache", "e", Hex.from_col_row(5, 5))
	var zoc: Dictionary = Pathfinding.zoc_cells(u, [u, f1, f2])
	var shared: int = 0
	for k in zoc:
		shared += 1
		t.check(int(zoc[k]) >= 2, "seules les cases à deux ennemis restent contrôlées")
	t.check(shared > 0, "deux ennemis voisins : zone commune")
	# Montagnard
	var m: Unit = t.mk("hache", "p", Hex.from_col_row(3, 4))
	var c2: Dictionary = _field()
	_put(c2, m.hex + Vector2i(1, 0), "ford")
	t.eq(Pathfinding.step_cost(m, c2, m.hex, m.hex + Vector2i(1, 0))["ap"], 4, "gué normal")
	m.perks.append("montagnard")
	t.eq(Pathfinding.step_cost(m, c2, m.hex, m.hex + Vector2i(1, 0))["ap"], 2, "Montagnard : gué comme de l'herbe")
	# Briseur : +10 % contre armure légère
	var r1: RandomNumberGenerator = t.rng_seeded(77)
	var r2: RandomNumberGenerator = t.rng_seeded(77)
	var a: Unit = t.mk("hache", "p")
	var b: Unit = t.mk("hache", "p")
	b.perks.append("briseur")
	var d: Unit = t.mk("hache", "e")
	d.arm_h = 10
	d.arm_b = 10
	var dmg_a: int = 0
	var dmg_b: int = 0
	for i in 200:
		var x: Dictionary = CombatRules.roll_damage(a, d, r1)
		var y: Dictionary = CombatRules.roll_damage(b, d, r2)
		dmg_a += int(x["hp"]) + int(x["armor"])
		dmg_b += int(y["hp"]) + int(y["armor"])
	t.check(dmg_b > dmg_a * 1.05, "Coup d'estoc : dégâts en hausse contre armure légère (%d contre %d)" % [dmg_b, dmg_a])
	d.arm_h = 150
	d.arm_b = 150
	r1.seed = 5
	r2.seed = 5
	var heavy_a: int = 0
	var heavy_b: int = 0
	for i in 200:
		heavy_a += int(CombatRules.roll_damage(a, d, r1)["hp"])
		heavy_b += int(CombatRules.roll_damage(b, d, r2)["hp"])
	t.eq(heavy_b, heavy_a, "pas d'effet contre une armure lourde")
	# Visée haute : plus de coups à la tête
	var heads_a: int = 0
	var heads_b: int = 0
	var rr: RandomNumberGenerator = t.rng_seeded(3)
	var g: Unit = t.mk("hache", "p")
	g.perks.append("coup_de_grace")
	for i in 3000:
		heads_a += 1 if CombatRules.roll_damage(a, d, rr)["head"] else 0
		heads_b += 1 if CombatRules.roll_damage(g, d, rr)["head"] else 0
	t.check(heads_b > heads_a + 150, "Visée haute : plus de coups à la tête (%d contre %d)" % [heads_b, heads_a])


func test_perk_promotion_and_save() -> void:
	var g: Node = t.new_game(21)
	var m: Unit = g.roster[0]
	m.pending = 3
	var rolls: Dictionary = g.roll_promotion()
	t.check(not g.apply_promotion(m, rolls, ["hp_max", "resolve"]), "il faut 3 attributs")
	t.eq(m.pending, 3, "rien consommé")
	t.check(g.apply_promotion(m, rolls, ["hp_max", "resolve", "melee_def"]), "promotion")
	t.eq(m.pending, 2, "promotion consommée")
	m.perks.append("cran")
	# Sauvegarde complète
	m.injuries.append({"id": "bras", "days_left": 5})
	m.injuries.append({"id": "oeil", "days_left": -1})
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = t.new_game(1)
	g2.from_dict(d)
	var m2: Unit = g2.roster[0]
	t.eq(m2.perks, m.perks, "talents sauvegardés")
	t.eq(m2.injuries.size(), 2, "blessures sauvegardées")
	t.eq(m2.injuries[0]["days_left"], 5, "durée entière après rechargement")
	t.eq(typeof(m2.injuries[1]["days_left"]), TYPE_INT, "type entier")
	# Ancienne sauvegarde sans talents ni blessures
	var old: Dictionary = m.to_dict()
	old.erase("perks")
	old.erase("injuries")
	var u: Unit = Unit.from_dict(old)
	t.check(u.perks.is_empty() and u.injuries.is_empty(), "valeurs par défaut")
	# Copie pour la bataille
	var cp: Unit = m.duplicate_unit()
	t.eq(cp.perks, m.perks, "le combattant garde ses talents")
	cp.injuries[0]["days_left"] = 1
	t.eq(m.injuries[0]["days_left"], 5, "copie profonde")
	g.free()
	g2.free()


# --- Blessures ---

func test_injury_effects() -> void:
	var u: Unit = t.mk("hache")
	u.injuries.append({"id": "bras", "days_left": 5})
	t.eq(u.eff("melee_skill"), 45, "Bras blessé : -10 mêlée")
	t.eq(u.melee_skill, 55, "la base n'est pas modifiée")
	var a: Unit = t.mk("hache", "p", Vector2i(0, 0))
	var d: Unit = t.mk("hache", "e", Vector2i(1, 0))
	var before: int = CombatRules.hit_chance(a, d, [a, d])
	a.injuries.append({"id": "bras", "days_left": 5})
	t.eq(CombatRules.hit_chance(a, d, [a, d]), before - 10, "blessure dans la chance de toucher")
	var l: Unit = t.mk()
	var fat0: int = l.fat_max_eff()
	var ini0: int = l.ini_eff()
	l.injuries.append({"id": "jambe", "days_left": 3})
	t.eq(l.fat_max_eff(), fat0 - 15, "Jambe blessée : endurance")
	t.eq(l.ini_eff(), ini0 - 15, "Jambe blessée : initiative")
	var c: Unit = t.mk()
	c.injuries.append({"id": "commotion", "days_left": 3})
	t.eq(c.eff("resolve"), 40, "Commotion : détermination")
	var o: Unit = t.mk()
	o.injuries.append({"id": "oeil", "days_left": -1})
	t.eq(o.eff("ranged_skill"), 45, "Œil perdu : distance")
	var b: Unit = t.mk()
	b.injuries.append({"id": "boiteux", "days_left": -1})
	t.eq(b.ini_eff(), 90, "Boiteux : initiative")
	var k: Unit = t.mk()
	k.injuries.append({"id": "cicatrice", "days_left": -1})
	t.eq(k.eff("resolve"), 45, "Cicatrice profonde : détermination")


func test_injury_rolls() -> void:
	var r: RandomNumberGenerator = t.rng_seeded(12)
	var hits: int = 0
	for i in 1000:
		var u: Unit = t.mk("hache", "p")
		u.hp_max = 60
		u.hp = 30
		if Injuries.roll_wound(u, 20, r) != "":
			hits += 1
			t.eq(u.injuries.size(), 1, "une blessure ajoutée")
			t.check(int(u.injuries[0]["days_left"]) >= 3, "durée positive")
			t.check(not bool(Data.INJURIES[u.injuries[0]["id"]]["perm"]), "temporaire")
	t.check(hits > 420 and hits < 580, "coup à 33 %% des PV : environ 50 %% de blessures (%d/1000)" % hits)
	var small: Unit = t.mk("hache", "p")
	var none: int = 0
	for i in 200:
		none += 1 if Injuries.roll_wound(small, 17, r) != "" else 0
	t.eq(none, 0, "coup sous 30 % des PV max : jamais de test")
	var foe: Unit = t.mk("hache", "e")
	for i in 100:
		t.eq(Injuries.roll_wound(foe, 50, r), "", "les ennemis ne se blessent pas")
	t.eq(foe.injuries.size(), 0, "aucune blessure ennemie")
	var tough_hits: int = 0
	for i in 1000:
		var tk: Unit = t.mk("hache", "p")
		tk.perks.append("dur_a_cuire")
		tough_hits += 1 if Injuries.roll_wound(tk, 30, r) != "" else 0
	t.check(tough_hits > 180 and tough_hits < 320, "Cuir épais : environ 25 %% (%d/1000)" % tough_hits)
	# Pas de doublon
	var d: Unit = t.mk("hache", "p")
	for i in 100:
		Injuries.roll_wound(d, 40, r)
	var ids: Dictionary = {}
	for i in d.injuries:
		t.check(not ids.has(i["id"]), "pas de blessure en double")
		ids[i["id"]] = true
	# Permanentes : seulement à 25 % des PV ou moins
	var perm: int = 0
	for i in 1000:
		var w: Unit = t.mk("hache", "p")
		w.hp = 10
		if Injuries.roll_permanent(w, r) != "":
			perm += 1
			t.eq(w.injuries[0]["days_left"], -1, "permanente = -1")
	t.check(perm > 290 and perm < 410, "environ 35 %% de séquelles (%d/1000)" % perm)
	var healthy: Unit = t.mk("hache", "p")
	healthy.hp = 40
	for i in 100:
		t.eq(Injuries.roll_permanent(healthy, r), "", "en bonne santé : aucune séquelle")


func test_injury_battle_logging() -> void:
	# Un coup lourd sur un de nos hommes finit par blesser et le journal le dit.
	var s: BattleState = BattleState.create(_contract(["chef"], "plain"), _roster(2, 9), t.rng_seeded(31))
	var victim: Unit = s.units[0]
	var foe: Unit = s.units[s.units.size() - 1]
	foe.weapon = "hache"
	foe.hex = victim.hex + Vector2i(1, 0)
	victim.hp_max = 400
	var wounded: bool = false
	for i in 120:
		victim.hp = 400
		foe.ap = 9
		foe.fat = 0
		foe.melee_skill = 200
		victim.arm_h = 0
		victim.arm_b = 0
		var res: Dictionary = s.attack(foe, victim)
		if res.has("wound"):
			wounded = true
			break
	t.check(true, "pas de plantage")
	if wounded:
		t.check(s.log_lines[0]["t"].contains("blessé"), "le journal mentionne la blessure")
	# Les dégâts ≥ 30 % de 400 = 120 sont impossibles : aucune blessure
	t.check(not wounded, "un coup léger pour un gros réservoir de PV ne blesse pas")
	victim.hp_max = 50
	var got: bool = false
	for i in 120:
		victim.hp = 50
		victim.injuries.clear()
		foe.ap = 9
		foe.fat = 0
		victim.arm_h = 0
		victim.arm_b = 0
		var res2: Dictionary = s.attack(foe, victim)
		if res2.has("wound"):
			got = true
			t.check(victim.injuries.size() == 1, "la blessure est enregistrée sur l'homme")
			t.check(s.log_lines[0]["t"].contains("blessé"), "journal de bataille")
			break
		if victim.hp <= 0:
			victim.dead = false
	t.check(got, "un coup qui retire plus de 30 %% des PV peut blesser")
	# L'ennemi frappé ne se blesse pas
	foe.hp_max = 50
	for i in 40:
		foe.hp = 50
		foe.dead = false
		victim.ap = 9
		victim.fat = 0
		victim.melee_skill = 200
		var res3: Dictionary = s.attack(victim, foe)
		t.check(not res3.has("wound"), "pas de blessure côté ennemi")


func test_injury_healing_and_campaign() -> void:
	var u: Unit = t.mk()
	u.injuries.append({"id": "bras", "days_left": 3})
	u.injuries.append({"id": "oeil", "days_left": -1})
	t.eq(Injuries.heal(u, 1).size(), 0, "rien de guéri le premier jour")
	t.eq(u.injuries[0]["days_left"], 2, "un jour de moins")
	var healed: Array[String] = Injuries.heal(u, 2)
	t.eq(healed, ["Bras blessé"], "guérison")
	t.eq(u.injuries.size(), 1, "la séquelle reste")
	t.eq(Injuries.heal(u, 50).size(), 0, "une séquelle ne guérit jamais")
	t.eq(u.injuries[0]["days_left"], -1, "toujours permanente")
	# Dans la campagne : le temps guérit, deux fois plus vite en ville
	var g: Node = t.new_game(5)
	g.gold = 100000
	var m: Unit = g.roster[0]
	m.injuries.append({"id": "jambe", "days_left": 6})
	t.eq(g.location != "", true, "départ en ville")
	g.advance_time(1.0)
	t.eq(m.injuries[0]["days_left"], 4, "en ville : 2 jours de soins par jour")
	g.location = ""
	g.advance_time(1.0)
	t.eq(m.injuries[0]["days_left"], 3, "sur la route : 1 jour")
	g.advance_time(3.0)
	t.eq(m.injuries.size(), 0, "guérie")
	# Fin de combat : les blessures passent du combattant à la compagnie
	g.location = g.world.start_town if "start_town" in g.world else g.location
	var contract: Dictionary = _contract(["brigand"], "plain")
	contract["kind"] = "contract"
	g.start_battle(contract)
	t.check(g.battle != null, "bataille lancée")
	if g.battle == null:
		g.free()
		return
	var b: BattleState = g.battle
	var fighter: Unit = null
	for x in b.units:
		if x.side == "p":
			fighter = x
			break
	var id: int = fighter.id
	fighter.injuries.append({"id": "commotion", "days_left": 4})
	fighter.hp = fighter.hp_max
	b.over = "win"
	for x in b.units:
		if x.side == "e":
			x.dead = true
	g.finish_battle()
	var member: Unit = g.member(id)
	t.check(member != null and member.has_injury("commotion"), "la blessure revient au camp")
	g.free()
	# Un homme à ≤ 25 % PV en fin de combat peut garder une séquelle : sur beaucoup d'essais, au moins une
	var scarred: int = 0
	for i in 40:
		var g3: Node = t.new_game(100 + i)
		g3.start_battle(contract)
		var b3: BattleState = g3.battle
		var f3: Unit = null
		for x in b3.units:
			if x.side == "p":
				f3 = x
				break
		f3.hp = 3
		b3.over = "win"
		for x in b3.units:
			if x.side == "e":
				x.dead = true
		var id3: int = f3.id
		g3.finish_battle()
		var m3: Unit = g3.member(id3)
		if m3 != null:
			for inj in m3.injuries:
				if int(inj["days_left"]) < 0:
					scarred += 1
		g3.free()
	t.check(scarred > 3 and scarred < 30, "séquelles après un combat à l'agonie (%d/40)" % scarred)
