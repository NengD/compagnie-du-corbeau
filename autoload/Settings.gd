extends Node
## Réglages du joueur (son, affichage, confort, jeu), sauvegardés dans user://settings.cfg.
## Les autres systèmes lisent les propriétés et écoutent `changed`.
## Logique pure testable : SCHEMA, sanitize(), to_config(), from_config(), resolution_list(), reset_defaults().
## Toute valeur absente ou invalide d'un ancien fichier retombe sur la valeur par défaut.

signal changed

const PATH: String = "user://settings.cfg"
## Vitesse des animations de bataille : multiplicateur de durée appliqué à BattleScreen.speed (plus petit = plus rapide).
const BATTLE_SPEEDS: Array = [
	{"n": "Rapide", "f": 0.5},
	{"n": "Normale", "f": 1.0},
	{"n": "Lente", "f": 1.6},
]
const WINDOW_MODES: Array = ["Fenêtré", "Plein écran", "Plein écran sans bordure"]
const RESOLUTIONS: Array = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const VSYNC_MODES: Array = ["Désactivé", "Activé", "Adaptatif"]
const FPS_LIMITS: Array = [30, 60, 120, 144, 0]  ## 0 = illimité
const MSAA_MODES: Array = ["Désactivé", "2×", "4×"]
const TEXT_SIZES: Array = [{"n": "Petit", "f": 0.88}, {"n": "Normal", "f": 1.0}, {"n": "Grand", "f": 1.2}]
const UI_SCALE_MIN: int = 75
const UI_SCALE_MAX: int = 150

## nom de la propriété -> [section, clé dans le fichier, défaut, min, max] (min/max ignorés pour les booléens).
const SCHEMA: Dictionary = {
	"master_volume": ["audio", "master", 1.0, 0.0, 1.0],
	"music_volume": ["audio", "music", 0.7, 0.0, 1.0],
	"sfx_volume": ["audio", "sfx", 0.9, 0.0, 1.0],
	"window_mode": ["video", "window_mode", 0, 0, 2],
	"window_w": ["video", "width", 0, 0, 16384],
	"window_h": ["video", "height", 0, 0, 16384],
	"window_x": ["video", "x", 0, -32768, 32768],
	"window_y": ["video", "y", 0, -32768, 32768],
	"window_pos_set": ["video", "has_pos", false, 0, 0],
	"monitor": ["video", "monitor", -1, -1, 15],
	"ui_scale": ["video", "ui_scale", 100, 75, 150],
	"vsync": ["video", "vsync", 1, 0, 2],
	"fps_limit": ["video", "fps", 4, 0, 4],
	"msaa": ["video", "msaa", 1, 0, 2],
	"quality": ["video", "quality", 2, 0, 4],
	"ground_mode": ["video", "ground_mode", 2, 0, 2],
	"shadows": ["video", "shadows", 2, 0, 2],
	"weather_level": ["video", "weather_level", 2, 0, 2],
	"particles": ["video", "particles", 2, 0, 3],
	"decals": ["video", "decals", 2, 0, 3],
	"map_tex": ["video", "map_tex", 1, 0, 2],
	"tex_filter": ["video", "tex_filter", 1, 0, 1],
	"show_fps": ["video", "show_fps", false, 0, 0],
	"screen_shake": ["game", "screen_shake", true, 0, 0],
	"text_size": ["game", "text_size", 1, 0, 2],
	"show_hit_pct": ["game", "show_hit_pct", false, 0, 0],
	"illustrated_ui": ["game", "illustrated_ui", true, 0, 0],
	"confirm_end_turn": ["game", "confirm_end_turn", false, 0, 0],
	"battle_speed": ["game", "battle_speed", 1, 0, 2],
	"skip_splash": ["game", "skip_splash", false, 0, 0],
	"day_night": ["game", "day_night", true, 0, 0],
	"weather_fx": ["game", "weather_fx", true, 0, 0],
	"map_anim": ["game", "map_anim", true, 0, 0],
	"tutorial_seen": ["game", "tutorial_seen", false, 0, 0],
	"edge_scroll": ["game", "edge_scroll", true, 0, 0],
	"camera_follow": ["game", "camera_follow", true, 0, 0],
	"minimap": ["game", "minimap", true, 0, 0],
	"map_territories": ["game", "map_territories", true, 0, 0],
	"map_regions": ["game", "map_regions", true, 0, 0],
	"map_borders": ["game", "map_borders", true, 0, 0],
}
## Clés de la fenêtre, appliquées ensemble (avec confirmation dans le panneau d'options).
const DISPLAY_KEYS: Array = ["window_mode", "window_w", "window_h", "window_x", "window_y", "window_pos_set", "monitor"]

