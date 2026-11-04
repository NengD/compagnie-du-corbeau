class_name BootScreen
extends ColorRect
## Écran de lancement : logo + barre de progression pendant le préchargement des ressources lourdes
## (sons, sprites), ≈ 1 à 2 s, puis fondu vers le menu. Sauté en headless, sans animations (tests)
## ou avec le réglage « Passer l'écran de lancement ».

signal finished

const MIN_TIME: float = 1.0
const MAX_TIME: float = 2.5
const DIRS: Array = ["res://assets/audio", "res://assets/sprites"]
const EXTS: Array = ["ogg", "wav", "mp3", "svg", "png"]

var _paths: Array[String] = []
var _bar: ProgressBar
var _time: float = 0.0
var _done: bool = false


static func should_show() -> bool:
	return DisplayServer.get_name() != "headless" and BattleScreen.speed > 0.0 and not (Engine.get_main_loop() as SceneTree).root.get_node("/root/Settings").skip_splash


## Liste des ressources à précharger (fichiers importés des dossiers `DIRS`).
static func resource_paths() -> Array[String]:
	var out: Array[String] = []
	for d in DIRS:
		_collect(str(d), out)
	return out


static func _collect(dir: String, out: Array[String]) -> void:
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		var name: String = f.trim_suffix(".import")
		if f.ends_with(".import") and EXTS.has(name.get_extension()):
			out.append(dir.path_join(name))
	for sub in da.get_directories():
		_collect(dir.path_join(sub), out)


func _ready() -> void:
	color = GameTheme.BG
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := UiKit.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/app_icon.svg") as Texture2D
	icon.custom_minimum_size = Vector2(160, 160)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(icon)
	var title := UiKit.title("Compagnie du Corbeau", 56, GameTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(320, 8)
	_bar.max_value = 1.0
	col.add_child(_bar)
	_paths = resource_paths()
	for p in _paths:
		ResourceLoader.load_threaded_request(p)


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var loaded: int = 0
	for p in _paths:
		if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loaded += 1
	var ratio: float = 1.0 if _paths.is_empty() else float(loaded) / _paths.size()
	_bar.value = lerpf(_bar.value, minf(ratio, _time / MIN_TIME), 0.25)
	if (ratio >= 1.0 and _time >= MIN_TIME) or _time >= MAX_TIME:
		_done = true
		_bar.value = 1.0
		var tw: Tween = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void:
			finished.emit()
			queue_free())
