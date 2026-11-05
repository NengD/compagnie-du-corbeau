extends RefCounted
## Butin, inventaire, vente / équipement, emplacements de sauvegarde, réglages.
var t


func _foe(weapon: String, head: String, body: String, shield: bool, ah: int, ab: int) -> Unit:
	var u: Unit = t.mk(weapon, "e")
	u.head = head
	u.body = body
	u.shield = shield
	u.arm_h = ah
	u.arm_b = ab
	u.dead = true
	return u


func test_loot_pieces() -> void:
	var ghoul: Unit = _foe("griffes", "none", "none", false, 0, 0)
	t.eq(Loot.pieces_of(ghoul).size(), 0, "les griffes et la peau d'une goule ne sont pas des objets")
	var chief: Unit = _foe("epee", "heaume", "mailles", true, 160, 130)
	t.eq(Loot.pieces_of(chief).size(), 4, "arme, bouclier, casque, armure")
	var hurt: Unit = _foe("hache", "casque", "gambison", false, 0, 65)
	var pieces: Array = Loot.pieces_of(hurt)
	t.eq(pieces.size(), 3, "pièces d'un blessé")
	t.check(Loot.recover_chance(pieces[1]) < Loot.recover_chance(pieces[2]), "casque détruit moins récupérable qu'une armure intacte")


func test_loot_roll() -> void:
	var rng: RandomNumberGenerator = t.rng_seeded(11)
	var alive: Unit = _foe("epee", "heaume", "mailles", true, 160, 130)
	alive.dead = false
	t.eq(Loot.roll_battle([alive], rng).size(), 0, "un ennemi vivant ne laisse rien")
	var player: Unit = _foe("epee", "heaume", "mailles", true, 160, 130)
	player.side = "p"
	t.eq(Loot.roll_battle([player], rng).size(), 0, "les morts du joueur ne comptent pas")
	var intact: int = 0
	var broken: int = 0
	for i in 300:
		for it in Loot.roll_battle([_foe("gourdin", "casque", "none", false, 90, 0)], rng):
			if it["kind"] == "head":
				intact += 1
		for it in Loot.roll_battle([_foe("gourdin", "casque", "none", false, 0, 0)], rng):
			if it["kind"] == "head":
				broken += 1
	t.check(intact > broken + 60, "l'armure intacte est bien plus souvent récupérée (%d contre %d)" % [intact, broken])
	var a: Array = Loot.roll_battle([_foe("hache", "casque", "mailles", true, 90, 130)], t.rng_seeded(5))
	var b: Array = Loot.roll_battle([_foe("hache", "casque", "mailles", true, 90, 130)], t.rng_seeded(5))
	t.eq(a, b, "même graine, même butin")
	var got: int = 0
	for i in 400:
		if not Loot.roll_contract_bonus(3, rng).is_empty():
			got += 1
	t.check(got > 40 and got < 250, "objet rare de contrat occasionnel (%d/400)" % got)
	for i in 50:
		var rare: Dictionary = Loot.roll_contract_bonus(2, rng)
		if not rare.is_empty():
			t.check(Loot.is_valid(rare), "objet rare valide")


func test_equip_rules() -> void:
	var u: Unit = t.mk("lance", "p")
	u.shield = true
	u.head = "none"
	t.check(not Loot.can_equip(u, Loot.item("shield")), "pas deux boucliers")
	var removed: Array = Loot.equip(u, Loot.item("weapon", "arc"))
	t.eq(u.weapon, "arc", "arme équipée")
	t.check(not u.shield, "arme à deux mains : bouclier retiré")
	t.eq(removed.size(), 2, "ancienne arme et bouclier rendus")
	t.check(not Loot.can_equip(u, Loot.item("shield")), "pas de bouclier avec une arme à deux mains")
	removed = Loot.equip(u, Loot.item("head", "heaume"))
	t.eq(removed.size(), 0, "tête nue : rien à rendre")
	t.eq(u.arm_h, 160, "armure de tête pleine")
	removed = Loot.equip(u, Loot.item("head", "casque"))
	t.eq(removed[0]["key"], "heaume", "l'ancien casque revient")
	u.weapon = "hache"
	t.check(Loot.can_equip(u, Loot.item("shield")), "bouclier avec arme à une main")


