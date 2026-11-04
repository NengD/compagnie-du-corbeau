extends SceneTree
## Test de fumée de l'interface : ville, carte, voyage, bataille jouée jusqu'au bout, retour à la carte.
##   godot --path . --headless -s res://tests/smoke_ui.gd
## Ne touche pas à user://savegame.json. (Les autoloads ne sont pas des identifiants dans un script -s :
## on passe par get_node et par des types Node.)

var _errors: int = 0
var game: Node


func _init() -> void:
	call_deferred("_run")


func _step(msg: String) -> void:
	print("· " + msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	game = root.get_node("/root/Game")
	game.autosave = false
	game.random_events = false
	load("res://scenes/battle/battle.gd").speed = 0.0
	game.new_game(5)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)
	await _check_company_setup(main)
	await _check_formation_panel(main)
	await _check_perk_tree(main)
	# --- Ville ---
	var camp: Node = _find(main, "Camp")
	_check(camp != null, "l'écran de ville s'affiche au départ")
	var tabs: TabContainer = camp.get("_tabs")
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await _frames(2)
		_step("onglet %s : %d nœuds" % [tabs.get_tab_title(i), _count(camp)])
	tabs.current_tab = tabs.get_tab_count() - 1  # Compagnie
	await _frames(2)
	var m: Unit = game.roster[0]
	m.xp = 150
	game.level_check(m)
	game.changed.emit()
	await _frames(1)
	camp.call("_open_promotion", m.id)
	await _frames(1)
	_check(camp.get("_modal") != null, "fenêtre de promotion")
	camp.call("_close_modal")
	tabs.current_tab = 0
	await _frames(1)
	game.gold = 99999
	_check(game.accept_contract(0), "contrat accepté depuis l'écran de ville")
	game.leave_settlement()
	await _frames(3)
	# --- Carte ---
	var map: Node = _find(main, "MapScreen")
	_check(map != null, "la carte s'affiche en quittant la ville")
	game.world.parties.clear()
	map.call("_set_speed", 3)
	map.view.travel_requested.emit(game.contract_target(), {"kind": "target", "title": "cible"})
	var guard: int = 0
	while game.battle == null and guard < 4000:
		guard += 1
		await process_frame
	_check(game.battle != null, "arrivée sur les lieux : la bataille s'engage (%d images)" % guard)
	_step("voyage : jour %d" % game.day)
	await _frames(3)
	# --- Bataille ---
	var screen: Node = _find(main, "BattleScreen")
	_check(screen != null and screen.state != null, "l'écran de bataille démarre")
	guard = 0
	var memo: Dictionary = {}
	while screen.state.over == "" and guard < 800:
		guard += 1
		await process_frame
		var cur: Unit = screen.state.current
		if not screen.get("_busy") and cur != null and cur.side == "p":
			var a: Dictionary = Ai.next_action(screen.state, cur, memo)
			if a["type"] == "attack":
				_click(screen, screen.board.hex_px(a["target"].hex) * screen.board.scale.x + screen.board.position)
			elif a["type"] == "move":
				var dest: Vector2i = a["path"][a["path"].size() - 1]
				_click(screen, screen.board.hex_px(dest) * screen.board.scale.x + screen.board.position)
			else:
				memo = {}
				screen.call("_end_turn")
	_step("bataille : %s en %d manches" % [screen.state.over, screen.state.round_no])
	_check(screen.state.over != "", "la bataille se termine")
	await _frames(2)
	game.finish_battle()
	await _frames(3)
	_check(_find(main, "MapScreen") != null or game.game_over, "retour sur la carte")
	# --- Fiche de compagnie depuis la carte ---
	map = _find(main, "MapScreen")
	if map != null:
		map.company_requested.emit()
		await _frames(2)
		var comp: Node = _find(main, "Camp")
		_check(comp != null and comp.mode == "company", "fiche de compagnie")
		comp.closed.emit()
		await _frames(2)
		_check(_find(main, "MapScreen") != null, "retour à la carte")
		var city: Dictionary = game.world.settlements[1]
		game.world.parties.clear()
		map = _find(main, "MapScreen")
		map.view.travel_requested.emit(game.world.settlement_pos(city), {"kind": "settlement", "id": city["id"], "title": city["name"]})
		guard = 0
		while game.location == "" and guard < 4000:
			guard += 1
			await process_frame
		await _frames(2)
		_check(game.location == city["id"] and _find(main, "Camp") != null, "arrivée en ville (%d images)" % guard)
	# --- Écran d'inventaire (appels directs, sans souris) ---
	game.inventory = [Loot.item("weapon", "hache"), Loot.item("head", "casque"), Loot.item("shield")]
	var inv_cls: GDScript = load("res://scenes/inventory/inventory_screen.gd")
	var inv: Node = inv_cls.call("open", main)
	await _frames(2)
	_check(inv != null and inv.is_inside_tree(), "l'inventaire s'ouvre")
	_check(inv_cls.call("open", main) == inv, "une seule fenêtre d'inventaire")
	var who: Unit = game.roster[0]
	inv.call("select", who.id)
	inv.call("quick", Inventory.in_stash(1))  # double-clic : casque équipé
	await _frames(2)
	_check(who.head == "casque", "double-clic : le casque est équipé")
	inv.call("quick", Inventory.at(who, "head"))
	await _frames(2)
	_check(who.head == "none" or who.head != "casque", "double-clic sur une pièce portée : retour à la réserve")
	_check(inv.call("can_drop", Inventory.in_stash(0), Inventory.at(who, "weapon")), "dépôt d'une arme sur la main droite")
	_check(not inv.call("can_drop", Inventory.in_stash(0), Inventory.at(who, "head")), "pas d'arme sur la tête")
	inv.call("drop", Inventory.in_stash(0), Inventory.at(who, "bag0"))
	await _frames(2)
	_check(who.bag[0]["key"] == "hache", "glisser vers le sac")
	inv.call("step", 1)
	inv.call("hover", null)
	inv.call("set_filter", "weapon")
	await _frames(2)
	_check(inv.call("selected") != who, "flèche : homme suivant")
	inv.call("close")
	await _frames(2)
	_check(get_nodes_in_group("inventory_screen").is_empty(), "plus d'inventaire ouvert")
	# --- Fiche de personnage : onglets et formation ---
	var inv2: Node = inv_cls.call("open", main)
	await _frames(2)
	inv2.call("set_tab", "perks")
	await _frames(2)
	_check(not _find_all(inv2, func(n: Node) -> bool: return n.get_script() != null and n.get_script().get_global_name() == "PerkTree").is_empty(), "onglet Talents : arbre présent")
	inv2.call("set_tab", "inventory")
	var fps: Array = _find_all(inv2, func(n: Node) -> bool: return n.get_script() != null and n.get_script().get_global_name() == "FormationPanel")
	_check(not fps.is_empty(), "formation présente sous la fiche")
	if game.roster.size() > 1 and not fps.is_empty():
		fps[0].emit_signal("unit_selected", game.roster[1].id)
		await _frames(2)
		_check(inv2.call("selected") == game.roster[1], "la formation change l'homme affiché")
	inv2.call("close")
	await _frames(2)
	# --- Marché : achat et vente ---
	if game.in_settlement():
		game.gold = 5000
		game.inventory.clear()
		var mk: Node = load("res://scenes/market/market_screen.gd").call("open", main)
		await _frames(3)
		_check(mk != null and mk.is_inside_tree(), "le marché s'ouvre")
		var wi: int = Market.filtered(game.shop_stock(), "weapon")[0]
		_check(mk.call("act_buy", wi), "marché : achat")
		_check(game.inventory.size() == 1, "marché : l'objet est en réserve")
		await _frames(2)
		mk.call("set_filter", "weapon")
		_check(mk.call("act_sell", 0), "marché : revente")
		mk.call("close")
		await _frames(2)
		_check(get_nodes_in_group("market_screen").is_empty(), "plus de marché ouvert")
	_step("jour %d, or %d, %d hommes" % [game.day, game.gold, game.roster.size()])
	print("\nSmoke UI : %s" % ("OK" if _errors == 0 else "%d erreur(s)" % _errors))
	quit(0 if _errors == 0 else 1)


