extends SceneTree
# Cue function library and compiler: FUNCTIONS shape, constructors, controls,
# pitch, structure, time, signals, lets/transforms, statements, seeds, errors
# and window-splitting invariance.
# Run: bash tests/verify.sh --no-build tests/test_cue_lib.gd
# Exits with code 0 when every check passes, 1 otherwise.

var failures: Array[String] = []

const FUNCTION_NAMES: Array[String] = [
	"s", "n", "note", "stack", "cat", "seq", "silence", "run", "game",
	"sine", "saw", "tri", "square", "rand", "perlin", "irand",
	"fast", "slow", "early", "late", "ply", "rev", "palindrome", "iter",
	"segment", "range", "struct", "mask", "euclid", "euclidRot", "degrade",
	"degradeBy", "sometimesBy", "sometimes", "often", "rarely", "almostNever",
	"almostAlways", "someCyclesBy", "someCycles", "every", "superimpose", "off",
	"scale", "transpose", "add", "gain", "velocity", "legato", "lpf", "hpf",
	"lpq", "attack", "decay", "sustain", "release", "pan", "detune",
]

const ALLOWED_KINDS: Array[String] = ["constructor", "method", "signal"]
const ALLOWED_ARG_KINDS: Array[String] = ["pattern", "transform", "numeric", "string"]


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else ": " + detail))
	if not ok:
		failures.append(name)


func f(n: int, d: int = 1) -> CueFrac:
	return CueFrac.make(n, d)


func _num(v: Variant, default_value: float) -> float:
	if v is Dictionary:
		return float((v as Dictionary).get("value", default_value))
	if v is int or v is float:
		return float(v)
	return default_value


func _parse(src: String) -> Dictionary:
	var result := CueParser.parse(src)
	if not bool(result.get("ok", false)):
		print("FAIL parse source: " + str(result))
		quit(1)
		return {}
	return result["ast"]


func _states(src: String, seed: int = 0) -> Dictionary:
	return CueLib.compile(_parse(src), seed)


func _program(layer: String, extra: String = "") -> Dictionary:
	return _states(extra + "state a:\n  " + layer + "\n")


func _query(res: Dictionary, b: CueFrac, e: CueFrac, controls: Dictionary = {}) -> Array[CueHap]:
	var pattern: CuePattern = res["states"]["a"]
	return pattern.query_arc(b, e, controls)


func _sorted(haps: Array) -> Array[CueHap]:
	var out: Array[CueHap] = []
	out.assign(haps)
	out.sort_custom(func(x: CueHap, y: CueHap) -> bool:
		var xb := x.whole_or_part().begin
		var yb := y.whole_or_part().begin
		if xb.eq(yb):
			return x.whole_or_part().end.lt(y.whole_or_part().end)
		return xb.lt(yb))
	return out


func _vals(haps: Array, key: String) -> Array:
	var out: Array = []
	for h: CueHap in _sorted(haps):
		var value: Dictionary = h.value
		out.append(value.get(key))
	return out


func _raw_vals(haps: Array) -> Array:
	var out: Array = []
	for h: CueHap in _sorted(haps):
		out.append(h.value)
	return out


func _frac_strs(fracs: Array) -> Array[String]:
	var out: Array[String] = []
	for v: CueFrac in fracs:
		out.append(str(v))
	return out


func _whole_begins(haps: Array) -> Array[String]:
	var out: Array[String] = []
	for h: CueHap in _sorted(haps):
		out.append(str(h.whole_or_part().begin))
	return out


func _whole_spans(haps: Array) -> Array[String]:
	var out: Array[String] = []
	for h: CueHap in _sorted(haps):
		var w: CueSpan = h.whole if h.whole != null else h.part
		out.append("%s-%s" % [str(w.begin), str(w.end)])
	return out


func _onsets(haps: Array) -> Array[CueHap]:
	var out: Array[CueHap] = []
	for h: CueHap in haps:
		if h.has_onset():
			out.append(h)
	return _sorted(out)


func _onset_starts(haps: Array) -> Array[String]:
	var out: Array[String] = []
	for h: CueHap in _sorted(_onsets(haps)):
		out.append(str(h.whole.begin))
	return out


func _onset_sig(haps: Array) -> Array[String]:
	var out: Array[String] = []
	for h: CueHap in _sorted(_onsets(haps)):
		out.append("%s-%s:%s" % [str(h.whole.begin), str(h.whole.end), str(h.value)])
	return out


