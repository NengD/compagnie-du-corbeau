Chaque fichier `*.gd` de ce dossier est une suite de tests chargée par `tests/run_tests.gd`.

```gdscript
extends RefCounted
var t  # le lanceur : t.check(cond, msg), t.eq(got, want, msg), t.new_game(seed), t.mk(...), t.rng_seeded(seed)

func test_quelque_chose() -> void:
	t.eq(1 + 1, 2, "addition")
```
