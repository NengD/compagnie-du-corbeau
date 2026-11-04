class_name PerkScreen
extends Control
## Fenêtre modale qui héberge un `PerkTree` (arbre de 50 talents). Ouverture : `PerkScreen.open(host, unit)`.
## Les règles restent dans `Perks` / `Game` ; l'arbre lui-même est `PerkTree` (réutilisable dans l'écran de personnage).

signal closed

var unit: Unit
var game: Node  ## l'état de campagne (autoload Game ; injectable pour les tests)
var tree: PerkTree
var _layer: CanvasLayer


static func open(host: Node, u: Unit, game_node: Node = null) -> PerkScreen:
	var layer := CanvasLayer.new()
	layer.layer = 55
	host.add_child(layer)
	var s := PerkScreen.new()
	s.unit = u
	s.game = game_node if game_node != null else host.get_node("/root/Game")
	s._layer = layer
	s.theme = GameTheme.get_theme()
	layer.add_child(s)
	s._build()
	return s


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ModalPanel"
	margin.add_child(panel)
	var root := UiKit.vbox(8)
	panel.add_child(root)
	var head := UiKit.hbox(12)
	head.add_child(PortraitView.new(unit, 56))
	var who := UiKit.vbox(0)
	who.add_child(UiKit.title(unit.unit_name, 30))
	who.add_child(UiKit.sub("%s · niveau %d · %d talent%s appris" % [unit.background, unit.level, unit.perks.size(), "s" if unit.perks.size() > 1 else ""], 14, false))
	head.add_child(who)
	head.add_child(UiKit.spacer())
	var close_b := UiKit.button("Fermer", "", true)
	close_b.pressed.connect(close)
	head.add_child(close_b)
	root.add_child(head)
	tree = PerkTree.new()
	tree.game = game
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(tree)
	tree.set_unit(unit)


func _input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	if is_instance_valid(_layer):
		_layer.queue_free()
