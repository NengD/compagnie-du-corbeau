class_name BattleWeather
extends Node2D
## Météo du plateau : tirage graine-stable par biome (pur, testable), teinte lumineuse, pluie/neige en particules,
## voile de brouillard, vent. Particules et dérives coupées quand BattleScreen.speed vaut 0 ou si l'option « Effets météo » est éteinte.

const KINDS: Array = ["clear", "rain", "fog", "snow", "wind"]
## Poids de tirage par biome (les biomes inconnus tirent comme « plain »).
const WEIGHTS: Dictionary = {
	"plain": {"clear": 45, "rain": 20, "fog": 15, "wind": 20},
	"forest": {"clear": 30, "rain": 30, "fog": 30, "wind": 10},
	"hills": {"clear": 35, "wind": 25, "fog": 15, "snow": 25},
	"water": {"clear": 25, "rain": 30, "fog": 40, "wind": 5},
}
## Teinte multiplicative globale par météo.
const TINTS: Dictionary = {
	"clear": Color(1, 1, 1),
	"rain": Color(0.74, 0.8, 0.88),
	"fog": Color(0.86, 0.9, 0.94),
	"snow": Color(0.88, 0.93, 1.0),
	"wind": Color(1.0, 0.97, 0.92),
}
const NAMES: Dictionary = {"clear": "Ciel dégagé", "rain": "Pluie", "fog": "Brouillard", "snow": "Neige", "wind": "Vent"}

var kind: String = "clear"
var area: Vector2 = Vector2(800, 500)
var _t: float = 0.0
var _tint: Sprite2D
var _fog: Array[Sprite2D] = []
var _parts: CPUParticles2D
var _live: bool = false


## Tirage déterministe : mêmes biome + graine -> même météo.
static func roll(biome: String, seed_v: int) -> String:
	var table: Dictionary = WEIGHTS.get(biome, WEIGHTS["plain"])
	var total: int = 0
	for k in KINDS:
		total += int(table.get(k, 0))
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 2654435761 + 97
	var x: int = r.randi_range(0, total - 1)
	for k in KINDS:
		x -= int(table.get(k, 0))
		if x < 0:
			return k
	return "clear"


static func wind_sway(k: String) -> float:
	return 2.2 if k == "wind" else (0.5 if k == "fog" else 1.0)


static func enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var st: Node = null if tree == null else tree.root.get_node_or_null("/root/Settings")
	if st == null:
		return true
	var v: Variant = st.get("weather_fx")
	return v == null or bool(v)


func setup(p_kind: String, p_area: Vector2) -> BattleWeather:
	kind = p_kind
	area = p_area
	for c in get_children():
		c.queue_free()
	_fog.clear()
	_parts = null
	_tint = null
	_live = false
	if not enabled():
		return self
	var tint: Color = TINTS.get(kind, Color.WHITE)
	if tint != Color.WHITE:
		_tint = Sprite2D.new()
		_tint.texture = _white()
		_tint.centered = false
		_tint.scale = area
		_tint.modulate = tint
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		_tint.material = m
		add_child(_tint)
	_live = UnitView._speed() > 0.0
	if _live:
		match kind:
			"rain":
				_make_particles(240, 0.55, Vector2(0.22, 1.0), 520.0, 640.0, _streak(), Color(0.75, 0.85, 1.0, 0.55), 1.0)
			"snow":
				_make_particles(130, 3.4, Vector2(0.15, 1.0), 38.0, 70.0, _soft(), Color(1, 1, 1, 0.85), 0.6)
			"fog":
				_make_fog()
			"wind":
				_make_particles(14, 2.2, Vector2(1.0, 0.18), 160.0, 260.0, _soft(), Color(0.72, 0.68, 0.42, 0.7), 0.35)
	set_process(_live)
	return self


func _make_particles(count: int, life: float, dir: Vector2, v_min: float, v_max: float, tex: Texture2D, col: Color, size: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = count
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.x * 0.6, 8.0)
	p.position = Vector2(area.x * 0.5, -10.0)
	p.direction = dir
	p.spread = 4.0 if kind == "rain" else 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.2
	p.color = col
	if kind == "rain":
		p.set_particle_flag(CPUParticles2D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	if kind == "wind":
		p.emission_rect_extents = Vector2(8.0, area.y * 0.5)
		p.position = Vector2(-10.0, area.y * 0.5)
	p.emitting = true
	add_child(p)
	_parts = p


func _make_fog() -> void:
	var tex: Texture2D = _soft()
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 7:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * r.randf_range(7.0, 11.0)
		s.position = Vector2(r.randf_range(0.0, area.x), r.randf_range(0.0, area.y))
		s.modulate = Color(0.86, 0.9, 0.93, r.randf_range(0.16, 0.26))
		s.set_meta("v", r.randf_range(4.0, 10.0))
		add_child(s)
		_fog.append(s)


func _process(delta: float) -> void:
	_t += delta
	if kind == "rain" and _tint != null:  # éclaircies lentes
		var k: float = 0.5 + 0.5 * sin(_t * 0.25)
		_tint.modulate = TINTS["rain"].lerp(Color(0.9, 0.93, 0.97), 0.35 * k)
	for s in _fog:
		s.position.x += float(s.get_meta("v")) * delta
		if s.position.x > area.x + 160.0:
			s.position.x = -160.0


## Pluie en cours (les feux s'éteignent). Lisible même sans particules.
func is_raining() -> bool:
	return kind == "rain"


static var _white_tex: Texture2D
static var _soft_tex: Texture2D
static var _streak_tex: Texture2D


static func _white() -> Texture2D:
	if _white_tex == null:
		var im := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(im)
	return _white_tex


static func _soft() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 32
		gt.height = 32
		_soft_tex = gt
	return _soft_tex


static func _streak() -> Texture2D:
	if _streak_tex == null:
		var im := Image.create(2, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 2:
				im.set_pixel(x, y, Color(1, 1, 1, float(y) / 15.0))
		_streak_tex = ImageTexture.create_from_image(im)
	return _streak_tex
