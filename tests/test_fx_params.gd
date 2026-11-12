extends SceneTree
# fx<i>.<param> addressing: has_parameter, schedule_parameter and note controls reach effect parameters.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_fx_params.gd

const SR := 44100

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

# Saw note through a default LowPassFilter (cutoff range 20..20000 Hz) as effect 0.
func make_filtered_config() -> VASynthConfiguration:
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
	sound.top_waveform = 3
	sound.middle_waveform = 3
	sound.bottom_waveform = 3
	var chain := EffectChain.new()
	chain.add_effect(LowPassFilter.new())
	sound.effect_chain = chain
	return sound

func make_plain_config() -> VASynthConfiguration:
	var sound := make_filtered_config()
	sound.effect_chain = null
	return sound

func rms(a: PackedVector2Array, from: int, to: int) -> float:
	var s := 0.0
	for i in range(from, to):
		s += a[i].x * a[i].x
	return sqrt(s / float(to - from))

# Root mean square of the first difference divided by the plain RMS: grows with high-frequency content.
func hf_ratio(a: PackedVector2Array, from: int, to: int) -> float:
	var d := 0.0
	for i in range(from + 1, to):
		var x := a[i].x - a[i - 1].x
		d += x * x
	var base := rms(a, from, to)
	if base < 1.0e-9:
		return 0.0
	return sqrt(d / float(to - from - 1)) / base

func render_with_control(cutoff: float) -> PackedVector2Array:
	var m := SynthOfflineMixer.new()
	m.init(SR)
	var t := m.add_track(make_filtered_config())
	m.schedule_note(t, 57.0, 1.0, 1000, -1, {"fx0.cutoff": cutoff})
	return m.render(22050)

func _initialize() -> void:
	# 1. has_parameter on a player.
	var player := AudioSynthPlayer.new()
	check("no configuration -> false", not player.has_parameter("fx0.cutoff"), "")
	player.configuration = make_filtered_config()
	check("engine parameter", player.has_parameter("pitch"), "")
	check("fx0.cutoff", player.has_parameter("fx0.cutoff"), "")
	check("fx0.resonance", player.has_parameter("fx0.resonance"), "")
	check("fx9.cutoff out of range", not player.has_parameter("fx9.cutoff"), "")
	check("fx0.bogus unknown parameter", not player.has_parameter("fx0.bogus"), "")
	check("fx.cutoff malformed", not player.has_parameter("fx.cutoff"), "")
	check("fx0 without parameter", not player.has_parameter("fx0"), "")
	check("fx0. empty parameter", not player.has_parameter("fx0."), "")
	check("FX0.cutoff is case sensitive", not player.has_parameter("FX0.cutoff"), "")
	check("fx-1.cutoff negative", not player.has_parameter("fx-1.cutoff"), "")
	player.free()

	# A preset configuration: the filter is effect 0 (BassPreset: LowPassFilter, then OverdriveDistortion).
	var preset_player := AudioSynthPlayer.new()
	var cfg := VASynthConfiguration.new()
	cfg.set_preset(BassPreset.new())
	preset_player.configuration = cfg
	check("preset fx0.cutoff", preset_player.has_parameter("fx0.cutoff"), "")
	check("preset fx0.resonance", preset_player.has_parameter("fx0.resonance"), "")
	check("preset fx1.drive (distortion)", preset_player.has_parameter("fx1.drive"), "")
	check("preset fx2.drive does not exist", not preset_player.has_parameter("fx2.drive"), "")
	preset_player.free()

	var plain := AudioSynthPlayer.new()
	plain.configuration = make_plain_config()
	check("no effect chain -> fx0.cutoff false", not plain.has_parameter("fx0.cutoff"), "")
	check("no effect chain -> engine parameter still true", plain.has_parameter("pitch"), "")
	plain.free()

	# 2. Offline mixer: the control changes the sound.
	var low := render_with_control(100.0)
	var high := render_with_control(2000.0)
	check("rendered something (low cutoff)", rms(low, 4000, 22000) > 1.0e-5, "rms %g" % rms(low, 4000, 22000))
	check("rendered something (high cutoff)", rms(high, 4000, 22000) > 1.0e-4, "rms %g" % rms(high, 4000, 22000))
	var hf_low := hf_ratio(low, 4000, 22000)
	var hf_high := hf_ratio(high, 4000, 22000)
	check("low cutoff has less high-frequency energy", hf_low < hf_high * 0.5, "low %g, high %g" % [hf_low, hf_high])
	check("different cutoffs give different audio", low != high, "")

	# 3. Mixer schedule_parameter and unknown names.
	var m := SynthOfflineMixer.new()
	m.init(SR)
	var t := m.add_track(make_filtered_config())
	check("schedule_parameter fx0.cutoff", m.schedule_parameter(t, "fx0.cutoff", 500.0, 3000), "")
	check("schedule_parameter fx9.cutoff is false", not m.schedule_parameter(t, "fx9.cutoff", 500.0, 3000), "")
	check("schedule_parameter fx0.bogus is false", not m.schedule_parameter(t, "fx0.bogus", 500.0, 3000), "")
	check("note with unknown fx control tolerated", m.schedule_note(t, 57.0, 1.0, 100, 2000, {"fx9.cutoff": 1.0}), "")
	var m2 := SynthOfflineMixer.new()
	m2.init(SR)
	var t2 := m2.add_track(make_plain_config())
	check("no effect chain: schedule_parameter fx0.cutoff is false", not m2.schedule_parameter(t2, "fx0.cutoff", 500.0, 10), "")

	# 4. A mid-note schedule_parameter changes the sound after its frame and not before.
	var before := SynthOfflineMixer.new()
	before.init(SR)
	var tb := before.add_track(make_filtered_config())
	before.schedule_note(tb, 57.0, 1.0, 1000, -1, {"fx0.cutoff": 2000.0})
	var base := before.render(30000)
	var after := SynthOfflineMixer.new()
	after.init(SR)
	var ta := after.add_track(make_filtered_config())
	after.schedule_note(ta, 57.0, 1.0, 1000, -1, {"fx0.cutoff": 2000.0})
	after.schedule_parameter(ta, "fx0.cutoff", 100.0, 15000)
	var changed := after.render(30000)
	var same_before := true
	for i in 15000:
		if absf(base[i].x - changed[i].x) > 1.0e-5:
			same_before = false
			break
	check("identical before the parameter frame", same_before, "")
	var hf_a := hf_ratio(base, 20000, 30000)
	var hf_b := hf_ratio(changed, 20000, 30000)
	check("less high-frequency energy after the change", hf_b < hf_a * 0.5, "before %g, after %g" % [hf_a, hf_b])

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
