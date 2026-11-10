extends SceneTree
# Cue file parser: corpus conformance, grammar agreement, AST shape and positions.
# Run: bash tests/verify.sh --no-build tests/test_cue_parser.gd
# Exits with code 0 when every check passes, 1 otherwise.

const ParserScript = preload("res://addons/godot_synth/cue/cue_parser.gd")
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


func _normalise(source: String) -> String:
	var text := source.replace("\r", "")
	if text != "" and not text.ends_with("\n"):
		text += "\n"
	return text


func _read(path: String) -> String:
	return _normalise(FileAccess.get_file_as_string(path))


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


func _walk_positions(node: Variant, path: String, bad: Array[String]) -> void:
	if node is Dictionary:
		var entry: Dictionary = node
		if entry.has("type"):
			var line: Variant = entry.get("line")
			var col: Variant = entry.get("col")
			if not (line is int) or not (col is int) or line < 1 or col < 1:
				bad.append("%s %s has line=%s col=%s" % [path, str(entry["type"]), str(line), str(col)])
		for key: Variant in entry.keys():
			if str(key) == "mini":
				continue
			_walk_positions(entry[key], path + "." + str(key), bad)
	elif node is Array:
		var items: Array = node
		for i in range(items.size()):
			_walk_positions(items[i], path + "[" + str(i) + "]", bad)


func _first_state(program: Dictionary) -> Dictionary:
	var items: Array = program.get("items", [])
	for item: Variant in items:
		if item is Dictionary and item.get("type") == "state":
			return item
	return {}


