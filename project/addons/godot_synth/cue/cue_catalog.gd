class_name CueCatalog
extends RefCounted
## The real instrument catalog of the cue language (D-239). Loaded from catalog/instruments.json.

const DEFAULT_PATH := "res://addons/godot_synth/cue/catalog/instruments.json"
## Scheduler-level controls: every instrument accepts them, they are never mapped to a target.
const BASE_CONTROLS: Array[String] = ["gain", "velocity", "legato"]

## Problems found by from_dict (empty when the catalog is well formed).
var errors: Array[String] = []
var _inst: Dictionary = {}       # name -> normalised entry (below)

static func load_default() -> CueCatalog:
	return load_file(DEFAULT_PATH)

static func load_file(path: String) -> CueCatalog:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		var cat := CueCatalog.new()
		cat.errors.append(path + ": file missing or empty")
		return cat
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		var cat := CueCatalog.new()
		cat.errors.append(path + ": not a JSON object")
		return cat
	return from_dict(parsed)

static func from_dict(d: Dictionary) -> CueCatalog:
	var cat := CueCatalog.new()
	if not d.has("version") or int(d["version"]) != 1:
		cat.errors.append("version must be 1")
		return cat
	var raw_instruments: Variant = d.get("instruments")
	if not raw_instruments is Dictionary:
		cat.errors.append("instruments missing")
		return cat

	var instruments: Dictionary = raw_instruments
	for name: String in instruments:
		var raw: Variant = instruments[name]
		if not raw is Dictionary:
			cat.errors.append(name + ": preset missing")
			continue
		var entry: Dictionary = raw
		var raw_preset: Variant = entry.get("preset")
		if not raw_preset is String or String(raw_preset).is_empty():
			cat.errors.append(name + ": preset missing")
			continue

		var controls: Dictionary = {}
		var raw_controls: Variant = entry.get("controls", {})
		if raw_controls is Dictionary:
			var control_dict: Dictionary = raw_controls
			for control: String in control_dict:
				var normalised: Dictionary = cat._normalise_control(name, control, control_dict[control])
				if not normalised.is_empty():
					controls[control] = normalised

		cat._inst[name] = {
			"preset": String(raw_preset),
			"role": String(entry.get("role", "")),
			"tags": _string_array(entry.get("tags", [])),
			"description": String(entry.get("description", "")),
			"polyphony": clampi(int(entry.get("polyphony", 4)), 1, 32),
			"default_note": int(entry.get("default_note", 60)),
			"controls": controls,
		}
	return cat

func has_instrument(name: String) -> bool:
	return _inst.has(name)

func instrument_names() -> PackedStringArray:
	var names := PackedStringArray()
	for name: String in _inst:
		names.append(name)
	names.sort()
	return names

func role(name: String) -> String:
	if not _inst.has(name):
		return ""
	return String(_inst[name]["role"])

func tags(name: String) -> PackedStringArray:
	if not _inst.has(name):
		return PackedStringArray()
	return _inst[name]["tags"]

func description(name: String) -> String:
	if not _inst.has(name):
		return ""
	return String(_inst[name]["description"])

func polyphony(name: String) -> int:
	if not _inst.has(name):
		return 4
	return int(_inst[name]["polyphony"])

func default_note(name: String) -> int:
	if not _inst.has(name):
		return 60
	return int(_inst[name]["default_note"])

func control_names(name: String) -> PackedStringArray:
	var names := PackedStringArray()
	if not _inst.has(name):
		return names
	var controls: Dictionary = _inst[name]["controls"]
	for control: String in controls:
		names.append(control)
	return names

func control_target(name: String, control: String) -> String:
	if not _inst.has(name):
		return ""
	var controls: Dictionary = _inst[name]["controls"]
	if not controls.has(control):
		return ""
	return String(controls[control]["target"])

func control_range(name: String, control: String) -> Vector2:
	if not _inst.has(name):
		return Vector2(0.0, 1.0)
	var controls: Dictionary = _inst[name]["controls"]
	if not controls.has(control):
		return Vector2(0.0, 1.0)
	var spec: Dictionary = controls[control]
	return Vector2(float(spec["lo"]), float(spec["hi"]))

