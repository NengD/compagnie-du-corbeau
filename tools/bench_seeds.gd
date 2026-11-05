extends SceneTree
## Vérifie la robustesse de la génération du grand monde sur beaucoup de graines (comptes, factions, contiguïté, connectivité).
## godot --headless -s res://tools/bench_seeds.gd -- <nombre de graines>
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var n: int = int(a[0]) if a.size() > 0 else 30
	var bad: int = 0
	var t_min: int = 99999
	var t_max: int = 0
	var t_sum: int = 0
	for sd in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + sd * 37
		var t0: int = Time.get_ticks_msec()
		var w: World = World.generate(rng, 0)
		var ms: int = Time.get_ticks_msec() - t0
		t_min = mini(t_min, ms)
		t_max = maxi(t_max, ms)
		t_sum += ms
		var problems: PackedStringArray = []
		var cities: int = 0
		for s in w.settlements:
			if s["kind"] == "city":
				cities += 1
			if w.find_path(w.settlement_pos(w.settlements[0]), w.settlement_pos(s)).is_empty():
				problems.append("lieu inaccessible " + str(s["name"]))
		if w.settlements.size() < 22 or cities < 6 or w.settlements.size() - cities < 16:
			problems.append("comptes %d lieux %d villes" % [w.settlements.size(), cities])
		var counts: Dictionary = Territory.place_counts(w)
		for k in Factions.playable_keys():
			if int(counts.get(k, 0)) < 3 or int(counts.get(k, 0)) > 6:
				problems.append("%s : %d lieux" % [k, int(counts.get(k, 0))])
		var comps: Dictionary = Territory.components(Territory.labels(w, 2))
		for k in comps:
			if k != "libres" and (comps[k] as Array).size() != 1:
				problems.append("territoire %s en %d morceaux" % [k, (comps[k] as Array).size()])
		if w.sites.size() < 10:
			problems.append("sites %d" % w.sites.size())
		if w.pois.size() < 28:
			problems.append("pois %d" % w.pois.size())
		for q in w.pois:
			if w.find_path(w.player_pos, w.poi_pos(q)).is_empty():
				problems.append("poi inaccessible")
		if not problems.is_empty():
			bad += 1
			print("graine %d : %s" % [rng.seed, "; ".join(problems)])
	print("%d graines, %d à problème ; génération min %d / moy %d / max %d ms" % [n, bad, t_min, t_sum / n, t_max])
	quit()