## Régression : à la création de partie, les boutons de couleur, d'emblème et de motif de « Votre compagnie » doivent
## réellement mettre l'aperçu à jour (bug corrigé : `sync` capturé vide par les fonctions anonymes).
func _check_company_setup(main: Node) -> void:
	var started: Array = []
	var setup_script: GDScript = load("res://scenes/newgame/company_setup.gd")
	var modal: Node = setup_script.open(main, func(setup: Dictionary) -> void: started.append(setup), func() -> void: pass)
	await _frames(1)
	var views: Array = _find_all(modal, func(n: Node) -> bool: return n.get_script() != null and n.get_script().get_global_name() == "BannerView")
	_check(not views.is_empty(), "création de bannière : aperçu présent")
	if views.is_empty():
		return
	var big: Node = views[0]
	var before: Dictionary = (big.get("banner") as Dictionary).duplicate()
	var names: Array = Data.BANNER_COLOR_NAMES
	var swatches: Array = _find_all(modal, func(n: Node) -> bool: return n is Button and names.has((n as Button).tooltip_text))
	_check(swatches.size() >= 2 * Data.BANNER_COLORS.size(), "création de bannière : palettes présentes (%d)" % swatches.size())
	(swatches[3] as Button).pressed.emit()
	_check(str(Banner.primary(big.get("banner")).to_html(false)) == str(Data.BANNER_COLORS[3]), "création de bannière : la couleur principale change l'aperçu")
	(swatches[Data.BANNER_COLORS.size() + 5] as Button).pressed.emit()
	_check(str(Banner.secondary(big.get("banner")).to_html(false)) == str(Data.BANNER_COLORS[5]), "création de bannière : la couleur secondaire change l'aperçu")
	var emblems: Array = _find_all(modal, func(n: Node) -> bool: return n is Button and (n as Button).toggle_mode and Data.BANNER_EMBLEMS.has((n as Button).tooltip_text))
	_check(emblems.size() == Data.BANNER_EMBLEMS.size(), "création de bannière : emblèmes présents")
	(emblems[4] as Button).pressed.emit()
	_check(int((big.get("banner") as Dictionary)["emblem"]) == 4, "création de bannière : l'emblème change l'aperçu")
	var patterns: Array = _find_all(modal, func(n: Node) -> bool: return n is Button and (n as Button).toggle_mode and Data.BANNER_PATTERNS.has((n as Button).text))
	_check(patterns.size() == Data.BANNER_PATTERNS.size(), "création de bannière : motifs présents")
	(patterns[2] as Button).pressed.emit()
	_check(int((big.get("banner") as Dictionary)["pattern"]) == 2, "création de bannière : le motif change l'aperçu")
	_check(big.get("banner") != before, "création de bannière : l'aperçu a changé")
	_check((emblems[4] as Button).button_pressed and not (emblems[0] as Button).button_pressed, "création de bannière : un seul emblème enfoncé")
	var go: Array = _find_all(modal, func(n: Node) -> bool: return n is Button and (n as Button).text == "Commencer l'aventure")
	_check(not go.is_empty(), "création de bannière : bouton « Commencer »")
	if not go.is_empty():
		(go[0] as Button).pressed.emit()
	_check(started.size() == 1, "création de bannière : la partie démarre")
	if started.size() == 1:
		var b: Dictionary = started[0]["banner"]
		_check(int(b["emblem"]) == 4 and int(b["pattern"]) == 2 and str(b["primary"]) == str(Data.BANNER_COLORS[3]), "création de bannière : les choix sont transmis")
	await _frames(1)


