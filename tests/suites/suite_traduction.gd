extends RefCounted
## Traduction anglaise : le français reste identique, l'anglais couvre les chaînes prioritaires (menus, interface),
## le moteur de gabarits (FuzzyTranslation) se comporte comme documenté.
var t

const PRIORITY_ZONES: Array = ["a_menus", "b_jeu"]
const IGNORE_PATH: String = "res://translations/ignore.txt"


func _ignored() -> Dictionary:
	var d: Dictionary = {}
	var f := FileAccess.open(IGNORE_PATH, FileAccess.READ)
	if f == null:
		return d
	while not f.eof_reached():
		var ln: String = f.get_line()
		if ln != "":
			d[ln.replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")] = true
	return d


func test_francais_inchange() -> void:
	I18n.apply(0)
	t.eq(I18n.current(), "fr", "langue active : français")
	for s in ["Quitter", "Nouvelle partie", "Jour %d", "Compagnie du [color=#b03a2e]Corbeau[/color]", "Aucun texte connu de personne"]:
		t.eq(I18n.t(s), s, "en français, « %s » est rendu tel quel" % s)
	t.eq(I18n.t("Jour %d") % 4, "Jour 4", "gabarit français")
	t.eq(String(TranslationServer.translate("Options")), "Options", "TranslationServer en français")


func test_anglais_exact_et_retour() -> void:
	I18n.apply(1)
	t.eq(I18n.current(), "en", "langue active : anglais")
	t.eq(I18n.t("Quitter"), "Quit", "mot simple")
	t.eq(I18n.t("Nouvelle partie"), "New game", "menu")
	t.eq(I18n.t("Compagnie du [color=#b03a2e]Corbeau[/color]"), "Company of the [color=#b03a2e]Raven[/color]", "titre avec BBCode")
	t.eq(I18n.t("Texte que personne n'a traduit"), "Texte que personne n'a traduit", "chaîne inconnue : repli français")
	I18n.apply(0)
	t.eq(I18n.t("Quitter"), "Quitter", "retour au français à chaud")


func test_gabarits() -> void:
	I18n.apply(1)
	t.eq(I18n.t("Jour %d") % 12, "Day 12", "gabarit simple")
	t.eq(I18n.t("%d jours" % 5), "5 days", "gabarit reconnu après formatage")
	t.eq(I18n.t("%d jours" % 1), "1 day", "pluriel : singulier si le premier nombre vaut 1")
	t.eq(I18n.t("Contrat accepté : Traquer la Bande noire. Cap sur Gué-des-Ânes."), "Contract accepted: Hunt down the Black Band. Heading for Gué-des-Ânes.", "arguments traduits, noms propres conservés")
	t.eq(I18n.t("Jour 3 · Quitter"), "Day 3 · Quit", "liste séparée par « · »")
	t.eq(I18n.t("[b]Quitter[/b]"), "[b]Quit[/b]", "balises BBCode conservées")
	t.eq(I18n.t("JOUR"), "DAY", "en-tête en capitales")
	t.eq(I18n.t("Attendre [W]"), "Wait [W]", "raccourci entre crochets")
	t.eq(I18n.t("Brigands près de Hautes-Marches"), "Bandits near Hautes-Marches", "gabarit nommé {town}")
	I18n.apply(0)


func test_champ_langue_des_reglages() -> void:
	var S = load("res://autoload/Settings.gd")
	t.check(S.SCHEMA.has("language"), "réglage « language » dans le schéma")
	t.eq(int(S.SCHEMA["language"][2]), 0, "le français est la langue par défaut")
	t.eq(S.sanitize("language", 7), 1, "valeur hors bornes ramenée")
	t.eq(S.sanitize("language", "abc"), 0, "valeur illisible : français")
	t.eq(I18n.code_of(0), "fr", "index 0 = français")
	t.eq(I18n.index_of("en"), 1, "code en -> index 1")
	t.eq(I18n.index_of("xx"), 0, "langue inconnue -> français")


func test_couverture_prioritaire() -> void:
	## Aucune chaîne française visible des zones (a) menus et (b) interface ne doit rester sans traduction anglaise.
	I18n.reload()
	var cat: FuzzyTranslation = I18n.catalog_en()
	var ignored: Dictionary = _ignored()
	var scan := I18nScan.new()
	var missing: Array = []
	var seen: Dictionary = {}
	var total: int = 0
	for e in scan.scan_all():
		if not PRIORITY_ZONES.has(e["zone"]):
			continue
		var s: String = e["text"]
		if seen.has(s) or ignored.has(s):
			continue
		seen[s] = true
		total += 1
		if not cat.has_exact(s):
			missing.append("%s (%s:%d)" % [s.replace("\n", "\\n"), str(e["file"]).replace("res://", ""), e["line"]])
	t.check(total > 1000, "la liste prioritaire est non vide (%d chaînes)" % total)
	t.check(missing.is_empty(), "chaînes prioritaires sans traduction anglaise (%d) : %s" % [missing.size(), "; ".join(missing.slice(0, 12))])
