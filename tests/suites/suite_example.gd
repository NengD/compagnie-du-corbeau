extends RefCounted
## Exemple de suite (voir README.md).
var t


func test_runner_works() -> void:
	t.eq(Hex.distance(Vector2i(0, 0), Vector2i(1, 0)), 1, "la suite est bien chargée")
