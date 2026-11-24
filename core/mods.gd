class_name Mods
extends RefCounted
## Mods en JSON : `user://mods/<nom>/mod.json` + fichiers de contenu JSON. Logique pure (aucun nœud), tolérante :
## un fichier ou une entrée invalide est ignoré avec un avertissement (lisible dans Options > Mods), jamais de plantage.
##
## Sécurité : un mod n'est que des DONNÉES (aucun script exécuté) ; le jeu ne lit que `mod.json` et des fichiers `.json`
## situés dans le dossier du mod (chemins relatifs stricts, sans « .. », sans lecteur, sans lien symbolique), ne les écrit
## jamais, et ne touche pas aux sauvegardes. Tailles, profondeur, nombre d'éléments et types sont bornés (voir ModsData) ;
## chaque valeur est reconstruite champ par champ (liste blanche), jamais copiée telle quelle.
## Les identifiants créés par un mod (scénarios, événements) sont préfixés « mod_<id du mod>_ » : aucune collision possible
## avec les identifiants du jeu, et une sauvegarde qui en cite un dont le mod a disparu retombe sur le comportement normal.
##
## Points d'extension (les tables `Data.*` sont des `const` : on ne les modifie jamais, on les COMPLÈTE à la lecture) :
## first_names / nicknames / company_names / place_names / epitaphs / backstory_pool / scenario_keys / scenario_data / events.
## NON pris en charge (les armes, armures et ennemis vivent dans des `const` lus partout par `Data.WPN[...]`) : voir docs/mods.md.

## Rapports de chargement, un par mod : {id, dir, name, version, author, description, enabled, state, warnings, counts, files}
## state : "ok" | "warn" (avertissements) | "error" (mod ignoré) | "disabled" (désactivé par le joueur).
static var reports: Array = []
static var content: Dictionary = _empty_content()


static func _empty_content() -> Dictionary:
	return {"first_names": [], "nicknames": [], "company_names": [], "place_names": [], "epitaphs": [],
		"backstories": {}, "scenarios": {}, "scenario_order": [], "events": []}


static func reset() -> void:
	reports = []
	content = _empty_content()


# --- Chargement ---

## Charge le dossier des mods du joueur (mods désactivés lus dans `user://mods_state.json`).
static func load_default() -> Array:
	return load_all(ModsData.ROOT, read_disabled())


## Charge tous les mods de `root`. Remplace l'état précédent. Retourne les rapports.
static func load_all(root: String = ModsData.ROOT, disabled: Array = []) -> Array:
	reset()
	var dirs: PackedStringArray = PackedStringArray()
	if DirAccess.dir_exists_absolute(root):  # pas de dossier de mods : aucun mod (et aucune erreur dans la console)
		dirs = DirAccess.get_directories_at(root)
	var names: Array = []
	for d in dirs:
		if not str(d).begins_with("."):
			names.append(str(d))
	names.sort()
	var used_ids: Dictionary = {}
	var n: int = 0
	for dn in names:
		n += 1
		if n > ModsData.MAX_MODS:
			reports.append(_blank_report(dn, dn, "Trop de mods (maximum %d) : ignoré." % ModsData.MAX_MODS))
			continue
		var rep: Dictionary = load_mod(root, dn, disabled.has(dn))
		if used_ids.has(str(rep["id"])):
			rep["state"] = "error"
			rep["warnings"].append("Identifiant « %s » déjà pris par un autre mod : ignoré." % rep["id"])
		used_ids[str(rep["id"])] = true
		reports.append(rep)
	# Fusion : seulement les mods activés et sans erreur, dans l'ordre alphabétique des dossiers.
	for rep in reports:
		if str(rep["state"]) in ["ok", "warn"]:
			_merge(rep["_content"])
	for rep in reports:
		rep.erase("_content")
	return reports


