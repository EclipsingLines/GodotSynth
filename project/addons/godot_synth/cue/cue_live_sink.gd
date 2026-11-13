class_name CueLiveSink
extends CueSink
## Plays cue events on AudioSynthPlayer nodes. Frames from the scheduler are relative to cycle 0;
## origin_frame is the players' clock value of cycle 0 (SynthTransport.origin_frame).

var tracks: Dictionary = {} # "group/instrument" -> AudioSynthPlayer
var groups: Dictionary = {} # group -> Array[AudioSynthPlayer]
var origin_frame: int = 0
## The last SynthNoteContext returned per track by schedule_note (diagnostics and tests).
var last_contexts: Dictionary = {}

var _warned: Dictionary = {}

func register_player(group: String, instrument: String, player: AudioSynthPlayer) -> void:
	tracks[group + "/" + instrument] = player
	if not groups.has(group):
		groups[group] = []
	groups[group].append(player)

func note(track: String, note: float, velocity: float, on_frame: int, off_frame: int, controls: Dictionary) -> void:
	if not tracks.has(track):
		_warn_unknown(track)
		return
	if origin_frame + on_frame < 0:
		return
	var player: AudioSynthPlayer = tracks[track]
	var ctx: SynthNoteContext = player.schedule_note(roundi(note), velocity, origin_frame + on_frame, origin_frame + off_frame, controls)
	if ctx != null:
		last_contexts[track] = ctx

func param(track: String, name: String, value: float, frame: int) -> void:
	if not tracks.has(track):
		_warn_unknown(track)
		return
	var player: AudioSynthPlayer = tracks[track]
	player.schedule_parameter(name, value, origin_frame + frame)

func gain_ramp(group: String, gain: float, frame: int, ramp_frames: int) -> void:
	if not groups.has(group):
		_warn_unknown(group)
		return
	for player: AudioSynthPlayer in groups[group]:
		player.schedule_gain_ramp(gain, origin_frame + frame, ramp_frames)

func _warn_unknown(name: String) -> void:
	if _warned.has(name):
		return
	_warned[name] = true
	push_warning("CueLiveSink: no player for '" + name + "'")
