# Compagnie du Corbeau

Jeu tactique de mercenaires au tour par tour, inspiré de **Battle Brothers** (Overhype Studios).
On dirige une compagnie de mercenaires : contrats, combats sur grille hexagonale, armure, moral,
fatigue, mort permanente, recrutement et progression.

Le joueur parle français. Réponds en français, et écris tout le texte du jeu en français.
Les identifiants de code (variables, fonctions, fichiers) sont en anglais.

## État actuel

- Étapes 1 à 4 de la feuille de route **faites** : `core/` testé, bataille jouable, camp avec sauvegarde, figurines en couches.
- **Carte du monde** (style Battle Brothers) faite : on clique pour voyager, le temps passe (solde chaque jour, +2 PV/jour de route),
  3 villes + 5 villages (contrats, recrues, marchand à prix variable, stock selon le type de lieu), un contrat à la fois
  (aller sur place, combat, prime versée tout de suite), bandes errantes qui poursuivent (brigands) ou rôdent (goules).
  Les contrats n'ont plus de « jours de route » fixes : le trajet réel les remplace. Pas de guérison au retour de combat.
- `prototype/corbeau.html` reste **la référence des règles** (ne pas le modifier). En cas de doute sur une règle,
  lis le code du prototype plutôt que d'inventer.
- **Combat enrichi** : terrains variés (forêt, colline, gué, rivière ; `Data.TERRAIN`, `core/terrain_gen.gd`, biome du contrat),
  ligne de tir (obstacles bloquent, unités sur la ligne −15 %), talents à chaque niveau (`Data.PERKS`, `Unit.perks`),
  blessures temporaires/permanentes (`Data.INJURIES`, `core/injuries.gd`, `Unit.injuries`). Stats lues via `Unit.eff()`.
- **Monde enrichi** : factions orcs (`"o"`) et morts-vivants (`"u"`), contrats chasse/escorte/livraison, événements de route
  (`core/events.gd`, `Game.resolve_event`), réputation par lieu, zoom/déplacement de la carte.
