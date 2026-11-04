extends SceneTree
## Simulation de régression à grande échelle : batailles IA contre IA.
##   godot --path . --headless -s res://tools/sim_battles.gd -- [--count 300] [--seed 0] [--verbose]
## Reproduire un échec : ... -- --seed N --count 1 --verbose
## Code de sortie 1 s'il y a des échecs. Surveiller aussi la sortie pour tout « SCRIPT ERROR ».
## Les taux de victoire sont INFORMATIFS (aucun réglage d'équilibrage ici).


func _init() -> void:
	var count: int = 300
	var first: int = 0
	var verbose: bool = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--count":
				i += 1
				count = int(args[i])
			"--seed":
				i += 1
				first = int(args[i])
			"--verbose":
				verbose = true
		i += 1
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	var g: Node = lib.make_game(1)
	var failures: Array[String] = []
	var rounds_total: int = 0
	var by_faction: Dictionary = {}  # clé -> [victoires, total]
	var by_over: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	for n in count:
		var seed_value: int = first + n
		if verbose:
			print("seed %d" % seed_value)
		var r: Dictionary = lib.run_battle(g, seed_value)
		rounds_total += int(r["rounds"])
		by_over[r["over"]] = int(by_over.get(r["over"], 0)) + 1
		var fk: String = str(r["factions"])
		var fs: Array = by_faction.get(fk, [0, 0])
		fs[1] += 1
		if r["over"] == "win":
			fs[0] += 1
		by_faction[fk] = fs
		if not (r["errors"] as Array).is_empty():
			failures.append("graine %d (%s, danger %d, %d hommes, %s) : %s" % [seed_value, fk, r["danger"], r["men"], r["biome"], " | ".join(PackedStringArray(r["errors"]))])
	var secs: float = (Time.get_ticks_msec() - t0) / 1000.0
	print("\n=== sim_battles : %d batailles en %.1f s ===" % [count, secs])
	print("manches moyennes : %.1f" % (float(rounds_total) / maxf(1.0, count)))
	print("issues : %s" % str(by_over))
	for k in by_faction:
		print("  %-4s victoires joueur %d/%d (informatif)" % [k, by_faction[k][0], by_faction[k][1]])
	print("échecs : %d" % failures.size())
	for f in failures:
		print("  ✗ " + f)
	g.free()
	quit(0 if failures.is_empty() else 1)
