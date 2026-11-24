class_name UnitView
extends Node2D
## Figurine posée sur le plateau : ombre, socle de camp, anneau de l'unité active, barres armure/PV, pastille de moral.

const OL := Color("17110c")
const BASE_COLORS := {"p": Color("8fb0d0"), "e": Color("d9705f")}

var unit: Unit
var figure: Figure
var is_current: bool = false
var _t: float = 0.0
var _phase: float = 0.0  ## déphasage de la respiration, propre à l'unité
var _off: Vector2 = Vector2.ZERO  ## décalage de la figurine (élan, recul)
var _flash: float = 0.0  ## 0..1, intensité du flash rouge
var _fading: bool = false
var _walk: float = 0.0  ## 0..1 : avancement du pas en cours (balancement)
var _walk_amp: float = 1.0  ## 1 = marche, ~1.7 = course (fuite)
var _step_dir: float = 1.0  ## alterne à chaque pas : l'inclinaison bascule d'un côté à l'autre
var _squash: float = 0.0  ## 0..0.08 : écrasement vertical du coup d'expert
var _fall: float = 0.0  ## 0..1 : chute de la figurine qui meurt
var _arrows: Array[float] = []  ## angles des flèches plantées dans la figurine
var _lean: float = 0.0  ## -0.3..0.3 : inclinaison de la pose (levée en arrière < 0, frappe vers l'avant > 0), dans le sens du regard
var _kneel: float = 0.0  ## 0..1 : affaissement du genou à la mort (la figurine descend de quelques pixels)
var _ws: float = 1.0  ## largeur du socle et de l'ombre (montures : plus large)
var _mounted: bool = false  ## cavalier (monture en calque ou cavalier de loup)


func setup(u: Unit) -> UnitView:
	unit = u
	_phase = float(u.id % 17) * 0.7
	figure = Figure.new().setup(u)
	_mounted = figure.mounted or u.sprite.begins_with("wolf_rider")
	_ws = 1.3 if _mounted else 1.0
	add_child(figure)
	set_process(true)
	refresh()
	return self


## Flèche ou carreau planté dans la figurine (angle de tir ; 4 au plus, les plus anciennes disparaissent).
func add_arrow(angle: float) -> void:
	_arrows.append(angle)
	while _arrows.size() > 4:
		_arrows.remove_at(0)
	queue_redraw()


func clear_arrows() -> void:
	if not _arrows.is_empty():
		_arrows.clear()
		queue_redraw()


func set_current(on: bool) -> void:
	is_current = on
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if is_current:
		queue_redraw()
	_apply_pose()


## Vitesse des animations de BattleScreen (0 = sans délai). Accès dynamique : battle.gd dépend de l'autoload Game,
## qu'un script `-s` ne peut pas compiler.
static func _speed() -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("Game"):
		return 0.0
	var bs: Variant = load("res://scenes/battle/battle.gd")
	if bs is GDScript and (bs as GDScript).can_instantiate():
		return float(bs.speed)
	return 0.0  # battle.gd ne compile pas (script `-s` sans autoloads) : pas d'animation


## Respiration idle (étirement vertical depuis les pieds) + décalage d'animation + flash de coup.
func _apply_pose() -> void:
	var sx: float = -1.0 if unit.side == "e" else 1.0
	var sh: Vector2 = figure.shape
	var breath: float = 0.012
	var sway: float = 0.0
	if Quality.value("map_anim"):
		# respiration en deux temps (inspiration lente + petit à-coup), plus rapide quand l'homme est blessé ; léger transfert du poids d'un pied à l'autre
		var rate: float = 1.0 + (0.45 if unit.hp < unit.hp_max * 0.4 else 0.0)
		breath += (sin(_t * 1.7 * rate + _phase) * 0.75 + sin(_t * 3.4 * rate + _phase * 1.7) * 0.25) * 0.011
		sway = sin(_t * 0.9 + _phase * 2.3) * 0.006
	var sy: float = 1.0 + breath - _squash
	var k: float = figure.base_scale
	figure.scale = Vector2(sx * k * sh.x * (1.0 + sway), sy * k * sh.y)
	# balancement de marche : rebond vertical + légère inclinaison (plus marquée et penchée vers l'avant en course) ;
	# une monture a un rebond plus doux et une bascule plus ample, jamais au galop
	var bob: float = sin(_walk * PI) * (2.4 if _mounted else 3.2) * _walk_amp
	var tilt: float = sin(_walk * PI) * (0.1 if _mounted else 0.06) * _step_dir * _walk_amp
	if _walk_amp > 1.0:
		tilt += sin(_walk * PI) * 0.05 * -sx
	# pose d'attaque (levée / frappe) et chute : bascule en arrière autour des pieds et s'affaisse
	tilt += sx * _lean
	tilt += -sx * _fall * (PI * 0.5)
	figure.rotation = tilt
	figure.position = _off + Vector2(0.0, 10.0 * (1.0 - sy * k * sh.y) - bob + _fall * 4.0 + _kneel * 5.0)
	figure.modulate = Color(1.0, 1.0 - 0.7 * _flash, 1.0 - 0.7 * _flash)


