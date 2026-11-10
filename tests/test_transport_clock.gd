extends SceneTree
# Transport clock: a playback's mixed_frames counts every frame it mixes, silent or not.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_transport_clock.gd

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func make_sine_config() -> VASynthConfiguration:
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

func peak_of(a: PackedVector2Array) -> float:
	var p := 0.0
	for v in a:
		p = maxf(p, maxf(absf(v.x), absf(v.y)))
	return p

func _initialize() -> void:
	var pb := SynthAudioStreamPlayback.new()
	pb.sample_rate = 44100.0
	check("starts at zero", pb.get_mixed_frames() == 0, str(pb.get_mixed_frames()))

	# Silent playback: the counter must still advance by exactly the frames mixed.
	var a := pb.render_offline(1024)
	check("silent render length", a.size() == 1024, str(a.size()))
	check("silent render is silent", peak_of(a) == 0.0, "peak %f" % peak_of(a))
	check("silent 1024", pb.get_mixed_frames() == 1024, str(pb.get_mixed_frames()))
	pb.render_offline(4096)
	check("silent 4096 more", pb.get_mixed_frames() == 5120, str(pb.get_mixed_frames()))
	# A size that is not a multiple of the 512-frame chunk.
	pb.render_offline(700)
	check("odd block size", pb.get_mixed_frames() == 5820, str(pb.get_mixed_frames()))
	var expected := 5820

	# A note plays: counter keeps advancing, and the output is audible.
	var cfg := make_sine_config()
	var ctx := pb.queue_note(cfg, 69.0, 1.0)
	check("queue_note returns a context", ctx != null, str(ctx))
	var played := pb.render_offline(2048)
	expected += 2048
	check("note is audible", peak_of(played) > 0.01, "peak %f" % peak_of(played))
	check("counter during note", pb.get_mixed_frames() == expected, "%d vs %d" % [pb.get_mixed_frames(), expected])
	check("voice active", pb.get_active_voice_count() == 1, str(pb.get_active_voice_count()))

	# Note ends (release 0.05 s = 2205 frames), voices drain, then silence again.
	pb.queue_note_off(ctx)
	pb.render_offline(4410)
	expected += 4410
	check("voice finished", pb.get_active_voice_count() == 0, str(pb.get_active_voice_count()))
	var tail := pb.render_offline(1024)
	expected += 1024
	check("silent after note", peak_of(tail) == 0.0, "peak %f" % peak_of(tail))
	check("counter after note ends", pb.get_mixed_frames() == expected, "%d vs %d" % [pb.get_mixed_frames(), expected])
	pb.render_offline(8192)
	expected += 8192
	check("counter keeps advancing when silent", pb.get_mixed_frames() == expected, "%d vs %d" % [pb.get_mixed_frames(), expected])

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
