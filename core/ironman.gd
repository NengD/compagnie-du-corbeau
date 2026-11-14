class_name Ironman
extends RefCounted
## Mode fer : mort définitive stricte. État : Game.extras["ironman"] = {"on": true} (absent = partie ordinaire).
## Une seule sauvegarde automatique : pas d'emplacements manuels, pas de chargement d'une copie plus ancienne.
## La sauvegarde est supprimée quand la compagnie est anéantie, une fois l'écran de fin passé (voir Main).

const LABEL := "Mode fer"
const HINT := "Mode fer : une seule sauvegarde automatique, aucun retour en arrière. La compagnie anéantie, la partie est effacée."


static func init_extras(extras: Dictionary) -> void:
	extras["ironman"] = {"on": true}


static func is_on(extras: Dictionary) -> bool:
	var s: Variant = extras.get("ironman", null)
	return typeof(s) == TYPE_DICTIONARY and bool((s as Dictionary).get("on", false))


## Les emplacements manuels (sauvegarde ou chargement) sont interdits dans cette partie.
static func blocks_slots(extras: Dictionary) -> bool:
	return is_on(extras)


## La partie en cours est finie (compagnie anéantie) : la sauvegarde doit disparaître.
static func should_wipe(extras: Dictionary, game_over: bool) -> bool:
	return game_over and is_on(extras)
