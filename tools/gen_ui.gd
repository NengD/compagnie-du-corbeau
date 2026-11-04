extends SceneTree
## Génère les 9-patch de l'interface « cuir et parchemin » dans assets/ui/ (dessinés pixel par pixel, sans ressource externe).
## godot --path . --headless -s res://tools/gen_ui.gd   puis   --headless --import

const OUT := "res://assets/ui/"
const INK0 := Color("0e0b08")
const GOLD := Color("cfa851")
const GOLD_D := Color("8a6f36")

var _seed: int = 1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_panel(64, Color("26211b"), 7, true), "panel")
	_save(_panel(64, Color("201b16"), 9, false), "panel_dark")
	_save(_card(48), "card")
	_save(_modal(96), "modal")
	_save(_chip(24, 20), "chip")
	_save(_flat(24, Color("30291f")), "flat")
	_save(_news(32), "news")
	for kind in ["", "pri"]:
		var base: Color = Color("30291f") if kind == "" else Color("6a231c")
		var pre: String = "btn_" if kind == "" else "btn_pri_"
		_save(_button(32, base, GOLD_D if kind == "" else Color("a8863e"), 0), pre + "normal")
		_save(_button(32, base.lightened(0.1), GOLD, 0), pre + "hover")
		_save(_button(32, base.darkened(0.2), GOLD, 1), pre + "pressed")
		_save(_button(32, base.darkened(0.15).lerp(Color("1c1915"), 0.35), Color("4a3f31"), 2), pre + "disabled")
	_save(_divider(256, 16), "divider")
	_save(_header_strip(256, 40), "header")
	print("textures écrites dans ", OUT)
	quit()


func _save(img: Image, n: String) -> void:
	var p: String = ProjectSettings.globalize_path(OUT + n + ".png")
	var err: int = img.save_png(p)
	if err != OK:
		push_error("échec de l'écriture de " + p)


# ---------------------------------------------------------------- outils
func _hash(x: int, y: int, s: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + s * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


## Cuir : grain fin et grosses variations ; `k` règle le contraste.
func _grain(c: Color, x: int, y: int, k: float = 1.0) -> Color:
	var n1: float = _hash(x, y, _seed)
	var n2: float = _hash(x / 3, y / 3, _seed + 7)
	var n3: float = _hash(x / 9, y / 9, _seed + 13)
	var f: float = 1.0 + ((n1 - 0.5) * 0.10 + (n2 - 0.5) * 0.10 + (n3 - 0.5) * 0.12) * k
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)


func _blank(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _edge(x: int, y: int, w: int, h: int) -> int:
	return mini(mini(x, y), mini(w - 1 - x, h - 1 - y))


## Coins arrondis de 2 px : vrai si le pixel est à rogner.
func _clipped(x: int, y: int, w: int, h: int, r: int = 2) -> bool:
	var dx: int = mini(x, w - 1 - x)
	var dy: int = mini(y, h - 1 - y)
	return dx + dy < r


func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy))
			if d <= r:
				img.set_pixel(x, y, c)
			elif d <= r + 0.8:
				var a: float = 1.0 - (d - r) / 0.8
				var o: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, o.lerp(Color(c, 1.0), a * c.a))


func _rivet(img: Image, cx: float, cy: float, r: float = 2.6) -> void:
	_disc(img, cx + 0.6, cy + 0.8, r + 0.4, Color(0, 0, 0, 0.5))
	_disc(img, cx, cy, r, Color("2a1d10"))
	_disc(img, cx, cy, r - 0.7, Color("8a6a3a"))
	_disc(img, cx - 0.5, cy - 0.6, r - 1.4, Color("c8a468"))
	_disc(img, cx - 0.9, cy - 1.0, 0.7, Color("f0dcA0"))


