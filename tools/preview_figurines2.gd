extends SceneTree
## Aperçu « figurines 2 » : silhouettes variées, cavalier, poses d'attaque et chute -> PNG.
## godot --path . --screen 1 --audio-driver Dummy -s res://tools/preview_figurines2.gd -- "<dossier>" [silhouettes|cavalier|sequence]

func _mk(id: int, side: String, weapon: String, body: String, head: String, shield: bool, bg: String = "") -> Unit:
	var u := Unit.new()
	u.id = id
	u.side = side
	u.faction = "p" if side == "p" else "b"
	u.weapon = weapon
	u.body = body
	u.head = head
	u.shield = shield
	u.background = bg
	u.hp_max = 60.0
	u.hp = 60.0
	return u


func _place(parent: Node, u: Unit, pos: Vector2, k: float = 2.6) -> UnitView:
	var v := UnitView.new().setup(u)
	v.position = pos
	v.scale = Vector2(k, k)
	parent.add_child(v)
	return v


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "."
	var mode: String = args[1] if args.size() > 1 else "silhouettes"
	var bg := ColorRect.new()
	bg.color = Color("3a3228")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	if mode == "silhouettes":
		var bgs: Array[String] = ["Bûcheron", "Braconnier", "Fermier", "Mendiant", "", "Reître"]
		var ws: Array[String] = ["epee", "lance", "hache", "gourdin", "arc", "masse"]
		for row in 2:
			for i in 6:
				var u: Unit = _mk(10 + row * 6 + i, "p", ws[i], ["gambison", "mailles", "tunique", "brigandine", "tunique", "gambison"][i], ["none", "casque", "capuchon", "heaume", "none", "casque"][(i + row) % 6], i % 2 == 0 and ws[i] != "arc", bgs[i])
				_place(bg, u, Vector2(120 + i * 205, 190 + row * 280), 3.0)
	elif mode == "cavalier":
		var rider: Unit = _mk(21, "e", "lance", "mailles", "casque", false)
		rider.foe_key = "cavalier_brigand"
		var rider2: Unit = _mk(22, "e", "epee", "gambison", "capuchon", true)
		rider2.foe_key = "cavalier_brigand"
		var foot: Unit = _mk(23, "e", "hache", "mailles", "casque", true)
		var wolf: Unit = _mk(24, "e", "lance", "tunique", "none", false)
		wolf.faction = "m"
		wolf.sprite = "wolf_rider"
		var ally: Unit = _mk(25, "p", "epee", "mailles", "casque", true)
		var xs: Array = [rider, rider2, foot, wolf, ally]
		for i in xs.size():
			_place(bg, xs[i], Vector2(150 + i * 250, 300), 3.4)
		_place(bg, rider, Vector2(150, 560), 1.0)
		_place(bg, ally, Vector2(260, 560), 1.0)
		_place(bg, foot, Vector2(370, 560), 1.0)
	else:
		# images fixes d'une séquence : préparation, frappe, retour ; parade ; chute en trois temps (variables privées de UnitView)
		var steps: Array = [
			{"w": "masse", "off": Vector2(-4, -4), "lean": -0.17, "t": "levée"},
			{"w": "masse", "off": Vector2(11, 0), "lean": 0.2, "t": "frappe"},
			{"w": "arc", "off": Vector2(-2.5, 0), "lean": -0.08, "t": "tension"},
			{"w": "epee", "off": Vector2(-2, 0), "lean": 0.0, "t": "parade", "sq": 0.035},
		]
		for i in steps.size():
			var u: Unit = _mk(30 + i, "p", steps[i]["w"], "gambison", "casque", steps[i]["w"] == "epee")
			var v: UnitView = _place(bg, u, Vector2(120 + i * 150, 220), 2.6)
			v._off = steps[i]["off"]
			v._lean = steps[i]["lean"]
			v._squash = float(steps[i].get("sq", 0.0))
		var death: Array = [[0.0, 0.0, 0.0, Vector2.ZERO], [1.0, 0.14, 0.0, Vector2(-1.5, 1)], [0.4, 0.0, 0.5, Vector2(-3, 3)], [0.0, 0.0, 1.0, Vector2(-4.5, 3)]]
		for i in death.size():
			var u2: Unit = _mk(40 + i, "p", "epee", "mailles", "casque", true)
			var v2: UnitView = _place(bg, u2, Vector2(120 + i * 150, 520), 2.6)
			v2._kneel = death[i][0]
			v2._lean = death[i][1]
			v2._fall = death[i][2]
			v2._off = death[i][3]
	for _f in 5:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(dir.path_join("figurines2_%s.png" % mode))
	quit()
