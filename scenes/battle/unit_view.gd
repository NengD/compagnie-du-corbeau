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
var _fall: float = 0.0  ## 0..1 : chute de la figurine qui meurt


func setup(u: Unit) -> UnitView:
	unit = u
	_phase = float(u.id % 17) * 0.7
	figure = Figure.new().setup(u)
	add_child(figure)
	set_process(true)
	refresh()
	return self


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
	var breath: float = sin(_t * 2.0 + _phase) * 0.012 + 0.012
	var sy: float = 1.0 + breath
	var k: float = figure.base_scale
	figure.scale = Vector2(sx * k, sy * k)
	# balancement de marche : rebond vertical + légère inclinaison (plus marquée et penchée vers l'avant en course)
	var bob: float = sin(_walk * PI) * 3.2 * _walk_amp
	var tilt: float = sin(_walk * PI) * 0.06 * _step_dir * _walk_amp
	if _walk_amp > 1.0:
		tilt += sin(_walk * PI) * 0.05 * -sx
	# chute : bascule en arrière autour des pieds et s'affaisse
	tilt += -sx * _fall * (PI * 0.5)
	figure.rotation = tilt
	figure.position = _off + Vector2(0.0, 10.0 * (1.0 - sy * k) - bob + _fall * 4.0)
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
	tw.tween_property(self, "_fall", 1.0, 0.38 * sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "_off", Vector2(-4.0 if unit.side == "p" else 4.0, 3.0), 0.38 * sp)
	tw.tween_interval(0.35 * sp)  # le corps reste au sol un instant
	tw.tween_property(self, "modulate:a", 0.0, 0.3 * sp)
	await tw.finished
	_fading = false
	_fall = 0.0
	_off = Vector2.ZERO
	visible = unit.is_live()
	modulate.a = 0.65 if unit.morale == 0 else 1.0
	queue_redraw()


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


## Élan vers la cible puis retour (aucune attente si _speed() vaut 0).
func lunge(toward: Vector2) -> void:
	if _speed() <= 0.0:
		return
	var dir: Vector2 = (toward - position).normalized() if toward != position else Vector2.RIGHT
	var tw: Tween = create_tween()
	tw.tween_property(self, "_off", dir * 9.0, 0.09 * _speed()).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_off", Vector2.ZERO, 0.16 * _speed()).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Recul et flash rouge quand l'unité est touchée.
func hit_flash() -> void:
	if _speed() <= 0.0:
		return
	var back := Vector2(-4.0 if unit.side == "p" else 4.0, 0.0)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "_flash", 1.0, 0.04 * _speed())
	tw.tween_property(self, "_off", back, 0.06 * _speed())
	await tw.finished
	var tw2: Tween = create_tween().set_parallel(true)
	tw2.tween_property(self, "_flash", 0.0, 0.2 * _speed())
	tw2.tween_property(self, "_off", Vector2.ZERO, 0.2 * _speed()).set_ease(Tween.EASE_OUT)
	await tw2.finished


func _ellipse(center: Vector2, rx: float, ry: float) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))


func _draw() -> void:
	# ombre douce en trois épaisseurs, puis socle coloré par camp
	for i in 3:
		_ellipse(Vector2(0, 11), 19.0 - i * 2.5, 6.4 - i * 0.9)
		draw_circle(Vector2.ZERO, 19.0 - i * 2.5, Color(0, 0, 0, 0.14 + i * 0.07))
	_ellipse(Vector2(0, 11), 17, 5.6)
	draw_arc(Vector2.ZERO, 17, 0.0, TAU, 40, Color(BASE_COLORS[unit.side], 0.75), 1.6, true)
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
	draw_circle(Vector2(-18, 17), 3.6, OL)
	draw_circle(Vector2(-18, 17), 3.0, GameTheme.MORALE_COLORS[unit.morale])
	var ha: int = unit.head_armor_max()
	var ba: int = unit.body_armor_max()
	draw_rect(Rect2(-13, 14 if ha > 0 else 15, 28, 10 if ha > 0 else 7), Color("120f0c"))
	if ha > 0:
		draw_rect(Rect2(-12, 15, 26.0 * unit.arm_h / ha, 2.5), Color("cfc8b8"))
	if ba > 0:
		draw_rect(Rect2(-12, 18 if ha > 0 else 16, 26.0 * unit.arm_b / ba, 2.5), GameTheme.STEEL)
	var hp_y: float = 21.0 if ha > 0 else (19.0 if ba > 0 else 16.0)
	draw_rect(Rect2(-12, hp_y, 26.0 * maxf(0.0, unit.hp) / unit.hp_max, 2.5), Color("c4483a"))
