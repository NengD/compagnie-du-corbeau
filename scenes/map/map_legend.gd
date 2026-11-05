class_name MapLegend
extends PanelContainer
## Légende de la carte du monde : sections repliables (lieux, compagnie et bandes, terrain, factions) et cases à cocher
## (territoires, noms de régions, frontières, mini-carte). Les pictogrammes sont dessinés par les MÊMES fonctions que la carte
## (MapPlaces, MapTerrain, CompanyMarker) à une échelle commune réduite (`ICON_K`) : ils ressemblent donc exactement aux icônes de la carte.

signal option_changed(key: String, on: bool)

const MIN_WIDTH := 380.0
const ICON_K := 0.58  ## échelle commune des pictogrammes de lieux et de bandes
const CELL := Vector2(78, 48)

var scroll: ScrollContainer
var _sections: Dictionary = {}  ## titre -> {"body": VBoxContainer, "head": Button}
var _faction_box: VBoxContainer
var _checks: Dictionary = {}  ## clé de réglage -> CheckBox


## Pictogramme : `kind` nomme ce qu'il dessine (voir `_draw`). `data` : informations complémentaires (faction, bandes…).
class Icon extends Control:
	var kind: String = ""
	var data: Dictionary = {}

	func _init(k: String = "", d: Dictionary = {}) -> void:
		kind = k
		data = d
		custom_minimum_size = MapLegend.CELL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		MapLegend.paint_icon(self, kind, data, MapLegend.CELL)


func _init() -> void:
	theme_type_variation = "Card"
	custom_minimum_size = Vector2(MIN_WIDTH, 0)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(MIN_WIDTH - 24.0, 360)
	add_child(scroll)
	var root := UiKit.vbox(6)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)
	root.add_child(UiKit.label("Légende de la carte", 17, GameTheme.GOLD, true))
	_places_section(root)
	_company_section(root)
	_terrain_section(root)
	_factions_section(root)
	_options_section(root)


## Hauteur maximale de la zone défilante (la vue en dispose).
func set_max_height(h: float) -> void:
	if scroll != null:
		scroll.custom_minimum_size.y = clampf(h, 160.0, 640.0)


func _section(root: VBoxContainer, title: String, open: bool) -> VBoxContainer:
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_theme_font_size_override("font_size", GameTheme.scaled_size(15))
	head.add_theme_color_override("font_color", GameTheme.GOLD)
	head.add_theme_color_override("font_hover_color", GameTheme.INK)
	var body := UiKit.vbox(2)
	body.visible = open
	head.text = ("▾ " if open else "▸ ") + title.to_upper()
	head.pressed.connect(func() -> void:
		body.visible = not body.visible
		head.text = ("▾ " if body.visible else "▸ ") + title.to_upper())
	root.add_child(head)
	root.add_child(body)
	_sections[title] = {"body": body, "head": head}
	return body


func _row(body: VBoxContainer, icon: Control, text: String, tip: String = "") -> void:
	var row := UiKit.hbox(10)
	row.add_child(icon)
	var l := UiKit.label(text, 14)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	if tip != "":
		row.tooltip_text = tip
		row.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(row)


func _places_section(root: VBoxContainer) -> void:
	var b: VBoxContainer = _section(root, "Lieux", true)
	_row(b, Icon.new("capital", {"faction": "roncevaux"}), "Capitale de faction (plus grande, remparts et étendards)")
	_row(b, Icon.new("city", {"faction": "marches"}), "Ville (bannière de son propriétaire)")
	_row(b, Icon.new("village", {"faction": "marches"}), "Village")
	_row(b, Icon.new("free", {}), "Ville libre (sans seigneur, bannière grise)")
	_row(b, Icon.new("site_fort", {}), "Fort de brigands")
	_row(b, Icon.new("site_lair", {}), "Repaire d'orcs")
	_row(b, Icon.new("site_necropolis", {}), "Nécropole")
	_row(b, Icon.new("site_citadel", {}), "Citadelle (le dernier défi)")
	_row(b, Icon.new("contract", {}), "Lieu du contrat en cours")
	_row(b, Icon.new("visited", {}), "Lieu déjà visité")
	_row(b, Icon.new("poi_ruins", {}), "Ruines (point d'intérêt : on s'y arrête une fois)")
	_row(b, Icon.new("poi_shrine", {}), "Sanctuaire")
	_row(b, Icon.new("poi_camp", {}), "Camp abandonné")
	_row(b, Icon.new("poi_tower", {}), "Tour de guet")
	_row(b, Icon.new("poi_cave", {}), "Grotte")


