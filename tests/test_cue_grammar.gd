extends SceneTree
# Conformance test for the cue language grammar: runs cue.gbnf through the
# GBNF recognizer over the valid/invalid corpus and checks the catalog.
# Run: bash tests/verify.sh --no-build tests/test_cue_grammar.gd
# Exits with code 0 when every check passes, 1 otherwise.

const GbnfScript = preload("res://addons/godot_synth/cue/cue_gbnf.gd")
const GrammarPath := "res://addons/godot_synth/cue/cue.gbnf"

var failures: Array[String] = []


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS " + name)
	else:
		print("FAIL " + name + ": " + detail)
		failures.append(name)


func _corpus_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../tests/cue_corpus")


func _files(sub: String) -> Array[String]:
	var names: Array[String] = []
	for name in DirAccess.get_files_at(_corpus_dir().path_join(sub)):
		if name.ends_with(".cue"):
			names.append(name)
	names.sort()
	return names


func _read(path: String) -> String:
	var text := FileAccess.get_file_as_string(path).replace("\r", "")
	if text != "" and not text.ends_with("\n"):
		text += "\n"
	return text


func _line_col(text: String, pos: int) -> Vector2i:
	var line := 1
	var last_nl := -1
	for i in range(pos):
		if text.unicode_at(i) == 10:
			line += 1
			last_nl = i
	var col := pos - (last_nl + 1) + 1
	return Vector2i(line, col)


func _expect(text: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("^// expect: (E_[A-Z_]+) (\\d+):(\\d+)\\n")
	var found := re.search(text)
	if found == null:
		return {}
	return {
		"code": found.get_string(1),
		"line": int(found.get_string(2)),
		"col": int(found.get_string(3)),
	}


func _initialize() -> void:
	var grammar = GbnfScript.load_grammar(FileAccess.get_file_as_string(GrammarPath))
	check("grammar loads", grammar.get_error() == "", grammar.get_error())

	var valid := _files("valid")
	var invalid := _files("invalid")
	check("valid corpus count", valid.size() == 12, "expected 12, got %d" % valid.size())
	check("invalid corpus count", invalid.size() == 28, "expected 28, got %d" % invalid.size())

	var syntax_count := 0
	var semantic_count := 0
	var missing_expect: Array[String] = []
	for name in invalid:
		var text := _read(_corpus_dir().path_join("invalid").path_join(name))
		var expected := _expect(text)
		if expected.is_empty():
			missing_expect.append(name)
		elif expected["code"] == "E_SYNTAX":
			syntax_count += 1
		else:
			semantic_count += 1
	check("invalid files have expect headers", missing_expect.is_empty(),
		"missing: " + ", ".join(missing_expect))
	check("syntax corpus count", syntax_count == 12, "expected 12, got %d" % syntax_count)
	check("semantic corpus count", semantic_count == 16, "expected 16, got %d" % semantic_count)

	for name in valid:
		var path := _corpus_dir().path_join("valid").path_join(name)
		var text := _read(path)
		var accepted: bool = grammar.accepts(text)
		var detail := ""
		if not accepted:
			var lc := _line_col(text, grammar.error_position())
			detail = "rejected at %d:%d error=%s" % [lc.x, lc.y, grammar.get_error()]
		check("valid " + name, accepted, detail)

	for name in invalid:
		var path := _corpus_dir().path_join("invalid").path_join(name)
		var text := _read(path)
		var expected := _expect(text)
		if expected.is_empty():
			continue
		if expected["code"] != "E_SYNTAX":
			continue
		var accepted: bool = grammar.accepts(text)
		var lc := _line_col(text, grammar.error_position())
		var ok: bool = not accepted and lc.x == expected["line"] and lc.y == expected["col"]
		check("syntax " + name, ok,
			"expected reject at %d:%d, got accepted=%s position=%d:%d error=%s" % [
				expected["line"], expected["col"], str(accepted), lc.x, lc.y, grammar.get_error()])

	for name in invalid:
		var path := _corpus_dir().path_join("invalid").path_join(name)
		var text := _read(path)
		var expected := _expect(text)
		if expected.is_empty() or expected["code"] == "E_SYNTAX":
			continue
		var accepted: bool = grammar.accepts(text)
		var lc := _line_col(text, grammar.error_position())
		check("semantic " + name, accepted,
			"expected accept, got reject at %d:%d error=%s" % [lc.x, lc.y, grammar.get_error()])

	var catalog_text := FileAccess.get_file_as_string(_corpus_dir().path_join("catalog.json"))
	var catalog = JSON.parse_string(catalog_text)
	var catalog_ok := catalog is Dictionary
	var catalog_detail := "catalog.json did not parse to a Dictionary"
	var expected_instruments: Array[String] = ["bass", "lead", "pad", "kick", "snare", "hat", "crash"]
	expected_instruments.sort()
	if catalog_ok:
		var keys: Array = (catalog as Dictionary).keys()
		var actual: Array[String] = []
		for key in keys:
			actual.append(str(key))
		actual.sort()
		catalog_ok = actual == expected_instruments
		catalog_detail = "keys were " + ", ".join(actual)
		if catalog_ok:
			for instrument in expected_instruments:
				var entry = (catalog as Dictionary)[instrument]
				if not (entry is Dictionary) or not ((entry as Dictionary)["controls"] is Array) \
						or ((entry as Dictionary)["controls"] as Array).size() != 12:
					catalog_ok = false
					catalog_detail = instrument + " does not have 12 controls"
					break
	check("catalog instruments and controls", catalog_ok, catalog_detail)

	check("start rule mini euclid", grammar.accepts("kick(3,8)", "mini"))
	check("start rule mini stacks", grammar.accepts("a b | c d, e", "mini"))
	check("start rule mini rejects dot", not grammar.accepts("a b . c", "mini"))
	check("start rule number decimal", grammar.accepts("12.5", "number"))
	check("start rule number rejects trailing dot", not grammar.accepts("1.", "number"))

	if failures.is_empty():
		print("PASS all cue grammar checks (12 valid, %d syntax, %d semantic)" % [syntax_count, semantic_count])
		quit(0)
	else:
		print("FAILURES: " + ", ".join(failures))
		quit(1)
