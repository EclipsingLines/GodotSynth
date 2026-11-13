extends SceneTree
# CueConductor: switches on boundaries, last request wins, rule precedence, crossfade segments, fills, re-entry.
# Run: bash tests/verify.sh --no-build tests/test_cue_conductor.gd

const ParserScript = preload("res://addons/godot_synth/cue/cue_parser.gd")
const LibScript = preload("res://addons/godot_synth/cue/cue_lib.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")
const SinkScript = preload("res://addons/godot_synth/cue/cue_recording_sink.gd")
const ConductorScript = preload("res://addons/godot_synth/cue/cue_conductor.gd")

const BASE := """tempo 120
state a:
  s("kick")
state b:
  s("hat")
state c:
  s("snare")
transition a -> b on bar fade 1 fill s("lead")
transition * -> b on 2 bars fade 2
transition * -> c on beat
"""

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

# Returns [conductor, sink] for a cue source, or [] when it does not parse/compile.
func make(src: String) -> Array:
	var r: Dictionary = ParserScript.parse(src)
	if not r["ok"]:
		check("source parses", false, str(r["diagnostics"]))
		return []
	var compiled: Dictionary = LibScript.compile(r["ast"], 0)
	if not compiled["errors"].is_empty():
		check("source compiles", false, str(compiled["errors"]))
		return []
	var sink = SinkScript.new()
	var cond = ConductorScript.new(compiled, catalog, sink, Callable(self, "c2f"))
	cond.start()
	return [cond, sink]

# Windows of 1/4 cycle from `from` to `to` (both multiples of 0.25).
func run(cond, from: float, to: float) -> void:
	var c := from
	while c < to - 1.0e-9:
		cond.process_window(c, minf(c + 0.25, to))
		c += 0.25

func note_frames(sink, track: String) -> Array:
	var out: Array = []
	for e in sink.of_type("note"):
		if e["track"] == track:
			out.append(e["on_frame"])
	return out

func ramps(sink, group: String) -> Array:
	var out: Array = []
	for e in sink.of_type("gain_ramp"):
		if e["group"] == group:
			out.append(e)
	return out

# Checks a 16-segment fade for `group`: segments start at `first_frame`, each `seg_frames` long, gains
# follow sin (up) or cos (down) and end exactly on the target.
func fade_ok(evs: Array, offset: int, first_frame: int, seg_frames: int, up: bool) -> bool:
	if evs.size() < offset + 16:
		return false
	for i in range(1, 17):
		var e: Dictionary = evs[offset + i - 1]
		var x := float(i) / 16.0
		var want: float = sin(x * PI / 2.0) if up else cos(x * PI / 2.0)
		if i == 16:
			want = 1.0 if up else 0.0
			if e["gain"] != want:
				return false
		if not near(e["gain"], want) or e["frame"] != first_frame + seg_frames * (i - 1) or e["ramp_frames"] != seg_frames:
			return false
	return true

