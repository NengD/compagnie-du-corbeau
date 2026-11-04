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
