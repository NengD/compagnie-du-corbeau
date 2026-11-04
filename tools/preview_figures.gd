extends SceneTree
## Aperçu des figurines : planche de plusieurs équipements -> PNG.
## godot --path . -s res://tools/preview_figures.gd -- "<fichier.png>"

func _initialize() -> void:
	var out: String = "preview.png"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var bg := ColorRect.new()
	bg.color = Color("3a3228")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var mode: String = args[1] if args.size() > 1 else ""
	if mode == "factions":
		var units: Array[Unit] = faction_units()
		for i in units.size():
			var fv := UnitView.new().setup(units[i])
			fv.position = Vector2(100 + (i % 6) * 200, 150 + (i / 6) * 260)
			fv.scale = Vector2(3.0, 3.0)
			bg.add_child(fv)
			if i % 6 == 0 or true:
				var pv := PortraitView.new(units[i], 90)
				pv.position = Vector2(fv.position.x + 50, fv.position.y + 50 if false else fv.position.y - 130)
				bg.add_child(pv)
				pv.size = Vector2(90, 90)
				pv._fit()
		for _f in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(out)
		quit()
		return
	var weapons: Array[String] = ["gourdin", "fourche", "lance", "hache", "masse", "epee", "arc"]
	var bodies: Array[String] = ["tunique", "gambison", "mailles", "brigandine"]
	var heads: Array[String] = ["none", "capuchon", "casque", "heaume"]
	var id: int = 1
	for row in 3:
		for i in 7:
			var u := Unit.new()
			u.id = id
			id += 1
			u.side = "p" if row != 1 else "e"
			u.weapon = weapons[i]
			u.shield = (i % 2 == 0)
			u.body = bodies[(i + row) % 4]
			u.head = heads[(i * 3 + row) % 4] if row > 0 else "none"
			var uv := UnitView.new().setup(u)
			uv.position = Vector2(100 + i * 170, 130 + row * 190)
			uv.scale = Vector2(2.4, 2.4)
			bg.add_child(uv)
	# portraits + goules
	for i in 6:
		var u := Unit.new()
		u.id = 40 + i
		u.body = bodies[i % 4]
		u.head = "none"
		u.weapon = "epee"
		var p := PortraitView.new(u, 110)
		p.position = Vector2(20 + i * 120, 590)
		bg.add_child(p)
		p.size = Vector2(110, 110)
		p._fit()
	for i in 2:
		var g := Unit.new()
		g.id = 60 + i
		g.faction = "g"
		g.side = "e"
		g.weapon = "griffesL" if i == 1 else "griffes"
		var gv := UnitView.new().setup(g)
		gv.position = Vector2(900 + i * 160, 640)
		gv.scale = Vector2(2.4, 2.4)
		bg.add_child(gv)
	for c in bg.get_children():
		if c is PortraitView:
			print(c.size, c._holder.position, c._holder.scale)
			break
	for _f in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()


## Orcs et morts-vivants (ajoutés en bas de planche par le mode "factions")
static func faction_units() -> Array[Unit]:
	var list: Array[Unit] = []
	var spec: Array = [
		["o", "hache", true, "casque", "mailles", false], ["o", "masse", false, "none", "brigandine", false],
		["o", "gourdin", false, "capuchon", "tunique", false], ["o", "epee", true, "none", "gambison", true],
		["u", "epee", true, "casque", "none", false], ["u", "lance", false, "none", "none", false],
		["u", "hache", true, "heaume", "none", false], ["u", "arc", false, "none", "none", false],
		["u", "griffes", false, "none", "none", false], ["u", "griffesL", false, "none", "none", false],
		["u", "gourdin", false, "capuchon", "none", false], ["o", "fourche", false, "none", "tunique", false],
	]
	var id: int = 100
	for sp in spec:
		var u := Unit.new()
		u.id = id
		id += 1
		u.faction = sp[0]
		u.side = "e"
		u.weapon = sp[1]
		u.shield = sp[2]
		u.head = sp[3]
		u.body = sp[4]
		u.leader = sp[5]
		list.append(u)
	return list
