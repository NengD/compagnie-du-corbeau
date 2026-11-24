extends RefCounted
## Camp vivant (veillées, rivalités, duels, mutineries : core/camp_life.gd), retraite et héritage (core/legacy.gd),
## historique des courbes (core/stats_history.gd).
var t


func _ctx(g: Node, extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"day": g.day, "gold": 500, "provisions": 20, "morale": 60.0, "fallen": 2, "road": false, "random": true}
	c.merge(extra, true)
	return c


func _ev(id: String, a: Unit, b: Unit, day: int = 5) -> Dictionary:
	return {"id": id, "a": a.id, "b": b.id if b != null else -1, "day": day, "stake": 25, "cost": 60}


func test_catalogue() -> void:
	for id in CampLifeData.EVENTS:
		var n: int = (CampLifeData.EVENTS[id]["choices"] as Array).size()
		t.check(n >= 2 and n <= 3, "%s : 2 ou 3 choix" % id)
		t.check(CampLife.DEFAULTS.has(id), "%s : choix d'office défini" % id)
		var ids: Array = (CampLifeData.EVENTS[id]["choices"] as Array).map(func(c: Dictionary) -> String: return str(c["id"]))
		t.check(ids.has(CampLife.DEFAULTS[id]), "%s : le choix d'office existe" % id)


func test_roll_and_pick() -> void:
	var g: Node = t.new_game(7)
	var ex: Dictionary = {}
	t.eq(CampLife.roll(ex, [g.roster[0]], t.rng_seeded(1), _ctx(g), 1.0).is_empty(), true, "moins de deux hommes : rien")
	var ev: Dictionary = CampLife.roll(ex, g.roster, t.rng_seeded(1), _ctx(g, {"day": 5}), 1.0)
	t.check(not ev.is_empty() and CampLife.has_pending(ex), "veillée tirée et en attente")
	t.check(CampLife.roll(ex, g.roster, t.rng_seeded(2), _ctx(g, {"day": 6}), 1.0).is_empty(), "une seule à la fois")
	var ex2: Dictionary = {}
	t.check(CampLife.roll(ex2, g.roster, t.rng_seeded(3), _ctx(g, {"day": 5}), 0.0).is_empty(), "probabilité nulle : rien")
	CampLife.roll(ex2, g.roster, t.rng_seeded(3), _ctx(g, {"day": 5}), 1.0)
	CampLife.resolve(ex2, CampLife.DEFAULTS[str(CampLife.pending(ex2)["id"])], g.roster, t.rng_seeded(4), _ctx(g, {"day": 5}))
	t.check(CampLife.roll(ex2, g.roster, t.rng_seeded(3), _ctx(g, {"day": 6}), 1.0).is_empty(), "écart minimal de %d jours" % CampLifeData.MIN_GAP)
	t.check(not CampLife.roll(ex2, g.roster, t.rng_seeded(3), _ctx(g, {"day": 5 + CampLifeData.MIN_GAP}), 1.0).is_empty(), "possible de nouveau ensuite")
	# les événements variés sortent bien
	var seen: Dictionary = {}
	for s in 200:
		var e: Dictionary = CampLife.pick(g.roster, t.rng_seeded(s), _ctx(g))
		seen[e["id"]] = true
	t.check(seen.size() >= 4, "au moins 4 genres de veillées en 200 tirages (%d)" % seen.size())
	t.check(not seen.has("mutiny"), "la mutinerie ne sort jamais d'un tirage ordinaire")


