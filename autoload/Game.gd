extends Node
## État global de la campagne : or, jour, renom, compagnie, carte du monde, contrat en cours, sauvegarde.
## Les scènes lisent cet état et appellent ces méthodes ; elles ne calculent aucune règle.

signal changed  ## l'état a changé (rafraîchir l'affichage)
signal location_changed  ## entrée ou sortie d'un lieu
signal battle_started
signal battle_finished
signal achievement_unlocked(id: String)  ## un succès vient d'être débloqué

const SAVE_PATH: String = "user://savegame.json"
const ROAD_HEAL: int = 2  ## PV rendus à chaque homme par jour de route

var rng := RandomNumberGenerator.new()
var gold: int = 800
var day: int = 1
var day_fraction: float = 0.0
var renown: int = 0
var roster: Array[Unit] = []
var fallen: Array = []
var news: Array[String] = []
var game_over: bool = false
var battle: BattleState = null
var world: World = null
var location: String = ""  ## id du lieu où se trouve la compagnie ("" = sur la carte)
var active_contract: Dictionary = {}  ## contrat accepté, à remplir à l'endroit indiqué
var inventory: Array = []  ## objets possédés mais non équipés : {"kind": "weapon"|"head"|"body"|"shield", "key": ...}
var pending_loot: Array = []  ## butin tiré à la fin d'une bataille gagnée, versé à l'inventaire par finish_battle
var pending_loot_ready: bool = false
var last_battle_report: Dictionary = {}  ## compte rendu de la dernière bataille (rempli par finish_battle, lu par SummaryScreen)
var loot_rng := RandomNumberGenerator.new()  ## aléa du butin, séparé de `rng` pour ne pas modifier le déroulé du reste
var pending_event: Dictionary = {}  ## événement de route en attente d'un choix : {"id": ..., "choice_text": ...} ({} = aucun)
var last_event_day: int = 0
var last_event_id: String = ""
var random_events: bool = true  ## faux dans les tests de déplacement : pas d'événement de route imprévu
var autosave: bool = true  ## désactivé par les tests : plus aucune écriture automatique (savegame.json ni emplacements)
var campaign: Dictionary = Campaign.new_state()  ## menace, crise finale, arcs, uniques sortis (voir core/campaign.gd)
var campaign_rng := RandomNumberGenerator.new()  ## aléa de la campagne (escalade, arcs), séparé de `rng`
var stats: Dictionary = Achievements.default_stats()  ## statistiques de la campagne (voir core/achievements.gd), sauvegardées
var unlocked: Dictionary = {}  ## succès débloqués {id: jour}, conservés entre les parties (user://achievements.json)
var achievements_path: String = Achievements.FILE_PATH
var banner: Dictionary = Data.BANNER_DEFAULT.duplicate()  ## bannière de la compagnie (voir core/banner.gd)
var company_name: String = Data.COMPANY_NAME_DEFAULT
var provisions: int = Data.PROVISIONS_START  ## vivres (rations) : un homme mange une ration par jour de route
var company_morale: float = Data.MORALE_START  ## moral de la compagnie, 0 à 100 (voir battle_start_morale)
var starve_days: int = 0  ## jours consécutifs sans de quoi manger
var buildings: Dictionary = {}  ## niveaux des bâtiments du camp {clé de Data.CAMP_BUILDINGS: 1 à 3} (voir core/camp_buildings.gd)
var faction_standing: Dictionary = Factions.default_standing()  ## réputation auprès de chaque faction humaine (Data.FACTIONS)
var story_flags: Dictionary = {}  ## histoires : "story_<id>" = jour de début, et les repères posés par leurs choix {clé: jour}
var pending_events: Array = []  ## suites d'histoires programmées : [{"id": étape, "due_day": jour}]
var _food_warned: bool = false
var difficulty: String = Data.DIFFICULTY_DEFAULT  ## niveau choisi à la création de la partie (voir core/difficulty.gd) ; ne change plus ensuite


func _ready() -> void:
	rng.randomize()
	loot_rng.randomize()
	unlocked = Achievements.load_unlocked(achievements_path)


# --- Partie ---

func new_game(seed_value: int = -1, p_difficulty: String = "normal") -> void:
	difficulty = Difficulty.clean(p_difficulty)
	if seed_value >= 0:
		rng.seed = seed_value
		loot_rng.seed = seed_value + 7919
	else:
		rng.randomize()
		loot_rng.randomize()
	inventory = []
	pending_loot = []
	pending_loot_ready = false
	Unit.next_id = 1
	gold = Difficulty.start_gold(difficulty)
	day = 1
	day_fraction = 0.0
	renown = 0
	roster.clear()
	fallen.clear()
	game_over = false
	battle = null
	active_contract = {}
	pending_event = {}
	last_event_day = 0
	last_event_id = ""
	stats = Achievements.default_stats()
	banner = Data.BANNER_DEFAULT.duplicate()
	company_name = Data.COMPANY_NAME_DEFAULT
	provisions = Data.PROVISIONS_START
	company_morale = Data.MORALE_START
	starve_days = 0
	buildings = {}
	faction_standing = Factions.default_standing()
	story_flags = {}
	pending_events = []
	_food_warned = false
	news = ["La Compagnie du Corbeau est fondée. Cinq lames, peu de couronnes, beaucoup de routes."]
	for k in ["milicien", "bucheron", "braconnier", "fermier", "deserteur"]:
		roster.append(Contracts.make_merc(k, rng, _names()))
	var cseed: int = seed_value if seed_value >= 0 else int(randi() % 1000000)
	campaign = Campaign.new_state("o" if cseed % 2 == 0 else "u")
	campaign_rng.seed = cseed + 104729
	world = World.generate(rng, renown)
	Factions.assign_owners(world)
	for s in world.settlements:
		_restock(s)
	location = str(world.settlements[0]["id"])
	save()
	changed.emit()
	location_changed.emit()


## Ajoute `n` à un compteur de statistiques.
func stat_add(key: String, n: float = 1.0) -> void:
	if not stats.has(key) or n == 0.0:
		return
	stats[key] = float(stats[key]) + n if key == "travel_days" else int(stats[key]) + int(n)


func _earn(n: int) -> void:
	gold += n
	stat_add("gold_earned", float(maxi(0, n)))


func _spend(n: int) -> void:
	gold -= n
	stat_add("gold_spent", float(maxi(0, n)))


## État de la partie lu par les succès de type « ctx ».
func achievement_context() -> Dictionary:
	var max_level: int = 1
	for m in roster:
		max_level = maxi(max_level, m.level)
	return {
		"renown": renown, "gold": gold, "days": day - 1, "max_level": max_level, "roster": roster.size(),
		"sites": int(campaign.get("sites_taken", 0)),
		"arcs": (Campaign.arc_summary(campaign) as Array).filter(func(a: Dictionary) -> bool: return a["phase"] == "done").size(),
		"uniques": (campaign.get("uniques_taken", []) as Array).size(),
		"ending": 1 if (bool(campaign.get("ending_pending", false)) or bool(campaign.get("free_mode", false))) else 0,
	}


## Débloque les succès atteints (signal `achievement_unlocked` pour chacun) ; renvoie leurs ids.
func check_achievements() -> Array[String]:
	if roster.is_empty() and battle == null:
		return []
	var fresh: Array[String] = Achievements.newly_met(stats, achievement_context(), unlocked)
	for id in fresh:
		unlocked[id] = day
	if not fresh.is_empty():
		if autosave:
			Achievements.save_unlocked(unlocked, achievements_path)
		for id in fresh:
			achievement_unlocked.emit(id)
	return fresh


func set_banner(primary: String, secondary: String, emblem: int) -> void:
	banner = Banner.clean({"primary": primary, "secondary": secondary, "emblem": emblem})
	_after_change()


func set_company_name(n: String) -> void:
	company_name = Banner.clean_name(n)
	_after_change()


func _names() -> Array:
	var out: Array = []
	for m in roster:
		out.append(m.unit_name)
	return out


func add_news(lines: Array) -> void:
	var all: Array[String] = []
	for l in lines:
		all.append(str(l))
	all.append_array(news)
	news = all.slice(0, 4)


func wages() -> int:
	var t: int = 0
	for m in roster:
		t += m.wage
	return t


func repair_cost() -> int:
	var missing: int = 0
	for m in roster:
		missing += (m.head_armor_max() - m.arm_h) + (m.body_armor_max() - m.arm_b)
	var gear: int = 0
	for m in roster:
		gear += gear_repair_cost(m)
	return int(ceil(float(int(ceil(missing * 0.5)) + gear) * CampBuildings.repair_mult(buildings)))  ## la forge du camp rabat le prix


## Remise en état de l'arme et du bouclier d'un homme (proportionnelle à l'usure et au prix).
func gear_repair_cost(m: Unit) -> int:
	var c: int = 0
	if m.weapon_wears():
		c += Loot.repair_price(Loot.worn(Loot.item("weapon", m.weapon), m.weapon_dur_now()))
	if m.shield:
		c += Loot.repair_price(Loot.worn(Loot.item("shield"), m.shield_dur_now()))
	return c


