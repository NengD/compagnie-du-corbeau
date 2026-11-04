class_name AttackAnims
extends RefCounted
## Animations d'attaque différenciées par arme : estoc, taille, écrasement, tir (flèche, carreau, javelot), griffes, coup de bouclier.
## Tout est visuel : le résultat (touché/raté) vient de l'état déjà calculé et ne change que l'issue de l'animation.
## `play` ne fait rien (et n'attend rien) quand BattleScreen.speed vaut 0.

const TABLE: Dictionary = {
	"lance": "thrust", "hallebarde": "thrust", "fourche": "thrust", "u_lance_aigle": "thrust",
	"epee": "slash", "hache": "slash", "u_epee_corbeau": "slash", "u_hache_fendcrane": "slash",
	"gourdin": "smash", "masse": "smash", "fleau": "smash", "u_masse_glas": "smash",
	"arc": "arrow", "u_arc_ronce": "arrow", "arbalete": "bolt", "javelot": "javelin",
	"griffes": "claws", "poings": "bash",
}
const ABILITY_KIND: Dictionary = {"coup_bouclier": "bash"}
const RANGED_KINDS: Array = ["arrow", "bolt", "javelin"]
const CHEST := Vector2(0.0, -14.0)


## Animation choisie pour une arme (et une capacité éventuelle). Inconnu -> « slash ».
static func kind_for(weapon: String, ability: String = "") -> String:
	if ABILITY_KIND.has(ability):
		return str(ABILITY_KIND[ability])
	return str(TABLE.get(weapon, "slash"))


static func is_projectile(kind: String) -> bool:
	return RANGED_KINDS.has(kind)


## Point où finit le projectile : la cible si touché, sinon à côté et derrière (le tir passe à côté).
static func projectile_end(from: Vector2, to: Vector2, hit: bool, salt: int = 0) -> Vector2:
	var dir: Vector2 = (to - from).normalized() if to != from else Vector2.RIGHT
	if hit:
		return to + CHEST
	var side: float = 1.0 if salt % 2 == 0 else -1.0
	return to + CHEST + dir * 34.0 + dir.orthogonal() * side * (16.0 + float(salt % 3) * 4.0)


## Joue l'animation. `await` rend la main au moment de l'impact (le reste de l'effet continue seul).
static func play(board: BoardView, a: Unit, d: Unit, hit: bool, ability: String = "") -> void:
	var sp: float = UnitView._speed()
	if sp <= 0.0 or board == null or not board.is_inside_tree():
		return
	var kind: String = kind_for(a.weapon, ability)
	var pa: Vector2 = board.hex_px(a.hex)
	var pb: Vector2 = board.hex_px(d.hex)
	var av: UnitView = board.view_of(a)
	var dir: Vector2 = (pb - pa).normalized() if pb != pa else Vector2.RIGHT
	if is_projectile(kind):
		var end: Vector2 = projectile_end(pa, pb, hit, a.id)
		await _projectile(board, kind, pa + CHEST, end, sp)
		return
	if av != null:
		av.lunge(pb)
	await board.get_tree().create_timer(0.09 * sp).timeout
	match kind:
		"thrust":
			_thrust(board, pa + CHEST, pb + CHEST, sp)
		"slash":
			_slash(board, pb, dir, sp)
		"smash":
			_smash(board, pb, sp)
		"claws":
			_claws(board, pb, dir, sp)
		"bash":
			_bash(board, pa + dir * 16.0 + CHEST, dir, sp)


static func _line(board: BoardView, width: float, col: Color) -> Line2D:
	var l := Line2D.new()
	l.width = width
	l.default_color = col
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	var c := Curve.new()
	c.add_point(Vector2(0, 0.1))
	c.add_point(Vector2(1, 1.0))
	l.width_curve = c
	board.add_fx(l)
	return l


static func _fade_free(n: CanvasItem, t: float) -> void:
	var tw: Tween = n.create_tween()
	tw.tween_property(n, "modulate:a", 0.0, t)
	tw.tween_callback(n.queue_free)


## Estoc : poussée en avant avec traînée.
static func _thrust(board: BoardView, from: Vector2, to: Vector2, sp: float) -> void:
	var dir: Vector2 = (to - from).normalized()
	var l := _line(board, 4.0, Color("efe6c8"))
	l.points = PackedVector2Array([from + dir * 16.0, from + dir * 16.0])
	var tw: Tween = l.create_tween()
	tw.tween_method(func(k: float) -> void: l.points = PackedVector2Array([from + dir * 16.0, from + dir * 16.0 + (to - from - dir * 16.0) * k]), 0.0, 1.0, 0.09 * sp)
	tw.tween_property(l, "modulate:a", 0.0, 0.2 * sp)
	tw.tween_callback(l.queue_free)


## Taille : arc de lame lumineux autour de la cible.
static func _slash(board: BoardView, center: Vector2, dir: Vector2, sp: float) -> void:
	var l := _line(board, 5.0, Color("fff3c8"))
	var base: float = dir.angle()
	var c := center + CHEST
	var tw: Tween = l.create_tween()
	tw.tween_method(func(k: float) -> void:
		var pts := PackedVector2Array()
		var n: int = 9
		for i in n:
			var f: float = float(i) / (n - 1) * k
			var ang: float = base - 1.2 + f * 2.4 + PI
			pts.append(c + Vector2(cos(ang), sin(ang)) * 19.0)
		l.points = pts, 0.05, 1.0, 0.1 * sp)
	tw.tween_property(l, "modulate:a", 0.0, 0.18 * sp)
	tw.tween_callback(l.queue_free)


