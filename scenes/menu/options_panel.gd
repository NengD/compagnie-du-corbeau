class_name OptionsPanel
extends RefCounted
## Fenêtre d'options en trois sections (Affichage, Son, Jeu). Écrit dans `Settings`.
## Les réglages de fenêtre (mode, taille, écran) sont mis en attente puis appliqués par « Appliquer » :
## un compte à rebours de 10 s rétablit l'ancien affichage si le joueur ne confirme pas.

const SettingsScript := preload("res://autoload/Settings.gd")
const REVERT_SECONDS: int = 10

var _host: Node
var _modal: ModalOverlay
var _mode: int = 0
var _res: Vector2i = Vector2i.ZERO  ## (0, 0) = taille actuelle
var _monitor: int = 0
var _confirm: ModalOverlay


static func open(host: Node) -> ModalOverlay:
	var p := OptionsPanel.new()
	return p._build(host)


func _build(host: Node) -> ModalOverlay:
	_host = host
	_modal = ModalOverlay.open(host, 580)
	_modal.set_meta("options_panel", self)  # garde l'instance en vie tant que la fenêtre existe
	var box: VBoxContainer = _modal.content
	box.add_child(UiKit.title("Options", 34))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 430)
	box.add_child(scroll)
	var body := UiKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_mode = _s().window_mode
	_monitor = DisplayServer.window_get_current_screen()
	_build_display(body)
	_build_sound(body)
	_build_game(body)
	var foot := UiKit.hbox(8)
	var defaults := UiKit.button("Valeurs par défaut", "ghost", true)
	defaults.pressed.connect(func() -> void:
		_s().reset_defaults()
		_modal.close()
		OptionsPanel.open(_host))
	foot.add_child(defaults)
	foot.add_child(UiKit.spacer())
	var close := UiKit.button("Fermer", "pri")
	close.pressed.connect(_modal.close)
	foot.add_child(close)
	box.add_child(foot)
	return _modal


# --- Sections ---

func _section(body: VBoxContainer, text: String) -> void:
	body.add_child(HSeparator.new())
	body.add_child(UiKit.title(text, 24, GameTheme.GOLD))


func _row(body: VBoxContainer, text: String, control: Control) -> void:
	var h := UiKit.hbox(8)
	var l := UiKit.label(text, 15)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	h.add_child(UiKit.spacer())
	h.add_child(control)
	body.add_child(h)


