extends RefCounted
## Plateau : animations par arme, tirage de météo, décalcomanies (logique pure, sans fenêtre).
var t


func test_attack_anim_kinds() -> void:
	t.eq(AttackAnims.kind_for("arc"), "arrow", "arc -> flèche")
	t.eq(AttackAnims.kind_for("lance"), "thrust", "lance -> estoc")
	t.eq(AttackAnims.kind_for("masse"), "smash", "masse -> écrasement")
	t.eq(AttackAnims.kind_for("hache"), "slash", "hache -> taille")
	t.eq(AttackAnims.kind_for("inconnue"), "slash", "arme inconnue -> taille")
	t.eq(AttackAnims.kind_for("epee", "coup_bouclier"), "bash", "coup de bouclier")
	var from := Vector2(0, 0)
	var to := Vector2(100, 0)
	t.eq(AttackAnims.projectile_end(from, to, true), to + AttackAnims.CHEST, "touché : la flèche arrive")
	t.check(AttackAnims.projectile_end(from, to, false).distance_to(to + AttackAnims.CHEST) > 20.0, "raté : la flèche passe à côté")


func test_weather_roll() -> void:
	for b in ["plain", "forest", "hills", "water"]:
		var seen := {}
		for s in 300:
			var k: String = BattleWeather.roll(b, s)
			t.eq(k, BattleWeather.roll(b, s), "tirage stable")
			t.check(BattleWeather.KINDS.has(k), "météo valide")
			seen[k] = true
		t.check(seen.size() >= 3, "plusieurs météos possibles en " + b)
		if b != "hills":
			t.check(not seen.has("snow"), "pas de neige en " + b)


func test_decals_cap_and_carry() -> void:
	var d := BattleDecals.new()
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 200:
		d.add("blood", Vector2i(i % 5, 1), r)
	t.eq(d.count(), BattleDecals.MAX_DECALS, "nombre limité")
	d.add("arrow", Vector2i(0, 0), r)
	d.save_carry()
	t.check(BattleDecals.carried.size() <= BattleDecals.MAX_CARRY, "reste limité")
	for c in BattleDecals.carried:
		t.check(float(c["alpha"]) < 0.8, "estompé")
		t.check(c["kind"] != "arrow", "flèches non conservées")
	var n := BattleDecals.new()
	n.load_carry({Vector2i(1, 1): {}}, r)
	t.eq(n.count(), BattleDecals.MAX_CARRY, "repris dans la bataille suivante")
	t.eq(BattleDecals.carried.size(), 0, "reste vidé")
