class_name BattleLog
extends RefCounted
## Journal de rediffusion : enregistre une bataille sous forme d'images successives (ce qui a changé), sans toucher aux règles.
## État initial (unités et terrain) + suite d'images {r: manche, a: id de l'unité qui agit, t: [[texte, css]…], u: [[id, q, r, pv, arm tête, arm corps, moral, drapeaux]…],
## n: nouvelles unités (renforts)}. Rejouer = appliquer les images dans l'ordre à une copie de l'état initial (`replay_state` + `apply_frame`).
## Borné : au plus MAX_FRAMES images ; au-delà l'enregistrement s'arrête (`truncated`). Aucun aléa, aucune dépendance de scène.

const VERSION: int = 1
const MAX_FRAMES: int = 900
const MAX_TEXTS: int = 6  ## lignes de journal gardées par image
const FLAG_DEAD: int = 1
const FLAG_ESCAPED: int = 2

var init: Dictionary = {}  ## état de départ (BattleState.to_dict allégé)
var frames: Array = []
var truncated: bool = false
var resumed: bool = false  ## l'enregistrement a commencé en cours de bataille (reprise d'une sauvegarde)
var _last: Dictionary = {}  ## id d'unité -> signature à l'image précédente
var _pending: Array = []  ## lignes de journal pas encore rattachées à une image


## Commence l'enregistrement de `s` (appelé une fois la bataille créée, ou rechargée).
static func start(s: BattleState, p_resumed: bool = false) -> BattleLog:
	var b := BattleLog.new()
	var d: Dictionary = s.to_dict()
	d.erase("log")
	b.init = d
	b.resumed = p_resumed
	for u in s.units:
		b._last[u.id] = _sig(u)
	return b


static func _sig(u: Unit) -> Array:
	return [u.hex.x, u.hex.y, u.hp, u.arm_h, u.arm_b, u.morale, (FLAG_DEAD if u.dead else 0) | (FLAG_ESCAPED if u.escaped else 0)]


## À appeler après chaque événement (texte de journal, fin de tour…). Ne crée une image que si quelque chose a changé.
func capture(s: BattleState, text: String = "", css: String = "") -> void:
	if truncated:
		return
	if text != "":
		_pending.append([text, css])
		if _pending.size() > MAX_TEXTS * 4:
			_pending = _pending.slice(_pending.size() - MAX_TEXTS * 2)
	var changed: Array = []
	var fresh: Array = []
	for u in s.units:
		var sg: Array = _sig(u)
		if not _last.has(u.id):
			fresh.append(u.combat_dict())
			_last[u.id] = sg
			continue
		if _last[u.id] != sg:
			changed.append([u.id] + sg)
			_last[u.id] = sg
	if changed.is_empty() and fresh.is_empty():
		return
	_push(s, changed, fresh)


func _push(s: BattleState, changed: Array, fresh: Array) -> void:
	if frames.size() >= MAX_FRAMES:
		truncated = true
		return
	var f: Dictionary = {"r": s.round_no, "a": s.current.id if s.current != null else -1}
	if not changed.is_empty():
		f["u"] = changed
	if not fresh.is_empty():
		f["n"] = fresh
	if not _pending.is_empty():
		var keep: Array = _pending.slice(maxi(0, _pending.size() - MAX_TEXTS))
		f["t"] = keep
		_pending = []
	frames.append(f)


## Fin de bataille : attache les dernières lignes de journal (image finale même sans changement d'unité).
func finalize(s: BattleState) -> void:
	capture(s)
	if truncated or _pending.is_empty():
		return
	if frames.size() >= MAX_FRAMES:
		truncated = true
		return
	frames.append({"r": s.round_no, "a": -1, "t": _pending.slice(maxi(0, _pending.size() - MAX_TEXTS))})
	_pending = []


func frame_count() -> int:
	return frames.size()


## Numéro de la première image d'une manche postérieure à `round_no` (−1 s'il n'y en a pas).
func next_round_index(from_index: int) -> int:
	if frames.is_empty():
		return -1
	var cur: int = int(frames[clampi(from_index, 0, frames.size() - 1)]["r"])
	for i in range(clampi(from_index, 0, frames.size() - 1), frames.size()):
		if int(frames[i]["r"]) > cur:
			return i
	return -1


# --- Relecture (pure) ---

## Copie jouable de l'état initial. `p_rng` est inutilisé par la relecture mais exigé par BattleState.
func replay_state(p_rng: RandomNumberGenerator = null) -> BattleState:
	var r: RandomNumberGenerator = p_rng if p_rng != null else RandomNumberGenerator.new()
	var d: Dictionary = init.duplicate(true)
	d["log"] = []
	d["over"] = ""
	return BattleState.from_dict(d, r)


