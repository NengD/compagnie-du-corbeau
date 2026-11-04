extends SceneTree
## Captures d'écran : ville, carte, bataille (fenêtre requise : ne pas lancer en --headless).
##   godot --path . -s res://tests/screenshots.gd -- <dossier de sortie>
## Utilise une partie temporaire : user://savegame.json n'est pas modifié.

var game: Node
var out_dir: String = "user://"


func _init() -> void:
	call_deferred("_run")


func _shot(shot_name: String) -> void:
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("capture : ", shot_name)


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and n.get_script().get_global_name() == cls:
		return n
	for c in n.get_children():
		var f: Node = _find(c, cls)
		if f != null:
			return f
	return null


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	game = root.get_node("/root/Game")
	game.autosave = false
	load("res://scenes/battle/battle.gd").speed = 0.0
	game.new_game(5)
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _shot("1_ville_contrats")
	var camp: Node = _find(main, "Camp")
	camp.get("_tabs").current_tab = 2
	await _shot("2_ville_marche")
	camp.get("_tabs").current_tab = 0
	game.accept_contract(0)
	game.leave_settlement()
	await _shot("3_carte")
	var map: Node = _find(main, "MapScreen")
	map.view.travel_requested.emit(game.contract_target(), {"kind": "target", "title": "cible"})
	for i in 40:
		game.map_step(0.05)
	await _shot("4_carte_route")
	game.world.parties.clear()
	game.engage_target()
	await _shot("5_bataille")
	quit(0)
