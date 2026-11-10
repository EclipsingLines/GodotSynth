class_name CueTheory extends RefCounted
# Static helpers for the cue language: note names to MIDI numbers, the scale
# tables, and scale-degree lookup.

const SCALES: Dictionary = {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"lydian": [0, 2, 4, 6, 7, 9, 11],
	"mixolydian": [0, 2, 4, 5, 7, 9, 10],
	"locrian": [0, 1, 3, 5, 6, 8, 10],
	"harmonicMinor": [0, 2, 3, 5, 7, 8, 11],
	"melodicMinor": [0, 2, 3, 5, 7, 9, 11],
	"majPent": [0, 2, 4, 7, 9],
	"minPent": [0, 3, 5, 7, 10],
	"blues": [0, 3, 5, 6, 7, 10],
	"chromatic": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
}
const DEFAULT_OCTAVE: int = 3

const _PITCH_CLASSES: Dictionary = {
	"c": 0,
	"d": 2,
	"e": 4,
	"f": 5,
	"g": 7,
	"a": 9,
	"b": 11,
}

# Parse a note name such as "c4", "eb3", "f#5" or "bb3" into a MIDI number.
# Returns -1 when the name is invalid or the result is outside 0..127.
static func note_to_midi(name: String) -> int:
	if name.is_empty():
		return -1
	var letter := name.substr(0, 1).to_lower()
	if not _PITCH_CLASSES.has(letter):
		return -1
	var midi: int = _PITCH_CLASSES[letter]

	var i := 1
	while i < name.length():
		var ch := name.substr(i, 1)
		if ch == "#" or ch == "s" or ch == "S":
			midi += 1
		elif ch == "b":
			midi -= 1
		else:
			break
		i += 1

	var octave := DEFAULT_OCTAVE
	var rest := name.substr(i)
	if not rest.is_empty():
		var start := 0
		var negative := false
		if rest.substr(0, 1) == "-":
			negative = true
			start = 1
		if start >= rest.length():
			return -1
		var value := 0
		for j in range(start, rest.length()):
			var digit := rest.substr(j, 1)
			if digit < "0" or digit > "9":
				return -1
			value = value * 10 + (digit.unicode_at(0) - 48)
		octave = -value if negative else value

	midi += 12 * (octave + 1)
	if midi < 0 or midi > 127:
		return -1
	return midi

# Parse "root[octave]:mode", for example "D4:minor" or "Bb:harmonicMinor".
static func parse_scale(text: String) -> Dictionary:
	var colon := text.find(":")
	if colon < 0:
		return _scale_error("missing ':'")
	var root_text := text.substr(0, colon)
	var mode_text := text.substr(colon + 1)
	if root_text.is_empty():
		return _scale_error("missing root")
	if mode_text.is_empty():
		return _scale_error("missing mode")
	var root_midi := note_to_midi(root_text)
	if root_midi < 0:
		return _scale_error("invalid root '" + root_text + "'")
	if not SCALES.has(mode_text):
		return _scale_error("unknown scale '" + mode_text + "'")
	var steps: Array[int] = []
	steps.assign(SCALES[mode_text])
	return {"ok": true, "root_midi": root_midi, "steps": steps, "error": ""}

static func _scale_error(message: String) -> Dictionary:
	return {"ok": false, "root_midi": -1, "steps": [], "error": message}

# Map a scale degree to MIDI. Degrees wrap into octaves in both directions.
static func degree_to_midi(degree: int, scale: Dictionary) -> int:
	var n: int = scale.steps.size()
	if n == 0:
		return scale.root_midi
	var oct: int = degree / n
	if degree % n != 0 and degree < 0:
		oct -= 1
	var idx := posmod(degree, n)
	return scale.root_midi + 12 * oct + scale.steps[idx]
