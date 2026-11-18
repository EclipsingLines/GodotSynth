class_name CueGenRunner
extends RefCounted
## Dataset generator runner: expands the prompt matrix, asks the configured teacher for each
## request, filters and dedupes the answers, and writes train/val/test JSONL splits, rejected
## records and stats. An interrupted run resumes from the ids already on disk.

const ProviderScript = preload("res://addons/godot_synth/cue/gen/cue_gen_provider.gd")
const MatrixScript = preload("res://addons/godot_synth/cue/gen/cue_gen_matrix.gd")
const FilterScript = preload("res://addons/godot_synth/cue/gen/cue_gen_filter.gd")
const PromptScript = preload("res://addons/godot_synth/cue/cue_prompt.gd")

const GRAMMAR_VERSION_PREFIX: String = "cue-grammar-v1"
const GBNF_PATH: String = "res://addons/godot_synth/cue/cue.gbnf"
const SPLITS: Array[String] = ["train", "val", "test"]

var config: Dictionary       ## provider config (CueGenProvider schema); never printed
var matrix: Dictionary
var out_dir: String          ## absolute directory, created if missing
var seed: int
var count: int
var filter_config: Dictionary = {}  ## passed to CueGenFilter.new
var quiet: bool = false      ## suppress per-item progress lines (tests)

func _init(p_config: Dictionary, p_matrix: Dictionary, p_out_dir: String, p_seed: int, p_count: int) -> void:
	config = p_config
	matrix = p_matrix
	out_dir = p_out_dir
	seed = p_seed
	count = p_count