func _eq(name: String, got: Variant, expected: Variant) -> void:
	check(name, got == expected, "got %s, expected %s" % [str(got), str(expected)])


func _eq_floats(name: String, got: Array, expected: Array, tol: float = 1e-9) -> void:
	var ok := got.size() == expected.size()
	var detail := "got %s, expected %s" % [str(got), str(expected)]
	if ok:
		for i in got.size():
			if absf(float(got[i]) - float(expected[i])) > tol:
				ok = false
				break
	check(name, ok, detail)


func _approx(name: String, got: float, expected: float, tol: float = 1e-9) -> void:
	check(name, absf(got - expected) <= tol, "got %s, expected %s" % [str(got), str(expected)])


func _codes(res: Dictionary) -> Array:
	var out: Array = []
	for err: Dictionary in res.get("errors", []):
		out.append(str(err.get("code", "")))
	return out


func _has_code(res: Dictionary, code: String) -> bool:
	return code in _codes(res)


func _initialize() -> void:
	_test_functions()
	_test_constructors_controls()
	_test_pitch()
	_test_structure_constructors()
	_test_time()
	_test_structure()
	_test_signals()
	_test_transforms_and_lets()
	_test_statements()
	_test_seed_handling()
	_test_errors()
	_test_window_splitting()

	if failures.is_empty():
		print("PASS all cue lib checks")
		quit(0)
	else:
		print("FAIL %d cue lib checks" % failures.size())
		quit(1)


func _test_functions() -> void:
	for name in FUNCTION_NAMES:
		check("function exists " + name, CueLib.has_function(name), "missing from FUNCTIONS")
	check("has_function bogus", not CueLib.has_function("bogus"), "bogus reported present")
	for key: Variant in CueLib.FUNCTIONS:
		var name := str(key)
		var entry: Dictionary = CueLib.FUNCTIONS[key]
		var keys: Array = entry.keys()
		keys.sort()
		var expected_keys: Array = ["arg_kinds", "kind", "max_args", "min_args"]
		if name == "s" or name == "n" or name == "note":
			expected_keys.append("also_method")
			expected_keys.sort()
		check("entry keys " + name, keys == expected_keys, "got %s" % str(keys))
		check("entry kind " + name, str(entry.get("kind", "")) in ALLOWED_KINDS, str(entry.get("kind")))
		var min_args := int(entry.get("min_args", -2))
		var max_args := int(entry.get("max_args", -2))
		check("entry arity " + name, max_args == -1 or min_args <= max_args,
			"min=%d max=%d" % [min_args, max_args])
		var arg_kinds: Array = entry.get("arg_kinds", [])
		var kinds_ok := true
		for kind: Variant in arg_kinds:
			if not (str(kind) in ALLOWED_ARG_KINDS):
				kinds_ok = false
		check("entry arg kinds " + name, kinds_ok, str(arg_kinds))
		var size_ok := arg_kinds.size() == max_args or (max_args == -1 and arg_kinds.size() == 1)
		check("entry arg count " + name, size_ok, "arg_kinds=%s max_args=%d" % [str(arg_kinds), max_args])

	var fast: Dictionary = CueLib.FUNCTIONS["fast"]
	check("fast spot check", fast["kind"] == "method" and fast["min_args"] == 1
		and fast["max_args"] == 1 and fast["arg_kinds"] == ["numeric"], str(fast))
	var every: Dictionary = CueLib.FUNCTIONS["every"]
	check("every spot check", every["kind"] == "method" and every["min_args"] == 2
		and every["max_args"] == 2 and every["arg_kinds"] == ["numeric", "transform"], str(every))
	check("stack variadic", CueLib.FUNCTIONS["stack"]["max_args"] == -1, str(CueLib.FUNCTIONS["stack"]))
	check("sine signal", CueLib.FUNCTIONS["sine"]["kind"] == "signal", str(CueLib.FUNCTIONS["sine"]))
	check("irand arity", CueLib.FUNCTIONS["irand"]["min_args"] == 1, str(CueLib.FUNCTIONS["irand"]))
	check("s constructor", CueLib.FUNCTIONS["s"]["kind"] == "constructor"
		and bool(CueLib.FUNCTIONS["s"].get("also_method", false)), str(CueLib.FUNCTIONS["s"]))
	check("scale arg", CueLib.FUNCTIONS["scale"]["arg_kinds"] == ["string"], str(CueLib.FUNCTIONS["scale"]))
	check("game arg", CueLib.FUNCTIONS["game"]["arg_kinds"] == ["string"], str(CueLib.FUNCTIONS["game"]))


