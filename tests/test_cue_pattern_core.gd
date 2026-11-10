extends SceneTree
# CueSpan, CueHap and CuePattern: constructors (pure, silence, seq, cat,
# timecat, stack), time transforms (fast, slow, early, late), window splitting
# invariance and the hap onset rules.
# Run: Godot --headless --path project -s ../tests/test_cue_pattern_core.gd
# Exits with code 0 when every check passes, 1 otherwise.

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func f(n: int, d: int = 1) -> CueFrac:
	return CueFrac.make(n, d)

func sig(haps: Array[CueHap]) -> Array[String]:
	var out: Array[String] = []
	for h in haps:
		out.append("%s | %s | %s" % [str(h.whole), str(h.part), str(h.value)])
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
	check(name, got == expected, "got %s, expected %s" % [str(got), str(expected)])

func eqonsets(name: String, haps: Array[CueHap], expected: Array[String]) -> void:
	var got := onset_sig(haps)
	check(name, got == expected, "got %s, expected %s" % [str(got), str(expected)])

func span_sig(spans: Array[CueSpan]) -> String:
	var parts: Array[String] = []
	for s in spans:
		parts.append(str(s))
	return " ".join(parts)

func cat_values(pat: CuePattern, cycles: int) -> Array[int]:
	var out: Array[int] = []
	for c in range(cycles):
		var haps := pat.query_arc(f(c), f(c + 1))
		if haps.size() != 1:
			check("cat cycle %d single hap" % c, false, "got %d haps" % haps.size())
			return out
		out.append(int(haps[0].value))
	return out

