class_name PortraitView
extends Control
## Portrait : la figurine recadrée sur le buste (même viewBox que le prototype : -21 -46 44 46).

const VIEW := Vector2(44, 46)
const ORIGIN := Vector2(21, 46)

var _unit: Unit
var _holder: Node2D


func _init(u: Unit = null, px: int = 54) -> void:
	custom_minimum_size = Vector2(px, px)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit = u
	_holder = Node2D.new()
	add_child(_holder)
	if u != null:
		_holder.add_child(Figure.new().setup(u))
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var k: float = minf(size.x / VIEW.x, size.y / VIEW.y)
	if k <= 0.0:
		k = custom_minimum_size.x / VIEW.x
	_holder.scale = Vector2.ONE * k
	_holder.position = ORIGIN * k + (size - VIEW * k) * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("2a2620"))
	draw_rect(Rect2(Vector2.ZERO, size), GameTheme.LINE, false, 1.0)
