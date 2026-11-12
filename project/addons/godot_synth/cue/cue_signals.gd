## Continuous cue signals and the seeded deterministic hash they use.
##
## Every random draw is hash01(seed, call site, time): the same file, seed and
## time always produce the same value, offline and live. There is no global RNG.
## Signals return one continuous hap (whole == null) valued at the query span's
## midpoint, so a scheduler must sample them at hap level (app_left, segment).
class_name CueSignals extends RefCounted

static func _lsr(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)

static func _mix64(z: int) -> int:
	z += -7046029254386353131          # 0x9E3779B97F4A7C15
	z = (z ^ _lsr(z, 30)) * -4658895280553007687   # 0xBF58476D1CE4E5B9
	z = (z ^ _lsr(z, 27)) * -7723592293110705685   # 0x94D049BB133111EB
	return z ^ _lsr(z, 31)

static func hash01(seed: int, site: int, t: CueFrac) -> float:
	var h: int = _mix64(seed)
	h = _mix64(h ^ site)
	h = _mix64(h ^ t.num)
	h = _mix64(h ^ t.den)
	return float(_lsr(h, 11)) / 9007199254740992.0     # / 2^53, result in [0, 1)

static func sine() -> CuePattern:
	return CuePattern.make_signal(func(t: CueFrac) -> Variant:
		return (sin(TAU * t.to_float()) + 1.0) / 2.0)

static func saw() -> CuePattern:
	return CuePattern.make_signal(func(t: CueFrac) -> Variant:
		return t.cycle_pos().to_float())

static func tri() -> CuePattern:
	return CuePattern.make_signal(func(t: CueFrac) -> Variant:
		var p := t.cycle_pos().to_float()
		if p < 0.5:
			return 2.0 * p
		return 2.0 * (1.0 - p))

static func square() -> CuePattern:
	return CuePattern.make_signal(func(t: CueFrac) -> Variant:
		var p := t.cycle_pos().to_float()
		return 0.0 if p < 0.5 else 1.0)

static func rand(seed: int, site: int) -> CuePattern:
	return CuePattern.make_signal(func(t: CueFrac) -> Variant:
		return hash01(seed, site, t))

static func irand(k: int, seed: int, site: int) -> CuePattern:
	return CuePattern.make_signal(func(t: CueFrac) -> Variant:
		var r := hash01(seed, site, t)
		var v := int(floor(r * float(k)))
		if k > 0:
			v = mini(v, k - 1)
		return v)

static func perlin(seed: int, site: int) -> CuePattern:
	return CuePattern.make_signal(func(t: CueFrac) -> Variant:
		var x := t.to_float()
		var fl := t.cycle()
		var a := hash01(seed, site, CueFrac.make(fl))
		var b := hash01(seed, site, CueFrac.make(fl + 1))
		var s := x - float(fl)
		var sm := s * s * s * (s * (s * 6.0 - 15.0) + 10.0)
		return a + sm * (b - a))
