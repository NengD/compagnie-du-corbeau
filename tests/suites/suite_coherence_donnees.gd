extends RefCounted
## Cohérence entre les tables de Data : chaque clé citée existe ailleurs (armes, armures, familles, icônes). Garde-fou avant de découper Data.gd.
var t


func test_ennemis_et_origines_citent_des_equipements_connus() -> void:
	for table_name in ["FOE", "BG"]:
		var table: Dictionary = Data.FOE if table_name == "FOE" else Data.BG
		for k in table:
			var d: Dictionary = table[k]
			for w in d.get("w", []):
				t.check(Data.WPN.has(w), "%s.%s : arme connue (%s)" % [table_name, k, w])
			for h in d.get("head", []):
				t.check(str(h) == "none" or Data.HEAD.has(h), "%s.%s : casque connu (%s)" % [table_name, k, h])
			for bo in d.get("body", []):
				t.check(Data.BODY.has(bo), "%s.%s : armure connue (%s)" % [table_name, k, bo])


func test_armes_ont_un_nom_un_prix_et_une_icone() -> void:
	for k in Data.WPN:
		var w: Dictionary = Data.WPN[k]
		t.check(str(w.get("n", "")) != "", "arme %s : nom" % k)
		t.check(int(w.get("max", 0)) >= int(w.get("min", 0)), "arme %s : dégâts min <= max" % k)
		if str(k).begins_with("u_"):
			continue  # armes uniques : icône propre (ItemIcons)
		t.check(ResourceLoader.exists("res://assets/icons/%s.svg" % k) or ResourceLoader.exists("res://assets/icons/%s.png" % k) or ResourceLoader.exists("res://assets/icons_items/%s.png" % k) or ResourceLoader.exists("res://assets/icons_items/%s.svg" % k), "arme %s : icône" % k)


func test_familles_citent_des_objets_connus() -> void:
	for fam in Data.WEAPON_FAMILIES:
		for w in Data.WEAPON_FAMILIES[fam].get("weapons", []):
			t.check(Data.WPN.has(w) or str(w).begins_with("u_"), "famille d'armes %s : arme connue (%s)" % [fam, w])
	for fam in Data.ARMOR_FAMILIES:
		var d: Dictionary = Data.ARMOR_FAMILIES[fam]
		for h in d.get("head", []):
			t.check(Data.HEAD.has(h) or str(h) == "none" or str(h).begins_with("u_"), "famille d'armures %s : casque connu (%s)" % [fam, h])
		for bo in d.get("body", []):
			t.check(Data.BODY.has(bo) or str(bo) == "none" or str(bo).begins_with("u_"), "famille d'armures %s : armure connue (%s)" % [fam, bo])


func test_talents_ont_nom_rang_et_description() -> void:
	for k in Data.PERKS:
		var p: Dictionary = Data.PERKS[k]
		t.check(str(p.get("n", "")) != "" and str(p.get("d", p.get("desc", ""))) != "", "talent %s : nom et description" % k)
