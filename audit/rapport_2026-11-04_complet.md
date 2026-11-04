# Audit complet — état de référence (2026-11-04)

Projet : Compagnie du Corbeau (Godot 4.7.2). Audit en lecture seule ; rien n'a été modifié hors de `audit/`.
Légende : **[V]** = vérifié (exécuté ou lu avec la référence donnée) ; **[S]** = supposé / non exécuté.

## Résumé

- **État général : sain.** Import sans erreur ni avertissement, tests 19 924 vérifications / 0 échec, smoke UI OK, 300 batailles IA et 15 campagnes simulées sans bug, dépôt propre. Aucun constat BLOQUANT.
- Les vrais risques sont dans la **robustesse de la sauvegarde** et quelques **contenus déclarés mais inatteignables**.
- Top 5 :
  1. Sauvegarde non atomique, sans copie de secours, et chargement sans garde sur JSON incomplet (`Game.gd:1563`, `1641`).
  2. Le **Chaman orc** (soigneur) n'est généré par aucun contrat, bande ni site : l'IA de soin n'est jamais vue en jeu (`contracts.gd:_ORCS`, `campaign.gd:186-203`).
  3. Fin de tour accidentelle : Espace/Entrée terminent le tour sans confirmation par défaut, Retour arrière annule un déplacement (`battle.gd:490-492`, `Settings.gd:93`).
  4. Deux chemins « Nouvelle partie » qui divergent (menu vs en-tête), dont l'un saute le tutoriel (`main.gd:188` vs `main.gd:309-315`).
  5. Aléa non sérialisé (`rng`, `loot_rng`) : recharger permet de retenter les jets, et une partie n'est pas reproductible.

Comptage : **BLOQUANT 0 — IMPORTANT 4 — MINEUR 14.**

## 1. Santé (vérifié)

| Contrôle | Résultat |
|---|---|
| `--headless --import` | exit 0, aucune ligne warning/erreur [V] |
| `tests/run_tests.gd` | « 19924 vérifications, 0 échec », exit 0 [V] |
| `tests/smoke_ui.gd` | « Smoke UI : OK » (camp → voyage → bataille gagnée en 13 manches → camp) [V] |
| `tools/sim_battles.gd --count 300 --seed 90000` | échecs : 0, aucun « SCRIPT ERROR » [V] |
| `tools/sim_campaign.gd --count 15 --seed 90000` | échecs : 0, aucun « SCRIPT ERROR » [V] |
| TODO/FIXME dans `*.gd` | aucun (un seul faux positif, `ai.gd:86`) [V] |
| Scripts orphelins (hors tests/tools) | aucun [V] |
| Signaux de `Game` | tous émis ET connectés (`main.gd:61-67`) [V] |
| Réglages `Settings` | tous lus quelque part (via `Quality.value`, `st.get(...)`, etc.) [V par grep] |
| Événements `Audio.EVENTS` (13) | tous utilisés par `Sfx.play(...)` et fichiers présents [V] |

## 2. Constats

### IMPORTANT

**I1 — Sauvegarde fragile** [V]
- Preuve : `Game.gd:1641-1652` (`save()` écrit directement dans `savegame.json`, pas de fichier temporaire + renommage, pas de `.bak`) ; `Game.gd:1563-1580` (`from_dict` lit `d["gold"]`, `d["day"]`, `d["roster"]`, `d["world"]`, `d["battle"]`… sans garde) ; `_read_save` (`Game.gd:1659-1665`) ne vérifie que `world` et `version`.
- Conséquence : plantage ou coupure pendant l'écriture (la sauvegarde est faite à chaque action et à chaque tour) → fichier tronqué, JSON invalide → « Continuer » grisé et partie perdue ; un JSON valide mais incomplet fait lever une erreur de script au chargement.
- Piste : écrire dans `savegame.json.tmp` puis renommer, garder `savegame.bak`, et valider les clés obligatoires dans `_read_save` (ou `.get` avec défaut dans `from_dict`).

**I2 — Chaman orc inatteignable** [V]
- Preuve : `Data.FOE["chaman_orc"]` (Data.gd, section orcs) ; absent de `Contracts._ORCS` (`contracts.gd:~99`), de `Campaign.garrison("lair")` et `citadel_waves` (`campaign.gd:183-203`) ; seules références hors données : `tests/suites/suite_batailles.gd:549,652`.
- Conséquence : le comportement « soigner un allié » de l'IA (`ai.gd:88-94`), `BattleState.can_heal` et tout le travail associé ne se voient jamais en partie.
- Piste : ajouter un `chaman_orc` aux compositions orcs de danger 2-3 et à la citadelle (une ligne par tableau).

