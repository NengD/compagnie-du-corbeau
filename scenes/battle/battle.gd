class_name BattleScreen
extends VBoxContainer
## Écran de bataille : plateau, panneau latéral, journal, écran de fin.
## Enchaîne les tours (joueur, IA, fuyards) en jouant les animations ; toutes les règles viennent de `BattleState`.

static var speed: float = 1.0  ## 0 = sans délai (tests)

const SIDE_W := 350
const ZOOM_MIN := 1.0
const ZOOM_MAX := 2.5
const ZOOM_STEP := 1.15
const FACTION_COLORS := {"p": Color("8fb0d0"), "b": Color("d9705f"), "g": Color("a99bb5"), "o": Color("8fb45f"), "u": Color("cbc6b0"), "m": Color("c9a25a"), "c": Color("b59a6a")}
const LOG_COLORS := {"hit": "#e9d6b4", "miss": "#9c8f78", "death": "#ff8a78", "mor": "#e0c85e", "sys": "#7fb6d8", "": "#ece1c9"}
const LOG_FILTERS := [["all", "Tout"], ["combat", "Combat"], ["mor", "Moral"], ["sys", "Système"]]
const LOG_SHOWN := 200

class Pips extends Control:
	var ap: int = 0
	var cost: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(9 * 14, 14)

	func _draw() -> void:
		for i in 9:
			var c := Vector2(7 + 14 * i, 7)
			if i < ap - cost:
				draw_circle(c, 5, GameTheme.GOLD)
			elif i < ap:
				draw_circle(c, 5, Color(GameTheme.GOLD, 0.3))
			draw_arc(c, 5, 0, TAU, 16, GameTheme.GOLD, 1.0)

var state: BattleState
var board: BoardView

var _stage: Control
var _title: Label
var _subtitle: Label
var _queue_box: HBoxContainer
var _cur_box: VBoxContainer
var _pips: Pips
var _pips_row: HBoxContainer
var _actions: HFlowContainer
var _hint: Label
var _obj_box: VBoxContainer
var _inspect_box: VBoxContainer
var _log: RichTextLabel

