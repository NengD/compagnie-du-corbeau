extends SceneTree
## Génère les sons de remplacement procéduraux (arc, cor, montée de niveau, vent).
## Lancer : godot --path . --headless -s res://tools/gen_audio.gd

const RATE := 22050


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_save("res://assets/audio/sfx/bow_0.wav", _bow(rng, 1.0))
	_save("res://assets/audio/sfx/bow_1.wav", _bow(rng, 1.12))
	_save("res://assets/audio/sfx/horn_0.wav", _horn())
	_save("res://assets/audio/sfx/levelup_0.wav", _levelup())
	_save("res://assets/audio/music/ambience_map.wav", _wind(rng))
	# Sons d'interface (graine à part pour ne pas modifier les sons ci-dessus)
	var ui := RandomNumberGenerator.new()
	ui.seed = 11
	_save("res://assets/audio/sfx/buy_0.wav", _coin_pings([1760.0, 2349.0], 0.07, 0.5))
	_save("res://assets/audio/sfx/buy_1.wav", _coin_pings([1568.0, 2093.0], 0.08, 0.5))
	_save("res://assets/audio/sfx/sell_0.wav", _coin_pings([2093.0, 1568.0, 1175.0], 0.06, 0.45))
	_save("res://assets/audio/sfx/sell_1.wav", _coin_pings([1976.0, 1480.0], 0.07, 0.45))
	_save("res://assets/audio/sfx/drop_0.wav", _thud(ui, 150.0))
	_save("res://assets/audio/sfx/drop_1.wav", _thud(ui, 180.0))
	_save("res://assets/audio/sfx/perk_0.wav", _chime([659.0, 880.0, 1319.0], 0.09, 1.5))
	_save("res://assets/audio/sfx/paper_open_0.wav", _swish(ui, 0.28, true))
	_save("res://assets/audio/sfx/paper_open_1.wav", _swish(ui, 0.32, true))
	_save("res://assets/audio/sfx/paper_close_0.wav", _swish(ui, 0.22, false))
	_save("res://assets/audio/sfx/paper_close_1.wav", _swish(ui, 0.25, false))
	_save("res://assets/audio/sfx/speed_0.wav", _chime([1047.0], 0.0, 0.12))
	_save("res://assets/audio/sfx/town_0.wav", _bell(196.0, 2.2))
	_save("res://assets/audio/sfx/repair_0.wav", _clang(ui, 1.0))
	_save("res://assets/audio/sfx/repair_1.wav", _clang(ui, 1.15))
	_save("res://assets/audio/sfx/hire_0.wav", _hire(ui))
	quit()


func _bow(rng: RandomNumberGenerator, pitch: float) -> PackedFloat32Array:
	var n := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * clampf(0.5 - t * 1.2, 0.05, 0.5)
		var twang := sin(TAU * 190.0 * pitch * t) * exp(-t * 14.0) * 0.6
		var snap := lp * exp(-t * 30.0) * 0.7
		out[i] = (twang + snap) * 0.8
	return out


func _horn() -> PackedFloat32Array:
	var dur := 2.4
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 98.0 if t < 0.7 else 147.0
		var env := minf(t / 0.12, 1.0) * clampf((dur - t) / 0.7, 0.0, 1.0)
		var s := 0.0
		for h in range(1, 9):
			s += sin(TAU * f * h * t + h) / float(h) * (1.0 if h < 6 else 0.4)
		var vib := 1.0 + 0.004 * sin(TAU * 5.0 * t)
		out[i] = s * 0.22 * env * vib
	return _lowpass(out, 0.18)


func _levelup() -> PackedFloat32Array:
	var notes := [392.0, 494.0, 587.0, 784.0]
	var n := int(RATE * 1.4)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in notes.size():
		var start := int(RATE * 0.11 * k)
		for i in range(start, n):
			var t := float(i - start) / RATE
			var s := sin(TAU * notes[k] * t) + 0.3 * sin(TAU * notes[k] * 2.0 * t)
			out[i] += s * exp(-t * 3.5) * 0.25 * minf(t / 0.005, 1.0)
	return out


