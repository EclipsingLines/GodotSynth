class_name CueRenderer
extends RefCounted
## Renders a cue plus a scripted scenario to frames and a WAV file without an audio device.
##
## The render uses the same CueConductor, CueScheduler and mixer path as live play:
## cue events are fanned out to a CueOfflineSink (which schedules the audio) and a
## CueRecordingSink (which records the events for inspection).

const WINDOW_CYCLES: float = 1.0 / 32.0
const MAX_FRAMES: int = 1 << 24

const ParserScript = preload("res://addons/godot_synth/cue/cue_parser.gd")
const ValidatorScript = preload("res://addons/godot_synth/cue/cue_validator.gd")
const LibScript = preload("res://addons/godot_synth/cue/cue_lib.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")
const ScanScript = preload("res://addons/godot_synth/cue/cue_scan.gd")
const OfflineSinkScript = preload("res://addons/godot_synth/cue/cue_offline_sink.gd")
const RecordingSinkScript = preload("res://addons/godot_synth/cue/cue_recording_sink.gd")
const ConductorScript = preload("res://addons/godot_synth/cue/cue_conductor.gd")
const FanoutScript = preload("res://addons/godot_synth/cue/cue_fanout_sink.gd")

## {duration_cycles: 8.0, sample_rate: 44100, tail_sec: 2.0, events: []}
static func default_scenario() -> Dictionary:
	return {
		"duration_cycles": 8.0,
		"sample_rate": 44100,
		"tail_sec": 2.0,
		"events": [],
	}

