extends SceneTree
# CueOfflineSink renders at the expected frames and applies gain ramps; CueLiveSink reaches real players.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_sinks.gd

const OfflineSinkScript = preload("res://addons/godot_synth/cue/cue_offline_sink.gd")
const LiveSinkScript = preload("res://addons/godot_synth/cue/cue_live_sink.gd")

const SR := 44100
const READY := 0
const ACTIVE := 1

var failures: Array[String] = []
var step := 0
var wall := 0.0
var live_sink = null
var player_a: AudioSynthPlayer
var player_b: AudioSynthPlayer
var on_f := 0
var off_f := 0
var rate := 0
var seen_before := false
var seen_active := false

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

func first_above(a: PackedVector2Array, from: int = 0, thr: float = 1.0e-5) -> int:
	for i in range(from, a.size()):
		if absf(a[i].x) > thr or absf(a[i].y) > thr:
			return i
	return -1

func peak_in(a: PackedVector2Array, from: int, to: int) -> float:
	var p := 0.0
	for i in range(from, mini(to, a.size())):
		p = maxf(p, maxf(absf(a[i].x), absf(a[i].y)))
	return p

func finish() -> bool:
	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
	return true

func _initialize() -> void:
	# ---- Offline sink: two tracks in group "g", one in group "h". ----
	var mixer := SynthOfflineMixer.new()
	check("mixer init", mixer.init(SR), "")
	var sink = OfflineSinkScript.new(mixer)
	sink.register_track("g", "bass", mixer.add_track(make_config()))
	sink.register_track("g", "pad", mixer.add_track(make_config()))
	sink.register_track("h", "lead", mixer.add_track(make_config()))
	sink.origin_frame = 1000
	check("groups", sink.groups["g"] == [0, 1] and sink.groups["h"] == [2], str(sink.groups))

	sink.note("g/bass", 69.0, 1.0, 4410, 30000, {})            # on at 5410
	sink.note("h/lead", 69.4, 1.0, 20000, 40000, {})           # on at 21000, pitch rounds to 69
	sink.note("g/pad", 57.0, 1.0, 100, 200, {"no_such_control": 1.0})   # tolerated
	sink.note("x/none", 60.0, 1.0, 0, 100, {})                  # unknown track: warning, ignored
	sink.param("g/bass", "pulse_width", 0.3, 4500)
	sink.param("x/none", "pulse_width", 0.3, 0)                # ignored
	sink.gain_ramp("g", 0.0, 24000, 0)                          # step to 0 at 25000 for both g tracks
	sink.gain_ramp("nogroup", 0.0, 0, 0)                        # ignored
	var out := mixer.render(44100)

	var on := first_above(out)
	check("first sound at origin + on_frame", on >= 1100 and on < 1100 + 32, "first sample above threshold at %d" % on)
	# The pad note (frames 1100..1200) rings out through its 0.05 s release (about 2200 frames); the next sound is the bass at 5410.
	check("silent between the pad tail and the bass", peak_in(out, 4000, 5400) < 1.0e-5, "peak %f" % peak_in(out, 4000, 5400))
	var bass_on := first_above(out, 4000)
	check("bass starts at origin + 4410", bass_on >= 5410 and bass_on < 5410 + 32, "first sample above threshold after the pad tail at %d" % bass_on)
	check("bass is audible before the ramp", peak_in(out, 10000, 24000) > 0.05, "peak %f" % peak_in(out, 10000, 24000))
	# The lead (group h) starts at 21000 and keeps playing after the g group is cut at 25000.
	check("lead audible after the g gain step", peak_in(out, 26000, 40000) > 0.05, "peak %f" % peak_in(out, 26000, 40000))
	check("late events: none", mixer.get_late_event_count() == 0, str(mixer.get_late_event_count()))

	# Same sink, g only: after the step the group is exactly silent.
	var m2 := SynthOfflineMixer.new()
	m2.init(SR)
	var s2 = OfflineSinkScript.new(m2)
	s2.register_track("g", "bass", m2.add_track(make_config()))
	s2.note("g/bass", 69.0, 1.0, 0, 40000, {})
	s2.gain_ramp("g", 0.0, 10000, 0)
	var out2 := m2.render(30000)
	check("group gain step silences the group", peak_in(out2, 10000, 30000) == 0.0 and peak_in(out2, 2000, 10000) > 0.05, "peak after %f" % peak_in(out2, 10000, 30000))
	# A gain ramp through the sink: linear down over 4000 frames.
	var m3 := SynthOfflineMixer.new()
	m3.init(SR)
	var s3 = OfflineSinkScript.new(m3)
	s3.register_track("g", "bass", m3.add_track(make_config()))
	s3.note("g/bass", 69.0, 1.0, 0, 40000, {})
	s3.gain_ramp("g", 0.0, 10000, 4000)
	var out3 := m3.render(20000)
	check("sink ramp reaches zero at F+N", peak_in(out3, 14000, 20000) == 0.0, "")
	check("sink ramp: still audible midway", peak_in(out3, 11800, 12200) > 0.01, "peak %f" % peak_in(out3, 11800, 12200))

	# A null mixer is harmless.
	var empty = OfflineSinkScript.new()
	empty.note("g/bass", 60.0, 1.0, 0, 100, {})
	check("null mixer ignored", true, "")

	# ---- Live sink: two real players in the tree, driven from _process. ----
	player_a = AudioSynthPlayer.new()
	player_a.configuration = make_config()
	root.add_child(player_a)
	player_b = AudioSynthPlayer.new()
	player_b.configuration = make_config()
	root.add_child(player_b)
	live_sink = LiveSinkScript.new()
	live_sink.register_player("g", "bass", player_a)
	live_sink.register_player("g", "pad", player_b)
	check("live groups", live_sink.groups["g"].size() == 2 and live_sink.tracks.size() == 2, "")

