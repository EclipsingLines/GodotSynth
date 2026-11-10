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

# Amplitude of one frequency component over samples[from, to) (Goertzel).
func tone_level(s: PackedFloat32Array, from: int, to: int, freq: float, sample_rate := 44100.0) -> float:
	var w := TAU * freq / sample_rate
	var c := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	for i in range(from, to):
		var s0: float = s[i] + c * s1 - s2
		s2 = s1
		s1 = s0
	var re := s1 - s2 * cos(w)
	var im := s2 * sin(w)
	return 2.0 * sqrt(re * re + im * im) / float(to - from)

# Statistics over stereo frames[from, to).
func stereo_stats(s: PackedVector2Array, from: int, to: int) -> Dictionary:
	var peak := 0.0
	var sq := 0.0
	var diff := 0.0
	var finite := true
	for i in range(from, to):
		var v := s[i]
		if is_nan(v.x) or is_nan(v.y) or is_inf(v.x) or is_inf(v.y):
			finite = false
			continue
		peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
		sq += 0.5 * (v.x * v.x + v.y * v.y)
		diff += (v.x - v.y) * (v.x - v.y)
	var n := float(maxi(to - from, 1))
	return {"peak": peak, "rms": sqrt(sq / n), "side_rms": sqrt(diff / n), "finite": finite}

func with_master(config: SynthConfiguration, effect: SynthAudioEffect) -> SynthConfiguration:
	var chain := EffectChain.new()
	chain.add_effect(effect)
	config.master_effect_chain = chain
	return config

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

	# PolyBLEP: at A7 (3520 Hz) the 13th harmonic of a naive saw folds back to
	# 1660 Hz at about 0.049. Band-limited, it should be gone.
	var high_saw := render(make_config(SAW), 105.0, 1.0)
	var alias := tone_level(high_saw, 4410, 44100, 1660.0)
	var fundamental := tone_level(high_saw, 4410, 44100, 3520.0)
	check("saw anti-aliasing", alias < 0.005 and fundamental > 0.5, "1660 Hz alias %.5f, fundamental %.4f" % [alias, fundamental])
	var high_square := render(make_config(SQUARE), 105.0, 1.0)
	var sq_alias := tone_level(high_square, 4410, 44100, 1660.0)
	check("square anti-aliasing", sq_alias < 0.01, "1660 Hz alias %.5f" % sq_alias)

	# Master effect chain: no chain means identical left and right.
	var plain := SynthOfflineRenderer.render_note_stereo(make_config(SAW), 57.0, 1.0, 1.0, 0.2)
	var plain_st := stereo_stats(plain, 0, plain.size())
	var plain_tail := stereo_stats(plain, int(0.4 * 44100), plain.size())
	check("stereo without master chain", plain_st.side_rms == 0.0 and plain_tail.peak < 0.001, "side rms %.6f, tail peak %.6f" % [plain_st.side_rms, plain_tail.peak])

	# Ping-pong on the master chain: echoes continue after the note and
	# alternate between left and right.
	var pp := PingPongDelay.new()
	pp.delay_time_parameter.base_value = 0.1
	pp.feedback_parameter.base_value = 0.5
	pp.mix_parameter.base_value = 0.5
	var echo := SynthOfflineRenderer.render_note_stereo(with_master(make_config(SAW), pp), 57.0, 1.0, 1.0, 0.2)
	var echo_tail := stereo_stats(echo, int(0.4 * 44100), int(0.8 * 44100))
	check("master ping-pong tail", echo_tail.finite and echo_tail.rms > 0.01, "rms %.4f after the note ended" % echo_tail.rms)
	check("master ping-pong stereo", echo_tail.side_rms > 0.5 * echo_tail.rms, "side rms %.4f vs rms %.4f" % [echo_tail.side_rms, echo_tail.rms])

	# Reverb at its largest, most diffuse settings must stay stable and decay.
	var rv := Reverb.new()
	rv.room_size_parameter.base_value = 0.95
	rv.diffusion_parameter.base_value = 0.9
	rv.mix_parameter.base_value = 0.5
	var verb := SynthOfflineRenderer.render_note_stereo(with_master(make_config(SAW), rv), 57.0, 1.0, 6.0, 0.2)
	var verb_all := stereo_stats(verb, 0, verb.size())
	var verb_early := stereo_stats(verb, int(0.3 * 44100), int(0.8 * 44100))
	var verb_late := stereo_stats(verb, int(5.0 * 44100), verb.size())
	check("reverb stable", verb_all.finite and verb_all.peak < 2.0, "peak %.4f" % verb_all.peak)
	check("reverb decays", verb_early.rms > 0.005 and verb_late.rms < verb_early.rms * 0.05, "rms %.5f at 0.3-0.8 s, %.6f at 5-6 s" % [verb_early.rms, verb_late.rms])
	check("reverb stereo", verb_early.side_rms > 0.0001, "side rms %.5f" % verb_early.side_rms)

	# PitchHelper.
	check("PitchHelper.midi_to_freq(69)", absf(PitchHelper.midi_to_freq(69.0) - 440.0) < 0.05, "%.4f" % PitchHelper.midi_to_freq(69.0))
	check("PitchHelper.midi_to_freq(60)", absf(PitchHelper.midi_to_freq(60.0) - 261.626) < 0.05, "%.4f" % PitchHelper.midi_to_freq(60.0))
	var fifth := PitchHelper.fast_pitch(7.0)
	check("PitchHelper.fast_pitch(7)", absf(fifth - pow(2.0, 7.0 / 12.0)) < 0.001, "%.5f (want %.5f)" % [fifth, pow(2.0, 7.0 / 12.0)])

	# Musical presets (GS-045): pitch is a semitone offset and the filter cutoff is in Hz.
	var bass_cfg := VASynthConfiguration.new()
	bass_cfg.set_preset(BassPreset.new())
	var bass_chain: EffectChain = bass_cfg.effect_chain
	var bass_filter: SynthAudioEffect = bass_chain.get_effects()[0]
	var bass_cutoff: ModulatedParameter = bass_filter.get_parameter("cutoff")
	check("preset pitch is an offset", absf(bass_cfg.pitch_modulation.base_value) < 0.001, "base %.2f" % bass_cfg.pitch_modulation.base_value)
	check("preset cutoff is in Hz", bass_cutoff.mod_max >= 20000.0 and bass_cutoff.base_value >= 20.0, "base %.1f range %.1f..%.1f" % [bass_cutoff.base_value, bass_cutoff.mod_min, bass_cutoff.mod_max])
	var bass_steady := steady(render(bass_cfg, 60.0, 1.0))
	check("bass preset is audible", bass_steady.finite and bass_steady.rms > 0.01, "rms %.4f" % bass_steady.rms)

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