## Checks the scenario against the compiled cue and normalizes it.
## Returns {diagnostics: Array, scenario: Dictionary}. The normalized scenario is
## {duration_cycles: float, sample_rate: int, tail_sec: float,
##  events: Array of {at: float, kind: "set_state"|"stinger"|"set_param", name: String, value: float}}
## sorted by (at, original index). Defaults are filled in. If diagnostics is non-empty the
## scenario must not be used.
static func validate_scenario(scenario: Dictionary, compiled: Dictionary) -> Dictionary:
	var diagnostics: Array = []
	var defaults := default_scenario()
	var duration: float = float(defaults["duration_cycles"])
	var sample_rate: int = int(defaults["sample_rate"])
	var tail_sec: float = float(defaults["tail_sec"])
	var input_events: Array = []

	for key: Variant in scenario.keys():
		var name := String(key)
		match name:
			"duration_cycles", "sample_rate", "tail_sec", "events":
				pass
			_:
				diagnostics.append(_diag("unknown scenario key '" + name + "'"))

	if scenario.has("duration_cycles"):
		var raw: Variant = scenario["duration_cycles"]
		if not _is_number(raw):
			diagnostics.append(_diag("duration_cycles must be a number (got " + _value_text(raw) + ")"))
		else:
			duration = float(raw)
			if duration <= 0.0:
				diagnostics.append(_diag("duration_cycles must be greater than 0 (got " + _value_text(raw) + ")"))
	if scenario.has("sample_rate"):
		var raw: Variant = scenario["sample_rate"]
		if not _is_number(raw) or not _is_whole_number(raw):
			diagnostics.append(_diag("sample_rate must be a whole number (got " + _value_text(raw) + ")"))
		else:
			sample_rate = int(raw)
			if sample_rate < 8000 or sample_rate > 192000:
				diagnostics.append(_diag("sample_rate must be between 8000 and 192000 (got " + _value_text(raw) + ")"))
	if scenario.has("tail_sec"):
		var raw: Variant = scenario["tail_sec"]
		if not _is_number(raw):
			diagnostics.append(_diag("tail_sec must be a number (got " + _value_text(raw) + ")"))
		else:
			tail_sec = float(raw)
			if tail_sec < 0.0 or tail_sec > 30.0:
				diagnostics.append(_diag("tail_sec must be between 0 and 30 (got " + _value_text(raw) + ")"))
	if scenario.has("events"):
		var raw: Variant = scenario["events"]
		if not raw is Array:
			diagnostics.append(_diag("events must be an array (got " + _value_text(raw) + ")"))
		else:
			input_events = raw

	var normalized: Array = []
	var actions: Array[String] = ["set_state", "stinger", "set_param"]
	for index: int in range(input_events.size()):
		var raw_event: Variant = input_events[index]
		if not raw_event is Dictionary:
			diagnostics.append(_diag("event %d: must be an object (got %s)" % [index, _value_text(raw_event)]))
			continue
		var event: Dictionary = raw_event
		var at: float = 0.0
		var at_ok := false
		if not event.has("at") or not _is_number(event["at"]):
			diagnostics.append(_diag("event %d: at must be a number (got %s)" % [index, _value_text(event.get("at"))]))
		else:
			at = float(event["at"])
			at_ok = true
			if at < 0.0 or at >= duration:
				diagnostics.append(_diag("event %d: at %s is outside 0 <= at < duration_cycles" % [index, _value_text(event["at"])]))
				at_ok = false
		for key: Variant in event.keys():
			var key_name := String(key)
			if key_name != "at" and key_name != "set_state" and key_name != "stinger" and key_name != "set_param" and key_name != "value":
				diagnostics.append(_diag("event %d: unknown key '%s'" % [index, key_name]))

		var found: Array[String] = []
		for action: String in actions:
			if event.has(action):
				found.append(action)
		if found.size() != 1:
			diagnostics.append(_diag("event %d: needs exactly one of set_state, stinger or set_param (got %d)" % [index, found.size()]))
			continue

		var kind := found[0]
		var raw_name: Variant = event[kind]
		if not raw_name is String or String(raw_name).is_empty():
			diagnostics.append(_diag("event %d: %s must be a non-empty string (got %s)" % [index, kind, _value_text(raw_name)]))
			continue
		var name := String(raw_name)
		if kind == "set_state" and not compiled["states"].has(name):
			diagnostics.append(_diag("event %d: unknown state '%s'" % [index, name]))
			continue
		if kind == "stinger" and not compiled["stingers"].has(name):
			diagnostics.append(_diag("event %d: unknown stinger '%s'" % [index, name]))
			continue

		var value := 0.0
		if kind == "set_param":
			if not compiled["params"].has(name):
				diagnostics.append(_diag("event %d: unknown param '%s'" % [index, name]))
				continue
			if not event.has("value"):
				diagnostics.append(_diag("event %d: set_param '%s' needs a value" % [index, name]))
				continue
			if not _is_number(event["value"]):
				diagnostics.append(_diag("event %d: set_param '%s' value must be a number (got %s)" % [index, name, _value_text(event["value"])]))
				continue
			value = float(event["value"])
		elif event.has("value"):
			diagnostics.append(_diag("event %d: value is only allowed with set_param" % index))
			continue

		if at_ok:
			normalized.append({"at": at, "kind": kind, "name": name, "value": value, "_index": index})

	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["at"]) != float(b["at"]):
			return float(a["at"]) < float(b["at"])
		return int(a["_index"]) < int(b["_index"])
	)
	var events: Array = []
	for entry: Dictionary in normalized:
		events.append({
			"at": float(entry["at"]),
			"kind": String(entry["kind"]),
			"name": String(entry["name"]),
			"value": float(entry["value"]),
		})

	var tempo: Dictionary = compiled["tempo"]
	var cps: float = float(tempo["bpm"]) / 60.0 / float(tempo["beats"])
	if cps > 0.0:
		var total_frames: int = roundi(duration / cps * float(sample_rate)) + roundi(tail_sec * float(sample_rate))
		if total_frames > MAX_FRAMES:
			diagnostics.append(_diag("render too long: %d frames exceeds the maximum of %d" % [total_frames, MAX_FRAMES]))

	return {
		"diagnostics": diagnostics,
		"scenario": {
			"duration_cycles": duration,
			"sample_rate": sample_rate,
			"tail_sec": tail_sec,
			"events": events,
		},
	}

