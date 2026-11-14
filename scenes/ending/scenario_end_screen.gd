class_name ScenarioEndScreen
extends Control
## Écran de fin d'un scénario (objectif atteint ou délai écoulé). Comme EndingScreen : n'agit pas lui-même,
## il émet `action` ("free" = continuer en partie libre, "menu") et main.gd décide.

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
	var won: bool = Scenarios.result(Game.extras) == "won"
	var key: String = Scenarios.active(Game.extras)
	var st: Dictionary = Game.ending_stats()
	box.add_child(Illustrations.banner("victory" if won else "defeat", 150))
	var t := UiKit.title("Scénario réussi !" if won else "Scénario manqué", 56, GameTheme.GOLD if won else GameTheme.BLOOD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var sub := UiKit.sub(Scenarios.label(key) + " — " + Scenarios.goal_text(key), 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var p := UiKit.para(Scenarios.end_text(Game.extras))
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(p)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row in [["Jours écoulés", int(st["day"]) - 1], ["Hommes tombés", st["dead"]], ["Hommes encore sous le drapeau", st["men"]],
			["Victimes", st["kills"]], ["Couronnes", st["gold"]], ["Renom", st["renown"]]]:
		grid.add_child(UiKit.label(str(row[0]), 16, GameTheme.MUTE))
		var v := UiKit.label(str(row[1]), 20, GameTheme.GOLD, true)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(v)
	box.add_child(grid)
	var row2 := UiKit.hbox(10)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	var free := UiKit.button("Continuer en partie libre", "pri")
	free.pressed.connect(func() -> void: action.emit("free"))
	row2.add_child(free)
	var menu := UiKit.button("Menu")
	menu.pressed.connect(func() -> void: action.emit("menu"))
	row2.add_child(menu)
	box.add_child(row2)
	UiKit.focus_first.call_deferred(box)
