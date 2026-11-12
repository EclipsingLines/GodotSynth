class_name CueSink
extends RefCounted
## Receives the events a CueScheduler/CueConductor produces. Frames are relative to cycle 0 of the cue.
## The base class ignores everything; subclasses record (CueRecordingSink) or play (live/offline sinks).

func note(_track: String, _note: float, _velocity: float, _on_frame: int, _off_frame: int, _controls: Dictionary) -> void:
	pass

func param(_track: String, _name: String, _value: float, _frame: int) -> void:
	pass

func gain_ramp(_group: String, _gain: float, _frame: int, _ramp_frames: int) -> void:
	pass
