class_name CuePlayer
extends Node
## Plays an adaptive cue (.cue file): loads it, creates the players, drives the conductor from the audio clock.

## Emitted when the audio clock passes a state switch point (not when set_state was called).
signal state_changed(from_state: String, to_state: String)

@export_file("*.cue") var cue_path: String = ""
@export var autoplay: bool = false

var catalog: CueCatalog
var transport: SynthTransport
var conductor: CueConductor
var players: Dictionary = {}          # "group/instrument" -> AudioSynthPlayer
var pairs: Dictionary = {}            # CueScan result: {group: PackedStringArray}
var diagnostics: Array[Dictionary] = []   # of the last load (errors and warnings)

var _sink: CueLiveSink
var _loaded: bool = false
var _playing: bool = false
var _log_seen: int = 0
var _announce: Array[Dictionary] = []    # {cycle, from, to}: switches the clock has not passed yet

func load_cue(path: String) -> Array[Dictionary]:
	_unload()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var diagnostic: Dictionary = {"code": "E_IO", "message": "cannot read " + path, "line": 0, "col": 0, "severity": "error"}
		diagnostics = [diagnostic]
		return diagnostics
	var source := file.get_as_text()
	file.close()
	return load_source(source)

func load_source(source: String) -> Array[Dictionary]:
	_unload()
	if catalog == null:
		catalog = CueCatalog.load_default()
	if not catalog.errors.is_empty():
		var cat_diag: Dictionary = {"code": "E_CATALOG", "message": String(catalog.errors[0]), "line": 0, "col": 0, "severity": "error"}
		diagnostics = [cat_diag]
		return diagnostics
	var parsed: Dictionary = CueParser.parse(source)
	if not bool(parsed["ok"]):
		diagnostics.assign(parsed["diagnostics"])
		return diagnostics
	var validated: Array[Dictionary] = CueValidator.validate(parsed["ast"], catalog.validator_catalog())
	for d: Dictionary in validated:
		if String(d["severity"]) == "error":
			diagnostics = validated
			return diagnostics
	var compiled: Dictionary = CueLib.compile(parsed["ast"], 0)
	if not (compiled["errors"] as Array).is_empty():
		var errs: Array[Dictionary] = []
		for e: Variant in compiled["errors"]:
			var entry: Dictionary = e
			errs.append({
				"code": String(entry["code"]),
				"message": String(entry["message"]),
				"line": int(entry["line"]),
				"col": int(entry["col"]),
				"severity": "error",
			})
		diagnostics = errs
		return diagnostics
	var scan: Dictionary = CueScan.instruments(parsed["ast"])
	pairs = scan
	_sink = CueLiveSink.new()
	for group: Variant in scan:
		var g := String(group)
		var instruments: PackedStringArray = scan[group]
		for inst: String in instruments:
			var p := AudioSynthPlayer.new()
			var cfg := catalog.create_configuration(inst)
			if cfg == null:
				var cfg_diag: Dictionary = {"code": "E_CATALOG", "message": "cannot create configuration for '" + inst + "'", "line": 0, "col": 0, "severity": "error"}
				_unload()
				diagnostics = [cfg_diag]
				return diagnostics
			p.configuration = cfg
			p.polyphony = catalog.polyphony(inst)
			p.name = "%s_%s" % [g, inst]
			add_child(p)
			players[g + "/" + inst] = p
			_sink.register_player(g, inst, p)
	transport = SynthTransport.new()
	add_child(transport)
	for key: Variant in players:
		transport.players.append(players[key])
	var tempo: Dictionary = compiled["tempo"]
	transport.reset_tempo(float(tempo["bpm"]) / 60.0 / float(tempo["beats"]))
	conductor = CueConductor.new(compiled, catalog, _sink, transport.cycle_to_frame, pairs)
	_loaded = true
	diagnostics = validated
	return diagnostics

func is_loaded() -> bool:
	return _loaded

func is_playing() -> bool:
	return _playing

func play() -> bool:
	if not _loaded or transport == null or conductor == null:
		push_warning("CuePlayer: play() before load")
		return false
	if not is_inside_tree():
		push_warning("CuePlayer: play() requires the node in the scene tree")
		return false
	transport.start()
	_sink.origin_frame = transport.origin_frame
	conductor.start()
	_log_seen = 0
	_announce.clear()
	_playing = true
	return true

func stop() -> void:
	_playing = false
	if transport != null:
		transport.stop()

func set_state(name: String) -> bool:
	if not _loaded or not _playing or conductor == null:
		push_warning("CuePlayer: set_state before play")
		return false
	return conductor.set_state(name)

func get_state() -> String:
	if _loaded and _playing and conductor != null:
		return conductor.get_state()
	return ""

func get_pending_state() -> String:
	if _loaded and conductor != null:
		return conductor.get_pending_state()
	return ""

func stinger(name: String) -> bool:
	if not _loaded or not _playing or conductor == null:
		push_warning("CuePlayer: stinger before play")
		return false
	return conductor.stinger(name)

func set_param(name: String, value: float) -> bool:
	if not _loaded or not _playing or conductor == null:
		push_warning("CuePlayer: set_param before play")
		return false
	return conductor.set_param(name, value)

func get_param(name: String) -> float:
	if _loaded and conductor != null:
		return conductor.get_param(name)
	return 0.0

func get_current_cycle() -> float:
	if transport != null:
		return transport.get_current_cycle()
	return 0.0

func get_state_names() -> PackedStringArray:
	var out := PackedStringArray()
	if conductor == null:
		return out
	for key: Variant in conductor.compiled["states"]:
		out.append(String(key))
	return out

func get_stinger_names() -> PackedStringArray:
	var out := PackedStringArray()
	if conductor == null:
		return out
	for key: Variant in conductor.compiled["stingers"]:
		out.append(String(key))
	return out

func get_param_names() -> PackedStringArray:
	var out := PackedStringArray()
	if conductor == null:
		return out
	for key: Variant in conductor.compiled["params"]:
		out.append(String(key))
	return out

func get_param_range(name: String) -> Vector2:
	if conductor == null:
		return Vector2.ZERO
	var params: Dictionary = conductor.compiled["params"]
	if not params.has(name):
		return Vector2.ZERO
	var p: Dictionary = params[name]
	return Vector2(float(p["lo"]), float(p["hi"]))

func _process(_delta: float) -> void:
	if not _playing:
		return
	var w := transport.poll_window()
	if not w.is_empty():
		conductor.process_window(w.from_cycle, w.to_cycle)
		var log := conductor.get_log()
		while _log_seen < log.size():
			var e: Dictionary = log[_log_seen]
			_log_seen += 1
			if e["type"] == "switch":
				_announce.append({"cycle": e["cycle"], "from": e["from"], "to": e["to"]})
	var now := transport.get_current_cycle()
	while not _announce.is_empty() and now >= float(_announce[0]["cycle"]):
		var a: Dictionary = _announce.pop_front()
		state_changed.emit(a["from"], a["to"])

func _ready() -> void:
	if autoplay and cue_path != "":
		var ds := load_cue(cue_path)
		if _loaded:
			play()
		elif not ds.is_empty():
			push_warning(String(ds[0]["message"]))

func _exit_tree() -> void:
	stop()

func _unload() -> void:
	stop()
	for child: Node in get_children():
		var in_tree := child.is_inside_tree()
		remove_child(child)
		if in_tree:
			child.queue_free()
		else:
			child.free()
	players.clear()
	pairs.clear()
	transport = null
	conductor = null
	_sink = null
	_loaded = false
	_playing = false
	_announce.clear()
	_log_seen = 0
