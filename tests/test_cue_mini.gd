extends SceneTree
# Mini-notation parser: AST shape, accepted forms, columns and syntax errors.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_mini.gd

const MiniScript = preload("res://addons/godot_synth/cue/cue_mini.gd")

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func _a(t: String, s: String = "") -> Dictionary:
	return {"type": "atom", "text": t, "suffix": s}

func _st(term: Dictionary, mods: Array = []) -> Dictionary:
	return {"type": "step", "term": term, "mods": mods}

func _seq(steps: Array) -> Dictionary:
	return {"type": "seq", "steps": steps}

func _num(v: float) -> Dictionary:
	return {"type": "number", "value": v}

func _mod(op: String, extra: Dictionary) -> Dictionary:
	var node := {"type": "mod", "op": op}
	node.merge(extra)
	return node

func _strip_cols(node: Variant) -> Variant:
	if node is Dictionary:
		var out: Dictionary = {}
		for key: Variant in node:
			if key == "col":
				continue
			out[key] = _strip_cols(node[key])
		return out
	if node is Array:
		var out: Array = []
		for item: Variant in node:
			out.append(_strip_cols(item))
		return out
	return node

func check_shape(name: String, result: Dictionary) -> void:
	var ok_shape: bool = typeof(result.get("ok")) == TYPE_BOOL
	var error_shape: bool = result.get("error") is Dictionary
	var ast_shape: bool = result.has("ast")
	if result.get("ok") == true:
		ok_shape = ok_shape and result["error"].is_empty() and result["ast"] != null
	else:
		ok_shape = ok_shape and result["ast"] == null and not result["error"].is_empty()
	check(name + " result shape", ok_shape and error_shape and ast_shape, str(result))

func expect_ast(name: String, source: String, expected: Dictionary) -> void:
	var result := MiniScript.parse(source)
	check_shape(name, result)
	if not result["ok"]:
		check(name, false, "error at %d: %s" % [result["error"]["col"], result["error"]["message"]])
		return
	var got: Variant = _strip_cols(result["ast"])
	check(name, got == expected, "%s != %s" % [str(got), str(expected)])

