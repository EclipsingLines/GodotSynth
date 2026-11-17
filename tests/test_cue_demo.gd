extends SceneTree
# The demo cue passes cue_check with the real catalog and the demo scene runs 120 frames headless.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_demo.gd

const CheckerScript = preload("res://addons/godot_synth/cue/cue_checker.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")
const ParserScript = preload("res://addons/godot_synth/cue/cue_parser.gd")
const LibScript = preload("res://addons/godot_synth/cue/cue_lib.gd")
const ScanScript = preload("res://addons/godot_synth/cue/cue_scan.gd")

const CUE_PATH := "res://addons/godot_synth/cue/demo/forest_demo.cue"
const SCENE_PATH := "res://addons/godot_synth/cue/demo/cue_demo.tscn"

var failures: Array[String] = []
var inst: Node = null
var frames := 0
var widgets := {"buttons": [], "sliders": [], "labels": []}

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func finish() -> bool:
	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
	return true

func collect(node: Node) -> void:
	if node is Button:
		widgets["buttons"].append(node)
	elif node is HSlider:
		widgets["sliders"].append(node)
	elif node is Label:
		widgets["labels"].append(node)
	for c in node.get_children():
		collect(c)

func button(text: String) -> Button:
	for b: Button in widgets["buttons"]:
		if b.text == text:
			return b
	return null

func _initialize() -> void:
	# 1. The cue file.
	var text := FileAccess.get_file_as_string(CUE_PATH)
	check("demo cue is readable", text != "", CUE_PATH)
	var catalog = CatalogScript.load_default()
	var res: Dictionary = CheckerScript.check_source(text, CUE_PATH, catalog.validator_catalog())
	var errs: Array = []
	for d: Dictionary in res["diagnostics"]:
		if d["severity"] == "error":
			errs.append(d)
	check("cue_check passes with the real catalog", res["ok"] == true and errs.is_empty(), str(errs))
	var parsed: Dictionary = ParserScript.parse(text)
	if parsed["ok"]:
		var compiled: Dictionary = LibScript.compile(parsed["ast"], 0)
		check("compiles", compiled["errors"].is_empty(), str(compiled["errors"]))
		check("three states", compiled["states"].size() == 3, str(compiled["states"].keys()))
		var faded := 0
		var fills := 0
		for t: Dictionary in compiled["transitions"]:
			if float(t["fade"]) > 0.0:
				faded += 1
			if t["fill"] != null:
				fills += 1
		check("transitions with fades and a fill", faded >= 2 and fills >= 1, "%d fades, %d fills" % [faded, fills])
		check("two stingers", compiled["stingers"].size() == 2, str(compiled["stingers"].keys()))
		check("a param and a bind", compiled["params"].size() >= 1 and compiled["binds"].size() >= 1, "")
		check("uses game()", text.contains("game("), "")
		var pairs: Dictionary = ScanScript.instruments(parsed["ast"])
		var known := true
		for g: String in pairs:
			for i: String in pairs[g]:
				if not catalog.has_instrument(i):
					known = false
		check("only catalog instruments", known, str(pairs))
	else:
		check("parses", false, str(parsed["diagnostics"]))

	# 2. The scene file has no hand-written uid.
	var scene_text := FileAccess.get_file_as_string(SCENE_PATH)
	check("scene has no uid= field", scene_text != "" and not scene_text.contains("uid="), "")
	var scene: PackedScene = load(SCENE_PATH)
	check("scene loads", scene != null, "")
	if scene == null:
		finish()
		return
	inst = scene.instantiate()
	root.add_child(inst)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		collect(inst)
		check("player loaded the demo cue", inst.player.is_loaded() and inst.player.is_playing(), str(inst.player.diagnostics))
		check("state buttons", button("State: explore") != null and button("State: tense") != null and button("State: combat") != null, "")
		check("stinger buttons", button("Stinger: found") != null and button("Stinger: hit") != null, "")
		check("a slider for the param", widgets["sliders"].size() == 1, str(widgets["sliders"].size()))
		check("at least three labels", widgets["labels"].size() >= 3, str(widgets["labels"].size()))
	if frames == 10:
		var b := button("State: tense")
		if b != null:
			b.pressed.emit()
			check("state button sets the pending state", inst.player.get_pending_state() == "tense", inst.player.get_pending_state())
		var s := button("Stinger: found")
		if s != null:
			s.pressed.emit()
			var seen := false
			for e: Dictionary in inst.player.conductor.get_log():
				if e["type"] == "stinger":
					seen = true
			check("stinger button triggers a stinger", seen, "")
		if widgets["sliders"].size() == 1:
			widgets["sliders"][0].value = 0.8
			check("slider sets the param", absf(inst.player.get_param("danger") - 0.8) < 0.001, str(inst.player.get_param("danger")))
	if frames >= 120:
		check("still playing after 120 frames", inst.player.is_playing(), "")
		var shown := false
		for l: Label in widgets["labels"]:
			if l.text.begins_with("Current state:"):
				shown = true
		check("labels are updated", shown, "")
		inst.queue_free()
		return finish()
	return false
