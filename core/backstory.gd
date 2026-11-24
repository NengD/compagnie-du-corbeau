class_name Backstory
extends RefCounted
## Passé et objectif personnel des hommes de la compagnie. Logique pure (aucun nœud, aucun autoload) :
## le tirage est stable (graine dérivée de l'id : il ne touche jamais à l'aléa de la partie) ; `Game` appelle `progress`
## aux bons moments et reporte les objectifs atteints dans les nouvelles, le résumé de bataille et le journal.
##
## Objectif (Unit.goal) : {"kind", "target", "prog", "done", "rw": {"type": "stat"|"perk"|"trait"|"hp", ...}}.

const KINDS: Array[String] = ["kills", "wins", "level", "gold", "days"]

## Courtes histoires par origine (clé de Data.BG). Texte original.
const STORIES: Dictionary = {
	"milicien": [
		"A tenu la palissade de son village trois étés de suite, jusqu'au jour où le seigneur a repris ses lances sans payer la dernière solde.",
		"Garde de porte à Vaubrun, il a vu les murs tomber sans rien pouvoir y faire. Il jure de ne plus jamais défendre un tas de pierres pour rien.",
		"Ancien sergent d'une levée oubliée, il sait tenir une ligne et compter les hommes qui n'y reviennent pas.",
	],
	"bucheron": [
		"Il abattait des chênes pour un charpentier de la vallée, avant qu'une dette ne lui fasse échanger la cognée pour une paye de soldat.",
		"Ses bras ont la largeur de deux fagots. Un incendie a emporté sa scierie ; la hache, elle, lui est restée.",
		"Fils de bûcheron, petit-fils de bûcheron, il n'a jamais su pourquoi on tuait les gens. Mais il sait que ça fait du bois à payer.",
	],
	"braconnier": [
		"Pris trois fois à tirer sur le gibier du seigneur, il a préféré quitter la région avant la quatrième.",
		"Il connaît la forêt mieux que les gardes qui le cherchaient. Il tire vite, parle peu et ne rate pas deux fois.",
		"Il nourrissait sa famille de lièvres volés. Famille partie, il ne reste que l'arc et l'habitude du silence.",
	],
	"fermier": [
		"Une mauvaise récolte, puis une pire, puis le percepteur. La terre est vendue, et le fermier s'est mis à la solde.",
		"Il a passé sa vie derrière une charrue et rêve d'un lopin à lui. Chaque couronne gagnée est comptée deux fois.",
		"Cadet d'une ferme trop petite pour trois frères, il est parti sans se retourner, la fourche encore à la main.",
	],
	"mendiant": [
		"Il a dormi sous tous les ponts de la région et connaît le goût du pain moisi. Une place à une table lui paraît déjà un luxe.",
		"Autrefois colporteur, ruiné par des voleurs de grand chemin, il a gardé la rancune et perdu le reste.",
		"Personne ne se souvient de son village, lui non plus. Il demande seulement qu'on ne le renvoie pas dans la rue.",
	],
	"deserteur": [
		"Il a quitté les rangs d'une armée avant la bataille, et les rangs ne l'ont pas oublié. Il vend maintenant son épée sous un autre nom.",
		"Il parle peu de la guerre d'où il vient. Il laisse seulement dire qu'il a vu un général s'enfuir avant ses hommes.",
		"Déserteur par prudence plus que par lâcheté, il sait reconnaître le moment où un combat est perdu, et s'en vante rarement.",
	],
	"reitre": [
		"Mercenaire de métier, il a servi quatre bannières en six ans, et n'en regrette aucune. La solde, d'abord.",
		"Ancien cavalier d'une compagnie dissoute, il a gardé la cotte de mailles, un orgueil intact et des dettes de jeu.",
		"Il a vu plus de champs de bataille que de villes. Il accepte d'être sous vos ordres tant que vous gagnez.",
	],
}

## Histoire de secours (origine inconnue : recrues uniques, anciens noms).
const STORY_FALLBACK: Array[String] = [
	"Il n'a pas dit grand-chose de son passé, et personne ne lui a posé la question deux fois.",
	"Un homme comme un autre, venu chercher une solde et une raison de se lever le matin.",
]

