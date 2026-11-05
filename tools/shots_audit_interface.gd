extends SceneTree
## Captures de l'audit n°2 (interface) : carte avec tiroir « Détails » ouvert, légende ouverte, mini-carte repliée/dépliée,
## fiche de personnage (libellés), marché, carte à zoom maximal. Fenêtre requise :
##   godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_audit_interface.gd -- "<dossier>" "<suffixe>" "<LxH>"
## Aucun réglage n'est enregistré (les options sont modifiées en mémoire seulement).
var game: Node
var dir: String = "."
var tag: String = ""


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, name, tag])


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and n.get_script().get_global_name() == cls:
		return n
	for c in n.get_children():
		var f: Node = _find(c, cls)
		if f != null:
			return f
	return null


func _key(map: Node, k: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = k
	map.call("_unhandled_key_input", ev)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	dir = a[0] if a.size() > 0 else "."
	tag = a[1] if a.size() > 1 else "x"
	if a.size() > 2 and a[2].contains("x"):
		var wh: PackedStringArray = a[2].split("x")
		var sz := Vector2i(int(wh[0]), int(wh[1]))
		DisplayServer.window_set_size(sz)
		root.size = sz
		await _frames(5)
	game = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	load("res://scenes/battle/battle.gd").speed = 0.0
	game.new_game(5)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	game.gold = 99999
	await _shot("1_ville")
	var camp: Node = _find(main, "Camp")
	if camp != null:
		camp.get("_tabs").current_tab = 2
		await _shot("2_marche")
	game.leave_settlement()
	await _frames(30)
	game.world.parties.clear()
	var map: Node = _find(main, "MapScreen")
	map.call("_set_speed", 0)
	var st: Node = root.get_node("/root/Settings")
	st.day_night = false
	await _shot("3_carte")
	_key(map, KEY_F)
	await _shot("4_tiroir")
	_key(map, KEY_L)  # la légende ferme le tiroir
	await _shot("5_legende")
	map.mini.set_collapsed(true)
	await _shot("6_legende_minimap_repliee")
	_key(map, KEY_L)
	_key(map, KEY_F)
	await _shot("7_tiroir_minimap_repliee")
	_key(map, KEY_F)
	map.mini.set_collapsed(false)
	# bandeau d'état du bas
	map.hud.say("Halte. Cliquez sur la carte pour avancer · ZQSD ou flèches : caméra · H : recentrer.", "t1")
	await _shot("8_bandeau")
	# fiche de personnage
	map.hud.inventory_pressed.emit()
	await _shot("9_fiche")
	var inv: Node = _find(root, "InventoryScreen")
	if inv != null:
		inv.call("close")
	# zoom maximal, de près
	var v: Control = map.view
	v.zoom_at(v.size * 0.5, 100.0)
	v.center_on(game.world.player_pos)
	await _shot("10_zoom_max")
	var det: Node = v.get("_detail")
	if det != null:
		det.visible = false  # même vue sans le détail de sol : comparaison avant / après
		await _shot("11_zoom_max_sans_detail")
	print("images enregistrées dans ", dir)
	quit(0)