func test_every_choice_resolves() -> void:
	for id in CampLifeData.EVENTS:
		for c in CampLifeData.EVENTS[id]["choices"]:
			var g: Node = t.new_game(9)
			var a: Unit = g.roster[0]
			var b: Unit = g.roster[1]
			var ex: Dictionary = {}
			CampLife.state(ex)["pending"] = _ev(str(id), a, b)
			var ctx: Dictionary = _ctx(g)
			var info: Dictionary = CampLife.describe(CampLife.pending(ex), g.roster, ctx)
			t.check(info["text"] != "" and not str(info["text"]).contains("{"), "%s : texte rempli" % id)
			for ch in info["choices"]:
				t.check(not str(ch["label"]).contains("{") and not str(ch["hint"]).contains("{"), "%s/%s : gabarits remplis" % [id, ch["id"]])
			var res: Dictionary = CampLife.resolve(ex, str(c["id"]), g.roster, t.rng_seeded(5), ctx)
			t.check(bool(res["ok"]) and not (res["lines"] as Array).is_empty(), "%s/%s : résolu avec un récit" % [id, c["id"]])
			t.check(not CampLife.has_pending(ex), "%s/%s : plus en attente" % [id, c["id"]])
			for u in g.roster:
				t.check((u as Unit).hp >= 1, "%s/%s : personne ne meurt" % [id, c["id"]])
				for v in (u as Unit).bonds.values():
					t.check(absi(int(v)) <= Bonds.LIMIT, "liens bornés")


func test_choice_refused_when_unaffordable() -> void:
	var g: Node = t.new_game(9)
	var ex: Dictionary = {}
	CampLife.state(ex)["pending"] = _ev("tale", g.roster[0], null)
	var poor: Dictionary = _ctx(g, {"gold": 5})
	var r: Dictionary = CampLife.resolve(ex, "round", g.roster, t.rng_seeded(1), poor)
	t.check(not bool(r["ok"]) and CampLife.has_pending(ex), "tournée refusée sans or, l'événement reste")
	r = CampLife.resolve(ex, "inconnu", g.roster, t.rng_seeded(1), poor)
	t.check(not bool(r["ok"]), "choix inconnu refusé")
	r = CampLife.resolve(ex, "listen", g.roster, t.rng_seeded(1), poor)
	t.check(bool(r["ok"]), "choix gratuit accepté")


func test_outcomes() -> void:
	var g: Node = t.new_game(9)
	var a: Unit = g.roster[0]
	var b: Unit = g.roster[1]
	var ex: Dictionary = {}
	CampLife.state(ex)["pending"] = _ev("song", a, null)
	var r: Dictionary = CampLife.resolve(ex, "join", g.roster, t.rng_seeded(1), _ctx(g))
	t.check(float(r["morale"]) > 0.0 and Bonds.get_bond(a, b.id) >= 1, "la chanson remonte le moral et rapproche")
	CampLife.state(ex)["pending"] = _ev("bet", a, b)
	r = CampLife.resolve(ex, "in", g.roster, t.rng_seeded(1), _ctx(g))
	t.check(absi(int(r["gold"])) == 25, "pari : la mise gagnée ou perdue")
	CampLife.state(ex)["pending"] = _ev("food", a, b)
	r = CampLife.resolve(ex, "share", g.roster, t.rng_seeded(1), _ctx(g))
	t.check(int(r["provisions"]) == -3 and float(r["morale"]) > 0.0, "rations doublées")
	CampLife.state(ex)["pending"] = _ev("tale", a, null)
	var n: int = a.traits.size()
	var got: bool = false
	for s in 60:
		a.traits.assign(a.traits.slice(0, n))
		CampLife.state(ex)["pending"] = _ev("tale", a, null)
		CampLife.resolve(ex, "round", g.roster, t.rng_seeded(s), _ctx(g))
		if a.traits.size() > n:
			got = true
			break
	t.check(got, "la tournée donne parfois un trait")
	# protagoniste parti : l'affaire s'éteint sans erreur
	CampLife.state(ex)["pending"] = {"id": "brawl", "a": 99999, "b": b.id, "day": 5, "stake": 0, "cost": 0}
	r = CampLife.resolve(ex, "split", g.roster, t.rng_seeded(1), _ctx(g))
	t.check(bool(r["ok"]) and not CampLife.has_pending(ex), "protagoniste absent : rien de bloquant")