## Resynchronise l'apparence avec l'état de l'unité (PV, mur de boucliers, fuite, mort).
func refresh() -> void:
	if not unit.is_live() and visible and not _fading and _speed() > 0.0 and is_inside_tree():
		_fade_out()
		return
	if _fading:
		return
	visible = unit.is_live()
	modulate.a = 0.65 if unit.morale == 0 else 1.0
	figure.refresh()
	queue_redraw()


func _fade_out() -> void:
	_fading = true
	var sp: float = _speed()
	var tw: Tween = create_tween()
	var back: float = -1.0 if unit.side == "p" else 1.0
	if Quality.value("map_anim"):
		# chute en trois temps : le genou cède, le corps bascule, impact au sol avec un petit rebond et de la poussière
		tw.tween_property(self, "_kneel", 1.0, 0.09 * sp).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "_lean", 0.14, 0.09 * sp)
		tw.parallel().tween_property(self, "_off", Vector2(back * 1.5, 1.0), 0.09 * sp)
		tw.tween_property(self, "_fall", 1.0, 0.22 * sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "_lean", 0.0, 0.22 * sp)
		tw.parallel().tween_property(self, "_kneel", 0.4, 0.22 * sp)
		tw.parallel().tween_property(self, "_off", Vector2(back * 4.5, 3.0), 0.22 * sp)
		tw.tween_callback(_thud)
		tw.tween_property(self, "_fall", 0.94, 0.035 * sp).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "_fall", 1.0, 0.035 * sp).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(self, "_fall", 1.0, 0.38 * sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "_off", Vector2(back * 4.0, 3.0), 0.38 * sp)
	tw.tween_interval(0.35 * sp)  # le corps reste au sol un instant
	tw.tween_property(self, "modulate:a", 0.0, 0.3 * sp)
	await tw.finished
	_fading = false
	_fall = 0.0
	_kneel = 0.0
	_lean = 0.0
	_off = Vector2.ZERO
	visible = unit.is_live()
	modulate.a = 0.65 if unit.morale == 0 else 1.0
	queue_redraw()


## Impact du corps au sol : nuage de poussière (sans effet si les particules sont coupées).
func _thud() -> void:
	var b: Node = get_parent()
	if b != null and b.get("fx") is BattleFx:
		(b.get("fx") as BattleFx).thud(position)


## Un pas jusqu'à `px` : glissement + balancement ; `run` = course (fuite), plus ample.
func move_to(px: Vector2, duration: float, run: bool = false) -> void:
	_walk_amp = 1.7 if run else 1.0
	_step_dir = -_step_dir
	_walk = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "position", px, duration)
	tw.tween_property(self, "_walk", 1.0, duration)
	await tw.finished
	_walk = 0.0
	if _speed() > 0.0 and Quality.value("map_anim"):  # fin de pas nette : petit tassement à l'arrivée
		var land: Tween = create_tween()
		land.tween_property(self, "_squash", 0.03, 0.03 * _speed())
		land.tween_property(self, "_squash", 0.0, 0.07 * _speed())


