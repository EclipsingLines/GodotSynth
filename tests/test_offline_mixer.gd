extends SceneTree
# SynthOfflineMixer: multi-track offline mix through the live playback path.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_offline_mixer.gd

const SR := 44100
const ON_A := 4410
const ON_B := 9000

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func make_config(wave: int) -> VASynthConfiguration:
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
	sound.top_waveform = wave
	sound.middle_waveform = wave
	sound.bottom_waveform = wave
	return sound

func build(with_b: bool) -> SynthOfflineMixer:
	var m := SynthOfflineMixer.new()
	check("init", m.init(SR), "")
	var ta := m.add_track(make_config(0))
	var tb := -1
	if with_b:
		tb = m.add_track(make_config(3))
	m.schedule_note(ta, 69.0, 1.0, ON_A, 13230)
	if with_b:
		m.schedule_note(tb, 57.0, 1.0, ON_B, 20000)
	return m

func first_nonzero(a: PackedVector2Array) -> int:
	for i in a.size():
		if a[i].x != 0.0 or a[i].y != 0.0:
			return i
	return -1

func peak_in(a: PackedVector2Array, from: int, to: int) -> float:
	var p := 0.0
	for i in range(from, mini(to, a.size())):
		p = maxf(p, maxf(absf(a[i].x), absf(a[i].y)))
	return p

func _initialize() -> void:
	# Two tracks.
	var two := build(true)
	check("track count", two.get_track_count() == 2, str(two.get_track_count()))
	var out := two.render(22050)
	check("length", out.size() == 22050, str(out.size()))
	check("mixed frames", two.get_mixed_frames() == 22050, str(two.get_mixed_frames()))
	two.render(1000)
	check("mixed frames accumulate", two.get_mixed_frames() == 23050, str(two.get_mixed_frames()))

	# Onset exactness: nothing before the first note, signal right at it.
	var onset := first_nonzero(out)
	check("silent before first onset", onset >= ON_A, "first non-zero sample at %d" % onset)
	check("first onset exact", onset >= ON_A and onset < ON_A + 32, "first non-zero sample at %d" % onset)

	# Track A alone must equal the two-track mix until track B starts, and differ afterwards.
	var only_a := build(false).render(22050)
	var same_until_b := true
	for i in ON_B:
		if out[i] != only_a[i]:
			same_until_b = false
			break
	check("tracks are independent until B starts", same_until_b, "")
	var diff := 0.0
	for i in range(ON_B + 64, ON_B + 2000):
		diff = maxf(diff, absf(out[i].x - only_a[i].x))
	check("track B is summed in", diff > 0.01, "max difference %f" % diff)
	check("no late events", two.get_late_event_count() == 0, str(two.get_late_event_count()))

	# Determinism: the same calls give bit-identical output.
	var again := build(true).render(22050)
	check("deterministic", again == out, "")

	# Controls and parameter events.
	var m := SynthOfflineMixer.new()
	m.init(SR)
	var t := m.add_track(make_config(1))
	check("note with controls", m.schedule_note(t, 60.0, 1.0, 1000, 5000, {"pulse_width": 0.3}), "")
	check("parameter event", m.schedule_parameter(t, "pulse_width", 0.2, 3000), "")
	check("unknown parameter", not m.schedule_parameter(t, "no_such_parameter", 0.2, 3000), "")
	check("unknown control tolerated", m.schedule_note(t, 62.0, 1.0, 6000, 8000, {"no_such_control": 1.0}), "")
	var o := m.render(12000)
	check("controls render", peak_in(o, 1000, 5000) > 0.01, "peak %f" % peak_in(o, 1000, 5000))
	check("controls: no late events", m.get_late_event_count() == 0, str(m.get_late_event_count()))

	# A dense schedule is larger than the playback's event ring and still lands on time.
	var dense := SynthOfflineMixer.new()
	dense.init(SR)
	var td := dense.add_track(make_config(0))
	for i in 600:
		dense.schedule_note(td, 60.0 + (i % 12), 0.8, i * 100, i * 100 + 50)
	var dout := dense.render(70000)
	check("dense schedule renders", peak_in(dout, 0, 70000) > 0.0001, "peak %f" % peak_in(dout, 0, 70000))
	check("dense schedule: no late events", dense.get_late_event_count() == 0, str(dense.get_late_event_count()))

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
