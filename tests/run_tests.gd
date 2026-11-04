extends SceneTree
## Tests de core/ et de l'état de campagne, en headless :
##   godot --path . --headless -s res://tests/run_tests.gd
## Code de sortie 0 si tout passe, 1 sinon.

var _checks: int = 0
var _failures: Array[String] = []


func _init() -> void:
	var tests: Array[Callable] = [
		test_hex, test_unit_formulas, test_hit_chance, test_damage, test_morale, test_pathfinding,
		test_battle_setup, test_free_attack, test_ai_battles, test_battle_serialization,
		test_world, test_contracts, test_game_camp, test_game_battle_results, test_game_travel, test_game_save_roundtrip,
	]
	for t in tests:
		var before: int = _failures.size()
		t.call()
		print("%s %s" % ["OK  " if _failures.size() == before else "FAIL", t.get_method()])
	# Suites additionnelles : tests/suites/*.gd (extends RefCounted, `var t` = ce lanceur, méthodes test_*).
	var dir: DirAccess = DirAccess.open("res://tests/suites")
	if dir != null:
		var files: PackedStringArray = dir.get_files()
		files.sort()
		for f in files:
			if not f.ends_with(".gd"):
				continue
			var suite: Object = load("res://tests/suites/" + f).new()
			suite.set("t", self)
			for m in suite.get_method_list():
				var mname: String = m["name"]
				if mname.begins_with("test_"):
					var before: int = _failures.size()
					suite.call(mname)
					print("%s %s::%s" % ["OK  " if _failures.size() == before else "FAIL", f.get_basename(), mname])
	print("\n%d vérifications, %d échec(s)." % [_checks, _failures.size()])
	for f in _failures:
		print("  ✗ " + f)
	quit(0 if _failures.is_empty() else 1)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	_checks += 1
	if got != want:
		_failures.append("%s (obtenu %s, attendu %s)" % [msg, str(got), str(want)])


func rng_seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func mk(weapon: String = "hache", side: String = "p", hex: Vector2i = Vector2i.ZERO) -> Unit:
	var u := Unit.new()
	u.id = Unit.alloc_id()
	u.unit_name = "U%d" % u.id
	u.side = side
	u.faction = side
	u.weapon = weapon
	u.melee_skill = 55
	u.ranged_skill = 60
	u.melee_def = 5
	u.ranged_def = 5
	u.body = "tunique"
	u.hp_max = 60
	u.hp = 60
	u.arm_b = 20
	u.fat_max = 100
	u.resolve = 50
	u.initiative = 100
	u.hex = hex
	u.ap = 9
	return u


func new_game(seed_value: int) -> Node:
	var g: Node = load("res://autoload/Game.gd").new()
	g.autosave = false
	g.random_events = false
	g.new_game(seed_value)
	return g


# --- Hexagones ---

func test_hex() -> void:
	eq(Hex.distance(Vector2i(0, 0), Vector2i(2, -1)), 2, "distance (2,-1)")
	eq(Hex.distance(Vector2i(0, 0), Vector2i(3, 0)), 3, "distance en ligne")
	eq(Hex.distance(Vector2i(1, 1), Vector2i(1, 1)), 0, "distance nulle")
	var n: Array[Vector2i] = Hex.neighbors(Vector2i(4, 4))
	eq(n.size(), 6, "6 voisins")
	for h in n:
		eq(Hex.distance(Vector2i(4, 4), h), 1, "voisin à distance 1")
	for r in 9:
		for c in 12:
			var h: Vector2i = Hex.from_col_row(c, r)
			eq(Hex.column(h), c, "colonne aller-retour")
			eq(Hex.from_pixel(Hex.to_pixel(h, 30.0), 30.0), h, "pixel aller-retour %s" % str(h))


# --- Formules d'unité ---

func test_unit_formulas() -> void:
	var u: Unit = mk()
	u.head = "heaume"
	u.body = "mailles"
	u.shield = true
	eq(u.weight(), 10 + 14 + 4, "poids tête+corps+bouclier")
	eq(u.fat_max_eff(), 100 - 28, "endurance effective")
	u.fat = 12
	eq(u.ini_eff(), 100 - 28 - 12, "initiative effective")
	eq(u.move_fat(), 2 + 2, "fatigue par case (poids 28)")
	u.shield = false
	u.head = "none"
	u.body = "tunique"
	eq(u.move_fat(), 2, "fatigue par case (poids 0)")


# --- Chance de toucher ---

