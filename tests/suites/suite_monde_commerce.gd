extends RefCounted
## Commerce de marchandises (core/trade.gd, trade_data.gd) et guerres entre factions (core/wars.gd) : prix, achats, mémoire des prix,
## anciennes sauvegardes, caravanes, naissance et fin de guerre, changement de propriétaire, aucune faction sans lieu.
var t

var _w: World = null


func _world() -> World:
	if _w == null:
		_w = World.generate(t.rng_seeded(5), 0)
		Factions.assign_owners(_w)
	return _w


func _fresh_world() -> World:
	var w: World = World.generate(t.rng_seeded(5), 0)
	Factions.assign_owners(w)
	return w


# --- Commerce ---

func test_prix_bornes_et_coherents() -> void:
	var w: World = _world()
	var makes_seen: int = 0
	var wants_seen: int = 0
	for s in w.settlements:
		for g in TradeData.ORDER:
			var base: float = float(TradeData.GOODS[g]["base"])
			for day in [1, 2, 3, 4, 10, 37]:
				var p: int = Trade.mid_price(s, g, day)
				t.check(float(p) >= base * TradeData.MIN_MULT * 0.95 - 1.0 and float(p) <= base * TradeData.MAX_MULT * 1.05 + 1.0, "prix borné : %s %s j%d = %d" % [g, s["id"], day, p])
				t.check(Trade.sell_price(s, g, day) < Trade.buy_price(s, g, day) or p <= 2, "on revend moins cher qu'on n'achète")
				t.eq(p, Trade.mid_price(s, g, day), "même lieu, même jour, même prix")
			var r: String = Trade.role(s, g)
			if r == "make":
				makes_seen += 1
				t.check(Trade.mid_price(s, g, 5) < int(round(base)), "produit local moins cher que la base")
			elif r == "want":
				wants_seen += 1
				t.check(Trade.mid_price(s, g, 5) > int(round(base)), "bien demandé plus cher que la base")
		t.check(Trade.makes(s).size() >= 1 and Trade.wants(s).size() >= 1, "chaque lieu produit et demande quelque chose")
		for g in Trade.makes(s):
			t.check(not Trade.wants(s).has(g), "jamais produit ET demandé")
	t.check(makes_seen > 0 and wants_seen > 0, "des rôles existent")


func test_variation_selon_le_jour() -> void:
	var s: Dictionary = _world().settlements[0]
	var seen: Dictionary = {}
	for day in range(1, 60, 3):
		seen[Trade.mid_price(s, "epices", day)] = true
	t.check(seen.size() > 1, "le prix bouge d'un jour à l'autre")
	t.eq(Trade.mid_price(s, "epices", 7), Trade.mid_price(s, "epices", 8), "stable dans une période de 3 jours")


func test_arbitrage_possible() -> void:
	# il existe au moins une paire de lieux où acheter ici et revendre là rapporte (après marge)
	var w: World = _world()
	var best: int = 0
	for g in TradeData.ORDER:
		var lo: int = 99999
		var hi: int = 0
		for s in w.settlements:
			lo = mini(lo, Trade.buy_price(s, g, 5))
			hi = maxi(hi, Trade.sell_price(s, g, 5))
		best = maxi(best, hi - lo)
	t.check(best > 5, "des écarts de prix à exploiter (%d)" % best)


