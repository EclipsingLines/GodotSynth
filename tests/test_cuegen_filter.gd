extends SceneTree
# CueGenFilter: cue extraction, normalised-text hash, metric reasons and the check/accept pipeline.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cuegen_filter.gd

const FilterScript = preload("res://addons/godot_synth/cue/gen/cue_gen_filter.gd")

const VALID_A: String = "tempo 96\nstate a:\n  n(\"0 ~ 0 3\").scale(\"D:minor\").s(\"bass\").gain(0.05)\n  s(\"kick(3,8)\").gain(0.05)\n  s(\"hat*8\").gain(0.05)\n"
# same cue as VALID_A, differing only in comments and spacing
const DUP_A: String = "// forest music\ntempo   96\n\nstate a:   // main\n  n(\"0 ~ 0 3\").scale(\"D:minor\").s(\"bass\").gain(0.05)\n  s(\"kick(3,8)\").gain(0.05)   \n  s(\"hat*8\").gain(0.05) // hats\n"
const VALID_B: String = "tempo 120\nstate a:\n  n(\"0 2 4 5\").scale(\"C4:major\").s(\"lead\").gain(0.05)\n  s(\"kick ~ snare ~\").gain(0.05)\n"
const SYNTAX_ERR: String = "tempo 96\nstate a:\n  s(\"kick\" =>\n"
const UNKNOWN_INSTRUMENT: String = "tempo 96\nstate a:\n  s(\"banjo\")\n"
# one kick every 8 cycles: almost all of the 8-cycle render is silence
const SILENT: String = "tempo 96\nstate a:\n  s(\"kick ~ ~ ~ ~ ~ ~ ~\").slow(8)\n"

var _fails: int = 0
var _checks: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("PASS ", label)
	else:
		_fails += 1
		print("FAIL %s: %s" % [label, detail])


