extends RefCounted
## Formation : emplacements, déplacement/échange, normalisation, sauvegarde, déploiement sur le plateau (logique pure).
var t

const TYPES: Array[String] = ["pitched", "ambush", "convoy", "siege", "night"]


func _contract(btype: String, biome: String = "plain") -> Dictionary:
	return {"kind": "contract", "type": "b", "type_contract": "kill", "d": 2, "foes": ["brigand", "archer", "brigand", "balafre"], "title": "T", "desc": "",
		"days": 1, "employer": "x", "pay": 400, "biome": biome, "battle_type": btype}


func _roster(n: int, seed_value: int = 4) -> Array:
	var out: Array = []
	var weapons: Array[String] = ["hache", "arc", "lance", "masse", "arc", "gourdin", "fourche", "epee"]
	for i in n:
		out.append(t.mk(weapons[(i + seed_value) % weapons.size()], "p"))
	return out


func _hexes(s: BattleState) -> Dictionary:
	var out: Dictionary = {}
	for u in s.units:
		if u.side == "p" and not u.immobile:
			out[u.id] = u.hex
	return out


func test_slots_constants() -> void:
	t.eq(Formation.SLOTS, 36, "36 emplacements")
	t.check(Formation.is_front(0) and Formation.is_front(8) and Formation.is_mid(9) and Formation.is_back(18) and Formation.is_reserve(27) and Formation.is_reserve(35), "bornes des rangées")
	t.check(not Formation.is_valid_slot(36) and not Formation.is_valid_slot(-1), "emplacements invalides")
	t.eq(Formation.hex_for_slot(27, 12, 9), Formation.NO_HEX, "la réserve n'a pas de case")
	t.eq(Formation.hex_for_slot(9 + 4, 12, 9), Hex.from_col_row(1, 4), "rangée du milieu -> colonne 1")
	t.eq(Formation.hex_for_slot(18 + 4, 12, 9), Hex.from_col_row(0, 4), "rangée arrière -> colonne 0")
	t.eq(Formation.hex_for_slot(4, 12, 9), Hex.from_col_row(2, 4), "rangée avant -> colonne 2")
	t.eq(Formation.hex_for_slot(8, 12, 5), Hex.from_col_row(2, 4), "ligne écrêtée sur un plateau bas")
	t.check(Formation.slot_label(0).begins_with("Rangée avant") and Formation.slot_label(30).begins_with("Réserve"), "libellés")


func test_default_matches_old_deploy() -> void:
	for seed_value in [1, 2, 3, 4, 5, 6, 7]:
		for n in [3, 5, 8, 10, 12]:
			var ros: Array = _roster(n, seed_value)
			var def: Dictionary = Formation.default_slots(ros)
			t.eq(Formation.field_count(def), mini(n, Data.FIGHTERS), "défaut : effectif au combat (n=%d)" % n)
			for ty in TYPES:
				if ty == "convoy":
					continue  # le convoi dégage désormais les arbres/rochers au lieu de poser un homme dessus : cases décalées (voir test_deploy_no_collision)
				var a: BattleState = BattleState.create(_contract(ty), ros, t.rng_seeded(seed_value))
				var b: BattleState = BattleState.create(_contract(ty), ros, t.rng_seeded(seed_value), 3, 1.0, "normal", def)
				t.eq(_hexes(a), _hexes(b), "formation par défaut = déploiement historique (%s, n=%d, graine %d)" % [ty, n, seed_value])
	t.eq(Formation.default_slots([]), {}, "compagnie vide")


