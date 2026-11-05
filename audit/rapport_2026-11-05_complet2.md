# Audit complet n°2 (2026-11-05)

Lecture seule : seul ce fichier a été écrit dans le dépôt. `settings.cfg` de l'utilisateur sauvegardé avant les captures et restauré après (vérifié identique).
**[V]** vérifié (exécuté ou lu, avec référence) — **[S]** supposé / non exécuté.

## Résumé (10 lignes)

- État général : **sain**, nettement plus solide qu'au premier audit. Import 0 avertissement ; tests **28 148 vérifications, 0 échec** ; smoke UI OK ; 300 batailles et 15 campagnes simulées : 0 échec, 0 erreur de script ; `git status` propre.
- Les 4 constats IMPORTANT du rapport 1 sont **corrigés** (sauvegarde atomique + `.bak`, chaman orc, confirmation de fin de tour, entrée unique « Nouvelle partie »).
- Grand monde : génération 135 ms, chemin 0,2 ms, monde sérialisé 17,8 Ko ; migration 80×50 réellement testée.
- Problèmes principaux : (1) noms de talents proches de ceux du jeu commercial, à faire relire (règle de provenance) ; (2) `CREDITS.md` périmé (50 icônes de talents annoncées, 76 présentes) et texte OFL absent ; (3) chemin d'achat ancien (`Game.buy`, `in_stock`) qui contourne le stock fini ; (4) à 1280×720 le tiroir « Détails » masque minimap, boutons et légende ; (5) quelques redessins/allocations par image sur la carte.
- Comptage : **BLOQUANT 0 — IMPORTANT 1 — MINEUR 13.**

## 1. Santé (vérifié)

| Contrôle | Résultat |
|---|---|
| `--headless --import` | exit 0, 0 ligne warning/erreur [V] |
| `tests/run_tests.gd` | 28 148 vérifications, 0 échec ; fuites de fin de run : 5 006 ObjectDB (1 427 au rapport 1), « 4 resources still in use » [V] |
| `tests/smoke_ui.gd` | OK [V] |
| `sim_battles` (300, graine 91000) / `sim_campaign` (15) | échecs 0, 0 « SCRIPT ERROR » [V] |
| Orphelins | aucun script orphelin ; `tests/shots_monde.gd.uid` sans .gd, toujours suivi par git [V] |
| TODO/FIXME | aucun [V] |
| 1427 → 5006 objets fuités en test | simple bruit croissant avec le nombre de suites (M6) |

## 2. Devenir des constats du rapport 1

| Ancien | Statut | Preuve |
|---|---|---|
| I1 sauvegarde fragile | **Corrigé** | `Game._write_json_safe` (`Game.gd:1824-1845`, .tmp vérifié + `.bak` + renommage) ; `_read_one` valide clés/types (`Game.gd:1862-1889`), repli sur `.bak` ; tests `suite_corrections.gd:35-102` |
| I2 chaman orc | **Corrigé** | `contracts.gd:108-109`, `campaign.gd:203` ; test `suite_corrections.gd:21` |
| I3 fin de tour | **Corrigé en grande partie** | `battle.gd:405-416` : confirmation si ≥ moitié des PA par la touche. **Reste** : Retour arrière annule un déplacement sans Ctrl (`battle.gd:498`), `confirm_end_turn` faux par défaut — voulu et documenté dans l'aide |
| I4 deux « Nouvelle partie » | **Corrigé** | `main.gd:226,350,374` → `_start_new_game` |
| M1 aléa non sauvegardé | **Toujours présent** | seul `campaign_rng_state` est écrit (`Game.gd:1734`) ; `rng` / `loot_rng` non (décision de conception) |
| M3 doublon `Settings.sfx_gain/music_gain` | Toujours présent | `Settings.gd:153,157` ; `music_gain` n'est appelée que par `suite_economie.gd:183` |
| M4 fonctions mortes | Toujours présentes, plus nombreuses | voir M4 ci-dessous |
| M5 .uid orphelin | Toujours présent | `tests/shots_monde.gd.uid` |
| M8 peu de sons | Inchangé (13 événements) | `Audio.EVENTS` |
| M9 texte OFL absent | **Toujours présent** | `assets/fonts/` : 3 .ttf sans licence |
| M10 CLAUDE.md désynchronisé | Partiellement : « État actuel » à jour, la section « Règles du jeu » (Max 10 hommes, 3 contrats) reste ancienne | `CLAUDE.md` |

## 3. Constats

### IMPORTANT

