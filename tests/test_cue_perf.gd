extends SceneTree
# Perf gate for the GDScript pattern engine (D-216): compiles the forest
# corpus' combat state plus five extra layers (8 layers in total) and times
# 64 cycles queried in 1/32-cycle windows. A total of 400 ms or more is a PM
# decision point, not a worker bug: report the number instead of shrinking the
# workload or loosening the budget.
# Run: bash tests/verify.sh --no-build tests/test_cue_perf.gd
# Exits with code 0 when the workload stays under the budget, 1 otherwise.

const BUDGET_MS := 400.0
const CYCLES := 64
const WINDOW := 32
const SEED := 7
const CORPUS_PATH := "../tests/cue_corpus/valid/forest.cue"

# The extra program is self-contained (no references to the forest lets); its
# five layers bring the forest combat state's three up to the eight the gate
# asks for.
const EXTRA_SRC := """state extra:
  s("kick*4").gain(0.9)
  s("hat*8").degradeBy(0.3).gain(game("danger"))
  n("0 2 4 7").scale("D3:minor").s("bass").slow(2).lpf(sine.range(300, 1200))
  n("<0 2 4 [6 4]>").scale("D4:minor").s("pad").every(2, fast(2)).off(0.25, add(7))
  s("snare(3,8)").sometimesBy(0.4, fast(2)).pan(rand)
"""

var failures: Array[String] = []


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else ": " + detail))
	if not ok:
		failures.append(name)


func _parse(src: String) -> Dictionary:
	var result := CueParser.parse(src)
	if not bool(result.get("ok", false)):
		print("FAIL parse source: " + str(result))
		return {}
	return result["ast"]


func _state_layer_count(ast: Dictionary, state_name: String) -> int:
	for item: Variant in ast.get("items", []):
		if item is Dictionary and String((item as Dictionary).get("type", "")) == "state" \
				and String((item as Dictionary).get("name", "")) == state_name:
			return ((item as Dictionary).get("layers", []) as Array).size()
	return -1


func _onset_sig(haps: Array[CueHap]) -> Array[String]:
	var out: Array[String] = []
	for h: CueHap in haps:
		if h.has_onset():
			out.append("%s-%s:%s" % [str(h.whole.begin), str(h.whole.end), str(h.value)])
	return out


func _window_query(pattern: CuePattern, from_cycle: int, windows: int, controls: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for i in windows:
		var b := from_cycle * WINDOW + i
		out.append_array(_onset_sig(pattern.query_arc(
			CueFrac.make(b, WINDOW), CueFrac.make(b + 1, WINDOW), controls)))
	return out


func _initialize() -> void:
	var root := ProjectSettings.globalize_path("res://").path_join(CORPUS_PATH)
	var src := FileAccess.get_file_as_string(root)
	if src.is_empty():
		print("FAIL load: forest.cue missing or empty")
		quit(1)
		return

	var forest_ast := _parse(src)
	if forest_ast.is_empty():
		quit(1)
		return
	var extra_ast := _parse(EXTRA_SRC)
	if extra_ast.is_empty():
		quit(1)
		return

	var res := CueLib.compile(forest_ast, SEED)
	var extra := CueLib.compile(extra_ast, SEED)
	var errors: Array = []
	errors.append_array(res.get("errors", []))
	errors.append_array(extra.get("errors", []))
	if not errors.is_empty():
		print("FAIL compile: " + str(errors))
		quit(1)
		return
	if not (res.get("states", {}) as Dictionary).has("combat"):
		print("FAIL compile: no combat state")
		quit(1)
		return
	if not (extra.get("states", {}) as Dictionary).has("extra"):
		print("FAIL compile: no extra state")
		quit(1)
		return

	var combat_layers := _state_layer_count(forest_ast, "combat")
	var extra_layers := _state_layer_count(extra_ast, "extra")
	var layer_count := combat_layers + extra_layers
	check("layers", layer_count == 8, "got %d (combat %d + extra %d)" % [layer_count, combat_layers, extra_layers])
	print("layers=%d" % layer_count)

	var layers: Array[CuePattern] = [res["states"]["combat"], extra["states"]["extra"]]
	var workload := CuePattern.stack(layers)
	var controls := {"params": {"danger": 0.5, "depth": 0.5}}

	# Untimed warm-up: cycle 0 in the same windows, so first-use lookups are
	# not billed to the timed region.
	for i in WINDOW:
		workload.query_arc(CueFrac.make(i, WINDOW), CueFrac.make(i + 1, WINDOW), controls)

	var t0 := Time.get_ticks_usec()
	var total_haps := 0
	for i in CYCLES * WINDOW:
		var haps := workload.query_arc(CueFrac.make(i, WINDOW), CueFrac.make(i + 1, WINDOW), controls)
		total_haps += haps.size()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("PERF cue_query_ms=%.1f haps=%d" % [ms, total_haps])

	if total_haps <= 0:
		print("FAIL workload: no haps")
		failures.append("workload")
	elif total_haps <= 1000:
		print("FAIL workload: too few haps (%d)" % total_haps)
		failures.append("workload")

	# Window invariance: [0,4) as one window and as 128 windows of 1/32 must
	# yield the same onsets.
	var whole := _onset_sig(workload.query_arc(CueFrac.make(0), CueFrac.make(4), controls))
	var split := _window_query(workload, 0, 4 * WINDOW, controls)
	whole.sort()
	split.sort()
	var mismatch := "size %d != %d" % [whole.size(), split.size()]
	if whole.size() == split.size():
		for i in whole.size():
			if whole[i] != split[i]:
				mismatch = "at %d: %s != %s" % [i, whole[i], split[i]]
				break
	var invariant := whole == split
	check("window_invariance", invariant, mismatch)

	var under_budget := ms < BUDGET_MS
	if under_budget:
		print("PASS cue_perf: %.1f ms < %d ms" % [ms, int(BUDGET_MS)])
	else:
		print("FAIL cue_perf: %.1f ms >= %d ms budget (PM decision point: profile, then optimise in GDScript or open C++ tickets, D-216)"
			% [ms, int(BUDGET_MS)])
	quit(0 if under_budget and failures.is_empty() else 1)
