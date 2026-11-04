extends SceneTree
## Captures de la carte plein cadre, du HUD, du tiroir, de l'étape « Votre compagnie » et du marqueur.
## godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_carte.gd -- "<dossier>" "<suffixe>"
var game: Node
var dir: String = "."
var tag: String = ""


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(6)
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, name, tag])


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and n.get_script().get_global_name() == cls:
		return n
	for c in n.get_children():
		var f: Node = _find(c, cls)
		if f != null:
			return f
	return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	dir = a[0] if a.size() > 0 else "."
	tag = a[1] if a.size() > 1 else "x"
	game = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	game.new_game(5)
	if a.size() > 2:
		root.content_scale_factor = float(a[2])
	game.set_company_identity({"name": "Les Corbeaux de Fer", "banner": {"primary": "3e526a", "secondary": "d8cfb8", "emblem": 0, "pattern": 3}})
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	game.gold = 99999
	game.accept_contract(0)
	game.leave_settlement()
	await _frames(30)
	game.world.parties.clear()
	var map: Node = _find(main, "MapScreen")
	map.call("_set_speed", 0)
	await _shot("map_idle")
	var v: Control = map.view
	print("view size ", v.size, " base_k ", v.get("_base_k"), " stage scale ", v.get("_stage").scale)
	# en déplacement
	map.call("_set_speed", 1)
	map.view.travel_requested.emit(game.contract_target(), {"kind": "target", "title": game.active_contract["target_name"]})
	await _frames(40)
	await _shot("map_moving")
	map.call("_set_speed", 0)
	map.drawer.open()
	await _frames(20)
	await _shot("map_drawer")
	map.drawer.close()
	await _frames(20)
	# légende
	map.hud.legend_pressed.emit()
	await _shot("map_legend")
	map.hud.legend_pressed.emit()
	# nuit
	game.day_fraction = 0.88
	await _frames(40)
	await _shot("map_night")
	game.day_fraction = 0.3
	# zoom sur le marqueur
	map.view.zoom_at(map.view.size * 0.5, 2.5)
	map.view.center_on_player()
	await _frames(10)
	await _shot("map_zoom")
	# étape Votre compagnie
	var cs: ModalOverlay = load("res://scenes/newgame/company_setup.gd").open(main, func(_s: Dictionary) -> void: pass, func() -> void: pass)
	await _shot("setup")
	cs.close()
	var bs: ModalOverlay = load("res://scenes/banner/banner_screen.gd").open(main)
	await _shot("banner_screen")
	bs.close()
	quit()
