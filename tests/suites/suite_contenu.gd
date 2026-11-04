extends RefCounted
## Contenu et rejouabilité : événements, textes de contrats, noms, traits de caractère, tenues d'élite, bannière, succès, statistiques.
var t

const EFFECT_KEYS: Array = ["w", "text", "gold", "hp_all", "hp_one", "renown", "days", "recruit", "battle", "repair", "xp_all", "food", "morale", "standing", "bond", "flag", "schedule", "recruit_story", "contract", "unique", "threat"]


func _kill_all_foes(b: BattleState) -> void:
	for u in b.units:
		if u.side == "e":
			u.dead = true
	b.check_end()


# --- A) Variété ---

func test_events_content() -> void:
	t.check(Events.DEFS.size() >= 25, "au moins 25 événements de route (%d)" % Events.DEFS.size())
	var ids: Dictionary = {}
	for e in Events.DEFS:
		t.check(not ids.has(e["id"]), "id d'événement unique : %s" % e["id"])
		ids[e["id"]] = true
		t.check(str(e["title"]) != "" and str(e["text"]) != "", "titre et texte : %s" % e["id"])
		t.check((e["choices"] as Array).size() >= 2, "au moins deux choix : %s" % e["id"])
		for c in e["choices"]:
			t.check(not (c["outcomes"] as Array).is_empty(), "issues : %s/%s" % [e["id"], c["id"]])
			for o in c["outcomes"]:
				for k in o:
					t.check(EFFECT_KEYS.has(k), "effet connu %s dans %s/%s" % [k, e["id"], c["id"]])
				if o.has("recruit") and o["recruit"] != "random":
					t.check(Data.BG.has(o["recruit"]), "recrue valide : %s" % e["id"])
				if o.has("battle"):
					t.check(Data.FACTION_NAMES.has(o["battle"]["type"]), "faction du combat : %s" % e["id"])


func test_all_events_resolve() -> void:
	# chaque choix de chaque événement se résout sans erreur dans une vraie partie
	for e in Events.DEFS:
		for c in e["choices"]:
			var g: Node = t.new_game(5)
			g.gold = 1000
			g.leave_settlement()
			g.pending_event = {"id": e["id"]}
			var res: Dictionary = g.resolve_event(str(c["id"]))
			t.check(bool(res["ok"]), "résolution %s/%s" % [e["id"], c["id"]])
			g.free()


func test_contract_texts() -> void:
	for f in ["b", "g", "o", "u"]:
		t.check((ContractTexts.FLAVOR[f] as Array).size() >= 13, "au moins 13 modèles de contrats pour %s" % f)
		var titles: Dictionary = {}
		for fl in ContractTexts.FLAVOR[f]:
			titles[str(fl[0]) + str(fl[1])] = true
			t.check(str(fl[1]).length() > 20, "description non vide (%s)" % f)
		t.eq(titles.size(), (ContractTexts.FLAVOR[f] as Array).size(), "modèles distincts (%s)" % f)
	t.check(ContractTexts.ESCORT.size() >= 10 and ContractTexts.DELIVERY.size() >= 10 and ContractTexts.HUNT.size() >= 10, "10 textes de plus par type de transport et de chasse")
	for h in ContractTexts.HUNT:
		t.check(str(h).contains("%s"), "texte de chasse avec le nom du chef")
	var g: Node = t.new_game(21)
	var seen: Dictionary = {}
	for i in 40:
		var cs: Array = Contracts.gen_contracts(900, t.rng_seeded(i), "Bourg", g.world.settlement_pos(g.world.settlements[0]), g.world, 4, 0, str(g.world.settlements[0]["id"]))
		for c in cs:
			t.check(str(c["desc"]) != "" and not str(c["desc"]).contains("{"), "description sans balise : %s" % c["desc"])
			t.check(not str(c["title"]).contains("{"), "titre sans balise")
			seen[c["desc"]] = true
	t.check(seen.size() >= 25, "assez de descriptions différentes générées (%d)" % seen.size())
	g.free()


