class_name QualityOverlay
extends CanvasLayer
## Nœud autonome ajouté par Settings : compteur d'images par seconde (en haut à droite, si « Afficher les images
## par seconde » est coché) et message unique de réglage automatique de la qualité (premier lancement).

var _fps: Label
var _notice: Label
var _acc: float = 0.0
var _notice_left: float = 0.0


func _ready() -> void:
	layer = 190
	_fps = Label.new()
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps.position = Vector2(-10, 4)
	_fps.add_theme_font_size_override("font_size", 14)
	_fps.add_theme_color_override("font_color", Color("e6dcc0"))
	_fps.add_theme_color_override("font_outline_color", Color("120f0c"))
	_fps.add_theme_constant_override("outline_size", 5)
	_fps.visible = false
	add_child(_fps)
	_notice = Label.new()
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_notice.position = Vector2(0, -28)
	_notice.add_theme_font_size_override("font_size", 16)
	_notice.add_theme_color_override("font_color", Color("e6dcc0"))
	_notice.add_theme_color_override("font_outline_color", Color("120f0c"))
	_notice.add_theme_constant_override("outline_size", 6)
	_notice.visible = false
	add_child(_notice)
	var st: Node = get_node_or_null("/root/Settings")
	if st != null:
		var msg: String = str(st.get("quality_notice"))
		if msg != "":
			show_notice(msg)
			st.set("quality_notice", "")


func show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_left = 8.0


func _process(delta: float) -> void:
	var st: Node = get_node_or_null("/root/Settings")
	var on: bool = st != null and bool(st.get("show_fps"))
	_fps.visible = on
	if on:
		_acc += delta
		if _acc >= 0.5:
			_acc = 0.0
			_fps.text = "%d i/s" % roundi(Engine.get_frames_per_second())
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.modulate.a = clampf(_notice_left, 0.0, 1.0)
		if _notice_left <= 0.0:
			_notice.visible = false
