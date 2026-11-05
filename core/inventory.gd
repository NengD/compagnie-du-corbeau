class_name Inventory
extends RefCounted
## Gestion d'inventaire « à la Battle Brothers » : réserve commune (`stash`, tableau d'objets de `Loot`) et emplacements
## des hommes (tête, corps, arme, bouclier, 2 emplacements de sac). Logique pure, sans scène.
##
## Un emplacement est un dictionnaire : `Inventory.at(unit, "weapon")` ou `Inventory.in_stash(index)`.
## Toutes les opérations sont transactionnelles : en cas d'échec rien n'a changé. Elles renvoient
## `{"ok": bool, "msg": String}` (msg = raison de l'échec, ou remarque sur ce qui a été rangé en route).
##
## Règles : une arme à deux mains est incompatible avec le bouclier (équiper l'arme range le bouclier dans la réserve ;
## équiper le bouclier est refusé) ; seuls armes et boucliers vont dans un sac ; la réserve ne dépasse pas `cap` objets.

const UNIT_SLOTS: Array[String] = ["head", "body", "weapon", "shield", "bag0", "bag1"]
const BIG: int = 1000000
const SORT_MODES: Array[String] = ["type", "value", "wear"]
const FILTERS: Array[String] = ["all", "weapon", "head", "body", "shield"]
const KIND_ORDER: Dictionary = {"weapon": 0, "shield": 1, "head": 2, "body": 3, "tool": 4}


static func at(u: Unit, slot: String) -> Dictionary:
	return {"u": u, "slot": slot}


static func in_stash(i: int = -1) -> Dictionary:
	return {"u": null, "slot": "stash", "i": i}


static func is_stash(loc: Dictionary) -> bool:
	return loc["slot"] == "stash"


static func same_loc(a: Dictionary, b: Dictionary) -> bool:
	if a["slot"] != b["slot"] or a["u"] != b["u"]:
		return false
	return a["slot"] != "stash" or int(a.get("i", -1)) == int(b.get("i", -1))


static func slot_label(slot: String) -> String:
	match slot:
		"head":
			return "Tête"
		"body":
			return "Corps"
		"weapon":
			return "Main droite"
		"shield":
			return "Main gauche"
		"stash":
			return "Réserve"
	return "Sac %d" % (slot.substr(3).to_int() + 1)


static func ok(msg: String = "") -> Dictionary:
	return {"ok": true, "msg": msg}


static func fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}


# --- Lecture / écriture d'un emplacement ---

static func bag_index(slot: String) -> int:
	return slot.substr(3).to_int() if slot.begins_with("bag") else -1


## L'objet qui se trouve dans l'emplacement ({} si vide). Les pièces portées sont reconstruites avec leur usure / armure actuelles.
static func get_item(stash: Array, loc: Dictionary) -> Dictionary:
	var slot: String = loc["slot"]
	if slot == "stash":
		var i: int = int(loc.get("i", -1))
		return (stash[i] as Dictionary) if i >= 0 and i < stash.size() else {}
	var u: Unit = loc["u"]
	match slot:
		"head":
			return {} if u.head == "none" else Loot.with_armor(Loot.item("head", u.head), u.arm_h)
		"body":
			return {} if u.body == "none" else Loot.with_armor(Loot.item("body", u.body), u.arm_b)
		"weapon":
			return Loot.worn(Loot.item("weapon", u.weapon), u.weapon_dur_now()) if u.weapon_wears() else {}
		"shield":
			return Loot.worn(Loot.item("shield"), u.shield_dur_now()) if u.shield else {}
	var b: int = bag_index(slot)
	return u.bag[b] if b >= 0 and b < u.bag.size() else {}


static func _take(stash: Array, loc: Dictionary) -> Dictionary:
	var it: Dictionary = get_item(stash, loc)
	if it.is_empty():
		return it
	var slot: String = loc["slot"]
	if slot == "stash":
		stash.remove_at(int(loc["i"]))
		return it
	var u: Unit = loc["u"]
	match slot:
		"head":
			u.head = "none"
			u.arm_h = 0
		"body":
			u.body = "none"
			u.arm_b = 0
		"weapon":
			u.weapon = "poings"
			u.weapon_dur = -1
			u.ammo = -1
		"shield":
			u.shield = false
			u.shield_dur = -1
			u.shield_wall = false
		_:
			u.bag[bag_index(slot)] = {}
	return it


