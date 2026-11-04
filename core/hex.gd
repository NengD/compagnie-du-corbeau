class_name Hex
extends RefCounted
## Coordonnées axiales (q, r), hexagones « pointy-top ». Logique pure.

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const SQ: float = 1.7320508075688772


static func distance(a: Vector2i, b: Vector2i) -> int:
	return (absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2


static func neighbors(h: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		out.append(h + d)
	return out


## Colonne « visuelle » d'une case (la grille est un rectangle décalé).
static func column(h: Vector2i) -> int:
	return h.x + (h.y >> 1)


static func from_col_row(col: int, row: int) -> Vector2i:
	return Vector2i(col - (row >> 1), row)


## Centre de la case en pixels pour un hexagone de rayon `size`.
static func to_pixel(h: Vector2i, size: float, margin: float = 6.0) -> Vector2:
	return Vector2(size * SQ * (h.x + h.y / 2.0) + size * SQ / 2.0 + margin, size * 1.5 * h.y + size + margin)


static func from_pixel(p: Vector2, size: float, margin: float = 6.0) -> Vector2i:
	var y: float = (p.y - size - margin) / (size * 1.5)
	var x: float = (p.x - size * SQ / 2.0 - margin) / (size * SQ) - y / 2.0
	return _round_axial(x, y)


static func _round_axial(fq: float, fr: float) -> Vector2i:
	var fs: float = -fq - fr
	var q: float = roundf(fq)
	var r: float = roundf(fr)
	var s: float = roundf(fs)
	var dq: float = absf(q - fq)
	var dr: float = absf(r - fr)
	var ds: float = absf(s - fs)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))


static func corners(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(a), sin(a)) * size)
	return pts
