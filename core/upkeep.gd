class_name Upkeep
extends RefCounted
## Entretien de l'équipement au camp / en lieu (logique pure) :
##  - aiguiser une arme tranchante ou huiler un haubert de mailles : petit coût, bonus qui expire après N combats
##    (état par homme dans `Unit.upkeep`) ;
##  - réparation pièce par pièce, par paliers (25 / 50 / 100 %), coût proportionnel ;
##  - forgeron variable selon le type de lieu (village : bon marché, sans mailles ; ville : tout ; forge du QG : remise conservée).
## La réparation globale (`Game.repair`) reste inchangée et n'utilise rien de ce fichier.

const SLOTS: Array[String] = ["weapon", "shield", "head", "body"]
const STEPS: Array[float] = [0.25, 0.5, 1.0]
const ARMOR_POINT_PRICE: float = 0.5  ## couronne par point d'armure (comme la réparation globale)

const SHARPEN_COST_RATE: float = 0.04  ## part du prix de l'arme
const SHARPEN_MIN: int = 8
const OIL_COST_RATE: float = 0.03  ## part du prix de l'armure
const OIL_MIN: int = 12

## Forgerons par type de lieu. `price` : coefficient de tarif ; `mail` : travaille les mailles ; `edge` / `oil` : pourcentage
## de bonus ; `combats` : durée du bonus.
const SMITHS: Dictionary = {
	"village": {"n": "forgeron de village", "price": 0.7, "mail": false, "edge": 6, "oil": 10, "combats": 2},
	"city": {"n": "maître forgeron", "price": 1.0, "mail": true, "edge": 10, "oil": 15, "combats": 3},
}
const FORGE_COMBATS_BONUS: int = 1  ## un niveau de forge au QG allonge le bonus ; il permet aussi les mailles au village


static func smith(settlement_kind: String, forge_level: int = 0) -> Dictionary:
	var s: Dictionary = (SMITHS.get(settlement_kind, SMITHS["village"]) as Dictionary).duplicate()
	if forge_level > 0:
		s["mail"] = true
		s["combats"] = int(s["combats"]) + FORGE_COMBATS_BONUS
	return s


# --- État par homme ---