- **Économie / système** : butin (`core/loot.gd`, `Game.inventory`), vente et équipement depuis l'inventaire (`Game.sell`,
  `Game.equip_from_inventory`), menu principal, options (`autoload/Settings.gd` -> `user://settings.cfg`), 3 emplacements
  de sauvegarde (`Game.save_to_slot/load_slot/slot_info`, l'autosave reste `user://savegame.json`), fondus entre écrans (`scenes/menu/`).
- **Audio et ressources** : `autoload/Audio.gd` (`Audio.play(evt)`, `Audio.music(name)`), `assets/audio/`, polices Pirata One /
  Alegreya Sans (OFL), icônes d'objets (`scenes/ui/item_icons.gd`, game-icons.net CC-BY 3.0). **Toute ressource téléchargée doit
  être créditée dans `assets/CREDITS.md`** (CC0 / CC-BY / OFL / MIT seulement). L'utilisateur autorise le téléchargement de
  ressources libres.
- **Figurines et effets** : calques détaillés (7 coiffures, 7 barbes, accessoires), animations (`UnitView.lunge/hit_flash`),
  sprites orcs/morts-vivants, effets d'impact (`scenes/battle/effects.gd`, `BattleFx`).
- **Armes et usure** : arbalète, hallebarde, fléau, javelots ; capacités actives par arme (`Data.ABILITIES`, `BattleState.use_ability`,
  boutons dans `battle.gd`) ; durabilité des armes et boucliers, réparation au camp.
- **Campagne** : forts/repaires hostiles attaquables sans contrat, marchand rare (`Data.UNIQUES`), arcs de 3 contrats liés, crise
  finale avec jauge de menace et écran de fin (`scenes/ending/`, `core/campaign.gd`), mode libre ensuite.
- **Ressenti** : dosage audio (limiteur, anti-répétition), animations de marche et de mort, zoom/déplacement du plateau de bataille,
  tutoriel au premier lancement (`scenes/tutorial/`, rejouable depuis les options).
- **Qualité et export** : `tools/sim_battles.gd` et `tools/sim_campaign.gd` (simulations IA, détection de bugs, pas d'équilibrage ;
  4 000 batailles et ~500 campagnes sans bug), `tests/suites/suite_regression.gd`. Export Windows : voir `tools/export.md`
  (`build/CompagnieDuCorbeau.exe`, ≈ 133 Mo, pck intégré).
- **Inventaire façon BB** : `scenes/inventory/inventory_screen.gd` (touche I, bouton sur la carte/en ville) : liste des hommes, poupée
  d'équipement (tête, corps, main droite, main gauche, 2 sacs), réserve en grille (capacité `Data.STASH_SIZE`), glisser-déposer,
  filtres/tri, aperçu des stats avant/après ; logique pure dans `core/inventory.gd` ; `Unit.bag` ; « Changer d'arme » en bataille
  (`BattleState.swap_weapon`, 4 PA).
- **Talents façon BB** : arbre de 28 talents sur 7 rangs × 4 colonnes (`Data.PERKS`, `core/perks.gd`, `scenes/perks/perk_screen.gd`,
  `PerkScreen.open(host, unit)`), 1 point par niveau (`Unit.perk_points`), un talent du rang N exige N−1 talents ; entraîneur payant
  en ville pour réinitialiser ; chefs ennemis peuvent avoir des talents fixes (`Data.FOE[...]["perks"]`).
- **Confort** : annuler un déplacement (`BattleState.undo_move`, Ctrl+Z), raccourcis clavier affichés et aide « ? »
  (`scenes/ui/shortcuts.gd`), journal filtrable, résumé après bataille (`scenes/battle/summary_screen.gd`, `Game.last_battle_report`),
  légende de carte et lieux visités (`settlement["visited_day"]`).
- **Contenu** : plus d'événements/contrats/noms, traits de caractère (`Data.TRAITS`, `Unit.traits`, `core/traits.gd`), tenues d'élite,
  bannière et nom de compagnie personnalisables (`Game.banner`, `Game.company_name`), succès et statistiques (`core/achievements.gd`,
  `Game.stats`, `user://achievements.json`, `scenes/achievements/`).
- **Options et lancement** : fenêtre (mode, résolution, écran, échelle UI, VSync, FPS, MSAA, tremblement, taille du texte…) dans
  `autoload/Settings.gd` / `scenes/menu/options_panel.gd` (`user://settings.cfg`) ; écran de lancement (`assets/splash.png`,
  `scenes/boot/boot_screen.gd`) ; icône `assets/app_icon.ico`. L'icône incrustée dans le .exe exige `rcedit` configuré à la main
  dans Godot (voir `tools/export.md`).
- **Batailles variées** : types (`contract["battle_type"]` : pitched / ambush / convoy / siege / night), objectifs secondaires
  (`BattleState.objectives`), décor interactif (`core/scenery.gd`, `Data.SCENERY`, `cells[h]["obj"]` : feu, portes, barricades, pièges,
  murs), outils de jet (kind `"tool"` : pierres, huile, filet), monstres (faction `"m"` : loup, ogre, troll, cavalier de loup ;
  `Unit.sprite`), IA plus variée (archers qui reculent, chefs à l'arrière, encerclement, soigneurs). Toute nouvelle arme de
  `Data.WPN` exige une icône du même nom dans `assets/icons/`.
- **Compagnie** : quartier général (`Data.CAMP_BUILDINGS`, `core/camp_buildings.gd`, onglet `scenes/camp/hq_tab.gd`), vivres
  (`Game.provisions`) et moral de compagnie (`Game.company_morale`), relations (`Unit.bonds`, `core/bonds.gd`), factions humaines
  (`Data.FACTIONS`, `settlement["owner"]`, `Game.faction_standing`, `core/factions.gd`), histoires à étapes (`Data.STORIES`,
  `Game.story_flags`, `Game.pending_events`).
- **Rendu du plateau** : sol texturé teinté par biome avec fondus, météo (`scenes/battle/weather.gd`), décalcomanies de sang,
  projectiles et animations d'attaque par arme (`scenes/battle/attack_anims.gd`), cadavres variés, obscurité de nuit.
- **Figurines et interface** : capes/manteaux/bottes, usure visible, sprites de monstres, portraits expressifs (`mood`), thème
  « cuir et parchemin » (`assets/ui/`, `tools/gen_ui.gd`, réglage « Interface illustrée »), illustrations de transition
  (`scenes/ui/illustrations.gd`, `town_arrival.gd`).
- **Carte** : cycle jour/nuit, météo, routes lissées (plus rapides : coût 0,8), rivières avec gués et ponts (`World.T.BRIDGE`),
  relief et forêts variés, territoires et bannières des factions, rose des vents et cartouche.
- **Difficulté** : Facile / Normal / Difficile choisie à la nouvelle partie (`Data.DIFFICULTY`, `core/difficulty.gd`,
  `Game.difficulty`, `scenes/menu/difficulty_panel.gd`) ; « Normal » reproduit exactement le comportement de référence ; les
  anciennes sauvegardes se chargent en Normal.
- **Qualité graphique** : préréglages Bas / Moyen / Élevé / Ultra + Personnalisé (`core/quality.gd`, `autoload/Settings.gd`,
  section « Graphismes » des options, compteur d'images par seconde optionnel, suggestion automatique au premier lancement selon
  la carte graphique).
- **Sauvegarde sûre** : écriture atomique (`Game._write_json_safe` : fichier `.tmp` vérifié, copie `.bak` de la version précédente,
  puis renommage), lecture validée avec repli automatique sur le `.bak` (`Game._read_save`), `from_dict` tolérant aux clés
  manquantes. Fin de tour au clavier (Espace/Entrée) : confirmation s'il reste la moitié des PA ou plus. Un seul point d'entrée
  « Nouvelle partie » (`Main._start_new_game`). Le chaman orc (soigneur) figure dans les compositions orques.
- **Carte plein cadre** : la carte remplit l'écran, HUD discret superposé (jauges vivres/moral/menace, temps et date, pastille du
  contrat, boutons ronds Compagnie/Inventaire/Détails/Légende/Aide), tiroir « Détails » (touche D) qui reprend l'ancien panneau
  latéral, en-tête compact sur la carte. **Bannière de compagnie** : étape « Votre compagnie » à la nouvelle partie
  (`scenes/newgame/`, nom + couleurs + emblème + motif, `core/banner.gd`), étendard planté sur la carte à la place de l'ancien
  marqueur (nom de la compagnie décalé près des lieux pour ne pas recouvrir leur nom).
- **Écrans façon BB (disposition seulement ; aucun contenu du jeu commercial n'est repris)** : marché « Place du marché » à stock fini
  (`scenes/market/market_screen.gd`, `core/market.gd`, `settlement["stock"]`, `Game.shop_stock/buy_item/sell_item`), fiche de
  personnage à onglets Inventaire / Talents (`scenes/inventory/inventory_screen.gd`, poupée d'équipement, statistiques en barres,
  formation en bas), cases d'objets (`scenes/ui/item_cell.gd`, `ItemIcons.get_icon_for_item`, icônes dans `assets/icons/`), formation
  de combat (`core/formation.gd`, `Game.formation`, `Game.set_formation_slot`, `scenes/inventory/formation_panel.gd` : 3 rangées de
  combat + réserve de 9 tentes ; `BattleState.create(..., formation)`), arbre de talents sur 7 rangs (50 de base, 76 avec les maîtrises)
  (`Data.PERKS`, `scenes/perks/perk_tree.gd`, `assets/perk_icons/`). Résolution 2K (2560×1440) disponible dans les options.
- **Provenance** : ne jamais lire ni copier le dossier d'une copie piratée de Battle Brothers (`E:\crack\…`) ; le dépôt est public.
- **Maîtrises et builds spécialisés** : 76 talents ; chaque arme et chaque armure a une famille (`Data.WEAPON_FAMILIES`,
  `Data.ARMOR_FAMILIES`, `Perks.weapon_family/armor_family`, un test échoue si une arme ou armure joueur n'a pas de famille),
  une maîtrise au rang 4 (17 : 12 armes + 5 armures) et un talent expert au rang 6 (17, exige la maîtrise) ; les effets ne
  s'appliquent qu'avec l'équipement RÉEL de la famille ; sans maîtrise, l'arme reste utilisable. `docs/builds.md` (généré par
  `tools/gen_builds_doc.gd`, ne pas éditer à la main) liste les familles et 12 builds testés.
- Tests modulaires : `tests/suites/suite_*.gd` (voir `tests/suites/README.md`) chargés par `tests/run_tests.gd`.
- Consignes de travail de l'utilisateur : ne jamais piloter la souris (pas de computer-use) ; lancer la fenêtre du jeu avec
  `--screen 1 --resolution 1280x720 --audio-driver Dummy` (écran de l'app Claude, **son coupé** : toujours ajouter `--audio-driver Dummy`
  quand Claude ouvre le jeu ou un script de capture ; pour l'exécutable exporté : `CompagnieDuCorbeau.exe --screen 1 --audio-driver Dummy`).
- Pas encore fait : tactile/manette, brouillard de guerre, équilibrage chiffré (volontairement écartés), carte du monde
  à explorer plus loin, nouveaux types de ville.

## Moteur et commandes

- Godot **4.7.2 stable**, déjà installé :
  - éditeur : `E:\_jeu perso\godot\Godot_v4.7.2-stable_win64.exe`
  - console (pour les commandes) : `E:\_jeu perso\godot\Godot_v4.7.2-stable_win64_console.exe`
- Le projet Godot est à la racine de ce dossier (`project.godot` ici).
- Langage : **GDScript typé** (annotations de type partout : `var hp: int`, `func f(a: Unit) -> int`).
- Les chemins contiennent des espaces : toujours les mettre entre guillemets.

```bash
GODOT="/e/_jeu perso/godot/Godot_v4.7.2-stable_win64_console.exe"   # Git Bash
# Windows cmd / PowerShell : "E:\_jeu perso\godot\Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --path . --headless --import                 # importer les ressources / détecter les erreurs de parsing
"$GODOT" --path . --headless -s res://tests/run_tests.gd   # tests de core/ et de Game (code 0 = OK)
"$GODOT" --path . --headless -s res://tests/smoke_ui.gd    # test de fumée de l'interface (camp -> bataille -> camp)
"$GODOT" --path . -s res://tests/screenshots.gd -- "<dossier>"   # captures d'écran (fenêtre requise)
py tools/gen_sprites.py                               # régénère assets/sprites/*.svg puis relancer --import
"$GODOT" --path . --screen 1 --audio-driver Dummy     # lancer le jeu (écran de l'app Claude, son coupé)
```

Piège : dans un script `-s` (SceneTree), les autoloads (`Game`, `Data`) ne sont pas des identifiants au
chargement ; passer par `root.get_node("/root/Game")` et ne pas typer avec des `class_name` qui les utilisent
(voir `tests/smoke_ui.gd`).

Piège : en GDScript, une fonction anonyme (`func() -> void: ...`) capture les variables locales **par valeur au moment de sa
création**. Une variable déclarée vide (`var sync := Callable()`) puis affectée plus tard reste vide pour les lambdas créées avant :
passer par un conteneur (`var sync: Array = [Callable()]`, `sync[0] = func...`). Cela a rendu inertes les boutons de l'étape
« Votre compagnie » ; tests de régression dans `tests/smoke_ui.gd` (`_check_company_setup`).

Piège : une infobulle personnalisée (`_make_custom_tooltip`) vit dans une fenêtre à part : n'y mets AUCUN libellé à retour à la ligne
automatique (`autowrap_mode`) dont la hauteur dépend d'une largeur calculée plus tard ; coupe le texte à l'avance
(`PerkIcon.wrap_text`). Tailles de fenêtre : la liste des options va jusqu'à la taille de l'ÉCRAN (le 2K 2560×1440 y figure,
ajusté à la zone utilisable en mode fenêtré).

Après chaque modification de script, lance au minimum `--headless --import` et corrige toute erreur
avant de dire que c'est fini. Ne laisse jamais le projet dans un état qui ne s'ouvre pas.

## Architecture

```
project.godot
autoload/
  Data.gd          # tables de données (armes, armures, origines, ennemis, noms, constantes)
  Game.gd          # état de campagne : or, jour, renom, compagnie, lieu, contrat actif ; temps, voyage (map_step), actions ; sauvegarde JSON
core/              # logique pure, SANS dépendance aux nœuds de scène -> testable en headless
  hex.gd           # coordonnées axiales, distance, voisins, conversion pixel
  unit.gd          # class_name Unit (Resource) : stats, équipement, état de combat, (dé)sérialisation
  combat_rules.gd  # chance de toucher, dégâts armure/PV, tests de moral
  pathfinding.gd   # BFS avec zones de contrôle
  battle_state.gd  # plateau, file d'initiative, manches, attaques, victoire, sérialisation
  ai.gd            # prochaine action ennemie (brigands, goules), fuite
  contracts.gd     # génération des contrats (par lieu), recrues, ennemis
  world.gd         # carte : terrain (bruit), lieux, bandes errantes, chemins (AStarGrid2D), déplacement
scenes/
  main.tscn/.gd    # en-tête + bascule camp / bataille
  camp/            # camp.gd : écran de ville (Contrats, Recruter, Marché, Compagnie) ou fiche Compagnie seule (mode "company")
  map/             # map_screen.gd (temps, panneau latéral), map_view.gd (terrain peint, villes, chemin, clics)
  battle/          # battle.gd (écran, tours, animations), board_view.gd (plateau), unit_view.gd (figurine + barres)
  ui/              # game_theme, ui_kit, figure (calques), portrait_view, stat_bar, modal_overlay
assets/
  sprites/         # calques SVG générés par tools/gen_sprites.py (ne pas éditer à la main)
  fonts/           # polices optionnelles (voir État actuel)
tools/gen_sprites.py
tests/             # run_tests.gd, smoke_ui.gd, screenshots.gd
```

Règles d'architecture :
- **Séparer logique et affichage.** Tout ce qui est dans `core/` doit tourner sans scène. Les scènes lisent
  l'état et émettent des actions ; elles ne calculent jamais de règle elles-mêmes.
- Les données (armes, armures…) vivent dans `Data.gd` (dictionnaires) ou en `.tres` ; pas de valeurs
  magiques dispersées dans les scènes.
- Aléatoire : passer par un `RandomNumberGenerator` injectable, pour que les tests puissent fixer la graine.
- Sauvegarde : `user://savegame.json` (sérialisation explicite de `Game`, bataille en cours incluse), sauvegarde
  automatique à chaque action du camp et au début de chaque tour du joueur. `Game.autosave = false` dans les tests.
- Séquencement : `core/` est synchrone. `BattleScreen` rejoue les mêmes primitives (`attack`, `step`,
  `free_attackers`…) avec des `await` pour les animations ; `BattleState.play_ai_turn` en est la version sans affichage.
- Calques de figurine teintés par `modulate` : peau, cheveux, étoffe, manches sont dessinés en blanc dans les SVG.

## Règles du jeu (portées du prototype)

### Unité
Attributs : `hp_max, fat_max, resolve (détermination), initiative, melee_skill, ranged_skill,
melee_def, ranged_def`. Équipement : arme, bouclier (bool), tête, corps. Armure tête `arm_h` et
corps `arm_b` (valeurs courantes, se réparent au camp). Niveau, XP, victimes, solde/jour.

- Poids = poids tête + poids corps + 4 si bouclier.
- Endurance effective = `fat_max − poids`. Initiative effective = `initiative − poids − fatigue actuelle`.
- Coût en fatigue d'un déplacement d'une case = `2 + floor(poids / 10)`.

### Tour de combat
- 9 PA par tour. Déplacement : 2 PA par case. Début de tour : fatigue −15 (min 0), mur de boucliers retiré.
- Ordre : tri par initiative effective décroissante, recalculé à chaque manche.
- « Attendre » renvoie l'unité en fin de file (une fois par manche).
- **Zone de contrôle** : on ne peut pas traverser une case adjacente à un ennemi en mêlée (on peut y entrer
  et s'y arrêter). Quitter le contact d'un ennemi de mêlée lui donne une attaque gratuite ; si elle touche,
  le déplacement est annulé.
- Terrain : herbe (praticable), arbre et rocher (bloquants). Carte 12 × 9, joueur à gauche, ennemi à droite,
  tireurs en deuxième ligne.

### Chance de toucher
```
Mêlée :    compétence_mêlée + bonus_arme − (déf_mêlée + 15 si bouclier + 20 si mur + MDEF[moral_cible])
           + 5 par allié de l'attaquant adjacent à la cible (encerclement)
Distance : compétence_distance + bonus_arme − (déf_distance + 25 si bouclier + 20 si mur + MDEF[moral_cible])
           − 3 par case au-delà de 2 ; −10 si la cible est adjacente
Puis :     + MSK[moral_attaquant], borné entre 5 et 95 %
MSK  = [−30, −20, −10, 0, +10]   MDEF = [−20, −15, −10, 0, +5]   (index = moral)
```

### Dégâts
- 25 % de chances de toucher la tête (×1,5 dégâts), sinon le corps.
- `brut = aléa(min, max)`. Si armure de la zone = 0 → tout en PV.
- Sinon : `dégâts_armure = brut × eff_armure` (plafonné à l'armure restante) ;
  `dégâts_PV = max(0, brut × traversée − armure × 0,1)` ;
  si `brut × eff_armure > armure`, ajouter `(brut × eff_armure − armure) / eff_armure × (1 − traversée)`.
- PV ≤ 0 → mort.

### Moral
États : 0 En fuite, 1 Brisé, 2 Hésitant, 3 Stable (départ), 4 Confiant.
- Test : réussi si `aléa(1,100) ≤ clamp(détermination + modificateur, 5, 95)`, sinon −1 cran.
- Tests déclenchés : coup de 12 PV ou plus (modif. +10, ou −15 si PV < 40 %) ; allié mort à 4 cases ou moins (0,
  ou −15 si c'était le chef) ; chef mort loin (−10).
- Ennemi mort à 4 cases ou moins : chance de remonter d'un cran (`détermination − 10`).
- En fuite : l'unité court vers son bord de carte et le quitte. Chaque tour, elle tente de se ressaisir
  (`détermination − 10 × ennemis adjacents`).
- Victoire quand aucun ennemi n'est en état de combattre (moral > 0).

### Données
Armes (dégâts min–max, efficacité contre armure, traversée, PA, fatigue, bonus toucher, portée, une main, prix) :

| Arme | Dégâts | Eff. armure | Traversée | PA | Fat. | Toucher | Portée | 1 main | Prix |
|---|---|---|---|---|---|---|---|---|---|
| Gourdin | 20–30 | 0,9 | 0,4 | 4 | 10 | 0 | 1 | oui | 40 |
| Fourche | 20–30 | 0,7 | 0,25 | 6 | 12 | +5 | 2 | non | 70 |
| Lance | 25–30 | 0,9 | 0,25 | 4 | 10 | +20 | 1 | oui | 250 |
| Hache | 30–45 | 1,4 | 0,1 | 4 | 12 | 0 | 1 | oui | 320 |
| Masse d'armes | 30–40 | 1,1 | 0,4 | 4 | 12 | 0 | 1 | oui | 380 |
| Épée d'armes | 35–45 | 0,8 | 0,2 | 4 | 10 | +10 | 1 | oui | 650 |
| Arc de chasse | 30–50 | 0,55 | 0,35 | 4 | 12 | 0 | 6 | non | 280 |
| Griffes (goule) | 20–35 | 0,6 | 0,15 | 4 | 8 | 0 | 1 | — | — |
| Griffes énormes | 35–55 | 0,8 | 0,15 | 4 | 10 | 0 | 1 | — | — |

Tête : capuchon 30 (poids 0, 60 cr.), casque à nasal 90 (5, 280), heaume fermé 160 (10, 750).
Corps : tunique 20 (0, 30), gambison 65 (6, 220), haubert de mailles 130 (14, 700), brigandine 190 (22, 1250).
Bouclier rond : 120 cr., poids 4, une arme à une main requise.

Origines des recrues, ennemis (brigands, archers, balafrés, chef ; goules, goule vorace) avec leurs plages
de stats : voir les objets `BG` et `FOE` dans le prototype.

### Camp et campagne
- Départ : 800 couronnes, 5 hommes (milicien, bûcheron, braconnier, fermier, déserteur). Max 10 hommes,
  les 8 premiers combattent.
- 3 contrats à la fois (brigands ou goules, danger 1–3, 1–3 jours de route). Prime ≈ `danger × 320 + aléa`.
- Victoire : prime + 40 × danger de renom, XP = victimes + 15 × danger. Défaite ou retraite : −15 renom.
- Solde payée à chaque jour écoulé ; si l'or passe sous 0, un homme déserte.
- Repos : +1 jour, +15 PV. Réparation : 0,5 couronne par point d'armure.
- Niveaux : seuils d'XP `[0, 0, 40, 100, 180, 280, 400, 540, 700, 900, 1150, 1450]`. À chaque niveau, on tire
  un gain pour chaque attribut et le joueur en choisit 3.

## Style visuel

Inspiration directe : Battle Brothers. Figurines en buste vues de profil, contour sombre épais,
couleurs terreuses peintes à la main, ombres simples, pas de dégradés criards.
- Une figurine = **pile de couches** (`Node2D` avec des `Sprite2D`) : corps/vêtement → armure → tête → barbe/cheveux
  → casque → arme → bouclier. Changer d'équipement = changer une texture.
- Le joueur regarde vers la droite, l'ennemi vers la gauche (`scale.x = -1`).
- Boucliers du joueur : ocre au chevron noir. Brigands : rouge et brun.
- Calques supplémentaires (générés, cf. `tools/gen_sprites.py`) : `face_0..2`, `mark_*` (cicatrices, œil au beurre noir, bandeau d'œil), `band`, `hair_0..6`, `beard_1..7`, `cape`/`satchel`/`bandolier`/`scarf`, `pauldron_*`, goules `ghoul[_big][_b]` ; `Figure.look(u)` tire tout de façon stable depuis `u.id`. Aperçu : `tools/preview_figures.gd`.
- `UnitView` anime : respiration idle, `await lunge(vers_px)` (élan d'attaque), `hit_flash()` (recul + flash rouge), fondu à la mort ; sans attente quand `BattleScreen.speed == 0`.
- Sous chaque figurine : ombre, socle coloré par camp, barres armure tête (gris clair), armure corps (bleu acier), PV (rouge).
- Tant qu'il n'y a pas de vrais sprites, on peut convertir les dessins SVG du prototype (`function figure`)
  en fichiers `.svg` séparés par couche dans `assets/sprites/` ; Godot les importe directement.
- Interface : fonds cuir/brun sombre, texte parchemin, accents or et rouge sang.
  Polices du prototype : *Pirata One* (titres) et *Alegreya Sans* (texte), libres sur Google Fonts.

## Feuille de route

(Étapes 1 à 4 terminées.)

1. **Port du cœur** : `core/` complet et testé (règles ci-dessus), sans graphismes.
2. **Bataille jouable** : plateau hexagonal, sélection, aperçu du chemin et du coût en PA, pourcentage de toucher
   au survol, journal de combat, IA, écran de victoire/défaite.
3. **Camp** : compagnie, contrats, recrutement, marché, promotion, sauvegarde.
4. **Figurines en couches** et portraits.
5. Ensuite, au choix du joueur : carte du monde à parcourir, blessures permanentes, talents (perks),
   butin après combat, nouvelles factions (orcs, morts-vivants), dégâts visibles sur l'équipement.

## Façon de travailler

- Avance par petites étapes jouables ; après chaque étape, dis au joueur comment la tester dans Godot.
- Avant d'ajouter une mécanique qui n'est pas dans le prototype, propose-la en une ou deux phrases et attends son accord.
- Ne modifie pas `prototype/corbeau.html` : c'est la référence.
- Garde ce fichier à jour quand l'architecture ou les règles changent.
