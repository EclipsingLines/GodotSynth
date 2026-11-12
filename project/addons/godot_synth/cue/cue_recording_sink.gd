class_name CueRecordingSink
extends CueSink
## Records every event in call order.
## note:      {type: "note", track, note, velocity, on_frame, off_frame, controls}
## param:     {type: "param", track, name, value, frame}
## gain_ramp: {type: "gain_ramp", group, gain, frame, ramp_frames}
var events: Array[Dictionary] = []

func clear() -> void:
	events.clear()

func of_type(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["type"] == type:
			out.append(e)
	return out

func note(track: String, note: float, velocity: float, on_frame: int, off_frame: int, controls: Dictionary) -> void:
	events.append({
		"type": "note",
		"track": track,
		"note": note,
		"velocity": velocity,
		"on_frame": on_frame,
		"off_frame": off_frame,
		"controls": controls.duplicate(),
	})

func param(track: String, name: String, value: float, frame: int) -> void:
	events.append({
		"type": "param",
		"track": track,
		"name": name,
		"value": value,
		"frame": frame,
	})

func gain_ramp(group: String, gain: float, frame: int, ramp_frames: int) -> void:
	events.append({
		"type": "gain_ramp",
		"group": group,
		"gain": gain,
		"frame": frame,
		"ramp_frames": ramp_frames,
	})
