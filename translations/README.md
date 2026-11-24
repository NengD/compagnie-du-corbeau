# Traductions

Le **français est la langue source** : les textes du code (littéraux, tables de `Data.gd`, etc.) servent de clés (msgid).
L'anglais est un catalogue de fichiers `en_*.po` chargés à la demande par `core/i18n.gd` (classe `I18n`) ; en français, aucune
traduction n'est enregistrée et le jeu s'affiche exactement comme avant.

## Règle de langue

Le jeu démarre **toujours en français**, même si le système est en anglais. Le choix du joueur (Options > Jeu > Langue)
est enregistré dans `user://settings.cfg` (`[game] language`, 0 = Français, 1 = English) et appliqué au démarrage
(`Settings.apply_all`) et à chaud (`Settings.set_value("language", i)` -> `I18n.apply`).

## Comment un texte est traduit

- Un `Label`, `Button`, `RichTextLabel`, infobulle, titre… voit son texte traduit automatiquement par le moteur à l'affichage
  (aussi après un changement de langue : le texte français brut est conservé, la traduction est faite à chaque affichage).
- `core/i18n_translation.gd` (`FuzzyTranslation`) retrouve aussi les phrases **construites** (`"%s frappe %s" % [a, b]`) :
  le gabarit français est compilé en expression régulière, les arguments sont traduits à part, le gabarit anglais est
  rempli. Il sait couper les listes (« · », « — », « ; »), les balises BBCode, `Texte (détail)`, `Texte [Raccourci]`,
  les EN-TÊTES EN CAPITALES, les mots isolés en minuscule et les noms composés (« Sanctuaire de la Veilleuse »).
- Texte dessiné à la main (`draw_string`) : à entourer de `I18n.t(...)` (identité en français) ; un gabarit s'écrit
  `I18n.t("Jour %d") % n`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `en_a_menus.po` | menus, options, nouvelle partie, pause, tutoriel, scénarios |
| `en_b_jeu.po` | carte, camp, marché, inventaire, talents, formation, atelier, événements de route |
| `en_c_bataille.po` | bataille : boutons, journal, états, ordres |
| `en_d_donnees.po` | tables de données : armes, armures, familles, talents, traits, factions, contrats, événements |
| `en_e_new.po`, `en_f_extra.po` | ajouts tardifs (touches, mods, accessibilité, gabarits du journal) |
| `ignore.txt` | chaînes françaises visibles à l'extraction mais qui n'ont rien à traduire (noms propres, identifiants) |
| `GLOSSARY.md` | glossaire et règles de style |

Tout fichier `translations/en*.po` est chargé. Format : `msgid "texte français"` / `msgstr "English text"` ;
gabarits : `%s`, `%d`, `%.1f`, `%+d`, `{nom}` ; pluriel : `a|b` ; ordre des arguments : `%1$s`, `%2$d`.

## Outils

```powershell
$GODOT = "E:\_jeu perso\godot\Godot_v4.7.2-stable_win64_console.exe"
& $GODOT --path . --headless -s res://tools/extract_strings.gd -- strings_fr.tsv      # liste des chaînes françaises visibles
& $GODOT --path . --headless -s res://tools/translation_report.gd -- --list           # couverture par zone + manquantes
& $GODOT --path . --headless -s res://tools/translation_runtime.gd -- --count 60       # couverture du journal de bataille (IA contre IA)
& $GODOT --path . --screen 1 --resolution 1280x720 --audio-driver Dummy -s res://tools/audit_responsive.gd -- --lang en
```

Le test `tests/suites/suite_traduction.gd` échoue si une chaîne des zones (a) menus et (b) interface n'a pas de traduction :
ajouter la traduction dans un `en_*.po` (ou la chaîne dans `ignore.txt` si elle n'a rien à traduire).
