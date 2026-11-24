# Mods (données JSON)

Un mod est un dossier de **données JSON** posé dans `user://mods/` (sous Windows :
`%APPDATA%\Godot\app_userdata\Compagnie du Corbeau\mods\`). Aucun script n'est exécuté. Le menu **Options > Mods**
liste les mods trouvés, leur état, leurs avertissements, et permet de les désactiver (effet au prochain lancement).

```
mods/
  mon_mod/
    mod.json          obligatoire
    noms.json         fichiers de contenu (tous les .json de la racine, ou ceux listés dans "files")
```

## `mod.json`

| Clé | Type | Règle |
|---|---|---|
| `name` | texte | obligatoire, 60 caractères au plus |
| `version` | texte | facultatif, 20 caractères |
| `author` | texte | facultatif, 60 caractères |
| `description` | texte | facultatif, 400 caractères |
| `files` | liste de chemins | facultatif ; sinon tous les `.json` de la racine du dossier du mod (16 au plus) |

Un chemin de `files` est relatif au dossier du mod, en lettres/chiffres/`_`/`-`/`.`/`/`, 3 niveaux au plus,
terminé par `.json`. Refusés : `..`, `\`, `:` (lecteur), chemin absolu, nom commençant par un point.

## Fichiers de contenu

Chaque fichier est un objet dont les clés sont des catégories (ci-dessous). Une catégorie inconnue, un fichier invalide
ou une entrée invalide est ignoré avec un avertissement (visible dans Options > Mods) : le reste du mod se charge.

| Catégorie | Format | Où le jeu l'utilise |
|---|---|---|
| `first_names` | liste de textes (2–24 car.) | prénoms des recrues |
| `nicknames` | liste de textes (2–30) | surnoms des recrues |
| `company_names` | liste de textes (3–28) | noms de compagnie suggérés |
| `place_names` | liste de textes (2–30) | noms de villes et villages (liste de secours des factions dans le grand monde, liste générale dans l'ancien monde) |
| `epitaphs` | liste de textes (10–160) | épitaphes du mémorial |
| `backstories` | `{origine: [textes 10–300]}` (origine = clé de `Data.BG` : milicien, bucheron, braconnier, fermier, mendiant, deserteur, …) | histoires de recrues (ajoutées à celles du jeu) |
| `scenarios` | `{id: scénario}` | écran « Nouvelle partie > Scénario » |
| `events` | liste d'événements | événements de route (même tirage que ceux du jeu) |

### Scénario

`n` (nom, obligatoire), `men` (1 à 8 origines, obligatoire), `goal` (obligatoire : `stat` = `renown`, `gold` ou une
statistique connue de la campagne, `target`, `label`). Facultatifs (avec défaut) : `tag`, `desc`, `intro`, `rule`, `win`,
`lose` (textes), `gold` (−1 = celui de la difficulté, jusqu'à 5000), `gear` (`""` ou `"noble"`), `wage_mult` (0,5–3),
`provisions` (0–60), `morale` (−20–30), `hunt_only` (booléen), `hunt_pay` (0,5–3), `days` (10–400).
L'identifiant devient `mod_<id du mod>_<id>`.

### Événement

```json
{"id": "passeur", "title": "…", "text": "…", "choices": [
  {"id": "payer", "label": "…", "cost": 30, "outcomes": [{"w": 3, "text": "…", "gold": 20}]},
  {"id": "negocier", "label": "…", "check": {"kind": "negotiate", "base": 55},
     "win": [{"w": 1, "text": "…"}], "lose": [{"w": 1, "text": "…"}]}
]}
```

* 1 à 5 choix ; au moins un choix **gratuit** (sans `cost`). Un choix a soit `outcomes` (1–5 issues), soit `check` + `win` + `lose` (1–4 issues chacune).
* `check.kind` : `negotiate`, `bribe`, `flee`, `trap` ; `base` 5–95 (la chance affichée tient compte de la compagnie).
* Effets d'une issue (entiers bornés) : `gold` ±500, `hp_all` ±30, `hp_one` ±40, `renown` ±30, `days` 0–5, `food` −20–30,
  `xp_all` 0–30, `repair` (booléen), `recruit` (`"random"` ou une origine), `battle` `{"type": "b"|"g"|"o"|"u", "d": 1–3}`.
* `w` = poids du tirage (1–20). L'identifiant devient `mod_<id du mod>_<id>`.

## Limites et sécurité

* 32 mods, 16 fichiers par mod, 256 Kio par fichier, 16 Kio pour `mod.json`, profondeur 10, 30 000 éléments.
* Un mod est **lu seulement** : le jeu n'écrit jamais dans son dossier ; il ne peut ni lire hors de son dossier, ni toucher aux
  sauvegardes (`user://savegame.json`, emplacements…). Chaque valeur est reconstruite champ par champ (liste blanche) ; les
  crochets (`[ ]`) et caractères de contrôle sont retirés des textes.
* Les identifiants créés par un mod sont préfixés `mod_<mod>_` : jamais de collision. Si un mod disparaît, une sauvegarde
  qui citait son scénario ou son événement retombe sur le comportement normal (partie libre, événement ignoré).
* L'état « désactivé » est mémorisé dans `user://mods_state.json` (écrit par le jeu).

## Ce qui n'est PAS pris en charge

Nouvelles **armes, armures, ennemis, talents, objets** : leurs tables (`Data.WPN`, `Data.FOE`, `Data.PERKS`…) sont des `const`
lues directement partout dans le jeu (`Data.WPN[clé]`), avec typage ; les rendre extensibles demanderait une refonte
(couche d'accès unique) hors de ce périmètre. Pas de code, d'images ni de sons non plus.

## Exemple

`docs/mods_exemple/compagnie_des_marais/` : copiez le dossier dans `mods/`, relancez le jeu, ouvrez Options > Mods.
