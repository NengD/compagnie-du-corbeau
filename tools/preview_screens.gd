extends SceneTree
## Aperçu des écrans Bannière et Succès (nécessite l'autoload Game : chargés au runtime) -> PNG.
## godot --path . --screen 1 --resolution 1280x720 -s res://tools/preview_screens.gd -- "<dossier>"


func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	await process_frame
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.new_game(5)
	game.stat_add("kills", 120)
	game.stat_add("battles_won", 3)
	game.check_achievements()
	var host := Control.new()
	host.theme = load("res://scenes/ui/game_theme.gd").get_theme()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = Color("1c1915")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var toast: CanvasLayer = load("res://scenes/achievements/achievement_toast.gd").new()
	host.add_child(toast)
	var m: Object = load("res://scenes/banner/banner_screen.gd").open(host)
	toast.show_achievement("kills_100")
	for _i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(dir + "/banner.png")
	m.close()
	m = load("res://scenes/achievements/achievements_screen.gd").open(host)
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(dir + "/achievements.png")
	quit()
