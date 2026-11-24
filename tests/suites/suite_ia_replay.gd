extends RefCounted
## IA plus maligne (renforts, commandants, ruses), rediffusion de bataille (BattleLog) et « Annuler le tour » (Facile).
var t  # le lanceur (voir tests/suites/README.md)

const B8: Array = ["brigand", "brigand", "brigand", "brigand", "archer", "archer", "balafre", "chef"]


func _contract(foes: Array, btype: String, extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"kind": "contract", "type": "b", "type_contract": "kill", "d": 2, "foes": foes, "title": "Test", "desc": "", "days": 1,
		"employer": "x", "pay": 400, "biome": "plain", "battle_type": btype}
	c.merge(extra, true)
	return c


func _party(n: int, seed_value: int = 4) -> Array:
	var r: RandomNumberGenerator = t.rng_seeded(seed_value)
	var out: Array = []
	var keys: Array = Data.BG.keys()
	for i in n:
		out.append(Contracts.make_merc(keys[i % keys.size()], r, []))
	return out


func _create(btype: String, foes: Array, seed_value: int = 9, difficulty: String = "normal", extra: Dictionary = {}, party: Array = []) -> BattleState:
	return BattleState.create(_contract(foes, btype, extra), party if not party.is_empty() else _party(6), t.rng_seeded(seed_value), 3, 1.0, difficulty)


func _field() -> Dictionary:
	var cells: Dictionary = {}
	for r in 9:
		for c in 12:
			cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	return cells


func _bare() -> BattleState:
	var s := BattleState.new()
	s.rng = t.rng_seeded(3)
	s.cells = _field()
	s.round_no = 1
	return s


func _foe(key: String, hex: Vector2i) -> Unit:
	var f: Unit = Contracts.make_foe(key, t.rng_seeded(1))
	f.reset_for_battle()
	f.hex = hex
	return f


func _play(s: BattleState, max_turns: int = 400) -> int:
	var turns: int = 0
	while s.over == "" and turns < max_turns:
		var u: Unit = s.next_turn()
		if u == null:
			break
		s.play_ai_turn(u)
		turns += 1
	return turns


func _snapshot(s: BattleState) -> Array:
	var out: Array = []
	for u in s.units:
		out.append([u.unit_name, u.hex, u.hp, u.arm_h, u.arm_b, u.morale, u.dead])
	return out


# --- Renforts ---

func test_renforts_siege_convoi_embuscade() -> void:
	for btype in ["siege", "convoy"]:
		var s: BattleState = _create(btype, B8)
		t.check(not s.reserve.is_empty(), "%s : une seconde vague est retenue" % btype)
		t.eq(AiPlan.reserve_round(btype), 3, "%s : arrive à la manche 3" % btype)
		var before: int = s.units.size()
		var arrived: Array = []
		s.reinforced.connect(func(a: Array) -> void: arrived.append_array(a))
		s.new_round()  # manche 2 : rien
		t.eq(s.units.size(), before, "%s : pas de renfort à la manche 2" % btype)
		s.new_round()  # manche 3
		t.check(s.units.size() > before and s.reserve.is_empty(), "%s : le renfort surgit à la manche 3" % btype)
		t.check(not arrived.is_empty(), "%s : le signal « reinforced » est émis" % btype)
		for u in s.units:
			t.check(s.cells.has(u.hex), "%s : renfort sur une case du plateau" % btype)
	var amb: BattleState = _create("ambush", B8)
	t.eq(AiPlan.reserve_round("ambush"), Data.AMBUSH_RESERVE_ROUND, "embuscade : manche des renforts inchangée")
	t.check(not amb.reserve.is_empty(), "embuscade : des ennemis attendent sur un flanc")
	var pitched: BattleState = _create("pitched", B8)
	t.check(pitched.reserve.is_empty(), "bataille rangée : aucun renfort")
	var small: BattleState = _create("siege", ["brigand", "brigand", "chef"])
	t.check(small.reserve.is_empty(), "petit effectif : rien n'est retenu")


func test_chef_jamais_retenu() -> void:
	var s: BattleState = _create("siege", B8)
	var leader_in: bool = false
	for u in s.units:
		if u.side == "e" and u.leader:
			leader_in = true
	t.check(leader_in, "le chef ennemi combat dès le début")


# --- Commandants ---