func _initialize() -> void:
	# extract_cue
	_check("extract: plain text", FilterScript.extract_cue("  tempo 96\n") == "tempo 96\n")
	_check("extract: fence without tag", FilterScript.extract_cue("Sure:\n```\ntempo 96\n```\nDone") == "tempo 96\n")
	_check("extract: fence with tag", FilterScript.extract_cue("```cue\ntempo 96\nstate a:\n  s(\"kick\")\n```") == "tempo 96\nstate a:\n  s(\"kick\")\n")
	_check("extract: fence after prose", FilterScript.extract_cue("Here is the cue: ```cue\ntempo 96\n```\n") == "tempo 96\n")
	_check("extract: first block only", FilterScript.extract_cue("```\na\n```\ntext\n```\nb\n```") == "a\n")
	_check("extract: unclosed fence", FilterScript.extract_cue("```\ntempo 96\n") == "tempo 96\n")
	_check("extract: CRLF", FilterScript.extract_cue("```\r\ntempo 96\r\n```\r\n") == "tempo 96\n")
	_check("extract: empty", FilterScript.extract_cue("  \n") == "")

	# normalize / hash
	_check("normalize drops comments, spaces and blank lines", FilterScript.normalize("// c\ntempo   96  // x\n\n\tstate a:\n") == "tempo 96\nstate a:",
		FilterScript.normalize("// c\ntempo   96  // x\n\n\tstate a:\n"))
	_check("hash is 64 hex chars", FilterScript.cue_hash("a").length() == 64)
	_check("hash of normal-form-equal texts is equal", FilterScript.cue_hash(VALID_A) == FilterScript.cue_hash(DUP_A))
	_check("hash differs for different cues", FilterScript.cue_hash(VALID_A) != FilterScript.cue_hash(VALID_B))
	_check("hash known vector", FilterScript.cue_hash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

	# reasons_from_metrics (pure)
	var good: Dictionary = {"clipped_samples": 0, "silent_fraction": 0.1, "onsets": 14 * 8, "cycles": 8.0, "density": 14.0}
	_check("metrics ok", FilterScript.reasons_from_metrics(good, 1.0, 32.0, 0.5).is_empty())
	var m: Dictionary = good.duplicate()
	m["clipped_samples"] = 1
	_check("metrics clipping", FilterScript.reasons_from_metrics(m, 1.0, 32.0, 0.5) == ["clipping"])
	m = good.duplicate()
	m["silent_fraction"] = 0.51
	_check("metrics silence", FilterScript.reasons_from_metrics(m, 1.0, 32.0, 0.5) == ["silence"])
	m = good.duplicate()
	m["silent_fraction"] = 0.5
	_check("metrics silence boundary is not silence", FilterScript.reasons_from_metrics(m, 1.0, 32.0, 0.5).is_empty())
	m = good.duplicate()
	m["onsets"] = 0
	m["density"] = 0.0
	_check("metrics no onsets only", FilterScript.reasons_from_metrics(m, 1.0, 32.0, 0.5) == ["no_onsets"])
	m = good.duplicate()
	m["density"] = 0.5
	_check("metrics density_low", FilterScript.reasons_from_metrics(m, 1.0, 32.0, 0.5) == ["density_low"])
	m["density"] = 33.0
	_check("metrics density_high", FilterScript.reasons_from_metrics(m, 1.0, 32.0, 0.5) == ["density_high"])
	m["density"] = 33.0
	_check("metrics density bounds configurable", FilterScript.reasons_from_metrics(m, 1.0, 40.0, 0.5).is_empty())
	m = good.duplicate()
	m["clipped_samples"] = 5
	m["silent_fraction"] = 0.9
	_check("metrics several reasons keep order", FilterScript.reasons_from_metrics(m, 1.0, 32.0, 0.5) == ["clipping", "silence"])

	# full pipeline with the real catalog
	var f := FilterScript.new()
	_check("default bounds", f.density_min == 1.0 and f.density_max == 32.0 and f.silence_max_fraction == 0.5,
		str([f.density_min, f.density_max, f.silence_max_fraction]))
	var r: Dictionary = f.check(SYNTAX_ERR)
	_check("syntax error", r["ok"] == false and r["reasons"] == ["syntax"], str(r))
	r = f.check(UNKNOWN_INSTRUMENT)
	_check("unknown instrument is validation", r["ok"] == false and r["reasons"] == ["validation"], str(r))
	r = f.check(VALID_A)
	_check("valid cue passes", r["ok"] == true and r["reasons"].is_empty(), str(r))
	var metrics: Dictionary = r["metrics"]
	_check("metrics carry the documented keys", metrics.has("clipped_samples") and metrics.has("silent_fraction") and metrics.has("onsets")
		and metrics.has("cycles") and metrics.has("density") and metrics.has("peak_dbfs"), str(metrics.keys()))
	_check("valid cue has onsets and density in bounds", int(metrics.get("onsets", 0)) > 0 and float(metrics.get("density", 0.0)) >= 1.0 and float(metrics.get("density", 99.0)) <= 32.0, str(metrics))
	_check("check does not record the hash", f.check(VALID_A)["ok"] == true)
	_check("accept returns true the first time", f.accept(VALID_A) == true)
	r = f.check(DUP_A)
	_check("duplicate differing only in comments and spaces", r["ok"] == false and r["reasons"] == ["duplicate"], str(r))
	_check("accept returns false for a duplicate", f.accept(DUP_A) == false)
	r = f.check(VALID_B)
	_check("a different valid cue still passes", r["ok"] == true, str(r))
	r = f.check(SILENT)
	_check("silent cue rejected", r["ok"] == false and (r["reasons"] as Array).has("silence"), str(r))
	var strict := FilterScript.new({"density_min": 20.0})
	r = strict.check(VALID_A)
	_check("density_min is configurable", r["ok"] == false and (r["reasons"] as Array).has("density_low"), str(r))

	print("checks: %d, failures: %d" % [_checks, _fails])
	if _fails == 0:
		print("PASS (%d checks)" % _checks)
	quit(1 if _fails > 0 else 0)
