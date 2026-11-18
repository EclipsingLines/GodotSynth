class_name CueGenFilter
extends RefCounted
## Quality gate of the cue dataset generator: extracts a cue from a teacher response, checks it
## against the real catalog, renders it with the default scenario and rejects broken, clipping,
## silent, empty, off-density or duplicate cues.

const CheckerScript = preload("res://addons/godot_synth/cue/cue_checker.gd")
const RendererScript = preload("res://addons/godot_synth/cue/cue_renderer.gd")
const AudioAnalysisScript = preload("res://addons/godot_synth/cue/cue_audio_analysis.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")

const REASONS: Array[String] = ["syntax", "validation", "render_failed", "clipping", "silence",
	"no_onsets", "density_low", "density_high", "duplicate"]

var density_min: float = 1.0          ## onsets per cycle, overall; below -> density_low
var density_max: float = 32.0         ## above -> density_high
var silence_max_fraction: float = 0.5 ## silent fraction above this -> silence
var scenario: Dictionary = {"duration_cycles": 8}
var catalog: CueCatalog               ## real catalog, CueCatalog.load_default()
var seen: Dictionary = {}             ## sha256 hex of normalised cue -> true


## Config keys (all optional): density_min, density_max, silence_max_fraction (floats), scenario (Dictionary).
func _init(config: Dictionary = {}) -> void:
	if config.has("density_min"):
		density_min = float(config["density_min"])
	if config.has("density_max"):
		density_max = float(config["density_max"])
	if config.has("silence_max_fraction"):
		silence_max_fraction = float(config["silence_max_fraction"])
	if config.get("scenario") is Dictionary:
		scenario = config["scenario"]
	catalog = CatalogScript.load_default()


## Pure. Takes the teacher's text and returns the cue source. If the text contains a ``` fence, return the
## content of the FIRST fenced block (the opening fence line, with an optional language tag such as
## "cue" or "gdscript", is dropped; the block ends at the next line that is exactly ``` after strip_edges, or at
## the end of the text if never closed). Otherwise use the whole text. Then normalise line endings to "\n"
## (drop "\r"), strip leading and trailing whitespace, and return it plus exactly one trailing "\n".
## An empty result stays "" (no newline added).
static func extract_cue(text: String) -> String:
	var normalized := text.replace("\r", "")
	var lines: PackedStringArray = normalized.split("\n")
	var opening := -1
	for i: int in range(lines.size()):
		if lines[i].contains("```"):
			opening = i
			break
	var body := normalized
	if opening >= 0:
		var content := PackedStringArray()
		for i: int in range(opening + 1, lines.size()):
			if lines[i].strip_edges() == "```":
				break
			content.append(lines[i])
		body = "\n".join(content)
	var stripped := body.strip_edges()
	if stripped.is_empty():
		return ""
	return stripped + "\n"


## Pure. Normal form used for duplicate detection: per line drop everything from the first "//" (cues have no
## string with "//" in it: the lexer forbids it outside comments; a "//" inside a double-quoted string is not
## treated specially in v1), collapse every run of whitespace (space, tab) to one space, strip the ends, then
## drop empty lines; join the remaining lines with "\n" (no trailing newline).
static func normalize(cue: String) -> String:
	var lines: PackedStringArray = cue.replace("\r", "").split("\n")
	var kept := PackedStringArray()
	for line: String in lines:
		var comment := line.find("//")
		if comment >= 0:
			line = line.substr(0, comment)
		var collapsed := ""
		var in_space := false
		for i: int in range(line.length()):
			var ch := line[i]
			if ch == " " or ch == "\t":
				in_space = true
			else:
				if in_space and not collapsed.is_empty():
					collapsed += " "
				in_space = false
				collapsed += ch
		var stripped := collapsed.strip_edges()
		if not stripped.is_empty():
			kept.append(stripped)
	return "\n".join(kept)