func _wind(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := RATE * 12
	var fade := RATE * 2
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	for i in n + fade:
		var t := float(i) / RATE
		var gust := 0.55 + 0.45 * sin(TAU * t / 6.0 + 1.3) * sin(TAU * t / 4.1)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.06
		lp2 += (lp - lp2) * 0.15
		raw[i] = lp2 * gust * 2.2
	# chants d'oiseaux lointains
	for c in 7:
		var at := rng.randi_range(RATE, n - RATE)
		var base := rng.randf_range(2600.0, 4200.0)
		for b in rng.randi_range(2, 4):
			var s0 := at + int(b * RATE * 0.16)
			for i in int(RATE * 0.09):
				var t := float(i) / RATE
				var amp := sin(PI * float(i) / (RATE * 0.09)) * 0.07
				raw[s0 + i] += sin(TAU * (base + 900.0 * t * 10.0) * t) * amp
	# boucle sans couture : fondu enchaîné entre la fin et le début
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in fade:
		var w := float(i) / fade
		out[i] = raw[i] * w + raw[n + i] * (1.0 - w)
	return out


## Quelques tintements métalliques enchaînés (pièces).
func _coin_pings(freqs: Array, step: float, dur: float) -> PackedFloat32Array:
	var n := int(RATE * (dur + step * freqs.size()))
	var out := PackedFloat32Array()
	out.resize(n)
	for k in freqs.size():
		var start := int(RATE * step * k)
		for i in range(start, n):
			var t := float(i - start) / RATE
			var f: float = freqs[k]
			var s := sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.76 * t) + 0.25 * sin(TAU * f * 5.4 * t)
			out[i] += s * exp(-t * 14.0) * 0.18 * minf(t / 0.002, 1.0)
	return out


## Choc sourd (objet posé).
func _thud(rng: RandomNumberGenerator, f: float) -> PackedFloat32Array:
	var n := int(RATE * 0.18)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		out[i] = (sin(TAU * f * (1.0 - t * 1.5) * t) * 0.7 + lp * 0.25) * exp(-t * 28.0)
	return out


## Notes de cloche arpégées (carillon).
func _chime(notes: Array, step: float, dur: float) -> PackedFloat32Array:
	var n := int(RATE * (dur + step * notes.size()))
	var out := PackedFloat32Array()
	out.resize(n)
	for k in notes.size():
		var start := int(RATE * step * k)
		for i in range(start, n):
			var t := float(i - start) / RATE
			var f: float = notes[k]
			var s := sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) + 0.12 * sin(TAU * f * 3.0 * t)
			out[i] += s * exp(-t * (3.0 if notes.size() > 1 else 18.0)) * 0.22 * minf(t / 0.004, 1.0)
	return out


## Bruissement de parchemin : bruit filtré, enveloppe en cloche (plus tardive à l'ouverture, plus précoce à la fermeture).
func _swish(rng: RandomNumberGenerator, dur: float, rising: bool) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var x := float(i) / n
		var env := (x if rising else 1.0 - x)
		env = pow(env, 0.8) * sin(PI * x) * 1.6
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.45
		hp += (lp - hp) * 0.08
		var crackle := 1.0 if rng.randf() < 0.012 else 0.0
		out[i] = (lp - hp) * env * 0.45 + crackle * rng.randf_range(-0.2, 0.2) * env
	return out


## Cloche de ville : partiels inharmoniques à longue extinction.
func _bell(f: float, dur: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var parts := [[1.0, 1.0, 1.6], [2.0, 0.6, 2.2], [2.4, 0.5, 2.6], [3.0, 0.35, 3.2], [4.1, 0.25, 4.0]]
	for p in parts:
		for i in n:
			var t := float(i) / RATE
			out[i] += sin(TAU * f * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2])) * 0.2 * minf(t / 0.003, 1.0)
	return out


## Coup de marteau sur l'enclume : claquement + résonance métallique.
func _clang(rng: RandomNumberGenerator, pitch: float) -> PackedFloat32Array:
	var n := int(RATE * 0.7)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.5
		for f in [820.0, 1310.0, 2270.0, 3460.0]:
			s += sin(TAU * f * pitch * t) * exp(-t * (6.0 + f / 500.0)) * 0.16
		out[i] = s * minf(t / 0.001, 1.0)
	return out


## Embauche : poignée de main (choc sourd) puis petite cloche.
func _hire(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _thud(rng, 120.0)
	var b := _chime([523.0, 784.0], 0.1, 0.9)
	var off := int(RATE * 0.12)
	var out := PackedFloat32Array()
	out.resize(b.size() + off)
	for i in a.size():
		out[i] += a[i]
	for i in b.size():
		out[off + i] += b[i]
	return out


func _lowpass(a: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := 0.0
	var out := a.duplicate()
	for i in a.size():
		y += (a[i] - y) * k
		out[i] = y * 2.2
	return out


func _save(path: String, data: PackedFloat32Array) -> void:
	var pcm := PackedByteArray()
	pcm.resize(data.size() * 2)
	for i in data.size():
		pcm.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = pcm
	w.save_to_wav(ProjectSettings.globalize_path(path))
	print("écrit ", path)