func test_towns_and_names() -> void:
	t.check(Data.TOWNS.size() >= 24, "au moins 24 noms de lieux (%d)" % Data.TOWNS.size())
	var uniq: Dictionary = {}
	for n in Data.TOWNS:
		uniq[n] = true
	t.eq(uniq.size(), Data.TOWNS.size(), "noms de lieux tous différents")
	for s in [1, 2, 3, 4, 5, 6, 7, 8]:
		var w: World = World.generate(t.rng_seeded(s), 0)
		var seen: Dictionary = {}
		for st in w.settlements:
			t.check(not seen.has(st["name"]), "pas de nom répété sur la carte (graine %d)" % s)
			seen[st["name"]] = true
	t.check(Data.FIRST_NAMES.size() >= 50 and Data.NICKNAMES.size() >= 30, "plus de prénoms et de surnoms")
	var names: Dictionary = {}
	var r: RandomNumberGenerator = t.rng_seeded(3)
	for i in 120:
		names[Contracts.random_name([], r)] = true
	t.check(names.size() >= 90, "variété des noms de recrues (%d)" % names.size())


# --- B) Traits ---

func test_traits_table() -> void:
	t.check(Data.TRAITS.size() >= 14, "au moins 14 traits (%d)" % Data.TRAITS.size())
	for k in Data.TRAITS:
		var d: Dictionary = Data.TRAITS[k]
		t.check(str(d["n"]) != "" and str(d["d"]) != "", "trait décrit : %s" % k)
		t.check(["good", "bad", "mixed"].has(str(d["tone"])), "ton valide : %s" % k)
		for sk in d.get("stat", {}):
			t.check(Data.STAT_NAMES.has(sk), "attribut valide dans %s" % k)


func test_traits_roll() -> void:
	var r: RandomNumberGenerator = t.rng_seeded(77)
	var counts: Dictionary = {1: 0, 2: 0}
	for i in 200:
		var u: Unit = Contracts.make_merc("fermier", r, [])
		t.check(u.traits.size() >= 1 and u.traits.size() <= 2, "1 ou 2 traits")
		counts[mini(2, u.traits.size())] += 1
		if u.traits.size() == 2:
			t.check(Data.TRAITS[u.traits[0]]["ex"] != Data.TRAITS[u.traits[1]]["ex"], "pas de traits contradictoires %s" % str(u.traits))
		t.check(Traits.roll_for(u) == u.traits, "tirage stable pour un même id")
		t.check(u.wage >= 1 and u.hp_max >= 20 and u.hp == u.hp_max, "solde et PV valides")
	t.check(counts[1] > 40 and counts[2] > 20, "les deux cas existent (%s)" % str(counts))
	var g: Node = t.new_game(9)
	for m in g.roster:
		t.check(not m.traits.is_empty(), "la compagnie de départ a des traits")
	g.free()


func test_traits_effects() -> void:
	var u: Unit = t.mk("arc")
	u.traits.assign(["myope"])
	t.eq(u.eff("ranged_skill"), 60 - 8, "Myope : −8 à distance")
	u.traits.assign(["costaud", "vif"])
	t.eq(u.eff("fat_max"), 110, "Costaud : +10 d'endurance")
	t.eq(u.eff("initiative"), 106, "Vif : +6 d'initiative")
	u.traits.assign(["brave"])
	t.eq(u.eff("resolve"), 50, "Brave : rien avant le premier coup")
	u.hit_taken = true
	t.eq(u.eff("resolve"), 60, "Brave : +10 après le premier coup")
	u.reset_for_battle()
	t.eq(u.eff("resolve"), 50, "nouvelle bataille : le bonus retombe")
	u.traits.assign(["rancunier"])
	u.hit_taken = true
	t.eq(u.eff("melee_skill"), 61, "Rancunier : +6 en mêlée une fois blessé")
	var rob: Unit = t.mk()
	rob.traits.assign(["robuste"])
	rob.wage = 10
	Traits._apply_gen_effects(rob)
	t.eq(rob.hp_max, 68, "Robuste : +8 PV")
	var avare: Unit = t.mk()
	avare.traits.assign(["avare"])
	avare.wage = 12
	Traits._apply_gen_effects(avare)
	t.eq(avare.wage, 15, "Avare : solde +25 %")
	var gour: Unit = t.mk()
	gour.traits.assign(["gourmand"])
	t.eq(Traits.rest_bonus(gour), 5, "Gourmand : +5 PV de repos")
	t.eq(Traits.ally_fall_mod(gour), 0, "pas de malus sans le trait")
	gour.traits.assign(["peureux"])
	t.eq(Traits.ally_fall_mod(gour), -10, "Peureux : −10")