func has_wounded() -> bool:
	for m in roster:
		if m.hp < m.hp_max:
			return true
	return false


func member(id: int) -> Unit:
	for m in roster:
		if m.id == id:
			return m
	return null


# --- Quartier général, vivres, moral, factions ---

func building_level(key: String) -> int:
	return CampBuildings.level_of(buildings, key)


## Capacité de la compagnie (tentes).
func max_roster() -> int:
	return mini(Data.MAX_ROSTER_CAP, Data.MAX_ROSTER + CampBuildings.roster_bonus(buildings))


## Emplacements de la réserve (entrepôt).
func stash_size() -> int:
	return Data.STASH_SIZE + CampBuildings.stash_bonus(buildings)


## Rayon de vue de la carte en pixels (poste de guet) : à lire par MapView à la place de sa constante VISION.
func vision_radius() -> float:
	return Data.MAP_VISION * CampBuildings.vision_mult(buildings)


func can_buy_building(key: String) -> bool:
	var c: int = CampBuildings.next_cost(buildings, key)
	return c >= 0 and gold >= c and not game_over and battle == null


## Achète le niveau suivant d'un bâtiment du camp (partout : le camp suit la compagnie).
func buy_building(key: String) -> bool:
	if not can_buy_building(key):
		return false
	var cost: int = CampBuildings.next_cost(buildings, key)
	_spend(cost)
	buildings[key] = building_level(key) + 1
	add_news(["%s : niveau %d (−%d couronnes)." % [Data.CAMP_BUILDINGS[key]["n"], building_level(key), cost]])
	_sfx("coins")
	_after_change()
	return true


## Ajoute du renom (l'enseigne majore les gains) ; renvoie le renom réellement ajouté.
func gain_renown(n: int) -> int:
	var g: int = n
	if n > 0:
		g = int(round(float(n) * CampBuildings.renown_mult(buildings)))
	var before: int = renown
	renown = maxi(0, renown + g)
	return renown - before


# Vivres

func provisions_cap() -> int:
	return Data.PROVISIONS_PER_MAN_CAP * maxi(1, roster.size())


## Jours de route que les vivres permettent de tenir.
func provisions_days() -> float:
	return float(provisions) / float(maxi(1, roster.size()))


## Prix de `n` rations ici (coefficient de lieu, réputation, cantine).
func food_cost(n: int) -> int:
	return int(ceil(float(price_of(Data.PROVISIONS_PRICE * n)) * CampBuildings.food_mult(buildings)))


func buy_provisions(n: int) -> bool:
	if not in_settlement() or game_over:
		return false
	n = mini(n, provisions_cap() - provisions)
	if n <= 0:
		return false
	var cost: int = food_cost(n)
	if gold < cost:
		return false
	_spend(cost)
	provisions += n
	_food_warned = false
	add_news(["Vivres : +%d rations pour %d couronnes." % [n, cost]])
	_sfx("coins")
	_after_change()
	return true


func buy_provisions_full() -> bool:
	return buy_provisions(provisions_cap() - provisions)


## Les hommes mangent sur la route : une ration chacun ; à court de vivres, la faim les affaiblit. Renvoie les lignes de nouvelles.
func _eat_on_road() -> Array:
	var lines: Array = []
	var n: int = roster.size()
	if n == 0:
		return lines
	var need: int = Difficulty.food_need(difficulty, n)
	if provisions >= need:
		provisions -= need
		starve_days = 0
		morale_add(CampBuildings.meal_morale(buildings))
		var left_days: float = provisions_days()
		if left_days <= float(Data.PROVISIONS_WARN_DAYS) and not _food_warned:
			_food_warned = true
			lines.append("Les vivres s'épuisent : il n'en reste que pour %d jour%s de route." % [int(left_days), "s" if int(left_days) > 1 else ""])
		elif left_days > float(Data.PROVISIONS_WARN_DAYS):
			_food_warned = false
		return lines
	var fed: int = provisions if need == n else mini(n, int(float(provisions) * float(n) / float(need)))
	provisions = 0
	starve_days += 1
	for i in range(fed, n):
		var m: Unit = roster[i]
		m.hp = maxi(1, m.hp - Data.STARVE_HP)
	morale_add(-Data.STARVE_MORALE)
	lines.append("Plus de vivres : %d homme%s à jeun (−%d PV, le moral chute)." % [n - fed, "s" if n - fed > 1 else "", Data.STARVE_HP])
	if starve_days >= 2 and roster.size() > 1 and rng.randf() < Data.STARVE_DESERT_CHANCE:
		var d: Unit = roster[rng.randi() % roster.size()]
		roster.erase(d)
		Bonds.prune(roster)
		lines.append("Affamé, %s déserte pendant la nuit." % d.unit_name)
	return lines


# Moral de compagnie

func morale_add(n: float) -> void:
	company_morale = clampf(company_morale + Difficulty.morale_delta(difficulty, n), 0.0, 100.0)


## Moral de départ des hommes en bataille : 2 (Hésitant) si la compagnie est abattue, 4 (Confiant) si elle est au sommet, sinon 3.
func battle_start_morale() -> int:
	if company_morale < Data.MORALE_LOW:
		return 2
	if company_morale > Data.MORALE_HIGH:
		return 4
	return 3


func morale_label() -> String:
	if company_morale < Data.MORALE_LOW:
		return "Abattue"
	if company_morale < 45.0:
		return "Morose"
	if company_morale <= Data.MORALE_HIGH:
		return "Correcte"
	return "Enthousiaste"


# Factions humaines

func standing_with(key: String) -> int:
	return int(faction_standing.get(key, 0))


func change_faction_standing(key: String, delta: int) -> void:
	if Data.FACTIONS.has(key):
		faction_standing[key] = clampi(standing_with(key) + delta, -Data.FACTION_STAND_MAX, Data.FACTION_STAND_MAX)


## Faction propriétaire du lieu où l'on se trouve ("" sur la carte).
func faction_here() -> String:
	return Factions.owner_of(settlement())


## Suites d'un contrat pour les factions (employeur, et rivale s'il y en a une). `result` : "win", "lost", "abandon".
func _faction_result(c: Dictionary, result: String) -> Array:
	var lines: Array = []
	var f: String = str(c.get("faction", ""))
	if not Data.FACTIONS.has(f) or c.get("kind", "contract") != "contract":
		return lines
	var delta: int = 0
	match result:
		"win":
			delta = Factions.GAIN_BASE + int(c.get("d", 1))
		"abandon":
			delta = -Factions.ABANDON_LOSS
		_:
			delta = -Factions.DEFEAT_LOSS
	change_faction_standing(f, delta)
	lines.append("%s : %+d de réputation." % [Factions.name_of(f), delta])
	var vs: String = str(c.get("vs_faction", ""))
	if result == "win" and Data.FACTIONS.has(vs):
		change_faction_standing(vs, -Factions.VS_LOSS)
		lines.append("%s : −%d de réputation." % [Factions.name_of(vs), Factions.VS_LOSS])
	return lines


## Mauvaise réputation : une patrouille de la faction ennemie parcourt la carte. Renvoie une ligne de nouvelles ou "".
func _maybe_spawn_patrol() -> String:
	if location != "" or world == null:
		return ""
	for k in Factions.keys():
		if standing_with(str(k)) > Data.FACTION_STAND_WORST or campaign_rng.randf() >= Data.FACTION_PATROL_CHANCE:
			continue
		var present: bool = false
		for p in world.parties:
			if str(p.get("patrol", "")) == str(k):
				present = true
		if present:
			continue
		var d: int = clampi(mini(3, 1 + renown / 160), 1, 3)
		var party: Dictionary = world.spawn_party("b", d, campaign_rng)
		if party.is_empty():
			continue
		party["patrol"] = str(k)
		party["title"] = "Patrouille : " + Factions.name_of(str(k))
		party["aggressive"] = true
		return "Une patrouille de la %s est lancée à vos trousses." % Factions.name_of(str(k))
	return ""


# Histoires et suites programmées

## Si une suite d'histoire est due (et qu'aucun événement n'attend), en fait l'événement en attente. Renvoie {"type": "event", ...} ou {}.
func pop_due_event() -> Dictionary:
	if not pending_event.is_empty() or battle != null or location != "":
		return {}
	var i: int = 0
	while i < pending_events.size():
		var pe: Dictionary = pending_events[i]
		if int(pe["due_day"]) > day:
			i += 1
			continue
		pending_events.remove_at(i)
		var def: Dictionary = Events.get_def(str(pe["id"]))
		if def.is_empty():
			continue
		last_event_day = day
		last_event_id = str(def["id"])
		pending_event = {"id": last_event_id}
		world.stop()
		save()
		return {"type": "event", "event": def}
	return {}


