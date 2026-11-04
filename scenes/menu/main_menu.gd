class_name MainMenu
extends Control
## Menu principal : Continuer, Nouvelle partie, Charger, Options, Quitter.
## N'agit pas lui-même : il émet `action` ("continue", "new", "load", "options", "quit") et main.gd décide.

signal action(what: String)

var _confirm_new: bool = false
var _box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = UiKit.vbox(10)
	center.add_child(_box)
	_rebuild()


func _rebuild() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size = Vector2(620, 0)
	title.add_theme_font_override("normal_font", GameTheme.title_font())
	title.add_theme_font_size_override("normal_font_size", 76)
	title.text = "[center]Compagnie du [color=#b03a2e]Corbeau[/color][/center]"
	_box.add_child(title)
	var sub := UiKit.sub("Mercenaires, contrats et mort permanente.", 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(sub)
	_box.add_child(_gap(18))
	var info: Dictionary = Game.slot_info(0)
	var cont := _menu_button("Continuer" if info.is_empty() else "Continuer — jour %d, %d couronnes, %d hommes" % [info["day"], info["gold"], info["men"]], "pri")
	cont.disabled = info.is_empty()
	cont.pressed.connect(func() -> void: action.emit("continue"))
	_box.add_child(cont)
	if _confirm_new:
		var warn := UiKit.sub("La sauvegarde automatique sera écrasée.", 14)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(warn)
		var yes := _menu_button("Oui, nouvelle partie", "pri")
		yes.pressed.connect(func() -> void:
			_confirm_new = false
			action.emit("new"))
		_box.add_child(yes)
		var no := _menu_button("Annuler")
		no.pressed.connect(func() -> void:
			_confirm_new = false
			_rebuild())
		_box.add_child(no)
	else:
		var nw := _menu_button("Nouvelle partie")
		nw.pressed.connect(func() -> void:
			if info.is_empty():
				action.emit("new")
			else:
				_confirm_new = true
				_rebuild())
		_box.add_child(nw)
		var ld := _menu_button("Charger")
		ld.pressed.connect(func() -> void: action.emit("load"))
		_box.add_child(ld)
		var op := _menu_button("Options")
		op.pressed.connect(func() -> void: action.emit("options"))
		_box.add_child(op)
		var q := _menu_button("Quitter", "ghost")
		q.pressed.connect(func() -> void: action.emit("quit"))
		_box.add_child(q)


## À rappeler quand une sauvegarde a changé (retour d'un écran Charger).
func refresh() -> void:
	_rebuild()


func _menu_button(text: String, kind: String = "") -> Button:
	var b := UiKit.button(text, kind)
	b.custom_minimum_size = Vector2(420, 46)
	b.add_theme_font_size_override("font_size", 18)
	return b


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
