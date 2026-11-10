extends SceneTree
# Fake teacher for tests: godot --headless --path project -s <this> -- <prompt_file> [<out_file>]
# Reads the prompt; if it contains the marker FAKE:fail it exits 3, else it answers with a canned cue in a
# fenced block, to <out_file> when given, else to stdout.
const CANNED: String = "Here is the cue.\n```cue\ntempo 96\nstate a:\n  s(\"kick\")\n```\nEnjoy.\n"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: fake_teacher <prompt_file> [<out_file>]")
		quit(2)
		return
	var prompt: String = FileAccess.get_file_as_string(args[0])
	if prompt.contains("FAKE:fail"):
		quit(3)
		return
	if args.size() > 1:
		var f: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
		if f == null:
			quit(4)
			return
		f.store_string(CANNED)
		f.close()
	else:
		print(CANNED)
	quit(0)
