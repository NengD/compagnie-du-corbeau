# Glossaire français → anglais

Vocabulaire de jeu tactique, à respecter pour toute nouvelle traduction (`translations/en_*.po`).

| Français | Anglais | Remarque |
|---|---|---|
| Compagnie | Company | « Compagnie du Corbeau » → *Company of the Raven* |
| Contrat | Contract | prime → *reward* (ou *bounty* pour une chasse au chef) |
| Couronnes | crowns | monnaie ; « Or » → *Gold* seulement dans les statistiques |
| Renom | Renown | réputation locale → *reputation* |
| Solde | wages | « Solde/jour » → *Wages/day* |
| Vivres / rations | Provisions / rations | |
| Homme / hommes | man / men | pas de féminisation forcée ; « they » pour un homme quelconque |
| Recrue | recruit | « Recruter » → *Recruit* |
| Réserve | Stash (inventaire) / reserve (hommes hors combat) | |
| Marché | Market | « Place du marché » → *Market square* |
| Quartier général | Headquarters | |
| Talent | perk | arbre de talents → *perk tree*, maîtrise → *mastery* |
| Niveau | level (*lvl* en abrégé) | |
| PV | HP | |
| PA (points d'action) | AP | |
| Fatigue | Fatigue | endurance → *stamina* |
| Initiative | Initiative | |
| Détermination | Resolve | |
| Moral | Morale | états : En fuite *Fleeing*, Brisé *Broken*, Hésitant *Wavering*, Stable *Steady*, Confiant *Confident* |
| Compétence de mêlée / à distance | Melee skill / Ranged skill | Déf. mêlée / distance → *Melee def. / Ranged def.* |
| Armure tête / corps | Head armor / Body armor | |
| Traversée | Penetration | « Vs armure » → *Vs armor* |
| Mur de boucliers | Shield wall | |
| Attaque gratuite / d'opportunité | free attack / opportunity attack | |
| Zone de contrôle | zone of control | |
| Étourdi | Stunned | |
| Brisé (moral) | Broken | |
| Bande errante | Roaming band | |
| Chasse au chef | Warlord hunt | |
| Escorte / Livraison | Escort / Delivery | |
| Embuscade | Ambush | |
| Fort / repaire | Fort / lair | |
| Mode fer | Ironman mode | |
| Mode libre | Free mode | |
| Succès | Achievements | |
| Encyclopédie | Encyclopedia | |
| Retraite (combat) | Retreat | départ d'un homme → *retirement* |
| Mémorial | Memorial | |
| Objet de famille | Family item | |
| Veillée | Evening at camp | |

## Règles de style

- Titres en « sentence case » (*New game*, pas *New Game*), sauf noms propres.
- Les noms propres de la fiction (lieux générés, noms et surnoms de recrues) **ne sont pas traduits** ;
  les créatures et personnages nommés de la fiction le sont (*Greyfang*, *the Pale Queen*).
- Pluriels : forme `singulier|pluriel` dans le gabarit anglais (choisie d'après le premier nombre) : `%d day|%d days`.
- Accords du français (`homme%s`, `tombé%s`) : le gabarit anglais ignore ces arguments ; on y référence les autres par position :
  `%1$d`, `%4$d`… (la numérotation compte tous les marqueurs du gabarit français, suffixes compris).
- Pas de « tu » : le joueur est *you*.
