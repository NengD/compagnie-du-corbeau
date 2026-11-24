class_name GameTheme
extends RefCounted
## Thème de l'interface : cuir, terre, fer et sang. Construit en code (une seule fois).

const BG := Color("1c1915")
const PANEL := Color("26211b")
const PANEL2 := Color("30291f")
const LINE := Color("4a3f31")
const INK := Color("ece1c9")
const MUTE := Color("a8997e")
const BLOOD := Color("b03a2e")
const GOLD := Color("cfa851")
const STEEL := Color("86a3c0")
const GOOD := Color("8ea25f")
const MORALE_COLORS: Array[Color] = [Color("ff7a68"), Color("e89a55"), Color("dcc56a"), Color("a8997e"), Color("a9c879")]

## --- Accessibilité (réglée par Settings.apply_all / set_value) ---
## Palettes pour les modes daltoniens (1 : rouge-vert, 2 : bleu-jaune), choisies pour rester distinctes une fois
## simulées (voir tests/suites/suite_acces_mods.gd). Mode 0 = couleurs d'origine.
const CB_MORALE: Array = [
	[Color("c0398f"), Color("e8601c"), Color("f0e442"), Color("d8d8d8"), Color("4aa8ec")],
	[Color("ff4b4b"), Color("8a4b00"), Color("ffd84a"), Color("bdbdbd"), Color("2fd0b8")],
]
## Symboles du moral (mode daltonien) : la forme s'ajoute à la couleur.
const MORALE_SYMBOLS: Array = ["▼▼", "▼", "◆", "●", "▲"]
const CB_SIDES: Array = [
	{"p": Color("56b4e9"), "e": Color("e69f00")},
	{"p": Color("25b8b0"), "e": Color("e84a5a")},
]
const SIDES: Dictionary = {"p": Color("8fb0d0"), "e": Color("d9705f")}
## Barres de la figurine : armure de tête, armure de corps, points de vie.
const BARS: Dictionary = {"head": Color("cfc8b8"), "body": Color("86a3c0"), "hp": Color("c4483a")}
const CB_BARS: Array = [
	{"head": Color("f2f2f2"), "body": Color("56b4e9"), "hp": Color("e8601c")},
	{"head": Color("f2f2f2"), "body": Color("25b8b0"), "hp": Color("e84a5a")},
]
## Couleurs de statut (jauges de la carte) : « mauvais » et « bon ».
const CB_STATUS: Array = [
	{"bad": Color("e8601c"), "ok": Color("56b4e9")},
	{"bad": Color("e84a5a"), "ok": Color("25b8b0")},
]
const INK_HC := Color("fffaf0")
const MUTE_HC := Color("d9cdb2")

static var cb_mode: int = 0
static var high_contrast: bool = false
static var reduce_motion: bool = false
static var tooltip_scale: float = 1.0

static var _theme: Theme
static var _title_font: Font
static var _bold_font: Font


static func _font(file: String, names: PackedStringArray, weight: int = 400) -> Font:
	if ResourceLoader.exists(file):
		return load(file) as Font
	var f := SystemFont.new()
	f.font_names = names
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	return f


static func title_font() -> Font:
	if _title_font == null:
		_title_font = _font("res://assets/fonts/PirataOne-Regular.ttf", PackedStringArray(["Pirata One", "Georgia", "Palatino Linotype", "Times New Roman"]))
	return _title_font