static func _put(stash: Array, loc: Dictionary, it: Dictionary) -> void:
	var slot: String = loc["slot"]
	if slot == "stash":
		stash.append(it)
		return
	var u: Unit = loc["u"]
	match slot:
		"head":
			u.head = str(it["key"])
			u.arm_h = Loot.armor_of(it)
		"body":
			u.body = str(it["key"])
			u.arm_b = Loot.armor_of(it)
		"weapon":
			u.weapon = str(it["key"])
			u.weapon_dur = Loot.dur_of(it) if it.has("dur") else -1
			u.ammo = int(Data.WPN[u.weapon].get("ammo", -1))
		"shield":
			u.shield = true
			u.shield_dur = Loot.dur_of(it) if it.has("dur") else -1
		_:
			u.bag[bag_index(slot)] = it


## L'emplacement accepte-t-il ce genre d'objet ?
static func accepts(slot: String, it: Dictionary) -> bool:
	var k: String = str(it["kind"])
	match slot:
		"stash":
			return true
		"head", "body", "weapon", "shield":
			return k == slot
	return k == "weapon" or k == "shield" or k == "tool"  # sac


## Raison pour laquelle `it` ne peut pas aller dans cet emplacement, "" si c'est permis.
static func why_not(loc: Dictionary, it: Dictionary) -> String:
	var slot: String = loc["slot"]
	if not accepts(slot, it):
		return "Cet emplacement n'accepte pas %s." % ("autre chose que des armes et boucliers" if slot.begins_with("bag") else "ce genre d'objet")
	if slot == "shield" and not bool((loc["u"] as Unit).weapon_data()["h1"]):
		return "Une arme à deux mains interdit le bouclier."
	return ""


# --- Opérations ---

static func _snap(u: Unit) -> Dictionary:
	if u == null:
		return {}
	return {"weapon": u.weapon, "weapon_dur": u.weapon_dur, "shield": u.shield, "shield_dur": u.shield_dur, "head": u.head,
		"body": u.body, "arm_h": u.arm_h, "arm_b": u.arm_b, "ammo": u.ammo, "shield_wall": u.shield_wall, "bag": u.bag.duplicate(true)}


static func _restore(u: Unit, s: Dictionary) -> void:
	if u == null:
		return
	for k in s:
		u.set(k, s[k])


## Déplace l'objet de `from` vers `to` (échange si `to` est occupé : l'ancien objet prend la place libérée si c'est permis,
## sinon il va dans la réserve). Une arme à deux mains qui arrive range le bouclier dans la réserve.
## Fonctionne entre emplacements d'un même homme, entre deux hommes (don), et vers/depuis la réserve.
static func move(stash: Array, from: Dictionary, to: Dictionary, cap: int = Data.STASH_SIZE) -> Dictionary:
	if same_loc(from, to) or (is_stash(from) and is_stash(to)):
		return fail("Rien à déplacer.")
	var it: Dictionary = get_item(stash, from)
	if it.is_empty():
		return fail("Emplacement vide.")
	var before: int = stash.size()
	var snap_stash: Array = stash.duplicate(true)
	var su1: Dictionary = _snap(from["u"])
	var su2: Dictionary = _snap(to["u"])
	var notes: Array[String] = []
	if not is_stash(to):
		var reason: String = why_not(to, it)
		if reason != "":
			return fail(reason)
	_take(stash, from)
	var displaced: Array = []
	if is_stash(to):
		_put(stash, to, it)
	else:
		var prev: Dictionary = _take(stash, to)
		var tu: Unit = to["u"]
		if str(to["slot"]) == "weapon" and not bool(Data.WPN[str(it["key"])]["h1"]) and tu.shield:
			var sh: Dictionary = _take(stash, at(tu, "shield"))
			displaced.append(sh)
			notes.append("Le bouclier est rangé dans la réserve.")
		_put(stash, to, it)
		if not prev.is_empty():
			var back: bool = not is_stash(from) and why_not(from, prev) == ""
			if back:
				_put(stash, from, prev)
			else:
				displaced.append(prev)
	stash.append_array(displaced)
	if stash.size() > cap and stash.size() > before:
		stash.clear()
		stash.append_array(snap_stash)
		_restore(from["u"], su1)
		_restore(to["u"], su2)
		return fail("Réserve pleine.")
	return ok(" ".join(notes))