## Effets d'une issue d'événement propres à la vie de la compagnie et aux histoires (voir Data.STORIES).
func _apply_story_outcome(o: Dictionary, lines: Array) -> void:
	var recruit: Unit = null
	if o.has("food"):
		var f: int = int(o["food"])
		provisions = clampi(provisions + f, 0, maxi(provisions_cap(), provisions))
		lines.append("%+d rations" % f)
	if o.has("morale"):
		morale_add(float(o["morale"]))
		lines.append("moral %+d" % int(o["morale"]))
	if o.has("standing"):
		for k in o["standing"]:
			change_faction_standing(str(k), int(o["standing"][k]))
			lines.append("%s : %+d" % [Factions.name_of(str(k)), int(o["standing"][k])])
	if o.has("threat"):
		campaign["threat"] = clampf(float(campaign.get("threat", 0.0)) + float(o["threat"]), 0.0, Campaign.THREAT_MAX)
		lines.append("menace %+d" % int(o["threat"]))
	if o.has("recruit_story"):
		recruit = _recruit_story(str(o["recruit_story"]), lines)
	if o.has("bond"):
		var friends: bool = str(o["bond"]) == "friends"
		var pair: Array = []
		if recruit != null and roster.size() >= 2:
			var other: Unit = recruit
			for i in 6:
				other = roster[rng.randi() % roster.size()]
				if other != recruit:
					break
			if other != recruit:
				Bonds.add(recruit, other, 16 if friends else -12)
				pair = [recruit, other]
		else:
			pair = Bonds.random_pair(roster, rng, 16 if friends else -12)
		if pair.size() == 2:
			lines.append("%s et %s %s" % [pair[0].unit_name, pair[1].unit_name, "deviennent amis" if friends else "se prennent en grippe"])
	if o.has("unique"):
		var uk: String = str(o["unique"])
		if Data.UNIQUES.has(uk) and not (campaign["uniques_taken"] as Array).has(uk):
			var it: Dictionary = Uniques.item_of(uk)
			add_to_stash([it])
			_note_uniques([it])
			lines.append("objet unique : %s" % Loot.item_name(it))
		else:
			_earn(150)
			lines.append("+150 couronnes")
	if o.has("contract"):
		var where: String = _post_special_contract(o["contract"])
		if where != "":
			lines.append("nouveau contrat à %s" % where)
	if o.has("flag"):
		story_flags[str(o["flag"])] = day
	if o.has("schedule"):
		var sc: Dictionary = o["schedule"]
		pending_events.append({"id": str(sc["id"]), "due_day": day + int(sc.get("days", 1))})


## Recrue unique d'une histoire (Data.STORY_RECRUITS) : talents, traits et niveau prédéfinis. Renvoie l'homme, ou null si la compagnie est pleine.
func _recruit_story(key: String, lines: Array) -> Unit:
	if not Data.STORY_RECRUITS.has(key):
		return null
	if roster.size() >= max_roster():
		_earn(100)
		lines.append("compagnie au complet : +100 couronnes à la place")
		return null
	var def: Dictionary = Data.STORY_RECRUITS[key]
	var t: Dictionary = Data.BG[str(def["bg"])]
	var u: Unit = Contracts.make_unit(t, "p", str(def["name"]), rng)
	u.faction = "p"
	u.wage = int(t["wage"])
	Traits.set_fixed(u, def["traits"])
	u.level = int(def["level"])
	u.xp = int(Data.XP_THRESHOLDS[clampi(u.level, 0, Data.XP_THRESHOLDS.size() - 1)])
	u.perks.assign(def["perks"])
	u.perk_points = maxi(0, Perks.points_for_level(u.level) - u.perks.size())
	for k in def["stats"]:
		u.set(str(k), int(u.get(str(k))) + int(def["stats"][k]))
	u.hp = u.hp_max
	u.wage = int(round(float(u.wage) * (1.0 + 0.12 * float(u.level - 1))))
	roster.append(u)
	lines.append("%s rejoint la compagnie" % u.unit_name)
	if key == "jumeau_a" or key == "jumeau_b":  # les jumeaux sont inséparables
		var twin: String = str(Data.STORY_RECRUITS["jumeau_b" if key == "jumeau_a" else "jumeau_a"]["name"])
		for m in roster:
			if m.unit_name == twin:
				Bonds.set_bond(u, m, 30)
	return u


## Poste un contrat spécial (issue d'histoire) dans le lieu le plus proche. Renvoie le nom du lieu, ou "" s'il n'y a pas de place sur la carte.
func _post_special_contract(spec: Dictionary) -> String:
	var best: Dictionary = {}
	var bd: float = 1e12
	for s in world.settlements:
		var d: float = world.settlement_pos(s).distance_to(world.player_pos)
		if d < bd:
			bd = d
			best = s
	if best.is_empty():
		return ""
	var origin: Vector2 = world.settlement_pos(best)
	var target: Vector2 = world.random_target(origin, 150.0, 480.0)
	if target == Vector2.ZERO:
		_earn(int(spec["pay"]) / 2)
		return ""
	var type: String = str(spec["type"])
	var d3: int = int(spec["d"])
	var c: Dictionary = {
		"kind": "contract", "type": type, "type_contract": "kill", "d": d3, "foes": Contracts.foes_for(type, d3), "title": str(spec["title"]),
		"desc": str(spec["desc"]), "employer": str(spec["employer"]), "origin": str(best["name"]), "origin_id": str(best["id"]),
		"pay": int(spec["pay"]), "days": maxi(1, int(ceil(origin.distance_to(target) / World.DAY_PX))), "tx": target.x, "ty": target.y,
		"ox": origin.x, "oy": origin.y, "target_name": str(Contracts.pick(Data.TARGET_NAMES[type], rng)), "biome": world.biome_at(target),
		"special": true,
	}
	if Data.FACTIONS.has(str(spec.get("faction", ""))):
		c["faction"] = str(spec["faction"])
	(best["contracts"] as Array).insert(0, c)
	return str(best["name"])


# --- Lieux ---

func settlement() -> Dictionary:
	return world.settlement_by_id(location) if location != "" else {}


func in_settlement() -> bool:
	return location != ""


func _restock(s: Dictionary) -> void:
	var shop: Dictionary = Data.SHOPS[s["kind"]]
	var standing: int = world.standing_of(s)  ## bonne réputation : un contrat de plus ; mauvaise : un de moins
	var n_contracts: int = clampi(int(shop["contracts"]) + (1 if standing >= 5 else (-1 if standing <= -5 else 0)), 1, 4)
	s["contracts"] = Contracts.gen_contracts(renown, rng, str(s["name"]), world.settlement_pos(s), world, n_contracts, standing, str(s["id"]))
	s["recruits"] = Contracts.gen_recruits(rng, _names(), shop["recruits"], 4 if s["kind"] == "city" else 3)
	s["restock_day"] = day + Data.RESTOCK_DAYS
	s["rare"] = Campaign.rare_stock(s, day, campaign["uniques_taken"])
	Campaign.post_arcs(campaign, world, s, day, renown)
	var ci: int = s["contracts"].size() - 1  # les contrats d'arc prennent la place d'un contrat ordinaire
	while s["contracts"].size() > n_contracts and ci >= 0:
		if not s["contracts"][ci].has("arc"):
			s["contracts"].remove_at(ci)
		ci -= 1
	_apply_factions(s)
	for c in s["contracts"]:
		c["pay"] = Difficulty.pay(difficulty, int(c["pay"]))  ## prime selon la difficulté (neutre en « normal »), après les modificateurs de faction


## Employeur des contrats, primes selon la réputation, recrues d'élite et marchand rare chez un allié. Aléa local : `rng` reste intact.
func _apply_factions(s: Dictionary) -> void:
	var owner: String = Factions.owner_of(s)
	if not Data.FACTIONS.has(owner):
		return
	var r := RandomNumberGenerator.new()
	r.seed = day * 7919 + int(str(s["id"]).trim_prefix("s")) * 331 + 29
	var standing: int = standing_with(owner)
	for c in s["contracts"]:
		if not c.has("faction"):
			Factions.tag_contract(c, owner, r)
			Factions.apply_pay(c, standing)
	if standing >= Data.FACTION_STAND_GOOD:
		(s["recruits"] as Array).append(Factions.make_elite_recruit(r, _names()))
	if standing >= Data.FACTION_STAND_BEST and (s.get("rare", []) as Array).is_empty():
		s["rare"] = Factions.forced_rare(s, day, campaign["uniques_taken"])


func enter_settlement(id: String) -> void:
	var s: Dictionary = world.settlement_by_id(id)
	if s.is_empty():
		return
	world.stop()
	world.player_pos = world.settlement_pos(s)
	location = id
	s["visited_day"] = day
	if day >= int(s["restock_day"]):
		_restock(s)
	add_news(["La compagnie arrive à %s." % s["name"]])
	_complete_transport(id)
	save()
	location_changed.emit()
	changed.emit()


func leave_settlement() -> void:
	if location == "":
		return
	location = ""
	save()
	location_changed.emit()
	changed.emit()


