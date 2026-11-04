extends SceneTree
## Aperçu des tenues d'élite, des boucliers de bannière et des emblèmes -> PNG.
## godot --path . --screen 1 --resolution 1280x720 -s res://tools/preview_elite.gd -- "<fichier.png>"


func _initialize() -> void:
	var out: String = "preview_elite.png"
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
	var heads: Array[String] = ["none", "capuchon", "casque", "heaume"]
	for i in 8:
		var u := Unit.new()
		u.id = 10 + i
		u.side = "p"
		u.weapon = "epee" if i % 2 == 0 else "hache"
		u.shield = i % 2 == 0
		u.body = ["gambison", "mailles", "brigandine", "tunique"][i % 4]
		u.head = heads[i % 4]
		u.level = 7 if i < 4 else 2
		var uv := UnitView.new().setup(u)
		uv.position = Vector2(90 + i * 150, 110)
		uv.scale = Vector2(2.2, 2.2)
		bg.add_child(uv)
	var foes: Array[String] = ["chef", "balafre", "berserker", "orc_chef", "brigand", "orc_guerrier"]
	for i in foes.size():
		var f: Unit = Contracts.make_foe(foes[i], RandomNumberGenerator.new())
		f.id = 40 + i
		var fv := UnitView.new().setup(f)
		fv.position = Vector2(110 + i * 190, 300)
		fv.scale = Vector2(2.4, 2.4)
		bg.add_child(fv)
	for i in Data.BANNER_EMBLEMS.size():
		var bv := BannerView.new({"primary": Data.BANNER_COLORS[i], "secondary": "f0e6c8" if i != 6 else "2b2622", "emblem": i}, Vector2(70, 94))
		bv.position = Vector2(40 + i * 150, 440)
		bg.add_child(bv)
		bv.size = Vector2(70, 94)
	for _f in 5:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
