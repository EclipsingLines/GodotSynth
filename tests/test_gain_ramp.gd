extends SceneTree
# GAIN_RAMP: sample-accurate gain ramps on a playback, through SynthOfflineMixer.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_gain_ramp.gd

const SR := 44100
const ON := 1000
const F := 22050   # ramp starts here
const N := 8820    # 0.2 s ramp
const TOTAL := 44100

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func make_config() -> VASynthConfiguration:
	var sound := VASynthConfiguration.new()
	sound.waveform_modulation = ModulatedParameter.new()
	var amp := ModulatedParameter.new()
	amp.base_value = 0.0
	amp.mod_amount = 1.0
	amp.mod_type = 0
	var adsr := ADSR.new()
	adsr.attack = 0.01
	adsr.decay = 0.05
	adsr.sustain_level = 1.0
	adsr.release = 0.05
	amp.source = adsr
	sound.amplitude_modulation = amp
	sound.pitch_modulation = ModulatedParameter.new()
	sound.pulse_width_modulation = ModulatedParameter.new()
	sound.top_waveform = 0
	sound.middle_waveform = 0
	sound.bottom_waveform = 0
	return sound

# A held sine note (A4) on one track; `ramps` is an Array of [gain, frame, ramp_frames].
func render(ramps: Array) -> PackedVector2Array:
	var m := SynthOfflineMixer.new()
	m.init(SR)
	var t := m.add_track(make_config())
	m.schedule_note(t, 69.0, 1.0, ON, -1)
	for r in ramps:
		m.schedule_gain_ramp(t, float(r[0]), int(r[1]), int(r[2]))
	return m.render(TOTAL)

func max_abs_diff(a: PackedVector2Array, b: PackedVector2Array, from: int, to: int) -> float:
	var d := 0.0
	for i in range(from, to):
		d = maxf(d, absf(a[i].x - b[i].x))
	return d

func _initialize() -> void:
	check("mixer has schedule_gain_ramp", ClassDB.class_has_method("SynthOfflineMixer", "schedule_gain_ramp"), "")
	check("player has schedule_gain_ramp", ClassDB.class_has_method("AudioSynthPlayer", "schedule_gain_ramp"), "")

	var ref_out := render([])
	var peak_ref := 0.0
	for i in range(5000, F):
		peak_ref = maxf(peak_ref, absf(ref_out[i].x))
	check("reference note is audible", peak_ref > 0.05, "peak %f" % peak_ref)

	# 1. Ramp to 0 over N frames at F.
	var down := render([[0.0, F, N]])
	check("unchanged before the ramp frame", max_abs_diff(ref_out, down, 0, F) < 1.0e-5, "diff %g" % max_abs_diff(ref_out, down, 0, F))
	var worst := 0.0
	var checked := 0
	for i in range(F, F + N):
		if absf(ref_out[i].x) > 0.1:
			var ratio := down[i].x / ref_out[i].x
			var want := 1.0 - float(i - F) / float(N)
			worst = maxf(worst, absf(ratio - want))
			checked += 1
	check("gain follows a linear ramp", checked > 1000 and worst < 0.02, "worst ratio error %f over %d samples" % [worst, checked])
	var silent := true
	for i in range(F + N, TOTAL):
		if down[i].x != 0.0 or down[i].y != 0.0:
			silent = false
			break
	check("exactly zero from F+N on", silent, "")

	# Monotone: the windowed peak never grows (441 frames = 10 ms; tolerance for the discrete sine).
	var prev := 1.0e9
	var monotone := true
	var k := F
	while k + 441 <= F + N:
		var p := 0.0
		for i in range(k, k + 441):
			p = maxf(p, absf(down[i].x))
		if p > prev + 0.02:
			monotone = false
		prev = p
		k += 441
	check("windowed peak is non-increasing", monotone, "")

	# 2. Ramp 0 frames is a step.
	var step := render([[0.0, F, 0]])
	check("step: unchanged before F", max_abs_diff(ref_out, step, 0, F) < 1.0e-5, "")
	var step_silent := true
	for i in range(F, TOTAL):
		if step[i].x != 0.0 or step[i].y != 0.0:
			step_silent = false
			break
	check("step: zero from F on", step_silent, "")

	# 3. Ramp down, then step back to 1 later: the signal returns.
	var G := 34000
	var back := render([[0.0, F, N], [1.0, G, 0]])
	check("back to unity after a step up", max_abs_diff(ref_out, back, G + 2000, TOTAL) < 0.02, "diff %g" % max_abs_diff(ref_out, back, G + 2000, TOTAL))
	var still_zero := true
	for i in range(F + N, G):
		if back[i].x != 0.0:
			still_zero = false
			break
	check("zero between the ramp end and the step up", still_zero, "")

	# 4. A new ramp cuts a running one: the second starts from the value reached at its frame.
	var cut_frame := F + N / 2
	var cut := render([[0.0, F, N], [1.0, cut_frame, 0]])
	check("a step cuts a running ramp", max_abs_diff(ref_out, cut, cut_frame + 1000, TOTAL) < 0.02, "")

	# 5. Gain above 1 is allowed up to 4, below 0 clamps to 0.
	var loud := render([[2.0, F, 0]])
	var peak_loud := 0.0
	for i in range(F + 1000, F + 3000):
		peak_loud = maxf(peak_loud, absf(loud[i].x))
	check("gain 2 doubles the level (clamped at +/-1)", peak_loud > peak_ref * 1.5 or peak_loud >= 0.999, "peak %f vs %f" % [peak_loud, peak_ref])
	var neg := render([[-3.0, F, 0]])
	var neg_silent := true
	for i in range(F, TOTAL):
		if neg[i].x != 0.0:
			neg_silent = false
			break
	check("negative gain clamps to 0", neg_silent, "")

	# 6. Bad arguments are rejected without a crash (an error line is expected).
	var m := SynthOfflineMixer.new()
	m.init(SR)
	var t := m.add_track(make_config())
	check("bad track rejected", not m.schedule_gain_ramp(5, 0.5, 100, 10), "")
	check("negative frame rejected", not m.schedule_gain_ramp(t, 0.5, -1, 10), "")
	check("valid call accepted", m.schedule_gain_ramp(t, 0.5, 100, 10), "")

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
