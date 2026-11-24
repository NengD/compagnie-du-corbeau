class_name FuzzyTranslation
extends Translation
## Traduction « tolérante » français -> anglais.
## Le français du jeu sert de clé (msgid). Au-delà de la correspondance exacte, une phrase construite à l'exécution
## (`"%s frappe %s" % [a, b]`, bannières BBCode, listes séparées par « · ») est retrouvée ainsi :
##   1. gabarit : un msgid contenant %s / %d / %+d / %.1f est compilé en expression régulière ; les arguments
##      captés sont eux-mêmes traduits (nom d'arme, de lieu connu...) puis réinsérés dans le gabarit anglais ;
##   2. balises BBCode : le texte entre les balises est traduit morceau par morceau ;
##   3. séparateurs (retour à la ligne, « · », « — », « ; », « , ») : chaque segment est traduit à part.
## Convention de pluriel dans un gabarit anglais : « %d day|%d days » (singulier si le premier nombre vaut 1).
## Dans le gabarit anglais, %1$s, %2$d... permettent de changer l'ordre des arguments.
## Rien n'est jamais inventé : une chaîne inconnue reste en français (valeur vide renvoyée au moteur).

const SEPARATORS: Array = ["\n", " · ", " — ", " ; ", "; ", " : ", ", "]
const MAX_DEPTH: int = 5
const GENERIC_FIXED: int = 4  ## en dessous de ce nombre de lettres fixes, un gabarit est « générique » (« %s : %s », « %s (%d) »)
const CACHE_LIMIT: int = 6000

var exact: Dictionary = {}  ## msgid français -> anglais (sans marqueurs de format)
var templates: Dictionary = {}  ## première lettre du préfixe fixe -> Array de gabarits compilés ("" : commencent par un marqueur)
var template_count: int = 0

var _cache: Dictionary = {}
var _seg: Dictionary = {}  ## cache des segments (texte -> traduction), pour les journaux qui se répètent
var _tag_re: RegEx = RegEx.create_from_string("\\[/?[a-zA-Z][^\\]]*\\]")
var _marker_re: RegEx = RegEx.create_from_string("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdfxXc]|\\{[a-z_]+\\}")
var _pos_re: RegEx = RegEx.create_from_string("%([0-9])\\$[sdfxXc]|%%|%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdfxXc]|\\{([a-z_]+)\\}")


func _init() -> void:
	locale = "en"


## Ajoute des paires français -> anglais (les entrées à marqueurs deviennent des gabarits).
func add_pairs(pairs: Dictionary) -> void:
	for k in pairs:
		var fr: String = str(k)
		var en: String = str(pairs[k])
		if en == "":
			continue
		_add_one(fr, en)
		var sf: String = _core(fr)
		var se: String = _core(en)
		if sf != fr and sf != "" and se != "" and not pairs.has(sf):
			_add_one(sf, se)  ## « · portée %d » sert aussi quand le séparateur a été retiré (segment d'une liste)
	_cache.clear()
	_seg.clear()


## Texte sans espaces, sans retour à la ligne ni séparateur de tête (« · », « — », « ; », « , »).
static func _core(t: String) -> String:
	return t.strip_edges().lstrip("·—;,: ").strip_edges()


func _add_one(fr: String, en: String) -> void:
	if _marker_re.search(fr) != null:
		_add_template(fr, en)
		# Le gabarit brut (`I18n.t("Jour %d") % n`) est aussi une clé : forme plurielle, sans numéros de position.
		if en.find("$") == -1 and fr.find("{") == -1:
			exact[fr] = en.split("|")[en.count("|")]
	else:
		exact[fr] = en


func has_exact(fr: String) -> bool:
	return exact.has(fr) or _find_template_key(fr)


func _find_template_key(fr: String) -> bool:
	for b in templates:
		for t in templates[b]:
			if t["fr"] == fr:
				return true
	return false


func _add_template(fr: String, en: String) -> void:
	var rx := ""
	var kinds: Array = []
	var names: Array = []
	var pos: int = 0
	var s: String = fr
	for m in _marker_re.search_all(s):
		rx += _esc(s.substr(pos, m.get_start() - pos))
		var spec: String = m.get_string()
		var named: bool = spec.begins_with("{")
		var kind: String = "s" if named else spec[spec.length() - 1]
		kinds.append(kind)
		names.append(spec.substr(1, spec.length() - 2) if named else "")
		if named:
			rx += "(.+?)"
		elif kind == "s":
			rx += "(.*?)"
		else:
			rx += "([-+]?[0-9]+(?:[.,][0-9]+)?)"
		pos = m.get_end()
	rx += _esc(s.substr(pos))
	rx = rx.replace("%%", "%")  # après échappement : « %% » littéral
	var re := RegEx.create_from_string("(?s)^" + rx + "$")
	if re == null or not re.is_valid():
		return
	var first_mark: int = _marker_re.search(fr).get_start()
	var prefix: String = fr.substr(0, first_mark)
	var bucket: String = prefix.substr(0, 1) if prefix != "" else ""
	if not templates.has(bucket):
		templates[bucket] = []
	templates[bucket].append({"fr": fr, "re": re, "en": en, "kinds": kinds, "names": names, "fixed": _letters(_marker_re.sub(s, "", true))})
	template_count += 1