var master_volume: float = 1.0  ## 0..1
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var window_mode: int = 0  ## 0 fenêtré, 1 plein écran, 2 plein écran sans bordure
var window_w: int = 0  ## taille mémorisée de la fenêtre (0 = jamais définie)
var window_h: int = 0
var window_x: int = 0
var window_y: int = 0
var window_pos_set: bool = false
var monitor: int = -1  ## -1 = l'écran actuel
var ui_scale: int = 100  ## pourcentage, 75..150
var vsync: int = 1  ## index dans VSYNC_MODES
var fps_limit: int = 4  ## index dans FPS_LIMITS
var msaa: int = 1  ## index dans MSAA_MODES (= Viewport.MSAA_*)
var quality: int = 2  ## préréglage graphique (Quality.LOW..ULTRA, CUSTOM) : toujours recalculé d'après les réglages détaillés
var ground_mode: int = 2  ## sol de la bataille : 0 aplats, 1 textures, 2 textures et fondus
var shadows: int = 2  ## ombres portées : 0 aucune, 1 simples, 2 complètes
var weather_level: int = 2  ## météo (si « weather_fx ») : 1 pluie et neige seulement, 2 complète avec brouillard
var particles: int = 2  ## densité des particules : index dans Quality.PARTICLE_FACTORS
var decals: int = 2  ## décalcomanies de sang : index dans Quality.DECAL_CAPS
var map_tex: int = 1  ## définition de la texture de la carte : 0 réduite, 1 normale, 2 haute
var tex_filter: int = 1  ## 0 filtrage linéaire simple, 1 mipmaps
var show_fps: bool = false  ## compteur d'images par seconde à l'écran
var quality_notice: String = ""  ## message à afficher une fois (réglage automatique au premier lancement)
var screen_shake: bool = true
var text_size: int = 1  ## index dans TEXT_SIZES
var show_hit_pct: bool = false  ## pourcentages de toucher affichés en permanence
var illustrated_ui: bool = true  ## interface « cuir et parchemin » (faux : style plat)
var confirm_end_turn: bool = false  ## demande avant « Fin du tour » s'il reste des PA
var battle_speed: int = 1  ## index dans BATTLE_SPEEDS
var skip_splash: bool = false
var day_night: bool = true  ## cycle jour/nuit sur la carte du monde
var weather_fx: bool = true  ## effets météo (carte du monde, bataille)
var map_anim: bool = true  ## animations de la carte (eau, bannières, torches, compagnie)
var tutorial_seen: bool = false  ## le tutoriel a été terminé ou passé (absent des anciens fichiers -> faux)
var edge_scroll: bool = true  ## la caméra de la carte défile quand la souris touche le bord de l'écran
var camera_follow: bool = true  ## la caméra suit la compagnie pendant les déplacements (sauf si on la déplace à la main)
var minimap: bool = true  ## mini-carte affichée sur la carte du monde
var map_territories: bool = true  ## teinte des territoires de faction sur la carte
var map_regions: bool = true  ## noms des régions écrits sur la carte
var map_borders: bool = true  ## frontières et bornes frontières
var persist: bool = true  ## faux dans les tests : ne rien écrire sur le disque

var _applying: bool = false
var _poll: float = 0.0
var _dirty_time: float = -1.0


func _ready() -> void:
	load_settings()
	apply_all()
	if DisplayServer.get_name() != "headless" and persist:
		var ov := QualityOverlay.new()
		ov.name = "QualityOverlay"
		add_child(ov)


func _process(delta: float) -> void:
	if not persist or DisplayServer.get_name() == "headless":
		return
	_poll += delta
	if _poll < 0.5:
		return
	_poll = 0.0
	_track_window()


# --- Valeurs ---

func battle_speed_factor() -> float:
	return float(BATTLE_SPEEDS[clampi(battle_speed, 0, BATTLE_SPEEDS.size() - 1)]["f"])


func text_factor() -> float:
	return float(TEXT_SIZES[clampi(text_size, 0, TEXT_SIZES.size() - 1)]["f"])


func fps_cap() -> int:
	return int(FPS_LIMITS[clampi(fps_limit, 0, FPS_LIMITS.size() - 1)])


## Volume effectif d'un bus : maître × (musique ou effets).
func music_gain() -> float:
	return master_volume * music_volume


func sfx_gain() -> float:
	return master_volume * sfx_volume


