class_name RoadEncounters
extends RefCounted
## Rencontres de route à choix : barrages, embuscades, blessés suspects, marchands louches…
## Un choix peut porter un test (`check`) : négocier (détermination du meilleur homme, réputation locale, traits),
## soudoyer (réussite presque sûre), fuir (initiative moyenne), tendre un piège (exige un chasseur).
## Les issues sont alors dans `win` / `lose` (listes d'issues pondérées comme `Events`), au lieu de `outcomes`.
## Les rencontres se résolvent via `Events.resolve` / `Game.resolve_event` ; ici : données, probabilités, disponibilité.
## Logique pure : l'aléa est injecté par l'appelant.
##
## Contexte `ctx` : {"roster": Array[Unit], "standing": réputation du lieu proche (−10..10), "faction": estime de sa faction}.
## Effet spécial : `"standing": {"local": n}` vise la faction du lieu proche (voir `Game.resolve_event`).

const CHANCE_MIN: int = 5  ## bornes de la chance affichée (en %)
const CHANCE_MAX: int = 95
const CHANCE_STEP: int = 5  ## la chance est affichée arrondie à 5 % (« environ 65 % »)

const NEGOTIATE_RESOLVE_REF: int = 50  ## détermination de référence
const NEGOTIATE_RESOLVE_K: float = 0.5
const NEGOTIATE_STANDING_K: float = 2.0
const NEGOTIATE_FACTION_K: float = 1.0
const NEGOTIATE_TRAIT_BONUS: Dictionary = {"sociable": 4, "brave": 3, "peureux": -3}
const BRIBE_STANDING_K: float = 0.5
const FLEE_INI_REF: int = 85  ## initiative moyenne de référence (moins le poids de l'équipement)
const FLEE_INI_K: float = 0.6
const TRAP_HUNTER_BONUS: int = 12
const TRAP_HUNTERS_MAX: int = 2
const TRAP_SKILL_REF: int = 55
const TRAP_SKILL_K: float = 0.3
const HUNTER_PERKS: Array = ["oeil_sur"]
const HUNTER_BACKGROUND: String = "braconnier"  ## clé de Data.BG

const KINDS: Array = ["negotiate", "bribe", "flee", "trap"]

