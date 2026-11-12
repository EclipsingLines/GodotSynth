extends SceneTree
# Mini-notation compiler: sequences, weights, cats, subs, stacks, choices,
# fast/slow, replicate, degrade, euclid and window-splitting invariance.
# Run: bash tests/verify.sh --no-build tests/test_cue_mini_compile.gd
# Exits with code 0 when every check passes, 1 otherwise.

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func f(n: int, d: int = 1) -> CueFrac:
	return CueFrac.make(n, d)

func compile_text(text: String, atom_fn: Callable = Callable(), seed: int = 0, site: int = 1) -> CuePattern:
	var parsed := CueMini.parse(text)
	if not parsed["ok"]:
		check("parse " + text, false, "error at %d: %s" % [parsed["error"]["col"], parsed["error"]["message"]])
		return CuePattern.silence()
	var fn := atom_fn
	if not fn.is_valid():
		fn = func(a: Dictionary) -> Variant: return a["text"]
	return CueMiniCompiler.compile(parsed["ast"], fn, seed, site)

func sig(haps: Array[CueHap]) -> Array[String]:
	var out: Array[String] = []
	for h in haps:
		var s: CueSpan = h.whole if h.whole != null else h.part
		out.append("%s-%s:%s" % [str(s.begin), str(s.end), str(h.value)])
	out.sort()
	return out

func onset_sig(haps: Array[CueHap]) -> Array[String]:
	var out: Array[String] = []
	for h in haps:
		if h.has_onset():
			out.append("%s-%s:%s" % [str(h.whole.begin), str(h.whole.end), str(h.value)])
	out.sort()
	return out

func eqsig(name: String, haps: Array[CueHap], expected: Array[String]) -> void:
	var got := sig(haps)
	var exp: Array[String] = []
	exp.append_array(expected)
	exp.sort()
	check(name, got == exp, "got %s, expected %s" % [str(got), str(exp)])

func eqonsets(name: String, haps: Array[CueHap], expected: Array[String]) -> void:
	var got := onset_sig(haps)
	var exp: Array[String] = []
	exp.append_array(expected)
	exp.sort()
	check(name, got == exp, "got %s, expected %s" % [str(got), str(exp)])

func sorted_haps(haps: Array[CueHap]) -> Array[CueHap]:
	var out: Array[CueHap] = []
	out.append_array(haps)
	out.sort_custom(func(x: CueHap, y: CueHap) -> bool:
		return x.whole_or_part().begin.lt(y.whole_or_part().begin))
	return out

func joined_values(haps: Array[CueHap]) -> String:
	var ordered := sorted_haps(haps)
	var vals: Array[String] = []
	for h in ordered:
		vals.append(str(h.value))
	return " ".join(vals)

func kept_cycles(haps: Array[CueHap]) -> Array[int]:
	var out: Array[int] = []
	for h in haps:
		if h.whole != null:
			out.append(h.whole.begin.cycle())
	out.sort()
	return out

func cycle_count(haps: Array[CueHap], c: int) -> int:
	var n := 0
	for h in haps:
		if h.whole != null and h.whole.begin.cycle() == c:
			n += 1
	return n

func check_window_split(name: String, pat: CuePattern, full_b: CueFrac, full_e: CueFrac, windows_a: Array, windows_b: Array) -> void:
	var whole := onset_sig(pat.onsets_in(full_b, full_e))
	var split_a: Array[String] = []
	for entry in windows_a:
		var w: Array = entry
		split_a.append_array(onset_sig(pat.onsets_in(w[0], w[1])))
	split_a.sort()
	check("window split %s" % name, whole == split_a, "got %s, expected %s" % [str(split_a), str(whole)])
	var split_b: Array[String] = []
	for entry in windows_b:
		var w: Array = entry
		split_b.append_array(onset_sig(pat.onsets_in(w[0], w[1])))
	split_b.sort()
	check("window split4 %s" % name, whole == split_b, "got %s, expected %s" % [str(split_b), str(whole)])

