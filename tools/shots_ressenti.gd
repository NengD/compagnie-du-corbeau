extends SceneTree
## Capture de contrôle : tutoriel, zoom du plateau, chute d'une figurine (fenêtre requise).
##   godot --path . --screen 1 --resolution 1280x720 -s res://tools/shots_ressenti.gd -- <dossier>
var out_dir: String = "user://"

func _init() -> void:
	call_deferred("_run")

func _shot(n: String) -> void:
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(n + ".png"))

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
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	load("res://scenes/battle/battle.gd").speed = 0.0
	game.new_game(5)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.get_node("/root/Settings").persist = false
	Tutorial.start()
	Tutorial.hint("town")
	await _shot("t1_tuto_ville")
	game.accept_contract(0)
	game.leave_settlement()
	game.world.parties.clear()
	game.engage_target()
	await process_frame
	var screen: Node = _find(main, "BattleScreen")
	await _shot("t2_tuto_bataille")
	var rect: Rect2 = screen._stage.get_global_rect()
	screen._zoom_at(rect.size * 0.5, 1.15 * 1.15 * 1.15 * 1.15 * 1.15 * 1.15)
	var v: UnitView = screen.board.view_of(screen.state.units[0])
	v._fall = 0.7
	await _shot("t3_zoom")
	quit(0)
