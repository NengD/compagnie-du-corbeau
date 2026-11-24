class_name Codex
extends RefCounted
## Encyclopédie en jeu (logique pure). Tout est lu dans les tables (Data.*, Seasons) : aucune valeur de règle n'est écrite ici.
## `categories()` -> [{id, n}] ; `entries(cat)` -> [{id, n, sub, ik, ikey}] ; `detail(cat, id)` -> {title, sub, ik, ikey, rows, text, links}.
## `ik` / `ikey` : genre et clé de l'icône ("weapon" | "head" | "body" | "shield" | "tool" | "perk" | "" ) résolue par l'écran.
## `links` : [{cat, id, n}] pour naviguer vers une fiche liée (maîtrise d'une arme, armes d'une famille…).

const CATS: Array = [
	{"id": "weapons", "n": "Armes"},
	{"id": "armors", "n": "Armures et boucliers"},
	{"id": "families", "n": "Familles et maîtrises"},
	{"id": "abilities", "n": "Capacités"},
	{"id": "tools", "n": "Outils de jet"},
	{"id": "perks", "n": "Talents"},
	{"id": "traits", "n": "Traits de caractère"},
	{"id": "injuries", "n": "Blessures"},
	{"id": "factions", "n": "Factions"},
	{"id": "foes", "n": "Bestiaire"},
	{"id": "terrain", "n": "Terrains et décors"},
	{"id": "battles", "n": "Types de bataille"},
	{"id": "seasons", "n": "Saisons"},
]


static func categories() -> Array:
	return CATS.duplicate(true)


static func cat_name(cat: String) -> String:
	for c in CATS:
		if str(c["id"]) == cat:
			return str(c["n"])
	return cat


static func _e(id: String, n: String, sub: String = "", ik: String = "", ikey: String = "") -> Dictionary:
	return {"id": id, "n": n, "sub": sub, "ik": ik, "ikey": ikey}


# --- Listes ---

static func entries(cat: String) -> Array:
	var out: Array = []
	match cat:
		"weapons":
			for k in Data.WPN:
				var fam: String = Perks.weapon_family(str(k))
				var sub: String = Perks.family_name(fam) if fam != "" else "Arme de monstre"
				out.append(_e(str(k), str(Data.WPN[k]["n"]), sub, "weapon", str(k)))
		"armors":
			for k in Data.HEAD:
				if str(k) != "none":
					out.append(_e("head:" + str(k), str(Data.HEAD[k]["n"]), "Casque", "head", str(k)))
			for k in Data.BODY:
				if str(k) != "none":
					out.append(_e("body:" + str(k), str(Data.BODY[k]["n"]), "Corps", "body", str(k)))
			out.append(_e("shield", str(Data.SHIELD["n"]), "Bouclier", "shield", "bouclier"))
		"families":
			for k in Data.WEAPON_FAMILIES:
				out.append(_e(str(k), str(Data.WEAPON_FAMILIES[k]["n"]), "Armes", "perk", str(Data.WEAPON_FAMILIES[k]["mastery"])))
			for k in Data.ARMOR_FAMILIES:
				out.append(_e(str(k), str(Data.ARMOR_FAMILIES[k]["n"]), "Armures", "perk", str(Data.ARMOR_FAMILIES[k]["mastery"])))
		"abilities":
			for k in Data.ABILITIES:
				out.append(_e(str(k), str(Data.ABILITIES[k]["n"])))
		"tools":
			for k in Data.TOOLS:
				out.append(_e(str(k), str(Data.TOOLS[k]["n"]), "", "tool", str(k)))
		"perks":
			var keys: Array = Data.PERKS.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool:
				var ta: int = int(Data.PERKS[a]["tier"])
				var tb: int = int(Data.PERKS[b]["tier"])
				return ta < tb or (ta == tb and int(Data.PERKS[a]["col"]) < int(Data.PERKS[b]["col"])))
			for k in keys:
				out.append(_e(str(k), str(Data.PERKS[k]["n"]), "Rang %d" % int(Data.PERKS[k]["tier"]), "perk", str(k)))
		"traits":
			for k in Data.TRAITS:
				out.append(_e(str(k), str(Data.TRAITS[k]["n"]), _tone(str(Data.TRAITS[k].get("tone", "mixed")))))
		"injuries":
			for k in Data.INJURIES:
				out.append(_e(str(k), str(Data.INJURIES[k]["n"]), "Définitive" if bool(Data.INJURIES[k]["perm"]) else "Temporaire"))
		"factions":
			for k in Data.FACTIONS:
				out.append(_e(str(k), str(Data.FACTIONS[k]["n"]), "Maison ou ligue"))
			for k in Data.FACTION_NAMES:
				out.append(_e("enemy:" + str(k), _cap(str(Data.FACTION_NAMES[k])), "Ennemis"))
		"foes":
			for k in Data.FOE:
				out.append(_e(str(k), str(Data.FOE[k]["n"]), _cap(str(Data.FACTION_NAMES.get(str(Data.FOE[k]["fac"]), "")))))
		"terrain":
			for k in Data.TERRAIN:
				out.append(_e("t:" + str(k), str(Data.TERRAIN[k]["n"]), "Terrain"))
			for k in Data.SCENERY:
				out.append(_e("s:" + str(k), str(Data.SCENERY[k]["n"]), "Décor"))
		"battles":
			for k in Data.BATTLE_TYPES:
				out.append(_e(str(k), str(Data.BATTLE_TYPE_NAMES.get(k, k))))
		"seasons":
			for s in Seasons.SEASONS:
				out.append(_e(str(s["id"]), str(s["n"])))
	return out


