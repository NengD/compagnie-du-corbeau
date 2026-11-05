extends SceneTree
## Charge un vrai fichier de sauvegarde (copie) et vérifie qu'il se joue comme avant. -- <chemin>
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(a[0]))
	var g: Node = load("res://autoload/Game.gd").new()
	g.autosave = false
	g.from_dict(d)
	var w: World = g.world
	print("monde %dx%d grand=%s lieux=%d sites=%d pois=%d bandes=%d jour=%d" % [w.gw, w.gh, w.grand, w.settlements.size(), w.sites.size(), w.pois.size(), w.parties.size(), g.day])
	var owners: Dictionary = {}
	for s in w.settlements:
		owners[str(s.get("owner", ""))] = true
	print("propriétaires ", owners.keys())
	for i in 40:
		g.map_step(0.2)
	print("ok, jour ", g.day)
	quit()
