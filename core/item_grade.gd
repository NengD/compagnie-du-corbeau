class_name ItemGrade
extends RefCounted
## Qualité des objets (armes, boucliers, casques, armures) : 4 grades. Logique pure, aléa injecté.
##
## Un objet de `Loot` porte la clé facultative "q" : -1 grossière, 1 fine, 2 maîtresse ; absente (ou 0) = correcte = comportement
## d'origine. Un homme porte `weapon_q / shield_q / head_q / body_q` (même valeurs). Les objets uniques (`Data.UNIQUES`) et les
## outils n'ont pas de grade. Effets modestes : dégâts (armes), durabilité (armes, boucliers), armure maximale (casques,
## armures) et prix (tout).

const ROUGH: int = -1
const OK: int = 0
const FINE: int = 1
const MASTER: int = 2
const GRADES: Array[int] = [-1, 0, 1, 2]

const NAMES: Dictionary = {-1: "Grossière", 0: "Correcte", 1: "Fine", 2: "Maîtresse"}
const COLORS: Dictionary = {-1: Color("a89a86"), 0: Color("d8ccb0"), 1: Color("6fb8dc"), 2: Color("c58af0")}

## Multiplicateurs par grade (clé = grade).
const DMG_MULT: Dictionary = {-1: 0.92, 0: 1.0, 1: 1.07, 2: 1.14}  ## dégâts d'une arme
const DUR_MULT: Dictionary = {-1: 0.8, 0: 1.0, 1: 1.25, 2: 1.5}  ## durabilité d'une arme ou d'un bouclier
const ARMOR_MULT: Dictionary = {-1: 0.9, 0: 1.0, 1: 1.08, 2: 1.16}  ## armure maximale d'un casque ou d'une armure
const PRICE_MULT: Dictionary = {-1: 0.6, 0: 1.0, 1: 1.5, 2: 2.3}  ## prix de base (achat, revente, réparation)

## Poids de tirage de base (somme libre) ; `bias` (0 à 1) déplace des grossières vers les fines et les maîtresses.
const BASE_WEIGHTS: Dictionary = {-1: 20.0, 0: 62.0, 1: 15.0, 2: 3.0}
const BIAS_FINE: float = 3.0  ## le poids des fines est multiplié par 1 + BIAS_FINE × bias
const BIAS_MASTER: float = 6.0
const BIAS_CITY: float = 0.25  ## type de lieu : un grand bourg a plus de fin / maîtresse
const BIAS_VILLAGE: float = 0.0
const BIAS_LEADER: float = 0.2  ## butin d'un chef ennemi
const BIAS_CONTRACT: float = 0.25  ## objet rare d'un contrat gagné, par point de danger

const FEMININE: Array[String] = ["fourche", "lance", "hache", "masse", "epee", "arbalete", "hallebarde", "tunique", "brigandine"]
const PLURAL: Array[String] = ["javelot", "brassards_cuir", "brassards_orques"]
## Pièces féminines au pluriel (« Manchettes fines »).
const FEM_PLURAL: Array[String] = ["manchettes", "manicles_cloutees", "manches_mailles", "epaulieres_fer", "bandes_toile", "jambieres_cuir",
	"guetres_cloutees", "chausses_mailles", "greves_fer", "greves_genouilleres", "jambieres_orques", "chausses_rouillees", "bandelettes_rouillees"]


static func clamp_grade(q: int) -> int:
	return clampi(q, ROUGH, MASTER)


## Cet objet peut-il avoir un grade ? (armes, boucliers, casques, armures payantes ; ni outils, ni uniques.)
static func gradable(it: Dictionary) -> bool:
	var k: String = str(it.get("kind", ""))
	if k != "weapon" and k != "shield" and k != "head" and k != "body" and k != "arms" and k != "legs":
		return false
	if Data.UNIQUES.has(str(it.get("key", ""))):
		return false
	return Loot.is_valid(it) and int(Loot.data_of(it).get("price", 0)) > 0


## Grade d'un objet (0 si absent ou hors bornes).
static func of(it: Dictionary) -> int:
	return clamp_grade(int(it.get("q", 0)))


## Copie de `it` marquée du grade `q` (la clé "q" n'existe que si le grade n'est pas « correcte »).
static func with_grade(it: Dictionary, q: int) -> Dictionary:
	if q == OK or not gradable(it):
		it.erase("q")
	else:
		it["q"] = clamp_grade(q)
	return it


static func dmg_mult(q: int) -> float:
	return float(DMG_MULT[clamp_grade(q)])


