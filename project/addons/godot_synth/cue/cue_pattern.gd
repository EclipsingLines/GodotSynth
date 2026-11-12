## A cue pattern: a function from a query state to the haps active in its span.
##
## Following Strudel's query model, a pattern can be queried for any window and
## returns fragments that are consistent across window boundaries. The classic
## constructors and time transforms live here; ops and signals build on them.
class_name CuePattern extends RefCounted

var query: Callable

func _init(q: Callable = Callable()) -> void:
	query = q

# Entry points.

func query_arc(b: CueFrac, e: CueFrac, controls: Dictionary = {}) -> Array[CueHap]:
	var out: Array[CueHap] = []
	out.append_array(query.call(make_state(CueSpan.make(b, e), controls)))
	return out

func onsets_in(b: CueFrac, e: CueFrac, controls: Dictionary = {}) -> Array[CueHap]:
	var out: Array[CueHap] = []
	for h in query_arc(b, e, controls):
		if h.has_onset():
			out.append(h)
	return out

static func make_state(span: CueSpan, controls: Dictionary) -> Dictionary:
	return {"span": span, "controls": controls}

# Constructors.

static func pure(v: Variant) -> CuePattern:
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		var span: CueSpan = state["span"]
		for sub in span.span_cycles():
			out.append(CueHap.make(CueSpan.make(sub.begin.sam(), sub.begin.next_sam()), sub, v))
		return out
	return CuePattern.new(q)

