extends SceneTree
## Capture de l'écran « Courbes de campagne » avec un historique fabriqué (fenêtre requise, pas de --headless) :
##   godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/capture_stats.gd -- <fichier.png> [camp|retraite|heritage]
## Utilise une partie temporaire (autosave coupée).

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://stats.png"
	var what: String = args[1] if args.size() > 1 else "stats"
	var game: Node = root.get_node("/root/Game")
	game.autosave = false
	game.new_game(5)
	var gold: int = 800
	for d in range(1, 121):
		gold = maxi(40, gold + (d * 37) % 90 - 30 + (160 if d % 11 == 0 else 0) - (110 if d % 17 == 0 else 0))
		StatsHistory.record(game.extras, d, {"gold": gold, "renown": d * 6 + (d * 13) % 25, "men": 5 + (d / 25) - (1 if d % 40 > 30 else 0), "wins": d / 7, "losses": d / 40, "fallen": d / 30, "food": 20})
	for t in [["kill", 9, 2], ["hunt", 3, 1], ["escort", 4, 0], ["delivery", 2, 1], ["assault", 2, 1], ["party", 5, 0], ["ambush", 1, 1]]:
		for i in int(t[1]):
			StatsHistory.record_battle(game.extras, {"kind": "contract", "type_contract": t[0]} if t[0] in ["kill", "hunt", "escort", "delivery"] else {"kind": t[0]}, true)
		for i in int(t[2]):
			StatsHistory.record_battle(game.extras, {"kind": "contract", "type_contract": t[0]} if t[0] in ["kill", "hunt", "escort", "delivery"] else {"kind": t[0]}, false)
	game.day = 120
	game.gold = gold
	game.stats["battles_won"] = 26
	game.stats["battles_lost"] = 5
	game.stats["kills"] = 118
	game.stats["men_fallen"] = 4
	game.stats["men_hired"] = 9
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 6:
		await process_frame
	if what == "camp":
		var a: Unit = game.roster[0]
		game.extras["camp_life"] = {"pending": {"id": "tale", "a": a.id, "b": -1, "day": 120, "stake": 0, "cost": 0}}
		load("res://scenes/camp/camp_life_screen.gd").open(main)
	elif what == "retraite":
		var v: Unit = game.roster[0]
		v.level = 9
		load("res://scenes/camp/legacy_screen.gd").open_retire(main, v.id)
	elif what == "heritage":
		var v2: Unit = game.roster[0]
		v2.level = 9
		game.retire_man(v2.id, "instructor", "weapon")
		load("res://scenes/camp/legacy_screen.gd").open_family(main)
	else:
		load("res://scenes/stats/stats_screen.gd").open(main)
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("capture : ", out)
	quit(0)
