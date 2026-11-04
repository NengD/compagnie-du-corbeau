extends SceneTree
## Capture de l'écran d'inventaire (fenêtre requise). godot --path . --screen 1 --resolution 1280x720 -s res://tests/shot_inventaire.gd -- <dossier>

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.new_game(5)
	root.size = Vector2i(1280, 720)
	game.inventory = [Loot.item("weapon", "hache"), Loot.item("head", "casque"), Loot.item("shield"), Loot.item("body", "mailles"), Uniques.item_of("u_epee_corbeau"), Loot.item("weapon", "arc")]
	game.inventory[0]["dur"] = 30
	game.roster[0].bag[0] = {"kind": "weapon", "key": "lance"}
	game.roster[0].head = "capuchon"
	game.roster[0].arm_h = 12
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var inv: Node = load("res://scenes/inventory/inventory_screen.gd").call("open", main)
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("inv1.png"))
	var mailles: int = game.inventory.find_custom(func(it: Dictionary) -> bool: return it.get("key", "") == "mailles")
	inv.call("hover", Inventory.in_stash(mailles))
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("inv2.png"))
	quit(0)