func test_aura_et_charge() -> void:
	var s: BattleState = _bare()
	var chef: Unit = _foe("chef", Vector2i(9, 4))
	var a: Unit = _foe("brigand", Vector2i(8, 4))
	var far: Unit = _foe("brigand", Vector2i(2, 4))
	for u in [chef, a, far]:
		s.units.append(u)
	t.eq(AiPlan.ini_bonus(s, a), AiPlan.LEADER_INI, "initiative : bonus près du chef")
	t.eq(AiPlan.ini_bonus(s, far), 0, "initiative : rien loin du chef")
	t.eq(AiPlan.ini_bonus(s, chef), 0, "initiative : pas pour le chef lui-même")
	t.eq(s.leader_aura(a), Data.LEADER_AURA, "moral : l'aura de chef existe toujours")
	# un seul adversaire faible : le camp du chef a la bataille en main
	var p: Unit = t.mk("hache", "p", Vector2i(3, 4))
	p.hp = 10
	s.units.append(p)
	t.check(AiPlan.charging(s, "e"), "charge : le chef sonne la charge quand il domine")
	s.extras = {"ia": {"lurk": [], "feint": [], "charge": {}}}
	AiPlan.on_turn(s, a)
	var lines: int = s.log_lines.size()
	t.check(lines >= 1 and str(s.log_lines[0]["t"]).contains("charge"), "charge : annoncée dans le journal")
	AiPlan.on_turn(s, a)
	t.eq(s.log_lines.size(), lines, "charge : annoncée une seule fois")
	# à armes égales : pas de charge
	var s2: BattleState = _bare()
	s2.units.append(_foe("chef", Vector2i(9, 4)))
	for i in 3:
		s2.units.append(t.mk("hache", "p", Vector2i(3, i + 2)))
	t.check(not AiPlan.charging(s2, "e"), "charge : pas quand l'adversaire est plus fort")
	# pas de chef vivant, pas de charge
	chef.dead = true
	t.check(not AiPlan.charging(s, "e"), "charge : sans chef, pas de charge")


# --- Tactique et ruses ---

func test_ciblage_et_position() -> void:
	var s: BattleState = _bare()
	var e: Unit = _foe("brigand", Vector2i(6, 4))
	var naked: Unit = t.mk("hache", "p", Vector2i(5, 4))
	naked.arm_h = 0
	naked.arm_b = 0
	var armored: Unit = t.mk("hache", "p", Vector2i(5, 3))
	armored.arm_h = 90
	armored.arm_b = 130
	s.units.append_array([e, naked, armored])
	t.check(AiPlan.target_bonus(s, e, naked, 60.0) > AiPlan.target_bonus(s, e, armored, 60.0), "ciblage : l'homme sans armure attire plus")
	t.check(AiPlan.target_bonus(s, e, naked, 10.0) < AiPlan.target_bonus(s, e, naked, 60.0), "ciblage : une cible quasi imprenable pèse moins")
	# encerclement : une case entourée de trois ennemis est mal notée
	var s2: BattleState = _bare()
	var me: Unit = _foe("brigand", Vector2i(8, 4))
	s2.units.append(me)
	var h: Vector2i = Vector2i(5, 4)
	var around: Array[Vector2i] = Hex.neighbors(h)
	for i in 3:
		var pu: Unit = t.mk("hache", "p", around[i])
		s2.units.append(pu)
	t.check(AiPlan.position_bonus(s2, me, h) < 0.0, "position : éviter d'être encerclé")