func test_rivalry_and_duel() -> void:
	var g: Node = t.new_game(5)
	var a: Unit = g.roster[0]
	var b: Unit = g.roster[1]
	for u in g.roster:
		u.bonds.clear()
	Bonds.set_bond(a, b, -12)
	var kinds: Dictionary = {}
	for s in 100:
		kinds[CampLife.pick(g.roster, t.rng_seeded(s), _ctx(g))["id"]] = true
	t.check(kinds.has("brawl"), "rivaux tendus : rixe possible")
	Bonds.set_bond(a, b, -25)
	kinds.clear()
	for s in 100:
		kinds[CampLife.pick(g.roster, t.rng_seeded(s), _ctx(g))["id"]] = true
	t.check(kinds.has("challenge"), "rivalité à bout : défi possible")
	# le duel ne tue jamais, désigne un vainqueur, apaise le lien
	for s in 40:
		a.hp = 8
		b.hp = 8
		Bonds.set_bond(a, b, -25)
		var d: Dictionary = CampLife.duel(a, b, t.rng_seeded(s))
		t.check(a.hp >= 1 and b.hp >= 1, "duel sans mort (graine %d)" % s)
		t.check(d["winner"] != d["loser"] and int(d["rounds"]) >= 1 and int(d["rounds"]) <= 8, "vainqueur et passes bornées")
	var ex: Dictionary = {}
	CampLife.state(ex)["pending"] = _ev("challenge", a, b)
	Bonds.set_bond(a, b, -25)
	a.hp = a.hp_max
	b.hp = b.hp_max
	var r: Dictionary = CampLife.resolve(ex, "duel", g.roster, t.rng_seeded(3), _ctx(g))
	t.check(bool(r["ok"]) and Bonds.get_bond(a, b.id) > -8, "après le duel, la rivalité est réglée")
	t.check(int(CampLife.state(ex)["duels"]) == 1 and str(r["chron"]) != "", "duel compté et consigné")
	t.check((a.hp < a.hp_max) or (b.hp < b.hp_max), "le duel laisse des traces")


func test_mutiny_warns_then_never_blocks() -> void:
	var g: Node = t.new_game(3)
	var ex: Dictionary = {}
	var lines: Array = []
	for i in 6:
		lines = CampLife.daily(ex, g.roster, t.rng_seeded(i), _ctx(g, {"day": 20 + i, "morale": 10.0}))
		if i == 0:
			t.check(lines.is_empty() and not CampLife.has_pending(ex), "premier jour bas : rien")
		if i == 1:
			t.check(not lines.is_empty() and not CampLife.has_pending(ex), "deuxième jour : avertissement, pas de mutinerie")
		if i == 3:
			t.check(CampLife.has_pending(ex) and CampLife.pending(ex)["id"] == "mutiny", "quatrième jour : la mutinerie éclate")
	# avant le jour 10, jamais
	var ex2: Dictionary = {}
	for i in 8:
		CampLife.daily(ex2, g.roster, t.rng_seeded(i), _ctx(g, {"day": 1 + i, "morale": 5.0}))
	t.check(not CampLife.has_pending(ex2), "pas de mutinerie avant le jour %d" % CampLifeData.MUTINY_MIN_DAY)
	# jamais à deux hommes
	var ex3: Dictionary = {}
	for i in 8:
		CampLife.daily(ex3, [g.roster[0], g.roster[1]], t.rng_seeded(i), _ctx(g, {"day": 30 + i, "morale": 5.0}))
	t.check(not CampLife.has_pending(ex3), "pas de mutinerie à deux hommes")
	# les trois réponses sont possibles même sans un sou
	for ch in ["pay", "speak", "let"]:
		var g2: Node = t.new_game(3)
		var ex4: Dictionary = {}
		var leader: Unit = CampLife.mutineer(g2.roster)
		CampLife.state(ex4)["pending"] = {"id": "mutiny", "a": leader.id, "b": -1, "day": 20, "stake": 0, "cost": 75}
		var res: Dictionary = CampLife.resolve(ex4, ch, g2.roster, t.rng_seeded(1), _ctx(g2, {"gold": 1000}))
		t.check(bool(res["ok"]), "mutinerie : %s résolue" % ch)
		if ch == "let":
			t.eq((res["leave"] as Array), [leader.id], "il part")
			t.check(int(res["gold"]) >= -CampLifeData.MUTINY_GOLD_CAP and int(res["gold"]) <= 0, "au plus %d couronnes emportées" % CampLifeData.MUTINY_GOLD_CAP)
	var g3: Node = t.new_game(3)
	var ex5: Dictionary = {}
	CampLife.state(ex5)["pending"] = {"id": "mutiny", "a": g3.roster[0].id, "b": -1, "day": 20, "stake": 0, "cost": 75}
	t.check(bool(CampLife.describe(CampLife.pending(ex5), g3.roster, _ctx(g3, {"gold": 10}))["choices"][0]["disabled"]), "prime impossible sans or")


