extends SceneTree
# Cue semantic validator: corpus conformance, inline error codes and positions.
# Run: bash tests/verify.sh --no-build tests/test_cue_validator.gd
# Exits with code 0 when every check passes, 1 otherwise.

const ParserScript = preload("res://addons/godot_synth/cue/cue_parser.gd")
const ValidatorScript = preload("res://addons/godot_synth/cue/cue_validator.gd")

var failures: Array[String] = []
var catalog_cache: Dictionary = {}


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


func _expect(text: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("^// expect: (E_[A-Z_]+) (\\d+):(\\d+)")
	var found := re.search(text)
	if found == null:
		return {}
	return {
		"code": found.get_string(1),
		"line": int(found.get_string(2)),
		"col": int(found.get_string(3)),
	}


func _catalog() -> Dictionary:
	if not catalog_cache.is_empty():
		return catalog_cache
	var path := _corpus_dir().path_join("catalog.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		check("catalog loads", false, path)
		return {}
	catalog_cache = parsed
	return catalog_cache


func _diags(source: String, label: String = "") -> Array[Dictionary]:
	var result := ParserScript.parse(source)
	if result.get("ok") != true:
		check("parses " + label, false, str(result))
		return []
	var ast: Dictionary = result["ast"]
	var diagnostics: Array[Dictionary] = ValidatorScript.validate(ast, _catalog())
	return diagnostics


func _find(diags: Array[Dictionary], code: String, line: int, col: int) -> Dictionary:
	for diagnostic: Dictionary in diags:
		if String(diagnostic.get("code", "")) == code \
				and int(diagnostic.get("line", 0)) == line \
				and int(diagnostic.get("col", 0)) == col:
			return diagnostic
	return {}


func _has(diags: Array[Dictionary], code: String, line: int, col: int) -> bool:
	return not _find(diags, code, line, col).is_empty()


func _initialize() -> void:
	var valid := _files("valid")
	var invalid := _files("invalid")

	# 1. Every valid corpus file produces no error (warnings are notes).
	for name in valid:
		var text := _read(_corpus_dir().path_join("valid").path_join(name))
		var result := ParserScript.parse(text)
		if result.get("ok") != true:
			check("valid parses " + name, false, str(result))
			continue
		var diagnostics: Array[Dictionary] = ValidatorScript.validate(result["ast"], _catalog())
		var errors: Array[String] = []
		for diagnostic: Dictionary in diagnostics:
			var line := "%s %d:%d %s" % [
				str(diagnostic.get("code", "")),
				int(diagnostic.get("line", 0)),
				int(diagnostic.get("col", 0)),
				str(diagnostic.get("message", "")),
			]
			if String(diagnostic.get("severity", "")) == "error":
				errors.append(line)
			else:
				print("NOTE " + name + ": " + line)
		check("valid " + name, errors.is_empty(), ", ".join(errors))

	# 2. Every semantic-invalid corpus file parses and yields its code and position.
	var semantic_count := 0
	for name in invalid:
		var text := _read(_corpus_dir().path_join("invalid").path_join(name))
		var expected := _expect(text)
		if expected.is_empty() or expected["code"] == "E_SYNTAX":
			continue
		semantic_count += 1
		var result := ParserScript.parse(text)
		if result.get("ok") != true:
			check("semantic parses " + name, false, str(result))
			continue
		check("semantic parses " + name, true)
		var diagnostics: Array[Dictionary] = ValidatorScript.validate(result["ast"], _catalog())
		var found := _find(diagnostics, expected["code"], expected["line"], expected["col"])
		var ok := not found.is_empty() and String(found.get("severity", "")) == "error"
		check("semantic " + name, ok, "expected %s %d:%d, got %s" % [
			expected["code"], expected["line"], expected["col"], str(diagnostics),
		])

	# 3. Diagnostics are sorted by line, then column, then code. The unused-let
	# warning is appended after the walk, so it arrives out of order on line 1.
	var sorted_source := "let unused = s(\"kick\")\nstate a:\n  foo\nbind kick.wobble <- nope\n"
	var sorted_diags := _diags(sorted_source, "sorted")
	var sorted_ok := sorted_diags.size() >= 4
	if sorted_ok:
		for i: int in range(1, sorted_diags.size()):
			var previous: Dictionary = sorted_diags[i - 1]
			var current: Dictionary = sorted_diags[i]
			var previous_line := int(previous.get("line", 0))
			var current_line := int(current.get("line", 0))
			var previous_col := int(previous.get("col", 0))
			var current_col := int(current.get("col", 0))
			if current_line < previous_line \
					or (current_line == previous_line and current_col < previous_col) \
					or (current_line == previous_line and current_col == previous_col \
						and String(current.get("code", "")) < String(previous.get("code", ""))):
				sorted_ok = false
				break
	check("sorted output", sorted_ok, str(sorted_diags))

	# 4. Inline cases pin each code at its exact position.
	var inline := [
		{"source": "state a:\n  s(3)\n", "code": "E_ARG_TYPE", "line": 2, "col": 5},
		{"source": "tempo 100\ntempo 120\nstate a:\n  s(\"kick\")\n",
			"code": "E_DUPLICATE", "line": 2, "col": 1},
		{"source": "let tempo = s(\"kick\")\nstate a:\n  s(\"snare\")\n",
			"code": "E_RESERVED", "line": 1, "col": 5},
		{"source": "state a:\n  foo\n", "code": "E_UNKNOWN_IDENT", "line": 2, "col": 3},
		{"source": "state a:\n  fast(2)\n", "code": "E_KIND", "line": 2, "col": 3},
		{"source": "let t = fast(2)\nstate a:\n  t\n",
			"code": "E_KIND", "line": 3, "col": 3},
		{"source": "state a:\n  s(\"kick\")\ntransition x -> a\n",
			"code": "E_UNKNOWN_STATE", "line": 3, "col": 12},
		{"source": "state a:\n  s(\"kick\")\nbind kick.gain <- nope\n",
			"code": "E_UNKNOWN_PARAM", "line": 3, "col": 19},
		{"source": "param x 1..0 = 0\nstate a:\n  s(\"kick\")\n",
			"code": "E_RANGE", "line": 1, "col": 7},
		{"source": "state a:\n  s(\"kick\").fast(2, 3)\n",
			"code": "E_ARITY", "line": 2, "col": 13},
		{"source": "state a:\n  s(\"kick\").every(2, fast)\n",
			"code": "E_ARITY", "line": 2, "col": 22},
		{"source": "state a:\n  s(\"kick\").stack(s(\"kick\"))\n",
			"code": "E_KIND", "line": 2, "col": 13},
		{"source": "state a:\n  s(\"kick@0\")\n",
			"code": "E_MINI", "line": 2, "col": 10},
		{"source": "", "code": "E_NO_STATE", "line": 1, "col": 1},
		{"source": "state a:\n  n(\"0 2\").s(\"lead\")\n",
			"code": "W_N_WITHOUT_SCALE", "line": 2, "col": 3, "severity": "warning"},
		{"source": "let x = s(\"kick\")\nstate a:\n  s(\"snare\")\n",
			"code": "W_UNUSED_LET", "line": 1, "col": 5, "severity": "warning"},
		{"source": "param p 0..1 = 0.5\nstate a:\n  note(\"c e\").lpf(800).s(\"lead\")\nbind lead.lpf <- p\n",
			"code": "E_BIND_CONFLICT", "line": 4, "col": 1},
		{"source": "let t = fast(2)\nstate a:\n  s(\"kick\").sine(t)\n",
			"code": "E_KIND", "line": 3, "col": 13},
	]
	for row: Dictionary in inline:
		var source := String(row["source"])
		var diagnostics := _diags(source, String(row["code"]))
		var found := _find(diagnostics, row["code"], int(row["line"]), int(row["col"]))
		var severity := String(row.get("severity", "error"))
		var ok := not found.is_empty() and String(found.get("severity", "")) == severity
		check("inline %s %d:%d" % [row["code"], int(row["line"]), int(row["col"])],
			ok, str(diagnostics))

	# Arguments of a chain-link error still count as let uses.
	var chain_args_diags := _diags(
		"let t = fast(2)\nstate a:\n  s(\"kick\").sine(t)\n", "chain args")
	check("chain link args counted", not _has(chain_args_diags, "W_UNUSED_LET", 1, 5),
		str(chain_args_diags))

	var clean_source := "let t = fast(2)\nstate a:\n  s(\"kick\").every(2, t)\n"
	var clean_diags := _diags(clean_source, "clean")
	check("inline clean", clean_diags.is_empty(), str(clean_diags))

	if failures.is_empty():
		print("PASS all cue validator checks (valid=%d, invalid=%d, inline=%d)" % [
			valid.size(), semantic_count, inline.size() + 2,
		])
		quit(0)
	else:
		print("FAILURES: " + ", ".join(failures))
		quit(1)