static func silence() -> CuePattern:
	var q := func(_state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		return out
	return CuePattern.new(q)

static func seq(pats: Array[CuePattern]) -> CuePattern:
	var n := pats.size()
	if n == 0:
		return silence()
	return cat(pats).fast(CueFrac.make(n))

static func cat(pats: Array[CuePattern]) -> CuePattern:
	var n := pats.size()
	if n == 0:
		return silence()
	if n == 1:
		return pats[0]
	var q := func(state: Dictionary) -> Array[CueHap]:
		var span: CueSpan = state["span"]
		var controls: Dictionary = state["controls"]
		var c := span.begin.cycle()
		var i := posmod(c, n)
		var offset := CueFrac.make(c - _floor_div(c, n))
		var sub_span := span.with_time(func(t: CueFrac) -> CueFrac: return t.sub(offset))
		var sub: Array[CueHap] = []
		sub.append_array(pats[i].query.call(make_state(sub_span, controls)))
		var shift := func(s: CueSpan) -> CueSpan:
			return s.with_time(func(t: CueFrac) -> CueFrac: return t.add(offset))
		var out: Array[CueHap] = []
		for h in sub:
			out.append(h.with_span(shift))
		return out
	return CuePattern.new(q).split_queries()

static func timecat(weighted: Array) -> CuePattern:
	var total := CueFrac.zero()
	for entry in weighted:
		total = total.add(to_frac(entry[0]))
	if total.is_zero():
		return silence()
	var pos := CueFrac.zero()
	var pats: Array[CuePattern] = []
	for entry in weighted:
		var w := to_frac(entry[0])
		var p: CuePattern = entry[1]
		pats.append(p.compress(pos.div(total), pos.add(w).div(total)))
		pos = pos.add(w)
	return stack(pats)

static func stack(pats: Array[CuePattern]) -> CuePattern:
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for p in pats:
			out.append_array(p.query.call(state))
		return out
	return CuePattern.new(q)

static func to_frac(v: Variant) -> CueFrac:
	if v is CueFrac:
		return v
	if v is int:
		return CueFrac.make(v)
	if v is float:
		return CueFrac.from_float(v)
	return CueFrac.zero()

static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return bool(v)
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING:
			return not (v in ["", "0", "f", "false"])
		TYPE_NIL:
			return false
		_:
			return true

static func make_signal(f: Callable) -> CuePattern:
	var q := func(state: Dictionary) -> Array[CueHap]:
		var span: CueSpan = state["span"]
		var out: Array[CueHap] = []
		out.append(CueHap.make(null, span, f.call(span.midpoint())))
		return out
	return CuePattern.new(q)

# One pattern per cycle, with no cycle offsetting (Strudel's slowcatPrime).
static func slowcat_prime(pats: Array[CuePattern]) -> CuePattern:
	var n := pats.size()
	if n == 0:
		return silence()
	var q := func(state: Dictionary) -> Array[CueHap]:
		var span: CueSpan = state["span"]
		var c := span.begin.cycle()
		var i := posmod(c, n)
		var out: Array[CueHap] = []
		out.append_array(pats[i].query.call(make_state(span, state["controls"])))
		return out
	return CuePattern.new(q).split_queries()

# Bjorklund's Euclidean rhythm, returning one 1/0 bit per step.
static func bjorklund(k: int, n: int) -> Array[int]:
	var out: Array[int] = []
	if n <= 0:
		return out
	k = clampi(k, 0, n)
	var ons := k
	var offs := n - k
	var x: Array = []
	for i in ons:
		x.append([1])
	var y: Array = []
	for i in offs:
		y.append([0])
	var a := ons
	var b := offs
	while mini(a, b) > 1:
		if a > b:
			var left: Array = x.slice(0, b)
			var rest: Array = x.slice(b)
			var new_x: Array = []
			for i in b:
				var group: Array = left[i].duplicate()
				group.append_array(y[i])
				new_x.append(group)
			y = rest
			x = new_x
			var old_a := a
			a = b
			b = old_a - b
		else:
			var left: Array = y.slice(0, a)
			var rest: Array = y.slice(a)
			var new_x: Array = []
			for i in a:
				var group: Array = x[i].duplicate()
				group.append_array(left[i])
				new_x.append(group)
			y = rest
			x = new_x
			b = b - a
	var flat: Array[int] = []
	for group in x:
		for bit in group:
			flat.append(int(bit))
	for group in y:
		for bit in group:
			flat.append(int(bit))
	return flat

static func euclid_bools(k: int, n: int, rot: int = 0) -> CuePattern:
	var bits := bjorklund(k, n)
	if bits.is_empty():
		return silence()
	var r := posmod(rot, n)
	var rotated: Array[int] = []
	rotated.append_array(bits.slice(r))
	rotated.append_array(bits.slice(0, r))
	var pats: Array[CuePattern] = []
	for bit in rotated:
		if bit == 1:
			pats.append(pure(true))
		else:
			pats.append(silence())
	return seq(pats)

# Strudel's innerJoin for function arguments: query each arg hap's pattern over
# that hap's part, so patterned factors apply over their own slice of time.
static func patternify_inner(arg: CuePattern, fn: Callable) -> CuePattern:
	var arg_query := arg.query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for ho: CueHap in arg_query.call(state):
			var inner: CuePattern = fn.call(ho.value)
			if inner == null:
				continue
			for hi: CueHap in inner.query.call(make_state(ho.part, state["controls"])):
				var p = hi.part.intersection(ho.part)
				if p != null:
					out.append(CueHap.make(hi.whole, p, hi.value))
		return out
	return CuePattern.new(q)

# Strudel's appLeft: structure from `left`, `right` queried over each left hap's
# whole. Used by struct and segment, not by the control join app_left.
static func _app_left_whole(left: CuePattern, right: CuePattern, fn: Callable) -> CuePattern:
	var left_query := left.query
	var right_query := right.query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for hl: CueHap in left_query.call(state):
			for hr: CueHap in right_query.call(make_state(hl.whole_or_part(), state["controls"])):
				var part = hl.part.intersection(hr.part)
				if part != null:
					out.append(CueHap.make(hl.whole, part, fn.call(hl.value, hr.value)))
		return out
	return CuePattern.new(q)

# Combinators.

func fmap(f: Callable) -> CuePattern:
	var inner := query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for h in inner.call(state):
			out.append(h.with_value(f))
		return out
	return CuePattern.new(q)

func filter_values(f: Callable) -> CuePattern:
	var inner := query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for h in inner.call(state):
			if f.call(h.value):
				out.append(h)
		return out
	return CuePattern.new(q)

func with_query_span(f: Callable) -> CuePattern:
	var inner := query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var span: CueSpan = f.call(state["span"])
		var out: Array[CueHap] = []
		out.append_array(inner.call(make_state(span, state["controls"])))
		return out
	return CuePattern.new(q)

func with_query_time(f: Callable) -> CuePattern:
	return with_query_span(func(s: CueSpan) -> CueSpan: return s.with_time(f))

func with_hap_span(f: Callable) -> CuePattern:
	var inner := query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for h in inner.call(state):
			out.append(h.with_span(f))
		return out
	return CuePattern.new(q)

func with_hap_time(f: Callable) -> CuePattern:
	return with_hap_span(func(s: CueSpan) -> CueSpan: return s.with_time(f))

func split_queries() -> CuePattern:
	var inner := query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var span: CueSpan = state["span"]
		var out: Array[CueHap] = []
		for sub in span.span_cycles():
			out.append_array(inner.call(make_state(sub, state["controls"])))
		return out
	return CuePattern.new(q)

# Like with_query_span, but a null mapped span means the query misses the
# pattern entirely (the gap after fast_gap's compressed portion).
func _with_query_span_maybe(f: Callable) -> CuePattern:
	var inner := query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var mapped = f.call(state["span"])
		if mapped == null:
			var empty: Array[CueHap] = []
			return empty
		var span: CueSpan = mapped
		var out: Array[CueHap] = []
		out.append_array(inner.call(make_state(span, state["controls"])))
		return out
	return CuePattern.new(q)

func compress(b: CueFrac, e: CueFrac) -> CuePattern:
	if b.gt(e) or b.gt(CueFrac.one()) or e.gt(CueFrac.one()):
		return silence()
	if b.lt(CueFrac.zero()) or e.lt(CueFrac.zero()):
		return silence()
	if b.eq(e):
		return silence()
	return fast_gap(CueFrac.one().div(e.sub(b))).late(b)

func fast_gap(factor: CueFrac) -> CuePattern:
	if factor.le(CueFrac.zero()):
		return silence()
	factor = factor.max(CueFrac.one())
	var qf := func(span: CueSpan) -> CueSpan:
		var cycle := span.begin.sam()
		var bpos := span.begin.sub(cycle).mul(factor).min(CueFrac.one())
		var epos := span.end.sub(cycle).mul(factor).min(CueFrac.one())
		if bpos.ge(CueFrac.one()):
			return null
		return CueSpan.make(cycle.add(bpos), cycle.add(epos))
	var ef := func(hap: CueHap) -> CueHap:
		var b := hap.part.begin
		var e := hap.part.end
		var cycle := b.sam()
		var bpos := b.sub(cycle).div(factor).min(CueFrac.one())
		var epos := e.sub(cycle).div(factor).min(CueFrac.one())
		var new_part := CueSpan.make(cycle.add(bpos), cycle.add(epos))
		var new_whole: CueSpan = null
		if hap.whole != null:
			new_whole = CueSpan.make(
				new_part.begin.sub(b.sub(hap.whole.begin).div(factor)),
				new_part.end.add(hap.whole.end.sub(e).div(factor)))
		return CueHap.make(new_whole, new_part, hap.value)
	var inner := _with_query_span_maybe(qf).query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for h in inner.call(state):
			out.append(ef.call(h))
		return out
	return CuePattern.new(q).split_queries()

func fast(k: CueFrac) -> CuePattern:
	if k.le(CueFrac.zero()):
		return silence()
	return with_query_time(func(t: CueFrac) -> CueFrac: return t.mul(k)).with_hap_time(func(t: CueFrac) -> CueFrac: return t.div(k))

func slow(k: CueFrac) -> CuePattern:
	if k.is_zero():
		return silence()
	return fast(CueFrac.one().div(k))

func early(c: CueFrac) -> CuePattern:
	return with_query_time(func(t: CueFrac) -> CueFrac: return t.add(c)).with_hap_time(func(t: CueFrac) -> CueFrac: return t.sub(c))

func late(c: CueFrac) -> CuePattern:
	return early(c.neg())

# Reflect every hap within its cycle. A zero-width query at the very start of a
# cycle reflects onto the next cycle's start: a known limitation when rev is
# used on a patterned argument sampled exactly on a cycle boundary.
func rev() -> CuePattern:
	var inner := query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var span: CueSpan = state["span"]
		var cycle := span.begin.sam()
		var next := span.begin.next_sam()
		var reflect := func(s: CueSpan) -> CueSpan:
			return CueSpan.make(cycle.add(next).sub(s.end), cycle.add(next).sub(s.begin))
		var sub: Array[CueHap] = []
		sub.append_array(inner.call(make_state(reflect.call(span), state["controls"])))
		var out: Array[CueHap] = []
		for h in sub:
			out.append(h.with_span(reflect))
		return out
	return CuePattern.new(q).split_queries()

func struct(bools: CuePattern) -> CuePattern:
	return _app_left_whole(bools.filter_values(truthy), self, func(_b: Variant, v: Variant) -> Variant: return v)

func mask(bools: CuePattern) -> CuePattern:
	var inner := query
	var bool_query := bools.query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for h: CueHap in inner.call(state):
			for b: CueHap in bool_query.call(make_state(h.part, state["controls"])):
				if truthy(b.value):
					var p = h.part.intersection(b.part)
					if p != null:
						out.append(CueHap.make(h.whole, p, h.value))
		return out
	return CuePattern.new(q)

func segment(k: CueFrac) -> CuePattern:
	return struct(pure(true).fast(k))

func range(lo: float, hi: float) -> CuePattern:
	return fmap(func(v: Variant) -> Variant: return float(v) * (hi - lo) + lo)

func range_pat(lo: CuePattern, hi: CuePattern) -> CuePattern:
	return app_left(lo, func(v: Variant, l: Variant) -> Variant:
		return {"v": v, "lo": l}).app_left(hi, func(d: Variant, h: Variant) -> Variant:
			return float(d["v"]) * (float(h) - float(d["lo"])) + float(d["lo"]))

# The control join: structure and parts come from the receiver, and the argument
# is sampled at each receiver hap's whole begin (part begin for a signal), never
# over a span. A silent argument or a null fn result drops the hap.
func app_left(arg: CuePattern, fn: Callable) -> CuePattern:
	var inner := query
	var arg_query := arg.query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for h: CueHap in inner.call(state):
			var t: CueFrac = h.part.begin
			if h.whole != null:
				t = h.whole.begin
			var hits: Array[CueHap] = []
			hits.append_array(arg_query.call(make_state(CueSpan.make(t, t), state["controls"])))
			if hits.is_empty():
				continue
			var v: Variant = fn.call(h.value, hits[0].value)
			if typeof(v) == TYPE_NIL:
				continue
			out.append(CueHap.make(h.whole, h.part, v))
		return out
	return CuePattern.new(q)

func ply(k: int) -> CuePattern:
	if k <= 0:
		return silence()
	var inner := query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for h: CueHap in inner.call(state):
			if h.whole == null:
				out.append(h)
				continue
			var d: CueFrac = h.whole.duration().div(CueFrac.make(k))
			for i in k:
				var w := CueSpan.make(h.whole.begin.add(d.mul(CueFrac.make(i))), h.whole.begin.add(d.mul(CueFrac.make(i + 1))))
				var p = w.intersection(h.part)
				if p != null:
					out.append(CueHap.make(w, p, h.value))
		return out
	return CuePattern.new(q)

# Replicate the pattern k times within each cycle, each copy early by i/k, then
# pick one copy per cycle (cat's own offsetting is part of Strudel's iter).
func iter(k: int) -> CuePattern:
	if k <= 0:
		return self
	var pats: Array[CuePattern] = []
	for i in k:
		pats.append(early(CueFrac.make(i, k)))
	return cat(pats)

func palindrome() -> CuePattern:
	return slowcat_prime([self, rev()])

func euclid(k: int, n: int, rot: int = 0) -> CuePattern:
	return struct(euclid_bools(k, n, rot))

# Seeded degradation: the draw is keyed on the hap's whole begin, so fragments
# of one hap always get the same decision and window splitting cannot change it.
func degrade_by(p: float, seed: int, site: int, invert: bool = false) -> CuePattern:
	var inner := query
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		for h: CueHap in inner.call(state):
			var t: CueFrac = h.part.begin
			if h.whole != null:
				t = h.whole.begin
			var r := CueSignals.hash01(seed, site, t)
			var keep := ((1.0 - r) >= p) if invert else (r >= p)
			if keep:
				out.append(h)
		return out
	return CuePattern.new(q)

static func _floor_div(n: int, d: int) -> int:
	var q := n / d
	if n % d != 0 and n < 0:
		q -= 1
	return q
