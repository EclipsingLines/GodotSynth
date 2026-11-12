class_name CueOfflineSink
extends CueSink
## Renders cue events into a SynthOfflineMixer. Same calls, same rounding as CueLiveSink.
## Frames from the scheduler are relative to cycle 0; origin_frame is the mixer frame of cycle 0.

var mixer: SynthOfflineMixer
var track_index: Dictionary = {} # "group/instrument" -> int (mixer track)
var groups: Dictionary = {} # group -> Array[int] (mixer tracks)
var origin_frame: int = 0

var _warned: Dictionary = {}

func _init(p_mixer: SynthOfflineMixer = null) -> void:
	mixer = p_mixer

func register_track(group: String, instrument: String, index: int) -> void:
	track_index[group + "/" + instrument] = index
	if not groups.has(group):
		groups[group] = []
	groups[group].append(index)

func note(track: String, note: float, velocity: float, on_frame: int, off_frame: int, controls: Dictionary) -> void:
	if mixer == null:
		return
	if not track_index.has(track):
		_warn_unknown(track)
		return
	if origin_frame + on_frame < 0:
		return
	var index: int = track_index[track]
	mixer.schedule_note(index, float(roundi(note)), velocity, origin_frame + on_frame, origin_frame + off_frame, controls)

func param(track: String, name: String, value: float, frame: int) -> void:
	if mixer == null:
		return
	if not track_index.has(track):
		_warn_unknown(track)
		return
	var index: int = track_index[track]
	mixer.schedule_parameter(index, name, value, maxi(origin_frame + frame, 0))

func gain_ramp(group: String, gain: float, frame: int, ramp_frames: int) -> void:
	if mixer == null:
		return
	if not groups.has(group):
		_warn_unknown(group)
		return
	for index: int in groups[group]:
		mixer.schedule_gain_ramp(index, gain, maxi(origin_frame + frame, 0), ramp_frames)

func _warn_unknown(name: String) -> void:
	if _warned.has(name):
		return
	_warned[name] = true
	push_warning("CueOfflineSink: no track for '" + name + "'")
