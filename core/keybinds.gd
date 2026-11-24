class_name Keybinds
extends RefCounted
## Touches reconfigurables. Une action nommée a une ou plusieurs « touches » (entiers : code | modificateurs | PHYS).
## Valeurs par défaut = les touches historiques du jeu. Les remplacements du joueur (`overrides`, action -> tableau d'entiers)
## sont poussés ici par `Settings` et sauvegardés dans `user://settings.cfg`. Logique pure, sans scène.
## Règle de correspondance : Ctrl / Alt / Méta doivent correspondre exactement ; Maj n'est exigée que si la touche l'inclut
## (ainsi « ? » fonctionne sur tous les claviers) -> tester « Maj+Tab » AVANT « Tab ».

const PHYS: int = 1 << 40  ## touche physique (position sur le clavier : W A S D = Z Q S D en AZERTY)
const CTRL: int = KEY_MASK_CTRL
const SHIFT: int = KEY_MASK_SHIFT
const ALT: int = KEY_MASK_ALT
const MOD_MASK: int = KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_MASK_ALT
const CODE_MASK: int = KEY_CODE_MASK

## Contextes : « map » = tout sauf la bataille (carte, camp, fenêtres) ; « battle » = pendant une bataille.
## `held` : touche testée en continu (caméra), pas par événement.
const ACTIONS: Array = [
	{"id": "end_turn", "ctx": ["battle"], "zone": "battle", "label": "Fin du tour", "keys": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]},
	{"id": "wait", "ctx": ["battle"], "zone": "battle", "label": "Attendre (repasser en fin de file)", "keys": [KEY_W]},
	{"id": "undo_move", "ctx": ["battle"], "zone": "battle", "label": "Annuler le dernier déplacement", "keys": [KEY_Z | KEY_MASK_CTRL, KEY_BACKSPACE]},
	{"id": "inspect_next", "ctx": ["battle"], "zone": "battle", "label": "Inspecter l'unité suivante", "keys": [KEY_TAB]},
	{"id": "inspect_prev", "ctx": ["battle"], "zone": "battle", "label": "Inspecter l'unité précédente", "keys": [KEY_TAB | KEY_MASK_SHIFT]},
	{"id": "battle_view", "ctx": ["battle"], "zone": "battle", "label": "Vue d'ensemble du plateau", "keys": [KEY_H, KEY_HOME]},
	{"id": "slot_1", "ctx": ["battle"], "zone": "battle", "label": "Bouton d'action n° 1", "keys": [KEY_1 | PHYS, KEY_KP_1]},
	{"id": "slot_2", "ctx": ["battle"], "zone": "battle", "label": "Bouton d'action n° 2", "keys": [KEY_2 | PHYS, KEY_KP_2]},
	{"id": "slot_3", "ctx": ["battle"], "zone": "battle", "label": "Bouton d'action n° 3", "keys": [KEY_3 | PHYS, KEY_KP_3]},
	{"id": "slot_4", "ctx": ["battle"], "zone": "battle", "label": "Bouton d'action n° 4", "keys": [KEY_4 | PHYS, KEY_KP_4]},
	{"id": "slot_5", "ctx": ["battle"], "zone": "battle", "label": "Bouton d'action n° 5", "keys": [KEY_5 | PHYS, KEY_KP_5]},
	{"id": "slot_6", "ctx": ["battle"], "zone": "battle", "label": "Bouton d'action n° 6", "keys": [KEY_6 | PHYS, KEY_KP_6]},
	{"id": "slot_7", "ctx": ["battle"], "zone": "battle", "label": "Bouton d'action n° 7", "keys": [KEY_7 | PHYS, KEY_KP_7]},
	{"id": "slot_8", "ctx": ["battle"], "zone": "battle", "label": "Bouton d'action n° 8", "keys": [KEY_8 | PHYS, KEY_KP_8]},
	{"id": "slot_9", "ctx": ["battle"], "zone": "battle", "label": "Bouton d'action n° 9", "keys": [KEY_9 | PHYS, KEY_KP_9]},
	{"id": "map_pause", "ctx": ["map"], "zone": "map", "label": "Pause / reprise du temps", "keys": [KEY_SPACE]},
	{"id": "map_next_place", "ctx": ["map"], "zone": "map", "label": "Lieu suivant (centre la vue)", "keys": [KEY_TAB]},
	{"id": "map_prev_place", "ctx": ["map"], "zone": "map", "label": "Lieu précédent", "keys": [KEY_TAB | KEY_MASK_SHIFT]},
	{"id": "cam_up", "ctx": ["map"], "zone": "map", "held": true, "label": "Caméra : haut", "keys": [KEY_W | PHYS, KEY_UP | PHYS]},
	{"id": "cam_down", "ctx": ["map"], "zone": "map", "held": true, "label": "Caméra : bas", "keys": [KEY_S | PHYS, KEY_DOWN | PHYS]},
	{"id": "cam_left", "ctx": ["map"], "zone": "map", "held": true, "label": "Caméra : gauche", "keys": [KEY_A | PHYS, KEY_LEFT | PHYS]},
	{"id": "cam_right", "ctx": ["map"], "zone": "map", "held": true, "label": "Caméra : droite", "keys": [KEY_D | PHYS, KEY_RIGHT | PHYS]},
	{"id": "cam_fast", "ctx": ["map"], "zone": "map", "held": true, "label": "Caméra : aller plus vite (maintenir)", "keys": [KEY_SHIFT]},
	{"id": "map_center", "ctx": ["map"], "zone": "map", "label": "Recentrer sur la compagnie", "keys": [KEY_C, KEY_H, KEY_HOME]},
	{"id": "map_details", "ctx": ["map"], "zone": "map", "label": "Tiroir « Détails »", "keys": [KEY_F]},
	{"id": "map_legend", "ctx": ["map"], "zone": "map", "label": "Légende de la carte", "keys": [KEY_L]},
	{"id": "map_minimap", "ctx": ["map"], "zone": "map", "label": "Replier / déplier la mini-carte", "keys": [KEY_M]},
	{"id": "inventory", "ctx": ["map"], "zone": "ui", "label": "Inventaire", "keys": [KEY_I]},
	{"id": "journal", "ctx": ["map"], "zone": "ui", "label": "Journal de campagne et mémorial", "keys": [KEY_J]},
	{"id": "codex", "ctx": ["map"], "zone": "ui", "label": "Encyclopédie", "keys": [KEY_F1]},
	{"id": "help", "ctx": ["map", "battle"], "zone": "ui", "label": "Aide : raccourcis clavier", "keys": [KEY_F1, KEY_QUESTION]},
]