const DEFS: Array = [
	{
		"id": "r_barrage", "title": "Barrage de rondins",
		"text": "Un amas de rondins coupe la route entre deux talus. Quatre hommes en cotte rapiécée, une bannière de seigneurie fanée, une marmite sur le feu : ce genre de barrage rapporte plus que la guerre.",
		"choices": [
			{"id": "talk", "label": "Négocier le passage avec leur sergent", "check": {"kind": "negotiate", "base": 50},
				"win": [{"w": 1, "text": "Le sergent se gratte la barbe, vous offre une gamelle et un laissez-passer griffonné. On repart le ventre plein.", "food": 6, "standing": {"local": 1}}],
				"lose": [{"w": 2, "text": "Le sergent flaire la faiblesse et double le tarif en riant.", "gold": -35},
					{"w": 1, "text": "La discussion s'envenime : les lames sortent à moitié, puis tout à fait.", "battle": {"type": "b", "d": 1}}]},
			{"id": "bribe", "label": "Glisser une bourse au sergent", "cost": 45, "check": {"kind": "bribe", "base": 90},
				"win": [{"w": 1, "text": "La bourse disparaît dans une manche. Les rondins roulent comme par enchantement."}],
				"lose": [{"w": 1, "text": "Il empoche l'argent… et siffle quand même ses hommes !", "battle": {"type": "b", "d": 1}}]},
			{"id": "flee", "label": "Rebrousser chemin et filer par les chaumes (1 jour)", "check": {"kind": "flee", "base": 55},
				"win": [{"w": 1, "text": "Un détour par les champs moissonnés, sans un cri derrière vous.", "days": 1}],
				"lose": [{"w": 1, "text": "Un archer vous a vus. Les traits sifflent avant que la compagnie ne soit hors de portée.", "hp_one": -8, "battle": {"type": "b", "d": 1}}]},
		],
	},
	{
		"id": "r_fosse", "title": "Silence suspect dans le chemin creux",
		"text": "Les oiseaux se sont tus. Entre deux ronces, un reflet d'acier : des brigands vous attendent en contrebas du talus, persuadés que vous n'avez rien vu.",
		"choices": [
			{"id": "flee", "label": "Se replier pas à pas, sans bruit (1 jour)", "check": {"kind": "flee", "base": 50},
				"win": [{"w": 1, "text": "Vous reculez sans qu'un seul brigand ne bouge. Un jour perdu, mais la peau sauve.", "days": 1}],
				"lose": [{"w": 1, "text": "Un cri : on vous a vus ! La charge arrive.", "battle": {"type": "b", "d": 1}}]},
			{"id": "talk", "label": "Les héler et marchander un tribut", "check": {"kind": "negotiate", "base": 30},
				"win": [{"w": 1, "text": "Leur chef rit, accepte un tribut modeste et vous laisse passer : « Les affaires, c'est les affaires. »", "gold": -30}],
				"lose": [{"w": 1, "text": "Le chef crache dans la poussière et siffle l'attaque.", "battle": {"type": "b", "d": 1}}]},
			{"id": "bribe", "label": "Leur faire porter une bourse par un éclaireur", "cost": 70, "check": {"kind": "bribe", "base": 88},
				"win": [{"w": 1, "text": "L'éclaireur revient sans dommage ; les brigands disparaissent dans les ronces."}],
				"lose": [{"w": 1, "text": "L'éclaireur ne revient pas. L'embuscade, elle, se déclenche.", "battle": {"type": "b", "d": 1}}]},
			{"id": "trap", "label": "Leur tendre une contre-embuscade", "requires": "hunter", "check": {"kind": "trap", "base": 45},
				"win": [{"w": 1, "text": "Vos tireurs rampent derrière les ronces : les brigands tombent dans leur propre piège et laissent bourses et vivres.", "gold": 95, "food": 8, "renown": 6, "xp_all": 3}],
				"lose": [{"w": 1, "text": "Une branche craque. Les brigands, avertis, chargent !", "battle": {"type": "b", "d": 1}}]},

		],
	},
	{
		"id": "r_gue_garde", "title": "Gué surveillé",
		"text": "Une milice de village garde le seul gué praticable et réclame un « droit de passage » par homme, par cheval et par chien. Le bailli tient un registre. Il aime visiblement ça.",
		"choices": [
			{"id": "talk", "label": "Plaider la cause de la compagnie auprès du bailli", "check": {"kind": "negotiate", "base": 55},
				"win": [{"w": 1, "text": "Le bailli reconnaît le nom de la compagnie et vous laisse passer pour une bouchée de pain.", "gold": -10, "renown": 3}],
				"lose": [{"w": 1, "text": "On vous fait payer le plein tarif, plus l'affront.", "gold": -50}]},
			{"id": "bribe", "label": "Arrondir le droit de passage en douce", "cost": 30, "check": {"kind": "bribe", "base": 90},
				"win": [{"w": 1, "text": "Le registre s'oublie opportunément. Le bailli vous souhaite bonne route."}],
				"lose": [{"w": 1, "text": "Il encaisse, puis réclame aussi le tarif officiel.", "gold": -20}]},
			{"id": "flee", "label": "Chercher un autre passage en amont (1 jour)", "check": {"kind": "flee", "base": 60},
				"win": [{"w": 1, "text": "Un bras mort, de l'eau à mi-cuisse, et personne pour compter les pièces.", "days": 1}],
				"lose": [{"w": 1, "text": "Le courant emporte un homme sur quelques mètres avant qu'on le repêche.", "days": 1, "hp_one": -12}]},
		],
	},
	{
		"id": "r_blesse", "title": "Voyageur blessé",
		"text": "Un homme est adossé à une borne, une flèche dans la cuisse, une sacoche serrée contre lui. Il vous supplie du regard. Ses bottes sont pourtant bien trop propres pour un pauvre diable.",
		"choices": [
			{"id": "help", "label": "Le soigner sans poser de questions (1 jour)",
				"outcomes": [{"w": 3, "text": "C'était un marchand dévalisé. Sa famille vous récompense largement.", "days": 1, "gold": 80, "renown": 6},
					{"w": 1, "text": "La flèche venait de ses « amis », qui reviennent finir le travail.", "days": 1, "battle": {"type": "b", "d": 1}}]},
			{"id": "probe", "label": "L'interroger fermement", "check": {"kind": "negotiate", "base": 45},
				"win": [{"w": 1, "text": "Sous votre regard, il avoue : il sert d'appât à une bande. Il vous mène à leur cache, vide pour l'heure.", "gold": 70, "standing": {"local": 1}}],
				"lose": [{"w": 1, "text": "Il se tait, puis hurle. Les rabatteurs jaillissent des fourrés.", "battle": {"type": "b", "d": 1}}]},
			{"id": "pass", "label": "Passer son chemin", "outcomes": [{"w": 1, "text": "Vous ne vous retournez pas. Le blessé, lui, ne crie même pas."}]},
			{"id": "trap", "label": "Feindre de partir et guetter de loin", "requires": "hunter", "check": {"kind": "trap", "base": 50},
				"win": [{"w": 1, "text": "Vous cueillez la bande au moment où elle sort de son trou : butin sans combat.", "gold": 100, "renown": 5}],
				"lose": [{"w": 1, "text": "Vos guetteurs sont repérés ; la bande vous encercle.", "hp_one": -6, "battle": {"type": "b", "d": 1}}]},

		],
	},
	{
		"id": "r_marchand_louche", "title": "Marchand aux balances truquées",
		"text": "Un marchand au sourire large vante son sel, son lard et ses « reliques de saints ». Ses balances penchent d'un côté qui ne doit rien au hasard.",
		"choices": [
			{"id": "buy", "label": "Acheter ses vivres sans discuter (35 couronnes)", "cost": 35,
				"outcomes": [{"w": 3, "text": "Le lard est correct, le sel un peu mouillé.", "food": 8},
					{"w": 1, "text": "Le lard est gâté sous une belle couenne. Quelques ventres s'en souviendront.", "food": 2, "hp_all": -3}]},
			{"id": "talk", "label": "Contester ses balances devant tout le monde", "check": {"kind": "negotiate", "base": 45},
				"win": [{"w": 1, "text": "Pris la main dans le sac, le marchand rend gorge et vous offre ses meilleures rations.", "food": 14, "gold": 25, "renown": 3}],
				"lose": [{"w": 1, "text": "Il crie au voleur. La foule du carrefour vous toise, et ça ne se rattrape pas.", "renown": -4}]},
			{"id": "pass", "label": "Passer", "outcomes": [{"w": 1, "text": "Le marchand cherche une autre dupe, sans rancune."}]},
		],
	},
	{
		"id": "r_loups_pieges", "title": "Piste de loups",
		"text": "Des empreintes fraîches, plus larges qu'une main, et une carcasse de mouton accrochée aux ronces. La meute n'est pas loin, et la nuit tombe.",
		"choices": [
			{"id": "flee", "label": "Presser le pas pour atteindre un abri", "check": {"kind": "flee", "base": 55},
				"win": [{"w": 1, "text": "Vous gagnez une grange avant la tombée de la nuit. Les hurlements restent dehors.", "hp_all": -2}],
				"lose": [{"w": 1, "text": "La meute vous rattrape au crépuscule.", "battle": {"type": "m", "d": 1}}]},
			{"id": "fire", "label": "Veiller autour de grands feux",
				"outcomes": [{"w": 3, "text": "Une nuit blanche, mais les loups tournent sans oser approcher.", "hp_all": -3},
					{"w": 1, "text": "Un loup plus hardi mord un homme au mollet avant de fuir.", "hp_one": -10}]},
			{"id": "trap", "label": "Poser collets et fosses avant la nuit (1 jour)", "requires": "hunter", "check": {"kind": "trap", "base": 50},
				"win": [{"w": 1, "text": "Au matin, deux loups pendent aux collets. Les peaux se vendront bien.", "days": 1, "gold": 70, "food": 6}],
				"lose": [{"w": 1, "text": "Les loups contournent les pièges et attaquent le campement.", "days": 1, "battle": {"type": "m", "d": 1}}]},

		],
	},
	{
		"id": "r_patrouille", "title": "Patrouille de recrutement",
		"text": "Une patrouille en tabards écarlates vous barre la route et cherche des bras pour « la guerre du comte ». Leur officier lorgne vos épées avec un appétit non dissimulé.",
		"choices": [
			{"id": "talk", "label": "Plaider : des mercenaires sous contrat sont exemptés", "check": {"kind": "negotiate", "base": 45},
				"win": [{"w": 1, "text": "L'officier consulte un registre, trouve la clause, et vous salue même.", "renown": 3, "standing": {"local": 2}}],
				"lose": [{"w": 1, "text": "Pour « l'effort de guerre », il confisque une partie de vos rations.", "food": -6, "standing": {"local": -1}}]},
			{"id": "bribe", "label": "Offrir une bourse à l'officier", "cost": 55, "check": {"kind": "bribe", "base": 88},
				"win": [{"w": 1, "text": "L'officier fait semblant de ne pas vous avoir vus. L'honneur est sauf, sa bourse aussi.", "standing": {"local": -1}}],
				"lose": [{"w": 1, "text": "Un sergent honnête dénonce la corruption : la patrouille se retourne contre vous.", "standing": {"local": -2}, "battle": {"type": "b", "d": 1}}]},
			{"id": "flee", "label": "Quitter la route et se fondre dans les bois", "check": {"kind": "flee", "base": 45},
				"win": [{"w": 1, "text": "Les tabards écarlates se perdent dans le sous-bois, et vous dans l'autre sens.", "days": 1}],
				"lose": [{"w": 1, "text": "On vous traite de déserteurs et l'on vous poursuit.", "standing": {"local": -2}, "battle": {"type": "b", "d": 1}}]},
		],
	},
	{
		"id": "r_eclaireurs_orcs", "title": "Éclaireurs sur l'éperon",
		"text": "Un cri guttural dans les rochers. Deux éclaireurs à la peau verte de mousse vous observent depuis un éperon. Derrière eux monte la fumée d'un camp de guerre.",
		"choices": [
			{"id": "talk", "label": "Offrir de la viande séchée et parlementer", "check": {"kind": "negotiate", "base": 25},
				"win": [{"w": 1, "text": "L'un d'eux flaire l'offrande, grogne, et vous laisse passer sans un bruit.", "food": -5, "renown": 4}],
				"lose": [{"w": 1, "text": "Vos mots s'émoussent contre leurs crocs : la bande charge.", "battle": {"type": "o", "d": 1}}]},
			{"id": "flee", "label": "Faire demi-tour et contourner l'éperon (1 jour)", "check": {"kind": "flee", "base": 45},
				"win": [{"w": 1, "text": "Un long détour dans l'éboulis, sans croiser un regard jaune.", "days": 1}],
				"lose": [{"w": 1, "text": "Un cri rauque répond au premier : la bande vous prend en chasse.", "battle": {"type": "o", "d": 1}}]},
			{"id": "trap", "label": "Tendre un fil de pierres et un seau de gravier", "requires": "hunter", "check": {"kind": "trap", "base": 40},
				"win": [{"w": 1, "text": "Un éclaireur trébuche, l'autre fuit en hurlant. Vous prenez leurs armes et leur bourse.", "gold": 85, "renown": 8}],
				"lose": [{"w": 1, "text": "Ils flairent le piège et le retournent contre vous.", "hp_one": -14, "battle": {"type": "o", "d": 1}}]},

		],
	},
]


