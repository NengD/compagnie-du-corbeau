class_name ContractCard
extends RefCounted
## Carte de contrat « parchemin » de l'onglet Contrats : bandeau du type (vignette dessinée en `_draw`), cachet de la faction qui
## l'émet, crânes de danger, prime et lieu. Aucune règle ici : accepter appelle le rappel donné, comme l'ancien affichage.

const OL := Color("17110c")
const INK := Color("3a2a18")
const PARCH := Color("d6c597")

## Types de contrat : libellé, couleur du bandeau. Toute valeur inconnue retombe sur "kill".
const KINDS: Dictionary = {
	"kill": {"n": "Élimination", "c": Color("7a2a20")},
	"hunt": {"n": "Chasse au chef", "c": Color("6a4a22")},
	"escort": {"n": "Escorte", "c": Color("3f5a3a")},
	"delivery": {"n": "Livraison", "c": Color("4a5a78")},
	"defense": {"n": "Défense", "c": Color("5a4a6a")},
	"ruins": {"n": "Ruines", "c": Color("5a5a4a")},
	"legend": {"n": "Bête légendaire", "c": Color("8a2a52")},
}


## Clé de type d'une carte (anciennes sauvegardes : "kill").
static func kind_of(ct: Dictionary) -> String:
	var k: String = str(ct.get("type_contract", "kill"))
	if bool(ct.get("ruins", false)) or k == "ruins":
		return "ruins"
	return k if KINDS.has(k) else "kill"


static func kind_name(kind: String) -> String:
	return str((KINDS.get(kind, KINDS["kill"]) as Dictionary)["n"])


## Construit la carte dans `parent`. `on_accept` : Callable sans argument. Renvoie le bouton « Accepter ».
static func build(parent: Node, ct: Dictionary, origin: Vector2, can_accept: bool, on_accept: Callable, width: int = 320) -> Button:
	var c := UiKit.card(parent, width)
	var kind: String = kind_of(ct)
	var fk: String = str(ct.get("faction", ""))
	var head := Head.new()
	head.kind = kind
	head.faction = fk
	head.danger = int(ct.get("d", 1))
	head.custom_minimum_size = Vector2(0, 54)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.tooltip_text = "%s · danger %d sur 3" % [kind_name(kind), head.danger]
	c.add_child(head)
	var top := UiKit.hbox(6)
	if ct.has("arc") and Campaign.ARCS.has(ct["arc"]):
		top.add_child(UiKit.chip("%s · %d/%d" % [Campaign.ARCS[ct["arc"]]["title"], int(ct.get("arc_step", 0)) + 1, Campaign.ARC_STEPS], GameTheme.GOLD))
	top.add_child(UiKit.spacer())
	var dist: float = origin.distance_to(Vector2(float(ct.get("tx", 0.0)), float(ct.get("ty", 0.0))))
	top.add_child(UiKit.sub("≈ %d jour%s de route" % [maxi(1, int(ceil(dist / World.DAY_PX))), "s" if dist > World.DAY_PX else ""], 13, false))
	c.add_child(top)
	c.add_child(UiKit.title(str(ct.get("title", "")), 22))
	c.add_child(UiKit.sub(str(ct.get("employer", ""))))
	if Data.FACTIONS.has(fk):
		var fl := UiKit.label("%s %s" % [Data.FACTIONS[fk]["ic"], Factions.name_of(fk)], 13, Factions.color_of(fk), true)
		fl.tooltip_text = "Employeur : sa réputation est en jeu."
		c.add_child(fl)
		if Data.FACTIONS.has(str(ct.get("vs_faction", ""))):
			c.add_child(UiKit.sub("Dessert la cause contre : " + Factions.name_of(str(ct["vs_faction"])) + " (prime majorée)", 12))
	c.add_child(UiKit.para(str(ct.get("desc", ""))))
	var where: String = str(ct.get("target_name", ""))
	var foe_name: String = str(Data.FACTION_NAMES.get(str(ct.get("type", "")), ""))
	if Contracts.is_transport(ct):
		var risk: String = "embuscade possible (%s)" % foe_name if float(ct.get("ambush_at", -1.0)) >= 0.0 else "route réputée sûre"
		c.add_child(UiKit.sub("%s · destination : %s · prime à l'arrivée · risque : %s" % [kind_name(kind), where, risk]))
	else:
		c.add_child(UiKit.sub("%s · Lieu : %s · ennemis : %s, environ %d" % [kind_name(kind), where, foe_name, (ct.get("foes", []) as Array).size()]))
	var foot := UiKit.hbox(6)
	foot.add_child(UiKit.label(str(ct.get("pay", 0)), 22, GameTheme.GOLD, true))
	foot.add_child(UiKit.sub("couronnes", 13, false))
	foot.add_child(UiKit.spacer())
	var acc := UiKit.button("Accepter", "pri")
	acc.disabled = not can_accept
	if on_accept.is_valid():
		acc.pressed.connect(on_accept)
	foot.add_child(acc)
	c.add_child(foot)
	return acc


