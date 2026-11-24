class_name I18nScan
extends RefCounted
## Parcourt les scripts du jeu et en tire les chaînes françaises visibles par le joueur.
## Partagé par tools/extract_strings.gd et tools/translation_report.gd.
## Heuristique (volontairement large, la liste d'exclusions affine) : un littéral est « visible » s'il contient
## une lettre et, soit une lettre accentuée, soit une espace entre deux mots, soit une majuscule initiale.
## Sont ignorés : commentaires, identifiants (snake_case, minuscules sans espace), chemins, couleurs, appels
## techniques (print, load, get_node, has_method...), clés de dictionnaire techniques.

const ROOTS: Array = ["res://scenes", "res://core", "res://autoload"]
const SKIP_FILES: Array = ["res://core/i18n.gd", "res://core/i18n_translation.gd"]
const SKIP_CALLS: Array = ["print(", "print_rich(", "push_error(", "push_warning(", "assert(", "preload(", "load(", "get_node", "has_method",
	"has_signal", "add_theme_", "ClassDB", "OS.", "FileAccess", "DirAccess", "ConfigFile", "connect(", "emit_signal", "call_deferred", "StringName(",
	"get_theme_", "has_theme_", "add_to_group", "is_in_group", "set_meta", "get_meta", "has_meta", "InputMap", "Input.", "TranslationServer", "ProjectSettings",
	"JSON.", "RegEx", "regex", "AudioServer", "Audio.play", "Audio.music", "theme_type_variation", "ResourceLoader", "group_name", "set_script"]
const MARKER_RE: String = "%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdfxXcr]|%%"

var _ident: RegEx
var _marker: RegEx
var _letter: RegEx
var _accent: RegEx


func _init() -> void:
	_ident = RegEx.create_from_string("^[a-z0-9_\\.\\-/:#%\\[\\]]*$")
	_marker = RegEx.create_from_string(MARKER_RE)
	_letter = RegEx.create_from_string("[A-Za-zÀ-ÿ]")
	_accent = RegEx.create_from_string("[À-ÿŒœ]")


## Liste de { "text", "file", "line", "zone" } (un élément par occurrence).
func scan_all() -> Array:
	var out: Array = []
	for root in ROOTS:
		for path in _list_gd(root):
			if SKIP_FILES.has(path):
				continue
			out.append_array(scan_file(path))
	return out


