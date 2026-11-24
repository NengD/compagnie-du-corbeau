class_name KeysPanel
extends RefCounted
## Fenêtre « Touches » : une ligne par action (zones Carte / Bataille / Interface). On clique sur une touche, puis on
## appuie sur la nouvelle ; une touche déjà prise est refusée, ou échangée si le joueur le confirme.
## Échap annule la saisie et reste réservée. Les changements sont enregistrés tout de suite (Settings.save_keybinds).

## Capte le clavier pendant la saisie (reçoit les événements avant le reste de l'interface).
class Catcher extends Node:
	var panel: KeysPanel

	func _input(event: InputEvent) -> void:
		if panel != null and event is InputEventKey and panel.on_key(event as InputEventKey):
			get_viewport().set_input_as_handled()


var _host: Node
var _modal: ModalOverlay
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _swap_row: HBoxContainer
var _capture: Array = []  ## [action, index] pendant la saisie, sinon vide
var _pending: Dictionary = {}  ## échange en attente : {"action", "index", "spec"}


static func open(host: Node) -> ModalOverlay:
	var p := KeysPanel.new()
	return p._build(host)


func _build(host: Node) -> ModalOverlay:
	_host = host
	_modal = ModalOverlay.open(host, 600)
	_modal.set_meta("keys_panel", self)  # garde l'instance en vie tant que la fenêtre existe
	var box: VBoxContainer = _modal.content
	box.add_child(UiKit.title("Touches", 34))
	box.add_child(UiKit.sub("Cliquez sur une touche, puis appuyez sur la nouvelle. Échap annule la saisie (et reste réservée)."))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 330)
	box.add_child(_scroll)
	_rows = UiKit.vbox(4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	_status = UiKit.sub("", 14)
	box.add_child(_status)
	_swap_row = UiKit.hbox(8)
	_swap_row.visible = false
	box.add_child(_swap_row)
	var foot := UiKit.hbox(8)
	var defaults := UiKit.button("Par défaut", "ghost", true)
	defaults.pressed.connect(func() -> void:
		Keybinds.reset_all()
		_cancel()
		_save()
		_say("Toutes les touches sont revenues à leurs valeurs par défaut.")
		_populate())
	foot.add_child(defaults)
	foot.add_child(UiKit.spacer())
	var close := UiKit.button("Fermer", "pri")
	close.pressed.connect(_modal.close)
	foot.add_child(close)
	box.add_child(foot)
	var c := Catcher.new()
	c.panel = self
	_modal.add_child(c)
	_populate()
	return _modal


func _populate() -> void:
	for ch in _rows.get_children():
		ch.queue_free()
	var conflicts: Array = Keybinds.find_conflicts()
	var clash: Dictionary = {}
	for c in conflicts:
		clash[str(c[0])] = true
		clash[str(c[1])] = true
	for z in Keybinds.ZONES:
		_rows.add_child(UiKit.label(str(z[1]), 18, GameTheme.GOLD, true))
		for a in Keybinds.ACTIONS:
			if str(a["zone"]) != str(z[0]):
				continue
			_rows.add_child(_row(str(a["id"]), clash.has(str(a["id"]))))


func _row(action: String, clashing: bool) -> Control:
	var h := UiKit.hbox(6)
	var l := UiKit.label(Keybinds.label_of(action), 14, GameTheme.status_bad() if clashing else GameTheme.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	var keys: Array = Keybinds.keys_of(action)
	for i in keys.size():
		h.add_child(_key_button(action, i, int(keys[i])))
	if keys.size() < 2 and Keybinds.defaults(action).size() >= 1:
		var add := UiKit.button("+", "ghost", true)
		add.tooltip_text = "Ajouter une seconde touche"
		add.pressed.connect(_begin.bind(action, keys.size(), add))
		h.add_child(add)
	var undo := UiKit.button("↺", "ghost", true)
	undo.tooltip_text = "Rétablir les touches par défaut de cette action"
	undo.disabled = Keybinds.is_default(action)
	undo.pressed.connect(func() -> void:
		Keybinds.reset_action(action)
		_cancel()
		_save()
		_populate())
	h.add_child(undo)
	return h


func _key_button(action: String, index: int, spec: int) -> Button:
	var b := UiKit.button(Keybinds.spec_name(spec), "ghost", true)
	b.custom_minimum_size = Vector2(110, 0)
	b.tooltip_text = "Cliquer, puis appuyer sur la nouvelle touche"
	b.pressed.connect(_begin.bind(action, index, b))
	return b


func _begin(action: String, index: int, b: Button) -> void:
	_cancel()
	_capture = [action, index]
	b.text = "Appuyez…"
	_say("« %s » : appuyez sur la nouvelle touche (Échap : annuler)." % Keybinds.label_of(action))


func _cancel() -> void:
	_capture = []
	_pending = {}
	if _swap_row != null and is_instance_valid(_swap_row):
		_swap_row.visible = false
		for c in _swap_row.get_children():
			c.queue_free()


func _say(text: String) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text


func _save() -> void:
	var st: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Settings")
	if st != null:
		st.call("save_keybinds")


## Touche reçue pendant la saisie. Retourne vrai si l'événement est consommé.
func on_key(ke: InputEventKey) -> bool:
	if _capture.is_empty() or not ke.pressed or ke.echo:
		return not _capture.is_empty()  # pendant la saisie, aucune touche ne passe à l'interface
	var action: String = str(_capture[0])
	var index: int = int(_capture[1])
	var code: int = ke.keycode if ke.keycode != 0 else ke.physical_keycode
	if code == KEY_ESCAPE:
		_cancel()
		_say("Saisie annulée.")
		_populate()
		return true
	var modifier_only: bool = code == KEY_SHIFT or code == KEY_CTRL or code == KEY_ALT or code == KEY_META
	if modifier_only and action != "cam_fast":
		return true
	var spec: int = Keybinds.spec_from_event(ke, Keybinds.is_physical_action(action))
	var r: Dictionary = Keybinds.assign(action, index, spec, false)
	if bool(r["ok"]):
		_finish("« %s » : %s." % [Keybinds.label_of(action), Keybinds.names_of(action)])
	elif not (r["conflict"] as Array).is_empty() and not Keybinds.is_reserved(spec, action):
		_offer_swap(action, index, spec, r["conflict"])
	else:
		_say(str(r["msg"]))
	return true


func _finish(msg: String) -> void:
	_cancel()
	_save()
	_say(msg)
	_populate()


func _offer_swap(action: String, index: int, spec: int, conflict: Array) -> void:
	var names: PackedStringArray = []
	for o in conflict:
		names.append(Keybinds.label_of(str(o)))
	_pending = {"action": action, "index": index, "spec": spec}
	_capture = []
	_say("%s est déjà attribuée à : %s. Échanger les touches ?" % [Keybinds.spec_name(spec), ", ".join(names)])
	for c in _swap_row.get_children():
		c.queue_free()
	var yes := UiKit.button("Échanger", "pri", true)
	yes.pressed.connect(func() -> void:
		var p: Dictionary = _pending
		var r: Dictionary = Keybinds.assign(str(p["action"]), int(p["index"]), int(p["spec"]), true)
		_finish("Touches échangées." if bool(r["ok"]) else str(r["msg"])))
	var no := UiKit.button("Refuser", "ghost", true)
	no.pressed.connect(func() -> void:
		_cancel()
		_say("Aucun changement.")
		_populate())
	_swap_row.add_child(yes)
	_swap_row.add_child(no)
	_swap_row.visible = true
