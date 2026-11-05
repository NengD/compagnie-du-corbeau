extends SceneTree
## Captures du grand monde : vue de départ, monde entier au zoom minimal, mini-carte, légende, caméra aux quatre bords, zoom de près,
## et mesures (texture de carte, images par seconde). Fenêtre requise :
## godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_grand_monde.gd -- "<dossier>" "<suffixe>"
var game: Node
var dir: String = "."
var tag: String = ""


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(8)
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, name, tag])


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and n.get_script().get_global_name() == cls:
		return n
	for c in n.get_children():
		var f: Node = _find(c, cls)
		if f != null:
			return f
	return null


func _press(key: Key, on: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	ev.pressed = on
	Input.parse_input_event(ev)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	dir = a[0] if a.size() > 0 else "."
	tag = a[1] if a.size() > 1 else "x"
	game = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	var t0: int = Time.get_ticks_msec()
	game.new_game(int(a[2]) if a.size() > 2 else 5)
	print("new_game : %d ms" % (Time.get_ticks_msec() - t0))
	game.set_company_identity({"name": "Les Corbeaux de Fer", "banner": {"primary": "3e526a", "secondary": "d8cfb8", "emblem": 0, "pattern": 3}})
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	game.gold = 99999
	game.leave_settlement()
	var t1: int = Time.get_ticks_msec()
	await _frames(30)
	print("premières images (texture, décor, territoires) : %d ms" % (Time.get_ticks_msec() - t1))
	game.world.parties.clear()
	var map: Node = _find(main, "MapScreen")
	map.call("_set_speed", 0)
	var v: Control = map.view
	await _frames(20)
	print("vue %s, échelle de base %.3f, zoom %.2f, échelle %.3f, monde %s" % [v.size, v.get("_base_k"), v.zoom, v.get("_stage").scale.x, game.world.size])
	await _shot("1_depart")
	# monde entier
	v.zoom_at(v.size * 0.5, 0.01)
	v.center_on(game.world.size * 0.5)
	await _shot("2_monde_entier")
	# légende ouverte sur le monde entier
	map.hud.legend_pressed.emit()
	await _frames(4)
	await _shot("3_legende")
	var sections: Dictionary = map._legend_panel._sections
	for k in sections:
		(sections[k]["head"] as Button).pressed.emit()
	await _frames(4)
	await _shot("3b_legende_sections_inversees")
	map.hud.legend_pressed.emit()
	# de près : les noms, la capitale, les routes
	v.zoom_at(v.size * 0.5, 100.0)
	v.center_on(game.world.player_pos)
	await _shot("4_pres")
	# caméra au clavier : les quatre bords (touches W A S D physiques = Z Q S D en AZERTY)
	v.zoom_at(v.size * 0.5, 0.01)
	v.zoom_at(v.size * 0.5, 3.0)
	v.center_on(game.world.player_pos)
	await _frames(3)
	var c0: Vector2 = v.visible_world_rect().get_center()
	_press(KEY_W, true)
	await _frames(40)
	_press(KEY_W, false)
	var c1: Vector2 = v.visible_world_rect().get_center()
	print("W (Z en AZERTY) : le centre de la vue passe de %s à %s (monte : %s)" % [c0, c1, c1.y < c0.y])
	for e in [["bord_nord", Vector2(0, -99999)], ["bord_ouest", Vector2(-99999, 0)], ["bord_sud", Vector2(0, 99999)], ["bord_est", Vector2(99999, 0)]]:
		v.pan_px(e[1])
		await _shot(str(e[0]))
	v.center_on_player()
	# suivi pendant un trajet
	var dest: Vector2 = game.world.player_pos + Vector2(700, 150)
	if not game.world.passable(dest):
		dest = game.world.player_pos + Vector2(-500, 100)
	v.travel_requested.emit(dest, {"kind": "point"})
	map.call("_set_speed", 3)
	await _frames(90)
	var pc: Vector2 = v.visible_world_rect().get_center()
	print("suivi : compagnie %s, centre de la vue %s" % [game.world.player_pos, pc])
	await _shot("5_suivi")
	# mesure d'images par seconde (monde entier puis de près)
	map.call("_set_speed", 0)
	for z in [0.01, 100.0, 1.0]:
		v.zoom_at(v.size * 0.5, z)
		v.center_on(game.world.player_pos)
		await _frames(10)
		var f0: int = Time.get_ticks_msec()
		var n: int = 30
		await _frames(n)
		print("images par seconde (zoom ×%.2f) : %.1f ; appels de dessin %d, primitives %d, objets %d" % [v.zoom, float(n) * 1000.0 / float(Time.get_ticks_msec() - f0),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	# mini-carte repliée
	map.call("_set_minimap", false)
	await _shot("6_minicarte_repliee")
	map.call("_set_minimap", true)
	quit()