**I1 — Noms de talents à faire relire (provenance)** [V pour les noms, S pour la comparaison]
- La règle du projet interdit tout nom de talent ou texte copié du jeu commercial. Je n'ai ouvert aucun fichier de copie externe ; la comparaison ci-dessous vient de ma connaissance générale du jeu. Dépôt : aucun fichier ni texte « crack » hors `CLAUDE.md:97`, aucun .exe/.dll suivi [V].
- Noms de `Data.PERKS` qui sont des traductions courantes de talents/compétences du jeu d'origine : **Esquive** (Dodge), **Studieux** (Student), **Mur de lances** (Spearwall), **Tourbillon** (Whirlwind), **Riposte**, **Coup de grâce**, **Insaisissable**, **Increvable**, **Pied sûr**, **Second souffle**, **Cran**. Ce sont des mots courants et les effets sont propres au projet, donc le risque est faible, mais ils restent la partie la plus proche.
- Le découpage 7 rangs × 4 colonnes et « un talent du rang N exige N−1 talents » reprend la disposition du jeu d'origine (CLAUDE.md l'assume : « disposition seulement »).
- Piste : renommer 5 à 8 des noms ci-dessus (ex. Esquive → Pas de côté, Studieux → Apprenti zélé, Tourbillon → Moulinet) et garder ce choix dans une note du dépôt.

### MINEUR

