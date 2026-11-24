extends RefCounted
## Graphismes : variété d'ennemis stable, calques existants, équipement visible, ambiances de région, animations d'experts, portraits uniques.
var t

const NEW_LAYERS: Array[String] = [
	"helm_pot", "bandana_face", "hat_felt", "torso_studded", "fur_collar", "orc_spikes", "orc_hide", "paint_orc_1", "paint_orc_2", "paint_orc_3",
	"skel_plate", "skel_shroud", "skel_crown", "skel_chain", "back_sword", "back_axe", "back_club", "back_spear", "back_bow", "back_xbow",
	"back_shield", "quiver_bolts", "banner_pole", "banner_flag", "banner_flag_trim", "armor_gorget", "armor_pauldron_off", "armor_aventail", "armor_knees",
]


func _foe(key: String, id: int) -> Unit:
	var u: Unit = Contracts.make_foe(key, t.rng_seeded(id))
	u.id = id
	return u


func test_layers_exist() -> void:
	for n in NEW_LAYERS:
		t.check(Figure.texture(n) != null, "calque %s" % n)
	for l in Figure.BACK_LAYER.values():
		t.check(Figure.texture(str(l)) != null, "dos %s" % l)


func test_looks_stable() -> void:
	for key in ["brigand", "orc_guerrier", "squelette"]:
		var a: Unit = _foe(key, 4242)
		var b: Unit = _foe(key, 4242)
		t.eq(Figure.look(a), Figure.look(b), "look stable %s" % key)
		t.eq(Figure.brigand_style(a), Figure.brigand_style(b), "style stable %s" % key)
		t.eq(Figure.orc_clan(a), Figure.orc_clan(b), "clan stable %s" % key)


func test_variety_covers_all_styles() -> void:
	var b_seen: Dictionary = {}
	var c_seen: Dictionary = {}
	var u_seen: Dictionary = {}
	for id in range(1, 300):
		var bu: Unit = _foe("brigand", id)
		bu.head = "none"
		b_seen[Figure.brigand_style(bu)] = true
		var ou: Unit = _foe("orc_guerrier", id)
		c_seen[Figure.orc_clan(ou)] = true
		var su: Unit = _foe("squelette", id)
		su.head = "none"
		u_seen[Figure.undead_style(su)] = true
	t.check(b_seen.size() >= 4, "au moins 4 allures de brigands (%d)" % b_seen.size())
	t.eq(c_seen.size(), Figure.ORC_CLAN_SKIN.size(), "tous les clans d'orcs apparaissent")
	t.eq(u_seen.size(), Figure.UNDEAD_STYLES.size(), "tous les styles de squelettes apparaissent")
	t.eq(Figure.brigand_style(_foe("goule", 3)), "", "pas d'allure de brigand pour une goule")


func test_every_variant_builds() -> void:
	for key in ["brigand", "archer", "balafre", "chef", "orc_jeune", "orc_guerrier", "berserker", "orc_chef", "chaman_orc", "squelette", "squelette_archer", "zombie", "necro", "goule", "loup", "ogre"]:
		for id in range(1, 40, 3):
			var u: Unit = _foe(key, id)
			var f: Figure = Figure.new().setup(u)
			t.check(f.get_child_count() >= 1, "%s #%d se construit" % [key, id])
			f.free()


func test_back_gear_and_bearer() -> void:
	var u: Unit = t.mk("hache", "p")
	u.bag = [{"kind": "weapon", "key": "epee"}, {"kind": "shield", "key": ""}]
	var bl: Array = Figure.back_layers(u)
	t.check(bl.has("back_sword") and bl.has("back_shield"), "épée et bouclier dans le dos")
	u.shield = true
	t.check(not Figure.back_layers(u).has("back_shield"), "pas de bouclier au dos s'il est tenu")
	u.bag = [{}, {}]
	t.eq(Figure.back_layers(u).size(), 0, "sac vide : rien dans le dos")
	var g: Node = t.new_game(7)
	# Figure lit la compagnie de l'autoload Game s'il existe (pas encore créé quand les suites tournent depuis _init) ; sinon `Unit.leader`.
	var ag: Node = t.root.get_node_or_null("Game")
	var saved: Array[Unit] = []
	if ag != null:
		saved = ag.roster
		ag.roster = g.roster
	var first: Unit = g.roster[0]
	for m in g.roster:
		m.leader = (m == first)
	t.check(Figure.is_standard_bearer(first), "le premier homme porte l'étendard")
	t.check(not Figure.is_standard_bearer(g.roster[1]), "les autres non")
	var f: Figure = Figure.new().setup(first)
	var with_gear: int = f.get_child_count()
	var f2: Figure = Figure.new().setup(first, false)
	t.check(with_gear > f2.get_child_count() or not Figure.gear_enabled(), "l'étendard ajoute des calques")
	f.free()
	f2.free()
	if ag != null:
		ag.roster = saved