## Emplacement naturel de l'objet pour `u` : tête, corps, arme, bouclier (sac si le bouclier est interdit), "" si rien.
static func auto_slot(u: Unit, it: Dictionary) -> String:
	var k: String = str(it["kind"])
	if k != "shield":
		return k
	if bool(u.weapon_data()["h1"]):
		return "shield"
	return "bag%d" % bag_free_slot(u) if bag_free_slot(u) >= 0 else ""


static func bag_free_slot(u: Unit) -> int:
	for i in u.bag.size():
		if (u.bag[i] as Dictionary).is_empty():
			return i
	return -1


## Équipe l'objet n° `index` de la réserve sur `u` (échange avec ce qui est porté).
static func equip(stash: Array, u: Unit, index: int, cap: int = Data.STASH_SIZE) -> Dictionary:
	if index < 0 or index >= stash.size():
		return fail("Objet introuvable.")
	var slot: String = auto_slot(u, stash[index])
	if slot == "":
		return fail("Une arme à deux mains interdit le bouclier (et le sac est plein).")
	return move(stash, in_stash(index), at(u, slot), cap)


## Range dans la réserve ce que porte `u` à cet emplacement.
static func unequip(stash: Array, u: Unit, slot: String, cap: int = Data.STASH_SIZE) -> Dictionary:
	return move(stash, at(u, slot), in_stash(), cap)


## Donne l'objet d'un emplacement de `from_u` à `to_u` (il va à son emplacement naturel).
static func give(stash: Array, from_u: Unit, slot: String, to_u: Unit, cap: int = Data.STASH_SIZE) -> Dictionary:
	var it: Dictionary = get_item(stash, at(from_u, slot))
	if it.is_empty():
		return fail("Emplacement vide.")
	var dest: String = auto_slot(to_u, it)
	if dest == "":
		return fail("%s ne peut pas porter cet objet." % to_u.unit_name)
	return move(stash, at(from_u, slot), at(to_u, dest), cap)


## Ajoute des objets à la réserve jusqu'à `cap`. Renvoie ceux qui n'ont pas pu y entrer.
static func add_items(stash: Array, items: Array, cap: int = Data.STASH_SIZE) -> Array:
	var overflow: Array = []
	for it in items:
		if stash.size() < cap:
			stash.append(it)
		else:
			overflow.append(it)
	return overflow


# --- Changement d'arme (sac <-> mains), utilisable en bataille ---

## Échange l'objet du sac n° `i` avec ce qui est porté (arme -> main droite, bouclier -> main gauche).
## L'objet retiré prend la place libérée ; un bouclier gêné par une arme à deux mains va dans l'autre emplacement du sac (sinon échec).
static func bag_swap(u: Unit, i: int) -> Dictionary:
	if i < 0 or i >= u.bag.size() or (u.bag[i] as Dictionary).is_empty():
		return fail("Rien dans ce sac.")
	var it: Dictionary = u.bag[i]
	if str(it["kind"]) == "tool":
		return fail("Un outil se lance, il ne s'équipe pas.")
	var snap: Dictionary = _snap(u)
	var tmp: Array = []
	var res: Dictionary = move(tmp, at(u, "bag%d" % i), at(u, "weapon" if str(it["kind"]) == "weapon" else "shield"), BIG)
	if not bool(res["ok"]):
		return res
	for d in tmp:
		var f: int = bag_free_slot(u)
		if f < 0:
			_restore(u, snap)
			return fail("Pas de place dans le sac pour ranger le bouclier.")
		u.bag[f] = d
	return ok("Le bouclier est rangé dans le sac." if not tmp.is_empty() else "")


## Raison pour laquelle l'échange avec le sac n° `i` est impossible, "" si possible (simulation sur une copie).
static func bag_swap_block(u: Unit, i: int) -> String:
	var res: Dictionary = bag_swap(u.duplicate_unit(), i)
	return "" if bool(res["ok"]) else str(res["msg"])


# --- Tri et filtre ---

## Indices de la réserve qui passent le filtre ("all", "weapon", "head", "body", "shield").
static func filtered(stash: Array, filter: String) -> Array[int]:
	var out: Array[int] = []
	for i in stash.size():
		if filter == "all" or str(stash[i]["kind"]) == filter:
			out.append(i)
	return out


