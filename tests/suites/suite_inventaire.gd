extends RefCounted
## Inventaire : emplacements, glisser-déposer (core/inventory.gd), sac, capacité, tri, changement d'arme en bataille, écran.
var t  # le lanceur (voir tests/suites/README.md)


func _man(weapon: String = "epee", shield: bool = false, head: String = "none", body: String = "tunique") -> Unit:
	var u: Unit = t.mk(weapon, "p")
	u.shield = shield
	u.head = head
	u.arm_h = int(Data.HEAD[head]["a"])
	u.body = body
	u.arm_b = int(Data.BODY[body]["a"])
	return u


func _kinds(stash: Array) -> Array:
	return stash.map(func(it: Dictionary) -> String: return str(it["kind"]) + ":" + str(it["key"]))


# --- Équiper / déséquiper ---

func test_equiper_echange() -> void:
	var u: Unit = _man("gourdin")
	var stash: Array = [Loot.item("weapon", "epee"), Loot.item("head", "casque")]
	var r: Dictionary = Inventory.equip(stash, u, 0)
	t.check(r["ok"], "équiper l'épée")
	t.eq(u.weapon, "epee", "arme équipée")
	t.eq(_kinds(stash), ["head:casque", "weapon:gourdin"], "l'ancienne arme est rendue à la réserve")
	t.check(Inventory.equip(stash, u, 0)["ok"], "équiper le casque")
	t.eq(u.head, "casque", "casque équipé")
	t.eq(u.arm_h, 90, "armure du casque pleine")


func test_deux_mains_et_bouclier() -> void:
	var u: Unit = _man("epee", true)
	var stash: Array = [Loot.item("weapon", "arc")]
	var r: Dictionary = Inventory.equip(stash, u, 0)
	t.check(r["ok"], "arme à deux mains équipée")
	t.check(not u.shield, "le bouclier est retiré")
	t.check(_kinds(stash).has("shield:"), "le bouclier est dans la réserve")
	t.check(_kinds(stash).has("weapon:epee"), "l'épée aussi")
	# bouclier interdit avec une arme à deux mains
	var before: Array = stash.duplicate(true)
	var si: int = _kinds(stash).find("shield:")
	var r2: Dictionary = Inventory.move(stash, Inventory.in_stash(si), Inventory.at(u, "shield"))
	t.check(not r2["ok"], "bouclier refusé avec un arc")
	t.eq(stash, before, "rien n'a changé après un refus")
	t.check(not u.shield, "toujours sans bouclier")
	t.check(Inventory.auto_slot(u, Loot.item("shield")) == "bag0", "double-clic sur un bouclier : va dans le sac")


func test_deseqiper_et_poings() -> void:
	var u: Unit = _man("epee", true, "casque", "mailles")
	u.arm_b = 100  # armure abîmée
	var stash: Array = []
	t.check(Inventory.unequip(stash, u, "weapon")["ok"], "ranger l'arme")
	t.eq(u.weapon, "poings", "à mains nues")
	t.check(Inventory.unequip(stash, u, "body")["ok"], "retirer l'armure")
	t.eq(u.body, "none", "plus d'armure")
	t.eq(u.arm_b, 0, "armure à zéro")
	t.eq(stash[1]["arm"], 100, "l'armure rangée garde son état")
	t.check(Inventory.equip(stash, u, 1)["ok"], "remettre l'armure")
	t.eq(u.arm_b, 100, "armure abîmée conservée")
	t.check(not Inventory.unequip(stash, u, "head").is_empty(), "résultat renvoyé")
	t.check(not bool(Inventory.unequip(stash, u, "weapon")["ok"]), "rien à ranger : refus")


