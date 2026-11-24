class_name Legacy
extends RefCounted
## Retraite et héritage. Un vétéran (niveau 8 ou plus, ou blessé gravement) peut se retirer : il quitte la compagnie
## (il ne combat plus et ne coûte plus de solde), devient instructeur du camp (un seul à la fois : petit bonus d'XP
## permanent pour tous) ou entre simplement dans le mémorial des retraités, et lègue une pièce de son équipement
## comme « objet de famille » nommé. Le reste de son équipement rejoint la réserve. Logique pure : `Game` retire l'homme
## du roster et verse les objets à la réserve. État dans `extras["legacy"]`.
##
## Objet de famille : l'objet reste un objet ordinaire (clé, grade, usure) ; la famille le conserve dans
## `heirlooms` avec un nom et un petit bonus de caractéristique accordé UNE fois à celui qui le reçoit
## (un autre homme de la même origine, ou une recrue « fils / fille de » engagée à demi-tarif).

const KEY: String = "legacy"
const MIN_LEVEL: int = 8
const XP_BONUS: float = 0.05  ## instructeur : +5 % d'XP à tous après chaque bataille
const HEIR_PRICE_FRAC: float = 0.5  ## prix d'une recrue « fils / fille de » (part du prix de l'origine)
const MAX_RETIRED: int = 60

## Bonus de l'objet de famille selon le genre de la pièce : {stat, montant}.
const BONUS: Dictionary = {
	"weapon": {"stat": "melee_skill", "amt": 3}, "shield": {"stat": "melee_def", "amt": 3}, "head": {"stat": "resolve", "amt": 3},
	"body": {"stat": "hp_max", "amt": 4}, "arms": {"stat": "melee_skill", "amt": 2}, "legs": {"stat": "initiative", "amt": 4},
}
const STAT_NAMES: Dictionary = {"melee_skill": "mêlée", "ranged_skill": "tir", "melee_def": "défense", "resolve": "détermination", "hp_max": "PV", "initiative": "initiative"}
const ROLES: Dictionary = {"instructor": "instructeur du camp", "memorial": "retraité"}


static func default_state() -> Dictionary:
	return {"retired": [], "instructor": {}, "heirlooms": [], "sons": 0, "next_hl": 1}