## Dictionnaire d'entretien lu dans une sauvegarde : clés connues, entiers, valeurs positives.
static func clean(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw
	if int(d.get("edge", 0)) > 0 and str(d.get("edge_w", "")) != "":
		out["edge"] = int(d["edge"])
		out["edge_pct"] = clampi(int(d.get("edge_pct", 6)), 1, 50)
		out["edge_w"] = str(d["edge_w"])
	if int(d.get("oil", 0)) > 0 and str(d.get("oil_b", "")) != "":
		out["oil"] = int(d["oil"])
		out["oil_pct"] = clampi(int(d.get("oil_pct", 10)), 1, 50)
		out["oil_b"] = str(d["oil_b"])
	return out


## Multiplicateur de dégâts dû à l'arme aiguisée (1 sans bonus ou si l'arme tenue n'est plus celle qui a été aiguisée).
static func edge_mult(u: Unit) -> float:
	if u.upkeep.is_empty() or int(u.upkeep.get("edge", 0)) <= 0 or str(u.upkeep.get("edge_w", "")) != u.weapon:
		return 1.0
	return 1.0 + float(int(u.upkeep.get("edge_pct", 0))) / 100.0


## Multiplicateur de l'usure d'armure subie (huile) : 1 sans bonus, ou si ce n'est pas le corps / l'armure huilée.
static func oil_mult(u: Unit, head: bool) -> float:
	if head or u.upkeep.is_empty() or int(u.upkeep.get("oil", 0)) <= 0 or str(u.upkeep.get("oil_b", "")) != u.body:
		return 1.0
	return 1.0 - float(int(u.upkeep.get("oil_pct", 0))) / 100.0


## Un combat de plus : les bonus s'usent. À appeler pour chaque homme qui a combattu.
static func tick_battle(u: Unit) -> void:
	if u.upkeep.is_empty():
		return
	for k in ["edge", "oil"]:
		if u.upkeep.has(k):
			u.upkeep[k] = int(u.upkeep[k]) - 1
	u.upkeep = clean(u.upkeep)


static func edge_left(u: Unit) -> int:
	return int(u.upkeep.get("edge", 0)) if edge_mult(u) > 1.0 else 0


static func oil_left(u: Unit) -> int:
	return int(u.upkeep.get("oil", 0)) if oil_mult(u, false) < 1.0 else 0


# --- Aiguiser / huiler ---

static func is_edged_weapon(key: String) -> bool:
	var f: String = Perks.weapon_family(key)
	return f != "" and str(Data.WEAPON_FAMILIES[f]["dmg_type"]) == "tranchant"


static func is_mail(slot: String, key: String) -> bool:
	return Perks.armor_family(slot, key) == "mailles"


## Raison pour laquelle `u` ne peut pas faire aiguiser son arme, "" si c'est possible.
static func why_not_sharpen(u: Unit, sm: Dictionary) -> String:
	if not u.weapon_wears() or not is_edged_weapon(u.weapon):
		return "Seule une arme tranchante (épée, hache) s'aiguise."
	if u.weapon_dur_now() <= 0:
		return "L'arme est ébréchée : il faut d'abord la réparer."
	if int(u.upkeep.get("edge", 0)) >= int(sm["combats"]) and str(u.upkeep.get("edge_w", "")) == u.weapon and int(u.upkeep.get("edge_pct", 0)) >= int(sm["edge"]):
		return "L'arme est déjà fraîchement aiguisée."
	return ""


static func why_not_oil(u: Unit, sm: Dictionary) -> String:
	if u.body == "none" or not is_mail("body", u.body):
		return "Seul un haubert de mailles s'huile."
	if not bool(sm["mail"]):
		return "Le forgeron du village ne travaille pas les mailles."
	if u.arm_b <= 0:
		return "Le haubert est détruit : il faut d'abord le réparer."
	if int(u.upkeep.get("oil", 0)) >= int(sm["combats"]) and str(u.upkeep.get("oil_b", "")) == u.body and int(u.upkeep.get("oil_pct", 0)) >= int(sm["oil"]):
		return "Le haubert est déjà fraîchement huilé."
	return ""


static func sharpen_cost(u: Unit, sm: Dictionary, mult: float = 1.0) -> int:
	var price: int = Loot.base_price(Loot.weapon_item(u))
	return int(ceil(float(maxi(SHARPEN_MIN, int(round(float(price) * SHARPEN_COST_RATE)))) * float(sm["price"]) * mult))


static func oil_cost(u: Unit, sm: Dictionary, mult: float = 1.0) -> int:
	var price: int = Loot.base_price(Loot.body_item(u))
	return int(ceil(float(maxi(OIL_MIN, int(round(float(price) * OIL_COST_RATE)))) * float(sm["price"]) * mult))


static func apply_sharpen(u: Unit, sm: Dictionary) -> void:
	u.upkeep["edge"] = int(sm["combats"])
	u.upkeep["edge_pct"] = int(sm["edge"])
	u.upkeep["edge_w"] = u.weapon


static func apply_oil(u: Unit, sm: Dictionary) -> void:
	u.upkeep["oil"] = int(sm["combats"])
	u.upkeep["oil_pct"] = int(sm["oil"])
	u.upkeep["oil_b"] = u.body


# --- Réparation pièce par pièce ---

static func slot_label(slot: String) -> String:
	match slot:
		"weapon":
			return "Arme"
		"shield":
			return "Bouclier"
		"head":
			return "Casque"
	return "Armure"


## État d'une pièce portée : {"have", "cur", "max", "key"}.
static func piece(u: Unit, slot: String) -> Dictionary:
	match slot:
		"weapon":
			return {"have": u.weapon_wears(), "cur": u.weapon_dur_now(), "max": u.weapon_dur_max(), "key": u.weapon}
		"shield":
			return {"have": u.shield, "cur": u.shield_dur_now(), "max": u.shield_dur_max(), "key": ""}
		"head":
			return {"have": u.head != "none", "cur": u.arm_h, "max": u.head_armor_max(), "key": u.head}
	return {"have": u.body != "none", "cur": u.arm_b, "max": u.body_armor_max(), "key": u.body}


static func missing(u: Unit, slot: String) -> int:
	var p: Dictionary = piece(u, slot)
	return maxi(0, int(p["max"]) - int(p["cur"])) if bool(p["have"]) else 0


## Points rendus par un palier (25 / 50 / 100 % du maximum de la pièce, dans la limite de ce qui manque).
static func step_points(u: Unit, slot: String, step: float) -> int:
	var miss: int = missing(u, slot)
	if miss <= 0:
		return 0
	if step >= 1.0:
		return miss
	return mini(miss, maxi(1, int(ceil(step * float(piece(u, slot)["max"])))))


## Prix d'un point de réparation (avant coefficients).
static func point_price(u: Unit, slot: String) -> float:
	match slot:
		"head", "body":
			return ARMOR_POINT_PRICE
		"weapon":
			return float(Loot.base_price(Loot.weapon_item(u))) * Data.REPAIR_GEAR_RATE / float(maxi(1, u.weapon_dur_max()))
	return float(Loot.base_price(Loot.shield_item(u))) * Data.REPAIR_GEAR_RATE / float(maxi(1, u.shield_dur_max()))


## Coût d'un palier : proportionnel aux points rendus, × tarif du forgeron × `mult` (forge du QG, talent Armurier).
static func step_cost(u: Unit, slot: String, step: float, sm: Dictionary, mult: float = 1.0) -> int:
	var pts: int = step_points(u, slot, step)
	return 0 if pts <= 0 else int(ceil(float(pts) * point_price(u, slot) * float(sm["price"]) * mult))


## Raison pour laquelle ce palier est impossible, "" sinon.
static func why_not_repair(u: Unit, slot: String, sm: Dictionary) -> String:
	if not bool(piece(u, slot)["have"]):
		return "Rien à réparer."
	if missing(u, slot) <= 0:
		return "Déjà en bon état."
	if (slot == "head" or slot == "body") and is_mail(slot, str(piece(u, slot)["key"])) and not bool(sm["mail"]):
		return "Le forgeron du village ne travaille pas les mailles."
	return ""


## Rend `step_points` à la pièce (aucun contrôle d'argent). Renvoie les points rendus.
static func apply_repair(u: Unit, slot: String, step: float) -> int:
	var pts: int = step_points(u, slot, step)
	if pts <= 0:
		return 0
	match slot:
		"weapon":
			var nw: int = u.weapon_dur_now() + pts
			u.weapon_dur = -1 if nw >= u.weapon_dur_max() else nw
		"shield":
			var ns: int = u.shield_dur_now() + pts
			u.shield_dur = -1 if ns >= u.shield_dur_max() else ns
		"head":
			u.arm_h = mini(u.head_armor_max(), u.arm_h + pts)
		"body":
			u.arm_b = mini(u.body_armor_max(), u.arm_b + pts)
	return pts