## Entrées de `cat` dont le nom ou le sous-titre contient `query` (insensible à la casse) ; tout si `query` est vide.
static func search(cat: String, query: String) -> Array:
	var q: String = query.strip_edges().to_lower()
	var all: Array = entries(cat)
	if q == "":
		return all
	return all.filter(func(e: Dictionary) -> bool: return str(e["n"]).to_lower().contains(q) or str(e["sub"]).to_lower().contains(q))


## Nombre total de fiches (toutes catégories).
static func total() -> int:
	var n: int = 0
	for c in CATS:
		n += entries(str(c["id"])).size()
	return n


# --- Fiches ---

static func detail(cat: String, id: String) -> Dictionary:
	var d: Dictionary = {"title": id, "sub": "", "ik": "", "ikey": "", "rows": [], "text": [], "links": []}
	match cat:
		"weapons":
			_weapon(d, id)
		"armors":
			_armor(d, id)
		"families":
			_family(d, id)
		"abilities":
			_ability(d, id)
		"tools":
			_tool(d, id)
		"perks":
			_perk(d, id)
		"traits":
			_trait(d, id)
		"injuries":
			_injury(d, id)
		"factions":
			_faction(d, id)
		"foes":
			_foe(d, id)
		"terrain":
			_terrain(d, id)
		"battles":
			_battle(d, id)
		"seasons":
			_season(d, id)
	return d


## Une fiche est « vide » si elle n'a ni titre lisible, ni ligne, ni texte.
static func is_empty_detail(d: Dictionary) -> bool:
	return str(d.get("title", "")) == "" or ((d["rows"] as Array).is_empty() and (d["text"] as Array).is_empty())


static func _link(d: Dictionary, cat: String, id: String, n: String) -> void:
	(d["links"] as Array).append({"cat": cat, "id": id, "n": n})


static func _row(d: Dictionary, k: String, v: Variant) -> void:
	(d["rows"] as Array).append([k, str(v)])


static func _txt(d: Dictionary, t: String) -> void:
	if t != "":
		(d["text"] as Array).append(t)


static func _num(v: float) -> String:
	var s: String = ("%.2f" % v).rstrip("0").rstrip(".")
	return s.replace(".", ",")


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s