## Renders. Result keys (always all present):
##   ok: bool
##   diagnostics: Array        parse/validate/compile/scenario diagnostics (warnings kept on success)
##   sample_rate: int          0 on failure
##   cps: float                bpm / 60 / beats of the cue (0.0 on failure)
##   duration_cycles: float
##   frames: PackedVector2Array   empty on failure
##   events: Array             the CueRecordingSink events (frames relative to cycle 0)
##   log: Array                the conductor log (get_log())
##   sections: Array           [{state, start_cycle, end_cycle, start_frame, end_frame}]
static func render(source: String, scenario: Dictionary, catalog: CueCatalog) -> Dictionary:
	var parsed: Dictionary = ParserScript.parse(source)
	if not bool(parsed.get("ok", false)):
		return _failure(parsed.get("diagnostics", []))

	var diagnostics: Array = []
	for diagnostic: Dictionary in ValidatorScript.validate(parsed["ast"], catalog.validator_catalog()):
		diagnostics.append(diagnostic)
	for diagnostic: Dictionary in diagnostics:
		if String(diagnostic.get("severity", "")) == "error":
			return _failure(diagnostics)

	var compiled: Dictionary = LibScript.compile(parsed["ast"], 0)
	var compile_errors: Array = compiled.get("errors", [])
	if not compile_errors.is_empty():
		for error: Dictionary in compile_errors:
			diagnostics.append({
				"code": String(error.get("code", "")),
				"message": String(error.get("message", "")),
				"line": int(error.get("line", 0)),
				"col": int(error.get("col", 0)),
				"severity": "error",
			})
		return _failure(diagnostics)

	var tempo: Dictionary = compiled["tempo"]
	var cps: float = float(tempo["bpm"]) / 60.0 / float(tempo["beats"])
	var validated: Dictionary = validate_scenario(scenario, compiled)
	var scenario_diagnostics: Array = validated["diagnostics"]
	if not scenario_diagnostics.is_empty():
		for diagnostic: Dictionary in scenario_diagnostics:
			diagnostics.append(diagnostic)
		return _failure(diagnostics)

	var normalized: Dictionary = validated["scenario"]
	var duration: float = float(normalized["duration_cycles"])
	var sample_rate: int = int(normalized["sample_rate"])
	var tail_sec: float = float(normalized["tail_sec"])
	var events: Array = normalized["events"]

	var mixer := SynthOfflineMixer.new()
	if not mixer.init(sample_rate):
		diagnostics.append(_diag("cannot initialize the offline mixer at %d Hz" % sample_rate))
		return _failure(diagnostics)
	var scan: Dictionary = ScanScript.instruments(parsed["ast"])
	var offline := OfflineSinkScript.new(mixer)
	var group_keys: Array = scan.keys()
	group_keys.sort()
	for group_key: Variant in group_keys:
		var group := String(group_key)
		var instruments: PackedStringArray = scan[group_key]
		var names: Array = []
		for instrument: Variant in instruments:
			names.append(String(instrument))
		names.sort()
		for instrument: String in names:
			var config: SynthConfiguration = catalog.create_configuration(instrument)
			if config == null:
				diagnostics.append(_diag("cannot create a configuration for '" + instrument + "'"))
				return _failure(diagnostics)
			var index: int = mixer.add_track(config, catalog.polyphony(instrument))
			offline.register_track(group, instrument, index)

	var transport := SynthTransport.new()
	transport.sample_rate = sample_rate
	transport.reset_tempo(cps)
	var recording := RecordingSinkScript.new()
	var sinks: Array[CueSink] = [offline, recording]
	var fanout := FanoutScript.new(sinks)
	var conductor := ConductorScript.new(compiled, catalog, fanout, transport.cycle_to_frame, scan)
	conductor.start()

	var n_windows: int = ceili(duration / WINDOW_CYCLES - 1e-9)
	var next_event: int = 0
	for k: int in range(n_windows):
		var from_c: float = float(k) * WINDOW_CYCLES
		var to_c: float = minf(float(k + 1) * WINDOW_CYCLES, duration)
		while next_event < events.size() and float(events[next_event]["at"]) < to_c:
			var event: Dictionary = events[next_event]
			match String(event["kind"]):
				"set_state":
					conductor.set_state(String(event["name"]))
				"stinger":
					conductor.stinger(String(event["name"]))
				"set_param":
					conductor.set_param(String(event["name"]), float(event["value"]))
			next_event += 1
		conductor.process_window(from_c, to_c)

	var total_frames: int = transport.cycle_to_frame(duration) + roundi(tail_sec * float(sample_rate))
	var frames: PackedVector2Array = mixer.render(total_frames)
	var log: Array[Dictionary] = conductor.get_log()
	var sections: Array = _build_sections(compiled, log, duration, total_frames, transport)
	transport.free()

	return {
		"ok": true,
		"diagnostics": diagnostics,
		"sample_rate": sample_rate,
		"cps": cps,
		"duration_cycles": duration,
		"frames": frames,
		"events": recording.events,
		"log": log,
		"sections": sections,
	}

