extends SceneTree
# Cue library, part 2: the seeded random family (degrade, degradeBy,
# sometimesBy and its presets, someCyclesBy, someCycles) and the higher-order
# transforms (every, superimpose, off), including determinism and window
# splitting invariance.
# Run: bash tests/verify.sh --no-build tests/test_cue_lib_random.gd
# Exits with code 0 when every check passes, 1 otherwise.

var failures: Array[String] = []


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else ": " + detail))
	if not ok:
		failures.append(name)


func f(n: int, d: int = 1) -> CueFrac:
	return CueFrac.make(n, d)


func _parse(src: String) -> Dictionary:
	var result := CueParser.parse(src)
	if not bool(result.get("ok", false)):
		print("FAIL parse source: " + str(result))
		quit(1)
		return {}
	return result["ast"]


func _compile(layer: String, seed: int = 0, extra: String = "") -> Dictionary:
	return CueLib.compile(_parse(extra + "state a:\n  " + layer + "\n"), seed)


func _compile_layers(layers: Array, seed: int = 0) -> Dictionary:
	var src := "state a:\n"
	for layer: Variant in layers:
		src += "  " + String(layer) + "\n"
	return CueLib.compile(_parse(src), seed)


func _state(layer: String, seed: int = 0, extra: String = "") -> CuePattern:
	var res := _compile(layer, seed, extra)
	var pattern: CuePattern = res["states"]["a"]
	return pattern


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


func _count(pat: CuePattern, b: CueFrac, e: CueFrac) -> int:
	return pat.onsets_in(b, e).size()


func _vals(pat: CuePattern, b: CueFrac, e: CueFrac, key: String) -> Array:
	var out: Array = []
	for h: CueHap in _sorted(pat.onsets_in(b, e)):
		var value: Variant = h.value
		if value is Dictionary:
			out.append((value as Dictionary).get(key))
		else:
			out.append(value)
	return out


func _value_tag(value: Variant) -> String:
	if value is Dictionary:
		var d: Dictionary = value
		if d.has("n"):
			return "n:" + str(d["n"])
		if d.has("note"):
			return "note:" + str(d["note"])
		if d.has("s"):
			return "s:" + str(d["s"])
	return "v:" + str(value)


func _sig(pat: CuePattern, b: CueFrac, e: CueFrac) -> Array[String]:
	var out: Array[String] = []
	for h: CueHap in _sorted(pat.onsets_in(b, e)):
		out.append("%s-%s:%s" % [str(h.whole.begin), str(h.whole.end), _value_tag(h.value)])
	out.sort()
	return out


func _split_sig(pat: CuePattern, cuts: Array[CueFrac]) -> Array[String]:
	var out: Array[String] = []
	for i in cuts.size() - 1:
		out.append_array(_sig(pat, cuts[i], cuts[i + 1]))
	out.sort()
	return out


func _same_sig(name: String, a: Array[String], b: Array[String]) -> void:
	check(name, a == b, "got %s, expected %s" % [str(a), str(b)])


func _remove_sig(base: Array[String], remove: Array[String]) -> Array[String]:
	var out: Array[String] = base.duplicate()
	for r: String in remove:
		var i := out.find(r)
		if i >= 0:
			out.remove_at(i)
	return out


func _codes(res: Dictionary) -> Array:
	var out: Array = []
	for err: Dictionary in res.get("errors", []):
		out.append(str(err.get("code", "")))
	return out


func _has_code(res: Dictionary, code: String) -> bool:
	return code in _codes(res)


func _initialize() -> void:
	_test_degrade()
	_test_determinism()
	_test_sometimes()
	_test_some_cycles()
	_test_every()
	_test_superimpose_off()
	_test_nested_random()
	_test_errors()
	_test_window_splitting()

	if failures.is_empty():
		print("PASS all cue lib random checks")
		quit(0)
	else:
		print("FAIL %d cue lib random checks" % failures.size())
		quit(1)