## Objectifs favoris par origine (tirage pondéré par la répétition).
const PREFS: Dictionary = {
	"milicien": ["wins", "wins", "level", "days"],
	"bucheron": ["kills", "kills", "days", "level"],
	"braconnier": ["kills", "kills", "gold", "level"],
	"fermier": ["days", "days", "gold", "level"],
	"mendiant": ["days", "gold", "gold", "wins"],
	"deserteur": ["wins", "gold", "kills", "days"],
	"reitre": ["kills", "gold", "gold", "wins"],
}

const STAT_LABELS: Dictionary = {
	"melee_skill": "maîtrise de mêlée", "ranged_skill": "tir", "resolve": "détermination", "melee_def": "défense", "hp_max": "PV maximum",
}


## Clé de Data.BG correspondant au nom d'origine affiché de `u` ("" si inconnue).
static func origin_key(u: Unit) -> String:
	for k in Data.BG:
		if str(Data.BG[k]["n"]) == u.background:
			return str(k)
	return ""


static func _rng(u: Unit) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = u.id * 6131 + 70001
	return r


## Tire l'histoire et l'objectif de `u` (stable pour un id donné). Écrase les champs existants.
static func assign(u: Unit) -> void:
	var r: RandomNumberGenerator = _rng(u)
	var key: String = origin_key(u)
	var pool: Array = Mods.backstory_pool(key, STORIES.get(key, STORY_FALLBACK))
	u.backstory = str(pool[r.randi() % pool.size()])
	var prefs: Array = PREFS.get(key, KINDS)
	var kind: String = str(prefs[r.randi() % prefs.size()])
	if kind == "level" and u.level >= 9:
		kind = "kills"
	u.goal = make_goal(u, kind, r)


## Tire l'histoire d'un homme du camp qui n'en a pas (ancienne sauvegarde, recrue unique). Renvoie true si elle vient d'être tirée.
static func ensure(u: Unit) -> bool:
	if u == null or u.side != "p" or (u.backstory != "" and not u.goal.is_empty()):
		return false
	assign(u)
	return true


## Objectif de genre `kind` pour `u` (cibles dans des plages modestes, récompense adaptée).
static func make_goal(u: Unit, kind: String, r: RandomNumberGenerator) -> Dictionary:
	var target: int = 0
	var rw: Dictionary = {}
	match kind:
		"kills":
			target = [8, 12, 15, 20][r.randi() % 4]
			var key: String = "ranged_skill" if bool(Data.WPN.get(u.weapon, {}).get("ranged", false)) else "melee_skill"
			rw = {"type": "stat", "key": key, "amt": 3}
		"wins":
			target = [3, 4, 6, 8][r.randi() % 4]
			rw = {"type": "stat", "key": "resolve", "amt": 4}
		"level":
			target = clampi(u.level + 2, 3, 11)
			rw = {"type": "perk", "amt": 1}
		"gold":
			target = [300, 450, 600, 900][r.randi() % 4]
			rw = {"type": "trait", "key": _pick_trait(u, r)}
		_:
			kind = "days"
			target = [20, 30, 45, 60][r.randi() % 4]
			rw = {"type": "hp", "key": "hp_max", "amt": 5}
	return {"kind": kind, "target": target, "prog": 0, "done": false, "rw": rw}


## Un trait positif sans effet « de génération » (PV, solde) qui ne contredit aucun des traits de `u` ; "" s'il n'y en a plus.
static func _pick_trait(u: Unit, r: RandomNumberGenerator) -> String:
	var ok: Array = []
	for k in Data.TRAITS:
		if _eligible_trait(u, str(k)):
			ok.append(k)
	ok.sort()
	return str(ok[r.randi() % ok.size()]) if not ok.is_empty() else ""


static func _eligible_trait(u: Unit, k: String) -> bool:
	var d: Dictionary = Data.TRAITS.get(k, {})
	if d.is_empty() or str(d.get("tone", "")) != "good" or d.has("hp") or d.has("wage") or u.traits.has(k):
		return false
	var fam: String = str(d.get("ex", ""))
	for h in u.traits:
		if fam != "" and str(Data.TRAITS.get(str(h), {}).get("ex", "")) == fam:
			return false
	return true


