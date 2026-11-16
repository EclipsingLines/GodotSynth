extends SceneTree
# CueEventAnalysis: key estimate, histogram, onset density, transitions.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_event_analysis.gd

const AnalysisScript = preload("res://addons/godot_synth/cue/cue_event_analysis.gd")

const SR := 1000
const ROLES := {"lead": "lead", "bass": "bass", "pad": "pad", "kick": "kick", "snare": "snare", "hat": "hat"}

var failures := 0
var checks := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS ", name)
	else:
		failures += 1
		print("FAIL ", name, ": ", detail)

func near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

func total(a: PackedFloat64Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s

func ev(track: String, midi: float, on: int, dur: int, vel: float = 1.0) -> Dictionary:
	return {"type": "note", "track": track, "note": midi, "velocity": vel, "on_frame": on, "off_frame": on + dur, "controls": {}}

# notes: Array of [midi, weight]; weight w = w seconds long at SR 1000 (w * 1000 frames), spread over time
func scale_events(track: String, notes: Array) -> Array:
	var out: Array = []
	var t := 0
	for n: Array in notes:
		var dur: int = int(n[1]) * 1000
		out.append(ev(track, float(n[0]), t, dur))
		t += dur
	return out

func _initialize() -> void:
	# 1. key: C major with the tonic and fifth emphasised
	var c_major := scale_events("explore/lead", [[60, 3], [62, 1], [64, 2], [65, 1], [67, 2], [69, 1], [71, 1]])
	var h1 := AnalysisScript.pitch_class_histogram(c_major, ROLES, SR)
	check("histogram has 12 bins and sums to 1", h1.size() == 12 and near(total(h1), 1.0, 1e-9))
	check("histogram weights", near(h1[0], 3.0 / 11.0, 1e-9) and near(h1[1], 0.0, 1e-12) and near(h1[4], 2.0 / 11.0, 1e-9), str(h1))
	var k1 := AnalysisScript.estimate_key(h1)
	check("C major scale -> C major", k1.tonic == "C" and k1.mode == "major", str(k1))
	check("C major correlation", near(k1.r, 0.96785, 0.001), str(k1.r))

	# 2. key: A natural minor with the tonic emphasised
	var a_minor := scale_events("explore/lead", [[57, 3], [59, 1], [60, 2], [62, 1], [64, 2], [65, 1], [67, 1]])
	var k2 := AnalysisScript.estimate_key(AnalysisScript.pitch_class_histogram(a_minor, ROLES, SR))
	check("A natural minor -> A minor", k2.tonic == "A" and k2.mode == "minor", str(k2))
	check("A minor correlation", near(k2.r, 0.96975, 0.001), str(k2.r))

	# 3. equal-weight C major scale: still C major (lower r)
	var flat := scale_events("explore/lead", [[60, 1], [62, 1], [64, 1], [65, 1], [67, 1], [69, 1], [71, 1]])
	var k3 := AnalysisScript.estimate_key(AnalysisScript.pitch_class_histogram(flat, ROLES, SR))
	check("equal-weight scale -> C major", k3.tonic == "C" and k3.mode == "major" and near(k3.r, 0.75641, 0.001), str(k3))

	# 4. drums are skipped by role; unknown instruments count as pitched
	var with_drums := c_major.duplicate()
	with_drums.append(ev("explore/snare", 61.0, 0, 50000))
	with_drums.append(ev("explore/hat", 66.0, 0, 50000))
	with_drums.append(ev("explore/kick", 61.0, 0, 50000))
	var h4 := AnalysisScript.pitch_class_histogram(with_drums, ROLES, SR)
	check("drum events excluded", h4[1] == 0.0 and h4[6] == 0.0 and near(h4[0], 3.0 / 11.0, 1e-9), str(h4))
	var unknown := [ev("x/mystery", 61.0, 0, 1000)]
	check("instrument missing from roles counts as pitched", near(AnalysisScript.pitch_class_histogram(unknown, ROLES, SR)[1], 1.0, 1e-9))
	check("non-note events ignored", total(AnalysisScript.pitch_class_histogram([{"type": "param", "track": "a/lead", "name": "x", "value": 1.0, "frame": 0}], ROLES, SR)) == 0.0)

	# 5. velocity and duration weighting, octave folding
	var weighted := [ev("a/lead", 60.0, 0, 1000, 1.0), ev("a/lead", 79.0, 0, 1000, 0.5)]
	var h5 := AnalysisScript.pitch_class_histogram(weighted, ROLES, SR)
	check("velocity weighting and pitch-class folding", near(h5[0], 2.0 / 3.0, 1e-9) and near(h5[7], 1.0 / 3.0, 1e-9), str(h5))
	check("empty input: zero histogram and no key", AnalysisScript.estimate_key(AnalysisScript.pitch_class_histogram([], ROLES, SR)).tonic == "")
	var held := AnalysisScript.pitch_class_histogram([ev("a/lead", 60.0, 100, -200)], ROLES, SR)
	check("note with off before on counts as one frame", near(held[0], 1.0, 1e-9), str(held))

	# 6. onset density: 2 cycles per section (cps 0.5 at SR 1000 -> 2000 frames per cycle)
	var sections := [
		{"state": "explore", "start_cycle": 0.0, "end_cycle": 2.0, "start_frame": 0, "end_frame": 4000},
		{"state": "combat", "start_cycle": 2.0, "end_cycle": 4.0, "start_frame": 4000, "end_frame": 8000},
	]
	var evs: Array = []
	for i in 4:
		evs.append(ev("explore/lead", 60.0, i * 1000, 500))
	evs.append(ev("explore/lead", 60.0, 3999, 10))
	evs.append(ev("explore/lead", 60.0, 8000, 10))
	for i in 8:
		evs.append(ev("combat/lead", 62.0, 4000 + i * 500, 100))
	for i in 16:
		evs.append(ev("combat/hat", 66.0, 4000 + i * 250, 50))
	var d := AnalysisScript.onset_density(evs, sections)
	check("one density entry per section", d.size() == 2 and d[0].state == "explore" and d[1].state == "combat", str(d))
	check("explore: 5 onsets (3999 included, 8000 outside) over 2 cycles = 2.5", near(d[0].groups.get("lead", -1.0), 2.5, 1e-9) and near(d[0].total, 2.5, 1e-9), str(d[0]))
	check("combat: lead 4.0, hat 8.0, total 12.0", near(d[1].groups.get("lead", -1.0), 4.0, 1e-9) and near(d[1].groups.get("hat", -1.0), 8.0, 1e-9) and near(d[1].total, 12.0, 1e-9), str(d[1]))
	check("groups list only groups with onsets", d[0].groups.size() == 1 and d[1].groups.size() == 2 and d[1].start_cycle == 2.0 and d[1].end_cycle == 4.0, str(d[1]))
	var zero_len := AnalysisScript.onset_density(evs, [{"state": "z", "start_cycle": 1.0, "end_cycle": 1.0, "start_frame": 0, "end_frame": 0}])
	check("zero-length section is empty", zero_len[0].total == 0.0 and zero_len[0].groups.is_empty())

	# 7. transitions: last request wins, quant text, frames and fade end (cps 0.5, SR 1000)
	var log: Array = [
		{"type": "request", "cycle": 1.5, "to": "combat", "quant": {"kind": "bar", "count": 1}},
		{"type": "request", "cycle": 1.75, "to": "combat", "quant": {"kind": "bars", "count": 2}},
		{"type": "switch", "cycle": 2.0, "from": "explore", "to": "combat", "fade": 1.0},
		{"type": "stinger", "cycle": 2.5},
		{"type": "request", "cycle": 3.0, "to": "explore", "quant": {"kind": "bar", "count": 1}},
		{"type": "switch", "cycle": 4.0, "from": "combat", "to": "explore", "fade": 0.0},
		{"type": "switch", "cycle": 6.0, "from": "explore", "to": "combat"},
	]
	var t := AnalysisScript.transitions(log, 0.5, SR)
	check("three transitions", t.size() == 3, str(t))
	if t.size() == 3:
		check("first: requested 1.75 (last request wins), 2 bars, switch 2.0 at frame 4000, fade ends 3.0", t[0].from == "explore" and t[0].to == "combat" and near(t[0].requested_cycle, 1.75, 1e-9) and t[0].quant == "2 bars" and near(t[0].switch_cycle, 2.0, 1e-9) and t[0].switch_frame == 4000 and near(t[0].fade_end_cycle, 3.0, 1e-9), str(t[0]))
		check("second: requested 3.0, bar, switch 4.0 at frame 8000, no fade", t[1].requested_cycle == 3.0 and t[1].quant == "bar" and t[1].switch_frame == 8000 and near(t[1].fade_end_cycle, 4.0, 1e-9), str(t[1]))
		check("third: no request paired, requested = switch, empty quant, fade missing = 0", t[2].requested_cycle == 6.0 and t[2].quant == "" and t[2].switch_frame == 12000 and near(t[2].fade_end_cycle, 6.0, 1e-9), str(t[2]))
	check("empty log gives no transitions", AnalysisScript.transitions([], 0.5, SR).is_empty())

	# 8. analyze() combines everything with JSON-friendly types
	var full := AnalysisScript.analyze(c_major, log, sections, ROLES, SR, 0.5)
	check("analyze keys", full.has("key") and full.has("pitch_class_histogram") and full.has("onset_density") and full.has("transitions"), str(full.keys()))
	check("analyze histogram is a plain Array of 12", full.pitch_class_histogram is Array and full.pitch_class_histogram.size() == 12)
	check("analyze key", full.key.tonic == "C" and full.key.mode == "major")
	check("analyze output is JSON-serializable", JSON.stringify(full).length() > 10)

	# 9. roles from a catalog file
	var path := ProjectSettings.globalize_path("user://cue_event_analysis_catalog.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "instruments": {"bass": {"role": "bass"}, "kick": {"role": "kick"}, "odd": {}}}))
	f.close()
	var roles := AnalysisScript.roles_from_catalog_file(path)
	check("roles read from file", roles == {"bass": "bass", "kick": "kick"}, str(roles))
	DirAccess.remove_absolute(path)
	check("missing catalog file gives {}", AnalysisScript.roles_from_catalog_file(path).is_empty())

	# 10. helpers
	check("group_of / instrument_of", AnalysisScript.group_of("combat/lead") == "combat" and AnalysisScript.instrument_of("combat/lead") == "lead" and AnalysisScript.group_of("noslash") == "")
	check("pearson of identical arrays is 1, of a constant is 0", near(AnalysisScript.pearson(AnalysisScript.KK_MAJOR, AnalysisScript.KK_MAJOR), 1.0, 1e-12) and AnalysisScript.pearson(PackedFloat64Array([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]), AnalysisScript.KK_MAJOR) == 0.0)

	if failures == 0:
		print("PASS all ", checks, " checks")
		quit(0)
	else:
		print("FAIL ", failures, " of ", checks)
		quit(1)
