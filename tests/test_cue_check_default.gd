extends SceneTree
# CueChecker against the real instrument catalog (default) and the fixture (--catalog).
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_check_default.gd

const CheckerScript = preload("res://addons/godot_synth/cue/cue_checker.gd")

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func codes(result: Dictionary) -> Array:
	var out: Array = []
	for d: Dictionary in result["diagnostics"]:
		out.append(d["code"])
	return out

func _write(path: String, text: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return ProjectSettings.globalize_path(path)

func _initialize() -> void:
	var corpus := ProjectSettings.globalize_path("res://").path_join("../tests/cue_corpus")
	var cat: Dictionary = CheckerScript.default_catalog()

	# 1. The default catalog is the real one.
	check("default catalog instruments", Array(cat.keys()) == ["bass", "lead", "pad", "kick", "snare", "hat", "arp"], str(cat.keys()))
	check("default catalog bass controls", cat["bass"]["controls"] == ["gain", "velocity", "legato", "lpf", "lpq"], str(cat["bass"]["controls"]))
	check("default_catalog_path is still the fixture", CheckerScript.default_catalog_path().ends_with("cue_corpus/catalog.json") and FileAccess.file_exists(CheckerScript.default_catalog_path()), CheckerScript.default_catalog_path())

	# 2. check_source with the real catalog.
	var ok_src := "param danger = 0\nstate a:\n  s(\"kick*2\")\n  s(\"hat*4\").gain(game(\"danger\"))\n  n(\"0 2\").scale(\"C:minor\").s(\"bass\").lpf(900)\nbind pad.lpf <- danger 400..4000\n"
	var r_ok: Dictionary = CheckerScript.check_source(ok_src, "ok.cue", cat)
	check("real instruments pass", r_ok["ok"] == true, str(r_ok["diagnostics"]))
	var r_crash: Dictionary = CheckerScript.check_source("state a:\n  s(\"crash\")\n", "crash.cue", cat)
	check("crash is not an instrument", r_crash["ok"] == false and "E_UNKNOWN_INSTRUMENT" in codes(r_crash), str(codes(r_crash)))
	var r_attack: Dictionary = CheckerScript.check_source("param x = 0\nstate a:\n  s(\"bass\")\nbind bass.attack <- x\n", "attack.cue", cat)
	check("attack is not a catalog control", r_attack["ok"] == false and "E_UNKNOWN_CONTROL" in codes(r_attack), str(codes(r_attack)))
	var r_hat_lpf: Dictionary = CheckerScript.check_source("param x = 0\nstate a:\n  s(\"hat\")\nbind hat.lpf <- x\n", "hatlpf.cue", cat)
	check("hat has hpf, not lpf", r_hat_lpf["ok"] == false and "E_UNKNOWN_CONTROL" in codes(r_hat_lpf), str(codes(r_hat_lpf)))
	var r_hat_hpf: Dictionary = CheckerScript.check_source("param x = 0\nstate a:\n  s(\"hat\")\nbind hat.hpf <- x 200..8000\n", "hathpf.cue", cat)
	check("hat hpf bind passes", r_hat_hpf["ok"] == true, str(r_hat_hpf["diagnostics"]))
	var r_lead_lpf: Dictionary = CheckerScript.check_source("param x = 0\nstate a:\n  s(\"lead\")\nbind lead.lpf <- x\n", "leadlpf.cue", cat)
	check("lead has no mapped controls in v1", r_lead_lpf["ok"] == false and "E_UNKNOWN_CONTROL" in codes(r_lead_lpf), str(codes(r_lead_lpf)))

	# 3. run(): default catalog vs --catalog.
	var tmp := _write("user://cue_check_default_ok.cue", ok_src)
	var run_ok: Dictionary = CheckerScript.run(PackedStringArray([tmp]))
	check("run default: real instruments exit 0", run_ok["exit_code"] == 0 and run_ok["lines"].size() == 1, str(run_ok))
	var forest := corpus + "/valid/forest.cue"
	var run_forest: Dictionary = CheckerScript.run(PackedStringArray([forest]))
	var parsed: Variant = JSON.parse_string(run_forest["lines"][0]) if run_forest["lines"].size() == 1 else null
	var forest_codes: Array = []
	if parsed is Dictionary:
		for d: Dictionary in parsed["diagnostics"]:
			forest_codes.append(d["code"])
	check("run default: forest.cue fails (crash)", run_forest["exit_code"] == 1 and "E_UNKNOWN_INSTRUMENT" in forest_codes, str(forest_codes))
	var run_fixture: Dictionary = CheckerScript.run(PackedStringArray([forest, "--catalog", corpus + "/catalog.json"]))
	check("run --catalog fixture: forest.cue passes", run_fixture["exit_code"] == 0, str(run_fixture))
	var run_valid: Dictionary = CheckerScript.run(PackedStringArray([corpus + "/valid", "--catalog", corpus + "/catalog.json"]))
	check("run --catalog fixture: valid corpus passes", run_valid["exit_code"] == 0 and run_valid["lines"].size() == 12, str(run_valid["exit_code"]))
	check("no extra usage error text", run_forest["error"] == "", run_forest["error"])
	DirAccess.remove_absolute(tmp)

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
