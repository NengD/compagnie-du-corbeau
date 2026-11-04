class_name BannerView
extends Control
## Bannière de la compagnie dessinée par code : fanion à queue d'aronde, couleur principale, motif du champ
## (uni, divisé, bandé, chevronné, écartelé) et emblème en couleur secondaire.
## `paint_cloth` est partagé avec le marqueur de la carte (scenes/map/company_marker.gd) : l'étoffe peut onduler et pencher.

const OUTLINE := Color("17110c")
const CLOTH: PackedVector2Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0.5, 0.82), Vector2(0, 1)]  ## forme de l'étoffe (repère unitaire)

var banner: Dictionary = Data.BANNER_DEFAULT.duplicate()
var wave: float = 0.0  ## > 0 : l'étoffe flotte (étendard animé, comme sur la carte)
var _t: float = 0.0


func _init(b: Dictionary = {}, px: Vector2 = Vector2(30, 40), p_wave: float = 0.0) -> void:
	custom_minimum_size = px
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wave = p_wave
	set_banner(b if not b.is_empty() else Data.BANNER_DEFAULT)
	set_process(wave > 0.0)


func set_banner(b: Dictionary) -> void:
	banner = Banner.clean(b)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var top: float = maxf(2.0, h * 0.07)
	draw_rect(Rect2(0, 0, w, top), Color("3a2818"))
	paint_cloth(self, Rect2(w * 0.05, top, w * (0.9 - 0.2 * wave), h * 0.97 - top), banner, _t, wave * 0.6, wave * 0.05, maxf(1.0, w * 0.04))


# --- Étoffe ---

## Subdivise les côtés d'un polygone (repère unitaire) pour qu'ils suivent l'ondulation une fois déformés.
static func _subdiv(poly: PackedVector2Array, step: float = 0.1) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var n: int = maxi(1, int(ceil(a.distance_to(b) / step)))
		for k in n:
			out.append(a.lerp(b, float(k) / float(n)))
	return out


## Zones du motif (repère unitaire) à teinter ; chacune sera découpée par la forme de l'étoffe.
static func pattern_polys(pattern: int) -> Array:
	match pattern:
		1:
			return [PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0.5, 1)])]
		2:
			return [PackedVector2Array([Vector2(0, 0.06), Vector2(1, 0.06), Vector2(1, 0.18), Vector2(0, 0.18)]),
				PackedVector2Array([Vector2(0, 0.66), Vector2(1, 0.66), Vector2(1, 0.78), Vector2(0, 0.78)])]
		3:
			return [PackedVector2Array([Vector2(0, 0.48), Vector2(0.5, 0.66), Vector2(1, 0.48), Vector2(1, 0.6), Vector2(0.5, 0.78), Vector2(0, 0.6)]),
				PackedVector2Array([Vector2(0, 0.0), Vector2(1, 0.0), Vector2(1, 0.07), Vector2(0, 0.07)])]
		4:
			return [PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0), Vector2(0.5, 0.5), Vector2(0, 0.5)]),
				PackedVector2Array([Vector2(0.5, 0.5), Vector2(1, 0.5), Vector2(1, 1), Vector2(0.5, 1)])]
	return []


## Dessine l'étoffe d'une bannière dans `rect` (accrochée par le haut). `wave` : amplitude de l'ondulation, `lean` : inclinaison
## (en largeurs d'étoffe, vers la droite) ; les deux sont proportionnelles à la distance au mât, donc le haut reste fixe.
static func paint_cloth(ci: CanvasItem, rect: Rect2, banner: Dictionary, t: float, wave: float, lean: float, outline_w: float) -> void:
	var b: Dictionary = Banner.clean(banner)
	var deform := func(u: Vector2) -> Vector2:
		var sway: float = rect.size.x * u.y * (lean + wave * sin(t * 3.6 - u.y * 3.5 - u.x * 1.4))
		return rect.position + Vector2(u.x * rect.size.x + sway, u.y * rect.size.y + wave * 0.15 * rect.size.x * sin(t * 4.2 + u.x * 3.0) * u.y)
	var shape: PackedVector2Array = _subdiv(CLOTH)
	var pts := PackedVector2Array()
	for u in shape:
		pts.append(deform.call(u))
	ci.draw_colored_polygon(pts, Banner.primary(b))
	var tint: Color = Banner.pattern_color(b)
	for ov in pattern_polys(Banner.pattern(b)):
		for piece in Geometry2D.intersect_polygons(CLOTH, ov):
			var q := PackedVector2Array()
			for u in _subdiv(piece as PackedVector2Array):
				q.append(deform.call(u))
			if q.size() >= 3:
				ci.draw_colored_polygon(q, tint)
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	ci.draw_polyline(outline, OUTLINE, outline_w, true)
	var cu := Vector2(0.5, 0.4)
	var c: Vector2 = deform.call(cu)
	var slope: float = (deform.call(Vector2(0.5, 0.5)) as Vector2).x - (deform.call(Vector2(0.5, 0.3)) as Vector2).x
	var ang: float = -atan2(slope, rect.size.y * 0.2) * 0.8
	var es: float = minf(rect.size.x * 0.6, rect.size.y * 0.42)
	ci.draw_set_transform(c, ang, Vector2.ONE)
	draw_emblem(ci, int(b["emblem"]), Vector2.ZERO, es, Banner.secondary(b))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Dessine l'emblème n° `idx` (voir Data.BANNER_EMBLEMS), centré en `c`, dans un carré de côté `s`.
