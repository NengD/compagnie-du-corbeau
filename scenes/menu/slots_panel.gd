class_name SlotsPanel
extends RefCounted
## Fenêtre des emplacements de sauvegarde : la sauvegarde automatique (0) et 3 emplacements manuels.
## `allow_save` : proposer « Sauvegarder » (menu pause) ; au menu principal, on ne peut que charger / supprimer.

var modal: ModalOverlay
var allow_save: bool = false
var on_loaded: Callable  ## appelé après un chargement réussi
var _confirm: String = ""  ## « save:N » ou « del:N » en attente de confirmation


static func open(host: Node, p_allow_save: bool, p_on_loaded: Callable) -> SlotsPanel:
	var p := SlotsPanel.new()
	p.allow_save = p_allow_save
	p.on_loaded = p_on_loaded
	p.modal = ModalOverlay.open(host, 520)
	p._rebuild()
	return p


func _rebuild() -> void:
	var box: VBoxContainer = modal.content
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_child(UiKit.title("Sauvegardes" if allow_save else "Charger une partie", 34))
	for n in range(0, Game.SLOT_COUNT + 1):
		box.add_child(_card(n))
	var close := UiKit.button("Fermer", "pri")
	close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(modal.close)
	box.add_child(close)


func _card(n: int) -> Control:
	var info: Dictionary = Game.slot_info(n)
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	var h := UiKit.hbox(10)
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label("Sauvegarde automatique" if n == 0 else "Emplacement %d" % n, 17, GameTheme.GOLD, true))
	if info.is_empty():
		v.add_child(UiKit.sub("Vide"))
	else:
		v.add_child(UiKit.sub("Jour %d · %d couronnes · %d hommes" % [info["day"], info["gold"], info["men"]]))
		if str(info["date"]) != "":
			v.add_child(UiKit.sub(str(info["date"])))
	h.add_child(v)
	if allow_save and n > 0:
		var key: String = "save:%d" % n
		var sv := UiKit.button("Confirmer l'écrasement" if _confirm == key else ("Écraser" if not info.is_empty() else "Sauvegarder"), "pri" if info.is_empty() or _confirm == key else "", true)
		sv.pressed.connect(func() -> void:
			if not info.is_empty() and _confirm != key:
				_confirm = key
			else:
				Game.save_to_slot(n)
				_confirm = ""
			_rebuild())
		h.add_child(sv)
	var ld := UiKit.button("Charger", "pri" if not allow_save else "", true)
	ld.disabled = info.is_empty()
	ld.pressed.connect(func() -> void:
		if Game.load_slot(n):
			modal.close()
			if on_loaded.is_valid():
				on_loaded.call())
	h.add_child(ld)
	var dkey: String = "del:%d" % n
	var dl := UiKit.button("Confirmer" if _confirm == dkey else "Supprimer", "ghost", true)
	dl.disabled = info.is_empty()
	dl.pressed.connect(func() -> void:
		if _confirm != dkey:
			_confirm = dkey
		else:
			Game.delete_slot(n)
			_confirm = ""
		_rebuild())
	h.add_child(dl)
	p.add_child(h)
	return p
