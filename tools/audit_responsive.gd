extends SceneTree
## Audit de réactivité de l'interface : ouvre TOUS les grands écrans à plusieurs tailles de fenêtre et échelles d'interface, et signale
## les contrôles visibles qui sortent de la zone virtuelle (hors zones défilantes), en tenant compte de la mise à l'échelle des FitBox.
##   godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/audit_responsive.gd -- \
##         [--sizes 1280x720,1024x768] [--scales 0.75,1,1.25,1.5] [--only texte] [--verbose]
## La taille de la fenêtre est forcée après le démarrage (DisplayServer.window_set_size) et vérifiée dans la sortie ; sans option,
## la taille courante et l'échelle 100 % sont utilisées. Les réglages (user://settings.cfg) ne sont pas écrits (Settings.persist = false).
## Code de sortie 1 s'il y a des débordements.

var problems: Array = []
var verbose: bool = false
var only: String = ""
var game: Node
var main: Node
var _cfg: String = ""
var _min_fit: float = 1.0
var _count: int = 0
var shots: String = ""  ## dossier des captures (--shots) : écrans clés seulement
const SHOT_LABELS: Array = ["marché", "inventaire", "options", "ville / onglet Contrats", "carte", "bataille", "menu principal"]


func _init() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Une zone défilante légitime : ScrollContainer ordinaire, ou FitBox qui a atteint son échelle plancher.
func _scrolls(n: Node, top: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != top.get_parent():
		if p is FitBox:
			if (p as FitBox).scale_now <= FitBox.MIN_SCALE + 0.001:
				return true
		elif p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _fit_scale(n: Node) -> float:
	var s: float = 1.0
	var p: Node = n
	while p != null:
		if p is FitBox:
			s = minf(s, (p as FitBox).scale_now)
		p = p.get_parent()
	return s


func _faded(n: Node) -> bool:
	var p: Node = n
	while p != null:
		if p is CanvasItem and (p as CanvasItem).modulate.a <= 0.01:
			return true
		p = p.get_parent()
	return false


func _grect(c: Control) -> Rect2:
	var t: Transform2D = c.get_global_transform()
	var pts: Array = [t * Vector2.ZERO, t * Vector2(c.size.x, 0.0), t * c.size, t * Vector2(0.0, c.size.y)]
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


func _check(label: String, node: Node) -> void:
	if only != "" and not label.contains(only):
		return
	_count += 1
	var vp: Rect2 = root.get_visible_rect()
	var bad: Array = []
	for c in node.find_children("*", "Control", true, false):
		var ctl: Control = c
		if not ctl.is_visible_in_tree() or ctl.size.x < 4.0 or ctl.size.y < 4.0 or _scrolls(ctl, node) or _faded(ctl):
			continue
		if ctl is FitBox or ctl is ColorRect:
			continue
		var r: Rect2 = _grect(ctl)
		if r.position.x < vp.position.x - 3.0 or r.position.y < vp.position.y - 3.0 or r.end.x > vp.end.x + 3.0 or r.end.y > vp.end.y + 3.0:
			bad.append("%s '%s' déborde %s (%s)" % [ctl.get_class(), ctl.name, str(r), str(node.get_path_to(ctl))])
			if bad.size() >= 5:
				break
	if shots != "" and SHOT_LABELS.has(label):
		var img: Image = root.get_texture().get_image()
		img.save_png("%s/%s_%dx%d_%d.png" % [shots, label.replace(" ", "_").replace("/", "-"), root.size.x, root.size.y, int(root.content_scale_factor * 100.0)])
	var fs: float = _fit_scale(node)
	for f in node.find_children("*", "FitBox", true, false):
		fs = minf(fs, (f as FitBox).scale_now)
	_min_fit = minf(_min_fit, fs)
	if not bad.is_empty():
		problems.append("[%s] %s : %s" % [_cfg, label, " ; ".join(PackedStringArray(bad))])
	elif verbose:
		print("  ok %-34s échelle d'ajustement %.2f" % [label, fs])


func _modal_of(v: Variant) -> Node:
	if v == null:
		return null
	if v is Control:
		return v
	if v is Object and "modal" in v and v.modal != null:
		return v.modal
	return v as Node


func _close(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n.has_method("close"):
		n.call("close")
	await _frames(2)


func _modal(label: String, opener: Callable) -> void:
	if only != "" and not label.contains(only):
		return
	var v: Variant = opener.call()
	await _frames(5)
	var n: Node = _modal_of(v)
	if n == null:
		print("  (ignoré : %s n'a rien ouvert)" % label)
		return
	_check(label, n)
	await _close(n)


func _setup_window(size: Vector2i, scale: float) -> bool:
	get_root().mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	await _frames(3)
	root.content_scale_factor = scale
	await _frames(6)
	var ok: bool = root.size == size
	_cfg = "fenêtre %dx%d%s, échelle %d%% (zone virtuelle %dx%d)" % [root.size.x, root.size.y, "" if ok else " (DEMANDÉE %dx%d)" % [size.x, size.y], int(scale * 100.0), root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	print("Configuration : ", _cfg)
	return ok


func _fresh_game() -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await _frames(2)
	game.new_game(5)
	game.gold = 5000
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(4)


func _all_scenarios() -> void:
	# --- Menu principal et création de partie ---
	if only == "" or "menu" in only or "partie" in only:
		main.call("_show_menu")
		await _frames(4)
		_check("menu principal", main)
		main.call("_enter_game")
		await _frames(3)
	await _modal("difficulté", func() -> Variant: return load("res://scenes/menu/difficulty_panel.gd").open(main, Callable()))
	await _modal("scénario", func() -> Variant: return load("res://scenes/newgame/scenario_panel.gd").open(main, Callable(), Callable()))
	await _modal("votre compagnie (bannière)", func() -> Variant: return load("res://scenes/newgame/company_setup.gd").open(main, Callable(), Callable()))
	await _modal("bannière", func() -> Variant: return load("res://scenes/banner/banner_screen.gd").open(main))
	await _modal("emplacements de sauvegarde", func() -> Variant: return load("res://scenes/menu/slots_panel.gd").open(main, true, Callable()))
	# --- Fenêtres modales ---
	await _modal("options", func() -> Variant: return load("res://scenes/menu/options_panel.gd").open(main))
	await _modal("encyclopédie", func() -> Variant: return load("res://scenes/codex/codex_screen.gd").open(main))
	await _modal("journal", func() -> Variant: return load("res://scenes/chronicle/chronicle_screen.gd").open(main))
	await _modal("mémorial", func() -> Variant: return load("res://scenes/chronicle/chronicle_screen.gd").open(main, "memorial"))
	await _modal("succès", func() -> Variant: return load("res://scenes/achievements/achievements_screen.gd").open(main))
	await _modal("courbes de campagne", func() -> Variant: return load("res://scenes/stats/stats_screen.gd").open(main))
	await _modal("héritage", func() -> Variant: return load("res://scenes/camp/legacy_screen.gd").open_family(main))
	await _modal("retraite d'un vétéran", func() -> Variant: return load("res://scenes/camp/legacy_screen.gd").open_retire(main, game.roster[0].id))
	await _modal("veillée au camp", func() -> Variant:
		game.extras["camp_life"] = {"pending": {"id": "mutiny", "a": game.roster[0].id, "b": -1, "day": game.day, "stake": 0, "cost": 75}}
		var m: Variant = load("res://scenes/camp/camp_life_screen.gd").open(main)
		game.extras.erase("camp_life")
		return m)
	await _modal("raccourcis", func() -> Variant: return load("res://scenes/ui/shortcuts.gd").open(main, "battle"))
	await _modal("atelier", func() -> Variant: return load("res://scenes/camp/workshop_screen.gd").open(main))
	await _modal("pause", func() -> Variant:
		main.call("_open_pause")
		return main.get("_pause_modal"))
	await _modal("résumé de bataille", func() -> Variant:
		var men: Array = []
		for u in game.roster:
			men.append({"u": u.to_dict(), "hp_before": u.hp_max, "hp_after": u.hp_max - 10, "xp": 12, "kills": 2, "wounds": ["Coupure"]})
		return load("res://scenes/battle/summary_screen.gd").open(main, {"result": "win", "title": "Contrat : chasser les brigands de la route", "gold": 300, "renown": 20, "fallen": ["Un tel"], "men": men, "has_replay": true,
			"loot": [{"kind": "weapon", "key": str(root.get_node("/root/Data").WPN.keys()[0])}, {"kind": "head", "key": str(root.get_node("/root/Data").HEAD.keys()[0])}], "goals": ["Objectif secondaire accompli"]}))
	await _modal("rediffusion", func() -> Variant:
		var rg := RandomNumberGenerator.new()
		rg.seed = 5
		var lib: RefCounted = load("res://tools/sim_lib.gd").new()
		var bs: BattleState = BattleState.create(lib.make_contract(["b"], 2, "plain", "pitched"), lib.make_party(rg, 6), rg)
		for i in 40:
			var bu: Unit = bs.next_turn()
			if bu == null:
				break
			bs.play_ai_turn(bu)
		bs.rec.finalize(bs)
		return ReplayScreen.open_log(main, bs.rec))
	await _modal("captifs", func() -> Variant:
		var m := ModalOverlay.open(main, 520)
		load("res://scenes/battle/captives_screen.gd").build(m.content, {"men": [{"name": "Brigand", "level": 2, "leader": true}, {"name": "Archer", "level": 1}], "faction": "h1"}, Callable())
		return m)
	await _modal("ruines (entrée)", func() -> Variant: return load("res://scenes/ruins/ruins_screen.gd").open_entry(main, "Ruines de la Crypte oubliée de Val-Cendre", "crypte", 3, Callable(), Callable()))
	await _modal("ruines (niveau)", func() -> Variant:
		var run: Dictionary = {"poi": "p0", "name": "Ruines de la Crypte oubliée de Val-Cendre", "theme": "crypte", "d": 3, "stage": 1, "stages": 3, "phase": "choice", "searched": false}
		return load("res://scenes/ruins/ruins_screen.gd").open_run(main, run, {"text": "Un piège à pression ! Une dalle s'abaisse et des pointes jaillissent.", "lines": ["Hugues le Roux : -20 PV", "+120 couronnes", "Trouvé : Haubert de mailles fin"]}, Callable()))
	await _modal("ruines (coffre)", func() -> Variant:
		var run2: Dictionary = {"poi": "p0", "name": "Citadelle orque", "theme": "citadelle", "d": 3, "stage": 3, "stages": 3, "phase": "chest", "searched": true}
		return load("res://scenes/ruins/ruins_screen.gd").open_run(main, run2, {}, Callable()))
	await _modal("antre légendaire", func() -> Variant: return load("res://scenes/ruins/ruins_screen.gd").open_lair(main, "troll", Callable(), Callable()))
	await _modal("préparation de défense", func() -> Variant:
		var dc: Dictionary = {"kind": "contract", "type": "b", "type_contract": "defense", "battle_type": "defense", "d": 3, "foes": ["brigand", "brigand", "archer", "chef"], "title": "Défendre le village des Trois-Ponts", "desc": "", "employer": "x", "origin": "x",
			"origin_id": "", "pay": 900, "days": 1, "tx": 0.0, "ty": 0.0, "ox": 0.0, "oy": 0.0, "target_name": "x", "biome": "plain"}
		var ds: BattleState = BattleState.create(dc, game.roster, game.rng, 3, 1.0, "normal", game.formation_slots())
		return load("res://scenes/battle/defense_panel.gd").open(main, ds, Callable()))
	await _modal("marché", func() -> Variant: return load("res://scenes/market/market_screen.gd").open(main, 0))
	await _modal("marché (marchandises)", func() -> Variant:
		var s: Variant = load("res://scenes/market/market_screen.gd").open(main, 0)
		if s != null and s.has_method("_set_tab"):
			s.call("_set_tab", "trade")
		elif s != null and s.has_method("set_tab"):
			s.call("set_tab", "trade")
		return s)
	await _modal("inventaire", func() -> Variant:
		load("res://scenes/inventory/inventory_screen.gd").last_tab = "inventory"
		return load("res://scenes/inventory/inventory_screen.gd").open(main, game.roster[0].id))
	await _modal("fiche d'homme (talents)", func() -> Variant:
		var s: Object = load("res://scenes/inventory/inventory_screen.gd").open(main, game.roster[0].id)
		if s.has_method("set_tab"):
			s.call("set_tab", "perks")
		else:
			print("  ? set_tab absent : ", s.get_script().resource_path)
		return s)
	load("res://scenes/inventory/inventory_screen.gd").last_tab = "inventory"
	await _modal("arbre de talents", func() -> Variant: return load("res://scenes/perks/perk_screen.gd").open(main, game.roster[0]))
	# --- Écrans de fin ---
	for k in [["écran de fin de campagne", "EndingScreen"], ["écran de fin de scénario", "ScenarioEndScreen"]]:
		if only != "" and not str(k[0]).contains(only):
			continue
		var scr: Control = (load("res://scenes/ending/ending_screen.gd") if k[1] == "EndingScreen" else load("res://scenes/ending/scenario_end_screen.gd")).new()
		var holder: Node = main.get("_content")
		holder.add_child(scr)
		await _frames(4)
		_check(str(k[0]), main)
		scr.queue_free()
		await _frames(2)
	# --- Ville (onglets) ---
	await _frames(2)
	if only == "" or "ville" in only:
		var camp: Node = main.find_child("Camp", true, false)
		if camp != null:
			var tabs: TabContainer = camp.get("_tabs")
			for i in tabs.get_tab_count():
				tabs.current_tab = i
				await _frames(3)
				_check("ville / onglet %s" % tabs.get_tab_title(i), main)
			tabs.current_tab = 0
	# --- Tutoriel ---
	if only == "" or "tutoriel" in only:
		load("res://scenes/tutorial/tutorial.gd").start()
		load("res://scenes/tutorial/tutorial.gd").hint("town")
		await _frames(4)
		if load("res://scenes/tutorial/tutorial.gd").current != null:
			_check("tutoriel", load("res://scenes/tutorial/tutorial.gd").current)
			load("res://scenes/tutorial/tutorial.gd").hide_card()
		await _frames(2)
	# --- Carte ---
	game.accept_contract(0)
	game.leave_settlement()
	await _frames(6)
	_check("carte", main)
	var map: Node = main.find_child("MapScreen", true, false)
	if verbose and map != null:
		for f in main.find_children("*", "FitBox", true, false):
			var fb: FitBox = f
			print("  FitBox taille %s échelle %.2f min enfant %s taille enfant %s holder %s" % [str(fb.size), fb.scale_now, str(fb.child.get_combined_minimum_size()), str(fb.child.size), str(fb.child.get_parent().size)])
		print("  carte : taille %s, HUD %s" % [str((map as Control).size), str(map.get("hud").size)])
	if map != null:
		var drawer: Variant = map.get("drawer")
		if drawer != null:
			drawer.toggle()
			await _frames(4)
			_check("carte / tiroir Détails", main)
			drawer.toggle()
			await _frames(3)
		map.call("_toggle_legend")
		await _frames(4)
		_check("carte / légende", main)
		map.call("_toggle_legend")
		await _frames(3)
	await _modal("inventaire sur la carte", func() -> Variant: return load("res://scenes/inventory/inventory_screen.gd").open(main, game.roster[0].id))
	# --- Bataille ---
	game.start_battle(game.active_contract)
	await _frames(8)
	_check("bataille", main)
	await _modal("bataille / pause", func() -> Variant:
		main.call("_open_pause")
		return main.get("_pause_modal"))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sizes: Array = []
	var scales: Array = [1.0]
	for i in args.size():
		match args[i]:
			"--verbose":
				verbose = true
			"--shots":
				shots = args[i + 1]
			"--only":
				only = args[i + 1]
			"--scale":
				scales = [float(args[i + 1])]
			"--scales":
				scales = []
				for s in args[i + 1].split(","):
					scales.append(float(s))
			"--sizes":
				for s in args[i + 1].split(","):
					var wh: PackedStringArray = s.split("x")
					sizes.append(Vector2i(int(wh[0]), int(wh[1])))
	var settings: Node = root.get_node("/root/Settings")
	settings.persist = false
	game = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	load("res://scenes/battle/battle.gd").speed = 0.0
	if sizes.is_empty():
		sizes = [root.size]
	var total: int = 0
	for sz in sizes:
		for sc in scales:
			var ok: bool = await _setup_window(sz, sc)
			if not ok:
				problems.append("[%s] la fenêtre n'a pas pu prendre la taille demandée" % _cfg)
			await _fresh_game()
			await _all_scenarios()
			total += 1
	print("Audit de réactivité : %d écran(s) vérifié(s) sur %d configuration(s), échelle d'ajustement minimale %.2f, %d problème(s)" % [_count, total, _min_fit, problems.size()])
	for p in problems:
		print("  ✗ ", p)
	quit(1 if not problems.is_empty() else 0)
