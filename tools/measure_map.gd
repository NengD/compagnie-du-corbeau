extends SceneTree
## Mesure le coût de dessin de la carte : appels et temps par peintre (MapView.stats), par phase (halte, route, fort zoom),
## et temps de construction à froid de la texture de fond. Sans fenêtre :
##   godot --path . --headless -s res://tools/measure_map.gd -- [images par phase] [graine] [mode]
## mode : « normal » (réglages actuels), « calme » (jour clair, animations de la carte en marche), « calme_fixe » (idem sans animations).
## Les réglages ne sont changés qu'en mémoire (jamais enregistrés dans settings.cfg).
## Sortie : une ligne par peintre -> appels par image, millisecondes par image.
var game: Node
var frames_per_phase: int = 240


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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


func _report(title: String, v: Control, n: int) -> void:
	var st: Dictionary = v.stats
	print("--- %s (%d images)" % [title, n])
	var keys: Array = st.keys()
	keys.sort()
	var tot_us: int = 0
	for k in keys:
		var e: Array = st[k]
		print("  %-22s %6.2f appels/image   %7.3f ms/image" % [k, float(e[0]) / n, float(e[1]) / 1000.0 / n])
		if k != "process":
			tot_us += int(e[1])
	print("  %-22s %24.3f ms/image (dessin seul)" % ["TOTAL", float(tot_us) / 1000.0 / n])
	st.clear()


func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		frames_per_phase = int(a[0])
	game = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	load("res://scenes/battle/battle.gd").speed = 0.0  # sans fondus ni écrans d'introduction
	var mode: String = a[2] if a.size() > 2 else "normal"
	var st: Node = root.get_node("/root/Settings")
	if mode.begins_with("calme"):
		st.day_night = false
		st.weather_fx = false
		st.map_anim = mode == "calme"
	print("mode : %s (animations %s, jour/nuit %s)" % [mode, str(st.map_anim), str(st.day_night)])
	game.new_game(int(a[1]) if a.size() > 1 else 5)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	var t1: int = Time.get_ticks_msec()
	game.leave_settlement()
	await _frames(2)
	print("construction à froid de la carte (2 images) : %d ms" % (Time.get_ticks_msec() - t1))
	var map: Node = _find(main, "MapScreen")
	if map == null:
		print("MapScreen introuvable")
		quit(1)
		return
	var v: Control = map.view
	await _frames(40)
	v.stats.clear()
	print("monde %s, vue %s" % [str(game.world.size), str(v.size)])
	map.call("_set_speed", 0)
	await _frames(frames_per_phase)
	_report("halte, vue de départ", v, frames_per_phase)
	game.accept_contract(0)
	game.world.parties.clear()  # pas de rencontre : on veut mesurer la marche, pas un combat
	map.call("_set_speed", 3)
	var goal: Vector2 = game.contract_target() if not game.active_contract.is_empty() else Vector2.ZERO
	if goal == Vector2.ZERO or goal.distance_to(game.world.player_pos) < 200.0:  # sans contrat : le lieu le plus éloigné
		var far: float = 0.0
		for s in game.world.settlements:
			var d: float = game.world.settlement_pos(s).distance_to(game.world.player_pos)
			if d > far and d < 1200.0:
				far = d
				goal = game.world.settlement_pos(s)
	v.travel_requested.emit(goal, {"kind": "point"})
	print("destination %s depuis %s : chemin de %d points, vitesse carte %s" % [str(goal), str(game.world.player_pos), game.world.path.size(), str(map.get("_speed"))])
	var p0: Vector2 = game.world.player_pos
	await _frames(frames_per_phase)
	print("trajet : %d px parcourus, chemin restant %d points, événement en attente : %s" % [int(p0.distance_to(game.world.player_pos)), game.world.path.size(), str(not game.pending_event.is_empty())])
	_report("route (vitesse 3)", v, frames_per_phase)
	map.call("_set_speed", 0)
	v.zoom_at(v.size * 0.5, 100.0)
	v.center_on(game.world.player_pos)
	await _frames(30)
	v.stats.clear()
	await _frames(frames_per_phase)
	_report("halte, zoom maximal", v, frames_per_phase)
	print("mémoire statique : %.1f Mo" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	quit(0)