func test_game_integration() -> void:
	var g: Node = t.new_game(21)
	g.random_events = true
	g.day = 12
	var n0: int = g.roster.size()
	var leader: Unit = CampLife.mutineer(g.roster)
	CampLife.state(g.extras)["pending"] = {"id": "mutiny", "a": leader.id, "b": -1, "day": 12, "stake": 0, "cost": 75}
	g.gold = 600
	var wage0: int = g.wages()
	g.camp_life_choose("let")
	t.eq(g.roster.size(), n0 - 1, "le mutin quitte la compagnie")
	t.check(g.gold >= 600 - CampLifeData.MUTINY_GOLD_CAP and g.gold <= 600, "or emporté borné")
	t.check(g.wages() < wage0, "plus de solde pour lui")
	t.check(not Chronicle.entries(g.extras, "event").is_empty(), "consigné au journal")
	# événement laissé sans réponse : tranché d'office, le temps continue
	var a: Unit = g.roster[0]
	CampLife.state(g.extras)["pending"] = _ev("song", a, null, g.day)
	g.day += CampLifeData.EXPIRE_DAYS
	g.advance_time(1.0)
	t.check(not CampLife.has_pending(g.extras), "veillée sans réponse tranchée d'office")
	# repos en lieu : tirage forcé via une probabilité de 1
	var g2: Node = t.new_game(22)
	g2.random_events = true
	var town: String = ""
	for s in g2.world.settlements:
		town = str(s["id"])
		break
	g2.enter_settlement(town)
	var got: bool = false
	for i in 12:
		g2.rest()
		if CampLife.has_pending(g2.extras):
			got = true
			break
		g2.day += 4
	t.check(got, "des veillées surviennent au repos (en 12 repos)")
	t.check(CampLife.pending(g2.extras)["id"] != "mutiny", "pas de mutinerie au repos ordinaire")
	var v: Dictionary = g2.camp_life_view()
	t.check(not v.is_empty() and (v["choices"] as Array).size() >= 2, "fenêtre décrite")
	g2.camp_life_choose(str(v["choices"][0]["id"]) if not bool(v["choices"][0]["disabled"]) else str(CampLife.DEFAULTS[str(CampLife.pending(g2.extras)["id"])]))
	t.check(not CampLife.has_pending(g2.extras), "choix appliqué")


func _veteran(g: Node) -> Unit:
	var m: Unit = g.roster[0]
	m.level = 8
	m.weapon = "hache"
	m.weapon_q = 1
	m.head = "casque"
	m.arm_h = m.head_armor_max()
	return m


