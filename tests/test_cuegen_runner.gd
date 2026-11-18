extends SceneTree
# CueGenRunner: prompt-matrix generation with the real filter, JSONL splits, resume and stats.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cuegen_runner.gd

const RunnerScript = preload("res://addons/godot_synth/cue/gen/cue_gen_runner.gd")

var _fails: int = 0
var _checks: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("PASS ", label)
	else:
		_fails += 1
		print("FAIL %s: %s" % [label, detail])


func _repo(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()


func _config() -> Dictionary:
	return {"backend": "command", "model": "fake-mix", "command": [OS.get_executable_path(), "--headless", "--quiet",
		"--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://").simplify_path(),
		"-s", _repo("tests/fixtures/fake_teacher_mix.gd"), "--", "{prompt_file}", "{out_file}"]}


# every axis has one value except "form", whose six values select the fake teacher's mode: 6 combinations
func _matrix() -> Dictionary:
	return {"version": 1,
		"axes": {"mood": ["calm"], "biome": ["cave"], "intensity": ["low"], "instrumentation": ["bass kick"],
			"form": ["FAKE:good_a", "FAKE:dup_a", "FAKE:good_b", "FAKE:syntax", "FAKE:unknown", "FAKE:fail"]},
		"templates": ["Write a {mood} {biome} {intensity} cue with {instrumentation}: {form}"]}


