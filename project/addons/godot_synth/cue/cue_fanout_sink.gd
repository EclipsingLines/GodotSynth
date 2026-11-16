class_name CueFanoutSink
extends CueSink
## Forwards every call to each child sink in order.

var sinks: Array[CueSink] = []

func _init(p_sinks: Array[CueSink] = []) -> void:
	sinks = p_sinks

func note(track: String, note: float, velocity: float, on_frame: int, off_frame: int, controls: Dictionary) -> void:
	for s: CueSink in sinks:
		s.note(track, note, velocity, on_frame, off_frame, controls)

func param(track: String, name: String, value: float, frame: int) -> void:
	for s: CueSink in sinks:
		s.param(track, name, value, frame)

func gain_ramp(group: String, gain: float, frame: int, ramp_frames: int) -> void:
	for s: CueSink in sinks:
		s.gain_ramp(group, gain, frame, ramp_frames)