## Paires d'actions autorisées à partager une touche par défaut (la première gagne là où les deux sont possibles).
const ALLOWED_SHARED: Array = [["codex", "help"]]
## Touches jamais attribuables : Échap (annuler / fermer partout).
const RESERVED: Array = [KEY_ESCAPE]
## Touches de validation du dialogue : seules les actions qui les ont par défaut peuvent les garder.
const CONFIRM_KEYS: Array = [KEY_ENTER, KEY_KP_ENTER]

const ZONES: Array = [["map", "Carte"], ["battle", "Bataille"], ["ui", "Interface"]]

## action -> Array[int] : remplacements du joueur uniquement (une action absente garde ses touches par défaut).
static var overrides: Dictionary = {}
static var _index: Dictionary = {}


static func _def(action: String) -> Dictionary:
	if _index.is_empty():
		for a in ACTIONS:
			_index[str(a["id"])] = a
	return _index.get(action, {})


static func has_action(action: String) -> bool:
	return not _def(action).is_empty()


static func action_ids() -> Array:
	var out: Array = []
	for a in ACTIONS:
		out.append(str(a["id"]))
	return out


static func label_of(action: String) -> String:
	return str(_def(action).get("label", action))


static func defaults(action: String) -> Array:
	var out: Array = []
	for k in _def(action).get("keys", []):
		out.append(int(k))
	return out


## Touches courantes d'une action.
static func keys_of(action: String) -> Array:
	if overrides.has(action):
		return (overrides[action] as Array).duplicate()
	return defaults(action)


static func is_default(action: String) -> bool:
	return not overrides.has(action)


# --- Correspondance ---

## Le code d'une touche (sans modificateurs ni drapeau physique).
static func code_of(spec: int) -> int:
	return spec & CODE_MASK


static func spec_matches(spec: int, ke: InputEventKey) -> bool:
	var phys: bool = (spec & PHYS) != 0
	var code: int = spec & CODE_MASK
	var got: int = ke.physical_keycode if phys else ke.keycode
	if got == 0 and not phys:
		got = ke.physical_keycode
	var ok: bool = got == code
	if not ok and code == KEY_QUESTION and not phys and ke.unicode == 63:
		ok = true
	if not ok:
		return false
	if _is_modifier_code(code):
		return true  # touche modificatrice seule (ex. Maj de la caméra) : sa propre pression ne compte pas
	if ke.ctrl_pressed != ((spec & CTRL) != 0) or ke.alt_pressed != ((spec & ALT) != 0) or ke.meta_pressed:
		return false
	return (spec & SHIFT) == 0 or ke.shift_pressed


