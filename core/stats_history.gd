class_name StatsHistory
extends RefCounted
## Historique de campagne pour les courbes : un point par jour (et à chaque fait marquant), borné à MAX_POINTS
## (au-delà, les plus anciens points sont éclaircis un sur deux : la forme de toute la campagne est conservée).
## État dans `extras["stats_history"]` : {"pts": [[jour, or, renom, hommes, victoires, défaites, tombés, vivres], ...], "by_type": {type: [victoires, défaites]}}.
## Logique pure.

const KEY: String = "stats_history"
const MAX_POINTS: int = 400
const COLS: Array[String] = ["day", "gold", "renown", "men", "wins", "losses", "fallen", "food"]

## Types de combat regroupés pour l'histogramme : clé -> libellé.
const TYPE_LABELS: Dictionary = {
	"kill": "Éliminer", "hunt": "Chasses", "escort": "Escortes", "delivery": "Livraisons", "assault": "Assauts", "ambush": "Embuscades", "party": "Bandes errantes", "other": "Autres",
}


static func _is_clean(raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY or typeof(raw.get("pts")) != TYPE_ARRAY or typeof(raw.get("by_type")) != TYPE_DICTIONARY or (raw["pts"] as Array).size() > MAX_POINTS:
		return false
	for p in raw["pts"]:
		if typeof(p) != TYPE_ARRAY or (p as Array).size() != COLS.size() or typeof(p[0]) != TYPE_INT or typeof(p[COLS.size() - 1]) != TYPE_INT:
			return false
	for k in raw["by_type"]:
		var v: Variant = raw["by_type"][k]
		if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2 or typeof(v[0]) != TYPE_INT or typeof(v[1]) != TYPE_INT:
			return false
	return true


## L'objet renvoyé est celui conservé dans `extras` ; une valeur absente, abîmée ou lue dans du JSON est d'abord remise en forme.
static func state(extras: Dictionary) -> Dictionary:
	if _is_clean(extras.get(KEY)):
		return extras[KEY]
	var raw: Variant = extras.get(KEY, {})
	var st: Dictionary = {"pts": [], "by_type": {}}
	if typeof(raw) == TYPE_DICTIONARY:
		var pts: Variant = (raw as Dictionary).get("pts", [])
		if typeof(pts) == TYPE_ARRAY:
			for p in pts:
				if typeof(p) == TYPE_ARRAY and (p as Array).size() >= COLS.size():
					var row: Array = []
					for i in COLS.size():
						row.append(int(p[i]))
					(st["pts"] as Array).append(row)
		var bt: Variant = (raw as Dictionary).get("by_type", {})
		if typeof(bt) == TYPE_DICTIONARY:
			for k in bt:
				if typeof(bt[k]) == TYPE_ARRAY and (bt[k] as Array).size() >= 2:
					st["by_type"][str(k)] = [int(bt[k][0]), int(bt[k][1])]
	while (st["pts"] as Array).size() > MAX_POINTS:
		thin(st["pts"])
	extras[KEY] = st
	return st


## Éclaircit la moitié la plus ancienne (un point sur deux), garde la récente et le tout dernier point.
static func thin(pts: Array) -> void:
	var half: int = pts.size() / 2
	var out: Array = []
	for i in half:
		if i % 2 == 0:
			out.append(pts[i])
	for i in range(half, pts.size()):
		out.append(pts[i])
	pts.clear()
	pts.append_array(out)


## Enregistre l'état du jour `day` (remplace le point du même jour). `v` : {gold, renown, men, wins, losses, fallen, food}.
static func record(extras: Dictionary, day: int, v: Dictionary) -> void:
	var st: Dictionary = state(extras)
	var pts: Array = st["pts"]
	var row: Array = [day, int(v.get("gold", 0)), int(v.get("renown", 0)), int(v.get("men", 0)), int(v.get("wins", 0)), int(v.get("losses", 0)), int(v.get("fallen", 0)), int(v.get("food", 0))]
	if not pts.is_empty() and int((pts[pts.size() - 1] as Array)[0]) == day:
		pts[pts.size() - 1] = row
	else:
		pts.append(row)
	while pts.size() > MAX_POINTS:
		thin(pts)


## Clé de regroupement d'un combat pour l'histogramme, d'après son contrat.
static func type_of(contract: Dictionary) -> String:
	var kind: String = str(contract.get("kind", "contract"))
	var k: String = str(contract.get("type_contract", "kill")) if kind == "contract" else kind
	return k if TYPE_LABELS.has(k) else "other"


static func record_battle(extras: Dictionary, contract: Dictionary, win: bool) -> void:
	var st: Dictionary = state(extras)
	var k: String = type_of(contract)
	var cur: Array = st["by_type"].get(k, [0, 0])
	cur[0 if win else 1] = int(cur[0 if win else 1]) + 1
	st["by_type"][k] = cur


## Valeurs d'une colonne (nom de COLS) : [[jour, valeur], ...].
static func series(extras: Dictionary, col: String) -> Array:
	var i: int = COLS.find(col)
	var out: Array = []
	if i < 0:
		return out
	for p in state(extras)["pts"]:
		out.append([int(p[0]), int(p[i])])
	return out


## Types ayant au moins un combat : [[clé, libellé, victoires, défaites]], les plus fréquents d'abord.
static func by_type(extras: Dictionary) -> Array:
	var out: Array = []
	var bt: Dictionary = state(extras)["by_type"]
	for k in bt:
		out.append([str(k), str(TYPE_LABELS.get(str(k), "Autres")), int(bt[k][0]), int(bt[k][1])])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) + int(a[3]) > int(b[2]) + int(b[3]))
	return out


## Résumé de campagne : lignes de texte (jours, victoires, pertes, or, renom…).
static func summary(extras: Dictionary, stats: Dictionary, day: int, gold: int, renown: int, men: int) -> Array:
	var wins: int = int(stats.get("battles_won", 0))
	var losses: int = int(stats.get("battles_lost", 0)) + int(stats.get("retreats", 0))
	var lines: Array = []
	lines.append("Jour %d · %d hommes · %d couronnes · renom %d" % [day, men, gold, renown])
	lines.append("%d bataille%s gagnée%s, %d perdue%s ou fuie%s ; %d ennemis abattus" % [wins, "s" if wins > 1 else "", "s" if wins > 1 else "", losses, "s" if losses > 1 else "", "s" if losses > 1 else "", int(stats.get("kills", 0))])
	var fallen: int = int(stats.get("men_fallen", 0))
	lines.append("%d homme%s tombé%s, %d engagé%s" % [fallen, "s" if fallen > 1 else "", "s" if fallen > 1 else "", int(stats.get("men_hired", 0)), "s" if int(stats.get("men_hired", 0)) > 1 else ""])
	var pts: Array = state(extras)["pts"]
	if pts.size() >= 2:
		var peak_g: int = 0
		var peak_n: int = 0
		for p in pts:
			peak_g = maxi(peak_g, int(p[1]))
			peak_n = maxi(peak_n, int(p[3]))
		lines.append("Record d'or : %d couronnes · effectif maximal : %d hommes" % [peak_g, peak_n])
	return lines
