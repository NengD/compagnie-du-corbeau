extends RefCounted
## Audit n°2 (interface, carte, sons) : couverture des événements sonores et règles de mise en page pures.
var t

const SCAN_DIRS: Array[String] = ["res://scenes", "res://autoload", "res://core"]


func _audio() -> Node:
	return load("res://autoload/Audio.gd").new()


func _gd_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)


## Tous les noms d'événements littéraux passés à Sfx.play / Audio.play / _sfx dans le code du jeu.
func _used_events() -> Dictionary:
	var files: Array[String] = []
	for d in SCAN_DIRS:
		_gd_files(d, files)
	var call_re := RegEx.new()
	call_re.compile("(?:Sfx\\.play|Audio\\.play|_sfx)\\(([^)\\n]*)\\)")
	var name_re := RegEx.new()
	name_re.compile("(?<!\\[)\"([a-z_0-9]+)\"(?!\\])")  # pas les clés de dictionnaire (res["armor"])
	var nl: String = String.chr(10)
	var used: Dictionary = {}
	for path in files:
		var kept: PackedStringArray = []
		for line in FileAccess.get_file_as_string(path).split(nl):
			if not line.strip_edges().begins_with("#"):  # pas les commentaires
				kept.append(line)
		var txt: String = nl.join(kept)
		for m in call_re.search_all(txt):
			for n in name_re.search_all(m.get_string(1)):
				used[n.get_string(1)] = path
	return used


func test_every_event_has_a_file() -> void:
	var a := _audio()
	for ev: String in a.EVENTS:
		var files: Array = a.EVENTS[ev]["files"]
		t.check(not files.is_empty(), "événement sans fichier : " + ev)
		var found: int = 0
		for f: String in files:
			if ResourceLoader.exists(a.SFX_DIR + f) or FileAccess.file_exists(a.SFX_DIR + f):
				found += 1
		t.check(found > 0, "aucun fichier présent pour l'événement : " + ev)
	a.free()


func test_no_unknown_event_in_code() -> void:
	var a := _audio()
	var used: Dictionary = _used_events()
	t.check(used.size() >= 15, "le balayage du code trouve les appels sonores (%d)" % used.size())
	for ev: String in used:
		t.check(a.EVENTS.has(ev), "événement inconnu « %s » appelé dans %s" % [ev, used[ev]])
	a.free()


func test_interface_events_exist() -> void:
	var a := _audio()
	for ev in ["buy", "sell", "drop", "perk", "paper_open", "paper_close", "speed", "town", "repair", "hire"]:
		t.check(a.EVENTS.has(ev), "événement d'interface manquant : " + ev)
	var used: Dictionary = _used_events()
	for ev in ["buy", "sell", "drop", "perk", "paper_open", "paper_close", "speed", "town", "repair", "hire"]:
		t.check(used.has(ev), "événement jamais déclenché : " + ev)
	a.free()


func test_new_events_are_not_louder_than_essentials() -> void:
	var a := _audio()
	for ev in ["buy", "sell", "drop", "paper_open", "paper_close", "speed", "town", "repair", "hire", "perk"]:
		t.check(float(a.EVENTS[ev]["db"]) <= -5.0, "volume trop fort pour un son d'interface : " + ev)
	a.free()
