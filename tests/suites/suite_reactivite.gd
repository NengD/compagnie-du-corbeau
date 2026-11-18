extends RefCounted
## Réactivité de l'interface : logique de FitBox (échelle d'ajustement, centrage) ; les grands écrans à 853×480 sont dans smoke_ui.
var t


func test_echelle_ajustement() -> void:
	var f: Script = load("res://scenes/ui/fit_box.gd")
	t.eq(f.compute_scale(Vector2(400, 300), Vector2(800, 600)), 1.0, "tient largement : échelle 1")
	t.eq(f.compute_scale(Vector2(800, 600), Vector2(800, 600)), 1.0, "tient pile : échelle 1")
	t.eq(f.compute_scale(Vector2(1000, 400), Vector2(800, 600)), 0.8, "trop large : rapport des largeurs")
	t.eq(f.compute_scale(Vector2(400, 1200), Vector2(800, 600)), f.MIN_SCALE, "trop haut : rapport des hauteurs, plancher")
	t.eq(f.compute_scale(Vector2(2000, 2000), Vector2(500, 500)), f.MIN_SCALE, "très grand : plancher (défilement)")
	t.eq(f.compute_scale(Vector2(1000, 900), Vector2(800, 720)), 0.8, "les deux axes : le plus serré")
	t.eq(f.compute_scale(Vector2.ZERO, Vector2(800, 600)), 1.0, "contenu vide : 1")
	t.eq(f.compute_scale(Vector2(100, 100), Vector2.ZERO), 1.0, "zone inconnue : 1 (jamais agrandi)")
	for i in 40:
		var s: float = f.compute_scale(Vector2(50 + i * 97, 40 + i * 53), Vector2(853, 480))
		t.check(s <= 1.0 and s >= f.MIN_SCALE, "échelle toujours dans [plancher, 1] (%f)" % s)


func test_centrage() -> void:
	var f: Script = load("res://scenes/ui/fit_box.gd")
	t.eq(f.centered_pos(Vector2(800, 600), Vector2(400, 200), 1.0), Vector2(200, 200), "centré à l'échelle 1")
	t.eq(f.centered_pos(Vector2(800, 600), Vector2(1000, 600), 0.8), Vector2(0, 60), "réduit : centré, collé au bord sur l'axe plein")
	var p: Vector2 = f.centered_pos(Vector2(100, 100), Vector2(1000, 1000), 0.6)
	t.check(p.x >= 0.0 and p.y >= 0.0, "jamais de position négative (le défilement prend le relais)")


## Un contenu trop grand est réduit pour tenir dans la zone, centré, sans être agrandi quand il tient.
func test_fitbox_en_arbre() -> void:
	var host := Control.new()
	host.size = Vector2(853, 480)
	t.root.add_child(host)
	var big := Control.new()
	big.custom_minimum_size = Vector2(977, 640)
	var fb: Control = load("res://scenes/ui/fit_box.gd").add_to(host, big, false)
	fb.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fb.size = Vector2(853, 480)
	fb.call("_refit")
	fb.notification(Container.NOTIFICATION_SORT_CHILDREN)
	fb.call("_place")
	var s: float = fb.scale_now
	t.check(s < 1.0 and s >= 0.6, "contenu 977×640 dans 853×480 : réduit (%f)" % s)
	t.check(is_equal_approx(big.scale.x, s) and is_equal_approx(big.scale.y, s), "mise à l'échelle uniforme")
	t.check(big.size.x * s <= 853.5 and big.size.y * s <= 480.5 or s <= 0.6001, "le contenu réduit tient dans la zone")
	var small := Control.new()
	small.custom_minimum_size = Vector2(300, 200)
	big.queue_free()
	var fb2: Control = load("res://scenes/ui/fit_box.gd").add_to(host, small, false)
	fb2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fb2.size = Vector2(853, 480)
	fb2.call("_refit")
	t.eq(fb2.scale_now, 1.0, "petit contenu : jamais agrandi")
	host.queue_free()
