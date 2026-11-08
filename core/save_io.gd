class_name SaveIO
extends RefCounted
## Lecture, validation, migration et écriture sûre des fichiers de sauvegarde (JSON). Logique pure : aucune dépendance aux nœuds.
## `Game` en garde les points d'entrée (`save`, `load_save`, `save_to_slot`…) et délègue ici.

## Version du schéma écrit par le jeu. À augmenter à chaque changement NON rétrocompatible, avec une migration `_migrate_N`.
const VERSION: int = 2
## Plus ancienne version encore lisible (les sauvegardes antérieures n'avaient pas de carte).
const MIN_VERSION: int = 2
const REQUIRED_KEYS: Array[String] = ["gold", "day", "roster", "world"]

## Dernière raison d'échec d'une écriture ("" = tout va bien).
static var last_error: String = ""


## Une sauvegarde lue est-elle complète ? (clés obligatoires, types, carte présente)
static func is_valid(parsed: Variant) -> bool:
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	if int(d.get("version", 0)) < MIN_VERSION:
		return false  # ancienne sauvegarde (sans carte) ou illisible
	for k in REQUIRED_KEYS:
		if not d.has(k):
			return false
	if typeof(d["roster"]) != TYPE_ARRAY or typeof(d["world"]) != TYPE_DICTIONARY:
		return false
	var w: Dictionary = d["world"]
	if not (w.has("terrain") or w.has("terrain_z")) or not w.has("settlements"):
		return false
	return true


## Lit un fichier et le valide ; {} s'il est absent, tronqué, corrompu, incomplet ou d'une version plus récente que le jeu.
static func read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:  # fichier tronqué ou corrompu : pas d'erreur bruyante
		return {}
	if not is_valid(json.data):
		return {}
	var d: Dictionary = json.data
	if int(d.get("version", 0)) > VERSION:
		return {}  # écrite par une version plus récente du jeu : on ne devine pas
	return migrate(d)


## Lit `path`, sinon la copie de secours `path.bak`.
static func read_save(path: String) -> Dictionary:
	var d: Dictionary = read_one(path)
	if d.is_empty():
		d = read_one(path + ".bak")
	return d


## Met une sauvegarde à la version courante, une migration par version (de N vers N+1). Sans effet tant que VERSION == 2.
static func migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", MIN_VERSION))
	while v < VERSION:
		# Ex. : if v == 2: d = _migrate_2(d)  (pure : ancienne forme -> nouvelle forme)
		v += 1
		d["version"] = v
	return d


## Écrit `d` dans `path` : fichier temporaire relu et vérifié, copie de secours `.bak` de la version précédente
## SEULEMENT si celle-ci est valide (jamais une sauvegarde abîmée par-dessus une bonne copie), puis remplacement.
## Renvoie false (et remplit `last_error`) si l'écriture échoue : le fichier existant reste intact.
static func write_safe(path: String, d: Dictionary) -> bool:
	last_error = ""
	var text: String = JSON.stringify(d)
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "écriture impossible (%s)" % error_string(FileAccess.get_open_error())
		push_warning("Sauvegarde impossible : %s" % last_error)
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var written: String = FileAccess.get_file_as_string(tmp)
	var check := JSON.new()
	if written.length() != text.length() or check.parse(written) != OK:
		last_error = "fichier temporaire incomplet (disque plein ?)"
		push_warning("Sauvegarde abandonnée : %s" % last_error)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	if FileAccess.file_exists(path) and not read_one(path).is_empty():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var err: int = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		last_error = "renommage impossible (%s)" % error_string(err)
		push_warning("Sauvegarde impossible : %s" % last_error)
		return false
	return true


## Supprime un fichier de sauvegarde et ses copies annexes.
static func remove_all(path: String) -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
