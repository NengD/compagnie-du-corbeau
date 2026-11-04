class_name CompanySetup
extends RefCounted
## Étape « Votre compagnie » de la nouvelle partie (après la difficulté) : nom, couleurs, emblème et motif de la bannière,
## avec aperçu en direct de l'étendard et du marqueur tel qu'il apparaîtra sur la carte.
## `on_start` reçoit {"name", "banner"} déjà validés par `Banner.resolve_setup` ; `on_back` ramène à la difficulté.
## Aucune règle ici : le tirage au hasard et la validation sont dans core/banner.gd.


## Pastille d'emblème : l'emblème n° `idx` dessiné dans les couleurs courantes.
class EmblemIcon extends Control:
	var idx: int = 0
	var banner: Dictionary = {}

	func _init(i: int = 0) -> void:
		idx = i
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)

	func _draw() -> void:
		if banner.is_empty():
			return
		draw_rect(Rect2(Vector2.ZERO, size), Banner.primary(banner))
		BannerView.draw_emblem(self, idx, size * 0.5, minf(size.x, size.y) * 0.72, Banner.secondary(banner))


static func open(host: Node, on_start: Callable, on_back: Callable, rng: RandomNumberGenerator = null) -> ModalOverlay:
	var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var modal: ModalOverlay = ModalOverlay.open(host, 860)
	var box: VBoxContainer = modal.content
	box.add_theme_constant_override("separation", 6)
	var st: Dictionary = {"name": Data.COMPANY_NAME_DEFAULT, "primary": "b03a2e", "secondary": "d8cfb8", "emblem": 0, "pattern": 0}
	box.add_child(UiKit.title("Votre compagnie", 34))
	box.add_child(UiKit.sub("Donnez un nom à vos mercenaires et dessinez l'étendard qui marquera leur position sur la carte.", 13))

	var cols := UiKit.hbox(22)
	box.add_child(cols)
	var left := UiKit.vbox(5)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := UiKit.vbox(8)
	cols.add_child(right)

	# --- Aperçus (colonne de droite) ---
	right.add_child(UiKit.label("Étendard", 14, GameTheme.GOLD, true))
	var big := BannerView.new(st, Vector2(120, 164), 0.45)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(big)
	right.add_child(UiKit.label("Sur la carte", 14, GameTheme.GOLD, true))
	var marker := CompanyMarker.Preview.new()
	right.add_child(marker)

	# --- Nom ---
	left.add_child(UiKit.label("Nom de la compagnie", 14, GameTheme.GOLD, true))
	var name_row := UiKit.hbox(6)
	var name_edit := LineEdit.new()
	name_edit.text = str(st["name"])
	name_edit.max_length = Data.COMPANY_NAME_MAX
	name_edit.placeholder_text = Data.COMPANY_NAME_DEFAULT
	name_edit.select_all_on_focus = true
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	var dice_name := UiKit.button("Suggestion", "ghost", true)
	dice_name.tooltip_text = "Un autre nom de compagnie"
	name_row.add_child(dice_name)
	left.add_child(name_row)
	var hint := UiKit.sub("%d à %d caractères." % [Data.COMPANY_NAME_MIN, Data.COMPANY_NAME_MAX], 12)
	left.add_child(hint)

	# --- Couleurs ---
	var swatches: Dictionary = {"primary": [], "secondary": []}
	var picker_btns: Dictionary = {}
	# Dans une fonction anonyme, une variable locale est capturée PAR VALEUR à la création : `sync` doit donc être un conteneur
	# (tableau) rempli plus tard, sinon les boutons créés avant son affectation appellent un Callable vide.
	var sync: Array = [Callable()]
	for key in ["primary", "secondary"]:
		left.add_child(UiKit.label("Couleur principale (champ de la bannière)" if key == "primary" else "Couleur secondaire (emblème)", 14, GameTheme.GOLD, true))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 4)
		row.add_theme_constant_override("v_separation", 4)
		for i in Data.BANNER_COLORS.size():
			var hex: String = str(Data.BANNER_COLORS[i])
			var b := Button.new()
			b.custom_minimum_size = Vector2(28, 28)
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = str(Data.BANNER_COLOR_NAMES[i])
			b.pressed.connect(func() -> void:
				st[key] = hex
				sync[0].call())
			row.add_child(b)
			(swatches[key] as Array).append([b, hex])
		var pick := ColorPickerButton.new()
		pick.custom_minimum_size = Vector2(28, 28)
		pick.edit_alpha = false
		pick.color = Color(str(st[key]))
		pick.tooltip_text = "Autre teinte…"
		pick.color_changed.connect(func(c: Color) -> void:
			st[key] = c.to_html(false)
			sync[0].call())
		row.add_child(pick)
		picker_btns[key] = pick
		left.add_child(row)

	# --- Emblème ---
	left.add_child(UiKit.label("Emblème", 14, GameTheme.GOLD, true))
	var egrid := HFlowContainer.new()
	egrid.add_theme_constant_override("h_separation", 4)
	egrid.add_theme_constant_override("v_separation", 4)
	var emb_btns: Array[Button] = []
	var emb_icons: Array[EmblemIcon] = []
	for i in Data.BANNER_EMBLEMS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.tooltip_text = str(Data.BANNER_EMBLEMS[i])
		var ic := EmblemIcon.new(i)
		b.add_child(ic)
		b.pressed.connect(func() -> void:
			st["emblem"] = i
			sync[0].call())
		egrid.add_child(b)
		emb_btns.append(b)
		emb_icons.append(ic)
	left.add_child(egrid)

	# --- Motif du champ ---
	left.add_child(UiKit.label("Motif du champ", 14, GameTheme.GOLD, true))
	var prow := UiKit.hbox(4)
	var pat_btns: Array[Button] = []
	for i in Data.BANNER_PATTERNS.size():
		var pb := UiKit.button(str(Data.BANNER_PATTERNS[i]), "", true)
		pb.toggle_mode = true
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(func() -> void:
			st["pattern"] = i
			sync[0].call())
		prow.add_child(pb)
		pat_btns.append(pb)
	left.add_child(prow)

	# --- Boutons ---
	var actions := UiKit.hbox(8)
	var rand := UiKit.button("Aléatoire", "ghost")
	rand.tooltip_text = "Nom, couleurs, emblème et motif au hasard"
	actions.add_child(rand)
	actions.add_child(UiKit.spacer())
	var back := UiKit.button("Retour", "ghost")
	actions.add_child(back)
	var go := UiKit.button("Commencer l'aventure", "pri")
	actions.add_child(go)
	box.add_child(actions)

	sync[0] = func() -> void:
		var banner: Dictionary = Banner.clean({"primary": st["primary"], "secondary": st["secondary"], "emblem": st["emblem"], "pattern": st["pattern"]})
		big.set_banner(banner)
		var nm: String = name_edit.text.strip_edges()
		marker.set_look(banner, nm if nm != "" else Data.COMPANY_NAME_DEFAULT)
		for key2 in ["primary", "secondary"]:
			for e in swatches[key2]:
				_style_swatch(e[0], str(e[1]), str(st[key2]) == str(e[1]))
			(picker_btns[key2] as ColorPickerButton).set_pick_color(Color(str(st[key2])))
		for i in emb_btns.size():
			emb_btns[i].set_pressed_no_signal(i == int(st["emblem"]))
			emb_icons[i].banner = banner
			emb_icons[i].queue_redraw()
		for i in pat_btns.size():
			pat_btns[i].set_pressed_no_signal(i == int(st["pattern"]))
		var ok: bool = Banner.is_valid_name(name_edit.text)
		go.disabled = not ok
		hint.add_theme_color_override("font_color", GameTheme.MUTE if ok else GameTheme.BLOOD)
	name_edit.text_changed.connect(func(_t: String) -> void: sync[0].call())
	dice_name.pressed.connect(func() -> void:
		name_edit.text = Banner.random_name(r, name_edit.text)
		sync[0].call())
	rand.pressed.connect(func() -> void:
		var nb: Dictionary = Banner.random_banner(r)
		st["primary"] = nb["primary"] if nb["primary"] != "" else str(Data.BANNER_COLORS[0])
		st["secondary"] = nb["secondary"]
		st["emblem"] = nb["emblem"]
		st["pattern"] = nb["pattern"]
		name_edit.text = Banner.random_name(r, name_edit.text)
		sync[0].call())
	back.pressed.connect(func() -> void:
		modal.close()
		if on_back.is_valid():
			on_back.call())
	go.pressed.connect(func() -> void:
		if not Banner.is_valid_name(name_edit.text):
			return
		var setup: Dictionary = Banner.resolve_setup({"name": name_edit.text, "banner": {"primary": st["primary"], "secondary": st["secondary"], "emblem": st["emblem"], "pattern": st["pattern"]}})
		modal.close()
		if on_start.is_valid():
			on_start.call(setup))
	sync[0].call()
	return modal


static func _style_swatch(b: Button, hex: String, selected: bool) -> void:
	var border: Color = GameTheme.GOLD if selected else GameTheme.LINE
	var width: int = 3 if selected else 1
	for stn in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(stn, GameTheme.box(Color(hex), border, width, 3, Vector4(0, 0, 0, 0)))
