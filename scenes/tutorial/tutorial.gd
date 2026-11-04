class_name Tutorial
extends CanvasLayer
## Tutoriel guidé non bloquant : une carte en bas à gauche, par écran (voir `TutorialData`), avec « Suivant » et « Passer ».
## `Tutorial.hint("town"|"map"|"battle"|"end")` est appelé par les écrans ; sans effet tant que le tutoriel n'est pas actif.
## `Tutorial.start()` (nouvelle partie, bouton « Revoir le tutoriel ») l'active ; « vu » est mémorisé dans `Settings.tutorial_seen`.

static var current: Tutorial

var active: bool = false
var seen: Array = []  ## identifiants d'étapes déjà affichées
var shown: Dictionary = {}  ## étape actuellement affichée (vide = aucune)
var last_ctx: String = ""
var settings: Node  ## injectable (tests) ; sinon l'autoload Settings

var _card: PanelContainer
var _title: Label
var _text: Label
var _next_btn: Button


func _init() -> void:
	layer = 60


func _ready() -> void:
	current = self
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = GameTheme.get_theme()
	add_child(root)
	_card = PanelContainer.new()
	_card.theme_type_variation = "ModalPanel"
	_card.custom_minimum_size = Vector2(380, 0)
	_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = 24
	_card.offset_bottom = -24
	_card.visible = false
	root.add_child(_card)
	var box := UiKit.vbox(8)
	_card.add_child(box)
	box.add_child(UiKit.label("TUTORIEL", 12, GameTheme.MUTE))
	_title = UiKit.title("", 22, GameTheme.GOLD)
	box.add_child(_title)
	_text = UiKit.para("", 15)
	box.add_child(_text)
	var row := UiKit.hbox(8)
	_next_btn = UiKit.button("Suivant", "pri", true)
	_next_btn.pressed.connect(dismiss)
	row.add_child(_next_btn)
	var skip_btn := UiKit.button("Passer le tutoriel", "ghost", true)
	skip_btn.pressed.connect(skip)
	row.add_child(skip_btn)
	box.add_child(row)
	_show_current()


func _exit_tree() -> void:
	if current == self:
		current = null


# --- API statique (sans effet si le tutoriel n'existe pas : tests, scripts) ---

static func hint(ctx: String) -> void:
	if current != null:
		current.notify(ctx)


## Active (ou relance) le tutoriel depuis le début.
static func start() -> void:
	if current != null:
		current.begin()


## Cache la carte sans toucher à la progression (retour au menu principal).
static func hide_card() -> void:
	if current != null:
		current.leave()


# --- Logique ---

func begin() -> void:
	active = true
	seen.clear()
	shown = {}
	_set_seen(false)
	if last_ctx != "":
		_advance(last_ctx)
	_show_current()


## L'écran `ctx` vient d'apparaître. Les étapes de l'écran quitté comptent comme vues si l'une d'elles a été affichée.
func notify(ctx: String) -> void:
	var changed: bool = ctx != last_ctx
	if changed and not shown.is_empty():
		for id in TutorialData.ids_for(str(shown["ctx"])):
			if not seen.has(id):
				seen.append(id)
		shown = {}
	last_ctx = ctx
	if not active:
		return
	if changed or shown.is_empty():
		_advance(ctx)
	_show_current()


func leave() -> void:
	last_ctx = ""
	shown = {}
	_show_current()


## « Suivant » : la carte affichée est lue ; on passe à la suivante du même écran, sinon la carte disparaît.
func dismiss() -> void:
	if not shown.is_empty() and not seen.has(shown["id"]):
		seen.append(shown["id"])
	shown = {}
	if TutorialData.all_seen(seen):
		finish()
		return
	_advance(last_ctx)
	_show_current()


func skip() -> void:
	finish()


func finish() -> void:
	active = false
	shown = {}
	_set_seen(true)
	_show_current()


## Mémorise « vu » dans l'autoload Settings (accès dynamique : pas d'identifiant d'autoload dans un script `-s`).
func _set_seen(v: bool) -> void:
	var s: Node = settings
	if s == null:
		var tree := Engine.get_main_loop() as SceneTree
		s = tree.root.get_node_or_null("Settings") if tree != null else null
	if s != null:
		s.call("set_value", "tutorial_seen", v)


func _advance(ctx: String) -> void:
	shown = TutorialData.next_step(ctx, seen)


func _show_current() -> void:
	if _card == null:
		return
	_card.visible = active and not shown.is_empty()
	if not _card.visible:
		return
	_title.text = str(shown["title"])
	_text.text = str(shown["text"])
	var last_of_ctx: bool = TutorialData.next_step(last_ctx, seen + [shown["id"]]).is_empty()
	_next_btn.text = "Terminer" if TutorialData.all_seen(seen + [shown["id"]]) else ("Compris" if last_of_ctx else "Suivant")
