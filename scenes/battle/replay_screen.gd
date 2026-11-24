class_name ReplayScreen
extends VBoxContainer
## Rediffusion d'une bataille, en lecture seule : rejoue les images de `BattleLog` sur un plateau (BoardView/UnitView réutilisés).
## Aucune règle ici : l'état de relecture est une copie de l'état initial à laquelle on applique `BattleLog.apply_frame`.
## Commandes : pause/lecture, vitesse ×1 / ×2 / ×4, saut à la manche suivante, retour au début.

const STAGE_MIN := Vector2(620, 300)
const STEP_DELAY := 0.4  ## secondes entre deux images à la vitesse ×1
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var log_data: BattleLog
var state: BattleState
var board: BoardView
var idx: int = 0  ## prochaine image à jouer
var speed_i: int = 0
var playing: bool = false

var _stage: Control
var _info: Label
var _text: Label
var _play_b: Button
var _gen: int = 0  ## change à chaque saut : les lectures en cours s'arrêtent
var _modal: ModalOverlay
var _alive: bool = true


## Rediffusion de la dernière bataille (`Game.extras["last_replay"]`). Renvoie la fenêtre, ou null s'il n'y a rien à revoir.
static func open(host: Node) -> ModalOverlay:
	var g: Node = host.get_tree().root.get_node_or_null("Game")  # accès dynamique : ce script doit compiler sans autoload (scripts -s)
	if g == null:
		return null
	var ex: Dictionary = g.get("extras")
	return open_log(host, BattleLog.unpack(ex.get("last_replay", null)))


## Rediffusion d'un journal déjà en mémoire (bataille en cours ou terminée).
static func open_log(host: Node, log: BattleLog) -> ModalOverlay:
	if log == null or not log.is_valid():
		return null
	var m := ModalOverlay.open(host, 660)
	var rs := ReplayScreen.new()
	m.content.add_child(rs)
	rs.setup(log, m)
	return m


func setup(log: BattleLog, modal: ModalOverlay = null) -> void:
	log_data = log
	_modal = modal
	add_theme_constant_override("separation", 8)
	add_child(UiKit.title("Revoir la bataille", 26))
	var frame := PanelContainer.new()
	frame.theme_type_variation = "Card"
	_stage = Control.new()
	_stage.clip_contents = true
	_stage.custom_minimum_size = STAGE_MIN
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.resized.connect(_fit_board)
	frame.add_child(_stage)
	add_child(frame)
	board = BoardView.new()
	_stage.add_child(board)
	_info = UiKit.sub("", 13)
	add_child(_info)
	_text = UiKit.sub("", 13)
	_text.custom_minimum_size = Vector2(STAGE_MIN.x, 54)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_text)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	_play_b = UiKit.button("Pause", "pri", true)
	_play_b.pressed.connect(toggle_play)
	row.add_child(_play_b)
	var group := ButtonGroup.new()
	for i in SPEEDS.size():
		var sb := UiKit.button("×%d" % int(SPEEDS[i]), "", true)
		sb.toggle_mode = true
		sb.button_group = group
		sb.button_pressed = i == speed_i
		sb.pressed.connect(set_speed.bind(i))
		row.add_child(sb)
	var skip := UiKit.button("Manche suivante", "", true)
	skip.pressed.connect(skip_round)
	row.add_child(skip)
	var start := UiKit.button("Début", "", true)
	start.pressed.connect(restart)
	row.add_child(start)
	var close := UiKit.button("Fermer", "ghost", true)
	close.pressed.connect(func() -> void:
		if _modal != null:
			_modal.close())
	row.add_child(close)
	add_child(row)
	if log.resumed:
		add_child(UiKit.sub("Bataille reprise depuis une sauvegarde : la rediffusion commence à la reprise.", 12))
	if log.truncated:
		add_child(UiKit.sub("Bataille très longue : la fin de la rediffusion est tronquée.", 12))
	_load_state()
	toggle_play()


func _exit_tree() -> void:
	_alive = false
	_gen += 1


func _load_state() -> void:
	state = log_data.replay_state()
	state.rec = null
	board.setup(state)
	_fit_board()
	_update_info()