func scan_file(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var src: String = f.get_as_text().replace("\r", "")
	var zone: String = zone_of(path)
	var lines: PackedStringArray = src.split("\n")
	var in_doc: bool = false
	for i in lines.size():
		var line: String = lines[i]
		if line.count("\"\"\"") % 2 == 1:
			in_doc = not in_doc
			continue
		if in_doc:
			continue
		for lit in _literals(line):
			var raw: String = lit["text"]
			var txt: String = _unescape(raw)
			if _is_visible(txt, line, int(lit["pos"])):
				out.append({"text": txt, "file": path, "line": i + 1, "zone": zone})
	return out


## Littéraux "..." d'une ligne, hors commentaires (et hors littéraux de chemins).
func _literals(line: String) -> Array:
	var res: Array = []
	var n: int = line.length()
	var i: int = 0
	while i < n:
		var c: String = line[i]
		if c == "#":
			break
		if c == "&" and i + 1 < n and line[i + 1] == "\"" or c == "^" and i + 1 < n and line[i + 1] == "\"":
			# StringName / NodePath : jamais affichés
			i += 2
			while i < n and line[i] != "\"":
				i += 1
			i += 1
			continue
		if c == "\"":
			var start: int = i + 1
			var j: int = start
			var buf: String = ""
			while j < n and line[j] != "\"":
				if line[j] == "\\" and j + 1 < n:
					buf += line.substr(j, 2)
					j += 2
				else:
					buf += line[j]
					j += 1
			res.append({"text": buf, "pos": i})
			i = j + 1
			continue
		i += 1
	return res


func _unescape(s: String) -> String:
	return s.replace("\\n", "\n").replace("\\t", "\t").replace("\\\"", "\"").replace("\\\\", "\\")


func _is_visible(t: String, line: String, pos: int) -> bool:
	if t.length() < 2 or _letter.search(t) == null:
		return false
	for tok in SKIP_CALLS:
		if line.find(tok) != -1 and line.find(tok) < pos:
			return false
	if t.begins_with("res://") or t.begins_with("user://") or t.begins_with("#") or t.begins_with("http"):
		return false
	if t.ends_with(".gd") or t.ends_with(".png") or t.ends_with(".svg") or t.ends_with(".json") or t.ends_with(".tscn"):
		return false
	if _ident.search(t) != null:
		return false
	# Clé de dictionnaire ou d'indexation : "xxx"] ou "xxx":
	var after: String = line.substr(pos + t.length() + 2).strip_edges(true, false)
	var is_key: bool = after.begins_with("]") or after.begins_with(":") and not after.begins_with(":=")
	var has_accent: bool = _accent.search(t) != null
	var has_space: bool = t.find(" ") != -1
	var upper_start: bool = t.unicode_at(0) >= 65 and t.unicode_at(0) <= 90 or t.unicode_at(0) >= 192 and t.unicode_at(0) <= 222
	if is_key and not has_space and not has_accent:
		return false
	if t.find("_") != -1 and not has_space:
		return false
	if t.begins_with("[") and t.ends_with("]") and t.find(" ") == -1 and t.length() < 14:
		return false
	if t.to_upper() == t and t.find(" ") == -1 and t.find("_") == -1 and not has_accent and t.length() > 3:
		pass  # mots en capitales (ex. « MORAL ») : gardés
	return has_accent or has_space or upper_start


## Marqueurs de format (%s, %d, %.1f, %%) présents dans un gabarit.
func markers(t: String) -> Array:
	var out: Array = []
	for m in _marker.search_all(t):
		out.append(m.get_string())
	return out


static func zone_of(path: String) -> String:
	var p: String = path.replace("res://", "")
	# (a) menus, nouvelle partie, options, pause, tutoriel
	for k in ["scenes/menu/", "scenes/newgame/", "scenes/tutorial/", "scenes/boot/", "scenes/main.gd", "core/difficulty.gd", "core/banner.gd", "core/scenarios", "scenes/achievements/", "scenes/ending/", "autoload/Settings.gd", "core/quality.gd", "scenes/ui/shortcuts.gd"]:
		if p.begins_with(k):
			return "a_menus"
	# (c) bataille
	for k in ["scenes/battle/", "core/battle_state.gd", "core/ai.gd", "core/combat_rules.gd", "core/abilities.gd", "core/injuries.gd", "core/status.gd", "core/orders.gd", "core/defense.gd", "core/replay.gd", "core/objectives.gd", "core/scenery.gd", "core/cover.gd", "core/legendary.gd", "core/potions.gd", "core/damage_types.gd", "core/impact_feel.gd"]:
		if p.begins_with(k):
			return "c_bataille"
	# (d) tables de données
	for k in ["autoload/Data.gd", "core/materials_data.gd", "core/trade_data.gd", "core/scenarios_data.gd", "core/events.gd", "core/road_encounters.gd", "core/contracts.gd", "core/codex.gd", "core/perks.gd", "core/traits.gd", "core/backstory.gd", "core/legends.gd", "core/loot.gd", "core/campaign.gd", "core/world_gen.gd", "core/names.gd", "core/factions.gd", "core/territory.gd"]:
		if p.begins_with(k):
			return "d_donnees"
	# (b) carte, camp, marché, inventaire, talents, formation, atelier et le reste de l'interface
	return "b_jeu"


func _list_gd(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_list_gd(dir_path + "/" + name))
		elif name.ends_with(".gd"):
			out.append(dir_path + "/" + name)
		name = d.get_next()
	d.list_dir_end()
	out.sort()
	return out
