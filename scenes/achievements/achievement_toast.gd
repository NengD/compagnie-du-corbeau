class_name AchievementToast
extends CanvasLayer
## Bandeau discret en haut de l'écran quand un succès est débloqué (file d'attente, un à la fois).

var _queue: Array[String] = []
var _busy: bool = false
var _panel: PanelContainer
var _title: Label
var _desc: Label


func _init() -> void:
	layer = 90


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "Card"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var h := UiKit.hbox(10)
	h.add_child(UiKit.label("★", 26, GameTheme.GOLD, true))
	var v := UiKit.vbox(0)
	_title = UiKit.label("", 16, GameTheme.GOLD, true)
	_desc = UiKit.sub("", 13, false)
	v.add_child(_title)
	v.add_child(_desc)
	h.add_child(v)
	_panel.add_child(h)
	add_child(_panel)
	if not _queue.is_empty() and not _busy:
		_next()


func show_achievement(id: String) -> void:
	_queue.append(id)
	if _panel != null and not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var d: Dictionary = Achievements.def_of(_queue.pop_front())
	if d.is_empty():
		_next()
		return
	_title.text = "Succès : %s" % d["n"]
	_desc.text = str(d["d"])
	_panel.visible = true
	_panel.reset_size()
	var vw: float = _panel.get_viewport().get_visible_rect().size.x
	_panel.position = Vector2((vw - _panel.size.x) * 0.5, -_panel.size.y - 4.0)
	_panel.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_panel, "position:y", 14.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		_panel.visible = false
		_next())
