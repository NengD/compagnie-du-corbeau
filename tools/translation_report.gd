extends SceneTree
## Rapport de couverture de la traduction anglaise : pour chaque zone, part des chaînes extraites (tools/i18n_scan.gd)
## qui ont une traduction dans translations/en*.po (correspondance exacte, gabarits compris).
## Les chaînes de translations/ignore.txt (noms propres, identifiants techniques) sont exclues du total.
## Usage : godot --headless -s res://tools/translation_report.gd -- [--list] [--out=chemin]
##   --list : affiche aussi les chaînes manquantes ; --out : les écrit dans un fichier (une par ligne, avec zone et lieu).

const IGNORE_PATH: String = "res://translations/ignore.txt"
const ZONES: Array = ["a_menus", "b_jeu", "c_bataille", "d_donnees"]


func _init() -> void:
	var list_missing: bool = false
	var out_path: String = ""
	for a in OS.get_cmdline_user_args():
		if a == "--list":
			list_missing = true
		elif a.begins_with("--out="):
			out_path = a.substr(6)
	var ignored: Dictionary = _load_ignore()
	var cat: FuzzyTranslation = I18n.catalog_en()
	var scan := I18nScan.new()
	var seen: Dictionary = {}
	var stats: Dictionary = {}
	var missing: Array = []
	for e in scan.scan_all():
		var t: String = e["text"]
		if seen.has(t) or ignored.has(t):
			continue
		seen[t] = true
		var z: String = e["zone"]
		if not stats.has(z):
			stats[z] = {"total": 0, "done": 0}
		stats[z]["total"] += 1
		if cat.has_exact(t):
			stats[z]["done"] += 1
		else:
			missing.append("%s\t%s\t%s:%d" % [z, t.replace("\n", "\\n"), str(e["file"]).replace("res://", ""), e["line"]])
	print("Catalogue anglais : %d phrases, %d gabarits ; %d chaînes ignorées." % [cat.exact.size(), cat.template_count, ignored.size()])
	var tot: int = 0
	var done: int = 0
	for z in ZONES:
		if not stats.has(z):
			continue
		var s: Dictionary = stats[z]
		tot += int(s["total"])
		done += int(s["done"])
		print("  %-11s %4d / %4d  (%.1f %%)" % [z, s["done"], s["total"], 100.0 * float(s["done"]) / maxf(1.0, float(s["total"]))])
	print("  %-11s %4d / %4d  (%.1f %%)" % ["TOTAL", done, tot, 100.0 * float(done) / maxf(1.0, float(tot))])
	if list_missing:
		for m in missing:
			print(m)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			for m in missing:
				f.store_line(m)
			f.close()
	quit(0)


func _load_ignore() -> Dictionary:
	var d: Dictionary = {}
	var f := FileAccess.open(IGNORE_PATH, FileAccess.READ)
	if f == null:
		return d
	while not f.eof_reached():
		var ln: String = f.get_line()
		if ln == "":
			continue
		d[ln.replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")] = true
	return d
