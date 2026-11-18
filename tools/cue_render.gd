extends SceneTree
# Usage: godot --headless --path project -s ../tools/cue_render.gd -- <cue-file> --out <wav> [--scenario <json>] [--analysis <json>] [--catalog <instruments.json>]
# (relative paths resolve against project/; prints one JSON line; exit 1 when the cue or scenario is invalid, 2 on bad usage)
const RendererScript = preload("res://addons/godot_synth/cue/cue_renderer.gd")

func _initialize() -> void:
	var result: Dictionary = RendererScript.run(OS.get_cmdline_user_args())
	for line: String in result.lines:
		print(line)
	if result.error != "":
		printerr(result.error)
	quit(result.exit_code)
