class_name MapFx
extends RefCounted
## Effets de la carte du monde : lumière du jour et de la nuit, étoiles, météo (pluie, brouillard, neige), cadre de parchemin,
## rose des vents et échelle. Purement visuel. L'heure vient de `Game.day_fraction` (0 = aube).

const OL := Color("17110c")
## Lumière : [heure, multiplicateur de couleur, niveau de nuit 0..1]
const KEYS: Array = [
	[0.00, Color(1.0, 0.86, 0.68), 0.25],
	[0.10, Color(1.0, 0.97, 0.90), 0.0],
	[0.16, Color(1.0, 1.0, 1.0), 0.0],
	[0.58, Color(1.0, 1.0, 1.0), 0.0],
	[0.70, Color(1.0, 0.72, 0.52), 0.2],
	[0.80, Color(0.46, 0.46, 0.72), 0.75],
	[0.88, Color(0.36, 0.42, 0.70), 1.0],
	[0.94, Color(0.38, 0.43, 0.70), 0.95],
	[0.98, Color(0.62, 0.55, 0.68), 0.5],
	[1.00, Color(1.0, 0.86, 0.68), 0.25],
]
const NIGHT_VISION_LOSS := 0.25

var t: float = 0.0
var anim: bool = true
var light: Color = Color.WHITE  ## lumière affichée (lissée)
var night: float = 0.0
var wx_kind: String = "clear"
var wx_k: float = 0.0  ## intensité affichée de la météo
var _wx_target: float = 0.0
var _last_day: int = -1
var _glow: GradientTexture2D


func _init() -> void:
	_glow = GradientTexture2D.new()
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 64
	_glow.height = 64
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_glow.gradient = g


## Lumière cible pour une heure donnée : {"mul": Color, "night": float}.
static func light_at(f: float) -> Dictionary:
	f = fposmod(f, 1.0)
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if f >= float(a[0]) and f <= float(b[0]):
			var k: float = smoothstep(0.0, 1.0, (f - float(a[0])) / (float(b[0]) - float(a[0])))
			return {"mul": (a[1] as Color).lerp(b[1], k), "night": lerpf(float(a[2]), float(b[2]), k)}
	return {"mul": Color.WHITE, "night": 0.0}


## Météo du jour, tirée de façon déterministe : "clear", "rain", "fog" ou "snow".
static func weather_for_day(day: int) -> String:
	var r: int = absi(hash(day * 7919 + 13)) % 100
	if r < 56:
		return "clear"
	if r < 76:
		return "rain"
	if r < 91:
		return "fog"
	return "snow"


static func phase_name(f: float) -> String:
	f = fposmod(f, 1.0)
	if f < 0.10:
		return "Aube"
	if f < 0.62:
		return "Jour"
	if f < 0.78:
		return "Crépuscule"
	return "Nuit"


## Rayon de vue affiché : −25 % en pleine nuit.
func vision_scale() -> float:
	return 1.0 - NIGHT_VISION_LOSS * night


func update(delta: float, day: int, frac: float, day_night: bool, weather_on: bool, animate: bool) -> void:
	anim = animate
	if animate:
		t += delta
	var target: Dictionary = light_at(frac) if day_night else {"mul": Color.WHITE, "night": 0.0}
	# lissage : un jour de jeu ne dure que quelques secondes, le rendu ne doit pas clignoter
	var k: float = 1.0 - exp(-delta * 1.6)
	light = light.lerp(target["mul"], k)
	night = lerpf(night, float(target["night"]), k)
	if day != _last_day:
		_last_day = day
		wx_kind = weather_for_day(day)
	_wx_target = 1.0 if weather_on and wx_kind != "clear" else 0.0
	wx_k = move_toward(wx_k, _wx_target, delta * 0.5)
	if wx_k <= 0.0 and wx_kind != "clear" and not weather_on:
		pass


