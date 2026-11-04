class_name GroundTex
extends RefCounted
## Textures de sol tileables générées par code (bruit FastNoiseLite), en niveaux de gris clairs :
## le plateau les teinte par biome. Mises en cache, créées une seule fois par processus.

const SIZE := 128
static var _cache: Dictionary = {}


## Clé : "grass0".."grass2", "dirt", "rock", "water", "sand".
static func get_tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = ImageTexture.create_from_image(_make(key))
	_cache[key] = tex
	return tex


static func _noise(seed_v: int, freq: float, kind: int, octaves: int = 3) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	return n.get_seamless_image(SIZE, SIZE)


static func _make(key: String) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var base: String = key.rstrip("0123456789")
	var variant: int = int(key.substr(base.length())) if key.length() > base.length() else 0
	var n1: Image
	var n2: Image
	var n3: Image
	match base:
		"grass":
			n1 = _noise(11 + variant * 7, 0.022, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
			n2 = _noise(23 + variant * 5, 0.11, FastNoiseLite.TYPE_PERLIN)
		"dirt":
			n1 = _noise(31, 0.028, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
			n2 = _noise(37, 0.16, FastNoiseLite.TYPE_PERLIN)
		"rock":
			n1 = _noise(41, 0.05, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
			n2 = _noise(43, 0.05, FastNoiseLite.TYPE_CELLULAR, 1)
			n3 = _noise(47, 0.2, FastNoiseLite.TYPE_PERLIN)
		"water":
			n1 = _noise(51, 0.03, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
			n2 = _noise(53, 0.09, FastNoiseLite.TYPE_PERLIN)
		_:  # sable
			n1 = _noise(61, 0.04, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
			n2 = _noise(67, 0.4, FastNoiseLite.TYPE_PERLIN)
	for y in SIZE:
		for x in SIZE:
			var a: float = n1.get_pixel(x, y).r
			var b: float = n2.get_pixel(x, y).r
			var v: float
			match base:
				"grass":
					v = 0.80 + 0.14 * a + 0.09 * b
				"dirt":
					v = 0.76 + 0.14 * a + 0.12 * b
				"rock":
					var c: float = n3.get_pixel(x, y).r
					var edge: float = n2.get_pixel(x, y).r
					v = 0.72 + 0.2 * a + 0.1 * c - 0.18 * (1.0 - smoothstep(0.0, 0.18, edge))
				"water":
					v = 0.82 + 0.12 * a + 0.1 * b
				_:
					v = 0.84 + 0.08 * a + 0.1 * (b - 0.5)
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	# détails ponctuels (touffes, cailloux), enroulés pour rester tileables
	var specks: int = 0
	match base:
		"grass":
			specks = 150
		"dirt":
			specks = 70
		"rock":
			specks = 24
		"sand":
			specks = 90
	for i in specks:
		var px: int = rng.randi_range(0, SIZE - 1)
		var py: int = rng.randi_range(0, SIZE - 1)
		var dark: bool = rng.randf() < 0.65
		var d: float = -0.13 if dark else 0.08
		var len: int = rng.randi_range(2, 4) if base == "grass" else 1
		for k in len:
			var xx: int = (px + (k / 2)) % SIZE
			var yy: int = (py - k) % SIZE
			if yy < 0:
				yy += SIZE
			var c0: Color = img.get_pixel(xx, yy)
			var nv: float = clampf(c0.r + d, 0.0, 1.0)
			img.set_pixel(xx, yy, Color(nv, nv, nv, 1.0))
	return img
