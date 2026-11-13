extends SceneTree
# CueConductor: stingers, params (clamp, game() visibility) and binds.
# Run: bash tests/verify.sh --no-build tests/test_cue_conductor_extras.gd

const ParserScript = preload("res://addons/godot_synth/cue/cue_parser.gd")
const LibScript = preload("res://addons/godot_synth/cue/cue_lib.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")
const SinkScript = preload("res://addons/godot_synth/cue/cue_recording_sink.gd")
const ConductorScript = preload("res://addons/godot_synth/cue/cue_conductor.gd")

const SRC := """tempo 120
param danger 0..1 = 0
param depth -2..2 = -1
state a:
  s("hat").gain(game("danger"))
state b:
  s("kick")
stinger found on beat len 2: s("lead*2")
stinger hit: s("snare")
bind pad.lpf <- danger 400..4000
bind bass.lpq <- danger
bind hat.hpf <- depth 200..8000
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

func make() -> Array:
	var r: Dictionary = ParserScript.parse(SRC)
	if not r["ok"]:
		check("source parses", false, str(r["diagnostics"]))
		return []
	var compiled: Dictionary = LibScript.compile(r["ast"], 0)
	if not compiled["errors"].is_empty():
		check("source compiles", false, str(compiled["errors"]))
		return []
	var pairs := {
		"a": PackedStringArray(["hat", "pad"]),
		"b": PackedStringArray(["bass", "kick", "pad"]),
		"stingers": PackedStringArray(["lead", "snare"]),
	}
	var sink = SinkScript.new()
	var cond = ConductorScript.new(compiled, catalog, sink, Callable(self, "c2f"), pairs)
	cond.start()
	return [cond, sink]

func note_frames(sink, track: String) -> Array:
	var out: Array = []
	for e in sink.of_type("note"):
		if e["track"] == track:
			out.append(e["on_frame"])
	return out

func param_events(sink) -> Array:
	return sink.of_type("param")

func summary(evs: Array) -> Array:
	var out: Array = []
	for e in evs:
		out.append([e["track"], e["name"], float(roundi(e["value"] * 1000.0)) / 1000.0, e["frame"]])
	return out

func _initialize() -> void:
	catalog = CatalogScript.load_default()

	# 1. set_param clamps into the declared range; unknown names are refused.
	var m1 := make()
	var cond1 = m1[0]
	check("default value", cond1.get_param("danger") == 0.0 and cond1.get_param("depth") == -1.0, "")
	check("set_param in range", cond1.set_param("danger", 0.25) and near(cond1.get_param("danger"), 0.25), "")
	cond1.set_param("danger", 5.0)
	check("clamped to hi", cond1.get_param("danger") == 1.0, str(cond1.get_param("danger")))
	cond1.set_param("danger", -3.0)
	check("clamped to lo", cond1.get_param("danger") == 0.0, "")
	cond1.set_param("depth", 10.0)
	check("custom range hi", cond1.get_param("depth") == 2.0, "")
	cond1.set_param("depth", -10.0)
	check("custom range lo", cond1.get_param("depth") == -2.0, "")
	check("unknown param refused", not cond1.set_param("nope", 0.5) and cond1.get_param("nope") == 0.0, "")
	var plog := 0
	for e in cond1.get_log():
		if e["type"] == "param":
			plog += 1
	check("param log entries (the refused call is not logged)", plog == 5, str(plog))

	# 2. game("danger") sees set_param from the next window on (velocity = 0.8 x gain).
	var m2 := make()
	var cond2 = m2[0]
	var sink2 = m2[1]
	cond2.process_window(0.0, 1.0)
	cond2.set_param("danger", 0.5)
	cond2.process_window(1.0, 2.0)
	var hats: Array = []
	for e in sink2.of_type("note"):
		if e["track"] == "a/hat":
			hats.append(e)
	check("two hat notes", hats.size() == 2, str(hats.size()))
	if hats.size() == 2:
		check("before set_param: gain 0", near(hats[0]["velocity"], 0.0) and hats[0]["on_frame"] == 0, str(hats[0]))
		check("after set_param: gain 0.5", near(hats[1]["velocity"], 0.4) and hats[1]["on_frame"] == 48000, str(hats[1]))

	# 3. Binds: initial values, then only on change, lerp mapping, every track of the instrument.
	var m3 := make()
	var cond3 = m3[0]
	var sink3 = m3[1]
	cond3.process_window(0.0, 0.25)
	var first := summary(param_events(sink3))
	check("first window emits every bind once, to every track", first == [
		["a/pad", "fx0.cutoff", 400.0, 0], ["b/pad", "fx0.cutoff", 400.0, 0],
		["b/bass", "fx0.resonance", 0.0, 0],
		["a/hat", "fx0.cutoff", 2150.0, 0]], str(first))
	cond3.process_window(0.25, 0.5)
	cond3.process_window(0.5, 0.75)
	check("no change, no events", param_events(sink3).size() == 4, str(param_events(sink3).size()))
	cond3.set_param("danger", 0.5)
	cond3.process_window(0.75, 1.0)
	var second := summary(param_events(sink3).slice(4))
	check("changed param: lerp(400, 4000, 0.5) and the default range 0..1, at the window start", second == [
		["a/pad", "fx0.cutoff", 2200.0, 36000], ["b/pad", "fx0.cutoff", 2200.0, 36000],
		["b/bass", "fx0.resonance", 0.5, 36000]], str(second))
	cond3.set_param("danger", 0.5)
	cond3.process_window(1.0, 1.25)
	check("same value again: no events", param_events(sink3).size() == 7, str(param_events(sink3).size()))
	cond3.set_param("depth", 2.0)
	cond3.process_window(1.25, 1.5)
	var third := summary(param_events(sink3).slice(7))
	check("only the bound control that changed", third == [["a/hat", "fx0.cutoff", 8000.0, 60000]], str(third))
	cond3.set_param("danger", 1.0)
	cond3.process_window(1.5, 1.75)
	var fourth := summary(param_events(sink3).slice(8))
	check("param at its max reaches the range end", fourth == [
		["a/pad", "fx0.cutoff", 4000.0, 72000], ["b/pad", "fx0.cutoff", 4000.0, 72000],
		["b/bass", "fx0.resonance", 1.0, 72000]], str(fourth))

	# 4. A conductor without pairs emits no bind events and does not break.
	var r4: Dictionary = ParserScript.parse(SRC)
	var c4: Dictionary = LibScript.compile(r4["ast"], 0)
	var sink4 = SinkScript.new()
	var cond4 = ConductorScript.new(c4, catalog, sink4, Callable(self, "c2f"))
	cond4.start()
	cond4.process_window(0.0, 1.0)
	check("no pairs: no param events", param_events(sink4).is_empty() and not sink4.of_type("note").is_empty(), "")

	# 5. Stingers: quantized start, length, retrigger.
	var m5 := make()
	var cond5 = m5[0]
	var sink5 = m5[1]
	cond5.process_window(0.0, 0.3)
	check("stinger accepted", cond5.stinger("found"), "")
	cond5.process_window(0.3, 1.2)
	check("lead*2 from the next beat (0.5), onsets every half cycle", note_frames(sink5, "stingers/lead") == [24000, 48000], str(note_frames(sink5, "stingers/lead")))
	check("stinger retrigger accepted", cond5.stinger("found"), "")
	cond5.process_window(1.2, 4.0)
	var lead := note_frames(sink5, "stingers/lead")
	check("retrigger ends the old instance at the new start and restarts", lead == [24000, 48000, 60000, 84000, 108000, 132000], str(lead))
	check("stinger does not change the state", cond5.get_state() == "a" and cond5.get_pending_state() == "", "")
	check("default quant (beat) and len 1: hit at an exact boundary", cond5.stinger("hit"), "")
	cond5.process_window(4.0, 6.0)
	check("hit plays one note", note_frames(sink5, "stingers/snare") == [192000], str(note_frames(sink5, "stingers/snare")))
	check("unknown stinger refused", not cond5.stinger("nope"), "")
	var st_log: Array = []
	for e in cond5.get_log():
		if e["type"] == "stinger":
			st_log.append([e["name"], e["cycle"]])
	check("stinger log", st_log == [["found", 0.5], ["found", 1.25], ["hit", 4.0]], str(st_log))

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
