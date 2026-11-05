# Export Windows

Prérequis : modèles d'export Godot 4.7.2 installés dans `%APPDATA%\Godot\export_templates\4.7.2.stable`
(il suffit de `windows_release_x86_64.exe` pour l'export release ; sinon Éditeur > Gérer les modèles d'export,
ou le fichier `Godot_v4.7.2-stable_export_templates.tpz` de https://github.com/godotengine/godot-builds/releases,
vérifié par sa somme SHA512, à dézipper dans ce dossier).

Commande (depuis la racine du projet ; le preset « Windows Desktop » est dans `export_presets.cfg`) :

```bash
mkdir -p build
"E:\_jeu perso\godot\Godot_v4.7.2-stable_win64_console.exe" --path . --headless --import
"E:\_jeu perso\godot\Godot_v4.7.2-stable_win64_console.exe" --path . --headless --export-release "Windows Desktop" build/CompagnieDuCorbeau.exe
```

Résultat : `build/CompagnieDuCorbeau.exe` (≈ 133 Mo, pck intégré, un seul fichier). `tests/`, `tools/`, `prototype/`, `*.md`
et `build/` sont exclus du paquet. Les sauvegardes vont dans `%APPDATA%\Godot\app_userdata\Compagnie du Corbeau\`.

Vérification : `build\CompagnieDuCorbeau.exe --screen 1 --resolution 1280x720 --audio-driver Dummy --quit-after 300` (code de sortie 0 ; `--audio-driver Dummy` coupe le son).

Licences : `*.md` est exclu du paquet, donc `assets/CREDITS.md` n'est pas embarqué ; `assets/fonts/OFL.txt` (texte de la SIL OFL 1.1) l'est. Si le jeu est
distribué en dehors du dépôt, joindre `assets/CREDITS.md` (et `LICENSE`) à l'archive.

Notes : version 0.2.0 et métadonnées (produit, description, copyright) dans le preset. Pas de signature de code.

## Icône du jeu

- Source : `assets/app_icon.svg` (corbeau sur écu, or #cfa851 / fond #1c1915 / liseré #b03a2e).
- Régénération : `godot --path . --headless -s res://tools/gen_icon.gd` (PNG 16 à 256 dans `assets/icons_png/`) puis
  `py tools/make_ico.py` (assemble `assets/app_icon.ico`, bibliothèque standard seulement).
- `config/icon` (project.godot) = icône de la **fenêtre** et de la barre des tâches : fonctionne sans rien d'autre.
- Icône du **fichier .exe** dans l'explorateur : elle exige l'outil externe **rcedit** (non installé par le projet).
  Pour l'activer vous-même :
  1. Télécharger `rcedit-x64.exe` depuis https://github.com/electron/rcedit/releases (vérifier la source).
  2. Godot > Éditeur > Paramètres de l'éditeur > Export > Windows : renseigner « Rcedit » avec ce fichier
     (sous Linux/macOS, il faut aussi Wine).
  3. Dans `export_presets.cfg` (ou Projet > Exporter), passer `application/modify_resources=true`
     (`application/icon="res://assets/app_icon.ico"` et les métadonnées sont déjà renseignés), puis refaire l'export.
  Tant que cette étape n'est pas faite, l'exe garde l'icône Godot dans l'explorateur.

## Écran de lancement

`assets/splash.png` (image du moteur, fond #1c1915) : `godot --path . --screen 1 --resolution 1280x720 res://tools/gen_splash.tscn`
(fenêtre requise). Ensuite `scenes/boot/boot_screen.gd` précharge les sons et sprites avant le menu.
