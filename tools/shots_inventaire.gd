extends SceneTree
## Captures de la fiche de personnage : onglets Inventaire et Talents.
##   godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_inventaire.gd -- <dossier> <1280|1920|2560>
func _init() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = a[0]
	var w: int = int(a[1]) if a.size() > 1 else 1280
	if true:
		DisplayServer.window_set_size(Vector2i(w, w * 9 / 16))
		DisplayServer.window_set_position(Vector2i(0, 0))
		await _frames(12)
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	game.new_game(5)
	var m: Unit = game.roster[0]
	m.level = 11
	m.weapon = "epee"
	m.shield = true
	m.head = "heaume"
	m.body = "brigandine"
	for st in Data.BUILDS[11]["steps"]:
		m.perks.append(str(st[0]))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	var scr: Node = load("res://scenes/inventory/inventory_screen.gd").call("open", main, m.id)
	for tab in ["inventory", "perks"]:
		scr.call("set_tab", tab)
		await _frames(12)
		root.get_texture().get_image().save_png(dir.path_join("inv_%s_%d.png" % [tab, w]))
	quit()