func test_ruses() -> void:
	var s: BattleState = _create("ambush", B8)
	var plan: Dictionary = s.extras.get("ia", {})
	t.check(not (plan.get("lurk", []) as Array).is_empty(), "embuscade : des tireurs restent cachés")
	var lurker: Unit = s.unit_by_id(int((plan["lurk"] as Array)[0]))
	# tout le monde loin de lui : il guette ; blessé ou approché : il sort
	for p in s.units:
		if p.side == "p":
			p.hex = Hex.from_col_row(0, 0)
	lurker.hex = Hex.from_col_row(11, 8)
	s.round_no = 1
	t.check(AiPlan.lurking(s, lurker), "ruse : le guetteur reste immobile loin de l'ennemi")
	s.round_no = AiPlan.LURK_UNTIL + 1
	t.check(not AiPlan.lurking(s, lurker), "ruse : il sort au plus tard à la manche prévue")
	s.round_no = 1
	lurker.hp -= 1
	t.check(not AiPlan.lurking(s, lurker), "ruse : blessé, il sort")
	lurker.hp = lurker.hp_max
	(s.units.filter(func(u: Unit) -> bool: return u.side == "p")[0] as Unit).hex = Hex.from_col_row(9, 8)
	t.check(not AiPlan.lurking(s, lurker), "ruse : un ennemi proche le fait sortir")
	# l'IA ne se bloque jamais : le tour d'un guetteur se termine
	var s3: BattleState = _create("ambush", B8)
	var turns: int = 0
	while turns < 30 and s3.over == "":
		var u: Unit = s3.next_turn()
		if u == null:
			break
		s3.play_ai_turn(u)
		turns += 1
	t.check(turns > 0, "ruse : l'IA joue ses tours")
	# repli feint
	var s4: BattleState = _bare()
	var f: Unit = _foe("brigand", Vector2i(9, 4))
	s4.units.append(f)
	s4.units.append(t.mk("hache", "p", Vector2i(1, 4)))
	s4.extras = {"ia": {"lurk": [], "feint": [f.id], "charge": {}}}
	s4.round_no = AiPlan.FEINT_FROM
	t.check(AiPlan.feinting(s4, f), "ruse : repli feint en manche 2-3")
	s4.round_no = AiPlan.FEINT_TO + 1
	t.check(not AiPlan.feinting(s4, f), "ruse : le repli feint s'arrête")


func test_play_ai_turn_deterministe() -> void:
	for btype in ["pitched", "ambush", "siege", "convoy"]:
		var roster: Array = _party(6)  # la même compagnie pour les deux batailles (la génération d'un homme dépend d'un compteur global)
		var a: BattleState = _create(btype, B8, 21, "normal", {}, roster)
		var b: BattleState = _create(btype, B8, 21, "normal", {}, roster)
		_play(a, 120)
		_play(b, 120)
		t.eq(_snapshot(a), _snapshot(b), "%s : même graine, même bataille" % btype)
		t.eq(a.log_lines.size(), b.log_lines.size(), "%s : même journal" % btype)
	# des graines différentes divergent (sanity)
	var rc: Array = _party(6)
	var c: BattleState = _create("pitched", B8, 22, "normal", {}, rc)
	var d: BattleState = _create("pitched", B8, 23, "normal", {}, rc)
	_play(c, 60)
	_play(d, 60)
	t.check(_snapshot(c) != _snapshot(d), "graines différentes : batailles différentes")


func test_ia_ne_bloque_pas() -> void:
	# une unité sans rien à faire passe son tour (même cernée de rochers)
	var s: BattleState = _bare()
	var f: Unit = _foe("brigand", Vector2i(9, 4))
	s.units.append(f)
	for n in Hex.neighbors(f.hex):
		if s.cells.has(n):
			s.cells[n]["t"] = "rock"
	s.units.append(t.mk("hache", "p", Vector2i(1, 4)))
	s.round_no = 1
	s.play_ai_turn(f)
	t.check(true, "tour sans issue : l'IA rend la main")


# --- Rediffusion ---

func test_rediffusion_rejouable_a_lidentique() -> void:
	for btype in ["pitched", "ambush", "siege"]:
		var s: BattleState = _create(btype, B8, 31)
		_play(s)
		s.rec.finalize(s)
		t.check(s.rec.frame_count() > 0, "%s : des images enregistrées" % btype)
		t.check(s.rec.frame_count() <= BattleLog.MAX_FRAMES, "%s : journal borné" % btype)
		var rp: BattleState = s.rec.replay_state()
		for f in s.rec.frames:
			BattleLog.apply_frame(rp, f)
		t.eq(BattleLog.diff_final(s, rp), [] as Array[String], "%s : la relecture redonne l'état final" % btype)
		# aller-retour JSON compressé
		var packed: Dictionary = s.rec.pack()
		var back: BattleLog = BattleLog.unpack(JSON.parse_string(JSON.stringify(packed)))
		t.check(back.is_valid(), "%s : journal compacté relu" % btype)
		t.eq(back.frame_count(), s.rec.frame_count(), "%s : même nombre d'images après relecture" % btype)
		var rp2: BattleState = back.replay_state()
		for f in back.frames:
			BattleLog.apply_frame(rp2, f)
		t.eq(BattleLog.diff_final(s, rp2), [] as Array[String], "%s : relecture identique après compactage" % btype)
	t.check(not BattleLog.unpack({"z": ""}).is_valid(), "journal abîmé : ignoré sans erreur")
	t.check(not BattleLog.unpack(null).is_valid(), "journal absent : vide")


