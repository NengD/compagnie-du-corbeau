class_name Unit
extends Resource
## Un combattant : attributs, équipement, état de combat. Sérialisable en dictionnaire.

static var next_id: int = 1

@export var id: int = 0
@export var unit_name: String = ""
@export var background: String = ""  ## nom affiché de l'origine / du type d'ennemi
@export var side: String = "p"  ## "p" joueur, "e" ennemi
@export var faction: String = "p"  ## "p", "b" brigands, "g" goules
@export var leader: bool = false
@export var xp_value: int = 0  ## XP donnée à celui qui le tue

@export var hp_max: int = 50
@export var fat_max: int = 100
@export var resolve: int = 40
@export var initiative: int = 100
@export var melee_skill: int = 50
@export var ranged_skill: int = 30
@export var melee_def: int = 0
@export var ranged_def: int = 0

@export var weapon: String = "gourdin"
@export var shield: bool = false
@export var head: String = "none"
@export var body: String = "tunique"
@export var arm_h: int = 0
@export var arm_b: int = 0

@export var level: int = 1
@export var xp: int = 0
@export var kills: int = 0
@export var pending: int = 0  ## promotions en attente
@export var wage: int = 0
var weapon_dur: int = -1  ## usure : durabilité restante de l'arme (-1 = neuve), 0 = ébréchée
var shield_dur: int = -1  ## idem pour le bouclier (0 = brisé)
var bag: Array = [{}, {}]  ## sac : Data.BAG_SLOTS emplacements d'armes / boucliers de rechange ({} = vide, sinon un objet de Loot)
var perks: Array[String] = []  ## talents (clés de Data.PERKS)
var perk_points: int = 0  ## points de talent à dépenser (1 par niveau gagné, voir core/perks.gd)
var injuries: Array = []  ## [{"id": clé de Data.INJURIES, "days_left": jours restants, -1 = permanente}]
var traits: Array[String] = []  ## traits de caractère (clés de Data.TRAITS, voir core/traits.gd) : tirés à la génération, jamais gagnés
var hit_taken: bool = false  ## a encaissé un coup dans cette bataille (Brave, Rancunier)
var lucky_used: bool = false  ## Chanceux : la chance a déjà joué dans cette bataille

# --- État de combat ---
var hp: int = 50
var ap: int = 0
var fat: int = 0
var morale: int = 3
var dead: bool = false
var escaped: bool = false
var shield_wall: bool = false
var waited: bool = false
var turn_round: int = 0
var hex: Vector2i = Vector2i.ZERO
var attacked_turn: bool = false  ## a déjà attaqué ce tour (talent Frappe vive)
var ammo: int = -1  ## projectiles restants (arme à munitions, -1 = sans objet)
var stunned: bool = false  ## étourdi : perdra des PA au début de son prochain tour
var exposed: bool = false  ## désarçonné : défenses réduites jusqu'à la fin de son prochain tour


static func alloc_id() -> int:
	var i: int = next_id
	next_id += 1
	return i


func weight() -> int:
	var w: int = int(Data.HEAD[head]["w"]) + int(Data.BODY[body]["w"]) + (int(Data.SHIELD["w"]) if shield else 0)
	return w - Perks.weight_cut(self, w)


func has_perk(id: String) -> bool:
	return perks.has(id)


func has_injury(id: String) -> bool:
	for i in injuries:
		if str(i["id"]) == id:
			return true
	return false


## Attribut effectif : valeur de base + talents + blessures (la valeur de base n'est jamais modifiée).
func eff(k: String) -> int:
	var v: int = int(get(k))
	var light: bool = not perks.is_empty() and weight() <= Data.PERK_LIGHT_WEIGHT
	for p in perks:
		var pd: Dictionary = Data.PERKS.get(p, {})
		v += int(pd.get("stat", {}).get(k, 0))
		if shield_ok():
			v += int(pd.get("shield_stat", {}).get(k, 0))
		if light:
			v += int(pd.get("light_stat", {}).get(k, 0))
	for i in injuries:
		v += int(Data.INJURIES.get(str(i["id"]), {}).get("fx", {}).get(k, 0))
	for tr in traits:
		var td: Dictionary = Data.TRAITS.get(tr, {})
		v += int(td.get("stat", {}).get(k, 0))
		if hit_taken:
			v += int(td.get("hit_stat", {}).get(k, 0))
	if exposed and (k == "melee_def" or k == "ranged_def"):
		v -= Data.EXPOSE_DEF
	return v