func test_hit_chance() -> void:
	var a: Unit = mk("hache", "p", Vector2i(0, 0))
	var d: Unit = mk("hache", "e", Vector2i(1, 0))
	var all: Array = [a, d]
	eq(CombatRules.hit_chance(a, d, all), 50, "55 - 5")
	d.shield = true
	eq(CombatRules.hit_chance(a, d, all), 35, "bouclier +15")
	d.shield_wall = true
	eq(CombatRules.hit_chance(a, d, all), 15, "mur de boucliers +20")
	d.shield = false
	d.shield_wall = false
	d.morale = 1
	eq(CombatRules.hit_chance(a, d, all), 65, "cible brisée : défense −15")
	d.morale = 3
	a.morale = 4
	eq(CombatRules.hit_chance(a, d, all), 60, "attaquant confiant +10")
	a.morale = 0
	eq(CombatRules.hit_chance(a, d, all), 20, "attaquant en fuite −30")
	a.morale = 3
	var ally: Unit = mk("hache", "p", Vector2i(1, 1))
	eq(ally.hex != d.hex and Hex.distance(ally.hex, d.hex) == 1, true, "allié adjacent à la cible")
	all.append(ally)
	eq(CombatRules.hit_chance(a, d, all), 55, "encerclement +5")
	d.melee_def = 90
	eq(CombatRules.hit_chance(a, d, all), 5, "plancher à 5 %")
	d.melee_def = -90
	eq(CombatRules.hit_chance(a, d, all), 95, "plafond à 95 %")
	# Distance
	var archer: Unit = mk("arc", "p", Vector2i(0, 0))
	var t: Unit = mk("hache", "e", Vector2i(4, 0))
	eq(CombatRules.hit_chance(archer, t, [archer, t]), 60 - 5 - 3 * 2, "arc à 4 cases")
	t.hex = Vector2i(1, 0)
	eq(CombatRules.hit_chance(archer, t, [archer, t]), 60 - 5 - 10, "arc au contact −10")
	t.hex = Vector2i(3, 0)
	t.shield = true
	eq(CombatRules.hit_chance(archer, t, [archer, t]), 60 - (5 + 25) - 3, "arc contre bouclier")
	# Fourche : portée 2
	var f: Unit = mk("fourche", "p", Vector2i(0, 0))
	var t2: Unit = mk("hache", "e", Vector2i(2, 0))
	f.ap = 9
	check(CombatRules.can_attack(f, t2), "fourche frappe à 2 cases")
	t2.hex = Vector2i(3, 0)
	check(not CombatRules.can_attack(f, t2), "fourche pas à 3 cases")
	t2.hex = Vector2i(1, 0)
	f.ap = 5
	check(not CombatRules.can_attack(f, t2), "fourche (6 PA) avec 5 PA")


# --- Dégâts ---

func test_damage() -> void:
	var a: Unit = mk("hache")
	for s in 40:
		var d: Unit = mk("hache", "e")
		d.arm_b = 0
		d.arm_h = 0
		var dmg: Dictionary = CombatRules.roll_damage(a, d, rng_seeded(s))
		eq(dmg["armor"], 0, "sans armure : rien à l'armure")
		var lo: float = 30 * (1.5 if dmg["head"] else 1.0) - 0.5
		var hi: float = 45 * (1.5 if dmg["head"] else 1.0) + 0.5
		check(dmg["hp"] >= lo and dmg["hp"] <= hi, "sans armure : tout en PV (%s)" % str(dmg))
	# Avec armure : on rejoue le même tirage et on applique la formule du prototype.
	for s in 40:
		var d: Unit = mk("hache", "e")
		d.arm_b = 100
		d.arm_h = 100
		var dmg: Dictionary = CombatRules.roll_damage(a, d, rng_seeded(s))
		var r: RandomNumberGenerator = rng_seeded(s)
		var head: bool = r.randf() < 0.25
		var raw: float = float(r.randi_range(30, 45)) * (1.5 if head else 1.0)
		var ad: float = raw * 1.4
		var arm_d: float = minf(100.0, ad)
		var hp_d: float = maxf(0.0, raw * 0.1 - 10.0)
		if ad > 100.0:
			hp_d += (ad - 100.0) / 1.4 * 0.9
		eq(dmg["head"], head, "zone touchée")
		eq(dmg["armor"], roundi(arm_d), "dégâts d'armure")
		eq(dmg["hp"], roundi(hp_d), "dégâts de PV")
	# Application
	var v: Unit = mk()
	v.arm_b = 50
	v.arm_h = 30
	CombatRules.apply_damage(v, {"head": false, "hp": 7, "armor": 80})
	eq(v.arm_b, 0, "armure corps plancher à 0")
	eq(v.hp, 53, "PV déduits")
	CombatRules.apply_damage(v, {"head": true, "hp": 3, "armor": 10})
	eq(v.arm_h, 20, "armure tête")


# --- Moral ---

func test_morale() -> void:
	var r: RandomNumberGenerator = rng_seeded(42)
	var fails: int = 0
	for i in 2000:
		var u: Unit = mk()
		u.resolve = 50
		if CombatRules.morale_test_fails(u, 0, r):
			fails += 1
			eq(u.morale, 2, "un cran perdu")
	check(fails > 850 and fails < 1150, "test de moral à 50 pct (%d/2000)" % fails)
	var sure: Unit = mk()
	sure.resolve = 100
	var lost: int = 0
	for i in 500:
		if CombatRules.morale_test_fails(sure, 0, r):
			lost += 1
	check(lost > 0 and lost < 60, "plafond à 95 pct : quelques échecs (%d/500)" % lost)
	var fled: Unit = mk()
	fled.morale = 0
	check(not CombatRules.morale_test_fails(fled, -90, r), "pas de test en fuite")
	var up: Unit = mk()
	up.resolve = 200
	up.morale = 3
	check(not CombatRules.morale_rally_up(up, r) or up.morale == 4, "remontée cohérente")
	eq(up.morale, 4, "résolution énorme : remonte")
	check(not CombatRules.morale_rally_up(up, r), "pas au-delà de Confiant")


