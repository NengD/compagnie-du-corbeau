class_name PortraitView
extends Control
## Portrait : la figurine recadrée serré sur la tête et les épaules (créatures : tout le corps), fond selon la faction,
## visage qui change avec l'humeur (`mood`) : normal, blessé, effrayé, mort, galvanisé. `refresh_mood()` la relit sur l'unité.
## `set_active(true)` met le portrait en valeur (cadre doré) : unité qui joue.

const MOODS: Array[String] = ["normal", "blesse", "effraye", "mort", "galvanise"]
const VIEW_HEAD := Vector2(36, 38)  ## zone visible (unités de la figurine) : x -17..19, y -45..-7
const ORIGIN_HEAD := Vector2(17, 45)
const VIEW_BODY := Vector2(68, 66)  ## créatures : x -34..34, y -50..16
const ORIGIN_BODY := Vector2(34, 50)
const OL := Color("17110c")
const LINEN := Color("e4dcc4")
const BLOOD := Color("a02a20")
## fond par faction : [haut, bas]
const BACKDROPS := {
	"p": [Color("4a3a26"), Color("2a2118")],  ## compagnie : cuir et ocre
	"b": [Color("4a2a24"), Color("241410")],  ## brigands : rouille
	"g": [Color("3c4636"), Color("1c2218")],  ## goules : vert malade
	"u": [Color("2e3a48"), Color("141a22")],  ## morts-vivants : bleu froid
	"o": [Color("3a4a2a"), Color("182210")],  ## orcs : vert sombre
	"m": [Color("46382a"), Color("20180e")],  ## monstres : terre brune
}

var mood: String = "normal"
var active: bool = false

var _unit: Unit
var _holder: Node2D
var _overlay: Node2D
var _frame: Control
var _creature: bool = false


## Humeur déduite de l'unité (logique pure) : mort > effrayé (moral ≤ Hésitant) > blessé (PV < 50 % ou blessure) > galvanisé (Confiant, en forme) > normal.
static func mood_of(u: Unit) -> String:
	if u == null:
		return "normal"
	if u.dead or u.hp <= 0:
		return "mort"
	var ratio: float = float(u.hp) / float(maxi(1, u.hp_max))
	if u.morale <= 2:
		return "effraye"
	if ratio < 0.5 or not u.injuries.is_empty():
		return "blesse"
	if u.morale >= 4 and ratio >= 0.6:
		return "galvanise"
	return "normal"


static func is_creature(u: Unit) -> bool:
	return u != null and (u.sprite != "" or u.faction == "g" or (u.faction == "u" and (u.weapon == "griffes" or u.weapon == "griffesL")))


func _init(u: Unit = null, px: int = 54) -> void:
	custom_minimum_size = Vector2(px, px)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit = u
	_creature = is_creature(u)
	_holder = Node2D.new()
	add_child(_holder)
	_overlay = _Overlay.new()
	_overlay.set("view", self)
	if u != null:
		_holder.add_child(Figure.new().setup(u))
		_holder.add_child(_overlay)
	_frame = _Frame.new()
	_frame.set("view", self)
	add_child(_frame)
	resized.connect(_fit)
	_fit()
	refresh_mood()


func _fit() -> void:
	var v: Vector2 = VIEW_BODY if _creature else VIEW_HEAD
	var o: Vector2 = ORIGIN_BODY if _creature else ORIGIN_HEAD
	var k: float = minf(size.x / v.x, size.y / v.y)
	if k <= 0.0:
		k = custom_minimum_size.x / v.x
	_holder.scale = Vector2.ONE * k
	_holder.position = o * k + (size - v * k) * 0.5
	_frame.size = size


## Relit l'humeur de l'unité et redessine (à appeler quand les PV ou le moral changent).
func refresh_mood() -> void:
	var m: String = mood_of(_unit)
	if _unit != null and _holder.get_child_count() > 0:
		var fig := _holder.get_child(0) as Figure
		if fig != null:
			fig.refresh()
			fig.modulate = Color(0.5, 0.5, 0.56) if m == "mort" else Color.WHITE
	mood = m
	_overlay.queue_redraw()
	_frame.queue_redraw()
	queue_redraw()


func set_active(on: bool) -> void:
	if active != on:
		active = on
		_frame.queue_redraw()
		queue_redraw()


func _faction_key() -> String:
	if _unit == null:
		return "p"
	if _unit.side == "p":
		return "p"
	return _unit.faction if BACKDROPS.has(_unit.faction) else "b"