static func _blank_report(id: String, dir_name: String, err: String) -> Dictionary:
	return {"id": id, "dir": dir_name, "name": dir_name, "version": "", "author": "", "description": "",
		"enabled": true, "state": "error", "warnings": [err], "counts": {}, "files": [], "_content": _empty_content()}


## Identifiant sûr tiré du nom du dossier : minuscules, chiffres, « _ », 32 caractères au plus.
static func make_id(dir_name: String) -> String:
	var out: String = ""
	for ch in dir_name.to_lower():
		out += ch if ModsData.ID_CHARS.contains(ch) else "_"
	out = out.substr(0, ModsData.ID_MAX)
	return out if out != "" else "mod"


## Lit un mod (manifeste puis fichiers de contenu). Ne plante jamais ; le contenu valide est dans `_content`.
static func load_mod(root: String, dir_name: String, disabled: bool = false) -> Dictionary:
	var rep: Dictionary = _blank_report(make_id(dir_name), dir_name, "")
	rep["warnings"] = []
	rep["enabled"] = not disabled
	var base: String = root.path_join(dir_name)
	var man: Dictionary = read_json(base.path_join("mod.json"), ModsData.MAX_MANIFEST_BYTES)
	if not bool(man["ok"]):
		return _fail(rep, "mod.json : %s" % man["err"])
	if typeof(man["data"]) != TYPE_DICTIONARY:
		return _fail(rep, "mod.json : doit être un objet JSON.")
	var m: Dictionary = man["data"]
	var nm: String = _text(m.get("name", ""), 60)
	if nm == "":
		return _fail(rep, "mod.json : « name » (texte non vide, 60 caractères au plus) est obligatoire.")
	rep["name"] = nm
	rep["version"] = _opt_text(m, "version", 20, "?", rep)
	rep["author"] = _opt_text(m, "author", 60, "", rep)
	rep["description"] = _opt_text(m, "description", 400, "", rep, true)
	var files: Array = _file_list(m, base, rep)
	var bucket: Dictionary = _empty_content()
	for rel in files:
		var path: String = base.path_join(str(rel))
		var res: Dictionary = read_json(path, ModsData.MAX_FILE_BYTES)
		if not bool(res["ok"]):
			_warn(rep, "%s : %s (fichier ignoré)." % [rel, res["err"]])
			continue
		if typeof(res["data"]) != TYPE_DICTIONARY:
			_warn(rep, "%s : doit être un objet JSON (fichier ignoré)." % rel)
			continue
		(rep["files"] as Array).append(str(rel))
		_read_content(res["data"], str(rep["id"]), str(rel), rep, bucket)
	rep["_content"] = bucket
	for k in bucket:
		var v: Variant = bucket[k]
		var c: int = (v as Array).size() if typeof(v) == TYPE_ARRAY else (v as Dictionary).size()
		if k != "scenario_order" and c > 0:
			rep["counts"][k] = c
	if disabled:
		rep["state"] = "disabled"
	elif not (rep["warnings"] as Array).is_empty():
		rep["state"] = "warn"
	else:
		rep["state"] = "ok"
	return rep


static func _fail(rep: Dictionary, msg: String) -> Dictionary:
	rep["state"] = "error"
	_warn(rep, msg)
	return rep


static func _warn(rep: Dictionary, msg: String) -> void:
	var w: Array = rep["warnings"]
	if w.size() < ModsData.MAX_WARNINGS:
		w.append(msg)
	elif w.size() == ModsData.MAX_WARNINGS:
		w.append("… (d'autres avertissements ne sont pas listés)")


static func _opt_text(m: Dictionary, key: String, max_len: int, def: String, rep: Dictionary, multiline: bool = false) -> String:
	if not m.has(key):
		return def
	if typeof(m[key]) != TYPE_STRING:
		_warn(rep, "mod.json : « %s » doit être un texte (ignoré)." % key)
		return def
	return _text(m[key], max_len, multiline)


