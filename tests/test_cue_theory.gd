extends SceneTree
# CueTheory: note names, scale parsing, degree lookup and the scale table.
# Run: Godot --headless --path project -s ../tests/test_cue_theory.gd

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func array_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

func check_midi(name: String, expected: int) -> void:
	var actual := CueTheory.note_to_midi(name)
	check("note '" + name + "'", actual == expected, "expected %d, got %d" % [expected, actual])

func _initialize() -> void:
	var valid_notes := {
		"c4": 60,
		"C4": 60,
		"a4": 69,
		"c": 48,
		"a": 57,
		"eb3": 51,
		"Eb3": 51,
		"f#5": 78,
		"fs5": 78,
		"c##4": 62,
		"cbb4": 58,
		"bb3": 58,
		"b3": 59,
		"cb4": 59,
		"c#": 49,
		"c-1": 0,
		"g9": 127,
		"c0": 12,
	}
	for name in valid_notes:
		check_midi(name, valid_notes[name])

	var invalid_notes := ["", "h4", "4", "c4x", "c#x", "cc4", "c--1", "c10", "c-2", " c4", "c 4"]
	for name in invalid_notes:
		check_midi(name, -1)

	var expected_scales := {
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
	check("SCALES has 13 keys", CueTheory.SCALES.size() == expected_scales.size(), str(CueTheory.SCALES.size()))
	for mode in expected_scales:
		var present := CueTheory.SCALES.has(mode)
		check("SCALES has '" + mode + "'", present, str(present))
		if present:
			check("SCALES '" + mode + "'", array_eq(CueTheory.SCALES[mode], expected_scales[mode]), str(CueTheory.SCALES[mode]))
	check("SCALES 'blues' size", CueTheory.SCALES["blues"].size() == 6, str(CueTheory.SCALES["blues"].size()))
	check("SCALES 'chromatic' size", CueTheory.SCALES["chromatic"].size() == 12, str(CueTheory.SCALES["chromatic"].size()))

	var c_major := CueTheory.parse_scale("C:major")
	check("parse C:major ok", c_major.ok, str(c_major.error))
	check("parse C:major root", c_major.root_midi == 48, str(c_major.root_midi))
	check("parse C:major steps", array_eq(c_major.steps, expected_scales["major"]), str(c_major.steps))
	var d_minor := CueTheory.parse_scale("D:minor")
	check("parse D:minor ok", d_minor.ok, str(d_minor.error))
	check("parse D:minor root", d_minor.root_midi == 50, str(d_minor.root_midi))
	var d4_minor := CueTheory.parse_scale("D4:minor")
	check("parse D4:minor ok", d4_minor.ok, str(d4_minor.error))
	check("parse D4:minor root", d4_minor.root_midi == 62, str(d4_minor.root_midi))
	var f_sharp_dorian := CueTheory.parse_scale("F#2:dorian")
	check("parse F#2:dorian ok", f_sharp_dorian.ok, str(f_sharp_dorian.error))
	check("parse F#2:dorian root", f_sharp_dorian.root_midi == 42, str(f_sharp_dorian.root_midi))
	var bb_harmonic := CueTheory.parse_scale("Bb:harmonicMinor")
	check("parse Bb:harmonicMinor ok", bb_harmonic.ok, str(bb_harmonic.error))
	check("parse Bb:harmonicMinor root", bb_harmonic.root_midi == 58, str(bb_harmonic.root_midi))

	var bad_scales := ["", "C", "C:", ":minor", "C:foo", "C:Minor", "H:major", "C4:major:x"]
	for text in bad_scales:
		var parsed := CueTheory.parse_scale(text)
		check("parse '" + text + "' fails", not parsed.ok, str(parsed))
		check("parse '" + text + "' root", parsed.root_midi == -1, str(parsed.root_midi))
		check("parse '" + text + "' error", not str(parsed.error).is_empty(), str(parsed.error))

	var c_major_degrees := {
		0: 48,
		1: 50,
		6: 59,
		7: 60,
		8: 62,
		14: 72,
		-1: 47,
		-7: 36,
		-8: 35,
		-14: 24,
		-15: 23,
	}
	for degree in c_major_degrees:
		var actual := CueTheory.degree_to_midi(degree, c_major)
		check("C:major degree %d" % degree, actual == c_major_degrees[degree], "expected %d, got %d" % [c_major_degrees[degree], actual])

	var d4_minor_degrees := {0: 62, 2: 65, 7: 74, -1: 60}
	for degree in d4_minor_degrees:
		var actual := CueTheory.degree_to_midi(degree, d4_minor)
		check("D4:minor degree %d" % degree, actual == d4_minor_degrees[degree], "expected %d, got %d" % [d4_minor_degrees[degree], actual])

	var c_maj_pent := CueTheory.parse_scale("C:majPent")
	var maj_pent_degrees := {5: 60, 4: 57, -1: 45}
	for degree in maj_pent_degrees:
		var actual := CueTheory.degree_to_midi(degree, c_maj_pent)
		check("C:majPent degree %d" % degree, actual == maj_pent_degrees[degree], "expected %d, got %d" % [maj_pent_degrees[degree], actual])

	for mode in CueTheory.SCALES:
		var scale := CueTheory.parse_scale("C3:" + mode)
		check("monotonic scale '" + mode + "' parses", scale.ok, str(scale.error))
		if not scale.ok:
			continue
		var prev := CueTheory.degree_to_midi(-21, scale)
		var monotonic := true
		var bad_degree := -20
		for degree in range(-20, 21):
			var cur := CueTheory.degree_to_midi(degree, scale)
			if cur <= prev:
				monotonic = false
				bad_degree = degree
				break
			prev = cur
		check("C3:" + mode + " monotonic", monotonic, "breaks at degree %d" % bad_degree)

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
