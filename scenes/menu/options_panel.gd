class_name OptionsPanel
extends RefCounted
## Fenêtre d'options : volumes, plein écran, vitesse des animations de bataille. Écrit dans `Settings`.


static func open(host: Node) -> ModalOverlay:
	var modal: ModalOverlay = ModalOverlay.open(host, 460)
	var box: VBoxContainer = modal.content
	box.add_child(UiKit.title("Options", 34))
	for row in [["Volume général", "master_volume"], ["Musique", "music_volume"], ["Effets sonores", "sfx_volume"]]:
		box.add_child(_slider_row(str(row[0]), str(row[1])))
	var fs := CheckButton.new()
	fs.text = "Plein écran"
	fs.focus_mode = Control.FOCUS_NONE
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool) -> void: Settings.set_value("fullscreen", on))
	box.add_child(fs)
	var sp := UiKit.hbox(8)
	sp.add_child(UiKit.label("Animations de bataille", 15))
	sp.add_child(UiKit.spacer())
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	for s in Settings.BATTLE_SPEEDS:
		opt.add_item(str(s["n"]))
	opt.select(Settings.battle_speed)
	opt.item_selected.connect(func(i: int) -> void: Settings.set_value("battle_speed", i))
	sp.add_child(opt)
	box.add_child(sp)
	var tuto := UiKit.button("Revoir le tutoriel", "ghost", true)
	tuto.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tuto.pressed.connect(func() -> void:
		Tutorial.start()
		modal.close())
	box.add_child(tuto)
	var close := UiKit.button("Fermer", "pri")
	close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(modal.close)
	box.add_child(close)
	return modal


static func _slider_row(text: String, key: String) -> Control:
	var h := UiKit.hbox(10)
	var l := UiKit.label(text, 15)
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Settings.get(key))
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var v := UiKit.label("%d %%" % roundi(s.value * 100.0), 14, GameTheme.GOLD, true)
	v.custom_minimum_size = Vector2(50, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = "%d %%" % roundi(x * 100.0)
		Settings.set_value(key, x))
	return h
