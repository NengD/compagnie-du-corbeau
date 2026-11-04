extends SceneTree
## Captures et mesure grossière du temps d'image pour un niveau de qualité (fenêtre requise).
##   godot --path . --screen 1 --resolution 1280x720 -s res://tools/shots_qualite.gd -- <dossier> <0..3>
## N'écrit pas dans user://settings.cfg (Settings.persist = false) ni dans la sauvegarde.

var out_dir: String = "user://"
var level: int = 2


func _init() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _measure(label: String) -> void:
	await _frames(20)  # échauffement
	var t0: int = Time.get_ticks_usec()
	var proc: float = 0.0
	for i in 120:
		await process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
	var dt: float = float(Time.get_ticks_usec() - t0) / 120000.0
	var calls: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("MESURE %s niveau=%s : %.2f ms/image (%.0f i/s), process=%.2f ms, appels de dessin=%d" % [label, Quality.name_of(level), dt, 1000.0 / dt, proc / 120.0 * 1000.0, calls])


func _shot(shot_name: String) -> void:
	await _frames(6)
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [shot_name, Quality.name_of(level)]))
	print("capture : ", shot_name, " ", Quality.name_of(level))


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
	if args.size() > 1:
		level = int(args[1])
	var st: Node = root.get_node("/root/Settings")
	st.persist = false
	st.set_value("vsync", 0)  # images libres : on mesure le coût réel
	st.set_value("fps_limit", 4)
	st.apply_quality(level)
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.new_game(5)
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	game.accept_contract(0)
	game.leave_settlement()
	await create_timer(5.0).timeout  # laisse passer l'illustration de transition
	await _shot("carte")
	await _measure("carte")
	game.world.parties.clear()
	game.engage_target()
	await create_timer(1.5).timeout
	await _shot("bataille")
	await _measure("bataille")
	# effets d'impact (particules) pour la capture
	var board: Node = _find(main, "BoardView")
	if board != null:
		var fx: Node = board.get("fx")
		for i in 6:
			fx.impact(board.hex_px(Vector2i(4 + i % 3, 3 + i / 3)), i % 2 == 0, true, Vector2.RIGHT)
		fx.death(board.hex_px(Vector2i(6, 4)), null)
		await _frames(8)
		await _shot("bataille_effets")
	quit(0)