func _initialize() -> void:
	# AST table.
	expect_ast("single word", "kick", _seq([_st(_a("kick"))]))
	expect_ast("sequence", "a b", _seq([_st(_a("a")), _st(_a("b"))]))
	expect_ast("surrounding spaces", " a ", _seq([_st(_a("a"))]))
	expect_ast("rest and sub", "a ~ [b c]", _seq([
		_st(_a("a")),
		_st({"type": "rest"}),
		_st({"type": "sub", "item": _seq([_st(_a("b")), _st(_a("c"))])}),
	]))
	expect_ast("cat", "<a b>", _seq([
		_st({"type": "cat", "items": [_seq([_st(_a("a")), _st(_a("b"))])]}),
	]))
	expect_ast("fast", "a*2", _seq([_st(_a("a"), [_mod("fast", {"arg": _num(2.0)})])]))
	expect_ast("slow cat", "a/<2 3>", _seq([_st(_a("a"), [
		_mod("slow", {"arg": {"type": "cat", "items": [_seq([_st(_a("2")), _st(_a("3"))])]}}),
	])]))
	expect_ast("replicate", "a!3 b! !", _seq([
		_st(_a("a"), [_mod("rep", {"count": 3})]),
		_st(_a("b"), [_mod("rep", {"count": 2})]),
		{"type": "repeat_prev"},
	]))
	expect_ast("weight and degrade", "a@3 b?0.3 c?", _seq([
		_st(_a("a"), [_mod("weight", {"value": 3.0})]),
		_st(_a("b"), [_mod("degrade", {"prob": 0.3})]),
		_st(_a("c"), [_mod("degrade", {"prob": 0.5})]),
	]))
	expect_ast("euclid", "a(3,8,2) b(5, 8)", _seq([
		_st(_a("a"), [_mod("euclid", {"k": 3, "n": 8, "rot": 2})]),
		_st(_a("b"), [_mod("euclid", {"k": 5, "n": 8, "rot": 0})]),
	]))
	expect_ast("suffixes and numbers", "bd:3 C:minor -3 2.5", _seq([
		_st(_a("bd", "3")),
		_st(_a("C", "minor")),
		_st(_a("-3")),
		_st(_a("2.5")),
	]))
	expect_ast("fast and slow factors", "a*2 b/2", _seq([
		_st(_a("a"), [_mod("fast", {"arg": _num(2.0)})]),
		_st(_a("b"), [_mod("slow", {"arg": _num(2.0)})]),
	]))
	expect_ast("mod order", "a?0.3*2", _seq([
		_st(_a("a"), [
			_mod("degrade", {"prob": 0.3}),
			_mod("fast", {"arg": _num(2.0)}),
		]),
	]))
	expect_ast("choice", "a b | c d", {"type": "choice", "items": [
		_seq([_st(_a("a")), _st(_a("b"))]),
		_seq([_st(_a("c")), _st(_a("d"))]),
	]})
	expect_ast("stack", "a, b", {"type": "stack", "items": [
		_seq([_st(_a("a"))]),
		_seq([_st(_a("b"))]),
	]})
	expect_ast("choice in stack", "a b | c d, e", {"type": "stack", "items": [
		{"type": "choice", "items": [
			_seq([_st(_a("a")), _st(_a("b"))]),
			_seq([_st(_a("c")), _st(_a("d"))]),
		]},
		_seq([_st(_a("e"))]),
	]})
	expect_ast("stack in sub", "[a, b]", _seq([
		_st({"type": "sub", "item": {"type": "stack", "items": [
			_seq([_st(_a("a"))]),
			_seq([_st(_a("b"))]),
		]}}),
	]))

	# Accept-only list.
	var accepted := [
		"a  b", "a b|c", "a!!", "a(3, 8)", "<a b, c d>", "a*<2 3>",
		"[a b](3,8)", "c#4 eb3 f#5 a", "~*2", "a:b",
	]
	for source: String in accepted:
		var result := MiniScript.parse(source)
		check_shape("accept " + source, result)
		check("accept " + source, result["ok"] and result["ast"] != null, str(result))

	# Column checks.
	var scored := MiniScript.parse("a  b*2")
	check_shape("columns scores", scored)
	if scored["ok"]:
		var steps: Array = scored["ast"]["steps"]
		check("step 0 col", steps[0]["col"] == 0, str(steps[0]["col"]))
		check("step 1 col", steps[1]["col"] == 3, str(steps[1]["col"]))
		var mod: Dictionary = steps[1]["mods"][0]
		check("mod col", mod["col"] == 4, str(mod["col"]))
		check("mod arg col", mod["arg"]["col"] == 5, str(mod["arg"]["col"]))
	else:
		check("columns scores parse", false, str(scored))

	var bracketed := MiniScript.parse(" [a b] ")
	check_shape("columns sub", bracketed)
	if bracketed["ok"]:
		var sub: Dictionary = bracketed["ast"]["steps"][0]["term"]
		check("sub col", sub["col"] == 1, str(sub["col"]))
		check("sub inner col", sub["item"]["col"] == 2, str(sub["item"]["col"]))
	else:
		check("columns sub parse", false, str(bracketed))

	var repeated := MiniScript.parse("a ~ !")
	check_shape("columns repeat", repeated)
	if repeated["ok"]:
		check("repeat col", repeated["ast"]["steps"][2]["col"] == 4, str(repeated["ast"]["steps"][2]["col"]))
	else:
		check("columns repeat parse", false, str(repeated))

	# Reject table: source, expected 0-based error column.
	var rejected := [
		["", 0],
		["  ", 2],
		["a b .", 4],
		["[a b", 4],
		["a b]", 3],
		["a(3,8", 5],
		["a(3)", 3],
		["a(3,8,2,1)", 7],
		["a*", 2],
		["a@", 2],
		["a@x", 2],
		["<a b", 4],
		["a | ", 4],
		["a, ", 3],
		["~~", 1],
		["a!x", 2],
		["1.5.2", 3],
		["a:", 2],
		["a:b:c", 3],
		["-", 1],
		["-a", 1],
		["a.b", 1],
		["a*<b, c>", 4],
	]
	for row: Array in rejected:
		var source: String = row[0]
		var col: int = row[1]
		var result := MiniScript.parse(source)
		check_shape("reject " + source, result)
		var ok: bool = not result["ok"] and result["ast"] == null
		if ok:
			ok = result["error"]["col"] == col and not String(result["error"]["message"]).is_empty()
		check("reject %s at %d" % [source, col], ok, str(result))

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
