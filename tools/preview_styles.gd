extends SceneTree
## Aperçu agrandi de chaque allure de brigand, clan d'orc et style de mort-vivant -> PNG.
## godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/preview_styles.gd -- "<fichier.png>"


func _initialize() -> void:
	var out: String = "preview_styles.png"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color("3a3228")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var x: float = 70.0
	for st in Figure.BRIGAND_STYLES:
		var f: Unit = Contracts.make_foe("brigand", rng)
		f.head = "none"
		f.body = "tunique" if st != "studded" else "gambison"
		f.shield = false
		for id in range(1, 400):
			f.id = id
			if Figure.brigand_style(f) == st:
				break
		var fv := UnitView.new().setup(f)
		fv.position = Vector2(x, 130)
		fv.scale = Vector2(2.6, 2.6)
		bg.add_child(fv)
		x += 200.0
	x = 90.0
	for c in 4:
		var o: Unit = Contracts.make_foe("orc_guerrier", rng)
		o.head = "none"
		o.body = "tunique"
		for id in range(1, 400):
			o.id = id
			if Figure.orc_clan(o) == c:
				break
		var ov := UnitView.new().setup(o)
		ov.position = Vector2(x, 400)
		ov.scale = Vector2(2.6, 2.6)
		bg.add_child(ov)
		x += 230.0
	x = 90.0
	for st in Figure.UNDEAD_STYLES:
		var s: Unit = Contracts.make_foe("squelette", rng)
		s.head = "none"
		s.shield = false
		for id in range(1, 400):
			s.id = id
			if Figure.undead_style(s) == st:
				break
		var sv := UnitView.new().setup(s)
		sv.position = Vector2(x, 640)
		sv.scale = Vector2(2.6, 2.6)
		bg.add_child(sv)
		x += 190.0
	for _f in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