## Fichiers de contenu : la liste « files » du manifeste (chemins validés) ou tous les .json à la racine du mod.
static func _file_list(m: Dictionary, base: String, rep: Dictionary) -> Array:
	var out: Array = []
	if m.has("files"):
		if typeof(m["files"]) != TYPE_ARRAY:
			_warn(rep, "mod.json : « files » doit être une liste (ignoré).")
		else:
			for f in m["files"]:
				if typeof(f) != TYPE_STRING or not safe_rel_path(str(f)):
					_warn(rep, "mod.json : chemin refusé « %s » (relatif, sans « .. », se terminant par .json)." % _text(f, 60))
				elif str(f) == "mod.json":
					continue
				elif not out.has(str(f)):
					out.append(str(f))
			if out.size() > ModsData.MAX_FILES_PER_MOD:
				_warn(rep, "Trop de fichiers (maximum %d) : les suivants sont ignorés." % ModsData.MAX_FILES_PER_MOD)
				out = out.slice(0, ModsData.MAX_FILES_PER_MOD)
			return out
	var names: Array = []
	for f in DirAccess.get_files_at(base):
		if str(f).to_lower().ends_with(".json") and str(f) != "mod.json" and safe_rel_path(str(f)):
			names.append(str(f))
	names.sort()
	if names.size() > ModsData.MAX_FILES_PER_MOD:
		_warn(rep, "Trop de fichiers (maximum %d) : les suivants sont ignorés." % ModsData.MAX_FILES_PER_MOD)
		names = names.slice(0, ModsData.MAX_FILES_PER_MOD)
	return names