## Applique l'image `f` à l'état de relecture `s`. Renvoie ce qui s'est passé, pour l'affichage :
## {"actor": Unit|null, "moved": [[Unit, case de départ]], "hurt": [[Unit, PV perdus, armure perdue]], "dead": [Unit], "morale": [Unit], "spawned": [Unit], "texts": Array, "round": int}
static func apply_frame(s: BattleState, f: Dictionary) -> Dictionary:
	var out: Dictionary = {"actor": s.unit_by_id(int(f.get("a", -1))), "moved": [], "hurt": [], "dead": [], "morale": [], "spawned": [], "texts": f.get("t", []), "round": int(f.get("r", 0))}
	for nd in f.get("n", []):
		var nu: Unit = Unit.from_combat_dict(nd)
		if s.unit_by_id(nu.id) == null:
			s.units.append(nu)
			(out["spawned"] as Array).append(nu)
	for row in f.get("u", []):
		var u: Unit = s.unit_by_id(int(row[0]))
		if u == null:
			continue
		var to := Vector2i(int(row[1]), int(row[2]))
		if to != u.hex:
			(out["moved"] as Array).append([u, u.hex])
		var hp: int = int(row[3])
		var ah: int = int(row[4])
		var ab: int = int(row[5])
		if hp < u.hp or ah < u.arm_h or ab < u.arm_b:
			(out["hurt"] as Array).append([u, maxi(0, u.hp - hp), maxi(0, u.arm_h - ah) + maxi(0, u.arm_b - ab)])
		var was_dead: bool = u.dead
		u.hex = to
		u.hp = hp
		u.arm_h = ah
		u.arm_b = ab
		if int(row[6]) != u.morale:
			(out["morale"] as Array).append(u)
		u.morale = int(row[6])
		var fl: int = int(row[7])
		u.dead = (fl & FLAG_DEAD) != 0
		u.escaped = (fl & FLAG_ESCAPED) != 0
		if u.dead and not was_dead:
			(out["dead"] as Array).append(u)
	s.round_no = maxi(s.round_no, int(f.get("r", 0)))
	return out


## Les unités de `real` et de `replayed` (relecture complète) coïncident-elles ? Liste des écarts (vide = identique).
static func diff_final(real: BattleState, replayed: BattleState) -> Array[String]:
	var bad: Array[String] = []
	for u in real.units:
		var r: Unit = replayed.unit_by_id(u.id)
		if r == null:
			bad.append("%s absent de la relecture" % u.unit_name)
			continue
		if _sig(u) != _sig(r):
			bad.append("%s : %s ≠ %s" % [u.unit_name, str(_sig(u)), str(_sig(r))])
	return bad


# --- Sérialisation (JSON) ---

func to_dict() -> Dictionary:
	return {"v": VERSION, "init": init, "frames": frames, "truncated": truncated, "resumed": resumed}


static func from_dict(d: Variant) -> BattleLog:
	var b := BattleLog.new()
	if typeof(d) != TYPE_DICTIONARY:
		return b
	var dd: Dictionary = d
	if typeof(dd.get("init", null)) == TYPE_DICTIONARY and typeof(dd.get("frames", null)) == TYPE_ARRAY:
		b.init = (dd["init"] as Dictionary).duplicate(true)
		b.frames = (dd["frames"] as Array).duplicate(true)
		b.truncated = bool(dd.get("truncated", false))
		b.resumed = bool(dd.get("resumed", false))
	return b


## Forme compacte pour `Game.extras` : JSON compressé (gzip) puis base64.
func pack() -> Dictionary:
	var raw: PackedByteArray = JSON.stringify(to_dict()).to_utf8_buffer()
	return {"v": VERSION, "z": Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP)), "n": frames.size()}


## Relit un journal compacté (journal vide si rien ou si la donnée est abîmée).
static func unpack(packed: Variant) -> BattleLog:
	if typeof(packed) != TYPE_DICTIONARY or not (packed as Dictionary).has("z"):
		return BattleLog.new()
	var raw: PackedByteArray = Marshalls.base64_to_raw(str(packed["z"]))
	if raw.is_empty():
		return BattleLog.new()
	var bytes: PackedByteArray = raw.decompress_dynamic(32 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	if bytes.is_empty():
		return BattleLog.new()
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return from_dict(parsed)


func is_valid() -> bool:
	return not init.is_empty() and not frames.is_empty()
