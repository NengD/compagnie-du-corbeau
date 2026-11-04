extends SceneTree
## Rastérise assets/app_icon.svg en PNG (16..256) dans assets/icons_png/ ; l'ICO est assemblé par tools/make_ico.py.
##   godot --path . --headless -s res://tools/gen_icon.gd

func _init() -> void:
	var svg: String = FileAccess.get_file_as_string("res://assets/app_icon.svg")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons_png"))
	for s in [16, 32, 48, 64, 128, 256]:
		var img := Image.new()
		var err: int = img.load_svg_from_string(svg, float(s) / 256.0)
		if err != OK:
			push_error("SVG illisible")
			quit(1)
			return
		img.save_png("res://assets/icons_png/icon_%d.png" % s)
		print("icon_%d.png %s" % [s, str(img.get_size())])
	quit(0)
