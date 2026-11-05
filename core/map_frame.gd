class_name MapFrame
extends RefCounted
## Cadrage de la carte du monde dans sa vue et mouvements de la caméra (logique pure, testable sans fenêtre).
## Vocabulaire : « échelle » = pixels d'écran par unité du monde ; « position » = coin haut-gauche du monde dans la vue.

const COVER_MAX_RATIO := 1.35  ## rapport remplir/ajuster au-delà duquel on préfère montrer toute la carte
const EDGE_PX := 14.0  ## épaisseur de la bande de défilement au bord de la vue
const PAN_SCREENS_PER_SEC := 0.75  ## déplacement de la caméra : fraction de la taille d'écran parcourue par seconde
const SHIFT_MULT := 2.2  ## Maj : caméra plus rapide
const START_SPAN := 0.30  ## part de la largeur du grand monde visible au départ (≈ un tiers)
const SCALE_MAX_GRAND := 1.7  ## échelle maximale dans le grand monde : les noms restent lisibles de près


## Échelle de base (pixels par unité du monde) pour une vue de taille `vs` : cadrage « remplir » (la carte couvre toute la vue,
## on la fait glisser) tant que le monde déborde de moins de COVER_MAX_RATIO, sinon « ajuster » (toute la carte visible).
## `allow_cover` faux (grand monde) : toujours « ajuster », le zoom minimal montre tout le monde.
static func base_scale(vs: Vector2, ws: Vector2 = World.SIZE, allow_cover: bool = true) -> float:
	var fit: float = minf(vs.x / ws.x, vs.y / ws.y)
	var cover: float = maxf(vs.x / ws.x, vs.y / ws.y)
	if not allow_cover:
		return maxf(fit, 0.0)
	return cover if fit > 0.0 and cover / fit <= COVER_MAX_RATIO else maxf(fit, 0.0)


## Zoom (rapport à l'échelle de base) du plan de départ du grand monde : environ START_SPAN de la largeur du monde visible.
static func start_zoom(vs: Vector2, ws: Vector2, base_k: float, zoom_max: float) -> float:
	if base_k <= 0.0:
		return 1.0
	var k: float = vs.x / (ws.x * START_SPAN)
	return clampf(k / base_k, 1.0, zoom_max)


## Zoom maximal : `SCALE_MAX_GRAND` (en échelle réelle) dans le grand monde, `classic_max` sinon.
static func zoom_max(base_k: float, grand: bool, classic_max: float) -> float:
	if not grand:
		return classic_max
	return maxf(1.0, SCALE_MAX_GRAND / maxf(base_k, 0.001))


## Position du monde dans la vue, bornée : centrée si le monde est plus petit que la vue, sans bord vide sinon.
static func clamp_stage(pos: Vector2, vs: Vector2, ws: Vector2, k: float) -> Vector2:
	var sz: Vector2 = ws * k
	var p: Vector2 = pos
	p.x = (vs.x - sz.x) * 0.5 if sz.x <= vs.x else clampf(p.x, vs.x - sz.x, 0.0)
	p.y = (vs.y - sz.y) * 0.5 if sz.y <= vs.y else clampf(p.y, vs.y - sz.y, 0.0)
	return p


## Position qui centre la vue sur le point `world_p` du monde.
static func stage_for_center(world_p: Vector2, vs: Vector2, k: float) -> Vector2:
	return vs * 0.5 - world_p * k


## Point du monde au centre de la vue.
static func center_of(pos: Vector2, vs: Vector2, k: float) -> Vector2:
	return (vs * 0.5 - pos) / maxf(k, 0.0001)


## Vitesse de la caméra en pixels d'écran par seconde : proportionnelle à la taille de l'écran.
## (En unités du monde par seconde, elle varie en sens inverse de l'échelle : diviser par `k`.)
static func pan_speed_px(vs: Vector2, fast: bool) -> float:
	return maxf(vs.x, vs.y) * PAN_SCREENS_PER_SEC * (SHIFT_MULT if fast else 1.0)


## Direction de défilement imposée par la position de la souris dans la vue (vecteur nul hors des bords ou hors de la vue).
static func edge_dir(m: Vector2, vs: Vector2, edge: float = EDGE_PX) -> Vector2:
	if m.x < 0.0 or m.y < 0.0 or m.x > vs.x or m.y > vs.y:
		return Vector2.ZERO
	var d := Vector2.ZERO
	if m.x < edge:
		d.x = -1.0
	elif m.x > vs.x - edge:
		d.x = 1.0
	if m.y < edge:
		d.y = -1.0
	elif m.y > vs.y - edge:
		d.y = 1.0
	return d


## Agrandissement des pictogrammes (lieux, bandes…) quand on dézoome : ils gardent une taille lisible à l'écran.
static func icon_scale(k: float, screen_min: float = 0.62, cap: float = 2.4) -> float:
	return clampf(screen_min / maxf(k, 0.01), 1.0, cap)
