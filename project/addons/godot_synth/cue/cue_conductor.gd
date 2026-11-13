class_name CueConductor
extends RefCounted
## The cue state machine: initial state, quantized switches, crossfades, fills. Clock-agnostic.
##
## It drives a CueScheduler and a CueSink, so the live CuePlayer and the offline cue_render share
## the same state logic. Frames are relative to cycle 0, as the scheduler and sink expect.

const FADE_SEGMENTS := 16

var scheduler: CueScheduler            # public: params and controls live here (GS-028)
var beats_per_bar: int = 4
var compiled: Dictionary
var catalog: CueCatalog
var sink: CueSink
var cycle_to_frame: Callable

var _pairs: Dictionary                 # {group: PackedStringArray} from CueScan; used by binds
var _stinger_src: Dictionary = {}      # name -> id of the last instance
var _bind_last: Dictionary = {}        # "<inst>.<control>" -> last emitted mapped value
var _current: String = ""
var _current_src: String = ""
var _pending: Dictionary = {}          # {to, t_sw, rule} or empty
var _scheduled_to: float = 0.0
var _live: Array[Dictionary] = []      # {id, state} for old instances that may still be fading
var _ramps: Array[Dictionary] = []     # queued gain entries {group, gain, start, end}
var _log: Array[Dictionary] = []
var _counter: int = 0
var _started: bool = false

## p_pairs: {group: PackedStringArray} from CueScan.instruments(ast); used by GS-028 (binds). May be {}.
func _init(p_compiled: Dictionary, p_catalog: CueCatalog, p_sink: CueSink, p_cycle_to_frame: Callable, p_pairs: Dictionary = {}) -> void:
	compiled = p_compiled
	catalog = p_catalog
	sink = p_sink
	cycle_to_frame = p_cycle_to_frame
	_pairs = p_pairs
	beats_per_bar = maxi(1, int(compiled["tempo"]["beats"]))
	_make_scheduler()

## Resets all runtime state and starts the first state at cycle 0.
func start() -> void:
	_current = ""
	_current_src = ""
	_pending = {}
	_scheduled_to = 0.0
	_live = []
	_ramps = []
	_stinger_src = {}
	_bind_last = {}
	_log = []
	_counter = 0
	_started = false
	_make_scheduler()
	var states: Dictionary = compiled["states"]
	if states.is_empty():
		push_error("CueConductor: no states to start")
		return
	_current = String(states.keys()[0])
	_current_src = _new_id("state", _current)
	scheduler.add_source(_current_src, _current, states[_current], 0.0, 0.0)
	_started = true

func is_started() -> bool:
	return _started

## Requests a switch to `name` on its quantized boundary. False when not started or unknown.
func set_state(name: String) -> bool:
	if not _started:
		push_warning("CueConductor: set_state before start")
		return false
	var states: Dictionary = compiled["states"]
	if not states.has(name):
		push_warning("CueConductor: unknown state '%s'" % name)
		return false
	if name == _current:
		if not _pending.is_empty():
			_pending = {}
			_log.append({"type": "request", "cycle": _scheduled_to, "from": _current, "to": name, "cancelled": true})
		return true
	var rule := _find_rule(_current, name)
	var t_sw := CueScheduler.next_boundary(_scheduled_to, rule["quant"], beats_per_bar)
	_pending = {"to": name, "t_sw": t_sw, "rule": rule}
	_log.append({
		"type": "request",
		"cycle": _scheduled_to,
		"from": _current,
		"to": name,
		"t_sw": t_sw,
		"quant": rule["quant"],
		"fade": float(rule["fade"]),
		"has_fill": rule["fill"] != null,
		"cancelled": false,
	})
	return true

## The state that is playing now (the old one until a pending switch is applied).
func get_state() -> String:
	return _current

func get_pending_state() -> String:
	if _pending.is_empty():
		return ""
	return String(_pending["to"])

## Switch point of the pending request, -1.0 when none.
func get_pending_cycle() -> float:
	if _pending.is_empty():
		return -1.0
	return float(_pending["t_sw"])

## End of the last processed window.
func get_scheduled_to() -> float:
	return _scheduled_to

func process_window(from_c: float, to_c: float) -> void:
	if to_c <= from_c:
		return
	var live: Array[Dictionary] = []
	for entry in _live:
		if scheduler.has_source(String(entry["id"])):
			live.append(entry)
	_live = live
	if not _pending.is_empty() and float(_pending["t_sw"]) < to_c:
		_apply_switch()
	_emit_ramps(to_c)
	_emit_binds(from_c)
	scheduler.process_window(from_c, to_c)
	_scheduled_to = to_c

func get_log() -> Array[Dictionary]:
	return _log

## Plays `name` from its next quantized boundary, layered over the current state. A retrigger
## ends the previous instance at the new start. False when not started or unknown.
func stinger(name: String) -> bool:
	if not _started or not compiled["stingers"].has(name):
		push_warning("CueConductor: unknown stinger '%s'" % name)
		return false
	var st: Dictionary = compiled["stingers"][name]
	var t0 := CueScheduler.next_boundary(_scheduled_to, st["quant"], beats_per_bar)
	var id := _new_id("stinger", name)
	if _stinger_src.has(name):
		var prev: Dictionary = scheduler.get_source(_stinger_src[name])
		if not prev.is_empty() and float(prev["end"]) > t0:
			scheduler.set_source_end(_stinger_src[name], t0)
	scheduler.add_source(id, "stingers", st["pattern"], t0, t0, t0 + float(st["len"]))
	_stinger_src[name] = id
	_log.append({"type": "stinger", "cycle": t0, "name": name, "requested": _scheduled_to})
	return true

