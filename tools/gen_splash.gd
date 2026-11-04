extends Node
## Dessine assets/splash.png (écran de lancement du moteur). Fenêtre requise (pas --headless) :
##   godot --path . --screen 1 --resolution 1280x720 res://tools/gen_splash.tscn

const ICON: Texture2D = preload("res://assets/app_icon.svg")
const TITLE: Font = preload("res://assets/fonts/PirataOne-Regular.ttf")
const BODY: Font = preload("res://assets/fonts/AlegreyaSans-Regular.ttf")

class Painter extends Control:
	func _draw() -> void:
		var sz: Vector2 = size
		draw_rect(Rect2(Vector2.ZERO, sz), Color("1c1915"))
		for i in 0:
			var k: float = float(i) / 12.0
			draw_rect(Rect2(Vector2.ZERO, sz).grow(-k * 60.0), Color(0.55, 0.12, 0.09, 0.012), false, 40.0)
		draw_rect(Rect2(Vector2(24, 24), sz - Vector2(48, 48)), Color("b03a2e"), false, 3.0)
		draw_rect(Rect2(Vector2(34, 34), sz - Vector2(68, 68)), Color("cfa851", 0.55), false, 1.0)
		var tex: Texture2D = preload("res://assets/app_icon.svg")
		draw_texture_rect(tex, Rect2(sz.x / 2 - 130, 90, 260, 260), false)
		var font: Font = preload("res://assets/fonts/PirataOne-Regular.ttf")
		draw_string(font, Vector2(0, 470), "Compagnie du Corbeau", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 84, Color("cfa851"))
		var body: Font = preload("res://assets/fonts/AlegreyaSans-Regular.ttf")
		draw_string(body, Vector2(0, 520), "Jeu tactique de mercenaires", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 26, Color("b9ad96"))


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var p := Painter.new()
	p.size = Vector2(1280, 720)
	add_child(p)
	await get_tree().create_timer(1.0).timeout
	p.queue_redraw()
	await get_tree().create_timer(1.0).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://assets/splash.png")
	print("splash.png ", img.get_size())
	get_tree().quit(0)
