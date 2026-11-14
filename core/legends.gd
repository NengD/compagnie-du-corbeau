class_name Legends
extends RefCounted
## Armes à histoire : un compteur de victimes suit l'arme (clé facultative "kills" de l'objet, `Unit.weapon_kills` une fois portée) et
## débloque des bonus à seuils. Les bonus passent par `Perks.weapon_field` (mêmes champs que les maîtrises : hit, ign, dmg, arm, ammo).
## Logique pure : aucune scène. Les statistiques de base des armes vivent dans Data.WPN, leur légende dans Data.UNIQUES.

## clé d'arme -> paliers. `kills` : victimes requises ; `wp` : champs ajoutés (hit, ign : sommés ; dmg, arm : multiplicateurs, 1,10 = +10 %) ; `t` : texte.
const TABLE: Dictionary = {
	"u_dague_veuve": [
		{"kills": 8, "wp": {"hit": 5}, "t": "+5 % au toucher"},
		{"kills": 20, "wp": {"ign": 0.10}, "t": "traverse 10 points d'armure de plus"},
		{"kills": 40, "wp": {"dmg": 1.10}, "t": "+10 % de dégâts"},
	],
	"u_marteau_forgeron": [
		{"kills": 10, "wp": {"arm": 1.10}, "t": "dégâts d'armure +10 %"},
		{"kills": 25, "wp": {"hit": 5}, "t": "+5 % au toucher"},
		{"kills": 50, "wp": {"ign": 0.08}, "t": "traverse 8 points d'armure de plus"},
	],
	"u_hache_aurore": [
		{"kills": 10, "wp": {"arm": 1.10}, "t": "dégâts d'armure +10 %"},
		{"kills": 25, "wp": {"dmg": 1.08}, "t": "+8 % de dégâts"},
		{"kills": 50, "wp": {"hit": 5}, "t": "+5 % au toucher"},
	],
	"u_arc_mirelune": [
		{"kills": 10, "wp": {"hit": 5}, "t": "+5 % au toucher"},
		{"kills": 25, "wp": {"ign": 0.05}, "t": "traverse 5 points d'armure de plus"},
		{"kills": 50, "wp": {"dmg": 1.08}, "t": "+8 % de dégâts"},
	],
	"u_pique_gardien": [
		{"kills": 10, "wp": {"hit": 5}, "t": "+5 % au toucher"},
		{"kills": 25, "wp": {"dmg": 1.08}, "t": "+8 % de dégâts"},
		{"kills": 50, "wp": {"arm": 1.10}, "t": "dégâts d'armure +10 %"},
	],
}


static func tracks(weapon_key: String) -> bool:
	return TABLE.has(weapon_key)


static func steps(weapon_key: String) -> Array:
	return TABLE.get(weapon_key, [])


## Victimes de l'arme portée par un objet (0 si la clé est absente ou si l'arme ne compte pas).
static func kills_of(it: Dictionary) -> int:
	if str(it.get("kind", "")) != "weapon" or not tracks(str(it.get("key", ""))):
		return 0
	return maxi(0, int(it.get("kills", 0)))


## Marque l'objet avec son compteur (n'ajoute "kills" que pour une arme à histoire déjà meurtrière).
static func with_kills(it: Dictionary, n: int) -> Dictionary:
	if n > 0 and str(it.get("kind", "")) == "weapon" and tracks(str(it.get("key", ""))):
		it["kills"] = n
	return it


## Paliers atteints avec `kills` victimes.
static func reached(weapon_key: String, kills: int) -> int:
	var n: int = 0
	for s in steps(weapon_key):
		if kills >= int(s["kills"]):
			n += 1
	return n


## Valeur cumulée d'un champ pour l'arme tenue par `u` (1.0 ou 0.0 sans effet, comme Perks.weapon_field).
static func field(u: Unit, field_name: String) -> float:
	var mult: bool = field_name == "dmg" or field_name == "arm"
	var v: float = 1.0 if mult else 0.0
	if not tracks(u.weapon):
		return v
	for s in steps(u.weapon):
		if u.weapon_kills < int(s["kills"]):
			break
		var wp: Dictionary = s["wp"]
		if not wp.has(field_name):
			continue
		if mult:
			v *= float(wp[field_name])
		else:
			v += float(wp[field_name])
	return v


## Lignes à ajouter à l'infobulle d'un objet : compteur, bonus acquis, prochain palier. Vide pour tout autre objet.
static func tooltip_lines(it: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var key: String = str(it.get("key", ""))
	if str(it.get("kind", "")) != "weapon" or not tracks(key):
		return out
	var k: int = kills_of(it)
	out.append("Victimes de l'arme : %d" % k)
	var next_step: Dictionary = {}
	for s in steps(key):
		if k >= int(s["kills"]):
			out.append("  ✔ %d victimes : %s" % [int(s["kills"]), str(s["t"])])
		elif next_step.is_empty():
			next_step = s
	if not next_step.is_empty():
		out.append("  Prochain palier à %d victimes : %s" % [int(next_step["kills"]), str(next_step["t"])])
	else:
		out.append("  Légende accomplie : tous les paliers sont atteints.")
	return out