func _company_section(root: VBoxContainer) -> void:
	var b: VBoxContainer = _section(root, "Compagnie et bandes", false)
	_row(b, Icon.new("company", {}), "Votre compagnie (votre bannière)")
	_row(b, Icon.new("party_b", {}), "Brigands : rôdent et poursuivent")
	_row(b, Icon.new("party_g", {}), "Goules : rôdent près des ruines")
	_row(b, Icon.new("party_o", {}), "Orcs : hordes qui poursuivent")
	_row(b, Icon.new("party_u", {}), "Morts-vivants")
	_row(b, Icon.new("party_m", {}), "Monstres : loups, ogres, trolls")


func _terrain_section(root: VBoxContainer) -> void:
	var b: VBoxContainer = _section(root, "Terrain", false)
	for e in [["t_plain", "Plaine (coût normal)"], ["t_forest", "Forêt (lente)"], ["t_hills", "Collines"], ["t_mountain", "Montagnes (infranchissables)"],
			["t_swamp", "Marais (très lent)"], ["t_snow", "Neige et toundra (froid du nord)"], ["t_water", "Eau (lacs, mer : infranchissable)"],
			["t_ford", "Gué (traversée lente)"], ["t_bridge", "Pont"], ["t_road", "Route (déplacement plus rapide)"]]:
		_row(b, Icon.new(str(e[0]), {}), str(e[1]))


func _factions_section(root: VBoxContainer) -> void:
	var b: VBoxContainer = _section(root, "Factions", false)
	_faction_box = UiKit.vbox(3)
	b.add_child(_faction_box)
	refresh_factions()


## Liste des factions : couleur, nom, nombre de lieux contrôlés et réputation de la compagnie auprès d'elles.
func refresh_factions() -> void:
	if _faction_box == null:
		return
	for c in _faction_box.get_children():
		_faction_box.remove_child(c)
		c.queue_free()
	var counts: Dictionary = Territory.place_counts(Game.world) if Game.world != null else {}
	for k in Data.FACTIONS:
		var key: String = str(k)
		var n: int = int(counts.get(key, 0))
		if n == 0 and Game.world != null and Game.world.grand:
			continue
		var st: int = Game.standing_with(key)
		var row := UiKit.hbox(8)
		var dot := Icon.new("faction", {"faction": key})
		dot.custom_minimum_size = Vector2(26, 24)
		row.add_child(dot)
		var v := UiKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label("%s %s" % [Data.FACTIONS[key]["ic"], Factions.name_of(key)], 14, Factions.color_of(key), true))
		v.add_child(UiKit.sub("%d lieu%s · %s (%+d)" % [n, "x" if n > 1 else "", Factions.label(st), st], 12))
		row.add_child(v)
		var rivals: Array = Factions.rivals_of(key).map(func(r: Variant) -> String: return Factions.name_of(str(r)))
		var allies: Array = Factions.allies_of(key).map(func(r: Variant) -> String: return Factions.name_of(str(r)))
		row.tooltip_text = "%s\nRivales : %s\nAlliées : %s\n%s" % [str(Data.FACTIONS[key]["desc"]), ", ".join(rivals) if not rivals.is_empty() else "aucune", ", ".join(allies) if not allies.is_empty() else "aucune", Factions.effects_text(st)]
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		_faction_box.add_child(row)


func _options_section(root: VBoxContainer) -> void:
	root.add_child(UiKit.label("Affichage", 14, GameTheme.GOLD, true))
	for e in [["map_territories", "Territoires"], ["map_regions", "Noms de régions"], ["map_borders", "Frontières"], ["minimap", "Mini-carte"]]:
		var key: String = str(e[0])
		var cb := CheckBox.new()
		cb.text = str(e[1])
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", GameTheme.scaled_size(14))
		cb.button_pressed = bool(Settings.get(key))
		cb.toggled.connect(func(on: bool) -> void:
			option_changed.emit(key, on))
		root.add_child(cb)
		_checks[key] = cb