func _test_constructors_controls() -> void:
	var res := _program("s(\"kick snare\")")
	var haps := _query(res, f(0), f(1))
	_eq("s kick snare spans", _whole_spans(haps), ["0-1/2", "1/2-1"])
	_eq("s kick snare values", _vals(haps, "s"), ["kick", "snare"])

	res = _program("s(\"kick:2\")")
	haps = _query(res, f(0), f(1))
	_eq("s suffix s", _vals(haps, "s"), ["kick"])
	_eq("s suffix n", _vals(haps, "n"), [2])

	res = _program("n(\"0 1\").s(\"bass\")")
	haps = _query(res, f(0), f(1))
	_eq("n then s n", _vals(haps, "n"), [0.0, 1.0])
	_eq("n then s s", _vals(haps, "s"), ["bass", "bass"])

	res = _program("note(\"c4 eb3\")")
	haps = _query(res, f(0), f(1))
	_eq("note names", _vals(haps, "note"), [60, 51])

	res = _program("s(\"a b\").gain(0.5)")
	haps = _query(res, f(0), f(1))
	_eq("gain constant", _vals(haps, "gain"), [0.5, 0.5])
	_eq("gain keeps s", _vals(haps, "s"), ["a", "b"])

	res = _program("s(\"x\").gain(\"<0.2 0.8>\")")
	_eq("gain patterned cycle0", _vals(_query(res, f(0), f(1)), "gain"), [0.2])
	_eq("gain patterned cycle1", _vals(_query(res, f(1), f(2)), "gain"), [0.8])

	res = _program("s(\"x\").gain(game(\"danger\"))")
	var danger := _query(res, f(0), f(1), {"params": {"danger": 0.7}})
	_eq("gain game param", _vals(danger, "gain"), [0.7])
	var no_params := _query(res, f(0), f(1), {})
	_eq("gain game default", _vals(no_params, "gain"), [0.0])

	res = _program("s(\"x\").lpf(900).hpf(100)")
	haps = _query(res, f(0), f(1))
	_eq("lpf", _vals(haps, "lpf"), [900.0])
	_eq("hpf", _vals(haps, "hpf"), [100.0])


func _test_pitch() -> void:
	var res := _program("n(\"0 1\").scale(\"C:major\")")
	var haps := _query(res, f(0), f(1))
	_eq("scale c major notes", _vals(haps, "note"), [48, 50])
	var has_n := false
	for h: CueHap in haps:
		if (h.value as Dictionary).has("n"):
			has_n = true
	check("scale removes n", not has_n, "n still present")

	res = _program("n(\"0 -1 7\").scale(\"C:major\")")
	_eq("scale negative degrees", _vals(_query(res, f(0), f(1)), "note"), [48, 47, 60])

	res = _program("n(\"0 2\").scale(\"D4:minor\")")
	_eq("scale d4 minor", _vals(_query(res, f(0), f(1)), "note"), [62, 65])

	res = _program("n(\"0 2\").scale(\"<C:major D:major>\")")
	_eq("scale patterned cycle1", _vals(_query(res, f(1), f(2)), "note"), [50, 54])

	res = _program("n(\"0\").scale(\"C:nope\")")
	_eq("scale invalid drops", _query(res, f(0), f(1)).size(), 0)

	res = _program("note(\"c4\").transpose(12)")
	_eq_floats("transpose note", _vals(_query(res, f(0), f(1)), "note"), [72.0])

	res = _program("n(\"0\").add(2)")
	_eq("add n", _vals(_query(res, f(0), f(1)), "n"), [2.0])

	res = _program("note(\"60\").add(7)")
	_eq_floats("add note", _vals(_query(res, f(0), f(1)), "note"), [67.0])

	res = _program("note(\"c3\").add(\"<0 7>\")")
	_eq_floats("add patterned cycle1", _vals(_query(res, f(1), f(2)), "note"), [55.0])

	res = _program("n(\"0 2\").transpose(1)")
	haps = _query(res, f(0), f(1))
	_eq("transpose n", _vals(haps, "n"), [1.0, 3.0])
	var has_note := false
	for h: CueHap in haps:
		if (h.value as Dictionary).has("note"):
			has_note = true
	check("transpose keeps n only", not has_note, "note appeared")