## Bandeau (Head) : fond de couleur du type, vignette à gauche, nom du type, cachet de faction et crânes de danger à droite.
class Head extends Control:
	var kind: String = "kill"
	var faction: String = ""
	var danger: int = 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var s: Vector2 = size
		var col: Color = (ContractCard.KINDS.get(kind, ContractCard.KINDS["kill"]) as Dictionary)["c"]
		draw_rect(Rect2(Vector2.ZERO, s), col)
		draw_rect(Rect2(Vector2(0, s.y - 5.0), Vector2(s.x, 5.0)), col.darkened(0.3))
		draw_rect(Rect2(Vector2.ZERO, s), ContractCard.OL, false, 2.0)
		# vignette dans un petit cadre de parchemin
		var vr := Rect2(Vector2(5, 5), Vector2(s.y - 10.0 + 14.0, s.y - 10.0))
		draw_rect(vr, ContractCard.PARCH)
		draw_rect(vr, ContractCard.OL, false, 1.5)
		ContractCard.paint_vignette(self, kind, vr.grow(-2.0))
		var f: Font = GameTheme.title_font()
		var tx: float = vr.end.x + 8.0
		draw_string(f, Vector2(tx, s.y * 0.5 + 2.0), I18n.t(ContractCard.kind_name(kind)), HORIZONTAL_ALIGNMENT_LEFT, maxf(s.x - tx - 70.0, 40.0), 19, Color("f0e6cc"))
		# crânes de danger
		for n in 3:
			ContractCard.paint_skull(self, Vector2(tx + 8.0 + n * 18.0, s.y - 14.0), 6.5, n < danger)
		# cachet de faction (cire)
		if Data.FACTIONS.has(faction):
			var fc: Color = Factions.color_of(faction)
			var sc := Vector2(s.x - 26.0, s.y * 0.5)
			draw_circle(sc + Vector2(1.5, 1.5), 15.0, Color(0, 0, 0, 0.35))
			draw_circle(sc, 15.0, fc.darkened(0.2))
			draw_arc(sc, 11.0, 0.0, TAU, 20, fc.lightened(0.3), 1.4, true)
			draw_arc(sc, 15.0, 0.0, TAU, 24, ContractCard.OL, 1.4, true)
			var nm: String = Factions.name_of(faction)
			draw_string(f, sc + Vector2(-8.0, 6.0), nm.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, 16, 17, Color("f0e6cc"))


## Petit crâne (plein si `on`, contour sinon).
static func paint_skull(c: CanvasItem, p: Vector2, r: float, on: bool) -> void:
	var fill := Color("e6dcc0") if on else Color(0.9, 0.85, 0.75, 0.22)
	var line := OL if on else Color(0.9, 0.85, 0.75, 0.4)
	c.draw_circle(p + Vector2(0, -r * 0.1), r, fill)
	c.draw_rect(Rect2(p + Vector2(-r * 0.5, r * 0.55), Vector2(r, r * 0.7)), fill)
	c.draw_arc(p + Vector2(0, -r * 0.1), r, 0.0, TAU, 16, line, 1.0, true)
	var eye: Color = Color("2a1a14") if on else Color(0.1, 0.07, 0.05, 0.4)
	c.draw_circle(p + Vector2(-r * 0.4, -r * 0.1), r * 0.26, eye)
	c.draw_circle(p + Vector2(r * 0.4, -r * 0.1), r * 0.26, eye)
	c.draw_line(p + Vector2(-r * 0.2, r * 0.7), p + Vector2(-r * 0.2, r * 1.2), line, 0.8)
	c.draw_line(p + Vector2(r * 0.2, r * 0.7), p + Vector2(r * 0.2, r * 1.2), line, 0.8)


