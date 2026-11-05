# Crédits des ressources

## Polices (SIL Open Font License 1.1, texte intégral et droits d'auteur dans `fonts/OFL.txt`) — dépôt github.com/google/fonts
- **Pirata One** (Copyright 2012 Rodrigo Fuenzalida, Nicolas Massi ; nom réservé « Pirata ») — `fonts/PirataOne-Regular.ttf`
- **Alegreya Sans** (Copyright 2013 The Alegreya Sans Project Authors, Huerta Tipográfica — github.com/huertatipografica/Alegreya-Sans) — `fonts/AlegreyaSans-Regular.ttf`, `AlegreyaSans-Bold.ttf`

## Icônes d'objets (CC BY 3.0) — https://game-icons.net, dépôt github.com/game-icons/icons
Recolorées (parchemin) ; fond retiré. Auteurs : Lorc, Delapouite, Lucas (lucasms), Willdabeast.
- `icons/gourdin.svg` (wood-club), `fourche.svg` (pitchfork), `griffes.svg`/`griffesL.svg` (claws), `casque.svg` (light-helm), `gambison.svg` (leather-armor) — Delapouite
- `icons/arc.svg` (bow-arrow) — Delapouite
- `icons/lance.svg` (spear-hook), `hache.svg` (battle-axe), `masse.svg` (spiked-mace), `epee.svg` (broadsword), `capuchon.svg` (hood), `heaume.svg` (visored-helm), `mailles.svg` (mail-shirt), `brigandine.svg` (lamellar) — Lorc
- `icons/tunique.svg` (shirt) — Lucas
- `icons/bouclier.svg` (round-shield) — Willdabeast
- `icons/hallebarde.svg` (halberd), `javelot.svg` (thrown-spear) — Lorc ; `icons/fleau.svg` (flail) — Delapouite (CC BY 3.0, recolorées comme les autres)
- `icons/arbalete.svg` : dessin original réalisé pour le projet (aucune source externe).
- `icons/poings.svg` : copie de `griffes.svg` (icône de repli pour « Poings nus », arme implicite d’un homme sans arme).
- `icons/morsure.svg`, `icons/massue_geant.svg` : copies des icônes `griffes.svg` / `gourdin.svg` (armes naturelles de monstres, jamais en vente) — mêmes auteurs et licence (Delapouite, CC BY 3.0)

## Effets sonores — `audio/sfx/`
- **Kenney Impact Sounds** (Kenney, www.kenney.nl) — CC0 ; copie via github.com/Boyquotes/kenney-impact-sounds-for-godot : `hit_flesh_*` (impact_punch_medium), `hit_armor_*` (impact_metal_medium), `death_*` (impact_soft_heavy), `step_*` (footstep_grass), `shield_wall_*` (impact_plate_heavy), `bow_thud_0` (impact_wood_medium, inutilisé).
- **Kenney RPG Audio, « 50 RPG sound effects »** (Kenney Vleugels, www.kenney.nl) — CC0 ; https://opengameart.org/content/50-rpg-sound-effects : `miss_*` (knifeSlice, drawKnife), `coins_*` (handleCoins), `click_*` (metalClick, bookFlip, metalLatch).
- **RandomMind** — CC0 ; OpenGameArt : `victory.mp3` (https://opengameart.org/content/medieval-victory-theme), `defeat.mp3` (https://opengameart.org/content/medieval-defeat-theme).
- `bow_*.wav`, `horn_0.wav`, `levelup_0.wav`, `buy_*.wav`, `sell_*.wav`, `drop_*.wav`, `paper_open_*.wav`, `paper_close_*.wav`, `hire_0.wav`, `repair_*.wav`, `speed_0.wav`, `perk_0.wav`, `town_0.wav` : générés procéduralement (`tools/gen_audio.gd`), œuvre originale du projet.

## Musique et ambiance — `audio/music/`
- **RandomMind** — CC0 ; OpenGameArt : `battle.mp3` (https://opengameart.org/content/medieval-battle), `map.mp3` (https://opengameart.org/content/medieval-exploration), `town.mp3` (https://opengameart.org/content/medieval-market-day, version Loop), `menu.mp3` (https://opengameart.org/content/medieval-kings-feast).
- `ambience_map.wav` : généré procéduralement (`tools/gen_audio.gd`).

## Icônes de talents (CC BY 3.0) — https://game-icons.net, dépôt github.com/game-icons/icons
Lot « talents » : `assets/perk_icons/*.svg` (76 fichiers, un par talent). **50** viennent de game-icons.net (CC BY 3.0 ; fond noir retiré, silhouette blanche teintée au rendu par `PerkIcon`) ; les **26 autres** — maîtrises `spec_fleau`, `spec_gourdin`, `spec_hast`, `spec_arbalete`, `spec_poings`, armures `ma_*` (5) et experts `ex_*` (16) — sont une **œuvre originale du projet**, dessinée par code (`tools/gen_perk_icons.py`, aucune ressource externe, licence du projet). Auteurs game-icons : Lorc, Delapouite, Skoll, Willdabeast, Sbed.
- Lorc : crossed-swords, sword-clash, meditation, trade, open-book, bandage-roll, piercing-sword, plain-dagger, dodging, boot-prints, broadsword, target-arrows, bowman, wolf-howl, shouting, axe-swing, thrown-spear, thor-fist, foot-trip, visored-helm, footprint, anvil, spyglass, spiked-mace, sprint, beast-eye, half-heart, barbed-spear, helmet-head-shot, guarded-tower, mountains, sword-wound, wind-slap, breastplate, crowned-heart, lightning-frequency
- Delapouite : biceps, lungs, team-upgrade, heart-shield, healing, spartan-helmet, coins-pile, charging-bull, rock-golem, stone-wall, eye-target
- Skoll : bullseye — Willdabeast : round-shield — Sbed : duel

## Icônes d'objets, jeu `icons_items/` (CC BY 3.0) — https://game-icons.net
Généré par `tools/gen_item_icons.py` (contour sombre + dégradé or) : formes des icônes ci-dessus, plus, dans `tools/icon_src/` : `delapouite__stone-pile` (pierres de jet), `lorc__fire-bottle` (huile), `lorc__fishing-net` (filet), `delapouite__bread` (pain), `delapouite__steak` (viande), `lorc__cheese-wedge` (fromage), `lorc__knapsack` (ration). Auteurs : Lorc, Delapouite. Les icônes d'objets uniques sont les formes ordinaires ornées (halo, étincelles) ; l'icône « ? » est un dessin original.

## Ressources originales du projet (aucune source externe)
- `sprites/*.svg` (calques des figurines, armes, armures, décors) : générés par `tools/gen_sprites.py` / `tools/gen_sprites_more.py`.
- `ui/*.png` (9-patch « cuir et parchemin ») : dessinés par `tools/gen_ui.gd`.
- `splash.png` : `tools/gen_splash.gd` ; `app_icon.svg`, `app_icon.ico`, `icons_png/icon_*.png` : `tools/gen_icon.gd` et `tools/make_ico.py`.
- Les textures, décalcomanies, effets et cartes sont produits par le code du jeu (aucun fichier image externe).
- Sons d'interface `buy_*`, `sell_*`, `drop_*`, `perk_0`, `paper_open_*`, `paper_close_*`, `speed_0`, `town_0`, `repair_*`, `hire_0` (`assets/audio/sfx/`) : générés procéduralement par `tools/gen_audio.gd` (aucune ressource externe), libres de droits.