func test_rediffusion_bornee() -> void:
	var s: BattleState = _create("pitched", B8, 5)
	var log: BattleLog = BattleLog.start(s)
	var u: Unit = s.units[0]
	for i in BattleLog.MAX_FRAMES + 50:
		u.hp = 1 + (i % 7)
		log.capture(s, "ligne %d" % i)
	t.eq(log.frame_count(), BattleLog.MAX_FRAMES, "journal plafonné")
	t.check(log.truncated, "journal tronqué signalé")
	t.check((log.frames[10].get("t", []) as Array).size() <= BattleLog.MAX_TEXTS, "lignes de journal bornées par image")


func test_rediffusion_ecran() -> void:
	var s: BattleState = _create("pitched", B8, 41)
	_play(s, 80)
	s.rec.finalize(s)
	var rs := ReplayScreen.new()
	t.check(rs != null, "écran de rediffusion instanciable")
	rs.free()
	var s2: BattleState = _create("pitched", B8, 42)
	t.eq(s2.rec.next_round_index(0), -1, "saut de manche : rien tant qu'une seule manche est enregistrée")


# --- Annuler le tour ---

func test_annuler_le_tour() -> void:
	t.check(TurnUndo.allowed("easy", {}), "Facile : annulation permise")
	t.check(not TurnUndo.allowed("normal", {}), "Normal : interdite")
	t.check(not TurnUndo.allowed("hard", {}), "Difficile : interdite")
	t.check(not TurnUndo.allowed("easy", {"ironman": {"on": true}}), "mode fer : interdite même en Facile")
	var hard: BattleState = _create("pitched", B8, 51, "normal")
	var u0: Unit = hard.next_turn()
	while u0 != null and u0.side != "p":
		hard.play_ai_turn(u0)
		u0 = hard.next_turn()
	t.eq(TurnUndo.capture(hard, "normal", {}), {}, "Normal : aucun instantané")
	var s: BattleState = _create("pitched", B8, 52, "easy")
	var u: Unit = s.next_turn()
	while u != null and u.side != "p":
		s.play_ai_turn(u)
		u = s.next_turn()
	t.check(u != null, "un tour du joueur est atteint")
	var snap: Dictionary = TurnUndo.capture(s, "easy", {})
	t.check(not snap.is_empty(), "Facile : instantané pris")
	t.check(not TurnUndo.can_use(s, snap, "easy", {}), "rien n'a changé : pas de bouton")
	var hex0: Vector2i = u.hex
	var ap0: int = u.ap
	u.ap -= 2
	u.hex = Hex.from_col_row(5, 4) if hex0 != Hex.from_col_row(5, 4) else Hex.from_col_row(5, 5)
	s.rng.randi()  # le hasard avance pendant le tour
	t.check(TurnUndo.can_use(s, snap, "easy", {}), "après une action, l'annulation est offerte")
	t.check(not TurnUndo.can_use(s, snap, "easy", {"ironman": {"on": true}}), "mode fer : refusée")
	t.check(not TurnUndo.can_use(s, snap, "normal", {}), "Normal : refusée")
	var rng_state: int = int(s.rng.state)
	var ns: BattleState = TurnUndo.restore(s, snap, "easy", {})
	t.check(ns != null, "restauration faite")
	if ns == null:
		return
	var back: Unit = ns.unit_by_id(u.id)
	t.eq(back.hex, hex0, "l'homme revient à sa case")
	t.eq(back.ap, ap0, "il retrouve ses PA")
	t.eq(int(ns.rng.state), rng_state, "le hasard n'est pas remis en arrière (la graine continue)")
	t.check(ns.rng == s.rng, "même générateur")
	t.check(bool(ns.extras.get("turn_undo_used", false)), "usage noté")
	back.ap -= 1
	var snap2: Dictionary = TurnUndo.capture(ns, "easy", {})
	t.check(not TurnUndo.can_use(ns, snap2, "easy", {}), "une seule fois par bataille")
	t.check(TurnUndo.restore(ns, snap, "easy", {}) == null, "second essai refusé")
	# l'indicateur survit à la sauvegarde
	var rl: BattleState = BattleState.from_dict(JSON.parse_string(JSON.stringify(ns.to_dict())), t.rng_seeded(1))
	t.check(bool(rl.extras.get("turn_undo_used", false)), "usage conservé dans la sauvegarde")
	t.check(not (rl.extras.get("ia", {}) as Dictionary).is_empty(), "ruses conservées dans la sauvegarde")