func _test_structure_constructors() -> void:
	var res := _program("stack(s(\"a\"), s(\"b\"))")
	var haps := _query(res, f(0), f(1))
	_eq("stack count", haps.size(), 2)
	_eq("stack spans", _whole_spans(haps), ["0-1", "0-1"])

	res = _program("cat(s(\"a\"), s(\"b\"))")
	_eq("cat cycle0", _vals(_query(res, f(0), f(1)), "s"), ["a"])
	_eq("cat cycle1", _vals(_query(res, f(1), f(2)), "s"), ["b"])
	_eq("cat cycle2", _vals(_query(res, f(2), f(3)), "s"), ["a"])

	res = _program("seq(s(\"a\"), s(\"b\"))")
	haps = _query(res, f(0), f(1))
	_eq("seq spans", _whole_spans(haps), ["0-1/2", "1/2-1"])
	_eq("seq values", _vals(haps, "s"), ["a", "b"])

	res = _program("n(run(4))")
	haps = _query(res, f(0), f(1))
	_eq("run values", _vals(haps, "n"), [0.0, 1.0, 2.0, 3.0])
	_eq("run wholes", _whole_begins(haps), ["0", "1/4", "1/2", "3/4"])

	res = _program("silence")
	_eq("silence layer", _query(res, f(0), f(1)).size(), 0)

	res = _program("s(\"a\")\n  s(\"b\")")
	_eq("two layers stack", _query(res, f(0), f(1)).size(), 2)


func _test_time() -> void:
	var res := _program("s(\"a b\").fast(2)")
	var haps := _query(res, f(0), f(1))
	_eq("fast count", haps.size(), 4)
	_eq("fast values", _vals(haps, "s"), ["a", "b", "a", "b"])

	res = _program("s(\"a b\").slow(2)")
	haps = _query(res, f(0), f(2))
	_eq("slow spans", _whole_spans(haps), ["0-1", "1-2"])
	_eq("slow values", _vals(haps, "s"), ["a", "b"])

	res = _program("s(\"a b\").fast(\"<1 2>\")")
	_eq("fast patterned cycle0", _query(res, f(0), f(1)).size(), 2)
	_eq("fast patterned cycle1", _query(res, f(1), f(2)).size(), 4)

	res = _program("s(\"a b\").early(0.25)")
	haps = _query(res, f(0), f(1))
	_eq("early starts", _onset_starts(haps), ["1/4", "3/4"])
	_eq("early values", _vals(_onsets(haps), "s"), ["b", "a"])

	var late_string := _program("s(\"a b\").late(\"0.25\")")
	var late_number := _program("s(\"a b\").late(0.25)")
	_eq("late string equals number",
		_onset_sig(_query(late_string, f(0), f(1))),
		_onset_sig(_query(late_number, f(0), f(1))))

	res = _program("s(\"a b\").ply(2)")
	_eq("ply values", _vals(_query(res, f(0), f(1)), "s"), ["a", "a", "b", "b"])

	res = _program("n(\"0 1 2 3\").iter(4)")
	_eq("iter cycle1", _vals(_query(res, f(1), f(2)), "n"), [1.0, 2.0, 3.0, 0.0])

	res = _program("n(\"0 1 2 3\").palindrome()")
	_eq("palindrome cycle1", _vals(_query(res, f(1), f(2)), "n"), [3.0, 2.0, 1.0, 0.0])

	res = _program("s(\"a b\").rev()")
	_eq("rev values", _vals(_query(res, f(0), f(1)), "s"), ["b", "a"])

	res = _program("n(saw.segment(4))")
	_eq_floats("segment signal", _vals(_query(res, f(0), f(1)), "n"), [0.125, 0.375, 0.625, 0.875])

	res = _program("s(\"a b\").segment(4)")
	haps = _query(res, f(0), f(1))
	_eq("segment values", _vals(haps, "s"), ["a", "a", "b", "b"])
	_eq("segment wholes", _whole_spans(haps), ["0-1/4", "1/4-1/2", "1/2-3/4", "3/4-1"])


