extends SceneTree
## Aperçu du contenu d'équipement (nouvelles armes, armures de faction, armes à histoire), figurines puis icônes.
## godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/preview_equip.gd -- "<dossier>"
## Écrit equip_figures.png et equip_icons.png dans le dossier (aucun réglage de fenêtre changé).


func _initialize() -> void:
	call_deferred("_run")


func _man(side: String, fac: String, weapon: String, head: String, body: String, shield: bool = false, seed_id: int = 1) -> Unit:
	var u := Unit.new()
	u.id = seed_id
	u.side = side
	u.faction = fac
	u.weapon = weapon
	u.head = head
	u.body = body
	u.shield = shield and bool(Data.WPN[weapon]["h1"])
	u.hp_max = 60
	u.hp = 60
	u.arm_h = u.head_armor_max()
	u.arm_b = u.body_armor_max()
	if fac == "o":
		u.sprite = ""
	return u


func _label(parent: Node, text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("e8dcb8"))
	parent.add_child(l)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var bg := ColorRect.new()
	bg.color = Color("3a3228")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var rows: Array = [
		[_man("p", "p", "dague", "casque", "gambison", false, 3), _man("p", "p", "epee_courte", "casque", "gambison", true, 4), _man("p", "p", "rapiere", "capuchon", "tunique", false, 5),
			_man("p", "p", "hache_bataille", "casque", "mailles", false, 6), _man("p", "p", "marteau_guerre", "casque", "gambison", true, 7), _man("p", "p", "baton_ferre", "none", "tunique", false, 8),
			_man("p", "p", "pique", "casque", "gambison", false, 9), _man("p", "p", "fronde", "capuchon", "tunique", true, 10)],
		[_man("p", "p", "arbalete_legere", "capuchon", "gambison", false, 11), _man("p", "p", "arc_long", "capuchon", "tunique", false, 12), _man("p", "p", "u_dague_veuve", "casque", "gambison", false, 13),
			_man("p", "p", "u_marteau_forgeron", "casque", "mailles", true, 14), _man("p", "p", "u_hache_aurore", "heaume", "brigandine", false, 15), _man("p", "p", "u_arc_mirelune", "capuchon", "gambison", false, 16),
			_man("p", "p", "u_pique_gardien", "casque", "mailles", false, 17), _man("p", "p", "hache", "heaume_crete", "haubert_surcot", true, 18)],
		[_man("e", "b", "dague", "cagoule_cuir", "cuir_cloute", true, 21), _man("e", "b", "fronde", "cagoule_cuir", "cuir_cloute", false, 22), _man("e", "b", "rapiere", "barbute", "haubert_surcot", true, 23),
			_man("e", "b", "epee", "heaume_crete", "haubert_surcot", true, 24), _man("e", "o", "baton_ferre", "casque_orque", "cuirasse_peaux", true, 25), _man("e", "o", "hache_bataille", "casque_orque", "plastron_orque", false, 26),
			_man("e", "u", "epee_courte", "casque_rouille", "cotte_rouillee", true, 27), _man("e", "u", "arc", "casque_rouille", "none", false, 28)],
	]
	for r in rows.size():
		for i in rows[r].size():
			var u: Unit = rows[r][i]
			var uv := UnitView.new().setup(u)
			uv.position = Vector2(90 + i * 150, 120 + r * 235)
			uv.scale = Vector2(2.7, 2.7)
			bg.add_child(uv)
			_label(bg, "%s" % (Loot.item_name({"kind": "weapon", "key": u.weapon})), Vector2(30 + i * 150, 150 + r * 235))
	for _f in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join("equip_figures.png"))
	# icônes : armes ordinaires et à histoire, casques, armures
	for c in bg.get_children():
		c.queue_free()
	await process_frame
	var theme: Theme = GameTheme.get_theme()
	var box := VBoxContainer.new()
	box.theme = theme
	box.position = Vector2(12, 8)
	box.size = Vector2(1256, 700)
	bg.add_child(box)
	var sets: Array = [
		["Armes ajoutées", ["dague", "epee_courte", "rapiere", "hache_bataille", "marteau_guerre", "baton_ferre", "pique", "fronde", "arbalete_legere", "arc_long"], "weapon"],
		["Armes à histoire", ["u_dague_veuve", "u_marteau_forgeron", "u_hache_aurore", "u_arc_mirelune", "u_pique_gardien"], "weapon"],
		["Casques de faction", ["cagoule_cuir", "barbute", "heaume_crete", "casque_orque", "casque_rouille"], "head"],
		["Armures de faction", ["cuir_cloute", "haubert_surcot", "cuirasse_peaux", "plastron_orque", "cotte_rouillee"], "body"],
	]
	for s in sets:
		var l := Label.new()
		l.text = str(s[0])
		l.add_theme_color_override("font_color", Color("cfa851"))
		box.add_child(l)
		var fl := HBoxContainer.new()
		fl.add_theme_constant_override("separation", 8)
		for k in s[1]:
			var c := ItemCell.new()
			c.set_item({"kind": str(s[2]), "key": str(k)}, {"size": 120})
			fl.add_child(c)
		box.add_child(fl)
	for _f in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join("equip_icons.png"))
	quit()