## Trie la réserve : "type" (armes, boucliers, casques, armures ; puis du plus cher au moins cher), "value" (prix de revente décroissant),
## "wear" (les plus abîmés d'abord).
static func sort_stash(stash: Array, mode: String) -> void:
	var cmp := func(a: Dictionary, b: Dictionary) -> bool:
		match mode:
			"value":
				var sa: int = Loot.sell_base(a)
				var sb: int = Loot.sell_base(b)
				if sa != sb:
					return sa > sb
			"wear":
				var wa: float = Loot.wear_ratio(a)
				var wb: float = Loot.wear_ratio(b)
				if not is_equal_approx(wa, wb):
					return wa < wb
			_:
				var ka: int = int(KIND_ORDER[str(a["kind"])])
				var kb: int = int(KIND_ORDER[str(b["kind"])])
				if ka != kb:
					return ka < kb
				var pa: int = Loot.base_price(a)
				var pb: int = Loot.base_price(b)
				if pa != pb:
					return pa > pb
		return Loot.item_name(a) + str(a["key"]) < Loot.item_name(b) + str(b["key"])
	stash.sort_custom(cmp)


# --- Aperçu ---

## Poids et effets sur l'endurance / l'initiative, pour l'affichage.
static func stats(u: Unit) -> Dictionary:
	return {"weight": u.weight(), "fat": u.fat_max_eff(), "ini": u.ini_eff(), "arm_h": u.arm_h, "arm_b": u.arm_b}


## Statistiques de `u` si on déplaçait l'objet de `from` vers `to` (calcul sur copies ; `from`/`to` peuvent désigner `u`).
## Renvoie {} si le déplacement est impossible.
static func preview(stash: Array, u: Unit, from: Dictionary, to: Dictionary) -> Dictionary:
	var copy: Unit = u.duplicate_unit()
	var s2: Array = stash.duplicate(true)
	var f: Dictionary = from.duplicate()
	var t: Dictionary = to.duplicate()
	for loc in [f, t]:
		if loc["u"] == u:
			loc["u"] = copy
		elif loc["u"] != null:
			loc["u"] = (loc["u"] as Unit).duplicate_unit()
	if not bool(move(s2, f, t, BIG)["ok"]):
		return {}
	return stats(copy)


# --- Texte ---

## Infobulle détaillée d'un objet (`sell` : prix de vente ici, -1 si on ne peut pas vendre).
## `who` : l'homme qui regarde l'objet (facultatif) ; sert à dire si la maîtrise de la famille de l'objet est apprise.
static func tooltip(it: Dictionary, sell: int = -1, who: Unit = null) -> String:
	if it.is_empty():
		return ""
	var d: Dictionary = Loot.data_of(it)
	var lines: Array[String] = [Loot.item_name(it)]
	var key: String = str(it["key"])
	match str(it["kind"]):
		"weapon":
			lines.append("Dégâts %d–%d · %s" % [d["min"], d["max"], "une main" if bool(d["h1"]) else "deux mains"])
			lines.append("Efficacité contre l'armure ×%s · traversée %d %%" % [str(d["arm"]), roundi(float(d["ign"]) * 100.0)])
			lines.append("Portée %d · %d PA · %d fatigue" % [d["rng"], d["ap"], d["fat"]])
			if int(d["hit"]) != 0:
				lines.append("Toucher %+d %%" % int(d["hit"]))
			if d.has("ammo"):
				lines.append("%d projectiles par bataille" % int(d["ammo"]))
		"shield":
			lines.append("Défense mêlée +15, distance +25 · mur de boucliers")
			lines.append("Poids %d · exige une arme à une main" % int(d["w"]))
		"head", "body":
			lines.append("Armure %d/%d · poids %d" % [Loot.armor_of(it), d["a"], d["w"]])
	var mline: String = Perks.mastery_line(who, str(it["kind"]), key)
	if mline != "":
		lines.append(mline if who != null else mline.replace(" (non apprise)", ""))
	if Loot.dur_max(it) > 0:
		lines.append("Durabilité %d/%d" % [Loot.dur_of(it), Loot.dur_max(it)])
	if d.get("note", "") != "":
		lines.append(str(d["note"]))
	if Uniques.is_unique(key):
		lines.append("Objet unique. " + Uniques.story(key))
	lines.append("Valeur de revente %s" % ("%d couronnes" % sell if sell >= 0 else "~%d couronnes (dans un lieu)" % Loot.sell_base(it)))
	return "\n".join(lines)