var _busy: bool = true
var _inspect: Unit = null
var _reach: Dictionary = {}
var _hover: Variant = null
var _confirm_retreat: bool = false
var _modal: ModalOverlay
var _alive: bool = true
var _ability: String = ""  ## capacité armée par le joueur : le prochain clic sur un ennemi l'utilise
var _zoom: float = 1.0  ## zoom de la vue (1 = plateau entier)
var _fit_k: float = 1.0  ## échelle qui fait tenir le plateau entier dans la scène
var _panning: bool = false
var _view_btn: Button
var _log_filter: String = "all"  ## filtre du journal (Tout / Combat / Moral / Système), conservé pendant la bataille
var _hot: Array[Button] = []  ## boutons d'action numérotés (touches 1 à 9), dans l'ordre d'affichage
var _help: ModalOverlay


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	var head := UiKit.hbox(14)
	_title = UiKit.title("", 26)
	_subtitle = UiKit.sub("")
	_subtitle.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_title)
	head.add_child(_subtitle)
	add_child(head)
	var main := UiKit.hbox(14)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main)

	var frame := PanelContainer.new()
	frame.theme_type_variation = "Card"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(frame)
	_stage = Control.new()
	_stage.clip_contents = true
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(400, 300)
	_stage.gui_input.connect(_on_stage_input)
	_stage.resized.connect(_fit_board)
	_stage.mouse_exited.connect(_on_mouse_exit)
	frame.add_child(_stage)
	board = BoardView.new()
	_stage.add_child(board)
	_view_btn = UiKit.button("Vue d'ensemble (H)", "ghost", true)
	_view_btn.tooltip_text = "Molette : zoom · bouton du milieu : déplacer · H ou Début : recentrer"
	_view_btn.visible = false
	_view_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_view_btn.position = Vector2(-170, 8)
	_view_btn.pressed.connect(reset_view)
	_stage.add_child(_view_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(SIDE_W, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var side := UiKit.vbox(10)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(side)
	var qs := ScrollContainer.new()
	qs.custom_minimum_size = Vector2(0, 48)
	qs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_queue_box = UiKit.hbox(4)
	qs.add_child(_queue_box)
	side.add_child(qs)
	_cur_box = UiKit.vbox(6)
	side.add_child(_cur_box)
	_pips_row = UiKit.hbox(8)
	_pips_row.add_child(UiKit.sub("PA", 13, false))
	_pips = Pips.new()
	_pips_row.add_child(_pips)
	side.add_child(_pips_row)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 6)
	_actions.add_theme_constant_override("v_separation", 6)
	side.add_child(_actions)
	_hint = UiKit.sub("")
	side.add_child(_hint)
	_obj_box = UiKit.vbox(2)
	side.add_child(_obj_box)
	_inspect_box = UiKit.vbox(6)
	side.add_child(_inspect_box)
	var log_panel := PanelContainer.new()
	log_panel.theme_type_variation = "Card"
	log_panel.custom_minimum_size = Vector2(0, 230)
	var log_box := UiKit.vbox(4)
	log_panel.add_child(log_box)
	var frow := UiKit.hbox(4)
	var fgroup := ButtonGroup.new()
	for f in LOG_FILTERS:
		var fb := UiKit.button(str(f[1]), "", true)
		fb.toggle_mode = true
		fb.button_group = fgroup
		fb.button_pressed = f[0] == _log_filter
		fb.pressed.connect(func() -> void:
			_log_filter = str(f[0])
			_refresh_log())
		frow.add_child(fb)
	frow.add_child(UiKit.spacer())
	var help_b := UiKit.button("?", "ghost", true)
	help_b.tooltip_text = "Raccourcis clavier (? ou F1)"
	help_b.pressed.connect(_open_help)
	frow.add_child(help_b)
	log_box.add_child(frow)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = true
	_log.custom_minimum_size = Vector2(0, 180)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_child(_log)
	side.add_child(log_panel)


func _exit_tree() -> void:
	_alive = false
	if _modal != null:
		_modal.close()


## Lance (ou reprend) la bataille `s`.
func start(s: BattleState, resumed: bool = false) -> void:
	state = s
	board.setup(s)
	_fit_board()
	_title.text = str(s.contract["title"])
	state.logged.connect(func(_t: String, _c: String) -> void: _refresh_log())
	_refresh_log()
	if s.over != "":
		_refresh_all()
		_show_end()
		return
	Sfx.music("battle")
	if not resumed:
		Sfx.play("horn")
	if resumed and s.current != null and s.current.is_live() and s.current.side == "p" and s.current.morale > 0:
		_begin_player_turn(s.current)
		return
	if resumed and s.current != null and s.current.is_live():
		s.queue.push_front(s.current)
		s.current = null
	_run_turns()


func _pause(t: float) -> void:
	if speed <= 0.0:
		return
	await get_tree().create_timer(t * speed).timeout


# --- Enchaînement des tours ---

func _run_turns() -> void:
	while _alive:
		var u: Unit = state.next_turn()
		if u == null:
			_refresh_all()
			_show_end()
			return
		_inspect = null
		_hover = null
		_busy = true
		_reach = {}
		_refresh_all()
		if u.morale == 0:
			await _pause(0.3)
			if not _alive:
				return
			await _flee_turn(u)
			continue
		if u.side == "e":
			await _pause(0.25)
			if not _alive:
				return
			await _ai_turn(u)
			continue
		_begin_player_turn(u)
		return


func _begin_player_turn(u: Unit) -> void:
	_busy = false
	_ability = ""
	_reach = state.reachable(u)
	_confirm_retreat = false
	_refresh_all()
	Game.save()


func _ai_turn(u: Unit) -> void:
	var memo: Dictionary = {}
	while _alive and u.is_live() and state.over == "":
		var a: Dictionary = Ai.next_action(state, u, memo)
		match a["type"]:
			"attack":
				await _attack(u, a["target"])
			"move":
				await _move_along(u, a["path"])
			"shield":
				state.raise_shield(u, false)
				_refresh_all()
				await _pause(0.2)
			"ability":
				await _attack(u, a["target"], false, str(a["id"]))
			"hit_object", "open", "heal", "raise":
				state.execute(u, a)
				_refresh_all()
				await _pause(0.3)
			_:
				break
		if not _alive or state.check_end():
			return


func _flee_turn(u: Unit) -> void:
	if state.leave_if_at_edge(u):
		_refresh_all()
		await _pause(0.25)
		return
	var path: Array[Vector2i] = Ai.flee_path(state, u)
	state.say("%s prend la fuite !" % u.unit_name, "mor")
	if not path.is_empty():
		await _move_along(u, path, true)
	if _alive and u.is_live():
		state.leave_if_at_edge(u)
	_refresh_all()
	await _pause(0.2)


func _attack(a: Unit, d: Unit, free: bool = false, ability: String = "") -> Dictionary:
	var morale_before: Dictionary = {}
	for u in state.units:
		morale_before[u.id] = u.morale
	var res: Dictionary = state.attack(a, d, free, ability)
	await board.attack_anim(a, d, bool(res["hit"]), ability)  # animation propre à l'arme (le résultat est déjà connu)
	await _pause(0.1)
	board.after_attack(a, d, res, ability)  # traces au sol, flèches plantées, poussière
	var dv: UnitView = board.view_of(d)
	if a.is_ranged():
		Sfx.play("bow")
	if not res["hit"]:
		Sfx.play("miss")
	else:
		Sfx.play("hit_armor" if int(res["armor"]) > 0 and int(res["hp"]) <= 0 else "hit_flesh")
		if d.dead:
			Sfx.play("death")
	if res["hit"] and dv != null:
		dv.hit_flash()
		var blood: Color = BattleFx.BLOOD
		if d.faction == "u":
			blood = Color("c8c0a0")
		elif d.faction == "g":
			blood = Color("4a5a2a")
		board.fx.impact(board.hex_px(d.hex), int(res["armor"]) > 0, int(res["hp"]) > 0, board.hex_px(d.hex) - board.hex_px(a.hex), bool(res["head"]), blood)
		if d.dead:
			board.fx.death(board.hex_px(d.hex), board if d.side == "p" else null, blood)
	if not res["hit"]:
		board.float_text(d.hex, "Raté", Color("ddd2bb"))
	else:
		if int(res["armor"]) > 0:
			board.float_text(d.hex, "−%d" % res["armor"], Color("cfd9e4"), -14.0)
		board.float_text(d.hex, ("Tête ! " if res["head"] else "") + "−%d" % res["hp"], Color("ff7a68"), 0.0, 18 if res["head"] else 15)
	if res.has("pushed"):
		board.float_text(d.hex, "Repoussé", Color("ddd2bb"), -28.0)
	if res.get("stunned", false):
		board.float_text(d.hex, "Étourdi", Color("dcc56a"), -28.0)
	if res.get("exposed", false):
		board.float_text(d.hex, "Désarçonné", Color("dcc56a"), -28.0)
	if res.get("shield_broken", false) or res.get("weapon_broke", false):
		board.float_text(d.hex if res.get("shield_broken", false) else a.hex, "Brisé" if res.get("shield_broken", false) else "Ébréché", Color("cfd9e4"), -28.0)
	for u in state.units:
		if u.is_live() and u.morale < int(morale_before[u.id]):
			board.float_text(u.hex, str(Data.MORALE_NAMES[u.morale]), GameTheme.MORALE_COLORS[u.morale], -14.0)
	_refresh_all()
	await _pause(0.3)
	return res


func _move_along(u: Unit, path: Array[Vector2i], run: bool = false) -> void:
	if path.is_empty():
		return
	for f in state.free_attackers(u):
		var r: Dictionary = await _attack(f, u, true)
		if not _alive or u.dead:
			return
		if r["hit"]:
			state.say("%s est retenu." % u.unit_name, "miss")
			return
	for h in path:
		var stop: bool = state.step(u, h)
		Sfx.play("step")
		await board.move_unit(u, h, (0.09 if run else 0.14) * speed, run)
		if not _alive:
			return
		board.refresh_units()
		if stop:
			break
	_refresh_all()


# --- Actions du joueur ---

func _player_move(h: Vector2i) -> void:
	var u: Unit = state.current
	_busy = true
	_hover = null
	_refresh_all()
	state.begin_move(u)  ## mémorise le départ : « Annuler le déplacement » tant qu'aucune action ne le verrouille
	await _move_along(u, Pathfinding.path_to(_reach, h))
	if _alive:
		_after_player_action()


## Annule le dernier déplacement du joueur (PA et fatigue rendus) tant que rien d'aléatoire ne s'est produit depuis.
func _undo_move() -> void:
	var u: Unit = state.current
	if not _player_turn() or u == null or not state.undo_move(u):
		return
	_ability = ""
	_reach = state.reachable(u)
	board.refresh_units()
	_refresh_all()
	Game.save()


func _player_attack(t: Unit) -> void:
	var ab: String = _ability
	_ability = ""
	_busy = true
	_inspect = t
	_refresh_all()
	await _attack(state.current, t, false, ab)
	if _alive:
		_after_player_action()


func _after_player_action() -> void:
	if state.check_end():
		_refresh_all()
		_show_end()
		return
	var u: Unit = state.current
	if u == null or not u.is_live() or u.morale == 0 or not state.can_act(u):
		state.current = null
		_run_turns()
		return
	_begin_player_turn(u)


func _end_turn() -> void:
	if _busy:
		return
	if Settings.confirm_end_turn and BattleScreen.speed > 0.0 and state.current != null and state.current.ap > 0 \
			and _player_turn() and _confirm_modal == null:
		_ask_end_turn()
		return
	state.current = null
	_run_turns()


## Réglage « Confirmer la fin du tour » : il reste des PA, on demande avant de passer.
var _confirm_modal: ModalOverlay


func _ask_end_turn() -> void:
	_confirm_modal = ModalOverlay.open(self, 380)
	var box: VBoxContainer = _confirm_modal.content
	box.add_child(UiKit.title("Finir le tour ?", 28))
	box.add_child(UiKit.para("Il reste %d PA à %s." % [state.current.ap, state.current.unit_name]))
	var row := UiKit.hbox(8)
	var yes := UiKit.button("Finir le tour", "pri")
	var no := UiKit.button("Continuer", "ghost")
	yes.pressed.connect(func() -> void:
		_confirm_modal.close()
		_confirm_modal = null
		state.current.ap = 0  # plus de PA : _end_turn ne redemande pas
		_end_turn())
	no.pressed.connect(func() -> void:
		_confirm_modal.close()
		_confirm_modal = null)
	row.add_child(yes)
	row.add_child(no)
	box.add_child(row)


func _wait_turn() -> void:
	if _busy or state.current == null or state.current.waited:
		return
	state.wait(state.current)
	_run_turns()


func _swap_weapon(slot: int) -> void:
	if _busy or state.current == null or not state.swap_weapon(state.current, slot):
		return
	_ability = ""
	_after_player_action()


func _raise_shield() -> void:
	if _busy:
		return
	state.raise_shield(state.current)
	Sfx.play("shield_wall")
	_after_player_action()


func _retreat() -> void:
	state.end_battle("retreat")
	_refresh_all()
	_show_end()


# --- Entrées ---

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or state == null:
		return
	var ke := event as InputEventKey
	var k: int = ke.keycode
	var handled: bool = true
	if _help != null and is_instance_valid(_help):
		if k == KEY_ESCAPE or k == KEY_QUESTION or k == KEY_F1:
			_help.close()
			_help = null
		else:
			handled = false
	elif _modal != null or _confirm_modal != null or state.over != "":
		handled = false
	elif k == KEY_F1 or k == KEY_QUESTION or ke.unicode == 63:
		_open_help()
	elif k == KEY_H or k == KEY_HOME:
		reset_view()
	elif k == KEY_ESCAPE:
		if _ability != "":
			_ability = ""
			_refresh_all()
		else:
			handled = false
	elif (k == KEY_Z and ke.ctrl_pressed) or k == KEY_BACKSPACE:
		_undo_move()
	elif k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
		_end_turn()
	elif k == KEY_W:
		_wait_turn()
	elif k == KEY_TAB:
		_inspect_next(-1 if ke.shift_pressed else 1)
	else:
		var pk: int = ke.physical_keycode
		var n: int = pk - KEY_1 if pk >= KEY_1 and pk <= KEY_9 else (k - KEY_KP_1 if k >= KEY_KP_1 and k <= KEY_KP_9 else -1)
		if n >= 0 and _player_turn() and n < _hot.size() and is_instance_valid(_hot[n]) and not _hot[n].disabled:
			_hot[n].pressed.emit()
		else:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _open_help() -> void:
	if _help != null and is_instance_valid(_help):
		return
	_help = Shortcuts.open(self, "battle")


## Tab : inspecte l'unité vivante suivante (ou précédente), dans l'ordre d'initiative.
func _inspect_next(dir: int) -> void:
	var order: Array[Unit] = []
	if state.current != null:
		order.append(state.current)
	order.append_array(state.queue)
	var live: Array[Unit] = []
	for u in order:
		if u.is_live():
			live.append(u)
	if live.is_empty():
		return
	var i: int = live.find(_inspect)
	_inspect = live[(i + dir + live.size()) % live.size()] if i >= 0 else live[0 if dir > 0 else live.size() - 1]
	if _inspect == state.current:
		_inspect = null
	_refresh_inspect()


func _board_hex(pos: Vector2) -> Vector2i:
	return board.hex_at((pos - board.position) / board.scale.x)


func _on_mouse_exit() -> void:
	if _hover != null:
		_hover = null
		_refresh_marks()


func _hover_at(pos: Vector2) -> void:
	var h: Vector2i = _board_hex(pos)
	var hv: Variant = h if state.cells.has(h) else null
	var changed: bool = hv != _hover
	_hover = hv
	var t: Unit = state.unit_at(h) if hv != null else null
	if t != null and t != _inspect and t != state.current:
		_inspect = t
		_refresh_inspect()
	if changed:
		_refresh_marks()


func _on_stage_input(event: InputEvent) -> void:
	if state == null:
		return
	# zoom (molette) et déplacement (bouton du milieu) : toujours disponibles
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_zoom_at(event.position, ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
		_stage.accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = event.pressed
		return
	if event is InputEventMouseMotion and _panning:
		board.position += event.relative
		_clamp_view()
		if state.over == "":
			_hover_at(event.position)
		return
	if state.over != "":
		return
	if event is InputEventMouseMotion:
		_hover_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _busy:
			return
		var h: Vector2i = _board_hex(event.position)
		if not state.cells.has(h):
			return
		var cur: Unit = state.current
		var t: Unit = state.unit_at(h)
		if t != null:
			_inspect = t
			if cur != null and cur.side == "p" and t.side != "p" and _can_hit(cur, t):
				_player_attack(t)
				return
			_refresh_inspect()
		elif _reach.has(h):
			_player_move(h)
		elif cur != null and cur.side == "p" and Scenery.kind_at(state.cells, h) != "":
			_player_object(cur, h)


## Clic sur un objet de décor : ouvre la porte voisine (2 PA) ou frappe l'obstacle destructible à portée.
func _player_object(u: Unit, h: Vector2i) -> void:
	var done: bool = false
	if Scenery.can_open(state, u, h):
		done = Scenery.open_door(state, u, h)
	elif Scenery.can_hit_object(state, u, h):
		_busy = true
		var r: Dictionary = Scenery.hit_object(state, u, h)
		done = true
		Sfx.play("hit_flesh" if r["hit"] else "miss")
		_refresh_all()
		await _pause(0.25)
	if done and _alive:
		_after_player_action()


# --- Affichage ---

func _fit_board() -> void:
	if state == null or _stage == null:
		return
	var ws: Vector2 = BoardView.world_size(state.width, state.height)
	var k: float = minf(_stage.size.x / ws.x, _stage.size.y / ws.y)
	if k <= 0.0:
		return
	_fit_k = k
	board.scale = Vector2.ONE * k * _zoom
	board.position = (_stage.size - ws * k * _zoom) * 0.5 if _zoom <= 1.0 else board.position
	_clamp_view()


## Molette : zoom ×1 à ×2,5 autour du point `anchor` (coordonnées du plateau-écran) ; la case sous le curseur reste en place.
func _zoom_at(anchor: Vector2, factor: float) -> void:
	var z: float = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(z, _zoom):
		return
	var world: Vector2 = (anchor - board.position) / board.scale.x
	_zoom = z
	board.scale = Vector2.ONE * _fit_k * _zoom
	board.position = anchor - world * board.scale.x
	_clamp_view()
	_after_view_change(anchor)


## Revient à la vue d'ensemble (zoom ×1, plateau centré).
func reset_view() -> void:
	_zoom = 1.0
	_fit_board()
	_after_view_change(_stage.get_local_mouse_position())


## Garde le plateau dans la fenêtre : centré s'il est plus petit qu'elle, sinon ses bords ne quittent jamais le cadre.
func _clamp_view() -> void:
	var ws: Vector2 = BoardView.world_size(state.width, state.height) * board.scale.x
	var p: Vector2 = board.position
	for axis in 2:
		if ws[axis] <= _stage.size[axis]:
			p[axis] = (_stage.size[axis] - ws[axis]) * 0.5
		else:
			p[axis] = clampf(p[axis], _stage.size[axis] - ws[axis], 0.0)
	board.position = p


func _after_view_change(mouse: Vector2) -> void:
	if _view_btn != null:
		_view_btn.visible = _zoom > 1.001
	if state != null and state.over == "":
		_hover_at(mouse)


func _player_turn() -> bool:
	return state.current != null and state.current.side == "p" and not _busy and state.over == ""


func _refresh_all() -> void:
	var prize: String = " · Prime %d couronnes" % state.contract["pay"] if state.contract.get("kind", "contract") == "contract" else (" · Assaut" if state.contract.get("kind", "") == "assault" else " · Embuscade")
	_subtitle.text = "Manche %d · Danger %d/3%s" % [state.round_no, state.contract["d"], prize]
	if state.battle_type != "pitched":
		_subtitle.text += " · " + str(Data.BATTLE_TYPE_NAMES[state.battle_type])
	_refresh_objectives()
	board.refresh_units()
	_refresh_queue()
	_refresh_current()
	_refresh_actions()
	_refresh_inspect()
	_refresh_marks()
	_refresh_log()


## Panneau des objectifs secondaires (liste cochée).
func _refresh_objectives() -> void:
	if _obj_box == null:
		return
	_clear(_obj_box)
	_obj_box.visible = not state.objectives.is_empty()
	if state.objectives.is_empty():
		return
	_obj_box.add_child(UiKit.sub("Objectifs", 13, false))
	for o in state.objectives:
		var mark: String = "☑" if bool(o["done"]) else ("☒" if bool(o["failed"]) else "☐")
		var b: Dictionary = o["bonus"]
		var gain: String = " (+%d couronnes)" % int(b["gold"]) if int(b["gold"]) > 0 else (" (+%d renom)" % int(b["renown"]) if int(b["renown"]) > 0 else "")
		_obj_box.add_child(UiKit.sub("%s %s%s" % [mark, o["label"], gain], 13))


func _refresh_marks() -> void:
	var cur: Unit = state.current
	var pl: bool = _player_turn()
	var path_set: Dictionary = {}
	var cost_hex: Variant = null
	var cost_text: String = ""
	var targets: Array = []
	var cost: int = 0
	if pl:
		if _hover != null and _reach.has(_hover):
			for k in Pathfinding.path_to(_reach, _hover):
				path_set[k] = true
			cost_hex = _hover
			cost = int(_reach[_hover]["ap"])
			cost_text = "%d PA" % cost
		for f in state.foes_of(cur):
			if _can_hit(cur, f) or Settings.show_hit_pct:
				targets.append({"hex": f.hex, "pct": state.hit_chance(cur, f, _ability)})
	board.set_marks(_reach if pl else {}, path_set, cur.hex if cur != null and state.over == "" else null, cost_hex, cost_text, targets)
	_pips.ap = cur.ap if cur != null else 0
	_pips.cost = cost
	_pips.queue_redraw()


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _refresh_queue() -> void:
	_clear(_queue_box)
	var order: Array[Unit] = []
	if state.current != null:
		order.append(state.current)
	order.append_array(state.queue)
	for u in order:
		if not u.is_live():
			continue
		var p := PanelContainer.new()
		var col: Color = FACTION_COLORS.get(u.faction, Color("b59a6a"))
		var sb := GameTheme.box(Color.TRANSPARENT, _border_color(u == state.current, col), 2, 3, Vector4(0, 0, 0, 0))
		p.add_theme_stylebox_override("panel", sb)
		p.tooltip_text = u.unit_name
		var qpv := PortraitView.new(u, 34)
		qpv.set_active(u == state.current)
		p.add_child(qpv)
		_queue_box.add_child(p)


func _border_color(cond: bool, col: Color) -> Color:
	return GameTheme.GOLD if cond else col


func _unit_block(parent: Node, u: Unit, tag: String) -> void:
	var c := UiKit.card(parent)
	var h := UiKit.hbox(10)
	var upv := PortraitView.new(u, 64)
	upv.set_active(u == state.current)
	h.add_child(upv)
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UiKit.hbox(6)
	var n := UiKit.title(u.unit_name, 20)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	top.add_child(n)
	top.add_child(UiKit.chip(str(Data.MORALE_NAMES[u.morale]), GameTheme.MORALE_COLORS[u.morale]))
	v.add_child(top)
	v.add_child(UiKit.sub("%s · %s%s" % [tag, u.background, " · niv. %d" % u.level if u.side == "p" else ""]))
	h.add_child(v)
	c.add_child(h)
	c.add_child(UiKit.bars(u, [StatBar.new("Fatigue", u.fat, u.fat_max_eff(), Color("5d7f8a"))]))
	var w: Dictionary = u.weapon_data()
	var line: String = "%s %d–%d · %d PA%s · Mêlée %d/%d · Dist. %d/%d%s" % [
		w["n"], w["min"], w["max"], w["ap"], " · portée %d" % w["rng"] if int(w["rng"]) > 1 else "",
		u.melee_skill, u.melee_def, u.ranged_skill, u.ranged_def, " · bouclier" if u.shield else ""]
	var info := UiKit.sub(line)
	c.add_child(info)
	var perk_row: Control = PerkIcon.row(u, 22)
	if perk_row != null:
		c.add_child(perk_row)
	if u.shield_wall:
		c.add_child(UiKit.label("Mur de boucliers", 13, GameTheme.GOLD, true))


func _refresh_current() -> void:
	_clear(_cur_box)
	var u: Unit = state.current
	_pips_row.visible = u != null and state.over == ""
	if u != null and state.over == "":
		_unit_block(_cur_box, u, "À vous" if u.side == "p" else "Ennemi")


## Attaque simple ou capacité armée possible contre `t` ?
func _can_hit(cur: Unit, t: Unit) -> bool:
	return state.can_use_ability(cur, t, _ability) if _ability != "" else state.can_attack(cur, t)


## Boutons de capacités de l'arme et du bouclier : un clic arme la capacité, le clic suivant sur un ennemi l'utilise.
func _add_ability_buttons(u: Unit) -> void:
	for id in CombatRules.abilities_of(u):
		var ab: Dictionary = Data.ABILITIES[id]
		var ap: int = CombatRules.ability_ap(u, id)
		var fat: int = CombatRules.ability_fat(u, id)
		var left: String = " ×%d" % CombatRules.tool_left(u, str(ab["tool"])) if ab.has("tool") else ""
		var b := UiKit.button("%s%s (%d PA)" % [ab["n"], left, ap], "pri" if _ability == id else "")
		b.tooltip_text = "%s
Coût : %d PA, %d fatigue." % [ab["d"], ap, fat]
		b.disabled = u.ap < ap or u.fat + fat > u.fat_max_eff()
		b.pressed.connect(func() -> void:
			_ability = "" if _ability == id else id
			_refresh_all())
		_reg_hot(b)
		_actions.add_child(b)
	if _ability != "":
		_hint.text = "%s : cliquez sur un ennemi à portée (ou de nouveau sur le bouton, ou Échap, pour annuler)." % Data.ABILITIES[_ability]["n"]


## Numérote le bouton (touches 1 à 9) et ajoute la touche à son texte.
func _reg_hot(b: Button) -> void:
	if _hot.size() >= 9:
		return
	_hot.append(b)
	b.text += Shortcuts.tag(str(_hot.size()))


func _refresh_actions() -> void:
	_clear(_actions)
	_hot.clear()
	_hint.text = ""
	var u: Unit = state.current
	if state.over != "" or u == null:
		return
	if not _player_turn():
		_hint.text = "L'ennemi agit…" if u.side == "e" else "…"
		return
	if u.shield_ok():
		var sw := UiKit.button("Mur de boucliers (4 PA)")
		sw.disabled = u.shield_wall or u.ap < 4 or u.fat + 10 > u.fat_max_eff()
		sw.pressed.connect(_raise_shield)
		_reg_hot(sw)
		_actions.add_child(sw)
	_add_ability_buttons(u)
	for bi in u.bag.size():  # changement d'arme : objets du sac
		if (u.bag[bi] as Dictionary).is_empty() or str(u.bag[bi]["kind"]) == "tool":
			continue
		var swap_b := UiKit.button("Changer : %s (%d PA)" % [Loot.item_name(u.bag[bi]), Data.SWAP_AP])
		var block: String = Inventory.bag_swap_block(u, bi)
		swap_b.disabled = block != "" or u.ap < Data.SWAP_AP or u.fat + Data.SWAP_FAT > u.fat_max_eff()
		swap_b.tooltip_text = block if block != "" else "Range ce que vous portez dans le sac. Coût : %d PA, %d fatigue." % [Data.SWAP_AP, Data.SWAP_FAT]
		swap_b.pressed.connect(_swap_weapon.bind(bi))
		_reg_hot(swap_b)
		_actions.add_child(swap_b)
	if state.can_undo_move(u):
		var undo_b := UiKit.button("Annuler le déplacement" + Shortcuts.tag("Ctrl+Z"))
		undo_b.tooltip_text = "Revenir à la case de départ et récupérer les PA et la fatigue du déplacement (tant que vous n'avez pas attaqué)."
		undo_b.pressed.connect(_undo_move)
		_actions.add_child(undo_b)
	var wait_b := UiKit.button("Attendre" + Shortcuts.tag("W"))
	wait_b.disabled = u.waited
	wait_b.pressed.connect(_wait_turn)
	_actions.add_child(wait_b)
	var end_b := UiKit.button("Fin du tour" + Shortcuts.tag("Espace"), "pri")
	end_b.pressed.connect(_end_turn)
	_actions.add_child(end_b)
	if _confirm_retreat:
		var go := UiKit.button("Confirmer la retraite", "pri")
		go.pressed.connect(_retreat)
		_actions.add_child(go)
		var stay := UiKit.button("Rester")
		stay.pressed.connect(func() -> void:
			_confirm_retreat = false
			_refresh_actions())
		_actions.add_child(stay)
	else:
		var r := UiKit.button("Retraite", "ghost")
		r.pressed.connect(func() -> void:
			_confirm_retreat = true
			_refresh_actions())
		_actions.add_child(r)


func _refresh_inspect() -> void:
	_clear(_inspect_box)
	var ins: Unit = _inspect
	if ins == null or not ins.is_live() or ins == state.current:
		return
	_unit_block(_inspect_box, ins, "Allié" if ins.side == "p" else "Cible")
	if _player_turn() and ins.side != state.current.side:
		var cur: Unit = state.current
		var w: Dictionary = cur.weapon_data()
		var row := UiKit.hbox(14)
		var dm: float = float(Data.ABILITIES[_ability].get("dmg", 1.0)) if _ability != "" else 1.0
		row.add_child(UiKit.label("Toucher %d %%" % state.hit_chance(cur, ins, _ability), 16, GameTheme.GOLD, true))
		row.add_child(UiKit.label("Dégâts %d–%d" % [roundi(int(w["min"]) * dm), roundi(int(w["max"]) * dm)], 16, GameTheme.GOLD, true))
		_inspect_box.add_child(row)
		if not _can_hit(cur, ins):
			var why: String = "Pas assez de PA ou trop fatigué."
			if Hex.distance(cur.hex, ins.hex) > cur.weapon_range():
				why = "Hors de portée."
			elif state.line_blocked(cur, ins):
				why = "Ligne de tir bloquée."
			_inspect_box.add_child(UiKit.sub(why))


func _log_kind(css: String) -> String:
	return "mor" if css == "mor" else ("sys" if css == "sys" else "combat")


## Journal : filtré, couleurs par type d'événement, les lignes d'une même action regroupées (chronologie dans le groupe,
## groupes du plus récent au plus ancien). Reste calé en haut sur le plus récent.
func _refresh_log() -> void:
	if state == null or _log == null:
		return
	var groups: Array = []  ## de plus récent à plus ancien ; chaque groupe = lignes dans l'ordre chronologique
	var last_g: int = -999999
	var shown: int = 0
	for l in state.log_lines:
		if _log_filter != "all" and _log_kind(str(l["c"])) != _log_filter:
			continue
		if shown >= LOG_SHOWN:
			break
		shown += 1
		var g: int = int(l.get("g", 0))
		if groups.is_empty() or g != last_g:
			groups.append([])
			last_g = g
		(groups[groups.size() - 1] as Array).push_front(l)
	var lines: PackedStringArray = []
	for grp in groups:
		for i in (grp as Array).size():
			var l: Dictionary = grp[i]
			var col: String = LOG_COLORS.get(l["c"], "#ece1c9")
			var t: String = str(l["t"]).replace("[", "(").replace("]", ")")
			if l["c"] == "death" or l["c"] == "sys":
				t = "[b]%s[/b]" % t
			var prefix: String = "" if i == 0 else "[color=#6b5d46]  ↳ [/color]"
			lines.append("%s[color=%s]%s[/color]" % [prefix, col, t])
	_log.text = "\n".join(lines)
	_log.scroll_to_line(0)


# --- Fin de bataille ---

func _show_end() -> void:
	if _modal != null:
		return
	var c: Dictionary = state.contract
	var win: bool = state.over == "win"
	Sfx.play("victory" if win else "defeat")
	Tutorial.hint("end")
	_modal = ModalOverlay.open(self, 460)
	var box: VBoxContainer = _modal.content
	var heading: String = "Victoire" if win else ("Retraite" if state.over == "retreat" else "Défaite")
	box.add_child(UiKit.title(heading, 40, GameTheme.GOLD if win else GameTheme.BLOOD))
	var is_contract: bool = c.get("kind", "contract") == "contract"
	if win:
		var more_waves: bool = c.get("kind", "") == "assault" and not Campaign.next_wave(c).is_empty()
		if more_waves:
			box.add_child(UiKit.para("Vague repoussée ! La suivante arrive, sans répit : les blessures restent."))
		elif c.get("kind", "") == "assault":
			box.add_child(UiKit.para("Le lieu est pris. La garnison est taillée en pièces."))
		else:
			box.add_child(UiKit.para("%s paiera %d couronnes." % [c["employer"], c["pay"]] if is_contract else "La bande est dispersée. La route est libre."))
	else:
		box.add_child(UiKit.para("Pas un sou pour ce contrat." if is_contract else "Les survivants s'enfuient à travers champs."))
	var dead: Array = []
	for u in state.units:
		if u.side == "p" and u.dead and not u.immobile:
			dead.append(u.unit_name)
	if dead.is_empty():
		box.add_child(UiKit.sub("Aucun mort à déplorer."))
	else:
		box.add_child(UiKit.label("Tombés : " + ", ".join(dead), 15, Color("ff8a78")))
	box.add_child(UiKit.sub("Le détail (hommes, butin, prime) suit."))
	var b := UiKit.button("Continuer", "pri")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func() -> void: Game.finish_battle())
	box.add_child(b)
