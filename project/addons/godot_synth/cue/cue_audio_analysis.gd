class_name CueAudioAnalysis
extends RefCounted

## Measures a rendered stereo buffer with ITU-R BS.1770-4 loudness, sample peak,
## clipped samples and long silent stretches, for the whole file and per section.
## Pure data in, pure data out: no engine or node access, no randomness.

## Floor reported for loudness and peak when there is nothing to measure (digital silence,
## fewer samples than one 400 ms block, or every block gated out). Plain -120.0 is used instead of
## -INF so the value is JSON-safe; consumers treat <= -120.0 as "silent".
const LUFS_FLOOR: float = -120.0
const PEAK_FLOOR_DBFS: float = -120.0
const CLIP_THRESHOLD: float = 0.999       # |sample| >= this counts as clipped
const BLOCK_SEC: float = 0.4
const HOP_SEC: float = 0.1                # 75% overlap
const ABSOLUTE_GATE_LUFS: float = -70.0
const RELATIVE_GATE_LU: float = -10.0
const SILENCE_WINDOW_SEC: float = 0.05
const SILENCE_RMS_DBFS: float = -60.0
const SILENCE_MIN_SEC: float = 0.5

const LOG10: float = 2.302585092994046

## Pre-filter (high shelf) and RLB (high pass) coefficients for a sample rate.
## The 48 kHz values are the published BS.1770-4 values; other rates use the
## bilinear transform of the analog prototypes.
static func k_weighting_coefficients(sample_rate: int) -> Dictionary:
	if sample_rate <= 0:
		return {
			"pre": {"b": PackedFloat64Array([1.0, 0.0, 0.0]), "a": PackedFloat64Array([1.0, 0.0, 0.0])},
			"rlb": {"b": PackedFloat64Array([1.0, 0.0, 0.0]), "a": PackedFloat64Array([1.0, 0.0, 0.0])},
		}
	var fs := float(sample_rate)

	var g := 3.999843853973347
	var f0 := 1681.974450955533
	var q := 0.7071752369554196
	var k := tan(PI * f0 / fs)
	var vh := pow(10.0, g / 20.0)
	var vb := pow(vh, 0.4996667741545416)
	var a0 := 1.0 + k / q + k * k
	var pre_b := PackedFloat64Array()
	pre_b.resize(3)
	pre_b[0] = (vh + vb * k / q + k * k) / a0
	pre_b[1] = 2.0 * (k * k - vh) / a0
	pre_b[2] = (vh - vb * k / q + k * k) / a0
	var pre_a := PackedFloat64Array()
	pre_a.resize(3)
	pre_a[0] = 1.0
	pre_a[1] = 2.0 * (k * k - 1.0) / a0
	pre_a[2] = (1.0 - k / q + k * k) / a0

	f0 = 38.13547087602444
	q = 0.5003270373238773
	k = tan(PI * f0 / fs)
	a0 = 1.0 + k / q + k * k
	var rlb_b := PackedFloat64Array([1.0, -2.0, 1.0])
	var rlb_a := PackedFloat64Array()
	rlb_a.resize(3)
	rlb_a[0] = 1.0
	rlb_a[1] = 2.0 * (k * k - 1.0) / a0
	rlb_a[2] = (1.0 - k / q + k * k) / a0

	return {
		"pre": {"b": pre_b, "a": pre_a},
		"rlb": {"b": rlb_b, "a": rlb_a},
	}

## Runs pre-filter then RLB over one channel. Zero initial state. Returns a new array.
static func k_weight(samples: PackedFloat64Array, sample_rate: int) -> PackedFloat64Array:
	if samples.is_empty():
		return PackedFloat64Array()
	return _k_weight_channel(samples, k_weighting_coefficients(sample_rate))

