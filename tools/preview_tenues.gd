extends SceneTree
## Aperçu des tenues, de l'usure et des monstres -> PNG.
## godot --path . --screen 1 --resolution 1280x720 -s res://tools/preview_tenues.gd -- "<fichier.png>" [outfits|wear|monsters]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "tenues.png"
	var mode: String = args[1] if args.size() > 1 else "outfits"
	var bg := ColorRect.new()
	bg.color = Color("3a3228")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var bodies: Array[String] = ["tunique", "gambison", "mailles", "brigandine"]
	var heads: Array[String] = ["none", "capuchon", "casque", "heaume"]
	if mode == "outfits":
		for row in 3:
			for i in 7:
				var u := Unit.new()
				u.id = 100 + row * 7 + i * 3
				u.side = "p" if row != 2 else "e"
				u.weapon = ["epee", "hache", "lance", "masse", "arc", "gourdin", "fourche"][i]
				u.shield = i % 3 == 0
				u.body = bodies[(i + row) % 4]
				u.head = heads[(i * 2 + row) % 4] if row != 1 else "none"
				var uv := UnitView.new().setup(u)
				uv.position = Vector2(100 + i * 170, 130 + row * 220)
				uv.scale = Vector2(2.6, 2.6)
				bg.add_child(uv)
	elif mode == "wear":
		for row in 2:
			for i in 3:  # usure 0, 1, 2
				var u := Unit.new()
				u.id = 7 + row
				u.side = "p"
				u.weapon = ["epee", "hache"][row]
				u.shield = true
				u.body = "mailles"
				u.head = "casque"
				u.arm_b = [130, 70, 20][i]
				u.arm_h = [90, 50, 15][i]
				u.shield_dur = [-1, 10, 3][i]
				u.weapon_dur = [-1, 8, 0][i]
				var uv := UnitView.new().setup(u)
				uv.position = Vector2(150 + i * 300 + row * 0, 160 + row * 260)
				uv.scale = Vector2(3.6, 3.6)
				bg.add_child(uv)
	else:
		var defs: Array = [["wolf", false], ["wolf", true], ["wolf_rider", false], ["wolf_rider", true], ["ogre", false], ["ogre", true], ["troll", false], ["troll", true]]
		for i in defs.size():
			for v in 2:
				var u := Unit.new()
				u.id = 3 + v * 5 + i
				u.side = "e"
				u.faction = "m"
				u.sprite = defs[i][0]
				u.leader = defs[i][1]
				u.weapon = "gourdin"
				var uv := UnitView.new().setup(u)
				uv.position = Vector2(110 + (i % 4) * 300 + v * 130 - 40, 140 + (i / 4) * 330)
				uv.scale = Vector2(2.4, 2.4)
				bg.add_child(uv)
	for _f in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
