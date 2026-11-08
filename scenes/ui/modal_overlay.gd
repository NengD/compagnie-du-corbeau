class_name ModalOverlay
extends Control
## Fenêtre modale centrée sur fond assombri. `content` reçoit les widgets ; `close()` la détruit.

static var open_count: int = 0  ## fenêtres modales ouvertes (la caméra de la carte ignore alors le clavier)

var content: VBoxContainer
var _layer: CanvasLayer
var _focus_pending: bool = false


static func open(host: Node, min_width: int = 460) -> ModalOverlay:
	var layer := CanvasLayer.new()
	layer.layer = 50
	host.add_child(layer)
	var m := ModalOverlay.new()
	m._layer = layer
	m.theme = GameTheme.get_theme()
	layer.add_child(m)
	m._build(min_width)
	return m


func _build(min_width: int) -> void:
	open_count += 1
	tree_exiting.connect(func() -> void: open_count = maxi(0, open_count - 1))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ModalPanel"
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	# Focus clavier : à l'ouverture (une fois le contenu ajouté), puis après chaque reconstruction si le joueur navigue au clavier.
	content.child_order_changed.connect(_queue_focus.bind(false))
	_queue_focus(true)


func _queue_focus(initial: bool) -> void:
	if _focus_pending or not is_inside_tree():
		return
	_focus_pending = true
	await get_tree().process_frame
	_focus_pending = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var owner_ctl: Control = get_viewport().gui_get_focus_owner()
	if owner_ctl != null and is_ancestor_of(owner_ctl):
		return
	if initial or UiKit.kb_mode:
		UiKit.focus_first(self)


func close() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