func price_of(base: int) -> int:
	var s: Dictionary = settlement()
	return Difficulty.price(difficulty, int(round(base * float(s.get("price_mult", 1.0)) * World.standing_price_mult(world.standing_of(s)) * Factions.price_mult(standing_with(Factions.owner_of(s))))))


func in_stock(kind: String, key: String = "") -> bool:
	var s: Dictionary = settlement()
	if s.is_empty():
		return false
	var shop: Dictionary = Data.SHOPS[s["kind"]]
	if kind == "shield":
		return bool(shop["shield"])
	return (shop[kind] as Array).has(key)


# --- Contrats ---

func accept_contract(index: int) -> bool:
	var s: Dictionary = settlement()
	if s.is_empty() or not active_contract.is_empty() or index < 0 or index >= s["contracts"].size():
		return false
	active_contract = s["contracts"][index]
	s["contracts"].remove_at(index)
	Campaign.on_accept(campaign, active_contract)
	add_news(["Contrat accepté : %s. Cap sur %s." % [active_contract["title"], active_contract["target_name"]]])
	_after_change()
	return true


func abandon_contract() -> void:
	if active_contract.is_empty():
		return
	renown = maxi(0, renown - 5)
	world.change_standing(str(active_contract.get("origin_id", "")), -2)
	add_news(["Contrat abandonné : %s (−5 renom)." % active_contract["title"]])
	add_news(_faction_result(active_contract, "abandon"))
	add_news(_arc_result(active_contract, false))
	active_contract = {}
	_after_change()


func contract_target() -> Vector2:
	return Vector2(float(active_contract["tx"]), float(active_contract["ty"])) if not active_contract.is_empty() else Vector2.ZERO


# --- Temps ---

func _pay_or_desert(days: int) -> String:
	_spend(wages() * days)
	if gold < 0 and not roster.is_empty():
		morale_add(-8.0)  ## paie en retard
		var m: Unit = roster[rng.randi() % roster.size()]
		roster.erase(m)
		gold = 0
		if roster.is_empty():
			game_over = true
		return "Faute de paie, %s déserte." % m.unit_name
	return ""


## Fait passer `days` jours (fractions admises). Chaque jour entier : solde, soins de route, nouvelles bandes.
func advance_time(days: float) -> void:
	world.update_parties(days)
	day_fraction += days
	var lines: Array = []
	var rolled: bool = false
	while day_fraction >= 1.0:
		day_fraction -= 1.0
		day += 1
		rolled = true
		if location == "":
			for m in roster:
				m.hp = mini(m.hp_max, m.hp + ROAD_HEAL + CampBuildings.road_heal_bonus(buildings))
			lines.append_array(_eat_on_road())
			morale_add(-0.2)  ## la route use
		else:
			morale_add(0.5)  ## on mange sur place, à l'abri
		for m in roster:  # blessures : un jour de soins sur la route, deux en ville (repos), plus l'infirmerie
			for n in Injuries.heal(m, (1 if location == "" else 2) + CampBuildings.injury_days_bonus(buildings)):
				lines.append("%s est remis de sa blessure (%s)." % [m.unit_name, n.to_lower()])
		lines.append_array(Campaign.daily(campaign, world, campaign_rng, day, renown, Difficulty.threat_mult(difficulty)))
		var deserter: String = _pay_or_desert(1)
		if deserter != "":
			lines.append(deserter)
		else:
			morale_add(0.3)  ## solde à jour
		var patrol: String = _maybe_spawn_patrol()
		if patrol != "":
			lines.append(patrol)
		if rng.randf() < 0.35:
			world.fill_parties(renown, World.MAX_PARTIES)
	if not lines.is_empty():
		add_news(lines)
	if rolled:
		check_achievements()
	if rolled or not lines.is_empty():
		changed.emit()


## Avance sur la carte pendant `days` jours. Renvoie l'évènement survenu :
## {"type": "" | "settlement" | "target" | "encounter" | "over", ...}
func map_step(days: float) -> Dictionary:
	if battle != null or location != "" or game_over or not pending_event.is_empty():
		return {}
	var day_before: int = day
	var used: float = world.step_player(days)
	stat_add("travel_days", used)
	advance_time(used)
	if game_over:
		return {"type": "over"}
	var p: Dictionary = world.encounter()
	if not p.is_empty():
		world.stop()
		return {"type": "encounter", "party": p}
	if not active_contract.is_empty():
		if Contracts.is_transport(active_contract):
			if not bool(active_contract.get("ambush_done", false)) and _transport_progress() >= float(active_contract.get("ambush_at", -1.0)) and float(active_contract.get("ambush_at", -1.0)) >= 0.0:
				active_contract["ambush_done"] = true
				world.stop()
				return {"type": "ambush"}
			if world.player_pos.distance_to(contract_target()) <= World.ARRIVE_PX:
				var dest_id: String = str(active_contract["dest_id"])
				enter_settlement(dest_id)
				return {"type": "settlement", "id": dest_id}
		elif world.player_pos.distance_to(contract_target()) <= World.ARRIVE_PX:
			world.stop()
			return {"type": "target"}
	if random_events and day > day_before and not game_over:
		var due: Dictionary = pop_due_event()  # suite d'une histoire programmée
		if not due.is_empty():
			return due
	if world.path.is_empty() and not world.dest.is_empty():
		var d: Dictionary = world.dest
		world.stop()
		if d["kind"] == "settlement":
			enter_settlement(str(d["id"]))
			return {"type": "settlement", "id": d["id"]}
		if d["kind"] == "site" and not world.site_by_id(str(d["id"])).is_empty():
			return {"type": "site", "id": str(d["id"])}  # jamais d'entrée en ville : l'écran de la carte propose l'assaut ou le repos
	elif random_events and day > day_before and not world.path.is_empty():
		# un jour entier de route vient de s'écouler : un événement peut survenir (jamais en ville ni en bataille)
		if Events.roll_day(rng, day - last_event_day):
			return _start_event()
	return {}


## Part du trajet origine → destination déjà parcourue par la compagnie (0 à 1).
func _transport_progress() -> float:
	var o := Vector2(float(active_contract["ox"]), float(active_contract["oy"]))
	var total: float = o.distance_to(contract_target())
	return clampf(o.distance_to(world.player_pos) / maxf(total, 1.0), 0.0, 1.0)


func _start_event() -> Dictionary:
	var def: Dictionary = Events.pick(rng, last_event_id, story_flags, day)
	last_event_day = day
	last_event_id = str(def["id"])
	pending_event = {"id": last_event_id}
	world.stop()
	save()
	return {"type": "event", "event": def}


## Applique le choix `choice_id` de l'événement en attente. Renvoie {"text": ..., "battle": bool, "ok": bool}.
## Si "battle" est vrai, l'embuscade est déjà lancée (`battle_started` émis).
func resolve_event(choice_id: String) -> Dictionary:
	if pending_event.is_empty():
		return {"ok": false, "text": "", "battle": false}
	var ev_id: String = str(pending_event["id"])
	var choice: Dictionary = Events.choice_of(Events.get_def(ev_id), choice_id)
	if choice.is_empty() or gold < int(choice.get("cost", 0)):
		return {"ok": false, "text": "", "battle": false}
	pending_event = {}
	stat_add("events_seen")
	_spend(int(choice.get("cost", 0)))
	var o: Dictionary = Events.resolve(ev_id, choice_id, rng)
	var lines: Array = []
	var text: String = str(o.get("text", ""))
	if o.has("gold"):
		var g: int = int(o["gold"])
		gold = maxi(0, gold + g)
		if g > 0:
			stat_add("gold_earned", float(g))
		lines.append("%+d couronnes" % g)
	if o.has("hp_all"):
		var h: int = int(o["hp_all"])
		for m in roster:
			m.hp = clampi(m.hp + h, 1, m.hp_max)
		lines.append("%+d PV à chaque homme" % h)
	if o.has("hp_one") and not roster.is_empty():
		var v: Unit = roster[rng.randi() % roster.size()]
		var h2: int = int(o["hp_one"])
		v.hp = clampi(v.hp + h2, 1, v.hp_max)
		lines.append("%s : %+d PV" % [v.unit_name, h2])
	if o.has("renown"):
		var r: int = gain_renown(int(o["renown"]))
		lines.append("%+d renom" % r)
	if o.has("xp_all"):
		for m in roster:
			m.xp += int(o["xp_all"])
			level_check(m)
		lines.append("+%d XP à chaque homme" % int(o["xp_all"]))
	if bool(o.get("repair", false)):
		for m in roster:
			m.arm_h = m.head_armor_max()
			m.arm_b = m.body_armor_max()
			m.weapon_dur = -1
			m.shield_dur = -1
		lines.append("armures réparées")
	if o.has("recruit"):
		if roster.size() >= max_roster():
			gold += 30
			lines.append("compagnie au complet : +30 couronnes à la place")
		else:
			var key: String = str(o["recruit"])
			if key == "random" or not Data.BG.has(key):
				key = str(Contracts.pick(["fermier", "bucheron", "mendiant", "braconnier"], rng))
			var nu: Unit = Contracts.make_merc(key, rng, _names())
			roster.append(nu)
			lines.append("%s rejoint la compagnie" % nu.unit_name)
	if o.has("days"):
		var before: int = roster.size()
		advance_time(float(o["days"]))
		lines.append("−%d jour%s" % [int(o["days"]), "s" if int(o["days"]) > 1 else ""])
		if roster.size() < before:
			lines.append("un homme a déserté faute de paie")
	_apply_story_outcome(o, lines)
	var story: String = Events.story_of(ev_id)
	if story != "" and not story_flags.has("story_" + story):
		story_flags["story_" + story] = day  ## l'histoire est commencée : elle ne sera plus tirée au hasard
	var fight: bool = o.has("battle") and not game_over
	var summary: String = text + (" (" + ", ".join(lines) + ")" if not lines.is_empty() else "")
	add_news([summary if summary != "" else "Événement de route."])
	if roster.is_empty():
		game_over = true
	if fight:
		var bd: Dictionary = o["battle"]
		start_battle({
			"kind": "ambush", "battle_type": "ambush", "party_id": -1, "type": str(bd["type"]), "d": int(bd["d"]), "foes": Contracts.foes_for(str(bd["type"]), int(bd["d"])),
			"title": "Embuscade en chemin", "desc": "", "employer": "", "origin": "", "pay": 0, "days": 0, "biome": world.biome_at(world.player_pos),
		})
	_after_change()
	return {"ok": true, "text": text, "effects": lines, "battle": fight and battle != null}