func test_region_look() -> void:
	var kinds: Dictionary = {}
	for biome in Data.BIOMES:
		for owner in [""] + Data.FACTIONS.keys():
			for ft in ["b", "u", "o"]:
				var a: Dictionary = RegionLook.derive(biome, str(owner), ft, 5)
				var b: Dictionary = RegionLook.derive(biome, str(owner), ft, 5)
				t.eq(a, b, "ambiance déterministe %s/%s" % [biome, owner])
				t.check(RegionLook.KINDS.has(a["kind"]), "ambiance valide")
				kinds[a["kind"]] = true
		t.check(not RegionLook.derive(biome, "", "b")["features"].is_empty(), "décor pour %s" % biome)
	for k in RegionLook.KINDS:
		t.check(kinds.has(k), "ambiance %s atteignable" % k)
		t.check(RegionLook.SPECS.has(k), "spec %s" % k)
	t.eq(RegionLook.derive("plain", "givre")["kind"], "snow", "givre : neige")
	t.eq(RegionLook.derive("water", "lys")["kind"], "bridge", "lys + eau : pont")


func test_region_decor_paints_without_changing_cells() -> void:
	var rng: RandomNumberGenerator = t.rng_seeded(3)
	var c: Dictionary = {"kind": "contract", "type": "b", "type_contract": "kill", "d": 1, "foes": ["brigand"], "title": "T", "desc": "", "days": 1,
		"employer": "x", "pay": 100, "biome": "water", "battle_type": "pitched"}
	var party: Array = [Contracts.make_merc(Data.BG.keys()[0], rng, [])]
	var st: BattleState = BattleState.create(c, party, rng)
	var before: Dictionary = st.cells.duplicate(true)
	var board := BoardView.new()
	board.setup(st)
	var lk: Dictionary = RegionDecor.look_for(board)  # le dessin lui-même exige un _draw() : couvert par tools/shots_graphismes.gd
	t.check(RegionLook.KINDS.has(lk["kind"]), "ambiance de la bataille")
	t.check(board.has_meta("rl_look"), "ambiance mise en cache")
	t.eq(st.cells, before, "le décor ne modifie aucune case")
	board.free()


func test_expert_animation() -> void:
	var u: Unit = t.mk("hache", "p")
	t.check(not AttackAnims.is_expert(u), "sans talent : pas de variante")
	u.perks.append("ex_hache")
	t.check(AttackAnims.is_expert(u), "talent expert + arme de la famille")
	u.weapon = "epee"
	t.check(not AttackAnims.is_expert(u), "talent d'une autre famille : pas de variante")
	t.check(AttackAnims.expert_color("smash") != AttackAnims.expert_color("slash"), "couleurs distinctes")
	# vitesse 0 : aucune attente, aucun nœud créé
	u.weapon = "hache"
	AttackAnims.play(null, u, t.mk("hache", "e"), true)
	var uv := UnitView.new().setup(u)
	uv.squash()
	uv.free()


func test_unique_portraits() -> void:
	for fac in Data.FACTION_LEADER:
		var key: String = str(Data.FACTION_LEADER[fac])
		var u: Unit = _foe(key, 900)
		t.eq(PortraitView.unique_tag(u), "leader", "chef %s reconnu" % key)
		var p := PortraitView.new(u, 54)
		t.check(p != null, "portrait du chef %s" % key)
		p.free()
	t.eq(PortraitView.unique_tag(_foe("brigand", 901)), "", "brigand ordinaire : pas de portrait unique")
	var r: Unit = t.mk("hache", "p")
	r.weapon = "u_epee_corbeau"
	t.eq(PortraitView.unique_tag(r), "rare", "objet unique : portrait rare")
	var pr := PortraitView.new(r, 54)
	pr.free()