# --- Déplacements ---

func _open_field(w: int = 12, h: int = 9) -> Dictionary:
	var cells: Dictionary = {}
	for r in h:
		for c in w:
			cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	return cells


func test_pathfinding() -> void:
	var cells: Dictionary = _open_field()
	var u: Unit = mk("hache", "p", Hex.from_col_row(5, 4))
	var reach: Dictionary = Pathfinding.reachable(u, cells, [u])
	var far: int = 0
	for k in reach:
		far = maxi(far, int(reach[k]["s"]))
		check(Hex.distance(u.hex, k) == int(reach[k]["s"]), "terrain libre : chemin le plus court")
	eq(far, 4, "9 PA = 4 cases")
	u.ap = 5
	eq(_max_steps(Pathfinding.reachable(u, cells, [u])), 2, "5 PA = 2 cases")
	u.ap = 9
	u.body = "brigandine"  # poids 22 : 4 de fatigue par case
	u.fat_max = 100  # endurance effective 78
	u.fat = 70
	eq(_max_steps(Pathfinding.reachable(u, cells, [u])), 2, "limité par la fatigue (8 restants / 4)")
	u.body = "tunique"
	u.fat = 0
	# Obstacles et occupation
	var blocker: Unit = mk("hache", "p", u.hex + Vector2i(1, 0))
	reach = Pathfinding.reachable(u, cells, [u, blocker])
	check(not reach.has(blocker.hex), "case occupée non atteignable")
	cells[u.hex + Vector2i(-1, 0)]["t"] = "tree"
	reach = Pathfinding.reachable(u, cells, [u])
	check(not reach.has(u.hex + Vector2i(-1, 0)), "arbre bloquant")
	cells[u.hex + Vector2i(-1, 0)]["t"] = "g"
	# Zone de contrôle : on peut entrer à côté d'un ennemi, pas traverser.
	var foe: Unit = mk("hache", "e", u.hex + Vector2i(3, 0))
	reach = Pathfinding.reachable(u, cells, [u, foe])
	var adj: Vector2i = u.hex + Vector2i(2, 0)
	check(reach.has(adj), "entrée dans la zone de contrôle permise")
	for k in reach:
		var p: Variant = reach[k]["p"]
		if p != null and p != u.hex:
			check(not Hex.neighbors(foe.hex).has(p), "on ne traverse pas la zone de contrôle")
	# Un tireur n'exerce pas de zone de contrôle.
	var archer: Unit = mk("arc", "e", u.hex + Vector2i(3, 0))
	reach = Pathfinding.reachable(u, cells, [u, archer])
	var through: bool = false
	for k in reach:
		if reach[k]["p"] != null and Hex.neighbors(archer.hex).has(reach[k]["p"]):
			through = true
	check(through, "pas de zone de contrôle pour un archer")
	# Chemin
	var target: Vector2i = u.hex + Vector2i(0, -3)
	var reach2: Dictionary = Pathfinding.reachable(u, cells, [u])
	var path: Array[Vector2i] = Pathfinding.path_to(reach2, target)
	eq(path.size(), 3, "longueur du chemin")
	eq(path[path.size() - 1], target, "le chemin finit sur la cible")


func _max_steps(reach: Dictionary) -> int:
	var m: int = 0
	for k in reach:
		m = maxi(m, int(reach[k]["s"]))
	return m


# --- Bataille ---

func _roster(n: int, seed_value: int) -> Array:
	var r: RandomNumberGenerator = rng_seeded(seed_value)
	var out: Array = []
	var keys: Array = Data.BG.keys()
	for i in n:
		out.append(Contracts.make_merc(keys[i % keys.size()], r, []))
	return out


func _contract(foes: Array) -> Dictionary:
	return {"type": "b", "d": 1, "foes": foes, "title": "Test", "desc": "", "days": 1, "employer": "x", "pay": 400}