## Aligne une case à cocher sur le réglage (changé ailleurs : mini-carte repliée, options…).
func sync_option(key: String, on: bool) -> void:
	if _checks.has(key):
		(_checks[key] as CheckBox).set_pressed_no_signal(on)


# --- Dessin des pictogrammes (mêmes fonctions que la carte) ---

static func _site_dict(kind: String) -> Dictionary:
	return {"kind": kind, "name": "", "state": "hostile", "x": 100.0, "y": 100.0}


static func _banner_for(key: String) -> Dictionary:
	var bn: Dictionary = MapPlaces.faction_banner(key)
	if bn.is_empty():
		bn = {"primary": "a33a2c", "secondary": "d8cfb8", "emblem": 0}
	return bn


## Dessine l'icône `kind` dans une cellule de taille `cell` (utilisé par `Icon` ; testable avec n'importe quel CanvasItem).
static func paint_icon(l: CanvasItem, kind: String, data: Dictionary, cell: Vector2) -> void:
	var c: Vector2 = cell * 0.5
	var lights: Array = []
	var font: Font = GameTheme.title_font()
	if kind.begins_with("t_"):
		_paint_terrain(l, kind, cell)
		return
	match kind:
		"capital", "city", "village", "free":
			var key: String = str(data.get("faction", "libres"))
			var s: Dictionary = {"kind": "village" if kind == "village" else "city", "capital": kind == "capital", "x": 100.0, "y": 100.0}
			if kind == "free":
				key = "libres"
			var k: float = ICON_K * (0.92 if kind == "village" else 1.0)
			var kk: float = k * MapPlaces.settlement_k(s)
			var foot: Vector2 = c + Vector2(0, 4)
			MapPlaces.paint_settlement(l, s, foot, lights, k)
			var city: bool = kind != "village"
			var bn: Dictionary = _banner_for(key)
			MapPlaces.paint_banner(l, foot + (Vector2(0, -37) if city else Vector2(-15, -7)) * kk, bn, 0.0, false, (1.0 if city else 0.75) * kk)
			if kind == "capital":
				for sx in [-1.0, 1.0]:
					MapPlaces.paint_banner(l, foot + Vector2(29.0 * sx, -26.0) * kk, bn, 0.0, false, 0.5 * kk)
		"site_fort", "site_lair", "site_necropolis", "site_citadel":
			var sk: String = kind.trim_prefix("site_")
			var col: Color = MapView.PARTY_COLORS.get(str(Campaign.SITE_TYPES[sk]["faction"]), Color("a33a2c"))
			var foot2: Vector2 = c + Vector2(0, 4)
			MapPlaces.begin_scaled(l, foot2, ICON_K * (0.8 if sk == "citadel" else 1.0))
			MapPlaces.paint_site(l, _site_dict(sk), Vector2.ZERO, col, font, 0.0, false, false)
			MapPlaces.end_scaled(l)
		"contract":
			MapPlaces.paint_contract_flag(l, c + Vector2(-4, 12), 0.5)
		"visited":
			MapPlaces.paint_visited_mark(l, c, 1.5)
		"company":
			var bn2: Dictionary = Game.banner.duplicate()
			bn2["primary"] = Banner.primary(Game.banner).to_html(false)
			CompanyMarker.paint(l, c + Vector2(0, 18), bn2, "", font, 0.0, false, 0.0, 0.0, 1.0, 0.7, false)
		"party_b", "party_g", "party_o", "party_u", "party_m":
			var col2: Color = MapView.PARTY_COLORS.get(kind.trim_prefix("party_"), Color("7a5e9a"))
			MapPlaces.begin_scaled(l, c + Vector2(0, 6), 1.25)
			MapPlaces.paint_party(l, Vector2.ZERO, col2, "", font, 0.0, false, 1.0, 0)
			MapPlaces.end_scaled(l)
		"faction":
			var fc: Color = Factions.color_of(str(data.get("faction", "")))
			var bn3: Dictionary = _banner_for(str(data.get("faction", "")))
			MapPlaces.paint_banner(l, Vector2(cell.x * 0.5 - 7.0, cell.y - 3.0), bn3, 0.0, false, 0.9)
			l.draw_rect(Rect2(Vector2(cell.x - 5.0, 4.0), Vector2(4.0, cell.y - 8.0)), fc)
		_:
			if kind.begins_with("poi_"):
				MapPlaces.paint_poi(l, kind.trim_prefix("poi_"), c + Vector2(0, 6), 1.6, false)