func fat_max_eff() -> int:
	return eff("fat_max") - weight()


func ini_eff() -> int:
	return eff("initiative") - weight() - fat


func move_fat() -> int:
	return maxi(1, 2 + weight() / 10 - (1 if has_perk("pied_sur") else 0))


func weapon_data() -> Dictionary:
	return Data.WPN[weapon]


func weapon_range() -> int:
	var r: int = int(Data.WPN[weapon]["rng"])
	if uses_ammo() and ammo <= 0:
		return 1  ## plus de projectiles : on frappe au contact
	return r + 2 if has_perk("oeil_de_lynx") and is_ranged() else r


## PA que coûte l'attaque (Frappe vive : -1 sur la première du tour).
func attack_ap() -> int:
	var c: int = int(Data.WPN[weapon]["ap"])
	return maxi(1, c - 1) if has_perk("frappe_vive") and not attacked_turn else c


func attack_fat() -> int:
	return maxi(0, int(Data.WPN[weapon]["fat"]) - (3 if has_perk("endurant") else 0))


func is_ranged() -> bool:
	return bool(Data.WPN[weapon]["ranged"])


func uses_ammo() -> bool:
	return Data.WPN[weapon].has("ammo")


# --- Usure ---

func weapon_dur_max() -> int:
	return int(Data.WPN[weapon].get("dur", Data.WEAPON_DUR))


func shield_dur_max() -> int:
	return int(Data.SHIELD["dur"])


func weapon_wears() -> bool:
	return int(Data.WPN[weapon]["price"]) > 0


func weapon_dur_now() -> int:
	return weapon_dur_max() if weapon_dur < 0 else mini(weapon_dur, weapon_dur_max())


func shield_dur_now() -> int:
	return shield_dur_max() if shield_dur < 0 else mini(shield_dur, shield_dur_max())


func weapon_broken() -> bool:
	return weapon_wears() and weapon_dur_now() <= 0


## Bouclier porté et encore utilisable.
func shield_ok() -> bool:
	return shield and shield_dur_now() > 0


## Abîme l'arme de `n` points ; renvoie true si elle vient de s'ébrécher.
func wear_weapon(n: int) -> bool:
	if not weapon_wears() or n <= 0 or weapon_dur_now() <= 0:
		return false
	weapon_dur = maxi(0, weapon_dur_now() - n)
	return weapon_dur == 0


## Abîme le bouclier de `n` points ; renvoie true s'il vient de se briser.
func wear_shield(n: int) -> bool:
	if not shield or n <= 0 or shield_dur_now() <= 0:
		return false
	shield_dur = maxi(0, shield_dur_now() - n)
	return shield_dur == 0


func is_live() -> bool:
	return not dead and not escaped


func is_fighting() -> bool:
	return is_live() and morale > 0


func head_armor_max() -> int:
	return int(Data.HEAD[head]["a"])


func body_armor_max() -> int:
	return int(Data.BODY[body]["a"])


func reset_for_battle() -> void:
	hp = clampi(hp, 1, hp_max)
	ap = Data.AP_PER_TURN
	fat = 0
	morale = 3
	dead = false
	escaped = false
	shield_wall = false
	waited = false
	turn_round = 0
	attacked_turn = false
	ammo = full_ammo()
	stunned = false
	exposed = false
	hit_taken = false
	lucky_used = false


## Projectiles en début de bataille (-1 = arme sans munitions), talents compris.
func full_ammo() -> int:
	var base: int = int(Data.WPN[weapon].get("ammo", -1))
	return base + int(Perks.weapon_field(self, "ammo")) if base >= 0 else -1


## Copie profonde (utilisée pour envoyer la compagnie au combat sans toucher au camp).
func duplicate_unit() -> Unit:
	return Unit.from_dict(to_dict())


