extends SceneTree
## Captures de contrôle des maîtrises (fenêtre requise) : arbre avec un build appris, une maîtrise sélectionnée, et l'infobulle riche.
##   godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_maitrises.gd -- <dossier> [suffixe]
var out_dir: String = "user://"
var suffix: String = ""


func _init() -> void:
	call_deferred("_run")


func _shot(n: String) -> void:
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(n + suffix + ".png"))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		suffix = "_" + args[1]
	if suffix.contains("1440"):  # une vraie capture 2K : la fenêtre est agrandie (voir shots_icones.gd)
		DisplayServer.window_set_size(Vector2i(2560, 1440))
		DisplayServer.window_set_position(Vector2i(0, 0))
		for i in 12:
			await process_frame
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	game.new_game(5)
	var m: Unit = game.roster[0]
	m.level = 11
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = GameTheme.get_theme()
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = GameTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	# 1. Duelliste à l'épée (8 talents appris, 2 points restants)
	var keys: Array = []
	for st in Data.BUILDS[0]["steps"]:
		keys.append(str(st[0]))
	m.weapon = "epee"
	m.head = "capuchon"
	m.body = "tunique"
	m.perks.assign(keys.slice(0, 8))
	m.perk_points = 2
	var scr: PerkScreen = PerkScreen.open(host, m)
	await _shot("maitrises_duelliste")
	scr.tree.select("frappe_vive")
	await _shot("maitrises_selection")
	# Infobulle riche d'une maîtrise (active), posée sur la capture
	var ic: PerkIcon = scr.tree.icon_of("spec_epee")
	var tip: Control = ic._make_custom_tooltip("") as Control
	var layer := CanvasLayer.new()
	layer.layer = 200
	root.add_child(layer)
	layer.add_child(tip)
	tip.position = Vector2(420, 380)
	await _shot("maitrises_infobulle_active")
	layer.queue_free()
	m.weapon = "hache"
	var tip2: Control = ic._make_custom_tooltip("") as Control
	var layer2 := CanvasLayer.new()
	layer2.layer = 200
	root.add_child(layer2)
	layer2.add_child(tip2)
	tip2.position = Vector2(420, 380)
	await _shot("maitrises_infobulle_inactive")
	layer2.queue_free()
	scr.close()
	await process_frame
	# 2. Rempart (bouclier + plates) : toutes les familles défensives
	var keys2: Array = []
	for st in Data.BUILDS[11]["steps"]:
		keys2.append(str(st[0]))
	m.weapon = "epee"
	m.shield = true
	m.head = "heaume"
	m.body = "brigandine"
	m.perks.assign(keys2)
	m.perk_points = 0
	var scr2: PerkScreen = PerkScreen.open(host, m)
	await _shot("maitrises_rempart")
	scr2.close()
	quit()