func test_usure_conservee() -> void:
	var u: Unit = _man("hache")
	u.weapon_dur = 12
	var stash: Array = []
	Inventory.unequip(stash, u, "weapon")
	t.eq(int(stash[0]["dur"]), 12, "usure de l'arme rangée")
	Inventory.equip(stash, u, 0)
	t.eq(u.weapon_dur_now(), 12, "usure retrouvée à l'équipement")
	u.shield = true
	u.shield_dur = 7
	var other: Unit = _man("gourdin")
	t.check(Inventory.give(stash, u, "shield", other)["ok"], "don du bouclier")
	t.eq(other.shield_dur_now(), 7, "usure du bouclier suit le don")
	t.check(not u.shield and other.shield, "bouclier changé de main")


# --- Sac ---

func test_sac() -> void:
	var u: Unit = _man("epee")
	var stash: Array = [Loot.item("weapon", "lance"), Loot.item("head", "heaume"), Loot.item("shield")]
	t.check(Inventory.move(stash, Inventory.in_stash(0), Inventory.at(u, "bag0"))["ok"], "arme dans le sac")
	t.eq(u.bag[0]["key"], "lance", "lance dans le sac 1")
	var r: Dictionary = Inventory.move(stash, Inventory.in_stash(0), Inventory.at(u, "bag1"))
	t.check(not r["ok"], "un casque ne va pas dans un sac")
	t.check(Inventory.move(stash, Inventory.in_stash(1), Inventory.at(u, "bag1"))["ok"], "bouclier dans le sac 2")
	t.eq(stash.size(), 1, "réserve allégée")
	# échange sac <-> main
	t.check(Inventory.move(stash, Inventory.at(u, "bag0"), Inventory.at(u, "weapon"))["ok"], "lance en main")
	t.eq(u.weapon, "lance", "arme changée")
	t.eq(u.bag[0]["key"], "epee", "l'épée prend la place libérée dans le sac")
	# échange sac <-> sac
	t.check(Inventory.move(stash, Inventory.at(u, "bag0"), Inventory.at(u, "bag1"))["ok"], "échange entre sacs")
	t.eq(u.bag[0]["kind"], "shield", "bouclier en sac 1")
	t.eq(u.bag[1]["key"], "epee", "épée en sac 2")


func test_sac_serialisation() -> void:
	var u: Unit = _man("epee")
	u.bag[1] = {"kind": "weapon", "key": "hache", "dur": 20}
	var v: Unit = Unit.from_dict(u.to_dict())
	t.eq(v.bag.size(), 2, "deux emplacements")
	t.check((v.bag[0] as Dictionary).is_empty(), "sac 1 vide")
	t.eq(v.bag[1]["key"], "hache", "sac 2 relu")
	t.eq(int(v.bag[1]["dur"]), 20, "usure relue")
	var old: Dictionary = u.to_dict()
	old.erase("bag")
	t.eq(Unit.from_dict(old).bag, [{}, {}], "ancienne sauvegarde : sac vide")
	var bad: Dictionary = u.to_dict()
	bad["bag"] = [{"kind": "head", "key": "heaume"}, {"kind": "weapon", "key": "n'existe_pas"}, {}]
	t.eq(Unit.from_dict(bad).bag, [{}, {}], "objets invalides écartés du sac")
	t.eq(v.duplicate_unit().bag[1]["key"], "hache", "copie profonde")


# --- Dons ---

func test_don_entre_hommes() -> void:
	var a: Unit = _man("epee", false, "heaume")
	var b: Unit = _man("gourdin", false, "capuchon")
	var stash: Array = []
	t.check(Inventory.give(stash, a, "head", b)["ok"], "don du heaume")
	t.eq(b.head, "heaume", "B porte le heaume")
	t.eq(a.head, "capuchon", "A reçoit le capuchon en échange")
	t.check(not Inventory.give(stash, a, "shield", b)["ok"], "pas de bouclier à donner")
	var c: Unit = _man("arc")
	a.shield = true
	t.check(Inventory.give(stash, a, "shield", c)["ok"], "bouclier donné à un archer : va dans son sac")
	t.eq(c.bag[0]["kind"], "shield", "dans le sac")


