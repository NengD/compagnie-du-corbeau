class_name TurnUndo
extends RefCounted
## « Annuler le tour » (difficulté Facile uniquement). En début de tour du joueur on garde un instantané complet de la bataille ;
## le bouton le restaure, UNE SEULE FOIS PAR BATAILLE (choix documenté : une fois par manche rendrait l'essai-erreur gratuit).
## Le générateur aléatoire n'est PAS remis en arrière : la même graine continue d'avancer, les tirages refaits sont donc différents
## (on ne peut pas « rejouer » un coup raté pour exploiter la chance). Le mode fer l'interdit toujours.
## Aucune dépendance de scène : `BattleScreen` garde l'instantané et remplace l'état.

const EASY: String = "easy"


## Cette partie autorise-t-elle l'annulation ? (Facile, hors mode fer)
static func allowed(difficulty: String, extras: Dictionary) -> bool:
	return Difficulty.clean(difficulty) == EASY and not Ironman.is_on(extras)


## Instantané du début de tour de l'unité courante ({} si l'annulation est interdite ou si ce n'est pas un tour du joueur).
static func capture(s: BattleState, difficulty: String, extras: Dictionary) -> Dictionary:
	if not allowed(difficulty, extras) or s.over != "" or s.current == null or s.current.side != "p":
		return {}
	var d: Dictionary = s.to_dict()
	d["turn_snap_unit"] = s.current.id
	return d


## L'annulation est-elle possible maintenant ? Un seul usage par bataille, seulement pendant le tour capturé, et seulement si quelque chose a changé.
static func can_use(s: BattleState, snap: Dictionary, difficulty: String, extras: Dictionary) -> bool:
	if snap.is_empty() or not allowed(difficulty, extras) or s.over != "" or bool(s.extras.get("turn_undo_used", false)):
		return false
	if s.current == null or s.current.side != "p" or int(snap.get("turn_snap_unit", -1)) != s.current.id or int(snap.get("round", -1)) != s.round_no:
		return false
	return _changed(s, snap)


## Quelque chose a-t-il bougé depuis le début du tour ? (inutile d'offrir le bouton sinon)
static func _changed(s: BattleState, snap: Dictionary) -> bool:
	var before: Dictionary = {}
	for ud in snap["units"]:
		before[int(ud["id"])] = ud
	for u in s.units:
		var b: Variant = before.get(u.id, null)
		if b == null:
			return true
		var bd: Dictionary = b
		if int(bd.get("q", 0)) != u.hex.x or int(bd.get("r", 0)) != u.hex.y or int(bd.get("hp", 0)) != u.hp or bool(bd.get("dead", false)) != u.dead \
				or int(bd.get("ap", 0)) != u.ap or int(bd.get("arm_h", 0)) != u.arm_h or int(bd.get("arm_b", 0)) != u.arm_b:
			return true
	return false


## Nouvel état de bataille revenu au début du tour, avec le MÊME générateur aléatoire (sa graine a continué d'avancer).
## L'enregistrement de rediffusion et le drapeau « annulation utilisée » sont conservés. Renvoie null si l'annulation n'est pas permise.
static func restore(s: BattleState, snap: Dictionary, difficulty: String, extras: Dictionary) -> BattleState:
	if not can_use(s, snap, difficulty, extras):
		return null
	var ns: BattleState = BattleState.from_dict(snap, s.rng)
	var keep_rec: BattleLog = s.rec
	ns.extras = AiPlan.clean_extras(snap.get("extras", {}))
	if s.extras.has("ia"):
		ns.extras["ia"] = (s.extras["ia"] as Dictionary).duplicate(true)  # les ruses déjà décidées ne changent pas
	ns.extras["turn_undo_used"] = true
	ns.rec = keep_rec
	ns.say("Le tour est annulé.", "sys")
	return ns