# ---------------------------------------------------------------- panneau de cuir cousu
func _panel(n: int, base: Color, stitch_at: int, rivets: bool) -> Image:
	_seed = 3
	var img := _blank(n, n)
	for y in n:
		for x in n:
			if _clipped(x, y, n, n):
				continue
			var d: int = _edge(x, y, n, n)
			var c: Color = _grain(base, x, y)
			if d == 0:
				c = INK0
			elif d == 1:
				c = Color("5a4c38") if (x < n / 2 and y < n / 2) or x < y and x < n - y else Color("3a2f22")
				c = Color("4e4232") if x + y < n else Color("2a2218")
			elif d == 2:
				c = c.darkened(0.25)
			# couture : tirets de fil clair, ombre dessous
			var along: int = x if (y == d or y == n - 1 - d) else y
			if d == stitch_at and (along % 7) < 4 and d == _edge(x, y, n, n):
				c = Color("a08a5c")
			elif d == stitch_at + 1 and (along % 7) < 4:
				c = c.darkened(0.4)
			img.set_pixel(x, y, c)
	if rivets:
		var o: float = float(stitch_at) + 7.0
		for p in [Vector2(o, o), Vector2(n - o, o), Vector2(o, n - o), Vector2(n - o, n - o)]:
			_rivet(img, p.x, p.y, 2.4)
	return img


# ---------------------------------------------------------------- carte de parchemin sombre
func _card(n: int) -> Image:
	_seed = 11
	var img := _blank(n, n)
	var base := Color("352c20")
	for y in n:
		for x in n:
			if _clipped(x, y, n, n):
				continue
			var d: int = _edge(x, y, n, n)
			var fib: float = _hash(x / 14, y, 5) - 0.5  # fibres horizontales
			var c: Color = _grain(base, x, y, 1.3)
			c = c.lightened(fib * 0.07)
			var burn: float = 1.0 - clampf(1.0 - float(d) / 9.0, 0.0, 1.0) * 0.42  # bords brûlés
			c = Color(c.r * burn, c.g * burn, c.b * burn, 1.0)
			if d == 0:
				c = INK0
			elif d == 1:
				c = Color("574a34")
			elif d == 4 and x > 3 and y > 3 and x < n - 4 and y < n - 4:
				c = c.lerp(Color("7a6840"), 0.55)
			img.set_pixel(x, y, c)
	# petits ornements aux angles
	for p in [Vector2(4, 4), Vector2(n - 5, 4), Vector2(4, n - 5), Vector2(n - 5, n - 5)]:
		_disc(img, p.x, p.y, 1.2, Color("8a7648"))
	return img


# ---------------------------------------------------------------- fenêtre modale : cuir, double filet d'or
func _modal(n: int) -> Image:
	_seed = 19
	var img := _blank(n, n)
	var base := Color("231e18")
	for y in n:
		for x in n:
			if _clipped(x, y, n, n, 3):
				continue
			var d: int = _edge(x, y, n, n)
			var c: Color = _grain(base, x, y)
			if d == 0:
				c = INK0
			elif d == 1 or d == 2:
				c = Color("3a2f22")
			elif d == 3 or d == 4:
				c = GOLD if (x + y) % 2 == 0 or d == 3 else GOLD_D
				c = GOLD if d == 3 else GOLD_D
			elif d == 5:
				c = INK0
			elif d == 9:
				c = c.lerp(Color("6a5530"), 0.7)
			elif d == 6 or d == 7:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	# losanges d'or aux angles + rivets à mi-bord
	for p in [Vector2(12, 12), Vector2(n - 13, 12), Vector2(12, n - 13), Vector2(n - 13, n - 13)]:
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				var m: int = absi(dx) + absi(dy)
				if m <= 5:
					img.set_pixelv(Vector2i(int(p.x) + dx, int(p.y) + dy), INK0 if m == 5 else (GOLD if m <= 3 else GOLD_D))
		img.set_pixelv(Vector2i(int(p.x) - 1, int(p.y) - 1), Color("f4e0a0"))
	return img


