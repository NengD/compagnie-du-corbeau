class_name BannerScreen
extends RefCounted
## Écran « Bannière » : nom de la compagnie, couleur principale (celle des boucliers), couleur secondaire et emblème.
## Chaque choix est appliqué tout de suite par `Game.set_banner` / `Game.set_company_name`.


static func open(host: Node) -> ModalOverlay:
	var modal: ModalOverlay = ModalOverlay.open(host, 560)
	var box: VBoxContainer = modal.content
	var state: Dictionary = {"primary": str(Game.banner["primary"]), "secondary": str(Game.banner["secondary"]), "emblem": int(Game.banner["emblem"]), "pattern": int(Game.banner.get("pattern", 0))}
	box.add_child(UiKit.title("Bannière de la compagnie", 32))

	var head := UiKit.hbox(16)
	var preview := BannerView.new(Game.banner, Vector2(96, 128))
	head.add_child(preview)
	var right := UiKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UiKit.sub("Nom de la compagnie", 13, false))
	var name_edit := LineEdit.new()
	name_edit.text = Game.company_name
	name_edit.max_length = Data.COMPANY_NAME_MAX
	name_edit.placeholder_text = Data.COMPANY_NAME_DEFAULT
	name_edit.select_all_on_focus = true
	right.add_child(name_edit)
	right.add_child(UiKit.sub("La couleur principale peint aussi les boucliers de vos hommes ; les vétérans portent des atours dans ses teintes.", 12))
	head.add_child(right)
	box.add_child(head)

	var apply := func() -> void:
		preview.set_banner(state)
		Game.set_banner(str(state["primary"]), str(state["secondary"]), int(state["emblem"]), int(state["pattern"]))
	var swatch_rows: Array = []
	box.add_child(UiKit.label("Couleur principale", 15, GameTheme.GOLD, true))
	var prow0 := _swatches(state, "primary", true, apply, swatch_rows)
	box.add_child(prow0)
	box.add_child(UiKit.label("Couleur secondaire (emblème et chevron)", 15, GameTheme.GOLD, true))
	var srow := _swatches(state, "secondary", false, apply, swatch_rows)
	box.add_child(srow)
	box.add_child(UiKit.label("Emblème", 15, GameTheme.GOLD, true))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var emblem_buttons: Array[Button] = []
	for i in Data.BANNER_EMBLEMS.size():
		var b := UiKit.button(str(Data.BANNER_EMBLEMS[i]), "", true)
		b.toggle_mode = true
		b.button_pressed = i == int(state["emblem"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			state["emblem"] = i
			for j in emblem_buttons.size():
				emblem_buttons[j].set_pressed_no_signal(j == i)
			apply.call())
		emblem_buttons.append(b)
		grid.add_child(b)
	box.add_child(grid)
	box.add_child(UiKit.label("Motif du champ", 15, GameTheme.GOLD, true))
	var prow := UiKit.hbox(6)
	var pattern_buttons: Array[Button] = []
	for i in Data.BANNER_PATTERNS.size():
		var pb := UiKit.button(str(Data.BANNER_PATTERNS[i]), "", true)
		pb.toggle_mode = true
		pb.button_pressed = i == int(state["pattern"])
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(func() -> void:
			state["pattern"] = i
			for j in pattern_buttons.size():
				pattern_buttons[j].set_pressed_no_signal(j == i)
			apply.call())
		pattern_buttons.append(pb)
		prow.add_child(pb)
	box.add_child(prow)

	var commit_name := func() -> void:
		if name_edit.text.strip_edges() != Game.company_name:
			Game.set_company_name(name_edit.text)
	name_edit.text_submitted.connect(func(_t: String) -> void: commit_name.call())
	name_edit.focus_exited.connect(commit_name)
	var row := UiKit.hbox(8)
	var reset := UiKit.button("Rétablir les couleurs d'origine", "ghost", true)
	reset.pressed.connect(func() -> void:
		var d: Dictionary = Data.BANNER_DEFAULT
		state["primary"] = str(d["primary"])
		state["secondary"] = str(d["secondary"])
		state["emblem"] = int(d["emblem"])
		state["pattern"] = int(d["pattern"])
		for j in pattern_buttons.size():
			pattern_buttons[j].set_pressed_no_signal(j == int(d["pattern"]))
		for j in emblem_buttons.size():
			emblem_buttons[j].set_pressed_no_signal(j == int(d["emblem"]))
		for sr in swatch_rows:
			(sr as Callable).call()
		apply.call())
	row.add_child(reset)
	row.add_child(UiKit.spacer())
	var close := UiKit.button("Fermer", "pri")
	close.pressed.connect(func() -> void:
		commit_name.call()
		modal.close())
	row.add_child(close)
	box.add_child(row)
	return modal


## Rangée de pastilles de couleur ; `allow_default` ajoute la pastille « ocre d'origine » (primary vide).
static func _swatches(state: Dictionary, key: String, allow_default: bool, apply: Callable, refreshers: Array) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var buttons: Array = []
	var colors: Array = []
	if allow_default:
		colors.append("")
	colors.append_array(Data.BANNER_COLORS)
	for i in colors.size():
		var hex: String = str(colors[i])
		var b := Button.new()
		b.custom_minimum_size = Vector2(34, 34)
		b.focus_mode = Control.FOCUS_NONE
		var shown: String = hex if hex != "" else str(Data.BANNER_COLORS[0])
		b.tooltip_text = "Ocre d'origine" if hex == "" else str(Data.BANNER_COLOR_NAMES[Data.BANNER_COLORS.find(hex)])
		b.text = "·" if hex == "" else ""
		buttons.append([b, hex, shown])
		b.pressed.connect(func() -> void:
			state[key] = hex
			for e in buttons:
				_style_swatch(e[0], e[2], str(state[key]) == str(e[1]))
			apply.call())
		row.add_child(b)
	var refresh := func() -> void:
		for e in buttons:
			_style_swatch(e[0], e[2], str(state[key]) == str(e[1]))
	refreshers.append(refresh)
	refresh.call()
	return row


static func _style_swatch(b: Button, hex: String, selected: bool) -> void:
	var border: Color = GameTheme.GOLD if selected else GameTheme.LINE
	var width: int = 3 if selected else 1
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, GameTheme.box(Color(hex), border, width, 3, Vector4(0, 0, 0, 0)))
