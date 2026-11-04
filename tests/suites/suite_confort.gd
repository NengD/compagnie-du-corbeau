extends RefCounted
## Confort de jeu : annulation de déplacement, journal groupé, compte rendu de bataille, lieux visités.
var t  # le lanceur (voir tests/suites/README.md)


func _field() -> Dictionary:
	var cells: Dictionary = {}
	for r in 9:
		for c in 12:
			cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	return cells


func _contract() -> Dictionary:
	return {"type": "b", "d": 1, "foes": ["brigand"], "title": "Test", "desc": "", "days": 1, "employer": "x", "pay": 400}


## Bataille 1 contre 1 sur terrain nu ; `a` (joueur) est l'unité courante.
func _duel(a_col: int, f_col: int) -> Array:
	var r: Array = []
	var rng: RandomNumberGenerator = t.rng_seeded(7)
	for i in 1:
		r.append(Contracts.make_merc("braconnier", rng, []))
	var s: BattleState = BattleState.create(_contract(), r, t.rng_seeded(9))
	s.cells = _field()
	var a: Unit = s.units[0]
	var f: Unit = s.units[1]
	a.hex = Hex.from_col_row(a_col, 4)
	f.hex = Hex.from_col_row(f_col, 4)
	s.current = a
	a.ap = 9
	a.fat = 0
	return [s, a, f]


func test_undo_move() -> void:
	var d: Array = _duel(1, 10)
	var s: BattleState = d[0]
	var a: Unit = d[1]
	var start: Vector2i = a.hex
	t.check(not s.can_undo_move(a), "rien à annuler au départ")
	var path: Array[Vector2i] = [Hex.from_col_row(2, 4), Hex.from_col_row(3, 4)]
	t.check(s.move_along(a, path, true), "déplacement fait")
	t.eq(a.ap, 9 - 4, "4 PA dépensés")
	t.check(a.fat > 0, "fatigue de déplacement")
	t.check(s.can_undo_move(a), "annulation possible")
	t.check(s.undo_move(a), "annulation faite")
	t.eq(a.hex, start, "retour à la case de départ")
	t.eq(a.ap, 9, "PA rendus")
	t.eq(a.fat, 0, "fatigue rendue")
	t.check(not s.undo_move(a), "un seul niveau d'annulation")
	# deux déplacements : seul le dernier s'annule
	s.move_along(a, [Hex.from_col_row(2, 4)] as Array[Vector2i], true)
	s.move_along(a, [Hex.from_col_row(3, 4)] as Array[Vector2i], true)
	s.undo_move(a)
	t.eq(a.hex, Hex.from_col_row(2, 4), "seul le dernier déplacement est annulé")
	t.eq(a.ap, 7, "PA du premier déplacement conservés")


func test_undo_blocked() -> void:
	# attaque d'opportunité subie (même ratée) : plus d'annulation
	var d: Array = _duel(5, 6)
	var s: BattleState = d[0]
	var a: Unit = d[1]
	s.move_along(a, [Hex.from_col_row(4, 4)] as Array[Vector2i], true)
	t.check(not s.can_undo_move(a), "attaque d'opportunité : pas d'annulation")
	# attaque après le déplacement
	d = _duel(5, 7)
	s = d[0]
	a = d[1]
	var f: Unit = d[2]
	s.move_along(a, [Hex.from_col_row(6, 4)] as Array[Vector2i], true)
	t.check(s.can_undo_move(a), "avant l'attaque : possible")
	s.attack(a, f)
	t.check(not s.can_undo_move(a), "après une attaque : impossible")
	# case de départ occupée
	d = _duel(1, 10)
	s = d[0]
	a = d[1]
	f = d[2]
	s.move_along(a, [Hex.from_col_row(2, 4)] as Array[Vector2i], true)
	f.hex = Hex.from_col_row(1, 4)
	t.check(not s.can_undo_move(a), "case de départ occupée : impossible")
	# changement d'arme / attendre / mur de boucliers ferment l'annulation
	d = _duel(1, 10)
	s = d[0]
	a = d[1]
	s.move_along(a, [Hex.from_col_row(2, 4)] as Array[Vector2i], true)
	s.raise_shield(a)
	t.check(not s.can_undo_move(a), "mur de boucliers : impossible")
	d = _duel(1, 10)
	s = d[0]
	a = d[1]
	s.move_along(a, [Hex.from_col_row(2, 4)] as Array[Vector2i], true)
	s.begin_turn(a)
	t.check(not s.can_undo_move(a), "nouveau tour : impossible")


func test_undo_serialization() -> void:
	var d: Array = _duel(1, 10)
	var s: BattleState = d[0]
	var a: Unit = d[1]
	s.move_along(a, [Hex.from_col_row(2, 4), Hex.from_col_row(3, 4)] as Array[Vector2i], true)
	var json: String = JSON.stringify(s.to_dict())
	var s2: BattleState = BattleState.from_dict(JSON.parse_string(json), t.rng_seeded(1))
	var a2: Unit = s2.unit_by_id(a.id)
	t.check(s2.can_undo_move(a2), "annulation conservée après sauvegarde")
	s2.undo_move(a2)
	t.eq(a2.hex, Hex.from_col_row(1, 4), "départ restauré après rechargement")
	# ancienne sauvegarde : sans clé d'annulation
	var old: Dictionary = JSON.parse_string(json)
	old.erase("undo")
	old.erase("log_group")
	var s3: BattleState = BattleState.from_dict(old, t.rng_seeded(1))
	t.check(s3.undo.is_empty(), "ancienne sauvegarde : rien à annuler")


