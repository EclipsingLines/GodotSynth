extends SceneTree
# Musical preset repair (GS-045): every preset's pitch is a semitone offset and its filter cutoff is in Hz.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_preset_repair.gd

const SR := 44100.0
const C4_HZ := 261.626

var failures: Array[String] = []

# cls: preset class. band: the Hz range every cutoff the preset can reach must lie in
# (the intent: bass 300-800, pad 1-2 kHz, kick low, snare/hat 1-6 kHz, lead/arp 1-2 kHz).
# bipolar: the cutoff source is an LFO (cutoff = base +/- mod_amount).
# dur: render length in seconds. pitch: steady window [from, to] in seconds for the f0 check,
# empty for the noise based drums (no pitch check).
var specs: Array[Dictionary] = [
	{"cls": "BassPreset", "band": [250.0, 900.0], "bipolar": false, "dur": 1.0, "pitch": [0.4, 0.55]},
	{"cls": "LeadSynthPreset", "band": [900.0, 2200.0], "bipolar": false, "dur": 1.0, "pitch": [0.45, 0.6]},
	{"cls": "PadSynthPreset", "band": [900.0, 2200.0], "bipolar": true, "dur": 3.0, "pitch": [2.6, 2.75]},
	{"cls": "KickDrumPreset", "band": [50.0, 600.0], "bipolar": false, "dur": 0.5, "pitch": []},
	{"cls": "SnareDrumPreset", "band": [900.0, 6500.0], "bipolar": false, "dur": 0.5, "pitch": []},
	{"cls": "HiHatPreset", "band": [900.0, 6500.0], "bipolar": false, "dur": 0.5, "pitch": []},
	{"cls": "ArpeggiatorPreset", "band": [900.0, 2200.0], "bipolar": false, "dur": 0.5, "pitch": [0.015, 0.115]},
]

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func make_cfg(cls: String) -> VASynthConfiguration:
	var cfg := VASynthConfiguration.new()
	cfg.set_preset(ClassDB.instantiate(cls))
	return cfg

# Cutoff parameter of effect 0 (the filter in all seven presets); null if there is none.
func cutoff_of(cfg: VASynthConfiguration) -> ModulatedParameter:
	var chain: EffectChain = cfg.effect_chain
	if chain == null or chain.get_effects().is_empty():
		return null
	var fx: SynthAudioEffect = chain.get_effects()[0]
	return fx.get_parameter("cutoff")

func rms(s: PackedFloat32Array, from: int, to: int) -> float:
	var sum := 0.0
	for i in range(from, to):
		sum += s[i] * s[i]
	return sqrt(sum / float(maxi(to - from, 1)))

func all_finite(s: PackedFloat32Array) -> bool:
	for v in s:
		if is_nan(v) or is_inf(v):
			return false
	return true

# Fundamental by autocorrelation over s[from, to): the first local maximum within 90% of the
# best one in the lag range 120..1200 Hz. 0.0 when there is no clear period.
func estimate_f0(s: PackedFloat32Array, from: int, to: int) -> float:
	var min_lag := int(SR / 1200.0)
	var max_lag := int(SR / 120.0)
	var m := (to - from) - max_lag - 1
	if m < 1000:
		return 0.0
	var r := PackedFloat32Array()
	r.resize(max_lag + 2)
	var best := 0.0
	for lag in range(min_lag, max_lag + 1):
		var acc := 0.0
		for i in range(from, from + m):
			acc += s[i] * s[i + lag]
		r[lag] = acc
		best = maxf(best, acc)
	if best <= 0.0:
		return 0.0
	for lag in range(min_lag + 1, max_lag):
		if r[lag] >= 0.9 * best and r[lag] >= r[lag - 1] and r[lag] >= r[lag + 1]:
			return SR / float(lag)
	return 0.0

func _initialize() -> void:
	for spec in specs:
		var cls: String = spec.cls
		var cfg := make_cfg(cls)

		# 1. Pitch is a semitone offset, not a MIDI number. Today: base 36..84.
		var base_pitch: float = cfg.pitch_modulation.base_value
		check(cls + " pitch offset is 0", absf(base_pitch) < 0.001, "base %.2f" % base_pitch)

		# 2. The cutoff is a Hz parameter with the filter's range and lies in the intended band.
		# Today: range 0..1, base 0.3..0.7, so all three fail.
		var cutoff := cutoff_of(cfg)
		if cutoff == null:
			check(cls + " has a filter", false, "no effect 0 or no cutoff parameter")
			continue
		check(cls + " cutoff range", absf(cutoff.mod_min - 20.0) < 0.01 and absf(cutoff.mod_max - 20000.0) < 0.01,
				"range %.1f..%.1f" % [cutoff.mod_min, cutoff.mod_max])
		var points: Array[float] = [cutoff.base_value, cutoff.base_value + cutoff.mod_amount]
		if spec.bipolar:
			points.append(cutoff.base_value - cutoff.mod_amount)
		var band: Array = spec.band
		var in_band := true
		for p in points:
			if p < band[0] or p > band[1]:
				in_band = false
		check(cls + " cutoff in band", in_band, "reaches %s Hz, want %.0f..%.0f" % [str(points), band[0], band[1]])

		# 3. Audible through the whole chain at note 60. Today the three low-pass presets (bass,
		# pad, kick) sit behind a 20 Hz low-pass and are near silent (about -70 dBFS).
		# The hi-hat's bitcrush (untouched by GS-045) holds one sample for 0.125 s at its default
		# sample-rate parameter, while the hat envelope decays in 0.1 s, so its full chain is
		# silent whatever the cutoff. Disable that hold in the test's own copy to measure the
		# filter, and pin the full chain's actual (silent) level so the mismatch stays visible.
		var audio_cfg := cfg
		if cls == "HiHatPreset":
			var raw := SynthOfflineRenderer.render_note(cfg, 60.0, 1.0, spec.dur)
			var raw_level := rms(raw, 0, raw.size())
			check(cls + " full chain is silent (bitcrush sample hold)", raw_level < 0.001, "rms %.4f" % raw_level)
			audio_cfg = make_cfg(cls)
			var crush: SynthAudioEffect = audio_cfg.effect_chain.get_effects()[1]
			var crush_rate: ModulatedParameter = crush.get_parameter("sample_rate")
			crush_rate.base_value = 0.0
		var audio := SynthOfflineRenderer.render_note(audio_cfg, 60.0, 1.0, spec.dur)
		var level := rms(audio, 0, audio.size())
		check(cls + " is audible", all_finite(audio) and level > 0.01, "rms %.4f over %.1f s" % [level, spec.dur])

		# 4. Pitch: note 60 sounds near 261.6 Hz. Measured with the effect chain removed, so the
		# band-pass filters of lead and arp cannot hide the fundamental. Today the note comes out
		# near 1046.5 Hz (pitch clamps to +24 semitones), 4x too high.
		var window: Array = spec.pitch
		if window.is_empty():
			continue
		var bare := make_cfg(cls)
		bare.effect_chain = null
		var tone := SynthOfflineRenderer.render_note(bare, 60.0, 1.0, spec.dur)
		var f0 := estimate_f0(tone, int(float(window[0]) * SR), int(float(window[1]) * SR))
		check(cls + " pitch of note 60", absf(f0 - C4_HZ) < C4_HZ * 0.03, "%.1f Hz, want %.1f" % [f0, C4_HZ])

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