func test_move_swap_cap() -> void:
	var ros: Array = _roster(10)
	var s: Dictionary = Formation.default_slots(ros)
	var reserve_id: int = Formation.occupant(s, Formation.RESERVE_START)
	t.check(reserve_id >= 0, "un homme en réserve")
	var full: Dictionary = Formation.move(s, reserve_id, Formation.FRONT_START)
	t.check(not bool(full["ok"]) and str(full["reason"]) != "", "champ plein : refusé avec une raison")
	var fid: int = Formation.field_ids(s)[0]
	var sw: Dictionary = Formation.move(s, reserve_id, int(s[fid]))
	t.check(bool(sw["ok"]), "échange réserve <-> champ permis")
	t.eq(int(sw["slots"][reserve_id]), int(s[fid]), "l'arrivant prend la place")
	t.eq(int(sw["slots"][fid]), int(s[reserve_id]), "l'occupant part à sa place")
	t.eq(Formation.field_count(sw["slots"]), Data.FIGHTERS, "échange : effectif du champ inchangé")
	var out: Dictionary = Formation.move(s, fid, Formation.RESERVE_START + 5)
	t.check(bool(out["ok"]) and Formation.field_count(out["slots"]) == Data.FIGHTERS - 1, "mise en réserve")
	var back_in: Dictionary = Formation.move(out["slots"], reserve_id, Formation.FRONT_START + 8)
	t.check(bool(back_in["ok"]) and Formation.field_count(back_in["slots"]) == Data.FIGHTERS, "il y a de la place : le champ se remplit")
	t.check(not bool(Formation.move(s, fid, 99)["ok"]) and not bool(Formation.move(s, 987654, 3)["ok"]), "emplacement ou homme invalide")
	var one: Dictionary = Formation.default_slots(_roster(1))
	t.check(not bool(Formation.move(one, Formation.field_ids(one)[0], Formation.RESERVE_START)["ok"]), "le dernier combattant ne peut pas partir")
	var sw2: Dictionary = Formation.swap(s, fid, reserve_id)
	t.eq(int(sw2[fid]), int(s[reserve_id]), "swap")
	t.eq(s, Formation.default_slots(ros), "move/swap ne modifient pas l'original")


func test_normalize() -> void:
	var ros: Array = _roster(6)
	var s: Dictionary = Formation.default_slots(ros)
	var gone: Unit = ros.pop_at(2)
	var n1: Dictionary = Formation.normalize(s, ros)
	t.check(not n1.has(gone.id) and n1.size() == 5, "un homme parti est retiré")
	var rookie: Unit = t.mk("hache", "p")
	ros.append(rookie)
	var n2: Dictionary = Formation.normalize(n1, ros)
	t.check(n2.has(rookie.id) and Formation.is_field(int(n2[rookie.id])), "recrue : sur le champ s'il y a de la place")
	var big: Array = _roster(8)
	var sb: Dictionary = Formation.default_slots(big)
	var extra: Unit = t.mk("arc", "p")
	big.append(extra)
	var n3: Dictionary = Formation.normalize(sb, big)
	t.check(Formation.is_reserve(int(n3[extra.id])), "champ plein : la recrue va en réserve")
	var bad: Dictionary = {}
	for u in big:
		bad[u.id] = 10
	bad[big[0].id] = 500
	var n4: Dictionary = Formation.normalize(bad, big)
	t.eq(n4.size(), big.size(), "tous placés")
	var seen: Dictionary = {}
	for id in n4:
		t.check(not seen.has(n4[id]) and Formation.is_valid_slot(int(n4[id])), "emplacements distincts et valides")
		seen[n4[id]] = true
	t.check(Formation.field_count(n4) <= Data.FIGHTERS, "plafond du champ")
	var over: Dictionary = {}
	for i in big.size():
		over[big[i].id] = i
	t.eq(Formation.field_count(Formation.normalize(over, big)), Data.FIGHTERS, "champ écrêté au maximum")


func test_auto_arrange() -> void:
	var ros: Array = _roster(9)
	var s: Dictionary = Formation.default_slots(ros)
	var scrambled: Dictionary = s.duplicate()
	for u in ros:
		if Formation.is_field(int(s[u.id])):
			scrambled[u.id] = Formation.FRONT_START + (int(s[u.id]) * 7) % 9
	scrambled = Formation.normalize(scrambled, ros)
	var auto: Dictionary = Formation.auto_arrange(ros, scrambled)
	for u in ros:
		var sl: int = int(auto[u.id])
		if Formation.is_field(sl):
			t.check(Formation.is_back(sl) if u.is_ranged() else Formation.is_mid(sl), "disposition auto : rôle respecté")
		t.eq(Formation.is_field(sl), Formation.is_field(int(scrambled[u.id])), "disposition auto : même effectif sur le champ")
	t.eq(auto, Formation.auto_arrange(ros, auto), "disposition auto idempotente")


