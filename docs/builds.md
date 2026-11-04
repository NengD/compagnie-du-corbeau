# Builds spécialisés : maîtrises d'armes et d'armures

Document généré par `tools/gen_builds_doc.gd` depuis les données du jeu (`Data.WEAPON_FAMILIES`, `Data.ARMOR_FAMILIES`, `Data.PERKS`, `Data.BUILDS`). Ne pas l'éditer à la main.

## Le principe

Chaque arme et chaque armure appartient à une **famille**. Toute arme reste utilisable sans restriction ; c'est la **maîtrise** de la famille (rang 4 de l'arbre) qui fait un spécialiste, puis un **talent expert** (rang 6, qui exige la maîtrise) renforce son identité et ouvre souvent une capacité signature.
Les effets ne comptent que si l'équipement RÉEL de l'homme est de la famille : la maîtrise de l'épée ne fait rien avec une hache en main. Les armes uniques (Lame du Corbeau, Fend-Crâne…) comptent dans la famille de leur modèle.
Un point de talent par niveau (niveaux 2 à 11, soit 10 points) ; un talent du rang N exige d'avoir appris N−1 talents. Dans l'arbre, la fiche d'un talent de maîtrise indique s'il est **actif** ou **inactif** avec l'équipement actuel de l'homme.

## Familles d'armes

| Famille | Armes | Maîtrise (rang 4) | Expert (rang 6) | Talents recommandés | Style de jeu |
|---|---|---|---|---|---|
| Épées | Épée d'armes, Lame du Corbeau | Maître d'épée | Riposte | Bretteur, Vif, Duelliste | Duelliste précis : Fente à prix d'attaque, ripostes gratuites. |
| Haches | Hache, Fend-Crâne | Fendeur | Boucher | Lame affûtée, Force brute, Coup de grâce | Briseur d'armure : fend boucliers et plates, vise la tête. |
| Masses | Masse d'armes, Glas de fer | Fracasseur | Marteleur | Regard glaçant, Dur à cuire, Porteur de plates | Étourdisseur : traverse l'armure, enchaîne sur les étourdis. |
| Fléaux | Fléau d'armes | Maître du fléau | Tourbillon | Garde ferme, Rempart, Mur vivant | Bretteur de ligne : ignore les boucliers, frappe deux ennemis, Tourbillon. |
| Gourdins | Gourdin | Assommeur | Matraqueur | Endurant, Vif, Croc-en-jambe | Harceleur : coups peu fatigants qui étourdissent, arme pauvre mais agile. |
| Lances | Lance, Lance de l'Aigle | Lancier | Mur de lances | Garde ferme, Rempart, Mur vivant | Mur de lances : repousse, frappe d'abord celui qui approche. |
| Armes d'hast | Fourche, Hallebarde | Piquier | Faucheur | Pied sûr, Croc-en-jambe, Frappe vive | Piquier : deux cases de portée, faucher pour clouer l'ennemi. |
| Arcs | Arc de chasse, Arc des Ronces | Tireur d'élite | Œil de lynx | Tireur posté, Esquive, Pas léger | Archer : aucun malus au contact, portée et tir précis. |
| Arbalètes | Arbalète | Arbalétrier | Perce-armure | Lame affûtée, Tireur posté, Prédateur | Tireur lent mais lourd : recharge abrégée, carreaux perforants. |
| Javelots | Javelots | Lanceur | Volée | Pied sûr, Pas léger, Montagnard | Tirailleur : volée de javelots puis décrochage. |
| Mains nues | Poings nus | Pugiliste | Poing d'acier | Duelliste, Frappe vive, Insaisissable | Moine : mains nues, esquive, étourdissements. |
| Boucliers | Bouclier rond | Rempart | Bastion | Garde ferme, Mur vivant, Gardien | Tank : mur de boucliers peu cher, voisins protégés. |

## Familles d'armures