## Teinte à appliquer au monde (lumière du jour mêlée à la météo).
func world_tint() -> Color:
	var c: Color = light
	match wx_kind:
		"rain":
			c = c * Color(0.82, 0.86, 0.92).lerp(Color.WHITE, 1.0 - wx_k)
		"fog":
			c = c * Color(0.92, 0.94, 0.96).lerp(Color.WHITE, 1.0 - wx_k)
		"snow":
			c = c * Color(0.92, 0.95, 1.0).lerp(Color.WHITE, 1.0 - wx_k)
	return Color(c.r, c.g, c.b, 1.0)


# --- Couche de lumières (additive, dans le repère du monde) ---

func paint_lights(l: CanvasItem, lights: Array) -> void:
	var a: float = clampf(night * 1.15 - 0.1, 0.0, 1.0)
	if a <= 0.02:
		return
	for lt in lights:
		var p: Vector2 = lt["p"]
		if str(lt["k"]) == "win":
			l.draw_rect(Rect2(p - Vector2(1.2, 1.2), Vector2(2.4, 2.8)), Color(1.0, 0.82, 0.4, a))
			l.draw_texture_rect(_glow, Rect2(p - Vector2(5, 5), Vector2(10, 10)), false, Color(1.0, 0.7, 0.25, 0.5 * a))
		else:
			var fl: float = 0.75 + 0.25 * sin(t * 9.0 + p.x) * (1.0 if anim else 0.0) + (0.1 * sin(t * 23.0 + p.y) if anim else 0.0)
			l.draw_texture_rect(_glow, Rect2(p - Vector2(13, 13), Vector2(26, 26)), false, Color(1.0, 0.6, 0.2, 0.55 * a * fl))
			l.draw_circle(p + Vector2(0, -1), 1.7 * fl, Color(1.0, 0.85, 0.4, a))


# --- Surcouches en repère écran ---

func paint_sky(c: Control) -> void:
	if night < 0.25:
		return
	var a: float = clampf((night - 0.25) * 1.2, 0.0, 1.0) * (1.0 - wx_k * (0.0 if wx_kind == "clear" else 0.7))
	var s: Vector2 = c.size
	for i in 60:
		var x: float = fposmod(float(i) * 0.6180339 * 977.0, 1.0) * s.x
		var y: float = fposmod(float(i) * 0.7548776 * 613.0 + 0.3, 1.0) * s.y
		var tw: float = 0.6 + 0.4 * sin(t * (0.8 + fposmod(float(i) * 0.37, 1.0)) + float(i)) if anim else 0.8
		var col := Color(0.92, 0.94, 1.0, 0.55 * a * tw)
		c.draw_circle(Vector2(x, y), 0.9, col)
		if i % 7 == 0:
			c.draw_line(Vector2(x - 2.2, y), Vector2(x + 2.2, y), Color(col, col.a * 0.6), 0.7)
			c.draw_line(Vector2(x, y - 2.2), Vector2(x, y + 2.2), Color(col, col.a * 0.6), 0.7)


