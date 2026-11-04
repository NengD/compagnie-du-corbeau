# Compagnie du Corbeau

Jeu tactique de mercenaires au tour par tour, inspiré de *Battle Brothers* (Overhype Studios). Fait avec **Godot 4.7** en GDScript.
On dirige une compagnie de mercenaires : on voyage sur une carte, on prend des contrats dans les villes et villages, on combat
sur une grille hexagonale (armure, moral, fatigue, mort permanente), puis on recrute, équipe et fait progresser ses hommes.

Tout le texte du jeu est en français.

## Fonctionnalités

- **Carte du monde** à parcourir librement : le temps passe en marchant (la solde est payée chaque jour), terrains variés,
  3 villes et 5 villages, forts hostiles, bandes errantes, événements de route, réputation par lieu.
- **Bataille hexagonale** : points d'action, zones de contrôle, ligne de tir, terrains (forêt, colline, gué, rivière),
  moral, fatigue, capacités actives par arme, usure de l'équipement, blessures temporaires et permanentes.
- **Compagnie** : recrutement, **inventaire** façon Battle Brothers (emplacements, sacs, réserve, glisser-déposer),
  **arbre de 28 talents** sur 7 rangs, butin, vente, marchand rare.
- **Campagne** : contrats variés (élimination, chasse au chef, escorte, livraison, arcs enchaînés), factions (brigands, goules,
  orcs, morts-vivants) et crise finale.
- Menu principal, 3 emplacements de sauvegarde, options, tutoriel, sons et musiques.

## Lancer le jeu

Installe [Godot 4.7.2](https://godotengine.org/download) puis :

```bash
godot --path . 
```

Ou récupère l'exécutable Windows dans l'onglet **Releases** du dépôt.

## Développement

```bash
godot --path . --headless --import                      # importer les ressources / détecter les erreurs
godot --path . --headless -s res://tests/run_tests.gd   # tests (core, campagne, suites tests/suites/*)
godot --path . --headless -s res://tests/smoke_ui.gd    # test de fumée de l'interface
```

Export Windows : voir [`tools/export.md`](tools/export.md). Architecture et règles du jeu : voir [`CLAUDE.md`](CLAUDE.md).
`prototype/corbeau.html` est le prototype HTML d'origine, qui sert de référence aux règles.

## Licences

Code sous licence MIT (voir [`LICENSE`](LICENSE)). Les polices, icônes, sons et musiques viennent de ressources libres :
sources et licences dans [`assets/CREDITS.md`](assets/CREDITS.md) (notamment CC BY 3.0 pour les icônes de game-icons.net).
Projet de fan sans lien avec Overhype Studios ni avec *Battle Brothers*.