## Contrat de transport terminé à l'arrivée dans la ville de destination.
func _complete_transport(id: String) -> void:
	if active_contract.is_empty() or not Contracts.is_transport(active_contract) or str(active_contract.get("dest_id", "")) != id:
		return
	var c: Dictionary = active_contract
	var d: int = int(c["d"])
	_earn(int(c["pay"]))
	stat_add("contracts_done")
	stat_add("transports_done")
	var rg: int = gain_renown(25 * d)
	world.change_standing(str(c.get("origin_id", "")), 2)
	world.change_standing(id, 1)
	add_news(["Contrat rempli : %s. +%d couronnes, +%d renom." % [c["title"], int(c["pay"]), rg]])
	add_news(_faction_result(c, "win"))
	morale_add(4.0)
	active_contract = {}


# --- Actions dans un lieu ---

func rest() -> void:
	if location == "":
		return
	var w: int = wages()
	for m in roster:
		m.hp = mini(m.hp_max, m.hp + 15 + Traits.rest_bonus(m) + CampBuildings.rest_heal_bonus(buildings))
	var before: int = roster.size()
	advance_time(1.0)
	morale_add(3.0)
	var lines: Array = ["Un jour de repos. −%d couronnes de solde." % w]
	if roster.size() < before:
		lines.push_front("Faute de paie, un homme a déserté.")
	add_news(lines)
	_after_change()


func repair() -> void:
	var c: int = repair_cost()
	if location == "" or c <= 0 or gold < c:
		return
	_spend(c)
	for m in roster:
		m.arm_h = m.head_armor_max()
		m.arm_b = m.body_armor_max()
		m.weapon_dur = -1
		m.shield_dur = -1
	add_news(["Armures, armes et boucliers réparés pour %d couronnes." % c])
	_after_change()


func move_up(id: int) -> void:
	var i: int = roster.find(member(id))
	if i > 0:
		var t: Unit = roster[i - 1]
		roster[i - 1] = roster[i]
		roster[i] = t
		_after_change()


func dismiss(id: int) -> void:
	var m: Unit = member(id)
	if m == null or roster.size() <= 1:
		return
	roster.erase(m)
	add_to_stash(Loot.gear_items(m))  ## son équipement (sac compris) revient à la compagnie (à revendre)
	add_news(["%s quitte la compagnie." % m.unit_name])
	_after_change()


func hire(index: int) -> bool:
	var s: Dictionary = settlement()
	if s.is_empty() or index < 0 or index >= s["recruits"].size():
		return false
	var r: Dictionary = s["recruits"][index]
	if gold < int(r["price"]) or roster.size() >= max_roster():
		return false
	_spend(int(r["price"]))
	stat_add("men_hired")
	roster.append(r["u"])
	s["recruits"].remove_at(index)
	add_news(["%s rejoint la compagnie." % r["u"].unit_name])
	_after_change()
	return true


## kind : "weapon", "shield", "head", "body". Achat chez le marchand du lieu. Renvoie true si l'achat a eu lieu.
func buy(m: Unit, kind: String, key: String = "") -> bool:
	if not in_stock(kind, key):
		return false
	var line: String
	match kind:
		"weapon":
			var w: Dictionary = Data.WPN[key]
			var price: int = price_of(int(w["price"]))
			if gold < price:
				return false
			_spend(price)
			m.weapon = key
			m.weapon_dur = -1
			if not bool(w["h1"]):
				m.shield = false
			line = "%s s'équipe : %s." % [m.unit_name, w["n"]]
		"shield":
			var price: int = price_of(int(Data.SHIELD["price"]))
			if gold < price or not bool(m.weapon_data()["h1"]) or m.shield:
				return false
			_spend(price)
			m.shield = true
			m.shield_dur = -1
			line = "%s s'équipe : %s." % [m.unit_name, Data.SHIELD["n"]]
		"head":
			var h: Dictionary = Data.HEAD[key]
			var price: int = price_of(int(h["price"]))
			if gold < price:
				return false
			_spend(price)
			m.head = key
			m.arm_h = int(h["a"])
			line = "%s s'équipe : %s." % [m.unit_name, h["n"]]
		"body":
			var b: Dictionary = Data.BODY[key]
			var price: int = price_of(int(b["price"]))
			if gold < price:
				return false
			_spend(price)
			m.body = key
			m.arm_b = int(b["a"])
			line = "%s s'équipe : %s." % [m.unit_name, b["n"]]
		"tool":  # outil de jet : va dans le sac de l'homme (sinon dans la réserve)
			var tl: Dictionary = Data.TOOLS[key]
			var price: int = price_of(int(tl["price"]))
			var slot: int = Inventory.bag_free_slot(m)
			if gold < price or (slot < 0 and inventory.size() >= Data.STASH_SIZE):
				return false
			_spend(price)
			if slot >= 0:
				m.bag[slot] = Loot.item("tool", key)
			else:
				inventory.append(Loot.item("tool", key))
			line = "%s prend : %s." % [m.unit_name, tl["n"]]
		_:
			return false
	add_news([line])
	_sfx("coins")
	_after_change()
	return true


