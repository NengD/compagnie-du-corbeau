extends RefCounted
## Hauteur et couvert à distance (core/cover.gd), captifs et rançon (core/captives.gd), compatibilité de la sérialisation.
var t  # le lanceur (voir tests/suites/README.md)


func _field(w: int = 12, h: int = 9) -> Dictionary:
	var cells: Dictionary = {}
	for r in h:
		for c in w:
			cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	return cells


func _bare() -> BattleState:
	var s := BattleState.new()
	s.rng = t.rng_seeded(3)
	s.cells = _field()
	s.round_no = 1
	return s


func _pair(ax: int, dx: int) -> Array:
	var a: Unit = t.mk("arc", "p", Hex.from_col_row(ax, 4))
	var d: Unit = t.mk("hache", "e", Hex.from_col_row(dx, 4))
	return [a, d]


func _hc(s: BattleState, a: Unit, d: Unit) -> int:
	return CombatRules.hit_chance(a, d, [a, d], s.cells)


func test_hauteur_distance() -> void:
	var s := _bare()
	var p: Array = _pair(2, 6)
	var a: Unit = p[0]
	var d: Unit = p[1]
	var base: int = _hc(s, a, d)
	s.cells[a.hex]["t"] = "hill"
	t.eq(_hc(s, a, d), clampi(base + Cover.HEIGHT_RANGED_BONUS, 5, 95), "tireur sur colline : bonus")
	s.cells[a.hex]["t"] = "g"
	s.cells[d.hex]["t"] = "hill"
	t.eq(_hc(s, a, d), clampi(base - Cover.HEIGHT_RANGED_MALUS, 5, 95), "cible sur colline : malus")
	t.check(Cover.tags(s.cells, a.hex, d.hex).size() == 1, "étiquette de hauteur")
	t.eq(Cover.short_tag(s.cells, a.hex, d.hex), "Surplomb", "étiquette courte")


func test_couvert() -> void:
	var s := _bare()
	var p: Array = _pair(2, 6)
	var a: Unit = p[0]
	var d: Unit = p[1]
	var base: int = _hc(s, a, d)
	t.check(not Cover.has_cover(s.cells, a.hex, d.hex), "pas de couvert en terrain nu")
	var front: Vector2i = Hex.neighbors(d.hex)[0]
	for n in Hex.neighbors(d.hex):
		if Hex.distance(a.hex, n) <= Hex.distance(a.hex, d.hex):
			front = n
			break
	s.cells[front]["t"] = "rock"
	t.check(Cover.has_cover(s.cells, a.hex, d.hex), "rocher voisin côté tireur : couvert")
	t.eq(_hc(s, a, d), clampi(base - Cover.COVER_MALUS, 5, 95), "malus de couvert")
	# la mêlée n'est pas touchée
	var m: Unit = t.mk("hache", "p", Hex.from_col_row(5, 4))
	var before: int = CombatRules.hit_chance(m, d, [m, d], _field())
	t.eq(CombatRules.hit_chance(m, d, [m, d], s.cells), before, "pas de couvert contre la mêlée")
	# barricade intacte = couvert ; ouverte = non
	s.cells[front]["t"] = "g"
	Scenery.place(s.cells, front, "wall")
	t.check(Cover.has_cover(s.cells, a.hex, d.hex), "rempart : couvert")
	# obstacle derrière la cible : aucun couvert
	s.cells[front].erase("obj")
	var back: Vector2i = Hex.neighbors(d.hex)[0]
	for n in Hex.neighbors(d.hex):
		if Hex.distance(a.hex, n) > Hex.distance(a.hex, d.hex):
			back = n
			break
	s.cells[back]["t"] = "rock"
	t.check(not Cover.has_cover(s.cells, a.hex, d.hex), "obstacle derrière la cible : pas de couvert")


func test_bornes() -> void:
	var s := _bare()
	var p: Array = _pair(1, 9)
	var a: Unit = p[0]
	var d: Unit = p[1]
	a.ranged_skill = 5
	d.ranged_def = 80
	s.cells[d.hex]["t"] = "hill"
	for n in Hex.neighbors(d.hex):
		s.cells[n]["t"] = "rock"
	t.eq(_hc(s, a, d), 5, "plancher à 5 %")
	a.ranged_skill = 200
	d.ranged_def = 0
	s.cells[d.hex]["t"] = "g"
	s.cells[a.hex]["t"] = "hill"
	for n in Hex.neighbors(d.hex):
		s.cells[n]["t"] = "g"
	t.eq(_hc(s, a, d), 95, "plafond à 95 %")
	# à bout portant : pas de couvert
	var adj: Unit = t.mk("hache", "e", Hex.neighbors(a.hex)[0])
	t.check(not Cover.has_cover(s.cells, a.hex, adj.hex), "pas de couvert au contact")


func test_ia_prefere_couvert() -> void:
	var s := _bare()
	var a: Unit = t.mk("arc", "e", Hex.from_col_row(8, 4))
	var f: Unit = t.mk("hache", "p", Hex.from_col_row(3, 4))
	s.units.append(a)
	s.units.append(f)
	var h1: Vector2i = Hex.from_col_row(8, 4)
	var plain: float = Ai.eval_pos(s, a, h1)
	var online: Array[Vector2i] = CombatRules.line_between(f.hex, h1)
	for n in Hex.neighbors(h1):
		if Hex.distance(f.hex, n) <= Hex.distance(f.hex, h1) and not online.has(n):
			s.cells[n]["t"] = "rock"
	t.check(Cover.has_cover(s.cells, f.hex, h1), "case abritée sans couper la ligne")
	t.check(Ai.eval_pos(s, a, h1) > plain, "l'archer préfère la case abritée")


