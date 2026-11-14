class_name DamageTypes
extends RefCounted
## Type de dégât d'une arme (tranchant / contondant / perforant) et indication d'efficacité contre une cible.
## Source du type : champ `dmg_type` de l'arme dans Data.WPN, sinon la famille (`Data.WEAPON_FAMILIES[...]["dmg_type"]`), sinon
## MaterialsData.WEAPON_TYPE_FALLBACK, sinon "" (neutre). Les armes uniques (u_*) héritent de la famille de leur modèle.

const GOOD_AT: float = 1.06  ## moyenne (arm, ign) à partir de laquelle on dit « efficace »
const POOR_AT: float = 0.94  ## moyenne en dessous de laquelle on dit « peu efficace »


static func of_weapon(key: String) -> String:
	var w: Dictionary = Data.WPN.get(key, {})
	if w.has("dmg_type"):
		return str(w["dmg_type"])
	var f: String = Perks.weapon_family(key)
	if f != "":
		return str(Data.WEAPON_FAMILIES[f].get("dmg_type", ""))
	return str(MaterialsData.WEAPON_TYPE_FALLBACK.get(key, ""))


static func of_unit(a: Unit) -> String:
	return of_weapon(a.weapon)


static func label(dmg_type: String) -> String:
	return str(MaterialsData.TYPE_NAMES.get(dmg_type, ""))


## Multiplicateurs {"arm", "ign"} de l'arme de `a` contre la zone touchée (tête ou corps) de `d`.
static func zone_mods(a: Unit, d: Unit, head: bool) -> Dictionary:
	return Materials.mods(Materials.of_unit(d, head), of_unit(a))


## Efficacité de l'arme de `a` contre `d` : {"type": "Tranchant", "verdict": "efficace" | "peu efficace" | "normal" | "", "material": "Mailles",
## "score": float}. On regarde le corps (75 % des coups) puis la tête si le corps est nu. `verdict` "" : cible sans armure.
static func versus(a: Unit, d: Unit) -> Dictionary:
	var t: String = of_unit(a)
	var out: Dictionary = {"type": label(t), "verdict": "", "material": "", "score": 1.0}
	var head: bool = d.arm_b <= 0
	var arm: int = d.arm_h if head else d.arm_b
	if arm <= 0:
		return out
	var m: Dictionary = zone_mods(a, d, head)
	var score: float = (float(m["arm"]) + float(m["ign"])) * 0.5
	out["score"] = score
	out["material"] = Materials.label(Materials.of_unit(d, head))
	out["verdict"] = "efficace" if score >= GOOD_AT else ("peu efficace" if score <= POOR_AT else "normal")
	return out


## Ligne de texte pour l'info-bulle : « Tranchant · peu efficace contre Mailles ».
static func hint_line(a: Unit, d: Unit) -> String:
	var v: Dictionary = versus(a, d)
	if str(v["type"]) == "":
		return ""
	if str(v["verdict"]) == "" or str(v["verdict"]) == "normal":
		return str(v["type"]) if str(v["verdict"]) == "" else "%s · normal contre %s" % [v["type"], str(v["material"]).to_lower()]
	return "%s · %s contre %s" % [v["type"], v["verdict"], str(v["material"]).to_lower()]


## « efficace contre plates, mailles ; peu efficace contre … » pour la fiche d'une arme de ce type.
static func strengths_line(dmg_type: String) -> String:
	var good: PackedStringArray = []
	var poor: PackedStringArray = []
	for mat in ["tissu", "cuir", "cuir_cloute", "matelasse", "mailles", "ecailles", "plates"]:
		var m: Dictionary = Materials.mods(mat, dmg_type)
		var score: float = (float(m["arm"]) + float(m["ign"])) * 0.5
		if score >= GOOD_AT:
			good.append(Materials.label(mat).to_lower())
		elif score <= POOR_AT:
			poor.append(Materials.label(mat).to_lower())
	var parts: PackedStringArray = []
	if not good.is_empty():
		parts.append("efficace contre " + ", ".join(good))
	if not poor.is_empty():
		parts.append("peu efficace contre " + ", ".join(poor))
	return " ; ".join(parts) if not parts.is_empty() else "sans point faible marqué"