func _test_structure() -> void:
	var res := _program("s(\"a\").struct(\"x ~ x x\")")
	var haps := _query(res, f(0), f(1))
	_eq("struct spans", _whole_spans(haps), ["0-1/4", "1/2-3/4", "3/4-1"])

	res = _program("s(\"a b c d\").mask(\"1 0\")")
	haps = _query(res, f(0), f(1))
	_eq("mask spans", _whole_spans(haps), ["0-1/4", "1/4-1/2"])
	_eq("mask values", _vals(haps, "s"), ["a", "b"])

	res = _program("s(\"a\").euclid(3, 8)")
	_eq("euclid starts", _onset_starts(_query(res, f(0), f(1))), ["0", "3/8", str(f(6, 8))])

	res = _program("s(\"a\").euclidRot(3, 8, 2)")
	_eq("euclidRot starts", _onset_starts(_query(res, f(0), f(1))), ["1/8", "1/2", "3/4"])

	res = _program("s(\"a\").euclid(\"<3 5>\", 8)")
	_eq("euclid patterned cycle1 starts",
		_onset_starts(_query(res, f(1), f(2))),
		["1", "5/4", "11/8", "13/8", "7/4"])


func _test_signals() -> void:
	var res := _program("s(\"x*4\").gain(saw)")
	_eq_floats("gain saw", _vals(_query(res, f(0), f(1)), "gain"), [0.0, 0.25, 0.5, 0.75])

	res = _program("s(\"x*4\").gain(square)")
	_eq_floats("gain square", _vals(_query(res, f(0), f(1)), "gain"), [0.0, 0.0, 1.0, 1.0])

	res = _program("s(\"x*4\").gain(tri)")
	_eq_floats("gain tri", _vals(_query(res, f(0), f(1)), "gain"), [0.0, 0.5, 1.0, 0.5])

	res = _program("s(\"x\").gain(sine)")
	_eq_floats("gain sine", _vals(_query(res, f(0), f(1)), "gain"), [0.5])

	res = _program("s(\"x*4\").gain(saw.range(10, 20))")
	_eq_floats("gain saw range", _vals(_query(res, f(0), f(1)), "gain"), [10.0, 12.5, 15.0, 17.5])

	res = _program("s(\"x*2\").lpf(saw.slow(2))")
	_eq_floats("lpf slow saw", _vals(_query(res, f(0), f(1)), "lpf"), [0.0, 0.25])

	res = _program("s(\"x*2\").gain(sine.range(\"0.2\", \"1\"))")
	_approx("gain sine range string", float(_vals(_query(res, f(0), f(1)), "gain")[0]), 0.6)

	res = _program("s(\"x*4\").pan(rand)")
	var first := _query(res, f(0), f(1))
	var first_values := _vals(first, "pan")
	_eq("rand pan count", first_values.size(), 4)
	var in_range := true
	for v: Variant in first_values:
		if float(v) < 0.0 or float(v) >= 1.0:
			in_range = false
	check("rand pan range", in_range, str(first_values))
	var second := _program("s(\"x*4\").pan(rand)")
	_eq_floats("rand pan deterministic", _vals(_query(second, f(0), f(1)), "pan"), first_values)


func _test_transforms_and_lets() -> void:
	var res := _states("let t = fast(2).rev()\nstate a:\n  s(\"x\")\n")
	var t: Variant = res["lets"]["t"]
	check("let t callable", t is Callable, str(t))
	var ab: Array[CuePattern] = [CuePattern.pure("a"), CuePattern.pure("b")]
	if t is Callable:
		var applied: CuePattern = t.call(CuePattern.seq(ab))
		_eq("let t applies", _raw_vals(applied.query_arc(f(0), f(1))), ["b", "a", "b", "a"])

	res = _states("let r = rev\nstate a:\n  s(\"x\")\n")
	check("let r callable", res["lets"]["r"] is Callable, str(res["lets"]["r"]))

	res = _states("let p = s(\"a b\")\nstate a:\n  p.fast(2)\n")
	_eq("let p fast", _query(res, f(0), f(1)).size(), 4)

	res = _states("let p = s(\"a b\")\nlet q = p.rev()\nstate a:\n  q\n")
	_eq("let q rev", _vals(_query(res, f(0), f(1)), "s"), ["b", "a"])

	res = _states("let t2 = fast(2)\nlet t3 = t2.rev()\nstate a:\n  s(\"x\")\n")
	var t3: Variant = res["lets"]["t3"]
	check("let t3 callable", t3 is Callable, str(t3))
	if t3 is Callable:
		var applied3: CuePattern = t3.call(CuePattern.seq(ab))
		_eq("let t3 applies", _raw_vals(applied3.query_arc(f(0), f(1))), ["b", "a", "b", "a"])

	var left := _states("let t = early(0.25).rev()\nstate a:\n  s(\"x\")\n")
	var right := _states("let u = rev().early(0.25)\nstate a:\n  s(\"x\")\n")
	var base := CuePattern.seq(ab)
	var lt: Callable = left["lets"]["t"]
	var rt: Callable = right["lets"]["u"]
	var left_sig := _onset_sig(lt.call(base).query_arc(f(0), f(1)))
	var right_sig := _onset_sig(rt.call(base).query_arc(f(0), f(1)))
	check("transform chain order", left_sig != right_sig,
		"left=%s right=%s" % [str(left_sig), str(right_sig)])