func _read_lines(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return out
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var p: Variant = JSON.parse_string(line)
		if p is Dictionary:
			var d: Dictionary = p
			out.append(d)
	return out


func _initialize() -> void:
	# pure helpers
	_check("split_for is deterministic", RunnerScript.split_for("abc") == RunnerScript.split_for("abc"))
	var counts: Dictionary = {"train": 0, "val": 0, "test": 0}
	for i: int in range(2000):
		counts[RunnerScript.split_for("id%d" % i)] += 1
	_check("split proportions about 90/5/5", counts["train"] > 1650 and counts["train"] < 1950 and counts["val"] > 40 and counts["test"] > 40, str(counts))
	_check("dataset_version names the grammar and a sha256", String(RunnerScript.dataset_version()).begins_with("cue-grammar-v1:")
		and String(RunnerScript.dataset_version()).length() == "cue-grammar-v1:".length() + 64, RunnerScript.dataset_version())

	# invalid config writes nothing
	var out: String = ProjectSettings.globalize_path("user://cuegen_runner_test")
	_wipe(out)
	var bad: Dictionary = {"backend": "openai", "model": "m"}
	var r0: Dictionary = RunnerScript.new(bad, _matrix(), out, 1, 6).run()
	_check("invalid config returns error", r0.has("error"))
	_check("invalid config writes nothing", not FileAccess.file_exists(out.path_join("stats.json")))

	# full run with the command backend and the fake teacher (6 requests = all 6 combinations)
	var runner = RunnerScript.new(_config(), _matrix(), out, 1, 6)
	runner.quiet = true
	var stats: Dictionary = runner.run()
	_check("requested", stats.get("requested") == 6, str(stats))
	_check("accepted 2 (good_a/dup_a collapse to one, plus good_b)", stats.get("accepted") == 2, str(stats))
	_check("rejected reasons", stats.get("rejected") == {"syntax": 1, "validation": 1, "duplicate": 1}, str(stats.get("rejected")))
	_check("one provider error", stats.get("provider_errors") == 1, str(stats))
	var by: Dictionary = stats.get("by_split", {})
	_check("by_split sums to accepted", int(by.get("train", 0)) + int(by.get("val", 0)) + int(by.get("test", 0)) == 2, str(by))
	_check("dataset_version in stats", String(stats.get("dataset_version", "")).begins_with("cue-grammar-v1:"))
	_check("gbnf_sha256 is the hex digest", String(stats.get("gbnf_sha256", "")).length() == 64
		and String(stats.get("dataset_version", "")).ends_with(String(stats.get("gbnf_sha256", ""))), str(stats.get("gbnf_sha256")))
	_check("seed recorded", stats.get("seed") == 1, str(stats.get("seed")))
	_check("teacher recorded without secrets", stats.get("teacher") == {"backend": "command", "model": "fake-mix"}, str(stats.get("teacher")))

	var records: Array[Dictionary] = []
	for s: String in ["train", "val", "test"]:
		var recs: Array[Dictionary] = _read_lines(out.path_join(s + ".jsonl"))
		for rec: Dictionary in recs:
			_check("record is in the split of its id (%s)" % rec["id"], RunnerScript.split_for(String(rec["id"])) == s)
		records.append_array(recs)
	_check("2 accepted records on disk", records.size() == 2, str(records.size()))
	var keys_ok: bool = true
	for rec: Dictionary in records:
		if not (rec.has("id") and rec.has("axes") and rec.has("messages") and rec.has("cue") and rec.has("metrics") and rec.has("teacher")):
			keys_ok = false
		if String(rec.get("cue", "")).is_empty() or not (rec.get("messages") is Array) or (rec.get("messages") as Array).is_empty():
			keys_ok = false
	_check("records carry id, axes, messages, cue, metrics, teacher", keys_ok)
	var rej: Array[Dictionary] = _read_lines(out.path_join("rejected.jsonl"))
	_check("rejected.jsonl has 3 lines with reasons", rej.size() == 3 and rej.all(func(d: Dictionary) -> bool: return (d.get("reasons") as Array).size() >= 1), str(rej.size()))
	var on_disk: Dictionary = {}
	var sp: Variant = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("stats.json")))
	if sp is Dictionary:
		on_disk = sp
	_check("stats.json matches the returned stats", on_disk.get("accepted") == 2 and on_disk.get("requested") == 6)

	# resume: nothing new is added (the failed item is retried and fails again)
	var before: String = FileAccess.get_file_as_string(out.path_join("train.jsonl")) + "|" + FileAccess.get_file_as_string(out.path_join("val.jsonl")) \
		+ "|" + FileAccess.get_file_as_string(out.path_join("test.jsonl")) + "|" + FileAccess.get_file_as_string(out.path_join("rejected.jsonl"))
	var again = RunnerScript.new(_config(), _matrix(), out, 1, 6)
	again.quiet = true
	var stats2: Dictionary = again.run()
	var after: String = FileAccess.get_file_as_string(out.path_join("train.jsonl")) + "|" + FileAccess.get_file_as_string(out.path_join("val.jsonl")) \
		+ "|" + FileAccess.get_file_as_string(out.path_join("test.jsonl")) + "|" + FileAccess.get_file_as_string(out.path_join("rejected.jsonl"))
	_check("resume leaves every file unchanged", before == after)
	_check("resume reports the same totals", stats2.get("accepted") == 2 and stats2.get("rejected") == {"syntax": 1, "validation": 1, "duplicate": 1}, str(stats2))
	_check("resume retried only the provider error", stats2.get("provider_errors") == 1, str(stats2))

	# no vendor names in the new files (this test file is excluded because it lists the tokens; the backend id
	# "openai" is allowed, only "openai.com" is searched)
	var deny: Array[String] = ["claude", "anthropic", "openai.com", "gpt-", "gemini", "mistral"]
	for rel: String in ["project/addons/godot_synth/cue/gen/cue_gen_runner.gd", "tools/cuegen/cuegen.gd", "tests/fixtures/fake_teacher_mix.gd"]:
		var text: String = FileAccess.get_file_as_string(_repo(rel)).to_lower()
		var hit: String = ""
		for tok: String in deny:
			if text.contains(tok):
				hit = tok
		_check("no vendor name in %s" % rel, not text.is_empty() and hit == "", "found: " + hit)

	_wipe(out)
	print("checks: %d, failures: %d" % [_checks, _fails])
	if _fails == 0:
		print("PASS (%d checks)" % _checks)
	quit(1 if _fails > 0 else 0)


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
