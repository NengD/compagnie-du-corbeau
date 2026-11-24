extends SceneTree
## Extrait les chaînes françaises visibles par le joueur (scenes/, core/, autoload/) et les écrit dans un fichier TSV :
##   msgid <TAB> zone <TAB> marqueurs de format <TAB> fichier:ligne (première occurrence) <TAB> occurrences
## Usage : godot --headless -s res://tools/extract_strings.gd -- [chemin_de_sortie]
## Par défaut : user://strings_fr.tsv. Le msgid est le français lui-même (retours à la ligne écrits \n).

func _init() -> void:
	var out_path: String = "user://strings_fr.tsv"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	var scan := I18nScan.new()
	var all: Array = scan.scan_all()
	var uniq: Dictionary = {}
	for e in all:
		var t: String = e["text"]
		if not uniq.has(t):
			uniq[t] = {"zone": e["zone"], "where": "%s:%d" % [e["file"], e["line"]], "n": 0}
		uniq[t]["n"] += 1
	var keys: Array = uniq.keys()
	keys.sort()
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("Écriture impossible : " + out_path)
		quit(1)
		return
	var per_zone: Dictionary = {}
	for k in keys:
		var u: Dictionary = uniq[k]
		per_zone[u["zone"]] = int(per_zone.get(u["zone"], 0)) + 1
		f.store_line("%s\t%s\t%s\t%s\t%d" % [str(k).replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t"), u["zone"], " ".join(scan.markers(k)), u["where"], u["n"]])
	f.close()
	print("%d occurrences, %d chaînes uniques -> %s" % [all.size(), keys.size(), ProjectSettings.globalize_path(out_path)])
	for z in per_zone:
		print("  %s : %d" % [z, per_zone[z]])
	quit(0)
