extends RefCounted
## Provenance et crédits : aucun ancien nom de talent proche du jeu commercial (docs/provenance.md), CREDITS.md couvre tous les dossiers d'assets.
var t

## Anciens noms (avant le renommage du 2026-11-05) : ne doivent plus figurer comme nom d'un talent.
const OLD_PERK_NAMES: Array[String] = [
	"Esquive", "Studieux", "Mur de lances", "Tourbillon", "Riposte", "Coup de grâce", "Insaisissable", "Increvable", "Pied sûr",
	"Second souffle", "Cran", "Duelliste", "Maître d'épée", "Maître du fléau", "Prédateur", "Chef-né", "Dur à cuire", "Port d'armure",
]


func test_no_old_perk_names() -> void:
	var names: Dictionary = {}
	for k in Data.PERKS:
		var n: String = String(Data.PERKS[k]["n"])
		t.check(not names.has(n), "nom de talent unique : %s" % n)
		names[n] = k
	for old in OLD_PERK_NAMES:
		t.check(not names.has(old), "ancien nom absent des talents : %s" % old)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func test_credits_cover_assets() -> void:
	var credits: String = _read("res://assets/CREDITS.md")
	t.check(credits.length() > 500, "CREDITS.md lisible")
	var d := DirAccess.open("res://assets")
	t.check(d != null, "dossier assets ouvrable")
	if d == null:
		return
	for sub in d.get_directories():
		t.check(credits.contains(sub + "/"), "CREDITS.md cite le dossier assets/%s" % sub)
	# Nombre réel d'icônes de talents.
	var n_perk: int = 0
	for f in DirAccess.get_files_at("res://assets/perk_icons"):
		if f.ends_with(".svg"):
			n_perk += 1
	t.check(credits.contains("(%d fichiers" % n_perk), "CREDITS.md annonce %d icônes de talents" % n_perk)
	t.check(n_perk == Data.PERKS.size(), "une icône par talent (%d)" % n_perk)
	# Polices : texte de licence présent.
	var ofl: String = _read("res://assets/fonts/OFL.txt")
	t.check(ofl.contains("SIL OPEN FONT LICENSE Version 1.1"), "OFL.txt contient la licence")
	t.check(ofl.contains("Pirata") and ofl.contains("Alegreya Sans"), "OFL.txt cite les deux polices")
	# Chaque fichier audio est couvert par un préfixe de nom cité dans CREDITS.
	for sub in ["sfx", "music"]:
		for f in DirAccess.get_files_at("res://assets/audio/" + sub):
			if f.ends_with(".import"):
				continue
			var stem: String = f.get_basename()
			var prefix: String = stem.rstrip("0123456789").rstrip("_")
			t.check(credits.contains(stem) or credits.contains(prefix), "CREDITS.md couvre l'audio %s" % f)
