extends SceneTree
# Usage: godot --headless --path project -s ../tools/cue_check.gd -- <file|dir>... [--catalog <path>]
# (relative paths resolve against project/; one JSON line per file; exit 1 if any error, 2 on bad usage)
# Validates against the real instrument catalog by default; --catalog <path> overrides it
# (for example with tests/cue_corpus/catalog.json).
#
# `--path project` changes Godot's working directory, so relative file arguments
# are resolved against project/ (for example ../tests/cue_corpus/valid); absolute
# paths work as they are. Godot prints its version banner as the first output
# line; consumers read the lines that start with `{`.
const CheckerScript = preload("res://addons/godot_synth/cue/cue_checker.gd")

func _initialize() -> void:
	var result: Dictionary = CheckerScript.run(OS.get_cmdline_user_args())
	for line: String in result.lines:
		print(line)
	if result.error != "":
		printerr(result.error)
	quit(result.exit_code)
