extends SceneTree
# CuePlayer: loading, diagnostics, created players, tempo, live state switch and params (Dummy audio).
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_player.gd

const PlayerScript = preload("res://addons/godot_synth/cue/cue_player.gd")

const CUE := """tempo 480
param danger 0..1 = 0
state a:
  s("kick")
  s("hat*4")
state b:
  s("kick")
  s("snare")
transition a -> b on bar fade 0.5 fill s("pad")
stinger f on beat: s("lead")
bind pad.lpf <- danger 400..4000
"""

var failures: Array[String] = []
var cp = null
var step := 0
var wall := 0.0
var fired := false
var fired_from := ""
var fired_to := ""
var fired_cycle := 0.0
var switch_cycle := 0.0

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func codes(ds: Array) -> Array:
	var out: Array = []
	for d: Dictionary in ds:
		out.append(d["code"])
	return out

func finish() -> bool:
	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
	return true

func _on_state_changed(from_state: String, to_state: String) -> void:
	fired = true
	fired_from = from_state
	fired_to = to_state
	fired_cycle = cp.get_current_cycle()

func _initialize() -> void:
	cp = PlayerScript.new()

	# 1. Bad cues are refused with diagnostics and leave the node empty.
	var d1: Array = cp.load_source("state a:\n  s(\"crash\")\n")
	check("unknown instrument refuses to load", not cp.is_loaded() and "E_UNKNOWN_INSTRUMENT" in codes(d1), str(codes(d1)))
	check("nothing created on a failed load", cp.get_child_count() == 0 and cp.players.is_empty(), str(cp.get_child_count()))
	var d2: Array = cp.load_source("state a:\n  s(\"kick\"\n")
	check("syntax error is reported", not cp.is_loaded() and "E_SYNTAX" in codes(d2), str(codes(d2)))
	var d3: Array = cp.load_source("")
	check("a cue without a state is refused", not cp.is_loaded() and "E_NO_STATE" in codes(d3), str(codes(d3)))
	var d4: Array = cp.load_source("param p = 0\nstate a:\n  s(\"bass\")\nbind bass.attack <- p\n")
	check("unknown control refuses to load", not cp.is_loaded() and "E_UNKNOWN_CONTROL" in codes(d4), str(codes(d4)))
	var d5: Array = cp.load_cue("res://does/not/exist.cue")
	check("missing file is E_IO", not cp.is_loaded() and "E_IO" in codes(d5), str(codes(d5)))
	check("play refused when nothing is loaded", not cp.play(), "")
	check("live API refused when nothing is loaded", not cp.set_state("a") and not cp.stinger("f") and not cp.set_param("danger", 0.5) and cp.get_state() == "", "")

	# 2. A cue with only warnings loads; reloading replaces the children.
	var d6: Array = cp.load_source("state a:\n  n(\"0 2\").s(\"lead\")\n")
	check("warnings do not block loading", cp.is_loaded() and "W_N_WITHOUT_SCALE" in codes(d6), str(codes(d6)))
	check("one player and the transport", cp.players.keys() == ["a/lead"] and cp.get_child_count() == 2, str(cp.players.keys()))

	# 3. The real cue.
	var d7: Array = cp.load_source(CUE)
	var errors := 0
	for d: Dictionary in d7:
		if d["severity"] == "error":
			errors += 1
	check("cue loads without errors", cp.is_loaded() and errors == 0, str(d7))
	var keys: Array = cp.players.keys()
	keys.sort()
	check("one player per (group, instrument)", keys == ["a/hat", "a/kick", "b/kick", "b/snare", "stingers/lead", "transitions/pad"], str(keys))
	check("children: 6 players and the transport (old ones removed)", cp.get_child_count() == 7, str(cp.get_child_count()))
	check("players share the transport", cp.transport.players.size() == 6, str(cp.transport.players.size()))
	check("transport cps = bpm / 60 / beats", is_equal_approx(cp.transport.get_cps(), 2.0), str(cp.transport.get_cps()))
	check("catalog polyphony and configuration", cp.players["a/kick"].polyphony == 2 and cp.players["a/hat"].polyphony == 4 and cp.players["a/kick"].configuration != null, "")
	check("names from the cue", Array(cp.get_state_names()) == ["a", "b"] and Array(cp.get_stinger_names()) == ["f"] and Array(cp.get_param_names()) == ["danger"], "")
	check("param range", cp.get_param_range("danger") == Vector2(0.0, 1.0), "")
	check("not playing yet", not cp.is_playing() and cp.get_state() == "", "")
	check("play refused outside the tree", not cp.play(), "")

	# 4. Live run, driven from _process.
	cp.state_changed.connect(_on_state_changed)
	root.add_child(cp)

func _process(delta: float) -> bool:
	wall += delta
	if wall > 20.0:
		check("test finished in time", false, "timeout in step %d" % step)
		return finish()
	match step:
		0:
			if cp.players["a/kick"].get_mixed_frames() > 0:
				check("play succeeds in the tree", cp.play(), "")
				check("playing, initial state", cp.is_playing() and cp.get_state() == "a", cp.get_state())
				wall = 0.0
				step = 1
		1:
			if wall > 0.4:
				check("set_state accepted", cp.set_state("b"), "")
				check("pending state", cp.get_pending_state() == "b", cp.get_pending_state())
				switch_cycle = cp.conductor.get_pending_cycle()
				check("switch point is a whole bar", switch_cycle == ceilf(switch_cycle) and switch_cycle > 0.0, str(switch_cycle))
				wall = 0.0
				step = 2
		2:
			if fired:
				check("state_changed(a, b)", fired_from == "a" and fired_to == "b", "%s -> %s" % [fired_from, fired_to])
				check("signal fires after the clock passes the switch point", fired_cycle >= switch_cycle - 0.001, "%f vs %f" % [fired_cycle, switch_cycle])
				check("state is b", cp.get_state() == "b" and cp.get_pending_state() == "", cp.get_state())
				check("stinger accepted", cp.stinger("f"), "")
				check("unknown stinger refused", not cp.stinger("nope"), "")
				check("set_param clamps", cp.set_param("danger", 5.0) and cp.get_param("danger") == 1.0, str(cp.get_param("danger")))
				check("unknown param refused", not cp.set_param("nope", 0.5), "")
				wall = 0.0
				step = 3
		3:
			if wall > 0.6:
				check("transport advanced", cp.get_current_cycle() > switch_cycle, str(cp.get_current_cycle()))
				cp.stop()
				check("stopped", not cp.is_playing(), "")
				cp.queue_free()
				return finish()
	return false
