extends Node
## Réglages du joueur (volumes, plein écran, vitesse des animations), sauvegardés dans user://settings.cfg.
## Les autres systèmes lisent les propriétés et écoutent `changed`.

signal changed

const PATH: String = "user://settings.cfg"
## Vitesse des animations de bataille : multiplicateur de durée appliqué à BattleScreen.speed (plus petit = plus rapide).
const BATTLE_SPEEDS: Array = [
	{"n": "Rapide", "f": 0.5},
	{"n": "Normale", "f": 1.0},
	{"n": "Lente", "f": 1.6},
]

var master_volume: float = 1.0  ## 0..1
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var fullscreen: bool = false
var battle_speed: int = 1  ## index dans BATTLE_SPEEDS
var tutorial_seen: bool = false  ## le tutoriel a été terminé ou passé (absent des anciens fichiers -> faux)
var persist: bool = true  ## faux dans les tests : ne rien écrire sur le disque


func _ready() -> void:
	load_settings()
	apply_window()


func battle_speed_factor() -> float:
	return float(BATTLE_SPEEDS[clampi(battle_speed, 0, BATTLE_SPEEDS.size() - 1)]["f"])


## Volume effectif d'un bus : maître × (musique ou effets).
func music_gain() -> float:
	return master_volume * music_volume


func sfx_gain() -> float:
	return master_volume * sfx_volume


func set_value(key: String, value: Variant) -> void:
	match key:
		"master_volume":
			master_volume = clampf(float(value), 0.0, 1.0)
		"music_volume":
			music_volume = clampf(float(value), 0.0, 1.0)
		"sfx_volume":
			sfx_volume = clampf(float(value), 0.0, 1.0)
		"fullscreen":
			fullscreen = bool(value)
			apply_window()
		"battle_speed":
			battle_speed = clampi(int(value), 0, BATTLE_SPEEDS.size() - 1)
		"tutorial_seen":
			tutorial_seen = bool(value)
		_:
			return
	save_settings()
	changed.emit()


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func save_settings() -> void:
	if not persist:
		return
	var c := ConfigFile.new()
	c.set_value("audio", "master", master_volume)
	c.set_value("audio", "music", music_volume)
	c.set_value("audio", "sfx", sfx_volume)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("game", "battle_speed", battle_speed)
	c.set_value("game", "tutorial_seen", tutorial_seen)
	c.save(PATH)


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	master_volume = clampf(float(c.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(c.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(c.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(c.get_value("video", "fullscreen", fullscreen))
	battle_speed = clampi(int(c.get_value("game", "battle_speed", battle_speed)), 0, BATTLE_SPEEDS.size() - 1)
	tutorial_seen = bool(c.get_value("game", "tutorial_seen", false))
	changed.emit()
