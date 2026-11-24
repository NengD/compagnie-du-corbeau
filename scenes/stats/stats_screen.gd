class_name StatsScreen
extends RefCounted
## Courbes de campagne : or, renom et effectif jour après jour, histogramme victoires / défaites par type de combat et
## résumé. Lecture seule : les données viennent de `Game.extras["stats_history"]` (core/stats_history.gd) et de `Game.stats`.
## Les dessins sont faits en `_draw` avec les couleurs du thème ; les graphiques s'étirent à la largeur de la fenêtre.


## Courbe : `pts` = [[x, y], ...] ; `step` : escalier (effectif) plutôt que ligne.
class LineChart extends Control:
	var title: String = ""
	var color: Color = GameTheme.GOLD
	var pts: Array = []
	var step: bool = false

	func _init(p_title: String, p_color: Color, p_pts: Array, p_step: bool = false) -> void:
		title = p_title
		color = p_color
		pts = p_pts
		step = p_step
		custom_minimum_size = Vector2(0, 110)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		var fs: int = 12
		draw_rect(Rect2(Vector2.ZERO, size), GameTheme.PANEL)
		draw_rect(Rect2(Vector2.ZERO, size), GameTheme.LINE, false, 1.0)
		draw_string(font, Vector2(8, 15), I18n.t(title), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 1, GameTheme.MUTE)
		if pts.size() < 2:
			draw_string(font, Vector2(8, size.y * 0.6), I18n.t("Pas encore assez de jours écoulés."), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GameTheme.MUTE)
			return
		var plot := Rect2(Vector2(10, 24), Vector2(maxf(10.0, size.x - 74.0), maxf(10.0, size.y - 42.0)))
		var x0: float = float(pts[0][0])
		var x1: float = float(pts[pts.size() - 1][0])
		var ymax: float = 1.0
		for p in pts:
			ymax = maxf(ymax, float(p[1]))
		ymax *= 1.1
		for g in 3:  # lignes de repère
			var gy: float = plot.position.y + plot.size.y * float(g) / 2.0
			draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), Color(GameTheme.LINE, 0.55), 1.0)
		var line: PackedVector2Array = PackedVector2Array()
		var prev_y: float = 0.0
		for i in pts.size():
			var px: float = plot.position.x + plot.size.x * ((float(pts[i][0]) - x0) / maxf(1.0, x1 - x0))
			var py: float = plot.end.y - plot.size.y * (float(pts[i][1]) / ymax)
			if step and i > 0:
				line.append(Vector2(px, prev_y))
			line.append(Vector2(px, py))
			prev_y = py
		draw_polyline(line, color, 2.0, true)
		var last: Vector2 = line[line.size() - 1]
		draw_circle(last, 3.5, color)
		draw_string(font, Vector2(plot.end.x + 8, clampf(last.y + 4.0, 30.0, size.y - 18.0)), str(int(pts[pts.size() - 1][1])), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 1, color)
		draw_string(font, Vector2(8, 15), "max %d" % int(ymax / 1.1), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16.0, fs - 1, GameTheme.MUTE)
		draw_string(font, Vector2(plot.position.x, size.y - 5), I18n.t("Jour %d") % int(x0), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, GameTheme.MUTE)
		draw_string(font, Vector2(plot.position.x, size.y - 5), I18n.t("Jour %d") % int(x1), HORIZONTAL_ALIGNMENT_RIGHT, plot.size.x, fs - 1, GameTheme.MUTE)


## Histogramme : une ligne par type de combat, barre verte (victoires) puis barre rouge (défaites).
class BarChart extends Control:
	var rows: Array = []  ## [[clé, libellé, victoires, défaites], ...]

	func _init(p_rows: Array) -> void:
		rows = p_rows
		custom_minimum_size = Vector2(0, 30.0 + 24.0 * maxf(1.0, float(rows.size())))
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), GameTheme.PANEL)
		draw_rect(Rect2(Vector2.ZERO, size), GameTheme.LINE, false, 1.0)
		draw_string(font, Vector2(8, 15), I18n.t("Victoires et défaites par type de combat"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GameTheme.MUTE)
		if rows.is_empty():
			draw_string(font, Vector2(8, 44), I18n.t("Aucun combat pour l'instant."), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameTheme.MUTE)
			return
		var biggest: int = 1
		for r in rows:
			biggest = maxi(biggest, int(r[2]) + int(r[3]))
		var label_w: float = 112.0
		var avail: float = maxf(20.0, size.x - label_w - 56.0)
		for i in rows.size():
			var y: float = 26.0 + 24.0 * float(i)
			draw_string(font, Vector2(8, y + 14), I18n.t(str(rows[i][1])), HORIZONTAL_ALIGNMENT_LEFT, label_w - 8.0, 12, GameTheme.INK)
			var wins: int = int(rows[i][2])
			var losses: int = int(rows[i][3])
			var ww: float = avail * float(wins) / float(biggest)
			var lw: float = avail * float(losses) / float(biggest)
			draw_rect(Rect2(label_w, y + 2, ww, 16), GameTheme.GOOD)
			draw_rect(Rect2(label_w + ww, y + 2, lw, 16), GameTheme.BLOOD)
			draw_string(font, Vector2(label_w + ww + lw + 6, y + 14), "%d / %d" % [wins, losses], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameTheme.MUTE)


static func open(host: Node) -> ModalOverlay:
	var modal: ModalOverlay = ModalOverlay.open(host, 700)
	var box: VBoxContainer = modal.content
	box.add_child(UiKit.title("Courbes de campagne", 30))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := UiKit.vbox(8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	box.add_child(scroll)
	build(inner)
	var close := UiKit.button("Fermer", "pri")
	close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func() -> void: modal.close())
	box.add_child(close)
	return modal


## Remplit `inner` : résumé, trois courbes, histogramme. Testable sans fenêtre.
static func build(inner: VBoxContainer) -> void:
	for line in StatsHistory.summary(Game.extras, Game.stats, Game.day, Game.gold, Game.renown, Game.roster.size()):
		inner.add_child(UiKit.sub(str(line), 14))
	var leg: Dictionary = Legacy.state(Game.extras)
	if not (leg["retired"] as Array).is_empty():
		inner.add_child(UiKit.sub("%d retraité%s au mémorial%s." % [(leg["retired"] as Array).size(), "s" if (leg["retired"] as Array).size() > 1 else "", ", instructeur : %s" % str(leg["instructor"]["name"]) if not (leg["instructor"] as Dictionary).is_empty() else ""], 13))
	inner.add_child(LineChart.new("Couronnes", GameTheme.GOLD, StatsHistory.series(Game.extras, "gold")))
	inner.add_child(LineChart.new("Renom", GameTheme.STEEL, StatsHistory.series(Game.extras, "renown")))
	inner.add_child(LineChart.new("Hommes dans la compagnie", GameTheme.GOOD, StatsHistory.series(Game.extras, "men"), true))
	inner.add_child(BarChart.new(StatsHistory.by_type(Game.extras)))