func test_game_sell_equip() -> void:
	var g: Node = t.new_game(21)
	var m: Unit = g.roster[0]
	g.inventory = [Loot.item("body", "mailles"), Loot.item("weapon", "epee"), Loot.item("shield")]
	t.check(g.in_settlement(), "départ en ville")
	var gold: int = g.gold
	var expect: int = g.price_of(int(round(700 * 0.4)))
	t.eq(g.sell_price(g.inventory[0]), expect, "prix de vente = 40 % × coefficient du lieu")
	t.check(g.sell_item(0), "vente")
	t.eq(g.gold, gold + expect, "or crédité")
	t.eq(g.inventory.size(), 2, "objet retiré de l'inventaire")
	t.check(not g.sell_item(9), "indice invalide")
	var old_weapon: String = m.weapon
	t.check(g.equip_from_inventory(m, 0), "équipement de l'épée")
	t.eq(m.weapon, "epee", "épée équipée")
	t.check(g.inventory.any(func(it: Dictionary) -> bool: return it["kind"] == "weapon" and it["key"] == old_weapon), "ancienne arme dans l'inventaire")
	g.leave_settlement()
	t.check(not g.sell_item(0), "pas de vente hors d'un lieu")
	var before: int = g.inventory.size()
	var worn_head: String = m.head
	g.enter_settlement(g.world.settlements[0]["id"])
	g.dismiss(m.id)
	t.check(g.inventory.size() > before, "l'équipement d'un homme renvoyé va à l'inventaire")
	t.check(worn_head == "none" or g.inventory.any(func(it: Dictionary) -> bool: return it["kind"] == "head" and it["key"] == worn_head), "son casque aussi")


func test_game_loot_after_battle() -> void:
	var g: Node = t.new_game(33)
	g.accept_contract(0)
	g.leave_settlement()
	g.start_battle(g.active_contract)
	var b: BattleState = g.battle
	for u in b.units:
		if u.side == "e":
			u.dead = true
			u.hp = 0
	b.check_end()
	t.eq(b.over, "win", "victoire")
	var loot: Array = g.prepare_loot().duplicate(true)
	t.check(loot.size() > 0, "du butin sur des brigands/goules morts")
	t.eq(g.prepare_loot(), loot, "le butin n'est tiré qu'une fois")
	var json: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	t.eq(json["pending_loot"].size(), loot.size(), "butin en attente sérialisé")
	var inv_before: int = g.inventory.size()
	g.finish_battle()
	t.eq(g.inventory.size(), inv_before + loot.size(), "butin versé à l'inventaire")
	t.eq(g.pending_loot.size(), 0, "butin en attente vidé")
	var g2: Node = load("res://autoload/Game.gd").new()
	g2.autosave = false
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	t.eq(g2.inventory, g.inventory, "inventaire aller-retour")
	var old: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	old.erase("inventory")
	old.erase("pending_loot")
	old.erase("pending_loot_ready")
	g2.from_dict(old)
	t.eq(g2.inventory.size(), 0, "ancienne sauvegarde : inventaire vide par défaut")
	# défaite : pas de butin
	var g3: Node = t.new_game(34)
	g3.accept_contract(0)
	g3.leave_settlement()
	g3.start_battle(g3.active_contract)
	g3.battle.end_battle("retreat")
	t.eq(g3.prepare_loot().size(), 0, "pas de butin en cas de retraite")


func test_save_slots() -> void:
	var g: Node = t.new_game(9)
	g.gold = 1234
	g.delete_slot(2)
	t.check(g.slot_info(2).is_empty(), "emplacement vide")
	t.check(not g.save_to_slot(0), "l'emplacement 0 est réservé à l'autosave")
	t.check(not g.save_to_slot(4), "emplacement hors limites")
	t.check(g.save_to_slot(2), "écriture de l'emplacement 2")
	var info: Dictionary = g.slot_info(2)
	t.eq(info["gold"], 1234, "or de l'emplacement")
	t.eq(info["men"], g.roster.size(), "hommes de l'emplacement")
	t.eq(info["day"], 1, "jour de l'emplacement")
	t.check(str(info["date"]) != "", "date de l'emplacement")
	g.gold = 5
	g.inventory = [Loot.item("weapon", "hache")]
	t.check(g.load_slot(2), "chargement de l'emplacement")
	t.eq(g.gold, 1234, "or restauré")
	t.eq(g.inventory.size(), 0, "inventaire de la sauvegarde restauré")
	g.delete_slot(2)
	t.check(g.slot_info(2).is_empty(), "emplacement supprimé")
	t.check(not g.load_slot(2), "charger un emplacement vide échoue")
	var path: String = ProjectSettings.globalize_path("user://savegame.json")
	var had_auto: bool = FileAccess.file_exists("user://savegame.json")
	var stamp: int = FileAccess.get_modified_time("user://savegame.json") if had_auto else 0
	g.autosave = false
	g.save()
	t.eq(FileAccess.get_modified_time("user://savegame.json") if had_auto else 0, stamp, "autosave désactivée : aucune écriture (%s)" % path.get_file())


func test_settings_defaults() -> void:
	var s: Node = load("res://autoload/Settings.gd").new()
	s.persist = false
	t.check(s.master_volume >= 0.0 and s.master_volume <= 1.0, "volume général borné")
	s.set_value("music_volume", 3.0)
	t.eq(s.music_volume, 1.0, "volume borné à 1")
	s.set_value("battle_speed", 99)
	t.eq(s.battle_speed, s.BATTLE_SPEEDS.size() - 1, "vitesse bornée")
	t.check(s.battle_speed_factor() > 0.0, "facteur de vitesse positif")
	s.free()
