class_name TerrainGen
extends RefCounted
## Génération du terrain d'une bataille selon le biome ("plain", "forest", "hills", "water").
## Les zones de déploiement (colonnes 0-2 et w-3 à w-1) restent de l'herbe ; les reliefs vivent dans les
## colonnes 3 à w-4 ; aucune case praticable n'est coupée du reste du plateau.


static func pick_biome(rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for k in Data.BIOME_WEIGHTS:
		total += int(Data.BIOME_WEIGHTS[k])
	var roll: int = rng.randi_range(1, total)
	for k in Data.BIOME_WEIGHTS:
		roll -= int(Data.BIOME_WEIGHTS[k])
		if roll <= 0:
			return str(k)
	return "plain"


static func generate(w: int, h: int, biome: String, rng: RandomNumberGenerator) -> Dictionary:
	var cells: Dictionary = {}
	for r in h:
		for c in w:
			cells[Hex.from_col_row(c, r)] = {"t": "g", "c": c, "v": rng.randi_range(0, 2)}
	var c_min: int = 3
	var c_max: int = w - 4
	match biome:
		"forest":
			_clusters(cells, rng, "forest", rng.randi_range(3, 5), c_min, c_max, h)
			_scatter(cells, rng, 0.04, c_min, c_max)
		"hills":
			_clusters(cells, rng, "hill", rng.randi_range(3, 4), c_min, c_max, h)
			_scatter(cells, rng, 0.05, c_min, c_max)
		"water":
			_river(cells, rng, c_min, c_max, h)
			_scatter(cells, rng, 0.05, c_min, c_max)
		_:
			_scatter(cells, rng, 0.13, c_min, c_max)
	_ensure_connected(cells, w, h, c_min, c_max)
	return cells


static func _scatter(cells: Dictionary, rng: RandomNumberGenerator, prob: float, c_min: int, c_max: int) -> void:
	for h in cells:
		var col: int = int(cells[h]["c"])
		if col >= c_min and col <= c_max and cells[h]["t"] == "g" and rng.randf() < prob:
			cells[h]["t"] = "tree" if rng.randf() < 0.6 else "rock"


static func _clusters(cells: Dictionary, rng: RandomNumberGenerator, kind: String, count: int, c_min: int, c_max: int, rows: int) -> void:
	for i in count:
		var center: Vector2i = Hex.from_col_row(rng.randi_range(c_min, c_max), rng.randi_range(0, rows - 1))
		var rad: int = rng.randi_range(1, 2)
		for h in cells:
			var col: int = int(cells[h]["c"])
			var d: int = Hex.distance(center, h)
			if col >= c_min and col <= c_max and d <= rad and cells[h]["t"] == "g" and (d == 0 or rng.randf() < 0.85):
				cells[h]["t"] = kind


## Rivière profonde de deux cases de large qui traverse de haut en bas, avec un ou deux gués.
static func _river(cells: Dictionary, rng: RandomNumberGenerator, c_min: int, c_max: int, rows: int) -> void:
	var base: int = rng.randi_range(c_min + 1, c_max - 2)
	var drift: int = 0
	for r in rows:
		drift = clampi(drift + rng.randi_range(-1, 1), -1, 1)
		var c0: int = clampi(base + drift, c_min, c_max - 1)
		for cc in [c0, c0 + 1]:
			cells[Hex.from_col_row(cc, r)]["t"] = "river"
	var ford_rows: Array[int] = []
	for i in rng.randi_range(1, 2):
		var r: int = rng.randi_range(1, rows - 2)
		if not ford_rows.has(r) and not ford_rows.has(r - 1) and not ford_rows.has(r + 1):
			ford_rows.append(r)
	for r in ford_rows:
		for cc in range(c_min, c_max + 1):
			var h: Vector2i = Hex.from_col_row(cc, r)
			if cells[h]["t"] == "river":
				cells[h]["t"] = "ford"


static func _flood(cells: Dictionary, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var open: Array[Vector2i] = [start]
	var head: int = 0
	while head < open.size():
		var cur: Vector2i = open[head]
		head += 1
		for n in Hex.neighbors(cur):
			if not seen.has(n) and not Pathfinding.blocked(cells, n):
				seen[n] = true
				open.append(n)
	return seen


## Garantit un passage d'un camp à l'autre, puis bouche (en rochers) les poches praticables isolées.
static func _ensure_connected(cells: Dictionary, w: int, h: int, c_min: int, c_max: int) -> void:
	var mid: int = h / 2
	var start: Vector2i = Hex.from_col_row(0, mid)
	var goal: Vector2i = Hex.from_col_row(w - 1, mid)
	var seen: Dictionary = _flood(cells, start)
	if not seen.has(goal):
		for col in range(c_min, c_max + 1):
			var cell: Dictionary = cells[Hex.from_col_row(col, mid)]
			if cell["t"] == "river":
				cell["t"] = "ford"
			elif Data.TERRAIN[cell["t"]]["block"]:
				cell["t"] = "g"
		seen = _flood(cells, start)
	for k in cells:
		if not seen.has(k) and not Pathfinding.blocked(cells, k):
			cells[k]["t"] = "rock"
