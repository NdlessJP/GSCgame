class_name AudioDirector
extends Node
## Procedural sound effects for the battle.
##
## The project ships without imported audio, so every clip is synthesised at
## start-up into an [AudioStreamWAV].  That keeps the repository asset free
## while still giving the battle audible feedback.
##
## The director is an autoload (`Audio`), so both the menus and the battle
## scene can reach it.  Call [method play] with one of the [enum Sfx] values.

enum Sfx {
	HIT,
	CRIT,
	BREAK,
	HEAL,
	SHIELD,
	WARNING,
	WAVE,
	VICTORY,
	DEFEAT,
	CLICK,
}

const MIX_RATE: int = 22050
const VOICE_COUNT: int = 8
## Minimum delay between two identical sounds, so a burst of hits does not
## turn into a wall of noise.
const THROTTLE: float = 0.055

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20241031
	for index in range(VOICE_COUNT):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)
	_build_streams()


## Plays one of the [enum Sfx] sounds.  Returns false when the sound was
## throttled or the audio device is unavailable.
func play(sound: int, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if not _streams.has(sound) or _players.is_empty():
		return false
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var last: float = float(_last_played.get(sound, -99.0))
	if now - last < THROTTLE:
		return false
	_last_played[sound] = now
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()
	return true


## Returns the synthesised stream for a sound, or null when it is unknown.
## Used by the test suite to verify that every clip really contains audio.
func stream_for(sound: int) -> AudioStreamWAV:
	return _streams.get(sound, null)


## Convenience helper so callers can use a readable name.
func play_named(sound_name: String, volume_db: float = 0.0) -> bool:
	var key: String = sound_name.to_upper()
	for value in Sfx.values():
		if String(value).to_upper() == key:
			return play(int(value), volume_db)
	return false


# --------------------------------------------------------------------------
# Synthesis
# --------------------------------------------------------------------------

func _build_streams() -> void:
	_streams[Sfx.HIT] = _to_stream(_synth(0.13, 340.0, 90.0, 0.55, 0.55, 0))
	_streams[Sfx.CRIT] = _to_stream(_synth(0.24, 980.0, 420.0, 0.22, 0.50, 0))
	_streams[Sfx.BREAK] = _to_stream(_synth(0.55, 430.0, 70.0, 0.38, 0.60, 1))
	_streams[Sfx.HEAL] = _to_stream(_synth(0.38, 520.0, 1040.0, 0.0, 0.34, 0))
	_streams[Sfx.SHIELD] = _to_stream(_synth(0.26, 760.0, 720.0, 0.08, 0.30, 1))
	_streams[Sfx.WARNING] = _to_stream(_concat([
		_synth(0.16, 470.0, 470.0, 0.12, 0.42, 1),
		_synth(0.22, 360.0, 360.0, 0.12, 0.42, 1),
	]))
	_streams[Sfx.WAVE] = _to_stream(_synth(0.46, 170.0, 620.0, 0.45, 0.40, 0))
	_streams[Sfx.VICTORY] = _to_stream(_concat([
		_synth(0.16, 523.0, 523.0, 0.0, 0.34, 0),
		_synth(0.16, 659.0, 659.0, 0.0, 0.34, 0),
		_synth(0.40, 784.0, 784.0, 0.0, 0.36, 0),
	]))
	_streams[Sfx.DEFEAT] = _to_stream(_concat([
		_synth(0.22, 392.0, 392.0, 0.0, 0.32, 0),
		_synth(0.22, 311.0, 311.0, 0.0, 0.32, 0),
		_synth(0.52, 233.0, 196.0, 0.05, 0.34, 0),
	]))
	_streams[Sfx.CLICK] = _to_stream(_synth(0.05, 1250.0, 900.0, 0.0, 0.26, 1))


## Generates a single tone with a pitch sweep, an optional noise mix and an
## attack/decay envelope.  `shape` 0 = sine, 1 = square.
func _synth(duration: float, f0: float, f1: float, noise_mix: float, volume: float, shape: int) -> PackedFloat32Array:
	var count: int = maxi(1, int(duration * MIX_RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	for index in count:
		var t: float = float(index) / float(count)
		var frequency: float = lerpf(f0, f1, t)
		phase += TAU * frequency / float(MIX_RATE)
		var wave_sample: float = sin(phase)
		if shape == 1:
			wave_sample = 1.0 if wave_sample >= 0.0 else -1.0
		var mixed: float = lerpf(wave_sample, _rng.randf_range(-1.0, 1.0), noise_mix)
		var attack: float = minf(1.0, t / 0.015)
		var decay: float = pow(1.0 - t, 2.0)
		out[index] = mixed * attack * decay * volume
	return out


func _concat(parts: Array) -> PackedFloat32Array:
	var total: int = 0
	for part: PackedFloat32Array in parts:
		total += part.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	var offset: int = 0
	for part: PackedFloat32Array in parts:
		for index in part.size():
			out[offset + index] = part[index]
		offset += part.size()
	return out


## Converts float samples into a 16 bit mono [AudioStreamWAV].
func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		var value: int = int(clampf(samples[index], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(index * 2, value)
	stream.data = bytes
	return stream
