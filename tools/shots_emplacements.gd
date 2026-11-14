extends SceneTree
## Capture de la fiche de personnage d'un homme équipé de bras et de jambes (poupée à 5 cases, rangée « Bras, jambes »),
## et d'une figurine en bataille avec la barre d'armure fusionnée.
##   godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_emplacements.gd -- <dossier>
func _init() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = a[0] if a.size() > 0 else "."
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(0, 0))
	await _frames(12)
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	game.new_game(5)
	var m: Unit = game.roster[0]
	m.level = 6
	m.weapon = "epee"
	m.shield = false
	m.head = "casque"
	m.body = "mailles"
	m.arm_h = m.head_armor_max()
	m.arm_b = m.body_armor_max() - 30
	m.arms = "epaulieres_fer"
	m.legs = "greves_genouilleres"
	m.arms_q = 1
	m.arm_a = m.arms_armor_max() - 25
	m.arm_l = m.legs_armor_max()
	game.inventory = [Loot.item("arms", "brassards_cuir"), Loot.item("arms", "manches_mailles"), Loot.item("legs", "chausses_mailles"), Loot.item("legs", "bandes_toile"),
		Loot.item("body", "gambison"), Loot.item("weapon", "hache")]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	var scr: Node = load("res://scenes/inventory/inventory_screen.gd").call("open", main, m.id)
	scr.call("set_tab", "inventory")
	await _frames(14)
	root.get_texture().get_image().save_png(dir.path_join("emplacements_fiche.png"))
	scr.call("close")
	await _frames(3)
	# figurines : toutes les familles sur une rangée
	var holder := Node2D.new()
	root.add_child(holder)
	var bg := ColorRect.new()
	bg.color = Color("5a4a36")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	root.move_child(bg, root.get_child_count() - 2)
	var sets: Array = [["none", "none"], ["manchettes", "bandes_toile"], ["brassards_cuir", "jambieres_cuir"], ["manicles_cloutees", "guetres_cloutees"],
		["manches_mailles", "chausses_mailles"], ["epaulieres_fer", "greves_fer"], ["garde_bras_plaques", "greves_genouilleres"]]
	for i in sets.size():
		var u: Unit = Unit.new()
		u.id = 40 + i
		u.side = "p"
		u.faction = "p"
		u.weapon = "epee"
		u.body = "gambison"
		u.head = "capuchon"
		u.arms = sets[i][0]
		u.legs = sets[i][1]
		var f: Figure = Figure.new().setup(u)
		f.scale *= 5.0
		f.position = Vector2(110 + i * 170, 380)
		holder.add_child(f)
	var u2: Unit = Unit.new()
	u2.id = 60
	u2.side = "p"
	u2.weapon = "arc"
	u2.body = "tunique"
	u2.arms = "brassards_cuir"
	u2.legs = "jambieres_cuir"
	var fb: Figure = Figure.new().setup(u2)
	fb.scale *= 5.0
	fb.position = Vector2(640, 640)
	holder.add_child(fb)
	await _frames(10)
	root.get_texture().get_image().save_png(dir.path_join("emplacements_figurines.png"))
	quit()
