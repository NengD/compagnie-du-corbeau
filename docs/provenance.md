# Provenance et originalité

## Principe de conception

*Compagnie du Corbeau* s'inspire du genre « mercenaires tactiques au tour par tour » (hexagones, armure, moral, fatigue, mort
permanente). Les **règles**, les **valeurs**, les **noms** et les **textes** du jeu sont écrits pour ce projet ; les formules viennent du
prototype `prototype/corbeau.html`.

- **Disposition par rangs** : l'arbre de talents est présenté en 7 rangs × colonnes, un talent du rang N exigeant N−1 talents déjà
  appris. C'est une **inspiration de structure** assumée (une mise en page de grille, pas un contenu) ; les talents, leurs effets, leurs
  chiffres et leurs familles (maîtrises d'armes et d'armures) sont propres au projet.
- **Règle** : aucun nom, texte, icône, son, image ni chiffre n'est copié d'un jeu commercial. Les ressources externes sont libres
  (CC0 / CC-BY / OFL / MIT) et créditées dans `assets/CREDITS.md`. Aucun fichier d'un jeu commercial n'est lu ni copié pendant le
  développement.
- Un test (`tests/suites/suite_provenance.gd`) vérifie qu'aucun des anciens noms ci-dessous ne figure plus parmi les talents.

## Renommage des talents (5 novembre 2026)

Certains noms étaient des traductions courantes de talents d'autres jeux. Seuls les noms affichés ont changé : les clés techniques
(`"esquive"`, `"cran"`…), les effets et les sauvegardes sont inchangés.

| Clé | Ancien nom | Nouveau nom |
|---|---|---|
| `esquive` | Esquive | Cible mouvante |
| `studieux` | Studieux | Apprenti zélé |
| `pied_sur` | Pied sûr | Jarret solide |
| `cran` | Cran | Nerfs d'acier |
| `predateur` | Prédateur | Rapace |
| `duelliste` | Duelliste | Loup solitaire |
| `dur_a_cuire` | Dur à cuire | Cuir épais |
| `second_souffle` | Second souffle | Poumons de forge |
| `increvable` | Increvable | Sept vies |
| `coup_de_grace` | Coup de grâce | Visée haute |
| `insaisissable` | Insaisissable | Anguille |
| `armure_lourde` | Port d'armure | Carapace |
| `chef_ne` | Chef-né | Meneur |
| `spec_epee` | Maître d'épée | Escrimeur |
| `spec_fleau` | Maître du fléau | Batteur |
| `ex_epee` | Riposte | Contre-pied |
| `ex_fleau` | Tourbillon | Moulinet |
| `ex_lance` | Mur de lances | Haie de piques |

Les capacités et builds qui reprenaient ces noms ont suivi : capacité « Tourbillon » → « Moulinet », « Riposte » → « Contre-pied »,
« Mur de lances » → « Haie de piques », build « Duelliste à l'épée » → « Escrimeur solitaire », build « Mur de lances » → « Haie de piques ».