## Nombre de lettres d'un texte : mesure la part « fixe » d'un gabarit (peu de lettres = gabarit générique).
static func _letters(t: String) -> int:
	var n: int = 0
	for ch in t:
		if ch.to_upper() != ch.to_lower():
			n += 1
	return n


static func _esc(s: String) -> String:
	var out := ""
	for ch in s:
		if "\\.^$*+?()[]{}|".contains(ch):
			out += "\\" + ch
		else:
			out += ch
	return out


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s: String = String(src_message).replace("\r", "")  ## fins de ligne Windows des sources
	if _cache.has(s):
		return StringName(_cache[s])
	var res: String = translate_text(s, 0)
	if res == s:
		res = ""
	if _cache.size() > CACHE_LIMIT:
		_cache.clear()
	_cache[s] = res
	return StringName(res)


## Traduction d'un texte : renvoie le texte lui-même s'il n'y a rien à traduire.
func translate_text(s: String, depth: int) -> String:
	if s == "" or depth > MAX_DEPTH:
		return s
	if exact.has(s):
		return exact[s]
	if _seg.has(s):
		return _seg[s]
	var r: String = _translate_raw(s, depth)
	if _seg.size() > CACHE_LIMIT:
		_seg.clear()
	_seg[s] = r
	return r


func _translate_raw(s: String, depth: int) -> String:
	var core: String = s.strip_edges()
	if core != s and core != "":
		var lead: String = s.substr(0, s.length() - s.lstrip(" \t\n").length())
		var trail: String = s.substr(s.rstrip(" \t\n").length())
		var inner: String = translate_text(core, depth + 1)
		return lead + inner + trail if inner != core else s
	var t: String = _try_templates(s, depth, false)
	if t != "":
		return t
	if _tag_re.search(s) != null:
		var tb: String = _split_tags(s, depth)
		if tb != s:
			return tb
	for sep in SEPARATORS:
		if s.find(sep) != -1:
			var parts: PackedStringArray = s.split(sep)
			var changed: bool = false
			var out: PackedStringArray = PackedStringArray()
			for p in parts:
				var tp: String = translate_text(p, depth + 1)
				if tp != p:
					changed = true
				out.append(tp)
			if changed:
				return (": " if sep == " : " else sep).join(out)
	var tg: String = _try_templates(s, depth, true)
	if tg != "":
		return tg
	# « couronnes » / « aube » : mot isolé en minuscule -> forme à majuscule initiale, remise en minuscule
	if s.length() > 1 and s.unicode_at(0) != s.substr(0, 1).to_upper().unicode_at(0) and s.find(" ") == -1:
		var up: String = s.substr(0, 1).to_upper() + s.substr(1)
		var tu: String = translate_text(up, depth + 1)
		if tu != up and tu.length() > 1 and tu.substr(1, 1) == tu.substr(1, 1).to_lower():
			return tu.substr(0, 1).to_lower() + tu.substr(1)
	# MAJUSCULES (en-têtes) : traduit la forme « Majuscule initiale » puis remet en capitales
	if s == s.to_upper() and s != s.to_lower() and s.length() > 1:
		var cap: String = s.substr(0, 1) + s.substr(1).to_lower()
		var tc: String = translate_text(cap, depth + 1)
		if tc != cap:
			return tc.to_upper()
	# « Texte [Espace] » : indication de raccourci en fin de ligne
	if s.ends_with("]") and s.rfind(" [") > 0:
		var cb: int = s.rfind(" [")
		var hh: String = s.substr(0, cb)
		var kk: String = s.substr(cb + 2, s.length() - cb - 3)
		var th2: String = translate_text(hh, depth + 1)
		var tk2: String = translate_text(kk, depth + 1)
		if th2 != hh or tk2 != kk:
			return th2 + " [" + tk2 + "]"
	# « Texte (détail) » : les deux parties sont traduites à part
	if s.ends_with(")") and s.find(" (") > 0:
		var cut: int = s.find(" (")
		var head: String = s.substr(0, cut)
		var inner2: String = s.substr(cut + 2, s.length() - cut - 3)
		var th: String = translate_text(head, depth + 1)
		var ti: String = translate_text(inner2, depth + 1)
		if th != head or ti != inner2:
			return th + " (" + ti + ")"
	# « Sanctuaire de la Veilleuse » : on cherche une coupe entre deux mots dont les deux côtés se traduisent
	# (ou dont un côté est un complément de nom propre : « de Haut-Regard »)
	var words: PackedStringArray = s.split(" ")
	if words.size() >= 2 and words.size() <= 8:
		var at: int = 0
		for i in range(1, words.size()):
			at += words[i - 1].length() + 1
			var left: String = s.substr(0, at - 1)
			var right: String = s.substr(at)
			var tl: String = translate_text(left, depth + 1)
			var tr_: String = translate_text(right, depth + 1)
			if tl != left and tr_ != right:
				return tl + " " + tr_
			if tl != left and (_is_name_tail(right) or _is_name(right)):
				return tl + " " + right
			if tr_ != right and (_is_name_tail(left) or _is_name(left)):
				return left + " " + tr_
	# « Texte. » : un point final retiré
	if s.ends_with(".") and not s.ends_with(".."):
		var base: String = s.substr(0, s.length() - 1)
		var tb2: String = translate_text(base, depth + 1)
		if tb2 != base:
			return tb2 + "."
	return s


