class_name Quality
extends RefCounted
## Qualité graphique : préréglages (Bas, Moyen, Élevé, Ultra) et réglages détaillés. Logique pure, sans scène.
## `Settings` stocke les valeurs détaillées ; ce fichier dit ce que chaque niveau fixe, reconnaît un niveau
## à partir des valeurs (sinon « Personnalisé »), suggère un niveau selon la carte graphique et fournit aux
## scènes de rendu des accesseurs gardés : `Quality.value("shadows")`, `Quality.particle_factor()`…
## Aucun de ces réglages ne change une règle du jeu.

const LOW := 0
const MEDIUM := 1
const HIGH := 2
const ULTRA := 3
const CUSTOM := 4

const NAMES: Array = ["Bas", "Moyen", "Élevé", "Ultra", "Personnalisé"]
const DESCS: Array = [
	"Bas : pour les petites configurations, aplats de couleur et peu d'effets.",
	"Moyen : textures du sol, ombres simples, météo légère et peu de particules.",
	"Élevé : textures fondues, ombres, météo complète et animations d'ambiance.",
	"Ultra : tout au maximum, anticrénelage 4×, particules abondantes, carte haute définition.",
	"Personnalisé : réglages détaillés choisis à la main.",
]
## Réglages fixés par chaque niveau. « weather » = niveau effectif (0 aucune, 1 pluie et neige, 2 complète avec brouillard).
const KEYS: Array = ["msaa", "ground_mode", "shadows", "weather", "particles", "decals", "map_anim", "day_night", "map_tex", "illustrated_ui", "screen_shake", "tex_filter"]
const PRESETS: Array = [
	{"msaa": 0, "ground_mode": 0, "shadows": 0, "weather": 0, "particles": 0, "decals": 0, "map_anim": false, "day_night": false, "map_tex": 0, "illustrated_ui": false, "screen_shake": false, "tex_filter": 0},
	{"msaa": 1, "ground_mode": 1, "shadows": 1, "weather": 1, "particles": 1, "decals": 1, "map_anim": false, "day_night": true, "map_tex": 1, "illustrated_ui": true, "screen_shake": true, "tex_filter": 0},
	{"msaa": 1, "ground_mode": 2, "shadows": 2, "weather": 2, "particles": 2, "decals": 2, "map_anim": true, "day_night": true, "map_tex": 1, "illustrated_ui": true, "screen_shake": true, "tex_filter": 1},
	{"msaa": 2, "ground_mode": 2, "shadows": 2, "weather": 2, "particles": 3, "decals": 3, "map_anim": true, "day_night": true, "map_tex": 2, "illustrated_ui": true, "screen_shake": true, "tex_filter": 1},
]
## Libellés des listes déroulantes du volet « Réglages avancés » (booléens : case à cocher, sans libellés).
const LABELS: Dictionary = {
	"msaa": ["Désactivé", "2×", "4×"],
	"ground_mode": ["Aplats de couleur", "Textures", "Textures et fondus"],
	"shadows": ["Aucune", "Simples", "Complètes"],
	"weather": ["Aucune", "Pluie et neige seulement", "Complète (avec brouillard)"],
	"particles": ["Aucune (0 %)", "Réduites (40 %)", "Normales (100 %)", "Abondantes (150 %)"],
	"decals": ["Aucune", "30 au plus", "80 au plus", "200 au plus"],
	"map_tex": ["Réduite", "Normale", "Haute"],
	"tex_filter": ["Linéaire simple", "Mipmaps"],
}
const PARTICLE_FACTORS: Array = [0.0, 0.4, 1.0, 1.5]
const DECAL_CAPS: Array = [0, 30, 80, 200]
const MAP_PX: Array = [4, 6, 8]  ## pixels de texture par case de la carte du monde

## Mots-clés du nom de la carte graphique (en minuscules).
const SOFTWARE_HINTS: Array = ["llvmpipe", "softpipe", "swiftshader", "microsoft basic", "basic render", "gdi generic", "software"]
const OLD_HINTS: Array = ["gma", "geforce 7", "geforce 8", "geforce 9", "geforce g1", "geforce gt 2", "radeon hd 2", "radeon hd 3", "radeon hd 4", "radeon x", "hd graphics 2000", "hd graphics 3000", "hd graphics 4000", "videocore", "mali-4"]
const INTEGRATED_HINTS: Array = ["intel", "uhd", "iris", "radeon graphics", "radeon(tm) graphics", "adreno", "mali", "powervr", "vega 3", "vega 6", "vega 7", "vega 8", "vega 10", "vega 11"]


