extends SceneTree
# Headless smoke test: piano scene plays, pitch is right, same-frame chords sum.
# Run: Godot --headless --audio-driver Dummy --path project -s <this file>

var capture: AudioEffectCapture
var t := 0.0
var step := 0
var samples := PackedFloat32Array()
var piano_player: Node
var synth: AudioSynthPlayer
var ctxs := []
var results := {}
var failures := []

func _initialize() -> void:
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	print("mix rate: ", AudioServer.get_mix_rate())
	var scene: PackedScene = load("res://addons/godot_synth/keyboard/piano_keyboard.tscn")
	var inst := scene.instantiate()
	root.add_child(inst)
	piano_player = inst.get_node("CenterContainer")

func drain() -> void:
	var n := capture.get_frames_available()
	if n > 0:
		var buf := capture.get_buffer(n)
		for v in buf:
			samples.append(v.x)

func stats(from_ratio := 0.3) -> Dictionary:
	var start := int(samples.size() * from_ratio)
	var peak := 0.0
	var sq := 0.0
	var crossings := 0
	var count := samples.size() - start
	for i in range(start, samples.size()):
		var s := samples[i]
		peak = max(peak, abs(s))
		sq += s * s
		if i > start and samples[i - 1] <= 0.0 and s > 0.0:
			crossings += 1
	var denom: float = float(maxi(count, 1))
	var rms: float = sqrt(sq / denom)
	var freq: float = float(crossings) * AudioServer.get_mix_rate() / denom
	return {"peak": peak, "rms": rms, "freq": freq, "n": count}

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

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func _process(delta: float) -> bool:
	t += delta
	drain()
	match step:
		0:
			if t > 0.3:
				samples.clear()
				piano_player.play_note(60, 1)
				step = 1; t = 0.0
		1:
			if t > 0.6:
				var st := stats()
				check("piano scene produces sound", st.peak > 0.01, str(st))
				piano_player.stop_note(1)
				step = 2; t = 0.0
		2:
			if t > 1.5:
				# Remove the piano scene; continue with a plain sine patch.
				root.get_child(root.get_child_count() - 1).queue_free()
				synth = AudioSynthPlayer.new()
				synth.configuration = make_sine_config()
				synth.polyphony = 8
				root.add_child(synth)
				step = 3; t = 0.0
		3:
			if t > 0.3:
				samples.clear()
				var c: SynthNoteContext = synth.get_context()
				c.note_on(69, 0.25)
				ctxs = [c]
				step = 4; t = 0.0
		4:
			if t > 0.6:
				var st := stats()
				results["single"] = st
				check("single A4 audible", st.peak > 0.01, str(st))
				check("single A4 pitch ~440 Hz", abs(st.freq - 440.0) < 6.0, "%.1f Hz" % st.freq)
				for c in ctxs:
					c.note_off(c.absolute_time)
				step = 5; t = 0.0
		5:
			if t > 0.5:
				samples.clear()
				ctxs = []
				for note in [69, 69, 69]:
					var c: SynthNoteContext = synth.get_context()
					c.note_on(note, 0.25)
					ctxs.append(c)
				step = 6; t = 0.0
		6:
			if t > 0.6:
				var st := stats()
				var ratio: float = st.rms / max(results["single"].rms, 0.000001)
				check("three same-frame notes all sound (issue 1)", ratio > 2.0, "rms ratio %.2f (expect ~3 for in-phase unison, >=1.7 otherwise)" % ratio)
				for c in ctxs:
					c.note_off(c.absolute_time)
				step = 7; t = 0.0
		7:
			if t > 0.5:
				samples.clear()
				ctxs = []
				for note in [69, 69, 69]:
					var c: SynthNoteContext = synth.get_context()
					synth.play_note_on_context(c, note, 0.25)
					ctxs.append(c)
				step = 8; t = 0.0
		8:
			if t > 0.6:
				var st := stats()
				var ratio: float = st.rms / max(results["single"].rms, 0.000001)
				check("three queued notes all sound", ratio > 2.0, "rms ratio %.2f" % ratio)
				for c in ctxs:
					synth.play_note_off_context(c)
				step = 9; t = 0.0
		9:
			if t > 0.6:
				samples.clear()
				step = 10; t = 0.0
		10:
			if t > 0.3:
				var st := stats(0.0)
				check("silence after release", st.peak < 0.001, str(st))
				print("RESULT: " + ("ALL PASS" if failures.is_empty() else "FAILURES: " + str(failures)))
				return true
	return false