func _chain_names(node: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var current: Variant = node
	while current is Dictionary and (current as Dictionary).get("type") == "call":
		names.append(str((current as Dictionary)["name"]))
		current = (current as Dictionary)["receiver"]
	return names


func _initialize() -> void:
	var grammar = GbnfScript.load_grammar(FileAccess.get_file_as_string(GrammarPath))
	check("grammar loads", grammar.get_error() == "", grammar.get_error())

	var valid := _files("valid")
	var invalid := _files("invalid")

	# 1. Every valid file parses, with a program root and 1-based positions.
	for name in valid:
		var text := _read(_corpus_dir().path_join("valid").path_join(name))
		var result := ParserScript.parse(text)
		var ok: bool = result.get("ok") == true
		var detail := str(result)
		if ok:
			var ast: Variant = result["ast"]
			ok = ast is Dictionary and (ast as Dictionary).get("type") == "program" \
					and result["diagnostics"] is Array and (result["diagnostics"] as Array).is_empty()
			if ok:
				var bad: Array[String] = []
				_walk_positions(ast, "ast", bad)
				ok = bad.is_empty()
				detail = ", ".join(bad)
		check("valid parses " + name, ok, detail)

	# 2. Every E_SYNTAX file fails with one diagnostic at the expected position.
	var syntax_names: Array[String] = []
	for name in invalid:
		var text := _read(_corpus_dir().path_join("invalid").path_join(name))
		var expected := _expect(text)
		if expected.is_empty() or expected["code"] != "E_SYNTAX":
			continue
		syntax_names.append(name)
		var result := ParserScript.parse(text)
		var diagnostics: Variant = result.get("diagnostics")
		var ok: bool = result.get("ok") == false and result.get("ast") == null \
				and diagnostics is Array and (diagnostics as Array).size() == 1
		var detail := str(result)
		if ok:
			var diagnostic: Dictionary = diagnostics[0]
			ok = diagnostic.get("code") == "E_SYNTAX" \
					and diagnostic.get("severity") == "error" \
					and not str(diagnostic.get("message", "")).is_empty() \
					and diagnostic.get("line") == expected["line"] \
					and diagnostic.get("col") == expected["col"]
			detail = "expected E_SYNTAX %d:%d, got %s" % [
				expected["line"], expected["col"], str(diagnostic)]
		check("syntax " + name, ok, detail)

	# 3. Every invalid file with a semantic code parses fine.
	for name in invalid:
		var text := _read(_corpus_dir().path_join("invalid").path_join(name))
		var expected := _expect(text)
		if expected.is_empty() or expected["code"] == "E_SYNTAX":
			continue
		var result := ParserScript.parse(text)
		check("semantic parses " + name, result.get("ok") == true, str(result))

	# 4. Agreement with the grammar on every corpus file, including error positions.
	for name in valid:
		var text := _read(_corpus_dir().path_join("valid").path_join(name))
		var parsed: bool = ParserScript.parse(text).get("ok") == true
		var accepted: bool = grammar.accepts(text)
		check("grammar agrees valid " + name, parsed == accepted,
			"parser=%s recognizer=%s" % [str(parsed), str(accepted)])
	for name in invalid:
		var text := _read(_corpus_dir().path_join("invalid").path_join(name))
		var parsed: bool = ParserScript.parse(text).get("ok") == true
		var accepted: bool = grammar.accepts(text)
		check("grammar agrees invalid " + name, parsed == accepted,
			"parser=%s recognizer=%s" % [str(parsed), str(accepted)])
		var expected := _expect(text)
		if expected.is_empty() or expected["code"] != "E_SYNTAX":
			continue
		var result := ParserScript.parse(text)
		var parser_lc := Vector2i(-1, -1)
		if result.get("ok") == false:
			var diagnostic: Dictionary = (result["diagnostics"] as Array)[0]
			parser_lc = Vector2i(int(diagnostic["line"]), int(diagnostic["col"]))
		var grammar_lc := _line_col(text, grammar.error_position())
		check("grammar position " + name, parser_lc == grammar_lc,
			"parser=%s recognizer=%s" % [str(parser_lc), str(grammar_lc)])

	# 5. Extra accept/reject table against both parser and grammar.
	var accepted_rows := [
		"",
		"\n",
		"// c\n",
		"tempo 90 3/4\n",
		"state a:\r\n  s(\"kick\")",
		"let x = rev()\n",
		"let x = 1.fast(2)\n",
	]
	var rejected_rows := [
		"state a:\n  s(\"\")\n",
		"state a:\n// c\n  s(\"kick\")\n",
		"state a:\n",
		"state a:\n  s(\"kick\")\n    // c\n    .fast(2)\n",
		"let x = rev( )\n",
		" tempo 120\n",
		"param x 0.. = 1\n",
		"tempo\n",
		"foo 1\n",
		"let x = (s(\"kick\")\n",
		"transition a -> b fa 1\n",
		"transition a -> b f\n",
		"stinger x o: s(\"a\")\n",
		"tempo 120 /x\n",
		" /x\n",
		"state a:\n  s(\"kick\")\n  /x\n",
	]
	for source: String in accepted_rows:
		var text := _normalise(source)
		var parsed: bool = ParserScript.parse(text).get("ok") == true
		var recognized: bool = grammar.accepts(text)
		var label := source.replace("\n", "\\n").replace("\r", "\\r")
		check("table accept " + label, parsed and recognized,
			"parser=%s recognizer=%s" % [str(parsed), str(recognized)])
	for source: String in rejected_rows:
		var text := _normalise(source)
		var result := ParserScript.parse(text)
		var parsed: bool = result.get("ok") == true
		var recognized: bool = grammar.accepts(text)
		var label := source.replace("\n", "\\n").replace("\r", "\\r")
		check("table reject " + label, not parsed and not recognized,
			"parser=%s recognizer=%s" % [str(parsed), str(recognized)])
		if not parsed:
			var diagnostic: Dictionary = (result["diagnostics"] as Array)[0]
			var parser_lc := Vector2i(int(diagnostic["line"]), int(diagnostic["col"]))
			var grammar_lc := _line_col(text, grammar.error_position())
			check("table position " + label, parser_lc == grammar_lc,
				"parser=%s recognizer=%s" % [str(parser_lc), str(grammar_lc)])

	# 6. AST spot checks on the forest corpus.
	var forest := ParserScript.parse(_read(_corpus_dir().path_join("valid").path_join("forest.cue")))
	check("forest parses", forest.get("ok") == true, str(forest))
	if forest.get("ok") == true:
		var program: Dictionary = forest["ast"]
		var items: Array = program["items"]
		check("forest item count", items.size() == 12, "got %d" % items.size())
		if items.size() == 12:
			var expected_types := [
				"tempo", "seed", "param", "param", "let", "let",
				"state", "state", "transition", "transition", "stinger", "bind",
			]
			var actual_types: Array[String] = []
			for item: Variant in items:
				actual_types.append(str((item as Dictionary)["type"]))
			check("forest item order", actual_types == expected_types, str(actual_types))

			var tempo: Dictionary = items[0]
			check("forest tempo bpm", tempo["bpm"] == 96.0, str(tempo["bpm"]))
			check("forest tempo beats", tempo["beats"] == 4, str(tempo["beats"]))
			check("forest tempo unit", tempo["unit"] == 4, str(tempo["unit"]))
			check("forest tempo position", tempo["line"] == 2 and tempo["col"] == 1,
				"%d:%d" % [tempo["line"], tempo["col"]])

			var danger: Dictionary = items[2]
			check("forest param danger", danger["type"] == "param" and danger["name"] == "danger"
				and danger["lo"] == 0.0 and danger["hi"] == 1.0 and danger["default"] == 0.0
				and danger["line"] == 4 and danger["name_col"] == 7 and danger["default_col"] == 21,
				str(danger))
			var depth: Dictionary = items[3]
			check("forest param depth defaults", depth["lo"] == 0.0 and depth["hi"] == 1.0, str(depth))

			var bass: Dictionary = items[4]
			var bass_expr: Dictionary = bass["expr"]
			check("forest let bass", bass["name"] == "bass" and bass["line"] == 7 and bass["name_col"] == 5,
				str(bass))
			check("forest bass chain names", _chain_names(bass_expr) == ["lpf", "s", "scale", "n"],
				str(_chain_names(bass_expr)))
			check("forest bass lpf", bass_expr["name"] == "lpf" and bass_expr["col"] == 52
				and (bass_expr["args"] as Array).size() == 1
				and (bass_expr["args"] as Array)[0]["type"] == "number"
				and (bass_expr["args"] as Array)[0]["value"] == 900.0,
				str(bass_expr))
			var n_node: Variant = bass_expr
			for _i in range(3):
				n_node = (n_node as Dictionary)["receiver"]
			var n_ok: bool = n_node is Dictionary and (n_node as Dictionary)["type"] == "call" \
					and (n_node as Dictionary)["name"] == "n" \
					and (n_node as Dictionary)["col"] == 12 \
					and (n_node as Dictionary)["receiver"] == null \
					and ((n_node as Dictionary)["args"] as Array).size() == 1
			var mini_text := ""
			var mini_type := ""
			if n_ok:
				var string_node: Dictionary = ((n_node as Dictionary)["args"] as Array)[0]
				n_ok = string_node["type"] == "string"
				if n_ok:
					mini_text = str(string_node["text"])
					mini_type = str((string_node["mini"] as Dictionary)["type"])
			check("forest bass n", n_ok and mini_text == "0 ~ 0 3" and mini_type == "seq",
				"n=%s text=%s mini=%s" % [str(n_node), mini_text, mini_type])

			var explore: Dictionary = items[6]
			var explore_layers: Array = explore["layers"]
			check("forest explore layers", explore_layers.size() == 3, str(explore_layers.size()))
			if explore_layers.size() == 3:
				check("forest explore layer 0", explore_layers[0] == {
					"type": "name", "name": "bass", "line": 11, "col": 3,
				}, str(explore_layers[0]))
				var gain: Dictionary = explore_layers[2]
				var game_call: Variant = null
				if gain["type"] == "call" and (gain["args"] as Array).size() > 0:
					game_call = (gain["args"] as Array)[0]
				var danger_string: Variant = null
				if game_call is Dictionary and (game_call as Dictionary)["type"] == "call" \
						and ((game_call as Dictionary)["args"] as Array).size() > 0:
					danger_string = ((game_call as Dictionary)["args"] as Array)[0]
				check("forest explore gain", gain["type"] == "call" and gain["name"] == "gain"
					and gain["line"] == 13 and game_call is Dictionary
					and (game_call as Dictionary)["type"] == "call"
					and (game_call as Dictionary)["name"] == "game"
					and danger_string is Dictionary
					and (danger_string as Dictionary)["type"] == "string"
					and (danger_string as Dictionary)["text"] == "danger"
					and (danger_string as Dictionary)["line"] == 13
					and (danger_string as Dictionary)["col"] == 24,
					str(gain))

			var combat: Dictionary = items[7]
			var combat_layers: Array = combat["layers"]
			check("forest combat layers", combat_layers.size() == 3, str(combat_layers.size()))
			if combat_layers.size() == 3:
				var fast: Dictionary = combat_layers[0]
				check("forest combat fast", fast["type"] == "call" and fast["name"] == "fast"
					and fast["receiver"] is Dictionary
					and (fast["receiver"] as Dictionary)["type"] == "name"
					and (fast["receiver"] as Dictionary)["name"] == "bass",
					str(fast))
				var lpf: Dictionary = combat_layers[2]
				var every: Variant = lpf["receiver"]
				var rev: Variant = null
				if every is Dictionary and ((every as Dictionary)["args"] as Array).size() > 1:
					rev = ((every as Dictionary)["args"] as Array)[1]
				check("forest combat continuation", lpf["type"] == "call" and lpf["name"] == "lpf"
					and lpf["line"] == 20 and lpf["col"] == 6
					and every is Dictionary and (every as Dictionary)["type"] == "call"
					and (every as Dictionary)["name"] == "every"
					and (every as Dictionary)["line"] == 19 and (every as Dictionary)["col"] == 6
					and rev is Dictionary and (rev as Dictionary)["type"] == "call"
					and (rev as Dictionary)["name"] == "rev"
					and (rev as Dictionary)["line"] == 19 and (rev as Dictionary)["col"] == 15
					and (rev as Dictionary)["receiver"] == null,
					str(lpf))

			var first_transition: Dictionary = items[8]
			check("forest first transition", first_transition["from"] == "explore"
				and first_transition["to"] == "combat"
				and first_transition["quant"] is Dictionary
				and (first_transition["quant"] as Dictionary)["kind"] == "bar"
				and (first_transition["quant"] as Dictionary)["count"] == 1
				and first_transition["fade"] == 1.0
				and first_transition["fill"] is Dictionary
				and (first_transition["fill"] as Dictionary)["type"] == "call"
				and (first_transition["fill"] as Dictionary)["name"] == "s",
				str(first_transition))
			var second_transition: Dictionary = items[9]
			check("forest second transition", second_transition["from"] == "*"
				and second_transition["quant"] is Dictionary
				and (second_transition["quant"] as Dictionary)["kind"] == "bars"
				and (second_transition["quant"] as Dictionary)["count"] == 4
				and second_transition["fade"] == 2.0
				and second_transition["fill"] == null,
				str(second_transition))

			var stinger: Dictionary = items[10]
			check("forest stinger", stinger["name"] == "found"
				and stinger["quant"] is Dictionary
				and (stinger["quant"] as Dictionary)["kind"] == "beat"
				and stinger["len"] == 1.0
				and stinger["expr"] is Dictionary
				and (stinger["expr"] as Dictionary)["type"] == "call",
				str(stinger))

			var bind: Dictionary = items[11]
			check("forest bind", bind["inst"] == "pad" and bind["control"] == "lpf"
				and bind["param"] == "danger" and bind["lo"] == 400.0 and bind["hi"] == 4000.0,
				str(bind))

	var binds := ParserScript.parse(_read(_corpus_dir().path_join("valid").path_join("binds.cue")))
	check("binds parses", binds.get("ok") == true, str(binds))
	if binds.get("ok") == true:
		var bind_items: Array = (binds["ast"] as Dictionary)["items"]
		var first_bind_found := false
		for item: Variant in bind_items:
			if item is Dictionary and (item as Dictionary)["type"] == "bind":
				first_bind_found = true
				check("binds first bind defaults", (item as Dictionary)["lo"] == null
					and (item as Dictionary)["hi"] == null, str(item))
				break
		check("binds has a bind", first_bind_found, str(bind_items))

	var comments := ParserScript.parse(_read(_corpus_dir().path_join("valid").path_join("comments_blank.cue")))
	check("comments_blank parses", comments.get("ok") == true, str(comments))
	if comments.get("ok") == true:
		var comment_items: Array = (comments["ast"] as Dictionary)["items"]
		var comment_tempo: Variant = null
		for item: Variant in comment_items:
			if item is Dictionary and (item as Dictionary)["type"] == "tempo":
				comment_tempo = item
				break
		check("comments_blank tempo", comment_tempo is Dictionary
			and (comment_tempo as Dictionary)["bpm"] == 100.0, str(comment_tempo))
		var first_state := _first_state(comments["ast"])
		check("comments_blank first state layers", not first_state.is_empty()
			and (first_state["layers"] as Array).size() == 3, str(first_state))

	# Mini error columns are translated to file columns on the string's line.
	var mini_source := "state a:\n  n(\"0 ~ 0 3 . \")\n"
	var mini_result := ParserScript.parse(mini_source)
	var second_line := mini_source.split("\n")[1]
	var expected_col := second_line.find(".") + 1
	check("mini col mapping", mini_result.get("ok") == false
		and (mini_result["diagnostics"] as Array).size() == 1
		and (mini_result["diagnostics"] as Array)[0]["code"] == "E_SYNTAX"
		and (mini_result["diagnostics"] as Array)[0]["line"] == 2
		and (mini_result["diagnostics"] as Array)[0]["col"] == expected_col,
		"expected line 2 col %d, got %s" % [expected_col, str(mini_result)])

	if failures.is_empty():
		print("PASS all cue parser checks")
		quit(0)
	else:
		print("FAILURES: " + ", ".join(failures))
		quit(1)