func _test_statements() -> void:
	var src := """tempo 96
seed 7
param danger 0..1 = 0
param depth = 0.25
let bass = n("0 ~ 0 3").scale("D:minor").s("bass").lpf(900)
state explore:
  bass
  s("hat*4").gain(game("danger"))
state combat:
  bass.fast(2)
transition explore -> combat on bar fade 1 fill s("crash")
transition * -> explore on 4 bars fade 2
transition combat -> explore
stinger found on beat: n("0 4 7 12").scale("D4:major").s("lead").fast(4)
stinger hit: s("snare")
bind pad.lpf <- danger 400..4000
bind pad.gain <- depth
"""
	var res := _states(src)
	_eq("program errors", res["errors"], [])
	_eq("state order", res["states"].keys(), ["explore", "combat"])
	_approx("tempo bpm", float(res["tempo"]["bpm"]), 96.0)
	_eq("tempo beats", res["tempo"]["beats"], 4)
	_eq("program seed", res["seed"], 7)
	_eq("param danger", res["params"]["danger"], {"lo": 0.0, "hi": 1.0, "default": 0.0})
	_eq("param depth", res["params"]["depth"], {"lo": 0.0, "hi": 1.0, "default": 0.25})
	_eq("transition count", res["transitions"].size(), 3)

	var t0: Dictionary = res["transitions"][0]
	_eq("transition 0 from", t0["from"], "explore")
	_eq("transition 0 to", t0["to"], "combat")
	_eq("transition 0 quant", t0["quant"], {"kind": "bar", "count": 1})
	_approx("transition 0 fade", float(t0["fade"]), 1.0)
	var fill: Variant = t0["fill"]
	check("transition 0 fill pattern", fill is CuePattern, str(fill))
	if fill is CuePattern:
		_eq("transition 0 fill crash", _vals((fill as CuePattern).query_arc(f(0), f(1)), "s"), ["crash"])

	var t1: Dictionary = res["transitions"][1]
	_eq("transition 1 from", t1["from"], "*")
	_eq("transition 1 quant", t1["quant"], {"kind": "bars", "count": 4})
	_approx("transition 1 fade", float(t1["fade"]), 2.0)
	_eq("transition 1 fill", t1["fill"], null)

	var t2: Dictionary = res["transitions"][2]
	_eq("transition 2 quant", t2["quant"], {"kind": "bar", "count": 1})
	_approx("transition 2 fade", float(t2["fade"]), 0.0)

	var found: Dictionary = res["stingers"]["found"]
	_eq("stinger found quant", found["quant"]["kind"], "beat")
	_approx("stinger found len", float(found["len"]), 1.0)
	var found_pattern: CuePattern = found["pattern"]
	_eq("stinger found haps", found_pattern.query_arc(f(0), f(1)).size(), 16)
	var hit: Dictionary = res["stingers"]["hit"]
	_eq("stinger hit quant", hit["quant"], {"kind": "beat", "count": 1})

	_eq("bind 0", res["binds"][0], {
		"inst": "pad", "control": "lpf", "param": "danger", "lo": 400.0, "hi": 4000.0})
	_eq("bind 1 lo", res["binds"][1]["lo"], null)

	var explore: CuePattern = res["states"]["explore"]
	var explore_haps := explore.query_arc(f(0), f(1))
	_eq("explore haps count", explore_haps.size(), 7)
	var bass_haps: Array[CueHap] = []
	var hat_haps: Array[CueHap] = []
	for h: CueHap in explore_haps:
		var value: Dictionary = h.value
		if value.get("s") == "bass":
			bass_haps.append(h)
		elif value.get("s") == "hat":
			hat_haps.append(h)
	_eq("explore bass notes", _vals(bass_haps, "note"), [50, 50, 55])
	_eq("explore bass wholes", _whole_begins(bass_haps), ["0", "1/2", "3/4"])
	_eq("explore hats", hat_haps.size(), 4)

	var combat: CuePattern = res["states"]["combat"]
	var combat_bass := combat.query_arc(f(0), f(1))
	_eq("combat bass notes", _vals(combat_bass, "note").size(), 6)


