extends SceneTree
## Capture de contrôle : écran de talents (fenêtre requise).
##   godot --path . --screen 1 --resolution 1280x720 -s res://tools/shots_talents.gd -- <dossier>
var out_dir: String = "user://"

func _init() -> void:
	call_deferred("_run")

func _shot(n: String) -> void:
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(n + ".png"))

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	game.new_game(5)
	var m: Unit = game.roster[0]
	m.level = 5
	m.perk_points = 4
	m.perks.append_array(["bretteur", "garde_ferme"] as Array[String])
	m.perk_points -= 0
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = GameTheme.get_theme()
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = GameTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var scr: PerkScreen = PerkScreen.open(host, m)
	await _shot("p1_arbre")
	scr._on_click("vif")
	scr._on_click("briseur")
	scr._on_hover("spec_bouclier")
	await _shot("p2_choix")
	quit()