func test_log_groups() -> void:
	var d: Array = _duel(5, 6)
	var s: BattleState = d[0]
	var a: Unit = d[1]
	var f: Unit = d[2]
	s.log_lines.clear()
	s.attack(a, f)
	var groups: Dictionary = {}
	for l in s.log_lines:
		groups[int(l["g"])] = true
	t.eq(groups.size(), 1, "les lignes d'une même attaque forment un groupe")
	s.attack(a, f)
	var g2: Dictionary = {}
	for l in s.log_lines:
		g2[int(l["g"])] = true
	t.eq(g2.size(), 2, "deux attaques = deux groupes")
	for i in 300:
		s.say("ligne %d" % i, "sys")
	t.eq(s.log_lines.size(), BattleState.LOG_MAX, "le journal garde %d lignes" % BattleState.LOG_MAX)
	t.check(BattleState.LOG_MAX >= 200, "au moins 200 lignes")
	var back: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), t.rng_seeded(1))
	t.eq(back.log_lines.size(), s.log_lines.size(), "journal restauré")
	t.eq(int(back.log_lines[0]["g"]), int(s.log_lines[0]["g"]), "groupe restauré")


func _won_game() -> Node:
	var g: Node = t.new_game(33)
	g.gold = 5000
	t.check(g.accept_contract(0), "contrat accepté")
	g.leave_settlement()
	g.world.parties.clear()
	g.engage_target()
	t.check(g.battle != null, "bataille lancée")
	return g


func test_battle_report() -> void:
	var g: Node = _won_game()
	var men: int = mini(g.roster.size(), Data.FIGHTERS)
	var gold0: int = g.gold
	var b: BattleState = g.battle
	for u in b.units:
		if u.side == "e":
			u.morale = 0
	b.check_end()
	t.eq(b.over, "win", "victoire")
	g.finish_battle()
	var r: Dictionary = g.last_battle_report
	t.check(not r.is_empty(), "compte rendu rempli")
	t.eq(r["result"], "win", "résultat")
	t.eq((r["men"] as Array).size(), men, "une ligne par homme engagé")
	t.eq(int(r["gold"]), g.gold - gold0, "prime = or gagné")
	t.check(int(r["renown"]) > 0, "renom gagné")
	for m in r["men"]:
		t.check(int(m["xp"]) > 0, "XP gagnée")
		t.check(m.has("u") and m.has("hp_before") and m.has("hp_after") and m.has("wounds"), "champs du résumé")
	# le résumé se construit et la sauvegarde le conserve
	var box := VBoxContainer.new()
	SummaryScreen.build(box, r, func() -> void: pass)
	t.check(box.get_child_count() > 3, "le résumé s'affiche")
	box.free()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = t.new_game(1)
	g2.from_dict(saved)
	t.eq(str(g2.last_battle_report["result"]), "win", "compte rendu sauvegardé")
	t.eq((g2.last_battle_report["men"] as Array).size(), men, "hommes sauvegardés")
	var old: Dictionary = saved.duplicate(true)
	old.erase("last_battle_report")
	g2.from_dict(old)
	t.check(g2.last_battle_report.is_empty(), "ancienne sauvegarde : compte rendu vide")


func test_battle_report_death() -> void:
	var g: Node = _won_game()
	var b: BattleState = g.battle
	var victim: Unit = null
	for u in b.units:
		if u.side == "p":
			victim = u
			break
	victim.hp = 0
	victim.dead = true
	for u in b.units:
		if u.side == "e":
			u.morale = 0
	b.check_end()
	g.finish_battle()
	var dead_rows: int = 0
	for m in g.last_battle_report["men"]:
		if bool(m["dead"]):
			dead_rows += 1
	t.eq(dead_rows, 1, "un tombé dans le compte rendu")
	t.check((g.last_battle_report["fallen"] as Array).size() == 1, "liste des tombés")


func test_visited() -> void:
	var g: Node = t.new_game(12)
	var s: Dictionary = g.world.settlements[1]
	t.eq(Visits.day_of(s), 0, "lieu jamais visité")
	g.day = 6
	g.enter_settlement(str(s["id"]))
	t.eq(Visits.day_of(g.world.settlement_by_id(str(s["id"]))), 6, "jour de visite noté")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = t.new_game(1)
	g2.from_dict(saved)
	t.eq(Visits.day_of(g2.world.settlement_by_id(str(s["id"]))), 6, "visite sauvegardée")
	t.check(Visits.tooltip(g2.world.settlement_by_id(str(s["id"])), 0).contains("Visité le jour 6"), "info-bulle")
	t.check(Visits.tooltip({"name": "X"}, 0).contains("Jamais"), "lieu non visité")