func paint_weather(c: Control) -> void:
	if wx_k <= 0.01:
		return
	var s: Vector2 = c.size
	match wx_kind:
		"rain":
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.12, 0.16, 0.22, 0.12 * wx_k))
			for i in 150:
				var sp: float = 520.0 + fposmod(float(i) * 31.7, 140.0)
				var x: float = fposmod(float(i) * 97.3 + t * 140.0 * (1.0 if anim else 0.0) * 0.4, s.x + 80.0) - 40.0
				var y: float = fposmod(float(i) * 53.1 + t * sp, s.y + 40.0) - 20.0
				c.draw_line(Vector2(x, y), Vector2(x - 4.0, y + 11.0), Color(0.78, 0.86, 0.95, 0.38 * wx_k), 1.0)
		"snow":
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.9, 0.93, 1.0, 0.08 * wx_k))
			for i in 120:
				var sp2: float = 28.0 + fposmod(float(i) * 7.7, 30.0)
				var x2: float = fposmod(float(i) * 83.9, s.x) + sin(t * 0.9 + float(i)) * 12.0
				var y2: float = fposmod(float(i) * 41.3 + t * sp2, s.y + 20.0) - 10.0
				c.draw_circle(Vector2(x2, y2), 1.2 + fposmod(float(i), 3.0) * 0.5, Color(1, 1, 1, 0.7 * wx_k))
		"fog":
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.82, 0.85, 0.84, 0.16 * wx_k))
			for i in 12:
				var bw: float = 320.0 + fposmod(float(i) * 57.0, 200.0)
				var x3: float = fposmod(float(i) * 211.0 + t * (6.0 + float(i % 4) * 2.0), s.x + bw) - bw * 0.5
				var y3: float = fposmod(float(i) * 173.0, s.y)
				c.draw_texture_rect(_glow, Rect2(Vector2(x3 - bw * 0.5, y3 - bw * 0.3), Vector2(bw, bw * 0.6)), false, Color(0.86, 0.88, 0.87, 0.34 * wx_k))


