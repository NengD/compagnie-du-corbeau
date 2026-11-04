class_name Figure
extends Node2D
## Figurine en buste : pile de calques (corps → armure → tête → barbe/cheveux → casque → arme → bouclier).
## Changer d'équipement = changer une texture. Voir tools/gen_sprites.py pour les calques.
## Le joueur regarde vers la droite, l'ennemi vers la gauche (scale.x = -1).

const DIR := "res://assets/sprites/"
const ORIGIN := Vector2(-36, -64)  ## coin haut-gauche du viewBox des calques
const PIXEL_SCALE := 0.25  ## les SVG sont rastérisés à 4×

const SKIN: Array[Color] = [Color("e2b896"), Color("cf9f78"), Color("b07a52"), Color("dcae88"), Color("8a5a3c"), Color("efcfb0"), Color("c48a62"), Color("6e4630")]
const HAIR: Array[Color] = [Color("2b1d14"), Color("4e3220"), Color("7a4e2a"), Color("a87e4a"), Color("6e6a64"), Color("141210"), Color("8c3a1e"), Color("c8b27a"), Color("b8b4aa")]
const CLOTH_P: Array[Color] = [Color("3e526a"), Color("4b5a3a"), Color("5e4a34"), Color("2f3f52"), Color("6a5b3c"), Color("5a4a6a"), Color("6a3e3a")]
const CLOTH_B: Array[Color] = [Color("6e3426"), Color("5b4a33"), Color("4b3a2c"), Color("7a5636"), Color("563028"), Color("3e3a30"), Color("6a4a2a")]
const HOOD: Array[Color] = [Color("8a7650"), Color("6b5a40"), Color("5a5a4a"), Color("7a6a52"), Color("4e5a46")]
const LEATHER: Array[Color] = [Color("7a5230"), Color("5e3e24"), Color("8a6a40"), Color("4a3220")]
const SLEEVES := {"mailles": Color("8f959b"), "brigandine": Color("8f959b"), "gambison": Color("b49a6c")}
const ORC_SKIN: Array[Color] = [Color("7a9a4e"), Color("6a8a46"), Color("88a55a"), Color("5e7e44"), Color("8a9a52")]
const ORC_HAIR := [3, 5, 6, -1]  ## coiffures humaines qui vont bien à un orc (-1 : aucune)
const BONE: Array[Color] = [Color("d8d0b8"), Color("c8bea0"), Color("e0dac4"), Color("b8ae92")]
const RUST := Color(0.82, 0.72, 0.62)  ## armes et boucliers des morts-vivants
const HAIR_STYLES := 7
const BEARD_STYLES := 8  ## 0 = rasé
const MARKS: Array[String] = ["", "scar_1", "scar_2", "scar_3", "bruise", "patch"]

## Ennemis d'élite : clé de Data.FOE -> ornements ("plume", "pauldron", "paint", "necklace"). Les hommes de niveau >= Data.ELITE_LEVEL
## portent la tenue de vétéran (plume ou cercle d'or, épaulière ornée, cape aux couleurs de la compagnie).
const ELITE_FOES := {"chef": ["plume", "pauldron"], "balafre": ["pauldron"], "berserker": ["paint", "necklace"], "orc_chef": ["necklace", "pauldron"]}
const ELITE_PLUME_FOE := Color("b03a2e")

static var _textures: Dictionary = {}

var unit: Unit
var _wall: bool = false
var base_scale: float = 1.0  ## carrure (orcs ×1.12, chef ×1.25) ; UnitView la combine à la respiration


