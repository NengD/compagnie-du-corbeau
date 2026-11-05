extends Node
## Sons et musique. `Audio.play("evenement")` pour un effet, `Audio.music("map")` pour changer de piste.
## Silencieux en headless ; un fichier absent est ignoré. Volumes lus dans /root/Settings s'il existe
## (propriétés master_volume, music_volume, sfx_volume entre 0 et 1, signal `changed`) et appliqués en direct.
##
## Dosage : chaque événement a un volume relatif (`db`), une variation de hauteur (`pitch`), un délai minimal entre deux
## déclenchements (`gap`, en secondes) et une priorité (`prio`, 0 = ambiance / 2 = essentiel). Une variante n'est jamais
## rejouée deux fois de suite, les sons secondaires sont écartés quand toutes les voix sont prises, et les jingles
## (`duck_db`) baissent la musique le temps de leur durée. `set_paused(true)` baisse la musique et fait taire les effets.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const BUS_MUSIC := "Musique"
const BUS_SFX := "Effets"
const FADE := 1.2
const POOL := 10
const DUCK_FADE := 0.25  ## durée de la descente / remontée de la musique autour d'un jingle
const PAUSE_DB := -14.0  ## atténuation de la musique en pause

## Événement -> {files, db: volume, pitch: variation de hauteur (± fraction ; négatif = hauteur fixe),
## gap: délai minimal entre deux lectures, prio: 0..2, duck_db: baisse de la musique pendant le son,
## then_stop: la musique s'arrête une fois le jingle fini}
const EVENTS: Dictionary = {
	"hit_flesh": {"files": ["hit_flesh_0.ogg", "hit_flesh_1.ogg", "hit_flesh_2.ogg"], "db": -2.0, "pitch": 0.08, "gap": 0.05, "prio": 1},
	"hit_armor": {"files": ["hit_armor_0.ogg", "hit_armor_1.ogg", "hit_armor_2.ogg"], "db": -3.0, "pitch": 0.08, "gap": 0.05, "prio": 1},
	"miss": {"files": ["miss_0.ogg", "miss_1.ogg", "miss_2.ogg"], "db": -7.0, "pitch": 0.1, "gap": 0.08, "prio": 0},
	"bow": {"files": ["bow_0.wav", "bow_1.wav"], "db": -3.0, "pitch": 0.06, "gap": 0.08, "prio": 1},
	"death": {"files": ["death_0.ogg", "death_1.ogg", "death_2.ogg"], "db": -1.0, "pitch": -0.18, "gap": 0.2, "prio": 2},
	"shield_wall": {"files": ["shield_wall_0.ogg", "shield_wall_1.ogg"], "db": -3.0, "pitch": 0.05, "gap": 0.2, "prio": 1},
	"step": {"files": ["step_0.ogg", "step_1.ogg", "step_2.ogg"], "db": -14.0, "pitch": 0.1, "gap": 0.07, "prio": 0},
	"click": {"files": ["click_0.ogg", "click_1.ogg", "click_2.ogg"], "db": -11.0, "pitch": 0.05, "gap": 0.04, "prio": 0},
	"coins": {"files": ["coins_0.ogg", "coins_1.ogg"], "db": -5.0, "pitch": 0.05, "gap": 0.12, "prio": 1},
	"buy": {"files": ["buy_0.wav", "buy_1.wav"], "db": -6.0, "pitch": 0.05, "gap": 0.12, "prio": 1},
	"sell": {"files": ["sell_0.wav", "sell_1.wav"], "db": -6.0, "pitch": 0.05, "gap": 0.12, "prio": 1},
	"drop": {"files": ["drop_0.wav", "drop_1.wav"], "db": -9.0, "pitch": 0.08, "gap": 0.08, "prio": 0},
	"perk": {"files": ["perk_0.wav"], "db": -6.0, "pitch": 0.0, "gap": 0.4, "prio": 2},
	"paper_open": {"files": ["paper_open_0.wav", "paper_open_1.wav"], "db": -10.0, "pitch": 0.06, "gap": 0.15, "prio": 0},
	"paper_close": {"files": ["paper_close_0.wav", "paper_close_1.wav"], "db": -11.0, "pitch": 0.06, "gap": 0.15, "prio": 0},
	"speed": {"files": ["speed_0.wav"], "db": -13.0, "pitch": 0.05, "gap": 0.08, "prio": 0},
	"town": {"files": ["town_0.wav"], "db": -8.0, "pitch": 0.0, "gap": 1.0, "prio": 1},
	"repair": {"files": ["repair_0.wav", "repair_1.wav"], "db": -7.0, "pitch": 0.05, "gap": 0.3, "prio": 1},
	"hire": {"files": ["hire_0.wav"], "db": -6.0, "pitch": 0.0, "gap": 0.4, "prio": 1},
	"levelup": {"files": ["levelup_0.wav"], "db": -4.0, "pitch": 0.0, "gap": 0.5, "prio": 2, "duck_db": -8.0},
	"horn": {"files": ["horn_0.wav"], "db": -3.0, "pitch": 0.0, "gap": 1.0, "prio": 2, "duck_db": -8.0},
	"victory": {"files": ["victory.mp3"], "db": -3.0, "pitch": 0.0, "gap": 1.0, "prio": 2, "duck_db": -20.0, "then_stop": true},
	"defeat": {"files": ["defeat.mp3"], "db": -3.0, "pitch": 0.0, "gap": 1.0, "prio": 2, "duck_db": -20.0, "then_stop": true},
}

