class_name Formation
extends RefCounted
## Formation de la compagnie : 36 emplacements numérotés 0..35.
##   0..8 rangée avant, 9..17 rangée du milieu, 18..26 rangée arrière (champ de bataille) ; 27..35 réserve (hors combat)
## Une formation est un Dictionary « id d'homme -> emplacement ». Logique pure, sans scène.

const SLOTS: int = 36
const ROW_LEN: int = 9
const FRONT_START: int = 0
const MID_START: int = 9
const BACK_START: int = 18
const RESERVE_START: int = 27
const NO_HEX := Vector2i(-9999, -9999)  ## emplacement de réserve : pas de case sur le plateau


static func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOTS


static func is_field(slot: int) -> bool:
	return slot >= 0 and slot < RESERVE_START


static func is_front(slot: int) -> bool:
	return slot >= FRONT_START and slot < MID_START


static func is_mid(slot: int) -> bool:
	return slot >= MID_START and slot < BACK_START

static func is_back(slot: int) -> bool:
	return slot >= BACK_START and slot < RESERVE_START


static func is_reserve(slot: int) -> bool:
	return slot >= RESERVE_START and slot < SLOTS


## Premier emplacement de `first..first+9` selon l'ordre de déploiement de BattleState.DEPLOY_ROWS (centre d'abord).
static func _order(first: int) -> Array[int]:
	var out: Array[int] = []
	for r in BattleState.DEPLOY_ROWS:
		out.append(first + r)
	return out


## Formation par défaut = déploiement historique : les `Data.FIGHTERS` premiers combattent, mêlée devant, tireurs derrière
## (centre d'abord) ; les autres sont en réserve, dans l'ordre de la compagnie.
static func default_slots(roster: Array) -> Dictionary:
	var out: Dictionary = {}
	var mel: int = 0
	var rng_n: int = 0
	var reserve_n: int = 0
	for i in roster.size():
		var u: Unit = roster[i]
		if i < Data.FIGHTERS:
			if u.is_ranged():
				out[u.id] = _order(BACK_START)[mini(rng_n, ROW_LEN - 1)]
				rng_n += 1
			else:
				out[u.id] = _order(MID_START)[mini(mel, ROW_LEN - 1)]
				mel += 1
		else:
			out[u.id] = RESERVE_START + mini(reserve_n, ROW_LEN - 1)
			reserve_n += 1
	return _repair(out, roster)