# --- Capacité ---

func test_capacite() -> void:
	var u: Unit = _man("epee", false, "casque")
	var stash: Array = []
	for i in 3:
		stash.append(Loot.item("weapon", "gourdin"))
	var r: Dictionary = Inventory.unequip(stash, u, "head", 3)
	t.check(not r["ok"], "réserve pleine : refus")
	t.eq(r["msg"], "Réserve pleine.", "message")
	t.eq(u.head, "casque", "casque toujours porté")
	t.eq(u.arm_h, 90, "armure intacte")
	t.eq(stash.size(), 3, "réserve inchangée")
	t.check(Inventory.equip(stash, u, 0, 3)["ok"], "échange possible quand la réserve est pleine")
	t.eq(stash.size(), 3, "toujours 3")
	var over: Array = Inventory.add_items(stash, [Loot.item("shield"), Loot.item("shield")], 4)
	t.eq(over.size(), 1, "une pièce déborde")
	t.eq(stash.size(), 4, "réserve remplie")


func test_trop_plein_vendu() -> void:
	var g: Node = t.new_game(3)
	g.inventory.clear()
	for i in Data.STASH_SIZE - 1:
		g.inventory.append(Loot.item("weapon", "gourdin"))
	var gold: int = g.gold
	var sold: int = g.add_to_stash([Loot.item("weapon", "epee"), Loot.item("weapon", "epee"), Loot.item("shield")])
	t.eq(g.inventory.size(), Data.STASH_SIZE, "réserve au maximum")
	t.eq(sold, 2, "deux objets vendus d'office")
	t.eq(g.gold, gold + Loot.sell_base(Loot.item("weapon", "epee")) + Loot.sell_base(Loot.item("shield")), "au prix de revente de base")
	t.check(not g.buy_rare(0), "pas d'achat rare sans place")
	g.free()


# --- Tri / filtre / aperçu / texte ---

func test_tri_et_filtre() -> void:
	var stash: Array = [Loot.item("body", "gambison"), Loot.item("weapon", "gourdin"), Loot.item("shield"), Loot.item("weapon", "epee"), Loot.item("head", "capuchon")]
	stash[1]["dur"] = 5
	Inventory.sort_stash(stash, "type")
	t.eq(_kinds(stash), ["weapon:epee", "weapon:gourdin", "shield:", "head:capuchon", "body:gambison"], "tri par type")
	Inventory.sort_stash(stash, "value")
	t.eq(stash[0]["key"], "epee", "tri par valeur : l'épée d'abord")
	Inventory.sort_stash(stash, "wear")
	t.eq(stash[0]["key"], "gourdin", "tri par usure : le plus abîmé d'abord")
	t.eq(Inventory.filtered(stash, "weapon").size(), 2, "filtre armes")
	t.eq(Inventory.filtered(stash, "all").size(), 5, "filtre tout")
	t.eq(Inventory.filtered(stash, "shield").size(), 1, "filtre boucliers")


func test_apercu_poids() -> void:
	var u: Unit = _man("epee", false, "none", "tunique")
	var stash: Array = [Loot.item("body", "brigandine")]
	var before: Dictionary = Inventory.stats(u)
	var after: Dictionary = Inventory.preview(stash, u, Inventory.in_stash(0), Inventory.at(u, "body"))
	t.eq(int(after["weight"]), 22, "poids avec la brigandine")
	t.eq(int(after["fat"]), int(before["fat"]) - 22, "endurance réduite")
	t.eq(int(after["ini"]), int(before["ini"]) - 22, "initiative réduite")
	t.eq(u.body, "tunique", "l'aperçu ne modifie rien")
	t.eq(stash.size(), 1, "ni la réserve")
	t.check(Inventory.preview(stash, u, Inventory.in_stash(0), Inventory.at(u, "head")).is_empty(), "aperçu impossible = vide")


