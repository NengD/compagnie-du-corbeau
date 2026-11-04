class_name Illustrations
extends Control
## Scènes peintes simplifiées, dessinées par code dans la palette du jeu : "town" (remparts au crépuscule), "victory" (bannière levée),
## "defeat" (champ de bataille sombre), "night" (campement nocturne). Corbeaux et étoiles sont déterministes (graine fixe).
## `Illustrations.banner(kind, height)` renvoie un bandeau prêt à insérer dans une boîte verticale.

const KINDS: Array[String] = ["town", "victory", "defeat", "night"]
const SKY := {
	"town": [Color("e0905a"), Color("4a2a38")],
	"victory": [Color("f0c070"), Color("5a3a30")],
	"defeat": [Color("5a4a48"), Color("1a1416")],
	"night": [Color("1c2438"), Color("0c0e16")],
}
const SIL := Color("120e0c")

var kind: String = "town"
var caption: String = ""


static func banner(k: String, h: int = 110, text: String = "") -> Illustrations:
	var il := Illustrations.new()
	il.kind = k if KINDS.has(k) else "town"
	il.caption = text
	il.custom_minimum_size = Vector2(0, h)
	il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	il.mouse_filter = Control.MOUSE_FILTER_IGNORE
	il.clip_contents = true
	return il


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), kind)
	if caption != "":
		var f: Font = GameTheme.title_font()
		var fs: int = GameTheme.scaled_size(int(clampf(size.y * 0.42, 22.0, 72.0)))
		var w: float = f.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var p := Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * 0.3)
		draw_string(f, p + Vector2(2, 2), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
		draw_string(f, p, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GameTheme.INK)
	draw_rect(Rect2(Vector2.ZERO, size), Color("17110c"), false, 2.0)
	draw_line(Vector2(0, size.y - 3), Vector2(size.x, size.y - 3), Color("8a6f36"), 1.0)


## Dessine la scène `k` dans `r` sur le CanvasItem `c` (réutilisable : bandeaux, écrans plein cadre).
static func paint(c: CanvasItem, r: Rect2, k: String) -> void:
	var cols: Array = SKY.get(k, SKY["town"])
	var n: int = 16
	for i in n:
		var t: float = float(i) / float(n - 1)
		c.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / n, r.size.x, r.size.y / n + 1.0), (cols[0] as Color).lerp(cols[1], t))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + KINDS.find(k)
	if k == "night" or k == "defeat":  # étoiles / lune
		for i in 40:
			var p := Vector2(r.position.x + rng.randf() * r.size.x, r.position.y + rng.randf() * r.size.y * 0.55)
			c.draw_circle(p, 0.7 + rng.randf() * 0.6, Color(1, 1, 0.9, 0.35 + rng.randf() * 0.4))
		c.draw_circle(r.position + Vector2(r.size.x * 0.8, r.size.y * 0.22), r.size.y * 0.09, Color("e8e0c0") if k == "night" else Color("a8a090"))
	else:  # soleil bas
		c.draw_circle(r.position + Vector2(r.size.x * 0.3, r.size.y * 0.62), r.size.y * 0.2, Color(1.0, 0.85, 0.5, 0.28))
		c.draw_circle(r.position + Vector2(r.size.x * 0.3, r.size.y * 0.62), r.size.y * 0.11, Color(1.0, 0.9, 0.6, 0.5))
	var ground: float = r.position.y + r.size.y * 0.78
	match k:
		"town":
			_walls(c, r, ground, rng)
		"victory":
			_hills(c, r, ground, rng)
			_flag(c, Vector2(r.position.x + r.size.x * 0.5, ground), r.size.y * 0.62, Color("b8862e"))
		"defeat":
			_hills(c, r, ground, rng)
			_spears(c, r, ground, rng)
		"night":
			_hills(c, r, ground, rng)
			_tents(c, r, ground)
	if k != "night":
		_ravens(c, r, rng, 6 if k == "victory" or k == "defeat" else 3)


