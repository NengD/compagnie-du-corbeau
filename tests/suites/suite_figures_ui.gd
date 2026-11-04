extends RefCounted
## Figurines, tenues, usure, portraits (logique pure, sans fenêtre).
var t


func _unit(id: int) -> Unit:
	var u := Unit.new()
	u.id = id
	u.side = "p"
	u.body = "mailles"
	u.head = "casque"
	u.arm_b = 130
	u.arm_h = 90
	u.hp_max = 60
	u.hp = 60
	return u


func test_apparence_stable() -> void:
	var u := _unit(5)
	t.eq(Figure.look(u)["beard"], Figure.look(u)["beard"], "look stable")
	t.eq(Figure.outfit(u), Figure.outfit(u), "tenue stable")


func test_usure() -> void:
	t.eq(Figure.wear_level(100, 100), 0, "neuf")
	t.eq(Figure.wear_level(60, 100), 1, "abîmé")
	t.eq(Figure.wear_level(20, 100), 2, "en lambeaux")
	var u := _unit(6)
	t.eq(Figure.wear_state(u)["body"], 0, "armure pleine")
	u.arm_b = 70
	t.eq(Figure.wear_state(u)["body"], 1, "armure à 54 %")


func test_humeur() -> void:
	var u := _unit(7)
	t.eq(PortraitView.mood_of(u), "normal", "normal")
	u.morale = 4
	t.eq(PortraitView.mood_of(u), "galvanise", "confiant")
	u.morale = 1
	t.eq(PortraitView.mood_of(u), "effraye", "brisé")
	u.morale = 3
	u.hp = 10
	t.eq(PortraitView.mood_of(u), "blesse", "blessé")
	u.dead = true
	t.eq(PortraitView.mood_of(u), "mort", "mort")


func test_creatures() -> void:
	var u := _unit(8)
	u.sprite = "wolf"
	t.check(PortraitView.is_creature(u), "loup = créature")
	t.check(Figure.texture("wolf") != null and Figure.texture("wolf_fx") != null, "calques du loup")
	t.check(Figure.texture("wolf_rider_orc") != null, "cavalier")
	t.eq(Figure.wear_state(u)["body"], 0, "pas d'usure sur une créature")