func test_retirement() -> void:
	var g: Node = t.new_game(31)
	var m: Unit = g.roster[1]
	t.check(Legacy.retire_block(m, g.roster.size()) != "", "un novice ne peut pas se retirer")
	m.injuries.append({"id": str(Data.INJURIES.keys()[0]), "days_left": -1})
	t.eq(Legacy.retire_block(m, g.roster.size()), "", "gravement blessé : possible")
	m.injuries.clear()
	var v: Unit = _veteran(g)
	t.eq(Legacy.retire_block(v, g.roster.size()), "", "niveau 8 : possible")
	t.check(Legacy.retire_block(v, 1) != "", "jamais le dernier homme")
	t.check(Legacy.retire_block(v, 5, true) != "", "jamais en bataille")
	var gear: Array = Loot.gear_items(v)
	var stash0: int = g.inventory.size()
	var n0: int = g.roster.size()
	var wage0: int = g.wages()
	var xp0: float = Legacy.xp_mult(g.extras)
	t.check(g.retire_man(v.id, "instructor", "weapon"), "retraite acceptée")
	t.eq(g.roster.size(), n0 - 1, "il quitte la compagnie")
	t.check(g.member(v.id) == null and g.wages() == wage0 - v.wage, "il ne coûte plus de solde")
	t.check(Legacy.xp_mult(g.extras) > xp0 and Legacy.has_instructor(g.extras), "instructeur : bonus d'XP")
	var st: Dictionary = Legacy.state(g.extras)
	t.eq((st["heirlooms"] as Array).size(), 1, "un objet de famille")
	var h: Dictionary = st["heirlooms"][0]
	t.check(str(h["name"]).contains(v.unit_name) and int(h["amt"]) > 0, "objet nommé, avec un bonus")
	t.eq(g.inventory.size(), stash0 + gear.size() - 1, "le reste de l'équipement rejoint la réserve")
	t.eq(str((h["item"] as Dictionary)["key"]), "hache", "l'objet de famille est son arme")
	t.eq(int(((h["item"] as Dictionary).get("q", 0))), 1, "le grade est conservé")
	t.eq(Legacy.state(g.extras)["retired"].size(), 1, "inscrit aux retraités")
	t.check(not Chronicle.entries(g.extras, "retire").is_empty(), "consigné au journal")
	# un seul instructeur actif
	var v2: Unit = g.roster[0]
	v2.level = 9
	t.check(not g.retire_man(v2.id, "instructor", ""), "second instructeur refusé")
	t.check(g.member(v2.id) != null, "…et il reste dans la compagnie")
	t.check(g.retire_man(v2.id, "memorial", ""), "retraite honorée possible")
	t.eq(Legacy.state(g.extras)["retired"].size(), 2, "deux retraités")


func test_heirloom_transfer() -> void:
	var g: Node = t.new_game(31)
	var v: Unit = _veteran(g)
	var bg: String = v.background
	g.retire_man(v.id, "memorial", "weapon")
	var h: Dictionary = Legacy.state(g.extras)["heirlooms"][0]
	var same: Unit = null
	for u in g.roster:
		if u.background == bg:
			same = u
	if same == null:
		same = g.roster[0]
		same.background = bg
	var skill_before: int = int(same.get(str(h["stat"])))
	var other: Unit = null
	for u in g.roster:
		if u.background != bg:
			other = u
			break
	if other != null:
		t.check(not g.bestow_heirloom(int(h["id"]), other.id), "origine différente : refusé")
	t.check(g.bestow_heirloom(int(h["id"]), same.id), "remis à un homme de la même origine")
	t.eq(same.weapon, "hache", "il porte l'arme")
	t.eq(int(same.get(str(h["stat"]))), skill_before + int(h["amt"]), "bonus accordé")
	t.check(not Legacy.held_by(g.extras, same).is_empty(), "porteur reconnu")
	t.check(not g.bestow_heirloom(int(h["id"]), same.id), "pas deux fois")
	# fils / fille de
	var g2: Node = t.new_game(32)
	var v2: Unit = _veteran(g2)
	g2.retire_man(v2.id, "memorial", "body")
	var h2: Dictionary = Legacy.state(g2.extras)["heirlooms"][0]
	g2.gold = 5000
	var n: int = g2.roster.size()
	var price: int = Legacy.heir_price(h2)
	t.check(price > 0, "prix de la recrue")
	t.check(g2.hire_heir(int(h2["id"])), "recrue engagée")
	t.eq(g2.roster.size(), n + 1, "elle rejoint la compagnie")
	var son: Unit = g2.roster[g2.roster.size() - 1]
	t.check(son.unit_name.contains("de " + v2.unit_name) and son.background == v2.background and son.backstory != "", "fils ou fille de l'ancien")
	t.check(g2.gold == 5000 - price, "payée à demi-tarif")


