extends SceneTree
# AudioSynthPlayer scheduling: notes start and stop on the audio clock, and players restarted
# together under AudioServer.lock() share a frame counter.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_player_schedule.gd

const READY := 0
const ACTIVE := 1

var failures: Array[String] = []
var step := 0
var wall := 0.0
var player: AudioSynthPlayer
var player2: AudioSynthPlayer
var ctx: SynthNoteContext
var ctx2: SynthNoteContext
var on_frame := 0
var off_frame := 0
var seen_ready := false
var seen_active := false
var seen_off := false

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

func finish() -> bool:
	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
	return true

func _initialize() -> void:
	# A player with no configuration refuses to schedule.
	var bare := AudioSynthPlayer.new()
	check("no configuration -> null", bare.schedule_note(60, 1.0, 100, 200, {}) == null, "")
	bare.free()

	player = AudioSynthPlayer.new()
	player.configuration = make_sine_config()
	root.add_child(player)
	player2 = AudioSynthPlayer.new()
	player2.configuration = make_sine_config()
	root.add_child(player2)

func _process(delta: float) -> bool:
	wall += delta
	if wall > 15.0:
		check("test finished in time", false, "timeout in step %d" % step)
		return finish()
	match step:
		0:
			# Wait for the audio clock to start moving.
			if player.get_mixed_frames() > 0:
				var rate := int(AudioServer.get_mix_rate())
				on_frame = player.get_mixed_frames() + int(0.3 * rate)
				off_frame = on_frame + int(0.3 * rate)
				ctx = player.schedule_note(69, 1.0, on_frame, off_frame, {"pulse_width": 0.3})
				check("schedule_note returns a context", ctx != null, str(ctx))
				var bad := player.schedule_note(69, 1.0, 100, 50, {})
				check("off before on -> null", bad == null, str(bad))
				player.schedule_parameter("pulse_width", 0.4, on_frame + 100)
				# Unknown control names are skipped with a warning, not an error.
				var odd := player.schedule_note(60, 1.0, on_frame + 20000, -1, {"no_such_control": 1.0})
				check("unknown control tolerated", odd != null, str(odd))
				step = 1
		1:
			var state_before := ctx.get_note_state()
			var m_before := player.get_mixed_frames()
			var active := ctx.is_note_on()
			var m_after := player.get_mixed_frames()
			if m_after < on_frame - 2048 and state_before == READY and not active:
				seen_ready = true
			if m_before > on_frame + 4096 and m_after < off_frame - 2048 and ctx.get_note_state() == ACTIVE:
				seen_active = true
			if m_before > off_frame + 4096:
				seen_off = not ctx.is_note_on()
				check("not active before on_frame", seen_ready, "")
				check("active between on and off", seen_active, "")
				check("released after off_frame", seen_off, "state %d" % ctx.get_note_state())
				step = 2
		2:
			# Restart both players in one lock: their counters must then be equal.
			AudioServer.lock()
			player.restart_stream()
			player2.restart_stream()
			AudioServer.unlock()
			wall = 0.0
			step = 3
		3:
			if wall > 0.5:
				AudioServer.lock()
				var a := player.get_mixed_frames()
				var b := player2.get_mixed_frames()
				AudioServer.unlock()
				check("counters advance after restart", a > 0, str(a))
				check("counters equal after synchronized start", a == b, "%d vs %d" % [a, b])
				# Events reach the new playback.
				ctx2 = player.schedule_note(60, 1.0, a + 2205, -1, {})
				check("schedule after restart", ctx2 != null, str(ctx2))
				wall = 0.0
				step = 4
		4:
			if wall > 0.5:
				check("note plays on the new playback", ctx2.is_note_on(), "state %d" % ctx2.get_note_state())
				return finish()
	return false