## 16-bit stereo AudioStreamWAV from the frames: per channel clampi(roundi(v * 32767.0), -32768, 32767)
## (NaN gives 0), little-endian via PackedByteArray.encode_s16, mix_rate = sample_rate.
static func to_wav(frames: PackedVector2Array, sample_rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	for i: int in range(frames.size()):
		data.encode_s16(i * 4, _to_s16(frames[i].x))
		data.encode_s16(i * 4 + 2, _to_s16(frames[i].y))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = true
	wav.data = data
	return wav

## to_wav(...).save_to_wav(path); returns the Error.
static func save_wav(frames: PackedVector2Array, sample_rate: int, path: String) -> int:
	return to_wav(frames, sample_rate).save_to_wav(path)

## Full CLI logic without touching the engine. args = user args after "--".
## Returns {lines: Array[String], exit_code: int, error: String}.
static func run(args: PackedStringArray) -> Dictionary:
	var cue_path := ""
	var out_path := ""
	var scenario_path := ""
	var catalog_path := ""
	var i := 0
	while i < args.size():
		var arg := String(args[i])
		if arg == "--scenario" or arg == "--out" or arg == "--catalog":
			if i + 1 >= args.size() or String(args[i + 1]).begins_with("--"):
				return _usage_error()
			match arg:
				"--scenario":
					scenario_path = String(args[i + 1])
				"--out":
					out_path = String(args[i + 1])
				"--catalog":
					catalog_path = String(args[i + 1])
			i += 2
		elif arg.begins_with("--"):
			return _usage_error()
		else:
			if not cue_path.is_empty():
				return _usage_error()
			cue_path = arg
			i += 1
	if cue_path.is_empty() or out_path.is_empty():
		return _usage_error()

	if not FileAccess.file_exists(cue_path):
		return _cli_error("cannot read " + cue_path)
	var cue_file := FileAccess.open(cue_path, FileAccess.READ)
	if cue_file == null:
		return _cli_error("cannot read " + cue_path)
	var source := cue_file.get_as_text()
	cue_file.close()

	var scenario: Dictionary = default_scenario()
	if not scenario_path.is_empty():
		if not FileAccess.file_exists(scenario_path):
			return _cli_error("cannot read " + scenario_path)
		var scenario_file := FileAccess.open(scenario_path, FileAccess.READ)
		if scenario_file == null:
			return _cli_error("cannot read " + scenario_path)
		var scenario_text := scenario_file.get_as_text()
		scenario_file.close()
		var parsed_scenario: Variant = JSON.parse_string(scenario_text)
		if not parsed_scenario is Dictionary:
			return _cli_error("scenario is not a JSON object: " + scenario_path)
		scenario = parsed_scenario

	var catalog: CueCatalog = CatalogScript.load_default()
	if not catalog_path.is_empty():
		if not FileAccess.file_exists(catalog_path):
			return _cli_error("cannot read " + catalog_path)
		var catalog_file := FileAccess.open(catalog_path, FileAccess.READ)
		if catalog_file == null:
			return _cli_error("cannot read " + catalog_path)
		var catalog_text := catalog_file.get_as_text()
		catalog_file.close()
		var parsed_catalog: Variant = JSON.parse_string(catalog_text)
		if not parsed_catalog is Dictionary:
			return _cli_error("catalog is not a JSON object: " + catalog_path)
		catalog = CatalogScript.from_dict(parsed_catalog)
		if not catalog.errors.is_empty():
			return _cli_error("invalid catalog " + catalog_path + ": " + str(catalog.errors))
	elif not catalog.errors.is_empty():
		return _cli_error("cannot load the default instrument catalog: " + str(catalog.errors))

	var result: Dictionary = render(source, scenario, catalog)
	if not bool(result["ok"]):
		var bad_lines: Array[String] = [JSON.stringify({"ok": false, "diagnostics": result["diagnostics"]}, "", false)]
		return {"lines": bad_lines, "exit_code": 1, "error": ""}

	var sample_rate: int = int(result["sample_rate"])
	var frames: PackedVector2Array = result["frames"]
	var save_error: int = save_wav(frames, sample_rate, out_path)
	if save_error != OK:
		return _cli_error("cannot write " + out_path)
	var frame_count := frames.size()
	var lines: Array[String] = [JSON.stringify({
		"ok": true,
		"out": out_path,
		"sample_rate": sample_rate,
		"frames": frame_count,
		"seconds": float(frame_count) / float(sample_rate),
		"diagnostics": result["diagnostics"],
	}, "", false)]
	return {"lines": lines, "exit_code": 0, "error": ""}

static func _build_sections(compiled: Dictionary, log: Array[Dictionary], duration: float, total_frames: int, transport: SynthTransport) -> Array:
	var sections: Array = []
	var states: Dictionary = compiled["states"]
	if states.is_empty():
		return sections
	var current_state := String(states.keys()[0])
	var current_start := 0.0
	for entry: Dictionary in log:
		if String(entry.get("type", "")) != "switch":
			continue
		var cycle := float(entry["cycle"])
		if cycle > current_start:
			sections.append({
				"state": current_state,
				"start_cycle": current_start,
				"end_cycle": cycle,
				"start_frame": transport.cycle_to_frame(current_start),
				"end_frame": transport.cycle_to_frame(cycle),
			})
		current_state = String(entry["to"])
		current_start = cycle
	sections.append({
		"state": current_state,
		"start_cycle": current_start,
		"end_cycle": duration,
		"start_frame": transport.cycle_to_frame(current_start),
		"end_frame": total_frames,
	})
	return sections

static func _failure(diagnostics: Array) -> Dictionary:
	return {
		"ok": false,
		"diagnostics": diagnostics,
		"sample_rate": 0,
		"cps": 0.0,
		"duration_cycles": 0.0,
		"frames": PackedVector2Array(),
		"events": [],
		"log": [],
		"sections": [],
	}

static func _diag(message: String) -> Dictionary:
	return {"code": "E_SCENARIO", "message": message, "line": 0, "col": 0, "severity": "error"}

static func _is_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var number := float(value)
		return not is_nan(number) and not is_inf(number)
	return false

static func _is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number == floorf(number)

static func _value_text(value: Variant) -> String:
	if value == null:
		return "null"
	return str(value)

static func _to_s16(value: float) -> int:
	if is_nan(value):
		return 0
	return clampi(roundi(value * 32767.0), -32768, 32767)

static func _usage_error() -> Dictionary:
	return {
		"lines": [],
		"exit_code": 2,
		"error": "usage: cue_render <cue-file> --out <wav> [--scenario <json>] [--catalog <instruments.json>]",
	}

static func _cli_error(message: String) -> Dictionary:
	return {"lines": [], "exit_code": 2, "error": message}
