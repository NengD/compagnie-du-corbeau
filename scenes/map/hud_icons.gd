class_name HudIcon
extends Control
## Pictogramme du HUD de la carte, dessiné par code dans un carré de 24 unités (mis à l'échelle de la taille du contrôle).
## kind : food, morale, threat, pause, play1, play2, play3, company, bag, details, legend, help, sun, moon, rain, fog, snow, close.

const OL := Color("17110c")
const CREAM := Color("ece1c9")

var kind: String = ""
var tint: Color = CREAM


func _init(k: String = "", px: float = 22.0, col: Color = CREAM) -> void:
	kind = k
	tint = col
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func set_kind(k: String, col: Color = CREAM) -> void:
	kind = k
	tint = col
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 24.0
	draw_set_transform(size * 0.5 - Vector2(12, 12) * s, 0.0, Vector2(s, s))
	paint(self, kind, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func paint(c: CanvasItem, kind: String, col: Color) -> void:
	var p := Vector2(12, 12)
	match kind:
		"food":  # miche de pain
			c.draw_colored_polygon(_ellipse(p + Vector2(0, 1), 10, 6.5), Color("c58a3a"))
			c.draw_polyline(_ellipse_closed(p + Vector2(0, 1), 10, 6.5), OL, 1.4)
			for i in 3:
				c.draw_line(p + Vector2(-4 + i * 4, -3), p + Vector2(-2 + i * 4, 2), Color("8a5a22"), 1.4)
		"morale":  # étendard
			c.draw_line(p + Vector2(-6, 10), p + Vector2(-6, -10), OL, 3.0)
			c.draw_line(p + Vector2(-6, 10), p + Vector2(-6, -10), Color("c9c2b2"), 1.4)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -9), p + Vector2(9, -6), p + Vector2(3, -2), p + Vector2(9, 2), p + Vector2(-5, 3)]), col)
			c.draw_polyline(PackedVector2Array([p + Vector2(-5, -9), p + Vector2(9, -6), p + Vector2(3, -2), p + Vector2(9, 2), p + Vector2(-5, 3), p + Vector2(-5, -9)]), OL, 1.2)
		"threat":  # crâne
			c.draw_circle(p + Vector2(0, -2), 8.0, col)
			c.draw_rect(Rect2(p + Vector2(-4, 4), Vector2(8, 6)), col)
			c.draw_circle(p + Vector2(-3, -2), 2.3, OL)
			c.draw_circle(p + Vector2(3, -2), 2.3, OL)
			c.draw_line(p + Vector2(-1.5, 6), p + Vector2(-1.5, 10), OL, 1.0)
			c.draw_line(p + Vector2(1.5, 6), p + Vector2(1.5, 10), OL, 1.0)
		"pause":
			c.draw_rect(Rect2(p + Vector2(-6, -7), Vector2(4.5, 14)), col)
			c.draw_rect(Rect2(p + Vector2(1.5, -7), Vector2(4.5, 14)), col)
		"play1", "play2", "play3":
			var n: int = int(kind.substr(4))
			for i in n:
				var x: float = -8.0 + float(i) * (16.0 / float(n)) if n > 1 else -4.0
				var w: float = 16.0 / float(n) if n > 1 else 9.0
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(x, -7), p + Vector2(x + w + (1.0 if n > 1 else 0.0), 0), p + Vector2(x, 7)]), col)
		"company":  # heaume
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 8), p + Vector2(-8, -1), p + Vector2(-5, -7), p + Vector2(0, -9), p + Vector2(5, -7), p + Vector2(8, -1), p + Vector2(8, 8), p + Vector2(4, 8), p + Vector2(4, 1), p + Vector2(-4, 1), p + Vector2(-4, 8)]), col)
			c.draw_line(p + Vector2(0, -9), p + Vector2(0, 1), OL, 1.4)
			c.draw_line(p + Vector2(-4, 1), p + Vector2(4, 1), OL, 1.4)
		"bag":  # besace
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 9), p + Vector2(-9, -1), p + Vector2(-4, -4), p + Vector2(4, -4), p + Vector2(9, -1), p + Vector2(8, 9)]), col)
			c.draw_arc(p + Vector2(0, -4), 4.0, PI, TAU, 10, col, 2.0, true)
			c.draw_rect(Rect2(p + Vector2(-2, 0), Vector2(4, 4)), OL)
		"details":  # parchemin à lignes
			c.draw_rect(Rect2(p + Vector2(-7, -9), Vector2(14, 18)), col)
			c.draw_rect(Rect2(p + Vector2(-7, -9), Vector2(14, 18)), OL, false, 1.2)
			for i in 4:
				c.draw_line(p + Vector2(-4, -5 + i * 4), p + Vector2(4, -5 + i * 4), OL, 1.3)
		"legend":  # épingle de carte
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, 10), p + Vector2(-6, 0), p + Vector2(-5, -5), p + Vector2(0, -9), p + Vector2(5, -5), p + Vector2(6, 0)]), col)
			c.draw_circle(p + Vector2(0, -3), 2.6, OL)
		"help":
			c.draw_arc(p + Vector2(0, -3), 5.0, deg_to_rad(180), deg_to_rad(400), 12, col, 2.6, true)
			c.draw_line(p + Vector2(4.2, -0.5), p + Vector2(0, 3.5), col, 2.6)
			c.draw_line(p + Vector2(0, 3.5), p + Vector2(0, 5.5), col, 2.6)
			c.draw_circle(p + Vector2(0, 9), 1.7, col)
		"sun":
			c.draw_circle(p, 5.0, Color("f0c050"))
			for i in 8:
				var a: float = TAU * float(i) / 8.0
				c.draw_line(p + Vector2(cos(a), sin(a)) * 7.5, p + Vector2(cos(a), sin(a)) * 10.5, Color("f0c050"), 1.8)
		"moon":
			BannerView.draw_emblem(c, 6, p, 20.0, Color("d9dce8"))
		"rain", "fog", "snow":
			var cloud := Color("aeb6c0") if kind != "fog" else Color("b9b8ae")
			c.draw_circle(p + Vector2(-4, -2), 4.5, cloud)
			c.draw_circle(p + Vector2(2, -4), 5.5, cloud)
			c.draw_circle(p + Vector2(6, -1), 3.8, cloud)
			c.draw_rect(Rect2(p + Vector2(-8.5, -2), Vector2(16.5, 4.5)), cloud)
			if kind == "rain":
				for i in 3:
					c.draw_line(p + Vector2(-5 + i * 5, 5), p + Vector2(-6.5 + i * 5, 10), Color("7ea6d0"), 1.6)
			elif kind == "snow":
				for i in 3:
					c.draw_circle(p + Vector2(-5 + i * 5, 7.5 + float(i % 2) * 2.0), 1.4, Color.WHITE)
			else:
				c.draw_line(p + Vector2(-8, 7), p + Vector2(8, 7), cloud, 1.6)
				c.draw_line(p + Vector2(-5, 10), p + Vector2(10, 10), cloud, 1.6)
		"close":
			c.draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), col, 2.4)
			c.draw_line(p + Vector2(6, -6), p + Vector2(-6, 6), col, 2.4)


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func _ellipse_closed(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out: PackedVector2Array = _ellipse(c, rx, ry)
	out.append(out[0])
	return out
