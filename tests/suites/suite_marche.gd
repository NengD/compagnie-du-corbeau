extends RefCounted
## Boutique à stock fini : génération (core/market.gd), achat, vente, vivres, sauvegarde.
var t


func test_generation() -> void:
	for kind in ["village", "city"]:
		var s: Array = Market.generate(kind, t.rng_seeded(5))
		t.check(s.size() > 5, "%s : rayon garni" % kind)
		t.check(Market.is_food(s[0]) and int(s[0]["qty"]) > 0, "%s : vivres en tête" % kind)
		for e in s:
			if Market.is_food(e):
				continue
			t.check(Loot.is_valid(e), "entrée valide : %s" % str(e))
			t.check(Loot.wear_ratio(e) >= Market.WEAR_MIN - 0.03 and Loot.wear_ratio(e) <= 1.0, "durabilité 0,5 à 1")
			if str(e["kind"]) == "tool":
				t.check(int(e["qty"]) >= 1, "outils empilés")
	# la ville vend plus de modèles que le village
	var v: Array = Market.generate("village", t.rng_seeded(5))
	var c: Array = Market.generate("city", t.rng_seeded(5))
	t.check(c.size() > v.size(), "la ville a plus de choix")
	t.eq(Market.generate("city", t.rng_seeded(9)), Market.generate("city", t.rng_seeded(9)), "même graine, même rayon")


func test_take_and_sold() -> void:
	var s: Array = [Market.food(20), Loot.item("weapon", "lance"), {"kind": "tool", "key": "pierre", "qty": 2}]
	t.eq(Market.take(s, 0), {}, "les vivres ne se prennent pas comme un objet")
	var it: Dictionary = Market.take(s, 2)
	t.eq(it, Loot.item("tool", "pierre"), "un outil sort seul")
	t.eq(int(s[2]["qty"]), 1, "l'empilement diminue")
	Market.take(s, 2)
	t.eq(s.size(), 2, "pile épuisée retirée")
	Market.add_sold(s, Loot.item("tool", "pierre"))
	Market.add_sold(s, Loot.item("tool", "pierre"))
	t.eq(int(s[2]["qty"]), 2, "outils revendus empilés")
	Market.add_sold(s, Loot.item("weapon", "hache"))
	t.eq(s.size(), 4, "arme revendue ajoutée")
	var big: Array = [Market.food(5)]
	for i in 100:
		Market.add_sold(big, Loot.item("weapon", "lance"))
	t.eq(big.size(), Market.MAX_ENTRIES, "rayon plafonné")
	t.check(Market.is_food(big[0]), "les vivres restent")


func test_filters() -> void:
	var s: Array = [Market.food(5), Loot.item("weapon", "lance"), Loot.item("body", "gambison"), Loot.item("shield")]
	t.eq(Market.filtered(s, "weapon"), [1] as Array[int], "filtre armes")
	t.eq(Market.filtered(s, "food"), [0] as Array[int], "filtre vivres")
	t.eq(Market.filtered(s, "all").size(), 4, "tout")
	t.eq(Market.inventory_filtered(s, "food").size(), 0, "pas de vivres dans la réserve")


func test_buy_sell() -> void:
	var g: Node = t.new_game(31)
	g.gold = 5000
	g.inventory.clear()
	var stock: Array = g.shop_stock()
	t.check(stock.size() > 0, "stock du lieu")
	var wi: int = -1
	for i in stock.size():
		if str(stock[i]["kind"]) == "weapon":
			wi = i
			break
	t.check(wi >= 0, "une arme en rayon")
	var e: Dictionary = stock[wi].duplicate()
	var price: int = g.stock_price(e)
	t.eq(price, g.price_of(Market.base_price(e)), "prix = règle de prix existante")
	var n_stock: int = stock.size()
	var gold: int = g.gold
	t.check(g.buy_item(wi), "achat")
	t.eq(g.gold, gold - price, "or débité")
	t.eq(g.inventory.size(), 1, "objet en réserve")
	t.eq(g.inventory[0]["key"], e["key"], "bon objet")
	t.check(g.shop_stock().size() <= n_stock, "il a quitté le rayon")
	# revente : retourne au rayon, au prix de revente
	var sp: int = g.sell_price(g.inventory[0])
	gold = g.gold
	var before: int = g.shop_stock().size()
	t.check(g.sell_item(0), "vente")
	t.eq(g.gold, gold + sp, "or crédité")
	t.eq(g.shop_stock().size(), before + 1, "l'objet rejoint le rayon")
	# pas assez d'or
	g.gold = 0
	t.check(not g.buy_item(g.shop_stock().size() - 1) or g.gold >= 0, "pas d'achat sans or")
	t.eq(g.shop_error, "Pas assez de couronnes.", "message or")
	# réserve pleine
	g.gold = 99999
	while g.inventory.size() < g.stash_size():
		g.inventory.append(Loot.item("weapon", "gourdin"))
	var wi2: int = Market.filtered(g.shop_stock(), "weapon")[0]
	t.check(not g.buy_item(wi2), "réserve pleine : refus")
	t.eq(g.shop_error, "Réserve pleine.", "message réserve pleine")
	t.check(not g.buy_item(999), "indice invalide")
	g.leave_settlement()
	t.check(not g.buy_item(0), "pas de marchand sur la route")
	t.eq(g.shop_stock().size(), 0, "pas de stock hors d'un lieu")


func test_food() -> void:
	var g: Node = t.new_game(32)
	g.gold = 5000
	g.provisions = 0
	var fi: int = Market.filtered(g.shop_stock(), "food")[0]
	var qty: int = int(g.shop_stock()[fi]["qty"])
	var lot: int = g.food_lot(g.shop_stock()[fi])
	t.eq(lot, mini(Data.PROVISIONS_PACK, qty), "un lot de vivres")
	var cost: int = g.stock_price(g.shop_stock()[fi])
	var gold: int = g.gold
	t.check(g.buy_item(fi), "achat de vivres")
	t.eq(g.provisions, lot, "compteur de vivres augmenté")
	t.eq(g.gold, gold - cost, "or débité")
	t.eq(cost, g.food_cost(lot), "prix des vivres existant")
	g.provisions = g.provisions_cap()
	t.check(not g.buy_item(Market.filtered(g.shop_stock(), "food")[0]), "vivres au maximum : refus")


func test_save_and_migration() -> void:
	var g: Node = t.new_game(33)
	var s: Dictionary = g.settlement()
	var before: Array = (g.shop_stock() as Array).duplicate(true)
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.world.to_dict()))
	var w: World = World.from_dict(d, t.rng_seeded(1))
	var s2: Dictionary = w.settlement_by_id(str(s["id"]))
	t.eq((s2["stock"] as Array).size(), before.size(), "stock sérialisé")
	t.eq(s2["stock"][0]["kind"], "food", "vivres conservés")
	# ancienne sauvegarde : pas de clé « stock »
	for sd in d["settlements"]:
		sd.erase("stock")
	var w2: World = World.from_dict(d, t.rng_seeded(1))
	t.check(not w2.settlement_by_id(str(s["id"])).has("stock"), "ancienne sauvegarde sans stock")
	s.erase("stock")
	t.check(g.shop_stock().size() > 0, "stock généré à la volée")
	# une ré-approvisionnement le régénère
	s["restock_day"] = 0
	g.enter_settlement(str(s["id"]))
	t.check(s.has("stock") and s["stock"].size() > 0, "réapprovisionnement")