const _KEYS: Array[String] = [
	"id", "unit_name", "background", "side", "faction", "leader", "xp_value",
	"hp_max", "fat_max", "resolve", "initiative", "melee_skill", "ranged_skill", "melee_def", "ranged_def",
	"weapon", "shield", "head", "body", "arm_h", "arm_b", "weapon_dur", "shield_dur", "level", "xp", "kills", "pending", "wage", "hp",
]


func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for k in _KEYS:
		d[k] = get(k)
	d["perks"] = perks.duplicate()
	d["perk_points"] = perk_points
	d["injuries"] = injuries.duplicate(true)
	d["bag"] = bag.duplicate(true)
	d["traits"] = traits.duplicate()
	return d


static func from_dict(d: Dictionary) -> Unit:
	var u := Unit.new()
	for k in _KEYS:
		if not d.has(k):
			continue
		var v: Variant = d[k]
		match typeof(u.get(k)):  # le JSON rend tous les nombres en float
			TYPE_INT:
				v = int(v)
			TYPE_BOOL:
				v = bool(v)
			TYPE_STRING:
				v = str(v)
		u.set(k, v)
	u.perks.assign(d.get("perks", []))
	if d.has("perk_points"):
		u.perk_points = int(d["perk_points"])
	else:  # ancienne sauvegarde : un point par niveau gagné qui n'a pas de talent
		u.perk_points = maxi(0, Perks.points_for_level(u.level) - u.perks.size())
	u.bag = Unit.clean_bag(d.get("bag", []))
	if d.has("traits"):
		for k in d["traits"]:
			if Data.TRAITS.has(str(k)):
				u.traits.append(str(k))
	elif u.side == "p":
		Traits.migrate(u)  # ancienne sauvegarde : l'homme reçoit ses traits
	for i in d.get("injuries", []):
		u.injuries.append({"id": str(i["id"]), "days_left": int(i["days_left"])})
	return u


## Sac lu dans une sauvegarde : toujours Data.BAG_SLOTS entrées, objets valides (arme ou bouclier) ou {}.
static func clean_bag(raw: Variant) -> Array:
	var out: Array = []
	for i in Data.BAG_SLOTS:
		var it: Variant = raw[i] if typeof(raw) == TYPE_ARRAY and i < (raw as Array).size() else {}
		if typeof(it) == TYPE_DICTIONARY and Loot.is_valid(it) and (str(it["kind"]) == "weapon" or str(it["kind"]) == "shield"):
			out.append(Loot.clean(it))
		else:
			out.append({})
	return out


## État de combat (en plus des attributs) pour sauvegarder une bataille en cours.
func combat_dict() -> Dictionary:
	var d: Dictionary = to_dict()
	d.merge({
		"ap": ap, "fat": fat, "morale": morale, "dead": dead, "escaped": escaped, "shield_wall": shield_wall,
		"waited": waited, "turn_round": turn_round, "attacked_turn": attacked_turn, "ammo": ammo, "stunned": stunned, "exposed": exposed, "q": hex.x, "r": hex.y,
		"hit_taken": hit_taken, "lucky_used": lucky_used,
	})
	return d


static func from_combat_dict(d: Dictionary) -> Unit:
	var u: Unit = Unit.from_dict(d)
	u.ap = int(d.get("ap", 0))
	u.fat = int(d.get("fat", 0))
	u.morale = int(d.get("morale", 3))
	u.dead = bool(d.get("dead", false))
	u.escaped = bool(d.get("escaped", false))
	u.shield_wall = bool(d.get("shield_wall", false))
	u.waited = bool(d.get("waited", false))
	u.turn_round = int(d.get("turn_round", 0))
	u.attacked_turn = bool(d.get("attacked_turn", false))
	u.ammo = int(d.get("ammo", u.full_ammo()))
	u.stunned = bool(d.get("stunned", false))
	u.exposed = bool(d.get("exposed", false))
	u.hit_taken = bool(d.get("hit_taken", false))
	u.lucky_used = bool(d.get("lucky_used", false))
	u.hex = Vector2i(int(d.get("q", 0)), int(d.get("r", 0)))
	return u
