class_name FormationPanel
extends Control
## Formation de la compagnie, façon Battle Brothers : trois rangées de 9 emplacements sur le champ de bataille (avant, milieu, arrière)
## et une rangée de 9 tentes de réserve. Se dessine seul à partir de `Game.roster` / `Game.formation_slots()` et se rafraîchit sur
## `Game.changed`. Glisser-déposer d'un homme vers n'importe quel emplacement (échange si occupé) ; clic = sélection.
## La logique (plafond, échanges, sauvegarde) vit dans core/formation.gd et Game.set_formation_slot.

signal unit_selected(unit_id: int)

const COLS: int = 9
const GAP: float = 4.0
const PAD: float = 6.0
const HEADER: float = 30.0
const RESERVE_GAP: float = 10.0
const MIN_CELL: float = 28.0
const MAX_CELL: float = 110.0

var selected_id: int = -1

var _cell: float = 48.0
var _origin := Vector2.ZERO
var _slots: Dictionary = {}  ## id -> emplacement (copie normalisée)
var _views: Dictionary = {}  ## id -> PortraitView
var _auto_btn: Button
var _hover_slot: int = -1
var _drop_ok: bool = true
var _dragging: bool = false
var _notice: String = ""
var _notice_token: int = 0
var _over: Control  ## calque du dessus : icônes de rôle (au-dessus des portraits)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(COLS * 44.0 + 2.0 * PAD + 8.0 * GAP, HEADER + 4.0 * 44.0 + 3.0 * GAP + RESERVE_GAP + 2.0 * PAD)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_auto_btn = UiKit.button("Disposition automatique", "", true)
	_auto_btn.tooltip_text = "Mêlée devant, tireurs derrière (la réserve ne change pas)"
	_auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.pressed.connect(func() -> void:
		if Game.battle != null:
			_say("Impossible pendant une bataille.")
			return
		Game.auto_arrange_formation())
	add_child(_auto_btn)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_overlay)
	add_child(_over)
	resized.connect(_rebuild)


func _ready() -> void:
	if not Game.changed.is_connected(_rebuild):
		Game.changed.connect(_rebuild)
	_rebuild()


func _exit_tree() -> void:
	if Game.changed.is_connected(_rebuild):
		Game.changed.disconnect(_rebuild)


## Met un homme en évidence (liseré doré) sans émettre `unit_selected`.
func set_selected(unit_id: int) -> void:
	if selected_id != unit_id:
		selected_id = unit_id
		queue_redraw()


# --- Géométrie ---

func _compute_layout() -> void:
	var avail_w: float = size.x - 2.0 * PAD - (COLS - 1) * GAP
	var avail_h: float = size.y - HEADER - 2.0 * PAD - 3.0 * GAP - RESERVE_GAP
	_cell = clampf(floorf(minf(avail_w / COLS, avail_h / 4.0)), MIN_CELL, MAX_CELL)
	var grid_w: float = COLS * _cell + (COLS - 1) * GAP
	_origin = Vector2(floorf((size.x - grid_w) * 0.5), HEADER + PAD)


func slot_rect(slot: int) -> Rect2:
	var row: int = slot / COLS
	var col: int = slot % COLS
	var y: float = _origin.y + row * (_cell + GAP) + (RESERVE_GAP if row >= 3 else 0.0)
	return Rect2(_origin.x + col * (_cell + GAP), y, _cell, _cell)


func slot_at(pos: Vector2) -> int:
	for s in Formation.SLOTS:
		if slot_rect(s).grow(GAP * 0.5).has_point(pos):
			return s
	return -1


func _man_at(slot: int) -> Unit:
	if slot < 0:
		return null
	for id in _slots:
		if int(_slots[id]) == slot:
			return Game.member(int(id))
	return null


# --- Contenu ---

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_compute_layout()
	_slots = Game.formation_slots()
	for id in _views.keys():
		if not _slots.has(id) or Game.member(int(id)) == null:
			(_views[id] as Node).queue_free()
			_views.erase(id)
	for id in _slots:
		var u: Unit = Game.member(int(id))
		if u == null:
			continue
		var pv: PortraitView = _views.get(id)
		if pv == null:
			pv = PortraitView.new(u, int(MIN_CELL))
			pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(pv)
			_views[id] = pv
		else:
			pv.refresh_mood()
		var r: Rect2 = slot_rect(int(_slots[id]))
		pv.position = r.position + Vector2(2, 2)
		pv.size = Vector2(r.size.x - 4.0, r.size.y - 9.0)
	_over.position = Vector2.ZERO
	_over.size = size
	move_child(_over, get_child_count() - 1)
	_over.queue_redraw()
	var bw: float = minf(220.0, size.x * 0.4)
	_auto_btn.position = Vector2(PAD, 2.0)
	_auto_btn.size = Vector2(bw, HEADER - 4.0)
	queue_redraw()


