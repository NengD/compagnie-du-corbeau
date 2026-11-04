class_name CompanyMarker
extends RefCounted
## Marqueur de la compagnie sur la carte : sa bannière plantée au sol (mât, étendard, ombre, nom), comme dans Battle Brothers.
## Dessiné en tailles d'écran (pixels) : `scr` = pixels d'écran par unité du monde, donc le marqueur reste lisible à tout zoom.

const OL := Color("17110c")
const WOOD := Color("8a6a40")
const POLE_H := 62.0  ## hauteur du mât (px)
const CLOTH_W := 30.0
const CLOTH_H := 40.0


## `me` : pied du mât (monde). `heading` : sens du déplacement (−1 gauche, 0 arrêt, +1 droite) ; `size_k` : agrandissement léger avec le zoom.
static func paint(l: CanvasItem, me: Vector2, banner: Dictionary, company: String, font: Font, t: float, animate: bool, heading: float, vision: float, scr: float, size_k: float = 1.0, crowded: bool = false) -> void:
	var moving: bool = absf(heading) > 0.0
	var u: float = size_k / maxf(scr, 0.05)  # unités du monde par « pixel » du marqueur
	if vision > 0.0:
		l.draw_arc(me, vision, 0.0, TAU, 72, Color(1, 1, 1, 0.07), 1.5, true)
	var pulse: float = 0.5 + 0.5 * sin(t * 2.5) if animate else 0.5
	# anneau doré au sol (discret) et ombre portée
	l.draw_set_transform(me, 0.0, Vector2(1.0, 0.42))
	l.draw_arc(Vector2.ZERO, (17.0 + pulse * 2.0) * u, 0.0, TAU, 32, Color(GameTheme.GOLD, 0.5 - pulse * 0.15), 1.8 * u, true)
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_shadow(l, me, u, heading)
	var bob: float = absf(sin(t * 7.0)) * 1.6 * u if animate and moving else 0.0
	var foot: Vector2 = me - Vector2(0, bob) + (Vector2(16.0 * u, 0) if crowded else Vector2.ZERO)  # décalé pour ne pas cacher le lieu
	var top: Vector2 = foot + Vector2(0, -POLE_H * u)
	# mât, traverse et pommeau
	l.draw_line(foot, top, OL, 5.0 * u)
	l.draw_line(foot, top, WOOD, 2.6 * u)
	l.draw_line(top + Vector2(-CLOTH_W * 0.58 * u, 2.0 * u), top + Vector2(CLOTH_W * 0.58 * u, 2.0 * u), OL, 4.4 * u)
	l.draw_line(top + Vector2(-CLOTH_W * 0.58 * u, 2.0 * u), top + Vector2(CLOTH_W * 0.58 * u, 2.0 * u), WOOD, 2.2 * u)
	l.draw_circle(top + Vector2(0, -1.5 * u), 3.6 * u, OL)
	l.draw_circle(top + Vector2(0, -1.5 * u), 2.4 * u, Color("d9b84a"))
	# étendard : flotte plus fort et s'incline à l'opposé de la marche quand la compagnie se déplace
	var wave: float = 0.0
	var lean: float = 0.03
	if animate:
		wave = 0.34 if moving else 0.14
	if moving:
		lean = -heading * 0.22
	var rect := Rect2(top + Vector2(-CLOTH_W * 0.5 * u, 4.5 * u), Vector2(CLOTH_W * u, CLOTH_H * u))
	BannerView.paint_cloth(l, rect, banner, t, wave, lean, 1.7 * u)
	# nom sous le mât
	if company != "":
		var fs: int = maxi(8, int(round(14.0 * u)))
		var pos: Vector2 = (foot + Vector2(-130.0 * u, -(POLE_H + 14.0) * u)) if crowded else (me + Vector2(-130.0 * u, 20.0 * u))  # au-dessus de l'étendard près d'un lieu
		l.draw_string_outline(font, pos, company, HORIZONTAL_ALIGNMENT_CENTER, 260.0 * u, fs, maxi(2, int(round(5.0 * u))), Color(0.07, 0.06, 0.05, 0.92))
		l.draw_string(font, pos, company, HORIZONTAL_ALIGNMENT_CENTER, 260.0 * u, fs, Color("f0e6c8"))


static func _shadow(l: CanvasItem, me: Vector2, u: float, heading: float) -> void:
	var lean: float = 1.0 if heading <= 0.0 else -1.0
	var pts := PackedVector2Array([me + Vector2(-2.5 * u, 0), me + Vector2(2.5 * u, 0), me + Vector2(lean * 30.0 * u + 3.0 * u, 7.0 * u), me + Vector2(lean * 30.0 * u - 3.0 * u, 8.0 * u)])
	l.draw_colored_polygon(pts, Color(0, 0, 0, 0.26))
	var e := PackedVector2Array()
	for i in 18:
		var a: float = TAU * float(i) / 18.0
		e.append(me + Vector2(cos(a) * 9.0 * u, sin(a) * 3.2 * u + 1.0 * u))
	l.draw_colored_polygon(e, Color(0, 0, 0, 0.34))


## Aperçu du marqueur tel qu'il apparaîtra sur la carte (étape « Votre compagnie »).
class Preview extends Control:
	var banner: Dictionary = Data.BANNER_DEFAULT.duplicate()
	var company: String = ""
	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(190, 150)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_look(b: Dictionary, n: String) -> void:
		banner = Banner.clean(b)
		company = n
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("7d8a55"))
		for i in 14:  # herbe et cailloux déterministes
			var p := Vector2(fposmod(float(i) * 61.7, size.x), fposmod(float(i) * 37.3 + 11.0, size.y))
			draw_circle(p, 2.0 + float(i % 3), Color(0.35, 0.45, 0.25, 0.5))
		draw_rect(r, Color("2a1d12"), false, 4.0)
		CompanyMarker.paint(self, Vector2(size.x * 0.5, size.y - 40.0), banner, company, GameTheme.title_font(), _t, Settings.map_anim, 0.0, 0.0, 1.0)
