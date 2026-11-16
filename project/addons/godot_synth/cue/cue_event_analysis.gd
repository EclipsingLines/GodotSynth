class_name CueEventAnalysis
extends RefCounted
## Musical facts from the note events and conductor log of a rendered cue: a
## duration- and velocity-weighted pitch-class histogram, a Krumhansl-Kessler
## key estimate, onset density per section and instrument group, and the timing
## of every state transition.
## Pure data in, pure data out: no cue class or engine node access, no randomness.

const PITCH_CLASS_NAMES: PackedStringArray = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

## Krumhansl-Kessler probe-tone profiles, index 0 = the tonic.
const KK_MAJOR: PackedFloat64Array = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
const KK_MINOR: PackedFloat64Array = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

## Catalog roles whose notes are excluded from the pitch-class histogram (unpitched / drum parts).
const DRUM_ROLES: PackedStringArray = ["drum", "drums", "perc", "percussion", "kick", "snare", "hat"]

## {instrument: role} read from an instruments.json file ({"instruments": {name: {"role": String, ...}}}).
## A missing/unreadable/malformed file, or an instrument without a "role", contributes nothing; returns {} on failure.
static func roles_from_catalog_file(path: String) -> Dictionary:
	var roles: Dictionary = {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return roles
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return roles
	var instruments: Variant = parsed.get("instruments")
	if not instruments is Dictionary:
		return roles
	var catalog: Dictionary = instruments
	for name: String in catalog:
		var entry: Variant = catalog[name]
		if not entry is Dictionary:
			continue
		var instrument: Dictionary = entry
		if not instrument.has("role"):
			continue
		var raw_role: Variant = instrument["role"]
		if not raw_role is String or String(raw_role).is_empty():
			continue
		roles[name] = String(raw_role)
	return roles

## "<group>/<instrument>" -> group ("" if there is no slash); instrument is the part after the first slash.
static func group_of(track: String) -> String:
	var slash := track.find("/")
	if slash < 0:
		return ""
	return track.substr(0, slash)

static func instrument_of(track: String) -> String:
	var slash := track.find("/")
	if slash < 0:
		return track
	return track.substr(slash + 1)

## Pearson correlation of two 12-element arrays; 0.0 if either has zero variance.
static func pearson(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var n := mini(a.size(), b.size())
	if n == 0:
		return 0.0
	var mean_a := 0.0
	var mean_b := 0.0
	for i in n:
		mean_a += a[i]
		mean_b += b[i]
	mean_a /= float(n)
	mean_b /= float(n)
	var cov := 0.0
	var var_a := 0.0
	var var_b := 0.0
	for i in n:
		var da := a[i] - mean_a
		var db := b[i] - mean_b
		cov += da * db
		var_a += da * da
		var_b += db * db
	if var_a == 0.0 or var_b == 0.0:
		return 0.0
	return cov / sqrt(var_a * var_b)

## Weighted pitch-class histogram, normalized to sum 1.0 (all zeros if there is no pitched weight).
## Only events with type "note" count. Skip an event when roles.get(instrument_of(track), "") is in DRUM_ROLES
## (an instrument missing from roles counts as pitched). pc = posmod(roundi(note), 12).
## weight = (maxi(off_frame - on_frame, 1) / float(sample_rate)) * clampf(velocity, 0.0, 1.0)
## (a note with off_frame < on_frame, for example a held note, counts as 1 frame).
static func pitch_class_histogram(events: Array, roles: Dictionary, sample_rate: int) -> PackedFloat64Array:
	var hist := PackedFloat64Array()
	hist.resize(12)
	var rate := float(sample_rate) if sample_rate > 0 else 1.0
	for event: Variant in events:
		if not event is Dictionary:
			continue
		var note_event: Dictionary = event
		if String(note_event.get("type", "")) != "note":
			continue
		var track := String(note_event.get("track", ""))
		var role := String(roles.get(instrument_of(track), ""))
		if role in DRUM_ROLES:
			continue
		var on_frame := int(note_event.get("on_frame", 0))
		var off_frame := int(note_event.get("off_frame", on_frame))
		var frames := maxi(off_frame - on_frame, 1)
		var velocity := clampf(float(note_event.get("velocity", 1.0)), 0.0, 1.0)
		var weight := float(frames) / rate * velocity
		var pc := posmod(roundi(float(note_event.get("note", 0.0))), 12)
		hist[pc] += weight
	var total := 0.0
	for value in hist:
		total += value
	if total <= 0.0:
		return hist
	for i in 12:
		hist[i] /= total
	return hist

## Best key for a histogram: 24 candidates (tonic 0..11 x mode major, minor). For tonic t the profile value for
## pitch class pc is profile[posmod(pc - t, 12)]. Candidates are scored with pearson(hist, rotated_profile);
## iterate mode major first then minor, tonic 0 to 11, and replace the best only when strictly greater
## (ties keep the earlier candidate). Returns {tonic: String, mode: "major"|"minor", r: float}.
## An all-zero histogram returns {tonic: "", mode: "", r: 0.0}.
static func estimate_key(hist: PackedFloat64Array) -> Dictionary:
	var total := 0.0
	for value in hist:
		total += value
	if total == 0.0:
		return {"tonic": "", "mode": "", "r": 0.0}
	var best_tonic := 0
	var best_mode := "major"
	var best_r := -INF
	for mode: String in ["major", "minor"]:
		var profile: PackedFloat64Array = KK_MAJOR if mode == "major" else KK_MINOR
		for tonic in 12:
			var rotated := PackedFloat64Array()
			rotated.resize(12)
			for pc in 12:
				rotated[pc] = profile[posmod(pc - tonic, 12)]
			var r := pearson(hist, rotated)
			if r > best_r:
				best_r = r
				best_tonic = tonic
				best_mode = mode
	return {"tonic": PITCH_CLASS_NAMES[best_tonic], "mode": best_mode, "r": best_r}

## Onsets per cycle, per section and instrument group.
## Returns Array (one per input section, same order) of
## {state: String, start_cycle: float, end_cycle: float, groups: Dictionary, total: float}
## where groups maps instrument name -> onsets / (end_cycle - start_cycle) for every instrument that has >= 1
## onset in that section (keys inserted in sorted order), and total is the sum over groups. An onset is a "note"
## event with start_frame <= on_frame < end_frame (drums count; this is rhythm density, not pitch).
## A section with end_cycle <= start_cycle gets groups {} and total 0.0.
static func onset_density(events: Array, sections: Array) -> Array:
	var result: Array = []
	for section: Variant in sections:
		if not section is Dictionary:
			continue
		var info: Dictionary = section
		var start_cycle := float(info.get("start_cycle", 0.0))
		var end_cycle := float(info.get("end_cycle", 0.0))
		var start_frame := int(info.get("start_frame", 0))
		var end_frame := int(info.get("end_frame", 0))
		var counts: Dictionary = {}
		if end_cycle > start_cycle:
			for event: Variant in events:
				if not event is Dictionary:
					continue
				var note_event: Dictionary = event
				if String(note_event.get("type", "")) != "note":
					continue
				var on_frame := int(note_event.get("on_frame", 0))
				if on_frame < start_frame or on_frame >= end_frame:
					continue
				var instrument := instrument_of(String(note_event.get("track", "")))
				counts[instrument] = int(counts.get(instrument, 0)) + 1
		var length := end_cycle - start_cycle
		var groups: Dictionary = {}
		var total := 0.0
		if length > 0.0:
			var names: Array = counts.keys()
			names.sort()
			for name: String in names:
				var density := float(counts[name]) / length
				groups[name] = density
				total += density
		result.append({
			"state": String(info.get("state", "")),
			"start_cycle": start_cycle,
			"end_cycle": end_cycle,
			"groups": groups,
			"total": total,
		})
	return result

## Transition timings from the conductor log. Returns Array of
## {from: String, to: String, requested_cycle: float, quant: String, switch_cycle: float,
##  switch_frame: int, fade_end_cycle: float}, one per "switch" entry, in log order.
## Pairing: walk the log in order keeping `pending` = the most recent "request" entry (a later request replaces an
## earlier one: last request wins). On a "switch" entry: if pending exists and pending.get("to") == entry.get("to"),
## requested_cycle = float(pending.cycle) and quant = _quant_text(pending.get("quant")), else requested_cycle = the
## switch cycle and quant = "". Then pending = null. switch_cycle = float(entry.cycle);
## switch_frame = roundi(switch_cycle / cps * float(sample_rate)); fade_end_cycle = switch_cycle + float(entry.get("fade", 0.0));
## from/to = String(entry.get("from", "")) / String(entry.get("to", "")). Other log types are ignored.
static func transitions(log: Array, cps: float, sample_rate: int) -> Array:
	var result: Array = []
	var pending: Dictionary = {}
	for entry: Variant in log:
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry
		var kind := String(item.get("type", ""))
		if kind == "request":
			pending = item
			continue
		if kind != "switch":
			continue
		var switch_cycle := float(item.get("cycle", 0.0))
		var requested_cycle := switch_cycle
		var quant := ""
		if not pending.is_empty() and pending.get("to") == item.get("to"):
			requested_cycle = float(pending.get("cycle", switch_cycle))
			quant = _quant_text(pending.get("quant"))
		pending = {}
		var switch_frame := 0
		if cps > 0.0 and sample_rate > 0:
			switch_frame = roundi(switch_cycle / cps * float(sample_rate))
		result.append({
			"from": String(item.get("from", "")),
			"to": String(item.get("to", "")),
			"requested_cycle": requested_cycle,
			"quant": quant,
			"switch_cycle": switch_cycle,
			"switch_frame": switch_frame,
			"fade_end_cycle": switch_cycle + float(item.get("fade", 0.0)),
		})
	return result

## quant text: kind "now"/"beat"/"bar" -> the kind; "bars"/"beats" -> "<count> <kind>" (for example "2 bars");
## null or a non-Dictionary -> "".
static func _quant_text(q: Variant) -> String:
	if not q is Dictionary:
		return ""
	var quant: Dictionary = q
	var kind := String(quant.get("kind", ""))
	match kind:
		"now", "beat", "bar":
			return kind
		"beats", "bars":
			return str(int(quant.get("count", 1))) + " " + kind
	return ""

## Everything at once. Returns
## {key: {tonic, mode, r}, pitch_class_histogram: Array (12 floats), onset_density: Array, transitions: Array}.
static func analyze(events: Array, log: Array, sections: Array, roles: Dictionary, sample_rate: int, cps: float) -> Dictionary:
	var hist := pitch_class_histogram(events, roles, sample_rate)
	var plain_hist: Array = []
	for value in hist:
		plain_hist.append(value)
	return {
		"key": estimate_key(hist),
		"pitch_class_histogram": plain_hist,
		"onset_density": onset_density(events, sections),
		"transitions": transitions(log, cps, sample_rate),
	}