## Cadre de parchemin, rose des vents, échelle (1 jour de marche) et heure du jour.
func paint_frame(c: Control, day_px: float, zoom_px_per_world: float, day_frac: float, show_clock: bool) -> void:
	var s: Vector2 = c.size
	var brown := Color("2a1d12")
	var parch := Color("b79f6b")
	var ink := Color("3a2a18")
	var bw: float = 9.0
	c.draw_rect(Rect2(0, 0, s.x, bw), brown)
	c.draw_rect(Rect2(0, s.y - bw, s.x, bw), brown)
	c.draw_rect(Rect2(0, 0, bw, s.y), brown)
	c.draw_rect(Rect2(s.x - bw, 0, bw, s.y), brown)
	var r2 := Rect2(Vector2(bw, bw), s - Vector2(bw, bw) * 2.0)
	c.draw_rect(r2.grow(-0.0), parch, false, 3.0)
	c.draw_rect(r2.grow(-4.0), ink, false, 1.0)
	# graduations façon carte ancienne
	var x: float = bw + 12.0
	var n: int = 0
	while x < s.x - bw - 8.0:
		var h: float = 4.0 if n % 5 == 0 else 2.0
		c.draw_line(Vector2(x, bw + 5.0), Vector2(x, bw + 5.0 + h), Color(ink, 0.7), 1.0)
		c.draw_line(Vector2(x, s.y - bw - 5.0), Vector2(x, s.y - bw - 5.0 - h), Color(ink, 0.7), 1.0)
		x += 14.0
		n += 1
	var y: float = bw + 12.0
	n = 0
	while y < s.y - bw - 8.0:
		var h2: float = 4.0 if n % 5 == 0 else 2.0
		c.draw_line(Vector2(bw + 5.0, y), Vector2(bw + 5.0 + h2, y), Color(ink, 0.7), 1.0)
		c.draw_line(Vector2(s.x - bw - 5.0, y), Vector2(s.x - bw - 5.0 - h2, y), Color(ink, 0.7), 1.0)
		y += 14.0
		n += 1
	for corner in [Vector2(bw, bw), Vector2(s.x - bw, bw), Vector2(bw, s.y - bw), Vector2(s.x - bw, s.y - bw)]:
		var dir := Vector2(1.0 if corner.x < s.x * 0.5 else -1.0, 1.0 if corner.y < s.y * 0.5 else -1.0)
		var d := PackedVector2Array([corner + dir * Vector2(0, 0), corner + dir * Vector2(14, 3), corner + dir * Vector2(3, 14)])
		c.draw_colored_polygon(d, parch)
		c.draw_circle(corner + dir * 8.0, 2.4, ink)
		c.draw_circle(corner + dir * 8.0, 1.2, parch)
	# rose des vents (bas à droite)
	var rc := Vector2(s.x - 62.0, s.y - 62.0)
	_compass(c, rc, 30.0)
	# échelle
	var px: float = day_px * zoom_px_per_world
	var sc := Rect2(Vector2(s.x - 150.0, s.y - 38.0), Vector2(maxf(px + 16.0, 112.0), 24.0))
	sc.position.x = s.x - 108.0 - sc.size.x
	c.draw_rect(sc, Color(0.72, 0.6, 0.38, 0.88))
	c.draw_rect(sc, ink, false, 1.2)
	var bx: float = sc.position.x + 8.0
	for i in 2:
		c.draw_rect(Rect2(Vector2(bx + px * 0.5 * i, sc.position.y + 12.0), Vector2(px * 0.5, 4.0)), ink if i == 0 else Color("e6dcc0"))
	c.draw_rect(Rect2(Vector2(bx, sc.position.y + 12.0), Vector2(px, 4.0)), ink, false, 1.0)
	var f: Font = GameTheme.title_font()
	c.draw_string(f, Vector2(bx, sc.position.y + 10.0), "1 jour de marche", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	# heure du jour (haut à droite)
	if show_clock:
		var cc := Vector2(s.x - 40.0, 40.0)
		c.draw_circle(cc, 17.0, Color(brown, 0.85))
		c.draw_arc(cc, 17.0, 0.0, TAU, 24, parch, 1.6, true)
		var ang: float = -PI + day_frac * TAU
		var sun_p: Vector2 = cc + Vector2(cos(ang), sin(ang)) * 10.0
		var is_night: bool = day_frac > 0.75
		c.draw_circle(sun_p, 4.0, Color("d9dce8") if is_night else Color("f0c050"))
		if is_night:
			c.draw_circle(sun_p + Vector2(1.6, -1.0), 3.4, Color(brown, 0.95))
		c.draw_line(cc + Vector2(-13, 4), cc + Vector2(13, 4), Color(parch, 0.5), 1.0)
		c.draw_string(f, Vector2(cc.x - 34.0, cc.y + 32.0), phase_name(day_frac), HORIZONTAL_ALIGNMENT_CENTER, 68, 13, Color("e6dcc0"))


func _compass(c: Control, p: Vector2, r: float) -> void:
	var ink := Color("3a2a18")
	var parch := Color("d6c597")
	c.draw_circle(p, r + 5.0, Color(0.72, 0.6, 0.38, 0.88))
	c.draw_arc(p, r + 5.0, 0.0, TAU, 32, ink, 1.2, true)
	c.draw_arc(p, r * 0.62, 0.0, TAU, 24, Color(ink, 0.6), 0.8, true)
	for i in 8:
		var a: float = -PI / 2.0 + TAU * float(i) / 8.0
		var long: bool = i % 2 == 0
		var len_: float = r if long else r * 0.62
		var wd: float = 0.16 if long else 0.2
		var tip: Vector2 = p + Vector2(cos(a), sin(a)) * len_
		var l1: Vector2 = p + Vector2(cos(a - wd * 2.2), sin(a - wd * 2.2)) * r * 0.2
		var l2: Vector2 = p + Vector2(cos(a + wd * 2.2), sin(a + wd * 2.2)) * r * 0.2
		c.draw_colored_polygon(PackedVector2Array([tip, l2, p]), ink if long else Color("5c4a30"))
		c.draw_colored_polygon(PackedVector2Array([tip, l1, p]), Color("e6dcc0") if long else parch)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(3, -r * 0.2), p]), Color("9c2f24"))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(-3, -r * 0.2), p]), Color("c8483a"))
	c.draw_string(GameTheme.title_font(), p + Vector2(-8, -r - 8.0), "N", HORIZONTAL_ALIGNMENT_CENTER, 16, 15, ink)
	c.draw_circle(p, 2.2, ink)
