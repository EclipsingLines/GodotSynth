extends SceneTree
# CueScheduler: exact events, window-splitting invariance, quantization, sink recording.
# Run: bash tests/verify.sh --no-build tests/test_cue_scheduler.gd

const FracScript = preload("res://addons/godot_synth/cue/cue_frac.gd")
const SpanScript = preload("res://addons/godot_synth/cue/cue_span.gd")
const HapScript = preload("res://addons/godot_synth/cue/cue_hap.gd")
const PatternScript = preload("res://addons/godot_synth/cue/cue_pattern.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")
const SchedulerScript = preload("res://addons/godot_synth/cue/cue_scheduler.gd")
const SinkScript = preload("res://addons/godot_synth/cue/cue_recording_sink.gd")

var failures: Array[String] = []
var catalog = null

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

func c2f(c: float) -> int:
	return roundi(c * 48000.0)

func pure_of(v: Dictionary):
	return PatternScript.pure(v)

func seq_of(a, b):
	var arr: Array[PatternScript] = [a, b]
	return PatternScript.seq(arr)

func seq3_of(a, b, c):
	var arr: Array[PatternScript] = [a, b, c]
	return PatternScript.seq(arr)

func make_scheduler(sink):
	return SchedulerScript.new(catalog, sink, Callable(self, "c2f"))

# One source "a" in group "g" from cycle 0, window [0, 1): returns the recorded note events.
func run_one(value: Dictionary) -> Array:
	var sink = SinkScript.new()
	var sch = make_scheduler(sink)
	sch.add_source("a", "g", pure_of(value), 0.0, 0.0)
	sch.process_window(0.0, 1.0)
	return sink.of_type("note")

func frames_of(events: Array) -> Array:
	var out: Array = []
	for e in events:
		out.append(e["on_frame"])
	return out

func params_pattern():
	var q := func(state: Dictionary) -> Array[HapScript]:
		var out: Array[HapScript] = []
		var span = state["span"]
		var p: Dictionary = state["controls"].get("params", {})
		for sub in span.span_cycles():
			var whole = SpanScript.make(sub.begin.sam(), sub.begin.next_sam())
			out.append(HapScript.make(whole, sub, {"s": "kick", "gain": float(p.get("danger", 0.0))}))
		return out
	return PatternScript.new(q)