func test_save_and_migration() -> void:
	var g: Node = t.new_game(9)
	var s: Dictionary = g.formation_slots()
	t.eq(s, Formation.default_slots(g.roster), "nouvelle partie : formation par défaut")
	var id0: int = Formation.field_ids(s)[0]
	t.check(g.set_formation_slot(id0, Formation.FRONT_START + 2), "set_formation_slot")
	var d: Dictionary = g.to_dict()
	t.check(d.has("formation") and d["formation"].has(str(id0)), "formation sérialisée")
	var json: Variant = JSON.parse_string(JSON.stringify(d))
	var g2: Node = t.new_game(10)
	g2.from_dict(json)
	t.eq(int(g2.formation_slots()[id0]), Formation.FRONT_START + 2, "formation relue après JSON")
	var old: Dictionary = json.duplicate(true)
	old.erase("formation")
	g2.from_dict(old)
	t.eq(g2.formation_slots(), Formation.default_slots(g2.roster), "ancienne sauvegarde : formation par défaut")
	old["formation"] = "n'importe quoi"
	g2.from_dict(old)
	t.eq(g2.formation_slots(), Formation.default_slots(g2.roster), "formation invalide : défaut")
	old["formation"] = {"abc": 3}
	g2.from_dict(old)
	t.eq(g2.formation_slots(), Formation.default_slots(g2.roster), "clés invalides : défaut")
	var extra: Unit = t.mk("hache", "p")
	g.roster.append(extra)
	t.check(g.formation_slots().has(extra.id), "nouveau venu placé")
	g.dismiss(g.roster[1].id)
	t.eq(g.formation_slots().size(), g.roster.size(), "renvoi : formation à jour")
	g.roster.remove_at(0)
	t.eq(g.formation_slots().size(), g.roster.size(), "mort : formation à jour")
	g.auto_arrange_formation()
	t.eq(g.formation_slots().size(), g.roster.size(), "disposition automatique")


func test_battle_uses_formation() -> void:
	var ros: Array = _roster(8, 2)
	var s: Dictionary = Formation.default_slots(ros)
	var keep: Array[int] = Formation.field_ids(s)
	var benched: int = keep[0]
	var m: Dictionary = Formation.move(s, benched, Formation.RESERVE_START)
	t.check(bool(m["ok"]), "mise en réserve")
	var f: Dictionary = m["slots"]
	var bs: BattleState = BattleState.create(_contract("pitched"), ros, t.rng_seeded(3), 3, 1.0, "normal", f)
	var ids: Array[int] = []
	for u in bs.units:
		if u.side == "p":
			ids.append(u.id)
	t.check(not ids.has(benched) and ids.size() == Data.FIGHTERS - 1, "l'homme en réserve ne combat pas")
	var other: int = keep[1]
	f = Formation.move(f, other, Formation.FRONT_START + 6)["slots"]
	bs = BattleState.create(_contract("pitched"), ros, t.rng_seeded(3), 3, 1.0, "normal", f)
	t.eq(bs.unit_by_id(other).hex, Hex.from_col_row(2, 6), "rangée avant, case 7 -> colonne 2, ligne 6")


func test_deploy_no_collision_all_boards() -> void:
	var biomes: Array = Data.BIOMES.duplicate()
	for seed_value in range(1, 25):
		for ty in TYPES:
			var ros: Array = _roster(8 + seed_value % 3, seed_value)
			var f: Dictionary = Formation.default_slots(ros)
			var r: RandomNumberGenerator = t.rng_seeded(seed_value)
			for id in Formation.field_ids(f):
				f = Formation.move(f, id, r.randi_range(0, 26))["slots"]
			var bs: BattleState = BattleState.create(_contract(ty, str(biomes[seed_value % biomes.size()])), ros, t.rng_seeded(seed_value), 3, 1.0, "normal", f)
			var used: Dictionary = {}
			var ok: bool = true
			var mine: int = 0
			for u in bs.units:
				if used.has(u.hex) or Pathfinding.blocked(bs.cells, u.hex):
					ok = false
				used[u.hex] = true
				if u.side == "p" and not u.immobile:
					mine += 1
			t.check(ok, "aucune collision ni obstacle (%s, graine %d)" % [ty, seed_value])
			t.eq(mine, Formation.field_count(Formation.normalize(f, ros)), "effectif déployé (%s)" % ty)
