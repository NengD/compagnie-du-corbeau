class_name ModalOverlay
extends Control
## Fenêtre modale centrée sur fond assombri. `content` reçoit les widgets ; `close()` la détruit.

var content: VBoxContainer
var _layer: CanvasLayer


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


func close() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
