extends SceneTree
# Fake teacher for the cuegen runner tests: godot --headless --path project -s <this> -- <prompt_file> <out_file>
# Picks the response from the first marker FAKE:<mode> in the prompt (good_a when there is none) and writes a
# fenced cue to <out_file>. FAKE:fail exits 3 without output.
const GOOD_A: String = "tempo 96\nstate a:\n  n(\"0 ~ 0 3\").scale(\"D:minor\").s(\"bass\").gain(0.05)\n  s(\"kick(3,8)\").gain(0.05)\n  s(\"hat*8\").gain(0.05)\n"
# same cue as GOOD_A, differing only in comments and spacing
const DUP_A: String = "// forest music\ntempo   96\n\nstate a:   // main\n  n(\"0 ~ 0 3\").scale(\"D:minor\").s(\"bass\").gain(0.05)\n  s(\"kick(3,8)\").gain(0.05)   \n  s(\"hat*8\").gain(0.05) // hats\n"
const GOOD_B: String = "tempo 120\nstate a:\n  n(\"0 2 4 5\").scale(\"C4:major\").s(\"lead\").gain(0.05)\n  s(\"kick ~ snare ~\").gain(0.05)\n"
const SYNTAX_ERR: String = "tempo 96\nstate a:\n  s(\"kick\" =>\n"
const UNKNOWN_INSTRUMENT: String = "tempo 96\nstate a:\n  s(\"banjo\")\n"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: fake_teacher_mix <prompt_file> <out_file>")
		quit(2)
		return

	var prompt: String = FileAccess.get_file_as_string(args[0])
	var regex := RegEx.new()
	regex.compile("FAKE:([a-z_]+)")
	var mode: String = "good_a"
	var found: RegExMatch = regex.search(prompt)
	if found != null:
		mode = found.get_string(1)

	if mode == "fail":
		quit(3)
		return

	var cue: String = GOOD_A
	match mode:
		"dup_a":
			cue = DUP_A
		"good_b":
			cue = GOOD_B
		"syntax":
			cue = SYNTAX_ERR
		"unknown":
			cue = UNKNOWN_INSTRUMENT

	var file: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	if file == null:
		quit(4)
		return
	file.store_string("Here you go.\n```cue\n" + cue + "```\n")
	file.close()
	quit(0)