## Joue un effet sonore s'il y a un arbre de scène avec l'autoload Audio (sans effet dans les tests).
func _sfx(event: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var a: Node = tree.root.get_node_or_null("Audio") if tree != null else null
	if a != null:
		a.call("play", event)


# --- Inventaire : vente et équipement ---

## Prix de vente d'un objet ici : 40 % du prix de base × coefficient du lieu.
func sell_price(it: Dictionary) -> int:
	return price_of(Loot.sell_base(it))


## Vend l'objet n° `index` de l'inventaire au marchand du lieu.
func sell(index: int) -> bool:
	if not in_settlement() or index < 0 or index >= inventory.size():
		return false
	var it: Dictionary = inventory[index]
	var price: int = sell_price(it)
	_earn(price)
	inventory.remove_at(index)
	add_news(["%s vendu : +%d couronnes." % [Loot.item_name(it), price]])
	_sfx("coins")
	_after_change()
	return true


func can_equip_from_inventory(m: Unit, index: int) -> bool:
	return m != null and index >= 0 and index < inventory.size() and battle == null and Inventory.auto_slot(m, inventory[index]) != ""


## Équipe `m` avec l'objet n° `index` ; l'ancien objet (et le bouclier devenu inutile) retourne à l'inventaire (voir core/inventory.gd).
func equip_from_inventory(m: Unit, index: int) -> bool:
	if not can_equip_from_inventory(m, index):
		return false
	var iname: String = Loot.item_name(inventory[index])
	var res: Dictionary = Inventory.equip(inventory, m, index, stash_size())
	if not bool(res["ok"]):
		return false
	add_news(["%s s'équipe : %s." % [m.unit_name, iname]])
	_after_change()
	return true


## Ajoute des objets à la réserve (Data.STASH_SIZE emplacements). Le trop-plein est vendu d'office à son prix de revente de base
## (40 % du prix, sans coefficient de lieu) : un message le signale. Renvoie le nombre d'objets vendus d'office.
func add_to_stash(items: Array) -> int:
	var overflow: Array = Inventory.add_items(inventory, items, stash_size())
	var total: int = 0
	for it in overflow:
		total += Loot.sell_base(it)
	if not overflow.is_empty():
		_earn(total)
		add_news(["Réserve pleine : %d objet%s vendu%s d'office (+%d couronnes)." % [overflow.size(), "s" if overflow.size() > 1 else "", "s" if overflow.size() > 1 else "", total]])
	return overflow.size()


## Inventaire modifiable ? (pas pendant une bataille : les hommes y sont des copies)
func can_edit_inventory() -> bool:
	return battle == null


## Déplace un objet entre emplacements (voir Inventory.move) ; sauvegarde et notifie si réussi.
func inv_move(from: Dictionary, to: Dictionary) -> Dictionary:
	if not can_edit_inventory():
		return Inventory.fail("Impossible pendant une bataille.")
	var res: Dictionary = Inventory.move(inventory, from, to, stash_size())
	if bool(res["ok"]):
		_after_change()
	return res


## Équipe l'objet n° `index` de la réserve sur `m`.
func inv_equip(m: Unit, index: int) -> Dictionary:
	if not can_edit_inventory():
		return Inventory.fail("Impossible pendant une bataille.")
	var res: Dictionary = Inventory.equip(inventory, m, index, stash_size())
	if bool(res["ok"]):
		_after_change()
	return res


func inv_unequip(m: Unit, slot: String) -> Dictionary:
	return inv_move(Inventory.at(m, slot), Inventory.in_stash())


func inv_give(from_m: Unit, slot: String, to_m: Unit) -> Dictionary:
	if not can_edit_inventory():
		return Inventory.fail("Impossible pendant une bataille.")
	var res: Dictionary = Inventory.give(inventory, from_m, slot, to_m, stash_size())
	if bool(res["ok"]):
		_after_change()
	return res


func inv_sort(mode: String) -> void:
	Inventory.sort_stash(inventory, mode)
	_after_change()


## Jette l'objet n° `index` de la réserve (sans le vendre).
func discard(index: int) -> bool:
	if not can_edit_inventory() or index < 0 or index >= inventory.size():
		return false
	var it: Dictionary = inventory[index]
	inventory.remove_at(index)
	add_news(["%s jeté." % Loot.item_name(it)])
	_after_change()
	return true


## Tire (une seule fois par bataille) le butin d'une bataille gagnée ; l'écran de fin l'affiche, finish_battle le verse.
func prepare_loot() -> Array:
	if battle == null:
		return pending_loot
	if not pending_loot_ready:
		pending_loot_ready = true
		pending_loot = []
		if battle.over == "win":
			pending_loot = Loot.roll_battle(battle.units, loot_rng, Difficulty.loot_mult(difficulty))
			if battle.contract.get("kind", "contract") == "contract":
				var rare: Dictionary = Loot.roll_contract_bonus(int(battle.contract.get("d", 1)), loot_rng)
				if not rare.is_empty():
					pending_loot.append(rare)
			elif battle.contract.get("kind", "") == "assault" and Campaign.next_wave(battle.contract).is_empty():
				var site: Dictionary = world.site_by_id(str(battle.contract.get("site_id", "")))
				if not site.is_empty():
					pending_loot.append_array(Campaign.assault_loot(str(site["kind"]), loot_rng, campaign["uniques_taken"]))
	return pending_loot


# --- Niveaux ---

func level_check(m: Unit) -> void:
	while m.level < 11 and m.xp >= int(Data.XP_THRESHOLDS[m.level + 1]):
		m.level += 1
		m.pending += 1
		m.perk_points += 1
		_sfx("levelup")


## Tire un gain pour chaque attribut. Le joueur en choisit 3.
func roll_promotion() -> Dictionary:
	var rolls: Dictionary = {}
	for k in Data.PROMO_RANGES:
		var r: Array = Data.PROMO_RANGES[k]
		rolls[k] = rng.randi_range(int(r[0]), int(r[1]))
	return rolls


## Les trois attributs choisis gagnent leur gain tiré (les talents se dépensent à part : `spend_perks`).
func apply_promotion(m: Unit, rolls: Dictionary, chosen: Array) -> bool:
	if chosen.size() != 3 or m.pending <= 0:
		return false
	for k in chosen:
		m.set(k, int(m.get(k)) + int(rolls[k]))
		if k == "hp_max":
			m.hp += int(rolls[k])
	m.pending -= 1
	add_news(["%s gagne en expérience." % m.unit_name])
	_after_change()
	return true


## Dépense des points de talent : `keys` dans l'ordre (tout ou rien). Voir `Perks.why_not`.
func spend_perks(m: Unit, keys: Array) -> bool:
	if m == null or keys.is_empty() or not Perks.take_all(m, keys):
		return false
	stat_add("perks_taken", float(keys.size()))
	add_news(["%s apprend : %s." % [m.unit_name, ", ".join(keys.map(func(k: Variant) -> String: return str(Data.PERKS[str(k)]["n"])))]])
	_after_change()
	return true


## Entraîneur de la ville : rend tous les talents (payant, en ville seulement).
func perk_reset_cost(m: Unit) -> int:
	return Perks.reset_cost(m)


func can_reset_perks(m: Unit) -> bool:
	return m != null and location != "" and not m.perks.is_empty() and gold >= Perks.reset_cost(m)


func reset_perks(m: Unit) -> bool:
	if not can_reset_perks(m):
		return false
	_spend(Perks.reset_cost(m))
	Perks.refund_all(m)
	add_news(["%s repart de zéro auprès de l'entraîneur : tous ses talents sont à rechoisir." % m.unit_name])
	_after_change()
	return true


# --- Bataille ---

func start_battle(contract: Dictionary) -> void:
	if roster.is_empty() or battle != null:
		return
	world.stop()
	battle = BattleState.create(contract, roster, rng, battle_start_morale(), CampBuildings.wear_mult(buildings), difficulty)
	save()
	battle_started.emit()


## Combat du contrat accepté (la compagnie est arrivée sur place).
func engage_target() -> void:
	if not active_contract.is_empty():
		start_battle(active_contract)


## Combat contre une bande errante croisée sur la route.
func engage_party(id: int) -> void:
	var p: Dictionary = world.party_by_id(id)
	if p.is_empty():
		return
	start_battle({
		"kind": "encounter", "party_id": id, "type": p["faction"], "d": p["d"], "foes": p["foes"].duplicate(),
		"title": "Embuscade : " + world.party_title(p).to_lower(), "desc": "", "employer": "", "origin": "", "pay": 0, "days": 0, "battle_type": "ambush", "traps": str(p["faction"]) == "b",
		"biome": world.biome_at(world.player_pos),
	})


## Embuscade sur la route d'un contrat de transport (escorte / livraison) : si on la perd, le contrat est perdu.
func engage_ambush() -> void:
	if active_contract.is_empty():
		return
	var c: Dictionary = active_contract
	start_battle({
		"kind": "ambush", "battle_type": "ambush", "transport": true, "party_id": -1, "type": c["type"], "d": c["d"], "foes": c["foes"].duplicate(),
		"title": "Embuscade sur la route de %s" % c["target_name"], "desc": "", "employer": "", "origin": c.get("origin", ""),
		"origin_id": c.get("origin_id", ""), "faction": c.get("faction", ""), "pay": 0, "days": 0, "biome": world.biome_at(world.player_pos),
	})


## Assaut d'un lieu hostile de la carte (aucun contrat requis). Renvoie false si impossible.
func engage_site(id: String) -> bool:
	var s: Dictionary = world.site_by_id(id)
	if s.is_empty() or s["state"] != "hostile" or battle != null or roster.is_empty():
		return false
	add_news(["La compagnie donne l'assaut : %s." % s["name"]])
	start_battle(Campaign.assault_contract(s, world))
	return battle != null


## Repos au poste libéré où se trouve la compagnie : +15 PV, un jour de solde.
func rest_at_site(id: String) -> bool:
	var s: Dictionary = world.site_by_id(id)
	if s.is_empty() or s["state"] != "friendly" or location != "" or world.player_pos.distance_to(world.settlement_pos(s)) > World.ARRIVE_PX * 2.0:
		return false
	var w: int = wages()
	for m in roster:
		m.hp = mini(m.hp_max, m.hp + Campaign.SITE_REST_HEAL + CampBuildings.rest_heal_bonus(buildings))
	var before: int = roster.size()
	advance_time(1.0)
	morale_add(3.0)
	var lines: Array = ["Un jour de repos à %s. −%d couronnes de solde." % [s["name"], w]]
	if roster.size() < before:
		lines.push_front("Faute de paie, un homme a déserté.")
	add_news(lines)
	_after_change()
	return true


## Achète l'objet n° `index` du marchand rare du lieu (il rejoint l'inventaire).
func buy_rare(index: int) -> bool:
	var s: Dictionary = settlement()
	if s.is_empty() or index < 0 or index >= (s.get("rare", []) as Array).size():
		return false
	var r: Dictionary = s["rare"][index]
	var price: int = rare_price_of(r)
	if gold < price or inventory.size() >= stash_size():
		return false
	_spend(price)
	inventory.append(r["item"])
	_note_uniques([r["item"]])
	s["rare"].remove_at(index)
	add_news(["Marchand rare : %s acheté pour %d couronnes." % [Loot.item_name(r["item"]), price]])
	_sfx("coins")
	_after_change()
	return true


func rare_price_of(r: Dictionary) -> int:
	return price_of(int(r["price"]))


## Note les objets uniques que le joueur détient désormais (ils ne ressortiront plus).
func _note_uniques(items: Array) -> void:
	for it in items:
		var k: String = str(it.get("key", ""))
		if Uniques.is_unique(k) and not (campaign["uniques_taken"] as Array).has(k):
			campaign["uniques_taken"].append(k)


## Suite d'un contrat d'arc (voir Campaign.on_result) : renvoie les lignes de nouvelles ; applique renom et cadeau éventuels.
func _arc_result(c: Dictionary, win: bool) -> Array:
	if not c.has("arc"):
		return []
	var res: Dictionary = Campaign.on_result(campaign, world, c, win, campaign_rng)
	gain_renown(int(res["renown"]))
	if not (res["item"] as Dictionary).is_empty():
		add_to_stash([res["item"]])
		_note_uniques([res["item"]])
	return res["lines"]


## Victoire d'un assaut : une vague de plus, ou le lieu est pris (prime, renom, état du lieu, fin de campagne pour la citadelle).
func _assault_won(c: Dictionary) -> Array:
	if not Campaign.next_wave(c).is_empty():
		return ["Vague repoussée : une autre arrive aussitôt !"]
	var lines: Array = []
	_earn(int(c["pay"]))
	var rg: int = gain_renown(int(c.get("renown", 0)))
	lines.append("%s : +%d couronnes, +%d renom." % [str(c["title"]).split(" (vague")[0].replace("Assaut", "Lieu pris"), int(c["pay"]), rg])
	var s: Dictionary = world.site_by_id(str(c.get("site_id", "")))
	if not s.is_empty():
		lines.append_array(Campaign.site_conquered(campaign, s, day))
	return lines


## Fin de partie gagnée : l'écran de fin a été vu et on poursuit en mode libre (plus de menace, le monde continue).
func continue_free() -> void:
	campaign["ending_pending"] = false
	campaign["free_mode"] = true
	_after_change()


func ending_pending() -> bool:
	return bool(campaign.get("ending_pending", false))


## Chiffres de l'écran de fin.
func ending_stats() -> Dictionary:
	var kills: int = 0
	for m in roster:
		kills += m.kills
	for f in fallen:
		kills += int(f["kills"])
	return {
		"day": day, "dead": fallen.size(), "gold": gold, "renown": renown, "kills": kills, "men": roster.size(),
		"sites": int(campaign["sites_taken"]), "arcs": (Campaign.arc_summary(campaign) as Array).filter(func(a: Dictionary) -> bool: return a["phase"] == "done").size(),
		"threat": Campaign.threat_title(campaign), "log": campaign["log"],
	}


## Retour sur la carte après une bataille terminée : récompenses, morts, renom.
func finish_battle() -> void:
	if battle == null or battle.over == "":
		return
	var b: BattleState = battle
	var c: Dictionary = b.contract
	var win: bool = b.over == "win"
	var is_contract: bool = c.get("kind", "contract") == "contract"
	var is_ambush: bool = c.get("kind", "") == "ambush"  ## embuscade de route ou d'événement (sans bande errante)
	var is_assault: bool = c.get("kind", "") == "assault"  ## assaut d'un lieu hostile (éventuellement en plusieurs vagues)
	var next_wave: Dictionary = Campaign.next_wave(c) if is_assault and win else {}
	var by_id: Dictionary = {}
	for u in b.units:
		if u.side == "p":
			by_id[u.id] = u
	var dead_names: Array = []
	var survivors: Array[Unit] = []
	var men_report: Array = []
	var fought: Array = []  ## hommes ayant combattu et survécu (liens d'amitié)
	var gold_before: int = gold
	var renown_before: int = renown
	for m in roster:
		var bu: Unit = by_id.get(m.id)
		if bu == null:
			survivors.append(m)
			continue
		stat_add("kills", maxi(0, bu.kills - m.kills))
		if bu.dead:
			stat_add("men_fallen")
			men_report.append({"u": m.to_dict(), "dead": true, "hp_before": m.hp, "hp_after": 0, "xp": 0, "kills": bu.kills - m.kills, "lvl_before": m.level, "lvl_after": m.level, "wounds": []})
			dead_names.append(m.unit_name)
			fallen.append({"name": m.unit_name, "bg": m.background, "lvl": m.level, "kills": bu.kills, "day": day})
			continue
		var rep_hp_before: int = m.hp
		var rep_lvl_before: int = m.level
		var rep_kills_before: int = m.kills
		var rep_inj_before: int = m.injuries.size()
		m.hp = maxi(1, bu.hp)
		m.arm_h = bu.arm_h
		m.arm_b = bu.arm_b
		m.weapon = bu.weapon  ## changements d'arme en bataille (Inventory.bag_swap) conservés
		m.shield = bu.shield
		m.bag = bu.bag.duplicate(true)
		m.weapon_dur = bu.weapon_dur
		m.shield_dur = bu.shield_dur
		m.kills = bu.kills
		m.injuries = bu.injuries.duplicate(true)
		var scar: String = Injuries.roll_permanent(m, rng, difficulty)
		if scar != "":
			add_news(["%s garde une séquelle : %s." % [m.unit_name, str(Data.INJURIES[scar]["n"]).to_lower()]])
		var xp_gain: int = Difficulty.xp(difficulty, int(b.xp.get(m.id, 0)) + (15 * int(c["d"]) if win else 5))
		m.xp += xp_gain
		level_check(m)
		var rep_wounds: Array = []
		for wi in range(rep_inj_before, m.injuries.size()):
			rep_wounds.append(str(Data.INJURIES[str(m.injuries[wi]["id"])]["n"]))
		men_report.append({"u": m.to_dict(), "dead": false, "hp_before": rep_hp_before, "hp_after": m.hp, "xp": xp_gain,
			"kills": bu.kills - rep_kills_before, "lvl_before": rep_lvl_before, "lvl_after": m.level, "wounds": rep_wounds})
		survivors.append(m)
		fought.append(m)
	roster = survivors
	Bonds.battle_gain(fought, win)
	Bonds.prune(roster)
	morale_add((6.0 if win else (-6.0 if b.over == "retreat" else -10.0)) - minf(12.0, 3.0 * float(dead_names.size())))
	var lines: Array = []
	if win:
		stat_add("battles_won")
		if dead_names.is_empty():
			stat_add("perfect_wins")
	elif b.over == "retreat":
		stat_add("retreats")
	else:
		stat_add("battles_lost")
	if win:
		if is_contract:
			_earn(int(c["pay"]))
			var rg: int = gain_renown(40 * int(c["d"]))
			stat_add("contracts_done")
			if c.get("type_contract", "kill") == "hunt":
				stat_add("hunts_done")
			lines.append("Contrat rempli : +%d couronnes, +%d renom." % [c["pay"], rg])
			lines.append_array(_faction_result(c, "win"))
			world.change_standing(str(c.get("origin_id", "")), 3 if c.get("type_contract", "kill") == "hunt" else 2)
			lines.append_array(_arc_result(c, true))
			active_contract = {}
		elif is_assault:
			lines.append_array(_assault_won(c))
		elif is_ambush:
			lines.append("Embuscade repoussée : +%d renom." % gain_renown(15 * int(c["d"])))
		else:
			lines.append("Bande dispersée : +%d renom." % gain_renown(15 * int(c["d"])))
			var p: Dictionary = world.party_by_id(int(c["party_id"]))
			world.parties.erase(p)
	else:
		renown = maxi(0, renown - 15)
		lines.append("Retraite. " if b.over == "retreat" else "Défaite. ")
		var contract_lost: bool = is_contract or (is_ambush and bool(c.get("transport", false)))
		lines[0] += "Le contrat est perdu." if contract_lost else "Les survivants s'enfuient."
		if contract_lost:
			world.change_standing(str(c.get("origin_id", "")), -1)
			lines.append_array(_faction_result(c, "lost"))
			lines.append_array(_arc_result(c, false))
			active_contract = {}
		elif is_ambush or is_assault:
			pass
		else:
			var p: Dictionary = world.party_by_id(int(c["party_id"]))
			if not p.is_empty():
				p["cooldown"] = 2.0
	if not dead_names.is_empty():
		lines.append("Tombés : %s." % ", ".join(dead_names))
	var loot: Array = prepare_loot()
	if not loot.is_empty():
		add_to_stash(loot)
		_note_uniques(loot)
		lines.append("Butin récupéré : %d objet%s." % [loot.size(), "s" if loot.size() > 1 else ""])
	var obj_report: Array = []
	for o in b.objectives:  # objectifs secondaires : primes versées seulement en cas de victoire
		obj_report.append({"label": str(o["label"]), "done": bool(o["done"]) and win, "gold": int(o["bonus"]["gold"]), "renown": int(o["bonus"]["renown"])})
	if win and (is_contract or is_assault):  # embuscades et rencontres de route : pas de primes d'objectifs
		var ob: Dictionary = b.objective_bonus()
		if int(ob["gold"]) > 0:
			_earn(int(ob["gold"]))
		if int(ob["renown"]) > 0:
			gain_renown(int(ob["renown"]))
		if int(ob["gold"]) > 0 or int(ob["renown"]) > 0:
			lines.append("Objectifs remplis : +%d couronnes, +%d renom." % [int(ob["gold"]), int(ob["renown"])])
	last_battle_report = {"result": b.over, "title": str(c.get("title", "")), "day": day, "men": men_report, "loot": loot.duplicate(true),
		"gold": gold - gold_before, "renown": renown - renown_before, "lines": lines.duplicate(), "fallen": dead_names.duplicate(), "objectives": obj_report}
	pending_loot = []
	pending_loot_ready = false
	battle = null
	add_news(lines)
	if roster.is_empty():
		game_over = true
	check_achievements()
	save()
	battle_finished.emit()
	changed.emit()
	if not next_wave.is_empty() and not game_over:
		start_battle(next_wave)  # assaut en plusieurs vagues : la suivante enchaîne, sans soin entre-temps


func _after_change() -> void:
	check_achievements()
	save()
	changed.emit()


# --- Sauvegarde (user://savegame.json) ---

func to_dict() -> Dictionary:
	Bonds.prune(roster)  ## liens vers des hommes partis : oubliés
	var ros: Array = []
	for m in roster:
		ros.append(m.to_dict())
	return {
		"version": 2, "difficulty": difficulty, "gold": gold, "day": day, "day_fraction": day_fraction, "renown": renown, "roster": ros,
		"fallen": fallen, "news": news, "game_over": game_over, "next_id": Unit.next_id,
		"world": world.to_dict(), "location": location, "active_contract": active_contract,
		"battle": battle.to_dict() if battle else null,
		"pending_event": pending_event, "last_event_day": last_event_day, "last_event_id": last_event_id,
		"campaign": campaign.duplicate(true), "campaign_rng_state": str(campaign_rng.state),
		"inventory": inventory.duplicate(true), "pending_loot": pending_loot.duplicate(true), "pending_loot_ready": pending_loot_ready,
		"stats": stats.duplicate(), "banner": banner.duplicate(), "company_name": company_name,
		"last_battle_report": last_battle_report,
		"provisions": provisions, "company_morale": company_morale, "starve_days": starve_days, "buildings": buildings.duplicate(),
		"faction_standing": faction_standing.duplicate(), "story_flags": story_flags.duplicate(), "pending_events": pending_events.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	difficulty = Difficulty.clean(d.get("difficulty", "normal"))  ## anciennes sauvegardes : Normal
	gold = int(d["gold"])
	day = int(d["day"])
	day_fraction = float(d["day_fraction"])
	renown = int(d["renown"])
	roster.clear()
	for ud in d["roster"]:
		roster.append(Unit.from_dict(ud))
	fallen = []
	for f in d["fallen"]:
		fallen.append({"name": str(f["name"]), "bg": str(f["bg"]), "lvl": int(f["lvl"]), "kills": int(f["kills"]), "day": int(f["day"])})
	news = []
	for n in d["news"]:
		news.append(str(n))
	game_over = bool(d["game_over"])
	Unit.next_id = int(d["next_id"])
	world = World.from_dict(d["world"], rng)
	location = str(d["location"])
	active_contract = Contracts.normalize(d["active_contract"])
	battle = null
	if d["battle"] != null:
		battle = BattleState.from_dict(d["battle"], rng)
	pending_event = {}
	if typeof(d.get("pending_event", {})) == TYPE_DICTIONARY and not (d.get("pending_event", {}) as Dictionary).is_empty():
		var pe: Dictionary = d["pending_event"]
		if not Events.get_def(str(pe.get("id", ""))).is_empty():
			pending_event = {"id": str(pe["id"])}
	last_event_day = int(d.get("last_event_day", 0))
	last_event_id = str(d.get("last_event_id", ""))
	campaign = Campaign.normalize_state(d.get("campaign", {}))
	if d.has("campaign_rng_state"):
		campaign_rng.state = int(str(d["campaign_rng_state"]))
	if not (d["world"] as Dictionary).has("sites"):  # ancienne sauvegarde : on ajoute les lieux hostiles
		var site_rng := RandomNumberGenerator.new()
		site_rng.seed = day * 7919 + 13
		world.gen_sites(site_rng)
	inventory = _clean_items(d.get("inventory", []))
	pending_loot = _clean_items(d.get("pending_loot", []))
	pending_loot_ready = bool(d.get("pending_loot_ready", false))
	stats = Achievements.normalize_stats(d.get("stats", {}))
	banner = Banner.clean(d.get("banner", {}))
	company_name = Banner.clean_name(str(d.get("company_name", Data.COMPANY_NAME_DEFAULT)))
	# Vie de la compagnie : une ancienne sauvegarde reçoit vivres et moral par défaut, aucun bâtiment, aucune relation ni histoire
	provisions = clampi(int(d.get("provisions", Data.PROVISIONS_START)), 0, 100000)
	company_morale = clampf(float(d.get("company_morale", Data.MORALE_START)), 0.0, 100.0)
	starve_days = maxi(0, int(d.get("starve_days", 0)))
	buildings = CampBuildings.normalize(d.get("buildings", {}))
	faction_standing = Factions.normalize_standing(d.get("faction_standing", {}))
	story_flags = {}
	var sf: Variant = d.get("story_flags", {})
	if typeof(sf) == TYPE_DICTIONARY:
		for k in sf:
			story_flags[str(k)] = int(sf[k])
	pending_events = []
	var pes: Variant = d.get("pending_events", [])
	if typeof(pes) == TYPE_ARRAY:
		for pe in pes:
			if typeof(pe) == TYPE_DICTIONARY and not Events.get_def(str((pe as Dictionary).get("id", ""))).is_empty():
				pending_events.append({"id": str(pe["id"]), "due_day": int(pe.get("due_day", day))})
	_food_warned = false
	Factions.assign_owners(world)  ## propriétaires des lieux (anciennes sauvegardes)
	last_battle_report = {}
	var lbr: Variant = d.get("last_battle_report", {})
	if typeof(lbr) == TYPE_DICTIONARY and not (lbr as Dictionary).is_empty():
		last_battle_report = (lbr as Dictionary).duplicate(true)
		last_battle_report["loot"] = _clean_items(last_battle_report.get("loot", []))


func _clean_items(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for it in raw:
			if Loot.is_valid(it):
				out.append(Loot.clean(it))
	return out


func save() -> void:
	if not autosave:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(to_dict()))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_save() -> bool:
	return _load_path(SAVE_PATH)


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("world") or int(parsed.get("version", 0)) < 2:
		return {}  # illisible ou ancienne sauvegarde (sans carte)
	return parsed


func _load_path(path: String) -> bool:
	var parsed: Dictionary = _read_save(path)
	if parsed.is_empty():
		return false
	from_dict(parsed)
	changed.emit()
	location_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# --- Emplacements de sauvegarde : 0 = sauvegarde automatique (savegame.json), 1..SLOT_COUNT = manuels (save_N.json) ---

const SLOT_COUNT: int = 3


func slot_path(n: int) -> String:
	return SAVE_PATH if n == 0 else "user://save_%d.json" % n


func _valid_slot(n: int) -> bool:
	return n >= 0 and n <= SLOT_COUNT


## Écrit la partie dans un emplacement manuel (1..SLOT_COUNT). Écriture explicite : indépendante de `autosave`.
func save_to_slot(n: int) -> bool:
	if n < 1 or n > SLOT_COUNT or world == null:
		return false
	var d: Dictionary = to_dict()
	d["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open(slot_path(n), FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(d))
	return true


func load_slot(n: int) -> bool:
	if not _valid_slot(n) or not _load_path(slot_path(n)):
		return false
	save()  # la partie chargée devient l'autosave (sans effet si `autosave` est faux)
	return true


## Résumé d'un emplacement : {} s'il est vide ou illisible, sinon {day, gold, men, date}.
func slot_info(n: int) -> Dictionary:
	if not _valid_slot(n):
		return {}
	var d: Dictionary = _read_save(slot_path(n))
	if d.is_empty():
		return {}
	var date: String = str(d.get("saved_at", ""))
	if date == "" and n == 0:
		date = Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(slot_path(0)), true)
	return {"day": int(d.get("day", 1)), "gold": int(d.get("gold", 0)), "men": (d.get("roster", []) as Array).size(), "difficulty": Difficulty.clean(d.get("difficulty", "normal")), "date": date.replace("T", " ")}


func delete_slot(n: int) -> void:
	if not _valid_slot(n):
		return
	if FileAccess.file_exists(slot_path(n)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(n)))