static func _tone(t: String) -> String:
	return {"good": "Atout", "bad": "Défaut", "mixed": "Double tranchant"}.get(t, "Trait")


static func _stat_fx(fx: Dictionary) -> String:
	var parts: Array[String] = []
	for k in fx:
		var v: int = int(fx[k])
		parts.append("%s %s%d" % [Data.STAT_NAMES.get(k, k), "+" if v > 0 else "−", absi(v)])
	return ", ".join(parts)


static func _perk_link(d: Dictionary, pk: String) -> void:
	if Data.PERKS.has(pk):
		_link(d, "perks", pk, str(Data.PERKS[pk]["n"]))


static func _weapon(d: Dictionary, k: String) -> void:
	var w: Dictionary = Data.WPN.get(k, {})
	if w.is_empty():
		return
	d["title"] = str(w["n"])
	d["ik"] = "weapon"
	d["ikey"] = k
	var fam: String = Perks.weapon_family(k)
	d["sub"] = ("Famille : " + Perks.family_name(fam)) if fam != "" else "Arme de monstre : aucune famille, jamais portée par la compagnie"
	_row(d, "Dégâts", "%d–%d" % [int(w["min"]), int(w["max"])])
	_row(d, "Efficacité contre l'armure", "×" + _num(float(w["arm"])))
	_row(d, "Traversée de l'armure", "%d %%" % int(round(float(w["ign"]) * 100.0)))
	_row(d, "Points d'action", int(w["ap"]))
	_row(d, "Fatigue par attaque", int(w["fat"]))
	_row(d, "Bonus au toucher", "%+d %%" % int(w["hit"]))
	_row(d, "Portée", "%d case%s" % [int(w["rng"]), "s" if int(w["rng"]) > 1 else ""])
	_row(d, "Prise", "Une main (bouclier possible)" if bool(w.get("h1", false)) else "Deux mains")
	if int(w.get("price", 0)) > 0:
		_row(d, "Prix de base", "%d couronnes" % int(w["price"]))
	_txt(d, str(w.get("note", "")))
	if Data.UNIQUES.has(k):
		_txt(d, "Objet unique. " + str(Data.UNIQUES[k].get("story", "")))
	if fam != "":
		var fd: Dictionary = Data.WEAPON_FAMILIES[fam]
		_txt(d, "Renforcée par la maîtrise « %s » (rang 4) puis le talent expert « %s » (rang 6), tant que l'arme réellement portée est de la famille %s." % [Data.PERKS[fd["mastery"]]["n"], Data.PERKS[fd["expert"]]["n"], Perks.family_name(fam).to_lower()])
		_link(d, "families", fam, Perks.family_name(fam))
		_perk_link(d, str(fd["mastery"]))
		_perk_link(d, str(fd["expert"]))
	var base: String = Perks.weapon_base(k)
	for a in Data.ABILITIES:
		var ws: Array = Data.ABILITIES[a]["weapons"]
		if ws.has(k) or ws.has(base):
			_link(d, "abilities", str(a), "Capacité : " + str(Data.ABILITIES[a]["n"]))
	for a in Data.ABILITIES:
		if bool(Data.ABILITIES[a].get("needs_shield", false)) and bool(w.get("h1", false)):
			_link(d, "abilities", str(a), "Avec bouclier : " + str(Data.ABILITIES[a]["n"]))


