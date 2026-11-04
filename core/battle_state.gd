class_name BattleState
extends RefCounted
## État d'une bataille : plateau, unités, file d'initiative, manches, victoire. Aucune dépendance de scène.

signal logged(text: String, css: String)

const DEPLOY_ROWS: Array[int] = [4, 3, 5, 2, 6, 1, 7, 0, 8]

var rng: RandomNumberGenerator
var width: int = Data.BOARD_W
var height: int = Data.BOARD_H
var cells: Dictionary = {}  ## Vector2i -> {"t": "g"|"tree"|"rock", "c": colonne, "v": variante 0-2}
var units: Array[Unit] = []
var queue: Array[Unit] = []
var round_no: int = 0
var current: Unit = null
var log_lines: Array[Dictionary] = []
var xp: Dictionary = {}  ## id d'unité -> XP gagnée
var corpses: Array[Vector2i] = []
var over: String = ""  ## "", "win", "lose", "retreat"
var contract: Dictionary = {}
var biome: String = "plain"
var undo: Dictionary = {}  ## dernier déplacement annulable : {"id", "hex", "ap", "fat"} (vide si rien à annuler)
var log_group: int = 0  ## numéro du groupe de lignes de journal (une action = un groupe)
var wear_mult: float = 1.0  ## part de l'usure subie par le matériel du joueur (forge du camp : < 1)
var battle_type: String = "pitched"  ## "pitched" | "ambush" | "convoy" | "siege" | "night" (contract["battle_type"])
var night: bool = false  ## bataille de nuit : vision limitée à `sight_radius` cases, torches et feux éclairent
var sight_radius: int = 0  ## rayon de vision de chaque camp (0 = pas de limite)
var rain: bool = false  ## pluie : les feux faiblissent vite et ne se propagent pas
var objectives: Array = []  ## objectifs secondaires : {id, kind, target, done, failed, bonus: {gold, renown}, label}
var reserve: Array = []  ## clés de Data.FOE des ennemis qui surgiront d'un flanc (embuscade)
var hold_rounds: int = 0  ## convoi : manches à tenir pour sauver les chariots
var start_party: int = 0  ## effectif de la compagnie au début (objectifs)
var raised: int = 0  ## morts relevés par les nécromants
const LOG_MAX: int = 200
const LIT_SIGHT: int = 8  ## de nuit, une unité éclairée est visible de si loin
const RAISE_MAX: int = 3
const AMBUSH_RESERVE_MAX: int = 3


## Crée une bataille : copie de la compagnie (les 8 premiers), ennemis du contrat, terrain, déploiement.
## `start_morale` : moral de départ des hommes du joueur (2 Hésitant, 3 Stable, 4 Confiant ; voir Game.battle_start_morale), `p_wear_mult` : forge du camp.
static func create(p_contract: Dictionary, roster: Array, p_rng: RandomNumberGenerator, start_morale: int = 3, p_wear_mult: float = 1.0) -> BattleState:
	var s := BattleState.new()
	s.rng = p_rng
	s.wear_mult = p_wear_mult
	s.contract = p_contract
	var bt: String = str(p_contract.get("battle_type", "pitched"))
	s.battle_type = bt if Data.BATTLE_TYPES.has(bt) else "pitched"
	s.night = s.battle_type == "night"
	s.sight_radius = Data.NIGHT_SIGHT if s.night else 0
	s.rain = bool(p_contract.get("rain", false))
	s._build_terrain()
	var party: Array[Unit] = []
	for i in mini(roster.size(), Data.FIGHTERS):
		var u: Unit = (roster[i] as Unit).duplicate_unit()
		u.reset_for_battle()
		u.morale = clampi(start_morale, 1, 4)
		party.append(u)
	var foes: Array[Unit] = []
	for k in p_contract["foes"]:
		var f: Unit = Contracts.make_foe(str(k), p_rng)
		f.reset_for_battle()
		foes.append(f)
	s.start_party = party.size()
	s._layout(party, foes)
	s.units.append_array(party)
	s.units.append_array(foes)
	s._make_objectives()
	s.say(str(p_contract["title"]), "sys")
	if s.battle_type != "pitched":
		s.say("%s." % Data.BATTLE_TYPE_NAMES[s.battle_type], "sys")
	s.new_round()
	return s


# --- Mise en place selon le type de bataille ---

## Déploiement et décor. Un aléa à part (dérivé de l'état du générateur, sans le consommer) évite de changer les batailles rangées existantes.
func _layout(party: Array[Unit], foes: Array[Unit]) -> void:
	var drng := RandomNumberGenerator.new()
	drng.seed = int(rng.state) ^ 0x7A11
	match battle_type:
		"ambush":
			_layout_ambush(party, foes, drng)
		"convoy":
			_layout_convoy(party, foes, drng)
		"siege":
			_layout_siege(party, foes)
		_:
			_deploy(party, 1, 0)
			_deploy(foes, width - 2, width - 1)
	if night:
		TerrainGen.add_torches(cells, width, height, drng)
	if bool(contract.get("traps", false)):
		TerrainGen.add_traps(cells, width, height, drng, "e")


func _free_cell(h: Vector2i, used: Dictionary) -> bool:
	return cells.has(h) and not used.has(h) and not Pathfinding.blocked(cells, h)


