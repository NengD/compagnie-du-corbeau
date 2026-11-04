extends SceneTree
## Captures de contrôle de l'arbre de talents (fenêtre requise) : 0, 3 et 8 talents appris, plus une infobulle.
##   godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_talents.gd -- <dossier> [suffixe]
var out_dir: String = "user://"
var suffix: String = ""

const EIGHT: Array[String] = ["bretteur", "vif", "parade", "briseur", "spec_epee", "garde_ferme", "cran", "dur_a_cuire"]


func _init() -> void:
	call_deferred("_run")


func _shot(n: String) -> void:
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(n + suffix + ".png"))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		suffix = "_" + args[1]
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	game.new_game(5)
	var m: Unit = game.roster[0]
	m.level = 9
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = GameTheme.get_theme()
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = GameTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	for n in [0, 3, 8]:
		m.perks.assign(EIGHT.slice(0, n))
		m.perk_points = [3, 2, 1][[0, 3, 8].find(n)]
		var scr: PerkScreen = PerkScreen.open(host, m)
		if n == 3:
			scr.tree.select("lame_affutee")
		await _shot("perk_%d" % n)
		if n == 8:
			scr.tree.select("nuque_protegee")
			await _shot("perk_8_select")
		scr.close()
		await process_frame
	quit()
