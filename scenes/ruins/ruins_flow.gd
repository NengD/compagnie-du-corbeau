class_name RuinsFlow
extends RefCounted
## Branche les fenêtres d'aventure (RuinsScreen) sur l'autoload Game : ruines à explorer, antre de bête légendaire.
## Appelé par la carte : `RuinsFlow.on_map_event(self, ev)` à l'arrivée à un point d'intérêt, `RuinsFlow.resume(self)` quand une
## exploration attend une décision (au retour d'un combat ou d'un chargement). Un seul panneau à la fois (groupe « adventure_modal »).

const GROUP: String = "adventure_modal"


static func _game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/Game")


static func busy(host: Node) -> bool:
	return not host.get_tree().get_nodes_in_group(GROUP).is_empty()


static func _track(m: ModalOverlay) -> ModalOverlay:
	m.add_to_group(GROUP)
	return m


## Événement de la carte {"type": "ruins" | "legend_lair", "id", ...}. Renvoie true s'il a été traité.
static func on_map_event(host: Node, ev: Dictionary) -> bool:
	var g: Node = _game()
	match str(ev.get("type", "")):
		"ruins":
			var q: Dictionary = g.world.poi_by_id(str(ev["id"]))
			if q.is_empty():
				return false
			var m: Array = [null]
			m[0] = _track(RuinsScreen.open_entry(host, str(q["name"]), Ruins.theme_for(q, int(g.renown)), Ruins.danger_for(int(g.renown), int(g.world.region_danger(g.world.poi_pos(q)))),
				func() -> void:
					(m[0] as ModalOverlay).close()
					g.ruins_enter(str(ev["id"])),
				func() -> void: (m[0] as ModalOverlay).close()))
			return true
		"legend_lair":
			var m2: Array = [null]
			m2[0] = _track(RuinsScreen.open_lair(host, str(ev["beast"]),
				func() -> void:
					(m2[0] as ModalOverlay).close()
					g.lair_attack(str(ev["id"])),
				func() -> void: (m2[0] as ModalOverlay).close()))
			return true
	return false


## Rouvre la fenêtre d'exploration si une décision attend (phase « choice » ou « chest »).
static func resume(host: Node, last: Dictionary = {}) -> bool:
	var g: Node = _game()
	if busy(host) or not Ruins.pending(g.extras) or g.battle != null:
		return false
	_show_run(host, last)
	return true


static func _show_run(host: Node, last: Dictionary) -> void:
	var g: Node = _game()
	var run: Dictionary = Ruins.run_of(g.extras)
	var m: Array = [null]
	m[0] = _track(RuinsScreen.open_run(host, run, last, func(id: String) -> void:
		var res: Dictionary = g.ruins_act(id)
		(m[0] as ModalOverlay).close()
		if not bool(res["ok"]) or bool(res["battle"]):
			return  # un combat commence : la carte cède la place à la bataille
		if Ruins.pending(g.extras):
			_show_run(host, res)
		else:
			var e: ModalOverlay = _track(ModalOverlay.open(host, 520))
			RuinsScreen.build_end(e.content, res, func() -> void: e.close())))