func test_infobulle() -> void:
	var tip: String = Inventory.tooltip(Loot.item("weapon", "hache"), 120)
	t.check(tip.contains("Hache") and tip.contains("30–45") and tip.contains("120 couronnes"), "infobulle d'arme")
	t.check(tip.contains("Durabilité 60/60"), "durabilité")
	var armor: String = Inventory.tooltip(Loot.with_armor(Loot.item("body", "mailles"), 50))
	t.check(armor.contains("50/130"), "armure actuelle")
	t.check(Inventory.tooltip(Uniques.item_of("u_epee_corbeau")).contains("unique"), "objet unique signalé")


# --- Bataille ---

func _battle_pair(a: Unit) -> BattleState:
	var d: Unit = t.mk("gourdin", "e", Hex.from_col_row(8, 4))
	a.hex = Hex.from_col_row(4, 4)
	a.reset_for_battle()
	d.reset_for_battle()
	var s := BattleState.new()
	s.rng = t.rng_seeded(5)
	for r in 9:
		for c in 12:
			s.cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": 0}
	s.units.append(a)
	s.units.append(d)
	return s


func test_changer_arme_en_bataille() -> void:
	var u: Unit = _man("epee", true)
	u.bag[0] = {"kind": "weapon", "key": "arc"}
	u.bag[1] = {"kind": "weapon", "key": "lance", "dur": 33}
	var s: BattleState = _battle_pair(u)
	t.check(s.can_swap_weapon(u, 1), "échange avec la lance possible")
	t.check(s.swap_weapon(u, 1), "échange fait")
	t.eq(u.weapon, "lance", "lance en main")
	t.eq(u.weapon_dur_now(), 33, "usure de la lance")
	t.eq(u.bag[1]["key"], "epee", "épée rangée dans le sac")
	t.eq(u.ap, Data.AP_PER_TURN - Data.SWAP_AP, "4 PA dépensés")
	t.eq(u.fat, Data.SWAP_FAT, "fatigue légère")
	t.check(u.shield, "bouclier toujours là (lance à une main)")
	# arc : deux mains, le bouclier doit être rangé dans le sac (on libère l'autre emplacement)
	u.bag[1] = {}
	u.ap = Data.AP_PER_TURN
	t.check(s.swap_weapon(u, 0), "échange avec l'arc")
	t.eq(u.weapon, "arc", "arc en main")
	t.check(not u.shield, "bouclier rangé")
	t.eq(u.bag[0]["key"], "lance", "la lance prend la place de l'arc")
	t.eq(u.bag[1]["kind"], "shield", "le bouclier est dans l'autre emplacement")
	# plus de PA : refus
	u.ap = 3
	t.check(not s.swap_weapon(u, 0), "pas assez de PA")


func test_changer_arme_bloque() -> void:
	var u: Unit = _man("epee", true)
	u.bag[0] = {"kind": "weapon", "key": "arc"}
	u.bag[1] = {"kind": "weapon", "key": "lance"}
	var s: BattleState = _battle_pair(u)
	# sac plein, arc exige de ranger le bouclier -> aucune place : refus et rien ne change
	t.check(not s.swap_weapon(u, 0), "pas de place pour le bouclier")
	t.eq(u.weapon, "epee", "arme inchangée")
	t.check(u.shield, "bouclier inchangé")
	t.eq(u.ap, Data.AP_PER_TURN, "PA inchangés")
	t.check(not s.can_swap_weapon(u, 2), "emplacement inexistant")
	var empty: Unit = _man("epee")
	var s2: BattleState = _battle_pair(empty)
	t.check(not s2.can_swap_weapon(empty, 0), "sac vide")