func _process(delta: float) -> bool:
	wall += delta
	if wall > 15.0:
		check("test finished in time", false, "timeout in step %d" % step)
		return finish()
	match step:
		0:
			if player_a.get_mixed_frames() > 0 and player_b.get_mixed_frames() > 0:
				AudioServer.lock()
				player_a.restart_stream()
				player_b.restart_stream()
				AudioServer.unlock()
				wall = 0.0
				step = 1
		1:
			if wall > 0.3:
				rate = int(AudioServer.get_mix_rate())
				live_sink.origin_frame = player_a.get_mixed_frames() + int(0.3 * rate)
				on_f = 0
				off_f = int(0.3 * rate)
				live_sink.note("g/bass", 69.4, 1.0, on_f, off_f, {"pulse_width": 0.3})
				live_sink.note("g/pad", 57.0, 1.0, on_f, off_f, {"no_such_control": 1.0})
				live_sink.note("x/none", 60.0, 1.0, 0, 100, {})        # unknown track: warning only
				live_sink.param("g/bass", "pulse_width", 0.4, on_f + 100)
				live_sink.gain_ramp("g", 0.5, off_f + 4000, 2000)     # reaches real players; must not error
				live_sink.gain_ramp("nogroup", 0.5, 0, 0)
				check("last_contexts has the played tracks", live_sink.last_contexts.has("g/bass") and live_sink.last_contexts.has("g/pad") and not live_sink.last_contexts.has("x/none"), str(live_sink.last_contexts.keys()))
				step = 2
		2:
			var ctx: SynthNoteContext = live_sink.last_contexts["g/bass"]
			var m := player_a.get_mixed_frames()
			var start: int = live_sink.origin_frame + on_f
			var stop: int = live_sink.origin_frame + off_f
			if m < start - 2048 and not ctx.is_note_on():
				seen_before = true
			if m > start + 4096 and m < stop - 2048 and ctx.get_note_state() == ACTIVE:
				seen_active = true
			if m > stop + 4096:
				check("not active before origin + on_frame", seen_before, "")
				check("active between on and off", seen_active, "")
				check("released after off_frame", not ctx.is_note_on(), "state %d" % ctx.get_note_state())
				return finish()
	return false
