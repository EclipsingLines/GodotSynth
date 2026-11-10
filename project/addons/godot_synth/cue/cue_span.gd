## An immutable time span [begin, end) on the cue timeline.
##
## Both ends are CueFrac, so spans stay exact no matter how a query window is
## sliced. A span can be zero-width when a query asks for an instant.
class_name CueSpan extends RefCounted

var begin: CueFrac
var end: CueFrac

func _init(b: CueFrac, e: CueFrac) -> void:
	begin = b
	end = e

static func make(b: CueFrac, e: CueFrac) -> CueSpan:
	return CueSpan.new(b, e)

func duration() -> CueFrac:
	return end.sub(begin)

func midpoint() -> CueFrac:
	return begin.add(end).div(CueFrac.make(2))

func eq(o: CueSpan) -> bool:
	return begin.eq(o.begin) and end.eq(o.end)

func with_time(f: Callable) -> CueSpan:
	return CueSpan.make(f.call(begin), f.call(end))

# Split at integer cycle boundaries. A zero-width span stays whole.
func span_cycles() -> Array[CueSpan]:
	var out: Array[CueSpan] = []
	if begin.eq(end):
		out.append(self)
		return out
	var b := begin
	while end.gt(b):
		if b.sam().eq(end.sam()):
			out.append(CueSpan.make(b, end))
			break
		var nb := b.next_sam()
		out.append(CueSpan.make(b, nb))
		b = nb
	return out

# The overlap with another span, or null when they do not overlap. A
# zero-width result is dropped when it only touches the end of a real span.
func intersection(o: CueSpan) -> CueSpan:
	var b := begin.max(o.begin)
	var e := end.min(o.end)
	if b.gt(e):
		return null
	if b.eq(e):
		if b.eq(end) and begin.lt(end):
			return null
		if b.eq(o.end) and o.begin.lt(o.end):
			return null
	return CueSpan.make(b, e)

func _to_string() -> String:
	return "[%s, %s)" % [str(begin), str(end)]
