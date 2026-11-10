extends SceneTree
# CueAudioAnalysis: BS.1770 loudness, peak, clipping, silence, sections.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_audio_analysis.gd

const AnalysisScript = preload("res://addons/godot_synth/cue/cue_audio_analysis.gd")

var failures := 0
var checks := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS ", name)
	else:
		failures += 1
		print("FAIL ", name, ": ", detail)

# stereo 997 Hz sine, amplitude amp, left amplitude left_amp (use amp for both channels)
func sine_frames(sr: int, secs: float, amp: float, right_amp: float = -1.0) -> PackedVector2Array:
	if right_amp < 0.0:
		right_amp = amp
	var n := int(secs * float(sr))
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var s := sin(TAU * 997.0 * float(i) / float(sr))
		out[i] = Vector2(amp * s, right_amp * s)
	return out

func silence_frames(sr: int, secs: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(int(secs * float(sr)))
	return out

func near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

func arrays_near(a: PackedFloat64Array, b: Array, tol: float) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(a[i] - float(b[i])) > tol:
			return false
	return true

func _initialize() -> void:
	# 1. coefficients: published 48 kHz values and the 44.1 kHz re-derivation
	var c48: Dictionary = AnalysisScript.k_weighting_coefficients(48000)
	check("48k pre b", arrays_near(c48.pre.b, [1.53512485958697, -2.69169618940638, 1.19839281085285], 1e-9), str(c48.pre.b))
	check("48k pre a", arrays_near(c48.pre.a, [1.0, -1.69065929318241, 0.73248077421585], 1e-9), str(c48.pre.a))
	check("48k rlb b", arrays_near(c48.rlb.b, [1.0, -2.0, 1.0], 1e-12), str(c48.rlb.b))
	check("48k rlb a", arrays_near(c48.rlb.a, [1.0, -1.99004745483398, 0.99007225036621], 1e-9), str(c48.rlb.a))
	var c44: Dictionary = AnalysisScript.k_weighting_coefficients(44100)
	check("44.1k pre b", arrays_near(c44.pre.b, [1.5308412300503478, -2.6509799951547297, 1.169079079921587], 1e-9), str(c44.pre.b))
	check("44.1k pre a", arrays_near(c44.pre.a, [1.0, -1.6636551132560204, 0.7125954280732254], 1e-9), str(c44.pre.a))
	check("44.1k rlb a", arrays_near(c44.rlb.a, [1.0, -1.989169673629796, 0.9891990357870393], 1e-9), str(c44.rlb.a))

	# 2. loudness references. 997 Hz sine, amplitude 0.1 (-20 dBFS peak) in both channels = -20.0 LUFS;
	# in the left channel only = -23.0 LUFS (the BS.1770 / EBU reference level); amplitude 1.0 both = 0.0 LUFS.
	for sr in [44100, 48000]:
		var both: Dictionary = AnalysisScript.analyze(sine_frames(sr, 3.0, 0.1), sr, [])
		check("%d: -20 dBFS stereo sine = -20.0 LUFS" % sr, near(both.total.lufs, -20.0, 0.05), str(both.total.lufs))
		var left_only: Dictionary = AnalysisScript.analyze(sine_frames(sr, 3.0, 0.1, 0.0), sr, [])
		check("%d: -20 dBFS left-only sine = -23.0 LUFS" % sr, near(left_only.total.lufs, -23.01, 0.05), str(left_only.total.lufs))
		var full: Dictionary = AnalysisScript.analyze(sine_frames(sr, 3.0, 1.0), sr, [])
		check("%d: full-scale stereo sine = 0.0 LUFS" % sr, near(full.total.lufs, 0.0, 0.05), str(full.total.lufs))
		check("%d: peak of the 0.1 sine is -20 dBFS" % sr, near(both.total.peak_dbfs, -20.0, 0.05), str(both.total.peak_dbfs))
		check("%d: result echoes rate and frame count" % sr, both.sample_rate == sr and both.frame_count == 3 * sr, str(both.frame_count))

	# 3. sections + gating: 4 s at 0.1, then 4 s at 0.01 (44.1 kHz)
	var sr3 := 44100
	var two_levels := sine_frames(sr3, 4.0, 0.1)
	two_levels.append_array(sine_frames(sr3, 4.0, 0.01))
	var secs: Array = [
		{"state": "loud", "start_frame": 0, "end_frame": 4 * sr3},
		{"state": "quiet", "start_frame": 4 * sr3, "end_frame": 8 * sr3},
	]
	var r3: Dictionary = AnalysisScript.analyze(two_levels, sr3, secs)
	check("two sections returned", r3.sections.size() == 2, str(r3.sections.size()))
	check("section 0 loudness", near(r3.sections[0].lufs, -20.0, 0.05), str(r3.sections[0].lufs))
	check("section 1 loudness", near(r3.sections[1].lufs, -40.0, 0.05), str(r3.sections[1].lufs))
	check("sections differ by 20 LU", near(r3.sections[0].lufs - r3.sections[1].lufs, 20.0, 0.05))
	check("section echoes state and frames", r3.sections[1].state == "quiet" and r3.sections[1].start_frame == 4 * sr3 and r3.sections[1].end_frame == 8 * sr3)
	check("section peaks", near(r3.sections[0].peak_dbfs, -20.0, 0.05) and near(r3.sections[1].peak_dbfs, -40.0, 0.05), "%f %f" % [r3.sections[0].peak_dbfs, r3.sections[1].peak_dbfs])
	# the relative gate drops the quiet blocks (and blocks straddling the change count partly): -20.16
	check("whole-file loudness is gated", near(r3.total.lufs, -20.16, 0.05), str(r3.total.lufs))
	var clamped: Dictionary = AnalysisScript.analyze(two_levels, sr3, [{"start_frame": -100, "end_frame": 99999999}])
	check("section range is clamped", clamped.sections[0].start_frame == 0 and clamped.sections[0].end_frame == two_levels.size(), str(clamped.sections[0]))

	# 4. clipping: 100 samples forced to full scale in a -20 dBFS signal
	var clip := sine_frames(sr3, 2.0, 0.1)
	for i in 100:
		clip[1000 + i] = Vector2(1.0, 0.0)
	var r4: Dictionary = AnalysisScript.analyze(clip, sr3, [])
	check("clipped sample count", r4.total.clipped_samples == 100, str(r4.total.clipped_samples))
	check("peak is 0 dBFS after clipping", near(r4.total.peak_dbfs, 0.0, 0.001), str(r4.total.peak_dbfs))
	check("no clipping in a clean signal", AnalysisScript.analyze(sine_frames(sr3, 1.0, 0.5), sr3, []).total.clipped_samples == 0)
	var both_ch := sine_frames(sr3, 1.0, 0.1)
	both_ch[10] = Vector2(-1.0, 1.0)
	check("left and right clips count separately", AnalysisScript.analyze(both_ch, sr3, []).total.clipped_samples == 2)

	# 5. silence: 3 s zeros, 1 s tone, 2 s zeros (44.1 kHz; windows are 2205 frames, 3 s = 60 windows)
	var sandwich := silence_frames(sr3, 3.0)
	sandwich.append_array(sine_frames(sr3, 1.0, 0.1))
	sandwich.append_array(silence_frames(sr3, 2.0))
	var r5: Dictionary = AnalysisScript.analyze(sandwich, sr3, [])
	var st: Array = r5.total.silent_stretches
	check("two silent stretches", st.size() == 2, str(st))
	if st.size() == 2:
		check("first stretch frames", st[0].start_frame == 0 and st[0].end_frame == 3 * sr3, str(st[0]))
		check("second stretch frames", st[1].start_frame == 4 * sr3 and st[1].end_frame == 6 * sr3, str(st[1]))
	check("gated loudness of the sandwich", near(r5.total.lufs, -21.14, 0.05), str(r5.total.lufs))
	# a 0.3 s gap is shorter than 0.5 s and is not reported
	var gap := sine_frames(sr3, 1.0, 0.1)
	gap.append_array(silence_frames(sr3, 0.3))
	gap.append_array(sine_frames(sr3, 1.0, 0.1))
	check("short gap not reported", AnalysisScript.analyze(gap, sr3, []).total.silent_stretches.is_empty())
	# -60 dBFS RMS threshold: amplitude 0.0013 (RMS 0.00092) is silent, 0.0016 (RMS 0.00113) is not
	check("quiet tone below -60 dBFS RMS counts as silent", AnalysisScript.analyze(sine_frames(sr3, 3.0, 0.0013), sr3, []).total.silent_stretches.size() == 1)
	check("tone above -60 dBFS RMS is not silent", AnalysisScript.analyze(sine_frames(sr3, 3.0, 0.0016), sr3, []).total.silent_stretches.is_empty())
	# silent stretches are reported per section in absolute frames
	var r5s: Dictionary = AnalysisScript.analyze(sandwich, sr3, [{"state": "tail", "start_frame": 4 * sr3, "end_frame": 6 * sr3}])
	check("section silent stretch is absolute", r5s.sections[0].silent_stretches.size() == 1 and r5s.sections[0].silent_stretches[0].start_frame == 4 * sr3 and r5s.sections[0].silent_stretches[0].end_frame == 6 * sr3, str(r5s.sections[0].silent_stretches))

	# 6. nothing to measure
	var empty: Dictionary = AnalysisScript.analyze(PackedVector2Array(), 44100, [])
	check("empty buffer gives floors", empty.total.lufs == -120.0 and empty.total.peak_dbfs == -120.0 and empty.total.clipped_samples == 0 and empty.total.silent_stretches.is_empty() and empty.frame_count == 0, str(empty))
	var all_silent: Dictionary = AnalysisScript.analyze(silence_frames(44100, 2.0), 44100, [])
	check("digital silence: lufs -120, peak -120, one stretch", all_silent.total.lufs == -120.0 and all_silent.total.peak_dbfs == -120.0 and all_silent.total.silent_stretches.size() == 1, str(all_silent.total))
	var too_short: Dictionary = AnalysisScript.analyze(sine_frames(44100, 0.3, 0.1), 44100, [])
	check("shorter than one block gives the lufs floor", too_short.total.lufs == -120.0, str(too_short.total.lufs))
	check("results are JSON-safe", JSON.stringify(r3).length() > 0 and not JSON.stringify(all_silent).contains("inf") and not JSON.stringify(all_silent).contains("nan"))

	if failures == 0:
		print("PASS all ", checks, " checks")
		quit(0)
	else:
		print("FAIL ", failures, " of ", checks)
		quit(1)