**I3 — Fin de tour / annulation accidentelles** [V]
- Preuve : `battle.gd:490-492` (Retour arrière annule un déplacement sans Ctrl ; Espace/Entrée/Entrée pavé → `_end_turn()`), `Settings.gd:93` (`confirm_end_turn` faux par défaut).
- Conséquence : un appui parasite (Entrée pour valider un autre bouton, Espace) gaspille les PA d'un homme ; en cas de modale fermée juste avant, le risque existe.
- Piste : exiger une confirmation s'il reste ≥ la moitié des PA, ou activer `confirm_end_turn` par défaut ; réserver Retour arrière à Ctrl+Z (déjà documenté).

**I4 — Deux entrées « Nouvelle partie » qui divergent** [V lu / effet à l'écran S]
- Preuve : `main.gd:183-199` (en-tête : « Tout effacer ? » → `Game.new_game(-1, level)` seul) contre `main.gd:309-315` (menu : `Game.new_game`, `Tutorial.start()` si `!Settings.tutorial_seen`, puis `_go(_enter_game)`).
- Conséquence : recommencer depuis l'en-tête ne passe pas par le fondu/`_enter_game` ni par le tutoriel ; deux endroits à maintenir.
- Piste : factoriser une fonction `_start_new_game(level)` appelée par les deux.

### MINEUR

- **M1 — Aléa non sauvegardé** [V] : `to_dict` (`Game.gd:1543-1560`) enregistre `campaign_rng_state` mais ni `rng` ni `loot_rng`. Recharger = nouveaux jets (butin, combats, événements). Décision de conception : acceptable, mais rend le « save-scumming » trivial et les bugs non reproductibles depuis une sauvegarde.
- **M2 — Sauvegarde complète à chaque action** [S] : `JSON.stringify(to_dict())` du monde + de la bataille à chaque tour joueur (`Game.save`). Sans doute négligeable aujourd'hui ; à surveiller si la carte grossit.
- **M3 — Doublon de source de vérité audio** [V] : `Settings.music_gain()` / `sfx_gain()` (`Settings.gd:141-145`) ne sont utilisés que par un test (`suite_economie.gd:183`) ; `Audio.gd` calcule ses propres volumes (`Audio.gd:50`, `331`). Le test ne prouve donc pas le gain réellement appliqué.
- **M4 — Fonctions mortes** [V] : `Game.delete_save`, `Game.faction_here`, `Game.inv_give`, `Settings.quality_name`, `Settings.sfx_gain`, `Bonds.is_rival`, `Inventory.bag_has_items`, `Loot.dur_missing`, `Scenery.approach_cells`, `BattleFx.thud`, `UnitView.arrow_count` (aucun appel hors définition) ; `Game.perk_reset_cost`, `Bonds.is_friend`, `Inventory.unequip`, `BattleState.play_ai_turn` : tests seulement (`play_ai_turn` sert aux simulations).
- **M5 — Fichier .uid orphelin suivi par git** [V] : `tests/shots_monde.gd.uid` sans `shots_monde.gd`.
- **M6 — Fuites à la fin des tests** [V] : « 1427 ObjectDB instances were leaked », « 4 resources still in use at exit » (inoffensif, mais bruit qui masquerait une vraie fuite).
- **M7 — Bornes de sécurité** [S] : divisions par `hp_max` sans garde (`ai.gd:44-45`, `injuries.gd:29,41`) ; un `hp_max` ≤ 0 (trait « Fragile » −8 + blessures permanentes cumulées) n'est pas exclu explicitement. Les 4 000 batailles précédentes n'ont rien montré.
- **M8 — Peu de sons** [V] : 13 événements seulement ; rien pour les capacités (étourdir, huile, filet, feu), pas de son par type d'arme (toutes les attaques de mêlée partagent `hit_*`), pas de sons d'interface hors `click` (`ui_kit.gd:168`), ni pour la fin de campagne ou les événements de route. `bow_thud_0.ogg` est inutilisé (signalé dans CREDITS).
- **M9 — Licences de polices** [V] : `assets/fonts/` ne contient pas le texte de l'OFL (CREDITS seul le nomme). La licence OFL demande de l'accompagner à la redistribution.
- **M10 — Documentation désynchronisée** [V] : CLAUDE.md décrit encore « 3 contrats à la fois », « Max 10 hommes » dans les règles portées, alors que le jeu a des contrats par lieu et `MAX_ROSTER_CAP = 13` (`Data.gd:367`) ; à mettre à jour (le résumé « État actuel » est lui à jour).
- **M11 — Boutiques à deux paliers seulement** [V] : `Data.SHOPS` = `village` / `city` (`Data.gd:175-185`) ; CLAUDE.md note déjà « nouveaux types de ville » comme non fait.
- **M12 — Indicatif seulement : taux de victoire de l'IA joueur dans la simulation** [V] : brigands 8/32, orcs 3/32, goules 15/32, morts-vivants 10/32, monstres 6/32 (bot, aucun équilibrage fait volontairement) — les orcs/monstres paraissent très durs pour un bot ; à surveiller côté joueur si une session d'équilibrage est lancée.
- **M13 — Ressource ajoutée sans lien clair** [V] : `assets/icons/poings|morsure|massue_geant.svg` sont des copies d'autres icônes (déjà créditées) — correct, mais l'arme unique de chaque monstre n'a pas d'icône propre.
- **M14 — Armes uniques sans fichier d'icône propre** [V] : `u_*` utilisent le `look` de leur modèle (`Uniques.look`, `item_icons.gd:15`) — fonctionnel, pas un bug ; l'objet unique n'est donc pas reconnaissable à l'icône dans l'inventaire.

## 3. Chaînes de bout en bout (lues dans le code)

Nouvelle partie → ville → contrat → voyage → bataille → résumé → butin → vente/équipement → niveaux/talents → repos/réparation → sauvegarde/chargement → fin : chaque maillon existe et est couvert par smoke_ui + simulations. Points précis :
- Sérialisation : `Game.to_dict` couvre or, jour, renom, compagnie (talents, traits, liens, blessures, sacs), monde, bataille (cases, objets, objectifs, réserves), inventaire, butin en attente, vivres, moral, bâtiments, factions, histoires, campagne, stats, bannière [V `Game.gd:1543-1560`, `unit.gd:272-289`, `battle_state.gd:1112-1137`].
- Migrations : anciennes sauvegardes (< version 2) rejetées silencieusement ; champs récents ont des valeurs par défaut (difficulté Normal, vivres, bâtiments, sites hostiles régénérés) [V `Game.gd:1563-1640`]. Pas de migration de version 1 → 2 (la sauvegarde ancienne est perdue sans message).
- Fin de partie : `game_over` géré par `camp.gd:104-112` et `main.gd:222-234` ; `ending_pending` → écran de fin puis mode libre [V].
- Succès : 31 définis, tous les compteurs `stat_add`/ctx lus ont une source (`Game.gd:118-142`) [V par grep].
- Contenu : toutes les clés `Data.FOE` sont générées sauf `chaman_orc` (I2) ; les 7 origines `Data.BG` sont proposées par `Data.SHOPS` ; les 17 traits, 28 talents, 12 capacités ont des textes français et sont consommés par des tables (pas de clé déclarée sans usage, hors recrues/histoires lues dynamiquement) [V]. Événements et histoires : les premières étapes entrent dans le tirage (`events.gd:459-472`), les suites par `pending_events` [V lu].

## 4. Interface et textes

- Aucun texte anglais visible repéré par grep dans `scenes/` [V].
- Modales : la plupart se ferment par Échap (`battle.gd:474-476`, `inventory_screen.gd:276`, `map_screen.gd:103-116`, pause `main.gd:336`) [V]. Je n'ai pas piloté l'interface : débordements de texte et écrans à liste vide sont **non vérifiés** [S].
- Raccourcis : pas de conflit détecté entre bataille (H, W, Tab, Z, 1-9, Espace, F1/?) et carte/inventaire (I, C, H, Tab, Espace) [V lu], hors I3.

## 5. Distribution

- Export : preset avec icône, versions 0.2.0, métadonnées (`export_presets.cfg:32-40`) ; `build/` exclu de git ; dépôt ≈ 26 Mo / 786 fichiers suivis [V].
- Crédits : polices, icônes d'objets, sons, musiques couverts par `assets/CREDITS.md` ; `assets/ui/`, `splash.png`, `app_icon.*` et sprites sont générés par `tools/` [V].

## 6. Manques par rapport à Battle Brothers (idées de joueur)

1. Brouillard de guerre / vision par camp en journée (seulement la nuit aujourd'hui).
2. Chariots de ravitaillement et d'équipement, taille de compagnie évolutive plus tôt, « retinue » (bannière, mascotte) à la BB.
3. Ambitions de compagnie (objectifs au choix, bonus) et événements d'équipe plus nombreux.
4. Origines/arrière-plans plus nombreux (BG = 7), avec compétences et traits propres.
5. Plusieurs étages de la carte du monde : villes de types différents (forgeron, port, château), marchands spécialisés.
6. Armes à quatre-cinq familles de capacités chacune, armes à deux mains versus à une main plus distinctes, armures avec casques/cuirasses par pièce nommée.
7. Sons par arme, cris des blessés, ambiance de bataille ; voix/bruitages d'événements.
8. Contrats plus variés (négociation de la prime, clauses, réputation de contrat), chronologie des crises.
9. Tactile/manette, accessibilité (daltonisme, contraste, sous-titres sonores).
10. Carte de bataille plus grande et terrains à étages, bâtiments à investir.

## 7. Trois actions recommandées en premier

1. **Sécuriser la sauvegarde** (I1) : écriture atomique + `.bak` + validation à la lecture. Petit.
2. **Brancher le chaman orc** (I2) et unifier « Nouvelle partie » (I4). Petit.
3. **Protéger la fin de tour** (I3) : confirmation par défaut ou Ctrl pour Retour arrière. Petit.
