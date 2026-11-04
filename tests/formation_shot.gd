extends SceneTree
## Capture du composant FormationPanel dans un hôte : godot --path . --screen 1 --audio-driver Dummy -s res://tests/formation_shot.gd -- "<dossier>" [largeur hauteur]
var game: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game = root.get_node("/root/Game")
	game.autosave = false
	game.new_game(5)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "user://"
	var w: int = int(args[1]) if args.size() > 2 else 1280
	var h: int = int(args[2]) if args.size() > 2 else 720
	var vs: Vector2 = root.get_visible_rect().size  # taille logique (échelle d'interface comprise)
	var lw: float = vs.x
	var lh: float = vs.y
	var hire: Array = ["hache", "arc", "lance", "masse", "arc"]
	for k in hire:
		var u: Unit = Contracts.make_merc("fermier", game.rng, [])
		u.weapon = k
		game.roster.append(u)
	game.formation_slots()
	game.set_formation_slot(game.roster[0].id, Formation.FRONT_START + 3)
	var host := Control.new()
	host.size = Vector2(lw, lh)
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = Color("14110d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var panel: Control = load("res://scenes/inventory/formation_panel.gd").new()
	panel.position = Vector2(lw * 0.05, lh * 0.1)
	panel.size = Vector2(lw * 0.9, lh * 0.75)
	host.add_child(panel)
	panel.call("set_selected", game.roster[1].id)
	for i in 6:
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/formation_%dx%d.png" % [dir, w, h])
	print("capture ok %dx%d" % [w, h])
	quit()