## Piste -> fichier (boucle) ; `ambience` : bruit de fond joué en plus.
const TRACKS: Dictionary = {
	"menu": {"file": "menu.mp3", "db": -8.0},
	"map": {"file": "map.mp3", "db": -9.0, "ambience": "ambience_map.wav"},
	"town": {"file": "town.mp3", "db": -9.0},
	"battle": {"file": "battle.mp3", "db": -8.0},
}

var enabled: bool = DisplayServer.get_name() != "headless"
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.9
## Pour les tests : dernier événement / piste demandés, même en headless.
var last_event: String = ""
var current_music: String = ""
var event_count: int = 0
var paused: bool = false
var duck_db: float = 0.0  ## baisse actuelle de la musique (jingle), 0 = aucune

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_prio: Array[int] = []
var _pool_start: Array[float] = []
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _ambience: AudioStreamPlayer
var _settings_connected := false
var _rng := RandomNumberGenerator.new()
var _tweens: Dictionary = {}  ## lecteur -> Tween de fondu en cours
var _duck_tween: Tween
var _last_variant: Dictionary = {}  ## événement -> dernier indice joué
var _last_play: Dictionary = {}  ## événement -> instant (s) de la dernière lecture


func _ready() -> void:
	_rng.randomize()
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	for i in POOL:
		_pool.append(_make_player(BUS_SFX))
		_pool_prio.append(0)
		_pool_start.append(0.0)
	for i in 2:
		_music.append(_make_player(BUS_MUSIC))
	_ambience = _make_player(BUS_MUSIC)
	_connect_settings()
	_apply_volumes()


# --- Logique pure (testable sans fichier audio) ---

## Choisit une variante parmi `count` sans répéter la précédente (si `count` > 1).
func choose_variant(event: String, count: int) -> int:
	if count <= 1:
		_last_variant[event] = 0
		return 0
	var last: int = int(_last_variant.get(event, -1))
	var i: int = _rng.randi_range(0, count - 1)
	if i == last:
		i = (i + 1 + _rng.randi_range(0, count - 2)) % count
	_last_variant[event] = i
	return i


## Faut-il jouer `event` maintenant ? Respecte le délai minimal par événement et la saturation des voix
## (`busy` voix occupées sur `pool`). Enregistre l'instant si oui. `now` en secondes.
func allow(event: String, now: float, busy: int = 0, pool: int = POOL) -> bool:
	if not EVENTS.has(event):
		return false
	var cfg: Dictionary = EVENTS[event]
	if now - float(_last_play.get(event, -1000.0)) < float(cfg.get("gap", 0.0)):
		return false
	if not voice_policy(int(cfg.get("prio", 1)), busy, pool):
		return false
	_last_play[event] = now
	return true


## Quand presque toutes les voix sont prises, les sons de priorité 0 sont écartés, puis ceux de priorité 1.
static func voice_policy(prio: int, busy: int, pool: int) -> bool:
	if prio >= 2:
		return true
	if prio == 1:
		return busy < pool
	return busy < pool - 3


## Voix à sacrifier quand il n'y en a plus de libre : priorité la plus basse, à égalité la plus ancienne.
static func pick_victim(prios: Array, starts: Array) -> int:
	var best: int = 0
	for i in prios.size():
		if int(prios[i]) < int(prios[best]) or (int(prios[i]) == int(prios[best]) and float(starts[i]) < float(starts[best])):
			best = i
	return best


## Hauteur de lecture : `pitch` >= 0 = variation aléatoire ± pitch, < 0 = hauteur fixe baissée (avec un léger bruit).
func pitch_for(pitch: float) -> float:
	if pitch >= 0.0:
		return 1.0 + _rng.randf_range(-pitch, pitch)
	return 1.0 + pitch + _rng.randf_range(-0.04, 0.04)


# --- Effets ---

func play(event: String) -> void:
	last_event = event
	event_count += 1
	if not enabled or not EVENTS.has(event):
		return
	if paused and event != "click":
		return
	_connect_settings()
	var cfg: Dictionary = EVENTS[event]
	var now: float = Time.get_ticks_msec() / 1000.0
	if not allow(event, now, _busy_voices()):
		return
	var stream := _pick(event, cfg["files"], SFX_DIR)
	if stream == null:
		return
	var idx: int = _free_player()
	var p: AudioStreamPlayer = _pool[idx]
	p.stream = stream
	p.volume_db = float(cfg["db"]) + _rng.randf_range(-1.0, 1.0)
	p.pitch_scale = pitch_for(float(cfg["pitch"]))
	_pool_prio[idx] = int(cfg.get("prio", 1))
	_pool_start[idx] = now
	p.play()
	if cfg.has("duck_db"):
		_duck_for(float(cfg["duck_db"]), stream.get_length() / p.pitch_scale, bool(cfg.get("then_stop", false)))


