class_name Banner
extends RefCounted
## Bannière de la compagnie : {"primary": "rrggbb" ou "" (ocre d'origine des boucliers), "secondary": "rrggbb", "emblem": index de Data.BANNER_EMBLEMS}.
## Logique pure ; le dessin est dans scenes/banner/banner_view.gd.


static func is_hex_color(s: String) -> bool:
	return s.length() == 6 and s.is_valid_hex_number(false)


## Bannière lue dans une sauvegarde : toujours valide, avec les valeurs par défaut pour ce qui manque.
static func clean(raw: Variant) -> Dictionary:
	var out: Dictionary = Data.BANNER_DEFAULT.duplicate()
	if typeof(raw) == TYPE_DICTIONARY:
		var r: Dictionary = raw
		var p: String = str(r.get("primary", "")).to_lower()
		if p == "" or is_hex_color(p):
			out["primary"] = p
		var s: String = str(r.get("secondary", out["secondary"])).to_lower()
		if is_hex_color(s):
			out["secondary"] = s
		out["emblem"] = clampi(int(r.get("emblem", 0)), 0, Data.BANNER_EMBLEMS.size() - 1)
		out["pattern"] = clampi(int(r.get("pattern", 0)), 0, Data.BANNER_PATTERNS.size() - 1)
	return out


static func is_custom(b: Dictionary) -> bool:
	return str(b.get("primary", "")) != ""


## Couleur principale à afficher (ocre d'origine si aucune n'est choisie).
static func primary(b: Dictionary) -> Color:
	return Color(str(b["primary"])) if is_custom(b) else Color(str(Data.BANNER_COLORS[0]))


static func secondary(b: Dictionary) -> Color:
	return Color(str(b.get("secondary", Data.BANNER_DEFAULT["secondary"])))


## Nom de compagnie nettoyé : espaces rognés, longueur bornée, jamais vide.
static func clean_name(s: String) -> String:
	var n: String = s.strip_edges().replace("\n", " ")
	if n.length() > Data.COMPANY_NAME_MAX:
		n = n.substr(0, Data.COMPANY_NAME_MAX).strip_edges()
	return n if n != "" else Data.COMPANY_NAME_DEFAULT


## Motif du champ (index de Data.BANNER_PATTERNS) ; 0 = uni.
static func pattern(b: Dictionary) -> int:
	return clampi(int(b.get("pattern", 0)), 0, Data.BANNER_PATTERNS.size() - 1)


## Teinte du motif : plus sombre que la couleur principale, ou plus claire si celle-ci est déjà sombre.
static func pattern_color(b: Dictionary) -> Color:
	var p: Color = primary(b)
	return p.lightened(0.28) if p.get_luminance() < 0.2 else p.darkened(0.32)


## Un nom saisi est valide s'il compte entre COMPANY_NAME_MIN et COMPANY_NAME_MAX caractères (espaces rognés).
static func is_valid_name(s: String) -> bool:
	var n: String = s.strip_edges()
	return n.length() >= Data.COMPANY_NAME_MIN and n.length() <= Data.COMPANY_NAME_MAX


## Nom de compagnie suggéré au hasard (`avoid` : nom à ne pas reproduire d'affilée).
static func random_name(rng: RandomNumberGenerator, avoid: String = "") -> String:
	var pool: Array = Data.COMPANY_NAME_SUGGESTIONS.filter(func(n: Variant) -> bool: return str(n) != avoid)
	return str(pool[rng.randi() % pool.size()])


## Bannière tirée au hasard, toujours valide ; la couleur secondaire contraste avec la principale.
static func random_banner(rng: RandomNumberGenerator) -> Dictionary:
	var colors: Array = Data.BANNER_COLORS
	var p: String = str(colors[rng.randi() % colors.size()])
	var cands: Array = colors.filter(func(c: Variant) -> bool: return absf(Color(str(c)).get_luminance() - Color(p).get_luminance()) > 0.3)
	var s: String = str(cands[rng.randi() % cands.size()]) if not cands.is_empty() else "1d1a17"
	return clean({"primary": p, "secondary": s, "emblem": rng.randi() % Data.BANNER_EMBLEMS.size(), "pattern": rng.randi() % Data.BANNER_PATTERNS.size()})


## Fiche « Votre compagnie » → {"name", "banner"} validés (nom nettoyé, bannière valide). Logique pure de l'étape de création.
static func resolve_setup(setup: Dictionary) -> Dictionary:
	return {"name": clean_name(str(setup.get("name", ""))), "banner": clean(setup.get("banner", {}))}


## Fiche par défaut (parties de test, étape sautée).
static func default_setup() -> Dictionary:
	return {"name": Data.COMPANY_NAME_DEFAULT, "banner": Data.BANNER_DEFAULT.duplicate()}
