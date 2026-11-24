extends SceneTree
## Couverture MESURÉE À L'EXÉCUTION du journal de bataille : joue des batailles IA contre IA (tools/sim_lib.gd), traduit chaque
## ligne du journal en anglais et signale celles qui contiennent encore du français (mots-outils ou lettres accentuées).
##   godot --headless -s res://tools/translation_runtime.gd -- [--count 60] [--list 25]
## Complète tools/translation_report.gd, qui ne voit que les chaînes écrites dans le code.

## Mots français qui trahissent une ligne non traduite (les accents seuls ne comptent pas : les noms propres en portent).
const FRENCH: String = "(?i)\\b(le|la|les|de|du|des|une|est|sont|sur|dans|avec|pour|qui|son|sa|ses|sous|lève|voit|tombe|tomber|coup|boucliers?|chef|armure|touche|manque)\\b"


func _init() -> void:
	var count: int = 60
	var list_n: int = 25
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--count":
			count = int(args[i + 1])
		elif args[i] == "--list":
			list_n = int(args[i + 1])
	I18n.apply(1)
	var re := RegEx.create_from_string(FRENCH)
	var names := RegEx.create_from_string("\\b(le|la|l'|du|de la|de) [A-ZÀ-Ý][A-Za-zÀ-ÿ'-]+|\\b[A-ZÀ-Ý][a-zà-ÿ]+-[A-ZÀ-Ýa-zà-ÿ-]+")
	var lib: RefCounted = load("res://tools/sim_lib.gd").new()
	var g: Node = lib.make_game(1)
	var total: int = 0
	var french: int = 0
	var freq: Dictionary = {}
	for n in count:
		var seed_value: int = 1000 + n
		var p: Dictionary = lib.params_for(seed_value)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var party: Array = lib.make_party(rng, int(p["men"]))
		var contract: Dictionary = lib.make_contract(p["factions"], int(p["danger"]), str(p["biome"]), str(p["btype"]))
		var s: BattleState = BattleState.create(contract, party, rng, 3, 1.0, "normal")
		var r: Dictionary = lib.play(s, seed_value % 2 == 0)
		var fin: BattleState = r["state"]
		for l in fin.log_lines:
			var raw: String = str(l["t"])
			var en: String = names.sub(I18n.t(raw), "", true)  ## les surnoms des recrues (« le Blême ») ne comptent pas
			total += 1
			if re.search(en) != null:
				french += 1
				var key: String = en.substr(0, 90)
				freq[key] = int(freq.get(key, 0)) + 1
	print("Journal de bataille (%d batailles) : %d lignes, %d encore en français (%.1f %% traduites)" % [count, total, french, 100.0 * float(total - french) / maxf(1.0, float(total))])
	var keys: Array = freq.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(freq[a]) > int(freq[b]))
	for i in mini(list_n, keys.size()):
		print("  %4d × %s" % [freq[keys[i]], keys[i]])
	g.free()
	quit(0)
