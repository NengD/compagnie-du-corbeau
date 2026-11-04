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
const LOG_MAX: int = 200


## Crée une bataille : copie de la compagnie (les 8 premiers), ennemis du contrat, terrain, déploiement.
static func create(p_contract: Dictionary, roster: Array, p_rng: RandomNumberGenerator) -> BattleState:
	var s := BattleState.new()
	s.rng = p_rng
	s.contract = p_contract
	s._build_terrain()
	var party: Array[Unit] = []
	for i in mini(roster.size(), Data.FIGHTERS):
		var u: Unit = (roster[i] as Unit).duplicate_unit()
		u.reset_for_battle()
		party.append(u)
	var foes: Array[Unit] = []
	for k in p_contract["foes"]:
		var f: Unit = Contracts.make_foe(str(k), p_rng)
		f.reset_for_battle()
		foes.append(f)
	s._deploy(party, 1, 0)
	s._deploy(foes, s.width - 2, s.width - 1)
	s.units.append_array(party)
	s.units.append_array(foes)
	s.say(str(p_contract["title"]), "sys")
	s.new_round()
	return s


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
	return CombatRules.hit_chance(a, d, units, cells, bonus)


## Ligne de tir coupée par un obstacle (n'a de sens que pour une arme à distance).
func line_blocked(a: Unit, d: Unit) -> bool:
	return a.is_ranged() and CombatRules.line_blocked(a.hex, d.hex, cells)


## Portée, PA, fatigue et (à distance) ligne de tir dégagée.
func can_attack(a: Unit, d: Unit) -> bool:
	return CombatRules.can_attack(a, d) and not line_blocked(a, d)


func reachable(u: Unit) -> Dictionary:
	return Pathfinding.reachable(u, cells, units)


func edge_column(u: Unit) -> int:
	return 0 if u.side == "p" else width - 1


# --- Déroulement ---

func new_round() -> void:
	round_no += 1
	var live: Array[Unit] = []
	for u in units:
		if u.is_live():
			live.append(u)
	live.sort_custom(func(a: Unit, b: Unit) -> bool:
		if a.ini_eff() != b.ini_eff():
			return a.ini_eff() > b.ini_eff()
		return a.id < b.id)
	queue = live
	for u in units:
		u.waited = false
	if round_no > 1:
		say("Manche %d" % round_no, "sys")


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
		var u: Unit = queue.pop_front()
		if u == null or not u.is_live():
			continue
		current = u
		begin_turn(u)
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
	for u in units:
		if u.is_fighting():
			if u.side == "e":
				enemies += 1
			else:
				friends += 1
	if enemies == 0:
		end_battle("win")
		return true
	if friends == 0:
		end_battle("lose")
		return true
	return false


func end_battle(result: String) -> void:
	over = result
	current = null
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
	return u.shield_ok() and not u.shield_wall and u.ap >= 4 or not CombatRules.abilities_of(u).is_empty() and _ability_target(u) != null


func _ability_target(u: Unit) -> Unit:
	for f in foes_of(u):
		for id in CombatRules.abilities_of(u):
			if can_use_ability(u, f, id):
				return f
	return null


# --- Capacités ---

## Portée, PA, fatigue, bouclier requis et (à distance) ligne de tir dégagée.
func can_use_ability(a: Unit, d: Unit, id: String) -> bool:
	return CombatRules.can_use_ability(a, d, id) and not line_blocked(a, d)


## Utilise une capacité de l'arme sur `d` (mêmes événements que `attack`, plus `ability`, `pushed`, `stunned`, `exposed`, `shield_broken`).
func use_ability(a: Unit, id: String, d: Unit) -> Dictionary:
	return attack(a, d, false, id)


## Repousse `d` d'une case à l'opposé de `a` si la case est libre et praticable. Renvoie la nouvelle case ou (-999, -999).
func push_target(a: Unit, d: Unit) -> Vector2i:
	var dist: int = Hex.distance(a.hex, d.hex)
	for n in Hex.neighbors(d.hex):
		if Hex.distance(a.hex, n) != dist + 1 or not cells.has(n) or unit_at(n) != null:
			continue
		if bool(Data.TERRAIN[cells[n]["t"]]["block"]):
			continue
		d.hex = n
		return n
	return Vector2i(-999, -999)


# --- Actions ---

func attack(a: Unit, d: Unit, free: bool = false, ability: String = "") -> Dictionary:
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
	if int(dmg["armor"]) > 0 and a.wear_weapon(2 if int(dmg["zone_armor"]) >= Data.HEAVY_ARMOR_WEAR else 1):
		say("L'arme de %s est ébréchée." % a.unit_name, "death")
		res["weapon_broke"] = true
	res["head"] = dmg["head"]
	res["hp"] = dmg["hp"]
	res["armor"] = dmg["armor"]
	say("%s touche %s%s%s : %d PV, %d armure — %d %%" % [a.unit_name, d.unit_name, " à la tête" if dmg["head"] else "", tag, dmg["hp"], dmg["armor"], ch], "hit")
	if d.hp > 0 and ability != "":
		_apply_ability_effects(a, d, ab, res)
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
	if d.wear_shield(n):
		say("Le bouclier de %s se brise !" % d.unit_name, "death")


func _apply_ability_effects(a: Unit, d: Unit, ab: Dictionary, res: Dictionary) -> void:
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


func _morale_down(u: Unit, modifier: int, why: String) -> void:
	if CombatRules.morale_test_fails(u, modifier + Perks.morale_aura(u, units) + Traits.aura(u, units), rng):
		say("%s %s : %s." % [u.unit_name, why, str(Data.MORALE_NAMES[u.morale]).to_lower()], "mor")


func _kill(d: Unit, a: Unit) -> void:
	d.hp = 0
	d.dead = true
	d.shield_wall = false
	corpses.append(d.hex)
	say("%s tombe sous les coups de %s." % [d.unit_name, a.unit_name], "death")
	a.kills += 1
	if a.side == "p":
		xp[a.id] = int(xp.get(a.id, 0)) + (d.xp_value if d.xp_value > 0 else 15)
	for x in units:
		if not x.is_live():
			continue
		var dist: int = Hex.distance(x.hex, d.hex)
		if x.side == d.side and dist <= 4:
			_morale_down(x, (-15 if d.leader else 0) + Traits.ally_fall_mod(x), "voit son chef tomber" if d.leader else "voit tomber " + d.unit_name.split(" ")[0])
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


func step(u: Unit, to: Vector2i) -> void:
	var c: Dictionary = Pathfinding.step_cost(u, cells, u.hex, to)
	u.hex = to
	u.ap -= int(c["ap"])
	u.fat += int(c["fat"])


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
		step(u, h)
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
		cell_list.append([h.x, h.y, c["t"], c["c"], c["v"]])
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
		"log_group": log_group,
	}


static func from_dict(d: Dictionary, p_rng: RandomNumberGenerator) -> BattleState:
	var s := BattleState.new()
	s.rng = p_rng
	s.width = int(d["width"])
	s.height = int(d["height"])
	for c in d["cells"]:
		s.cells[Vector2i(int(c[0]), int(c[1]))] = {"t": str(c[2]), "c": int(c[3]), "v": int(c[4])}
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
	var ud: Dictionary = d.get("undo", {})
	if not ud.is_empty() and (ud["hex"] as Array).size() == 2:
		s.undo = {"id": int(ud["id"]), "hex": Vector2i(int(ud["hex"][0]), int(ud["hex"][1])), "ap": int(ud["ap"]), "fat": int(ud["fat"])}
	return s