## Identifiants des hommes sur le champ de bataille.
static func field_ids(slots: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for id in slots:
		if is_field(int(slots[id])):
			out.append(int(id))
	out.sort()
	return out


static func field_count(slots: Dictionary) -> int:
	return field_ids(slots).size()


## Id de l'occupant d'un emplacement, ou -1.
static func occupant(slots: Dictionary, slot: int) -> int:
	for id in slots:
		if int(slots[id]) == slot:
			return int(id)
	return -1


## Formation cohérente avec la compagnie : retire les absents, répare doublons et valeurs hors limites, plafonne le champ à
## `Data.FIGHTERS`, et place les nouveaux venus (sur le champ s'il y a de la place, sinon en réserve ; ordre de la compagnie).
static func normalize(slots: Dictionary, roster: Array) -> Dictionary:
	var out: Dictionary = {}
	var taken: Dictionary = {}  ## emplacement -> id
	var late: Array[Unit] = []  ## sans place valide
	var field: int = 0
	for u in roster:
		var uid: int = (u as Unit).id
		var s: int = int(slots[uid]) if slots.has(uid) else -1
		if not is_valid_slot(s) or taken.has(s) or (is_field(s) and field >= Data.FIGHTERS):
			late.append(u)
			continue
		taken[s] = uid
		out[uid] = s
		if is_field(s):
			field += 1
	for u in late:
		var target: int = _free_for(u, taken, field)
		if target < 0:
			continue
		taken[target] = u.id
		out[u.id] = target
		if is_field(target):
			field += 1
	return out


## Emplacement libre pour un homme : le champ (selon son rôle) s'il y a de la place, sinon la réserve ; -1 si tout est plein.
static func _free_for(u: Unit, taken: Dictionary, field: int) -> int:
	if field < Data.FIGHTERS:
		var first: int = BACK_START if u.is_ranged() else MID_START
		for pref in ([BACK_START, MID_START, FRONT_START] if u.is_ranged() else [MID_START, FRONT_START, BACK_START]):
			for s in _order(pref):
				if not taken.has(s):
					return s
	for s in range(RESERVE_START, SLOTS):
		if not taken.has(s):
			return s
	return -1


## Ne garde que des emplacements distincts valides (utilisé pour les formations construites à la main).
static func _repair(slots: Dictionary, roster: Array) -> Dictionary:
	return normalize(slots, roster)


## Déplace un homme vers un emplacement. Occupé : échange. Libre : refusé si cela fait dépasser `Data.FIGHTERS` hommes sur le champ,
## ou s'il ne resterait personne pour combattre. Renvoie {ok, slots, reason}.
static func move(slots: Dictionary, unit_id: int, to_slot: int) -> Dictionary:
	var res: Dictionary = {"ok": false, "slots": slots.duplicate(), "reason": ""}
	if not is_valid_slot(to_slot):
		res["reason"] = "Cet emplacement n'existe pas."
		return res
	if not slots.has(unit_id):
		res["reason"] = "Cet homme ne fait pas partie de la compagnie."
		return res
	var from_slot: int = int(slots[unit_id])
	if from_slot == to_slot:
		res["ok"] = true
		return res
	var other: int = occupant(slots, to_slot)
	var out: Dictionary = slots.duplicate()
	if other >= 0:
		out[unit_id] = to_slot
		out[other] = from_slot
		res["ok"] = true
		res["slots"] = out
		return res
	var count: int = field_count(slots)
	if is_field(to_slot) and not is_field(from_slot) and count >= Data.FIGHTERS:
		res["reason"] = "Il y a déjà %d hommes sur le champ de bataille : mettez-en un en réserve d'abord." % Data.FIGHTERS
		return res
	if is_field(from_slot) and not is_field(to_slot) and count <= 1:
		res["reason"] = "Au moins un homme doit rester sur le champ de bataille."
		return res
	out[unit_id] = to_slot
	res["ok"] = true
	res["slots"] = out
	return res


## Échange les places de deux hommes (toujours permis).
static func swap(slots: Dictionary, a: int, b: int) -> Dictionary:
	var out: Dictionary = slots.duplicate()
	if slots.has(a) and slots.has(b):
		out[a] = slots[b]
		out[b] = slots[a]
	return out


## « Disposition automatique » : les hommes du champ sont replacés (mêlée devant, tireurs derrière, centre d'abord) ;
## la réserve ne change pas.
static func auto_arrange(roster: Array, slots: Dictionary) -> Dictionary:
	var norm: Dictionary = normalize(slots, roster)
	var out: Dictionary = {}
	var mel: int = 0
	var rng_n: int = 0
	var front: Array[int] = _order(MID_START)
	var back: Array[int] = _order(BACK_START)
	for u in roster:
		var s: int = int(norm.get((u as Unit).id, -1))
		if is_field(s):
			if u.is_ranged():
				out[u.id] = back[mini(rng_n, ROW_LEN - 1)]
				rng_n += 1
			else:
				out[u.id] = front[mini(mel, ROW_LEN - 1)]
				mel += 1
		elif s >= 0:
			out[u.id] = s
	return normalize(out, roster)


## Case du plateau d'un emplacement de champ : rangée du milieu -> colonne `mid_col`, arrière -> `back_col`, avant -> une colonne
## plus près de l'ennemi (2 * mid_col - back_col). L'indice 0..8 dans la rangée est la ligne du plateau (écrêtée). Réserve : `NO_HEX`.
static func hex_for_slot(slot: int, width: int, height: int, mid_col: int = 1, back_col: int = 0) -> Vector2i:
	if not is_field(slot):
		return NO_HEX
	var idx: int = slot % ROW_LEN
	var col: int = back_col
	if is_mid(slot):
		col = mid_col
	elif is_front(slot):
		col = 2 * mid_col - back_col
	return Hex.from_col_row(clampi(col, 0, maxi(0, width - 1)), clampi(idx, 0, maxi(0, height - 1)))


static func slot_label(slot: int) -> String:
	if is_front(slot):
		return "Rangée avant, case %d" % (slot - FRONT_START + 1)
	if is_mid(slot):
		return "Rangée du milieu, case %d" % (slot - MID_START + 1)
	if is_back(slot):
		return "Rangée arrière, case %d" % (slot - BACK_START + 1)
	if is_reserve(slot):
		return "Réserve, case %d" % (slot - RESERVE_START + 1)
	return "—"


# --- Sauvegarde ---

static func to_dict(slots: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id in slots:
		out[str(id)] = int(slots[id])
	return out


## Relit une formation sauvegardée ; absente ou invalide : formation par défaut de la compagnie.
static func from_dict(d: Variant, roster: Array) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY or (d as Dictionary).is_empty():
		return default_slots(roster)
	var slots: Dictionary = {}
	for k in d:
		var v: Variant = d[k]
		if (typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT) or not str(k).is_valid_int():
			return default_slots(roster)
		slots[int(str(k))] = int(v)
	return normalize(slots, roster)