## Embuscade : la compagnie est dispersée ; l'ennemi surgit à portée ; quelques ennemis attendent sur un flanc.
func _layout_ambush(party: Array[Unit], foes: Array[Unit], drng: RandomNumberGenerator) -> void:
	var held: int = mini(AMBUSH_RESERVE_MAX, maxi(1, foes.size() / 4)) if foes.size() >= 4 else 0
	for i in held:
		var f: Unit = foes.pop_back()
		reserve.append(f.foe_key)
	var used: Dictionary = {}
	var pool: Array[Vector2i] = []
	for c in range(1, 7):
		for r in height:
			pool.append(Hex.from_col_row(c, r))
	_shuffle(pool, drng)
	var placed: Array[Vector2i] = []
	for u in party:
		var spot: Variant = null
		for h in pool:  # de préférence loin des autres (dispersion)
			if _free_cell(h, used):
				var ok: bool = true
				for q in placed:
					if Hex.distance(q, h) < 2:
						ok = false
						break
				if ok:
					spot = h
					break
		if spot == null:
			for h in pool:
				if _free_cell(h, used):
					spot = h
					break
		if spot == null:
			spot = Hex.from_col_row(0, placed.size() % height)
		u.hex = spot
		used[spot] = true
		placed.append(spot)
	var fpool: Array[Vector2i] = []
	for c in range(4, width):
		for r in height:
			fpool.append(Hex.from_col_row(c, r))
	_shuffle(fpool, drng)
	for f in foes:
		var best: Variant = null
		var want_lo: int = 4 if f.is_ranged() else 2
		var want_hi: int = 6 if f.is_ranged() else 4
		for h in fpool:
			if not _free_cell(h, used):
				continue
			var md: int = 99
			for q in placed:
				md = mini(md, Hex.distance(q, h))
			if md >= want_lo and md <= want_hi:
				best = h
				break
		if best == null:
			for h in fpool:
				if _free_cell(h, used):
					best = h
					break
		if best == null:
			best = Hex.from_col_row(width - 1, used.size() % height)
		f.hex = best
		used[best] = true
	for u in party + foes:
		cells[u.hex]["t"] = "g" if Pathfinding.blocked(cells, u.hex) else cells[u.hex]["t"]


