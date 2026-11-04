extends RefCounted
## Réglages : bornes, sérialisation, ancien fichier, résolutions. Sans fenêtre ni disque.
var t


func _mk() -> Node:
	var s: Node = load("res://autoload/Settings.gd").new()
	s.persist = false
	return s


func test_defaults_and_bounds() -> void:
	var s: Node = _mk()
	t.eq(s.ui_scale, 100, "échelle par défaut")
	t.eq(s.window_mode, 0, "fenêtré par défaut")
	t.check(not s.confirm_end_turn, "confirmation de fin de tour désactivée par défaut")
	t.check(s.screen_shake, "tremblement activé par défaut")
	s.set_value("ui_scale", 500)
	t.eq(s.ui_scale, 150, "échelle bornée en haut")
	s.set_value("ui_scale", 10)
	t.eq(s.ui_scale, 75, "échelle bornée en bas")
	s.set_value("vsync", 9)
	t.eq(s.vsync, 2, "vsync borné")
	s.set_value("msaa", -3)
	t.eq(s.msaa, 0, "msaa borné")
	s.set_value("master_volume", 4.0)
	t.eq(s.master_volume, 1.0, "volume borné")
	s.set_value("text_size", "grand")
	t.eq(s.text_size, 1, "valeur illisible -> défaut")
	s.set_value("text_size", 2)
	t.check(is_equal_approx(s.text_factor(), 1.2), "facteur de texte grand")
	s.set_value("fps_limit", 4)
	t.eq(s.fps_cap(), 0, "illimité = 0")
	s.set_value("inconnu", 3)  # ignoré sans erreur
	s.free()


func test_roundtrip() -> void:
	var s: Node = _mk()
	s.set_value("window_mode", 1)
	s.set_value("window_w", 1600)
	s.set_value("window_h", 900)
	s.set_value("ui_scale", 125)
	s.set_value("screen_shake", false)
	s.set_value("confirm_end_turn", true)
	s.set_value("skip_splash", true)
	s.set_value("music_volume", 0.25)
	var c: ConfigFile = s.to_config()
	var s2: Node = _mk()
	s2.from_config(c)
	t.eq(s2.window_mode, 1, "mode conservé")
	t.eq(s2.window_w, 1600, "largeur conservée")
	t.eq(s2.ui_scale, 125, "échelle conservée")
	t.check(not s2.screen_shake, "tremblement conservé")
	t.check(s2.confirm_end_turn and s2.skip_splash, "booléens conservés")
	t.check(is_equal_approx(s2.music_volume, 0.25), "volume conservé")
	s.reset_defaults()
	t.eq(s.ui_scale, 100, "valeurs par défaut")
	t.check(s.screen_shake and not s.skip_splash, "défauts booléens")
	s.free()
	s2.free()


func test_old_settings_file() -> void:
	var c := ConfigFile.new()  # ancien format : volumes, fullscreen, vitesse, tutoriel
	c.set_value("audio", "master", 0.5)
	c.set_value("video", "fullscreen", true)
	c.set_value("game", "battle_speed", 7)
	c.set_value("game", "tutorial_seen", true)
	var s: Node = _mk()
	s.from_config(c)
	t.check(is_equal_approx(s.master_volume, 0.5), "volume repris")
	t.eq(s.window_mode, 2, "ancien plein écran -> sans bordure")
	t.eq(s.battle_speed, 2, "vitesse bornée")
	t.check(s.tutorial_seen, "tutoriel vu repris")
	t.eq(s.ui_scale, 100, "clé absente -> défaut")
	t.eq(s.vsync, 1, "vsync absent -> défaut")
	var bad := ConfigFile.new()
	bad.set_value("video", "ui_scale", "énorme")
	bad.set_value("game", "screen_shake", "oui")
	var s2: Node = _mk()
	s2.from_config(bad)
	t.eq(s2.ui_scale, 100, "valeur d'un mauvais type -> défaut")
	t.check(s2.screen_shake, "booléen illisible -> défaut")
	s.set_value("fullscreen", false)
	t.eq(s.window_mode, 0, "ancienne clé fullscreen acceptée")
	s.free()
	s2.free()


func test_resolutions() -> void:
	var s: Node = _mk()
	var small: Array = s.resolution_list(Vector2i(1366, 768))
	t.eq(small.size(), 2, "écran 1366×768 : deux tailles")
	t.eq(small[1], Vector2i(1366, 768), "la plus grande qui tient")
	t.eq(s.resolution_list(Vector2i(800, 600)).size(), 0, "petit écran : aucune")
	t.eq(s.resolution_list(Vector2i(3840, 2160)).size(), 5, "grand écran : toutes")
	var p: Vector2i = s.clamp_position(Vector2i(5000, -40), Vector2i(1280, 720), Rect2i(0, 0, 1920, 1080))
	t.eq(p, Vector2i(640, 0), "position ramenée dans l'écran")
	s.free()
