extends RefCounted
## Small synthesized one-shot cues (flap whoosh, pencil-tap score, paper crash).
## Rendered once to 16-bit PCM WAV so Web playback needs no live generator.

const RATE := 22050


static func register_all(audio: Node) -> void:
	if audio == null:
		return
	audio.call("register_stream", "player.action", flap())
	audio.call("register_stream", "score.reward", score())
	audio.call("register_stream", "enemy.impact", crash())
	audio.call("register_stream", "game.defeat", crash())
	audio.call("register_stream", "ui.confirm", tick(1.0))
	audio.call("register_stream", "game.pause", tick(0.78))


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, roundi(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream


static func _env(i: int, n: int, attack: float = 0.004) -> float:
	var t := float(i) / float(RATE)
	var a := minf(t / attack, 1.0)
	var r := 1.0 - float(i) / float(n)
	return a * r * r


static func flap() -> AudioStreamWAV:
	var n := int(RATE * 0.12)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var phase := 0.0
	var noise := 0.0
	for i in n:
		var p := float(i) / float(n)
		phase += TAU * lerpf(360.0, 700.0, p) / RATE
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.35)
		out[i] = (sin(phase) * 0.45 + noise * 0.4) * _env(i, n, 0.008) * 0.55
	return _make(out)


static func score() -> AudioStreamWAV:
	var n1 := int(RATE * 0.07)
	var n2 := int(RATE * 0.2)
	var out := PackedFloat32Array()
	out.resize(n1 + n2)
	for i in n1:
		out[i] = sin(TAU * 988.0 * i / RATE) * _env(i, n1, 0.002) * 0.45
	for i in n2:
		var t := float(i) / RATE
		out[n1 + i] = (sin(TAU * 1319.0 * t) * 0.4 + sin(TAU * 2638.0 * t) * 0.08) * _env(i, n2, 0.002) * 0.6
	return _make(out)


static func crash() -> AudioStreamWAV:
	var n := int(RATE * 0.34)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var noise := 0.0
	for i in n:
		var p := float(i) / float(n)
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), lerpf(0.9, 0.25, p))
		var thump := sin(TAU * lerpf(150.0, 55.0, p) * i / RATE)
		out[i] = (noise * 0.55 + thump * 0.55) * _env(i, n, 0.002) * 0.8
	return _make(out)


static func tick(pitch: float) -> AudioStreamWAV:
	var n := int(RATE * 0.06)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = sin(TAU * 700.0 * pitch * i / RATE) * _env(i, n, 0.002) * 0.4
	return _make(out)
