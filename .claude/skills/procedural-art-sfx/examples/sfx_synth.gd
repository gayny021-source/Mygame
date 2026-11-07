class_name SfxSynth
extends RefCounted
## Bakes short procedural sound effects into AudioStreamWAV. No external .wav files.
## Mono, 16-bit PCM, 22050 Hz.
##
## Baking is a GDScript loop over every sample (tens of thousands for a set of
## sounds), so call these at LOAD time and cache the results — never on the
## event itself. For variety (e.g. the d20 rattle) bake 3–4 variants with
## different seeds up front and pick one when the event fires.

const MIX_RATE := 22050
## Samples of noise at the start of a click: the transient, ~2 ms.
const CLICK_NOISE_SAMPLES := 40


## Builds an AudioStreamWAV from float samples in [-1, 1].
static func to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## Short UI click: a fast-decaying high sine with a tiny noise transient.
static func click(rng: RandomNumberGenerator, freq := 1800.0, length_s := 0.04) -> AudioStreamWAV:
	var n := int(length_s * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := exp(-t * 90.0)
		var tone := sin(TAU * freq * t)
		var noise := rng.randf_range(-1.0, 1.0) if i < CLICK_NOISE_SAMPLES else 0.0
		out[i] = (tone * 0.6 + noise * 0.4) * env * 0.8
	return to_wav(out)


## Low thud for a hit or a heavy page: pitch drops from f0 to f1.
static func thud(f0 := 160.0, f1 := 50.0, length_s := 0.25) -> AudioStreamWAV:
	var n := int(length_s * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var k := t / length_s
		var f := lerpf(f0, f1, k)
		phase += TAU * f / MIX_RATE
		out[i] = sin(phase) * exp(-t * 14.0) * 0.9
	return to_wav(out)


## Retro explosion: filtered noise with a long decay.
static func boom(rng: RandomNumberGenerator, length_s := 0.8) -> AudioStreamWAV:
	var n := int(length_s * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var cutoff := lerpf(0.35, 0.02, t / length_s)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * cutoff
		out[i] = lp * exp(-t * 4.0) * 1.6
	return to_wav(out)


## Dice rattle for the d20 roll: several short clicks at random times.
static func dice_rattle(rng: RandomNumberGenerator, hits := 7, length_s := 0.6) -> AudioStreamWAV:
	var n := int(length_s * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for h in hits:
		var start := int(rng.randf_range(0.0, length_s * 0.85) * MIX_RATE)
		var freq := rng.randf_range(1400.0, 2600.0)
		var amp := rng.randf_range(0.3, 0.7)
		for j in int(0.03 * MIX_RATE):
			var idx := start + j
			if idx >= n:
				break
			var t := float(j) / MIX_RATE
			out[idx] += sin(TAU * freq * t) * exp(-t * 120.0) * amp
	return to_wav(out)