func _busy_voices() -> int:
	var n: int = 0
	for p in _pool:
		if p.playing:
			n += 1
	return n


func _free_player() -> int:
	for i in _pool.size():
		if not _pool[i].playing:
			return i
	return pick_victim(_pool_prio, _pool_start)


## Baisse la musique de `db` pendant `length` secondes, puis la remonte (ou l'arrête si `stop_after`).
func _duck_for(db: float, length: float, stop_after: bool) -> void:
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, duck_db, db, DUCK_FADE)
	_duck_tween.tween_interval(maxf(0.1, length - DUCK_FADE))
	if stop_after:
		_duck_tween.tween_callback(stop_music)
		_duck_tween.tween_method(_set_duck, db, 0.0, FADE)
	else:
		_duck_tween.tween_method(_set_duck, db, 0.0, DUCK_FADE * 3.0)


func _set_duck(db: float) -> void:
	duck_db = db
	_apply_volumes()


## Pause : la musique baisse et les effets se taisent (seul le clic d'interface reste audible).
func set_paused(on: bool) -> void:
	paused = on
	if on and enabled:
		for p in _pool:
			p.stop()
	_apply_volumes()


# --- Musique ---

func music(name: String) -> void:
	var same: bool = current_music == name
	current_music = name
	if not enabled or not TRACKS.has(name):
		return
	_connect_settings()
	var cfg: Dictionary = TRACKS[name]
	var stream := _load(MUSIC_DIR + String(cfg["file"]), true)
	if stream == null:
		return
	var old: AudioStreamPlayer = _music[_active]
	if same and old.playing and old.stream == stream:
		return
	_active = 1 - _active
	var fresh: AudioStreamPlayer = _music[_active]
	fresh.stream = stream
	fresh.volume_db = -60.0
	fresh.play()
	_fade(fresh, float(cfg["db"]), FADE)
	if old.playing:
		_fade(old, -60.0, FADE, true)
	_set_ambience(String(cfg.get("ambience", "")))


func stop_music() -> void:
	current_music = ""
	if not enabled:
		return
	for p in _music:
		if p.playing:
			_fade(p, -60.0, FADE, true)
	_set_ambience("")


func _set_ambience(file: String) -> void:
	if file == "":
		if _ambience.playing:
			_fade(_ambience, -60.0, FADE, true)
		return
	var stream := _load(MUSIC_DIR + file, true)
	if stream == null or (_ambience.playing and _ambience.stream == stream and _ambience.volume_db > -50.0):
		return
	_ambience.stream = stream
	_ambience.volume_db = -60.0
	_ambience.play()
	_fade(_ambience, -14.0, FADE)


func _fade(p: AudioStreamPlayer, to_db: float, dur: float, stop_after: bool = false) -> void:
	if _tweens.has(p) and is_instance_valid(_tweens[p]):
		(_tweens[p] as Tween).kill()
	var tw := create_tween()
	_tweens[p] = tw
	tw.tween_property(p, "volume_db", to_db, dur)
	if stop_after:
		tw.tween_callback(func() -> void:
			if p.volume_db <= -59.0:
				p.stop())


func _pick(event: String, files: Array, dir: String) -> AudioStream:
	var first: int = choose_variant(event, files.size())
	for k in files.size():
		var s := _load(dir + String(files[(first + k) % files.size()]), false)
		if s != null:
			return s
	return null


func _load(path: String, loop: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
		if s != null and loop:
			if s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = true
			elif s is AudioStreamWAV:
				var w := s as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = w.data.size() / (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if w.stereo else 1)
	_cache[path] = s
	return s


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, "Master")


func _connect_settings() -> void:
	if _settings_connected:
		return
	var s := get_node_or_null("/root/Settings")
	if s == null:
		return
	_settings_connected = true
	if s.has_signal("changed"):
		s.connect("changed", _apply_volumes)
	_apply_volumes()


## Volumes des bus : réglages du joueur + atténuation de jingle / de pause pour la musique.
func _apply_volumes() -> void:
	var s := get_node_or_null("/root/Settings")
	if s != null:
		master_volume = float(s.get("master_volume") if s.get("master_volume") != null else master_volume)
		music_volume = float(s.get("music_volume") if s.get("music_volume") != null else music_volume)
		sfx_volume = float(s.get("sfx_volume") if s.get("sfx_volume") != null else sfx_volume)
	if not enabled:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var extra: float = duck_db + (PAUSE_DB if paused else 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), linear_to_db(maxf(music_volume, 0.0001)) + extra)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), linear_to_db(maxf(sfx_volume, 0.0001)))
