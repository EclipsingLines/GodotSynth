## An immutable exact fraction on two int64 values: the only number type used
## for time in the cue pattern engine.
##
## Every time value (span ends, factors, offsets, cycle numbers) is a CueFrac,
## so onsets do not depend on how the scheduler slices its windows. Floats only
## appear inside signal values (sine, rand), never in time math.
##
## Values are normalized on construction: the denominator is always > 0, the
## sign lives on the numerator, and gcd(|num|, den) == 1 (zero is 0/1).
## Instances are immutable by convention: every operation returns a new object.
##
## Overflow: int64 arithmetic wraps silently in GDScript and there is no
## detection. Operations stay exact while operand |num| and den stay below
## 2^31, because cross products then stay below 2^62. Real pattern time stays
## tiny: denominators are products of step counts (8, 16, 3, 7, ...) and
## numerators are cycle numbers times those denominators.
class_name CueFrac extends RefCounted

const MAX_DENOMINATOR := 1_000_000
const MAX_FLOAT_MAGNITUDE := 1e12

var num: int
var den: int

func _init(n: int = 0, d: int = 1) -> void:
	if d == 0:
		push_error("CueFrac: zero denominator for numerator %d" % n)
		num = 0
		den = 1
		return
	if d < 0:
		n = -n
		d = -d
	var g: int = _gcd(absi(n), d)
	num = n / g
	den = d / g

static func make(n: int, d: int = 1) -> CueFrac:
	return CueFrac.new(n, d)

static func from_float(f: float) -> CueFrac:
	if is_nan(f) or is_inf(f) or absf(f) > MAX_FLOAT_MAGNITUDE:
		push_error("CueFrac.from_float: unsupported value %s" % str(f))
		return zero()
	var neg_sign: int = -1 if f < 0.0 else 1
	var x: float = absf(f)
	# Convergents of the continued fraction of x.
	var h0: int = 0
	var h1: int = 1
	var k0: int = 1
	var k1: int = 0
	var r: float = x
	for i in range(64):
		var a: int = floori(r)
		var h2: int = a * h1 + h0
		var k2: int = a * k1 + k0
		if k2 > MAX_DENOMINATOR:
			break
		h0 = h1
		h1 = h2
		k0 = k1
		k1 = k2
		var frac: float = r - float(a)
		if frac < 1e-12 or absf(x - float(h1) / float(k1)) < 1e-12:
			break
		r = 1.0 / frac
	return make(neg_sign * h1, k1)

static func zero() -> CueFrac:
	return make(0)

static func one() -> CueFrac:
	return make(1)

func add(o: CueFrac) -> CueFrac:
	if den == o.den:
		return make(num + o.num, den)
	var g: int = _gcd(den, o.den)
	var n: int = num * (o.den / g) + o.num * (den / g)
	return make(n, (den / g) * o.den)

func sub(o: CueFrac) -> CueFrac:
	return add(o.neg())

func mul(o: CueFrac) -> CueFrac:
	if is_zero() or o.is_zero():
		return zero()
	# Cross-reduce first to keep the products small.
	var g1: int = _gcd(absi(num), o.den)
	var g2: int = _gcd(absi(o.num), den)
	return make((num / g1) * (o.num / g2), (den / g2) * (o.den / g1))

func div(o: CueFrac) -> CueFrac:
	if o.is_zero():
		push_error("CueFrac: division by zero")
		return zero()
	return mul(make(o.den, o.num))

func neg() -> CueFrac:
	return make(-num, den)

func lt(o: CueFrac) -> bool:
	return num * o.den < o.num * den

func le(o: CueFrac) -> bool:
	return num * o.den <= o.num * den

func gt(o: CueFrac) -> bool:
	return num * o.den > o.num * den

func ge(o: CueFrac) -> bool:
	return num * o.den >= o.num * den

func eq(o: CueFrac) -> bool:
	return num == o.num and den == o.den

func min(o: CueFrac) -> CueFrac:
	return self if lt(o) else o

func max(o: CueFrac) -> CueFrac:
	return self if gt(o) else o

# Floor to an integer cycle, as a CueFrac.
func sam() -> CueFrac:
	return make(cycle())

func next_sam() -> CueFrac:
	return make(cycle() + 1)

func cycle() -> int:
	return _floor_div(num, den)

func cycle_pos() -> CueFrac:
	return sub(sam())

func to_float() -> float:
	return float(num) / float(den)

func is_zero() -> bool:
	return num == 0

func _to_string() -> String:
	if den == 1:
		return str(num)
	return "%d/%d" % [num, den]

static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t: int = a % b
		a = b
		b = t
	return absi(a)

# Floor division: GDScript's int `/` truncates toward zero, which is wrong for
# negative numerators. The denominator is always positive here.
static func _floor_div(n: int, d: int) -> int:
	var q: int = n / d
	if n % d != 0 and n < 0:
		q -= 1
	return q
