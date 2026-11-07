extends AudioStreamPlayer
## Real-time synthesis through AudioStreamGenerator. Use only for continuous,
## parameter-driven sound (a drone whose pitch follows the game). For short
## one-shot effects use SfxSynth (baked AudioStreamWAV): zero work per frame.
##
## Control it ONLY through start() / halt(), never play() / stop() directly, and
## never reassign `stream`: in Godot 4.7.2 every play() creates a NEW playback
## object (checked), so a cached one goes dead after stop() + play().

const RATE := 22050.0
## Frames pushed per chunk. The buffer is allocated once, never per frame.
const CHUNK := 512
## Seconds of audio the generator holds. 0.25 s survives a main-thread hitch
## (a synchronous scene load) without a gap; pitch changes lag by up to this much.
const BUFFER_SECONDS := 0.25
const MIN_FREQ := 20.0
const MAX_FREQ := RATE * 0.45
const FALLBACK_FREQ := 220.0
const VOLUME := 0.2
## Upper bound on chunks pushed per frame (32 × 512 frames, far more than a
## 0.25 s buffer holds), so the loop ends even if the engine kept reporting space.
const MAX_CHUNKS_PER_FRAME := 32

## Tone in Hz. Non-finite or out-of-range values are clamped, so a NaN from a
## caller's division (e.g. progress / total with total == 0) cannot poison the phase.
@export var freq := FALLBACK_FREQ
var _phase := 0.0
var _playback: AudioStreamGeneratorPlayback
var _buf := PackedVector2Array()


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = BUFFER_SECONDS
	stream = gen
	_buf.resize(CHUNK)
	set_process(false)


## Starts (or restarts) the drone and re-fetches the playback every time.
func start() -> void:
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	set_process(_playback != null)


## Stops the drone and the per-frame work.
func halt() -> void:
	set_process(false)
	_playback = null
	stop()


func _process(_delta: float) -> void:
	if _playback == null or not (stream is AudioStreamGenerator):
		halt()
		return
	var f := freq if is_finite(freq) else FALLBACK_FREQ
	var step := TAU * clampf(f, MIN_FREQ, MAX_FREQ) / RATE
	var budget := MAX_CHUNKS_PER_FRAME
	while budget > 0 and _playback.get_frames_available() >= CHUNK:
		budget -= 1
		for i in CHUNK:
			var s := sin(_phase) * VOLUME
			_buf[i] = Vector2(s, s)
			_phase = fmod(_phase + step, TAU)
		_playback.push_buffer(_buf)
