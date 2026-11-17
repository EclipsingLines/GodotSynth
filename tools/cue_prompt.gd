extends SceneTree
# Usage: godot --headless --path project -s ../tools/cue_prompt.gd -- --request "<text>" [--pack <dir>]
# Prints system prompt + instrument table + examples + request as one text block.
const PromptScript = preload("res://addons/godot_synth/cue/cue_prompt.gd")

func _initialize() -> void:
	var result: Dictionary = PromptScript.run(OS.get_cmdline_user_args())
	if result.text != "":
		print(String(result.text).rstrip("\n"))
	if result.error != "":
		printerr(result.error)
	quit(result.exit_code)
