class_name TownArrival
extends Control
## Écran d'arrivée en ville (≈ 1 s) : remparts au crépuscule, nom du lieu en grand, fondu. Ne bloque rien (souris ignorée).

const DURATION := 1.0


## Affiche l'arrivée sur `host`. Sans effet si `speed` vaut 0 (tests) ou si l'arbre n'est pas disponible.
static func show_over(host: Control, place: String, speed: float = 1.0) -> TownArrival:
	if speed <= 0.0 or host == null or not host.is_inside_tree():
		return null
	var t := TownArrival.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t._place = place
	host.add_child(t)
	t.modulate.a = 0.0
	var tw: Tween = t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.15 * speed)
	tw.tween_interval(DURATION * 0.55 * speed)
	tw.tween_property(t, "modulate:a", 0.0, 0.3 * speed)
	tw.tween_callback(t.queue_free)
	return t


var _place: String = ""


func _draw() -> void:
	Illustrations.paint(self, Rect2(Vector2.ZERO, size), "town")
	var f: Font = GameTheme.title_font()
	var fs: int = GameTheme.scaled_size(72)
	var w: float = f.get_string_size(_place, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	var p := Vector2((size.x - w) * 0.5, size.y * 0.32)
	draw_string(f, p + Vector2(3, 3), _place, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
	draw_string(f, p, _place, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GameTheme.INK)