func _initialize() -> void:
	catalog = CatalogScript.load_default()

	# 1. No request: the initial state plays alone, nothing but notes is emitted.
	var m1 := make(BASE)
	var cond1 = m1[0]
	var sink1 = m1[1]
	check("initial state is the first declared", cond1.get_state() == "a" and cond1.get_pending_state() == "" and cond1.get_pending_cycle() == -1.0, "")
	check("beats per bar", cond1.beats_per_bar == 4, str(cond1.beats_per_bar))
	run(cond1, 0.0, 2.0)
	check("initial state notes", note_frames(sink1, "a/kick") == [0, 48000], str(note_frames(sink1, "a/kick")))
	check("no gain events without a switch", sink1.of_type("gain_ramp").is_empty(), "")
	check("no-op for the current state", cond1.set_state("a") and cond1.get_log().is_empty(), "")
	check("unknown state refused", not cond1.set_state("zzz") and cond1.get_log().is_empty(), "")

	# 2. a -> b on bar, fade 1, with a fill; requested at 0.5 so the switch is at 1.0.
	var m2 := make(BASE)
	var cond2 = m2[0]
	var sink2 = m2[1]
	run(cond2, 0.0, 0.5)
	check("set_state accepted", cond2.set_state("b"), "")
	check("pending state and cycle", cond2.get_pending_state() == "b" and cond2.get_pending_cycle() == 1.0 and cond2.get_state() == "a", "%s %f" % [cond2.get_pending_state(), cond2.get_pending_cycle()])
	var req: Dictionary = cond2.get_log()[0]
	check("request log: a -> b rule wins over * -> b", req["type"] == "request" and req["t_sw"] == 1.0 and req["fade"] == 1.0 and req["has_fill"] == true and req["from"] == "a" and req["to"] == "b" and req["quant"]["kind"] == "bar", str(req))
	run(cond2, 0.5, 1.0)
	check("switch waits for the window that passes t_sw", cond2.get_state() == "a" and cond2.get_pending_state() == "b", "")
	run(cond2, 1.0, 3.0)
	check("switch applied", cond2.get_state() == "b" and cond2.get_pending_state() == "", "")
	check("old state plays through the fade only", note_frames(sink2, "a/kick") == [0, 48000], str(note_frames(sink2, "a/kick")))
	check("new state starts at the switch point", note_frames(sink2, "b/hat") == [48000, 96000], str(note_frames(sink2, "b/hat")))
	check("fill plays once in the transitions group", note_frames(sink2, "transitions/lead") == [48000], str(note_frames(sink2, "transitions/lead")))
	var up2 := ramps(sink2, "b")
	var down2 := ramps(sink2, "a")
	check("new group: step to 0 then 16 segments", up2.size() == 17 and up2[0]["gain"] == 0.0 and up2[0]["frame"] == 48000 and up2[0]["ramp_frames"] == 0, str(up2.size()))
	check("new group follows sin to exactly 1", fade_ok(up2, 1, 48000, 3000, true), "")
	check("old group follows cos to exactly 0", down2.size() == 16 and fade_ok(down2, 0, 48000, 3000, false), str(down2.size()))
	check("equal power midpoint", near(up2[8]["gain"], 0.70710678) and near(down2[7]["gain"], 0.70710678), "%f %f" % [up2[8]["gain"], down2[7]["gain"]])
	check("33 gain events in all", sink2.of_type("gain_ramp").size() == 33, str(sink2.of_type("gain_ramp").size()))
	var log2: Array = cond2.get_log()
	check("switch log", log2.size() == 2 and log2[1]["type"] == "switch" and log2[1]["cycle"] == 1.0 and log2[1]["from"] == "a" and log2[1]["to"] == "b" and log2[1]["fade"] == 1.0 and log2[1]["fill"] == true, str(log2))

	# 3. Last request wins: b is pending, then c replaces it (c has its own rule: on beat, hard cut).
	var m3 := make(BASE)
	var cond3 = m3[0]
	var sink3 = m3[1]
	run(cond3, 0.0, 0.5)
	cond3.set_state("b")
	cond3.set_state("c")
	check("last request wins", cond3.get_pending_state() == "c" and cond3.get_pending_cycle() == 0.5, "%s %f" % [cond3.get_pending_state(), cond3.get_pending_cycle()])
	run(cond3, 0.5, 2.0)
	check("replaced request never plays", note_frames(sink3, "b/hat").is_empty() and cond3.get_state() == "c", "")
	check("fade 0: old state cut at the switch point", note_frames(sink3, "a/kick") == [0], str(note_frames(sink3, "a/kick")))
	check("new state restarts at the switch point", note_frames(sink3, "c/snare") == [24000, 72000], str(note_frames(sink3, "c/snare")))
	var g3: Array = sink3.of_type("gain_ramp")
	check("fade 0 emits one step to 1.0 for the new group", g3.size() == 1 and g3[0]["group"] == "c" and g3[0]["gain"] == 1.0 and g3[0]["frame"] == 24000 and g3[0]["ramp_frames"] == 0, str(g3))
	var reqs3 := 0
	var sw3 := 0
	for e in cond3.get_log():
		if e["type"] == "request":
			reqs3 += 1
		if e["type"] == "switch":
			sw3 += 1
	check("log has two requests and one switch", reqs3 == 2 and sw3 == 1, "%d %d" % [reqs3, sw3])
	# Requesting the current state cancels a pending switch.
	var m3b := make(BASE)
	run(m3b[0], 0.0, 0.5)
	m3b[0].set_state("b")
	check("requesting the current state cancels the pending one", m3b[0].set_state("a") and m3b[0].get_pending_state() == "", "")
	run(m3b[0], 0.5, 3.0)
	check("cancelled switch never happens", m3b[0].get_state() == "a" and note_frames(m3b[1], "b/hat").is_empty(), "")

	# 4. Wildcard rule: from c, b uses "* -> b on 2 bars fade 2". Requested at 3.25 -> next multiple of 2 is 4.0.
	run(cond3, 2.0, 3.25)
	cond3.set_state("b")
	var req4: Dictionary = cond3.get_log()[cond3.get_log().size() - 1]
	check("wildcard rule, 2 bars boundary", req4["t_sw"] == 4.0 and req4["fade"] == 2.0 and req4["has_fill"] == false and req4["quant"]["kind"] == "bars" and req4["quant"]["count"] == 2, str(req4))

	# 5. Default rule with no transitions: bar boundary, hard cut, no fill.
	var m5 := make("state a:\n  s(\"kick\")\nstate b:\n  s(\"hat\")\n")
	var cond5 = m5[0]
	var sink5 = m5[1]
	run(cond5, 0.0, 0.5)
	cond5.set_state("b")
	check("default rule switch point", cond5.get_pending_cycle() == 1.0, str(cond5.get_pending_cycle()))
	run(cond5, 0.5, 2.0)
	check("default rule: hard cut, new state from the boundary", note_frames(sink5, "a/kick") == [0] and note_frames(sink5, "b/hat") == [48000], "")
	check("default rule: one step, no fill group", sink5.of_type("gain_ramp").size() == 1 and note_frames(sink5, "transitions/lead").is_empty(), "")

	# 6. Fill window is max(1, F) cycles: fade 0.25 -> 1 cycle, fade 3 -> 3 cycles.
	var m6 := make("tempo 120\nstate a:\n  s(\"kick\")\nstate b:\n  s(\"hat\")\ntransition a -> b on bar fade 0.25 fill s(\"snare*2\")\ntransition b -> a on bar fade 3 fill s(\"snare*2\")\n")
	var cond6 = m6[0]
	var sink6 = m6[1]
	run(cond6, 0.0, 0.5)
	cond6.set_state("b")
	run(cond6, 0.5, 6.0)
	check("fill of a short fade lasts one cycle", note_frames(sink6, "transitions/snare") == [48000, 72000], str(note_frames(sink6, "transitions/snare")))
	check("short fade: segments of 750 frames", fade_ok(ramps(sink6, "b"), 1, 48000, 750, true), "")
	cond6.set_state("a")
	check("b -> a request at an exact boundary", cond6.get_pending_cycle() == 6.0, str(cond6.get_pending_cycle()))
	run(cond6, 6.0, 10.0)
	var snares6 := note_frames(sink6, "transitions/snare")
	check("fill of a long fade lasts F cycles", snares6 == [48000, 72000, 288000, 312000, 336000, 360000, 384000, 408000], str(snares6))
	var a6 := ramps(sink6, "a")
	check("re-entering a group: step to 0 then a sin fade up", a6.size() == 33 and a6[16]["gain"] == 0.0 and a6[16]["frame"] == 288000 and fade_ok(a6, 17, 288000, 9000, true), str(a6.size()))
	check("long fade: old group cos down", fade_ok(ramps(sink6, "b"), 17, 288000, 9000, false), "")

	# 7. Re-entering a state that is still fading out: stale segments are dropped, the old instance is cut.
	var m7 := make("tempo 120\nstate a:\n  s(\"kick\")\nstate b:\n  s(\"hat\")\ntransition a -> b on bar fade 4\ntransition b -> a on bar fade 1\n")
	var cond7 = m7[0]
	var sink7 = m7[1]
	run(cond7, 0.0, 0.5)
	cond7.set_state("b")                 # switch at 1.0, fade 4 (segments of 0.25 cycle = 12000 frames)
	run(cond7, 0.5, 1.5)
	cond7.set_state("a")                 # b -> a on bar: switch at 2.0, fade 1
	check("re-entry switch point", cond7.get_pending_cycle() == 2.0, str(cond7.get_pending_cycle()))
	run(cond7, 1.5, 4.0)
	var a7 := ramps(sink7, "a")
	var b7 := ramps(sink7, "b")
	check("group a: 4 old segments + step + 16 new", a7.size() == 21, str(a7.size()))
	check("group b: step + 4 old segments + 16 new", b7.size() == 21, str(b7.size()))
	check("old segments were cut after 4", a7[0]["frame"] == 48000 and a7[0]["ramp_frames"] == 12000 and a7[3]["frame"] == 48000 + 3 * 12000, str(a7[3]))
	check("stale segments never emitted: first event at the re-entry is the step", a7[4]["gain"] == 0.0 and a7[4]["frame"] == 96000 and a7[4]["ramp_frames"] == 0, str(a7[4]))
	check("re-entered group fades up", fade_ok(a7, 5, 96000, 3000, true), "")
	check("b fades down over the new fade", fade_ok(b7, 5, 96000, 3000, false), "")
	check("old instance of a is cut at the re-entry, new instance plays", note_frames(sink7, "a/kick") == [0, 48000, 96000, 144000], str(note_frames(sink7, "a/kick")))
	check("b ends one fade after the re-entry", note_frames(sink7, "b/hat") == [48000, 96000], str(note_frames(sink7, "b/hat")))

	# 8. A meter of 3 beats: "on beat" boundaries are thirds of a cycle.
	var m8 := make("tempo 90 3/4\nstate a:\n  s(\"kick\")\nstate b:\n  s(\"hat\")\ntransition a -> b on beat\n")
	var cond8 = m8[0]
	cond8.process_window(0.0, 0.1)
	cond8.set_state("b")
	check("beats per bar from the tempo", cond8.beats_per_bar == 3, str(cond8.beats_per_bar))
	check("beat boundary in a 3/4 cue", near(cond8.get_pending_cycle(), 1.0 / 3.0), str(cond8.get_pending_cycle()))

	# 9. restart resets everything.
	cond2.start()
	check("start resets state, log and gains", cond2.get_state() == "a" and cond2.get_log().is_empty() and cond2.get_scheduled_to() == 0.0, "")

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
