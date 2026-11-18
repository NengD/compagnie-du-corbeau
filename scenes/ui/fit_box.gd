class_name FitBox
extends ScrollContainer
## Contenu unique qui tient toujours dans la zone disponible : si sa taille minimale dépasse la zone, il est réduit
## uniformément (jamais agrandi), puis centré. Sous `MIN_SCALE`, le texte deviendrait trop petit : l'échelle s'arrête
## là et la zone devient défilante. Quand le contenu tient, rien ne change (échelle 1).
## `fill` : le contenu occupe toute la zone (écran plein cadre) ; sinon il garde sa taille minimale et se centre (fenêtre modale).
## Logique pure : compute_scale().

const MIN_SCALE: float = 0.6

var child: Control
var fill: bool = true
var scale_now: float = 1.0
var _holder: Control
var _pending: bool = false


## Échelle d'ajustement : 1 si le contenu tient, sinon le rapport le plus serré, plancher `min_scale`.
static func compute_scale(content_min: Vector2, avail: Vector2, min_scale: float = MIN_SCALE) -> float:
	var s: float = 1.0
	if content_min.x > 0.0 and avail.x > 0.0:
		s = minf(s, avail.x / content_min.x)
	if content_min.y > 0.0 and avail.y > 0.0:
		s = minf(s, avail.y / content_min.y)
	return clampf(s, min_scale, 1.0) if s < 1.0 else 1.0


## Position du contenu (en pixels de la zone) quand il est centré : jamais négative.
static func centered_pos(holder_size: Vector2, content_size: Vector2, s: float) -> Vector2:
	var p: Vector2 = (holder_size - content_size * s) * 0.5
	return Vector2(maxf(0.0, floorf(p.x)), maxf(0.0, floorf(p.y)))


## Crée une FitBox pleine zone dans `parent` et y place `content`.
static func add_to(parent: Node, content: Control, fill_area: bool = true) -> FitBox:
	var f := FitBox.new()
	f.fill = fill_area
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(f)
	f.set_content(content)
	return f


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # sans EXPAND, un ScrollContainer laisse l'enfant à sa taille minimale
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_holder)
	GameTheme.style_scrollbar(self)
	_holder.resized.connect(_place)
	resized.connect(_queue_refit)


func set_content(c: Control) -> void:
	child = c
	_holder.add_child(c)
	c.minimum_size_changed.connect(_queue_refit)
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_refit()


func _queue_refit() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	_refit.call_deferred()


func _refit() -> void:
	_pending = false
	if child == null or not is_instance_valid(child):
		return
	var cm: Vector2 = child.get_combined_minimum_size()
	scale_now = compute_scale(cm, size)
	_holder.custom_minimum_size = (cm * scale_now).ceil()
	_place()


func _place() -> void:
	if child == null or not is_instance_valid(child):
		return
	var cm: Vector2 = child.get_combined_minimum_size()
	var hs: Vector2 = _holder.size
	child.scale = Vector2(scale_now, scale_now)
	if fill:
		child.position = Vector2.ZERO
		child.size = (hs / scale_now).max(cm)
	else:
		child.size = cm
		child.position = centered_pos(hs, cm, scale_now)
