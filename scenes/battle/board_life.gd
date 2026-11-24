class_name BoardLife
extends RefCounted
## Ambiance animée du plateau de bataille : orientation des ombres selon l'heure, particules de saison / de région (feuilles,
## pétales, neige légère, poussière, pollen), filets de courant sur l'eau. PUREMENT VISUEL, en arrière-plan (alpha bas, jamais sur
## les unités ni les marques) ; positions calculées par hachage de (graine, indice, temps) : sans aucun tirage au sort.
## Coupé quand les animations d'ambiance le sont (Quality "map_anim") et par la densité de particules (Quality "particles").

const BASE_COUNT := 16
const MAX_COUNT := 40


## Ombres : {"dx": inclinaison horizontale (-1 gauche .. +1 droite), "len": allongement, "a": opacité}.
## Le matin le soleil est à gauche (ombres vers la droite), le soir à droite ; midi : ombres courtes ; nuit : très faibles.
static func sun(frac: float, night: bool) -> Dictionary:
	if night:
		return {"dx": 0.35, "len": 1.0, "a": 0.14}
	var t: float = clampf((fposmod(frac, 1.0) - 0.08) / 0.62, 0.0, 1.0)
	var sx: float = lerpf(-1.0, 1.0, t)
	return {"dx": -sx * 0.9, "len": 1.45 - 0.75 * sin(t * PI), "a": 0.3}


## Nom du mode de particules : "none" | "leaves" | "petals" | "snow" | "dust" | "pollen".
static func mode_for(season: int, region_kind: String, weather: String) -> String:
	if weather == "snow" or weather == "rain":
		return "none"  # la météo fournit déjà ses propres particules
	if region_kind == "snow" or season == Seasons.WINTER:
		return "snow"
	if region_kind in ["desert", "rocky", "ruins"]:
		return "dust"
	if season == Seasons.AUTUMN:
		return "leaves"
	if season == Seasons.SPRING and region_kind in ["meadow", "farmland", "heath"]:
		return "petals"
	return "pollen"


static func count_for(density: float) -> int:
	if density <= 0.0:
		return 0
	return clampi(roundi(float(BASE_COUNT) * density), 1, MAX_COUNT)


## Particules à l'instant `t` : [{"p": Vector2, "r": float (rotation), "s": float (taille 0..1), "a": float (opacité 0..1)}].
static func particles(mode: String, n: int, t: float, area: Vector2, seed_value: int) -> Array:
	var out: Array = []
	if mode == "none" or n <= 0 or area.x <= 0.0 or area.y <= 0.0:
		return out
	var vx: float = 14.0
	var vy: float = 18.0
	match mode:
		"snow":
			vx = 6.0
			vy = 16.0
		"dust":
			vx = 36.0
			vy = 1.0
		"pollen":
			vx = 5.0
			vy = -4.0
		"petals":
			vx = 12.0
			vy = 12.0
	for i in n:
		var x0: float = MapLife.unit(seed_value, i, 1) * area.x
		var y0: float = MapLife.unit(seed_value, i, 2) * area.y
		var sp: float = 0.6 + MapLife.unit(seed_value, i, 3) * 0.8
		var ph: float = MapLife.unit(seed_value, i, 4) * TAU
		var x: float = fposmod(x0 + t * vx * sp + sin(t * 0.9 + ph) * 9.0, area.x)
		var y: float = fposmod(y0 + t * vy * sp + sin(t * 0.7 + ph * 1.3) * 3.0, area.y)
		var fade: float = clampf(minf(minf(x, area.x - x), minf(y, area.y - y)) / 30.0, 0.0, 1.0)
		out.append({"p": Vector2(x, y), "r": t * (1.5 + sp) + ph, "s": 0.5 + MapLife.unit(seed_value, i, 5) * 0.5, "a": fade})
	return out


static func paint_ambient(l: CanvasItem, mode: String, n: int, t: float, area: Vector2, seed_value: int) -> void:
	for q in particles(mode, n, t, area, seed_value):
		var p: Vector2 = q["p"]
		var s: float = q["s"]
		var a: float = q["a"]
		match mode:
			"leaves":
				var col: Color = Color("b8641f") if int(s * 10.0) % 2 == 0 else Color("c89a2e")
				var d := Vector2(cos(q["r"]), sin(q["r"])) * 2.6 * s
				l.draw_line(p - d, p + d, Color(col, 0.7 * a), 2.2 * s)
			"petals":
				l.draw_circle(p, 1.5 * s + 0.4, Color(0.97, 0.86, 0.9, 0.7 * a))
			"snow":
				l.draw_circle(p, 1.2 * s + 0.3, Color(1, 1, 1, 0.55 * a))
			"dust":
				l.draw_line(p, p + Vector2(5.0 * s, 0.4), Color(0.78, 0.7, 0.55, 0.28 * a), 1.2)
			_:
				var tw: float = 0.5 + 0.5 * sin(t * 2.0 + float(q["r"]))
				l.draw_circle(p, 1.0 * s + 0.2, Color(1.0, 0.95, 0.6, 0.35 * a * tw))


## Filets de courant sur une case d'eau centrée en `p` (`ph` : phase propre à la case, `ford` : gué, plus calme).
static func paint_flow(l: CanvasItem, p: Vector2, ph: float, t: float, ford: bool) -> void:
	var speed: float = 5.0 if ford else 9.0
	for k in 2:
		var u: float = fposmod(t * speed / 30.0 + ph * 0.16 + float(k) * 0.5, 1.0)
		var x: float = p.x - 16.0 + u * 32.0
		var y: float = p.y - 5.0 + float(k) * 12.0 + sin(ph + float(k)) * 2.0
		var a: float = sin(u * PI) * 0.35
		l.draw_line(Vector2(x, y), Vector2(x + 7.0, y - 0.6), Color(0.9, 0.96, 1.0, a), 1.2)
