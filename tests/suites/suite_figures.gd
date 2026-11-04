extends RefCounted
## Figurines : tous les calques existent, chaque faction/équipement se construit, l'apparence est stable.
var t

const LAYERS: Array[String] = [
	"head", "head_orc", "face_0", "face_1", "face_2", "face_orc_0", "face_orc_1", "face_orc_2", "orc_crown", "orc_mantle",
	"skel_torso", "skel_rags", "skel_skull_0", "skel_skull_1", "skel_eyes", "skel_arm_off", "skel_hand_off",
	"zombie", "zombie_b", "zombie_big", "zombie_big_b", "ghoul", "ghoul_b", "ghoul_big", "ghoul_big_b",
	"cape", "satchel", "bandolier", "scarf", "band", "pauldron_mailles", "pauldron_brigandine",
]
const WEAPONS: Array[String] = ["gourdin", "fourche", "lance", "hache", "masse", "epee", "arc", "griffes", "griffesL"]


func _unit(fac: String, weapon: String, id: int, leader: bool = false) -> Unit:
	var u: Unit = t.mk(weapon, "e" if fac != "p" else "p")
	u.id = id
	u.faction = fac
	u.leader = leader
	return u


func test_layers_exist() -> void:
	for n in LAYERS:
		t.check(Figure.texture(n) != null, "calque %s" % n)
	for i in range(1, 8):
		t.check(Figure.texture("beard_%d" % i) != null, "barbe %d" % i)
	for i in 7:
		t.check(Figure.texture("hair_%d" % i) != null, "coiffure %d" % i)
	for w in ["gourdin", "fourche", "lance", "hache", "masse", "epee", "arc"]:
		for pre in ["weapon_", "arm_", "hand_", "skel_arm_", "skel_hand_"]:
			t.check(Figure.texture(pre + w) != null, pre + w)


func test_every_faction_builds() -> void:
	var id: int = 500
	for fac in ["p", "b", "o", "u", "g"]:
		for w in WEAPONS:
			var u: Unit = _unit(fac, w, id, id % 5 == 0)
			id += 1
			u.shield = (id % 2 == 0) and w != "arc" and not w.begins_with("griffes")
			var f: Figure = Figure.new().setup(u)
			t.check(f.get_child_count() >= 1, "%s/%s a des calques" % [fac, w])
			t.check(f.base_scale >= 1.0, "carrure %s" % fac)
			f.free()


func test_orc_build_is_wider() -> void:
	t.check(Figure.body_scale(_unit("o", "hache", 1)) > 1.0, "orc plus large")
	t.check(Figure.body_scale(_unit("o", "hache", 1, true)) > Figure.body_scale(_unit("o", "hache", 1)), "chef orc plus grand")
	t.eq(Figure.body_scale(_unit("p", "hache", 1)), 1.0, "humain inchangé")


func test_look_is_stable() -> void:
	var u: Unit = _unit("p", "epee", 77)
	t.eq(Figure.look(u), Figure.look(u), "même id, même apparence")


func test_fx_silent_without_speed() -> void:
	var fx := BattleFx.new()
	fx.impact(Vector2.ZERO, true, true, Vector2.RIGHT)
	fx.dust(Vector2.ZERO)
	fx.death(Vector2.ZERO)
	t.check(true, "aucun plantage hors arbre")
	fx.free()