static func _is_clean(raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = raw
	if typeof(d.get("retired")) != TYPE_ARRAY or typeof(d.get("instructor")) != TYPE_DICTIONARY or typeof(d.get("heirlooms")) != TYPE_ARRAY 			or typeof(d.get("sons")) != TYPE_INT or typeof(d.get("next_hl")) != TYPE_INT:
		return false
	for e in d["retired"]:
		if typeof(e) != TYPE_DICTIONARY or typeof((e as Dictionary).get("day")) != TYPE_INT or typeof((e as Dictionary).get("lvl")) != TYPE_INT or typeof((e as Dictionary).get("kills")) != TYPE_INT:
			return false
	for h in d["heirlooms"]:
		if typeof(h) != TYPE_DICTIONARY or typeof((h as Dictionary).get("item")) != TYPE_DICTIONARY or typeof((h as Dictionary).get("id")) != TYPE_INT 				or typeof((h as Dictionary).get("holder")) != TYPE_INT or typeof((h as Dictionary).get("amt")) != TYPE_INT:
			return false
	var ins: Dictionary = d["instructor"]
	return ins.is_empty() or (typeof(ins.get("lvl")) == TYPE_INT and typeof(ins.get("day")) == TYPE_INT)


## L'objet renvoyé est celui qui est conservé dans `extras` (stable : on peut modifier ses éléments) ; une valeur absente,
## abîmée ou lue dans une sauvegarde JSON (nombres flottants) est d'abord remise en forme.
static func state(extras: Dictionary) -> Dictionary:
	if _is_clean(extras.get(KEY)):
		return extras[KEY]
	var raw: Variant = extras.get(KEY, {})
	var st: Dictionary = default_state()
	if typeof(raw) == TYPE_DICTIONARY:
		var d: Dictionary = raw
		var rl: Variant = d.get("retired", [])
		for e in (rl if typeof(rl) == TYPE_ARRAY else []):
			if typeof(e) == TYPE_DICTIONARY and (e as Dictionary).has("name"):
				st["retired"].append({"name": str(e["name"]), "bg": str(e.get("bg", "")), "lvl": int(e.get("lvl", 1)), "kills": int(e.get("kills", 0)),
					"day": int(e.get("day", 1)), "role": str(e.get("role", "memorial")) if ROLES.has(str(e.get("role", "memorial"))) else "memorial", "hl": str(e.get("hl", ""))})
		st["retired"] = (st["retired"] as Array).slice(-MAX_RETIRED)
		var ins: Variant = d.get("instructor", {})
		if typeof(ins) == TYPE_DICTIONARY and (ins as Dictionary).has("name"):
			st["instructor"] = {"name": str(ins["name"]), "bg": str(ins.get("bg", "")), "lvl": int(ins.get("lvl", 1)), "day": int(ins.get("day", 1))}
		var hls: Variant = d.get("heirlooms", [])
		if typeof(hls) == TYPE_ARRAY:
			for h in hls:
				if typeof(h) == TYPE_DICTIONARY and Loot.is_valid((h as Dictionary).get("item")) and BONUS.has(str(h["item"].get("kind", ""))):
					st["heirlooms"].append({"id": int(h.get("id", 0)), "item": Loot.clean(h["item"]), "name": str(h.get("name", "Objet de famille")), "from": str(h.get("from", "?")),
						"bg": str(h.get("bg", "")), "holder": int(h.get("holder", -1)), "stat": str(h.get("stat", "melee_skill")), "amt": int(h.get("amt", 2)), "day": int(h.get("day", 1))})
		st["sons"] = int(d.get("sons", 0))
		st["next_hl"] = maxi(int(d.get("next_hl", 1)), 1)
		for h in st["heirlooms"]:
			st["next_hl"] = maxi(int(st["next_hl"]), int(h["id"]) + 1)
	extras[KEY] = st
	return st


static func retired_count(extras: Dictionary) -> int:
	return (state(extras)["retired"] as Array).size()


static func has_instructor(extras: Dictionary) -> bool:
	return not (state(extras)["instructor"] as Dictionary).is_empty()


## Multiplicateur d'XP des hommes en bataille grâce à l'instructeur (1,0 sans instructeur).
static func xp_mult(extras: Dictionary) -> float:
	return 1.0 + XP_BONUS if has_instructor(extras) else 1.0


## Raison pour laquelle `u` ne peut pas se retirer ("" = c'est possible).
static func retire_block(u: Unit, roster_size: int, in_battle: bool = false) -> String:
	if in_battle:
		return "Pas pendant une bataille."
	if roster_size <= 1:
		return "La compagnie ne peut pas rester sans personne."
	if not is_veteran(u):
		return "Il faut être niveau %d ou gravement blessé." % MIN_LEVEL
	return ""


static func is_veteran(u: Unit) -> bool:
	if u.level >= MIN_LEVEL:
		return true
	for i in u.injuries:
		if int((i as Dictionary).get("days_left", 0)) < 0:
			return true  ## séquelle permanente
	return false


## Pièces portées, utilisables comme objet de famille : [{"kind", "item", "label"}].
static func heirloom_choices(u: Unit) -> Array:
	var out: Array = []
	for p in Loot.pieces_of(u):
		var it: Dictionary = p["item"]
		if BONUS.has(str(it["kind"])):
			out.append({"kind": str(it["kind"]), "item": it, "label": Loot.item_name(it)})
	return out


## Bonus {stat, amt} d'un objet de famille de genre `kind` (arme à distance : tir plutôt que mêlée).
static func bonus_for(it: Dictionary) -> Dictionary:
	var b: Dictionary = (BONUS[str(it["kind"])] as Dictionary).duplicate()
	if str(it["kind"]) == "weapon" and bool(Data.WPN.get(str(it["key"]), {}).get("ranged", false)):
		b["stat"] = "ranged_skill"
	return b


static func bonus_text(h: Dictionary) -> String:
	return "+%d %s" % [int(h["amt"]), str(STAT_NAMES.get(str(h["stat"]), h["stat"]))]


## Retire `u` : inscrit sa retraite, éventuellement nomme un objet de famille tiré de la pièce `piece_kind` ("" = aucun)
## et rend les autres objets à verser à la réserve. `role` : "instructor" (un seul à la fois) ou "memorial".
## Renvoie {"ok", "msg", "items", "heirloom"} ; ne touche pas au roster.
static func retire(extras: Dictionary, u: Unit, day: int, role: String, piece_kind: String) -> Dictionary:
	var st: Dictionary = state(extras)
	var res: Dictionary = {"ok": false, "msg": "", "items": [], "heirloom": {}}
	if role == "instructor" and not (st["instructor"] as Dictionary).is_empty():
		res["msg"] = "Le camp a déjà un instructeur."
		return res
	if not ROLES.has(role):
		role = "memorial"
	var items: Array = Loot.gear_items(u)
	var hl: Dictionary = {}
	if piece_kind != "":
		for c in heirloom_choices(u):
			if str(c["kind"]) == piece_kind:
				var it: Dictionary = c["item"]
				var idx: int = items.find(it)
				if idx >= 0:
					items.remove_at(idx)
				var b: Dictionary = bonus_for(it)
				hl = {"id": int(st["next_hl"]), "item": it.duplicate(true), "name": "%s de %s" % [str(Loot.data_of(it).get("n", "?")), u.unit_name],
					"from": u.unit_name, "bg": u.background, "holder": -1, "stat": str(b["stat"]), "amt": int(b["amt"]), "day": day}
				st["next_hl"] = int(st["next_hl"]) + 1
				(st["heirlooms"] as Array).append(hl)
				break
	(st["retired"] as Array).append({"name": u.unit_name, "bg": u.background, "lvl": u.level, "kills": u.kills, "day": day, "role": role, "hl": str(hl.get("name", ""))})
	while (st["retired"] as Array).size() > MAX_RETIRED:
		(st["retired"] as Array).pop_front()
	if role == "instructor":
		st["instructor"] = {"name": u.unit_name, "bg": u.background, "lvl": u.level, "day": day}
	res["ok"] = true
	res["items"] = items
	res["heirloom"] = hl
	res["msg"] = "%s prend sa retraite%s." % [u.unit_name, " et devient instructeur du camp" if role == "instructor" else ""]
	return res


static func heirloom_by_id(extras: Dictionary, id: int) -> Dictionary:
	for h in state(extras)["heirlooms"]:
		if int(h["id"]) == id:
			return h
	return {}


## Objets de famille sans porteur vivant dans `roster`.
static func free_heirlooms(extras: Dictionary, roster: Array) -> Array:
	var ids: Dictionary = {}
	for u in roster:
		ids[(u as Unit).id] = true
	var out: Array = []
	for h in state(extras)["heirlooms"]:
		if not ids.has(int(h["holder"])):
			out.append(h)
	return out


## Objet de famille que `u` porte encore (même clé dans la bonne pièce), ou {}.
static func held_by(extras: Dictionary, u: Unit) -> Dictionary:
	for h in state(extras)["heirlooms"]:
		if int(h["holder"]) == u.id:
			for p in Loot.pieces_of(u):
				var it: Dictionary = p["item"]
				if str(it["kind"]) == str((h["item"] as Dictionary)["kind"]) and str(it["key"]) == str((h["item"] as Dictionary)["key"]):
					return h
	return {}


## Hommes de `roster` pouvant recevoir l'objet : même origine, sans objet de famille déjà.
static func eligible_heirs(extras: Dictionary, roster: Array, h: Dictionary) -> Array:
	var out: Array = []
	for u in roster:
		if (u as Unit).background == str(h["bg"]) and held_by(extras, u).is_empty() and Loot.can_equip(u, h["item"]):
			out.append(u)
	return out


## Remet l'objet de famille `id` à `heir` : équipe la pièce (l'ancienne rejoint `removed`, à verser à la réserve) et
## accorde le bonus. Renvoie {"ok", "msg", "removed"}.
static func bestow(extras: Dictionary, id: int, heir: Unit, roster: Array) -> Dictionary:
	var res: Dictionary = {"ok": false, "msg": "", "removed": []}
	var h: Dictionary = heirloom_by_id(extras, id)
	if h.is_empty() or not free_heirlooms(extras, roster).has(h):
		res["msg"] = "Cet objet de famille a déjà un porteur."
		return res
	if heir.background != str(h["bg"]):
		res["msg"] = "Seul un homme de la même origine (%s) peut le porter." % str(h["bg"])
		return res
	if not Loot.can_equip(heir, h["item"]):
		res["msg"] = "%s ne peut pas le porter avec son équipement actuel." % heir.unit_name
		return res
	res["removed"] = Loot.equip(heir, (h["item"] as Dictionary).duplicate(true))
	var stat: String = str(h["stat"])
	heir.set(stat, int(heir.get(stat)) + int(h["amt"]))
	if stat == "hp_max":
		heir.hp += int(h["amt"])
	h["holder"] = heir.id
	res["ok"] = true
	res["msg"] = "%s reçoit « %s » (%s)." % [heir.unit_name, str(h["name"]), bonus_text(h)]
	return res


## Clé de Data.BG de l'origine nommée `bg_name` ("" si inconnue).
static func origin_key(bg_name: String) -> String:
	for k in Data.BG:
		if str(Data.BG[k]["n"]) == bg_name:
			return str(k)
	return ""


## Prix d'une recrue « fils / fille de » pour l'objet de famille `h` (0 si l'origine est inconnue).
static func heir_price(h: Dictionary) -> int:
	var k: String = origin_key(str(h["bg"]))
	return int(round(float(Data.BG[k]["price"]) * HEIR_PRICE_FRAC)) if k != "" else 0


## Nouvelle recrue « fils / fille de » : origine de l'ancien, nom et histoire propres. Ne l'ajoute à aucune liste.
static func make_heir(extras: Dictionary, h: Dictionary, rng: RandomNumberGenerator, taken: Array) -> Unit:
	var k: String = origin_key(str(h["bg"]))
	if k == "":
		return null
	var u: Unit = Contracts.make_merc(k, rng, taken)
	var girl: bool = rng.randf() < 0.5
	var first: String = str(CampLifeData.DAUGHTER_NAMES[rng.randi() % CampLifeData.DAUGHTER_NAMES.size()]) if girl else str(Data.FIRST_NAMES[rng.randi() % Data.FIRST_NAMES.size()])
	u.unit_name = "%s, %s de %s" % [first, "fille" if girl else "fils", str(h["from"])]
	u.backstory = "%s de %s, venu%s reprendre la place laissée vide. Il faudra mériter le nom que l'on porte." % ["Fille" if girl else "Fils", str(h["from"]), "e" if girl else ""]
	state(extras)["sons"] = int(state(extras)["sons"]) + 1
	return u