static func _armor(d: Dictionary, id: String) -> void:
	var slot: String = "shield"
	var k: String = "bouclier"
	var t: Dictionary = {}
	if id == "shield":
		t = Data.SHIELD
	else:
		slot = id.get_slice(":", 0)
		k = id.get_slice(":", 1)
		t = (Data.HEAD if slot == "head" else Data.BODY).get(k, {})
	if t.is_empty():
		return
	d["title"] = str(t["n"])
	d["ik"] = slot
	d["ikey"] = k
	d["sub"] = {"head": "Casque", "body": "Armure de corps", "shield": "Bouclier"}[slot]
	if slot == "shield":
		_row(d, "Poids", int(t["w"]))
		_row(d, "Durabilité", int(t["dur"]))
		_row(d, "Prix de base", "%d couronnes" % int(t["price"]))
		_txt(d, "Se porte avec une arme à une main. Défense accrue contre les attaques de mêlée et à distance ; il s'use sous les coups.")
		var fb: Dictionary = Data.WEAPON_FAMILIES["bouclier"]
		_link(d, "families", "bouclier", "Boucliers")
		_perk_link(d, str(fb["mastery"]))
		_perk_link(d, str(fb["expert"]))
		return
	_row(d, "Armure", int(t["a"]))
	_row(d, "Poids", int(t["w"]))
	_row(d, "Prix de base", "%d couronnes" % int(t["price"]))
	var fam: String = Perks.armor_family(slot, k)
	if fam != "":
		var af: Dictionary = Data.ARMOR_FAMILIES[fam]
		d["sub"] += " · " + Perks.family_name(fam)
		_txt(d, "Renforcée par la maîtrise « %s » (rang 4) et le talent expert « %s » (rang 6), quand l'équipement réel de l'homme est de la famille %s." % [Data.PERKS[af["mastery"]]["n"], Data.PERKS[af["expert"]]["n"], Perks.family_name(fam).to_lower()])
		_link(d, "families", fam, Perks.family_name(fam))
		_perk_link(d, str(af["mastery"]))
		_perk_link(d, str(af["expert"]))
	if Data.UNIQUES.has(k):
		_txt(d, "Objet unique. " + str(Data.UNIQUES[k].get("story", "")))


static func _family(d: Dictionary, fam: String) -> void:
	var is_w: bool = Data.WEAPON_FAMILIES.has(fam)
	var fd: Dictionary = Data.WEAPON_FAMILIES.get(fam, Data.ARMOR_FAMILIES.get(fam, {}))
	if fd.is_empty():
		return
	d["title"] = str(fd["n"])
	d["sub"] = "Famille d'armes" if is_w else "Famille d'armures"
	d["ik"] = "perk"
	d["ikey"] = str(fd["mastery"])
	_row(d, "Maîtrise (rang 4)", Data.PERKS[fd["mastery"]]["n"])
	_row(d, "Talent expert (rang 6)", Data.PERKS[fd["expert"]]["n"])
	if is_w and str(fd.get("dmg_type", "")) != "":
		_row(d, "Type de dégâts", _cap(str(fd["dmg_type"])))
	_row(d, "Objets de la famille", Perks.family_members(fam))
	_txt(d, "Les effets de la maîtrise et du talent expert ne jouent qu'avec l'équipement RÉEL de la famille ; sans maîtrise, l'arme ou l'armure reste utilisable.")
	if not is_w and str(fd.get("rule", "")) == "all":
		_txt(d, "Il faut porter la tenue complète (tête et corps) de cette famille.")
	if is_w:
		for w in fd["weapons"]:
			_link(d, "weapons", str(w), str(Data.WPN[w]["n"]))
	else:
		for kk in fd["head"]:
			if str(kk) != "none":
				_link(d, "armors", "head:" + str(kk), str(Data.HEAD[kk]["n"]))
		for kk in fd["body"]:
			if str(kk) != "none":
				_link(d, "armors", "body:" + str(kk), str(Data.BODY[kk]["n"]))
	if fam == "bouclier":
		_link(d, "armors", "shield", str(Data.SHIELD["n"]))
	_perk_link(d, str(fd["mastery"]))
	_perk_link(d, str(fd["expert"]))


