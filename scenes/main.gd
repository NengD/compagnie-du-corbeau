extends Control
## Racine du jeu : menu principal, en-tête de la compagnie, puis bascule entre ville, carte et bataille
## (fondu enchaîné court entre les écrans), menu pause.

const CAMP_SCENE := preload("res://scenes/camp/camp.tscn")
const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const MAP_SCENE := preload("res://scenes/map/map_screen.tscn")
const FADE_TIME: float = 0.12  ## durée de chaque moitié du fondu (≈ 0,25 s au total)

var _header: Control
var _content: VBoxContainer
var _values: Dictionary = {}
var _actions: HBoxContainer
var _confirm_new: bool = false
var _company_open: bool = false
var _in_menu: bool = false
var _menu: MainMenu
var _pause_modal: ModalOverlay
var _fade: ColorRect
var _fade_tween: Tween
var _fading_out: bool = false
var _pending: Callable
var _booted: bool = false


func _ready() -> void:
	theme = GameTheme.get_theme()
	RenderingServer.set_default_clear_color(GameTheme.BG)
	var bg := ColorRect.new()
	bg.color = GameTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := UiKit.vbox(12)
	margin.add_child(root)
	_header = _build_header()
	root.add_child(_header)
	_content = UiKit.vbox(0)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(GameTheme.BG, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.visible = false
	layer.add_child(_fade)
	add_child(Tutorial.new())

	Game.changed.connect(_update_header)
	Game.location_changed.connect(_on_screen_change)
	Game.battle_started.connect(func() -> void: _go(_show_battle.bind(false)))
	Game.battle_finished.connect(_on_screen_change)
	Settings.changed.connect(_apply_battle_speed)
	if Game.roster.is_empty():
		_show_menu()  # lancement : le menu principal décide (Continuer / Nouvelle partie / Charger…)
	else:
		_enter_game()  # une partie est déjà en mémoire (tests, rechargement)
	_booted = true
	_update_header()


# --- Fondu entre écrans ---

## Exécute `fn` (changement d'écran) derrière un fondu enchaîné. Sans délai quand BattleScreen.speed == 0 (tests).
func _go(fn: Callable) -> void:
	if not _booted or BattleScreen.speed <= 0.0 or not is_inside_tree():
		_cancel_fade()
		fn.call()
		return
	_pending = fn
	if _fading_out:
		return
	_fading_out = true
	if _fade_tween != null:
		_fade_tween.kill()
	_fade.visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	_fade_tween.tween_callback(_apply_pending)
	_fade_tween.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	_fade_tween.tween_callback(func() -> void: _fade.visible = false)


func _apply_pending() -> void:
	_fading_out = false
	var f: Callable = _pending
	_pending = Callable()
	if f.is_valid():
		f.call()


func _cancel_fade() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fading_out = false
	_pending = Callable()
	_fade.visible = false
	_fade.color.a = 0.0


func _on_screen_change() -> void:
	_go(_route)


func _apply_battle_speed() -> void:
	if BattleScreen.speed > 0.0:  # 0 = mode test sans délai : on n'y touche pas
		BattleScreen.speed = Settings.battle_speed_factor()


# --- En-tête ---

func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HeaderPanel"
	var row := UiKit.hbox(22)
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size = Vector2(330, 0)
	title.add_theme_font_override("normal_font", GameTheme.title_font())
	title.add_theme_font_size_override("normal_font_size", 34)
	title.text = "Compagnie du [color=#b03a2e]Corbeau[/color]"
	row.add_child(title)
	for key in ["Jour", "Couronnes", "Renom", "Solde/jour"]:
		var pair := UiKit.hbox(5)
		var k := UiKit.label(key.to_upper(), 12, GameTheme.MUTE)
		k.size_flags_vertical = Control.SIZE_SHRINK_END
		pair.add_child(k)
		var v := UiKit.label("0", 17, GameTheme.GOLD, true)
		pair.add_child(v)
		_values[key] = v
		row.add_child(pair)
	row.add_child(UiKit.spacer())
	_actions = UiKit.hbox(6)
	row.add_child(_actions)
	panel.add_child(row)
	return panel


func _update_header() -> void:
	_values["Jour"].text = str(Game.day)
	_values["Couronnes"].text = str(Game.gold)
	_values["Renom"].text = str(Game.renown)
	_values["Solde/jour"].text = str(Game.wages())
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()
	if Game.battle != null or _in_menu:
		return
	if _confirm_new:
		_actions.add_child(UiKit.sub("Tout effacer ?"))
		var yes := UiKit.button("Oui, recommencer", "pri", true)
		yes.pressed.connect(func() -> void:
			_confirm_new = false
			Game.new_game())
		_actions.add_child(yes)
		var no := UiKit.button("Non", "", true)
		no.pressed.connect(func() -> void:
			_confirm_new = false
			_update_header())
		_actions.add_child(no)
	else:
		var b := UiKit.button("Nouvelle partie", "ghost", true)
		b.pressed.connect(func() -> void:
			_confirm_new = true
			_update_header())
		_actions.add_child(b)
		var menu_b := UiKit.button("Menu", "", true)
		menu_b.tooltip_text = "Pause (Échap)"
		menu_b.pressed.connect(_open_pause)
		_actions.add_child(menu_b)


# --- Écrans ---

func _clear_content() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()


## Choisit l'écran selon l'état : ville, carte ou fiche de compagnie (la bataille a son propre signal).
## Synchrone ; sans effet tant que le menu principal est affiché.
func _route() -> void:
	if Game.battle != null or _in_menu:
		return
	_clear_content()
	if Game.ending_pending() and not Game.game_over:
		var ending := EndingScreen.new()
		ending.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ending.action.connect(func(what: String) -> void:
			if what == "free":
				Game.continue_free()
				_go(_route)
			else:
				Game.continue_free()  # la partie reste jouable si on la recharge
				Game.save()
				_go(_show_menu))
		_content.add_child(ending)
	elif Game.game_over or Game.location != "":
		_company_open = false
		_add_camp("town")
		Tutorial.hint("town")
	elif _company_open:
		_add_camp("company")
		Tutorial.hint("company")
	else:
		var m: MapScreen = MAP_SCENE.instantiate()
		_content.add_child(m)
		m.company_requested.connect(func() -> void:
			_company_open = true
			_go(_route))
		Tutorial.hint("map")
	_update_header()


func _add_camp(mode: String) -> void:
	var camp: Camp = CAMP_SCENE.instantiate()
	camp.mode = mode
	if mode == "company":
		camp.closed.connect(func() -> void:
			_company_open = false
			_go(_route))
	_content.add_child(camp)


func _show_battle(resumed: bool) -> void:
	_in_menu = false
	_header.visible = true
	_clear_content()
	_apply_battle_speed()
	var screen: BattleScreen = BATTLE_SCENE.instantiate()
	_content.add_child(screen)
	screen.start(Game.battle, resumed)
	Tutorial.hint("battle")
	_update_header()


## Entre dans la partie en mémoire : reprend la bataille en cours ou affiche ville / carte.
func _enter_game() -> void:
	_in_menu = false
	_header.visible = true
	_company_open = false
	if Game.battle != null:
		_show_battle(true)
	else:
		_route()
	_update_header()


# --- Menu principal ---

func _show_menu() -> void:
	_cancel_pause()
	_in_menu = true
	Tutorial.hide_card()
	Sfx.music("menu")
	_header.visible = false
	_clear_content()
	_menu = MainMenu.new()
	_menu.action.connect(_on_menu_action)
	_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_menu)
	_update_header()