## Élan vers la cible puis retour (aucune attente si _speed() vaut 0). `kind` (voir AttackAnims.kind_for) choisit la pose :
## levée puis frappe (smash, slash), estoc rapide (thrust), tension de l'arme de tir (arrow, bolt, javelin), bond (claws), coup de bouclier (bash).
## Sans `kind`, ou quand les animations d'ornement sont coupées (Quality map_anim), l'élan simple d'origine.
func lunge(toward: Vector2, kind: String = "") -> void:
	var sp: float = _speed()
	if sp <= 0.0:
		return
	var dir: Vector2 = (toward - position).normalized() if toward != position else Vector2.RIGHT
	var tw: Tween = create_tween()
	if kind == "" or not Quality.value("map_anim"):
		tw.tween_property(self, "_off", dir * 9.0, 0.09 * sp).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "_off", Vector2.ZERO, 0.16 * sp).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		return
	var p: Dictionary = POSES.get(kind, POSES["slash"])
	var up := Vector2(0.0, float(p["lift"]))
	# 1) préparation (levée, recul, tension), 2) frappe, 3) retour
	tw.tween_property(self, "_off", -dir * float(p["back"]) + up, float(p["t1"]) * sp).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_lean", float(p["lean1"]), float(p["t1"]) * sp).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_off", dir * float(p["reach"]), float(p["t2"]) * sp).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "_lean", float(p["lean2"]), float(p["t2"]) * sp).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_off", Vector2.ZERO, float(p["t3"]) * sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_lean", 0.0, float(p["t3"]) * sp).set_ease(Tween.EASE_OUT)
	await tw.finished


## Poses d'attaque : recul (back), levée en pixels (lift, négatif = vers le haut), portée (reach), inclinaisons de préparation et de frappe, durées (en secondes à vitesse 1).
const POSES: Dictionary = {
	"smash": {"back": 4.0, "lift": -4.0, "reach": 11.0, "lean1": -0.17, "lean2": 0.2, "t1": 0.09, "t2": 0.05, "t3": 0.15},
	"slash": {"back": 3.0, "lift": -2.0, "reach": 10.0, "lean1": -0.1, "lean2": 0.15, "t1": 0.065, "t2": 0.045, "t3": 0.14},
	"thrust": {"back": 3.0, "lift": 0.0, "reach": 13.0, "lean1": -0.04, "lean2": 0.06, "t1": 0.035, "t2": 0.04, "t3": 0.14},
	"claws": {"back": 2.0, "lift": 1.0, "reach": 12.0, "lean1": -0.06, "lean2": 0.12, "t1": 0.04, "t2": 0.045, "t3": 0.14},
	"bash": {"back": 2.5, "lift": 0.0, "reach": 12.0, "lean1": -0.06, "lean2": 0.1, "t1": 0.04, "t2": 0.045, "t3": 0.15},
	"arrow": {"back": 2.5, "lift": 0.0, "reach": 1.5, "lean1": -0.08, "lean2": 0.03, "t1": 0.1, "t2": 0.03, "t3": 0.14},
	"bolt": {"back": 1.5, "lift": 0.0, "reach": 1.0, "lean1": -0.04, "lean2": 0.02, "t1": 0.08, "t2": 0.025, "t3": 0.12},
	"javelin": {"back": 4.0, "lift": -2.0, "reach": 5.0, "lean1": -0.14, "lean2": 0.1, "t1": 0.09, "t2": 0.04, "t3": 0.14},
}


## Délai entre le début de la pose et l'impact (ou le départ du projectile), à vitesse 1 : la pose joue sa préparation et sa frappe d'abord.
static func impact_delay(kind: String) -> float:
	if not Quality.value("map_anim") or not POSES.has(kind):
		return 0.09 if not AttackAnims.is_projectile(kind) else 0.0
	var p: Dictionary = POSES[kind]
	return float(p["t1"]) + float(p["t2"]) * (0.4 if AttackAnims.is_projectile(kind) else 1.0)


## Parade ou esquive d'un coup raté : le bouclier se projette vers l'attaquant, sinon l'homme se rejette en arrière (aucune attente ; rien à vitesse 0).
func parry(from_dir: Vector2) -> void:
	var sp: float = _speed()
	if sp <= 0.0 or not Quality.value("map_anim"):
		return
	var d: Vector2 = from_dir.normalized() if from_dir != Vector2.ZERO else Vector2.RIGHT
	var tw: Tween = create_tween()
	if unit.shield:
		tw.tween_property(self, "_off", -d * 2.0, 0.03 * sp)
		tw.parallel().tween_property(self, "_squash", 0.035, 0.03 * sp)
		tw.tween_property(self, "_off", Vector2.ZERO, 0.14 * sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "_squash", 0.0, 0.14 * sp)
	else:
		tw.tween_property(self, "_off", -d * 6.0 + Vector2(0.0, -1.5), 0.05 * sp).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "_lean", -0.1, 0.05 * sp)
		tw.tween_property(self, "_off", Vector2.ZERO, 0.15 * sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "_lean", 0.0, 0.15 * sp)


