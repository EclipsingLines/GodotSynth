extends SceneTree
# Usage: godot --headless --path project -s ../tools/cue_reference.gd -- [--check] [--doc <path>]
# Regenerates the generated tables in docs/cue-language.md (--check: exit 1 if they are out of date).
const ReferenceScript = preload("res://addons/godot_synth/cue/cue_reference.gd")

func _initialize() -> void:
	var result: Dictionary = ReferenceScript.run(OS.get_cmdline_user_args())
	for line: String in result.lines:
		print(line)
	if result.error != "":
		printerr(result.error)
	quit(result.exit_code)
