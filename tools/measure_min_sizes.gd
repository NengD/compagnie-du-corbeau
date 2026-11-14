extends SceneTree
## Hauteur / largeur minimales imposées par les grands écrans (à comparer à la fenêtre virtuelle : 1280x720 à 100 %, 853x480 à 150 % en 1280x720).
##   godot --path . --headless -s res://tools/measure_min_sizes.gd
func _init() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _min_of(node: Node) -> String:
	var worst: Vector2 = Vector2.ZERO
	var stack: Array = [node]
	var depth: Dictionary = {node: 0}
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is PanelContainer and depth[n] <= 3:
			var m: Vector2 = (n as Control).get_combined_minimum_size()
			if m.y > worst.y:
				worst = m
		for c in n.get_children():
			depth[c] = depth[n] + 1
			stack.append(c)
	return "%d x %d" % [int(worst.x), int(worst.y)]


func _run() -> void:
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	game.new_game(5)
	game.gold = 5000
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	var m: Unit = game.roster[0]
	m.arms = "epaulieres_fer"
	m.legs = "greves_fer"
	m.arm_a = m.arms_armor_max()
	m.arm_l = m.legs_armor_max()
	var mk: Node = load("res://scenes/market/market_screen.gd").call("open", main)
	await _frames(4)
	print("marché (équipement) : ", _min_of(mk))
	mk.call("set_tab", "trade")
	await _frames(4)
	print("marché (marchandises) : ", _min_of(mk))
	mk.call("close")
	await _frames(2)
	var inv: Node = load("res://scenes/inventory/inventory_screen.gd").call("open", main, m.id)
	await _frames(4)
	print("fiche (inventaire) : ", _min_of(inv))
	for n in inv.find_children("*", "Control", true, false):
		var c: Control = n
		if c.get_combined_minimum_size().y > 190 and c.get_combined_minimum_size().y < 800 and c.get_parent().get_parent() != null and (c.get_parent() is BoxContainer):
			print("   détail ", c.get_class(), " ", c.get_script().get_global_name() if c.get_script() != null else "", " ", c.get_combined_minimum_size())
	inv.call("set_tab", "perks")
	await _frames(4)
	print("fiche (talents) : ", _min_of(inv))
	inv.call("close")
	await _frames(2)
	var ws: Node = load("res://scenes/camp/workshop_screen.gd").open(main)
	await _frames(4)
	print("atelier : ", _min_of(ws))
	quit()