static func get_def(id: String) -> Dictionary:
	for e in DEFS:
		if e["id"] == id:
			return e
	return {}


# --- Contexte ---

static func context(roster: Array, standing: int = 0, faction: int = 0) -> Dictionary:
	return {"roster": roster, "standing": standing, "faction": faction}


static func _roster(ctx: Dictionary) -> Array:
	return ctx.get("roster", [])


# --- Hommes concernés ---

static func is_hunter(u: Unit) -> bool:
	if u.background == str(Data.BG.get(HUNTER_BACKGROUND, {}).get("n", "")):
		return true
	for p in HUNTER_PERKS:
		if u.perks.has(p):
			return true
	return false


static func hunters(roster: Array) -> Array:
	return roster.filter(func(u: Unit) -> bool: return is_hunter(u))


## Meilleure détermination effective de la compagnie (0 si vide).
static func best_resolve(roster: Array) -> int:
	var best: int = 0
	for u in roster:
		best = maxi(best, (u as Unit).eff("resolve"))
	return best


## Initiative moyenne effective moins le poids de l'équipement.
static func mean_initiative(roster: Array) -> float:
	if roster.is_empty():
		return float(FLEE_INI_REF)
	var s: float = 0.0
	for u in roster:
		s += float((u as Unit).eff("initiative") - (u as Unit).weight())
	return s / float(roster.size())


