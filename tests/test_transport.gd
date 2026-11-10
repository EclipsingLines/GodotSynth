extends SceneTree
# SynthTransport: tempo map conversions, window continuity and tempo changes (no audio needed).
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_transport.gd

const Transport := preload("res://addons/godot_synth/transport/synth_transport.gd")

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func _initialize() -> void:
	# 1. Conversions and round trips at 48 kHz, 0.5 cps.
	var t := Transport.new()
	t.sample_rate = 48000
	t.reset_tempo(0.5)
	check("cycle 1 -> frame", t.cycle_to_frame(1.0) == 96000, str(t.cycle_to_frame(1.0)))
	check("frame -> cycle 1", is_equal_approx(t.frame_to_cycle(96000), 1.0), str(t.frame_to_cycle(96000)))
	var worst := 0.0
	for i in 200:
		var c := float(i) * 0.37
		worst = maxf(worst, absf(t.frame_to_cycle(t.cycle_to_frame(c)) - c))
	check("round trip within half a frame", worst < 1.0e-5, "worst error %g cycles" % worst)

	# 2. Window continuity over 100 calls with a fake frame source.
	var fake: Array[int] = [0]
	t.frame_source = func() -> int: return fake[0]
	t.start()
	check("origin after start", t.origin_frame == 4800, str(t.origin_frame))
	var windows: Array = []
	for i in 100:
		fake[0] += 600 + (i * 37) % 900
		windows.append(t.poll_window())
	var contiguous := true
	var nonneg := true
	var non_empty := 0
	for i in windows.size():
		var w = windows[i]
		if i == 0 and w.from_cycle != 0.0:
			contiguous = false
		if i > 0 and w.from_cycle != windows[i - 1].to_cycle:
			contiguous = false
		if w.to_cycle < w.from_cycle:
			nonneg = false
		if not w.is_empty():
			non_empty += 1
	check("first window starts at cycle 0", windows[0].from_cycle == 0.0, str(windows[0].from_cycle))
	check("windows are contiguous (no gaps, no overlaps)", contiguous, "")
	check("windows never run backwards", nonneg, "")
	check("most windows are non-empty", non_empty >= 90, str(non_empty))
	var expect_end: float = t.frame_to_cycle(fake[0] - t.origin_frame + roundi(t.lookahead_sec * 48000.0))
	check("last window ends at the lookahead horizon", is_equal_approx(windows[99].to_cycle, expect_end), "%f vs %f" % [windows[99].to_cycle, expect_end])
	check("current cycle", is_equal_approx(t.get_current_cycle(), maxf(0.0, t.frame_to_cycle(fake[0] - t.origin_frame))), str(t.get_current_cycle()))
	var held := t.poll_window()
	check("no clock progress -> empty window", held.is_empty(), "")
	t.stop()
	check("stopped", not t.running, "")
	t.free()

	# 3. Tempo change at a cycle boundary.
	var t3 := Transport.new()
	t3.sample_rate = 48000
	t3.reset_tempo(1.0)
	var fake3: Array[int] = [0]
	t3.frame_source = func() -> int: return fake3[0]
	t3.start()
	fake3[0] = 60000 # 55200 frames after the origin, plus 7200 lookahead = 1.3 cycles
	var w1 = t3.poll_window()
	check("window reaches 1.3 cycles", is_equal_approx(w1.to_cycle, 1.3), str(w1.to_cycle))
	t3.set_cps(2.0) # takes effect at the next whole cycle: 2.0
	check("old tempo kept before the boundary", t3.cycle_to_frame(1.5) == 72000, str(t3.cycle_to_frame(1.5)))
	check("boundary frame", t3.cycle_to_frame(2.0) == 96000, str(t3.cycle_to_frame(2.0)))
	check("new tempo after the boundary", t3.cycle_to_frame(3.0) == 120000, str(t3.cycle_to_frame(3.0)))
	check("frame -> cycle after the boundary", is_equal_approx(t3.frame_to_cycle(120000), 3.0), str(t3.frame_to_cycle(120000)))
	check("absolute frame", t3.cycle_to_absolute_frame(3.0) == 124800, str(t3.cycle_to_absolute_frame(3.0)))
	t3.set_cps(4.0) # replaces the pending change
	check("later set_cps replaces the pending change", t3.cycle_to_frame(3.0) == 108000, str(t3.cycle_to_frame(3.0)))
	t3.set_cps(1.0) # equals the current tempo: no change pending
	check("back to the old tempo cancels the change", t3.cycle_to_frame(3.0) == 144000, str(t3.cycle_to_frame(3.0)))
	t3.set_cps(4.0)
	fake3[0] = 200000
	var w2 = t3.poll_window()
	check("windows stay contiguous across the tempo change", w2.from_cycle == w1.to_cycle, "%f vs %f" % [w2.from_cycle, w1.to_cycle])
	var want := 2.0 + float(200000 - 4800 + 7200 - 96000) * 4.0 / 48000.0
	check("window end uses the new tempo", is_equal_approx(w2.to_cycle, want), "%f vs %f" % [w2.to_cycle, want])
	# A change after more has been scheduled lands on the next whole cycle after that window.
	t3.set_cps(1.0)
	check("second change boundary", t3.cycle_to_frame(11.0) == 204000, str(t3.cycle_to_frame(11.0)))
	check("second change tempo", t3.cycle_to_frame(12.0) == 252000, str(t3.cycle_to_frame(12.0)))
	t3.free()

	# 4. Drift detection (warning output is expected for the unequal case).
	var t4 := Transport.new()
	var same: Array[int] = [5, 5, 5]
	var skewed: Array[int] = [5, 5, 6]
	check("equal counters are fine", t4.check_drift_values(same), "")
	check("unequal counters are reported", not t4.check_drift_values(skewed), "")
	t4.free()

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
