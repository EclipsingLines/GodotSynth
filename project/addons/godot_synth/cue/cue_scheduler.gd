class_name CueScheduler
extends RefCounted
## Turns pattern sources into frame-stamped note events, one lookahead window at a time.

var catalog: CueCatalog
var sink: CueSink
var cycle_to_frame: Callable          # float cycle -> int frame (relative to cycle 0)
var controls: Dictionary = {}         # passed to every pattern query, e.g. {"params": {"danger": 0.5}}

var _sources: Array[Dictionary] = []
var _warned: Dictionary = {}

func _init(p_catalog: CueCatalog, p_sink: CueSink, p_cycle_to_frame: Callable) -> void:
	catalog = p_catalog
	sink = p_sink
	cycle_to_frame = p_cycle_to_frame

## Adds a source. An existing source with the same id is replaced (removed, the new one appended).
func add_source(id: String, group: String, pattern: CuePattern, t0: float, start: float, end: float = INF) -> void:
	remove_source(id)
	_sources.append({"id": id, "group": group, "pattern": pattern, "t0": t0, "start": start, "end": end})

func has_source(id: String) -> bool:
	for src in _sources:
		if src["id"] == id:
			return true
	return false

func get_source(id: String) -> Dictionary:
	for src in _sources:
		if src["id"] == id:
			return src.duplicate()
	return {}

func set_source_end(id: String, end: float) -> void:
	for src in _sources:
		if src["id"] == id:
			src["end"] = end
			return

func remove_source(id: String) -> void:
	for i in range(_sources.size() - 1, -1, -1):
		if _sources[i]["id"] == id:
			_sources.remove_at(i)

func get_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for src in _sources:
		out.append(src.duplicate())
	return out

## Emits the note events of every source for [from_c, to_c).
func process_window(from_c: float, to_c: float) -> void:
	if to_c <= from_c:
		return
	var entries: Array[Dictionary] = []
	for si in _sources.size():
		var src: Dictionary = _sources[si]
		var b := maxf(from_c, float(src["start"]))
		var e := minf(to_c, float(src["end"]))
		if e <= b:
			continue
		var pattern: CuePattern = src["pattern"]
		var haps := pattern.onsets_in(CueFrac.from_float(b - float(src["t0"])), CueFrac.from_float(e - float(src["t0"])), controls)
		for hi in haps.size():
			var hap: CueHap = haps[hi]
			entries.append({"on": float(src["t0"]) + hap.whole.begin.to_float(), "si": si, "hi": hi, "hap": hap, "src": src})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["on"] != b["on"]:
			return a["on"] < b["on"]
		if a["si"] != b["si"]:
			return a["si"] < b["si"]
		return a["hi"] < b["hi"])

	for entry in entries:
		var hap: CueHap = entry["hap"]
		var v: Variant = hap.value
		if not v is Dictionary:
			continue
		var value: Dictionary = v
		var s := String(value.get("s", ""))
		if s == "" or not catalog.has_instrument(s):
			if not _warned.has(s):
				_warned[s] = true
				push_warning("CueScheduler: unknown instrument '%s'" % s)
			continue
		var pitch: float
		if value.has("note"):
			pitch = _num(value["note"], 0.0)
		elif value.has("n"):
			pitch = _num(value["n"], 0.0) + 60.0
		else:
			pitch = float(catalog.default_note(s))
		var velocity := clampf(_num(value.get("velocity", 0.8), 0.8) * _num(value.get("gain", 1.0), 1.0), 0.0, 1.0)
		var legato := _num(value.get("legato", 1.0), 1.0)
		var on_c: float = entry["on"]
		var dur := hap.whole.end.to_float() - hap.whole.begin.to_float()
		var on_frame := int(cycle_to_frame.call(on_c))
		var off_frame := int(cycle_to_frame.call(on_c + dur * legato))
		if off_frame <= on_frame:
			off_frame = on_frame + 1
		var src: Dictionary = entry["src"]
		sink.note(String(src["group"]) + "/" + s, pitch, velocity, on_frame, off_frame, catalog.map_controls(s, value))

	# Sources past their end can never produce another onset.
	for i in range(_sources.size() - 1, -1, -1):
		if float(_sources[i]["end"]) <= to_c:
			_sources.remove_at(i)

static func next_boundary(c: float, quant: Dictionary, beats_per_bar: int) -> float:
	var bpb := maxi(1, beats_per_bar)
	var count := maxi(1, int(quant.get("count", 1)))
	var eps := 1.0e-9
	var result: float
	match String(quant.get("kind", "bar")):
		"now":
			result = c
		"beat":
			result = ceilf(c * bpb - eps) / bpb
		"bars":
			result = ceilf(c / count - eps) * count
		"beats":
			var step := float(count) / bpb
			result = ceilf(c / step - eps) * step
		_:
			result = ceilf(c - eps)
	if c >= 0.0:
		result = maxf(result, 0.0)
	return result

static func _num(x: Variant, default: float) -> float:
	if x is int or x is float:
		return float(x)
	return default
