## An immutable happening: the whole event span, the fragment this query
## actually returns, and the event value.
##
## `whole` is null for continuous (signal) haps. A hap has an onset only when
## the fragment starts where the whole event starts; a fragment that crosses a
## query boundary shares the whole span but has no onset.
class_name CueHap extends RefCounted

var whole: CueSpan
var part: CueSpan
var value: Variant

func _init(w: CueSpan, p: CueSpan, v: Variant) -> void:
	whole = w
	part = p
	value = v

static func make(w: CueSpan, p: CueSpan, v: Variant) -> CueHap:
	return CueHap.new(w, p, v)

func has_onset() -> bool:
	return whole != null and whole.begin.eq(part.begin)

func whole_or_part() -> CueSpan:
	return whole if whole != null else part

func with_span(f: Callable) -> CueHap:
	var w: CueSpan = null
	if whole != null:
		w = f.call(whole)
	return CueHap.make(w, f.call(part), value)

func with_value(f: Callable) -> CueHap:
	return CueHap.make(whole, part, f.call(value))

func _to_string() -> String:
	var w := str(whole) if whole != null else "~"
	return "%s | %s %s" % [w, str(part), str(value)]
