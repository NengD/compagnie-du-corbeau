extends SceneTree
## Chronomètre la génération du grand monde et de la texture de carte, vérifie les factions et sauvegarde un aperçu en PNG.
## godot --headless -s res://tools/bench_world.gd -- <graine> <fichier.png>
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var seed_v: int = int(a[0]) if a.size() > 0 else 5
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var t0: int = Time.get_ticks_msec()
	var w: World = World.generate(rng, 0)
	var t1: int = Time.get_ticks_msec()
	print("génération monde : %d ms ; lieux %d ; sites %d ; pois %d ; bandes %d" % [t1 - t0, w.settlements.size(), w.sites.size(), w.pois.size(), w.parties.size()])
	var cnt: Dictionary = {}
	for t in w.terrain:
		cnt[t] = int(cnt.get(t, 0)) + 1
	print("terrain ", cnt)
	print("factions ", Territory.place_counts(w))
	var lab: Dictionary = Territory.labels(w, 2)
	var comps: Dictionary = Territory.components(lab)
	for k in comps:
		print("  ", k, " composantes ", (comps[k] as Array).size())
	var t2: int = Time.get_ticks_msec()
	var enc: String = World.encode_terrain(w.terrain)
	print("terrain compressé : %d caractères" % enc.length())
	for px in [4, 6]:
		var b: int = Time.get_ticks_msec()
		MapTerrain._ck = 0
		MapTerrain.textures(w, px)
		print("texture px=%d : %d ms" % [px, Time.get_ticks_msec() - b])
	if a.size() > 1:
		var img := Image.create(w.gw, w.gh, false, Image.FORMAT_RGB8)
		var cols: Array = [Color("8fae5a"), Color("3e6b34"), Color("a89a60"), Color("3a6a9a"), Color("6e6a62"), Color("c9b070"), Color("78a8c8"), Color("6a7a4a"), Color("e8eef0")]
		for y in w.gh:
			for x in w.gw:
				img.set_pixel(x, y, cols[w.terrain[y * w.gw + x]])
		for s in w.settlements:
			var c: Vector2i = w.cell_of(w.settlement_pos(s))
			img.set_pixel(c.x, c.y, Color(1, 0, 0) if bool(s.get("capital", false)) else Color(1, 1, 0))
		for s in w.sites:
			var c2: Vector2i = w.cell_of(w.settlement_pos(s))
			img.set_pixel(c2.x, c2.y, Color(0, 0, 0))
		img.resize(w.gw * 5, w.gh * 5, Image.INTERPOLATE_NEAREST)
		img.save_png(a[1])
	quit()