func _initialize() -> void:
	catalog = CatalogScript.load_default()
	check("catalog loads", catalog.has_instrument("kick") and catalog.has_instrument("bass"), str(catalog.errors))

	# 1. Exact events of a two-step sequence over one cycle.
	var sink1 = SinkScript.new()
	var sch1 = make_scheduler(sink1)
	sch1.add_source("a", "g", seq_of(pure_of({"s": "kick"}), pure_of({"s": "hat"})), 0.0, 0.0)
	sch1.process_window(0.0, 1.0)
	var ev := sink1.of_type("note")
	check("two note events", ev.size() == 2, str(ev.size()))
	if ev.size() == 2:
		check("kick event", ev[0]["track"] == "g/kick" and ev[0]["on_frame"] == 0 and ev[0]["off_frame"] == 24000 and near(ev[0]["note"], 36.0) and near(ev[0]["velocity"], 0.8) and ev[0]["controls"].is_empty(), str(ev[0]))
		check("hat event", ev[1]["track"] == "g/hat" and ev[1]["on_frame"] == 24000 and ev[1]["off_frame"] == 48000, str(ev[1]))
	check("note events have the documented keys", ev.size() > 0 and Array(ev[0].keys()) == ["type", "track", "note", "velocity", "on_frame", "off_frame", "controls"], str(ev[0].keys() if ev.size() > 0 else []))
	check("sources are pruned after their end only", sch1.get_sources().size() == 1, "")

	# 2. Velocity, gain, legato.
	var e2 := run_one({"s": "bass", "gain": 0.5, "velocity": 0.6})
	check("velocity x gain", e2.size() == 1 and near(e2[0]["velocity"], 0.3), str(e2))
	var e2b := run_one({"s": "bass", "gain": 2.0})
	check("velocity clamps to 1", e2b.size() == 1 and near(e2b[0]["velocity"], 1.0), str(e2b))
	var e3 := run_one({"s": "pad"})
	check("default legato 1", e3.size() == 1 and e3[0]["on_frame"] == 0 and e3[0]["off_frame"] == 48000, str(e3))
	var e3b := run_one({"s": "pad", "legato": 0.5})
	check("legato 0.5", e3b.size() == 1 and e3b[0]["off_frame"] == 24000, str(e3b))
	var e3c := run_one({"s": "pad", "legato": 2.0})
	check("legato 2", e3c.size() == 1 and e3c[0]["off_frame"] == 96000, str(e3c))
	var e3d := run_one({"s": "pad", "legato": 0.0})
	check("zero legato still has off > on", e3d.size() == 1 and e3d[0]["off_frame"] == 1, str(e3d))

	# 3. Pitch precedence: note, then n + 60, then the default note.
	check("note wins over n", near(run_one({"s": "lead", "note": 50, "n": 3})[0]["note"], 50.0), "")
	check("n + 60 without note", near(run_one({"s": "lead", "n": 3})[0]["note"], 63.0), "")
	check("default note (lead)", near(run_one({"s": "lead"})[0]["note"], 72.0), "")
	check("default note (bass)", near(run_one({"s": "bass"})[0]["note"], 36.0), "")
	check("fractional note kept", near(run_one({"s": "lead", "note": 61.5})[0]["note"], 61.5), "")

	# 4. Catalog controls become targets with mapped values; scheduler-level keys stay out.
	var e4 := run_one({"s": "bass", "lpf": 1000.0, "lpq": 0.5, "gain": 0.5, "pan": 0.3})
	check("controls mapped", e4.size() == 1 and Array(e4[0]["controls"].keys()) == ["fx0.cutoff", "fx0.resonance"] and near(e4[0]["controls"]["fx0.cutoff"], 1000.0) and near(e4[0]["controls"]["fx0.resonance"], 0.5), str(e4))

	# 5. Unknown instruments are skipped, known ones still play.
	check("unknown instrument -> no event", run_one({"s": "nope"}).is_empty(), "")
	check("missing s -> no event", run_one({"n": 1}).is_empty(), "")
	var sink5 = SinkScript.new()
	var sch5 = make_scheduler(sink5)
	sch5.add_source("a", "g", seq_of(pure_of({"s": "nope"}), pure_of({"s": "kick"})), 0.0, 0.0)
	sch5.process_window(0.0, 1.0)
	check("known instrument survives an unknown one", frames_of(sink5.of_type("note")) == [24000], str(frames_of(sink5.of_type("note"))))

	# 6. Window-splitting invariance: one window vs 128 windows of 1/32 cycle.
	var make_run := func(split: bool):
		var sk = SinkScript.new()
		var sc = make_scheduler(sk)
		sc.add_source("drums", "g", seq3_of(pure_of({"s": "kick"}), pure_of({"s": "hat"}), pure_of({"s": "snare", "gain": 0.7})), 0.0, 0.0)
		sc.add_source("bass", "g", pure_of({"s": "bass", "note": 38}).fast(FracScript.make(3, 1)), 0.5, 0.5)
		if split:
			for i in 128:
				sc.process_window(float(i) / 32.0, float(i + 1) / 32.0)
		else:
			sc.process_window(0.0, 4.0)
		return sk.events
	var whole = make_run.call(false)
	var parts = make_run.call(true)
	check("splitting windows gives identical events", JSON.stringify(whole) == JSON.stringify(parts), "%d vs %d events" % [whole.size(), parts.size()])
	check("enough events to mean something", whole.size() > 20, str(whole.size()))
	var sorted_ok := true
	for i in range(1, whole.size()):
		if whole[i]["on_frame"] < whole[i - 1]["on_frame"]:
			sorted_ok = false
	check("events come out in onset order", sorted_ok, "")

	# 7. t0, start and end clip the source.
	var sink7 = SinkScript.new()
	var sch7 = make_scheduler(sink7)
	sch7.add_source("late", "g", seq_of(pure_of({"s": "kick"}), pure_of({"s": "hat"})), 1.0, 1.0, 3.0)
	sch7.process_window(0.0, 4.0)
	check("source clipped to [start, end)", frames_of(sink7.of_type("note")) == [48000, 72000, 96000, 120000], str(frames_of(sink7.of_type("note"))))
	var sink7b = SinkScript.new()
	var sch7b = make_scheduler(sink7b)
	sch7b.add_source("off", "g", pure_of({"s": "kick"}), 0.5, 0.5)
	sch7b.process_window(0.0, 2.0)
	check("t0 shifts the pattern", frames_of(sink7b.of_type("note")) == [24000, 72000], str(frames_of(sink7b.of_type("note"))))

	# 8. set_source_end, remove_source, replace by id, pruning.
	var sink8 = SinkScript.new()
	var sch8 = make_scheduler(sink8)
	sch8.add_source("a", "g", pure_of({"s": "kick"}), 0.0, 0.0)
	sch8.process_window(0.0, 1.0)
	sch8.set_source_end("a", 2.0)
	check("get_source shows the new end", sch8.get_source("a")["end"] == 2.0, str(sch8.get_source("a")))
	sch8.process_window(1.0, 4.0)
	check("set_source_end stops the source (end exclusive)", frames_of(sink8.of_type("note")) == [0, 48000], str(frames_of(sink8.of_type("note"))))
	check("finished source is pruned", not sch8.has_source("a") and sch8.get_sources().is_empty(), "")
	sch8.add_source("b", "g", pure_of({"s": "kick"}), 4.0, 4.0)
	sch8.remove_source("b")
	sch8.process_window(4.0, 6.0)
	check("removed source emits nothing", sink8.of_type("note").size() == 2, "")
	sch8.add_source("r", "g", pure_of({"s": "kick"}), 0.0, 0.0)
	sch8.add_source("r", "g", pure_of({"s": "hat"}), 0.0, 0.0)
	check("same id replaces", sch8.get_sources().size() == 1 and sch8.get_source("r")["group"] == "g", "")
	sch8.get_sources()[0]["end"] = 0.0
	check("get_sources returns copies", sch8.get_source("r")["end"] == INF, "")

	# 9. Ties: same onset, source order decides.
	var sink9 = SinkScript.new()
	var sch9 = make_scheduler(sink9)
	sch9.add_source("first", "g", pure_of({"s": "kick"}), 0.0, 0.0)
	sch9.add_source("second", "g", pure_of({"s": "hat"}), 0.0, 0.0)
	sch9.process_window(0.0, 1.0)
	var tracks9: Array = []
	for e in sink9.of_type("note"):
		tracks9.append(e["track"])
	check("equal onsets keep source order", tracks9 == ["g/kick", "g/hat"], str(tracks9))

	# 10. Query controls reach the pattern (game params).
	var sink10 = SinkScript.new()
	var sch10 = make_scheduler(sink10)
	sch10.controls = {"params": {"danger": 0.5}}
	sch10.add_source("p", "g", params_pattern(), 0.0, 0.0)
	sch10.process_window(0.0, 1.0)
	var n10 := sink10.of_type("note")
	check("controls.params visible to the pattern", n10.size() == 1 and near(n10[0]["velocity"], 0.4), str(n10))

	# 11. next_boundary table. Rows: [c, kind, count, beats_per_bar, expected].
	var rows := [
		[0.0, "bar", 1, 4, 0.0], [0.3, "bar", 1, 4, 1.0], [1.0, "bar", 1, 4, 1.0], [1.0 + 1.0e-12, "bar", 1, 4, 1.0], [1.0 + 1.0e-6, "bar", 1, 4, 2.0],
		[1.2, "beat", 1, 4, 1.25], [1.25, "beat", 1, 4, 1.25], [0.26, "beat", 1, 4, 0.5], [0.0, "beat", 1, 4, 0.0], [0.1, "beat", 1, 3, 1.0 / 3.0],
		[2.3, "bars", 4, 4, 4.0], [4.0, "bars", 4, 4, 4.0], [4.01, "bars", 4, 4, 8.0], [0.0, "bars", 2, 4, 0.0],
		[0.6, "beats", 2, 4, 1.0], [0.5, "beats", 2, 4, 0.5], [1.0, "beats", 3, 4, 1.5],
		[1.234, "now", 1, 4, 1.234], [0.4, "weird", 1, 4, 1.0],
	]
	var table_ok := true
	for r in rows:
		var got: float = SchedulerScript.next_boundary(r[0], {"kind": r[1], "count": r[2]}, r[3])
		if absf(got - r[4]) > 1.0e-9:
			table_ok = false
			print("FAIL next_boundary row: ", r, " got ", got)
	check("next_boundary table", table_ok, "%d rows" % rows.size())

	# 12. The base sink ignores everything and the recording sink clears.
	var base = load("res://addons/godot_synth/cue/cue_sink.gd").new()
	base.note("t", 60.0, 0.5, 0, 10, {})
	base.param("t", "x", 1.0, 0)
	base.gain_ramp("g", 0.0, 0, 0)
	check("base sink is a no-op", true, "")
	var rec = SinkScript.new()
	rec.param("g/kick", "fx0.cutoff", 500.0, 12)
	rec.gain_ramp("g", 0.5, 100, 50)
	check("param event shape", rec.events[0] == {"type": "param", "track": "g/kick", "name": "fx0.cutoff", "value": 500.0, "frame": 12}, str(rec.events[0]))
	check("gain_ramp event shape", rec.events[1] == {"type": "gain_ramp", "group": "g", "gain": 0.5, "frame": 100, "ramp_frames": 50}, str(rec.events[1]))
	rec.clear()
	check("clear empties the log", rec.events.is_empty(), "")

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