func test_trait_sociable_aura() -> void:
	var a: Unit = t.mk("hache", "p", Vector2i(2, 2))
	var s: Unit = t.mk("hache", "p", Vector2i(3, 2))
	s.traits.assign(["sociable"])
	var far: Unit = t.mk("hache", "p", Vector2i(9, 2))
	t.eq(Traits.aura(a, [a, s, far]), 5, "allié adjacent sociable : +5")
	t.eq(Traits.aura(far, [a, s, far]), 0, "trop loin : rien")
	t.eq(Traits.aura(s, [a, s, far]), 0, "ne s'applique pas à soi-même")


func test_trait_lucky_survival() -> void:
	var b: BattleState = BattleState.create({"d": 1, "foes": ["brigand"], "type": "b", "title": "t", "kind": "contract", "pay": 0, "days": 1, "biome": "plain"}, [t.mk()], t.rng_seeded(3))
	var d: Unit = null
	var a: Unit = null
	for u in b.units:
		if u.side == "p":
			d = u
		else:
			a = u
	d.traits.assign(["chanceux"])
	t.check(Traits.lucky_save(d, t.rng_seeded(1)) or d.lucky_used, "le trait joue une fois")
	t.check(not Traits.lucky_save(d, t.rng_seeded(1)), "pas deux fois dans la même bataille")
	d.reset_for_battle()
	var saved: int = 0
	for i in 60:
		d.lucky_used = false
		if Traits.lucky_save(d, t.rng_seeded(i)):
			saved += 1
	t.check(saved > 8 and saved < 40, "environ 35 %% de chances (%d/60)" % saved)
	var plain: Unit = t.mk()
	t.check(not Traits.lucky_save(plain, t.rng_seeded(2)) and not plain.lucky_used, "sans le trait, rien ne se passe")
	# bataille : un coup mortel contre un Chanceux laisse 1 PV (s'il a de la chance)
	var survived: int = 0
	for i in 40:
		d.reset_for_battle()
		d.hp = 1
		d.arm_b = 0
		d.arm_h = 0
		b.rng.seed = i
		a.weapon = "hache"
		a.hex = d.hex + Vector2i(1, 0)
		b.attack(a, d)
		if not d.dead:
			survived += 1
	t.check(survived > 0, "au moins un coup mortel évité ou raté (%d/40)" % survived)


func test_traits_save_and_migration() -> void:
	var u: Unit = Contracts.make_merc("bucheron", t.rng_seeded(4), [])
	var back: Unit = Unit.from_dict(u.to_dict())
	t.eq(back.traits, u.traits, "traits sauvegardés")
	t.eq(back.hp_max, u.hp_max, "PV inchangés au rechargement")
	t.eq(back.wage, u.wage, "solde inchangée au rechargement")
	var old: Dictionary = u.to_dict()
	old.erase("traits")
	old["hp_max"] = 60
	old["hp"] = 60
	old["wage"] = 10
	var mig: Unit = Unit.from_dict(old)
	t.check(not mig.traits.is_empty(), "ancienne sauvegarde : l'homme reçoit des traits")
	t.check(mig.hp_max >= 20, "PV valides après migration")
	t.eq(Unit.from_dict(mig.to_dict()).traits, mig.traits, "migration puis rechargement : stable")
	var foe: Dictionary = Contracts.make_foe("brigand", t.rng_seeded(1)).to_dict()
	foe.erase("traits")
	t.check(Unit.from_dict(foe).traits.is_empty(), "les ennemis n'ont pas de traits")
	var c: Dictionary = u.combat_dict()
	t.eq(Unit.from_combat_dict(c).traits, u.traits, "traits conservés dans une bataille sauvegardée")