## Pure. Lower-case hex SHA-256 of the UTF-8 bytes of normalize(cue), using HashingContext
## (HashingContext.HASH_SHA256: start, update, finish, then hex via PackedByteArray.hex_encode()).
static func cue_hash(cue: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(normalize(cue).to_utf8_buffer())
	return context.finish().hex_encode()


## Pure. Reasons derived from a metrics Dictionary and the bounds (order: clipping, silence, no_onsets,
## then density_low / density_high). metrics keys: clipped_samples (int), silent_fraction (float),
## onsets (int), cycles (float), density (float, onsets per cycle). Rules: clipped_samples > 0 -> clipping;
## silent_fraction > silence_max_fraction -> silence; onsets == 0 -> no_onsets (and then NO density reason);
## else density < density_min -> density_low, density > density_max -> density_high.
static func reasons_from_metrics(metrics: Dictionary, density_min: float, density_max: float, silence_max_fraction: float) -> Array[String]:
	var reasons: Array[String] = []
	if int(metrics.get("clipped_samples", 0)) > 0:
		reasons.append("clipping")
	if float(metrics.get("silent_fraction", 0.0)) > silence_max_fraction:
		reasons.append("silence")
	var onsets := int(metrics.get("onsets", 0))
	if onsets == 0:
		reasons.append("no_onsets")
		return reasons
	var density := float(metrics.get("density", 0.0))
	if density < density_min:
		reasons.append("density_low")
	elif density > density_max:
		reasons.append("density_high")
	return reasons


## Runs the pipeline on a cue source (already extracted). Returns {ok: bool, reasons: Array[String], metrics: Dictionary}.
## Short-circuit order, each step returns at once:
##  1. CueChecker.check_source(cue, "cue", catalog.validator_catalog()); if not ok: reasons = ["syntax"] when any
##     error diagnostic has code "E_SYNTAX", else ["validation"]; metrics = {}.
##  2. duplicate: cue_hash(cue) is in `seen` -> reasons = ["duplicate"], metrics = {}.
##  3. CueRenderer.render(cue, scenario, catalog); not ok or frames empty -> ["render_failed"], metrics = {}.
##  4. metrics = _metrics_from_render(...); reasons = reasons_from_metrics(...); ok = reasons.is_empty().
## check() never records the hash; a rejected cue does not block a later identical cue.
func check(cue: String) -> Dictionary:
	var checked: Dictionary = CheckerScript.check_source(cue, "cue", catalog.validator_catalog())
	if not bool(checked.get("ok", false)):
		for diagnostic: Dictionary in checked.get("diagnostics", []):
			if String(diagnostic.get("severity", "")) == "error" and String(diagnostic.get("code", "")) == "E_SYNTAX":
				return {"ok": false, "reasons": ["syntax"] as Array[String], "metrics": {}}
		return {"ok": false, "reasons": ["validation"] as Array[String], "metrics": {}}

	if seen.has(cue_hash(cue)):
		return {"ok": false, "reasons": ["duplicate"] as Array[String], "metrics": {}}

	var rendered: Dictionary = RendererScript.render(cue, scenario, catalog)
	var frames: PackedVector2Array = rendered.get("frames", PackedVector2Array())
	if not bool(rendered.get("ok", false)) or frames.is_empty():
		return {"ok": false, "reasons": ["render_failed"] as Array[String], "metrics": {}}

	var metrics := _metrics_from_render(rendered, float(scenario.get("duration_cycles", 8.0)))
	var reasons := reasons_from_metrics(metrics, density_min, density_max, silence_max_fraction)
	return {"ok": reasons.is_empty(), "reasons": reasons, "metrics": metrics}


## Records the hash of an accepted cue so later identical (after normalisation) cues are "duplicate".
## Returns false when the hash was already present, else true.
func accept(cue: String) -> bool:
	var hash := cue_hash(cue)
	if seen.has(hash):
		return false
	seen[hash] = true
	return true


## Builds the metrics dictionary described above from a CueRenderer result; also adds
## peak_dbfs (float, overall), loudness_lufs (float or null when unavailable), frames (int), sample_rate (int).
func _metrics_from_render(render: Dictionary, duration_cycles: float) -> Dictionary:
	var frames: PackedVector2Array = render.get("frames", PackedVector2Array())
	var sample_rate := int(render.get("sample_rate", 0))
	var sections: Array = render.get("sections", [])
	var audio: Dictionary = AudioAnalysisScript.analyze(frames, sample_rate, sections)
	var total: Dictionary = audio.get("total", {})

	var onsets := 0
	for event: Variant in render.get("events", []):
		if event is Dictionary and String((event as Dictionary).get("type", "")) == "note":
			onsets += 1

	var silent_frames := 0
	for stretch: Dictionary in total.get("silent_stretches", []):
		silent_frames += int(stretch.get("end_frame", 0)) - int(stretch.get("start_frame", 0))
	var silent_fraction := 0.0
	if not frames.is_empty():
		silent_fraction = float(mini(silent_frames, frames.size())) / float(frames.size())

	var density := 0.0
	if duration_cycles > 0.0:
		density = float(onsets) / duration_cycles

	var loudness: Variant = null
	if sample_rate > 0 and not frames.is_empty():
		loudness = float(total.get("lufs", AudioAnalysisScript.LUFS_FLOOR))

	return {
		"clipped_samples": int(total.get("clipped_samples", 0)),
		"silent_fraction": silent_fraction,
		"onsets": onsets,
		"cycles": duration_cycles,
		"density": density,
		"peak_dbfs": float(total.get("peak_dbfs", AudioAnalysisScript.PEAK_FLOOR_DBFS)),
		"loudness_lufs": loudness,
		"frames": frames.size(),
		"sample_rate": sample_rate,
	}
