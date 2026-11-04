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


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = _font("res://assets/fonts/AlegreyaSans-Regular.ttf", PackedStringArray(["Alegreya Sans", "Segoe UI", "Trebuchet MS", "Arial"]))
	t.default_font_size = scaled_size(15)
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font_size("normal_font_size", "RichTextLabel", scaled_size(14))

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
	_theme = t
	return t
