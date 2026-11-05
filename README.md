# Compagnie du Corbeau

Jeu tactique de mercenaires au tour par tour, inspiré de *Battle Brothers* (Overhype Studios). Fait avec **Godot 4.7** en GDScript.
On dirige une compagnie de mercenaires : on voyage sur une carte, on prend des contrats dans les villes et villages, on combat
sur une grille hexagonale (armure, moral, fatigue, mort permanente), puis on recrute, équipe et fait progresser ses hommes.

Tout le texte du jeu est en français.

## Fonctionnalités

- **Grand monde** à parcourir librement (≈ 3600 × 2400 px, plein cadre, cycle jour/nuit, météo) : le temps passe en marchant (la solde est
  payée chaque jour), plus de 20 lieux, 6 factions humaines et cités libres aux territoires contigus, 30 points d'intérêt, forts hostiles,
  bandes errantes, événements de route, réputation par lieu. Caméra au clavier (ZQSD / WASD ou flèches, Maj = rapide, `H` recentre,
  molette = zoom), mini-carte, légende (`L`) et tiroir « Détails » (`F`).
- **Bataille hexagonale** : points d'action, zones de contrôle, ligne de tir, terrains (forêt, colline, gué, rivière),
  moral, fatigue, capacités actives par arme, usure de l'équipement, blessures temporaires et permanentes.
- **Compagnie** : recrutement, fiche de personnage à onglets Inventaire / Talents (emplacements, sacs, réserve, glisser-déposer),
  **formation de combat** (3 rangées + réserve), **arbre de 76 talents** sur 7 rangs avec maîtrises d'armes et d'armures pour des builds
  spécialisés (voir `docs/builds.md`), marché à stock fini, butin, marchand rare, quartier général, vivres et moral de compagnie.
- **Campagne** : contrats variés (élimination, chasse au chef, escorte, livraison, arcs enchaînés), factions (brigands, goules,
  orcs, morts-vivants) et crise finale.
- **Difficulté** Facile / Normal / Difficile à la nouvelle partie, bannière et nom de compagnie personnalisables.
- Menu principal, 3 emplacements de sauvegarde (écriture atomique avec copie de secours), options complètes (fenêtre, résolution jusqu'au 2K,
  **qualité graphique** Bas / Moyen / Élevé / Ultra), tutoriel, succès, sons et musiques.

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
godot --path . --headless -s res://tools/sim_battles.gd     # batailles simulées par l'IA (détection de bugs)
godot --path . --headless -s res://tools/sim_campaign.gd    # campagnes simulées (détection de bugs)
```

Export Windows : voir [`tools/export.md`](tools/export.md). Architecture et règles du jeu : voir [`CLAUDE.md`](CLAUDE.md).
Originalité des noms et des textes : [`docs/provenance.md`](docs/provenance.md).
`prototype/corbeau.html` est le prototype HTML d'origine, qui sert de référence aux règles.

## Licences

Code sous licence MIT (voir [`LICENSE`](LICENSE)). Les polices, icônes, sons et musiques viennent de ressources libres :
sources et licences dans [`assets/CREDITS.md`](assets/CREDITS.md) (notamment CC BY 3.0 pour les icônes de game-icons.net).
Projet de fan sans lien avec Overhype Studios ni avec *Battle Brothers*.