static func dur_mult(q: int) -> float:
	return float(DUR_MULT[clamp_grade(q)])


static func armor_mult(q: int) -> float:
	return float(ARMOR_MULT[clamp_grade(q)])


static func price_mult(q: int) -> float:
	return float(PRICE_MULT[clamp_grade(q)])


static func name_of(q: int) -> String:
	return str(NAMES[clamp_grade(q)])


static func color_of(q: int) -> Color:
	return COLORS[clamp_grade(q)]


## Poids de tirage pour un biais donné.
static func weights(bias: float) -> Dictionary:
	var b: float = clampf(bias, 0.0, 1.0)
	return {-1: float(BASE_WEIGHTS[-1]) * (1.0 - b), 0: float(BASE_WEIGHTS[0]), 1: float(BASE_WEIGHTS[1]) * (1.0 + BIAS_FINE * b), 2: float(BASE_WEIGHTS[2]) * (1.0 + BIAS_MASTER * b)}


## Tire un grade. `min_grade` : plancher (un bonus de contrat n'est jamais grossier).
static func roll(rng: RandomNumberGenerator, bias: float = 0.0, min_grade: int = ROUGH) -> int:
	var w: Dictionary = weights(bias)
	var total: float = 0.0
	for g in GRADES:
		if g >= min_grade:
			total += float(w[g])
	var x: float = rng.randf() * total
	for g in GRADES:
		if g < min_grade:
			continue
		x -= float(w[g])
		if x < 0.0:
			return g
	return clampi(OK, min_grade, MASTER)


## Tire et applique un grade à `it` si l'objet en admet un. Renvoie `it`.
static func roll_item(it: Dictionary, rng: RandomNumberGenerator, bias: float = 0.0, min_grade: int = ROUGH) -> Dictionary:
	if gradable(it):
		with_grade(it, roll(rng, bias, min_grade))
	return it


## Biais de tirage d'un type de lieu ("village" | "city").
static func place_bias(settlement_kind: String) -> float:
	return BIAS_CITY if settlement_kind == "city" else BIAS_VILLAGE


# --- Noms ---

## « Hache » + fine -> « Hache fine » ; maîtresse -> « Hache de maître » ; grossière -> « Hache grossière ». Accord selon l'objet.
static func graded_name(base: String, key: String, q: int) -> String:
	q = clamp_grade(q)
	if q == OK:
		return base
	var fem: bool = FEMININE.has(key)
	var plural: bool = PLURAL.has(key)
	var fem_pl: bool = FEM_PLURAL.has(key)
	match q:
		ROUGH:
			return "%s %s" % [base, "grossières" if fem_pl else ("grossiers" if plural else ("grossière" if fem else "grossier"))]
		FINE:
			return "%s %s" % [base, "fines" if fem_pl else ("fins" if plural else ("fine" if fem else "fin"))]
	return "%s de maître" % base


## Ligne d'infobulle : grade et effets (« Qualité fine : dégâts +7 %, durabilité +25 %, valeur ×1,5 »).
static func describe(it: Dictionary) -> String:
	var q: int = of(it)
	if q == OK:
		return ""
	var parts: Array[String] = []
	match str(it.get("kind", "")):
		"weapon":
			parts.append("dégâts %+d %%" % roundi((dmg_mult(q) - 1.0) * 100.0))
			parts.append("durabilité %+d %%" % roundi((dur_mult(q) - 1.0) * 100.0))
		"shield":
			parts.append("durabilité %+d %%" % roundi((dur_mult(q) - 1.0) * 100.0))
		"head", "body", "arms", "legs":
			parts.append("armure %+d %%" % roundi((armor_mult(q) - 1.0) * 100.0))
	parts.append("valeur ×%s" % str(price_mult(q)).replace(".", ","))
	return "Qualité %s : %s" % [name_of(q).to_lower(), ", ".join(parts)]


# --- Équipement d'un homme : (dé)sérialisation tolérante ---

const UNIT_KEYS: Array[String] = ["weapon_q", "shield_q", "head_q", "body_q"]


static func write_unit(u: Unit, d: Dictionary) -> void:
	for k in UNIT_KEYS:
		if int(u.get(k)) != OK:
			d[k] = int(u.get(k))
	if not u.upkeep.is_empty():
		d["upkeep"] = u.upkeep.duplicate(true)


static func read_unit(u: Unit, d: Dictionary) -> void:
	for k in UNIT_KEYS:
		u.set(k, clamp_grade(int(d.get(k, 0))))
	u.upkeep = Upkeep.clean(d.get("upkeep", {}))