| Famille | Pièces | Maîtrise (rang 4) | Expert (rang 6) | Talents recommandés | Style de jeu |
|---|---|---|---|---|---|
| Tissu léger | Tête nue, Capuchon matelassé, Rien, Tunique de lin | Foulée légère | Feu follet | Vif, Pas léger, Insaisissable | Léger : initiative et esquive, se bat avant les autres. |
| Matelassé | Gambison | Bourre épaisse | Double bourre | Souffle long, Second souffle, Camaraderie | Intermédiaire : armure effective, endurance, moins de blessures. |
| Mailles | Haubert de mailles, Cotte de la Nuit | Maillons serrés | Cotte maîtresse | Parade, Tête dure, Dur à cuire | Fantassin : moins de poids, résiste aux lames. |
| Plates lourdes | Heaume fermé, Heaume du Veilleur, Brigandine, Brigandine du Roi déchu | Porteur de plates | Forteresse | Port d'armure, Dur à cuire, Regard glaçant | Forteresse : poids sans fatigue, initiative lourde, inébranlable. |
| Casques | Casque à nasal, Casque du Loup gris | Tête dure | Heaume vissé | Nuque protégée, Tête froide, Cran | Tête protégée : peu de coups à la tête, résiste au choc. |

## Ce que fait chaque maîtrise

- **Épées** — *Maître d'épée* : Épées : +10 % au toucher ; Fente ne coûte plus de PA en plus.
  - *Riposte* (expert) : Épée en main : quand un ennemi le rate au corps à corps, il riposte aussitôt, sans PA (1 fois par manche).
- **Haches** — *Fendeur* : Haches : +15 % de dégâts à l'armure ; chaque coup sur un bouclier l'abîme de 4 points de plus.
  - *Boucher* (expert) : Hache en main : 10 points de plus de chances de viser la tête ; ouvre « Taille en deux » (2 PA de plus : ×1,25 dégâts, armure ×1,6).
- **Masses** — *Fracasseur* : Masses : traversent 10 points de plus l'armure ; 10 % de chances d'étourdir sur un coup qui touche.
  - *Marteleur* (expert) : Masse en main : +20 % de dégâts contre une cible étourdie ou brisée ; ouvre « Marteler » (étourdit à coup sûr, ×1,2 dégâts).
- **Fléaux** — *Maître du fléau* : Fléaux : contourne 10 points de plus de bouclier ; le coup balaie un second ennemi adjacent (−10 au toucher, 60 % des dégâts).
  - *Tourbillon* (expert) : Fléau en main : ouvre « Tourbillon » (frappe tous les ennemis adjacents) ; Briser le bouclier coûte 1 PA de moins.
- **Gourdins** — *Assommeur* : Gourdins : chaque coup coûte 3 fatigue de moins, 12 % de chances d'étourdir ; Assommer ne coûte plus de PA en plus.
  - *Matraqueur* (expert) : Gourdin en main : +10 % de dégâts ; ouvre « Matraquer » (1 PA de plus : étourdit à coup sûr, test de moral à −10).
- **Lances** — *Lancier* : Lances : +10 % au toucher ; Recul ne coûte plus de PA en plus.
  - *Mur de lances* (expert) : Lance en main : attaque gratuite sur tout ennemi qui vient à son contact (1 fois par manche) ; elle repousse l'ennemi touché.
- **Armes d'hast** — *Piquier* : Fourches et hallebardes : +8 % au toucher, +10 % contre une cible à 2 cases, 1 PA de moins par coup ; Croc coûte 1 PA de moins.
  - *Faucheur* (expert) : Arme d'hast en main : +5 % au toucher contre une cible à 2 cases ; ouvre « Faucher » (la cible ne peut plus bouger à son prochain tour).
- **Arcs** — *Tireur d'élite* : Arcs : +10 % de dégâts, aucun malus de tir au contact ; Tir ajusté et Flèche enflammée coûtent 1 PA de moins.
  - *Œil de lynx* (expert) : Arc en main : +2 de portée, malus de distance réduit (−2 au lieu de −3 par case) ; ouvre « Tir précis » (+20 % au toucher, 25 % de plus de viser la tête).
