class_name MapFrame
extends RefCounted
## Cadrage de la carte du monde dans sa vue (logique pure, testable sans fenêtre).

const COVER_MAX_RATIO := 1.35  ## rapport remplir/ajuster au-delà duquel on préfère montrer toute la carte


## Échelle de base (pixels par unité du monde) pour une vue de taille `vs` : cadrage « remplir » (la carte couvre toute la vue,
## on la fait glisser) tant que le monde déborde de moins de COVER_MAX_RATIO, sinon « ajuster » (toute la carte visible).
static func base_scale(vs: Vector2) -> float:
	var fit: float = minf(vs.x / World.SIZE.x, vs.y / World.SIZE.y)
	var cover: float = maxf(vs.x / World.SIZE.x, vs.y / World.SIZE.y)
	return cover if fit > 0.0 and cover / fit <= COVER_MAX_RATIO else maxf(fit, 0.0)