## Whole-buffer analysis.
## sections: Array of Dictionaries with start_frame and end_frame (end exclusive) and optional state.
static func analyze(frames: PackedVector2Array, sample_rate: int, sections: Array) -> Dictionary:
	var n := frames.size()
	var result := {
		"sample_rate": sample_rate,
		"frame_count": n,
		"total": _empty_metrics(),
		"sections": [],
	}
	if sample_rate <= 0 or n == 0:
		result.frame_count = 0
		var clamp_n := n if sample_rate > 0 else 0
		for section in sections:
			result.sections.append(_empty_section(section, clamp_n))
		return result

	var left := PackedFloat64Array()
	var right := PackedFloat64Array()
	left.resize(n)
	right.resize(n)
	for i in n:
		var frame := frames[i]
		left[i] = frame.x
		right[i] = frame.y

	var coefficients := k_weighting_coefficients(sample_rate)
	var weighted_left := _k_weight_channel(left, coefficients)
	var weighted_right := _k_weight_channel(right, coefficients)

	# Prefix sums of squares of the K-weighted channels, size n + 1.
	var prefix_left := PackedFloat64Array()
	var prefix_right := PackedFloat64Array()
	prefix_left.resize(n + 1)
	prefix_right.resize(n + 1)
	var sum_left := 0.0
	var sum_right := 0.0
	for i in n:
		var l := weighted_left[i]
		var r := weighted_right[i]
		sum_left += l * l
		sum_right += r * r
		prefix_left[i + 1] = sum_left
		prefix_right[i + 1] = sum_right

	result.total = _analyze_range(frames, prefix_left, prefix_right, sample_rate, 0, n)
	for section in sections:
		var start_frame := clampi(int(section.get("start_frame", 0)), 0, n)
		var end_frame := clampi(int(section.get("end_frame", 0)), 0, n)
		var state := ""
		if section.has("state"):
			state = str(section["state"])
		var metrics := _analyze_range(frames, prefix_left, prefix_right, sample_rate, start_frame, end_frame)
		result.sections.append({
			"state": state,
			"start_frame": start_frame,
			"end_frame": end_frame,
			"lufs": metrics.lufs,
			"peak_dbfs": metrics.peak_dbfs,
			"clipped_samples": metrics.clipped_samples,
			"silent_stretches": metrics.silent_stretches,
		})
	return result

static func _k_weight_channel(samples: PackedFloat64Array, coefficients: Dictionary) -> PackedFloat64Array:
	var n := samples.size()
	var out := PackedFloat64Array()
	out.resize(n)
	var pre_b: PackedFloat64Array = coefficients.pre.b
	var pre_a: PackedFloat64Array = coefficients.pre.a
	var rlb_b: PackedFloat64Array = coefficients.rlb.b
	var rlb_a: PackedFloat64Array = coefficients.rlb.a
	var pb0 := pre_b[0]
	var pb1 := pre_b[1]
	var pb2 := pre_b[2]
	var pa1 := pre_a[1]
	var pa2 := pre_a[2]
	var rb0 := rlb_b[0]
	var rb1 := rlb_b[1]
	var rb2 := rlb_b[2]
	var ra1 := rlb_a[1]
	var ra2 := rlb_a[2]
	var pz1 := 0.0
	var pz2 := 0.0
	var rz1 := 0.0
	var rz2 := 0.0
	for i in n:
		var x := samples[i]
		var pre := pb0 * x + pz1
		pz1 = pb1 * x - pa1 * pre + pz2
		pz2 = pb2 * x - pa2 * pre
		var y := rb0 * pre + rz1
		rz1 = rb1 * pre - ra1 * y + rz2
		rz2 = rb2 * pre - ra2 * y
		out[i] = y
	return out

static func _analyze_range(frames: PackedVector2Array, prefix_left: PackedFloat64Array, prefix_right: PackedFloat64Array, sample_rate: int, start_frame: int, end_frame: int) -> Dictionary:
	var n := frames.size()
	var s := clampi(start_frame, 0, n)
	var e := clampi(end_frame, 0, n)
	if e <= s:
		return _empty_metrics()

	var peak := 0.0
	var clipped := 0
	for i in range(s, e):
		var frame := frames[i]
		var ax := absf(frame.x)
		var ay := absf(frame.y)
		if ax > peak:
			peak = ax
		if ay > peak:
			peak = ay
		if ax >= CLIP_THRESHOLD:
			clipped += 1
		if ay >= CLIP_THRESHOLD:
			clipped += 1

	var peak_dbfs := PEAK_FLOOR_DBFS
	if peak > 0.0:
		peak_dbfs = 20.0 * _log10(peak)

	return {
		"lufs": _integrated_loudness(prefix_left, prefix_right, sample_rate, s, e),
		"peak_dbfs": peak_dbfs,
		"clipped_samples": clipped,
		"silent_stretches": _silent_stretches(frames, sample_rate, s, e),
	}