## Libellé de l'objectif ("Abattre 12 ennemis").
static func goal_text(g: Dictionary) -> String:
	if g.is_empty():
		return ""
	var n: int = int(g.get("target", 0))
	match str(g.get("kind", "")):
		"kills":
			return "Abattre %d ennemis" % n
		"wins":
			return "Remporter %d bataille%s" % [n, "s" if n > 1 else ""]
		"level":
			return "Atteindre le niveau %d" % n
		"gold":
			return "Toucher %d couronnes de primes" % n
		"days":
			return "Tenir %d jours dans la compagnie" % n
	return ""


## Libellé de la récompense ("+3 en maîtrise de mêlée").
static func reward_text(g: Dictionary) -> String:
	var rw: Dictionary = g.get("rw", {})
	match str(rw.get("type", "")):
		"stat", "hp":
			return "+%d %s" % [int(rw.get("amt", 0)), STAT_LABELS.get(str(rw.get("key", "")), str(rw.get("key", "")))]
		"perk":
			return "un point de talent"
		"trait":
			var t: String = str(rw.get("key", ""))
			return "le trait « %s »" % str(Data.TRAITS[t]["n"]) if Data.TRAITS.has(t) else "un point de talent"
	return ""


## Progression ("7 / 12", ou "Accompli").
static func progress_text(g: Dictionary) -> String:
	if g.is_empty():
		return ""
	if bool(g.get("done", false)):
		return "Accompli"
	return "%d / %d" % [mini(int(g.get("prog", 0)), int(g.get("target", 0))), int(g.get("target", 0))]


## Une ligne pour la fiche : « Objectif : Abattre 12 ennemis (7 / 12) · récompense : +3 … ».
static func summary(u: Unit) -> String:
	if u.goal.is_empty():
		return ""
	return "Objectif : %s (%s) · récompense : %s" % [goal_text(u.goal), progress_text(u.goal), reward_text(u.goal)]


## Fait avancer l'objectif de `u` si son genre est `kind`. `absolute` : `n` remplace la progression (niveau) au lieu de s'y ajouter.
## Renvoie un compte rendu {"u", "text", "reward"} si l'objectif vient d'être atteint, sinon {}.
static func progress_one(u: Unit, kind: String, n: int, absolute: bool = false) -> Dictionary:
	if u == null or u.side != "p" or n <= 0:
		return {}
	ensure(u)
	var g: Dictionary = u.goal
	if bool(g.get("done", false)) or str(g.get("kind", "")) != kind:
		return {}
	g["prog"] = maxi(int(g.get("prog", 0)), n) if absolute else int(g.get("prog", 0)) + n
	if int(g["prog"]) < int(g["target"]):
		return {}
	g["prog"] = int(g["target"])
	g["done"] = true
	var rtext: String = reward_text(g)
	apply_reward(u)
	return {"u": u, "text": "%s a tenu son pari : « %s ». Récompense : %s." % [u.unit_name, goal_text(g).to_lower(), rtext], "reward": rtext}


## Applique la récompense (une seule fois : l'appelant vient de marquer l'objectif « done »).
static func apply_reward(u: Unit) -> void:
	var rw: Dictionary = u.goal.get("rw", {})
	match str(rw.get("type", "")):
		"stat":
			var k: String = str(rw["key"])
			u.set(k, int(u.get(k)) + int(rw.get("amt", 0)))
		"hp":
			u.hp_max += int(rw.get("amt", 0))
			u.hp += int(rw.get("amt", 0))
		"trait":
			var t: String = str(rw.get("key", ""))
			if _eligible_trait(u, t):
				u.traits.append(t)
			else:  # le trait est devenu impossible (conflit, déjà acquis) : un point de talent à la place
				u.goal["rw"] = {"type": "perk", "amt": 1}
				u.perk_points += 1
		_:
			u.perk_points += maxi(1, int(rw.get("amt", 1)))


## `progress_one` pour plusieurs hommes ; renvoie la liste des comptes rendus des objectifs atteints.
static func progress(men: Array, kind: String, n: int, absolute: bool = false) -> Array:
	var out: Array = []
	for m in men:
		var res: Dictionary = progress_one(m as Unit, kind, n, absolute)
		if not res.is_empty():
			out.append(res)
	return out