static func _ability(d: Dictionary, k: String) -> void:
	var a: Dictionary = Data.ABILITIES.get(k, {})
	if a.is_empty():
		return
	d["title"] = str(a["n"])
	d["sub"] = "Capacité active d'arme"
	if a.has("ap_extra"):
		_row(d, "PA en plus d'une attaque", int(a["ap_extra"]))
	if a.has("ap"):
		_row(d, "Points d'action", int(a["ap"]))
	if a.has("fat_extra"):
		_row(d, "Fatigue en plus", int(a["fat_extra"]))
	if a.has("fat"):
		_row(d, "Fatigue", int(a["fat"]))
	if a.has("hit"):
		_row(d, "Toucher", "%+d %%" % int(a["hit"]))
	var ws: Array = a.get("weapons", [])
	var names: Array[String] = []
	for w in ws:
		if Data.WPN.has(w):
			names.append(str(Data.WPN[w]["n"]))
			_link(d, "weapons", str(w), str(Data.WPN[w]["n"]))
	if not names.is_empty():
		_row(d, "Armes", ", ".join(names))
	if bool(a.get("needs_shield", false)):
		_row(d, "Condition", "Porter un bouclier")
	if bool(a.get("needs_target_shield", false)):
		_row(d, "Condition", "La cible porte un bouclier")
	_txt(d, str(a.get("d", "")))


static func _tool(d: Dictionary, k: String) -> void:
	var t: Dictionary = Data.TOOLS.get(k, {})
	if t.is_empty():
		return
	d["title"] = str(t["n"])
	d["sub"] = "Outil de jet"
	d["ik"] = "tool"
	d["ikey"] = k
	_row(d, "Prix de base", "%d couronnes" % int(t["price"]))
	_row(d, "Utilisations par bataille", int(t["uses"]))
	_txt(d, str(t.get("note", "")))
	var ab: String = str(t.get("ab", ""))
	if Data.ABILITIES.has(ab):
		_link(d, "abilities", ab, str(Data.ABILITIES[ab]["n"]))


static func _perk(d: Dictionary, k: String) -> void:
	var p: Dictionary = Data.PERKS.get(k, {})
	if p.is_empty():
		return
	d["title"] = str(p["n"])
	d["ik"] = "perk"
	d["ikey"] = k
	d["sub"] = "Rang %d · %s" % [int(p["tier"]), str(Data.PERK_FAMILIES.get(p["fam"], {}).get("n", ""))]
	_row(d, "Rang", "%d (il faut %d talent%s appris avant)" % [int(p["tier"]), Perks.needed_before(k), "s" if Perks.needed_before(k) > 1 else ""])
	if p.has("req"):
		_row(d, "Exige", Data.PERKS[p["req"]]["n"])
		_perk_link(d, str(p["req"]))
	if p.has("stat"):
		_row(d, "Attributs", _stat_fx(p["stat"]))
	var fam: String = Perks.family_of_perk(k)
	if fam != "":
		_row(d, "Famille d'équipement", Perks.family_name(fam))
		_row(d, "Équipement concerné", Perks.family_members(fam))
		_link(d, "families", fam, Perks.family_name(fam))
	_txt(d, str(p["d"]))
	for o in Data.PERKS:
		if str(Data.PERKS[o].get("req", "")) == k:
			_perk_link(d, str(o))


static func _trait(d: Dictionary, k: String) -> void:
	var t: Dictionary = Data.TRAITS.get(k, {})
	if t.is_empty():
		return
	d["title"] = str(t["n"])
	d["sub"] = _tone(str(t.get("tone", "mixed")))
	_txt(d, str(t["d"]))
	if t.has("wage"):
		_row(d, "Solde", "×" + _num(float(t["wage"])))
	if t.has("stat"):
		_row(d, "Attributs", _stat_fx(t["stat"]))
	if (d["rows"] as Array).is_empty():
		_row(d, "Effet", "En bataille ou au camp (voir description)")