static func texture(layer_name: String) -> Texture2D:
	if not _textures.has(layer_name):
		var path: String = DIR + layer_name + ".svg"
		_textures[layer_name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[layer_name]


func setup(u: Unit) -> Figure:
	unit = u
	base_scale = body_scale(u)
	scale = Vector2(-1.0 if u.side == "e" else 1.0, 1.0) * base_scale
	position.y = 10.0 * (1.0 - base_scale)
	rebuild()
	return self


## Ornements d'élite de `u` (voir ELITE_FOES) ; "vet" pour la tenue de vétéran des hommes de la compagnie.
static func elite_tags(u: Unit) -> Array:
	if u.side == "p":
		return ["vet", "plume", "pauldron", "cape"] if u.level >= Data.ELITE_LEVEL else []
	for k in ELITE_FOES:
		if Data.FOE.has(k) and str(Data.FOE[k]["n"]) == u.background:
			return ELITE_FOES[k]
	return []


## Bannière de la compagnie (celle de la partie en cours si l'autoload Game existe).
static func company_banner() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var g: Node = tree.root.get_node_or_null("Game") if tree != null else null
	if g != null and typeof(g.get("banner")) == TYPE_DICTIONARY:
		return g.get("banner")
	return Data.BANNER_DEFAULT


static func body_scale(u: Unit) -> float:
	if u.faction == "o":
		return 1.25 if u.leader else 1.12
	return 1.0


## Apparence stable pour une unité donnée (dérivée de son id).
static func look(u: Unit) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = u.id * 31 + 7
	var cloth: Array[Color] = CLOTH_P if u.side == "p" else CLOTH_B
	var d: Dictionary = {
		"skin": SKIN[r.randi() % SKIN.size()], "hair": HAIR[r.randi() % HAIR.size()],
		"beard": r.randi() % BEARD_STYLES, "hs": r.randi() % HAIR_STYLES, "cloth": cloth[r.randi() % cloth.size()],
		"hood": HOOD[r.randi() % HOOD.size()],
	}
	# nouveaux tirages à la suite : l'apparence de base reste celle d'avant
	d["face"] = r.randi() % 3
	d["mark"] = MARKS[r.randi() % MARKS.size()] if r.randf() < 0.4 else ""
	d["band"] = r.randf() < 0.25
	d["leather"] = LEATHER[r.randi() % LEATHER.size()]
	var acc: float = r.randf()
	d["acc"] = "cape" if acc < 0.2 else ("satchel" if acc < 0.4 else ("bandolier" if acc < 0.55 else ("scarf" if acc < 0.7 else "")))
	if u.faction == "o":
		d["skin"] = ORC_SKIN[r.randi() % ORC_SKIN.size()]
		d["face"] = r.randi() % 3
		d["hs"] = ORC_HAIR[r.randi() % ORC_HAIR.size()]
	if u.faction == "u":
		d["bone"] = BONE[r.randi() % BONE.size()]
		d["face"] = r.randi() % 2
	if u.faction == "g" or u.faction == "u":
		d["ghoul_b"] = r.randf() < 0.5
	return d


## Reconstruit les calques si l'équipement ou le mur de boucliers a changé.
func refresh() -> void:
	if unit != null and unit.shield_wall != _wall:
		rebuild()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_wall = unit.shield_wall
	var l: Dictionary = look(unit)
	if unit.faction == "u":
		_build_undead(l)
		return
	if unit.faction == "g":
		var gn: String = "ghoul_big" if unit.weapon == "griffesL" else "ghoul"
		_add(gn + "_b" if l["ghoul_b"] else gn)
		return
	var orc: bool = unit.faction == "o"
	var sleeve: Color = SLEEVES.get(unit.body, l["skin"].darkened(0.1) if orc and unit.body == "tunique" else l["cloth"])
	var w: String = unit.weapon
	var acc: String = l["acc"]
	var tags: Array = elite_tags(unit)
	if tags.has("cape"):  # vétéran : cape aux couleurs de la compagnie
		_add("cape", Banner.primary(company_banner()).darkened(0.3))
		_add("cape_trim")
	elif acc == "cape":
		_add("cape", l["cloth"].darkened(0.15))
	if w == "arc":
		_add("quiver")
	elif not unit.shield:
		_add("arm_off", sleeve)
		_add("hand_off", l["skin"])
	_add("torso_" + unit.body if unit.body != "none" else "torso_tunique", l["cloth"] if unit.body == "tunique" else Color.WHITE)
	if orc and unit.leader:
		_add("orc_mantle")
	match acc:
		"satchel":
			if w != "arc" and not unit.shield:
				_add("satchel", l["leather"])
		"bandolier":
			if w != "arc":
				_add("bandolier", l["leather"])
		"scarf":
			_add("scarf", l["cloth"].lightened(0.2))
	if orc:
		_add("head_orc", l["skin"])
		_add("face_orc_%d" % l["face"])
		if unit.head == "none" and l["hs"] >= 0:
			_add("hair_%d" % l["hs"], l["hair"])
		match unit.head:
			"none":
				if unit.leader:
					_add("orc_crown")
			"capuchon":
				_add("helm_capuchon", l["hood"])
			_:
				_add("helm_" + unit.head)
		_add_elite_head(tags)
		_finish_human(w, sleeve, l)
		return
	_add("head", l["skin"])
	if l["mark"] == "bruise":
		_add("mark_bruise")
	_add("face_%d" % l["face"])
	if l["mark"] != "" and l["mark"] != "bruise" and l["mark"] != "patch" and unit.head != "heaume":
		_add("mark_" + l["mark"])
	if l["mark"] == "patch" and unit.head != "heaume":
		_add("mark_patch")
	if unit.head != "heaume" and l["beard"] > 0:
		_add("beard_%d" % l["beard"], l["hair"])
	match unit.head:
		"none":
			_add("hair_%d" % l["hs"], l["hair"])
			if l["band"]:
				_add("band", l["cloth"].lightened(0.15))
		"capuchon":
			_add("helm_capuchon", l["hood"])
		_:
			_add("helm_" + unit.head)
	_add_elite_head(tags)
	_finish_human(w, sleeve, l)


## Arme, bras, épaulière, main et bouclier (communs aux humains et aux orcs).
func _finish_human(w: String, sleeve: Color, l: Dictionary) -> void:
	var pose: String = "gourdin" if w == "poings" else w  # à mains nues : bras et main du gourdin, sans arme
	if w != "poings":
		_add("weapon_" + w)
	_add("arm_" + pose, sleeve)
	if unit.body == "mailles" or unit.body == "brigandine":
		_add("pauldron_" + unit.body)
	if elite_tags(unit).has("pauldron"):
		_add("pauldron_elite")
	_add("hand_" + pose, l["skin"])
	if unit.shield:
		_add_shield()


## Ornements de tête des ennemis d'élite et des vétérans : plume sur casque, cercle d'or tête nue, peinture de guerre, collier d'os.
func _add_elite_head(tags: Array) -> void:
	if tags.has("plume"):
		var plume: Color = Banner.primary(company_banner()).lightened(0.1) if tags.has("vet") else ELITE_PLUME_FOE
		if unit.head != "none" and unit.head != "capuchon":
			_add("crest_plume", plume)
		elif tags.has("vet") and unit.faction != "o":
			_add("circlet")
	if tags.has("paint"):
		_add("war_paint")
	if tags.has("necklace"):
		_add("bone_necklace")


## Bouclier : celui de la compagnie aux couleurs de la bannière (champ, chevron, bossage) si elle est personnalisée.
func _add_shield() -> void:
	var up: String = "_up" if unit.shield_wall else ""
	if unit.side == "p" and Banner.is_custom(company_banner()):
		var b: Dictionary = company_banner()
		_add("shield_p" + up)
		_add("shield_field" + up, Banner.primary(b))
		_add("shield_chev" + up, Banner.secondary(b))
		_add("shield_boss" + up)
	else:
		_add("shield_%s%s" % [unit.side, up])


## Morts-vivants : zombie (griffes) ou squelette en calques.
func _build_undead(l: Dictionary) -> void:
	var w: String = unit.weapon
	if w == "griffes" or w == "griffesL":
		var zn: String = "zombie_big" if w == "griffesL" else "zombie"
		_add(zn + "_b" if l["ghoul_b"] else zn)
		return
	var bone: Color = l["bone"]
	var rust: Color = RUST
	if not unit.shield:
		_add("skel_arm_off", bone)
		_add("skel_hand_off", bone)
	_add("skel_torso", bone)
	_add("skel_rags", l["cloth"].darkened(0.25))
	_add("skel_skull_%d" % l["face"], bone)
	_add("skel_eyes")
	match unit.head:
		"capuchon":
			_add("helm_capuchon", l["hood"].darkened(0.3))
		"casque", "heaume":
			_add("helm_" + unit.head, rust)
	_add("weapon_" + w, rust)
	_add("skel_arm_" + w, bone)
	_add("skel_hand_" + w, bone)
	if unit.shield:
		_add("shield_e%s" % ("_up" if unit.shield_wall else ""), rust)


func _add(layer_name: String, tint: Color = Color.WHITE) -> void:
	var tex: Texture2D = texture(layer_name)
	if tex == null:
		tex = texture(Uniques.alias_layer(layer_name))  # objet unique : sprite de son modèle
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = ORIGIN
	s.scale = Vector2.ONE * PIXEL_SCALE
	s.modulate = tint
	add_child(s)
