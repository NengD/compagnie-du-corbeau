class_name Cover
extends RefCounted
## Hauteur et couvert pour les tirs à distance (jamais pour la mêlée : elle a son propre bonus de colline).
## Pur : lit seulement `cells`. Constantes nommées ci-dessous.

const HEIGHT_RANGED_BONUS: int = 10  ## tireur plus haut que la cible (colline, chemin de ronde)
const HEIGHT_RANGED_MALUS: int = 10  ## cible plus haute que le tireur
const COVER_MALUS: int = 15  ## cible collée à un obstacle tourné vers le tireur (non cumulatif)
const COVER_MIN_DIST: int = 2  ## pas de couvert à bout portant
const COVER_TERRAIN: Array = ["tree", "rock", "forest"]
const COVER_SCENERY: Array = ["barricade", "wall", "door", "gate"]


static func height_of(cells: Dictionary, h: Vector2i) -> int:
	return int(CombatRules.terrain_at(cells, h)["h"]) + Scenery.height_bonus(cells, h)


## > 0 : le tireur domine ; < 0 : il tire d'en bas ; 0 : même niveau.
static func height_diff(cells: Dictionary, a: Vector2i, d: Vector2i) -> int:
	return signi(height_of(cells, a) - height_of(cells, d))


## Cette case offre-t-elle un abri (obstacle du terrain ou décor intact) ?
static func is_cover_cell(cells: Dictionary, h: Vector2i) -> bool:
	if not cells.has(h):
		return false
	if COVER_TERRAIN.has(str(cells[h]["t"])):
		return true
	var o: Dictionary = Scenery.obj_at(cells, h)
	if o.is_empty() or bool(o.get("open", false)):
		return false
	return COVER_SCENERY.has(str(o.get("kind", "")))


## La cible est-elle abritée contre un tir venant de `from` ? Un obstacle voisin de la cible,
## au moins aussi proche du tireur qu'elle (devant ou sur le flanc), la protège.
static func has_cover(cells: Dictionary, from: Vector2i, target: Vector2i) -> bool:
	var dist: int = Hex.distance(from, target)
	if dist < COVER_MIN_DIST:
		return false
	for n in Hex.neighbors(target):
		if Hex.distance(from, n) <= dist and is_cover_cell(cells, n):
			return true
	return false


## Modificateur total de toucher à distance (négatif = plus dur).
static func ranged_modifier(cells: Dictionary, from: Vector2i, target: Vector2i) -> int:
	var m: int = 0
	var hd: int = height_diff(cells, from, target)
	if hd > 0:
		m += HEIGHT_RANGED_BONUS
	elif hd < 0:
		m -= HEIGHT_RANGED_MALUS
	if has_cover(cells, from, target):
		m -= COVER_MALUS
	return m


## Étiquettes pour l'interface : ["Hauteur +10", "Couvert −15"].
static func tags(cells: Dictionary, from: Vector2i, target: Vector2i) -> Array[String]:
	var out: Array[String] = []
	var hd: int = height_diff(cells, from, target)
	if hd > 0:
		out.append("Hauteur +%d" % HEIGHT_RANGED_BONUS)
	elif hd < 0:
		out.append("Hauteur −%d" % HEIGHT_RANGED_MALUS)
	if has_cover(cells, from, target):
		out.append("Couvert −%d" % COVER_MALUS)
	return out


## Version courte pour l'étiquette du plateau : "Hauteur · Couvert".
static func short_tag(cells: Dictionary, from: Vector2i, target: Vector2i) -> String:
	var parts: Array[String] = []
	var hd: int = height_diff(cells, from, target)
	if hd > 0:
		parts.append("Hauteur")
	elif hd < 0:
		parts.append("Surplomb")
	if has_cover(cells, from, target):
		parts.append("Couvert")
	return " · ".join(parts)


## Pour l'IA : valeur d'une case pour un tireur (cases abritées de la plupart des ennemis préférées).
static func position_score(cells: Dictionary, h: Vector2i, foes: Array) -> float:
	var covered: int = 0
	var n: int = 0
	for f in foes:
		var fu: Unit = f
		n += 1
		if has_cover(cells, fu.hex, h):
			covered += 1
	if n == 0:
		return 0.0
	return 8.0 * float(covered) / float(n)
