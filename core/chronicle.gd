class_name Chronicle
extends RefCounted
## Journal de campagne : chronologie bornée des faits marquants, conservée dans `Game.extras["chronicle"]`
## (liste de {"d": jour, "k": genre, "x": texte}, la plus ancienne en premier). Logique pure : `extras` est passé en paramètre.

const KEY: String = "chronicle"
const MAX_ENTRIES: int = 300

## Genres d'entrées : clé -> libellé (l'ordre est celui des filtres de l'écran).
const KINDS: Dictionary = {
	"battle": "Batailles", "death": "Morts", "contract": "Contrats", "level": "Niveaux",
	"hire": "Embauches", "goal": "Objectifs", "event": "Événements",
}

const EPITAPHS: Array[String] = [
	"Il est tombé en tenant sa place.",
	"On ne l'a pas oublié autour du feu.",
	"Sa solde est restée impayée ; sa dette, elle, est éteinte.",
	"Une croix de bois au bord de la route, et c'est tout.",
	"Il savait ce que le métier coûtait.",
	"Qu'il repose là où la terre est douce.",
]


## Ajoute une entrée (jour `day`, genre `kind`, texte `text`). Les plus anciennes sont écartées au-delà de MAX_ENTRIES.
static func record(extras: Dictionary, day: int, kind: String, text: String) -> void:
	if text == "":
		return
	var list: Array = _list(extras)
	list.append({"d": day, "k": kind if KINDS.has(kind) else "event", "x": text})
	while list.size() > MAX_ENTRIES:
		list.pop_front()
	extras[KEY] = list


## Liste brute lue dans `extras` (tolérante : clé absente ou abîmée -> liste vide, entrées incomplètes réparées ou écartées).
static func _list(extras: Dictionary) -> Array:
	var raw: Variant = extras.get(KEY, [])
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in raw:
		if typeof(e) == TYPE_DICTIONARY and (e as Dictionary).has("x"):
			var k: String = str(e.get("k", "event"))
			out.append({"d": int(e.get("d", 1)), "k": k if KINDS.has(k) else "event", "x": str(e["x"])})
	return out


## Entrées de genre `kind` ("" = toutes), la plus récente en premier.
static func entries(extras: Dictionary, kind: String = "") -> Array:
	var out: Array = []
	var list: Array = _list(extras)
	for i in range(list.size() - 1, -1, -1):
		if kind == "" or str(list[i]["k"]) == kind:
			out.append(list[i])
	return out


## Nombre d'entrées de chaque genre : {genre: n}.
static func counts(extras: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for e in _list(extras):
		out[e["k"]] = int(out.get(e["k"], 0)) + 1
	return out


## Épitaphe stable pour un tombé (même nom -> même phrase).
static func epitaph(name_: String) -> String:
	return EPITAPHS[absi(name_.hash()) % EPITAPHS.size()]
