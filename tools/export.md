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

Vérification : `build\CompagnieDuCorbeau.exe --screen 1 --resolution 1280x720 --quit-after 300` (code de sortie 0).

Notes : l'icône (`assets/app_icon.svg`) et les infos de version (0.1.0) sont dans le preset ; `application/modify_resources`
est désactivé car il exige l'outil externe rcedit (l'exe garde alors l'icône Godot dans l'explorateur, mais la fenêtre
utilise l'icône du preset si renseignée par le projet). Pas de signature de code.