func test_traits_not_gained() -> void:
	var g: Node = t.new_game(12)
	var before: Dictionary = {}
	for m in g.roster:
		before[m.id] = m.traits.duplicate()
	g.battle = null
	g.accept_contract(0)
	g.engage_target()
	if g.battle != null:
		_kill_all_foes(g.battle)
		g.finish_battle()
	for m in g.roster:
		t.eq(m.traits, before[m.id], "les traits ne changent pas en combat")
	g.free()


# --- C) Tenues d'élite et bannière ---

func test_elite_layers() -> void:
	for l in ["crest_plume", "circlet", "pauldron_elite", "cape_trim", "war_paint", "bone_necklace", "shield_field", "shield_chev", "shield_boss", "shield_field_up", "shield_chev_up", "shield_boss_up"]:
		t.check(Figure.texture(l) != null, "calque présent : %s" % l)


func test_elite_tags() -> void:
	var u: Unit = t.mk()
	u.level = 5
	t.check(Figure.elite_tags(u).is_empty(), "niveau 5 : tenue ordinaire")
	u.level = Data.ELITE_LEVEL
	t.check(Figure.elite_tags(u).has("vet") and Figure.elite_tags(u).has("cape"), "niveau 6 : tenue de vétéran")
	for k in ["chef", "balafre", "berserker", "orc_chef"]:
		var f: Unit = Contracts.make_foe(k, t.rng_seeded(1))
		t.check(not Figure.elite_tags(f).is_empty(), "ennemi d'élite : %s" % k)
	t.check(Figure.elite_tags(Contracts.make_foe("brigand", t.rng_seeded(1))).is_empty(), "un détrousseur n'a pas d'ornements")


func test_elite_figures_build() -> void:
	for k in ["chef", "balafre", "berserker", "orc_chef", "brigand", "goule", "necro"]:
		var f := Figure.new().setup(Contracts.make_foe(k, t.rng_seeded(2)))
		t.check(f.get_child_count() > 0, "figurine construite : %s" % k)
		f.free()
	for head in ["none", "capuchon", "casque", "heaume"]:
		var u: Unit = t.mk()
		u.level = 7
		u.head = head
		u.shield = true
		var plain: Unit = t.mk()
		plain.id = u.id
		plain.head = head
		plain.shield = true
		var fv := Figure.new().setup(u)
		var fp := Figure.new().setup(plain)
		t.check(fv.get_child_count() > fp.get_child_count(), "le vétéran porte plus de calques (%s)" % head)
		fv.free()
		fp.free()


func test_banner_logic() -> void:
	var d: Dictionary = Banner.clean({})
	t.eq(d["primary"], "", "bannière par défaut : écus ocre")
	t.check(not Banner.is_custom(d), "pas personnalisée")
	var c: Dictionary = Banner.clean({"primary": "B03A2E", "secondary": "zzz", "emblem": 99})
	t.eq(c["primary"], "b03a2e", "couleur normalisée")
	t.eq(c["secondary"], Data.BANNER_DEFAULT["secondary"], "couleur invalide ignorée")
	t.eq(c["emblem"], Data.BANNER_EMBLEMS.size() - 1, "emblème borné")
	t.check(Banner.is_custom(c) and Banner.primary(c) == Color("b03a2e"), "couleur principale")
	t.eq(Banner.clean_name("   "), Data.COMPANY_NAME_DEFAULT, "nom vide -> nom d'origine")
	t.eq(Banner.clean_name("  Les Loups  "), "Les Loups", "espaces rognés")
	t.eq(Banner.clean_name("x".repeat(80)).length(), Data.COMPANY_NAME_MAX, "nom borné")
	t.eq(Data.BANNER_COLORS.size(), Data.BANNER_COLOR_NAMES.size(), "un nom par couleur")
	t.check(Data.BANNER_EMBLEMS.size() >= 8, "8 emblèmes")


