extends SceneTree
## Captures des ambiances de région (décor de plateau) -> PNG dans le dossier donné.
## godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_graphismes.gd -- "<dossier>"

const BIOME_OF := {"meadow": "plain", "farmland": "plain", "dense_forest": "forest", "marsh": "water", "snow": "plain", "ruins": "plain",
	"bridge": "water", "rocky": "hills", "desert": "plain", "heath": "hills"}


func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color("2a241c")
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var n: int = 0
	var page: int = 0
	var boards: Array = []
	for kind in RegionLook.KINDS:
		var biome: String = BIOME_OF[kind]
		var rng := RandomNumberGenerator.new()
		rng.seed = 11 + n
		var foes: Array = ["brigand", "brigand", "archer"]
		var c: Dictionary = {"kind": "contract", "type": "b", "type_contract": "kill", "d": 2, "foes": foes, "title": "T", "desc": "", "days": 1,
			"employer": "x", "pay": 400, "biome": biome, "battle_type": "pitched"}
		var party: Array = []
		for i in 4:
			party.append(Contracts.make_merc(Data.BG.keys()[i], rng, []))
		var st: BattleState = BattleState.create(c, party, rng)
		var bv := BoardView.new()
		bg.add_child(bv)
		bv.setup(st)
		var look: Dictionary = RegionLook.derive(biome, "", "b", 7 + n)
		look["kind"] = kind
		look["wash"] = RegionLook.SPECS[kind]["wash"]
		look["features"] = RegionLook.SPECS[kind]["features"]
		bv.set_meta("rl_key", st.get_instance_id())
		bv.set_meta("rl_look", look)
		bv.scale = Vector2(0.9, 0.9)
		bv.position = Vector2(30 + (n % 2) * 620, 60 + ((n % 4) / 2) * 330)
		var lb := Label.new()
		lb.text = "%s (%s)" % [kind, biome]
		lb.position = bv.position + Vector2(0, -30)
		bg.add_child(lb)
		boards.append(bv)
		n += 1
		if n % 4 == 0 or n == RegionLook.KINDS.size():
			for _f in 5:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/ambiance_%d.png" % [dir, page])
			page += 1
			for b in boards:
				b.queue_free()
			for ch in bg.get_children():
				if ch is Label:
					ch.queue_free()
			boards.clear()
			await process_frame
	quit()
