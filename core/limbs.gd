class_name Limbs
extends RefCounted
## Pièces d'armure supplémentaires : emplacements « Bras » (`arms`) et « Jambes » (`legs`), en plus de la tête et du corps.
## Logique pure (aléa injecté). Chaque pièce a son armure courante / maximale, son poids, son prix, son matériau, sa famille
## d'armure (Data.ARMOR_FAMILIES) et son grade (ItemGrade). Aucune pièce par défaut ("none") : un homme qui n'en porte pas se bat
## exactement comme avant (voir `roll_zone`, qui ne consomme aucun tirage dans ce cas).
##
## Champs de `Unit` : `arms` / `legs` (clé de Data.ARMS / Data.LEGS), `arm_a` / `arm_l` (armure courante), `arms_q` / `legs_q` (grade).

const SLOTS: Array[String] = ["arms", "legs"]
const LABELS: Dictionary = {"arms": "Bras", "legs": "Jambes"}
const CUR_FIELD: Dictionary = {"arms": "arm_a", "legs": "arm_l"}
const Q_FIELD: Dictionary = {"arms": "arms_q", "legs": "legs_q"}
const ZONE_VERBS: Dictionary = {"head": " à la tête", "body": "", "arms": " au bras", "legs": " à la jambe"}


static func is_slot(slot: String) -> bool:
	return SLOTS.has(slot)


static func table(slot: String) -> Dictionary:
	return Data.ARMS if slot == "arms" else Data.LEGS


static func label(slot: String) -> String:
	return str(LABELS.get(slot, slot))


## Clé de la pièce portée à l'emplacement.
static func key_of(u: Unit, slot: String) -> String:
	return u.arms if slot == "arms" else u.legs


static func worn(u: Unit, slot: String) -> bool:
	var k: String = key_of(u, slot)
	return k != "none" and table(slot).has(k)


static func any_worn(u: Unit) -> bool:
	return worn(u, "arms") or worn(u, "legs")


static func cur(u: Unit, slot: String) -> int:
	return u.arm_a if slot == "arms" else u.arm_l


static func set_cur(u: Unit, slot: String, v: int) -> void:
	if slot == "arms":
		u.arm_a = v
	else:
		u.arm_l = v


static func grade(u: Unit, slot: String) -> int:
	return u.arms_q if slot == "arms" else u.legs_q


static func set_grade(u: Unit, slot: String, q: int) -> void:
	if slot == "arms":
		u.arms_q = q
	else:
		u.legs_q = q


static func weight_of(slot: String, key: String) -> int:
	return int(table(slot).get(key, {}).get("w", 0))


## Poids des pièces de bras et de jambes (0 sans pièce).
static func weight(u: Unit) -> int:
	if u.arms == "none" and u.legs == "none":
		return 0  ## chemin rapide : weight() est appelé très souvent (déplacements, initiative)
	return weight_of("arms", u.arms) + weight_of("legs", u.legs)


## Armure maximale de la pièce portée (grade compris ; 0 sans pièce).
static func armor_max(u: Unit, slot: String) -> int:
	var a: int = int(table(slot).get(key_of(u, slot), {}).get("a", 0))
	var q: int = grade(u, slot)
	return a if q == 0 else int(round(float(a) * ItemGrade.armor_mult(q)))


static func total_cur(u: Unit) -> int:
	return (u.arm_a if worn(u, "arms") else 0) + (u.arm_l if worn(u, "legs") else 0)


static func total_max(u: Unit) -> int:
	return armor_max(u, "arms") + armor_max(u, "legs")


## La pièce portée sous forme d'objet de Loot ({} sans pièce), avec son grade et son armure actuelle.
static func piece_item(u: Unit, slot: String) -> Dictionary:
	if not worn(u, slot):
		return {}
	return Loot.with_armor(ItemGrade.with_grade(Loot.item(slot, key_of(u, slot)), grade(u, slot)), cur(u, slot))


## Zone touchée par un coup qui n'est pas à la tête : "body" (par défaut), "arms" ou "legs". Un tirage de plus UNIQUEMENT si l'homme
## porte au moins une pièce ; une zone sans pièce retombe sur le corps.
static func roll_zone(d: Unit, rng: RandomNumberGenerator) -> String:
	if not any_worn(d):
		return "body"
	var x: float = rng.randf()
	if x < Data.LIMB_HIT_ARMS:
		return "arms" if worn(d, "arms") else "body"
	if x < Data.LIMB_HIT_ARMS + Data.LIMB_HIT_LEGS:
		return "legs" if worn(d, "legs") else "body"
	return "body"


## Armure courante de la zone touchée ("head", "body", "arms", "legs").
static func zone_armor(d: Unit, zone: String) -> int:
	match zone:
		"head":
			return d.arm_h
		"arms":
			return d.arm_a
		"legs":
			return d.arm_l
	return d.arm_b


## Retire `n` points d'armure à la zone touchée.
static func wear_zone(d: Unit, zone: String, n: int) -> void:
	match zone:
		"head":
			d.arm_h = maxi(0, d.arm_h - n)
		"arms":
			d.arm_a = maxi(0, d.arm_a - n)
		"legs":
			d.arm_l = maxi(0, d.arm_l - n)
		_:
			d.arm_b = maxi(0, d.arm_b - n)


static func zone_phrase(zone: String) -> String:
	return str(ZONE_VERBS.get(zone, ""))


# --- Sauvegarde : clés absentes = pas de pièce ---

static func write_unit(u: Unit, d: Dictionary) -> void:
	for s in SLOTS:
		if worn(u, s):
			d[s] = key_of(u, s)
			d[CUR_FIELD[s]] = cur(u, s)
			if grade(u, s) != 0:
				d[Q_FIELD[s]] = grade(u, s)


static func read_unit(u: Unit, d: Dictionary) -> void:
	for s in SLOTS:
		var k: String = str(d.get(s, "none"))
		if not table(s).has(k):
			k = "none"
		if s == "arms":
			u.arms = k
		else:
			u.legs = k
		set_grade(u, s, ItemGrade.clamp_grade(int(d.get(Q_FIELD[s], 0))) if k != "none" else 0)
		set_cur(u, s, clampi(int(d.get(CUR_FIELD[s], armor_max(u, s))), 0, armor_max(u, s)) if k != "none" else 0)


## Remplit l'armure courante de toutes les pièces portées (renvoi à neuf).
static func restore_all(u: Unit) -> void:
	for s in SLOTS:
		set_cur(u, s, armor_max(u, s))