func test_banner_save_and_game() -> void:
	var g: Node = t.new_game(31)
	t.eq(g.company_name, Data.COMPANY_NAME_DEFAULT, "nom d'origine")
	g.set_banner("3e526a", "d8cfb8", 3)
	g.set_company_name("  Les Loups du Nord ")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = t.new_game(32)
	g2.from_dict(d)
	t.eq(g2.company_name, "Les Loups du Nord", "nom sauvegardé")
	t.eq(g2.banner["primary"], "3e526a", "couleur principale sauvegardée")
	t.eq(g2.banner["emblem"], 3, "emblème sauvegardé")
	var old: Dictionary = d.duplicate(true)
	old.erase("banner")
	old.erase("company_name")
	old.erase("stats")
	g2.from_dict(old)
	t.eq(g2.company_name, Data.COMPANY_NAME_DEFAULT, "ancienne sauvegarde : nom d'origine")
	t.check(not Banner.is_custom(g2.banner), "ancienne sauvegarde : bannière d'origine")
	t.eq(g2.stats, Achievements.default_stats(), "ancienne sauvegarde : statistiques à zéro")
	g2.free()
	g.free()


func test_banner_view_and_screen() -> void:
	var v := BannerView.new({"primary": "b03a2e", "secondary": "d8cfb8", "emblem": 4}, Vector2(60, 80))
	t.eq(v.banner["emblem"], 4, "vue de la bannière")
	v.free()
	t.eq(Data.BANNER_EMBLEMS.size(), 13, "treize emblèmes dessinés")


# --- D) Succès et statistiques ---

func test_achievement_defs() -> void:
	t.check(Achievements.DEFS.size() >= 20, "au moins 20 succès (%d)" % Achievements.DEFS.size())
	var ids: Dictionary = {}
	for d in Achievements.DEFS:
		t.check(not ids.has(d["id"]), "id unique : %s" % d["id"])
		ids[d["id"]] = true
		t.check(["stats", "ctx"].has(d["src"]), "source valide : %s" % d["id"])
		if d["src"] == "stats":
			t.check(Achievements.STAT_LABELS.has(d["key"]), "compteur connu : %s" % d["key"])
	t.check(Achievements.default_stats().size() >= 12, "au moins 12 statistiques")


func test_achievement_logic() -> void:
	var s: Dictionary = Achievements.default_stats()
	var ctx: Dictionary = {"renown": 0, "gold": 0, "days": 0, "max_level": 1, "roster": 5, "sites": 0, "arcs": 0, "uniques": 0, "ending": 0}
	t.eq(Achievements.newly_met(s, ctx, {}).size(), 0, "rien au départ")
	s["kills"] = 1
	t.eq(Achievements.newly_met(s, ctx, {}), ["first_blood"] as Array[String], "Premier sang")
	t.eq(Achievements.newly_met(s, ctx, {"first_blood": 3}).size(), 0, "déjà débloqué : pas de doublon")
	s["kills"] = 100
	ctx["renown"] = 500
	var got: Array[String] = Achievements.newly_met(s, ctx, {})
	t.check(got.has("kills_100") and got.has("renown_500") and got.has("first_blood"), "100 victimes et renom 500")
	t.eq(Achievements.normalize_stats({"kills": 7.0, "travel_days": 2.5}).kills, 7, "statistiques lues du JSON")
	t.eq(Achievements.normalize_stats(null), Achievements.default_stats(), "statistiques absentes")


