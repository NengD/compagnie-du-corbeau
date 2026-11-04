extends SceneTree
## Génère docs/builds.md depuis Data.BUILDS, Data.WEAPON_FAMILIES, Data.ARMOR_FAMILIES et Data.PERKS (le texte ne peut donc pas diverger des données).
##   godot --path . --headless -s res://tools/gen_builds_doc.gd
## Le test `suite_maitrises::test_builds_reachable` vérifie que chaque build cité y figure et qu'il est atteignable.

## Style de jeu résumé de chaque famille (tableau « famille -> maîtrise -> talents recommandés -> style »).
const STYLE: Dictionary = {
	"epee": ["bretteur, vif, duelliste", "Duelliste précis : Fente à prix d'attaque, ripostes gratuites."],
	"hache": ["lame_affutee, force_brute, coup_de_grace", "Briseur d'armure : fend boucliers et plates, vise la tête."],
	"masse": ["intimidant, dur_a_cuire, ma_plates", "Étourdisseur : traverse l'armure, enchaîne sur les étourdis."],
	"fleau": ["garde_ferme, spec_bouclier, mur_vivant", "Bretteur de ligne : ignore les boucliers, frappe deux ennemis, Tourbillon."],
	"gourdin": ["endurant, vif, croc_en_jambe", "Harceleur : coups peu fatigants qui étourdissent, arme pauvre mais agile."],
	"lance": ["garde_ferme, spec_bouclier, mur_vivant", "Mur de lances : repousse, frappe d'abord celui qui approche."],
	"hast": ["pied_sur, croc_en_jambe, frappe_vive", "Piquier : deux cases de portée, faucher pour clouer l'ennemi."],
	"arc": ["archer_pose, esquive, legerete", "Archer : aucun malus au contact, portée et tir précis."],
	"arbalete": ["lame_affutee, archer_pose, predateur", "Tireur lent mais lourd : recharge abrégée, carreaux perforants."],
	"javelot": ["pied_sur, legerete, montagnard", "Tirailleur : volée de javelots puis décrochage."],
	"poings": ["duelliste, frappe_vive, insaisissable", "Moine : mains nues, esquive, étourdissements."],
	"bouclier": ["garde_ferme, mur_vivant, gardien", "Tank : mur de boucliers peu cher, voisins protégés."],
	"tissu": ["vif, legerete, insaisissable", "Léger : initiative et esquive, se bat avant les autres."],
	"matelasse": ["souffle_long, second_souffle, camaraderie", "Intermédiaire : armure effective, endurance, moins de blessures."],
	"mailles": ["parade, ma_casque, dur_a_cuire", "Fantassin : moins de poids, résiste aux lames."],
	"plates": ["armure_lourde, dur_a_cuire, intimidant", "Forteresse : poids sans fatigue, initiative lourde, inébranlable."],
	"casque": ["nuque_protegee, tete_froide, cran", "Tête protégée : peu de coups à la tête, résiste au choc."],
}


func _init() -> void:
	call_deferred("_run")


func _name(k: String) -> String:
	return str(Data.PERKS[k]["n"])


func _perk_list(csv: String) -> String:
	var out: Array[String] = []
	for k in csv.split(", "):
		out.append(_name(k) if Data.PERKS.has(k) else k)
	return ", ".join(out)