func _test_degrade() -> void:
	var plain := _state("s(\"hat*4\")")
	var plain_sig := _sig(plain, f(0), f(100))

	var pat := _state("s(\"hat*4\").degrade()")
	var count := _count(pat, f(0), f(100))
	check("degrade count", count >= 160 and count <= 240, "got %d" % count)
	var kept_sig := _sig(pat, f(0), f(100))
	var kept_only := true
	for s: String in kept_sig:
		if not (s in plain_sig):
			kept_only = false
			break
	check("degrade keeps plain onsets", kept_only, "kept %s" % str(kept_sig))

	check("degradeBy 0 count", _count(_state("s(\"hat*4\").degradeBy(0.0)"), f(0), f(100)) == 400)
	check("degradeBy 1 count", _count(_state("s(\"hat*4\").degradeBy(1.0)"), f(0), f(100)) == 0)
	var hard := _count(_state("s(\"hat*4\").degradeBy(0.9)"), f(0), f(100))
	check("degradeBy 0.9 count", hard >= 10 and hard <= 70, "got %d" % hard)

	var patterned := _state("s(\"hat*4\").degradeBy(\"<0 1>\")")
	check("degradeBy pattern cycle 0", _count(patterned, f(0), f(1)) == 4,
		"got %d" % _count(patterned, f(0), f(1)))
	check("degradeBy pattern cycle 1", _count(patterned, f(1), f(2)) == 0,
		"got %d" % _count(patterned, f(1), f(2)))


func _test_determinism() -> void:
	var layer := "s(\"hat*4\").degradeBy(0.5)"
	var a := _sig(_state(layer, 3), f(0), f(10))
	var b := _sig(_state(layer, 3), f(0), f(10))
	_same_sig("same seed same signature", a, b)
	var c := _sig(_state(layer, 4), f(0), f(10))
	check("different seed different signature", a != c, "seed 3 and 4 both gave %s" % str(a))

	var statement := _sig(_state(layer, 99, "seed 3\n"), f(0), f(10))
	_same_sig("seed statement overrides argument", statement, a)

	var two := _compile_layers([
		"s(\"hat*4\").degrade()",
		"s(\"hat*4\").degrade()",
	], 5)
	var first_res := CueLib.compile(_parse("state a:\n  s(\"hat*4\").degrade()\n"), 5)
	var first_pat: CuePattern = first_res["states"]["a"]
	var first := _sig(first_pat, f(0), f(10))
	var both: CuePattern = two["states"]["a"]
	var remainder := _remove_sig(_sig(both, f(0), f(10)), first)
	check("two degrade layers get different sites", remainder != first,
		"both layers kept the same events")

	var cuts: Array[CueFrac] = []
	for i in 11:
		cuts.append(f(i))
	var odd: Array[CueFrac] = [f(0), f(3, 10), f(1)]
	for layer2: String in [
		"s(\"hat*4\").degradeBy(0.5)",
		"s(\"hat*4\").sometimesBy(0.5, fast(2))",
		"s(\"hat*4\").someCyclesBy(0.5, fast(2))",
	]:
		var pat := _state(layer2, 7)
		var whole := _sig(pat, f(0), f(10))
		_same_sig("ten windows " + layer2, _split_sig(pat, cuts), whole)
		var whole_one := _sig(pat, f(0), f(1))
		_same_sig("tenth windows " + layer2, _split_sig(pat, odd), whole_one)


func _test_sometimes() -> void:
	var layer := "s(\"hat*4\").sometimesBy(%s, fast(2))"
	check("sometimesBy 0 count", _count(_state(layer % "0"), f(0), f(100)) == 400,
		"got %d" % _count(_state(layer % "0"), f(0), f(100)))
	check("sometimesBy 1 count", _count(_state(layer % "1"), f(0), f(100)) == 800,
		"got %d" % _count(_state(layer % "1"), f(0), f(100)))

	var expected := {
		"sometimes": [540, 660, 600],
		"often": [640, 760, 700],
		"rarely": [440, 560, 500],
		"almostNever": [400, 480, 440],
		"almostAlways": [700, 820, 760],
	}
	for name: String in expected:
		var bounds: Array = expected[name]
		var count := _count(_state("s(\"hat*4\")." + name + "(fast(2))"), f(0), f(100))
		check(name + " count", count >= int(bounds[0]) and count <= int(bounds[1]),
			"got %d, expected about %d" % [count, int(bounds[2])])

	check("sometimesBy 0.3 rev count",
		_count(_state("s(\"hat*4\").sometimesBy(0.3, rev())"), f(0), f(100)) == 400)
	check("sometimesBy 0.5 rev count",
		_count(_state("s(\"hat*4\").sometimesBy(0.5, rev())"), f(0), f(100)) == 400)