- **Arbalètes** — *Arbalétrier* : Arbalètes : la recharge coûte 2 PA et 3 fatigue de moins, traversent 10 points de plus l'armure.
  - *Perce-armure* (expert) : Arbalète en main : +5 % au toucher, Tir ajusté coûte 1 PA de moins ; ouvre « Carreau perforant » (armure ×1,3, traverse 15 points de plus).
- **Javelots** — *Lanceur* : Javelots : +10 % au toucher, +10 % de dégâts et 2 javelots de plus.
  - *Volée* (expert) : Javelots : 2 javelots de plus ; ouvre « Double lancer » (deux javelots d'un coup, 2 PA de plus).
- **Mains nues** — *Pugiliste* : Mains nues : dégâts doublés, +5 % au toucher, traverse 25 points de plus l'armure et la détruit deux fois plus vite, +6 en défense (mêlée et distance).
  - *Poing d'acier* (expert) : Mains nues : chaque coup coûte 1 PA de moins, 15 % d'étourdir ; ouvre « Direct au menton » (étourdit à coup sûr).
- **Boucliers** — *Rempart* : Avec un bouclier : +5 en défense de mêlée, +10 à distance ; le mur de boucliers coûte 1 PA et 4 fatigue de moins, le coup de bouclier 1 PA de moins.
  - *Bastion* (expert) : Bouclier : le mur de boucliers ne l'use plus deux fois plus vite, les alliés adjacents ont +5 en défense tant qu'il le tient, le coup de bouclier repousse.
- **Tissu léger** — *Foulée légère* : Tissu seul (tunique, capuchon ou rien) : +12 d'initiative, +4 en défense de mêlée, +6 à distance.
  - *Feu follet* (expert) : Tissu seul : +8 d'initiative, +4 en défense, une case de fatigue en moins par pas, et les attaques d'opportunité contre lui ont 25 % de moins de chances de toucher.
- **Matelassé** — *Bourre épaisse* : Gambison : +12 d'armure effective (corps et tête, tant qu'il reste de l'armure) et +12 d'endurance.
  - *Double bourre* (expert) : Gambison : encore 10 points d'armure effective ; deux fois moins de risques de blessure.
- **Mailles** — *Maillons serrés* : Mailles : 3 points de poids en moins ; l'armure subit 15 % de dégâts en moins des armes tranchantes (épées, haches).
  - *Cotte maîtresse* (expert) : Mailles : 2 points de poids en moins ; l'armure et les PV subissent encore 15 % de dégâts en moins des armes tranchantes.
- **Plates lourdes** — *Porteur de plates* : Plates (brigandine, heaume) : le poids ne pèse plus sur la fatigue ni sur le déplacement, mais l'initiative baisse de 30 % du poids en plus.
  - *Forteresse* (expert) : Plates : 8 points d'armure effective, impossible à repousser, 40 % de chances de résister à un étourdissement.
- **Casques** — *Tête dure* : Casque à nasal ou casque du Loup : 15 points d'armure effective à la tête, 8 points de moins de chances d'être visé à la tête.
  - *Heaume vissé* (expert) : Casque : 10 points d'armure effective à la tête de plus, +8 en détermination, 40 % de chances de résister à un étourdissement.

## Archétypes de builds (niveau 11, dans l'ordre d'apprentissage)

Chaque liste tient dans les 10 points d'un homme de niveau 11, dans l'ordre : rangs et prérequis sont respectés (vérifié par les tests).

### Duelliste à l'épée

*Esquive, précision et ripostes : un contre un, sans allié collé.*  Famille d'armes : **Épées** · armure : **Tissu léger**.

1. **Bretteur** (rang 1) — Précision de base.
2. **Vif** (rang 1) — Initiative : frapper avant les autres.
3. **Parade** (rang 1) — Défense de mêlée.
4. **Maître d'épée** (rang 4) — Maîtrise : +10 % au toucher, Fente au prix d'une attaque.
5. **Foulée légère** (rang 4) — Étoffe légère : initiative et esquive.
6. **Duelliste** (rang 5) — +8 en attaque et en défense quand personne n'est collé à lui.
7. **Riposte** (rang 6) — Riposte gratuite après chaque coup raté.
8. **Feu follet** (rang 6) — Les attaques d'opportunité le ratent presque toujours.
9. **Frappe vive** (rang 7) — Une attaque à 3 PA : Fente + déplacement.
10. **Insaisissable** (rang 7) — Passe entre les zones de contrôle.

### Briseur à la hache

*Détruit les armures et fend les boucliers ; tient la ligne en cotte de mailles.*  Famille d'armes : **Haches** · armure : **Mailles**.

1. **Bretteur** (rang 1) — Précision de base.
2. **Endurant** (rang 1) — Moins de fatigue par coup.
3. **Parade** (rang 1) — Défense de mêlée.
4. **Fendeur** (rang 4) — Maîtrise : dégâts d'armure +15 %, bouclier fendu.
5. **Lame affûtée** (rang 2) — +8 % de dégâts d'armure en plus.
6. **Maillons serrés** (rang 4) — Maillons serrés : moins lourd, résiste aux lames.
7. **Boucher** (rang 6) — Têtes plus visées et « Taille en deux ».
8. **Force brute** (rang 5) — Coup puissant pour finir.
9. **Cotte maîtresse** (rang 6) — Cotte maîtresse : encore moins de dégâts tranchants.
10. **Coup de grâce** (rang 7) — Plus de coups à la tête, fatals avec la hache.

### Fracasseur en plates

*Étourdit, traverse l'armure et encaisse sans bouger : l'enclume de la compagnie.*  Famille d'armes : **Masses** · armure : **Plates lourdes**.

1. **Bretteur** (rang 1) — Précision de base.
2. **Endurant** (rang 1) — Moins de fatigue par coup.
3. **Souffle long** (rang 2) — Endurance pour compenser l'effort.
4. **Fracasseur** (rang 4) — Maîtrise : traverse l'armure, étourdit parfois.
5. **Porteur de plates** (rang 4) — Plates : le poids ne fatigue plus (initiative lourde).
6. **Marteleur** (rang 6) — Marteler : étourdissement garanti, dégâts sur étourdis.
7. **Forteresse** (rang 6) — Forteresse : impossible à repousser, résiste à l'étourdissement.
8. **Regard glaçant** (rang 5) — Test de moral sur chaque coup qui blesse.
9. **Dur à cuire** (rang 5) — Moins de blessures.
10. **Second souffle** (rang 5) — Récupère plus de fatigue par tour.

### Fléau et bouclier

*Un mur de boucliers qui balaie : deux cibles par coup, bouclier ennemi contourné.*  Famille d'armes : **Fléaux** · armure : **Matelassé**.

1. **Bretteur** (rang 1) — Précision de base.
2. **Parade** (rang 1) — Défense de mêlée.
3. **Garde ferme** (rang 3) — +10 en défense avec un bouclier.
4. **Maître du fléau** (rang 4) — Maîtrise : contourne les boucliers, balaie un second ennemi.
5. **Rempart** (rang 4) — Rempart : mur de boucliers moins cher.
6. **Bourre épaisse** (rang 4) — Bourre épaisse : armure effective et endurance.
7. **Tourbillon** (rang 6) — Tourbillon : frappe tous les ennemis adjacents.
8. **Mur vivant** (rang 5) — +10 en défense dans le mur de boucliers.
9. **Camaraderie** (rang 2) — +3 en défense par allié adjacent.
10. **Double bourre** (rang 6) — Double bourre : encore plus d'armure, moins de blessures.

### Matraqueur de ruelle

*Arme pauvre, coups peu fatigants et étourdissants : le harceleur vif.*  Famille d'armes : **Gourdins** · armure : **Tissu léger**.

1. **Bretteur** (rang 1) — Précision de base.
2. **Endurant** (rang 1) — Moins de fatigue par coup.
3. **Vif** (rang 1) — Initiative.
4. **Assommeur** (rang 4) — Maîtrise : coups légers en fatigue, étourdit parfois, Assommer à prix réduit.
5. **Foulée légère** (rang 4) — Étoffe légère.
6. **Matraqueur** (rang 6) — Matraquer : étourdissement garanti et moral ébranlé.
7. **Feu follet** (rang 6) — Pas de fatigue en trop, attaques d'opportunité ratées.
8. **Croc-en-jambe** (rang 5) — Désarçonne pour le coup suivant.
9. **Prédateur** (rang 3) — +10 au toucher sur un ennemi brisé.
10. **Frappe vive** (rang 7) — Un coup de moins en PA.

### Mur de lances

*Tient une ligne : repousse et frappe d'abord tout ce qui approche.*  Famille d'armes : **Lances** · armure : **Matelassé**.

1. **Bretteur** (rang 1) — Précision de base.
2. **Parade** (rang 1) — Défense de mêlée.
3. **Garde ferme** (rang 3) — +10 en défense avec un bouclier.
4. **Lancier** (rang 4) — Maîtrise : +10 % au toucher, Recul à prix d'attaque.
5. **Rempart** (rang 4) — Rempart : bouclier plus efficace.
6. **Mur de lances** (rang 6) — Mur de lances : attaque gratuite sur qui approche.
7. **Mur vivant** (rang 5) — +10 en défense dans le mur.
8. **Bastion** (rang 6) — Bastion : les voisins gagnent +5 en défense.
9. **Camaraderie** (rang 2) — +3 en défense par allié adjacent.
10. **Bourre épaisse** (rang 4) — Bourre épaisse : armure effective et endurance.

### Piquier faucheur

*Frappe à deux cases et cloue les ennemis au sol avant qu'ils n'arrivent.*  Famille d'armes : **Armes d'hast** · armure : **Matelassé**.

1. **Bretteur** (rang 1) — Précision de base.
2. **Endurant** (rang 1) — Moins de fatigue par coup.
3. **Vif** (rang 1) — Initiative.
4. **Piquier** (rang 4) — Maîtrise : un PA de moins par coup, bonus à deux cases.
5. **Pied sûr** (rang 2) — Moins de fatigue en marchant.
6. **Bourre épaisse** (rang 4) — Bourre épaisse.
7. **Faucheur** (rang 6) — Faucher : la cible ne peut plus bouger.
8. **Croc-en-jambe** (rang 5) — Désarçonne avant le coup suivant.
9. **Double bourre** (rang 6) — Double bourre.
10. **Frappe vive** (rang 7) — Une attaque d'hast à 4 PA.

### Archer d'élite

*Tire de loin sans malus et ajuste : le premier à frapper, le dernier à bouger.*  Famille d'armes : **Arcs** · armure : **Tissu léger**.

1. **Œil sûr** (rang 1) — +10 en attaque à distance.
2. **Vif** (rang 1) — Initiative.
3. **Esquive** (rang 2) — +10 en défense à distance.
4. **Tireur posté** (rang 3) — +10 au toucher sans avoir bougé.
5. **Tireur d'élite** (rang 4) — Maîtrise : +10 % de dégâts, aucun malus au contact.
6. **Foulée légère** (rang 4) — Étoffe légère.
7. **Œil de lynx** (rang 6) — Portée +2 et « Tir précis ».
8. **Feu follet** (rang 6) — Esquive et mobilité.
9. **Pas léger** (rang 5) — Initiative et défense en équipement léger.
10. **Frappe vive** (rang 7) — Un tir de moins en PA.

### Arbalétrier perce-armure

*Peu de coups, gros dégâts : la recharge est abrégée et les carreaux traversent.*  Famille d'armes : **Arbalètes** · armure : **Casques**.

1. **Œil sûr** (rang 1) — +10 en attaque à distance.
2. **Endurant** (rang 1) — Moins de fatigue par tir.
3. **Lame affûtée** (rang 2) — +8 % de dégâts d'armure.
4. **Arbalétrier** (rang 4) — Maîtrise : recharge raccourcie, perce un peu plus.
5. **Tête dure** (rang 4) — Tête dure : casque plus solide.
6. **Perce-armure** (rang 6) — Carreau perforant : détruit l'armure.
7. **Heaume vissé** (rang 6) — Heaume vissé : détermination et résistance au choc.
8. **Tireur posté** (rang 3) — +10 au toucher sans avoir bougé.
9. **Nuque protégée** (rang 5) — Moins de coups à la tête.
10. **Prédateur** (rang 3) — +10 au toucher sur un ennemi brisé.

### Lanceur de javelots

*Tirailleur mobile : une volée de javelots puis il décroche.*  Famille d'armes : **Javelots** · armure : **Tissu léger**.

1. **Œil sûr** (rang 1) — +10 en attaque à distance.
2. **Vif** (rang 1) — Initiative.
3. **Endurant** (rang 1) — Moins de fatigue par jet.
4. **Lanceur** (rang 4) — Maîtrise : plus précis, plus de javelots.
5. **Pied sûr** (rang 2) — Moins de fatigue en marchant.
6. **Foulée légère** (rang 4) — Étoffe légère.
7. **Volée** (rang 6) — Volée : encore 2 javelots et Double lancer.
8. **Pas léger** (rang 5) — Initiative et défense en équipement léger.
9. **Montagnard** (rang 7) — Ignore les pénalités de terrain.
10. **Insaisissable** (rang 7) — Passe entre les zones de contrôle.

### Pugiliste

*Mains nues, sans armure : un moine esquiveur qui étourdit à répétition.*  Famille d'armes : **Mains nues** · armure : **Tissu léger**.

1. **Vif** (rang 1) — Initiative.
2. **Parade** (rang 1) — Défense de mêlée.
3. **Bretteur** (rang 1) — Précision de base.
4. **Pugiliste** (rang 4) — Maîtrise : dégâts doublés et défense.
5. **Foulée légère** (rang 4) — Étoffe légère.
6. **Poing d'acier** (rang 6) — Poing d'acier : coups à 3 PA, étourdit.
7. **Feu follet** (rang 6) — Les attaques d'opportunité le ratent presque toujours.
8. **Duelliste** (rang 5) — Seul au contact : +8 en attaque et en défense.
9. **Frappe vive** (rang 7) — Un coup de moins en PA.
10. **Insaisissable** (rang 7) — Passe entre les zones de contrôle.

### Rempart de la compagnie

*Le tank : mur de boucliers peu coûteux, voisins protégés, rien ne le fait reculer.*  Famille d'armes : **Boucliers** · armure : **Plates lourdes**.

1. **Parade** (rang 1) — Défense de mêlée.
2. **Endurant** (rang 1) — Moins de fatigue par coup.
3. **Garde ferme** (rang 3) — +10 en défense avec un bouclier.
4. **Rempart** (rang 4) — Rempart : mur peu coûteux, coup de bouclier à prix réduit.
5. **Porteur de plates** (rang 4) — Plates : le poids ne fatigue plus.
6. **Mur vivant** (rang 5) — +10 en défense dans le mur.
7. **Bastion** (rang 6) — Bastion : le mur n'use plus le bouclier, voisins protégés.
8. **Forteresse** (rang 6) — Forteresse : impossible à repousser.
9. **Dur à cuire** (rang 5) — Moins de blessures.
10. **Port d'armure** (rang 7) — Poids réduit de 30 %.

## Synergies utiles

- **Mobilité** : *Vif*, *Pas léger*, *Insaisissable* et *Frappe vive* complètent les builds en tissu (initiative, esquive) ; *Pas léger* demande 10 de poids ou moins (les Maillons serrés y aident).
- **Endurance** : *Endurant*, *Second souffle*, *Souffle long* soutiennent les capacités signature (2 PA et beaucoup de fatigue) ; les plates (*Porteur de plates*) suppriment la fatigue du poids.
- **Esprit d'équipe** : *Camaraderie*, *Gardien*, *Mur vivant* et le *Bastion* du bouclier se cumulent dans une ligne serrée ; *Chef-né* et *Voix claire* tiennent le moral des rangs.
- **Moral et pression** : *Regard glaçant* après un coup d'étourdisseur (masse, gourdin, poings) ; *Prédateur* sur les ennemis brisés.
- **Dégâts d'armure** : *Lame affûtée* s'ajoute à la hache et à l'arbalète perforante.