## Écrasement : coup de haut en bas puis onde de choc au sol.
static func _smash(board: BoardView, center: Vector2, sp: float) -> void:
	var l := _line(board, 6.0, Color("e8dcc0"))
	var top: Vector2 = center + Vector2(0.0, -48.0)
	var bot: Vector2 = center + Vector2(0.0, 6.0)
	l.points = PackedVector2Array([top, top])
	var tw: Tween = l.create_tween()
	tw.tween_method(func(k: float) -> void: l.points = PackedVector2Array([top, top.lerp(bot, k)]), 0.0, 1.0, 0.07 * sp)
	tw.tween_callback(func() -> void: _ring(board, center + Vector2(0.0, 8.0), 24.0, sp))
	tw.tween_property(l, "modulate:a", 0.0, 0.14 * sp)
	tw.tween_callback(l.queue_free)


static func _ring(board: BoardView, at: Vector2, radius: float, sp: float) -> void:
	var l := Line2D.new()
	l.width = 2.4
	l.default_color = Color(0.92, 0.86, 0.7, 0.8)
	var pts := PackedVector2Array()
	for i in 25:
		var a: float = TAU * i / 24.0
		pts.append(Vector2(cos(a), sin(a) * 0.4) * 10.0)
	l.points = pts
	l.position = at
	board.add_fx(l)
	var tw: Tween = l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE * (radius / 10.0), 0.28 * sp).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.28 * sp)
	tw.chain().tween_callback(l.queue_free)


## Griffes : trois traînées parallèles.
static func _claws(board: BoardView, center: Vector2, dir: Vector2, sp: float) -> void:
	var c: Vector2 = center + CHEST
	for i in 3:
		var off: Vector2 = Vector2(-1.0, 1.0).normalized().orthogonal() * (i - 1) * 6.0
		var l := _line(board, 2.4, Color("f0d8c8"))
		var a: Vector2 = c + off + Vector2(-10.0, -13.0)
		var b: Vector2 = c + off + Vector2(10.0, 13.0)
		l.points = PackedVector2Array([a, a])
		var tw: Tween = l.create_tween()
		tw.tween_interval(0.025 * i * sp)
		tw.tween_method(func(k: float) -> void: l.points = PackedVector2Array([a, a.lerp(b, k)]), 0.0, 1.0, 0.07 * sp)
		tw.tween_property(l, "modulate:a", 0.0, 0.16 * sp)
		tw.tween_callback(l.queue_free)


## Coup de bouclier : onde en demi-cercle poussée vers la cible.
static func _bash(board: BoardView, at: Vector2, dir: Vector2, sp: float) -> void:
	var l := Line2D.new()
	l.width = 4.0
	l.default_color = Color(0.85, 0.82, 0.74, 0.85)
	var pts := PackedVector2Array()
	for i in 9:
		var a: float = -PI * 0.5 + PI * i / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 13.0)
	l.points = pts
	l.rotation = dir.angle()
	l.position = at
	board.add_fx(l)
	var tw: Tween = l.create_tween().set_parallel(true)
	tw.tween_property(l, "position", at + dir * 20.0, 0.14 * sp).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.2 * sp)
	tw.chain().tween_callback(l.queue_free)


## Projectile suivant la ligne de tir : arc de cercle (flèche), droit et rapide (carreau), parabole haute (javelot).
static func _projectile(board: BoardView, kind: String, from: Vector2, to: Vector2, sp: float) -> void:
	var dist: float = from.distance_to(to)
	var arc: float = 0.18 * dist
	var speed: float = 650.0
	var width: float = 2.0
	var col := Color("d9c79a")
	match kind:
		"bolt":
			arc = 0.05 * dist
			speed = 1100.0
			col = Color("c9c2b0")
		"javelin":
			arc = 0.3 * dist
			speed = 420.0
			width = 3.0
			col = Color("b89a6a")
	arc = clampf(arc, 6.0, 46.0)
	var flight: float = clampf(dist / speed, 0.1, 0.7) * sp
	var node := Node2D.new()
	var shaft := Line2D.new()
	shaft.points = PackedVector2Array([Vector2(-9, 0), Vector2(7, 0)])
	shaft.width = width
	shaft.default_color = col
	node.add_child(shaft)
	var tip := Line2D.new()
	tip.points = PackedVector2Array([Vector2(6, 0), Vector2(10, 0)])
	tip.width = width + 1.0
	tip.default_color = Color("8a8f94")
	node.add_child(tip)
	node.position = from
	node.rotation = (to - from).angle()
	board.add_fx(node)
	var tw: Tween = node.create_tween()
	var prev: Vector2 = from
	tw.tween_method(func(k: float) -> void:
		var p: Vector2 = from.lerp(to, k) + Vector2(0.0, -arc * 4.0 * k * (1.0 - k))
		if p != prev:
			node.rotation = (p - prev).angle()
		prev = p
		node.position = p, 0.0, 1.0, flight)
	await tw.finished
	if is_instance_valid(node):
		node.queue_free()
