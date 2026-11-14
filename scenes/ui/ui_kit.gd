class_name UiKit
extends RefCounted
## Fabriques de composants d'interface réutilisables (étiquettes, boutons, cartes d'unité).


static func label(text: String, size: int = 15, color: Color = GameTheme.INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", GameTheme.scaled_size(size))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", GameTheme.bold_font())
	return l


static func title(text: String, size: int = 24, color: Color = GameTheme.INK) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", GameTheme.title_font())
	return l


static func sub(text: String, size: int = 13, expand: bool = true) -> Label:
	var l := label(text, size, GameTheme.MUTE)
	if expand:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func para(text: String, size: int = 15) -> Label:
	var l := label(text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## kind : "" | "pri" | "ghost"
## Vrai quand le joueur navigue au clavier (touche Tab, flèches, Entrée…) ; faux dès qu'il utilise la souris.
## Mis à jour par `Main._input`. Tant qu'il est faux, un clic de souris ne laisse pas d'anneau de focus sur un bouton.
static var kb_mode: bool = false
static var _programmatic: bool = false


## Relâche le focus une fois le clic terminé (jamais pendant l'appui : perdre le focus annule le clic d'un bouton).
static func _after_click(b: Control) -> void:
	if not kb_mode and is_instance_valid(b):
		b.release_focus.call_deferred()


## Premier contrôle focalisable, visible et actif sous `root` (parcours en profondeur) ; null s'il n'y en a pas.
static func first_focusable(root: Node) -> Control:
	if root is Control:
		var c: Control = root
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() and not (c is BaseButton and (c as BaseButton).disabled):
			return c
	for ch in root.get_children():
		var f: Control = first_focusable(ch)
		if f != null:
			return f
	return null


## Donne le focus clavier au premier contrôle de `root` (à l'ouverture d'une fenêtre ou d'un menu). Renvoie true si trouvé.
static func focus_first(root: Node) -> bool:
	var f: Control = first_focusable(root)
	if f == null or not f.is_inside_tree():
		return false
	_programmatic = true
	f.grab_focus()
	_programmatic = false
	return true


static func button(text: String, kind: String = "", small: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL  # navigable au clavier ; pas d'anneau de focus après un clic souris (voir _after_click)
	b.pressed.connect(_click)
	b.button_up.connect(_after_click.bind(b))
	match kind:
		"pri":
			b.theme_type_variation = "PrimaryButton"
		"ghost":
			b.theme_type_variation = "GhostButton"
	if small:
		b.add_theme_font_size_override("font_size", 13)
	return b


static func chip(text: String, color: Color = GameTheme.MUTE) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "ChipPanel"
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(label(text.to_upper(), 11, color, true))
	return p


static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Ajoute une carte à `parent` et renvoie la boîte verticale intérieure.
static func card(parent: Node, min_width: int = 0) -> VBoxContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	p.custom_minimum_size = Vector2(min_width, 0)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(p)
	var v := vbox(8)
	p.add_child(v)
	return v


static func kv_row(key: String, value: String) -> HBoxContainer:
	var h := hbox(8)
	h.add_child(label(key, 13, GameTheme.MUTE))
	h.add_child(spacer())
	var v := label(value, 13)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	return h


static func stats_grid(u: Unit) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	for k in Data.STAT_NAMES:
		var v: int = int(u.get(k))
		if k == "fat_max":
			v = u.fat_max_eff()
		elif k == "initiative":
			v = u.initiative - u.weight()
		var p := PanelContainer.new()
		p.theme_type_variation = "FlatPanel"
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		var name_l := label(str(Data.STAT_SHORT[k]).to_upper(), 9, GameTheme.MUTE)
		name_l.clip_text = true
		box.add_child(name_l)
		box.add_child(label(str(v), 15, GameTheme.INK, true))
		p.add_child(box)
		g.add_child(p)
	return g


static func gear_list(u: Unit) -> VBoxContainer:
	var w: Dictionary = u.weapon_data()
	var v := vbox(2)
	var wear: String = "  [usure %d/%d]" % [u.weapon_dur_now(), u.weapon_dur_max()] if u.weapon_wears() else ""
	var wit: Dictionary = Loot.weapon_item(u)
	v.add_child(kv_row("Arme", "%s · %d–%d%s" % [Loot.item_name(wit), Loot.dmg_min(wit), Loot.dmg_max(wit), wear]))
	var sh_wear: String = "  [usure %d/%d]" % [u.shield_dur_now(), u.shield_dur_max()] if u.shield else ""
	v.add_child(kv_row("Main gauche", (Shields.label(u.shield_kind) + sh_wear) if u.shield else "—"))
	v.add_child(kv_row("Tête", Loot.item_name(Loot.head_item(u)) if u.head != "none" else str(Data.HEAD[u.head]["n"])))
	v.add_child(kv_row("Corps", Loot.item_name(Loot.body_item(u)) if u.body != "none" else str(Data.BODY[u.body]["n"])))
	return v


## Barres PV / armure tête / armure corps (+ fatigue ou XP en option).
static func bars(u: Unit, extra: Array = []) -> VBoxContainer:
	var v := vbox(3)
	v.add_child(StatBar.new("PV", maxi(0, u.hp), u.hp_max, GameTheme.BLOOD))
	if u.head_armor_max() > 0:
		v.add_child(StatBar.new("Tête", u.arm_h, u.head_armor_max(), Color("c9c2b2")))
	if u.body_armor_max() > 0:
		v.add_child(StatBar.new("Corps", u.arm_b, u.body_armor_max(), GameTheme.STEEL))
	if u.side == "p":  # usure : seulement quand l'arme ou le bouclier est abîmé
		if u.weapon_wears() and u.weapon_dur_now() < u.weapon_dur_max():
			v.add_child(StatBar.new("Arme", u.weapon_dur_now(), u.weapon_dur_max(), Color("a98a5a")))
		if u.shield and u.shield_dur_now() < u.shield_dur_max():
			v.add_child(StatBar.new("Bouclier", u.shield_dur_now(), u.shield_dur_max(), Color("a98a5a")))
	for e in extra:
		v.add_child(e)
	return v


static func skulls(danger: int) -> Label:
	var txt: String = ""
	for n in 3:
		txt += "◆" if n < danger else "◇"
	return label(txt, 18, GameTheme.BLOOD)


static func _click() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var a: Node = tree.root.get_node_or_null("Audio") if tree != null else null
	if a != null:
		a.call("play", "click")