func map_control_value(name: String, control: String, v: float) -> float:
	if not _inst.has(name):
		return v
	var controls: Dictionary = _inst[name]["controls"]
	if not controls.has(control):
		return v
	var spec: Dictionary = controls[control]
	var lo := float(spec["lo"])
	var hi := float(spec["hi"])
	var x := clampf(v, lo, hi)
	var t: float
	if String(spec["curve"]) == "log" and lo > 0.0:
		t = log(x / lo) / log(hi / lo)
	else:
		t = (x - lo) / (hi - lo)
	var out_lo := float(spec["out_lo"])
	var out_hi := float(spec["out_hi"])
	return out_lo + t * (out_hi - out_lo)

func map_controls(name: String, hap_value: Dictionary) -> Dictionary:
	var mapped: Dictionary = {}
	if not _inst.has(name):
		return mapped
	var controls: Dictionary = _inst[name]["controls"]
	for control: String in controls:
		if not hap_value.has(control):
			continue
		var v: Variant = hap_value[control]
		if not (v is int or v is float):
			continue
		mapped[String(controls[control]["target"])] = map_control_value(name, control, float(v))
	return mapped

func validator_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for name: String in _inst:
		var controls: Array = []
		for control: String in BASE_CONTROLS:
			controls.append(control)
		for control: String in control_names(name):
			controls.append(control)
		catalog[name] = {"controls": controls}
	return catalog

func to_prompt_table() -> String:
	var catalog := validator_catalog()
	var lines := PackedStringArray()
	for name: String in instrument_names():
		var control_names_all: Array = catalog[name]["controls"]
		var controls_text := ", ".join(PackedStringArray(control_names_all))
		var tags_text := ", ".join(tags(name))
		lines.append(name + " | " + role(name) + " | " + tags_text + " | " + controls_text + " | " + description(name))
	return "\n".join(lines)

func create_configuration(name: String) -> SynthConfiguration:
	if not _inst.has(name):
		return null
	var preset_name: String = _inst[name]["preset"]
	if not ClassDB.class_exists(preset_name):
		push_error("CueCatalog: preset class '" + preset_name + "' not found")
		return null
	if not ClassDB.is_parent_class(preset_name, "VASynthPreset"):
		push_error("CueCatalog: preset class '" + preset_name + "' is not a VASynthPreset")
		return null
	var preset := ClassDB.instantiate(preset_name) as VASynthPreset
	if preset == null:
		push_error("CueCatalog: preset class '" + preset_name + "' could not be instantiated")
		return null
	var cfg := VASynthConfiguration.new()
	cfg.set_preset(preset)
	return cfg

func validate_presets() -> Array[String]:
	var problems: Array[String] = []
	for name: String in _inst:
		var preset_name: String = _inst[name]["preset"]
		if not ClassDB.class_exists(preset_name):
			problems.append(name + ": preset class '" + preset_name + "' not found")
		elif not ClassDB.is_parent_class(preset_name, "VASynthPreset"):
			problems.append(name + ": preset class '" + preset_name + "' is not a VASynthPreset")
	return problems

func _normalise_control(name: String, control: String, raw: Variant) -> Dictionary:
	var label := name + "." + control
	if not raw is Dictionary:
		errors.append(label + ": control must be an object")
		return {}
	var spec: Dictionary = raw

	var raw_target: Variant = spec.get("target")
	if not raw_target is String or String(raw_target).is_empty():
		errors.append(label + ": target missing")
		return {}
	var target := String(raw_target)

	var raw_lo: Variant = spec.get("lo")
	var raw_hi: Variant = spec.get("hi")
	if not _is_number(raw_lo) or not _is_number(raw_hi):
		errors.append(label + ": lo and hi must be numbers")
		return {}
	var lo := float(raw_lo)
	var hi := float(raw_hi)
	if lo >= hi:
		errors.append(label + ": lo must be less than hi")
		return {}

	var curve := String(spec.get("curve", "linear"))
	if curve != "linear" and curve != "log":
		errors.append(label + ": curve must be 'linear' or 'log'")
		return {}

	var raw_out_lo: Variant = spec.get("out_lo", lo)
	var raw_out_hi: Variant = spec.get("out_hi", hi)
	if not _is_number(raw_out_lo) or not _is_number(raw_out_hi):
		errors.append(label + ": out_lo and out_hi must be numbers")
		return {}

	return {
		"target": target,
		"lo": lo,
		"hi": hi,
		"curve": curve,
		"out_lo": float(raw_out_lo),
		"out_hi": float(raw_out_hi),
	}

func _is_number(v: Variant) -> bool:
	return v is int or v is float

static func _string_array(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if v is Array:
		for item: Variant in v:
			out.append(String(item))
	return out