func _test_some_cycles() -> void:
	check("someCyclesBy 0 count", _count(_state("s(\"hat*4\").someCyclesBy(0, fast(2))"), f(0), f(100)) == 400)
	check("someCyclesBy 1 count", _count(_state("s(\"hat*4\").someCyclesBy(1, fast(2))"), f(0), f(100)) == 800)

	var pat := _state("s(\"hat*4\").someCycles(fast(2))", 7)
	var eight_cycles: Array[int] = []
	var sizes_ok := true
	for c in 100:
		var n := _count(pat, f(c), f(c + 1))
		if n == 8:
			eight_cycles.append(c)
		elif n != 4:
			sizes_ok = false
	check("someCycles sizes are 4 or 8", sizes_ok, "unexpected cycle size")
	check("someCycles eight count", eight_cycles.size() >= 30 and eight_cycles.size() <= 70,
		"got %d 8-onset cycles" % eight_cycles.size())
	var expected: Array[int] = []
	for c in 100:
		if CueSignals.hash01(7, 1, CueFrac.make(c)) < 0.5:
			expected.append(c)
	check("someCycles picks by hash", eight_cycles == expected,
		"got %s, expected %s" % [str(eight_cycles), str(expected)])


func _test_every() -> void:
	var pat := _state("n(\"0 1 2 3\").every(4, rev())")
	check("every 4 cycle 0", _vals(pat, f(0), f(1), "n") == [3.0, 2.0, 1.0, 0.0],
		str(_vals(pat, f(0), f(1), "n")))
	for c in [1, 2, 3]:
		check("every 4 cycle %d" % c, _vals(pat, f(c), f(c + 1), "n") == [0.0, 1.0, 2.0, 3.0],
			str(_vals(pat, f(c), f(c + 1), "n")))
	check("every 4 cycle 4", _vals(pat, f(4), f(5), "n") == [3.0, 2.0, 1.0, 0.0],
		str(_vals(pat, f(4), f(5), "n")))
	check("every 4 cycle 8", _vals(pat, f(8), f(9), "n") == [3.0, 2.0, 1.0, 0.0],
		str(_vals(pat, f(8), f(9), "n")))

	var fast2 := _state("n(\"0 1 2 3\").every(2, fast(2))")
	check("every 2 cycle 0", _count(fast2, f(0), f(1)) == 8, "got %d" % _count(fast2, f(0), f(1)))
	check("every 2 cycle 1", _count(fast2, f(1), f(2)) == 4, "got %d" % _count(fast2, f(1), f(2)))
	check("every 2 cycle 2", _count(fast2, f(2), f(3)) == 8, "got %d" % _count(fast2, f(2), f(3)))

	var every1 := _state("n(\"0 1 2 3\").every(1, fast(2))")
	var every1_ok := true
	for c in 4:
		if _count(every1, f(c), f(c + 1)) != 8:
			every1_ok = false
	check("every 1 all cycles", every1_ok, "expected 8 per cycle")

	for k: int in [0, -1]:
		var none := _state("n(\"0 1 2 3\").every(%d, fast(2))" % k)
		var none_ok := true
		for c in 4:
			if _count(none, f(c), f(c + 1)) != 4:
				none_ok = false
		check("every %d unchanged" % k, none_ok, "expected 4 per cycle")

	var patterned := _state("n(\"0 1 2 3\").every(\"<2 4>\", rev())")
	check("every pattern cycle 0", _vals(patterned, f(0), f(1), "n") == [3.0, 2.0, 1.0, 0.0],
		str(_vals(patterned, f(0), f(1), "n")))
	check("every pattern cycle 1", _vals(patterned, f(1), f(2), "n") == [0.0, 1.0, 2.0, 3.0],
		str(_vals(patterned, f(1), f(2), "n")))

	var chained := _state("n(\"0 1 2 3\").every(2, rev()).fast(2)")
	check("every then fast", _count(chained, f(0), f(1)) == 8 and _count(chained, f(1), f(2)) == 8,
		"got %d / %d" % [_count(chained, f(0), f(1)), _count(chained, f(1), f(2))])