func test_capacite_achat_vente() -> void:
	var ex: Dictionary = {}
	var st: Dictionary = Trade.state(ex)
	t.eq(Trade.total(st), 0, "cale vide au départ")
	t.eq(Trade.capacity(5, 0), TradeData.CARGO_BASE + 5 * TradeData.CARGO_PER_MAN, "capacité selon les hommes")
	t.check(Trade.capacity(5, 2) > Trade.capacity(5, 0), "l'entrepôt agrandit la cale")
	var r: Dictionary = Trade.buy(st, "sel", 4, 20, 1000, 10)
	t.check(bool(r["ok"]) and int(r["qty"]) == 4 and int(r["cost"]) == 80, "achat de 4 sel")
	r = Trade.buy(st, "sel", 10, 20, 1000, 6)
	t.eq(int(r["qty"]), 6, "achat limité par la place")
	r = Trade.buy(st, "sel", 1, 20, 1000, 0)
	t.check(not bool(r["ok"]), "cale pleine : refus")
	r = Trade.buy(st, "vin", 5, 30, 70, 10)
	t.eq(int(r["qty"]), 2, "achat limité par l'or")
	r = Trade.buy(st, "vin", 1, 30, 10, 10)
	t.check(not bool(r["ok"]), "pas assez d'or : refus")
	t.eq(Trade.total(st), 12, "total de la cargaison")
	var sr: Dictionary = Trade.sell(st, "sel", 5, 30)
	t.check(bool(sr["ok"]) and int(sr["gain"]) == 150, "vente de 5 sel")
	t.eq(Trade.qty_of(st, "sel"), 5, "reste en cale")
	sr = Trade.sell(st, "sel", 99, 30)
	t.eq(int(sr["qty"]), 5, "on ne vend pas plus que ce qu'on a")
	t.check(not st["cargo"].has("sel") and not st["paid"].has("sel"), "bien épuisé retiré")
	t.check(not bool(Trade.sell(st, "fer", 1, 10)["ok"]), "rien à vendre : refus")


func test_memoire_des_prix() -> void:
	var w: World = _world()
	var st: Dictionary = Trade.state({})
	Trade.remember(st, w.settlements[0], 4)
	Trade.remember(st, w.settlements[1], 9)
	var k: Array = Trade.known(st, "fer")
	t.eq(k.size(), 2, "deux lieux mémorisés")
	t.check(int(k[0]["price"]) >= int(k[1]["price"]), "triés du plus cher au moins cher")
	t.eq(int(st["seen"][str(w.settlements[1]["id"])]["day"]), 9, "jour de la visite retenu")
	Trade.remember(st, w.settlements[0], 20)
	t.eq(Trade.known(st, "fer").size(), 2, "une revisite remplace l'ancienne note")


func test_ancienne_sauvegarde_et_normalisation() -> void:
	var ex: Dictionary = {}
	var st: Dictionary = Trade.state(ex)
	t.check(st["cargo"].is_empty() and st["seen"].is_empty(), "clé absente = valeurs par défaut")
	var bad: Dictionary = {"trade": {"cargo": {"sel": 3, "inconnu": 9, "vin": -2}, "paid": {"sel": 50}, "seen": {"s1": "n'importe quoi", "s2": {"name": "X", "day": 3, "p": {"sel": 0, "zzz": 4}}}}}
	var n: Dictionary = Trade.state(bad)
	t.eq(n["cargo"], {"sel": 3}, "biens inconnus ou négatifs écartés")
	t.eq(n["paid"], {"sel": 50}, "coût conservé")
	t.eq(n["seen"].size(), 1, "entrée invalide écartée")
	t.eq(int(n["seen"]["s2"]["p"]["sel"]), 1, "prix minimal 1")
	var j: Variant = JSON.parse_string(JSON.stringify(bad))
	t.eq(Trade.state({"trade": j["trade"]})["cargo"], {"sel": 3}, "aller-retour JSON")


