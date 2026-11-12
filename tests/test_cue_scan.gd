extends SceneTree
# CueScan: (group, instrument) pairs from a cue AST.
# Run: bash tests/verify.sh --no-build tests/test_cue_scan.gd

const ScanScript = preload("res://addons/godot_synth/cue/cue_scan.gd")
const ParserScript = preload("res://addons/godot_synth/cue/cue_parser.gd")

var failures: Array[String] = []

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + ": " + detail)
	if not ok:
		failures.append(name)

func scan(src: String) -> Dictionary:
	var r: Dictionary = ParserScript.parse(src)
	if not r["ok"]:
		check("source parses", false, str(r["diagnostics"]))
		return {}
	return ScanScript.instruments(r["ast"])

func names(d: Dictionary, group: String) -> Array:
	return Array(d[group]) if d.has(group) else ["<missing group>"]

func _initialize() -> void:
	# 1. The forest corpus file.
	var path := ProjectSettings.globalize_path("res://").path_join("../tests/cue_corpus/valid/forest.cue")
	var text := FileAccess.get_file_as_string(path)
	check("forest.cue is readable", text != "", path)
	var forest := scan(text)
	check("forest groups", Array(forest.keys()) == ["explore", "combat", "transitions", "stingers"], str(forest.keys()))
	check("forest explore", names(forest, "explore") == ["bass", "hat", "pad"], str(names(forest, "explore")))
	check("forest combat", names(forest, "combat") == ["bass", "hat", "kick", "lead", "snare"], str(names(forest, "combat")))
	check("forest transitions", names(forest, "transitions") == ["crash"], str(names(forest, "transitions")))
	check("forest stingers", names(forest, "stingers") == ["lead"], str(names(forest, "stingers")))

	# 2. Let expansion, including a let that uses an earlier let.
	var lets := scan("let a = s(\"kick\")\nlet b = a.fast(2)\nlet unused = s(\"snare\")\nstate x:\n  b\nstate y:\n  a\n  s(\"hat\")\n")
	check("let expands through another let", names(lets, "x") == ["kick"], str(names(lets, "x")))
	check("let used in a second state", names(lets, "y") == ["hat", "kick"], str(names(lets, "y")))
	check("unused let contributes nothing", not ("snare" in names(lets, "x")) and not ("snare" in names(lets, "y")), "")

	# 3. s as a method, kick:2, several atoms, nested mini containers, rests.
	var s1 := scan("state m:\n  n(\"0 2\").scale(\"C:minor\").s(\"bass\")\n  s(\"kick:2 ~ [hat, snare] <pad lead>*2\")\n")
	check("s as a chain link", "bass" in names(s1, "m"), str(names(s1, "m")))
	check("kick:2 gives kick, nested containers walked", names(s1, "m") == ["bass", "hat", "kick", "lead", "pad", "snare"], str(names(s1, "m")))
	check("the scale string is not an instrument", not ("C" in names(s1, "m")), "")

	# 4. Non-literal arguments are ignored; their sub-expressions are not.
	var s2 := scan("param p = 0\nstate q:\n  s(game(\"p\"))\n  stack(s(\"hat\"), s(\"kick\")).every(2, fast(2))\n")
	check("non-literal s argument ignored, others found", names(s2, "q") == ["hat", "kick"], str(names(s2, "q")))

	# 5. Groups: empty state, transitions only when non-empty, stingers.
	var s3 := scan("state quiet:\n  silence\nstate loud:\n  s(\"kick\")\ntransition quiet -> loud fill s(\"snare*4\")\ntransition loud -> quiet\nstinger hit: s(\"hat\")\nstinger hit2: n(\"0\").s(\"lead\")\n")
	check("empty state is present and empty", s3.has("quiet") and s3["quiet"].size() == 0, str(s3.get("quiet")))
	check("transitions fill", names(s3, "transitions") == ["snare"], str(names(s3, "transitions")))
	check("stingers merged and sorted", names(s3, "stingers") == ["hat", "lead"], str(names(s3, "stingers")))
	var s4 := scan("state only:\n  s(\"kick\")\n")
	check("no transitions or stingers keys when empty", Array(s4.keys()) == ["only"], str(s4.keys()))

	# 6. Result arrays are PackedStringArray, sorted, duplicate free.
	var s5 := scan("state d:\n  s(\"kick kick snare kick\")\n  s(\"snare\")\n")
	check("sorted and duplicate free", names(s5, "d") == ["kick", "snare"] and s5["d"] is PackedStringArray, str(names(s5, "d")))

	print("ALL PASS" if failures.is_empty() else "FAILED: " + ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
