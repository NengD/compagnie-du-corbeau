extends SceneTree
## Test de fumée de l'interface : ville, carte, voyage, bataille jouée jusqu'au bout, retour à la carte.
##   godot --path . --headless -s res://tests/smoke_ui.gd
## Ne touche pas à user://savegame.json. (Les autoloads ne sont pas des identifiants dans un script -s :
## on passe par get_node et par des types Node.)

var _errors: int = 0
var game: Node


func _init() -> void:
	call_deferred("_run")


func _step(msg: String) -> void:
	print("· " + msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	game = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	load("res://scenes/battle/battle.gd").speed = 0.0
	game.new_game(5)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)
	# --- Ville ---
	var camp: Node = _find(main, "Camp")
	_check(camp != null, "l'écran de ville s'affiche au départ")
	var tabs: TabContainer = camp.get("_tabs")
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await _frames(2)
		_step("onglet %s : %d nœuds" % [tabs.get_tab_title(i), _count(camp)])
	tabs.current_tab = tabs.get_tab_count() - 1  # Compagnie
	await _frames(2)
	var m: Unit = game.roster[0]
	m.xp = 150
	game.level_check(m)
	game.changed.emit()
	await _frames(1)
	camp.call("_open_promotion", m.id)
	await _frames(1)
	_check(camp.get("_modal") != null, "fenêtre de promotion")
	camp.call("_close_modal")
	tabs.current_tab = 0
	await _frames(1)
	game.gold = 99999
	_check(game.accept_contract(0), "contrat accepté depuis l'écran de ville")
	game.leave_settlement()
	await _frames(3)
	# --- Carte ---
	var map: Node = _find(main, "MapScreen")
	_check(map != null, "la carte s'affiche en quittant la ville")
	game.world.parties.clear()
	map.call("_set_speed", 3)
	map.view.travel_requested.emit(game.contract_target(), {"kind": "target", "title": "cible"})
	var guard: int = 0
	while game.battle == null and guard < 4000:
		guard += 1
		await process_frame
	_check(game.battle != null, "arrivée sur les lieux : la bataille s'engage (%d images)" % guard)
	_step("voyage : jour %d" % game.day)
	await _frames(3)
	# --- Bataille ---
	var screen: Node = _find(main, "BattleScreen")
	_check(screen != null and screen.state != null, "l'écran de bataille démarre")
	guard = 0
	var memo: Dictionary = {}
	while screen.state.over == "" and guard < 800:
		guard += 1
		await process_frame
		var cur: Unit = screen.state.current
		if not screen.get("_busy") and cur != null and cur.side == "p":
			var a: Dictionary = Ai.next_action(screen.state, cur, memo)
			if a["type"] == "attack":
				_click(screen, screen.board.hex_px(a["target"].hex) * screen.board.scale.x + screen.board.position)
			elif a["type"] == "move":
				var dest: Vector2i = a["path"][a["path"].size() - 1]
				_click(screen, screen.board.hex_px(dest) * screen.board.scale.x + screen.board.position)
			else:
				memo = {}
				screen.call("_end_turn")
	_step("bataille : %s en %d manches" % [screen.state.over, screen.state.round_no])
	_check(screen.state.over != "", "la bataille se termine")
	await _frames(2)
	game.finish_battle()
	await _frames(3)
	_check(_find(main, "MapScreen") != null or game.game_over, "retour sur la carte")
	# --- Fiche de compagnie depuis la carte ---
	map = _find(main, "MapScreen")
	if map != null:
		map.company_requested.emit()
		await _frames(2)
		var comp: Node = _find(main, "Camp")
		_check(comp != null and comp.mode == "company", "fiche de compagnie")
		comp.closed.emit()
		await _frames(2)
		_check(_find(main, "MapScreen") != null, "retour à la carte")
		var city: Dictionary = game.world.settlements[1]
		game.world.parties.clear()
		map = _find(main, "MapScreen")
		map.view.travel_requested.emit(game.world.settlement_pos(city), {"kind": "settlement", "id": city["id"], "title": city["name"]})
		guard = 0
		while game.location == "" and guard < 4000:
			guard += 1
			await process_frame
		await _frames(2)
		_check(game.location == city["id"] and _find(main, "Camp") != null, "arrivée en ville (%d images)" % guard)
	# --- Écran d'inventaire (appels directs, sans souris) ---
	game.inventory = [Loot.item("weapon", "hache"), Loot.item("head", "casque"), Loot.item("shield")]
	var inv_cls: GDScript = load("res://scenes/inventory/inventory_screen.gd")
	var inv: Node = inv_cls.call("open", main)
	await _frames(2)
	_check(inv != null and inv.is_inside_tree(), "l'inventaire s'ouvre")
	_check(inv_cls.call("open", main) == inv, "une seule fenêtre d'inventaire")
	var who: Unit = game.roster[0]
	inv.call("select", who.id)
	inv.call("quick", Inventory.in_stash(1))  # double-clic : casque équipé
	await _frames(2)
	_check(who.head == "casque", "double-clic : le casque est équipé")
	inv.call("quick", Inventory.at(who, "head"))
	await _frames(2)
	_check(who.head == "none" or who.head != "casque", "double-clic sur une pièce portée : retour à la réserve")
	_check(inv.call("can_drop", Inventory.in_stash(0), Inventory.at(who, "weapon")), "dépôt d'une arme sur la main droite")
	_check(not inv.call("can_drop", Inventory.in_stash(0), Inventory.at(who, "head")), "pas d'arme sur la tête")
	inv.call("drop", Inventory.in_stash(0), Inventory.at(who, "bag0"))
	await _frames(2)
	_check(who.bag[0]["key"] == "hache", "glisser vers le sac")
	inv.call("step", 1)
	inv.call("hover", null)
	inv.call("set_filter", "weapon")
	await _frames(2)
	_check(inv.call("selected") != who, "flèche : homme suivant")
	inv.call("close")
	await _frames(2)
	_check(get_nodes_in_group("inventory_screen").is_empty(), "plus d'inventaire ouvert")
	_step("jour %d, or %d, %d hommes" % [game.day, game.gold, game.roster.size()])
	print("\nSmoke UI : %s" % ("OK" if _errors == 0 else "%d erreur(s)" % _errors))
	quit(0 if _errors == 0 else 1)


func _click(screen: Node, stage_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = stage_pos
	screen.call("_on_stage_input", ev)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors += 1
		print("  ✗ " + msg)


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and n.get_script().get_global_name() == cls:
		return n
	for c in n.get_children():
		var f: Node = _find(c, cls)
		if f != null:
			return f
	return null


func _count(n: Node) -> int:
	var t: int = 1
	for c in n.get_children():
		t += _count(c)
	return t
