extends SceneTree
# Cue pattern ops: rev, struct, mask, segment, range, signals, seeded hash,
# joins (app_left, patternify_inner), ply, iter, palindrome, slowcat_prime,
# euclid/degrade_by and window-splitting invariance.
# Run: bash tests/verify.sh --no-build tests/test_cue_pattern_ops.gd
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

func onset_starts(haps: Array[CueHap]) -> Array[String]:
	var out: Array[String] = []
	for h in haps:
		if h.has_onset():
			out.append(str(h.whole.begin))
	out.sort()
	return out

func span_sig(haps: Array[CueHap]) -> Array[String]:
	var out: Array[String] = []
	for h in haps:
		out.append("%s | %s" % [str(h.whole), str(h.part)])
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

func eqstarts(name: String, haps: Array[CueHap], expected: Array[String]) -> void:
	var got := onset_starts(haps)
	var exp: Array[String] = []
	exp.append_array(expected)
	exp.sort()
	check(name, got == exp, "got %s, expected %s" % [str(got), str(exp)])

func eqspans(name: String, haps: Array[CueHap], expected: Array[String]) -> void:
	var got := span_sig(haps)
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

func values_in_time(haps: Array[CueHap]) -> Array[String]:
	var out: Array[String] = []
	for h in sorted_haps(haps):
		out.append(str(h.value))
	return out

func approx(name: String, got: float, expected: float, tol: float = 1e-9) -> void:
	check(name, absf(got - expected) <= tol, "got %s, expected %s" % [str(got), str(expected)])

func approx_values(name: String, haps: Array[CueHap], expected: Array[float], tol: float = 1e-9) -> void:
	var ordered := sorted_haps(haps)
	var ok := ordered.size() == expected.size()
	var got: Array[float] = []
	for h in ordered:
		got.append(float(h.value))
	if ok:
		for i in expected.size():
			if absf(got[i] - expected[i]) > tol:
				ok = false
	check(name, ok, "got %s, expected %s" % [str(got), str(expected)])

func signal_at(name: String, pat: CuePattern, t: CueFrac, expected: float) -> void:
	var haps := pat.query_arc(t, t)
	if haps.size() != 1:
		check(name, false, "got %d haps" % haps.size())
		return
	var h := haps[0]
	var ok := h.whole == null and h.part.begin.eq(t) and h.part.end.eq(t) \
		and absf(float(h.value) - expected) <= 1e-9
	check(name, ok, "got %s, expected %s" % [str(h), str(expected)])