## Valeur ramenée dans les bornes et au bon type ; une valeur illisible donne le défaut.
static func sanitize(key: String, value: Variant) -> Variant:
	if not SCHEMA.has(key):
		return null
	var def: Array = SCHEMA[key]
	var d: Variant = def[2]
	match typeof(d):
		TYPE_BOOL:
			if typeof(value) == TYPE_BOOL:
				return value
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				return value != 0
			return d
		TYPE_INT:
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return d
			return clampi(int(value), int(def[3]), int(def[4]))
		_:
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return d
			var f: float = float(value)
			if is_nan(f):
				return d
			return clampf(f, float(def[3]), float(def[4]))


func set_value(key: String, value: Variant) -> void:
	if key == "fullscreen":  # ancien nom : plein écran sans bordure
		key = "window_mode"
		value = 2 if bool(value) else 0
	if not SCHEMA.has(key):
		return
	if key == "quality":
		var lv: int = int(sanitize(key, value))
		if lv <= Quality.ULTRA:
			apply_quality(lv)
		return
	set(key, sanitize(key, value))
	if key == "weather_level":
		weather_fx = weather_level > 0  # 0 = météo coupée
		if weather_level == 0:
			weather_level = 2  # valeur de repli quand on rallumera « Effets météo »
	elif key == "weather_fx" and weather_fx and weather_level == 0:
		weather_level = 2
	_apply_key(key)
	if key in Quality.KEYS or key in ["weather_fx", "weather_level"]:
		quality = Quality.identify(detail_values())
	save_settings()
	changed.emit()


## Valeurs détaillées courantes (clés de Quality.KEYS ; « weather » = niveau effectif).
func detail_values() -> Dictionary:
	var d: Dictionary = {}
	for k in Quality.KEYS:
		d[k] = (weather_level if weather_fx else 0) if k == "weather" else get(k)
	return d


## Applique un préréglage (Quality.LOW..ULTRA) : écrase tous les réglages détaillés.
func apply_quality(level: int, notify: bool = true) -> void:
	var lv: int = clampi(level, Quality.LOW, Quality.ULTRA)
	var p: Dictionary = Quality.preset_values(lv)
	var ui_before: bool = illustrated_ui
	for k in p:
		if k == "weather":
			weather_fx = int(p[k]) > 0
			weather_level = maxi(int(p[k]), 1) if int(p[k]) > 0 else 2
		else:
			set(k, sanitize(k, p[k]))
	quality = lv
	apply_video_quality()
	if illustrated_ui != ui_before:
		GameTheme.apply_style()
	save_settings()
	if notify:
		changed.emit()


## Texte de la liste « Qualité graphique » : niveau actuel (reconnu d'après les réglages détaillés).
func quality_name() -> String:
	return Quality.name_of(quality)


## Remet tous les réglages par défaut (sauf « tutoriel vu »), les applique et les enregistre.
func reset_defaults() -> void:
	for k in SCHEMA:
		if k != "tutorial_seen":
			set(k, SCHEMA[k][2])
	quality = Quality.identify(detail_values())
	apply_all()
	if DisplayServer.get_name() != "headless":
		GameTheme.apply_style()
	save_settings()
	changed.emit()


# --- Fichier ---

func to_config() -> ConfigFile:
	var c := ConfigFile.new()
	for k in SCHEMA:
		var def: Array = SCHEMA[k]
		c.set_value(str(def[0]), str(def[1]), get(k))
	return c


## Lit un ConfigFile (éventuellement ancien ou abîmé) ; ce qui manque ou est invalide reprend le défaut.
func from_config(c: ConfigFile) -> void:
	for k in SCHEMA:
		var def: Array = SCHEMA[k]
		set(k, sanitize(k, c.get_value(str(def[0]), str(def[1]), def[2])))
	if not c.has_section_key("video", "window_mode") and bool(c.get_value("video", "fullscreen", false)):
		window_mode = 2  # ancien fichier : « plein écran » était le mode sans bordure
	# Le préréglage affiché se déduit toujours des réglages détaillés : un ancien fichier (sans « quality »)
	# donne Élevé s'il correspond, « Personnalisé » sinon.
	quality = Quality.identify(detail_values())


func save_settings() -> void:
	if not persist:
		return
	to_config().save(PATH)


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		_first_launch()
		return
	from_config(c)
	changed.emit()


