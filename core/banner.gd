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