func test_bataille_reporte_equipement() -> void:
	var g: Node = t.new_game(9)
	var m: Unit = g.roster[0]
	m.weapon = "epee"
	m.bag[0] = {"kind": "weapon", "key": "hache"}
	var b: BattleState = BattleState.create({"type": "b", "d": 1, "foes": ["brigand"], "title": "T", "desc": "", "days": 1, "employer": "x", "pay": 1, "biome": "plain"}, g.roster, t.rng_seeded(2))
	var bu: Unit = null
	for u in b.units:
		if u.id == m.id:
			bu = u
	t.eq(bu.bag[0]["key"], "hache", "le sac part au combat")
	bu.ap = 9
	t.check(b.swap_weapon(bu, 0), "échange en bataille")
	t.eq(m.weapon, "epee", "le camp n'est pas touché pendant la bataille")
	g.battle = b
	b.over = "win"
	for u in b.units:
		if u.side == "e":
			u.dead = true
	t.check(not g.can_edit_inventory(), "inventaire verrouillé en bataille")
	t.check(not g.inv_equip(m, 0)["ok"], "équiper refusé en bataille")
	g.finish_battle()
	t.eq(m.weapon, "hache", "arme de la bataille reportée")
	t.eq(m.bag[0]["key"], "epee", "épée dans le sac au retour")
	g.free()


# --- Game ---

func test_game_sauvegarde_et_migration() -> void:
	var g: Node = t.new_game(4)
	g.inventory = [Loot.item("weapon", "hache"), Loot.with_armor(Loot.item("body", "mailles"), 70)]
	g.roster[0].bag[0] = {"kind": "shield", "key": "", "dur": 9}
	var g2: Node = t.new_game(5)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	t.eq(g2.inventory[1]["arm"], 70, "armure abîmée de la réserve conservée")
	t.eq(int(g2.roster[0].bag[0]["dur"]), 9, "sac conservé")
	var old: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	for r in old["roster"]:
		r.erase("bag")
	old["inventory"] = [{"kind": "weapon", "key": "epee"}, {"kind": "head", "key": "casque", "arm": 12}]
	var g3: Node = t.new_game(6)
	g3.from_dict(old)
	t.eq(g3.roster[0].bag, [{}, {}], "ancienne sauvegarde : sacs vides")
	t.eq(g3.inventory.size(), 2, "ancien inventaire repris")
	t.eq(Loot.armor_of(g3.inventory[1]), 12, "armure abîmée relue")
	g.free()
	g2.free()
	g3.free()


func test_game_inventaire_actions() -> void:
	var g: Node = t.new_game(7)
	var m: Unit = g.roster[0]
	g.inventory = [Loot.item("weapon", "epee"), Loot.item("weapon", "lance")]
	var old_weapon: String = m.weapon
	t.check(g.inv_equip(m, 0)["ok"], "équiper via Game")
	t.check(g.inventory.any(func(it: Dictionary) -> bool: return it["key"] == old_weapon), "ancienne arme rendue")
	t.check(g.inv_move(Inventory.in_stash(0), Inventory.at(m, "bag1"))["ok"], "vers le sac via Game")
	t.check(g.inv_unequip(m, "bag1")["ok"], "retour du sac")
	t.check(g.discard(0), "jeter")
	g.location = ""
	g.world.parties.clear()
	t.check(not g.sell(0), "pas de vente hors d'un lieu")
	t.check(not g.can_equip_from_inventory(m, 99), "indice invalide")
	# renvoi d'un homme : sac et armure abîmée reviennent à la réserve
	var leaver: Unit = g.roster[1]
	leaver.bag[0] = {"kind": "weapon", "key": "hache"}
	leaver.body = "mailles"
	leaver.arm_b = 40
	g.inventory.clear()
	g.dismiss(leaver.id)
	t.check(g.inventory.any(func(it: Dictionary) -> bool: return it["key"] == "hache"), "le sac revient à la réserve")
	var mail: Array = g.inventory.filter(func(it: Dictionary) -> bool: return it["key"] == "mailles")
	t.eq(Loot.armor_of(mail[0]), 40, "armure abîmée suit")
	g.free()
