extends SceneTree
## Audit de réactivité de l'interface : ouvre les grands écrans à plusieurs tailles de fenêtre et échelles d'interface, et signale les
## contrôles visibles qui sortent de la fenêtre (hors zones défilantes) ou dont la taille minimale dépasse la fenêtre.
##   godot --path . --screen 1 --resolution 1920x1080 --audio-driver Dummy -s res://tools/audit_responsive.gd -- [--scale 1.5] [--verbose]
## (la taille de fenêtre vient de --resolution : en mode sans fenêtre elle ne peut pas changer ; une exécution par résolution)
## Code de sortie 1 s'il y a des débordements.

var problems: Array = []
var verbose: bool = false
var scale: float = 1.0


func _init() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _has_scroll_ancestor(n: Node, top: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != top:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _overflow(label: String, node: Node, cfg: String) -> void:
	var vp: Rect2 = root.get_visible_rect()
	var bad: Array = []
	if node is Control:
		var m: Vector2 = (node as Control).get_combined_minimum_size()
		if m.x > vp.size.x + 1.0 or m.y > vp.size.y + 1.0:
			bad.append("taille minimale %dx%d > fenêtre %dx%d" % [m.x, m.y, vp.size.x, vp.size.y])
	for c in node.find_children("*", "Control", true, false):
		var ctl: Control = c
		if not ctl.is_visible_in_tree() or ctl.size.x < 4.0 or ctl.size.y < 4.0 or _has_scroll_ancestor(ctl, node):
			continue
		var r: Rect2 = ctl.get_global_rect()
		if r.position.x < vp.position.x - 3.0 or r.position.y < vp.position.y - 3.0 or r.end.x > vp.end.x + 3.0 or r.end.y > vp.end.y + 3.0:
			bad.append("%s%s déborde (%s)" % [ctl.get_class(), (" '" + (ctl as Control).name + "'"), str(r)])
			if bad.size() >= 6:
				break
	if not bad.is_empty():
		problems.append("[%s] %s : %s" % [cfg, label, " ; ".join(PackedStringArray(bad))])
	elif verbose:
		print("  ok [%s] %s" % [cfg, label])


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--verbose":
			verbose = true
		elif args[i] == "--scale" and i + 1 < args.size():
			scale = float(args[i + 1])
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	game.new_game(5)
	game.gold = 5000
	load("res://scenes/battle/battle.gd").speed = 0.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	for _once in 1:
		root.content_scale_factor = scale
		await _frames(6)
		var cfg: String = "fenêtre %dx%d, échelle %d%% (zone virtuelle %dx%d)" % [root.size.x, root.size.y, int(scale * 100.0), root.get_visible_rect().size.x, root.get_visible_rect().size.y]
		print("Configuration : ", cfg)
		# Écran de ville (par défaut)
		_overflow("ville", main, cfg)
		var opens: Array = [
			["marché", "res://scenes/market/market_screen.gd", "open", [main, 0], "close"],
			["inventaire", "res://scenes/inventory/inventory_screen.gd", "open", [main, game.roster[0].id], "close"],
			["atelier", "res://scenes/camp/workshop_screen.gd", "open", [main], "close"],
			["encyclopédie", "res://scenes/codex/codex_screen.gd", "open", [main], "close"],
			["journal", "res://scenes/chronicle/chronicle_screen.gd", "open", [main], "close"],
			["options", "res://scenes/menu/options_panel.gd", "open", [main], "close"],
		]
		for o in opens:
			var scr: GDScript = load(str(o[1]))
			if scr == null:
				continue
			var inst: Variant = scr.callv(str(o[2]), o[3])
			await _frames(4)
			if inst is Node and is_instance_valid(inst):
				_overflow(str(o[0]), inst, cfg)
				if (inst as Object).has_method(str(o[4])):
					inst.call(str(o[4]))
				elif inst is ModalOverlay:
					(inst as ModalOverlay).close()
			await _frames(2)
	print("Audit de réactivité : %d problème(s)" % problems.size())
	for p in problems:
		print("  ✗ ", p)
	quit(1 if not problems.is_empty() else 0)
