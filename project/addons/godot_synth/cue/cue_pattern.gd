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

static func _floor_div(n: int, d: int) -> int:
	var q := n / d
	if n % d != 0 and n < 0:
		q -= 1
	return q
