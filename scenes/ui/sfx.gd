class_name Sfx
extends RefCounted
## Accès sûr à l'autoload Audio depuis n'importe quel script (sans effet s'il n'y a pas d'arbre de scène, comme dans les tests).


static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Audio") if tree != null else null


static func play(event: String) -> void:
	var a := _audio()
	if a != null:
		a.call("play", event)


static func paused(on: bool) -> void:
	var a := _audio()
	if a != null:
		a.call("set_paused", on)


static func music(track: String) -> void:
	var a := _audio()
	if a != null:
		a.call("music", track)