func _initialize() -> void:
	var a := CuePattern.pure("a")
	var b := CuePattern.pure("b")
	var c := CuePattern.pure("c")

	# 1. pure over one cycle.
	var h1 := CuePattern.pure(1).query_arc(f(0), f(1))
	eqsig("pure one cycle", h1, ["[0, 1) | [0, 1) | 1"])
	check("pure one cycle onset", h1.size() == 1 and h1[0].has_onset(), "size %d" % h1.size())

	# 2. pure split across a window boundary.
	var h2 := CuePattern.pure(1).query_arc(f(1, 2), f(3, 2))
	eqsig("pure split window", h2, ["[0, 1) | [1/2, 1) | 1", "[1, 2) | [1, 3/2) | 1"])
	check("pure split first no onset", h2.size() == 2 and not h2[0].has_onset(), "size %d" % h2.size())
	check("pure split second onset", h2.size() == 2 and h2[1].has_onset(), "size %d" % h2.size())

	# 3. Zero-width query.
	eqsig("pure zero width", CuePattern.pure(1).query_arc(f(1, 2), f(1, 2)), ["[0, 1) | [1/2, 1/2) | 1"])

	# 4. silence.
	check("silence empty", CuePattern.silence().query_arc(f(0), f(4)).is_empty(), "non-empty")

	# 5. seq repeats each cycle.
	eqsig("seq one cycle", CuePattern.seq([CuePattern.pure(1), CuePattern.pure(2)]).query_arc(f(0), f(1)),
		["[0, 1/2) | [0, 1/2) | 1", "[1/2, 1) | [1/2, 1) | 2"])
	eqsig("seq two cycles", CuePattern.seq([CuePattern.pure(1), CuePattern.pure(2)]).query_arc(f(0), f(2)),
		["[0, 1/2) | [0, 1/2) | 1", "[1, 3/2) | [1, 3/2) | 1",
		"[1/2, 1) | [1/2, 1) | 2", "[3/2, 2) | [3/2, 2) | 2"])

	# 6. seq of three, empty and one.
	eqsig("seq three", CuePattern.seq([a, b, c]).query_arc(f(0), f(1)),
		["[0, 1/3) | [0, 1/3) | a", "[1/3, 2/3) | [1/3, 2/3) | b", "[2/3, 1) | [2/3, 1) | c"])
	check("seq empty is silence", CuePattern.seq([]).query_arc(f(0), f(1)).is_empty(), "non-empty")
	eqsig("seq one equals pattern", CuePattern.seq([a]).query_arc(f(0), f(1)), sig(a.query_arc(f(0), f(1))))

	# 7. Nested seq.
	eqsig("nested seq", CuePattern.seq([a, CuePattern.seq([b, c])]).query_arc(f(0), f(1)),
		["[0, 1/2) | [0, 1/2) | a", "[1/2, 3/4) | [1/2, 3/4) | b", "[3/4, 1) | [3/4, 1) | c"])

	# 8. cat: one pattern per cycle, negative cycles included.
	var cat3 := CuePattern.cat([CuePattern.pure(1), CuePattern.pure(2), CuePattern.pure(3)])
	check("cat cycles 0..4", cat_values(cat3, 5) == [1, 2, 3, 1, 2], str(cat_values(cat3, 5)))
	eqsig("cat negative cycle", cat3.query_arc(f(-1), f(0)), ["[-1, 0) | [-1, 0) | 3"])

	# 9. cat offsets nested patterns by their own cycle count.
	var nested_cat := CuePattern.cat([CuePattern.cat([CuePattern.pure(1), CuePattern.pure(2)]), CuePattern.pure(9)])
	check("cat offset cycles 0..4", cat_values(nested_cat, 5) == [1, 9, 2, 9, 1], str(cat_values(nested_cat, 5)))

	# 10. cat with a seq per cycle.
	var cat_seq := CuePattern.cat([CuePattern.seq([a, b]), c])
	eqsig("cat seq cycle 0", cat_seq.query_arc(f(0), f(1)),
		["[0, 1/2) | [0, 1/2) | a", "[1/2, 1) | [1/2, 1) | b"])
	eqsig("cat seq cycle 1", cat_seq.query_arc(f(1), f(2)), ["[1, 2) | [1, 2) | c"])
	eqsig("cat seq cycle 2", cat_seq.query_arc(f(2), f(3)),
		["[2, 5/2) | [2, 5/2) | a", "[5/2, 3) | [5/2, 3) | b"])

	# 11. timecat compresses each pattern into its share of the cycle.
	var tc := CuePattern.timecat([[1, a], [3, b]])
	eqsig("timecat 1:3 cycle 0", tc.query_arc(f(0), f(1)),
		["[0, 1/4) | [0, 1/4) | a", "[1/4, 1) | [1/4, 1) | b"])
	eqsig("timecat 1:3 cycle 1", tc.query_arc(f(1), f(2)),
		["[1, 5/4) | [1, 5/4) | a", "[5/4, 2) | [5/4, 2) | b"])
	eqsig("timecat 2:1:1", CuePattern.timecat([[2, a], [1, b], [1, c]]).query_arc(f(0), f(1)),
		["[0, 1/2) | [0, 1/2) | a", "[1/2, 3/4) | [1/2, 3/4) | b", "[3/4, 1) | [3/4, 1) | c"])

	# 12. stack layers patterns.
	eqsig("stack", CuePattern.stack([CuePattern.pure(1), CuePattern.pure(2)]).query_arc(f(0), f(1)),
		["[0, 1) | [0, 1) | 1", "[0, 1) | [0, 1) | 2"])

	# 13. fast.
	eqsig("fast pure", CuePattern.pure(1).fast(f(2)).query_arc(f(0), f(1)),
		["[0, 1/2) | [0, 1/2) | 1", "[1/2, 1) | [1/2, 1) | 1"])
	eqsig("fast seq 3/2", CuePattern.seq([a, b]).fast(f(3, 2)).query_arc(f(0), f(1)),
		["[0, 1/3) | [0, 1/3) | a", "[1/3, 2/3) | [1/3, 2/3) | b", "[2/3, 1) | [2/3, 1) | a"])
	check("fast zero is silence", CuePattern.pure(1).fast(f(0)).query_arc(f(0), f(1)).is_empty(), "non-empty")

	# 14. slow.
	var slow_pure := CuePattern.pure(1).slow(f(2))
	eqsig("slow cycle 0", slow_pure.query_arc(f(0), f(1)), ["[0, 2) | [0, 1) | 1"])
	var slow_h := slow_pure.query_arc(f(0), f(1))
	check("slow cycle 0 onset", slow_h.size() == 1 and slow_h[0].has_onset(), "size %d" % slow_h.size())
	var slow_h2 := slow_pure.query_arc(f(1), f(2))
	eqsig("slow cycle 1", slow_h2, ["[0, 2) | [1, 2) | 1"])
	check("slow cycle 1 no onset", slow_h2.size() == 1 and not slow_h2[0].has_onset(), "size %d" % slow_h2.size())
	eqsig("slow seq", CuePattern.seq([a, b]).slow(f(2)).query_arc(f(0), f(2)),
		["[0, 1) | [0, 1) | a", "[1, 2) | [1, 2) | b"])

	# 15. early.
	var early_pat := CuePattern.seq([a, b]).early(f(1, 4))
	eqsig("early", early_pat.query_arc(f(0), f(1)),
		["[-1/4, 1/4) | [0, 1/4) | a", "[1/4, 3/4) | [1/4, 3/4) | b", "[3/4, 5/4) | [3/4, 1) | a"])
	eqonsets("early onsets", early_pat.onsets_in(f(0), f(1)), ["1/4-3/4:b", "3/4-5/4:a"])

	# 16. late.
	var late_pat := CuePattern.seq([a, b]).late(f(1, 4))
	eqsig("late", late_pat.query_arc(f(0), f(1)),
		["[-1/4, 1/4) | [0, 1/4) | b", "[1/4, 3/4) | [1/4, 3/4) | a", "[3/4, 5/4) | [3/4, 1) | b"])
	eqonsets("late onsets", late_pat.onsets_in(f(0), f(1)), ["1/4-3/4:a", "3/4-5/4:b"])

	# 17. fmap and filter_values.
	eqsig("fmap", CuePattern.pure(1).fmap(func(v): return v + 1).query_arc(f(0), f(1)),
		["[0, 1) | [0, 1) | 2"])
	eqsig("filter_values", CuePattern.seq([CuePattern.pure(1), CuePattern.pure(2)]).filter_values(func(v): return v > 1).query_arc(f(0), f(1)),
		["[1/2, 1) | [1/2, 1) | 2"])

	# 18. Zero-width query through seq.
	var zero_h := CuePattern.seq([CuePattern.pure(1), CuePattern.pure(2)]).query_arc(f(1, 2), f(1, 2))
	eqsig("seq zero width", zero_h, ["[1/2, 1) | [1/2, 1/2) | 2"])
	check("seq zero width onset", zero_h.size() == 1 and zero_h[0].has_onset(), "size %d" % zero_h.size())

	# 19. span_cycles and intersection.
	var sp_0_1 := CueSpan.make(f(0), f(1))
	check("span_cycles [0,1)", span_sig(sp_0_1.span_cycles()) == "[0, 1)", span_sig(sp_0_1.span_cycles()))
	var sp_half_5_2 := CueSpan.make(f(1, 2), f(5, 2))
	check("span_cycles [1/2,5/2)", span_sig(sp_half_5_2.span_cycles()) == "[1/2, 1) [1, 2) [2, 5/2)", span_sig(sp_half_5_2.span_cycles()))
	var sp_zero := CueSpan.make(f(1, 2), f(1, 2))
	check("span_cycles zero width", sp_zero.span_cycles().size() == 1, span_sig(sp_zero.span_cycles()))
	check("span_cycles [1,2)", span_sig(CueSpan.make(f(1), f(2)).span_cycles()) == "[1, 2)", span_sig(CueSpan.make(f(1), f(2)).span_cycles()))
	var inter := sp_0_1.intersection(CueSpan.make(f(1, 2), f(2)))
	check("intersection overlap", inter != null and str(inter) == "[1/2, 1)", str(inter))
	check("intersection touching", sp_0_1.intersection(CueSpan.make(f(1), f(2))) == null, str(sp_0_1.intersection(CueSpan.make(f(1), f(2)))))
	check("intersection disjoint", sp_0_1.intersection(CueSpan.make(f(2), f(3))) == null, str(sp_0_1.intersection(CueSpan.make(f(2), f(3)))))

	# 20. Window-splitting invariance: onsets from one window equal the union
	# of the onsets from any partition of it.
	var names: Array[String] = []
	var pats: Array[CuePattern] = []
	names.append("pure a")
	pats.append(CuePattern.pure("a"))
	names.append("seq abc")
	pats.append(CuePattern.seq([a, b, c]))
	names.append("cat ab")
	pats.append(CuePattern.cat([a, b]))
	names.append("cat seq c")
	pats.append(CuePattern.cat([CuePattern.seq([a, b]), c]))
	names.append("timecat")
	pats.append(CuePattern.timecat([[1, a], [3, b]]))
	names.append("stack seq")
	pats.append(CuePattern.stack([a, CuePattern.seq([b, c])]))
	names.append("seq fast")
	pats.append(CuePattern.seq([a, b]).fast(f(3, 2)))
	names.append("seq slow")
	pats.append(CuePattern.seq([a, b, c]).slow(f(2)))
	names.append("seq early")
	pats.append(CuePattern.seq([a, b]).early(f(1, 4)))
	names.append("seq late")
	pats.append(CuePattern.seq([a, b]).late(f(1, 3)))
	names.append("seq cat fast")
	pats.append(CuePattern.seq([a, CuePattern.cat([b, c])]).fast(f(2)))
	names.append("slow 3")
	pats.append(a.slow(f(3)))
	names.append("slow 3/2")
	pats.append(a.slow(f(3, 2)))
	for idx in range(pats.size()):
		var p: CuePattern = pats[idx]
		var whole := onset_sig(p.onsets_in(f(0), f(2)))
		var split: Array[String] = []
		split.append_array(onset_sig(p.onsets_in(f(0), f(37, 100))))
		split.append_array(onset_sig(p.onsets_in(f(37, 100), f(1))))
		split.append_array(onset_sig(p.onsets_in(f(1), f(2))))
		split.sort()
		check("window split %s" % names[idx], whole == split, "got %s, expected %s" % [str(whole), str(split)])
		var split4: Array[String] = []
		split4.append_array(onset_sig(p.onsets_in(f(0), f(1, 7))))
		split4.append_array(onset_sig(p.onsets_in(f(1, 7), f(2, 3))))
		split4.append_array(onset_sig(p.onsets_in(f(2, 3), f(5, 4))))
		split4.append_array(onset_sig(p.onsets_in(f(5, 4), f(2))))
		split4.sort()
		check("window split4 %s" % names[idx], whole == split4, "got %s, expected %s" % [str(whole), str(split4)])

	# slow(3) keeps exactly one onset across its three cycles.
	var slow3 := a.slow(f(3))
	var slow3_onsets: Array[String] = []
	slow3_onsets.append_array(onset_sig(slow3.onsets_in(f(0), f(1))))
	slow3_onsets.append_array(onset_sig(slow3.onsets_in(f(1), f(2))))
	slow3_onsets.append_array(onset_sig(slow3.onsets_in(f(2), f(3))))
	check("slow 3 one onset across cycles", slow3_onsets == ["0-3:a"], str(slow3_onsets))

	if failures.is_empty():
		print("PASS all cue pattern core checks")
		quit(0)
	else:
		print("FAIL %d cue pattern core checks" % failures.size())
		quit(1)
