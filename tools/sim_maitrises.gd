extends SceneTree
## Simulation INFORMATIVE des maîtrises (aucune règle d'équilibrage n'en dépend) :
##  1. statistiques « avant / après » sur des unités de test : toucher, dégâts par coup, PA par attaque, endurance, initiative, défense ;
##  2. batailles IA contre IA : pour chaque build de Data.BUILDS, la même compagnie avec et sans ses talents contre les mêmes ennemis.
##   godot --path . --headless -s res://tools/sim_maitrises.gd -- [--count 60]
## Code de sortie 1 seulement si une bataille se bloque ou viole un invariant.


func _init() -> void:
	var count: int = 60
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--count" and i + 1 < args.size():
			count = int(args[i + 1])
	var lib: RefCounted = load("res://tools/sim_maitrises_lib.gd").new()
	var bad: int = lib.run(count)
	quit(0 if bad == 0 else 1)