func bits_string(bits: Array[int]) -> String:
	var parts: Array[String] = []
	for bit in bits:
		parts.append(str(bit))
	return "".join(parts)

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
	var a := CuePattern.pure("a")
	var b := CuePattern.pure("b")
	var c := CuePattern.pure("c")

	# 1. rev reflects each cycle's time.
	var rev4 := CuePattern.seq([CuePattern.pure(1), CuePattern.pure(2), CuePattern.pure(3), CuePattern.pure(4)]).rev()
	var rev4_h := rev4.query_arc(f(0), f(1))
	eqsig("rev seq4", rev4_h, [
		"[0, 1/4) | [0, 1/4) | 4",
		"[1/4, 1/2) | [1/4, 1/2) | 3",
		"[1/2, 3/4) | [1/2, 3/4) | 2",
		"[3/4, 1) | [3/4, 1) | 1",
	])
	check("rev seq4 time order", values_in_time(rev4_h) == ["4", "3", "2", "1"], str(values_in_time(rev4_h)))
	eqsig("rev seq cycle 1", CuePattern.seq([a, b]).rev().query_arc(f(1), f(2)), [
		"[1, 3/2) | [1, 3/2) | b",
		"[3/2, 2) | [3/2, 2) | a",
	])
	var cat_ab_c := CuePattern.cat([CuePattern.seq([a, b]), c])
	eqsig("rev cat cycle 0", cat_ab_c.rev().query_arc(f(0), f(1)), [
		"[0, 1/2) | [0, 1/2) | b",
		"[1/2, 1) | [1/2, 1) | a",
	])
	eqsig("rev cat cycle 1", cat_ab_c.rev().query_arc(f(1), f(2)), [
		"[1, 2) | [1, 2) | c",
	])

	# 2. struct takes its structure from the bool pattern.
	var struct_pat := CuePattern.pure("a").struct(CuePattern.seq([
		CuePattern.pure(true), CuePattern.silence(), CuePattern.pure(true), CuePattern.pure(true)]))
	var struct_h := struct_pat.query_arc(f(0), f(1))
	eqsig("struct true haps", struct_h, [
		"[0, 1/4) | [0, 1/4) | a",
		"[1/2, 3/4) | [1/2, 3/4) | a",
		"[3/4, 1) | [3/4, 1) | a",
	])
	eqonsets("struct true onsets", struct_h, ["0-1/4:a", "1/2-3/4:a", "3/4-1:a"])
	eqsig("struct false values", CuePattern.pure("a").struct(CuePattern.seq([
		CuePattern.pure(true), CuePattern.pure(false)])).query_arc(f(0), f(1)), [
		"[0, 1/2) | [0, 1/2) | a",
	])
	var struct_true := CuePattern.seq([a, b]).struct(CuePattern.pure(true)).query_arc(f(0), f(1))
	eqsig("struct pure true", struct_true, [
		"[0, 1) | [0, 1/2) | a",
		"[0, 1) | [1/2, 1) | b",
	])
	eqonsets("struct pure true onsets", struct_true, ["0-1:a"])

	# 3. mask clips parts to the true regions.
	eqsig("mask true/false", CuePattern.seq([a, b, c, CuePattern.pure("d")]).mask(CuePattern.seq([
		CuePattern.pure(true), CuePattern.pure(false)])).query_arc(f(0), f(1)), [
		"[0, 1/4) | [0, 1/4) | a",
		"[1/4, 1/2) | [1/4, 1/2) | b",
	])
	var masked := CuePattern.pure("a").mask(CuePattern.seq([
		CuePattern.pure(false), CuePattern.pure(true)])).query_arc(f(0), f(1))
	eqsig("mask fragments whole", masked, ["[0, 1) | [1/2, 1) | a"])
	check("mask fragment no onset", masked.size() == 1 and not masked[0].has_onset(), str(masked))

	# 4. segment samples the source at each segment's midpoint.
	var saw_seg := CueSignals.saw().segment(f(4))
	var saw_seg_h := saw_seg.query_arc(f(0), f(1))
	approx_values("segment saw values", saw_seg_h, [0.125, 0.375, 0.625, 0.875])
	eqspans("segment saw spans", saw_seg_h, [
		"[0, 1/4) | [0, 1/4)",
		"[1/4, 1/2) | [1/4, 1/2)",
		"[1/2, 3/4) | [1/2, 3/4)",
		"[3/4, 1) | [3/4, 1)",
	])
	approx_values("segment sine values", CueSignals.sine().segment(f(2)).query_arc(f(0), f(1)), [1.0, 0.0])

	# 5. range and range_pat map signal values.
	approx_values("range saw segment", saw_seg.range(10.0, 20.0).query_arc(f(0), f(1)),
		[11.25, 13.75, 16.25, 18.75])
	approx_values("range_pat saw segment", saw_seg.range_pat(CuePattern.pure(0), CuePattern.pure(100)).query_arc(f(0), f(1)),
		[12.5, 37.5, 62.5, 87.5])

	# 6. continuous signals, sampled at the query midpoint.
	signal_at("sine t=1/4", CueSignals.sine(), f(1, 4), 1.0)
	signal_at("saw t=1/4", CueSignals.saw(), f(1, 4), 0.25)
	signal_at("tri t=1/4", CueSignals.tri(), f(1, 4), 0.5)
	signal_at("square t=1/4", CueSignals.square(), f(1, 4), 0.0)
	signal_at("sine t=3/4", CueSignals.sine(), f(3, 4), 0.0)
	signal_at("saw t=3/4", CueSignals.saw(), f(3, 4), 0.75)
	signal_at("tri t=3/4", CueSignals.tri(), f(3, 4), 0.5)
	signal_at("square t=3/4", CueSignals.square(), f(3, 4), 1.0)
	signal_at("tri t=1/2", CueSignals.tri(), f(1, 2), 1.0)
	signal_at("square t=1/2", CueSignals.square(), f(1, 2), 1.0)
	signal_at("saw t=5/4 wraps", CueSignals.saw(), f(5, 4), 0.25)

	var ir := CueSignals.irand(4, 1, 1)
	var ir_ok := true
	var ir_detail := ""
	var ir_distinct := {}
	for i in 200:
		var t := f(i, 200)
		var ir_h := ir.query_arc(t, t)
		if ir_h.size() != 1:
			ir_ok = false
			ir_detail = "hap count %d at %s" % [ir_h.size(), str(t)]
			break
		var iv: Variant = ir_h[0].value
		if typeof(iv) != TYPE_INT or int(iv) < 0 or int(iv) > 3:
			ir_ok = false
			ir_detail = "value %s at %s" % [str(iv), str(t)]
			break
		ir_distinct[int(iv)] = true
	check("irand values ints in 0..3", ir_ok, ir_detail)
	check("irand varies", ir_distinct.size() >= 2, "distinct %d" % ir_distinct.size())

	var perl := CueSignals.perlin(1, 1)
	var perl_ok := true
	var perl_detail := ""
	for i in 200:
		var t := f(i, 200)
		var perl_h := perl.query_arc(t, t)
		if perl_h.size() != 1:
			perl_ok = false
			perl_detail = "hap count %d at %s" % [perl_h.size(), str(t)]
			break
		var pv := float(perl_h[0].value)
		if pv < 0.0 or pv > 1.0:
			perl_ok = false
			perl_detail = "value %s at %s" % [str(pv), str(t)]
			break
	check("perlin values in [0,1]", perl_ok, perl_detail)
	var perl_anchor_ok := true
	for i in 20:
		var t := f(i)
		var perl_h := perl.query_arc(t, t)
		var expected := CueSignals.hash01(1, 1, t)
		if perl_h.size() != 1 or absf(float(perl_h[0].value) - expected) > 1e-9:
			perl_anchor_ok = false
	check("perlin at integer t equals hash01", perl_anchor_ok, "mismatch")

	# 7. hash01 is the reproducible splitmix64 hash.
	approx("hash01 ref 0", CueSignals.hash01(0, 0, f(0)), 0.16526896395580137, 1e-12)
	approx("hash01 ref 1", CueSignals.hash01(7, 1, f(0)), 0.9256224043710863, 1e-12)
	approx("hash01 ref 2", CueSignals.hash01(7, 1, f(1, 2)), 0.45999557124115287, 1e-12)
	approx("hash01 ref 3", CueSignals.hash01(42, 3, f(5, 4)), 0.3294315429697693, 1e-12)
	check("_mix64 zero reference", CueSignals._mix64(0) == -2152535657050944081, str(CueSignals._mix64(0)))
	var hd1 := CueSignals.hash01(1, 1, f(3, 7))
	var hd2 := CueSignals.hash01(1, 1, f(3, 7))
	check("hash01 deterministic", hd1 == hd2, "%s vs %s" % [str(hd1), str(hd2)])
	check("hash01 seed differs", CueSignals.hash01(1, 1, f(1)) != CueSignals.hash01(2, 1, f(1)), "equal")
	check("hash01 site differs", CueSignals.hash01(1, 1, f(1)) != CueSignals.hash01(1, 2, f(1)), "equal")
	approx("hash01 normalized time", CueSignals.hash01(7, 1, f(1, 2)), CueSignals.hash01(7, 1, f(2, 4)), 1e-15)

	var total := 0.0
	var buckets: Array[int] = []
	for i in 10:
		buckets.append(0)
	var dist_ok := true
	var dist_detail := ""
	for i in 2000:
		var t := f(i)
		var hv := CueSignals.hash01(0, 0, t)
		if hv < 0.0 or hv >= 1.0:
			dist_ok = false
			dist_detail = "value %s at %s" % [str(hv), str(t)]
			break
		total += hv
		var bi := int(floor(hv * 10.0))
		if bi < 0:
			bi = 0
		if bi > 9:
			bi = 9
		buckets[bi] += 1
	check("hash01 all in [0,1)", dist_ok, dist_detail)
	var mean := total / 2000.0
	check("hash01 mean", mean >= 0.45 and mean <= 0.55, str(mean))
	for i in 10:
		check("hash01 bucket %d" % i, buckets[i] >= 140 and buckets[i] <= 260, str(buckets[i]))

	# 8. app_left point-samples the argument at the receiver's whole begin.
	var receiver := CuePattern.seq([CuePattern.pure({"x": 1}), CuePattern.pure({"x": 2})])
	var merge := func(l: Variant, r: Variant) -> Variant:
		var d: Dictionary = l.duplicate()
		d["g"] = r
		return d
	var cat_arg := CuePattern.cat([CuePattern.pure(0.2), CuePattern.pure(0.8)])
	var cat_join := receiver.app_left(cat_arg, merge)
	var cj0 := sorted_haps(cat_join.query_arc(f(0), f(1)))
	var cj0_ok := cj0.size() == 2
	if cj0_ok:
		cj0_ok = int(cj0[0].value["x"]) == 1 and absf(float(cj0[0].value["g"]) - 0.2) <= 1e-9 \
			and str(cj0[0].whole) == "[0, 1/2)" \
			and int(cj0[1].value["x"]) == 2 and absf(float(cj0[1].value["g"]) - 0.2) <= 1e-9 \
			and str(cj0[1].whole) == "[1/2, 1)"
	check("app_left cat cycle 0", cj0_ok, str(cj0))
	var cj1 := sorted_haps(cat_join.query_arc(f(1), f(2)))
	var cj1_ok := cj1.size() == 2
	if cj1_ok:
		cj1_ok = absf(float(cj1[0].value["g"]) - 0.8) <= 1e-9 and absf(float(cj1[1].value["g"]) - 0.8) <= 1e-9
	check("app_left cat cycle 1", cj1_ok, str(cj1))

	var seq4v := CuePattern.seq([CuePattern.pure(1), CuePattern.pure(2), CuePattern.pure(3), CuePattern.pure(4)])
	var pair_merge := func(l: Variant, r: Variant) -> Variant:
		return {"v": l, "g": r}
	var saw_join := sorted_haps(seq4v.app_left(CueSignals.saw(), pair_merge).query_arc(f(0), f(1)))
	var saw_g: Array[float] = []
	for h in saw_join:
		saw_g.append(float(h.value["g"]))
	var saw_join_ok := saw_g.size() == 4
	if saw_join_ok:
		for i in 4:
			if absf(saw_g[i] - float(i) * 0.25) > 1e-9:
				saw_join_ok = false
	check("app_left saw samples whole begins", saw_join_ok, str(saw_g))
	check("app_left silent arg drops", receiver.app_left(CuePattern.silence(), merge).query_arc(f(0), f(1)).is_empty(), "not empty")
	var null_fn := func(_l: Variant, _r: Variant) -> Variant: return null
	check("app_left null fn drops", receiver.app_left(cat_arg, null_fn).query_arc(f(0), f(1)).is_empty(), "not empty")

	var worked_arg := CuePattern.seq([CuePattern.pure(0.2), CuePattern.pure(0.5), CuePattern.pure(0.8)])
	var worked := sorted_haps(receiver.app_left(worked_arg, merge).query_arc(f(1, 4), f(1)))
	var worked_ok := worked.size() == 2
	if worked_ok:
		var w0 := worked[0]
		var w1 := worked[1]
		worked_ok = int(w0.value["x"]) == 1 and absf(float(w0.value["g"]) - 0.2) <= 1e-9 \
			and str(w0.whole) == "[0, 1/2)" and str(w0.part) == "[1/4, 1/2)" and not w0.has_onset() \
			and int(w1.value["x"]) == 2 and absf(float(w1.value["g"]) - 0.5) <= 1e-9 \
			and str(w1.whole) == "[1/2, 1)" and str(w1.part) == "[1/2, 1)" and w1.has_onset()
	check("app_left worked example", worked_ok, str(worked))

	var boundary := sorted_haps(receiver.app_left(CuePattern.seq([
		CuePattern.pure(0.2), CuePattern.pure(0.8)]), merge).query_arc(f(0), f(1)))
	var boundary_ok := boundary.size() == 2 \
		and absf(float(boundary[0].value["g"]) - 0.2) <= 1e-9 \
		and absf(float(boundary[1].value["g"]) - 0.8) <= 1e-9
	check("app_left boundary takes starting step", boundary_ok, str(boundary))

	var stacked := sorted_haps(receiver.app_left(CuePattern.stack([
		CuePattern.pure(1), CuePattern.pure(2)]), merge).query_arc(f(0), f(1)))
	var stack_ok := stacked.size() == 2
	if stack_ok:
		stack_ok = int(stacked[0].value["g"]) == 1 and int(stacked[1].value["g"]) == 1
	check("app_left stack first layer", stack_ok, str(stacked))

	var continuous := CueSignals.saw().app_left(CuePattern.pure(5), func(l: Variant, r: Variant) -> Variant:
		return float(l) + float(r)).query_arc(f(1, 4), f(1, 2))
	var cont_ok := continuous.size() == 1 and continuous[0].whole == null \
		and str(continuous[0].part) == "[1/4, 1/2)" \
		and absf(float(continuous[0].value) - 5.375) <= 1e-9
	check("app_left continuous receiver", cont_ok, str(continuous))

	# 9. patternify_inner joins a patterned argument over its own part.
	var pi_cat := CuePattern.patternify_inner(CuePattern.cat([CuePattern.pure(1), CuePattern.pure(2)]),
		func(v: Variant) -> CuePattern: return CuePattern.seq([a, b]).fast(CuePattern.to_frac(v)))
	var pi0 := pi_cat.query_arc(f(0), f(1))
	var pi1 := pi_cat.query_arc(f(1), f(2))
	check("patternify_inner cycle 0 count", pi0.size() == 2, "got %d" % pi0.size())
	check("patternify_inner cycle 1 count", pi1.size() == 4, "got %d" % pi1.size())
	eqspans("patternify_inner cycle 0 spans", pi0, ["[0, 1/2) | [0, 1/2)", "[1/2, 1) | [1/2, 1)"])
	eqspans("patternify_inner cycle 1 spans", pi1, [
		"[1, 5/4) | [1, 5/4)",
		"[5/4, 3/2) | [5/4, 3/2)",
		"[3/2, 7/4) | [3/2, 7/4)",
		"[7/4, 2) | [7/4, 2)",
	])
	var pi_seq := CuePattern.patternify_inner(CuePattern.seq([CuePattern.pure(1), CuePattern.pure(2)]),
		func(v: Variant) -> CuePattern: return CuePattern.seq([a, b]).fast(CuePattern.to_frac(v)))
	var pi_seq_h := sorted_haps(pi_seq.query_arc(f(0), f(1)))
	var pi_seq_ok := pi_seq_h.size() == 3
	if pi_seq_ok:
		pi_seq_ok = str(pi_seq_h[0].whole) == "[0, 1/2)" \
			and str(pi_seq_h[1].whole) == "[1/2, 3/4)" \
			and str(pi_seq_h[2].whole) == "[3/4, 1)"
	check("patternify_inner seq arg", pi_seq_ok, str(pi_seq_h))

	# 10. ply subdivides each whole.
	var seq_ab := CuePattern.seq([a, b])
	eqsig("ply 2", seq_ab.ply(2).query_arc(f(0), f(1)), [
		"[0, 1/4) | [0, 1/4) | a",
		"[1/4, 1/2) | [1/4, 1/2) | a",
		"[1/2, 3/4) | [1/2, 3/4) | b",
		"[3/4, 1) | [3/4, 1) | b",
	])
	eqspans("ply 3 pure", CuePattern.pure("a").ply(3).query_arc(f(0), f(1)), [
		"[0, 1/3) | [0, 1/3)",
		"[1/3, 2/3) | [1/3, 2/3)",
		"[2/3, 1) | [2/3, 1)",
	])
	check("ply 1 equals source", sig(seq_ab.ply(1).query_arc(f(0), f(1))) == sig(seq_ab.query_arc(f(0), f(1))),
		str(sig(seq_ab.ply(1).query_arc(f(0), f(1)))))
	var ply_frag := sorted_haps(seq_ab.ply(2).query_arc(f(1, 8), f(1)))
	var ply_frag_ok := ply_frag.size() == 4
	if ply_frag_ok:
		ply_frag_ok = str(ply_frag[0].whole) == "[0, 1/4)" and str(ply_frag[0].part) == "[1/8, 1/4)" \
			and not ply_frag[0].has_onset() \
			and str(ply_frag[1].whole) == "[1/4, 1/2)" and ply_frag[1].has_onset() \
			and str(ply_frag[2].whole) == "[1/2, 3/4)" and ply_frag[2].has_onset() \
			and str(ply_frag[3].whole) == "[3/4, 1)" and ply_frag[3].has_onset()
	check("ply fragment clips parts", ply_frag_ok, str(ply_frag))

	# 11. iter rotates the pattern's start each cycle.
	var iter_pat := CuePattern.seq([CuePattern.pure(0), CuePattern.pure(1), CuePattern.pure(2), CuePattern.pure(3)]).iter(4)
	var iter_expected := [
		["0", "1", "2", "3"],
		["1", "2", "3", "0"],
		["2", "3", "0", "1"],
		["3", "0", "1", "2"],
		["0", "1", "2", "3"],
	]
	for cyc in 5:
		var got := values_in_time(iter_pat.query_arc(f(cyc), f(cyc + 1)))
		check("iter cycle %d" % cyc, got == iter_expected[cyc], "got %s, expected %s" % [str(got), str(iter_expected[cyc])])

	# 12. palindrome alternates forward and reversed cycles.
	var pal := CuePattern.seq([a, b]).palindrome()
	var pal_expected := [["a", "b"], ["b", "a"], ["a", "b"]]
	for cyc in 3:
		var got := values_in_time(pal.query_arc(f(cyc), f(cyc + 1)))
		check("palindrome cycle %d" % cyc, got == pal_expected[cyc], "got %s, expected %s" % [str(got), str(pal_expected[cyc])])

	# 13. slowcat_prime picks by global cycle with no offsetting.
	var scp := CuePattern.slowcat_prime([CuePattern.seq([a, b]), c])
	check("slowcat_prime cycle 0", values_in_time(scp.query_arc(f(0), f(1))) == ["a", "b"], str(values_in_time(scp.query_arc(f(0), f(1)))))
	check("slowcat_prime cycle 1", values_in_time(scp.query_arc(f(1), f(2))) == ["c"], str(values_in_time(scp.query_arc(f(1), f(2)))))
	check("slowcat_prime cycle 2", values_in_time(scp.query_arc(f(2), f(3))) == ["a", "b"], str(values_in_time(scp.query_arc(f(2), f(3)))))
	check("slowcat_prime cycle 2 matches cat", sig(scp.query_arc(f(2), f(3))) == sig(cat_ab_c.query_arc(f(2), f(3))),
		"%s vs %s" % [str(sig(scp.query_arc(f(2), f(3)))), str(sig(cat_ab_c.query_arc(f(2), f(3))))])

	# 14. bjorklund vectors and euclid orientation.
	var vectors := [
		[3, 8, "10010010"],
		[5, 8, "10110110"],
		[4, 8, "10101010"],
		[2, 5, "10100"],
		[3, 5, "10101"],
		[1, 4, "1000"],
		[0, 4, "0000"],
		[8, 8, "11111111"],
	]
	for entry in vectors:
		var k: int = entry[0]
		var n: int = entry[1]
		var expected: String = entry[2]
		var got := bits_string(CuePattern.bjorklund(k, n))
		check("bjorklund %d,%d" % [k, n], got == expected, "got %s, expected %s" % [got, expected])
	eqstarts("euclid_bools 3,8,2", CuePattern.euclid_bools(3, 8, 2).onsets_in(f(0), f(1)), ["1/8", "1/2", "3/4"])
	var e38 := CuePattern.pure("a").euclid(3, 8).onsets_in(f(0), f(1))
	eqstarts("euclid 3,8 starts", e38, ["0", "3/8", "3/4"])
	var e38_len_ok := true
	for h in e38:
		if not h.whole.duration().eq(f(1, 8)):
			e38_len_ok = false
	check("euclid 3,8 whole length", e38_len_ok, str(e38))
	eqstarts("euclid 5,8 starts", CuePattern.pure("a").euclid(5, 8).onsets_in(f(0), f(1)),
		["0", "1/4", "3/8", "5/8", "3/4"])
	check("euclid 0,8 silent", CuePattern.pure("a").euclid(0, 8).query_arc(f(0), f(4)).is_empty(), "not empty")
	check("euclid 3,0 silent", CuePattern.pure("a").euclid(3, 0).query_arc(f(0), f(4)).is_empty(), "not empty")
	check("euclid 9,8 clamps to 8,8",
		sig(CuePattern.pure("a").euclid(9, 8).query_arc(f(0), f(1))) == sig(CuePattern.pure("a").euclid(8, 8).query_arc(f(0), f(1))),
		str(sig(CuePattern.pure("a").euclid(9, 8).query_arc(f(0), f(1)))))

	# 15. degrade_by is seeded, deterministic and invertible.
	var eight_pats: Array[CuePattern] = []
	for i in 8:
		eight_pats.append(CuePattern.pure(1))
	var eight := CuePattern.seq(eight_pats)
	var kept_half := eight.degrade_by(0.5, 7, 1).query_arc(f(0), f(100))
	check("degrade_by 0.5 count", kept_half.size() >= 340 and kept_half.size() <= 460, str(kept_half.size()))
	check("degrade_by 0.0 keeps all", eight.degrade_by(0.0, 7, 1).query_arc(f(0), f(100)).size() == 800,
		str(eight.degrade_by(0.0, 7, 1).query_arc(f(0), f(100)).size()))
	check("degrade_by 1.0 keeps none", eight.degrade_by(1.0, 7, 1).query_arc(f(0), f(100)).is_empty(), "not empty")
	var half_sig := sig(kept_half)
	var half_sig_again := sig(eight.degrade_by(0.5, 7, 1).query_arc(f(0), f(100)))
	check("degrade_by deterministic", half_sig == half_sig_again, "differs")
	var seed8_sig := sig(eight.degrade_by(0.5, 8, 1).query_arc(f(0), f(100)))
	check("degrade_by seed differs", half_sig != seed8_sig, "equal")
	var inverted := eight.degrade_by(0.5, 7, 1, true).query_arc(f(0), f(100))
	var seen := {}
	for h in kept_half:
		seen[str(h.whole)] = true
	var overlap := 0
	for h in inverted:
		if seen.has(str(h.whole)):
			overlap += 1
		else:
			seen[str(h.whole)] = true
	check("degrade_by invert union covers", seen.size() == 800, str(seen.size()))
	check("degrade_by invert overlap small", overlap < 5, str(overlap))

	# 16. Window-splitting invariance for every op.
	var w3_a := [[f(0), f(37, 100)], [f(37, 100), f(1)], [f(1), f(2)]]
	var w4_a := [[f(0), f(1, 7)], [f(1, 7), f(2, 3)], [f(2, 3), f(5, 4)], [f(5, 4), f(2)]]
	check_window_split("rev", CuePattern.seq([a, b, c]).rev(), f(0), f(2), w3_a, w4_a)
	check_window_split("ply", CuePattern.seq([a, b]).ply(2), f(0), f(2), w3_a, w4_a)
	check_window_split("iter", CuePattern.seq([CuePattern.pure(0), CuePattern.pure(1), CuePattern.pure(2), CuePattern.pure(3)]).iter(4),
		f(0), f(4),
		[[f(0), f(37, 100)], [f(37, 100), f(1)], [f(1), f(2)], [f(2), f(4)]],
		[[f(0), f(1, 7)], [f(1, 7), f(2, 3)], [f(2, 3), f(5, 4)], [f(5, 4), f(2)], [f(2), f(4)]])
	check_window_split("palindrome", CuePattern.seq([a, b]).palindrome(), f(0), f(2), w3_a, w4_a)
	check_window_split("euclid", CuePattern.pure("a").euclid(3, 8), f(0), f(2), w3_a, w4_a)
	check_window_split("mask", CuePattern.seq([a, b, c, CuePattern.pure("d")]).mask(
		CuePattern.seq([CuePattern.pure(true), CuePattern.pure(false)])), f(0), f(2), w3_a, w4_a)
	check_window_split("degrade_by", eight.degrade_by(0.5, 3, 1), f(0), f(2), w3_a, w4_a)
	check_window_split("struct", CuePattern.pure("a").struct(
		CuePattern.seq([CuePattern.pure(true), CuePattern.silence(), CuePattern.pure(true)])), f(0), f(2), w3_a, w4_a)
	check_window_split("app_left", receiver.app_left(worked_arg, merge), f(0), f(2), w3_a, w4_a)

	if failures.is_empty():
		print("PASS all cue pattern ops checks")
		quit(0)
	else:
		print("FAIL %d cue pattern ops checks" % failures.size())
		quit(1)
