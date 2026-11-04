class_name Visits
extends RefCounted
## Lieux déjà visités : `settlement["visited_day"]` (rempli par `Game.enter_settlement`, 0 = jamais).


## Jour de la dernière visite d'un village ou d'une ville (0 = jamais visité).
static func day_of(s: Dictionary) -> int:
	return int(s.get("visited_day", 0))


## Texte d'info-bulle d'un lieu habité : nom, réputation, visite.
static func tooltip(s: Dictionary, standing: int) -> String:
	var t: String = "%s\nRéputation : %s (%+d)" % [s["name"], World.standing_label(standing), standing]
	var d: int = day_of(s)
	t += "\nVisité le jour %d" % d if d > 0 else "\nJamais visité"
	return t