func test_trade_dans_game() -> void:
	var g: Node = t.new_game(31)
	g.gold = 2000
	var cap: int = g.cargo_capacity()
	t.eq(cap, Trade.capacity(g.roster.size(), 0), "capacité de la compagnie")
	var view: Array = g.trade_view()
	t.eq(view.size(), TradeData.ORDER.size(), "toutes les marchandises à l'étal")
	t.eq(Trade.state(g.extras)["seen"].size(), 1, "prix du lieu mémorisés à l'ouverture")
	var gold0: int = g.gold
	t.check(g.trade_buy("grain", 3), "achat via Game")
	t.eq(Trade.qty_of(Trade.state(g.extras), "grain"), 3, "cargaison mise à jour")
	t.check(g.gold < gold0, "or dépensé")
	t.eq(g.inventory.size(), 0, "la réserve d'objets ne bouge pas")
	t.check(not g.trade_buy("grain", 1000) or Trade.total(Trade.state(g.extras)) <= cap, "jamais au-delà de la capacité")
	var before: int = g.gold
	t.check(g.trade_sell("grain", 1), "vente via Game")
	t.check(g.gold > before, "or gagné")
	# sauvegarde
	var d: Dictionary = g.to_dict()
	var g2: Node = t.new_game(32)
	g2.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq(Trade.state(g2.extras)["cargo"], Trade.state(g.extras)["cargo"], "cargaison sauvegardée")
	t.eq(Trade.state(g2.extras)["seen"].size(), Trade.state(g.extras)["seen"].size(), "prix connus sauvegardés")
	# ancienne sauvegarde sans extras
	d.erase("extras")
	var g3: Node = t.new_game(33)
	g3.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq(Trade.total(Trade.state(g3.extras)), 0, "ancienne sauvegarde : cale vide")
	t.eq(Wars.list_of(g3.extras).size(), 0, "ancienne sauvegarde : pas de guerre")


func test_caravane() -> void:
	var rng: RandomNumberGenerator = t.rng_seeded(3)
	var cs: Array = []
	for i in 40:
		cs.append({"type_contract": "escort", "title": "Escorte vers Quelquepart", "desc": "x", "pay": 200})
	cs.append({"type_contract": "kill", "title": "Chasse", "desc": "", "pay": 100})
	Trade.tag_caravans(cs, rng)
	var n: int = 0
	for c in cs:
		if Trade.is_caravan(c):
			n += 1
			t.check(str(c["title"]).begins_with("Caravane vers"), "titre de caravane")
	t.check(n > 5 and n < 40, "une part des escortes seulement (%d)" % n)
	t.check(not Trade.is_caravan(cs[40]), "un contrat de combat n'est jamais une caravane")
	var c: Dictionary = {"type_contract": "escort", "caravan": true, "pay": 200}
	Trade.on_accept(c, 6)
	t.check(Trade.settle_caravan(c.duplicate(true), 6).contains("intacte"), "prime si intacte")
	var c2: Dictionary = c.duplicate(true)
	Trade.settle_caravan(c2, 6)
	t.check(int(c2["pay"]) > 200, "prime ajoutée à la paie")
	var c3: Dictionary = c.duplicate(true)
	Trade.settle_caravan(c3, 5)
	t.eq(int(c3["pay"]), 200, "pas de prime si un homme est tombé")
	var c4: Dictionary = {"type_contract": "escort", "pay": 200}
	t.eq(Trade.settle_caravan(c4, 3), "", "escorte ordinaire : rien")


# --- Guerres ---

func _force_war(w: World, extras: Dictionary, a: String, b: String, day: int = 10) -> void:
	var st: Dictionary = Wars.state(extras, true)
	(st["list"] as Array).append({"a": a, "b": b, "start": day, "len": 30, "score": 0, "flips": 0})


func test_naissance_et_fin() -> void:
	var w: World = _fresh_world()
	var ex: Dictionary = {}
	var rng: RandomNumberGenerator = t.rng_seeded(11)
	var born: int = -1
	var max_wars: int = 0
	var ended: bool = false
	for day in range(1, 400):
		var lines: Array = Wars.daily(ex, w, rng, day)
		var n: int = Wars.list_of(ex).size()
		max_wars = maxi(max_wars, n)
		if born < 0 and n > 0:
			born = day
			t.check(day >= Wars.FIRST_DAY, "pas de guerre avant le jour %d" % Wars.FIRST_DAY)
		if born >= 0 and n == 0:
			ended = true
	t.check(born > 0, "une guerre naît (jour %d)" % born)
	t.check(ended, "une guerre finit")
	t.check(max_wars <= Wars.MAX_WARS, "pas plus de %d guerres à la fois" % Wars.MAX_WARS)