## "train" when the first byte of SHA-256(id as UTF-8) is < 230, "val" when < 243, else "test" (about 90/5/5).
## Use HashingContext (HASH_SHA256) and PackedByteArray[0].
static func split_for(id: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(id.to_utf8_buffer())
	var digest: PackedByteArray = context.finish()
	if digest.is_empty():
		return "train"
	var first: int = digest[0]
	if first < 230:
		return "train"
	if first < 243:
		return "val"
	return "test"

## dataset_version = GRAMMAR_VERSION_PREFIX + ":" + lower-case hex SHA-256 of the file bytes of cue.gbnf
## (FileAccess.get_file_as_bytes(GBNF_PATH)); "cue-grammar-v1:missing" when the file cannot be read.
static func dataset_version() -> String:
	return GRAMMAR_VERSION_PREFIX + ":" + _grammar_hash()

static func _grammar_hash() -> String:
	if not FileAccess.file_exists(GBNF_PATH):
		return "missing"
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(GBNF_PATH)
	if bytes.is_empty():
		return "missing"
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

## Runs the generation and returns the stats Dictionary (also written to <out_dir>/stats.json).
func run() -> Dictionary:
	var config_errors: Array[String] = ProviderScript.validate_config(config)
	if not config_errors.is_empty():
		return {"error": config_errors[0]}
	var matrix_errors: Array[String] = MatrixScript.validate(matrix)
	if not matrix_errors.is_empty():
		return {"error": matrix_errors[0]}

	DirAccess.make_dir_recursive_absolute(out_dir)

	var filter = FilterScript.new(filter_config)
	var done_ids: Dictionary = {}
	for split_name: String in SPLITS:
		for record: Dictionary in _read_records(out_dir.path_join(split_name + ".jsonl")):
			if record.has("id"):
				done_ids[String(record["id"])] = true
			filter.accept(String(record.get("cue", "")))
	for record: Dictionary in _read_records(out_dir.path_join("rejected.jsonl")):
		if record.has("id"):
			done_ids[String(record["id"])] = true

	var provider_errors: int = 0
	var items: Array[Dictionary] = MatrixScript.expand(matrix, seed, count)
	for i: int in range(items.size()):
		var item: Dictionary = items[i]
		var id: String = String(item["id"])
		if done_ids.has(id):
			continue

		var prompt: Dictionary = _build_prompt(String(item["request"]))
		if not String(prompt.get("error", "")).is_empty():
			provider_errors += 1
			if not quiet:
				print("[%d/%d] %s provider_error" % [i + 1, count, id])
			continue

		var system: String = String(prompt.get("system", ""))
		var prompt_messages: Array[Dictionary] = []
		var raw_messages: Variant = prompt.get("messages", [])
		if raw_messages is Array:
			for message: Variant in raw_messages:
				if message is Dictionary:
					prompt_messages.append(message as Dictionary)
		var full_messages: Array[Dictionary] = ProviderScript.with_system(system, prompt_messages)

		var response: Dictionary = ProviderScript.complete(config, system, prompt_messages)
		if not bool(response.get("ok", false)):
			provider_errors += 1
			if not quiet:
				print("[%d/%d] %s provider_error" % [i + 1, count, id])
			continue

		var cue: String = FilterScript.extract_cue(String(response.get("text", "")))
		var result: Dictionary = filter.check(cue)
		var item_axes: Dictionary = item["axes"]
		if bool(result.get("ok", false)):
			filter.accept(cue)
			var record: Dictionary = {
				"id": id,
				"axes": item_axes,
				"messages": full_messages,
				"cue": cue,
				"metrics": result.get("metrics", {}),
				"teacher": {"backend": String(config.get("backend", "")), "model": String(config.get("model", ""))},
			}
			_append_line(out_dir.path_join(split_for(id) + ".jsonl"), JSON.stringify(record))
			if not quiet:
				print("[%d/%d] %s accepted" % [i + 1, count, id])
		else:
			var reasons: Array[String] = []
			var raw_reasons: Variant = result.get("reasons", [])
			if raw_reasons is Array:
				for reason: Variant in raw_reasons:
					reasons.append(String(reason))
			var rejected: Dictionary = {
				"id": id,
				"axes": item_axes,
				"reasons": reasons,
				"cue": cue,
				"metrics": result.get("metrics", {}),
			}
			_append_line(out_dir.path_join("rejected.jsonl"), JSON.stringify(rejected))
			if not quiet:
				print("[%d/%d] %s rejected: %s" % [i + 1, count, id, ",".join(reasons)])

	var accepted: int = 0
	var by_split: Dictionary = {"train": 0, "val": 0, "test": 0}
	for split_name: String in SPLITS:
		var split_records: Array[Dictionary] = _read_records(out_dir.path_join(split_name + ".jsonl"))
		var split_count: int = 0
		for record: Dictionary in split_records:
			if record.has("id"):
				split_count += 1
		by_split[split_name] = split_count
		accepted += split_count

	var rejected_counts: Dictionary = {}
	for record: Dictionary in _read_records(out_dir.path_join("rejected.jsonl")):
		var raw_reasons: Variant = record.get("reasons", [])
		if raw_reasons is Array:
			for reason: Variant in raw_reasons:
				var reason_text: String = String(reason)
				rejected_counts[reason_text] = int(rejected_counts.get(reason_text, 0)) + 1

	var grammar_hash: String = _grammar_hash()
	var stats: Dictionary = {
		"requested": count,
		"accepted": accepted,
		"rejected": rejected_counts,
		"by_split": by_split,
		"provider_errors": provider_errors,
		"dataset_version": GRAMMAR_VERSION_PREFIX + ":" + grammar_hash,
		"gbnf_sha256": grammar_hash,
		"teacher": {"backend": String(config.get("backend", "")), "model": String(config.get("model", ""))},
		"seed": seed,
	}
	_write_text(out_dir.path_join("stats.json"), JSON.stringify(stats, "\t"))
	return stats

func _build_prompt(request: String) -> Dictionary:
	var built: Dictionary = PromptScript.build(request)
	var messages: Array[Dictionary] = []
	var raw_messages: Variant = built.get("messages", [])
	if raw_messages is Array:
		for message: Variant in raw_messages:
			if message is Dictionary:
				messages.append(message as Dictionary)
	return {
		"system": String(built.get("system", "")),
		"messages": messages,
		"error": String(built.get("error", "")),
	}

func _read_records(path: String) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return records
	var text: String = FileAccess.get_file_as_string(path)
	for line: String in text.split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			records.append(parsed as Dictionary)
	return records

func _append_line(path: String, line: String) -> void:
	var file: FileAccess = null
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file == null:
			push_error("cuegen: cannot open " + path)
			return
		var length: int = file.get_length()
		if length > 0:
			file.seek(length - 1)
			if file.get_8() != 10:
				file.store_8(10)
		file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("cuegen: cannot create " + path)
			return
	file.store_line(line)
	file.close()

func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("cuegen: cannot write " + path)
		return
	file.store_string(text)
	file.close()
