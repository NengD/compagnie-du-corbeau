class_name HqTab
extends RefCounted
## Onglet « Quartier général » : bâtiments du camp, vivres, moral, réputation des factions. Lit `Game`, n'applique aucune règle.


static func build(root: VBoxContainer) -> void:
	_status(root)
	root.add_child(UiKit.title("Bâtiments du camp", 24))
	root.add_child(UiKit.sub("Le camp suit la compagnie : on améliore ses bâtiments où que l'on soit."))
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(flow)
	for key in Data.BUILDING_ORDER:
		_card(flow, str(key))
	root.add_child(UiKit.title("Factions", 24))
	var ff := HFlowContainer.new()
	ff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(ff)
	for k in Factions.keys():
		var c := UiKit.card(ff, 300)
		var n: int = Game.standing_with(str(k))
		c.add_child(UiKit.label("%s %s" % [Data.FACTIONS[k]["ic"], Factions.name_of(str(k))], 17, Factions.color_of(str(k)), true))
		c.add_child(UiKit.sub(str(Data.FACTIONS[k]["desc"])))
		c.add_child(UiKit.label("%s (%+d)" % [Factions.label(n), n], 14, GameTheme.INK, true))
		c.add_child(UiKit.sub(Factions.effects_text(n)))


static func _status(root: VBoxContainer) -> void:
	var c := UiKit.card(root)
	c.add_child(UiKit.label("État de la compagnie", 13, GameTheme.GOLD, true))
	c.add_child(UiKit.para("Vivres : %d rations (≈ %.1f jours de route, stock max %d)" % [Game.provisions, Game.provisions_days(), Game.provisions_cap()], 14))
	c.add_child(UiKit.para("Moral : %s (%d/100)" % [Game.morale_label(), int(Game.company_morale)], 14))
	c.add_child(UiKit.sub("Effectif %d/%d · réserve %d/%d" % [Game.roster.size(), Game.max_roster(), Game.inventory.size(), Game.stash_size()]))


static func _card(flow: Node, key: String) -> void:
	var def: Dictionary = Data.CAMP_BUILDINGS[key]
	var lv: int = Game.building_level(key)
	var c := UiKit.card(flow, 300)
	c.add_child(UiKit.label("%s %s — niveau %d/%d" % [def["ic"], def["n"], lv, CampBuildings.MAX_LEVEL], 16, GameTheme.INK, true))
	c.add_child(UiKit.sub(str(def["d"])))
	c.add_child(UiKit.sub("Actuel : " + CampBuildings.effect_text(key, lv)))
	var cost: int = CampBuildings.next_cost(Game.buildings, key)
	if cost < 0:
		c.add_child(UiKit.label("Niveau maximal", 13, GameTheme.GOLD, true))
		return
	c.add_child(UiKit.sub("Suivant : " + CampBuildings.effect_text(key, lv + 1)))
	var b := UiKit.button("Améliorer (%d couronnes)" % cost, "pri", true)
	b.disabled = not Game.can_buy_building(key)
	b.pressed.connect(func() -> void: Game.buy_building(key))
	c.add_child(b)