func test_battle_setup() -> void:
	var s: BattleState = BattleState.create(_contract(["brigand", "brigand", "archer", "chef"]), _roster(10, 3), rng_seeded(5))
	eq(s.units.size(), 8 + 4, "8 combattants + ennemis")
	var seen: Dictionary = {}
	for u in s.units:
		check(not seen.has(u.hex), "déploiements distincts")
		seen[u.hex] = true
		eq(s.cells[u.hex]["t"], "g", "unité sur l'herbe")
		check(Hex.column(u.hex) <= 1 if u.side == "p" else Hex.column(u.hex) >= 10, "camp de départ")
		eq(u.morale, 3, "moral de départ")
		eq(u.ap, 9, "9 PA")
	eq(s.round_no, 1, "manche 1")
	for i in range(1, s.queue.size()):
		check(s.queue[i - 1].ini_eff() >= s.queue[i].ini_eff(), "file triée par initiative")
	# Terrain : bloquant seulement au milieu
	for h in s.cells:
		if s.cells[h]["t"] != "g":
			var c: int = int(s.cells[h]["c"])
			check(c >= 3 and c <= 8, "obstacles au centre")
	# Tour : attendre renvoie en fin de file
	var first: Unit = s.next_turn()
	eq(s.current, first, "unité courante")
	var n: int = s.queue.size()
	s.wait(first)
	eq(s.queue.size(), n + 1, "attendre : retour en file")
	eq(s.queue[s.queue.size() - 1], first, "attendre : en dernier")
	# Début de tour : fatigue -15, mur retiré, 9 PA
	var u2: Unit = s.queue[0]
	u2.fat = 40
	u2.shield_wall = true
	u2.ap = 2
	s.next_turn()
	eq(u2.fat, 25, "fatigue −15")
	eq(u2.ap, 9, "PA restaurés")
	check(not u2.shield_wall, "mur de boucliers retiré")
	# Victoire / défaite
	for u in s.units:
		if u.side == "e":
			u.morale = 0
	check(s.check_end(), "fin si plus d'ennemi combattant")
	eq(s.over, "win", "victoire")
	var s2: BattleState = BattleState.create(_contract(["brigand"]), _roster(3, 1), rng_seeded(1))
	for u in s2.units:
		if u.side == "p":
			u.dead = true
	s2.check_end()
	eq(s2.over, "lose", "défaite")


func test_free_attack() -> void:
	var s: BattleState = BattleState.create(_contract(["brigand"]), _roster(1, 2), rng_seeded(9))
	var a: Unit = s.units[0]
	var f: Unit = s.units[1]
	s.cells = _open_field()
	a.hex = Hex.from_col_row(5, 4)
	f.hex = Hex.from_col_row(6, 4)
	eq(s.free_attackers(a).size(), 1, "un ennemi au contact")
	var start_ap: int = a.ap
	var start_hex: Vector2i = a.hex
	var path: Array[Vector2i] = [Hex.from_col_row(4, 4)]
	var moved: bool = s.move_along(a, path)
	if moved:
		eq(a.hex, path[0], "déplacement effectué")
		eq(a.ap, start_ap - 2, "2 PA par case")
		eq(a.fat, a.move_fat(), "fatigue de déplacement")
	else:
		check(a.dead or a.hex == start_hex, "déplacement annulé ou mort")
	eq(f.ap, 9, "l'attaque gratuite ne coûte pas de PA")


func test_ai_battles() -> void:
	for seed_value in 12:
		var foes: Array = [["brigand", "brigand", "archer"], ["goule", "goule", "vorace"], ["brigand", "archer", "balafre", "chef"]][seed_value % 3]
		var s: BattleState = BattleState.create(_contract(foes), _roster(8, seed_value), rng_seeded(seed_value))
		var turns: int = 0
		while s.over == "" and s.round_no < 120 and turns < 6000:
			var u: Unit = s.next_turn()
			if u == null:
				break
			s.play_ai_turn(u)
			turns += 1
		check(s.over == "win" or s.over == "lose", "la bataille %d se termine (manche %d, over=%s)" % [seed_value, s.round_no, s.over])
		for u in s.units:
			check(u.hp <= u.hp_max and u.arm_h >= 0 and u.arm_b >= 0 and u.fat >= 0, "valeurs bornées")
			if u.is_live():
				check(not Pathfinding.blocked(s.cells, u.hex), "unité sur une case praticable")
		var occ: Dictionary = {}
		for u in s.units:
			if u.is_live():
				check(not occ.has(u.hex), "deux unités sur la même case")
				occ[u.hex] = true


func test_battle_serialization() -> void:
	var s: BattleState = BattleState.create(_contract(["brigand", "archer", "balafre"]), _roster(6, 4), rng_seeded(8))
	for i in 12:
		var u: Unit = s.next_turn()
		if u == null:
			break
		s.play_ai_turn(u)
	var json: String = JSON.stringify(s.to_dict())
	var back: BattleState = BattleState.from_dict(JSON.parse_string(json), rng_seeded(1))
	eq(back.units.size(), s.units.size(), "nombre d'unités")
	eq(back.round_no, s.round_no, "manche")
	eq(back.queue.size(), s.queue.size(), "file")
	eq(back.over, s.over, "état final")
	eq(back.cells.size(), s.cells.size(), "cases")
	eq(back.corpses.size(), s.corpses.size(), "cadavres")
	for i in s.units.size():
		var a: Unit = s.units[i]
		var b: Unit = back.units[i]
		eq(b.hex, a.hex, "position")
		eq(b.hp, a.hp, "PV")
		eq(b.arm_b, a.arm_b, "armure")
		eq(b.morale, a.morale, "moral")
		eq(b.weapon, a.weapon, "arme")
		eq(b.dead, a.dead, "mort")
	if s.current:
		eq(back.current.id, s.current.id, "unité courante")


