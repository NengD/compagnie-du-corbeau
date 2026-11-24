class_name I18n
extends RefCounted
## Langues du jeu. Le français est la langue source : les textes du code sont les clés (msgid) des traductions.
## Règle de langue : le français est TOUJOURS la langue par défaut, même si le système est en anglais ;
## le choix du joueur (Options > Jeu > Langue) est enregistré dans user://settings.cfg (clé `language`).
## L'anglais est un catalogue `translations/en*.po` chargé à la demande (FuzzyTranslation) ; en français, aucune
## traduction n'est enregistrée : le moteur rend le texte tel quel (comportement identique à l'avant-i18n).
##
## Usage dans le code : un texte fixe n'a rien à faire (les Label/Button/infobulles le traduisent seuls) ;
## un gabarit construit avec `%` ou `+` s'écrit `I18n.t("... %s ...") % args` (affichage français inchangé).

const LANGS: Array = [
	{"code": "fr", "name": "Français"},
	{"code": "en", "name": "English"},
]
const CATALOG_DIR: String = "res://translations"

static var _en: FuzzyTranslation = null
static var _loaded_files: Array = []
static var _code: String = "fr"


static func code_of(index: int) -> String:
	return str(LANGS[clampi(index, 0, LANGS.size() - 1)]["code"])


static func index_of(code: String) -> int:
	for i in LANGS.size():
		if LANGS[i]["code"] == code:
			return i
	return 0


static func names() -> Array:
	var out: Array = []
	for l in LANGS:
		out.append(str(l["name"]))
	return out


## Langue active (code) : celle du serveur de traduction, « fr » par défaut.
static func current() -> String:
	return _code


## Applique la langue (index dans LANGS) : enregistre ou retire le catalogue, puis fixe la locale.
## Les contrôles déjà affichés se retraduisent seuls (notification de changement de langue).
static func apply(index: int) -> void:
	var code: String = code_of(index)
	_code = code
	if code == "en":
		var en: FuzzyTranslation = catalog_en()
		if TranslationServer.get_translation_object("en") != en:
			TranslationServer.add_translation(en)
		TranslationServer.set_locale("en")
	else:
		if _en != null and TranslationServer.get_translations().has(_en):
			TranslationServer.remove_translation(_en)
		TranslationServer.set_locale("fr")


## Texte traduit (ou texte français inchangé). Utilisable partout, y compris dans les fonctions statiques.
static func t(msg: String) -> String:
	return String(TranslationServer.translate(msg))


## Singulier / pluriel selon n (les deux formes sont des clés du catalogue).
static func tn(one: String, other: String, n: int) -> String:
	return t(one if n == 1 or n == -1 else other)


## Catalogue anglais (chargé une fois : tous les fichiers translations/en*.po).
static func catalog_en() -> FuzzyTranslation:
	if _en == null:
		_en = FuzzyTranslation.new()
		for f in _po_files():
			var tr_res: Translation = load(f) as Translation
			if tr_res == null:
				continue
			var pairs: Dictionary = {}
			for k in tr_res.get_message_list():
				pairs[str(k)] = str(tr_res.get_message(k))
			_en.add_pairs(pairs)
			_loaded_files.append(f)
	return _en


## Recharge le catalogue (outils et tests qui modifient les fichiers).
static func reload() -> void:
	if _en != null and TranslationServer.get_translations().has(_en):
		TranslationServer.remove_translation(_en)
	_en = null
	_loaded_files.clear()


static func _po_files() -> Array:
	var out: Array = []
	var d := DirAccess.open(CATALOG_DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if not d.current_is_dir() and n.begins_with("en") and (n.ends_with(".po") or n.ends_with(".po.remap")):
			out.append(CATALOG_DIR + "/" + n.trim_suffix(".remap"))
		n = d.get_next()
	d.list_dir_end()
	out.sort()
	return out