func test_achievement_file() -> void:
	var path: String = "user://test_achievements.json"
	t.check(Achievements.save_unlocked({"first_blood": 4, "inconnu": 2}, path), "écriture")
	var back: Dictionary = Achievements.load_unlocked(path)
	t.eq(back, {"first_blood": 4}, "relecture (succès inconnus ignorés)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	t.eq(Achievements.load_unlocked(path), {}, "fichier absent")


func test_game_stats_flow() -> void:
	var g: Node = t.new_game(40)
	g.achievements_path = "user://test_achievements_unused.json"
	t.eq(g.stats["battles_won"], 0, "départ à zéro")
	var fired: Array = []
	g.achievement_unlocked.connect(func(id: String) -> void: fired.append(id))
	g.stat_add("kills", 3)
	t.eq(g.stats["kills"], 3, "stat_add")
	var fresh: Array[String] = g.check_achievements()
	t.check(fresh.has("first_blood"), "Premier sang débloqué")
	t.check(fired.has("first_blood") and g.unlocked.has("first_blood"), "signal et état")
	t.eq(g.check_achievements().size(), 0, "pas de second déblocage")
	t.check(not FileAccess.file_exists(g.achievements_path), "autosave faux : rien d'écrit sur le disque")
	# or gagné / dépensé
	var gold0: int = g.gold
	g._earn(100)
	g._spend(40)
	t.eq(g.stats["gold_earned"], 100, "or gagné")
	t.eq(g.stats["gold_spent"], 40, "or dépensé")
	t.eq(g.gold, gold0 + 60, "l'or suit")
	# contrat + bataille gagnée
	g.accept_contract(0)
	g.engage_target()
	t.check(g.battle != null, "bataille lancée")
	var victims: int = 0
	for u in g.battle.units:
		if u.side == "p":
			u.kills = 2
		else:
			victims += 1
	_kill_all_foes(g.battle)
	g.finish_battle()
	t.eq(g.stats["battles_won"], 1, "victoire comptée")
	t.eq(g.stats["contracts_done"], 1, "contrat compté")
	t.check(g.stats["kills"] >= 3 + 2 * 5, "victimes comptées (%d)" % g.stats["kills"])
	t.eq(g.stats["perfect_wins"], 1, "victoire sans perte")
	t.check(g.unlocked.has("won_1") and g.unlocked.has("contract_1") and g.unlocked.has("flawless"), "succès de la bataille")
	# voyage
	g.leave_settlement()
	g.world.parties.clear()
	var far: Dictionary = g.world.settlements[1]
	g.world.set_destination(g.world.settlement_pos(far), {"kind": "settlement", "id": far["id"]})
	var before: float = g.stats["travel_days"]
	for i in 6:
		g.map_step(0.25)
	t.check(g.stats["travel_days"] > before, "journées de marche comptées")
	# sauvegarde
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2: Node = t.new_game(41)
	g2.from_dict(d)
	t.eq(g2.stats["battles_won"], 1, "statistiques rechargées")
	t.check(g2.stats["travel_days"] > 0.0, "journées de marche rechargées")
	g2.free()
	g.free()


func test_achievement_context() -> void:
	var g: Node = t.new_game(50)
	var c: Dictionary = g.achievement_context()
	t.eq(c["roster"], 5, "effectif")
	t.eq(c["max_level"], 1, "niveau maximal")
	t.eq(c["sites"], 0, "lieux pris")
	g.roster[0].level = 6
	g.renown = 600
	g.gold = 4000
	var fresh: Array[String] = g.check_achievements()
	t.check(fresh.has("level_6") and fresh.has("renown_500") and fresh.has("gold_3000"), "succès d'état déclenchés (%s)" % str(fresh))
	g.free()


func test_achievements_screens_build() -> void:
	var g: Node = t.new_game(60)
	t.check(g != null, "partie")
	t.check(Achievements.def_of("first_blood").size() > 0 and Achievements.def_of("nope").is_empty(), "def_of")
	g.free()
	# les écrans (BannerScreen, AchievementsScreen) lisent l'autoload Game : voir tools/preview_screens.gd
	var host := Control.new()
	t.root.add_child(host)
	var toast := AchievementToast.new()
	host.add_child(toast)
	toast.show_achievement("first_blood")
	t.check(true, "bandeau de succès")
	host.queue_free()