## Nom propre probable : majuscule initiale, aucun chiffre, assez court (« Émeric », « Hervé l'Ours »).
func _is_name(t: String) -> bool:
	if t == "" or t.length() > 30 or t.unicode_at(0) == t.substr(0, 1).to_lower().unicode_at(0):
		return false
	for ch in t:
		if ch >= "0" and ch <= "9":
			return false
	return true


## Complément de nom propre (« de Haut-Regard », « du Loup Gris ») : conservé tel quel.
func _is_name_tail(t: String) -> bool:
	if not (t.begins_with("de ") or t.begins_with("du ") or t.begins_with("des ") or t.begins_with("d'") or t.begins_with("de la ") or t.begins_with("l'")):
		return false
	for ch in t:
		if ch != ch.to_lower():
			return true
	return false


func _split_tags(s: String, depth: int) -> String:
	var out := ""
	var pos: int = 0
	var changed: bool = false
	for m in _tag_re.search_all(s):
		var piece: String = s.substr(pos, m.get_start() - pos)
		var tp: String = translate_text(piece, depth + 1) if piece.strip_edges() != "" else piece
		if tp != piece:
			changed = true
		out += tp + m.get_string()
		pos = m.get_end()
	var rest: String = s.substr(pos)
	var tr_rest: String = translate_text(rest, depth + 1) if rest.strip_edges() != "" else rest
	if tr_rest != rest:
		changed = true
	return out + tr_rest if changed else s


## `generic` : gabarits presque sans texte fixe (« %s : %s ») ; ils passent après les séparateurs pour ne pas masquer une meilleure coupe.
func _try_templates(s: String, depth: int, generic: bool) -> String:
	var first: String = s.substr(0, 1)
	for bucket in [first, ""]:
		if not templates.has(bucket):
			continue
		for t in templates[bucket]:
			if (int(t["fixed"]) < GENERIC_FIXED) != generic:
				continue
			var m: RegExMatch = t["re"].search(s)
			if m == null:
				continue
			var args: Array = []
			for i in t["kinds"].size():
				var raw: String = m.get_string(i + 1)
				if t["kinds"][i] == "s":
					var tr_arg: String = translate_text(raw, depth + 1)
					args.append(tr_arg)
				else:
					args.append(raw)
			return _fill(str(t["en"]), args, t["kinds"], t["names"])
	return ""


func _fill(en: String, args: Array, kinds: Array, names: Array) -> String:
	var form: String = en
	if en.find("|") != -1:
		var sp: PackedStringArray = en.split("|")
		var n: float = 0.0
		for i in kinds.size():
			if kinds[i] != "s":
				n = absf(str(args[i]).strip_edges().to_float())
				break
		form = sp[0] if n == 1.0 else sp[sp.size() - 1]
	var out := ""
	var pos: int = 0
	var seq: int = 0
	for m in _pos_re.search_all(form):
		out += form.substr(pos, m.get_start() - pos)
		pos = m.get_end()
		var g: String = m.get_string()
		if g == "%%":
			out += "%"
			continue
		var idx: int
		if m.get_string(2) != "":
			idx = names.find(m.get_string(2))
		elif m.get_string(1) != "":
			idx = int(m.get_string(1)) - 1
		else:
			idx = seq
			seq += 1
		if idx >= 0 and idx < args.size():
			out += str(args[idx])
	return out + form.substr(pos)
