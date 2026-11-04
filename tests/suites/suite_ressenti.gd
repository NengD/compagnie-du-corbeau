extends RefCounted
## Ressenti : dosage sonore (variantes, limiteur, voix), tutoriel (étapes, progression, mémorisation).
var t


func _audio() -> Node:
	return load("res://autoload/Audio.gd").new()


func test_variants_never_repeat() -> void:
	var a := _audio()
	var last: int = -1
	var seen := {}
	for i in 200:
		var v: int = a.choose_variant("hit_flesh", 3)
		t.check(v >= 0 and v < 3, "indice dans la plage")
		t.check(v != last, "variante différente de la précédente")
		last = v
		seen[v] = true
	t.eq(seen.size(), 3, "les trois variantes sortent")
	t.eq(a.choose_variant("levelup", 1), 0, "une seule variante -> 0")
	t.eq(a.choose_variant("levelup", 1), 0, "une seule variante, encore")
	a.free()


func test_limiter_gap_and_unknown() -> void:
	var a := _audio()
	t.check(a.allow("step", 10.0), "premier pas joué")
	t.check(not a.allow("step", 10.02), "deuxième pas trop proche écarté")
	t.check(a.allow("step", 10.2), "pas suivant après le délai")
	t.check(a.allow("click", 10.2), "un autre événement n'est pas gêné")
	t.check(not a.allow("evenement_inconnu", 10.0), "événement inconnu refusé")
	a.free()


func test_voice_policy_and_victim() -> void:
	var a := _audio()
	t.check(a.voice_policy(2, 10, 10), "essentiel toujours joué")
	t.check(not a.voice_policy(1, 10, 10), "normal refusé quand tout est pris")
	t.check(a.voice_policy(1, 9, 10), "normal accepté s'il reste une voix")
	t.check(not a.voice_policy(0, 7, 10), "secondaire écarté quand presque plein")
	t.check(a.voice_policy(0, 6, 10), "secondaire accepté avec de la marge")
	t.eq(a.pick_victim([2, 0, 1, 0], [1.0, 5.0, 2.0, 3.0]), 3, "sacrifie la plus basse priorité, la plus ancienne")
	t.eq(a.pick_victim([1, 1], [4.0, 2.0]), 1, "à égalité de priorité, la plus ancienne")
	var p: float = a.pitch_for(0.1)
	t.check(p >= 0.9 and p <= 1.1, "hauteur dans la variation")
	t.check(a.pitch_for(-0.18) < 0.9, "hauteur fixe baissée")
	a.free()


func test_events_config_sane() -> void:
	var a := _audio()
	for ev: String in a.EVENTS:
		var c: Dictionary = a.EVENTS[ev]
		t.check(float(c["db"]) <= 0.0, "volume relatif <= 0 dB : " + ev)
		t.check(c.has("gap") and c.has("prio"), "gap et prio : " + ev)
	a.free()


func test_tutorial_steps() -> void:
	t.check(TutorialData.STEPS.size() >= 4 and TutorialData.STEPS.size() <= 6, "4 à 6 étapes")
	var seen: Array = []
	var s: Dictionary = TutorialData.next_step("town", seen)
	t.eq(s["id"], "town_contract", "première étape en ville")
	seen.append("town_contract")
	t.eq(TutorialData.next_step("town", seen)["id"], "town_leave", "puis quitter la ville")
	seen.append("town_leave")
	t.check(TutorialData.next_step("town", seen).is_empty(), "plus d'étape en ville")
	t.check(TutorialData.next_step("company", seen).is_empty(), "aucune étape sur un écran sans conseil")
	for st in TutorialData.STEPS:
		t.check(str(st["title"]) != "" and str(st["text"]) != "", "texte présent : " + str(st["id"]))


func test_tutorial_flow() -> void:
	var settings: Node = load("res://autoload/Settings.gd").new()
	settings.persist = false
	var tu := Tutorial.new()
	tu.settings = settings
	tu.notify("town")
	t.check(not tu.active and tu.shown.is_empty(), "inactif : rien ne s'affiche")
	tu.begin()
	t.check(tu.active and not settings.tutorial_seen, "démarré, pas encore vu")
	tu.notify("town")
	t.eq(tu.shown["id"], "town_contract", "carte en ville")
	tu.dismiss()
	t.eq(tu.shown["id"], "town_leave", "deuxième carte du même écran")
	tu.notify("map")  # on quitte la ville sans fermer la carte
	t.eq(tu.shown["id"], "map_travel", "carte de la route")
	t.check(tu.seen.has("town_leave"), "l'écran quitté compte comme vu")
	tu.notify("battle")
	tu.dismiss()
	tu.dismiss()
	t.check(tu.shown.is_empty(), "plus de carte de bataille")
	tu.notify("end")
	t.eq(tu.shown["id"], "loot_end", "carte du butin")
	tu.dismiss()
	t.check(not tu.active and settings.tutorial_seen, "terminé : mémorisé comme vu")
	tu.begin()
	t.check(tu.active and not settings.tutorial_seen, "on peut le revoir")
	tu.skip()
	t.check(not tu.active and settings.tutorial_seen, "passer = vu")
	tu.free()
	settings.free()