func _run() -> void:
	var L: Array[String] = []
	L.append("# Builds spécialisés : maîtrises d'armes et d'armures")
	L.append("")
	L.append("Document généré par `tools/gen_builds_doc.gd` depuis les données du jeu (`Data.WEAPON_FAMILIES`, `Data.ARMOR_FAMILIES`, `Data.PERKS`, `Data.BUILDS`). Ne pas l'éditer à la main.")
	L.append("")
	L.append("## Le principe")
	L.append("")
	L.append("Chaque arme et chaque armure appartient à une **famille**. Toute arme reste utilisable sans restriction ; c'est la **maîtrise** de la famille (rang 4 de l'arbre) qui fait un spécialiste, puis un **talent expert** (rang 6, qui exige la maîtrise) renforce son identité et ouvre souvent une capacité signature.")
	L.append("Les effets ne comptent que si l'équipement RÉEL de l'homme est de la famille : la maîtrise de l'épée ne fait rien avec une hache en main. Les armes uniques (Lame du Corbeau, Fend-Crâne…) comptent dans la famille de leur modèle.")
	L.append("Un point de talent par niveau (niveaux 2 à 11, soit 10 points) ; un talent du rang N exige d'avoir appris N−1 talents. Dans l'arbre, la fiche d'un talent de maîtrise indique s'il est **actif** ou **inactif** avec l'équipement actuel de l'homme.")
	L.append("")
	L.append("## Familles d'armes")
	L.append("")
	L.append("| Famille | Armes | Maîtrise (rang 4) | Expert (rang 6) | Talents recommandés | Style de jeu |")
	L.append("|---|---|---|---|---|---|")
	for f in Data.WEAPON_FAMILIES:
		var fd: Dictionary = Data.WEAPON_FAMILIES[f]
		L.append("| %s | %s | %s | %s | %s | %s |" % [fd["n"], Perks.family_members(f), _name(str(fd["mastery"])), _name(str(fd["expert"])), _perk_list(str(STYLE[f][0])), STYLE[f][1]])
	L.append("")
	L.append("## Familles d'armures")
	L.append("")
	L.append("| Famille | Pièces | Maîtrise (rang 4) | Expert (rang 6) | Talents recommandés | Style de jeu |")
	L.append("|---|---|---|---|---|---|")
	for f in Data.ARMOR_FAMILIES:
		var fd2: Dictionary = Data.ARMOR_FAMILIES[f]
		L.append("| %s | %s | %s | %s | %s | %s |" % [fd2["n"], Perks.family_members(f), _name(str(fd2["mastery"])), _name(str(fd2["expert"])), _perk_list(str(STYLE[f][0])), STYLE[f][1]])
	L.append("")
	L.append("## Ce que fait chaque maîtrise")
	L.append("")
	for kind in [Data.WEAPON_FAMILIES, Data.ARMOR_FAMILIES]:
		for f in kind:
			var fd3: Dictionary = kind[f]
			L.append("- **%s** — *%s* : %s" % [fd3["n"], _name(str(fd3["mastery"])), Data.PERKS[str(fd3["mastery"])]["d"]])
			L.append("  - *%s* (expert) : %s" % [_name(str(fd3["expert"])), Data.PERKS[str(fd3["expert"])]["d"]])
	L.append("")
	L.append("## Archétypes de builds (niveau 11, dans l'ordre d'apprentissage)")
	L.append("")
	L.append("Chaque liste tient dans les 10 points d'un homme de niveau 11, dans l'ordre : rangs et prérequis sont respectés (vérifié par les tests).")
	L.append("")
	for b in Data.BUILDS:
		var bd: Dictionary = b
		L.append("### %s" % bd["n"])
		L.append("")
		L.append("*%s*  Famille d'armes : **%s** · armure : **%s**." % [bd["style"], Perks.family_name(str(bd["weapon"])), Perks.family_name(str(bd["armor"]))])
		L.append("")
		var i: int = 1
		for st in bd["steps"]:
			L.append("%d. **%s** (rang %d) — %s" % [i, _name(str(st[0])), Perks.tier_of(str(st[0])), st[1]])
			i += 1
		L.append("")
	L.append("## Synergies utiles")
	L.append("")
	L.append("- **Mobilité** : *Vif*, *Pas léger*, *Insaisissable* et *Frappe vive* complètent les builds en tissu (initiative, esquive) ; *Pas léger* demande 10 de poids ou moins (les Maillons serrés y aident).")
	L.append("- **Endurance** : *Endurant*, *Second souffle*, *Souffle long* soutiennent les capacités signature (2 PA et beaucoup de fatigue) ; les plates (*Porteur de plates*) suppriment la fatigue du poids.")
	L.append("- **Esprit d'équipe** : *Camaraderie*, *Gardien*, *Mur vivant* et le *Bastion* du bouclier se cumulent dans une ligne serrée ; *Chef-né* et *Voix claire* tiennent le moral des rangs.")
	L.append("- **Moral et pression** : *Regard glaçant* après un coup d'étourdisseur (masse, gourdin, poings) ; *Prédateur* sur les ennemis brisés.")
	L.append("- **Dégâts d'armure** : *Lame affûtée* s'ajoute à la hache et à l'arbalète perforante.")
	var f_out := FileAccess.open("res://docs/builds.md", FileAccess.WRITE)
	f_out.store_string("\n".join(L) + "\n")
	f_out.close()
	print("docs/builds.md écrit (%d lignes)" % L.size())
	quit()