## Sets a game param, clamped into its declared range. False when not started or unknown.
func set_param(name: String, value: float) -> bool:
	if not _started or not compiled["params"].has(name):
		push_warning("CueConductor: unknown param '%s'" % name)
		return false
	var p: Dictionary = compiled["params"][name]
	var v := clampf(value, float(p["lo"]), float(p["hi"]))
	scheduler.controls["params"][name] = v
	_log.append({"type": "param", "cycle": _scheduled_to, "name": name, "value": v})
	return true

func get_param(name: String) -> float:
	var params: Dictionary = scheduler.controls["params"]
	if not params.has(name):
		push_warning("CueConductor: unknown param '%s'" % name)
		return 0.0
	return float(params[name])

func _make_scheduler() -> void:
	scheduler = CueScheduler.new(catalog, sink, cycle_to_frame)
	var defaults: Dictionary = {}
	var params: Dictionary = compiled["params"]
	for name: String in params:
		defaults[name] = float(params[name]["default"])
	scheduler.controls = {"params": defaults}

func _new_id(prefix: String, name: String) -> String:
	var id := "%s:%s:%d" % [prefix, name, _counter]
	_counter += 1
	return id

func _find_rule(from: String, to: String) -> Dictionary:
	var fallback: Dictionary = {}
	var transitions: Array = compiled["transitions"]
	for entry: Variant in transitions:
		if not (entry is Dictionary):
			continue
		var rule: Dictionary = entry
		if String(rule["to"]) != to:
			continue
		if String(rule["from"]) == from:
			return rule
		if fallback.is_empty() and String(rule["from"]) == "*":
			fallback = rule
	if not fallback.is_empty():
		return fallback
	return {"quant": {"kind": "bar", "count": 1}, "fade": 0.0, "fill": null}

func _apply_switch() -> void:
	var p := _pending
	_pending = {}
	var t := float(p["t_sw"])
	var to := String(p["to"])
	var rule: Dictionary = p["rule"]
	var fade := float(rule["fade"])
	var old := _current
	var old_end := t + fade if fade > 0.0 else t
	scheduler.set_source_end(_current_src, old_end)
	_live.append({"id": _current_src, "state": old})
	for entry in _live:
		if String(entry["state"]) != to:
			continue
		var s := scheduler.get_source(String(entry["id"]))
		if not s.is_empty() and float(s["end"]) > t:
			scheduler.set_source_end(String(entry["id"]), t)
	var kept: Array[Dictionary] = []
	for entry in _ramps:
		var group := String(entry["group"])
		if (group == old or group == to) and float(entry["start"]) >= t:
			continue
		kept.append(entry)
	_ramps = kept
	_current = to
	_current_src = _new_id("state", to)
	var states: Dictionary = compiled["states"]
	scheduler.add_source(_current_src, to, states[to], t, t)
	if fade > 0.0:
		_ramps.append({"group": to, "gain": 0.0, "start": t, "end": t})
		for i in range(1, FADE_SEGMENTS + 1):
			var c0 := t + fade * float(i - 1) / float(FADE_SEGMENTS)
			var c1 := t + fade * float(i) / float(FADE_SEGMENTS)
			var x := float(i) / float(FADE_SEGMENTS)
			var up := 1.0 if i == FADE_SEGMENTS else sin(x * PI / 2.0)
			var down := 0.0 if i == FADE_SEGMENTS else cos(x * PI / 2.0)
			_ramps.append({"group": to, "gain": up, "start": c0, "end": c1})
			_ramps.append({"group": old, "gain": down, "start": c0, "end": c1})
	else:
		_ramps.append({"group": to, "gain": 1.0, "start": t, "end": t})
	if rule["fill"] != null:
		scheduler.add_source(_new_id("fill", to), "transitions", rule["fill"], t, t, t + maxf(1.0, fade))
	_log.append({"type": "switch", "cycle": t, "from": old, "to": to, "fade": fade, "fill": rule["fill"] != null})

func _emit_binds(from_c: float) -> void:
	var params: Dictionary = scheduler.controls["params"]
	var frame := int(cycle_to_frame.call(from_c))
	for b: Dictionary in compiled["binds"]:
		var inst: String = b["inst"]
		var control: String = b["control"]
		if not params.has(b["param"]) or not compiled["params"].has(b["param"]):
			continue
		var target: String = catalog.control_target(inst, control)
		if target == "":
			continue
		var p: Dictionary = compiled["params"][b["param"]]
		var pmin := float(p["lo"])
		var pmax := float(p["hi"])
		var t := 0.0 if pmax == pmin else (float(params[b["param"]]) - pmin) / (pmax - pmin)
		var rng: Vector2 = catalog.control_range(inst, control)
		var lo: float = float(b["lo"]) if b["lo"] != null else rng.x
		var hi: float = float(b["hi"]) if b["hi"] != null else rng.y
		var mapped: float = catalog.map_control_value(inst, control, lerpf(lo, hi, t))
		var key := inst + "." + control
		if _bind_last.has(key) and _bind_last[key] == mapped:
			continue
		_bind_last[key] = mapped
		for group: String in _pairs:
			if inst in _pairs[group]:
				sink.param(group + "/" + inst, target, mapped, frame)

func _emit_ramps(to_c: float) -> void:
	var kept: Array[Dictionary] = []
	for entry in _ramps:
		if float(entry["start"]) >= to_c:
			kept.append(entry)
			continue
		var f0 := int(cycle_to_frame.call(float(entry["start"])))
		var f1 := int(cycle_to_frame.call(float(entry["end"])))
		sink.gain_ramp(String(entry["group"]), float(entry["gain"]), f0, maxi(0, f1 - f0))
	_ramps = kept