## Vrai si l'événement (une touche pressée) correspond à l'action.
static func matches(event: InputEvent, action: String) -> bool:
	if not (event is InputEventKey):
		return false
	var ke := event as InputEventKey
	for s in keys_of(action):
		if spec_matches(int(s), ke):
			return true
	return false


## Actions de `candidates` qui correspondent (dans l'ordre donné) : première trouvée, "" sinon.
static func first_match(event: InputEvent, candidates: Array) -> String:
	for a in candidates:
		if matches(event, str(a)):
			return str(a)
	return ""


## Numéro 1..9 du bouton d'action pressé, 0 sinon.
static func slot_of(event: InputEvent) -> int:
	for i in range(1, 10):
		if matches(event, "slot_%d" % i):
			return i
	return 0


## Touche maintenue (caméra) : vrai si une des touches de l'action est enfoncée en ce moment.
static func is_held(action: String) -> bool:
	for s in keys_of(action):
		var spec: int = int(s)
		var code: int = spec & CODE_MASK
		if (spec & PHYS) != 0:
			if Input.is_physical_key_pressed(code as Key):
				return true
		elif Input.is_key_pressed(code as Key):
			return true
	return false


# --- Affichage ---

## Nom lisible d'une touche (« Ctrl+Z », « Z » pour la touche physique W en AZERTY…).
static func spec_name(spec: int) -> String:
	var code: int = spec & CODE_MASK
	var mods: int = spec & MOD_MASK
	var shown: int = code
	if (spec & PHYS) != 0 and DisplayServer.get_name() != "headless" and not (code >= KEY_0 and code <= KEY_9):
		var k: int = DisplayServer.keyboard_get_keycode_from_physical(code as Key)
		if k != 0:
			shown = k & CODE_MASK
	var base: String = _key_text(shown)
	var out: String = ""
	if (mods & CTRL) != 0:
		out += "Ctrl+"
	if (mods & ALT) != 0:
		out += "Alt+"
	if (mods & SHIFT) != 0:
		out += "Maj+"
	return out + base


static func _key_text(code: int) -> String:
	match code:
		KEY_SPACE:
			return "Espace"
		KEY_ENTER:
			return "Entrée"
		KEY_KP_ENTER:
			return "Entrée (pavé)"
		KEY_TAB:
			return "Tab"
		KEY_BACKSPACE:
			return "Retour arrière"
		KEY_HOME:
			return "Début"
		KEY_ESCAPE:
			return "Échap"
		KEY_SHIFT:
			return "Maj"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_QUESTION:
			return "?"
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return "Pavé %d" % (code - KEY_KP_0)
	var s: String = OS.get_keycode_string(code as Key)
	return s if s != "" else "Touche %d" % code


## « Espace / Entrée » : toutes les touches courantes de l'action.
static func names_of(action: String) -> String:
	var parts: PackedStringArray = []
	for s in keys_of(action):
		parts.append(spec_name(int(s)))
	return " / ".join(parts)


## Première touche seulement (pour les étiquettes de boutons : « Fin du tour [Espace] »).
static func short_name(action: String) -> String:
	var ks: Array = keys_of(action)
	return spec_name(int(ks[0])) if not ks.is_empty() else "—"


## Touche saisie par le joueur -> spec ; physical vrai pour les lettres/flèches de caméra.
static func spec_from_event(ke: InputEventKey, physical: bool = false) -> int:
	var code: int = ke.physical_keycode if physical else ke.keycode
	if code == 0:
		code = ke.physical_keycode
	var spec: int = code & CODE_MASK
	if physical:
		spec |= PHYS
	if ke.ctrl_pressed:
		spec |= CTRL
	if ke.alt_pressed:
		spec |= ALT
	if ke.shift_pressed and not _is_modifier_code(code):
		spec |= SHIFT
	return spec


static func _is_modifier_code(code: int) -> bool:
	return code == KEY_SHIFT or code == KEY_CTRL or code == KEY_ALT or code == KEY_META


## Une action « physique » (caméra) enregistre la position de la touche, les autres le caractère.
static func is_physical_action(action: String) -> bool:
	for s in defaults(action):
		if (int(s) & PHYS) != 0:
			return true
	return false


# --- Conflits et affectation ---

static func _contexts(action: String) -> Array:
	return _def(action).get("ctx", [])


static func _share_context(a: String, b: String) -> bool:
	for c in _contexts(a):
		if _contexts(b).has(c):
			return true
	return false


static func _allowed_pair(a: String, b: String) -> bool:
	for p in ALLOWED_SHARED:
		if (p[0] == a and p[1] == b) or (p[0] == b and p[1] == a):
			return true
	return false