## Aucun fichier de réglages : premier lancement. Choisit un niveau selon la carte graphique.
func _first_launch() -> void:
	if not persist or DisplayServer.get_name() == "headless":
		return
	var lv: int = Quality.suggest_here()
	if lv != Quality.HIGH:
		apply_quality(lv, false)
	quality_notice = "Qualité graphique réglée sur %s (modifiable dans Options)." % Quality.name_of(lv)
	save_settings()


# --- Application ---

func apply_all() -> void:
	apply_window()
	apply_scale()
	apply_video_quality()


func _apply_key(key: String) -> void:
	if key in DISPLAY_KEYS:
		apply_window()
	elif key == "ui_scale":
		apply_scale()
	elif key in ["vsync", "fps_limit", "msaa", "tex_filter"]:
		apply_video_quality()
	elif key == "text_size":
		GameTheme.refresh_text_size()
	elif key == "illustrated_ui":
		GameTheme.apply_style()


func apply_scale() -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_window().content_scale_factor = float(ui_scale) / 100.0


func apply_video_quality() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vs: Array = [DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE]
	DisplayServer.window_set_vsync_mode(vs[clampi(vsync, 0, 2)])
	Engine.max_fps = fps_cap()
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.msaa_2d = clampi(msaa, 0, 2) as Viewport.MSAA
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if tex_filter > 0 else Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR


## Résolutions de la liste qui tiennent dans l'écran (`screen` = zone utilisable).
static func resolution_list(screen: Vector2i) -> Array:
	var out: Array = []
	for r in RESOLUTIONS:
		var v: Vector2i = r
		if v.x <= screen.x and v.y <= screen.y:
			out.append(v)
	return out


## Position qui garde la fenêtre (taille `size`) visible dans l'écran `screen_rect`.
static func clamp_position(pos: Vector2i, size: Vector2i, screen_rect: Rect2i) -> Vector2i:
	var x: int = clampi(pos.x, screen_rect.position.x, maxi(screen_rect.position.x, screen_rect.end.x - size.x))
	var y: int = clampi(pos.y, screen_rect.position.y, maxi(screen_rect.position.y, screen_rect.end.y - size.y))
	return Vector2i(x, y)


## Instantané des réglages de fenêtre (pour revenir en arrière).
func display_snapshot() -> Dictionary:
	var d: Dictionary = {}
	for k in DISPLAY_KEYS:
		d[k] = get(k)
	return d


## Applique un ensemble de réglages de fenêtre ; `center` recentre la fenêtre (changement de taille).
func apply_display(values: Dictionary, center: bool = false) -> void:
	for k in values:
		if k in DISPLAY_KEYS:
			set(k, sanitize(k, values[k]))
	if center:
		window_pos_set = false
	apply_window()
	save_settings()
	changed.emit()


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_applying = true
	var scr: int = DisplayServer.window_get_current_screen()
	if monitor >= 0 and monitor < DisplayServer.get_screen_count() and monitor != scr:
		scr = monitor
		DisplayServer.window_set_current_screen(scr)
	if window_mode == 0:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var area: Rect2i = DisplayServer.screen_get_usable_rect(scr)
		var size: Vector2i = DisplayServer.window_get_size()
		if window_w > 0 and window_h > 0:
			size = Vector2i(mini(window_w, area.size.x), mini(window_h, area.size.y))
			DisplayServer.window_set_size(size)
		var pos: Vector2i
		if window_pos_set:
			pos = clamp_position(Vector2i(window_x, window_y), size, area)
		else:
			pos = area.position + (area.size - size) / 2
		DisplayServer.window_set_position(pos)
	else:
		var m: int = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if window_mode == 1 else DisplayServer.WINDOW_MODE_FULLSCREEN
		if DisplayServer.window_get_mode() != m:
			DisplayServer.window_set_mode(m)
	_applying = false


## Mémorise taille/position quand le joueur déplace ou redimensionne la fenêtre (mode fenêtré seulement).
func _track_window() -> void:
	if _applying or window_mode != 0 or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var size: Vector2i = DisplayServer.window_get_size()
	var pos: Vector2i = DisplayServer.window_get_position()
	var scr: int = DisplayServer.window_get_current_screen()
	if size == Vector2i(window_w, window_h) and pos == Vector2i(window_x, window_y) and window_pos_set and scr == monitor:
		if _dirty_time >= 0.0:
			_dirty_time += 0.5
			if _dirty_time >= 1.0:  # stable depuis 1 s : on enregistre
				_dirty_time = -1.0
				save_settings()
		return
	window_w = size.x
	window_h = size.y
	window_x = pos.x
	window_y = pos.y
	window_pos_set = true
	monitor = scr
	_dirty_time = 0.0
