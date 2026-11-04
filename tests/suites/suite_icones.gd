extends RefCounted
## Couverture des icônes d'objets (ItemIcons) : une icône par clé de Data, repli sûr, rareté.
var t

const FOOD_KEYS: Array = ["pain", "viande", "fromage", "ration"]


func test_icone_pour_chaque_cle() -> void:
	for k: String in Data.WPN:
		t.check(ItemIcons.get_icon("weapon", k) != null, "icône arme " + k)
	for k: String in Data.HEAD:
		if k != "none":
			t.check(ItemIcons.get_icon("head", k) != null, "icône casque " + k)
	for k: String in Data.BODY:
		if k != "none":
			t.check(ItemIcons.get_icon("body", k) != null, "icône armure " + k)
	for k: String in Data.TOOLS:
		t.check(ItemIcons.get_icon("tool", k) != null, "icône outil " + k)
	for k: String in FOOD_KEYS:
		t.check(ItemIcons.get_icon("food", k) != null, "icône vivres " + k)
	t.check(ItemIcons.get_icon("shield", "") != null, "icône bouclier")
	for k: String in Data.UNIQUES:
		var kind: String = str(Data.UNIQUES[k]["kind"])
		t.check(ItemIcons.get_icon(kind, k) != null, "icône unique " + k)
		t.check(ItemIcons.get_icon(kind, k) != ItemIcons.get_icon(kind, str(Data.UNIQUES[k]["look"])), "unique %s distinct de son modèle" % k)


func test_repli_sur() -> void:
	t.check(ItemIcons.unknown() != null, "icône « ? » présente")
	t.check(ItemIcons.get_icon_for_item({}) == ItemIcons.unknown(), "objet vide -> ?")
	t.check(ItemIcons.get_icon_for_item({"kind": "weapon", "key": "n_importe_quoi"}) == ItemIcons.unknown(), "clé inconnue -> ?")
	t.check(ItemIcons.get_icon_for_item({"kind": "bizarre", "key": "x"}) == ItemIcons.unknown(), "genre inconnu -> ?")
	t.check(ItemIcons.get_icon_for_item({"kind": "weapon", "key": "hache"}) == ItemIcons.get_icon("weapon", "hache"), "cache partagé")
	t.check(ItemIcons.get_icon("head", "none") == null, "tête nue sans icône")


func test_rarete() -> void:
	t.eq(ItemIcons.rarity({"kind": "weapon", "key": "hache"}), "common", "commun")
	t.eq(ItemIcons.rarity({"kind": "weapon", "key": "hache", "quality": 1}), "quality", "qualité")
	t.eq(ItemIcons.rarity({"kind": "weapon", "key": "u_epee_corbeau"}), "unique", "unique")
	t.check(ItemIcons.quality_tint({"kind": "weapon", "key": "u_epee_corbeau"}) == ItemIcons.COL_UNIQUE, "teinte unique")
	t.check(ItemIcons.quality_tint({"kind": "head", "key": "casque"}) == ItemIcons.COL_COMMON, "teinte commune")