## Chemin relatif sûr : lettres, chiffres, « _ », « - », « . » et « / » ; sans « .. », ni « \ », ni lecteur ni racine ;
## 3 niveaux au plus ; extension .json.
static func safe_rel_path(rel: String) -> bool:
	if rel.length() < 6 or rel.length() > 80 or not rel.to_lower().ends_with(".json"):
		return false
	if rel.begins_with("/") or rel.contains("\\") or rel.contains(":") or rel.contains("//"):
		return false
	var parts: PackedStringArray = rel.split("/")
	if parts.size() > 3:
		return false
	for p in parts:
		if p == "" or p.begins_with(".") or p.contains(".."):
			return false
	for ch in rel:
		var c: int = ch.unicode_at(0)
		var ok: bool = (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or ch in ["_", "-", ".", "/"]
		if not ok:
			return false
	return true


# --- Lecture JSON ---

## {"ok": bool, "data": Variant, "err": String}. Taille bornée avant lecture ; profondeur et nombre d'éléments bornés après.
static func read_json(path: String, max_bytes: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": null, "err": "fichier introuvable"}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "data": null, "err": "lecture impossible"}
	var len_: int = f.get_length()
	if len_ > max_bytes:
		f.close()
		return {"ok": false, "data": null, "err": "trop gros (%d octets, maximum %d)" % [len_, max_bytes]}
	var bytes: PackedByteArray = f.get_buffer(len_)
	f.close()
	return parse_text(bytes.get_string_from_utf8(), max_bytes)


static func parse_text(text: String, max_bytes: int = ModsData.MAX_FILE_BYTES) -> Dictionary:
	if text.length() > max_bytes:
		return {"ok": false, "data": null, "err": "trop gros"}
	if text.begins_with("﻿"):
		text = text.substr(1)
	var j := JSON.new()
	if j.parse(text) != OK:
		return {"ok": false, "data": null, "err": "JSON invalide (ligne %d : %s)" % [j.get_error_line(), j.get_error_message()]}
	var counter: Array = [0]
	if not _within_limits(j.data, 0, counter):
		return {"ok": false, "data": null, "err": "structure trop profonde ou trop volumineuse"}
	return {"ok": true, "data": j.data, "err": ""}


static func _within_limits(v: Variant, depth: int, counter: Array) -> bool:
	counter[0] += 1
	if depth > ModsData.MAX_JSON_DEPTH or int(counter[0]) > ModsData.MAX_JSON_NODES:
		return false
	match typeof(v):
		TYPE_ARRAY:
			for e in v:
				if not _within_limits(e, depth + 1, counter):
					return false
		TYPE_DICTIONARY:
			for k in v:
				if not _within_limits(v[k], depth + 1, counter):
					return false
	return true


# --- Nettoyage des valeurs ---

## Texte nettoyé : sans crochets (BBCode), sans caractères de contrôle ; `multiline` garde les retours à la ligne.
static func _text(v: Variant, max_len: int, multiline: bool = false) -> String:
	if typeof(v) != TYPE_STRING:
		return ""
	var out: String = ""
	for ch in str(v):
		var c: int = ch.unicode_at(0)
		if ch == "[" or ch == "]" or c == 0x7f:
			continue
		if c < 32:
			if c == 10 and multiline:
				out += "\n"
			elif c == 9:
				out += " "
			continue
		out += ch
	out = out.strip_edges()
	return out.substr(0, max_len)


## Liste de textes : chaque élément doit être un texte de longueur `lens` ; les autres sont écartés (avertissement groupé).
static func _strings(v: Variant, lens: Array, max_n: int, label: String, warns: Array, exclude: Array = []) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		warns.append("« %s » doit être une liste de textes (ignoré)." % label)
		return out
	var dropped: int = 0
	for e in v:
		if typeof(e) != TYPE_STRING:
			dropped += 1
			continue
		var s: String = _text(e, 400, false)
		if s.length() < int(lens[0]) or s.length() > int(lens[1]) or out.has(s) or exclude.has(s):
			dropped += 1
			continue
		if out.size() >= max_n:
			dropped += 1
			continue
		out.append(s)
	if dropped > 0:
		warns.append("« %s » : %d entrée(s) écartée(s) (type, longueur %d–%d, doublon ou liste pleine)." % [label, dropped, lens[0], lens[1]])
	return out


static func _int(d: Dictionary, key: String, lo: int, hi: int, def: int, warns: Array, label: String) -> int:
	if not d.has(key):
		return def
	var v: Variant = d[key]
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		warns.append("%s : « %s » doit être un nombre (valeur par défaut)." % [label, key])
		return def
	var f: float = float(v)
	if is_nan(f) or is_inf(f):
		warns.append("%s : « %s » invalide (valeur par défaut)." % [label, key])
		return def
	var n: int = int(f)
	if n < lo or n > hi:
		warns.append("%s : « %s » ramené entre %d et %d." % [label, key, lo, hi])
		return clampi(n, lo, hi)
	return n


static func _flt(d: Dictionary, key: String, lo: float, hi: float, def: float, warns: Array, label: String) -> float:
	if not d.has(key):
		return def
	var v: Variant = d[key]
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT or is_nan(float(v)) or is_inf(float(v)):
		warns.append("%s : « %s » doit être un nombre (valeur par défaut)." % [label, key])
		return def
	return clampf(float(v), lo, hi)


static func _valid_id(s: Variant) -> bool:
	if typeof(s) != TYPE_STRING:
		return false
	var t: String = str(s)
	if t.length() < 1 or t.length() > ModsData.ID_MAX:
		return false
	for ch in t:
		if not ModsData.ID_CHARS.contains(ch):
			return false
	return true


# --- Contenu ---

static func _read_content(file: Dictionary, mod_id: String, rel: String, rep: Dictionary, bucket: Dictionary) -> void:
	for key in file:
		var k: String = str(key)
		if not ModsData.CATEGORIES.has(k):
			_warn(rep, "%s : catégorie inconnue « %s » (ignorée)." % [rel, _text(k, 40)])
			continue
		var warns: Array = []
		var v: Variant = file[key]
		match k:
			"first_names":
				_add_list(bucket, k, _strings(v, ModsData.NAME_LEN, ModsData.LIST_MAX, k, warns, Data.FIRST_NAMES))
			"nicknames":
				_add_list(bucket, k, _strings(v, ModsData.NICK_LEN, ModsData.LIST_MAX, k, warns, Data.NICKNAMES))
			"company_names":
				_add_list(bucket, k, _strings(v, [Data.COMPANY_NAME_MIN, Data.COMPANY_NAME_MAX], ModsData.LIST_MAX, k, warns, Data.COMPANY_NAME_SUGGESTIONS))
			"place_names":
				_add_list(bucket, k, _strings(v, ModsData.PLACE_LEN, ModsData.LIST_MAX, k, warns, Data.TOWNS))
			"epitaphs":
				_add_list(bucket, k, _strings(v, ModsData.EPITAPH_LEN, ModsData.LIST_MAX, k, warns, Chronicle.EPITAPHS))
			"backstories":
				_read_backstories(v, bucket, warns)
			"scenarios":
				_read_scenarios(v, mod_id, bucket, warns)
			"events":
				_read_events(v, mod_id, bucket, warns)
		for w in warns:
			_warn(rep, "%s : %s" % [rel, w])


static func _add_list(bucket: Dictionary, key: String, items: Array) -> void:
	var cur: Array = bucket[key]
	for s in items:
		if not cur.has(s):
			cur.append(s)


static func _read_backstories(v: Variant, bucket: Dictionary, warns: Array) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		warns.append("« backstories » doit être un objet {origine: [textes]} (ignoré).")
		return
	var out: Dictionary = bucket["backstories"]
	for k in v:
		var key: String = str(k)
		if not Data.BG.has(key):
			warns.append("backstories : origine inconnue « %s » (ignorée)." % _text(key, 30))
			continue
		var items: Array = _strings(v[k], ModsData.STORY_LEN, ModsData.STORIES_PER_ORIGIN_MAX, "backstories." + key, warns)
		if not items.is_empty():
			var cur: Array = out.get(key, [])
			for s in items:
				if not cur.has(s):
					cur.append(s)
			out[key] = cur.slice(0, ModsData.STORIES_PER_ORIGIN_MAX)


static func _read_scenarios(v: Variant, mod_id: String, bucket: Dictionary, warns: Array) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		warns.append("« scenarios » doit être un objet {identifiant: scénario} (ignoré).")
		return
	var n: int = 0
	for k in v:
		if not _valid_id(k):
			warns.append("scenarios : identifiant refusé « %s » (a-z, 0-9, _ ; 32 caractères au plus)." % _text(k, 30))
			continue
		n += 1
		if n > ModsData.SCENARIOS_MAX or (bucket["scenarios"] as Dictionary).size() >= ModsData.SCENARIOS_MAX:
			warns.append("scenarios : trop de scénarios (maximum %d)." % ModsData.SCENARIOS_MAX)
			break
		var full: String = "mod_%s_%s" % [mod_id, k]
		var sc: Dictionary = _clean_scenario(v[k], str(k), warns)
		if sc.is_empty():
			continue
		if not (bucket["scenarios"] as Dictionary).has(full):
			(bucket["scenario_order"] as Array).append(full)
		bucket["scenarios"][full] = sc


static func _clean_scenario(d: Variant, id: String, warns: Array) -> Dictionary:
	var lab: String = "scénario « %s »" % id
	if typeof(d) != TYPE_DICTIONARY:
		warns.append("%s : doit être un objet (ignoré)." % lab)
		return {}
	var s: Dictionary = d
	var name_: String = _text(s.get("n", ""), 60)
	if name_.length() < 2:
		warns.append("%s : « n » (nom, 2 à 60 caractères) obligatoire (scénario ignoré)." % lab)
		return {}
	var men: Array = []
	if typeof(s.get("men", null)) == TYPE_ARRAY:
		for o in s["men"]:
			if typeof(o) == TYPE_STRING and Data.BG.has(str(o)) and men.size() < 8:
				men.append(str(o))
	if men.is_empty():
		warns.append("%s : « men » doit lister 1 à 8 origines connues (clés de Data.BG) (scénario ignoré)." % lab)
		return {}
	var stats: Array = ["renown", "gold"] + Achievements.default_stats().keys()
	var g: Variant = s.get("goal", null)
	if typeof(g) != TYPE_DICTIONARY or typeof((g as Dictionary).get("stat", null)) != TYPE_STRING or not stats.has(str((g as Dictionary)["stat"])):
		warns.append("%s : « goal.stat » doit être « renown », « gold » ou une statistique connue (scénario ignoré)." % lab)
		return {}
	var gd: Dictionary = g
	var goal: Dictionary = {
		"stat": str(gd["stat"]),
		"target": _int(gd, "target", 1, 100000, 100, warns, lab),
		"label": _text(gd.get("label", ""), 30) if _text(gd.get("label", ""), 30) != "" else str(gd["stat"]),
	}
	var out: Dictionary = {}
	out["n"] = name_
	for key in ["tag", "desc", "intro", "rule", "win", "lose"]:
		var lim: int = 100 if key == "tag" else (600 if key in ["desc", "win", "lose"] else 300)
		out[key] = _text(s.get(key, ""), lim, true) if s.has(key) else str(ModsData.SCENARIO_DEFAULTS[key])
	out["men"] = men
	out["gold"] = _int(s, "gold", -1, 5000, -1, warns, lab)
	out["gear"] = "noble" if str(s.get("gear", "")) == "noble" else ""
	out["wage_mult"] = _flt(s, "wage_mult", 0.5, 3.0, 1.0, warns, lab)
	out["provisions"] = _int(s, "provisions", 0, 60, 0, warns, lab)
	out["morale"] = _int(s, "morale", -20, 30, 0, warns, lab)
	out["hunt_only"] = typeof(s.get("hunt_only", false)) == TYPE_BOOL and bool(s.get("hunt_only", false))
	out["hunt_pay"] = _flt(s, "hunt_pay", 0.5, 3.0, 1.0, warns, lab)
	out["days"] = _int(s, "days", 10, 400, 90, warns, lab)
	out["goal"] = goal
	return out


static func _read_events(v: Variant, mod_id: String, bucket: Dictionary, warns: Array) -> void:
	if typeof(v) != TYPE_ARRAY:
		warns.append("« events » doit être une liste d'événements (ignoré).")
		return
	for e in v:
		if (bucket["events"] as Array).size() >= ModsData.EVENTS_MAX:
			warns.append("events : trop d'événements (maximum %d)." % ModsData.EVENTS_MAX)
			break
		var ev: Dictionary = _clean_event(e, mod_id, warns)
		if ev.is_empty():
			continue
		var dup: bool = false
		for o in bucket["events"]:
			if o["id"] == ev["id"]:
				dup = true
		if dup:
			warns.append("événement « %s » en double (ignoré)." % ev["id"])
		else:
			(bucket["events"] as Array).append(ev)


static func _clean_event(d: Variant, mod_id: String, warns: Array) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		warns.append("événement : doit être un objet (ignoré).")
		return {}
	var e: Dictionary = d
	if not _valid_id(e.get("id", null)):
		warns.append("événement : « id » invalide (a-z, 0-9, _ ; 32 caractères au plus) (ignoré).")
		return {}
	var lab: String = "événement « %s »" % e["id"]
	var title: String = _text(e.get("title", ""), 60)
	var text: String = _text(e.get("text", ""), 600, true)
	if title.length() < 2 or text.length() < 10:
		warns.append("%s : « title » (2 à 60) et « text » (10 à 600) sont obligatoires (ignoré)." % lab)
		return {}
	if typeof(e.get("choices", null)) != TYPE_ARRAY or (e["choices"] as Array).is_empty():
		warns.append("%s : « choices » doit lister 1 à 5 choix (ignoré)." % lab)
		return {}
	var choices: Array = []
	var seen: Array = []
	for c in (e["choices"] as Array).slice(0, 5):
		var ch: Dictionary = _clean_choice(c, lab, warns)
		if ch.is_empty() or seen.has(ch["id"]):
			continue
		seen.append(ch["id"])
		choices.append(ch)
	var free: bool = false
	for c in choices:
		if int(c.get("cost", 0)) == 0:
			free = true
	if choices.is_empty() or not free:
		warns.append("%s : il faut au moins un choix valide et gratuit (ignoré)." % lab)
		return {}
	return {"id": "mod_%s_%s" % [mod_id, e["id"]], "title": title, "text": text, "choices": choices}


static func _clean_choice(c: Variant, lab: String, warns: Array) -> Dictionary:
	if typeof(c) != TYPE_DICTIONARY or not _valid_id((c as Dictionary).get("id", null)):
		warns.append("%s : choix invalide (id manquant ou incorrect), écarté." % lab)
		return {}
	var d: Dictionary = c
	var label: String = _text(d.get("label", ""), 120)
	if label.length() < 2:
		warns.append("%s : choix « %s » sans « label » (écarté)." % [lab, d["id"]])
		return {}
	var out: Dictionary = {"id": str(d["id"]), "label": label}
	var cost: int = _int(d, "cost", 0, 500, 0, warns, lab)
	if cost > 0:
		out["cost"] = cost
	if d.has("check"):
		var ck: Variant = d["check"]
		if typeof(ck) != TYPE_DICTIONARY or str((ck as Dictionary).get("kind", "")) not in ModsData.CHECK_KINDS:
			warns.append("%s : choix « %s » : « check.kind » doit être %s (écarté)." % [lab, d["id"], "/".join(ModsData.CHECK_KINDS)])
			return {}
		out["check"] = {"kind": str(ck["kind"]), "base": _int(ck, "base", 5, 95, 50, warns, lab)}
		for side in ["win", "lose"]:
			var arr: Array = _clean_outcomes(d.get(side, null), lab, warns)
			if arr.is_empty():
				warns.append("%s : choix « %s » : « %s » doit lister 1 à 4 issues (écarté)." % [lab, d["id"], side])
				return {}
			out[side] = arr
	else:
		var oc: Array = _clean_outcomes(d.get("outcomes", null), lab, warns)
		if oc.is_empty():
			warns.append("%s : choix « %s » : « outcomes » doit lister 1 à 5 issues (écarté)." % [lab, d["id"]])
			return {}
		out["outcomes"] = oc
	return out


static func _clean_outcomes(v: Variant, lab: String, warns: Array) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for o in (v as Array).slice(0, 5):
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = o
		var text: String = _text(d.get("text", ""), 300, true)
		if text.length() < 2:
			continue
		var r: Dictionary = {"w": _int(d, "w", 1, 20, 1, warns, lab), "text": text}
		for ek in ModsData.EFFECT_RANGES:
			if d.has(ek):
				var rg: Array = ModsData.EFFECT_RANGES[ek]
				var val: int = _int(d, str(ek), int(rg[0]), int(rg[1]), 0, warns, lab)
				if val != 0:
					r[ek] = val
		if typeof(d.get("repair", false)) == TYPE_BOOL and bool(d.get("repair", false)):
			r["repair"] = true
		if d.has("recruit"):
			var rc: String = str(d["recruit"])
			if rc == "random" or Data.BG.has(rc):
				r["recruit"] = rc
			else:
				warns.append("%s : « recruit » inconnu « %s » (ignoré)." % [lab, _text(rc, 30)])
		if d.has("battle"):
			var b: Variant = d["battle"]
			if typeof(b) == TYPE_DICTIONARY and str((b as Dictionary).get("type", "")) in ModsData.BATTLE_FACTIONS:
				r["battle"] = {"type": str(b["type"]), "d": _int(b, "d", 1, 3, 1, warns, lab)}
			else:
				warns.append("%s : « battle » invalide (type %s) (ignoré)." % [lab, "/".join(ModsData.BATTLE_FACTIONS)])
		out.append(r)
	return out


# --- Fusion ---

static func _merge(b: Dictionary) -> void:
	for k in ["first_names", "nicknames", "company_names", "place_names", "epitaphs"]:
		var cur: Array = content[k]
		for s in b[k]:
			if not cur.has(s):
				cur.append(s)
	for k in b["backstories"]:
		var cur2: Array = content["backstories"].get(k, [])
		for s in b["backstories"][k]:
			if not cur2.has(s):
				cur2.append(s)
		content["backstories"][k] = cur2
	for k in b["scenario_order"]:
		if not (content["scenarios"] as Dictionary).has(k):
			(content["scenario_order"] as Array).append(k)
		content["scenarios"][k] = b["scenarios"][k]
	for e in b["events"]:
		(content["events"] as Array).append(e)


# --- Accès pour le jeu (le contenu des mods COMPLÈTE les tables du jeu ; sans mod, les tables d'origine sont rendues telles quelles) ---

static func first_names() -> Array:
	return Data.FIRST_NAMES if (content["first_names"] as Array).is_empty() else Data.FIRST_NAMES + content["first_names"]


static func nicknames() -> Array:
	return Data.NICKNAMES if (content["nicknames"] as Array).is_empty() else Data.NICKNAMES + content["nicknames"]


static func company_names() -> Array:
	return Data.COMPANY_NAME_SUGGESTIONS if (content["company_names"] as Array).is_empty() else Data.COMPANY_NAME_SUGGESTIONS + content["company_names"]


static func towns() -> Array:
	return Data.TOWNS if (content["place_names"] as Array).is_empty() else Data.TOWNS + content["place_names"]


static func extra_places() -> Array:
	return content["place_names"]


static func epitaphs() -> Array:
	return Chronicle.EPITAPHS if (content["epitaphs"] as Array).is_empty() else Array(Chronicle.EPITAPHS) + content["epitaphs"]


## Histoires d'une origine : celles du jeu (`base`) puis celles des mods.
static func backstory_pool(key: String, base: Array) -> Array:
	var extra: Array = content["backstories"].get(key, [])
	return base if extra.is_empty() else base + extra


static func scenario_keys() -> Array:
	return ScenariosData.ORDER + content["scenario_order"]


static func scenario_data(key: String) -> Dictionary:
	if ScenariosData.SCENARIOS.has(key):
		return ScenariosData.SCENARIOS[key]
	return (content["scenarios"] as Dictionary).get(key, {})


static func events() -> Array:
	return content["events"]


static func event_def(id: String) -> Dictionary:
	for e in content["events"]:
		if e["id"] == id:
			return e
	return {}


static func loaded_count() -> int:
	var n: int = 0
	for r in reports:
		if str(r["state"]) in ["ok", "warn"]:
			n += 1
	return n


# --- Mods désactivés par le joueur ---

static func read_disabled(path: String = ModsData.STATE_FILE) -> Array:
	var res: Dictionary = read_json(path, ModsData.MAX_MANIFEST_BYTES)
	var out: Array = []
	if bool(res["ok"]) and typeof(res["data"]) == TYPE_DICTIONARY and typeof((res["data"] as Dictionary).get("disabled", null)) == TYPE_ARRAY:
		for d in res["data"]["disabled"]:
			if typeof(d) == TYPE_STRING and out.size() < 200:
				out.append(str(d))
	return out


static func write_disabled(list: Array, path: String = ModsData.STATE_FILE) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"disabled": list}))
	f.close()
	return true
