extends SceneTree
## Aperçu de la variété d'ennemis et de l'équipement visible -> PNG.
## godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/preview_variete.gd -- "<fichier.png>" [nu]
## Avec « nu » en second argument : les extras d'équipement sont coupés (comparaison avant/après est approchée par l'ancienne tenue).


func _initialize() -> void:
	var out: String = "preview_variete.png"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	await process_frame
	var game: Node = root.get_node("/root/Game")
	game.banner = {"primary": "3e526a", "secondary": "d8cfb8", "emblem": 1}
	var bg := ColorRect.new()
	bg.color = Color("3a3228")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var rows: Array = [["brigand", "archer", "balafre"], ["orc_jeune", "orc_guerrier", "berserker"], ["squelette", "squelette_archer", "necro"]]
	var y: float = 80.0
	var nid: int = 100
	for row in rows:
		for i in 12:
			var f: Unit = Contracts.make_foe(row[i % row.size()], rng)
			f.id = nid
			nid += 3
			var fv := UnitView.new().setup(f)
			fv.position = Vector2(60 + i * 100, y)
			fv.scale = Vector2(1.7, 1.7)
			bg.add_child(fv)
		y += 120.0
	# compagnie : étendard + armes de rechange + armures
	var kits: Array = [["hache", "epee", "lance", "brigandine", "heaume"], ["epee", "arc", "", "mailles", "casque"], ["hallebarde", "", "bouclier", "gambison", "none"],
		["arbalete", "", "", "gambison", "capuchon"], ["lance", "masse", "", "mailles", "casque"], ["arc", "hache", "", "tunique", "none"]]
	var roster: Array[Unit] = []
	game.roster = roster
	for i in kits.size():
		var k: Array = kits[i]
		var u := Unit.new()
		u.id = 10 + i
		u.side = "p"
		u.weapon = k[0]
		u.shield = false
		u.body = k[3]
		u.head = k[4]
		u.bag = [{}, {}]
		if k[1] != "":
			u.bag[0] = {"kind": "weapon", "key": k[1]}
		if k[2] == "bouclier":
			u.bag[1] = {"kind": "shield", "key": ""}
		roster.append(u)
		var uv := UnitView.new().setup(u)
		uv.position = Vector2(90 + i * 200, y + 20)
		uv.scale = Vector2(2.4, 2.4)
		bg.add_child(uv)
	for _f in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
