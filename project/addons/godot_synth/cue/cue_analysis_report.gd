class_name CueAnalysisReport
extends RefCounted
## Combines the audio measurements (CueAudioAnalysis) and the musical-event measurements
## (CueEventAnalysis) of a rendered cue into one JSON-safe Dictionary, plus a short list of
## plain-English summary lines for a model or a human judging the cue without listening.
## Pure data in, pure data out: no cue class or engine node access, no randomness.

const VERSION: int = 1
const DEFAULT_CATALOG_PATH: String = "res://addons/godot_synth/cue/catalog/instruments.json"

const AudioAnalysisScript = preload("res://addons/godot_synth/cue/cue_audio_analysis.gd")
const EventAnalysisScript = preload("res://addons/godot_synth/cue/cue_event_analysis.gd")

## Builds the report Dictionary. render_result is a successful CueRenderer.render result,
## roles is {instrument: role} and cue_name is the cue path as given ("" when built from text).
## Section i merges the audio metrics of section i, the render's section i and the event
## onset density of section i. The "summary" key is filled in last by summary().
static func build(render_result: Dictionary, roles: Dictionary, cue_name: String) -> Dictionary:
	var sample_rate := int(render_result.get("sample_rate", 0))
	var frames: PackedVector2Array = render_result.get("frames", PackedVector2Array())
	var render_sections: Array = render_result.get("sections", [])
	var audio: Dictionary = AudioAnalysisScript.analyze(frames, sample_rate, render_sections)
	var events: Array = render_result.get("events", [])
	var log: Array = render_result.get("log", [])
	var cps := float(render_result.get("cps", 0.0))
	var musical: Dictionary = EventAnalysisScript.analyze(events, log, render_sections, roles, sample_rate, cps)
	var frame_count := frames.size()
	var seconds := 0.0
	if sample_rate > 0:
		seconds = float(frame_count) / float(sample_rate)

	var audio_sections: Array = audio.get("sections", [])
	var densities: Array = musical.get("onset_density", [])
	var sections: Array = []
	for i: int in range(render_sections.size()):
		var source: Dictionary = render_sections[i]
		var measured: Dictionary = audio_sections[i] if i < audio_sections.size() else {}
		var density: Dictionary = densities[i] if i < densities.size() else {}
		sections.append({
			"state": String(source.get("state", "")),
			"start_cycle": float(source.get("start_cycle", 0.0)),
			"end_cycle": float(source.get("end_cycle", 0.0)),
			"start_frame": int(source.get("start_frame", measured.get("start_frame", 0))),
			"end_frame": int(source.get("end_frame", measured.get("end_frame", 0))),
			"lufs": float(measured.get("lufs", AudioAnalysisScript.LUFS_FLOOR)),
			"peak_dbfs": float(measured.get("peak_dbfs", AudioAnalysisScript.PEAK_FLOOR_DBFS)),
			"clipped_samples": int(measured.get("clipped_samples", 0)),
			"silent_stretches": measured.get("silent_stretches", []),
			"onsets_per_cycle": density.get("groups", {}),
			"onsets_per_cycle_total": float(density.get("total", 0.0)),
		})

	var report := {
		"version": VERSION,
		"cue": cue_name,
		"sample_rate": sample_rate,
		"cps": cps,
		"duration_cycles": float(render_result.get("duration_cycles", 0.0)),
		"frames": frame_count,
		"seconds": seconds,
		"total": audio.get("total", {}),
		"sections": sections,
		"key": musical.get("key", {"tonic": "", "mode": "", "r": 0.0}),
		"pitch_class_histogram": musical.get("pitch_class_histogram", []),
		"transitions": musical.get("transitions", []),
	}
	report["summary"] = summary(report)
	return report

## The plain-English summary lines, in report order: one or two per section, the total,
## the key estimate, one per transition, then warnings. Works on a hand-built report; it
## reads only sample_rate, seconds, total, sections, key and transitions.
static func summary(report: Dictionary) -> Array:
	var lines: Array = []
	var sample_rate := float(report.get("sample_rate", 0))

	var sections: Array = report.get("sections", [])
	for section: Dictionary in sections:
		var state := String(section.get("state", ""))
		lines.append("section %s: %.1f LUFS, peak %.1f dBFS, %d clipped, %.1f onsets/cycle" % [
			state,
			float(section.get("lufs", AudioAnalysisScript.LUFS_FLOOR)),
			float(section.get("peak_dbfs", AudioAnalysisScript.PEAK_FLOOR_DBFS)),
			int(section.get("clipped_samples", 0)),
			float(section.get("onsets_per_cycle_total", 0.0)),
		])
		var stretches: Array = section.get("silent_stretches", [])
		if not stretches.is_empty():
			var longest := 0
			for stretch: Dictionary in stretches:
				longest = maxi(longest, int(stretch.get("end_frame", 0)) - int(stretch.get("start_frame", 0)))
			var longest_seconds := 0.0
			if sample_rate > 0.0:
				longest_seconds = float(longest) / sample_rate
			lines.append("section %s: %d silent stretch(es) of at least 0.5 s, longest %.1f s" % [
				state, stretches.size(), longest_seconds,
			])

	var total: Dictionary = report.get("total", {})
	lines.append("total: %.1f LUFS, peak %.1f dBFS, %d clipped samples, %d silent stretches, %.1f s" % [
		float(total.get("lufs", AudioAnalysisScript.LUFS_FLOOR)),
		float(total.get("peak_dbfs", AudioAnalysisScript.PEAK_FLOOR_DBFS)),
		int(total.get("clipped_samples", 0)),
		(total.get("silent_stretches", []) as Array).size(),
		float(report.get("seconds", 0.0)),
	])

	var key: Dictionary = report.get("key", {})
	var tonic := String(key.get("tonic", ""))
	if tonic.is_empty():
		lines.append("key estimate: none (no pitched notes)")
	else:
		lines.append("key estimate: %s %s (r=%.2f)" % [tonic, String(key.get("mode", "")), float(key.get("r", 0.0))])

	for transition: Dictionary in report.get("transitions", []):
		var quant := String(transition.get("quant", ""))
		lines.append("transition %s -> %s: requested at cycle %.2f, switch at cycle %.2f (%s), fade ends at cycle %.2f" % [
			String(transition.get("from", "")),
			String(transition.get("to", "")),
			float(transition.get("requested_cycle", 0.0)),
			float(transition.get("switch_cycle", 0.0)),
			quant if not quant.is_empty() else "no request",
			float(transition.get("fade_end_cycle", 0.0)),
		])

	var clipped := int(total.get("clipped_samples", 0))
	if clipped > 0:
		lines.append("warning: %d samples clipped" % clipped)
	for section: Dictionary in sections:
		if float(section.get("onsets_per_cycle_total", 0.0)) == 0.0:
			lines.append("warning: section %s has no note onsets" % String(section.get("state", "")))
	return lines