func _say(text: String) -> void:
	_notice = text
	_notice_token += 1
	var token: int = _notice_token
	queue_redraw()
	get_tree().create_timer(2.8).timeout.connect(func() -> void:
		if token == _notice_token:
			_notice = ""
			queue_redraw())


# --- Dessin ---

func _draw() -> void:
	var font: Font = GameTheme.bold_font()
	var fs: int = clampi(int(_cell * 0.28), 11, 18)
	var fh: Font = font
	draw_rect(Rect2(Vector2.ZERO, size), GameTheme.BG.darkened(0.1), true)
	draw_rect(Rect2(Vector2.ZERO, size), GameTheme.LINE, false, 1.0)
	# compteur « N/M »
	var count: int = Formation.field_count(_slots)
	var label: String = "%d/%d" % [count, Data.FIGHTERS]
	var cw: float = fh.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2).x
	var col: Color = GameTheme.GOLD if count < Data.FIGHTERS else GameTheme.INK
	draw_string(fh, Vector2(size.x - PAD - cw, HEADER * 0.5 + (fs + 2) * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, col)
	var sub: String = "au combat"
	var sw: float = fh.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(fh, Vector2(size.x - PAD - cw - sw - 6.0, HEADER * 0.5 + 4.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GameTheme.MUTE)
	if _notice != "":
		var nx: float = _auto_btn.position.x + _auto_btn.size.x + 10.0
		draw_string(fh, Vector2(nx, HEADER * 0.5 + 4.0), _notice, HORIZONTAL_ALIGNMENT_LEFT, size.x - nx - cw - sw - 24.0, 12, GameTheme.BLOOD.lightened(0.25))
	for s in Formation.SLOTS:
		_draw_slot(s)


func _draw_slot(s: int) -> void:
	var r: Rect2 = slot_rect(s)
	var man: Unit = _man_at(s)
	var field: bool = Formation.is_field(s)
	draw_rect(r, GameTheme.PANEL.darkened(0.15 if field else 0.35), true)
	var border: Color = GameTheme.LINE
	var width: float = 1.0
	if man != null and man.id == selected_id:
		border = GameTheme.GOLD
		width = 2.0
	if _dragging and s == _hover_slot:
		border = GameTheme.GOOD if _drop_ok else GameTheme.BLOOD
		width = 2.0
	if man == null:
		if Formation.is_reserve(s):
			_draw_tent(r)
		else:
			_draw_ghost(r)
	else:

		_draw_hp(r, man)
	draw_rect(r, border, false, width)


func _draw_ghost(r: Rect2) -> void:
	var c: Color = GameTheme.LINE.darkened(0.2)
	var cx: float = r.position.x + r.size.x * 0.5
	var head_r: float = r.size.x * 0.15
	draw_circle(Vector2(cx, r.position.y + r.size.y * 0.36), head_r, c)
	var pts := PackedVector2Array([
		Vector2(cx - r.size.x * 0.30, r.end.y - 3.0), Vector2(cx - r.size.x * 0.24, r.position.y + r.size.y * 0.62),
		Vector2(cx + r.size.x * 0.24, r.position.y + r.size.y * 0.62), Vector2(cx + r.size.x * 0.30, r.end.y - 3.0)])
	draw_colored_polygon(pts, c)


func _draw_tent(r: Rect2) -> void:
	var c: Color = GameTheme.LINE.darkened(0.15)
	var cx: float = r.position.x + r.size.x * 0.5
	var pts := PackedVector2Array([
		Vector2(cx, r.position.y + r.size.y * 0.2), Vector2(r.end.x - r.size.x * 0.1, r.end.y - r.size.y * 0.15),
		Vector2(r.position.x + r.size.x * 0.1, r.end.y - r.size.y * 0.15)])
	draw_colored_polygon(pts, c)
	var door := PackedVector2Array([
		Vector2(cx, r.position.y + r.size.y * 0.5), Vector2(cx + r.size.x * 0.1, r.end.y - r.size.y * 0.15),
		Vector2(cx - r.size.x * 0.1, r.end.y - r.size.y * 0.15)])
	draw_colored_polygon(door, GameTheme.BG)


## Petite icône de rôle (épée : mêlée ; arc : tireur) dans un disque sombre, en haut à droite de la case.
func _draw_role(ci: CanvasItem, r: Rect2, u: Unit) -> void:
	var rad: float = clampf(r.size.x * 0.12, 6.0, 12.0)
	var c := Vector2(r.end.x - rad - 3.0, r.position.y + rad + 3.0)
	ci.draw_circle(c, rad, Color(0.07, 0.05, 0.04, 0.85))
	var ink: Color = GameTheme.INK
	var k: float = rad * 0.62
	if u.is_ranged():
		ci.draw_arc(c + Vector2(-k * 0.35, 0), k * 1.05, -PI / 2.2, PI / 2.2, 10, ink, 1.6)
		ci.draw_line(c + Vector2(-k * 0.35 + k * 1.05 * cos(PI / 2.2), -k * 1.05 * sin(PI / 2.2)), c + Vector2(-k * 0.35 + k * 1.05 * cos(PI / 2.2), k * 1.05 * sin(PI / 2.2)), ink, 1.0)
		ci.draw_line(c + Vector2(-k * 0.5, 0), c + Vector2(k * 0.9, 0), ink, 1.2)
	else:
		ci.draw_line(c + Vector2(-k, k), c + Vector2(k, -k), ink, 1.8)
		ci.draw_line(c + Vector2(-k * 0.55, k * 0.1), c + Vector2(-k * 0.05, k * 0.65), ink, 1.4)


func _draw_hp(r: Rect2, u: Unit) -> void:
	var ratio: float = clampf(float(u.hp) / float(maxi(1, u.hp_max)), 0.0, 1.0)
	var bar := Rect2(r.position.x + 2.0, r.end.y - 6.0, r.size.x - 4.0, 4.0)
	draw_rect(bar, Color(0.05, 0.04, 0.03, 0.9), true)
	var fill: Color = GameTheme.BLOOD if ratio > 0.34 else GameTheme.BLOOD.darkened(0.25)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill, true)


# --- Interactions ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed:
		var man: Unit = _man_at(slot_at((event as InputEventMouseButton).position))
		if man != null:
			selected_id = man.id
			queue_redraw()
			unit_selected.emit(man.id)


func _get_tooltip(at_position: Vector2) -> String:
	var s: int = slot_at(at_position)
	var man: Unit = _man_at(s)
	if man == null:
		return Formation.slot_label(s) if s >= 0 else ""
	var wname: String = str(Data.WPN[man.weapon]["n"]) if Data.WPN.has(man.weapon) else man.weapon
	return "%s\nNiveau %d · %s\nPV %d/%d\n%s" % [man.unit_name, man.level, wname, man.hp, man.hp_max, Formation.slot_label(s)]


func _get_drag_data(at_position: Vector2) -> Variant:
	var s: int = slot_at(at_position)
	var man: Unit = _man_at(s)
	if man == null:
		return null
	selected_id = man.id
	unit_selected.emit(man.id)
	var preview := PortraitView.new(man, int(_cell))
	preview.size = Vector2(_cell, _cell)
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	_dragging = true
	queue_redraw()
	return {"formation_unit": man.id, "from": s}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("formation_unit"):
		return false
	var s: int = slot_at(at_position)
	_hover_slot = s
	if s < 0:
		_drop_ok = false
	elif Game.battle != null:
		_drop_ok = false
	else:
		_drop_ok = bool(Formation.move(_slots, int((data as Dictionary)["formation_unit"]), s)["ok"])
	queue_redraw()
	return _drop_ok


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var s: int = slot_at(at_position)
	var uid: int = int((data as Dictionary)["formation_unit"])
	_end_drag()
	if Game.battle != null:
		_say("Impossible pendant une bataille.")
		return
	var res: Dictionary = Formation.move(_slots, uid, s)
	if not bool(res["ok"]):
		_say(str(res["reason"]))
		return
	Game.set_formation_slot(uid, s)


func _end_drag() -> void:
	_dragging = false
	_hover_slot = -1
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_end_drag()
	elif what == NOTIFICATION_MOUSE_EXIT and _dragging:
		_hover_slot = -1
		queue_redraw()


func _draw_overlay() -> void:
	for id in _slots:
		var u: Unit = Game.member(int(id))
		if u != null:
			_draw_role(_over, slot_rect(int(_slots[id])), u)
