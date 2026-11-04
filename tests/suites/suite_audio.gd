extends RefCounted
## Audio : l'API ne plante jamais (headless = silence) et tous les fichiers déclarés existent.
var t


func _audio() -> Node:
	return load("res://autoload/Audio.gd").new()


func test_audio_api_is_safe_in_headless() -> void:
	var a := _audio()
	a.play("hit_flesh")
	t.eq(a.last_event, "hit_flesh", "événement mémorisé")
	a.play("evenement_inconnu")
	a.music("battle")
	t.eq(a.current_music, "battle", "piste mémorisée")
	a.music("piste_inconnue")
	a.stop_music()
	t.eq(a.current_music, "", "musique arrêtée")
	a.free()


func test_audio_files_exist() -> void:
	var a := _audio()
	for ev: String in a.EVENTS:
		for f: String in a.EVENTS[ev]["files"]:
			t.check(ResourceLoader.exists(a.SFX_DIR + f), "son manquant : " + f)
	for tr: String in a.TRACKS:
		t.check(ResourceLoader.exists(a.MUSIC_DIR + String(a.TRACKS[tr]["file"])), "piste manquante : " + tr)
		var amb := String(a.TRACKS[tr].get("ambience", ""))
		if amb != "":
			t.check(ResourceLoader.exists(a.MUSIC_DIR + amb), "ambiance manquante : " + amb)
	a.free()


func test_item_icons() -> void:
	t.check(ItemIcons.get_icon("weapon", "hache") != null, "icône de hache")
	t.check(ItemIcons.get_icon("shield", "") != null, "icône de bouclier")
	t.check(ItemIcons.get_icon("head", "none") == null, "pas d'icône pour tête nue")
	t.check(ItemIcons.get_icon("body", "inconnu") == null, "clé inconnue -> null")
	for k: String in Data.WPN:
		t.check(ItemIcons.get_icon("weapon", k) != null, "icône arme " + k)
	for k: String in Data.HEAD:
		if k != "none":
			t.check(ItemIcons.get_icon("head", k) != null, "icône tête " + k)
	for k: String in Data.BODY:
		if k != "none":
			t.check(ItemIcons.get_icon("body", k) != null, "icône corps " + k)
