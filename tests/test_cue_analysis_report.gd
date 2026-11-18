extends SceneTree
# CueAnalysisReport and cue_render --analysis.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_analysis_report.gd

const ReportScript = preload("res://addons/godot_synth/cue/cue_analysis_report.gd")
const RendererScript = preload("res://addons/godot_synth/cue/cue_renderer.gd")

const SR := 44100

var failures := 0
var checks := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS ", name)
	else:
		failures += 1
		print("FAIL ", name, ": ", detail)

func is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

func note_ev(track: String, midi: float, on: int, dur: int) -> Dictionary:
	return {"type": "note", "track": track, "note": midi, "velocity": 1.0, "on_frame": on, "off_frame": on + dur, "controls": {}}

func sine_frames(secs: float, amp: float) -> PackedVector2Array:
	var n := int(secs * float(SR))
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var s := amp * sin(TAU * 997.0 * float(i) / float(SR))
		out[i] = Vector2(s, s)
	return out

func _initialize() -> void:
	# 1. summary() on a hand-built report: exact strings
	var hand := {
		"sample_rate": 44100, "frames": 441000, "seconds": 10.0,
		"total": {"lufs": -15.0, "peak_dbfs": -1.0, "clipped_samples": 12, "silent_stretches": [{"start_frame": 0, "end_frame": 44100}]},
		"sections": [
			{"state": "combat", "lufs": -14.23, "peak_dbfs": -1.31, "clipped_samples": 0, "silent_stretches": [], "onsets_per_cycle_total": 6.5},
			{"state": "calm", "lufs": -30.0, "peak_dbfs": -9.0, "clipped_samples": 12, "silent_stretches": [{"start_frame": 0, "end_frame": 44100}], "onsets_per_cycle_total": 0.0},
		],
		"key": {"tonic": "D", "mode": "minor", "r": 0.912},
		"transitions": [{"from": "calm", "to": "combat", "requested_cycle": 4.0, "quant": "bar", "switch_cycle": 5.0, "switch_frame": 110250, "fade_end_cycle": 6.0}],
	}
	var lines: Array = ReportScript.summary(hand)
	var want: Array = [
		"section combat: -14.2 LUFS, peak -1.3 dBFS, 0 clipped, 6.5 onsets/cycle",
		"section calm: -30.0 LUFS, peak -9.0 dBFS, 12 clipped, 0.0 onsets/cycle",
		"section calm: 1 silent stretch(es) of at least 0.5 s, longest 1.0 s",
		"total: -15.0 LUFS, peak -1.0 dBFS, 12 clipped samples, 1 silent stretches, 10.0 s",
		"key estimate: D minor (r=0.91)",
		"transition calm -> combat: requested at cycle 4.00, switch at cycle 5.00 (bar), fade ends at cycle 6.00",
		"warning: 12 samples clipped",
		"warning: section calm has no note onsets",
	]
	check("summary lines are exact", lines == want, str(lines))
	hand["key"] = {"tonic": "", "mode": "", "r": 0.0}
	hand["transitions"] = [{"from": "a", "to": "b", "requested_cycle": 1.0, "quant": "", "switch_cycle": 1.0, "switch_frame": 0, "fade_end_cycle": 1.0}]
	var lines2: Array = ReportScript.summary(hand)
	check("no pitched notes line", lines2.has("key estimate: none (no pitched notes)"), str(lines2))
	check("empty quant reads 'no request'", lines2.has("transition a -> b: requested at cycle 1.00, switch at cycle 1.00 (no request), fade ends at cycle 1.00"), str(lines2))

	# 2. build() from a hand-built render result: 1 cycle = 1 s (cps 1.0), calm 0..1, fight 1..4
	var frames := sine_frames(4.0, 0.1)
	var events: Array = []
	for i in 4:
		events.append(note_ev("calm/lead", [60.0, 64.0, 67.0, 72.0][i], i * 5000, 4000))
	for i in 6:
		events.append(note_ev("fight/hat", 66.0, SR + i * 1000, 500))
	for i in 3:
		events.append(note_ev("fight/lead", [62.0, 65.0, 69.0][i], SR + i * 9000, 8000))
	var result := {
		"ok": true, "diagnostics": [], "sample_rate": SR, "cps": 1.0, "duration_cycles": 4.0, "frames": frames, "events": events,
		"log": [{"type": "request", "cycle": 0.5, "to": "fight", "quant": {"kind": "bar", "count": 1}}, {"type": "switch", "cycle": 1.0, "from": "calm", "to": "fight", "fade": 0.0}],
		"sections": [
			{"state": "calm", "start_cycle": 0.0, "end_cycle": 1.0, "start_frame": 0, "end_frame": SR},
			{"state": "fight", "start_cycle": 1.0, "end_cycle": 4.0, "start_frame": SR, "end_frame": 4 * SR},
		],
	}
	var roles := {"lead": "lead", "hat": "hat"}
	var report: Dictionary = ReportScript.build(result, roles, "inline.cue")
	check("report key order", str(report.keys()) == str(["version", "cue", "sample_rate", "cps", "duration_cycles", "frames", "seconds", "total", "sections", "key", "pitch_class_histogram", "transitions", "summary"]), str(report.keys()))
	check("report header", report.version == 1 and report.cue == "inline.cue" and report.sample_rate == SR and is_num(report.cps) and report.frames == 4 * SR and is_num(report.seconds) and absf(float(report.seconds) - 4.0) < 1e-9, str(report))
	check("total has audio metrics", report.total.has("lufs") and report.total.has("peak_dbfs") and report.total.has("clipped_samples") and report.total.has("silent_stretches") and absf(float(report.total.lufs) + 20.0) < 0.2, str(report.total))
	check("two sections with merged fields", report.sections.size() == 2, str(report.sections.size()))
	if report.sections.size() == 2:
		var s0: Dictionary = report.sections[0]
		var s1: Dictionary = report.sections[1]
		for k in ["state", "start_cycle", "end_cycle", "start_frame", "end_frame", "lufs", "peak_dbfs", "clipped_samples", "silent_stretches", "onsets_per_cycle", "onsets_per_cycle_total"]:
			check("section 0 has " + k, s0.has(k), k)
		check("section 0 values", s0.state == "calm" and s0.end_frame == SR and absf(float(s0.onsets_per_cycle.lead) - 4.0) < 1e-9 and absf(float(s0.onsets_per_cycle_total) - 4.0) < 1e-9, str(s0))
		check("section 1 densities: hat 2.0 (6 over 3 cycles), lead 1.0, total 3.0", absf(float(s1.onsets_per_cycle.hat) - 2.0) < 1e-9 and absf(float(s1.onsets_per_cycle.lead) - 1.0) < 1e-9 and absf(float(s1.onsets_per_cycle_total) - 3.0) < 1e-9, str(s1.onsets_per_cycle))
		check("peak of the -20 dBFS sine", absf(float(s1.peak_dbfs) + 20.0) < 0.05, str(s1.peak_dbfs))
	check("key present, hat excluded from the histogram", report.key.has("tonic") and report.key.has("mode") and is_num(report.key.r) and report.pitch_class_histogram.size() == 12 and float(report.pitch_class_histogram[6]) == 0.0, str(report.key))
	check("one transition with the request cycle", report.transitions.size() == 1 and absf(float(report.transitions[0].requested_cycle) - 0.5) < 1e-9 and report.transitions[0].quant == "bar" and report.transitions[0].switch_frame == SR, str(report.transitions))
	check("summary is a non-empty Array of Strings", report.summary is Array and report.summary.size() >= 4 and report.summary[0] is String, str(report.summary))
	check("summary names both sections and the total", String("\n").join(PackedStringArray(report.summary)).contains("section calm:") and String("\n").join(PackedStringArray(report.summary)).contains("section fight:") and String("\n").join(PackedStringArray(report.summary)).contains("total:"))
	var text := JSON.stringify(report, "\t")
	var back = JSON.parse_string(text)
	check("report round-trips through JSON", back is Dictionary and back.version == 1 and not text.contains("inf") and not text.contains("nan"))

	# 3. end to end: cue_render --analysis
	var dir := ProjectSettings.globalize_path("user://")
	var cue_path := dir.path_join("cue_analysis_test.cue")
	var scn_path := dir.path_join("cue_analysis_test.json")
	var wav_path := dir.path_join("cue_analysis_test.wav")
	var json_path := dir.path_join("cue_analysis_test.analysis.json")
	var f := FileAccess.open(cue_path, FileAccess.WRITE)
	f.store_string("\n".join(["tempo 120", "state calm:", "  s(\"kick*2\")", "state fight:", "  s(\"kick*4\")", "  s(\"hat*8\")", "transition calm -> fight on bar", ""]))
	f.close()
	f = FileAccess.open(scn_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"duration_cycles": 2, "sample_rate": 22050, "tail_sec": 0.25, "events": [{"at": 1.0, "set_state": "fight"}]}))
	f.close()
	var cli: Dictionary = RendererScript.run(PackedStringArray([cue_path, "--scenario", scn_path, "--out", wav_path, "--analysis", json_path]))
	check("cli with --analysis exits 0", cli.exit_code == 0 and cli.lines.size() == 1 and cli.error == "", str(cli))
	if cli.lines.size() == 1:
		var line = JSON.parse_string(cli.lines[0])
		check("cli line names the analysis path", line is Dictionary and line.get("analysis") == json_path, cli.lines[0])
	check("analysis file exists", FileAccess.file_exists(json_path))
	var rep = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	check("analysis file is a JSON object", rep is Dictionary, "not a dictionary")
	if rep is Dictionary:
		check("analysis keys", str(rep.keys()) == str(["version", "cue", "sample_rate", "cps", "duration_cycles", "frames", "seconds", "total", "sections", "key", "pitch_class_histogram", "transitions", "summary"]), str(rep.keys()))
		check("analysis scalar types", is_num(rep.version) and rep.cue == cue_path and int(rep.sample_rate) == 22050 and is_num(rep.cps) and is_num(rep.seconds) and is_num(rep.frames), str(rep))
		check("two sections: calm then fight", rep.sections.size() == 2 and rep.sections[0].state == "calm" and rep.sections[1].state == "fight", str(rep.sections))
		if rep.sections.size() == 2:
			check("calm: 2 kick onsets per cycle", absf(float(rep.sections[0].onsets_per_cycle.kick) - 2.0) < 1e-9, str(rep.sections[0].onsets_per_cycle))
			check("fight: 12 onsets per cycle (4 kick + 8 hat)", absf(float(rep.sections[1].onsets_per_cycle_total) - 12.0) < 1e-9, str(rep.sections[1].onsets_per_cycle_total))
			check("section audio fields are numbers", is_num(rep.sections[1].lufs) and is_num(rep.sections[1].peak_dbfs) and is_num(rep.sections[1].clipped_samples) and rep.sections[1].silent_stretches is Array)
		check("one transition calm -> fight at cycle 1", rep.transitions.size() == 1 and rep.transitions[0].from == "calm" and rep.transitions[0].to == "fight" and absf(float(rep.transitions[0].switch_cycle) - 1.0) < 1e-9, str(rep.transitions))
		check("drum-only cue has no pitched key", rep.key.tonic == "" and rep.key.mode == "", str(rep.key))
		check("summary lines present", rep.summary is Array and rep.summary.size() >= 4 and String(rep.summary[0]).begins_with("section calm: "), str(rep.summary))
	# a failed render writes no analysis file
	DirAccess.remove_absolute(json_path)
	f = FileAccess.open(scn_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"events": [{"at": 0.5, "set_state": "nope"}]}))
	f.close()
	var bad: Dictionary = RendererScript.run(PackedStringArray([cue_path, "--scenario", scn_path, "--out", wav_path, "--analysis", json_path]))
	check("invalid scenario: exit 1, no analysis file", bad.exit_code == 1 and not FileAccess.file_exists(json_path), str(bad))
	check("--analysis needs a value", RendererScript.run(PackedStringArray([cue_path, "--out", wav_path, "--analysis"])).exit_code == 2)
	for p in [cue_path, scn_path, wav_path, json_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

	if failures == 0:
		print("PASS all ", checks, " checks")
		quit(0)
	else:
		print("FAIL ", failures, " of ", checks)
		quit(1)