func _test_superimpose_off() -> void:
	var sup := _state("n(\"0 1\").superimpose(fast(2))")
	check("superimpose count", _count(sup, f(0), f(1)) == 6, "got %d" % _count(sup, f(0), f(1)))

	var off := _state("note(\"48\").off(0.25, add(12))")
	var haps := _sorted(off.onsets_in(f(0), f(1)))
	var off_ok := haps.size() == 2
	if off_ok:
		off_ok = str(haps[0].whole.begin) == "0" and str(haps[0].whole.end) == "1" \
			and int((haps[0].value as Dictionary).get("note", -1)) == 48 \
			and str(haps[1].whole.begin) == "1/4" and str(haps[1].whole.end) == "5/4" \
			and int((haps[1].value as Dictionary).get("note", -1)) == 60
	check("off constant", off_ok, str(_sig(off, f(0), f(1))))

	var off_pat := _state("n(\"0\").off(\"<0.25 0.5>\", add(7))")
	var cycle0 := _vals(off_pat, f(0), f(1), "n")
	var cycle1 := _vals(off_pat, f(1), f(2), "n")
	check("off pattern cycle 0", cycle0 == [0.0, 7.0], str(cycle0))
	check("off pattern cycle 1", cycle1 == [0.0, 7.0], str(cycle1))
	var onsets0 := _sorted(off_pat.onsets_in(f(0), f(1)))
	var onsets1 := _sorted(off_pat.onsets_in(f(1), f(2)))
	var shifted0 := onsets0.size() == 2 and str(onsets0[1].whole.begin) == "1/4"
	var shifted1 := onsets1.size() == 2 and str(onsets1[1].whole.begin) == "3/2"
	check("off pattern shift 0", shifted0, str(_sig(off_pat, f(0), f(1))))
	check("off pattern shift 1", shifted1, str(_sig(off_pat, f(1), f(2))))

	var stacked := _state("s(\"a\").superimpose(rev()).superimpose(fast(2))")
	check("superimpose twice", _count(stacked, f(0), f(1)) == 6,
		"got %d" % _count(stacked, f(0), f(1)))


func _test_nested_random() -> void:
	var pat := _state("s(\"hat*4\").every(2, degradeBy(0.5))")
	check("every nested cycle 1", _count(pat, f(1), f(2)) == 4,
		"got %d" % _count(pat, f(1), f(2)))
	var even_count := 0
	for c in 100:
		if c % 2 == 0:
			even_count += _count(pat, f(c), f(c + 1))
	check("every nested even cycles", even_count >= 80 and even_count <= 120,
		"got %d" % even_count)

	var layer := "s(\"hat*4\").sometimesBy(0.5, degradeBy(0.5))"
	var a := _sig(_state(layer, 11), f(0), f(10))
	var b := _sig(_state(layer, 11), f(0), f(10))
	_same_sig("nested random deterministic", a, b)


func _test_errors() -> void:
	var res := _compile("s(\"a\").every(2, 3)")
	check("every wrong transform kind", _has_code(res, "E_KIND"), str(_codes(res)))
	var pattern: CuePattern = res["states"]["a"]
	check("every wrong transform queryable", pattern.onsets_in(f(0), f(1)) is Array,
		"query did not return an array")

	var missing := _compile("s(\"a\").off(0.25)")
	check("off arity", _has_code(missing, "E_ARITY"), str(_codes(missing)))


func _test_window_splitting() -> void:
	var cases := [
		"s(\"hat*4\").degradeBy(0.5)",
		"s(\"hat*4\").sometimesBy(0.5, fast(2))",
		"s(\"hat*4\").someCyclesBy(0.5, fast(2))",
		"n(\"0 1 2 3\").every(3, rev())",
		"n(\"0 1 2 3\").off(0.25, add(7))",
		"s(\"hat*4\").superimpose(fast(2))",
	]
	var cuts1: Array[CueFrac] = [f(0), f(37, 100), f(1), f(3), f(4)]
	var cuts2: Array[CueFrac] = [f(0), f(1, 7), f(2, 3), f(5, 4), f(4)]
	for layer: String in cases:
		var pat := _state(layer, 7)
		var whole := _sig(pat, f(0), f(4))
		_same_sig("window split 1 " + layer, _split_sig(pat, cuts1), whole)
		_same_sig("window split 2 " + layer, _split_sig(pat, cuts2), whole)