## Vignette d'un type de contrat dans `r` : dessins simples à l'encre sur le parchemin.
static func paint_vignette(c: CanvasItem, kind: String, r: Rect2) -> void:
	var m: Vector2 = r.get_center()
	var u: float = minf(r.size.x, r.size.y) * 0.5
	match kind:
		"hunt":  # tête cornue et cible
			c.draw_arc(m, u * 0.85, 0.0, TAU, 20, INK, 1.6, true)
			c.draw_circle(m + Vector2(0, u * 0.1), u * 0.4, INK)
			c.draw_polyline(PackedVector2Array([m + Vector2(-u * 0.3, -u * 0.1), m + Vector2(-u * 0.6, -u * 0.6), m + Vector2(-u * 0.2, -u * 0.35)]), INK, 2.0)
			c.draw_polyline(PackedVector2Array([m + Vector2(u * 0.3, -u * 0.1), m + Vector2(u * 0.6, -u * 0.6), m + Vector2(u * 0.2, -u * 0.35)]), INK, 2.0)
			c.draw_circle(m + Vector2(-u * 0.15, u * 0.05), 1.6, PARCH)
			c.draw_circle(m + Vector2(u * 0.15, u * 0.05), 1.6, PARCH)
		"escort":  # chariot
			c.draw_rect(Rect2(m + Vector2(-u * 0.6, -u * 0.35), Vector2(u * 1.2, u * 0.6)), INK)
			c.draw_arc(m + Vector2(0, -u * 0.35), u * 0.6, PI, TAU, 12, INK, 2.0, true)
			c.draw_circle(m + Vector2(-u * 0.4, u * 0.4), u * 0.22, INK)
			c.draw_circle(m + Vector2(u * 0.4, u * 0.4), u * 0.22, INK)
			c.draw_circle(m + Vector2(-u * 0.4, u * 0.4), u * 0.08, PARCH)
			c.draw_circle(m + Vector2(u * 0.4, u * 0.4), u * 0.08, PARCH)
		"delivery":  # lettre scellée
			c.draw_rect(Rect2(m + Vector2(-u * 0.7, -u * 0.45), Vector2(u * 1.4, u * 0.9)), Color("efe4c4"))
			c.draw_rect(Rect2(m + Vector2(-u * 0.7, -u * 0.45), Vector2(u * 1.4, u * 0.9)), INK, false, 1.6)
			c.draw_polyline(PackedVector2Array([m + Vector2(-u * 0.7, -u * 0.45), m + Vector2(0, u * 0.1), m + Vector2(u * 0.7, -u * 0.45)]), INK, 1.4)
			c.draw_circle(m + Vector2(0, u * 0.1), u * 0.2, Color("9c2f24"))
		"defense":  # tour crénelée
			c.draw_rect(Rect2(m + Vector2(-u * 0.4, -u * 0.35), Vector2(u * 0.8, u * 0.95)), INK)
			for n in 3:
				c.draw_rect(Rect2(m + Vector2(-u * 0.4 + n * u * 0.34, -u * 0.6), Vector2(u * 0.2, u * 0.28)), INK)
			c.draw_rect(Rect2(m + Vector2(-u * 0.1, u * 0.2), Vector2(u * 0.2, u * 0.4)), PARCH)
		"ruins":  # arche brisée
			c.draw_rect(Rect2(m + Vector2(-u * 0.6, -u * 0.1), Vector2(u * 0.25, u * 0.7)), INK)
			c.draw_rect(Rect2(m + Vector2(u * 0.35, -u * 0.45), Vector2(u * 0.25, u * 1.05)), INK)
			c.draw_arc(m + Vector2(u * 0.0, -u * 0.1), u * 0.55, PI, PI * 1.55, 8, INK, 3.0, true)
			c.draw_line(m + Vector2(-u * 0.7, u * 0.6), m + Vector2(u * 0.7, u * 0.6), INK, 2.0)
		"legend":  # œil de bête
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-u * 0.8, 0), m + Vector2(0, -u * 0.5), m + Vector2(u * 0.8, 0), m + Vector2(0, u * 0.5)]), INK)
			c.draw_circle(m, u * 0.28, Color("c8483a"))
			c.draw_line(m + Vector2(0, -u * 0.3), m + Vector2(0, u * 0.3), INK, 2.0)
		_:  # kill : deux épées croisées
			c.draw_line(m + Vector2(-u * 0.7, -u * 0.7), m + Vector2(u * 0.7, u * 0.5), INK, 2.6)
			c.draw_line(m + Vector2(u * 0.7, -u * 0.7), m + Vector2(-u * 0.7, u * 0.5), INK, 2.6)
			c.draw_line(m + Vector2(-u * 0.5, u * 0.3), m + Vector2(-u * 0.2, u * 0.7), INK, 2.0)
			c.draw_line(m + Vector2(u * 0.5, u * 0.3), m + Vector2(u * 0.2, u * 0.7), INK, 2.0)