func test_duree_d_une_guerre() -> void:
	var w: World = _fresh_world()
	var ex: Dictionary = {}
	var rng: RandomNumberGenerator = t.rng_seeded(21)
	var starts: Dictionary = {}
	var lens: Array = []
	for day in range(1, 600):
		Wars.daily(ex, w, rng, day)
		for war in Wars.list_of(ex):
			var key: String = "%s|%s|%d" % [war["a"], war["b"], war["start"]]
			if not starts.has(key):
				starts[key] = day
				t.check(int(war["len"]) >= Wars.LEN_MIN and int(war["len"]) <= Wars.LEN_MAX, "durée prévue 20 à 40 jours")
				t.check(Factions.relation(war["a"], war["b"]) == Factions.REL_RIVAL, "guerre entre rivales seulement")
			lens.append(day - int(starts[key]))
	for l in lens:
		t.check(int(l) <= Wars.LEN_MAX + 1, "aucune guerre ne dépasse 40 jours (%d)" % int(l))


func test_changement_de_proprietaire() -> void:
	var w: World = _fresh_world()
	var ex: Dictionary = {}
	var pairs: Array = Wars.eligible_pairs(Wars.state(ex), w)
	t.check(not pairs.is_empty(), "des paires éligibles")
	var a: String = str(pairs[0][0])
	var b: String = str(pairs[0][1])
	_force_war(w, ex, a, b)
	Wars.state(ex)["list"][0]["score"] = Wars.FLIP_AT
	var before_b: int = int(Wars.counts(w).get(b, 0))
	var before_a: int = int(Wars.counts(w).get(a, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var got: Array = []
	for day in range(11, 30):
		got.append_array(Wars.daily(ex, w, rng, day))
		if int(Wars.counts(w).get(a, 0)) > before_a:
			break
	t.check(int(Wars.counts(w).get(a, 0)) > before_a, "le vainqueur gagne un lieu")
	t.check(int(Wars.counts(w).get(b, 0)) < before_b, "le perdant en perd un")
	t.check(not got.is_empty() and str(got[0]).length() > 5, "une nouvelle est produite")
	# le lieu protégé ne change pas de mains
	var w2: World = _fresh_world()
	var ex2: Dictionary = {}
	_force_war(w2, ex2, a, b)
	var target: Dictionary = Wars.frontier_target(w2, a, b, [])
	var other: Dictionary = Wars.frontier_target(w2, a, b, [str(target["id"])])
	t.check(other.is_empty() or str(other["id"]) != str(target["id"]), "lieu protégé écarté")
	# les contrats du lieu passent au nouvel employeur
	var s: Dictionary = target
	s["contracts"] = [{"faction": b, "vs_faction": a, "pay": 100}]
	Wars.flip(s, a)
	t.eq(Factions.owner_of(s), a, "nouveau propriétaire")
	t.eq(str(s["contracts"][0]["faction"]), a, "contrat repris par le vainqueur")
	t.check(not s["contracts"][0].has("vs_faction"), "rivalité effacée")


func test_aucune_faction_sans_lieu() -> void:
	for seed_value in [2, 5, 9]:
		var w: World = World.generate(t.rng_seeded(seed_value), 0)
		Factions.assign_owners(w)
		var ex: Dictionary = {}
		var rng: RandomNumberGenerator = t.rng_seeded(seed_value * 7)
		var initial: Dictionary = Wars.counts(w)
		for day in range(1, 500):
			Wars.daily(ex, w, rng, day)
			if day % 10 == 0:
				for k in initial:
					if int(initial[k]) >= Wars.MIN_KEEP:
						t.check(int(Wars.counts(w).get(k, 0)) >= Wars.MIN_KEEP, "%s garde au moins %d lieux (j%d, graine %d)" % [k, Wars.MIN_KEEP, day, seed_value])
		for k in initial:
			if str(k) != "":
				t.check(int(Wars.counts(w).get(k, 0)) >= 1, "faction %s toujours présente" % k)
	# même en forçant un score écrasant pendant des siècles
	var w3: World = _fresh_world()
	var ex3: Dictionary = {}
	var pr: Array = Wars.eligible_pairs(Wars.state(ex3), w3)[0]
	_force_war(w3, ex3, str(pr[0]), str(pr[1]))
	var r3: RandomNumberGenerator = t.rng_seeded(4)
	for day in range(11, 40):
		if not Wars.list_of(ex3).is_empty():
			Wars.list_of(ex3)[0]["score"] = Wars.SCORE_MAX
		Wars.daily(ex3, w3, r3, day)
	t.check(int(Wars.counts(w3).get(str(pr[1]), 0)) >= Wars.MIN_KEEP, "un perdant écrasé garde ses derniers lieux")


func test_effets_sur_le_joueur() -> void:
	var ex: Dictionary = {}
	_force_war(_world(), ex, "roncevaux", "lys")
	var st: Dictionary = Wars.state(ex)
	var c: Dictionary = {"faction": "roncevaux", "pay": 200}
	Wars.apply_pay(st, c)
	t.check(int(c["pay"]) > 200, "prime majorée en temps de guerre")
	var p1: int = int(c["pay"])
	Wars.apply_pay(st, c)
	t.eq(int(c["pay"]), p1, "une seule fois par contrat")
	var calm: Dictionary = {"faction": "marches", "pay": 200}
	Wars.apply_pay(st, calm)
	t.eq(int(calm["pay"]), 200, "faction en paix : prime inchangée")
	var line: String = Wars.contract_done(ex, "roncevaux", 2)
	t.check(line != "", "le contrat pèse sur la guerre")
	t.eq(int(Wars.state(ex)["list"][0]["score"]), 2, "score en faveur de l'employeur (a)")
	Wars.contract_done(ex, "lys", 3)
	t.eq(int(Wars.state(ex)["list"][0]["score"]), -1, "score en faveur de b")
	t.eq(Wars.contract_done(ex, "givre", 1), "", "faction hors guerre : rien")
	# réputation et prix
	t.eq(Wars.price_mult(st, "lys", {"roncevaux": 30}), Wars.PRICE_MULT, "ennemi d'une faction qui nous estime : prix majorés")
	t.eq(Wars.price_mult(st, "lys", {"roncevaux": 30, "lys": 30}), 1.0, "mais pas si on est aussi estimé chez lui")
	t.eq(Wars.price_mult(st, "lys", {"roncevaux": 0}), 1.0, "réputation neutre : rien")
	t.eq(Wars.price_mult(st, "marches", {"roncevaux": 30}), 1.0, "faction hors guerre : rien")


func test_guerre_sauvegardee() -> void:
	var g: Node = t.new_game(44)
	var ex: Dictionary = g.extras
	var prs: Array = Wars.eligible_pairs(Wars.state(ex), g.world)
	if prs.is_empty():
		t.check(true, "monde sans paire éligible : rien à tester")
		return
	_force_war(g.world, ex, str(prs[0][0]), str(prs[0][1]))
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = t.new_game(45)
	g2.from_dict(d)
	t.eq(Wars.list_of(g2.extras).size(), 1, "guerre rechargée")
	t.eq(Wars.pairs(g2.extras)[0], [str(prs[0][0]), str(prs[0][1])] as Array, "mêmes belligérants")
	# avancer le temps avec le hook de Game ne casse rien
	g2.leave_settlement()
	g2.advance_time(3.0)
	t.check(g2.day >= 4, "le temps passe avec une guerre en cours")
