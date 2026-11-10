class_name SynthTransport
extends Node
## Audio-clock transport: tempo map (cycles <-> frames), lookahead windows, synchronized start.
##
## A cycle is the unit of the tempo map (one cycle = one pattern repetition) and
## tempo is cycles per second (cps). The map is a list of segments
## [code]{start_frame, start_cycle, cps}[/code] relative to the transport origin
## (frame 0 = cycle 0); [member origin_frame] is the player clock value of cycle 0.
## [method poll_window] hands out contiguous cycle windows to schedule, and
## [method start] restarts every player in one mix step so their clocks agree.

## Cycles [from_cycle, to_cycle) to schedule next. 64-bit floats, so no Vector2.
class CycleWindow extends RefCounted:
	var from_cycle: float = 0.0
	var to_cycle: float = 0.0
	func is_empty() -> bool:
		return to_cycle <= from_cycle

## How far ahead of the audio clock [method poll_window] schedules, in seconds.
@export var lookahead_sec: float = 0.15
## How far in the future cycle 0 lies after [method start], in seconds.
@export var start_delay_sec: float = 0.1
## Seconds between drift checks of the players' clocks while running.
@export var drift_check_interval_sec: float = 1.0

## Players started together by [method start] and scheduled on the same clock.
var players: Array[AudioSynthPlayer] = []
## Mix rate used by the tempo map, in frames per second.
var sample_rate: int = 44100
## Player clock value (frames) of cycle 0. Valid after start().
var origin_frame: int = 0
## Returns the current audio clock in frames (int). Default: players[0].get_mixed_frames().
var frame_source: Callable = Callable()
## True between [method start] and [method stop].
var running: bool = false

var _segments: Array[Dictionary] = []
var _scheduled_to: float = 0.0
var _drift_warned: bool = false
var _drift_timer: float = 0.0

func _init() -> void:
	reset_tempo(0.5)

## Replaces the tempo map with a single segment at [param p_cps] and rewinds the window cursor to cycle 0.
func reset_tempo(p_cps: float) -> void:
	assert(p_cps > 0.0)
	_segments.clear()
	_segments.append({"start_frame": 0, "start_cycle": 0.0, "cps": p_cps})
	_scheduled_to = 0.0

## Tempo (cps) of the segment containing the end of what has been scheduled (the last segment).
func get_cps() -> float:
	return _segments[_segments.size() - 1]["cps"]

## Frame of [param c], relative to the origin, on the segment containing it.
func cycle_to_frame(c: float) -> int:
	var s := _segments[_segment_for_cycle(c)]
	return int(s["start_frame"]) + roundi((c - float(s["start_cycle"])) / float(s["cps"]) * float(sample_rate))

## Cycle of [param f], relative to the origin, on the segment containing it.
func frame_to_cycle(f: int) -> float:
	var s := _segments[_segment_for_frame(f)]
	return float(s["start_cycle"]) + float(f - int(s["start_frame"])) * float(s["cps"]) / float(sample_rate)

## Player-clock frame of cycle [param c]: [member origin_frame] plus the relative frame.
func cycle_to_absolute_frame(c: float) -> int:
	return origin_frame + cycle_to_frame(c)

## Changes the tempo at the next whole cycle at or after the end of what [method poll_window] handed out.
## A later call before the next poll replaces the pending change.
func set_cps(p_cps: float) -> void:
	assert(p_cps > 0.0)
	var boundary := ceilf(_scheduled_to)
	while _segments.size() > 1 and float(_segments[_segments.size() - 1]["start_cycle"]) >= boundary:
		_segments.pop_back()
	if float(_segments[0]["start_cycle"]) >= boundary:   # nothing scheduled yet (boundary == 0.0)
		_segments[0]["cps"] = p_cps
		return
	if is_equal_approx(float(_segments[_segments.size() - 1]["cps"]), p_cps):
		return
	_segments.append({"start_frame": cycle_to_frame(boundary), "start_cycle": boundary, "cps": p_cps})

## Next cycles [from_cycle, to_cycle) to schedule: [code]from_cycle[/code] is the previous
## call's [code]to_cycle[/code] (0.0 on the first call) and [code]to_cycle[/code] is the
## lookahead horizon, so consecutive windows neither overlap nor leave gaps.
func poll_window() -> CycleWindow:
	var w := CycleWindow.new()
	w.from_cycle = _scheduled_to
	w.to_cycle = _scheduled_to
	if not running:
		return w
	var horizon := _now_frame() - origin_frame + roundi(lookahead_sec * float(sample_rate))
	var to_cycle := frame_to_cycle(horizon)
	if to_cycle > _scheduled_to:
		w.to_cycle = to_cycle
		_scheduled_to = to_cycle
	return w

## Restarts every player under [method AudioServer.lock] so their clocks start together,
## then places cycle 0 [member start_delay_sec] in the future.
func start() -> void:
	if frame_source.is_null():
		sample_rate = roundi(AudioServer.get_mix_rate())
	reset_tempo(get_cps())
	if players.is_empty():
		origin_frame = _now_frame() + roundi(start_delay_sec * float(sample_rate))
	else:
		AudioServer.lock()
		for p in players:
			p.restart_stream()
		origin_frame = _now_frame() + roundi(start_delay_sec * float(sample_rate))   # read while locked
		AudioServer.unlock()
	_drift_warned = false
	_drift_timer = 0.0
	running = true

## Stops every player under [method AudioServer.lock] and stops handing out windows.
func stop() -> void:
	running = false
	if not players.is_empty():
		AudioServer.lock()
		for p in players:
			p.stop()
		AudioServer.unlock()

## Cycle at the audio clock, clamped to 0.0; 0.0 while stopped.
func get_current_cycle() -> float:
	if not running:
		return 0.0
	return maxf(0.0, frame_to_cycle(_now_frame() - origin_frame))

## True if all players report the same mixed_frames; warns once if not. Reads under AudioServer.lock().
func check_drift() -> bool:
	if players.size() < 2:
		return true
	var counts: Array[int] = []
	AudioServer.lock()
	for p in players:
		counts.append(p.get_mixed_frames())
	AudioServer.unlock()
	return check_drift_values(counts)

## Compares the given mixed_frames counts and warns once when they differ.
func check_drift_values(counts: Array[int]) -> bool:
	for c in counts:
		if c != counts[0]:
			if not _drift_warned:
				_drift_warned = true
				push_warning("SynthTransport: players' mixed_frames differ: %s" % [counts])
			return false
	return true

func _process(delta: float) -> void:
	if running and players.size() > 1:
		_drift_timer += delta
		if _drift_timer >= drift_check_interval_sec:
			_drift_timer = 0.0
			check_drift()

func _now_frame() -> int:
	if frame_source.is_valid():
		return int(frame_source.call())
	if players.is_empty():
		return 0
	return players[0].get_mixed_frames()

func _segment_for_cycle(c: float) -> int:
	for i in range(_segments.size() - 1, -1, -1):
		if float(_segments[i]["start_cycle"]) <= c:
			return i
	return 0

func _segment_for_frame(f: int) -> int:
	for i in range(_segments.size() - 1, -1, -1):
		if int(_segments[i]["start_frame"]) <= f:
			return i
	return 0
