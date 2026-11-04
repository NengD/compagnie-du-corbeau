class_name BattleFx
extends Node2D
## Effets visuels de bataille (particules dessinées, sans texture) : sang, étincelles, poussière, tremblement.
## À placer dans la couche fx de BoardView. Toutes les positions sont en pixels du plateau.
## Rien ne se produit quand BattleScreen.speed vaut 0 (tests).

const BLOOD := Color("8f2a22")
const DUST := Color("a89a78")

var _shaking: bool = false


static func enabled() -> bool:
	return UnitView._speed() > 0.0


func _burst(pos: Vector2, count: int, life: float, col: Color, v_min: float, v_max: float, size: float, dir: Vector2 = Vector2.ZERO, spread: float = 180.0, gravity: float = 0.0, additive: bool = false) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.direction = dir if dir != Vector2.ZERO else Vector2.UP
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector2(0.0, gravity)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.color = col
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = m
	add_child(p)
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)
	return p


## Impact d'un coup : étincelles si l'armure a encaissé, sang si des PV sont touchés. `dir` va de l'attaquant vers la cible.
func impact(pos: Vector2, armor_hit: bool, hp_hit: bool, dir: Vector2, head: bool = false, blood: Color = BLOOD) -> void:
	if not enabled() or not is_inside_tree():
		return
	var d: Vector2 = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	var at: Vector2 = pos + Vector2(0.0, -14.0)
	if armor_hit:
		_burst(at, 10, 0.35, Color("ffe59a"), 60.0, 150.0, 1.6, d, 70.0, 0.0, true)
		_burst(at, 5, 0.22, Color("ffffff"), 30.0, 70.0, 1.2, Vector2.UP, 120.0, 0.0, true)
	if hp_hit:
		var n: int = 16 if head else 10
		_burst(at, n, 0.55, blood, 50.0, 130.0, 2.4, d, 55.0, 260.0)
		_burst(at, 5, 0.35, blood.darkened(0.25), 20.0, 60.0, 3.2, Vector2.UP, 150.0, 200.0)


## Coup d'une arme lourde : éclat de poussière et gravats au sol.
func heavy_hit(pos: Vector2) -> void:
	if not enabled() or not is_inside_tree():
		return
	_burst(pos + Vector2(0.0, 8.0), 12, 0.7, Color(DUST, 0.6), 12.0, 50.0, 4.5, Vector2.UP, 170.0, -8.0)
	_burst(pos + Vector2(0.0, 4.0), 6, 0.4, Color("6c665a"), 40.0, 90.0, 1.8, Vector2.UP, 150.0, 320.0)


## Éclats de bois (palissade, porte, barricade).
func splinters(pos: Vector2) -> void:
	if not enabled() or not is_inside_tree():
		return
	_burst(pos + Vector2(0.0, -6.0), 9, 0.5, Color("9a7a4a"), 50.0, 120.0, 2.2, Vector2.UP, 160.0, 280.0)


## Chute ou mort : poussière qui se lève du sol.
func thud(pos: Vector2) -> void:
	if not enabled() or not is_inside_tree():
		return
	_burst(pos + Vector2(0.0, 9.0), 8, 0.8, Color(DUST, 0.5), 8.0, 28.0, 4.0, Vector2.UP, 160.0, -6.0)


## Nuage de poussière sous les pieds d'une unité qui se déplace.
func dust(pos: Vector2) -> void:
	if not enabled() or not is_inside_tree():
		return
	_burst(pos + Vector2(0.0, 10.0), 5, 0.5, Color(DUST, 0.55), 6.0, 20.0, 3.0, Vector2.UP, 90.0, -14.0)


## Mort d'un homme : grosse gerbe, poussière et tremblement du plateau.
func death(pos: Vector2, target: Node2D = null, blood: Color = BLOOD) -> void:
	if not enabled() or not is_inside_tree():
		return
	var at: Vector2 = pos + Vector2(0.0, -8.0)
	_burst(at, 22, 0.7, blood, 40.0, 150.0, 2.8, Vector2.UP, 180.0, 300.0)
	_burst(pos + Vector2(0.0, 8.0), 8, 0.7, Color(DUST, 0.5), 10.0, 40.0, 4.0, Vector2.UP, 160.0, -10.0)
	if target != null:
		shake(target, 3.0, 0.22)


## Petit tremblement (le nœud revient à sa position d'origine ; un nouveau tremblement en cours est ignoré).
func shake(target: Node2D, amplitude: float, duration: float) -> void:
	if not enabled() or _shaking or not is_instance_valid(target) or not shake_allowed():
		return
	_shaking = true
	var origin: Vector2 = target.position
	var tw: Tween = create_tween()
	var steps: int = 6
	for i in steps:
		var k: float = 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude * k
		tw.tween_property(target, "position", origin + off, duration / steps)
	tw.tween_property(target, "position", origin, 0.02)
	tw.tween_callback(func() -> void: _shaking = false)


## Réglage « tremblement d'écran » (lu sans identifiant d'autoload : le script se charge aussi dans les tests `-s`).
static func shake_allowed() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var st: Node = null if tree == null else tree.root.get_node_or_null("/root/Settings")
	return st == null or bool(st.get("screen_shake"))
