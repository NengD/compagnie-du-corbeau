class_name EndingScreen
extends Control
## Écran de fin de campagne (crise finale écrasée) : récapitulatif, puis « Continuer en mode libre » ou « Menu ».
## N'agit pas lui-même : il émet `action` ("free" ou "menu") et main.gd décide.

signal action(what: String)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := UiKit.vbox(12)
	box.custom_minimum_size = Vector2(620, 0)
	center.add_child(box)
	var st: Dictionary = Game.ending_stats()
	var t := UiKit.title("Victoire !", 64, GameTheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var p := UiKit.para("%s est brisé. Le royaume respire, et l'on chantera longtemps le nom de la Compagnie du Corbeau — celui de ceux qui sont tombés en chemin aussi." % (str(st["threat"])[0].to_upper() + str(st["threat"]).substr(1)))
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(p)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row in [
		["Jours de campagne", st["day"]], ["Hommes tombés", st["dead"]], ["Hommes encore sous le drapeau", st["men"]],
		["Victimes", st["kills"]], ["Couronnes", st["gold"]], ["Renom", st["renown"]],
		["Lieux hostiles pris", st["sites"]], ["Affaires closes (arcs)", st["arcs"]],
	]:
		grid.add_child(UiKit.label(str(row[0]), 16, GameTheme.MUTE))
		var v := UiKit.label(str(row[1]), 20, GameTheme.GOLD, true)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(v)
	box.add_child(grid)
	if not (st["log"] as Array).is_empty():
		box.add_child(UiKit.title("Récits de la compagnie", 22))
		for l in st["log"]:
			box.add_child(UiKit.sub(str(l), 14))
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var free := UiKit.button("Continuer en mode libre", "pri")
	free.pressed.connect(func() -> void: action.emit("free"))
	row.add_child(free)
	var menu := UiKit.button("Menu")
	menu.pressed.connect(func() -> void: action.emit("menu"))
	row.add_child(menu)
	box.add_child(row)
