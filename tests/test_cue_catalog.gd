extends SceneTree
# CueCatalog: the real instrument catalog (D-239) and its mappings.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_catalog.gd

const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

func _initialize() -> void:
	var cat = CatalogScript.load_default()
	check("default loads without errors", cat.errors.is_empty(), str(cat.errors))
	check("instrument names sorted", Array(cat.instrument_names()) == ["arp", "bass", "hat", "kick", "lead", "pad", "snare"], str(cat.instrument_names()))
	check("has_instrument", cat.has_instrument("bass") and not cat.has_instrument("crash"), "")

	# Table of expected values: role, polyphony, default note, validator controls.
	var want := {
		"bass": ["bass", 4, 36, ["gain", "velocity", "legato", "lpf", "lpq"]],
		"lead": ["lead", 6, 72, ["gain", "velocity", "legato"]],
		"pad": ["pad", 4, 60, ["gain", "velocity", "legato", "lpf", "lpq"]],
		"kick": ["drums", 2, 36, ["gain", "velocity", "legato", "lpf", "lpq"]],
		"snare": ["drums", 2, 48, ["gain", "velocity", "legato", "hpf"]],
		"hat": ["drums", 4, 84, ["gain", "velocity", "legato", "hpf"]],
		"arp": ["arp", 6, 72, ["gain", "velocity", "legato"]],
	}
	var vc: Dictionary = cat.validator_catalog()
	check("validator catalog keys", Array(vc.keys()) == ["bass", "lead", "pad", "kick", "snare", "hat", "arp"], str(vc.keys()))
	for n: String in want:
		var w: Array = want[n]
		check(n + " role", cat.role(n) == w[0], cat.role(n))
		check(n + " polyphony", cat.polyphony(n) == w[1], str(cat.polyphony(n)))
		check(n + " default note", cat.default_note(n) == w[2], str(cat.default_note(n)))
		check(n + " validator controls", vc[n]["controls"] == w[3], str(vc[n]["controls"]))
		check(n + " description is non-empty", cat.description(n) != "", "")
	check("unknown instrument defaults", cat.polyphony("nope") == 4 and cat.default_note("nope") == 60 and cat.role("nope") == "", "")

	# Targets and ranges.
	check("bass lpf target", cat.control_target("bass", "lpf") == "fx0.cutoff", cat.control_target("bass", "lpf"))
	check("bass lpq target", cat.control_target("bass", "lpq") == "fx0.resonance", "")
	check("snare hpf target", cat.control_target("snare", "hpf") == "fx0.cutoff", "")
	check("gain has no target", cat.control_target("bass", "gain") == "", "")
	check("bass has no hpf", cat.control_target("bass", "hpf") == "", "")
	check("pad lpf range", cat.control_range("pad", "lpf") == Vector2(20.0, 20000.0), str(cat.control_range("pad", "lpf")))
	check("lpq range", cat.control_range("bass", "lpq") == Vector2(0.0, 1.0), "")

	# Value mapping (linear, in the filter's own units; clamped).
	check("lpf 1000 Hz maps to 1000", near(cat.map_control_value("bass", "lpf", 1000.0), 1000.0), str(cat.map_control_value("bass", "lpf", 1000.0)))
	check("lpf clamps high", near(cat.map_control_value("bass", "lpf", 50000.0), 20000.0), "")
	check("lpf clamps low", near(cat.map_control_value("bass", "lpf", -5.0), 20.0), "")
	check("lpq 0.5", near(cat.map_control_value("bass", "lpq", 0.5), 0.5), "")
	check("unknown control passes through", cat.map_control_value("bass", "pan", 0.25) == 0.25, "")

	# map_controls: targets and mapped values only, JSON order, scheduler-level and unknown keys skipped.
	var mc: Dictionary = cat.map_controls("bass", {"s": "bass", "note": 40, "gain": 0.5, "velocity": 0.9, "legato": 2.0, "lpq": 0.5, "lpf": 1000.0, "attack": 0.3})
	check("map_controls keys in JSON order", Array(mc.keys()) == ["fx0.cutoff", "fx0.resonance"], str(mc.keys()))
	check("map_controls values", near(mc["fx0.cutoff"], 1000.0) and near(mc["fx0.resonance"], 0.5), str(mc))
	check("map_controls ignores non-numbers", cat.map_controls("bass", {"lpf": "high"}).is_empty(), "")
	check("map_controls unknown instrument", cat.map_controls("nope", {"lpf": 1.0}).is_empty(), "")
	check("map_controls on lead is empty", cat.map_controls("lead", {"lpf": 1000.0, "gain": 1.0}).is_empty(), "")

	# Log curve and out range through from_dict (no ClassDB needed).
	var custom = CatalogScript.from_dict({"version": 1, "instruments": {"x": {
		"preset": "BassPreset", "role": "bass", "tags": ["t"], "description": "d", "polyphony": 99, "default_note": 40,
		"controls": {"c": {"target": "fx0.cutoff", "lo": 20, "hi": 20000, "curve": "log", "out_lo": 0.0, "out_hi": 1.0}}}}})
	check("custom catalog is clean", custom.errors.is_empty(), str(custom.errors))
	check("polyphony clamps to 32", custom.polyphony("x") == 32, str(custom.polyphony("x")))
	check("log: lo -> 0", near(custom.map_control_value("x", "c", 20.0), 0.0), "")
	check("log: hi -> 1", near(custom.map_control_value("x", "c", 20000.0), 1.0), "")
	check("log: geometric mean -> 0.5", near(custom.map_control_value("x", "c", 632.455532), 0.5), str(custom.map_control_value("x", "c", 632.455532)))
	check("log: below lo clamps to 0", near(custom.map_control_value("x", "c", 1.0), 0.0), "")

	# Malformed input is reported, never crashes.
	var bad1 = CatalogScript.from_dict({"version": 2, "instruments": {}})
	check("wrong version is an error", not bad1.errors.is_empty() and bad1.instrument_names().is_empty(), str(bad1.errors))
	var bad2 = CatalogScript.from_dict({"version": 1, "instruments": {"y": {"role": "bass"}}})
	check("missing preset is an error", not bad2.errors.is_empty() and not bad2.has_instrument("y"), str(bad2.errors))
	var bad3 = CatalogScript.from_dict({"version": 1, "instruments": {"z": {"preset": "BassPreset", "controls": {"c": {"target": "fx0.cutoff", "lo": 5, "hi": 5}}}}})
	check("empty control range is an error", not bad3.errors.is_empty(), str(bad3.errors))
	var bad4 = CatalogScript.load_file("res://does/not/exist.json")
	check("missing file is an error", not bad4.errors.is_empty() and bad4.instrument_names().is_empty(), "")

	# Prompt table.
	var lines: PackedStringArray = cat.to_prompt_table().split("\n")
	check("prompt table has 7 lines", lines.size() == 7, str(lines.size()))
	check("prompt table sorted", lines[0].begins_with("arp | ") and lines[6].begins_with("snare | "), lines[0])
	check("prompt table bass line", lines[1] == "bass | bass | low, warm | gain, velocity, legato, lpf, lpq | Low bass: square, sine and triangle layers, low-pass filter, light overdrive.", lines[1])
	check("prompt table has no trailing newline", not cat.to_prompt_table().ends_with("\n"), "")

	# Presets: classes exist, configurations build, effect 0 is the expected filter, every target resolves.
	check("preset classes are valid", cat.validate_presets().is_empty(), str(cat.validate_presets()))
	var filters := {"bass": "LowPassFilter", "lead": "BandPassFilter", "pad": "LowPassFilter", "kick": "LowPassFilter",
		"snare": "HighPassFilter", "hat": "HighPassFilter", "arp": "BandPassFilter"}
	for n: String in filters:
		var cfg = cat.create_configuration(n)
		check(n + " configuration builds", cfg != null and cfg is VASynthConfiguration, str(cfg))
		if cfg == null:
			continue
		var chain: EffectChain = cfg.effect_chain
		var effects: Array = chain.get_effects() if chain != null else []
		check(n + " has an effect chain", chain != null and effects.size() >= 2, "")
		if chain != null and effects.size() > 0:
			var fx0: Object = effects[0]
			check(n + " effect 0 is " + filters[n], fx0.get_class() == filters[n], fx0.get_class())
		var player := AudioSynthPlayer.new()
		player.configuration = cfg
		for c in cat.control_names(n):
			var target: String = cat.control_target(n, c)
			check(n + "." + c + " target resolves (" + target + ")", player.has_parameter(target), "")
		player.free()
		var cfg2 = cat.create_configuration(n)
		check(n + " configurations are independent", cfg2 != cfg, "")
	check("unknown instrument -> null configuration", cat.create_configuration("nope") == null, "")

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
