extends RefCounted
## Figurines 2 : silhouettes variées (stables, bornées), montures (cheval), poses d'attaque, aucun délai à vitesse 0.
var t


func _unit(fac: String, id: int, bg: String = "") -> Unit:
	var u: Unit = t.mk("epee", "e" if fac != "p" else "p")
	u.id = id
	u.faction = fac
	u.background = bg
	return u


func test_silhouette_stable_and_bounded() -> void:
	var builds: Dictionary = {}
	for id in range(1, 301):
		for fac in ["p", "b", "o", "u"]:
			var u: Unit = _unit(fac, id)
			var a: Dictionary = Figure.silhouette(u)
			t.eq(a, Figure.silhouette(u), "silhouette stable (id %d)" % id)
			t.check(float(a["w"]) >= Figure.SIL_W_MIN and float(a["w"]) <= Figure.SIL_W_MAX, "largeur bornée")
			t.check(float(a["h"]) >= Figure.SIL_H_MIN and float(a["h"]) <= Figure.SIL_H_MAX, "taille bornée")
			t.check(float(a["head"]) >= Figure.SIL_HEAD_MIN and float(a["head"]) <= Figure.SIL_HEAD_MAX, "tête bornée")
			builds[int(a["build"])] = true
	t.eq(builds.size(), 3, "mince, normale et costaude apparaissent")


func test_silhouette_leaves_creatures_alone() -> void:
	var g: Unit = _unit("g", 12)
	t.eq(float(Figure.silhouette(g)["w"]), 1.0, "goule inchangée")
	var w: Unit = _unit("m", 13)
	w.sprite = "wolf"
	t.eq(float(Figure.silhouette(w)["h"]), 1.0, "loup inchangé")


func test_background_nudges_build() -> void:
	var heavy: int = 0
	var lean: int = 0
	for id in range(1, 201):
		heavy += int(Figure.silhouette(_unit("p", id, "Bûcheron"))["build"])
		lean += int(Figure.silhouette(_unit("p", id, "Braconnier"))["build"])
	t.check(heavy > lean, "les bûcherons sont plus massifs que les braconniers")


func test_figure_applies_shape_without_touching_rules() -> void:
	var u: Unit = _unit("p", 31)
	var hp: float = u.hp_max
	var f: Figure = Figure.new().setup(u)
	var sil: Dictionary = Figure.silhouette(u)
	t.check(is_equal_approx(f.shape.x, float(sil["w"])) and is_equal_approx(f.shape.y, float(sil["h"])), "forme appliquée")
	t.eq(f.base_scale, 1.0, "carrure de base intacte")
	t.eq(u.hp_max, hp, "aucune règle touchée")
	f.free()
	var portrait: Figure = Figure.new().setup(u, false)
	t.eq(portrait.shape, Vector2.ONE, "portrait : cadrage fixe")
	portrait.free()


func test_mount_layers_exist() -> void:
	for n in ["mount_horse", "mount_horse_fx", "mount_horse_front"]:
		t.check(Figure.texture(n) != null, "calque " + n)
	for k in Data.FOE:
		var m: String = str(Data.FOE[k].get("mount", ""))
		if m != "":
			t.check(Figure.MOUNT_TINTS.has(m), "teintes de la monture %s (%s)" % [m, k])
			for suffix in ["", "_fx", "_front"]:
				t.check(Figure.texture("mount_%s%s" % [m, suffix]) != null, "calque monture %s%s" % [m, suffix])


func test_cavalry_foe_builds_mounted() -> void:
	t.check(Data.FOE.has("cavalier_brigand"), "ligne cavalier brigand")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var u: Unit = Contracts.make_foe("cavalier_brigand", rng)
	t.eq(Figure.mount_of(u), "horse", "monture lue depuis Data.FOE")
	var f: Figure = Figure.new().setup(u)
	t.check(f.mounted, "cavalier monté")
	t.check(f.shape.x < 1.0 + 0.001 or f.shape.x <= Figure.SIL_W_MAX, "taille réduite pour tenir sur la case")
	f.free()
	var foot: Unit = Contracts.make_foe("brigand", rng)
	t.eq(Figure.mount_of(foot), "", "brigand à pied")
	t.eq(Figure.mount_of(_unit("p", 3)), "", "homme de la compagnie à pied")
	var pf: Figure = Figure.new().setup(u, false)
	t.check(not pf.mounted, "portrait sans monture")
	pf.free()
	var cavalry: int = 0
	for d in [2, 3]:
		cavalry += (Contracts.foes_for("b", d) as Array).count("cavalier_brigand")
	t.check(cavalry >= 2, "cavaliers dans les bandes de danger moyen et élevé")
	var hp: float = u.hp_max
	var sav: Unit = Unit.from_dict(u.to_dict())
	t.eq(Figure.mount_of(sav), "horse", "monture conservée par la sauvegarde")
	t.eq(sav.hp_max, hp, "stats conservées")


func test_poses_cover_every_attack_kind() -> void:
	var kinds: Dictionary = {}
	for w in AttackAnims.TABLE:
		kinds[AttackAnims.TABLE[w]] = true
	for k in AttackAnims.ABILITY_KIND.values():
		kinds[k] = true
	for k in kinds:
		t.check(UnitView.POSES.has(k), "pose pour %s" % k)
	for k in UnitView.POSES:
		var p: Dictionary = UnitView.POSES[k]
		var total: float = float(p["t1"]) + float(p["t2"]) + float(p["t3"])
		t.check(total <= 0.34, "pose %s courte (%.2f s)" % [k, total])
		t.check(UnitView.impact_delay(k) <= 0.15, "impact rapide pour %s" % k)


func test_no_delay_at_speed_zero() -> void:
	var u: Unit = _unit("p", 9)
	var v: UnitView = UnitView.new().setup(u)
	# à vitesse 0 (aucune bataille à l'écran) les animations rendent la main sans créer de tween ni attendre
	v.lunge(Vector2(50, 0), "smash")
	v.parry(Vector2.RIGHT)
	v.squash()
	v.hit_flash()
	t.check(v._lean == 0.0 and v._off == Vector2.ZERO, "aucune pose engagée à vitesse 0")
	v.free()


func test_mounted_view_is_wider() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8
	var rider: UnitView = UnitView.new().setup(Contracts.make_foe("cavalier_brigand", rng))
	var foot: UnitView = UnitView.new().setup(Contracts.make_foe("brigand", rng))
	t.check(rider._ws > foot._ws, "socle plus large pour un cavalier")
	rider.free()
	foot.free()