static func _injury(d: Dictionary, k: String) -> void:
	var inj: Dictionary = Data.INJURIES.get(k, {})
	if inj.is_empty():
		return
	d["title"] = str(inj["n"])
	var perm: bool = bool(inj["perm"])
	d["sub"] = "Blessure définitive" if perm else "Blessure temporaire"
	if perm:
		_row(d, "Durée", "Définitive")
	else:
		var days: Array = inj["days"]
		_row(d, "Durée", "%d à %d jours (moins avec le repos en ville et l'infirmerie)" % [int(days[0]), int(days[1])])
	_row(d, "Effet", _stat_fx(inj["fx"]))
	_txt(d, "Une blessure se reçoit en bataille quand un homme tombe au sol sans mourir." if not perm else "Elle reste pour la vie de l'homme.")


static func _faction(d: Dictionary, id: String) -> void:
	if id.begins_with("enemy:"):
		var ek: String = id.trim_prefix("enemy:")
		if not Data.FACTION_NAMES.has(ek):
			return
		d["title"] = _cap(str(Data.FACTION_NAMES[ek]))
		d["sub"] = "Ennemis des contrats et de la route"
		if Data.FACTION_LEADER.has(ek):
			var lead: String = str(Data.FACTION_LEADER[ek])
			_row(d, "Chef (cible des chasses)", Data.FOE[lead]["n"])
			_link(d, "foes", lead, str(Data.FOE[lead]["n"]))
		var names: Array[String] = []
		for f in Data.FOE:
			if str(Data.FOE[f]["fac"]) == ek:
				names.append(str(Data.FOE[f]["n"]))
				_link(d, "foes", str(f), str(Data.FOE[f]["n"]))
		_row(d, "Composition", ", ".join(names))
		return
	var f: Dictionary = Data.FACTIONS.get(id, {})
	if f.is_empty():
		return
	d["title"] = str(f["n"])
	d["sub"] = "Région : %s" % str(f.get("region", ""))
	_row(d, "Capitale", f.get("capital", ""))
	_row(d, "Région", f.get("region", ""))
	_row(d, "Lieux", ", ".join((f.get("places", []) as Array).slice(0, 6).map(func(p: Variant) -> String: return str(p))) + "…")
	_txt(d, str(f["desc"]))
	_txt(d, "Votre réputation auprès d'une faction change les primes, les contrats, les recrues et le marchand rare.")


static func _foe(d: Dictionary, k: String) -> void:
	var f: Dictionary = Data.FOE.get(k, {})
	if f.is_empty():
		return
	d["title"] = str(f["n"])
	d["sub"] = _cap(str(Data.FACTION_NAMES.get(str(f["fac"]), "")))
	_row(d, "PV", "%d–%d" % [int(f["hp"][0]), int(f["hp"][1])])
	_row(d, "Att. mêlée", "%d–%d" % [int(f["mSk"][0]), int(f["mSk"][1])])
	_row(d, "Att. distance", "%d–%d" % [int(f["rSk"][0]), int(f["rSk"][1])])
	_row(d, "Déf. mêlée", "%d–%d" % [int(f["mDef"][0]), int(f["mDef"][1])])
	_row(d, "Déf. distance", "%d–%d" % [int(f["rDef"][0]), int(f["rDef"][1])])
	_row(d, "Détermination", "%d–%d" % [int(f["res"][0]), int(f["res"][1])])
	_row(d, "Initiative", "%d–%d" % [int(f["ini"][0]), int(f["ini"][1])])
	var ws: Array[String] = []
	for w in f["w"]:
		if Data.WPN.has(w):
			ws.append(str(Data.WPN[w]["n"]))
			_link(d, "weapons", str(w), str(Data.WPN[w]["n"]))
	_row(d, "Armes", ", ".join(ws))
	_row(d, "Expérience donnée", int(f["xp"]))
	if bool(f.get("leader", false)):
		_txt(d, "Chef : sa mort ébranle le moral de ses hommes.")
	if bool(f.get("flank", false)):
		_txt(d, "Se jette sur les flancs et l'arrière de la ligne.")
	for pk in f.get("perks", []):
		_perk_link(d, str(pk))
		_txt(d, "Talent : " + str(Data.PERKS[pk]["n"]) + " — " + str(Data.PERKS[pk]["d"]))