func _initialize() -> void:
	# 1. Sequence: steps share the cycle equally.
	eqsig("a b c", compile_text("a b c").query_arc(f(0), f(1)),
		["0-1/3:a", "1/3-2/3:b", "2/3-1:c"])

	# 2. Rest.
	eqsig("a ~ b", compile_text("a ~ b").query_arc(f(0), f(1)),
		["0-1/3:a", "2/3-1:b"])

	# 3. Subsequence in one step.
	eqsig("a [b c]", compile_text("a [b c]").query_arc(f(0), f(1)),
		["0-1/2:a", "1/2-3/4:b", "3/4-1:c"])

	# 4. Weights.
	eqsig("a@3 b", compile_text("a@3 b").query_arc(f(0), f(1)),
		["0-3/4:a", "3/4-1:b"])
	eqsig("a b@2", compile_text("a b@2").query_arc(f(0), f(1)),
		["0-1/3:a", "1/3-1:b"])

	# 5. Cats (slowcat) and cat-in-stack.
	var cat3 := compile_text("<a b c>")
	for c in 4:
		var v: String = "abc"[c % 3]
		eqsig("<a b c> cycle %d" % c, cat3.query_arc(f(c), f(c + 1)),
			["%d-%d:%s" % [c, c + 1, v]])
	var cat_c := compile_text("<a b> c")
	eqsig("<a b> c cycle 0", cat_c.query_arc(f(0), f(1)), ["0-1/2:a", "1/2-1:c"])
	eqsig("<a b> c cycle 1", cat_c.query_arc(f(1), f(2)), ["1-3/2:b", "3/2-2:c"])
	eqsig("<a b> c cycle 2", cat_c.query_arc(f(2), f(3)), ["2-5/2:a", "5/2-3:c"])
	eqsig("<a [b c]> cycle 1", compile_text("<a [b c]>").query_arc(f(1), f(2)),
		["1-3/2:b", "3/2-2:c"])
	var cat_stack := compile_text("<a b, c d e>")
	eqsig("<a b, c d e> cycle 0", cat_stack.query_arc(f(0), f(1)), ["0-1:a", "0-1:c"])
	eqsig("<a b, c d e> cycle 1", cat_stack.query_arc(f(1), f(2)), ["1-2:b", "1-2:d"])
	eqsig("<a b, c d e> cycle 2", cat_stack.query_arc(f(2), f(3)), ["2-3:a", "2-3:e"])

	# 6. Fast.
	eqsig("a*2", compile_text("a*2").query_arc(f(0), f(1)),
		["0-1/2:a", "1/2-1:a"])
	eqsig("a*2 b", compile_text("a*2 b").query_arc(f(0), f(1)),
		["0-1/4:a", "1/4-1/2:a", "1/2-1:b"])
	eqsig("[a b]*2", compile_text("[a b]*2").query_arc(f(0), f(1)),
		["0-1/4:a", "1/4-1/2:b", "1/2-3/4:a", "3/4-1:b"])
	var fast15 := compile_text("a*1.5")
	eqonsets("a*1.5 onsets [0,2)", fast15.onsets_in(f(0), f(2)),
		["0-2/3:a", "2/3-4/3:a", "4/3-2:a"])
	check("a*1.5 onset count", fast15.onsets_in(f(0), f(2)).size() == 3,
		"got %d" % fast15.onsets_in(f(0), f(2)).size())

	# 7. Slow: one hap spanning two cycles, onset only in the first.
	var slow2 := compile_text("a/2")
	var slow0 := slow2.query_arc(f(0), f(1))
	var slow1 := slow2.query_arc(f(1), f(2))
	check("a/2 first window haps", slow0.size() == 1, "got %d" % slow0.size())
	if slow0.size() == 1:
		var h := slow0[0]
		check("a/2 first whole", h.whole != null and h.whole.begin.eq(f(0)) and h.whole.end.eq(f(2)),
			str(h))
		check("a/2 first part", h.part.begin.eq(f(0)) and h.part.end.eq(f(1)), str(h))
		check("a/2 first onset", h.has_onset(), str(h))
	check("a/2 second window haps", slow1.size() == 1, "got %d" % slow1.size())
	if slow1.size() == 1:
		var h := slow1[0]
		check("a/2 second whole", h.whole != null and h.whole.begin.eq(f(0)) and h.whole.end.eq(f(2)),
			str(h))
		check("a/2 second part", h.part.begin.eq(f(1)) and h.part.end.eq(f(2)), str(h))
		check("a/2 second no onset", not h.has_onset(), str(h))
	check("a/2 onsets [0,2)", slow2.onsets_in(f(0), f(2)).size() == 1,
		"got %d" % slow2.onsets_in(f(0), f(2)).size())
	eqsig("[a b]/2 cycle 0", compile_text("[a b]/2").query_arc(f(0), f(1)), ["0-1:a"])
	eqsig("[a b]/2 cycle 1", compile_text("[a b]/2").query_arc(f(1), f(2)), ["1-2:b"])

	# 8. Patterned fast/slow factors.
	var fast_pat := compile_text("a*<2 3>")
	eqsig("a*<2 3> cycle 0", fast_pat.query_arc(f(0), f(1)), ["0-1/2:a", "1/2-1:a"])
	eqsig("a*<2 3> cycle 1", fast_pat.query_arc(f(1), f(2)), ["1-4/3:a", "4/3-5/3:a", "5/3-2:a"])
	eqsig("a*<2 3> cycle 2", fast_pat.query_arc(f(2), f(3)), ["2-5/2:a", "5/2-3:a"])
	eqsig("a*<2 3> cycle 3", fast_pat.query_arc(f(3), f(4)),
		["3-10/3:a", "10/3-11/3:a", "11/3-4:a"])
	var slow_pat := compile_text("a/<2 4>")
	eqsig("a/<2 4> cycle 0", slow_pat.query_arc(f(0), f(1)), ["0-2:a"])

	# 9. Replication and bare repeat_prev.
	eqsig("a!3", compile_text("a!3").query_arc(f(0), f(1)),
		["0-1/3:a", "1/3-2/3:a", "2/3-1:a"])
	eqsig("a!", compile_text("a!").query_arc(f(0), f(1)),
		["0-1/2:a", "1/2-1:a"])
	eqsig("a ! b", compile_text("a ! b").query_arc(f(0), f(1)),
		["0-1/3:a", "1/3-2/3:a", "2/3-1:b"])
	eqsig("a b!2", compile_text("a b!2").query_arc(f(0), f(1)),
		["0-1/3:a", "1/3-2/3:b", "2/3-1:b"])
	eqsig("[a b]!2", compile_text("[a b]!2").query_arc(f(0), f(1)),
		["0-1/4:a", "1/4-1/2:b", "1/2-3/4:a", "3/4-1:b"])

	# 10. Stack.
	eqsig("a , b", compile_text("a , b").query_arc(f(0), f(1)), ["0-1:a", "0-1:b"])
	eqsig("a b, c", compile_text("a b, c").query_arc(f(0), f(1)),
		["0-1/2:a", "1/2-1:b", "0-1:c"])
	eqsig("[a, b c]", compile_text("[a, b c]").query_arc(f(0), f(1)),
		["0-1:a", "0-1/2:b", "1/2-1:c"])

	# 11. Euclidean rhythms.
	eqonsets("a(3,8)", compile_text("a(3,8)").onsets_in(f(0), f(1)),
		["0-1/8:a", "3/8-1/2:a", "3/4-7/8:a"])
	eqonsets("a(3,8,2)", compile_text("a(3,8,2)").onsets_in(f(0), f(1)),
		["1/8-1/4:a", "1/2-5/8:a", "3/4-7/8:a"])
	eqonsets("a(5,8)", compile_text("a(5,8)").onsets_in(f(0), f(1)),
		["0-1/8:a", "1/4-3/8:a", "3/8-1/2:a", "5/8-3/4:a", "3/4-7/8:a"])
	eqonsets("a(3,8) b", compile_text("a(3,8) b").onsets_in(f(0), f(1)),
		["0-1/16:a", "3/16-1/4:a", "3/8-7/16:a", "1/2-1:b"])
	check("a(3,8)*2 onsets", compile_text("a(3,8)*2").onsets_in(f(0), f(1)).size() == 6,
		"got %d" % compile_text("a(3,8)*2").onsets_in(f(0), f(1)).size())

	# 12. Atoms: suffixes, numbers and null.
	var suffix_atom := func(a: Dictionary) -> Variant: return String(a["text"]) + "/" + String(a["suffix"])
	eqsig("bd:3 sn", compile_text("bd:3 sn", suffix_atom).query_arc(f(0), f(1)),
		["0-1/2:bd/3", "1/2-1:sn/"])
	eqsig("C:minor", compile_text("C:minor", suffix_atom).query_arc(f(0), f(1)),
		["0-1:C/minor"])
	var number_atom := func(a: Dictionary) -> Variant: return String(a["text"]).to_float()
	var numbers := sorted_haps(compile_text("0 -3 2.5", number_atom).query_arc(f(0), f(1)))
	var numbers_ok := numbers.size() == 3
	if numbers_ok:
		numbers_ok = is_equal_approx(float(numbers[0].value), 0.0) \
			and is_equal_approx(float(numbers[1].value), -3.0) \
			and is_equal_approx(float(numbers[2].value), 2.5)
	check("numeric atoms", numbers_ok, str(numbers))
	var null_atom := func(a: Dictionary) -> Variant:
		if String(a["text"]) == "x":
			return null
		return a["text"]
	eqsig("null atom", compile_text("a x b", null_atom).query_arc(f(0), f(1)),
		["0-1/3:a", "2/3-1:b"])

	# 13. Rests are silent.
	check("~ empty", compile_text("~").query_arc(f(0), f(1)).is_empty(),
		str(compile_text("~").query_arc(f(0), f(1))))
	check("~ ~ empty", compile_text("~ ~").query_arc(f(0), f(1)).is_empty(),
		str(compile_text("~ ~").query_arc(f(0), f(1))))

	# 14. Seeded degradation.
	var degrade := compile_text("a?", Callable(), 7, 1)
	var degrade_haps := degrade.query_arc(f(0), f(200))
	var expected_kept: Array[int] = []
	for c in 200:
		if CueSignals.hash01(7, 1024, f(c)) >= 0.5:
			expected_kept.append(c)
	var kept := kept_cycles(degrade_haps)
	check("a? exact kept cycles", kept == expected_kept, "got %s, expected %s" % [str(kept), str(expected_kept)])
	check("a? kept count", kept.size() >= 80 and kept.size() <= 120, "got %d" % kept.size())
	var degrade_sig := sig(degrade_haps)
	check("a? deterministic", sig(compile_text("a?", Callable(), 7, 1).query_arc(f(0), f(200))) == degrade_sig,
		"signatures differ")
	check("a? changes with seed", sig(compile_text("a?", Callable(), 8, 1).query_arc(f(0), f(200))) != degrade_sig,
		"same signature for seed 8")
	check("a? changes with site", sig(compile_text("a?", Callable(), 7, 2).query_arc(f(0), f(200))) != degrade_sig,
		"same signature for site 2")
	var degrade03 := compile_text("a?0.3", Callable(), 7, 1).query_arc(f(0), f(200))
	check("a?0.3 kept count", degrade03.size() >= 120 and degrade03.size() <= 160,
		"got %d" % degrade03.size())
	var degrade_fast := compile_text("a*4?", Callable(), 0, 1).query_arc(f(0), f(50))
	check("a*4? kept count", degrade_fast.size() >= 80 and degrade_fast.size() <= 120,
		"got %d" % degrade_fast.size())

	# 15. Choices.
	var choice := compile_text("a|b", Callable(), 0, 1)
	var a_count := 0
	var one_per_cycle := true
	for c in 200:
		var ch := choice.query_arc(f(c), f(c + 1))
		if ch.size() != 1:
			one_per_cycle = false
			continue
		var h := ch[0]
		if h.whole == null or not h.whole.begin.eq(f(c)) or not h.whole.end.eq(f(c + 1)):
			one_per_cycle = false
		if str(h.value) == "a":
			a_count += 1
	check("a|b one hap per cycle", one_per_cycle, "cycle with missing/extra haps")
	check("a|b a count", a_count >= 70 and a_count <= 130, "got %d" % a_count)
	var choice_sig := sig(choice.query_arc(f(0), f(200)))
	check("a|b deterministic", sig(compile_text("a|b", Callable(), 0, 1).query_arc(f(0), f(200))) == choice_sig,
		"signatures differ")
	check("a|b changes with seed", sig(compile_text("a|b", Callable(), 1, 1).query_arc(f(0), f(200))) != choice_sig,
		"same signature for seed 1")

	var pick3 := compile_text("a b | c d | e", Callable(), 0, 1)
	var options := ["a b", "c d", "e"]
	var seen := {}
	var exact_picks := true
	for c in 200:
		var got := joined_values(pick3.query_arc(f(c), f(c + 1)))
		seen[got] = true
		if not (got in options):
			exact_picks = false
		if c < 20:
			var i := mini(floori(CueSignals.hash01(0, 1024, f(c)) * 3.0), 2)
			if got != options[i]:
				exact_picks = false
				check("pick3 cycle %d" % c, false, "got %s, expected %s" % [got, options[i]])
	check("pick3 values", exact_picks, str(seen))
	check("pick3 all options", seen.has("a b") and seen.has("c d") and seen.has("e"), str(seen))

	var independent := compile_text("[a|b] [c|d]", Callable(), 0, 1)
	var combos := {}
	var independent_ok := true
	for c in 200:
		var ch := independent.query_arc(f(c), f(c + 1))
		if ch.size() != 2:
			independent_ok = false
			continue
		var vals: Array[String] = [str(ch[0].value), str(ch[1].value)]
		vals.sort()
		combos[vals[0] + "/" + vals[1]] = true
	check("independent choice haps", independent_ok, "cycle without exactly two haps")
	check("independent choice combos", combos.size() == 4,
		"got %s" % str(combos))

	# 16. Replicas of a degraded step draw independent sites.
	var degrade_rep := compile_text("a?!2", Callable(), 0, 1).query_arc(f(0), f(200))
	var exactly_one := 0
	for c in 200:
		if cycle_count(degrade_rep, c) == 1:
			exactly_one += 1
	check("a?!2 exactly one survives", exactly_one > 40, "got %d" % exactly_one)

	# 17. Window-splitting invariance for onsets.
	var windows_a := [[f(0), f(37, 100)], [f(37, 100), f(1)], [f(1), f(2)]]
	var windows_b := [[f(0), f(1, 7)], [f(1, 7), f(2, 3)], [f(2, 3), f(5, 4)], [f(5, 4), f(2)]]
	var invariance := [
		"a b c", "<a b> [c d]*2", "a(3,8,2)", "a/2", "a@3 b",
		"a? b?", "a|b c", "[a|b]*2", "<a b, c d e>",
	]
	for source: String in invariance:
		check_window_split(source, compile_text(source), f(0), f(2), windows_a, windows_b)
	var windows_a4 := [
		[f(0), f(37, 100)], [f(37, 100), f(1)], [f(1), f(2)],
		[f(2), f(237, 100)], [f(237, 100), f(3)], [f(3), f(4)],
	]
	var windows_b4 := [
		[f(0), f(1, 7)], [f(1, 7), f(2, 3)], [f(2, 3), f(5, 4)], [f(5, 4), f(2)],
		[f(2), f(15, 7)], [f(15, 7), f(8, 3)], [f(8, 3), f(13, 4)], [f(13, 4), f(4)],
	]
	check_window_split("a*<2 3> [0,4)", compile_text("a*<2 3>"), f(0), f(4), windows_a4, windows_b4)

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
