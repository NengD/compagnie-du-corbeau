extends SceneTree
## Planche de contact des icônes d'objets dans des ItemCell.
## godot --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/shots_icones.gd -- "<dossier>" "<suffixe>"
var dir: String = "."
var tag: String = ""


func _init() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _row(parent: Control, title: String, cells: Array) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color("cfa851"))
	parent.add_child(l)
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 4)
	fl.add_theme_constant_override("v_separation", 4)
	for c in cells:
		c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		fl.add_child(c)
	parent.add_child(fl)


func _cell(it: Dictionary, o: Dictionary = {}) -> ItemCell:
	var c := ItemCell.new()
	c.set_item(it, o)
	return c


func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	dir = a[0] if a.size() > 0 else "."
	tag = a[1] if a.size() > 1 else "x"
	if tag.contains("1440"):
		DisplayServer.window_set_size(Vector2i(2560, 1440))
		DisplayServer.window_set_position(Vector2i(0, 0))
		await _frames(10)
	print("window ", root.size)
	var bg := ColorRect.new()
	bg.color = Color("2a2118")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var theme: Theme = GameTheme.get_theme()
	var box := VBoxContainer.new()
	box.theme = theme
	box.position = Vector2(12, 8)
	box.size = Vector2(1256, 700)
	box.add_theme_constant_override("separation", 3)
	root.add_child(box)
	var rows: Array = []
	var weapons: Array = []
	for k: String in Data.WPN:
		if not Data.UNIQUES.has(k):
			weapons.append(_cell({"kind": "weapon", "key": k}, {"price": int(Data.WPN[k]["price"]), "size": 56}))
	_row(box, "Armes (prix)", weapons)
	var gear: Array = []
	for k: String in Data.HEAD:
		if k != "none" and not Data.UNIQUES.has(k):
			gear.append(_cell({"kind": "head", "key": k}, {"price": int(Data.HEAD[k]["price"]), "size": 56}))
	for k: String in Data.BODY:
		if k != "none" and not Data.UNIQUES.has(k):
			gear.append(_cell({"kind": "body", "key": k}, {"price": int(Data.BODY[k]["price"]), "size": 56}))
	gear.append(_cell({"kind": "shield", "key": ""}, {"price": 120, "durability": 0.84, "size": 56}))
	for k: String in Data.TOOLS:
		gear.append(_cell({"kind": "tool", "key": k}, {"price": int(Data.TOOLS[k]["price"]), "qty": 3, "size": 56}))
	for k in ["pain", "viande", "fromage", "ration"]:
		gear.append(_cell({"kind": "food", "key": k}, {"price": 94, "qty": 25, "size": 56}))
	_row(box, "Casques, armures, bouclier, outils (quantité), vivres", gear)
	var uni: Array = []
	for k: String in Data.UNIQUES:
		uni.append(_cell({"kind": str(Data.UNIQUES[k]["kind"]), "key": k}, {"price": 2966, "size": 56}))
	_row(box, "Uniques (cadre or, prix à 4 chiffres)", uni)
	var states: Array = [
		_cell({"kind": "weapon", "key": "hache"}, {"durability": 0.98, "price": 201}),
		_cell({"kind": "weapon", "key": "hache"}, {"durability": 0.45, "price": 174}),
		_cell({"kind": "weapon", "key": "hache"}, {"durability": 0.12}),
		_cell({"kind": "weapon", "key": "hache"}, {"selected": true}),
		_cell({"kind": "weapon", "key": "hache", "quality": 1}, {}),
		_cell({"kind": "weapon", "key": "hache"}, {"locked": true}),
		_cell({"kind": "tool", "key": "pierre"}, {"qty": 12}),
		_cell({"kind": "weapon", "key": "zzz"}, {}),
	]
	for s in ["", "head", "body", "weapon", "shield", "bag", "tool"]:
		var e := ItemCell.new()
		e.set_empty(s)
		states.append(e)
	_row(box, "États : durabilité vert / orange / rouge, sélectionnée, qualité, verrouillée, quantité, inconnue, vides (fantômes)", states)
	var sizes: Array = []
	for s in [32, 48, 64, 96]:
		sizes.append(_cell({"kind": "body", "key": "u_cotte_nuit"}, {"size": s, "price": 1900, "durability": 0.8}))
		sizes.append(_cell({"kind": "weapon", "key": "arbalete"}, {"size": s, "price": 560}))
	_row(box, "Tailles 32 / 48 / 64 / 96", sizes)
	await _frames(8)
	root.get_viewport().get_texture().get_image().save_png("%s/icones_%s.png" % [dir, tag])
	quit(0)
