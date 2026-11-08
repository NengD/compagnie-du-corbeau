class_name BattleFx
extends Node2D
## Effets visuels de bataille (particules dessinées, sans texture) : sang, étincelles, poussière, tremblement.
## À placer dans la couche fx de BoardView. Toutes les positions sont en pixels du plateau.
## Rien ne se produit quand BattleScreen.speed vaut 0 (tests).

const BLOOD := Color("8f2a22")
const DUST := Color("a89a78")



static func enabled() -> bool:
	return UnitView._speed() > 0.0


func _burst(pos: Vector2, count: int, life: float, col: Color, v_min: float, v_max: float, size: float, dir: Vector2 = Vector2.ZERO, spread: float = 180.0, gravity: float = 0.0, additive: bool = false) -> CPUParticles2D:
	var amount: int = Quality.scaled_count(count, Quality.particle_factor())
	if amount <= 0:  # densité de particules à 0 %
		return null
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
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
		add_trauma(target, 0.25)


## Tremblement du plateau par « traumatisme » : chaque coup AJOUTE de l'intensité (0..1), qui décroît seule ; l'amplitude suit son carré
## (les petits coups bougent à peine, les gros claquent). Mouvement lissé (sinus), additif : il se compose avec le déplacement du plateau.
const SHAKE_MAX: Vector2 = Vector2(7.0, 5.0)
const TRAUMA_DECAY: float = 1.7

var _trauma: float = 0.0
var _shake_target: Node2D = null
var _applied: Vector2 = Vector2.ZERO  ## décalage actuellement ajouté à la position de la cible
var _last_pos: Vector2 = Vector2.ZERO  ## position posée par nos soins à l'image précédente
var _st: float = 0.0


func _init() -> void:
	set_process(false)


func add_trauma(target: Node2D, amount: float) -> void:
	if amount <= 0.0 or not enabled() or not shake_allowed() or not is_instance_valid(target):
		return
	if _shake_target != target:
		_release_shake()
		_shake_target = target
		_last_pos = target.position
	_trauma = clampf(_trauma + amount, 0.0, 1.0)
	set_process(true)


func _process(delta: float) -> void:
	if _shake_target == null or not is_instance_valid(_shake_target):
		_shake_target = null
		_applied = Vector2.ZERO
		_trauma = 0.0
		set_process(false)
		return
	var base: Vector2 = _shake_target.position - _applied if _shake_target.position == _last_pos else _shake_target.position  # déplacé par ailleurs (pan, zoom) : sa valeur fait foi
	_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
	_st += delta * 34.0
	var k: float = _trauma * _trauma
	var off := Vector2(SHAKE_MAX.x * k * sin(_st * 1.7 + 0.3), SHAKE_MAX.y * k * sin(_st * 2.3))
	_shake_target.position = base + off
	_applied = off
	_last_pos = _shake_target.position
	if _trauma <= 0.0:
		_release_shake()
		set_process(false)


## Rend à la cible sa position sans décalage (si personne d'autre ne l'a déplacée entre-temps).
func _release_shake() -> void:
	if _shake_target != null and is_instance_valid(_shake_target) and _shake_target.position == _last_pos:
		_shake_target.position -= _applied
	_applied = Vector2.ZERO
	_trauma = 0.0
	_shake_target = null


## Arrêt sur image : ralentit le temps un instant pour appuyer un coup. Statique : survit à la libération de la figurine ou de l'effet.
## Le temps est toujours rendu (le dernier appel en cours décide, voir `_stop_id`) et par `_exit_tree` si l'écran disparaît.
static var _stop_id: int = 0


static func hit_stop(tree: SceneTree, duration: float, slow: float = 0.05) -> void:
	if tree == null or duration <= 0.0 or not enabled() or not shake_allowed():
		return
	_stop_id += 1
	var mine: int = _stop_id
	Engine.time_scale = slow
	await tree.create_timer(duration * clampf(UnitView._speed(), 0.3, 1.0), true, false, true).timeout  # ignore le ralenti lui-même
	if mine == _stop_id:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	_stop_id += 1
	Engine.time_scale = 1.0
	_release_shake()


## Réglage « tremblement d'écran » (lu sans identifiant d'autoload : le script se charge aussi dans les tests `-s`).
static func shake_allowed() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var st: Node = null if tree == null else tree.root.get_node_or_null("/root/Settings")
	return st == null or bool(st.get("screen_shake"))
