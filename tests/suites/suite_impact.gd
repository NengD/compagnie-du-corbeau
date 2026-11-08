extends RefCounted
## Ressenti des coups : paliers (tremblement + arrêt sur image) et sécurité du ralenti.
var t


func test_paliers() -> void:
	t.eq(ImpactFeel.tier({"hit": false}, 50.0, false)["name"], "none", "coup raté : aucun retour")
	t.eq(ImpactFeel.tier({"hit": true, "armor": 20, "hp": 0, "head": false}, 50.0, false)["name"], "small", "armure seule : petit")
	t.eq(ImpactFeel.tier({"hit": true, "armor": 0, "hp": 5, "head": false}, 50.0, false)["name"], "small", "petite blessure : petit")
	t.eq(ImpactFeel.tier({"hit": true, "armor": 0, "hp": 15, "head": false}, 50.0, false)["name"], "medium", "20 % des PV : moyen")
	t.eq(ImpactFeel.tier({"hit": true, "armor": 0, "hp": 8, "head": true}, 50.0, false)["name"], "large", "coup à la tête : grand")
	t.eq(ImpactFeel.tier({"hit": true, "armor": 0, "hp": 30, "head": true}, 50.0, true)["name"], "kill", "coup fatal : le plus fort")


func test_paliers_croissants() -> void:
	var order: Array = ["none", "small", "medium", "large", "kill"]
	for i in range(1, order.size()):
		var a: Dictionary = ImpactFeel.TIERS[order[i - 1]]
		var b: Dictionary = ImpactFeel.TIERS[order[i]]
		t.check(float(b["trauma"]) > float(a["trauma"]), "tremblement croissant : %s" % order[i])
		t.check(float(b["stop"]) >= float(a["stop"]), "arrêt sur image croissant : %s" % order[i])
		t.check(float(b["stop"]) <= 0.15, "arrêt sur image court : %s" % order[i])
	t.check(float(ImpactFeel.TIERS["kill"]["trauma"]) <= 1.0, "tremblement borné à 1")


func test_hit_stop_inactif_hors_animation() -> void:
	# En test, BattleScreen.speed vaut 0 : aucun ralenti ne doit jamais être posé.
	var before: float = Engine.time_scale
	BattleFx.hit_stop(null, 0.1)
	t.eq(Engine.time_scale, before, "hit_stop sans arbre / sans animation : temps inchangé")
	t.eq(Engine.time_scale, 1.0, "le temps du jeu est normal")


func test_trauma_sans_animation_ne_bouge_rien() -> void:
	var fx := BattleFx.new()
	var n := Node2D.new()
	n.position = Vector2(10, 20)
	fx.add_trauma(n, 0.9)
	t.eq(n.position, Vector2(10, 20), "pas d'animation (vitesse 0) : plateau immobile")
	fx.free()
	n.free()