func _bandits(morales: Array, extra: Dictionary = {}) -> BattleState:
	var s := _bare()
	s.contract = {"title": "Test", "vs_faction": "", "kind": "contract"}
	s.contract.merge(extra, true)
	s.units.append(t.mk("hache", "p", Hex.from_col_row(1, 1)))
	var i: int = 0
	for m in morales:
		var f: Unit = t.mk("hache", "e", Hex.from_col_row(8, i))
		f.faction = "b"
		f.morale = int(m)
		s.units.append(f)
		i += 1
	return s


func test_captifs_eligibles() -> void:
	var s := _bandits([1, 0, 3])
	var cap: Dictionary = Captives.collect(s, true)
	t.eq(cap["men"].size(), 2, "deux brisés/en fuite")
	t.check(Captives.collect(s, false).is_empty(), "pas de captifs en cas de défaite")
	t.check(Captives.collect(_bandits([3, 4]), true).is_empty(), "aucun captif si tous stables")
	var s2 := _bandits([0])
	(s2.units[1] as Unit).faction = "u"
	t.check(Captives.collect(s2, true).is_empty(), "morts-vivants exclus")
	(s2.units[1] as Unit).faction = "g"
	t.check(Captives.collect(s2, true).is_empty(), "goules exclues")
	var s3 := _bandits([0])
	(s3.units[1] as Unit).escaped = true
	t.check(Captives.collect(s3, true).is_empty(), "en fuite hors du plateau : pas de captif")
	var s4 := _bandits([0])
	(s4.units[1] as Unit).dead = true
	t.check(Captives.collect(s4, true).is_empty(), "mort : pas de captif")


func test_effets_des_choix() -> void:
	var cap: Dictionary = {"men": [{"name": "A", "level": 1, "leader": false}, {"name": "B", "level": 3, "leader": true}], "faction": "", "title": ""}
	var want: int = (Captives.RANSOM_BASE + Captives.RANSOM_PER_LEVEL) + (Captives.RANSOM_BASE + 3 * Captives.RANSOM_PER_LEVEL) * Captives.RANSOM_LEADER_MULT
	t.eq(Captives.ransom_value(cap), want, "valeur de rançon (chef x3)")
	t.eq(int(Captives.effects(cap, "ransom")["gold"]), want, "rançon : or")
	t.check(float(Captives.effects(cap, "free")["morale"]) > 0.0, "libération : moral +")
	t.check(float(Captives.effects(cap, "execute")["morale"]) < 0.0, "exécution : moral −")
	t.check(Captives.effects(cap, "free")["line"] != "", "phrase d'effet")
	t.eq(int(Captives.effects(cap, "bidon")["gold"]), 0, "choix inconnu : rien")
	var fk: String = str(Data.FACTIONS.keys()[0])
	cap["faction"] = fk
	t.check(int(Captives.effects(cap, "free")["standing"][fk]) > 0, "libérer : réputation +")
	t.check(int(Captives.effects(cap, "execute")["standing"][fk]) < 0, "exécuter : réputation −")
	t.check(int(Captives.effects(cap, "ransom")["standing"][fk]) < 0, "rançon : petite perte")


func test_application_dans_game() -> void:
	var g: Node = t.new_game(77)
	var fk: String = str(Data.FACTIONS.keys()[0])
	var cap: Dictionary = {"men": [{"name": "A", "level": 2, "leader": false}], "faction": fk, "title": "x"}
	g.extras["captives"] = cap
	g.last_battle_report = {"gold": 100, "renown": 5, "captives": {"n": 1, "outcome": ""}}
	var gold0: int = g.gold
	var line: String = g.apply_captives("ransom")
	t.eq(g.gold, gold0 + Captives.ransom_value(cap), "or encaissé")
	t.check(line != "", "ligne renvoyée")
	t.check(g.pending_captives().is_empty(), "captifs consommés")
	t.eq(g.last_battle_report["captives"]["outcome"], line, "consigné dans le compte rendu")
	t.check(g.news.has(line), "consigné dans les nouvelles")
	t.eq(g.apply_captives("ransom"), "", "pas de double application")
	g.extras["captives"] = cap
	var m0: float = g.company_morale
	var s0: int = g.standing_with(fk)
	g.apply_captives("free")
	t.check(g.company_morale >= m0, "libération : moral non réduit")
	t.check(g.standing_with(fk) >= s0, "libération : réputation")
	g.extras["captives"] = cap
	m0 = g.company_morale
	g.apply_captives("execute")
	t.check(g.company_morale <= m0, "exécution : moral non augmenté")


func test_serialisation_inchangee() -> void:
	var s := _bandits([3])
	var d: Dictionary = s.to_dict()
	for k in d.keys():
		t.check(not str(k).contains("captive") and not str(k).contains("cover"), "pas de nouvelle clé de bataille : " + str(k))
	var back: BattleState = BattleState.from_dict(d, t.rng_seeded(1))
	t.eq(back.units.size(), s.units.size(), "aller-retour de la bataille")
	t.eq(back.cells.size(), s.cells.size(), "cases conservées")