static func _hills(c: CanvasItem, r: Rect2, ground: float, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array([Vector2(r.position.x, r.end.y)])
	var phase: float = rng.randf() * 6.0
	for i in 25:
		var x: float = r.position.x + r.size.x * i / 24.0
		pts.append(Vector2(x, ground - sin(i * 0.7 + phase) * r.size.y * 0.04 - r.size.y * 0.02))
	pts.append(Vector2(r.end.x, r.end.y))
	c.draw_colored_polygon(pts, SIL)


static func _walls(c: CanvasItem, r: Rect2, ground: float, rng: RandomNumberGenerator) -> void:
	var base: float = ground
	c.draw_rect(Rect2(r.position.x, base - r.size.y * 0.16, r.size.x, r.end.y - base + r.size.y * 0.16), SIL)
	# créneaux
	var step: float = maxf(10.0, r.size.y * 0.09)
	var x: float = r.position.x
	while x < r.end.x:
		c.draw_rect(Rect2(x, base - r.size.y * 0.16 - step * 0.6, step * 0.55, step * 0.6), SIL)
		x += step
	# tours, toits pointus et fenêtres éclairées
	for i in 4:
		var tx: float = r.position.x + r.size.x * (0.12 + i * 0.25 + rng.randf() * 0.04)
		var tw: float = r.size.y * (0.14 + rng.randf() * 0.04)
		var th: float = r.size.y * (0.38 + rng.randf() * 0.14)
		c.draw_rect(Rect2(tx, base - th, tw, th), SIL)
		c.draw_colored_polygon(PackedVector2Array([Vector2(tx - 3, base - th), Vector2(tx + tw * 0.5, base - th - tw * 0.9), Vector2(tx + tw + 3, base - th)]), SIL)
		c.draw_rect(Rect2(tx + tw * 0.4, base - th * 0.72, tw * 0.2, tw * 0.3), Color("f0b860"))
	# porte éclairée
	var gx: float = r.position.x + r.size.x * 0.5
	c.draw_rect(Rect2(gx - r.size.y * 0.07, base - r.size.y * 0.15, r.size.y * 0.14, r.size.y * 0.15), Color("e8a850"))


static func _flag(c: CanvasItem, foot: Vector2, h: float, col: Color) -> void:
	c.draw_line(foot, foot + Vector2(0, -h), SIL, 3.0)
	var w: float = h * 0.42
	var top: Vector2 = foot + Vector2(0, -h)
	c.draw_colored_polygon(PackedVector2Array([top + Vector2(2, 0), top + Vector2(w, h * 0.06), top + Vector2(w * 0.8, h * 0.2), top + Vector2(w, h * 0.34), top + Vector2(2, h * 0.3)]), col)
	c.draw_polyline(PackedVector2Array([top + Vector2(2, 0), top + Vector2(w, h * 0.06), top + Vector2(w * 0.8, h * 0.2), top + Vector2(w, h * 0.34), top + Vector2(2, h * 0.3), top + Vector2(2, 0)]), SIL, 1.5)
	_raven(c, top + Vector2(w * 0.45, h * 0.15), h * 0.1, Color("1d1a17"))  # emblème : corbeau
	c.draw_circle(top, 3.0, Color("c9a24a"))


static func _spears(c: CanvasItem, r: Rect2, ground: float, rng: RandomNumberGenerator) -> void:
	for i in 9:
		var x: float = r.position.x + r.size.x * (0.05 + i * 0.11 + rng.randf() * 0.04)
		var h: float = r.size.y * (0.25 + rng.randf() * 0.3)
		var lean: float = (rng.randf() - 0.5) * h * 0.4
		c.draw_line(Vector2(x, ground + 2), Vector2(x + lean, ground - h), SIL, 2.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + lean, ground - h - 6), Vector2(x + lean - 2, ground - h), Vector2(x + lean + 2, ground - h)]), SIL)
		if i % 3 == 1:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x + lean, ground - h * 0.9), Vector2(x + lean + h * 0.3, ground - h * 0.8), Vector2(x + lean, ground - h * 0.65)]), Color("4a1c18"))


static func _tents(c: CanvasItem, r: Rect2, ground: float) -> void:
	for i in 3:
		var x: float = r.position.x + r.size.x * (0.25 + i * 0.22)
		var w: float = r.size.y * 0.3
		var h: float = r.size.y * 0.3
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - w, ground + 4), Vector2(x, ground - h), Vector2(x + w, ground + 4)]), SIL)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.18, ground + 4), Vector2(x, ground - h * 0.35), Vector2(x + w * 0.18, ground + 4)]), Color("e8a850"))
	var fx: float = r.position.x + r.size.x * 0.5
	c.draw_circle(Vector2(fx, ground + 2), r.size.y * 0.05, Color(1.0, 0.6, 0.2, 0.35))
	c.draw_colored_polygon(PackedVector2Array([Vector2(fx - 3, ground + 4), Vector2(fx, ground - r.size.y * 0.07), Vector2(fx + 3, ground + 4)]), Color("f4b040"))


static func _ravens(c: CanvasItem, r: Rect2, rng: RandomNumberGenerator, count: int) -> void:
	for i in count:
		var p := Vector2(r.position.x + r.size.x * (0.1 + rng.randf() * 0.8), r.position.y + r.size.y * (0.1 + rng.randf() * 0.35))
		_raven(c, p, r.size.y * (0.05 + rng.randf() * 0.04), SIL)


## Corbeau en vol : deux ailes en V et un corps ; `s` = demi-envergure.
static func _raven(c: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s, -s * 0.5), p + Vector2(-s * 0.3, -s * 0.05), p, p + Vector2(-s * 0.4, s * 0.3)]), col)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(s, -s * 0.5), p + Vector2(s * 0.3, -s * 0.05), p, p + Vector2(s * 0.4, s * 0.3)]), col)
	c.draw_circle(p + Vector2(0, s * 0.05), s * 0.22, col)
