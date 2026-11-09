extends SceneTree
# Deterministic offline-render test: renders notes with SynthOfflineRenderer
# (no audio server involved) and checks pitch, level, NaN/Inf, waveform
# selection and the oscillator shapes.
# Run: Godot --headless --path project -s ../tests/offline_render.gd
# Exits with code 0 when every check passes, 1 otherwise.

const SINE := 0
const SQUARE := 1
const SAW := 3
const SUPER_SAW := 8
const SUB_SQUARE := 9

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func make_config(bottom: int, middle := -1, top := -1, pulse_width := 0.5) -> VASynthConfiguration:
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
	var pw := ModulatedParameter.new()
	pw.base_value = pulse_width
	sound.pulse_width_modulation = pw
	sound.bottom_waveform = bottom
	sound.middle_waveform = bottom if middle < 0 else middle
	sound.top_waveform = bottom if top < 0 else top
	return sound

# Statistics over samples[from, to).
func stats(s: PackedFloat32Array, sample_rate: float, from: int, to: int) -> Dictionary:
	var peak := 0.0
	var sq := 0.0
	var sum := 0.0
	var finite := true
	var first_cross := -1.0
	var last_cross := -1.0
	var crossings := 0
	for i in range(from, to):
		var v := s[i]
		if is_nan(v) or is_inf(v):
			finite = false
			continue
		peak = maxf(peak, absf(v))
		sq += v * v
		sum += v
		if i > from and s[i - 1] <= 0.0 and v > 0.0:
			# Linear interpolation of the crossing point.
			var pos := float(i - 1) + (-s[i - 1]) / (v - s[i - 1])
			if first_cross < 0.0:
				first_cross = pos
			last_cross = pos
			crossings += 1
	var n := float(maxi(to - from, 1))
	var freq := 0.0
	if crossings > 1:
		freq = float(crossings - 1) * sample_rate / (last_cross - first_cross)
	return {"peak": peak, "rms": sqrt(sq / n), "mean": sum / n, "freq": freq, "finite": finite}

func render(config: SynthConfiguration, note: float, seconds := 0.5, release_at := -1.0, sample_rate := 44100.0) -> PackedFloat32Array:
	return SynthOfflineRenderer.render_note(config, note, 1.0, seconds, release_at, sample_rate)

func steady(s: PackedFloat32Array, sample_rate := 44100.0) -> Dictionary:
	# Skip the attack/decay (first 0.1 s).
	return stats(s, sample_rate, int(0.1 * sample_rate), s.size())

func _initialize() -> void:
	# Pitch and level.
	var a4 := render(make_config(SINE), 69.0)
	var st := steady(a4)
	check("render length", a4.size() == 22050, "%d samples" % a4.size())
	check("finite", st.finite, "no NaN/Inf")
	check("A4 pitch", absf(st.freq - 440.0) < 0.5, "%.2f Hz" % st.freq)
	check("sine level", absf(st.rms - 0.7071) < 0.02 and st.peak < 1.01, "rms %.4f peak %.4f" % [st.rms, st.peak])

	var c4 := steady(render(make_config(SINE), 60.0))
	check("C4 pitch", absf(c4.freq - 261.626) < 0.5, "%.2f Hz" % c4.freq)

	var r48 := render(make_config(SINE), 69.0, 0.5, -1.0, 48000.0)
	var st48 := steady(r48, 48000.0)
	check("A4 pitch at 48 kHz", absf(st48.freq - 440.0) < 0.5, "%.2f Hz" % st48.freq)

	# Determinism.
	check("deterministic", render(make_config(SINE), 69.0) == a4, "two renders are identical")

	# Release: silent after release + release time.
	var rel := render(make_config(SINE), 69.0, 0.6, 0.3)
	var tail := stats(rel, 44100.0, int(0.5 * 44100.0), rel.size())
	check("silence after release", tail.peak < 0.001, "peak %.6f" % tail.peak)

	# Waveform selection (issue #3): a square must not sound like a sine.
	var sq := steady(render(make_config(SQUARE), 69.0))
	check("waveform selection", absf(sq.rms - st.rms) > 0.2, "sine rms %.4f, square rms %.4f" % [st.rms, sq.rms])
	check("square level", absf(sq.rms - 1.0) < 0.05, "rms %.4f" % sq.rms)

	# SUB_SQUARE is a square one octave down, with no DC.
	var sub := steady(render(make_config(SUB_SQUARE), 69.0))
	check("sub square no DC", absf(sub.mean) < 0.05, "mean %.4f" % sub.mean)
	check("sub square octave", absf(sub.freq - 220.0) < 1.0, "%.2f Hz" % sub.freq)

	# SUPER_SAW detunes its saws, so its short-window level beats over time.
	var ss := render(make_config(SUPER_SAW, -1, -1, 0.99), 57.0, 1.0)
	var lo := 1e9
	var hi := 0.0
	var win := 882 # 20 ms
	var pos := 4410
	while pos + win <= ss.size():
		var w := stats(ss, 44100.0, pos, pos + win)
		lo = minf(lo, w.rms)
		hi = maxf(hi, w.rms)
		pos += win
	check("super saw detune", hi > lo * 1.15, "20 ms rms ranges %.4f..%.4f" % [lo, hi])

	# PitchHelper.
	check("PitchHelper.midi_to_freq(69)", absf(PitchHelper.midi_to_freq(69.0) - 440.0) < 0.05, "%.4f" % PitchHelper.midi_to_freq(69.0))
	check("PitchHelper.midi_to_freq(60)", absf(PitchHelper.midi_to_freq(60.0) - 261.626) < 0.05, "%.4f" % PitchHelper.midi_to_freq(60.0))
	var fifth := PitchHelper.fast_pitch(7.0)
	check("PitchHelper.fast_pitch(7)", absf(fifth - pow(2.0, 7.0 / 12.0)) < 0.001, "%.5f (want %.5f)" % [fifth, pow(2.0, 7.0 / 12.0)])

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