func test_stats_history() -> void:
	var ex: Dictionary = {}
	for d in range(1, 1500):
		StatsHistory.record(ex, d, {"gold": d * 3, "renown": d, "men": 5 + d % 3, "wins": d / 10, "losses": d / 30, "fallen": d / 50, "food": 20})
	var pts: Array = StatsHistory.state(ex)["pts"]
	t.check(pts.size() <= StatsHistory.MAX_POINTS, "historique borné (%d)" % pts.size())
	t.eq(int(pts[pts.size() - 1][0]), 1499, "le dernier jour est conservé")
	t.eq(int(pts[0][0]), 1, "le début est conservé")
	var sorted: bool = true
	for i in range(1, pts.size()):
		if int(pts[i][0]) <= int(pts[i - 1][0]):
			sorted = false
	t.check(sorted, "jours croissants après éclaircissement")
	StatsHistory.record(ex, 1499, {"gold": 1})
	t.eq(StatsHistory.series(ex, "gold")[-1][1], 1, "même jour : remplacé")
	StatsHistory.record_battle(ex, {"kind": "contract", "type_contract": "hunt"}, true)
	StatsHistory.record_battle(ex, {"kind": "contract", "type_contract": "hunt"}, false)
	StatsHistory.record_battle(ex, {"kind": "ambush"}, true)
	var bt: Array = StatsHistory.by_type(ex)
	t.eq(bt[0][0], "hunt", "les types sont triés par fréquence")
	t.eq([bt[0][2], bt[0][3]], [1, 1], "victoires et défaites par type")
	t.eq(StatsHistory.type_of({"kind": "inconnu"}), "other", "type inconnu : autres")
	# état abîmé : valeurs par défaut, sans erreur
	var bad: Dictionary = {"stats_history": {"pts": [[1, 2], "x", [1, 2, 3, 4, 5, 6, 7, 8]], "by_type": {"kill": "z", "hunt": [2, 3]}}}
	var st: Dictionary = StatsHistory.state(bad)
	t.eq((st["pts"] as Array).size(), 1, "points incomplets écartés")
	t.eq(st["by_type"], {"hunt": [2, 3]}, "types abîmés écartés")
	t.eq(StatsHistory.state({}), {"pts": [], "by_type": {}}, "extras vide : défauts")


func test_save_and_old_saves() -> void:
	var g: Node = t.new_game(41)
	g.advance_time(3.0)
	var pts: int = (StatsHistory.state(g.extras)["pts"] as Array).size()
	t.check(pts >= 3, "un point par jour écoulé (%d)" % pts)
	CampLife.state(g.extras)["pending"] = _ev("song", g.roster[0], null, g.day)
	g.retire_man(_veteran(g).id, "instructor", "head")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = t.new_game(1)
	g2.from_dict(d)
	t.eq((StatsHistory.state(g2.extras)["pts"] as Array).size(), (StatsHistory.state(g.extras)["pts"] as Array).size(), "historique sauvegardé")
	t.check(CampLife.has_pending(g2.extras) and CampLife.pending(g2.extras)["id"] == "song", "veillée en attente sauvegardée")
	t.check(Legacy.has_instructor(g2.extras) and Legacy.state(g2.extras)["heirlooms"].size() == 1, "instructeur et héritage sauvegardés")
	t.check(not Legacy.state(g2.extras)["heirlooms"][0]["item"].is_empty(), "objet de famille intact")
	# ancienne sauvegarde : aucune de ces clés
	var old: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	old["extras"] = {}
	var g3: Node = t.new_game(1)
	g3.from_dict(old)
	t.check(not CampLife.has_pending(g3.extras) and not Legacy.has_instructor(g3.extras) and Legacy.xp_mult(g3.extras) == 1.0, "ancienne sauvegarde : valeurs par défaut")
	g3.advance_time(1.0)
	if g3.in_settlement():
		g3.rest()
	t.check(true, "ancienne sauvegarde : le jeu continue")
	# clés abîmées
	g3.extras["camp_life"] = "n'importe quoi"
	g3.extras["legacy"] = {"retired": "x", "heirlooms": [{"item": 3}, 7], "instructor": []}
	g3.extras["stats_history"] = []
	t.eq(CampLife.state(g3.extras)["pending"], {}, "camp_life abîmé : défauts")
	t.eq(Legacy.state(g3.extras)["heirlooms"], [], "legacy abîmé : défauts")
	t.eq(StatsHistory.state(g3.extras)["pts"], [], "stats_history abîmé : défauts")
