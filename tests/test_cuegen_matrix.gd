extends SceneTree
# CueGenMatrix: prompt-matrix validation, deterministic expansion and cycling.
# Run: Godot --headless --path project -s ../tests/test_cuegen_matrix.gd

const MatrixScript = preload("res://addons/godot_synth/cue/gen/cue_gen_matrix.gd")

var _fails: int = 0
var _checks: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("PASS ", label)
	else:
		_fails += 1
		print("FAIL %s: %s" % [label, detail])


func _load_matrix() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../tools/cuegen/matrix.json").simplify_path()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


func _small_matrix() -> Dictionary:
	return {
		"version": 1,
		"axes": {
			"mood": ["calm", "tense"],
			"biome": ["cave"],
			"intensity": ["low"],
			"instrumentation": ["bass", "pad lead"],
			"form": ["one looping state"],
		},
		"templates": ["A {mood} {biome} {intensity} {instrumentation} {form}"],
	}


func _ids(items: Array[Dictionary]) -> Array:
	var out: Array = []
	for it: Dictionary in items:
		out.append(it["id"])
	return out


func _initialize() -> void:
	var matrix: Dictionary = _load_matrix()
	_check("matrix.json loads", not matrix.is_empty(), "empty or unreadable")
	if matrix.is_empty():
		quit(1)
		return

	# validation of the shipped matrix
	var errors: Array[String] = MatrixScript.validate(matrix)
	_check("shipped matrix validates", errors.is_empty(), str(errors))
	var axes: Dictionary = matrix["axes"]
	var sizes_ok: bool = true
	for axis: String in MatrixScript.AXES:
		var vals: Array = axes[axis]
		if vals.size() < 5 or vals.size() > 8:
			sizes_ok = false
	_check("every axis has 5..8 values", sizes_ok)
	var instr_ok: bool = true
	for v: Variant in axes["instrumentation"]:
		for tok: String in String(v).split(" "):
			if not MatrixScript.INSTRUMENTS.has(tok):
				instr_ok = false
	_check("instrumentation tokens are catalog instruments", instr_ok)
	var product: int = MatrixScript.combination_count(matrix)
	_check("combination_count is the product", product == 7 * 7 * 5 * 8 * 6, str(product))

	# invalid matrices
	var bad: Dictionary = matrix.duplicate(true)
	bad["axes"]["instrumentation"] = ["bass banjo"]
	_check("unknown instrument rejected", not MatrixScript.validate(bad).is_empty())
	bad = matrix.duplicate(true)
	bad["axes"]["mood"] = []
	_check("empty axis rejected", not MatrixScript.validate(bad).is_empty())
	bad = matrix.duplicate(true)
	bad["templates"] = ["no placeholders"]
	_check("template without placeholders rejected", not MatrixScript.validate(bad).is_empty())
	bad = matrix.duplicate(true)
	bad["axes"].erase("form")
	_check("missing axis rejected", not MatrixScript.validate(bad).is_empty())
	_check("expand of invalid matrix is empty", MatrixScript.expand(bad, 1, 5).is_empty())

	# expansion
	var a: Array[Dictionary] = MatrixScript.expand(matrix, 42, 50)
	var b: Array[Dictionary] = MatrixScript.expand(matrix, 42, 50)
	_check("count honoured", a.size() == 50, str(a.size()))
	_check("deterministic", a == b)
	_check("count 0 is empty", MatrixScript.expand(matrix, 42, 0).is_empty())
	var other: Array[Dictionary] = MatrixScript.expand(matrix, 43, 50)
	_check("different seed gives different order", _ids(a) != _ids(other))
	var prefix: Array[Dictionary] = MatrixScript.expand(matrix, 42, 10)
	_check("prefix-stable", prefix == a.slice(0, 10))

	var shape_ok: bool = true
	var values_ok: bool = true
	var req_ok: bool = true
	var id_ok: bool = true
	var seen_ids: Dictionary = {}
	var seen_axes: Dictionary = {}
	var distinct: bool = true
	var re := RegEx.new()
	re.compile("^[0-9a-f]{12}$")
	for it: Dictionary in a:
		if not (it.has("id") and it.has("axes") and it.has("request")):
			shape_ok = false
			continue
		var ax: Dictionary = it["axes"]
		if ax.size() != 5:
			shape_ok = false
		for axis: String in MatrixScript.AXES:
			if not ax.has(axis) or not (axes[axis] as Array).has(ax[axis]):
				values_ok = false
			elif not String(it["request"]).contains(String(ax[axis])):
				req_ok = false
		if String(it["request"]).contains("{") or String(it["request"]).is_empty():
			req_ok = false
		if re.search(String(it["id"])) == null:
			id_ok = false
		seen_ids[it["id"]] = true
		var key: String = str(ax)
		if seen_axes.has(key):
			distinct = false
		seen_axes[key] = true
	_check("items have id/axes/request", shape_ok)
	_check("axis values are valid", values_ok)
	_check("request carries every axis value, no leftover placeholder", req_ok)
	_check("ids are 12 hex chars", id_ok)
	_check("ids unique", seen_ids.size() == 50, str(seen_ids.size()))
	_check("no combination repeats when count < product", distinct)

	# cycling when count > product (small matrix: 2 * 1 * 1 * 2 * 1 = 4 combinations)
	var small: Dictionary = _small_matrix()
	_check("small matrix validates", MatrixScript.validate(small).is_empty(), str(MatrixScript.validate(small)))
	_check("small product", MatrixScript.combination_count(small) == 4)
	var cyc: Array[Dictionary] = MatrixScript.expand(small, 7, 10)
	_check("cycling returns count items", cyc.size() == 10)
	var first_round: Dictionary = {}
	for i in range(4):
		first_round[str(cyc[i]["axes"])] = true
	_check("first round covers all 4 combinations", first_round.size() == 4, str(first_round.size()))
	var cycle_ok: bool = true
	for i in range(4, 10):
		if cyc[i]["axes"] != cyc[i - 4]["axes"]:
			cycle_ok = false
	_check("later rounds repeat the same order", cycle_ok)
	var cyc_ids: Dictionary = {}
	for it: Dictionary in cyc:
		cyc_ids[it["id"]] = true
	_check("ids stay unique when cycling", cyc_ids.size() == 10, str(cyc_ids.size()))

	print("checks: %d, failures: %d" % [_checks, _fails])
	if _fails == 0:
		print("PASS (%d checks)" % _checks)
	quit(1 if _fails > 0 else 0)