func _option(items: Array, selected: int, on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for it in items:
		o.add_item(str(it))
	o.select(clampi(selected, 0, maxi(0, items.size() - 1)))
	o.item_selected.connect(on_pick)
	return o


func _check(body: VBoxContainer, text: String, on: bool, on_toggle: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = on
	c.toggled.connect(on_toggle)
	body.add_child(c)


func _build_display(body: VBoxContainer) -> void:
	body.add_child(UiKit.title("Affichage", 24, GameTheme.GOLD))
	_row(body, "Mode de la fenêtre", _option(SettingsScript.WINDOW_MODES, _mode, func(i: int) -> void: _mode = i))
	# Résolutions : celles qui tiennent dans l'écran ; « Taille actuelle » en tête.
	var scr: int = DisplayServer.window_get_current_screen()
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(scr).size
	var cur: Vector2i = DisplayServer.window_get_size()
	var list: Array = SettingsScript.resolution_list(usable) if usable.x > 0 else SettingsScript.RESOLUTIONS.duplicate()
	var names: Array = ["Taille actuelle (%d×%d)" % [cur.x, cur.y]]
	for r in list:
		names.append("%d×%d" % [r.x, r.y])
	_row(body, "Taille de la fenêtre", _option(names, 0, func(i: int) -> void:
		_res = Vector2i.ZERO if i == 0 else list[i - 1]))
	var n: int = DisplayServer.get_screen_count()
	if n > 1:
		var screens: Array = []
		for i in n:
			var s: Vector2i = DisplayServer.screen_get_size(i)
			screens.append("Écran %d (%d×%d)" % [i + 1, s.x, s.y])
		_row(body, "Écran", _option(screens, _monitor, func(i: int) -> void: _monitor = i))
	var apply := UiKit.button("Appliquer", "pri", true)
	apply.size_flags_horizontal = Control.SIZE_SHRINK_END
	apply.pressed.connect(_apply_display)
	body.add_child(apply)
	body.add_child(_scale_row())
	_row(body, "Synchronisation verticale", _option(SettingsScript.VSYNC_MODES, _s().vsync, func(i: int) -> void: _s().set_value("vsync", i)))
	var fps_names: Array = []
	for f in SettingsScript.FPS_LIMITS:
		fps_names.append("Illimité" if int(f) == 0 else "%d i/s" % int(f))
	_row(body, "Limite d'images par seconde", _option(fps_names, _s().fps_limit, func(i: int) -> void: _s().set_value("fps_limit", i)))
	_row(body, "Anticrénelage (MSAA 2D)", _option(SettingsScript.MSAA_MODES, _s().msaa, func(i: int) -> void: _s().set_value("msaa", i)))


func _scale_row() -> Control:
	var h := UiKit.hbox(10)
	var l := UiKit.label("Échelle de l'interface", 15)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = SettingsScript.UI_SCALE_MIN
	s.max_value = SettingsScript.UI_SCALE_MAX
	s.step = 5
	s.value = _s().ui_scale
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var v := UiKit.label("%d %%" % _s().ui_scale, 14, GameTheme.GOLD, true)
	v.custom_minimum_size = Vector2(50, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	s.value_changed.connect(func(x: float) -> void: v.text = "%d %%" % int(x))
	# Appliqué au relâchement du curseur (évite de reconstruire l'interface pendant le glissement).
	s.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			_s().set_value("ui_scale", int(s.value)))
	return h


func _build_sound(body: VBoxContainer) -> void:
	_section(body, "Son")
	for row in [["Volume général", "master_volume"], ["Musique", "music_volume"], ["Effets sonores", "sfx_volume"]]:
		body.add_child(_slider_row(str(row[0]), str(row[1])))


func _build_game(body: VBoxContainer) -> void:
	_section(body, "Jeu")
	var speeds: Array = []
	for s in SettingsScript.BATTLE_SPEEDS:
		speeds.append(str(s["n"]))
	_row(body, "Animations de bataille", _option(speeds, _s().battle_speed, func(i: int) -> void: _s().set_value("battle_speed", i)))
	var sizes: Array = []
	for s in SettingsScript.TEXT_SIZES:
		sizes.append(str(s["n"]))
	_row(body, "Taille du texte (nouveaux écrans)", _option(sizes, _s().text_size, func(i: int) -> void: _s().set_value("text_size", i)))
	_check(body, "Tremblement d'écran", _s().screen_shake, func(on: bool) -> void: _s().set_value("screen_shake", on))
	_check(body, "Afficher en permanence les chances de toucher", _s().show_hit_pct, func(on: bool) -> void: _s().set_value("show_hit_pct", on))
	_check(body, "Confirmer « Fin du tour » s'il reste des PA", _s().confirm_end_turn, func(on: bool) -> void: _s().set_value("confirm_end_turn", on))
	_check(body, "Passer l'écran de lancement", _s().skip_splash, func(on: bool) -> void: _s().set_value("skip_splash", on))
	var tuto := UiKit.button("Revoir le tutoriel", "ghost", true)
	tuto.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tuto.pressed.connect(func() -> void:
		Tutorial.start()
		_modal.close())
	body.add_child(tuto)


func _slider_row(text: String, key: String) -> Control:
	var h := UiKit.hbox(10)
	var l := UiKit.label(text, 15)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(_s().get(key))
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
		_s().set_value(key, x))
	return h


# --- Application de la fenêtre avec retour automatique ---

func _apply_display() -> void:
	var before: Dictionary = _s().display_snapshot()
	var values: Dictionary = {"window_mode": _mode}
	var center: bool = false
	if _res != Vector2i.ZERO:
		values["window_w"] = _res.x
		values["window_h"] = _res.y
		center = true
	if DisplayServer.get_screen_count() > 1 and _monitor != DisplayServer.window_get_current_screen():
		values["monitor"] = _monitor
		center = true
	_s().apply_display(values, center)
	if values["window_mode"] != before["window_mode"] or center:
		_ask_keep(before)


func _ask_keep(before: Dictionary) -> void:
	if is_instance_valid(_confirm):
		_confirm.close()
	_confirm = ModalOverlay.open(_host, 420)
	var box: VBoxContainer = _confirm.content
	box.add_child(UiKit.title("Garder cet affichage ?", 28))
	var info := UiKit.para("")
	box.add_child(info)
	var left: Array = [REVERT_SECONDS]
	info.text = "Retour à l'affichage précédent dans %d s." % left[0]
	var row := UiKit.hbox(8)
	var keep := UiKit.button("Garder", "pri")
	var undo := UiKit.button("Annuler", "ghost")
	row.add_child(keep)
	row.add_child(undo)
	box.add_child(row)
	var timer := Timer.new()
	timer.wait_time = 1.0
	box.add_child(timer)
	var revert := func() -> void:
		_s().apply_display(before)
		if is_instance_valid(_confirm):
			_confirm.close()
	keep.pressed.connect(func() -> void: _confirm.close())
	undo.pressed.connect(revert)
	timer.timeout.connect(func() -> void:
		left[0] -= 1
		if left[0] <= 0:
			revert.call()
		else:
			info.text = "Retour à l'affichage précédent dans %d s." % left[0])
	timer.autostart = true


## L'autoload Settings, retrouvé par son chemin (le script reste chargeable dans les tests `-s`).
func _s() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/Settings")