static func _terrain(d: Dictionary, id: String) -> void:
	var k: String = id.get_slice(":", 1)
	if id.begins_with("t:"):
		var t: Dictionary = Data.TERRAIN.get(k, {})
		if t.is_empty():
			return
		d["title"] = str(t["n"])
		d["sub"] = "Terrain de bataille"
		_row(d, "Coût de déplacement", "%d PA" % int(t["ap"]))
		_row(d, "Fatigue supplémentaire", int(t["fat"]))
		if float(t["fat_mult"]) != 1.0:
			_row(d, "Fatigue de déplacement", "×" + _num(float(t["fat_mult"])))
		_row(d, "Bloque le passage", "Oui" if bool(t["block"]) else "Non")
		_row(d, "Bloque la ligne de tir", "Oui" if bool(t["los"]) else "Non")
		if int(t["h"]) != 0:
			_row(d, "Hauteur", int(t["h"]))
		if int(t["def"]) != 0:
			_row(d, "Défense", "%+d" % int(t["def"]))
		_txt(d, "Un obstacle sur la ligne de tir bloque les tirs ; une unité sur la ligne les gêne (−15 %).")
	else:
		var s: Dictionary = Data.SCENERY.get(k, {})
		if s.is_empty():
			return
		d["title"] = str(s["n"])
		d["sub"] = "Décor interactif"
		_row(d, "Points de structure", int(s["hp"]))
		_row(d, "Bloque le passage", "Oui" if bool(s["block"]) else "Non")
		_row(d, "Bloque la ligne de tir", "Oui" if bool(s["los"]) else "Non")
		if s.has("dmg"):
			_row(d, "Dégâts", "%d–%d" % [int(s["dmg"][0]), int(s["dmg"][1])])
		if s.has("open_ap"):
			_row(d, "Ouvrir", "%d PA" % int(s["open_ap"]))
		if s.has("morale"):
			_row(d, "Moral", "%+d" % int(s["morale"]))
		if s.has("light"):
			_row(d, "Lumière (cases)", int(s["light"]))
		_txt(d, "Le décor se détruit, s'ouvre ou s'enflamme pendant la bataille.")


static func _battle(d: Dictionary, k: String) -> void:
	if not Data.BATTLE_TYPES.has(k):
		return
	d["title"] = str(Data.BATTLE_TYPE_NAMES.get(k, k))
	d["sub"] = "Type de bataille"
	_row(d, "Clé", k)
	if k == "night":
		_row(d, "Vision de chaque camp", "%d cases" % int(Data.NIGHT_SIGHT))
	var texts: Dictionary = {
		"pitched": "Deux lignes face à face sur un terrain ouvert : le combat le plus courant.",
		"ambush": "L'ennemi frappe de côté ou par surprise : la compagnie démarre en désordre.",
		"convoy": "Il faut défendre ou intercepter un convoi qui avance sur le plateau.",
		"siege": "Remparts, portes et barricades : on prend ou l'on défend une position.",
		"night": "La vue est réduite à quelques cases ; les feux éclairent le plateau.",
		"defense": "On défend un lieu : défenses posées avant le combat, miliciens alliés, villageois à protéger, assaillants en plusieurs vagues.",
	}
	_txt(d, str(texts.get(k, "")))


static func _season(d: Dictionary, id: String) -> void:
	for s in Seasons.SEASONS:
		if str(s["id"]) == id:
			d["title"] = str(s["n"])
			d["sub"] = "Saison de %d jours" % Seasons.SEASON_DAYS
			_row(d, "Vitesse de marche", "×" + _num(float(s["travel"])))
			_row(d, "Rations consommées", "×" + _num(float(s["food"])))
			_row(d, "Prix des vivres", "×" + _num(float(s["food_price"])))
			_txt(d, str(s["d"]))
			return
