extends SceneTree
## Aperçu des nouvelles armes : godot --path . -s res://tools/preview_armes.gd -- "<fichier.png>"

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "armes.png"
	var bg := ColorRect.new()
	bg.color = Color("3a3228")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var weapons: Array[String] = ["arbalete", "hallebarde", "fleau", "javelot"]
	for row in 2:
		for i in weapons.size():
			var u := Unit.new()
			u.id = 1 + i + row * 10
			u.side = "p" if row == 0 else "e"
			u.faction = "p" if row == 0 else "u"
			u.weapon = weapons[i]
			u.shield = (weapons[i] == "fleau" or weapons[i] == "javelot")
			u.body = "gambison"
			u.head = "casque"
			var uv := UnitView.new().setup(u)
			uv.position = Vector2(200 + i * 280, 250 + row * 300)
			uv.scale = Vector2(4, 4)
			bg.add_child(uv)
	for _f in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