## Léger écrasement de la figurine pendant un coup d'expert (aucune attente ; rien si _speed() vaut 0).
func squash() -> void:
	if _speed() <= 0.0:
		return
	var tw: Tween = create_tween()
	tw.tween_property(self, "_squash", 0.08, 0.07 * _speed())
	tw.tween_property(self, "_squash", 0.0, 0.14 * _speed())


## Recul et flash rouge quand l'unité est touchée.
func hit_flash() -> void:
	if _speed() <= 0.0:
		return
	var back := Vector2(-4.0 if unit.side == "p" else 4.0, 0.0)
	if GameTheme.reduce_motion:  # animations réduites : pas de recul, flash très atténué
		back = Vector2.ZERO
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "_flash", 0.3 if GameTheme.reduce_motion else 1.0, 0.04 * _speed())
	tw.tween_property(self, "_off", back, 0.06 * _speed())
	if Quality.value("map_anim"):
		tw.tween_property(self, "_lean", -0.09, 0.05 * _speed())
	await tw.finished
	var tw2: Tween = create_tween().set_parallel(true)
	tw2.tween_property(self, "_flash", 0.0, 0.2 * _speed())
	tw2.tween_property(self, "_off", Vector2.ZERO, 0.2 * _speed()).set_ease(Tween.EASE_OUT)
	tw2.tween_property(self, "_lean", 0.0, 0.2 * _speed()).set_ease(Tween.EASE_OUT)
	await tw2.finished


## Pastille de moral : un rond coloré ; en mode daltonien, une forme par cran (croix, triangles, carré, rond).
func _morale_mark(c: Vector2, m: int) -> void:
	var col: Color = GameTheme.morale_color(m)
	if GameTheme.cb_mode == 0:
		draw_circle(c, 3.6, OL)
		draw_circle(c, 3.0, col)
		return
	var pts := PackedVector2Array()
	match clampi(m, 0, 4):
		0:
			draw_line(c + Vector2(-3.4, -3.4), c + Vector2(3.4, 3.4), OL, 3.6)
			draw_line(c + Vector2(-3.4, 3.4), c + Vector2(3.4, -3.4), OL, 3.6)
			draw_line(c + Vector2(-3.4, -3.4), c + Vector2(3.4, 3.4), col, 2.0)
			draw_line(c + Vector2(-3.4, 3.4), c + Vector2(3.4, -3.4), col, 2.0)
			return
		1:
			pts = PackedVector2Array([c + Vector2(-4, -3), c + Vector2(4, -3), c + Vector2(0, 4)])
		2:
			pts = PackedVector2Array([c + Vector2(-3, -3), c + Vector2(3, -3), c + Vector2(3, 3), c + Vector2(-3, 3)])
		3:
			draw_circle(c, 4.0, OL)
			draw_circle(c, 3.2, col)
			return
		_:
			pts = PackedVector2Array([c + Vector2(-4, 3), c + Vector2(4, 3), c + Vector2(0, -4)])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), OL, 1.2)


func _ellipse(center: Vector2, rx: float, ry: float) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))


## Rayon d'un élément du socle (ombre, anneau de camp) : élargi pour les montures.
func _r(v: float) -> float:
	return v * _ws


