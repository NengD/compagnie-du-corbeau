# Publier une version

Les archives Windows et Linux se fabriquent seules sur GitHub (fichier `.github/workflows/release.yml`).

## Publier

1. Mettre à jour le numéro dans `project.godot` (`config/version`) et `export_presets.cfg` (`file_version`, `product_version`), commiter et pousser.
2. Poser l'étiquette et la pousser :

```bash
git tag v0.4.1
git push origin v0.4.1
```

3. Sur GitHub, onglet **Actions**, le travail « Publier une version » démarre (environ 10 à 20 minutes). Il installe Godot, importe le projet,
   lance les tests (`run_tests.gd`, `smoke_ui.gd`), exporte Windows et Linux, fabrique les deux zips et crée la **Release** avec les
   notes générées. **Si un test échoue, rien n'est publié.**

On peut aussi le lancer à la main : Actions, « Publier une version », **Run workflow** (numéro de version facultatif).

## Réglage à vérifier une fois

Settings, Actions, General, « Workflow permissions » : choisir **Read and write permissions** si la publication échoue avec une erreur de droits
(le fichier demande déjà `contents: write`, mais certains dépôts ou organisations l'interdisent par défaut).

## À la main (sans GitHub)

```bash
godot --headless --path . --export-release "Windows Desktop" build/CompagnieDuCorbeau.exe
godot --headless --path . --export-release "Linux" build/CompagnieDuCorbeau.x86_64
python tools/package_release.py        # écrit les deux zips dans build/ (version lue dans project.godot)
```

L'exécutable Linux est marqué exécutable dans l'archive : pas de `chmod` à la décompression.

## Limites connues

- L'icône n'est pas incrustée dans le .exe (il faudrait configurer `rcedit` dans Godot) ; l'icône de fenêtre fonctionne.
- Le jeu n'est pas signé : Windows SmartScreen peut afficher un avertissement au premier lancement.
