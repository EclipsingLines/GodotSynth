extends SceneTree
# Usage: godot --headless --path project -s ../tools/cuegen/cuegen.gd -- --config <json> --count N --out <dir> [--seed S] [--matrix <json>]
# Relative paths resolve against project/. Exit 0 = finished, 1 = finished but some items had provider errors
# (run again to retry them), 2 = bad usage or config. Last stdout line is the stats JSON.
const RunnerScript = preload("res://addons/godot_synth/cue/gen/cue_gen_runner.gd")

const USAGE: String = "usage: godot --headless --path project -s ../tools/cuegen/cuegen.gd -- --config <json> --count N --out <dir> [--seed S] [--matrix <json>]"

func _initialize() -> void:
	var config_arg: String = ""
	var matrix_arg: String = ""
	var out_arg: String = ""
	var count: int = 0
	var seed: int = 0
	var has_config: bool = false
	var has_count: bool = false
	var has_out: bool = false

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		var arg: String = String(args[i])
		if arg != "--config" and arg != "--count" and arg != "--out" and arg != "--seed" and arg != "--matrix":
			_usage_error()
			return
		if i + 1 >= args.size():
			_usage_error()
			return
		var value: String = String(args[i + 1])
		if arg == "--config":
			config_arg = value
			has_config = true
		elif arg == "--count":
			if not value.is_valid_int():
				_usage_error()
				return
			count = value.to_int()
			has_count = true
		elif arg == "--out":
			out_arg = value
			has_out = true
		elif arg == "--seed":
			if not value.is_valid_int():
				_usage_error()
				return
			seed = value.to_int()
		else:
			matrix_arg = value
		i += 2

	if not has_config or not has_count or not has_out or count < 1:
		_usage_error()
		return

	if matrix_arg.is_empty():
		matrix_arg = ProjectSettings.globalize_path("res://").path_join("../tools/cuegen/matrix.json").simplify_path()

	var config: Variant = _read_json_object(_resolve(config_arg))
	if not (config is Dictionary):
		quit(2)
		return
	var matrix: Variant = _read_json_object(_resolve(matrix_arg))
	if not (matrix is Dictionary):
		quit(2)
		return

	var runner = RunnerScript.new(config, matrix, _resolve(out_arg), seed, count)
	var stats: Dictionary = runner.run()
	if stats.has("error"):
		printerr(String(stats["error"]))
		quit(2)
		return

	print(JSON.stringify(stats))
	quit(1 if int(stats.get("provider_errors", 0)) > 0 else 0)

func _resolve(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://").path_join(path).simplify_path()

func _read_json_object(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		printerr("cannot read " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		printerr("not a JSON object: " + path)
		return null
	return parsed

func _usage_error() -> void:
	printerr(USAGE)
	quit(2)
