extends SceneTree
# CueFrac: exact int64 fraction arithmetic, normalization, floors, cycle
# positions and float conversion.
# Run: Godot --headless --path project -s ../tests/test_cue_frac.gd
# Exits with code 0 when every check passes, 1 otherwise.

var failures: Array[String] = []
var lcg_state: int = 123456789

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func eqs(name: String, f: CueFrac, expected: String) -> void:
	check(name, str(f) == expected, "got %s, expected %s" % [str(f), expected])

# Deterministic stand-in for randi(): a plain int64 LCG.
func next_rand() -> int:
	lcg_state = (lcg_state * 1103515245 + 12345) % 2147483648
	return lcg_state

func _initialize() -> void:
	# Normalization.
	eqs("normalize 2/4", CueFrac.make(2, 4), "1/2")
	eqs("normalize 1/-2", CueFrac.make(1, -2), "-1/2")
	eqs("normalize 0/5", CueFrac.make(0, 5), "0")
	check("zero denominator is 1", CueFrac.make(0, 5).den == 1, "den %d" % CueFrac.make(0, 5).den)
	eqs("normalize 6/3", CueFrac.make(6, 3), "2")
	eqs("normalize -6/-4", CueFrac.make(-6, -4), "3/2")

	# Arithmetic.
	eqs("1/2 + 1/3", CueFrac.make(1, 2).add(CueFrac.make(1, 3)), "5/6")
	eqs("1/2 - 1/3", CueFrac.make(1, 2).sub(CueFrac.make(1, 3)), "1/6")
	eqs("2/3 * 3/4", CueFrac.make(2, 3).mul(CueFrac.make(3, 4)), "1/2")
	eqs("1/2 / 1/4", CueFrac.make(1, 2).div(CueFrac.make(1, 4)), "2")
	eqs("neg 3/4", CueFrac.make(3, 4).neg(), "-3/4")
	eqs("1/2 - 1/2", CueFrac.make(1, 2).sub(CueFrac.make(1, 2)), "0")
	eqs("-1/2 * -1/2", CueFrac.make(-1, 2).mul(CueFrac.make(-1, 2)), "1/4")

	# Comparisons.
	check("1/3 < 1/2", CueFrac.make(1, 3).lt(CueFrac.make(1, 2)), "lt")
	check("1/2 <= 1/2", CueFrac.make(1, 2).le(CueFrac.make(1, 2)), "le")
	check("-1/2 < 1/3", CueFrac.make(-1, 2).lt(CueFrac.make(1, 3)), "lt")
	check("3/4 > 2/3", CueFrac.make(3, 4).gt(CueFrac.make(2, 3)), "gt")
	check("1/2 >= 1/2", CueFrac.make(1, 2).ge(CueFrac.make(1, 2)), "ge")
	check("eq 2/4 == 1/2", CueFrac.make(2, 4).eq(CueFrac.make(1, 2)), "eq")
	eqs("min 1/3, 1/2", CueFrac.make(1, 3).min(CueFrac.make(1, 2)), "1/3")
	eqs("max -1/2, 0", CueFrac.make(-1, 2).max(CueFrac.zero()), "0")

	# sam / next_sam / cycle / cycle_pos.
	eqs("sam 7/2", CueFrac.make(7, 2).sam(), "3")
	eqs("sam -1/2", CueFrac.make(-1, 2).sam(), "-1")
	eqs("sam 3", CueFrac.make(3).sam(), "3")
	eqs("sam 0", CueFrac.zero().sam(), "0")
	eqs("sam -3", CueFrac.make(-3).sam(), "-3")
	eqs("sam -7/2", CueFrac.make(-7, 2).sam(), "-4")
	eqs("next_sam 7/2", CueFrac.make(7, 2).next_sam(), "4")
	eqs("next_sam 3", CueFrac.make(3).next_sam(), "4")
	eqs("next_sam -1/2", CueFrac.make(-1, 2).next_sam(), "0")
	check("cycle 7/2", CueFrac.make(7, 2).cycle() == 3, str(CueFrac.make(7, 2).cycle()))
	check("cycle -1/2", CueFrac.make(-1, 2).cycle() == -1, str(CueFrac.make(-1, 2).cycle()))
	eqs("cycle_pos 7/2", CueFrac.make(7, 2).cycle_pos(), "1/2")
	eqs("cycle_pos -1/2", CueFrac.make(-1, 2).cycle_pos(), "1/2")
	eqs("cycle_pos -3", CueFrac.make(-3).cycle_pos(), "0")
	eqs("cycle_pos 3", CueFrac.make(3).cycle_pos(), "0")
	eqs("cycle_pos 10/3", CueFrac.make(10, 3).cycle_pos(), "1/3")

	# to_float.
	check("to_float 1/3", is_equal_approx(CueFrac.make(1, 3).to_float(), 0.3333333333333333), "%.12f" % CueFrac.make(1, 3).to_float())
	check("to_float -3/4", CueFrac.make(-3, 4).to_float() == -0.75, "%.12f" % CueFrac.make(-3, 4).to_float())

	# from_float.
	eqs("from_float 0.5", CueFrac.from_float(0.5), "1/2")
	eqs("from_float 0.25", CueFrac.from_float(0.25), "1/4")
	eqs("from_float 0.1", CueFrac.from_float(0.1), "1/10")
	eqs("from_float 1/3", CueFrac.from_float(1.0 / 3.0), "1/3")
	eqs("from_float 0.37", CueFrac.from_float(0.37), "37/100")
	eqs("from_float 2.5", CueFrac.from_float(2.5), "5/2")
	eqs("from_float -0.75", CueFrac.from_float(-0.75), "-3/4")
	eqs("from_float 0.0", CueFrac.from_float(0.0), "0")
	eqs("from_float 3.0", CueFrac.from_float(3.0), "3")
	eqs("from_float 0.125", CueFrac.from_float(0.125), "1/8")
	eqs("from_float 0.3", CueFrac.from_float(0.3), "3/10")

	# Round trip: every small exact fraction survives float conversion.
	var round_ok := true
	var round_detail := "64x16 pairs"
	for i in range(1, 65):
		for j in range(1, 17):
			var f := CueFrac.from_float(float(i) / float(j))
			if not f.eq(CueFrac.make(i, j)):
				round_ok = false
				round_detail = "%d/%d became %s" % [i, j, str(f)]
				break
		if not round_ok:
			break
	check("float round trip", round_ok, round_detail)

	# Overflow headroom: gcd and normalization work past 2^31, and a 30-term
	# harmonic sum stays exact.
	eqs("large operands", CueFrac.make(3000000000, 4000000000), "3/4")
	var acc := CueFrac.one()
	for k in range(2, 31):
		acc = acc.add(CueFrac.make(1, k))
	check("harmonic sum", absf(acc.to_float() - 3.994987130920391) < 1e-9, "%.12f" % acc.to_float())
	eqs("harmonic string", acc, "9304682830147/2329089562800")

	# Immutability: an operation never touches its operands.
	var a := CueFrac.make(1, 2)
	var b := a.add(CueFrac.make(1, 2))
	eqs("operand unchanged", a, "1/2")
	eqs("result", b, "1")

	# Deterministic stress: add/sub, mul/div and lt against float.
	var stress_ok := true
	var stress_detail := "500 iterations"
	for i in range(500):
		var an: int = next_rand() % 41 - 20
		var ad: int = next_rand() % 16 + 1
		var bn: int = next_rand() % 41 - 20
		var bd: int = next_rand() % 16 + 1
		var fa := CueFrac.make(an, ad)
		var fb := CueFrac.make(bn, bd)
		var sub_ok := fa.add(fb).sub(fb).eq(fa)
		var mul_ok := fb.is_zero() or fa.mul(fb).div(fb).eq(fa)
		var cmp_ok := true
		var fa_float := fa.to_float()
		var fb_float := fb.to_float()
		if absf(fa_float - fb_float) > 1e-9:
			cmp_ok = fa.lt(fb) == (fa_float < fb_float)
		if not sub_ok or not mul_ok or not cmp_ok:
			stress_ok = false
			stress_detail = "iteration %d: a=%s b=%s add/sub=%s mul/div=%s cmp=%s" % [i, str(fa), str(fb), sub_ok, mul_ok, cmp_ok]
			break
	check("stress", stress_ok, stress_detail)

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