# --- Carte du monde ---

func _free_dir(w: World, from: Vector2, dist: float) -> Vector2:
	for i in 16:
		var d: Vector2 = Vector2.from_angle(TAU * i / 16.0) * dist
		var clear: bool = true
		for k in 9:  # la ligne droite jusqu'au point doit être libre
			clear = clear and w.passable(from + d * (k / 8.0))
		if clear:
			return d
	return Vector2.ZERO


func test_world() -> void:
	for seed_value in [1, 2, 3, 4, 5]:
		var w: World = World.generate(rng_seeded(seed_value), 0)
		eq(w.settlements.size(), World.CITIES + World.VILLAGES, "lieux (graine %d)" % seed_value)
		var cities: int = 0
		for s in w.settlements:
			if s["kind"] == "city":
				cities += 1
			check(w.passable(w.settlement_pos(s)), "lieu sur terrain praticable")
			check(not w.find_path(w.settlement_pos(w.settlements[0]), w.settlement_pos(s)).is_empty(), "%s est atteignable" % s["name"])
		eq(cities, World.CITIES, "villes")
		eq(w.player_pos, w.settlement_pos(w.settlements[0]), "départ dans la première ville")
		eq(w.parties.size(), World.MAX_PARTIES, "bandes errantes")
		for p in w.parties:
			check(w.passable(w.party_pos(p)) and p["foes"].size() > 0, "bande valide")
			check(w.party_pos(p).distance_to(w.player_pos) >= 220.0, "bande loin du départ")
	var w2: World = World.generate(rng_seeded(9), 0)
	# Déplacement : le temps dépend du terrain.
	var target: Dictionary = w2.settlements[1]
	var tp: Vector2 = w2.settlement_pos(target)
	check(w2.set_destination(tp, {"kind": "settlement", "id": target["id"]}), "chemin vers la ville")
	var straight: float = w2.player_pos.distance_to(tp)
	var total: float = 0.0
	var guard: int = 0
	while not w2.path.is_empty() and guard < 400:
		total += w2.step_player(0.25)
		guard += 1
	eq(w2.player_pos, tp, "arrivée à destination")
	check(total >= straight / World.DAY_PX * World.ROAD_COST - 0.001,"au moins la durée en ligne droite (%.2f jours)" % total)
	check(total <= straight / World.DAY_PX * 3.0, "pas absurdement long")
	eq(w2.step_player(1.0), 0.0, "pas de temps consommé sans chemin")
	check(not w2.set_destination(Vector2(5, 5), {}), "destination infranchissable refusée")
	# Bandes : une bande agressive poursuit la compagnie, une bande au repos est ignorée.
	var p: Dictionary = w2.parties[0]
	p["aggressive"] = true
	p["cooldown"] = 0.0
	var off: Vector2 = _free_dir(w2, w2.player_pos, 100.0)
	p["x"] = (w2.player_pos + off).x
	p["y"] = (w2.player_pos + off).y
	var before: float = w2.party_pos(p).distance_to(w2.player_pos)
	w2.update_parties(0.2)
	check(w2.party_pos(p).distance_to(w2.player_pos) < before, "la bande agressive se rapproche")
	p["x"] = w2.player_pos.x + 3.0
	p["y"] = w2.player_pos.y
	eq(w2.encounter(), p, "contact : rencontre")
	p["cooldown"] = 2.0
	check(w2.encounter().is_empty(), "bande au repos : pas de rencontre")
	for i in 60:
		w2.update_parties(0.5)
	for q in w2.parties:
		check(w2.passable(w2.party_pos(q)), "les bandes restent sur un terrain praticable")
	# Sérialisation
	var back: World = World.from_dict(JSON.parse_string(JSON.stringify(w2.to_dict())), rng_seeded(1))
	eq(back.terrain, w2.terrain, "terrain")
	eq(back.settlements.size(), w2.settlements.size(), "lieux")
	eq(back.parties.size(), w2.parties.size(), "bandes")
	eq(back.player_pos, w2.player_pos, "position")
	check(not back.find_path(back.player_pos, back.settlement_pos(back.settlements[2])).is_empty(), "chemins après rechargement")


# --- Contrats et lieux ---