func _on_menu_action(what: String) -> void:
	match what:
		"continue":
			if Game.load_save():
				_go(_enter_game)
		"new":
			Game.new_game()
			if not Settings.tutorial_seen:
				Tutorial.start()  # première partie : le tutoriel accompagne les premiers écrans
			_go(_enter_game)
		"load":
			var p: SlotsPanel = SlotsPanel.open(self, false, func() -> void: _go(_enter_game))
			p.modal.tree_exited.connect(func() -> void:
				if is_instance_valid(_menu) and _menu.is_inside_tree():
					_menu.refresh())
		"options":
			OptionsPanel.open(self)
		"quit":
			get_tree().quit()


# --- Pause (Échap) ---

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		_open_inventory()  # touche I : inventaire (hors menu, bataille et fenêtres ouvertes)
		return
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if _in_menu or Game.battle != null:
		return
	if _pause_modal != null:
		if _count_modals(self) <= 1:
			_cancel_pause()
			get_viewport().set_input_as_handled()
		return
	if _count_modals(self) > 0:
		return
	if Game.location == "" and Game.world != null and not Game.world.path.is_empty():
		return  # la carte s'en sert pour arrêter le voyage
	_open_pause()
	get_viewport().set_input_as_handled()


func _open_inventory() -> void:
	if _in_menu or Game.battle != null or Game.game_over or Game.ending_pending() or _count_modals(self) > 0:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	InventoryScreen.open(self)
	get_viewport().set_input_as_handled()


func _count_modals(n: Node) -> int:
	var total: int = 0
	if n is ModalOverlay:
		total += 1
	for c in n.get_children():
		total += _count_modals(c)
	return total


func _cancel_pause() -> void:
	Sfx.paused(false)
	if _pause_modal != null:
		_pause_modal.close()
		_pause_modal = null


func _open_pause() -> void:
	if _pause_modal != null or _in_menu or Game.battle != null:
		return
	Sfx.paused(true)
	_pause_modal = ModalOverlay.open(self, 360)
	var box: VBoxContainer = _pause_modal.content
	box.add_child(UiKit.title("Pause", 34))
	var resume := UiKit.button("Reprendre", "pri")
	resume.pressed.connect(_cancel_pause)
	box.add_child(resume)
	var saves := UiKit.button("Sauvegarder / Charger")
	saves.pressed.connect(func() -> void: SlotsPanel.open(self, true, func() -> void:
		_cancel_pause()
		_go(_enter_game)))
	box.add_child(saves)
	var opts := UiKit.button("Options")
	opts.pressed.connect(func() -> void: OptionsPanel.open(self))
	box.add_child(opts)
	var quit := UiKit.button("Retour au menu principal", "ghost")
	quit.pressed.connect(func() -> void:
		Game.save()
		_go(_show_menu))
	box.add_child(quit)
