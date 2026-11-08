class_name ImpactFeel
extends RefCounted
## Intensité du ressenti d'un coup (tremblement du plateau + arrêt sur image), en trois paliers proportionnés à l'importance du coup.
## Logique pure : `scenes/battle/battle.gd` applique ces valeurs via `BattleFx.add_trauma` et `BattleFx.hit_stop`.

const TIERS: Dictionary = {
	"none": {"trauma": 0.0, "stop": 0.0},
	"small": {"trauma": 0.12, "stop": 0.0},    ## l'armure encaisse tout
	"medium": {"trauma": 0.3, "stop": 0.045},  ## coup sérieux aux PV
	"large": {"trauma": 0.5, "stop": 0.085},   ## coup à la tête
	"kill": {"trauma": 0.7, "stop": 0.12},     ## coup fatal
}
## Un coup qui retire au moins cette part des PV maximum de la cible compte comme « sérieux ».
const HEAVY_HP_FRACTION: float = 0.2


## Résultat d'une attaque (clés `hit`, `armor`, `hp`, `head` de BattleState.attack) -> {"name", "trauma", "stop"}.
static func tier(res: Dictionary, target_hp_max: float, target_dead: bool) -> Dictionary:
	var name: String = "none"
	if bool(res.get("hit", false)):
		var hp: int = int(res.get("hp", 0))
		if target_dead:
			name = "kill"
		elif bool(res.get("head", false)) and hp > 0:
			name = "large"
		elif hp > 0 and float(hp) >= target_hp_max * HEAVY_HP_FRACTION:
			name = "medium"
		elif hp > 0 or int(res.get("armor", 0)) > 0:
			name = "small"
	var t: Dictionary = (TIERS[name] as Dictionary).duplicate()
	t["name"] = name
	return t