func _fit_board() -> void:
	if state == null or _stage == null or board == null:
		return
	var ws: Vector2 = BoardView.world_size(state.width, state.height)
	var k: float = minf(_stage.size.x / ws.x, _stage.size.y / ws.y)
	if k <= 0.0:
		return
	board.scale = Vector2.ONE * k
	board.position = (_stage.size - ws * k) * 0.5


func _update_info() -> void:
	var n: int = log_data.frame_count()
	var rnd: int = state.round_no if state != null else 1
	_info.text = "Image %d / %d · Manche %d · ×%d" % [mini(idx, n), n, rnd, int(SPEEDS[speed_i])]
	_play_b.text = "Pause" if playing else ("Rejouer" if idx >= n else "Lecture")


func set_speed(i: int) -> void:
	speed_i = clampi(i, 0, SPEEDS.size() - 1)
	_update_info()


func toggle_play() -> void:
	if playing:
		playing = false
		_gen += 1
	else:
		if idx >= log_data.frame_count():
			restart()
			return
		playing = true
		_run(_gen)
	_update_info()


func restart() -> void:
	_gen += 1
	idx = 0
	_load_state()
	_text.text = ""
	playing = true
	_run(_gen)
	_update_info()


## Saute à la première image de la manche suivante (sans animation) puis continue si la lecture était en cours.
func skip_round() -> void:
	var target: int = log_data.next_round_index(maxi(0, idx - 1))
	if target < 0:
		return
	seek(target)


## Replace la relecture juste avant l'image `i` (sans animation).
func seek(i: int) -> void:
	var was_playing: bool = playing
	_gen += 1
	i = clampi(i, 0, log_data.frame_count())
	state = log_data.replay_state()
	state.rec = null
	for k in i:
		BattleLog.apply_frame(state, log_data.frames[k])
	idx = i
	board.setup(state)
	_fit_board()
	_text.text = ""
	playing = was_playing
	if playing:
		_run(_gen)
	_update_info()


func _run(gen: int) -> void:
	while _alive and gen == _gen and playing and idx < log_data.frame_count():
		await step_once()
	if _alive and gen == _gen:
		playing = false
		_update_info()


## Joue l'image suivante (état + animation). Utilisable directement par un test (vitesse des animations nulle : sans délai).
func step_once() -> void:
	if idx >= log_data.frame_count():
		return
	var gen: int = _gen
	var f: Dictionary = log_data.frames[idx]
	idx += 1
	var info: Dictionary = BattleLog.apply_frame(state, f)
	var fast: bool = SPEEDS[speed_i] >= 4.0 or UnitView._speed() <= 0.0
	var k: float = SPEEDS[speed_i]
	var move_time: float = 0.0
	for mv in info["moved"]:
		var mu: Unit = mv[0]
		var dist: int = Hex.distance(mv[1], mu.hex)
		var dur: float = minf(0.6, 0.12 * float(maxi(1, dist))) / k
		move_time = maxf(move_time, dur)
		if board.views.has(mu.id) and not fast:
			board.move_unit(mu, mu.hex, dur)  # lancé sans attendre : tous les déplacements de l'image se font ensemble
	board.refresh_units()
	var actor: Unit = info["actor"]
	for h in info["hurt"]:
		var hu: Unit = h[0]
		var hv: UnitView = board.view_of(hu)
		if actor != null and actor != hu and not fast:
			var av: UnitView = board.view_of(actor)
			if av != null and hv != null and Hex.distance(actor.hex, hu.hex) <= 1:
				av.lunge(board.hex_px(hu.hex))
		if hv != null and not fast:
			hv.hit_flash()
		var txt: String = "−%d" % int(h[1]) if int(h[1]) > 0 else "−%d armure" % int(h[2])
		board.float_text(hu.hex, txt, Color("ff7a68") if int(h[1]) > 0 else Color("cfd9e4"))
	for sp in info["spawned"]:
		board.float_text((sp as Unit).hex, "Renfort !", Color("dcc56a"), -28.0)
	var lines: PackedStringArray = []
	for t in info["texts"]:
		lines.append(str(t[0]))
	if not lines.is_empty():
		_text.text = "\n".join(lines)
	_update_info()
	if not _alive or gen != _gen:
		return
	if UnitView._speed() > 0.0 and is_inside_tree():
		await get_tree().create_timer(maxf(move_time, STEP_DELAY / k)).timeout