## Vrai si cette touche ne peut être attribuée à personne (Échap, ou validation du dialogue pour une action qui ne l'a pas).
static func is_reserved(spec: int, action: String) -> bool:
	var code: int = spec & CODE_MASK
	if RESERVED.has(code):
		return true
	if CONFIRM_KEYS.has(code) and (spec & MOD_MASK) == 0:
		for d in defaults(action):
			if (int(d) & CODE_MASK) == code and (int(d) & MOD_MASK) == 0:
				return false
		return true
	return false


## Actions (autres que `action`) qui utilisent déjà cette touche dans un contexte commun.
static func conflicts(action: String, spec: int) -> Array:
	var out: Array = []
	for other in action_ids():
		if other == action or not _share_context(action, other) or _allowed_pair(action, other):
			continue
		for s in keys_of(other):
			if int(s) == spec:
				out.append(other)
				break
	return out


## Détecte les doublons dans la configuration courante : [[action_a, action_b, spec], ...].
static func find_conflicts() -> Array:
	var out: Array = []
	var ids: Array = action_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if not _share_context(ids[i], ids[j]) or _allowed_pair(ids[i], ids[j]):
				continue
			for s in keys_of(ids[i]):
				if keys_of(ids[j]).has(s):
					out.append([ids[i], ids[j], int(s)])
	return out


## Remplace la touche numéro `index` de l'action. Retour : {"ok": bool, "msg": String, "conflict": Array}.
## `swap` : si la touche est prise, l'autre action reçoit l'ancienne touche (échange) ; sinon refus.
static func assign(action: String, index: int, spec: int, swap: bool = false) -> Dictionary:
	if not has_action(action):
		return {"ok": false, "msg": "Action inconnue.", "conflict": []}
	if is_reserved(spec, action):
		return {"ok": false, "msg": "Cette touche est réservée.", "conflict": []}
	var cur: Array = keys_of(action)
	index = clampi(index, 0, maxi(0, cur.size()))
	var old: int = int(cur[index]) if index < cur.size() else -1
	if cur.has(spec) and old != spec:
		return {"ok": false, "msg": "Cette touche est déjà utilisée par cette action.", "conflict": []}
	var cf: Array = conflicts(action, spec)
	if not cf.is_empty():
		if not swap or old < 0:
			return {"ok": false, "msg": "Déjà utilisée par : %s." % ", ".join(cf.map(func(a: Variant) -> String: return label_of(str(a)))), "conflict": cf}
		for other in cf:
			if is_reserved(old, str(other)):
				return {"ok": false, "msg": "Échange impossible.", "conflict": cf}
		for other in cf:
			var ok: Array = keys_of(str(other))
			var at: int = ok.find(spec)
			ok[at] = old
			overrides[str(other)] = ok
	if index < cur.size():
		cur[index] = spec
	else:
		cur.append(spec)
	overrides[action] = cur
	_prune(action)
	return {"ok": true, "msg": "", "conflict": cf}


static func _prune(action: String) -> void:
	if overrides.has(action) and overrides[action] == defaults(action):
		overrides.erase(action)
	for a in overrides.keys():
		if overrides[a] == defaults(str(a)):
			overrides.erase(a)


static func reset_action(action: String) -> void:
	overrides.erase(action)


static func reset_all() -> void:
	overrides = {}


# --- Sauvegarde (section « keys » du fichier de réglages) ---

## Tableau d'entiers valide pour une action connue, sinon null (jamais d'erreur).
static func sanitize_keys(action: String, value: Variant) -> Variant:
	if not has_action(action) or typeof(value) != TYPE_ARRAY:
		return null
	var arr: Array = value
	if arr.is_empty() or arr.size() > 4:
		return null
	var out: Array = []
	for v in arr:
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
			return null
		var n: int = int(v)
		var code: int = n & CODE_MASK
		if code <= 0 or n < 0 or n >> 41 != 0 or RESERVED.has(code) or out.has(n):
			return null
		out.append(n)
	return out


## Charge les remplacements depuis un dictionnaire action -> tableau ; ignore ce qui est invalide ;
## en cas de conflit résiduel, l'action en conflit retombe sur ses touches par défaut.
static func load_overrides(raw: Dictionary) -> void:
	overrides = {}
	for a in raw:
		var v: Variant = sanitize_keys(str(a), raw[a])
		if v != null:
			overrides[str(a)] = v
	for c in find_conflicts():
		overrides.erase(str(c[0]))
		overrides.erase(str(c[1]))
	_prune("")


static func export_overrides() -> Dictionary:
	return overrides.duplicate(true)