func _draw() -> void:
	var cols: Array = BACKDROPS[_faction_key()]
	var top: Color = cols[0]
	var bot: Color = cols[1]
	if mood == "mort":
		top = top.lerp(Color(0.2, 0.2, 0.22), 0.6)
		bot = bot.lerp(Color(0.08, 0.08, 0.1), 0.6)
	# dégradé vertical en bandes
	var n: int = 12
	for i in n:
		var t: float = float(i) / float(n - 1)
		draw_rect(Rect2(0, size.y * i / n, size.x, size.y / n + 1.0), top.lerp(bot, t))
	# halo derrière le buste
	var halo: Color = Color("cfa851") if mood == "galvanise" else Color(1, 1, 1)
	var ha: float = 0.22 if mood == "galvanise" else 0.07
	for i in 4:
		draw_circle(Vector2(size.x * 0.52, size.y * 0.5), size.x * (0.46 - i * 0.09), Color(halo, ha * 0.5))


# ---------------------------------------------------------------- traits d'humeur (par-dessus la figurine)
class _Overlay:
	extends Node2D
	var view: PortraitView

	func _draw() -> void:
		if view == null or view._unit == null or PortraitView.is_creature(view._unit):
			return
		var u: Unit = view._unit
		if u.faction == "u":
			if view.mood == "galvanise":
				draw_circle(Vector2(4.4, -28.4), 3.0, Color(0.6, 1.0, 0.9, 0.35))
			return
		var bare: bool = u.head == "none"
		match view.mood:
			"blesse":
				_hurt(u, bare)
			"effraye":
				_scared()
			"mort":
				_dead()
			"galvanise":
				_inspired()

	func _brow(a: Vector2, b: Vector2, w: float = 1.5) -> void:
		draw_line(a, b, Color("231710"), w, true)

	func _hurt(u: Unit, bare: bool) -> void:
		var ratio: float = float(u.hp) / float(maxi(1, u.hp_max))
		draw_circle(Vector2(1.5, -27.0), 7.2, Color(0.86, 0.86, 0.8, 0.2))  # pâleur
		draw_circle(Vector2(5.4, -26.4), 2.6, Color(0.36, 0.2, 0.42, 0.28))  # cerne
		_brow(Vector2(2.8, -31.6), Vector2(7.6, -30.0))  # sourcil douloureux (côté du nez relevé)
		draw_polyline(PackedVector2Array([Vector2(4.4, -21.0), Vector2(5.6, -21.9), Vector2(6.8, -20.9), Vector2(8.0, -21.8)]), Color("3a1a14"), 0.9, true)
		if bare:  # bandeau de lin sur le front
			var band := PackedVector2Array([Vector2(-6.6, -32.0), Vector2(1.0, -34.8), Vector2(8.4, -31.8), Vector2(8.5, -29.4), Vector2(1.0, -32.2), Vector2(-6.6, -29.8)])
			draw_colored_polygon(band, LINEN)
			draw_polyline(band + PackedVector2Array([band[0]]), OL, 0.8, true)
			draw_line(Vector2(-2, -32.6), Vector2(-1.4, -30.6), Color(0.6, 0.55, 0.45, 0.6), 0.5)
			draw_circle(Vector2(4.2, -31.2), 1.2, BLOOD)
		else:  # casque : pansement sur la joue
			var p := PackedVector2Array([Vector2(3.4, -24.6), Vector2(7.4, -25.6), Vector2(8.0, -23.4), Vector2(4.0, -22.4)])
			draw_colored_polygon(p, LINEN)
			draw_polyline(p + PackedVector2Array([p[0]]), OL, 0.7, true)
			draw_circle(Vector2(5.8, -24.0), 0.8, BLOOD)
		if ratio < 0.25:  # filet de sang
			draw_polyline(PackedVector2Array([Vector2(8.2, -22.4), Vector2(8.8, -19.6), Vector2(8.4, -17.4)]), BLOOD, 1.0, true)

	func _scared() -> void:
		draw_circle(Vector2(1.5, -27.0), 7.2, Color(0.78, 0.9, 0.78, 0.22))  # teint verdâtre
		var eye := PackedVector2Array()
		for i in 14:
			var a: float = TAU * i / 14.0
			eye.append(Vector2(5.4 + cos(a) * 2.5, -28.0 + sin(a) * 2.7))
		draw_colored_polygon(eye, Color("f4efe0"))
		draw_polyline(eye + PackedVector2Array([eye[0]]), OL, 0.7, true)
		draw_circle(Vector2(6.4, -27.7), 0.85, Color("1a1410"))
		_brow(Vector2(2.4, -31.4), Vector2(5.0, -33.8), 1.3)  # sourcils haut levés
		_brow(Vector2(5.0, -33.8), Vector2(8.0, -32.2), 1.3)
		var mouth := PackedVector2Array()
		for i in 10:
			var a: float = TAU * i / 10.0
			mouth.append(Vector2(6.6 + cos(a) * 1.3, -21.2 + sin(a) * 1.8))
		draw_colored_polygon(mouth, Color("2a0e0c"))
		draw_polyline(mouth + PackedVector2Array([mouth[0]]), OL, 0.6, true)
		for d in [Vector2(9.4, -32.0), Vector2(-0.6, -31.4), Vector2(10.2, -26.0)]:  # gouttes de sueur
			var drop := PackedVector2Array([d + Vector2(0, -1.7), d + Vector2(1.0, 0.2), d + Vector2(0, 1.0), d + Vector2(-1.0, 0.2)])
			draw_colored_polygon(drop, Color(0.7, 0.88, 1.0, 0.9))
			draw_polyline(drop + PackedVector2Array([drop[0]]), Color(0.2, 0.3, 0.4, 0.8), 0.4, true)

	func _dead() -> void:
		draw_circle(Vector2(1.5, -27.0), 7.6, Color(0.1, 0.1, 0.14, 0.32))
		for c in [Vector2(5.4, -28.0)]:  # œil en croix
			draw_line(c + Vector2(-1.8, -1.8), c + Vector2(1.8, 1.8), Color("14100c"), 1.0, true)
			draw_line(c + Vector2(-1.8, 1.8), c + Vector2(1.8, -1.8), Color("14100c"), 1.0, true)
		draw_line(Vector2(4.4, -21.4), Vector2(8.0, -21.6), Color("231710"), 1.0, true)
		draw_polyline(PackedVector2Array([Vector2(7.6, -21.6), Vector2(8.2, -18.6), Vector2(7.8, -16.4)]), Color(0.5, 0.1, 0.08), 1.0, true)

	func _inspired() -> void:
		draw_circle(Vector2(1.5, -27.0), 7.0, Color(1.0, 0.85, 0.5, 0.12))
		_brow(Vector2(2.8, -30.2), Vector2(7.8, -31.8), 1.5)  # sourcil résolu, incliné vers le nez
		draw_circle(Vector2(5.0, -28.6), 0.45, Color(1, 1, 1, 0.9))  # éclat dans l'œil
		draw_line(Vector2(4.4, -21.4), Vector2(8.2, -22.2), Color("3a1a14"), 1.0, true)  # sourire en coin
		for s in [Vector2(11.5, -36), Vector2(-8, -30), Vector2(12.5, -22)]:  # étincelles
			var r: float = 1.9
			var star := PackedVector2Array([s + Vector2(0, -r), s + Vector2(0.4, -0.4), s + Vector2(r, 0), s + Vector2(0.4, 0.4),
				s + Vector2(0, r), s + Vector2(-0.4, 0.4), s + Vector2(-r, 0), s + Vector2(-0.4, -0.4)])
			draw_colored_polygon(star, Color("f4d878"))


# ---------------------------------------------------------------- cadre
class _Frame:
	extends Control
	var view: PortraitView

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if view == null:
			return
		var r := Rect2(Vector2.ZERO, size)
		# vignette : bords assombris
		for i in 3:
			draw_rect(r.grow(-float(i)), Color(0, 0, 0, 0.16 - i * 0.045), false, 1.0)
		var gold: Color = GameTheme.GOLD
		if view.active:
			draw_rect(r.grow(-1.0), Color(gold, 0.35), false, 4.0)
			draw_rect(r.grow(-1.0), gold, false, 2.0)
			draw_rect(r, OL, false, 1.0)
		else:
			draw_rect(r.grow(-0.5), Color("4a3f31"), false, 1.0)
			draw_rect(r, OL, false, 1.0)
		if size.x >= 40.0:  # rivets d'angle
			var c: Color = gold if view.active else Color("8a7a5c")
			for p in [Vector2(3.5, 3.5), Vector2(size.x - 3.5, 3.5), Vector2(3.5, size.y - 3.5), Vector2(size.x - 3.5, size.y - 3.5)]:
				draw_circle(p, 1.5, OL)
				draw_circle(p, 1.0, c)