static func _integrated_loudness(prefix_left: PackedFloat64Array, prefix_right: PackedFloat64Array, sample_rate: int, s: int, e: int) -> float:
	var block := roundi(BLOCK_SEC * float(sample_rate))
	var hop := roundi(HOP_SEC * float(sample_rate))
	if block <= 0 or hop <= 0:
		return LUFS_FLOOR

	# Blocks that pass the absolute gate, kept as their mean square energies.
	var gated := PackedFloat64Array()
	var start := s
	while start + block <= e:
		var z := ((prefix_left[start + block] - prefix_left[start]) + (prefix_right[start + block] - prefix_right[start])) / float(block)
		start += hop
		if z <= 0.0:
			continue
		var loudness := -0.691 + 10.0 * _log10(z)
		if loudness > ABSOLUTE_GATE_LUFS:
			gated.append(z)
	if gated.is_empty():
		return LUFS_FLOOR

	var mean := 0.0
	for z in gated:
		mean += z
	mean /= float(gated.size())
	var relative_gate := (-0.691 + 10.0 * _log10(mean)) + RELATIVE_GATE_LU

	var kept_sum := 0.0
	var kept_count := 0
	for z in gated:
		if -0.691 + 10.0 * _log10(z) > relative_gate:
			kept_sum += z
			kept_count += 1
	if kept_count == 0:
		return LUFS_FLOOR
	return -0.691 + 10.0 * _log10(kept_sum / float(kept_count))

static func _silent_stretches(frames: PackedVector2Array, sample_rate: int, s: int, e: int) -> Array:
	var window := roundi(SILENCE_WINDOW_SEC * float(sample_rate))
	var stretches: Array = []
	if window <= 0:
		return stretches
	var threshold := pow(10.0, SILENCE_RMS_DBFS / 20.0)
	var min_frames := roundi(SILENCE_MIN_SEC * float(sample_rate))
	var run_start := -1
	var run_windows := 0
	var window_start := s
	while window_start + window <= e:
		var sum := 0.0
		var window_end := window_start + window
		for i in range(window_start, window_end):
			var frame := frames[i]
			var mono := (frame.x + frame.y) * 0.5
			sum += mono * mono
		var rms := sqrt(sum / float(window))
		if rms < threshold:
			if run_start < 0:
				run_start = window_start
				run_windows = 0
			run_windows += 1
		elif run_start >= 0:
			_flush_stretch(stretches, run_start, run_windows, window, min_frames)
			run_start = -1
		window_start = window_end
	if run_start >= 0:
		_flush_stretch(stretches, run_start, run_windows, window, min_frames)
	return stretches

static func _flush_stretch(stretches: Array, run_start: int, run_windows: int, window: int, min_frames: int) -> void:
	var length := run_windows * window
	if length >= min_frames:
		stretches.append({
			"start_frame": run_start,
			"end_frame": run_start + length,
		})

static func _empty_metrics() -> Dictionary:
	return {
		"lufs": LUFS_FLOOR,
		"peak_dbfs": PEAK_FLOOR_DBFS,
		"clipped_samples": 0,
		"silent_stretches": [],
	}

static func _empty_section(section: Dictionary, clamp_n: int) -> Dictionary:
	var state := ""
	if section.has("state"):
		state = str(section["state"])
	return {
		"state": state,
		"start_frame": clampi(int(section.get("start_frame", 0)), 0, clamp_n),
		"end_frame": clampi(int(section.get("end_frame", 0)), 0, clamp_n),
		"lufs": LUFS_FLOOR,
		"peak_dbfs": PEAK_FLOOR_DBFS,
		"clipped_samples": 0,
		"silent_stretches": [],
	}

static func _log10(value: float) -> float:
	return log(value) / LOG10
