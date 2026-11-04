class_name TraitChips
extends RefCounted
## Pastilles des traits de caractère d'un homme (info-bulle = description). Vert : atout, rouge : défaut, or : double tranchant.

const TONES := {"good": Color("8ea25f"), "bad": Color("c4574a"), "mixed": Color("cfa851")}


## Rangée de pastilles, ou null si l'homme n'a aucun trait.
static func row(u: Unit) -> Control:
	if u.traits.is_empty():
		return null
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	for k in u.traits:
		if Data.TRAITS.has(k):
			f.add_child(chip(str(k)))
	return f


static func chip(id: String) -> Control:
	var d: Dictionary = Data.TRAITS[id]
	var c: PanelContainer = UiKit.chip(str(d["n"]), TONES.get(str(d.get("tone", "mixed")), GameTheme.MUTE))
	c.tooltip_text = "%s : %s" % [d["n"], d["d"]]
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c
