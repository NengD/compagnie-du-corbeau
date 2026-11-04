class_name BannerView
extends Control
## Bannière de la compagnie dessinée par code : fanion à queue d'aronde, couleur principale, emblème en couleur secondaire.

var banner: Dictionary = Data.BANNER_DEFAULT.duplicate()


func _init(b: Dictionary = {}, px: Vector2 = Vector2(30, 40)) -> void:
	custom_minimum_size = px
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	set_banner(b if not b.is_empty() else Data.BANNER_DEFAULT)


func set_banner(b: Dictionary) -> void:
	banner = Banner.clean(b)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var pole := Color("3a2818")
	draw_rect(Rect2(0, 0, w, maxf(2.0, h * 0.07)), pole)
	var top: float = maxf(2.0, h * 0.07)
	var pts := PackedVector2Array([Vector2(w * 0.05, top), Vector2(w * 0.95, top), Vector2(w * 0.95, h * 0.97), Vector2(w * 0.5, h * 0.8), Vector2(w * 0.05, h * 0.97)])
	draw_colored_polygon(pts, Banner.primary(banner))
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, Color("17110c"), maxf(1.0, w * 0.04))
	var c := Vector2(w * 0.5, top + (h * 0.78 - top) * 0.5)
	draw_emblem(self, int(banner["emblem"]), c, minf(w * 0.62, h * 0.5), Banner.secondary(banner))


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
		_:  # chevron
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r, -r * 0.35), c + Vector2(0, r * 0.55), c + Vector2(r, -r * 0.35)]), col, lw * 1.6)