func _test_seed_handling() -> void:
	var without := "state a:\n  s(\"x*4\").pan(rand)\n"
	var a := _states(without, 5)
	var b := _states("seed 5\n" + without, 0)
	_eq_floats("seed argument equals statement",
		_vals(_query(a, f(0), f(1)), "pan"),
		_vals(_query(b, f(0), f(1)), "pan"))

	var c := _states("seed 9\n" + without, 5)
	var d := _states(without, 9)
	_eq_floats("seed statement wins",
		_vals(_query(c, f(0), f(1)), "pan"),
		_vals(_query(d, f(0), f(1)), "pan"))


func _test_errors() -> void:
	var res := _program("s(\"a\").bogus(1)")
	check("unknown function code", _has_code(res, "E_UNKNOWN_FUNCTION"), str(_codes(res)))
	var haps := _query(res, f(0), f(1))
	check("unknown function queryable", haps is Array, "query did not return an array")

	res = _program("s(\"a\").fast()")
	check("arity code", _has_code(res, "E_ARITY"), str(_codes(res)))

	res = _program("fast(2)")
	check("transform layer kind", _has_code(res, "E_KIND"), str(_codes(res)))

	res = _program("s(\"a\").every(2, rev())")
	check("every implemented", not _has_code(res, "E_UNKNOWN_FUNCTION"), str(_codes(res)))
	haps = _query(res, f(0), f(1))
	check("every queryable", haps is Array, "query did not return an array")


func _test_window_splitting() -> void:
	var layers: Array = [
		["s(\"a b c\").fast(\"<1 2>\")", 2],
		["s(\"a b\").early(0.25)", 2],
		["n(\"0 2 4\").scale(\"C:major\").ply(2)", 2],
		["s(\"a*4\").gain(saw)", 2],
		["s(\"a b\").rev().fast(1.5)", 2],
		["n(\"0 1\").iter(2).palindrome()", 4],
		["s(\"a(3,8)\").struct(\"x x ~\")", 2],
	]
	for entry: Array in layers:
		var layer := String(entry[0])
		var total := int(entry[1])
		var res := _program(layer)
		var pattern: CuePattern = res["states"]["a"]
		var whole := _onset_sig(pattern.query_arc(f(0), f(total)))

		var cuts1: Array[CueFrac] = [f(0), f(37, 100), f(1)]
		if total > 2:
			cuts1.append(f(2))
		cuts1.append(f(total))
		var split1: Array[String] = []
		for i in cuts1.size() - 1:
			split1.append_array(_onset_sig(pattern.query_arc(cuts1[i], cuts1[i + 1])))
		split1.sort()
		var whole_sorted := whole.duplicate()
		whole_sorted.sort()
		check("window split 1 " + layer, split1 == whole_sorted,
			"split=%s whole=%s" % [str(split1), str(whole_sorted)])

		var cuts2: Array[CueFrac] = [f(0), f(1, 7), f(2, 3), f(5, 4)]
		if total > 2:
			cuts2 = [f(0), f(1, 7), f(2, 3), f(5, 4), f(2)]
		cuts2.append(f(total))
		var split2: Array[String] = []
		for i in cuts2.size() - 1:
			split2.append_array(_onset_sig(pattern.query_arc(cuts2[i], cuts2[i + 1])))
		split2.sort()
		check("window split 2 " + layer, split2 == whole_sorted,
			"split=%s whole=%s" % [str(split2), str(whole_sorted)])