static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = _font("res://assets/fonts/AlegreyaSans-Bold.ttf", PackedStringArray(["Alegreya Sans", "Segoe UI", "Trebuchet MS", "Arial"]), 700)
	return _bold_font


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 1, radius: int = 3, pad: Vector4 = Vector4(10, 6, 10, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


## Taille de police multipliée par le réglage « Taille du texte » (Settings.text_size).
static func scaled_size(size: int) -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var st: Node = null if tree == null else tree.root.get_node_or_null("/root/Settings")
	var f: float = 1.0 if st == null else float(st.call("text_factor"))
	return maxi(8, roundi(size * f))


## Réapplique la taille du texte au thème partagé ; les écrans construits ensuite utilisent la nouvelle taille.
static func refresh_text_size() -> void:
	if _theme != null:
		_theme.default_font_size = scaled_size(15)
		_theme.set_font_size("normal_font_size", "RichTextLabel", scaled_size(14))
		apply_tooltip_scale(tooltip_scale)


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = _font("res://assets/fonts/AlegreyaSans-Regular.ttf", PackedStringArray(["Alegreya Sans", "Segoe UI", "Trebuchet MS", "Arial"]))
	t.default_font_size = scaled_size(15)
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font_size("normal_font_size", "RichTextLabel", scaled_size(14))
	_styles(t)
	_theme = t
	apply_accessibility(cb_mode, high_contrast, reduce_motion)
	apply_tooltip_scale(tooltip_scale)
	return t


static func morale_color(i: int) -> Color:
	var k: int = clampi(i, 0, MORALE_COLORS.size() - 1)
	return MORALE_COLORS[k] if cb_mode == 0 else (CB_MORALE[cb_mode - 1] as Array)[k]


## Symbole du moral, seulement en mode daltonien (sinon chaîne vide).
static func morale_symbol(i: int) -> String:
	return "" if cb_mode == 0 else str(MORALE_SYMBOLS[clampi(i, 0, MORALE_SYMBOLS.size() - 1)])


## Nom du moral, précédé de son symbole en mode daltonien.
static func morale_text(i: int) -> String:
	var n: String = str(Data.MORALE_NAMES[clampi(i, 0, Data.MORALE_NAMES.size() - 1)])
	return n if cb_mode == 0 else morale_symbol(i) + " " + n


static func side_color(side: String) -> Color:
	var pal: Dictionary = SIDES if cb_mode == 0 else CB_SIDES[cb_mode - 1]
	return pal.get(side, SIDES["e"])


static func bar_color(which: String) -> Color:
	var pal: Dictionary = BARS if cb_mode == 0 else CB_BARS[cb_mode - 1]
	return pal.get(which, Color.WHITE)


static func status_bad() -> Color:
	return BLOOD.lightened(0.25) if cb_mode == 0 else (CB_STATUS[cb_mode - 1] as Dictionary)["bad"]


static func status_ok() -> Color:
	return GOLD if cb_mode == 0 else (CB_STATUS[cb_mode - 1] as Dictionary)["ok"]


## Couleur de texte : en mode « texte plus contrasté », l'encre et le gris deviennent plus clairs.
static func text_color(c: Color) -> Color:
	if not high_contrast:
		return c
	if c == INK:
		return INK_HC
	if c == MUTE:
		return MUTE_HC
	return c


static func apply_accessibility(mode: int, contrast: bool, reduce: bool = false) -> void:
	cb_mode = clampi(mode, 0, 2)
	high_contrast = contrast
	reduce_motion = reduce
	if _theme != null:
		_theme.set_color("font_color", "Label", text_color(INK))
		_theme.set_color("default_color", "RichTextLabel", text_color(INK))


## Infobulles : taille de la police par défaut (la bulle suit le thème de la commande survolée).
static func apply_tooltip_scale(f: float) -> void:
	tooltip_scale = clampf(f, 1.0, 2.0)
	if _theme != null:
		_theme.set_font_size("font_size", "TooltipLabel", roundi(scaled_size(15) * tooltip_scale))


## Agrandit les étiquettes d'une infobulle personnalisée (à appeler sur la racine retournée par `_make_custom_tooltip`).
static func scale_tooltip(root: Node) -> void:
	if tooltip_scale <= 1.001:
		return
	for c in root.find_children("*", "Label", true, false):
		var l := c as Label
		var cur: int = l.get_theme_font_size("font_size")
		l.add_theme_font_size_override("font_size", roundi(cur * tooltip_scale))


static func illustrated() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var st: Node = null if tree == null else tree.root.get_node_or_null("/root/Settings")
	return st == null or bool(st.get("illustrated_ui"))


## Réapplique le style (plat ou illustré) au thème partagé, sur place : les écrans ouverts suivent.
static func apply_style() -> void:
	if _theme != null:
		_styles(_theme)


static func _tex(file: String, margin: int, content: Vector4, tile: bool = true) -> StyleBox:
	var path: String = "res://assets/ui/" + file + ".png"
	if not ResourceLoader.exists(path):
		return null
	var s := StyleBoxTexture.new()
	s.texture = load(path) as Texture2D
	s.set_texture_margin_all(margin)
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	if tile:
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s


## Remplace les boîtes plates par les cadres dessinés de assets/ui/ (voir tools/gen_ui.gd).
static func _skin(t: Theme) -> void:
	for type in ["Button", "OptionButton"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var f: String = {"normal": "normal", "hover": "hover", "pressed": "pressed", "hover_pressed": "pressed", "disabled": "disabled"}[st]
			var sb := _tex("btn_" + f, 9, Vector4(12, 6, 12, 6), false)
			if sb != null:
				t.set_stylebox(st, type, sb)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb2 := _tex("btn_pri_" + st, 9, Vector4(12, 6, 12, 6), false)
		if sb2 != null:
			t.set_stylebox(st, "PrimaryButton", sb2)
	var m: Dictionary = {
		"Card": ["card", 14, Vector4(16, 14, 16, 14)],
		"ModalPanel": ["modal", 36, Vector4(30, 28, 30, 28)],
		"ChipPanel": ["chip", 6, Vector4(7, 2, 7, 2)],
		"FlatPanel": ["flat", 5, Vector4(6, 3, 6, 3)],
		"NewsPanel": ["news", 6, Vector4(14, 8, 12, 8)],
	}
	for k in m:
		var a: Array = m[k]
		var sb3 := _tex(str(a[0]), int(a[1]), a[2])
		if sb3 != null:
			t.set_stylebox("panel", k, sb3)
	var pp := _tex("panel", 20, Vector4(16, 14, 16, 14))
	if pp != null:
		t.set_stylebox("panel", "PopupMenu", pp)


static func _styles(t: Theme) -> void:
	_flat_styles(t)
	if illustrated():
		_skin(t)
	_screen_variations(t)


## Variations de style partagées par les grands écrans (marché, inventaire…) : à utiliser par `theme_type_variation`
## plutôt que par des surcharges de style nœud par nœud. Indépendantes du réglage « Interface illustrée ».
##   WindowPanel : cadre d'une fenêtre plein écran · InsetPanel : zone encastrée · ResourcePanel : barre de ressources
##   ListPanel : colonne de liste · GoldScrollBar : barre de défilement dorée (VScrollBar)
static func _screen_variations(t: Theme) -> void:
	var panels: Dictionary = {
		"WindowPanel": box(Color("17130e"), Color("6b5630"), 2, 4, Vector4(8, 8, 8, 8)),
		"InsetPanel": box(Color("1d1812"), Color("4a3f31"), 1, 3, Vector4(8, 8, 8, 8)),
		"ResourcePanel": box(Color("14100c"), LINE, 1, 3, Vector4(10, 5, 10, 5)),
		"ListPanel": box(Color("1a1510"), Color("5a4a30"), 2, 3, Vector4(10, 8, 6, 8)),
	}
	for k in panels:
		t.set_type_variation(k, "PanelContainer")
		t.set_stylebox("panel", k, panels[k])
	t.set_type_variation("GoldScrollBar", "VScrollBar")
	t.set_stylebox("scroll", "GoldScrollBar", box(Color("0e0b08"), Color("3a2f22"), 1, 6, Vector4(0, 0, 0, 0)))
	t.set_stylebox("grabber", "GoldScrollBar", box(Color("8a6a2c"), Color("cfa851"), 1, 6, Vector4(0, 0, 0, 0)))
	t.set_stylebox("grabber_highlight", "GoldScrollBar", box(Color("b08a3a"), Color("e8c56a"), 1, 6, Vector4(0, 0, 0, 0)))
	t.set_stylebox("grabber_pressed", "GoldScrollBar", box(Color("c89a40"), Color("f0d27a"), 1, 6, Vector4(0, 0, 0, 0)))


## Barre de défilement dorée sur un ScrollContainer (thème : GoldScrollBar).
static func style_scrollbar(sc: ScrollContainer) -> void:
	var bar: VScrollBar = sc.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(14, 0)
	bar.theme_type_variation = "GoldScrollBar"


static func _flat_styles(t: Theme) -> void:
	# Boutons
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, box(PANEL2, LINE))
		t.set_stylebox("hover", type, box(PANEL2, GOLD))
		t.set_stylebox("pressed", type, box(Color("3d3322"), GOLD))
		t.set_stylebox("hover_pressed", type, box(Color("3d3322"), GOLD))
		t.set_stylebox("disabled", type, box(Color(PANEL2, 0.5), Color(LINE, 0.5)))
		t.set_stylebox("focus", type, box(Color.TRANSPARENT, GOLD, 2))
		t.set_color("font_color", type, INK)
		t.set_color("font_hover_color", type, INK)
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_hover_pressed_color", type, GOLD)
		t.set_color("font_focus_color", type, INK)
		t.set_color("font_disabled_color", type, Color(MUTE, 0.55))
		t.set_font("font", type, bold_font())
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(Color("6a231c"), Color("8f3328")))
	t.set_stylebox("hover", "PrimaryButton", box(Color("7c2a21"), GOLD))
	t.set_stylebox("pressed", "PrimaryButton", box(Color("7c2a21"), GOLD))
	t.set_stylebox("disabled", "PrimaryButton", box(Color(Color("6a231c"), 0.4), Color(Color("8f3328"), 0.4)))
	t.set_type_variation("GhostButton", "Button")
	t.set_stylebox("normal", "GhostButton", box(Color.TRANSPARENT, LINE))
	t.set_stylebox("disabled", "GhostButton", box(Color.TRANSPARENT, Color(LINE, 0.4)))

	# Panneaux
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(PANEL, LINE, 1, 4, Vector4(12, 12, 12, 12)))
	t.set_type_variation("FlatPanel", "PanelContainer")
	t.set_stylebox("panel", "FlatPanel", box(PANEL2, Color.TRANSPARENT, 0, 2, Vector4(5, 2, 5, 2)))
	t.set_type_variation("ChipPanel", "PanelContainer")
	t.set_stylebox("panel", "ChipPanel", box(PANEL2, LINE, 1, 2, Vector4(6, 1, 6, 1)))
	t.set_type_variation("NewsPanel", "PanelContainer")
	var news := box(PANEL, Color.TRANSPARENT, 0, 0, Vector4(12, 8, 12, 8))
	news.border_color = GOLD
	news.border_width_left = 3
	t.set_stylebox("panel", "NewsPanel", news)
	t.set_type_variation("ModalPanel", "PanelContainer")
	t.set_stylebox("panel", "ModalPanel", box(PANEL, GOLD, 1, 4, Vector4(18, 18, 18, 18)))
	t.set_type_variation("HeaderPanel", "PanelContainer")
	var head := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(0, 0, 0, 10))
	head.border_color = LINE
	head.border_width_bottom = 1
	t.set_stylebox("panel", "HeaderPanel", head)
	t.set_stylebox("panel", "PopupMenu", box(PANEL, GOLD, 1, 2, Vector4(4, 4, 4, 4)))
	t.set_stylebox("hover", "PopupMenu", box(PANEL2, Color.TRANSPARENT, 0, 2, Vector4(4, 2, 4, 2)))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", GOLD)

	# Onglets
	t.set_font("font", "TabContainer", title_font())
	t.set_font_size("font_size", "TabContainer", 24)
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_hovered_color", "TabContainer", GOLD)
	t.set_color("font_unselected_color", "TabContainer", MUTE)
	var tab_sel := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(12, 2, 12, 4))
	tab_sel.border_color = BLOOD
	tab_sel.border_width_bottom = 2
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	var tab_off := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(12, 2, 12, 4))
	t.set_stylebox("tab_unselected", "TabContainer", tab_off)
	t.set_stylebox("tab_hovered", "TabContainer", tab_off)
	t.set_stylebox("tab_focus", "TabContainer", tab_off)
	t.set_stylebox("panel", "TabContainer", box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(0, 10, 0, 0)))
	t.set_constant("separation", "HFlowContainer", 12)
	t.set_constant("h_separation", "HFlowContainer", 12)
	t.set_constant("v_separation", "HFlowContainer", 12)
