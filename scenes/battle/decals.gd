class_name BattleDecals
extends RefCounted
## Décalcomanies au sol du plateau (sang, flèches, cendres, éclats) : logique pure, sans dessin.
## Une décalcomanie : {"hex": Vector2i, "kind": String, "ox": float, "oy": float, "rot": float, "size": float, "alpha": float, "col": Color}.
## Le nombre est limité ; d'une bataille à l'autre on garde les plus récentes, estompées (`carry`).

const MAX_DECALS := 70
const MAX_CARRY := 14
const CARRY_FADE := 0.4

## Reste d'une bataille à l'autre (estompé) : alimente le sol de la bataille suivante.
static var carried: Array = []

var items: Array = []


func add(kind: String, hex: Vector2i, rng: RandomNumberGenerator, col: Color = Color(0.45, 0.07, 0.06), size: float = 1.0, alpha: float = 0.8) -> Dictionary:
	var d := {
		"hex": hex, "kind": kind,
		"ox": rng.randf_range(-12.0, 12.0), "oy": rng.randf_range(-6.0, 12.0),
		"rot": rng.randf_range(0.0, TAU), "size": size * rng.randf_range(0.7, 1.25),
		"alpha": alpha, "col": col,
	}
	items.append(d)
	while items.size() > MAX_DECALS:
		items.remove_at(0)
	return d


## Les plus anciennes sont retirées d'abord ; retourne le nombre final.
func count() -> int:
	return items.size()


## Place dans le reste statique les décalcomanies à emporter vers la bataille suivante.
func save_carry() -> void:
	var keep: Array = []
	for d in items:
		if str(d["kind"]) == "blood" or str(d["kind"]) == "ash":
			var c: Dictionary = (d as Dictionary).duplicate()
			c["alpha"] = float(c["alpha"]) * CARRY_FADE
			keep.append(c)
	carried = keep.slice(maxi(0, keep.size() - MAX_CARRY))


## Reprend les restes de la bataille précédente, sur des cases de la nouvelle carte.
func load_carry(cells: Dictionary, rng: RandomNumberGenerator) -> void:
	var keys: Array = cells.keys()
	if keys.is_empty():
		return
	for d in carried:
		var c: Dictionary = (d as Dictionary).duplicate()
		c["hex"] = keys[rng.randi() % keys.size()]
		items.append(c)
	carried = []