- **M1 — Aléa `rng`/`loot_rng` non sérialisé** [V] : recharger permet de retenter butin et jets. Décision de conception à trancher.
- **M2 — `CREDITS.md` périmé** [V] : `CREDITS.md:30` annonce « 50 fichiers » d'icônes de talents ; `assets/perk_icons/` en contient 76. Les 26 icônes de maîtrise sont dessinées par code (`tools/gen_perk_icons.py`) mais ne sont pas déclarées comme œuvre originale.
- **M3 — Texte de la licence OFL absent** [V] : à ajouter à côté des polices (ou dans `CREDITS.md`).
- **M4 — Fonctions mortes ou seulement testées** [V] : `Game.delete_save`, `has_save`, `faction_here`, `inv_give`, `Settings.quality_name`, `sfx_gain`, `Bonds.is_rival`, `Factions.relation_label`, `Inventory.bag_has_items`, `Loot.dur_missing`, `Scenery.approach_cells`, `BattleFx.thud`, `UnitView.arrow_count`, `InventoryScreen.can_drop_on_member/drop_on_member`, `MapPlaces.paint_company/paint_label/paint_territories/paint_territory_names` (la carte a ses propres versions dans `map_view.gd:574`), `MapView.set_show_*` (appelées dynamiquement via `Settings.get`, `map_view.gd:163` : fausse alerte probable). Seulement testées : `Game.buy_provisions_full`, `equip_from_inventory`, `perk_reset_cost`, `Perks.abilities/build_problem/row_size/uncovered_gear`, `Formation.swap`, `Banner.default_setup`.
- **M5 — Ancien chemin d'achat** [V] : `Game.buy`, `Game.in_stock`, `Game.sell` (`Game.gd:679,1028,1106`) ne sont appelés par aucune scène, mais restent publics et contournent le stock fini (`buy_item`, `Game.gd:1162`). Deux sources de vérité ; un futur appel les réactiverait. Piste : les supprimer ou les faire passer par le stock.
- **M6 — Bruit des tests** [V] : fuites de fin de run en hausse (5 006 instances).
- **M7 — Assertion toujours vraie** [V] : `suite_grand_monde.gd:402` `gen_ms < 3000 or gen_ms < 9000` n'impose en fait que 9 s.
- **M8 — Pauvreté sonore** [V] : toujours 13 événements ; aucun son pour le marché (achat/vente utilisent `coins`), la formation, les talents appris.
- **M9 — Interface 1280×720** [V par captures] : le tiroir « Détails » (touche F) masque la minimap, les boutons ronds et le début du texte d'aide ; la légende (L) s'ouvre sous le tiroir, partiellement cachée ; le bandeau d'aide du bas est tronqué (« H : recent… »). À 1920 et 2560 les écrans testés tiennent. Piste : fermer l'un quand l'autre s'ouvre.
- **M10 — Statistiques sans libellé** [V par captures] : la fiche de personnage affiche ses 16 stats par icônes + barres seulement (infobulles seules) ; peu accessible. Même remarque pour « 40/70 » (vivres) du marché sans libellé visible.
- **M11 — Allocations par image sur la carte** [V lu] : `map_view.gd:~245-260` reconstruit à chaque image `_owners_signature`, `_visits_signature` (≈ 60 chaînes) et `nsig` ; `_frame`, `_dyn`, `_sky`, `_wx` sont redessinés à chaque image. Mesure non faite en jeu [S] ; coût probablement faible à 29 lieux.
- **M12 — Définition de la texture du monde** [V lu] : le grand monde utilise 2 pixels de moins par case (`map_terrain.gd:38-40`) : 4 px/case en qualité « Normale » (6 → 4), soit 720×480 pour un monde de 3600×2400 px affichés (5 px d'écran par pixel de texture). À fort zoom, le fond peut paraître flou [S, non vérifié en zoom].
- **M13 — Documentation** [V] : `CLAUDE.md` « Règles du jeu » toujours sur 10 hommes / 3 contrats ; `README.md` liste de fonctions à rafraîchir [S].

## 4. Intégration entre systèmes (lue, tests existants)

- **Formation × batailles spéciales** : `_deploy_party` est utilisé pour les 3 dispositions (embuscade/convoi/siège/nuit : `battle_state.gd:105,193,233`), avec repli sur la case libre la plus proche et dernier recours qui « dégage » une case (`cells[spot]["t"] = "g"`, ~l.318) — peut effacer un obstacle ou un décor sous l'unité, sans gravité. `deploy_slots` n'est pas sérialisé dans la bataille (inutile après le déploiement). Test `suite_formation.gd:184` couvre tous les plateaux [V].
- **Maîtrises × talents × traits × blessures** : `Unit.eff()` empile talents, maîtrises (`Perks.family_stat`), blessures, traits, état exposé sans plafond (`unit.gd:117-138`), seul `hit_chance` borne à 5-95 % ; empilement potentiellement fort mais sans bug détecté par 4 000+ batailles simulées. `eff()` est appelé très souvent (parcours de tous les talents) : coût CPU à surveiller si les unités par bataille augmentent [S].
- **Marché × inventaire × butin × vente** : `sell_item` → `Market.add_sold` remet l'objet en stock ; réserve pleine → vente d'office (`add_to_stash`, `Game.gd:1244`) ; prix de revente < prix d'achat (`Loot.sell_base` × `SELL_RATE`), donc pas d'arbitrage évident [V lu]. Stock ancien généré à la demande (`Game.gd:1120`), migration testée (`suite_marche.gd:117`).
- **Grand monde × contrats × factions × sauvegarde** : `World.from_dict` accepte l'absence de `gw/gh/grand/pois` (monde classique 80×50, `world.gd:805-861`), reconstruit les routes ; test d'ancienne sauvegarde `suite_grand_monde.gd:209-266` (jouable après chargement) [V]. Anciennes sauvegardes sans formation (`Formation.from_dict`, `Game.gd:1752`), sans stock (génération à la demande), sans bannière (`Banner.clean`) : défauts prévus et testés (`suite_formation`, `suite_marche`, `suite_contenu`).
- **Ce qui n'est pas testé** : un vieux fichier 80×50 contenant des factions humaines ou événements nés du grand monde — la migration réattribue les propriétaires (`Factions.assign_owners`) mais ne vérifie pas qu'un monde 80×50 n'a pas de faction manquante [S].

## 5. Performances du grand monde [V sauf mention]

| Mesure | Valeur |
|---|---|
| Génération du monde | 135 ms (29 lieux, 11 sites, 30 POI) |
| Territoires et frontières | 104 ms |
| `find_path` | 0,20 ms par chemin |
| Sérialisation du monde | 2 ms, 17 797 octets |
| Écriture de sauvegarde | + copie `.bak` à chaque écriture (coût disque doublé, négligeable ici) |
| Redessins par image | voir M11 |

## 6. Distribution

- `.gitignore` : `.godot/`, `*.tmp`, `build/` [V]. Dépôt : 1 110 fichiers suivis, ≈ 26 Mo `.git`, 2,5 Mo de texte ; assets 26 Mo (audio 22 Mo) [V].
- Crédits : voir M2/M3. Polices Pirata One / Alegreya Sans, icônes game-icons.net, audio Kenney/RandomMind (CC0), icônes d'objets : créditées [V]. Les perk_icons de maîtrise sont originales (code) mais non déclarées.
- `export_presets.cfg` : version 0.2.0 inchangée [V] — à incrémenter si une version est publiée [S].
- Provenance : aucune mention de fichier externe commercial dans le dépôt ; voir I1 pour les noms.

## 7. Interface (captures 1280 / 1920 / 2560 : contrats, fiche, talents, marché, options, carte) [V]

- Aucun débordement de texte repéré sur la fiche, le marché, les options ni l'arbre de talents à 1280×720 ; contrats : cartes centrées à gauche, la moitié droite est vide (disposition, pas un bug).
- Les écrans testés tiennent à 2560×1440 (échelle correcte).
- Non captés : bataille, résumé, formation depuis la ville, écran de fin, tutoriel, création de compagnie [S, non vus dans cet audit].
- Mes touches Échap synthétiques n'ont pas fermé les modales empilées (artefact probable de l'injection d'événements) : à retester à la main.

## 8. Manques par rapport à Battle Brothers (idées)

1. Brouillard de guerre en journée ; vision par camp.
2. Tactile/manette ; accessibilité (daltonisme, contraste, libellés de stats).
3. Sons par arme et par capacité, voix/cris, ambiance de bataille.
4. Plus d'origines (7 seulement) et de villes spécialisées (forge, port, château).
5. Ambitions de compagnie, objectifs de campagne au choix.
6. Chariots de ravitaillement, vente/échange entre factions.
7. Plateau plus grand, étages, bâtiments à investir.
8. Évolution des contrats : négociation, clauses.

## 9. Actions recommandées

1. Relire et renommer quelques talents (I1) — rapide, règle de provenance.
2. Mettre `CREDITS.md` à jour (76 icônes, 26 originales) et ajouter le texte OFL (M2, M3).
3. Supprimer ou rebrancher `Game.buy/in_stock/sell` et le code mort de la carte (M4, M5).
4. Corriger la superposition tiroir/légende/aide à 1280×720 (M9).
5. Trancher la reproductibilité de l'aléa (M1) et, si besoin, mesurer les redessins de la carte (M11).