func test_contracts() -> void:
	var g: Node = new_game(11)
	for s in g.world.settlements:
		var shop: Dictionary = Data.SHOPS[s["kind"]]
		check(s["contracts"].size() >= 1 and s["contracts"].size() <= int(shop["contracts"]), "contrats de %s" % s["name"])
		for c in s["contracts"]:
			check(c["d"] >= 1 and c["d"] <= 3, "danger 1-3")
			var from: Vector2 = g.world.settlement_pos(s)
			var to := Vector2(c["tx"], c["ty"])
			var dist: float = from.distance_to(to)
			if Contracts.is_transport(c):  # escorte / livraison : testées dans suites/suite_monde.gd
				check(dist >= 100.0, "destination à bonne distance (%d)" % dist)
			else:
				check(c["pay"] >= c["d"] * 320 * 0.89, "prime >= danger x 320 (réputation ±10 %)")
				if c["type_contract"] == "kill":
					eq(c["foes"].size(), Contracts.foes_for(c["type"], c["d"]).size(), "effectif ennemi")
				check(dist >= 100.0 and dist <= 500.0, "cible à bonne distance (%d)" % dist)
			check(not g.world.find_path(from, to).is_empty(), "cible atteignable")
		var allowed: Array = []
		for k in shop["recruits"]:
			allowed.append(Data.BG[k]["n"])
		eq(s["recruits"].size(), 4 if s["kind"] == "city" else 3, "recrues de %s" % s["name"])
		for r in s["recruits"]:
			check(allowed.has(r["u"].background), "origine proposée par ce lieu")
			check(r["price"] > 0 and r["price"] % 5 == 0, "prix multiple de 5")
	var r2: RandomNumberGenerator = rng_seeded(3)
	var foe: Unit = Contracts.make_foe("chef", r2)
	check(foe.leader and foe.side == "e" and foe.xp_value == 60, "chef brigand")
	eq(foe.arm_h, 160, "armure du heaume")
	eq(foe.arm_b, 130, "armure du haubert")
	var m: Unit = Contracts.make_merc("milicien", r2, [])
	check(m.shield and m.weapon == "lance", "milicien : lance et bouclier")
	g.free()


# --- Camp (dans un lieu) ---

func _village_id(g: Node) -> String:
	for s in g.world.settlements:
		if s["kind"] == "village":
			return s["id"]
	return ""


func test_game_camp() -> void:
	var g: Node = new_game(21)
	eq(g.gold, 800, "or de départ")
	eq(g.roster.size(), 5, "5 hommes")
	check(g.in_settlement() and g.settlement()["kind"] == "city", "départ dans une ville")
	var w: int = g.wages()
	check(w > 0, "solde > 0")
	g.rest()
	eq(g.day, 2, "repos : +1 jour")
	eq(g.gold, 800 - w, "repos : solde payée")
	var m: Unit = g.roster[0]
	m.arm_b = 0
	var cost: int = g.repair_cost()
	eq(cost, int(ceil(m.body_armor_max() * 0.5)), "coût de réparation 0,5/point")
	var gold_before: int = g.gold
	g.repair()
	eq(g.gold, gold_before - cost, "réparation payée")
	eq(m.arm_b, m.body_armor_max(), "armure réparée")
	# Recrutement
	g.gold = 5000
	var recs: Array = g.settlement()["recruits"]
	var n: int = recs.size()
	var price: int = recs[0]["price"]
	check(g.hire(0), "engagement")
	eq(g.roster.size(), 6, "6 hommes")
	eq(g.settlement()["recruits"].size(), n - 1, "recrue retirée")
	eq(g.gold, 5000 - price, "prix payé")
	while g.roster.size() < 10:
		g.settlement()["recruits"].append({"u": Contracts.make_merc("mendiant", g.rng, []), "price": 10})
		g.hire(g.settlement()["recruits"].size() - 1)
	g.settlement()["recruits"].append({"u": Contracts.make_merc("mendiant", g.rng, []), "price": 10})
	check(not g.hire(g.settlement()["recruits"].size() - 1), "effectif maximal de 10")
	# Marché de la ville : tout est en vente, au prix du lieu.
	var e: Unit = g.roster[1]
	g.gold = 1000
	var epee: int = g.price_of(650)
	check(g.buy(e, "weapon", "epee"), "achat d'arme")
	eq(g.gold, 1000 - epee, "prix de l'épée dans ce lieu")
	eq(e.weapon, "epee", "arme équipée")
	check(g.buy(e, "shield"), "achat de bouclier (arme à une main)")
	g.gold = 1000
	check(g.buy(e, "weapon", "arc"), "achat d'arc")
	check(not e.shield, "arc à deux mains : bouclier retiré")
	check(not g.buy(e, "shield"), "pas de bouclier avec une arme à deux mains")
	g.gold = 100
	check(not g.buy(e, "body", "brigandine"), "or insuffisant")
	g.gold = 2000
	check(g.buy(e, "body", "brigandine"), "achat de brigandine")
	eq(e.arm_b, 190, "armure neuve")
	# Un village vend moins, une route ne vend rien.
	g.enter_settlement(_village_id(g))
	g.gold = 5000
	check(not g.in_stock("weapon", "epee"), "pas d'épée au village")
	check(not g.buy(e, "weapon", "epee"), "achat refusé au village")
	check(g.in_stock("weapon", "lance"), "lance au village")
	check(g.buy(e, "weapon", "lance"), "achat au village")
	g.leave_settlement()
	check(not g.buy(e, "weapon", "gourdin"), "pas de marchand sur la route")
	check(not g.hire(0), "pas de recrutement sur la route")
	g.gold = 5000
	g.repair()
	eq(g.gold, 5000, "pas de réparation sur la route")
	g.enter_settlement(g.world.settlements[0]["id"])
	# Niveaux
	var v: Unit = g.roster[2]
	v.level = 1
	v.pending = 0
	v.xp = 39
	g.level_check(v)
	eq(v.level, 1, "39 XP : niveau 1")
	v.xp = 40
	g.level_check(v)
	eq([v.level, v.pending], [2, 1], "40 XP : niveau 2")
	v.xp = 190
	g.level_check(v)
	eq([v.level, v.pending], [4, 3], "190 XP : niveau 4")
	var rolls: Dictionary = g.roll_promotion()
	for k in Data.PROMO_RANGES:
		check(rolls[k] >= Data.PROMO_RANGES[k][0] and rolls[k] <= Data.PROMO_RANGES[k][1], "gain %s dans sa plage" % k)
	check(not g.apply_promotion(v, rolls, ["hp_max", "resolve"]), "il faut choisir 3 attributs")
	var hp_before: int = v.hp_max
	var res_before: int = v.resolve
	check(g.apply_promotion(v, rolls, ["hp_max", "resolve", "melee_def"]), "promotion")
	eq(v.hp_max, hp_before + rolls["hp_max"], "PV max")
	eq(v.resolve, res_before + rolls["resolve"], "détermination")
	eq(v.pending, 2, "promotion consommée")
	# Désertion faute de paie
	g.gold = 0
	var count: int = g.roster.size()
	g.rest()
	eq(g.roster.size(), count - 1, "un homme déserte")
	eq(g.gold, 0, "or ramené à 0")
	g.free()


