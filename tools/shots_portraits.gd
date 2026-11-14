extends SceneTree
## Portraits des chefs de faction et des porteurs d'objets uniques -> PNG.
## godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_portraits.gd -- "<fichier.png>"


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "portraits.png"
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color("2a241c")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var x: float = 30.0
	for fac in Data.FACTION_LEADER:
		var key: String = Data.FACTION_LEADER[fac]
		var plain: String = {"b": "brigand", "g": "goule", "o": "orc_guerrier", "u": "squelette", "m": "ogre"}[fac]
		for k in [plain, key]:
			var u: Unit = Contracts.make_foe(k, rng)
			u.id = 77
			var p := PortraitView.new(u, 120)
			p.position = Vector2(x, 40 if k == key else 200)
			bg.add_child(p)
			p.size = Vector2(120, 120)
			p._fit()
			p.size = Vector2(120, 120)
			p._fit()
		x += 130.0
	for i in 3:
		var u2 := Unit.new()
		u2.id = 30 + i
		u2.side = "p"
		u2.faction = "p"
		u2.weapon = ["u_epee_corbeau", "u_arc_ronce", "hache"][i]
		u2.head = ["u_casque_loup", "none", "u_heaume_veilleur"][i]
		u2.body = "mailles"
		var p2 := PortraitView.new(u2, 120)
		p2.position = Vector2(30 + i * 130, 400)
		bg.add_child(p2)
		p2.size = Vector2(120, 120)
		p2._fit()
		p2.size = Vector2(120, 120)
		p2._fit()
	for _f in 5:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