static func _paint_terrain(l: CanvasItem, kind: String, cell: Vector2) -> void:
	var c: Vector2 = cell * 0.5
	var bg: Color = MapTerrain.LAND[World.T.PLAIN]
	match kind:
		"t_forest":
			bg = MapTerrain.LAND[World.T.FOREST]
		"t_hills":
			bg = MapTerrain.LAND[World.T.HILLS]
		"t_mountain":
			bg = MapTerrain.LAND[World.T.MOUNTAIN]
		"t_swamp":
			bg = MapTerrain.LAND[World.T.SWAMP]
		"t_snow":
			bg = MapTerrain.LAND[World.T.SNOW]
		"t_water", "t_ford", "t_bridge":
			bg = Color(0.30, 0.46, 0.55)
	var r := Rect2(Vector2(2, 3), cell - Vector2(4, 6))
	l.draw_rect(r, bg)
	if kind == "t_water" or kind == "t_ford" or kind == "t_bridge":
		for i in 4:
			var y: float = r.position.y + 8.0 + i * 9.0
			l.draw_polyline(PackedVector2Array([Vector2(r.position.x + 6, y), Vector2(r.position.x + 18, y - 2.0), Vector2(r.position.x + 30, y), Vector2(r.position.x + 42, y - 2.0)]), Color(0.85, 0.93, 0.95, 0.5), 1.2, true)
	match kind:
		"t_plain":
			for i in 7:
				var p := Vector2(10.0 + i * 9.0, 14.0 + float((i * 7) % 5) * 5.0)
				l.draw_multiline(PackedVector2Array([p, p + Vector2(-2, -3.5), p, p + Vector2(0.5, -4.5), p, p + Vector2(2.4, -3.2)]), Color(0.34, 0.45, 0.2, 0.9), 1.2)
		"t_forest":
			MapTerrain._conifer(l, c + Vector2(-16, 8), 1.0, 0.3)
			MapTerrain._broadleaf(l, c + Vector2(2, 12), 1.0, 0.5)
			MapTerrain._conifer(l, c + Vector2(18, 6), 0.9, 0.8)
		"t_hills":
			MapTerrain._hill(l, c + Vector2(-12, 8), 1.1)
			MapTerrain._hill(l, c + Vector2(12, 12), 0.9)
		"t_mountain":
			MapTerrain._peak(l, c + Vector2(-12, 14), 22.0, false, 0.3)
			MapTerrain._peak(l, c + Vector2(10, 15), 28.0, true, 0.6)
		"t_swamp":
			for i in 2:
				var sp: Vector2 = c + Vector2(-14.0 + i * 26.0, 10.0)
				l.draw_set_transform(sp, 0.0, Vector2(1.0, 0.45))
				l.draw_circle(Vector2.ZERO, 8.0, Color(0.22, 0.32, 0.30, 0.9))
				l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in 4:
				var rp: Vector2 = c + Vector2(-20.0 + i * 12.0, 16.0)
				l.draw_multiline(PackedVector2Array([rp, rp + Vector2(-1.5, -7), rp, rp + Vector2(0.3, -9), rp, rp + Vector2(1.8, -6.5)]), Color(0.36, 0.42, 0.2, 0.95), 1.2)
				l.draw_circle(rp + Vector2(0.3, -9), 1.2, Color(0.42, 0.3, 0.18))
		"t_snow":
			for i in 6:
				var np := Vector2(10.0 + i * 11.0, 12.0 + float((i * 5) % 4) * 7.0)
				l.draw_line(np, np + Vector2(4.0, -1.0), Color(0.62, 0.7, 0.74, 0.9), 1.4)
			MapTerrain._conifer(l, c + Vector2(14, 14), 0.9, 0.2)
		"t_ford":
			MapTerrain._ford(l, c, 3, 3)
		"t_bridge":
			MapTerrain.paint_bridge(l, c, 0.0, false)
		"t_road":
			MapTerrain.paint_road_swatch(l, Vector2(6, c.y + 2.0), Vector2(cell.x - 6.0, c.y - 2.0))
	l.draw_rect(r, Color("17110c"), false, 1.2)
