# Crédits des ressources

## Polices (SIL Open Font License 1.1) — dépôt github.com/google/fonts
- **Pirata One** (Rodrigo Fuenzalida) — `fonts/PirataOne-Regular.ttf`
- **Alegreya Sans** (Juan Pablo del Peral, Huerta Tipográfica) — `fonts/AlegreyaSans-Regular.ttf`, `AlegreyaSans-Bold.ttf`

## Icônes d'objets (CC BY 3.0) — https://game-icons.net, dépôt github.com/game-icons/icons
Recolorées (parchemin) ; fond retiré. Auteurs : Lorc, Delapouite, Lucas (lucasms), Willdabeast.
- `icons/gourdin.svg` (wood-club), `fourche.svg` (pitchfork), `griffes.svg`/`griffesL.svg` (claws), `casque.svg` (light-helm), `gambison.svg` (leather-armor) — Delapouite
- `icons/arc.svg` (bow-arrow) — Delapouite
- `icons/lance.svg` (spear-hook), `hache.svg` (battle-axe), `masse.svg` (spiked-mace), `epee.svg` (broadsword), `capuchon.svg` (hood), `heaume.svg` (visored-helm), `mailles.svg` (mail-shirt), `brigandine.svg` (lamellar) — Lorc
- `icons/tunique.svg` (shirt) — Lucas
- `icons/bouclier.svg` (round-shield) — Willdabeast

## Effets sonores — `audio/sfx/`
- **Kenney Impact Sounds** (Kenney, www.kenney.nl) — CC0 ; copie via github.com/Boyquotes/kenney-impact-sounds-for-godot : `hit_flesh_*` (impact_punch_medium), `hit_armor_*` (impact_metal_medium), `death_*` (impact_soft_heavy), `step_*` (footstep_grass), `shield_wall_*` (impact_plate_heavy), `bow_thud_0` (impact_wood_medium, inutilisé).
- **Kenney RPG Audio, « 50 RPG sound effects »** (Kenney Vleugels, www.kenney.nl) — CC0 ; https://opengameart.org/content/50-rpg-sound-effects : `miss_*` (knifeSlice, drawKnife), `coins_*` (handleCoins), `click_*` (metalClick, bookFlip, metalLatch).
- **RandomMind** — CC0 ; OpenGameArt : `victory.mp3` (https://opengameart.org/content/medieval-victory-theme), `defeat.mp3` (https://opengameart.org/content/medieval-defeat-theme).
- `bow_*.wav`, `horn_0.wav`, `levelup_0.wav` : généré procéduralement (`tools/gen_audio.gd`), libre de droits.

## Musique et ambiance — `audio/music/`
- **RandomMind** — CC0 ; OpenGameArt : `battle.mp3` (https://opengameart.org/content/medieval-battle), `map.mp3` (https://opengameart.org/content/medieval-exploration), `town.mp3` (https://opengameart.org/content/medieval-market-day, version Loop), `menu.mp3` (https://opengameart.org/content/medieval-kings-feast).
- `ambience_map.wav` : généré procéduralement (`tools/gen_audio.gd`).
- `icons/hallebarde.svg` (halberd), `javelot.svg` (thrown-spear) — Lorc ; `icons/fleau.svg` (flail) — Delapouite (CC BY 3.0, recolorées comme les autres)
- `icons/arbalete.svg` : dessin original réalisé pour le projet (aucune source externe).
- `icons/poings.svg` : copie de `griffes.svg` (icône de repli pour « Poings nus », arme implicite d’un homme sans arme).
- `icons/morsure.svg`, `icons/massue_geant.svg` : copies des icônes `griffes.svg` / `gourdin.svg` (armes naturelles de monstres, jamais en vente) — mêmes auteurs et licence (Delapouite, CC BY 3.0)

## Icônes de talents (CC BY 3.0) — https://game-icons.net, dépôt github.com/game-icons/icons
Lot « talents » : `assets/perk_icons/*.svg` (50 fichiers, un par talent ; fond noir retiré, silhouette blanche teintée au rendu par `PerkIcon`). Auteurs : Lorc, Delapouite, Skoll, Willdabeast, Sbed.
- Lorc : crossed-swords, sword-clash, meditation, trade, open-book, bandage-roll, piercing-sword, plain-dagger, dodging, boot-prints, broadsword, target-arrows, bowman, wolf-howl, shouting, axe-swing, thrown-spear, thor-fist, foot-trip, visored-helm, footprint, anvil, spyglass, spiked-mace, sprint, beast-eye, half-heart, barbed-spear, helmet-head-shot, guarded-tower, mountains, sword-wound, wind-slap, breastplate, crowned-heart, lightning-frequency
- Delapouite : biceps, lungs, team-upgrade, heart-shield, healing, spartan-helmet, coins-pile, charging-bull, rock-golem, stone-wall, eye-target
- Skoll : bullseye — Willdabeast : round-shield — Sbed : duel

## Icônes d'objets, jeu `icons_items/` (CC BY 3.0) — https://game-icons.net
Généré par `tools/gen_item_icons.py` (contour sombre + dégradé or) : formes des icônes ci-dessus, plus, dans `tools/icon_src/` : `delapouite__stone-pile` (pierres de jet), `lorc__fire-bottle` (huile), `lorc__fishing-net` (filet), `delapouite__bread` (pain), `delapouite__steak` (viande), `lorc__cheese-wedge` (fromage), `lorc__knapsack` (ration). Auteurs : Lorc, Delapouite. Les icônes d'objets uniques sont les formes ordinaires ornées (halo, étincelles) ; l'icône « ? » est un dessin original.