func _shuffle(arr: Array[Vector2i], drng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = drng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Convoi : 2 à 3 chariots immobiles derrière la compagnie ; il faut les garder en vie.
func _layout_convoy(party: Array[Unit], foes: Array[Unit], drng: RandomNumberGenerator) -> void:
	_deploy(party, 4, 3)
	_deploy(foes, width - 2, width - 1)
	var n: int = 2 + drng.randi_range(0, 1)
	var rows: Array[int] = []
	rows.assign([3, 5] if n == 2 else [2, 4, 6])
	for i in n:
		var cart: Unit = make_cart(i + 1)
		cart.hex = Hex.from_col_row(2, rows[i])
		cells[cart.hex]["t"] = "g"
		units.append(cart)
	hold_rounds = Data.CONVOY_ROUNDS


static func make_cart(n: int) -> Unit:
	var c := Unit.new()
	c.id = Unit.alloc_id()
	c.unit_name = "%s %d" % [Data.CART["n"], n]
	c.background = str(Data.CART["n"])
	c.side = "p"
	c.faction = "c"
	c.sprite = "cart"
	c.immobile = true
	c.hp_max = int(Data.CART["hp"])
	c.hp = c.hp_max
	c.fat_max = 100
	c.resolve = 95
	c.initiative = 10
	c.melee_skill = 0
	c.ranged_skill = 0
	c.melee_def = 0
	c.ranged_def = 0
	c.weapon = "poings"
	c.head = "none"
	c.body = "none"
	c.xp_value = 0
	return c


## Siège : un rempart avec une porte destructible, des archers sur le chemin de ronde (huile bouillante), les défenseurs derrière.
func _layout_siege(party: Array[Unit], foes: Array[Unit]) -> void:
	_deploy(party, 1, 0)
	_deploy(foes, 8, 9)
	TerrainGen.add_fort(cells, width, height)
	var tops: Array[Vector2i] = TerrainGen.fort_tops(width, height)
	var cands: Array[Unit] = []
	for f in foes:
		if f.is_ranged() and not f.leader:
			cands.append(f)
	for f in foes:
		if not f.is_ranged() and not f.leader and cands.size() < tops.size():
			cands.append(f)
	for i in mini(tops.size(), cands.size()):
		var f: Unit = cands[i]
		f.hex = tops[i]
		f.bag[0] = Loot.item("tool", "huile")
	for f in foes:
		if cells[f.hex].has("obj") and not bool(cells[f.hex]["obj"].get("top", false)):
			cells[f.hex].erase("obj")


func _build_terrain() -> void:
	biome = str(contract.get("biome", ""))
	if not Data.BIOMES.has(biome):
		biome = TerrainGen.pick_biome(rng)
	cells = TerrainGen.generate(width, height, biome, rng)


func _deploy(list: Array[Unit], col_melee: int, col_ranged: int) -> void:
	var mel: Array[Unit] = []
	var rng_u: Array[Unit] = []
	for u in list:
		(rng_u if u.is_ranged() else mel).append(u)
	var rows_rev: Array[int] = DEPLOY_ROWS.duplicate()
	rows_rev.reverse()
	var slots_m: Array[Vector2i] = []
	var slots_r: Array[Vector2i] = []
	for r in DEPLOY_ROWS:
		slots_m.append(Vector2i(col_melee, r))
		slots_r.append(Vector2i(col_ranged, r))
	for r in rows_rev:
		slots_m.append(Vector2i(col_ranged, r))
		slots_r.append(Vector2i(col_melee, r))
	var used: Dictionary = {}
	for u in mel:
		_place(u, slots_m, used)
	for u in rng_u:
		_place(u, slots_r, used)


func _place(u: Unit, slots: Array[Vector2i], used: Dictionary) -> void:
	for slot in slots:
		if used.has(slot):
			continue
		used[slot] = true
		u.hex = Hex.from_col_row(slot.x, slot.y)
		cells[u.hex]["t"] = "g"
		return


# --- Accès ---

func say(text: String, css: String = "") -> void:
	log_lines.push_front({"t": text, "c": css, "g": log_group})
	if log_lines.size() > LOG_MAX:
		log_lines.resize(LOG_MAX)
	logged.emit(text, css)


## Les prochaines lignes du journal forment un nouveau groupe (une même action).
func new_log_group() -> void:
	log_group += 1


func unit_by_id(id: int) -> Unit:
	for u in units:
		if u.id == id:
			return u
	return null


func unit_at(h: Vector2i) -> Unit:
	for u in units:
		if u.is_live() and u.hex == h:
			return u
	return null


func foes_of(u: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for x in units:
		if x.is_live() and x.side != u.side:
			out.append(x)
	return out


func allies_of(u: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for x in units:
		if x.is_live() and x.side == u.side and x != u:
			out.append(x)
	return out


func hit_chance(a: Unit, d: Unit, ability: String = "") -> int:
	var bonus: int = int(Data.ABILITIES[ability].get("hit", 0)) if ability != "" else 0
	if ability != "" and Data.ABILITIES[ability].has("tool"):
		var dist: int = Hex.distance(a.hex, d.hex)
		var ter: int = int(CombatRules.terrain_at(cells, d.hex)["def"])
		if bool(Data.ABILITIES[ability].get("splash", false)):
			return 95
		return clampi(a.eff("ranged_skill") + bonus - (d.eff("ranged_def") + ter + int(Data.MDEF[d.morale])) - 3 * maxi(0, dist - 2) + int(Data.MSK[a.morale]), 5, 95)
	var ch: int = CombatRules.hit_chance(a, d, units, cells, bonus)
	if night and a.is_ranged():
		ch = clampi(ch - Data.NIGHT_FAR_PENALTY * maxi(0, Hex.distance(a.hex, d.hex) - 3), 5, 95)
	return ch


## Ligne de tir coupée par un obstacle (n'a de sens que pour une arme à distance).
func line_blocked(a: Unit, d: Unit) -> bool:
	return a.is_ranged() and CombatRules.line_blocked(a.hex, d.hex, cells)


## `target` est-il visible du camp `side` ? (de nuit : à `sight_radius` cases d'un allié, ou éclairé et à moins de LIT_SIGHT)
func can_see(side: String, target: Unit) -> bool:
	if sight_radius <= 0 or target.side == side:
		return true
	var lit: bool = -1 == 0
	var lit_checked: bool = false
	for x in units:
		if not x.is_live() or x.side != side:
			continue
		var dist: int = Hex.distance(x.hex, target.hex)
		if dist <= sight_radius:
			return true
		if dist <= LIT_SIGHT:
			if not lit_checked:
				lit = Scenery.lit(cells, target.hex)
				lit_checked = true
			if lit:
				return true
	return false


func is_visible_to_player(u: Unit) -> bool:
	return can_see("p", u)


## Portée, PA, fatigue, visibilité et (à distance) ligne de tir dégagée.
func can_attack(a: Unit, d: Unit) -> bool:
	return CombatRules.can_attack(a, d) and not line_blocked(a, d) and can_see(a.side, d)


func reachable(u: Unit, avoid: bool = false) -> Dictionary:
	return Pathfinding.reachable(u, cells, units, avoid)


func edge_column(u: Unit) -> int:
	return 0 if u.side == "p" else width - 1


# --- Déroulement ---

func new_round() -> void:
	round_no += 1
	if round_no > 1:
		say("Manche %d" % round_no, "sys")
		Scenery.tick_round(self)
		for u in units:
			var rg: int = int(u.foe_data().get("regen", 0))
			if rg > 0 and u.is_live() and u.hp < u.hp_max:
				u.hp = mini(u.hp_max, u.hp + rg)
				say("%s se régénère." % u.unit_name, "miss")
		if round_no == Data.AMBUSH_RESERVE_ROUND and not reserve.is_empty():
			_spawn_reserve()
		_update_hold()
	var live: Array[Unit] = []
	for u in units:
		if u.is_live() and not u.immobile:
			live.append(u)
	var ambush_first: bool = battle_type == "ambush" and round_no == 1
	live.sort_custom(func(a: Unit, b: Unit) -> bool:
		if ambush_first and (a.side == "e") != (b.side == "e"):
			return a.side == "e"
		if a.ini_eff() != b.ini_eff():
			return a.ini_eff() > b.ini_eff()
		return a.id < b.id)
	queue = live
	for u in units:
		u.waited = false


## Embuscade : les ennemis tenus en réserve surgissent d'un flanc (haut ou bas du plateau).
func _spawn_reserve() -> void:
	var row: int = 0 if rng.randi_range(0, 1) == 0 else height - 1
	var col: int = width - 4
	for k in reserve:
		var f: Unit = Contracts.make_foe(str(k), rng)
		f.reset_for_battle()
		var placed: bool = false
		for dc in range(0, 6):
			for r in [row, height - 1 - row]:
				var h: Vector2i = Hex.from_col_row(maxi(1, col - dc), r)
				if not placed and cells.has(h) and not Pathfinding.blocked(cells, h) and unit_at(h) == null:
					f.hex = h
					placed = true
		if not placed:
			continue
		units.append(f)
		say("%s surgit d'un flanc !" % f.unit_name, "sys")
	reserve = []


## Objectif « tenir N manches » et victoire du convoi.
func _update_hold() -> void:
	for o in objectives:
		if str(o["kind"]) == "hold" and not bool(o["done"]) and not bool(o["failed"]) and round_no > int(o["target"]):
			o["done"] = true
	if battle_type == "convoy" and hold_rounds > 0 and round_no > hold_rounds and over == "":
		var carts: int = 0
		for u in units:
			if u.is_cart() and u.is_live():
				carts += 1
		if carts > 0:
			end_battle("win")


func begin_turn(u: Unit) -> void:
	if u.turn_round == round_no:
		return
	u.turn_round = round_no
	undo = {}
	new_log_group()
	u.ap = Data.AP_PER_TURN
	u.fat = maxi(0, u.fat - 15 - (5 if u.has_perk("second_souffle") else 0))
	u.shield_wall = false
	u.attacked_turn = false
	u.exposed = false
	u.moved_cells = 0
	if u.rooted == 1:
		u.rooted = 2
		say("%s est immobilisé." % u.unit_name, "miss")
	elif u.rooted >= 2:
		u.rooted = 0
	Scenery.start_of_turn(self, u)
	if not u.is_live():
		return
	if u.stunned:
		u.stunned = false
		u.ap = maxi(0, u.ap - Data.STUN_AP)
		say("%s est étourdi et perd des forces." % u.unit_name, "mor")


## Passe à l'unité suivante (nouvelle manche si besoin). Renvoie null si la bataille est finie.
## Une unité en fuite tente de se ressaisir avant d'agir.
func next_turn() -> Unit:
	while true:
		if check_end():
			current = null
			return null
		if queue.is_empty():
			new_round()
			if check_end():
				current = null
				return null
		var u: Unit = queue.pop_front()
		if u == null or not u.is_live():
			continue
		current = u
		begin_turn(u)
		if not u.is_live():
			current = null
			continue
		if u.morale == 0:
			var adj: int = 0
			for f in foes_of(u):
				if Hex.distance(f.hex, u.hex) == 1:
					adj += 1
			if rng.randi_range(1, 100) <= clampi(u.eff("resolve") - 10 * adj, 5, 90):
				u.morale = 1
				say("%s se ressaisit." % u.unit_name, "mor")
		return u
	return null


func check_end() -> bool:
	if over != "":
		return true
	var enemies: int = 0
	var friends: int = 0
	var carts: int = 0
	var cart_total: int = 0
	var leader_alive: bool = false
	var leader_any: bool = false
	var pdead: int = 0
	for u in units:
		if u.is_cart():
			cart_total += 1
			if u.is_live():
				carts += 1
		if u.side == "p" and u.dead and not u.immobile:
			pdead += 1
		if u.side == "e" and u.leader:
			leader_any = true
			if u.is_live():
				leader_alive = true
		if u.is_fighting() and not u.immobile:
			if u.side == "e":
				enemies += 1
			else:
				friends += 1
	for o in objectives:
		if str(o["kind"]) == "hold" and not bool(o["done"]) and pdead * 2 > start_party:
			o["failed"] = true
	if enemies == 0:
		end_battle("win")
		return true
	if friends == 0 or (cart_total > 0 and carts == 0):
		end_battle("lose")
		return true
	if battle_type == "siege" and leader_any and not leader_alive:
		end_battle("win")
		return true
	return false


## Évalue les objectifs secondaires à la fin (les primes ne sont versées qu'en cas de victoire).
func _evaluate_objectives(result: String) -> void:
	var lost: int = 0
	var carts: int = 0
	for u in units:
		if u.side == "p" and u.dead and not u.immobile:
			lost += 1
		if u.is_cart() and u.is_live():
			carts += 1
	for o in objectives:
		if result != "win":
			continue
		match str(o["kind"]):
			"no_loss":
				o["done"] = lost == 0
			"fast":
				o["done"] = round_no <= int(o["target"])
			"protect":
				o["done"] = carts >= int(o["target"])
			"hold":
				if not bool(o["failed"]):
					o["done"] = round_no >= int(o["target"]) or bool(o["done"])


func _make_objectives() -> void:
	objectives = []
	var d: int = int(contract.get("d", 1))
	var leader_id: int = -1
	var carts: int = 0
	for u in units:
		if u.side == "e" and u.leader and leader_id < 0:
			leader_id = u.id
		if u.is_cart():
			carts += 1
	if leader_id >= 0 and battle_type != "convoy":
		_add_obj("kill_leader", leader_id, "Tuer le chef", 40 * d, 5 * d)
	match battle_type:
		"ambush":
			_add_obj("hold", 3, "Tenir 3 manches sans perdre la moitié de la compagnie", 0, 10 * d)
			_add_obj("no_loss", 0, "Aucun mort", 20 * d, 5 * d)
		"convoy":
			_add_obj("protect", carts, "Sauver tous les chariots", 60 * d, 10 * d)
		"siege":
			_add_obj("fast", 10, "Finir en 10 manches", 50 * d, 5 * d)
		"night":
			_add_obj("no_loss", 0, "Aucun mort", 30 * d, 5 * d)
		_:
			_add_obj("no_loss", 0, "Aucun mort", 20 * d, 8 * d)
			_add_obj("fast", 6, "Finir en 6 manches", 30 * d, 0)


func _add_obj(kind: String, target: int, label: String, gold: int, renown: int) -> void:
	objectives.append({"id": "%s_%d" % [kind, objectives.size()], "kind": kind, "target": target, "done": false, "failed": false,
		"bonus": {"gold": gold, "renown": renown}, "label": label})


## Total des primes des objectifs remplis : {"gold", "renown"}.
func objective_bonus() -> Dictionary:
	var g: int = 0
	var r: int = 0
	for o in objectives:
		if bool(o["done"]):
			g += int(o["bonus"]["gold"])
			r += int(o["bonus"]["renown"])
	return {"gold": g, "renown": r}


func end_battle(result: String) -> void:
	over = result
	current = null
	_evaluate_objectives(result)
	if result == "win":
		for u in units:
			if u.side == "e" and u.is_live():
				u.escaped = true
		say("Victoire. Le champ est à vous.", "sys")
	elif result == "retreat":
		say("La compagnie bat en retraite.", "sys")
	else:
		say("Défaite. Les survivants se dispersent.", "sys")


## L'unité peut-elle encore faire quelque chose d'utile ce tour ?
func can_act(u: Unit) -> bool:
	if not u.is_live() or u.morale == 0:
		return false
	if not reachable(u).is_empty():
		return true
	for f in foes_of(u):
		if can_attack(u, f):
			return true
	return u.shield_ok() and not u.shield_wall and u.ap >= 4 or not CombatRules.abilities_of(u).is_empty() and _ability_target(u) != null or _object_work(u)


## Une porte à ouvrir ou un obstacle à frapper à portée ?
func _object_work(u: Unit) -> bool:
	if not Scenery.openable_near(self, u).is_empty() and u.ap >= int(Data.SCENERY["door"]["open_ap"]):
		return true
	for h in Scenery.breach_targets(self, u):
		if Scenery.can_hit_object(self, u, h):
			return true
	return false


func _ability_target(u: Unit) -> Unit:
	for f in foes_of(u):
		for id in CombatRules.abilities_of(u):
			if can_use_ability(u, f, id):
				return f
	return null


# --- Capacités ---

## Portée, PA, fatigue, bouclier requis et (à distance) ligne de tir dégagée.
func can_use_ability(a: Unit, d: Unit, id: String) -> bool:
	if not CombatRules.can_use_ability(a, d, id) or not can_see(a.side, d):
		return false
	if Data.ABILITIES[id].has("tool"):
		return not CombatRules.line_blocked(a.hex, d.hex, cells)
	return not line_blocked(a, d)


## Utilise une capacité de l'arme sur `d` (mêmes événements que `attack`, plus `ability`, `pushed`, `stunned`, `exposed`, `shield_broken`).
func use_ability(a: Unit, id: String, d: Unit) -> Dictionary:
	return attack(a, d, false, id)


## Repousse `d` d'une case à l'opposé de `a` si la case est libre et praticable. Renvoie la nouvelle case ou (-999, -999).
func push_target(a: Unit, d: Unit) -> Vector2i:
	var dist: int = Hex.distance(a.hex, d.hex)
	for n in Hex.neighbors(d.hex):
		if Hex.distance(a.hex, n) != dist + 1 or not cells.has(n) or unit_at(n) != null:
			continue
		if Pathfinding.blocked(cells, n):
			continue
		d.hex = n
		return n
	return Vector2i(-999, -999)


# --- Actions ---

## Lancer d'un outil du sac (pierre, huile, filet) sur `d`. Mêmes clés de résultat que `attack`.
func _throw(a: Unit, d: Unit, id: String) -> Dictionary:
	var ab: Dictionary = Data.ABILITIES[id]
	new_log_group()
	undo = {}
	a.ap -= int(ab["ap"])
	a.fat += int(ab["fat"])
	a.attacked_turn = true
	var tk: String = str(ab["tool"])
	a.tool_used[tk] = int(a.tool_used.get(tk, 0)) + 1
	var ch: int = hit_chance(a, d, id)
	var hit: bool = rng.randi_range(1, 100) <= ch
	var res: Dictionary = {"attacker": a, "target": d, "hit": hit, "chance": ch, "free": false, "head": false, "hp": 0, "armor": 0, "killed": false, "ability": id}
	if not hit:
		say("%s manque %s — %s." % [a.unit_name, d.unit_name, str(ab["n"]).to_lower()], "miss")
		return res
	var hit_list: Array[Unit] = [d]
	if bool(ab.get("splash", false)):
		hit_list = []
		for x in units:
			if x.is_live() and Hex.distance(x.hex, d.hex) <= 1:
				hit_list.append(x)
	for x in hit_list:
		if ab.has("dmg_range"):
			var dm: int = rng.randi_range(int(ab["dmg_range"][0]), int(ab["dmg_range"][1]))
			x.hp -= dm
			x.hit_taken = true
			if x == d:
				res["hp"] = dm
			say("%s est touché (%s) : %d PV." % [x.unit_name, str(ab["n"]).to_lower(), dm], "hit")
		if x.hp <= 0:
			if x == d:
				res["killed"] = true
			_kill(x, a)
			continue
		if bool(ab.get("stun", false)) and x == d:
			x.stunned = true
			res["stunned"] = true
			say("%s est étourdi." % x.unit_name, "mor")
		if bool(ab.get("net", false)) and x == d:
			if x.is_big():
				say("%s se dégage du filet sans effort." % x.unit_name, "miss")
			else:
				x.rooted = 1
				res["rooted"] = true
				say("%s est pris dans le filet." % x.unit_name, "mor")
		if bool(ab.get("splash", false)):
			_morale_down(x, -10, "est ébouillanté")
	if bool(ab.get("fire", false)):
		for h in [d.hex] + Hex.neighbors(d.hex):
			Scenery.ignite(self, h)
	return res


func attack(a: Unit, d: Unit, free: bool = false, ability: String = "") -> Dictionary:
	if ability != "" and Data.ABILITIES[ability].has("tool"):
		return _throw(a, d, ability)
	var w: Dictionary = a.weapon_data()
	var ab: Dictionary = Data.ABILITIES[ability] if ability != "" else {}
	new_log_group()
	if not free or (not undo.is_empty() and int(undo["id"]) == d.id):
		undo = {}  # une attaque (aléatoire) ou une attaque d'opportunité sur le marcheur ferme l'annulation
	if not free:
		a.ap -= CombatRules.ability_ap(a, ability) if ability != "" else a.attack_ap()
		a.fat += CombatRules.ability_fat(a, ability) if ability != "" else a.attack_fat()
		a.attacked_turn = true
		if a.uses_ammo() and a.ammo > 0:
			a.ammo -= 1
	var ch: int = hit_chance(a, d, ability)
	var hit: bool = rng.randi_range(1, 100) <= ch
	var res: Dictionary = {"attacker": a, "target": d, "hit": hit, "chance": ch, "free": free, "head": false, "hp": 0, "armor": 0, "killed": false, "ability": ability}
	var tag: String = " (attaque d'opportunité)" if free else (" — %s" % ab["n"] if ability != "" else "")
	_wear_on_block(a, d, hit)
	if not hit:
		say("%s manque %s%s — %d %%" % [a.unit_name, d.unit_name, tag, ch], "miss")
		return res
	var dmg: Dictionary = CombatRules.roll_damage(a, d, rng, ab)
	CombatRules.apply_damage(d, dmg)
	d.hit_taken = true
	if d.hp <= 0 and Traits.lucky_save(d, rng):  # trait Chanceux : échappe à un coup mortel, une fois par bataille
		d.hp = 1
		say("%s échappe à la mort de justesse !" % d.unit_name, "mor")
		res["lucky"] = true
	if int(dmg["armor"]) > 0 and a.wear_weapon(_wear_n(a, 2 if int(dmg["zone_armor"]) >= Data.HEAVY_ARMOR_WEAR else 1)):
		say("L'arme de %s est ébréchée." % a.unit_name, "death")
		res["weapon_broke"] = true
	res["head"] = dmg["head"]
	res["hp"] = dmg["hp"]
	res["armor"] = dmg["armor"]
	say("%s touche %s%s%s : %d PV, %d armure — %d %%" % [a.unit_name, d.unit_name, " à la tête" if dmg["head"] else "", tag, dmg["hp"], dmg["armor"], ch], "hit")
	if d.hp > 0 and ability != "":
		_apply_ability_effects(a, d, ab, res)
	if d.hp > 0 and int(a.foe_data().get("stun_hit", 0)) > 0 and not d.is_big() and rng.randi_range(1, 100) <= int(a.foe_data()["stun_hit"]):
		d.stunned = true
		res["stunned"] = true
		say("%s est étourdi." % d.unit_name, "mor")
	if d.hp <= 0:
		res["killed"] = true
		_kill(d, a)
	else:
		if int(dmg["hp"]) >= 12:
			_morale_down(d, -15 if d.hp < d.hp_max * 0.4 else 10, "flanche sous le coup")
		if a.has_perk("intimidant") and int(dmg["hp"]) > 0 and d.hp < d.hp_max * 0.6:
			_morale_down(d, -10, "est intimidé par %s" % a.unit_name)
		var wound: String = Injuries.roll_wound(d, int(dmg["hp"]), rng)
		if wound != "":
			res["wound"] = wound
			say("%s est blessé : %s." % [d.unit_name, Data.INJURIES[wound]["n"]], "death")
	return res


## Le bouclier de la cible encaisse le coup (touché ou paré) ; le mur de boucliers l'use deux fois plus.
func _wear_on_block(a: Unit, d: Unit, hit: bool) -> void:
	if not d.shield_ok():
		return
	var n: int = (1 if hit else 2) * (2 if d.shield_wall else 1)
	if d.wear_shield(_wear_n(d, n)):
		say("Le bouclier de %s se brise !" % d.unit_name, "death")


## Points d'usure réellement subis par `u` : la forge du camp en épargne une part au matériel du joueur (aléa utilisé seulement avec une forge).
func _wear_n(u: Unit, n: int) -> int:
	if wear_mult >= 1.0 or u.side != "p":
		return n
	var kept: int = 0
	for i in n:
		if rng.randf() < wear_mult:
			kept += 1
	return kept


func _apply_ability_effects(a: Unit, d: Unit, ab: Dictionary, res: Dictionary) -> void:
	if bool(ab.get("fire", false)) and Scenery.ignite(self, d.hex):
		res["fire"] = true
	if ab.has("morale"):
		_morale_down(d, int(ab["morale"]), "est assommé")
	if bool(ab.get("push", false)):
		var from: Vector2i = d.hex
		var to: Vector2i = push_target(a, d)
		if to != Vector2i(-999, -999):
			res["pushed"] = [from, to]
			say("%s est repoussé." % d.unit_name, "miss")
	if bool(ab.get("stun", false)):
		d.stunned = true
		res["stunned"] = true
		say("%s est étourdi." % d.unit_name, "mor")
	if bool(ab.get("expose", false)):
		d.exposed = true
		res["exposed"] = true
		say("%s est désarçonné." % d.unit_name, "mor")
	if ab.has("shield_break") and d.shield_ok():
		res["shield_broken"] = d.wear_shield(int(ab["shield_break"]))
		say("Le bouclier de %s est %s." % [d.unit_name, "fracassé" if res["shield_broken"] else "meurtri"], "death" if res["shield_broken"] else "miss")


## Mort due au décor (feu, piège) : sans tueur.
func kill_env(d: Unit, cause: String) -> void:
	d.hp = 0
	d.dead = true
	d.shield_wall = false
	corpses.append(d.hex)
	say("%s succombe à %s." % [d.unit_name, cause], "death")


func morale_test(u: Unit, modifier: int, why: String) -> void:
	_morale_down(u, modifier, why)


## Aura d'un chef allié vivant à 4 cases ou moins (pas sur lui-même).
func leader_aura(u: Unit) -> int:
	for x in units:
		if x != u and x.is_live() and x.leader and x.side == u.side and x.morale > 0 and Hex.distance(x.hex, u.hex) <= 4:
			return Data.LEADER_AURA
	return 0


func _morale_down(u: Unit, modifier: int, why: String) -> void:
	if u.immobile:
		return
	if CombatRules.morale_test_fails(u, modifier + Perks.morale_aura(u, units) + Traits.aura(u, units) + Bonds.morale_mod(u, units) + leader_aura(u), rng):
		say("%s %s : %s." % [u.unit_name, why, str(Data.MORALE_NAMES[u.morale]).to_lower()], "mor")


func _kill(d: Unit, a: Unit, cause: String = "") -> void:
	d.hp = 0
	d.dead = true
	d.shield_wall = false
	corpses.append(d.hex)
	if d.immobile:
		say("%s est détruit." % d.unit_name, "death")
		return
	if a == null:
		say("%s succombe à %s." % [d.unit_name, cause if cause != "" else "ses blessures"], "death")
	else:
		say("%s tombe sous les coups de %s." % [d.unit_name, a.unit_name], "death")
		a.kills += 1
		if a.side == "p":
			xp[a.id] = int(xp.get(a.id, 0)) + (d.xp_value if d.xp_value > 0 else 15)
	if d.side == "e" and d.leader:
		for o in objectives:
			if str(o["kind"]) == "kill_leader" and int(o["target"]) == d.id:
				o["done"] = true
	for x in units:
		if not x.is_live():
			continue
		var dist: int = Hex.distance(x.hex, d.hex)
		if x.side == d.side and dist <= 4:
			_morale_down(x, (-15 if d.leader else 0) + Traits.ally_fall_mod(x) + Bonds.fall_mod(x, d), "voit son chef tomber" if d.leader else "voit tomber " + d.unit_name.split(" ")[0])
		elif x.side != d.side and dist <= 4:
			if CombatRules.morale_rally_up(x, rng):
				say("%s est galvanisé." % x.unit_name, "mor")
	if d.leader:
		for x in units:
			if x.is_live() and x.side == d.side and Hex.distance(x.hex, d.hex) > 4:
				_morale_down(x, -10, "perd son chef")


## Ennemis de mêlée au contact qui ont droit à une attaque gratuite si `u` s'éloigne.
func free_attackers(u: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for f in foes_of(u):
		if f.morale > 0 and not f.is_ranged() and Hex.distance(f.hex, u.hex) == 1:
			out.append(f)
	return out


## Fait un pas. Renvoie true si le déplacement doit s'arrêter là (mort, piège…).
func step(u: Unit, to: Vector2i) -> bool:
	var c: Dictionary = Pathfinding.step_cost(u, cells, u.hex, to)
	u.hex = to
	u.ap -= int(c["ap"])
	u.fat += int(c["fat"])
	u.moved_cells += 1
	return Scenery.on_enter(self, u) or not u.is_live()


## Déplacement complet, synchrone (tests, simulation). Renvoie false si l'unité est morte ou retenue.
func move_along(u: Unit, path: Array[Vector2i], record_undo: bool = false) -> bool:
	if path.is_empty():
		return true
	if record_undo:
		begin_move(u)
	for f in free_attackers(u):
		var r: Dictionary = attack(f, u, true)
		if u.dead:
			return false
		if r["hit"]:
			say("%s est retenu." % u.unit_name, "miss")
			return false
	for h in path:
		if step(u, h):
			return u.is_live()
	return true


## Mémorise la situation de `u` avant un déplacement du joueur, pour `undo_move`. À appeler avant les attaques d'opportunité.
func begin_move(u: Unit) -> void:
	undo = {"id": u.id, "hex": u.hex, "ap": u.ap, "fat": u.fat}


## Le dernier déplacement de `u` peut-il être annulé ? (pas d'attaque, de capacité ou d'équipement depuis ; case de départ libre)
func can_undo_move(u: Unit) -> bool:
	if undo.is_empty() or u == null or not u.is_live() or current != u or int(undo["id"]) != u.id or over != "":
		return false
	var start: Vector2i = undo["hex"]
	return start != u.hex and unit_at(start) == null


## Ramène `u` à sa case de départ et lui rend les PA et la fatigue du déplacement. Un seul niveau. Renvoie true si fait.
func undo_move(u: Unit) -> bool:
	if not can_undo_move(u):
		return false
	u.hex = undo["hex"]
	u.ap = int(undo["ap"])
	u.fat = int(undo["fat"])
	undo = {}
	new_log_group()
	say("%s revient sur ses pas." % u.unit_name, "miss")
	return true


func raise_shield(u: Unit, with_fatigue: bool = true) -> void:
	undo = {}
	u.shield_wall = true
	u.ap -= 4
	if with_fatigue:
		u.fat += 10
	say("%s %s." % [u.unit_name, "forme un mur de boucliers" if with_fatigue else "lève son bouclier"], "miss")


## Peut-on échanger l'objet du sac n° `slot` avec ce qui est porté ? (PA, fatigue, règles d'équipement)
func can_swap_weapon(u: Unit, slot: int) -> bool:
	return u.is_live() and u.ap >= Data.SWAP_AP and u.fat + Data.SWAP_FAT <= u.fat_max_eff() \
		and slot >= 0 and slot < u.bag.size() and Inventory.bag_swap_block(u, slot) == ""


## Change d'arme (ou de bouclier) avec le sac n° `slot` : coûte Data.SWAP_AP PA et Data.SWAP_FAT de fatigue. Renvoie true si fait.
func swap_weapon(u: Unit, slot: int) -> bool:
	if not can_swap_weapon(u, slot):
		return false
	var incoming: String = Loot.item_name(u.bag[slot])
	undo = {}
	Inventory.bag_swap(u, slot)
	u.ap -= Data.SWAP_AP
	u.fat += Data.SWAP_FAT
	if not u.shield_ok():
		u.shield_wall = false
	say("%s sort %s." % [u.unit_name, incoming.to_lower()], "miss")
	return true


func wait(u: Unit) -> void:
	undo = {}
	u.waited = true
	queue.append(u)
	current = null


func leave_if_at_edge(u: Unit) -> bool:
	if Hex.column(u.hex) == edge_column(u):
		u.escaped = true
		say("%s quitte le champ de bataille." % u.unit_name, "mor")
		return true
	return false


## Exécute une action d'IA de façon synchrone (tests, simulation).
func execute(u: Unit, action: Dictionary) -> void:
	match action["type"]:
		"attack":
			attack(u, action["target"])
		"move":
			move_along(u, action["path"])
		"shield":
			raise_shield(u, false)
		"ability":
			use_ability(u, str(action["id"]), action["target"])
		"hit_object":
			Scenery.hit_object(self, u, action["hex"])
		"open":
			Scenery.open_door(self, u, action["hex"])
		"heal":
			heal_ally(u, action["target"])
		"raise":
			raise_dead(u, action["target"])


const HEAL_AP: int = 4
const RAISE_AP: int = 6


func can_heal(h: Unit, t: Unit) -> bool:
	return int(h.foe_data().get("heal", 0)) > 0 and h.is_live() and h.morale > 0 and h.ap >= HEAL_AP and t.is_live() and t.side == h.side and t != h \
		and t.hp < t.hp_max and Hex.distance(h.hex, t.hex) <= 2


func heal_ally(h: Unit, t: Unit) -> bool:
	if not can_heal(h, t):
		return false
	h.ap -= HEAL_AP
	undo = {}
	new_log_group()
	var n: int = mini(t.hp_max - t.hp, int(h.foe_data()["heal"]))
	t.hp += n
	say("%s soigne %s (+%d PV)." % [h.unit_name, t.unit_name, n], "mor")
	return true


## Morts-vivants relevables : cadavres d'alliés `side` de faction "u" (sauf nécromants), sur une case libre.
func raisable(n: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	if not bool(n.foe_data().get("raise", false)) or not n.is_live() or n.morale == 0 or n.ap < RAISE_AP or raised >= RAISE_MAX:
		return out
	for x in units:
		if x.dead and x.side == n.side and x.faction == "u" and not x.leader and Hex.distance(x.hex, n.hex) <= 2 and unit_at(x.hex) == null \
				and not Pathfinding.blocked(cells, x.hex):
			out.append(x)
	return out


func raise_dead(n: Unit, t: Unit) -> bool:
	if not raisable(n).has(t):
		return false
	n.ap -= RAISE_AP
	undo = {}
	new_log_group()
	raised += 1
	t.dead = false
	t.hp = maxi(1, t.hp_max / 2)
	t.morale = 3
	t.fat = 0
	t.turn_round = round_no
	t.ap = 0
	var ci: int = corpses.find(t.hex)
	if ci >= 0:
		corpses.remove_at(ci)
	say("%s relève %s !" % [n.unit_name, t.unit_name], "mor")
	return true


## Tour complet d'une unité contrôlée par l'IA (ou en fuite), synchrone.
func play_ai_turn(u: Unit) -> void:
	if u.morale == 0:
		if not leave_if_at_edge(u):
			var path: Array[Vector2i] = Ai.flee_path(self, u)
			say("%s prend la fuite !" % u.unit_name, "mor")
			if not path.is_empty():
				move_along(u, path)
			if u.is_live():
				leave_if_at_edge(u)
		return
	var memo: Dictionary = {}
	while u.is_live() and over == "":
		var action: Dictionary = Ai.next_action(self, u, memo)
		if action["type"] == "end":
			break
		execute(u, action)
		if check_end():
			return


# --- Sérialisation ---

func to_dict() -> Dictionary:
	var cell_list: Array = []
	for h in cells:
		var c: Dictionary = cells[h]
		var row: Array = [h.x, h.y, c["t"], c["c"], c["v"]]
		if c.has("obj"):
			row.append(c["obj"].duplicate())
		cell_list.append(row)
	var q_ids: Array = []
	for u in queue:
		q_ids.append(u.id)
	var unit_list: Array = []
	for u in units:
		unit_list.append(u.combat_dict())
	var corpse_list: Array = []
	for h in corpses:
		corpse_list.append([h.x, h.y])
	return {
		"width": width, "height": height, "cells": cell_list, "units": unit_list, "queue": q_ids,
		"round": round_no, "current": current.id if current else -1, "log": log_lines, "xp": xp,
		"corpses": corpse_list, "over": over, "contract": contract, "biome": biome,
		"undo": ({"id": undo["id"], "hex": [undo["hex"].x, undo["hex"].y], "ap": undo["ap"], "fat": undo["fat"]} if not undo.is_empty() else {}),
		"log_group": log_group, "wear_mult": wear_mult,
		"battle_type": battle_type, "night": night, "sight_radius": sight_radius, "rain": rain, "objectives": objectives.duplicate(true),
		"reserve": reserve.duplicate(), "hold_rounds": hold_rounds, "start_party": start_party, "raised": raised,
	}


static func from_dict(d: Dictionary, p_rng: RandomNumberGenerator) -> BattleState:
	var s := BattleState.new()
	s.rng = p_rng
	s.width = int(d["width"])
	s.height = int(d["height"])
	for c in d["cells"]:
		var cell: Dictionary = {"t": str(c[2]), "c": int(c[3]), "v": int(c[4])}
		if (c as Array).size() > 5:
			var ro: Dictionary = c[5]
			var o: Dictionary = {"kind": str(ro["kind"]), "hp": int(ro.get("hp", 0))}
			for bk in ["open", "hidden", "top"]:
				if ro.has(bk):
					o[bk] = bool(ro[bk])
			if ro.has("ttl"):
				o["ttl"] = int(ro["ttl"])
			if ro.has("owner"):
				o["owner"] = str(ro["owner"])
			cell["obj"] = o
		s.cells[Vector2i(int(c[0]), int(c[1]))] = cell
	s.battle_type = str(d.get("battle_type", "pitched"))
	s.night = bool(d.get("night", false))
	s.sight_radius = int(d.get("sight_radius", 0))
	s.rain = bool(d.get("rain", false))
	for o in d.get("objectives", []):
		s.objectives.append({"id": str(o["id"]), "kind": str(o["kind"]), "target": int(o["target"]), "done": bool(o["done"]), "failed": bool(o.get("failed", false)),
			"bonus": {"gold": int(o["bonus"]["gold"]), "renown": int(o["bonus"]["renown"])}, "label": str(o.get("label", ""))})
	s.reserve = (d.get("reserve", []) as Array).duplicate()
	s.hold_rounds = int(d.get("hold_rounds", 0))
	s.start_party = int(d.get("start_party", 0))
	s.raised = int(d.get("raised", 0))
	for ud in d["units"]:
		s.units.append(Unit.from_combat_dict(ud))
	for id in d["queue"]:
		var u: Unit = s.unit_by_id(int(id))
		if u:
			s.queue.append(u)
	s.round_no = int(d["round"])
	s.current = s.unit_by_id(int(d["current"]))
	for l in d["log"]:
		s.log_lines.append({"t": str(l["t"]), "c": str(l["c"]), "g": int(l.get("g", 0))})
	for k in d["xp"]:
		s.xp[int(k)] = int(d["xp"][k])
	for c in d["corpses"]:
		s.corpses.append(Vector2i(int(c[0]), int(c[1])))
	s.over = str(d["over"])
	s.contract = Contracts.normalize(d["contract"])
	s.biome = str(d.get("biome", "plain"))
	s.log_group = int(d.get("log_group", 0))
	s.wear_mult = float(d.get("wear_mult", 1.0))
	var ud: Dictionary = d.get("undo", {})
	if not ud.is_empty() and (ud["hex"] as Array).size() == 2:
		s.undo = {"id": int(ud["id"]), "hex": Vector2i(int(ud["hex"][0]), int(ud["hex"][1])), "ap": int(ud["ap"]), "fat": int(ud["fat"])}
	return s