# ---------------------------------------------------------------- bouton de cuir à liseré d'or
## state : 0 normal/survol, 1 appuyé (ombre en haut), 2 désactivé.
func _button(n: int, base: Color, rim: Color, state: int) -> Image:
	_seed = 23 + state
	var img := _blank(n, n)
	for y in n:
		for x in n:
			if _clipped(x, y, n, n):
				continue
			var d: int = _edge(x, y, n, n)
			var t: float = float(y) / float(n - 1)
			var shade: float = (0.18 - 0.36 * t) if state != 1 else (-0.18 + 0.30 * t)
			var c: Color = _grain(base, x, y, 0.9)
			c = Color(clampf(c.r * (1.0 + shade), 0, 1), clampf(c.g * (1.0 + shade), 0, 1), clampf(c.b * (1.0 + shade), 0, 1), 1.0)
			if d == 0:
				c = INK0
			elif d == 1:
				c = rim
			elif d == 2:
				c = c.darkened(0.3) if state != 1 else c.darkened(0.45)
			elif d == 3 and state == 0 and y < n / 2:
				c = c.lightened(0.10)
			img.set_pixel(x, y, c)
	return img


func _chip(w: int, h: int) -> Image:
	_seed = 31
	var img := _blank(w, h)
	for y in h:
		for x in w:
			if _clipped(x, y, w, h):
				continue
			var d: int = _edge(x, y, w, h)
			var c: Color = _grain(Color("2c261d"), x, y, 0.6)
			if d == 0:
				c = Color("4a3f31")
			elif d == 1:
				c = c.darkened(0.2)
			img.set_pixel(x, y, c)
	return img


## Petite plaque (cases de statistiques, lignes d'inventaire) : cuir sombre sans bordure marquée.
func _flat(n: int, base: Color) -> Image:
	_seed = 37
	var img := _blank(n, n)
	for y in n:
		for x in n:
			if _clipped(x, y, n, n, 1):
				continue
			var d: int = _edge(x, y, n, n)
			var c: Color = _grain(base, x, y, 0.8)
			if d == 0:
				c = c.darkened(0.45)
			elif d == 1:
				c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	return img


## Bandeau de nouvelles : fond de cuir avec une tranche d'or à gauche.
func _news(n: int) -> Image:
	_seed = 41
	var img := _blank(n, n)
	for y in n:
		for x in n:
			var c: Color = _grain(Color("26211b"), x, y, 0.8)
			if x < 3:
				c = GOLD if x > 0 else INK0
			elif x == n - 1 or y == 0 or y == n - 1:
				c = c.darkened(0.4)
			img.set_pixel(x, y, c)
	return img


# ---------------------------------------------------------------- séparateur orné
func _divider(w: int, h: int) -> Image:
	var img := _blank(w, h)
	var cy: int = h / 2
	for x in w:
		var fade: float = clampf(minf(float(x), float(w - 1 - x)) / (w * 0.35), 0.0, 1.0)
		var gap: bool = absi(x - w / 2) < 14
		if gap:
			continue
		img.set_pixel(x, cy, Color(GOLD, fade * 0.9))
		img.set_pixel(x, cy + 1, Color(INK0, fade * 0.7))
		if (x % 24) == 0 and x > w * 0.1 and x < w * 0.9:
			img.set_pixel(x, cy - 1, Color(GOLD, fade * 0.8))
	# losange central + petits losanges de part et d'autre
	for off in [-28, 0, 28]:
		var r: int = 5 if off == 0 else 2
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var m: int = absi(dx) + absi(dy)
				if m <= r:
					img.set_pixelv(Vector2i(w / 2 + off + dx, cy + dy), INK0 if m == r else (GOLD if m <= r - 2 else GOLD_D))
	return img


## Bandeau d'en-tête : cuir sombre, filet d'or en bas.
func _header_strip(w: int, h: int) -> Image:
	_seed = 53
	var img := _blank(w, h)
	for y in h:
		for x in w:
			var c: Color = _grain(Color("1f1a15"), x, y, 0.9)
			if y == h - 1:
				c = INK0
			elif y == h - 2:
				c = GOLD_D
			elif y == h - 3:
				c = c.darkened(0.3)
			elif y == 0:
				c = Color("3a2f22")
			img.set_pixel(x, y, c)
	return img