static func clamp_level(level: int) -> int:
	return clampi(level, LOW, CUSTOM)


static func name_of(level: int) -> String:
	return str(NAMES[clamp_level(level)])


## Réglages d'un préréglage (copie). Pour « Personnalisé » : ceux d'Élevé (point de départ).
static func preset_values(level: int) -> Dictionary:
	var i: int = clampi(level, LOW, ULTRA)
	return (PRESETS[i] as Dictionary).duplicate()


## Niveau dont les valeurs sont exactement celles de `values`, sinon CUSTOM. Une clé absente compte comme différente.
static func identify(values: Dictionary) -> int:
	for lv in PRESETS.size():
		var p: Dictionary = PRESETS[lv]
		var same: bool = true
		for k in KEYS:
			if not values.has(k) or values[k] != p[k]:
				same = false
				break
		if same:
			return lv
	return CUSTOM


## Préréglage le plus proche de `values` (le plus de réglages identiques ; à égalité, le plus élevé).
static func nearest(values: Dictionary) -> int:
	var best: int = HIGH
	var best_n: int = -1
	for lv in PRESETS.size():
		var n: int = 0
		for k in KEYS:
			if values.has(k) and values[k] == PRESETS[lv][k]:
				n += 1
		if n >= best_n:
			best_n = n
			best = lv
	return best


## Niveau suggéré d'après le nom de l'adaptateur graphique (RenderingServer.get_video_adapter_name()).
static func suggest(adapter: String) -> int:
	var a: String = adapter.to_lower().strip_edges()
	if a == "":
		return HIGH
	for h in SOFTWARE_HINTS:
		if a.contains(str(h)):
			return LOW
	for h in OLD_HINTS:
		if a.contains(str(h)):
			return LOW
	if a.contains("intel") and a.contains("arc"):
		return HIGH
	for h in INTEGRATED_HINTS:
		if a.contains(str(h)):
			return MEDIUM
	if a.contains("vega") and not (a.contains(" rx ") or a.contains("frontier") or a.contains(" vii") or a.contains("56") or a.contains("64")):
		return MEDIUM  # Vega intégrée (Ryzen), pas les Vega de bureau
	return HIGH


static func suggest_here() -> int:
	return suggest(RenderingServer.get_video_adapter_name())


# --- Accesseurs pour les scènes de rendu ---

## Réglage courant. Sans Settings (tests `-s`, outils) : valeurs d'Élevé. Clé inconnue : null.
## Clés « effectives » : "weather" (0..2), "particles" -> facteur (float), "decals" -> plafond (int), "map_px" -> pixels par case.
static func value(key: String) -> Variant:
	var st: Node = _settings()
	match key:
		"weather":
			if st == null:
				return int(PRESETS[HIGH]["weather"])
			if not bool(st.get("weather_fx")):
				return 0
			return clampi(int(st.get("weather_level")), 0, 2)
		"particles":
			return float(PARTICLE_FACTORS[clampi(_idx(st, "particles"), 0, 3)])
		"decals":
			return int(DECAL_CAPS[clampi(_idx(st, "decals"), 0, 3)])
		"map_px":
			return int(MAP_PX[clampi(_idx(st, "map_tex"), 0, 2)])
	if not (PRESETS[HIGH] as Dictionary).has(key):
		return null
	if st != null:
		var v: Variant = st.get(key)
		if v != null:
			return v
	return PRESETS[HIGH][key]


static func particle_factor() -> float:
	return float(value("particles"))


static func _idx(st: Node, key: String) -> int:
	if st != null:
		var v: Variant = st.get(key)
		if v != null:
			return int(v)
	return int(PRESETS[HIGH][key])


static func _settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return null if tree == null else tree.root.get_node_or_null("/root/Settings")


## Nombre de particules après application de la densité (0 si la densité est nulle ; au moins 1 sinon).
static func scaled_count(base: int, factor: float) -> int:
	if factor <= 0.0 or base <= 0:
		return 0
	return maxi(1, roundi(float(base) * factor))