func _find_all(n: Node, pred: Callable) -> Array:
	var out: Array = []
	if pred.call(n):
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_all(c, pred))
	return out


func _click(screen: Node, stage_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = stage_pos
	screen.call("_on_stage_input", ev)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors += 1
		print("  ✗ " + msg)


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and n.get_script().get_global_name() == cls:
		return n
	for c in n.get_children():
		var f: Node = _find(c, cls)
		if f != null:
			return f
	return null


func _count(n: Node) -> int:
	var t: int = 1
	for c in n.get_children():
		t += _count(c)
	return t


## Composant FormationPanel (scenes/inventory/formation_panel.gd) : affichage, sélection, glisser-déposer, plafond du champ.
func _check_formation_panel(main: Node) -> void:
	var panel: Control = load("res://scenes/inventory/formation_panel.gd").new()
	panel.position = Vector2(20, 20)
	panel.size = Vector2(700, 340)
	main.add_child(panel)
	await _frames(2)
	var selected: Array = []
	panel.connect("unit_selected", func(id: int) -> void: selected.append(id))
	var slots: Dictionary = game.formation_slots()
	var field: Array = Formation.field_ids(slots)
	_check(field.size() == mini(game.roster.size(), Data.FIGHTERS), "formation : les hommes du champ sont affichés")
	var first: int = int(field[0])
	var from_slot: int = int(slots[first])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (panel.call("slot_rect", from_slot) as Rect2).get_center()
	panel.call("_gui_input", click)
	_check(selected == [first], "formation : un clic sélectionne l'homme")
	var target: int = Formation.FRONT_START + 8
	var data: Variant = {"formation_unit": first, "from": from_slot}  # (_get_drag_data exige un vrai glisser dans le moteur)
	_check(int(panel.call("_man_at", from_slot).id) == first, "formation : le bon homme occupe la case")
	var drop_pos: Vector2 = (panel.call("slot_rect", target) as Rect2).get_center()
	_check(bool(panel.call("_can_drop_data", drop_pos, data)), "formation : dépôt sur une case vide permis")
	panel.call("_drop_data", drop_pos, data)
	_check(int(game.formation_slots()[first]) == target, "formation : l'homme est déplacé")
	var occupant: int = int(field[1])
	var occ_slot: int = int(game.formation_slots()[occupant])
	var data2: Variant = {"formation_unit": first, "from": target}
	panel.call("_drop_data", (panel.call("slot_rect", occ_slot) as Rect2).get_center(), data2)
	_check(int(game.formation_slots()[first]) == occ_slot and int(game.formation_slots()[occupant]) == target, "formation : dépôt sur un occupant = échange")
	panel.call("set_selected", occupant)
	panel.queue_free()
	await _frames(1)
	game.formation = {}
	game.formation_slots()


## Arbre de talents : PerkTree seul dans un hôte (taille libre), apprentissage, puis PerkScreen modal (talents refondus).
func _check_perk_tree(main: Node) -> void:
	var host := Control.new()
	host.size = Vector2(1000, 600)
	main.add_child(host)
	var u: Unit = game.roster[0]
	var saved_perks: Array[String] = u.perks.duplicate()
	var saved_pts: int = u.perk_points
	u.perks.clear()
	u.perk_points = 2
	var tr := PerkTree.new()
	tr.size = Vector2(1000, 600)
	host.add_child(tr)
	tr.set_unit(u)
	await _frames(2)
	_check(tr.icon_of("bretteur") != null and tr.icon_of("chef_ne") != null, "arbre de talents : pastilles présentes")
	var taken: Array = []
	tr.perk_taken.connect(func(k: String) -> void: taken.append(k))
	tr.icon_of("vif").clicked.emit("vif")
	tr.icon_of("vif").clicked.emit("vif")
	await _frames(2)
	_check(u.has_perk("vif") and taken == ["vif"], "arbre de talents : sélection puis apprentissage au second clic")
	# Maîtrises : badge de famille et infobulle « Actif / Inactif » selon l'équipement porté
	u.weapon = "epee"
	u.perks.assign(["bretteur", "vif", "parade", "spec_epee"])
	u.perk_points = 1
	tr.set_unit(u)
	await _frames(2)
	var mic: PerkIcon = tr.icon_of("spec_epee")
	_check(PerkIcon.badge_of("spec_epee") != null and PerkIcon.badge_of("ma_mailles") != null and PerkIcon.badge_of("vif") == null, "maîtrises : badge de famille (arme, armure, aucun)")
	_check(mic.unit == u and tr.state_of("spec_epee") == "taken", "maîtrise apprise : l'icône connaît l'homme affiché")
	var tip: Control = mic._make_custom_tooltip("") as Control
	_check(tip != null and "Actif" in _all_text(tip) and "Épée d'armes" in _all_text(tip), "infobulle de maîtrise : famille et état actif")
	tip.free()
	u.weapon = "hache"
	var tip2: Control = mic._make_custom_tooltip("") as Control
	_check("Inactif" in _all_text(tip2), "infobulle de maîtrise : inactive avec une hache")
	tip2.free()
	_check(tr.icon_of("ex_epee") != null and tr.state_of("ex_epee") == "locked", "talent expert présent, fermé (rang 5 talents requis)")
	tr.size = Vector2(1000, 600)
	var scr: PerkScreen = PerkScreen.open(main, u)
	await _frames(2)
	_check(scr.tree != null and scr.tree.icon_of("parade") != null, "écran de talents : arbre hébergé dans la modale")
	scr.close()
	await _frames(2)
	host.queue_free()
	u.perks.assign(saved_perks)
	u.perk_points = saved_pts


## Texte de tous les Label / RichTextLabel sous un nœud.
func _all_text(n: Node) -> String:
	var out: String = ""
	if n is Label:
		out += (n as Label).text + "
"
	for c in n.get_children():
		out += _all_text(c)
	return out