# --- Voyage, contrats et batailles ---

func _kill_enemies(b: BattleState) -> void:
	for u in b.units:
		if u.side == "e":
			u.morale = 0
	b.check_end()


func test_game_battle_results() -> void:
	var g: Node = new_game(33)
	g.gold = 5000
	var home: Dictionary = g.settlement()
	var n_contracts: int = home["contracts"].size()
	var c: Dictionary = home["contracts"][0]
	check(g.accept_contract(0), "contrat accepté")
	eq(home["contracts"].size(), n_contracts - 1, "contrat retiré du tableau")
	eq(g.active_contract["title"], c["title"], "contrat actif")
	check(not g.accept_contract(0), "un seul contrat à la fois")
	g.leave_settlement()
	eq(g.location, "", "sur la route")
	# Voyage jusqu'à la cible
	g.world.parties.clear()
	check(g.world.set_destination(g.contract_target(), {"kind": "target"}), "route vers la cible")
	var gold_start: int = g.gold
	var day_start: int = g.day
	var ev: Dictionary = {}
	var guard: int = 0
	while ev.get("type", "") == "" and guard < 500:
		ev = g.map_step(0.25)
		guard += 1
	eq(ev.get("type", ""), "target", "arrivée sur les lieux du contrat")
	check(g.day > day_start, "des jours ont passé")
	check(g.gold < gold_start, "la solde est payée en route")
	g.engage_target()
	check(g.battle != null, "bataille lancée")
	var b: BattleState = g.battle
	eq(b.units.size(), 5 + c["foes"].size(), "unités engagées")
	var victim: Unit = null
	var survivor: Unit = null
	for u in b.units:
		if u.side == "p":
			if victim == null:
				victim = u
			elif survivor == null:
				survivor = u
	check(g.member(victim.id) != victim, "la bataille travaille sur des copies")
	var dead_name: String = g.member(victim.id).unit_name
	victim.dead = true
	survivor.hp = 5
	survivor.arm_b = 3
	survivor.kills = 2
	b.xp[survivor.id] = 10
	var xp_before: int = g.member(survivor.id).xp
	_kill_enemies(b)
	eq(b.over, "win", "victoire")
	var gold_before: int = g.gold
	var day_before: int = g.day
	var ob_gold: int = int(b.objective_bonus()["gold"])
	g.finish_battle()
	eq(g.battle, null, "bataille terminée")
	eq(g.roster.size(), 4, "un mort de moins")
	eq(g.fallen[0]["name"], dead_name, "nom au mémorial")
	eq(g.gold, gold_before + c["pay"] + ob_gold, "prime versée (+ objectifs)")
	eq(g.day, day_before, "pas de jour perdu au retour")
	eq(g.renown, 40 * c["d"], "renom")
	check(g.active_contract.is_empty(), "contrat terminé")
	var s: Unit = g.member(survivor.id)
	eq(s.xp, xp_before + 10 + 15 * c["d"], "XP : victimes + 15 x danger")
	eq(s.kills, 2, "victimes reportées")
	eq(s.arm_b, 3, "armure reportée")
	eq(s.hp, 5, "PV reportés")
	# Rencontre avec une bande errante
	g.world.fill_parties(0, 2)
	var party: Dictionary = g.world.parties[0]
	var pid: int = party["id"]
	var renown_before: int = g.renown
	gold_before = g.gold
	g.engage_party(pid)
	eq(g.battle.contract["kind"], "encounter", "embuscade")
	_kill_enemies(g.battle)
	g.finish_battle()
	check(g.world.party_by_id(pid).is_empty(), "bande dispersée")
	eq(g.renown, renown_before + 15 * party["d"], "renom de l'embuscade")
	eq(g.gold, gold_before, "pas de prime pour une embuscade")
	# Retraite : la bande reste mais laisse la compagnie respirer.
	var party2: Dictionary = g.world.parties[0]
	g.engage_party(party2["id"])
	g.battle.end_battle("retreat")
	g.finish_battle()
	check(not g.world.party_by_id(party2["id"]).is_empty(), "la bande survit à la retraite")
	check(g.world.party_by_id(party2["id"])["cooldown"] > 0.0, "temps de répit")
	# Contrat perdu
	g.enter_settlement(g.world.settlements[0]["id"])
	g.accept_contract(0)
	g.leave_settlement()
	g.start_battle(g.active_contract)
	g.battle.end_battle("lose")
	g.finish_battle()
	check(g.active_contract.is_empty(), "contrat perdu")
	g.free()