func _draw() -> void:
	# ombre douce en trois épaisseurs, puis socle coloré par camp
	var sh: int = int(Quality.value("shadows"))
	if sh >= 2:
		for i in 3:
			_ellipse(Vector2(0, 11), 19.0 - i * 2.5, 6.4 - i * 0.9)
			draw_circle(Vector2.ZERO, _r(19.0 - i * 2.5), Color(0, 0, 0, 0.14 + i * 0.07))
	elif sh == 1:  # ombre simple : une seule ellipse
		_ellipse(Vector2(0, 11), 18.0, 6.0)
		draw_circle(Vector2.ZERO, _r(18.0), Color(0, 0, 0, 0.3))
	_ellipse(Vector2(0, 11), 17, 5.6)
	if GameTheme.cb_mode > 0 and unit.side == "e":  # daltonien : losange pour l'ennemi, rond pour la compagnie
		var rr: float = _r(19.0)
		draw_polyline(PackedVector2Array([Vector2(0, -rr), Vector2(rr, 0), Vector2(0, rr), Vector2(-rr, 0), Vector2(0, -rr)]), Color(GameTheme.side_color("e"), 0.9), 2.2, true)
	else:
		draw_arc(Vector2.ZERO, _r(17.0), 0.0, TAU, 40, Color(GameTheme.side_color(unit.side), 0.75), 1.6, true)
	if Legendary.is_legend(unit):  # bête légendaire : anneau d'or au pied
		draw_arc(Vector2.ZERO, 21, 0.0, TAU, 40, Color(GameTheme.GOLD, 0.95), 2.4, true)
	if is_current:
		var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
		_ellipse(Vector2(0, 11), 24, 8.5)
		draw_circle(Vector2.ZERO, 24, Color(GameTheme.GOLD, 0.10 + 0.08 * pulse))
		_ellipse(Vector2(0, 11), 20, 7)
		draw_circle(Vector2.ZERO, 20, Color(GameTheme.GOLD, 0.12))
		for i in 12:
			var a: float = TAU * i / 12.0 + _t * 1.2
			draw_arc(Vector2.ZERO, 20, a, a + TAU / 12.0 * 0.6, 6, GameTheme.GOLD, 2.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_morale_mark(Vector2(-18, 17), unit.morale)
	if Legendary.is_legend(unit):  # étoile d'or « Légendaire » à côté des barres
		var star := PackedVector2Array()
		for i in 10:
			var r: float = 6.0 if i % 2 == 0 else 2.6
			var a: float = -PI / 2.0 + TAU * i / 10.0
			star.append(Vector2(21.0, 18.0) + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(star, GameTheme.GOLD)
		draw_polyline(star + PackedVector2Array([star[0]]), OL, 1.0)
	var ha: int = unit.head_armor_max()
	var ba: int = unit.body_armor_max()
	var lm: int = Limbs.total_max(unit)  ## bras et jambes : une seule fine barre fusionnée (somme des pièces), seulement si l'homme en porte
	draw_rect(Rect2(-13, 14 if ha > 0 else 15, 28, (10 if ha > 0 else 7) + (2.2 if lm > 0 else 0.0)), Color("120f0c"))
	if ha > 0:
		draw_rect(Rect2(-12, 15, 26.0 * unit.arm_h / ha, 2.5), GameTheme.bar_color("head"))
	if ba > 0:
		draw_rect(Rect2(-12, 18 if ha > 0 else 16, 26.0 * unit.arm_b / ba, 2.5), GameTheme.bar_color("body"))
	for i in _arrows.size():  # flèches plantées, piquées dans le buste
		var base := Vector2(-3.0 + i * 3.0, -18.0 + (i % 2) * 5.0)
		var dir := Vector2.from_angle(_arrows[i] + PI).normalized() * 9.0
		draw_line(base, base + dir, Color("d9c79a"), 1.6)
		draw_line(base + dir, base + dir + dir.rotated(0.5) * 0.4, Color("b04a3a"), 1.3)
		draw_line(base + dir, base + dir + dir.rotated(-0.5) * 0.4, Color("b04a3a"), 1.3)
	var hp_y: float = 21.0 if ha > 0 else (19.0 if ba > 0 else 16.0)
	if lm > 0:
		draw_rect(Rect2(-12, hp_y, 26.0 * float(Limbs.total_cur(unit)) / float(lm), 1.6), Color("8a929a"))
		hp_y += 2.2
	draw_rect(Rect2(-12, hp_y, 26.0 * maxf(0.0, unit.hp) / unit.hp_max, 2.5), GameTheme.bar_color("hp"))
	if not unit.statuses.is_empty():  # pastilles d'état (saignement, poison, brûlure, gel, ordres) sous les barres
		var sids: Array[String] = Statuses.active(unit)
		for i in sids.size():
			var sc := Vector2(-9.0 + 7.5 * i, hp_y + 8.0)
			draw_circle(sc, 3.6, OL)
			draw_circle(sc, 2.7, StatusesData.STATUSES[sids[i]]["color"])