# --- Probabilités ---

## Chance brute (en %, avant bornes) du test `check` dans le contexte `ctx`.
static func raw_chance(check: Dictionary, ctx: Dictionary) -> float:
	var roster: Array = _roster(ctx)
	var v: float = float(check.get("base", 50))
	match str(check.get("kind", "")):
		"negotiate":
			v += NEGOTIATE_RESOLVE_K * float(best_resolve(roster) - NEGOTIATE_RESOLVE_REF) if not roster.is_empty() else 0.0
			v += NEGOTIATE_STANDING_K * float(ctx.get("standing", 0)) + NEGOTIATE_FACTION_K * float(ctx.get("faction", 0))
			var tb: float = 0.0
			for tid in NEGOTIATE_TRAIT_BONUS:
				for u in roster:
					if Traits.has(u as Unit, str(tid)):
						tb += float(NEGOTIATE_TRAIT_BONUS[tid])
						break  ## un même trait ne compte qu'une fois
			v += clampf(tb, -6.0, 8.0)
		"bribe":
			v += BRIBE_STANDING_K * float(ctx.get("standing", 0))
		"flee":
			v += FLEE_INI_K * (mean_initiative(roster) - float(FLEE_INI_REF))
		"trap":
			var hs: Array = hunters(roster)
			v += float(mini(hs.size(), TRAP_HUNTERS_MAX) * TRAP_HUNTER_BONUS)
			var best: int = 0
			for u in hs:
				best = maxi(best, (u as Unit).eff("ranged_skill"))
			if not hs.is_empty():
				v += TRAP_SKILL_K * float(best - TRAP_SKILL_REF)
	return v