static func draw_emblem(ci: CanvasItem, idx: int, c: Vector2, s: float, col: Color) -> void:
	var r: float = s * 0.5
	var lw: float = maxf(1.5, s * 0.12)
	match idx:
		0:  # corbeau : silhouette en vol
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.2), c + Vector2(-r * 0.35, -r * 0.75), c + Vector2(0, -r * 0.2), c + Vector2(r * 0.35, -r * 0.75), c + Vector2(r, -r * 0.2), c + Vector2(r * 0.25, r * 0.15), c + Vector2(r * 0.15, r * 0.8), c + Vector2(-r * 0.15, r * 0.8), c + Vector2(-r * 0.25, r * 0.15)]), col)
		1:  # épées croisées
			ci.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, lw)
			ci.draw_line(c + Vector2(r, -r), c + Vector2(-r, r), col, lw)
			ci.draw_line(c + Vector2(-r * 0.7, -r * 0.2), c + Vector2(-r * 0.2, -r * 0.7), col, lw * 1.2)
			ci.draw_line(c + Vector2(r * 0.7, -r * 0.2), c + Vector2(r * 0.2, -r * 0.7), col, lw * 1.2)
		2:  # étoile
			var pts := PackedVector2Array()
			for i in 10:
				var a: float = -PI / 2.0 + TAU * float(i) / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.42))
			ci.draw_colored_polygon(pts, col)
		3:  # croix
			ci.draw_rect(Rect2(c.x - lw * 0.7, c.y - r, lw * 1.4, r * 2.0), col)
			ci.draw_rect(Rect2(c.x - r, c.y - lw * 0.7 - r * 0.15, r * 2.0, lw * 1.4), col)
		4:  # tour crénelée
			ci.draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.5, r * 1.1, r * 1.5), col)
			for k in 3:
				ci.draw_rect(Rect2(c.x - r * 0.7 + k * r * 0.5, c.y - r, r * 0.3, r * 0.55), col)
		5:  # couronne
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.6), c + Vector2(-r, -r * 0.6), c + Vector2(-r * 0.5, -r * 0.1), c + Vector2(0, -r * 0.8), c + Vector2(r * 0.5, -r * 0.1), c + Vector2(r, -r * 0.6), c + Vector2(r, r * 0.6)]), col)
		6:  # lune : arc extérieur (r) moins un disque décalé (0,8 r), points calculés pour un croissant sans croisement
			var arc := PackedVector2Array()
			for i in 25:
				var a: float = deg_to_rad(51.3 + (308.7 - 51.3) * float(i) / 24.0)
				arc.append(c + Vector2(cos(a), sin(a)) * r)
			for i in 25:
				var a: float = deg_to_rad(282.6 - (282.6 - 77.4) * float(i) / 24.0)
				arc.append(c + Vector2(r * 0.45, 0) + Vector2(cos(a), sin(a)) * r * 0.8)
			ci.draw_colored_polygon(arc, col)
		7:  # chevron
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r, -r * 0.35), c + Vector2(0, r * 0.55), c + Vector2(r, -r * 0.35)]), col, lw * 1.6)
		8:  # loup : tête de face, oreilles dressées
			var f := PackedVector2Array()
			for v in [Vector2(-0.85, -1.0), Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(0.85, -1.0), Vector2(0.8, 0.1), Vector2(0.25, 0.55), Vector2(0.0, 1.0), Vector2(-0.25, 0.55), Vector2(-0.8, 0.1)]:
				f.append(c + (v as Vector2) * r)
			ci.draw_colored_polygon(f, col)
		9:  # cerf : ramure et museau
			ci.draw_line(c + Vector2(0, r * 0.2), c + Vector2(0, -r * 0.2), col, lw)
			for sd in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(0, -r * 0.1), c + Vector2(sd * r * 0.45, -r * 0.5), c + Vector2(sd * r * 0.8, -r)]), col, lw * 0.8)
				ci.draw_line(c + Vector2(sd * r * 0.45, -r * 0.5), c + Vector2(sd * r * 0.95, -r * 0.4), col, lw * 0.6)
				ci.draw_line(c + Vector2(sd * r * 0.62, -r * 0.75), c + Vector2(sd * r * 0.3, -r * 0.95), col, lw * 0.6)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, r * 0.15), c + Vector2(r * 0.4, r * 0.15), c + Vector2(0, r)]), col)
		10:  # hache : manche en diagonale, fer en croissant
			ci.draw_line(c + Vector2(-r * 0.7, r), c + Vector2(r * 0.4, -r * 0.85), col, lw * 0.9)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.1 * r, -r), c + Vector2(r, -r * 0.6), c + Vector2(r * 0.85, r * 0.2), c + Vector2(r * 0.2, -r * 0.1)]), col)
		11:  # crâne
			ci.draw_circle(c + Vector2(0, -r * 0.2), r * 0.72, col)
			ci.draw_rect(Rect2(c.x - r * 0.38, c.y + r * 0.3, r * 0.76, r * 0.65), col)
			var hole := Color("17110c")
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.2, hole)
			ci.draw_circle(c + Vector2(r * 0.3, -r * 0.2), r * 0.2, hole)
			ci.draw_line(c + Vector2(-r * 0.15, r * 0.5), c + Vector2(-r * 0.15, r * 0.9), hole, maxf(1.0, lw * 0.3))
			ci.draw_line(c + Vector2(r * 0.15, r * 0.5), c + Vector2(r * 0.15, r * 0.9), hole, maxf(1.0, lw * 0.3))
		12:  # soleil : disque et huit rayons
			ci.draw_circle(c, r * 0.46, col)
			for i in 8:
				var a2: float = TAU * float(i) / 8.0
				ci.draw_line(c + Vector2(cos(a2), sin(a2)) * r * 0.66, c + Vector2(cos(a2), sin(a2)) * r, col, lw * 0.7)
		_:  # repli : chevron
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r, -r * 0.35), c + Vector2(0, r * 0.55), c + Vector2(r, -r * 0.35)]), col, lw * 1.6)
