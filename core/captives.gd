class_name Captives
extends RefCounted
## Captifs après une bataille gagnée : les ennemis humains encore debout mais brisés ou en fuite.
## Pur : `collect` lit l'état du combat, `effects` calcule les conséquences d'un choix ; `Game.apply_captives` les applique.

const ELIGIBLE_FACTIONS: Array = ["b"]  ## brigands et autres humains ; ni bêtes, ni goules, ni morts-vivants, ni orcs
const MAX_MORALE: int = 1  ## brisé (1) ou en fuite (0)
const RANSOM_BASE: int = 12
const RANSOM_PER_LEVEL: int = 10
const RANSOM_LEADER_MULT: int = 3
const RANSOM_STANDING: int = -1  ## réputation perdue auprès de la faction pour une rançon extorquée
const FREE_STANDING: int = 2
const FREE_MORALE: float = 3.0
const FREE_RENOWN_NO_FACTION: int = 1  ## sans faction connue, un peu de renom à la place
const EXECUTE_MORALE: float = -8.0
const EXECUTE_STANDING: int = -3
const CHOICES: Array = ["ransom", "free", "execute"]


## Captifs possibles d'une bataille terminée : {} si aucun. Sinon {"men": [{name, level, leader}], "faction": clé ou "", "title"}.
static func collect(b: BattleState, win: bool) -> Dictionary:
	if not win or b == null:
		return {}
	var men: Array = []
	for x in b.units:
		var u: Unit = x
		if u.side == "p" or u.dead or u.escaped or u.hp <= 0 or u.is_cart():
			continue
		if not ELIGIBLE_FACTIONS.has(u.faction) or u.morale > MAX_MORALE:
			continue
		men.append({"name": u.unit_name, "level": maxi(1, u.level), "leader": u.leader})
	if men.is_empty():
		return {}
	var fk: String = str(b.contract.get("vs_faction", ""))
	if not Data.FACTIONS.has(fk):
		fk = ""
	return {"men": men, "faction": fk, "title": str(b.contract.get("title", ""))}


static func ransom_value(cap: Dictionary) -> int:
	var total: int = 0
	for m in cap.get("men", []):
		var v: int = RANSOM_BASE + RANSOM_PER_LEVEL * int(m.get("level", 1))
		if bool(m.get("leader", false)):
			v *= RANSOM_LEADER_MULT
		total += v
	return total


static func choice_label(choice: String) -> String:
	match choice:
		"ransom":
			return "Exiger une rançon"
		"free":
			return "Les libérer"
		_:
			return "Les exécuter"


## Conséquences d'un choix : {"gold": int, "morale": float, "renown": int, "standing": {clé: delta}, "line": String}.
static func effects(cap: Dictionary, choice: String) -> Dictionary:
	var n: int = cap.get("men", []).size()
	var fk: String = str(cap.get("faction", ""))
	var fname: String = Factions.name_of(fk) if fk != "" else ""
	var out: Dictionary = {"gold": 0, "morale": 0.0, "renown": 0, "standing": {}, "line": ""}
	if n == 0 or not CHOICES.has(choice):
		return out
	var who: String = "%d captif%s" % [n, "s" if n > 1 else ""]
	match choice:
		"ransom":
			out["gold"] = ransom_value(cap)
			if fk != "":
				out["standing"] = {fk: RANSOM_STANDING}
			out["line"] = "Rançon : %s rendu%s contre %d couronnes%s." % [who, "s" if n > 1 else "", int(out["gold"]), (" (%s : %d de réputation)" % [fname, RANSOM_STANDING]) if fk != "" else ""]
		"free":
			out["morale"] = FREE_MORALE
			if fk != "":
				out["standing"] = {fk: FREE_STANDING}
			else:
				out["renown"] = FREE_RENOWN_NO_FACTION
			out["line"] = "%s libéré%s : le moral de la compagnie remonte%s." % [who.capitalize(), "s" if n > 1 else "", (" et %s vous en sait gré (+%d)" % [fname, FREE_STANDING]) if fk != "" else " et votre renom grandit un peu"]
		_:
			out["morale"] = EXECUTE_MORALE
			if fk != "":
				out["standing"] = {fk: EXECUTE_STANDING}
			out["line"] = "%s exécuté%s : la compagnie en est ébranlée%s." % [who.capitalize(), "s" if n > 1 else "", (", %s vous hait (%d)" % [fname, EXECUTE_STANDING]) if fk != "" else ""]
	return out


## Phrase d'effet courte affichée sous chaque bouton.
static func effect_hint(cap: Dictionary, choice: String) -> String:
	var e: Dictionary = effects(cap, choice)
	var parts: Array[String] = []
	if int(e["gold"]) != 0:
		parts.append("%+d couronnes" % int(e["gold"]))
	if float(e["morale"]) != 0.0:
		parts.append("moral %+d" % int(e["morale"]))
	if int(e["renown"]) != 0:
		parts.append("renom %+d" % int(e["renown"]))
	for k in e["standing"]:
		parts.append("%s %+d" % [Factions.name_of(str(k)), int(e["standing"][k])])
	return " · ".join(parts)