## Chance de réussite (entier, borné à CHANCE_MIN..CHANCE_MAX) : celle réellement utilisée au tirage.
static func chance(check: Dictionary, ctx: Dictionary) -> int:
	return clampi(int(round(raw_chance(check, ctx))), CHANCE_MIN, CHANCE_MAX)


## Chance affichée : arrondie à 5 %, toujours dans les bornes.
static func shown_chance(check: Dictionary, ctx: Dictionary) -> int:
	var c: int = chance(check, ctx)
	return clampi(int(round(float(c) / float(CHANCE_STEP))) * CHANCE_STEP, CHANCE_MIN, CHANCE_MAX)


# --- Disponibilité et affichage ---

## "" si le choix est possible, sinon la raison (en français).
static func locked_reason(choice: Dictionary, ctx: Dictionary) -> String:
	if str(choice.get("requires", "")) == "hunter" and hunters(_roster(ctx)).is_empty():
		return "Il faut un chasseur ou un braconnier dans la compagnie (ou un tireur à l'Œil sûr)."
	return ""


## Texte d'un bouton : libellé + coût + chance estimée. {"label", "chance" (−1 sans test), "locked" (raison ou "")}.
static func describe(choice: Dictionary, ctx: Dictionary) -> Dictionary:
	var label: String = str(choice["label"])
	var cost: int = int(choice.get("cost", 0))
	var chance_shown: int = -1
	if choice.has("check"):
		if cost > 0 and not label.contains("couronne"):
			label += " — %d couronnes" % cost
		chance_shown = shown_chance(choice["check"], ctx)
		label += " (environ %d %%)" % chance_shown
	return {"label": label, "chance": chance_shown, "locked": locked_reason(choice, ctx)}


## Libellé court du type de test, pour l'infobulle.
static func kind_hint(check: Dictionary) -> String:
	match str(check.get("kind", "")):
		"negotiate":
			return "Négociation : dépend de la détermination du meilleur homme, de la réputation locale et des traits."
		"bribe":
			return "Pot-de-vin : presque sûr, mais l'argent est perdu même en cas d'échec."
		"flee":
			return "Fuite : dépend de l'initiative moyenne de la compagnie (l'équipement lourd pèse). Un échec vaut une embuscade."
		"trap":
			return "Piège : dépend des chasseurs de la compagnie et de leur tir."
	return ""