func test_game_travel() -> void:
	var g: Node = new_game(40)
	g.world.parties.clear()
	var dest: Dictionary = g.world.settlements[1]
	g.leave_settlement()
	check(g.world.set_destination(g.world.settlement_pos(dest), {"kind": "settlement", "id": dest["id"]}), "route vers %s" % dest["name"])
	var day0: int = g.day
	var gold0: int = g.gold
	var ev: Dictionary = {}
	var guard: int = 0
	while ev.get("type", "") == "" and guard < 600:
		ev = g.map_step(0.2)
		guard += 1
	eq(ev.get("type", ""), "settlement", "arrivée")
	eq(g.location, dest["id"], "on est entré dans le lieu")
	check(g.day > day0, "le temps a passé")
	eq(g.gold, gold0 - g.wages() * (g.day - day0), "solde payée chaque jour de route")
	eq(g.map_step(1.0), {}, "pas de déplacement dans un lieu")
	g.leave_settlement()
	var free_pt: Vector2 = g.world.random_target(g.world.player_pos, 80.0, 200.0)
	check(g.world.set_destination(free_pt, {"kind": "point"}), "route libre")
	guard = 0
	while not g.world.path.is_empty() and guard < 300:
		g.map_step(0.2)
		guard += 1
	eq(g.location, "", "toujours sur la route")
	# Une bande agressive finit par rattraper une compagnie immobile.
	g.world.parties.clear()
	g.world.fill_parties(0, 1)
	var p: Dictionary = g.world.parties[0]
	p["aggressive"] = true
	var off: Vector2 = _free_dir(g.world, g.world.player_pos, 120.0)
	p["x"] = (g.world.player_pos + off).x
	p["y"] = (g.world.player_pos + off).y
	ev = {}
	guard = 0
	g.gold = 99999
	while ev.get("type", "") != "encounter" and guard < 200:
		g.advance_time(0.05)  # le temps ne passe pas tout seul : on le fait passer
		ev = g.map_step(0.0)
		guard += 1
	eq(ev.get("type", ""), "encounter", "la bande rattrape la compagnie")
	g.free()


func test_game_save_roundtrip() -> void:
	var g: Node = new_game(77)
	g.accept_contract(0)
	g.leave_settlement()
	g.world.set_destination(g.contract_target(), {"kind": "target"})
	g.map_step(0.3)
	g.start_battle(g.active_contract)
	for i in 6:
		var u: Unit = g.battle.next_turn()
		g.battle.play_ai_turn(u)
	var json: String = JSON.stringify(g.to_dict())
	var g2: Node = load("res://autoload/Game.gd").new()
	g2.autosave = false
	g2.from_dict(JSON.parse_string(json))
	eq(g2.gold, g.gold, "or")
	eq(g2.day, g.day, "jour")
	eq(g2.location, g.location, "lieu")
	eq(g2.roster.size(), g.roster.size(), "compagnie")
	eq(g2.roster[0].unit_name, g.roster[0].unit_name, "nom")
	eq(g2.active_contract["title"], g.active_contract["title"], "contrat actif")
	check(absf(g2.active_contract["tx"] - g.active_contract["tx"]) < 0.01, "cible du contrat")
	eq(g2.world.settlements.size(), g.world.settlements.size(), "lieux")
	eq(g2.world.settlements[1]["recruits"].size(), g.world.settlements[1]["recruits"].size(), "recrues")
	eq(g2.world.settlements[1]["contracts"].size(), g.world.settlements[1]["contracts"].size(), "contrats")
	eq(g2.world.player_pos, g.world.player_pos, "position")
	check(g2.battle != null, "bataille en cours restaurée")
	eq(g2.battle.units.size(), g.battle.units.size(), "unités de la bataille")
	eq(g2.battle.round_no, g.battle.round_no, "manche")
	eq(g2.battle.contract["pay"], g.battle.contract["pay"], "prime")
	g.free()
	g2.free()
