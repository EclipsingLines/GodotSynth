extends SceneTree
# Frame-scheduled events: an event at frame F takes effect on exactly frame F, mid-block.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_transport_schedule.gd

const F := 3000 # not a multiple of the 512-frame mix chunk

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

func new_playback() -> SynthAudioStreamPlayback:
	var pb := SynthAudioStreamPlayback.new()
	pb.sample_rate = 44100.0
	return pb

func first_nonzero(a: PackedVector2Array, from: int = 0) -> int:
	for i in range(from, a.size()):
		if a[i].x != 0.0 or a[i].y != 0.0:
			return i
	return -1

func peak_in(a: PackedVector2Array, from: int, to: int) -> float:
	var p := 0.0
	for i in range(from, mini(to, a.size())):
		p = maxf(p, maxf(absf(a[i].x), absf(a[i].y)))
	return p

func rms_in(a: PackedVector2Array, from: int, to: int) -> float:
	var s := 0.0
	for i in range(from, to):
		s += a[i].x * a[i].x
	return sqrt(s / float(to - from))

func _initialize() -> void:
	var cfg := make_sine_config()

	# 1. A note scheduled at F is silent before F and starts within a few frames of F.
	var pb := new_playback()
	var ctx := pb.queue_note_at(cfg, 69.0, 1.0, F)
	check("queue_note_at returns a context", ctx != null, str(ctx))
	var out := pb.render_offline(8192)
	var onset := first_nonzero(out)
	check("silent before F", onset >= F, "first non-zero sample at %d (F = %d)" % [onset, F])
	check("onset within 32 frames of F", onset >= F and onset < F + 32, "first non-zero sample at %d" % onset)
	check("audible after F", peak_in(out, F, 8192) > 0.01, "peak %f" % peak_in(out, F, 8192))
	check("no late events", pb.get_late_event_count() == 0, str(pb.get_late_event_count()))

	# 2. The onset does not depend on how the host chops the blocks.
	for block in [100, 333, 1024, 5000]:
		var pb2 := new_playback()
		pb2.queue_note_at(cfg, 69.0, 1.0, F)
		var got := PackedVector2Array()
		while got.size() < 8192:
			got.append_array(pb2.render_offline(block))
		var o2 := first_nonzero(got)
		check("onset with block size %d" % block, o2 >= F and o2 < F + 32, "first non-zero sample at %d" % o2)

	# 3. Two notes at the same frame: both start (START_VOICE is applied before NOTE_ON for each).
	var single := new_playback()
	single.queue_note_at(cfg, 69.0, 1.0, F)
	var one := single.render_offline(8192)
	var chord := new_playback()
	chord.queue_note_at(cfg, 69.0, 1.0, F)
	chord.queue_note_at(cfg, 76.0, 1.0, F)
	var two := chord.render_offline(8192)
	check("same-frame notes both active", chord.get_active_voice_count() == 2, str(chord.get_active_voice_count()))
	var one_rms := rms_in(one, F + 1000, F + 4000)
	var two_rms := rms_in(two, F + 1000, F + 4000)
	check("same-frame notes sum", two_rms > one_rms * 1.2, "rms %f vs single %f" % [two_rms, one_rms])
	check("same-frame onset", first_nonzero(two) >= F and first_nonzero(two) < F + 32, str(first_nonzero(two)))

	# 4. Out-of-order pushes are sorted: the later-pushed earlier event still starts first.
	var ooo := new_playback()
	ooo.queue_note_at(cfg, 76.0, 1.0, 5000)
	ooo.queue_note_at(cfg, 69.0, 1.0, F)
	var seq := ooo.render_offline(8192)
	check("sorted by frame", first_nonzero(seq) >= F and first_nonzero(seq) < F + 32, str(first_nonzero(seq)))
	var before := rms_in(seq, 3600, 4800)
	var after := rms_in(seq, 5600, 6800)
	check("second note joins at 5000", after > before * 1.2, "rms %f then %f" % [before, after])

	# 5. A scheduled note-off ends the note on time.
	var off := new_playback()
	off.queue_note_at(cfg, 69.0, 1.0, 1000, 3000)
	var offo := off.render_offline(9000)
	check("sustains before off", peak_in(offo, 2000, 3000) > 0.05, "peak %f" % peak_in(offo, 2000, 3000))
	check("silent after release", peak_in(offo, 6500, 9000) < 0.0001, "peak %f" % peak_in(offo, 6500, 9000))
	check("voice gone", off.get_active_voice_count() == 0, str(off.get_active_voice_count()))

	# 6. Late events: a frame in the past applies at block start and is counted.
	var late := new_playback()
	late.render_offline(2048)
	check("no late events yet", late.get_late_event_count() == 0, str(late.get_late_event_count()))
	late.queue_note_at(cfg, 69.0, 1.0, 100) # START_VOICE and NOTE_ON are both late
	var lo := late.render_offline(512)
	check("late event audible at block start", first_nonzero(lo) >= 0 and first_nonzero(lo) < 32, str(first_nonzero(lo)))
	check("late events counted", late.get_late_event_count() == 2, str(late.get_late_event_count()))
	# Exactly at the block start (frame 2560) and frame -1 are on time.
	late.queue_note_at(cfg, 76.0, 1.0, 2560)
	late.render_offline(512)
	late.queue_note(cfg, 72.0, 1.0)
	late.render_offline(512)
	check("on-time events not counted", late.get_late_event_count() == 2, str(late.get_late_event_count()))

	# 7. A full pending array drops events and counts them as late; nothing crashes.
	var full := new_playback()
	for batch in 5:
		for i in 450:
			full.release_all(20000)
		full.render_offline(1) # drains the ring into the pending array
	check("pending array is capped", full.get_pending_event_count() == 2048, str(full.get_pending_event_count()))
	check("overflow counted as late", full.get_late_event_count() == 450 * 5 - 2048, str(full.get_late_event_count()))
	full.render_offline(30000)
	check("pending drained after their frame", full.get_pending_event_count() == 0, str(full.get_pending_event_count()))

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
