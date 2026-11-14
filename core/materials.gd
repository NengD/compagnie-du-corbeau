class_name Materials
extends RefCounted
## Matériau d'une pièce d'armure et effet du type de dégât sur elle (tables : core/materials_data.gd). Fonctions pures.


## Matériau de la pièce `key` de l'emplacement `slot` ("head" | "body" | "arms" | "legs"). "nu" si aucune armure.
static func of(slot: String, key: String) -> String:
	var table: Dictionary = Data.HEAD if slot == "head" else (Data.BODY if slot == "body" else Limbs.table(slot))
	if key == "none" or not table.has(key):
		return "nu"
	return of_entry(slot, key, table[key])


## Même chose à partir de la fiche `d` de la pièce (champ « mat » > table par clé > valeur d'armure).
static func of_entry(slot: String, key: String, d: Dictionary) -> String:
	if d.has("mat") and MaterialsData.MATRIX.has(str(d["mat"])):
		return str(d["mat"])
	var by_key: Dictionary = MaterialsData.HEAD_MATERIAL if slot == "head" else MaterialsData.BODY_MATERIAL
	if by_key.has(key):
		return str(by_key[key])
	var a: int = int(d.get("a", 0))
	if a <= 0:
		return "nu"
	for row in MaterialsData.DEFAULT_BY_ARMOR:
		if a <= int(row[0]):
			return str(row[1])
	return "plates"


static func of_unit(u: Unit, head: bool) -> String:
	return of("head", u.head) if head else of("body", u.body)


## Matériau de la zone touchée ("head" | "body" | "arms" | "legs").
static func of_zone(u: Unit, zone: String) -> String:
	match zone:
		"head":
			return of("head", u.head)
		"arms":
			return of("arms", u.arms)
		"legs":
			return of("legs", u.legs)
	return of("body", u.body)


static func label(material: String) -> String:
	return str(MaterialsData.MATERIAL_NAMES.get(material, material))


## Multiplicateurs {"arm", "ign"} du type de dégât `dmg_type` contre le matériau ; neutres si l'un des deux est inconnu. Toujours bornés.
static func mods(material: String, dmg_type: String) -> Dictionary:
	var row: Dictionary = MaterialsData.MATRIX.get(material, {})
	var m: Dictionary = row.get(dmg_type, {})
	return {
		"arm": clampf(float(m.get("arm", 1.0)), MaterialsData.MULT_MIN, MaterialsData.MULT_MAX),
		"ign": clampf(float(m.get("ign", 1.0)), MaterialsData.MULT_MIN, MaterialsData.MULT_MAX),
	}
