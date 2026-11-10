extends SceneTree
# CueGenProvider: config validation, request building, response parsing and the command backend.
# Run: Godot --headless --path project -s ../tests/test_cuegen_provider.gd

const ProviderScript = preload("res://addons/godot_synth/cue/gen/cue_gen_provider.gd")
const ENV_NAME: String = "CUEGEN_TEST_KEY"
const ENV_VALUE: String = "test-key-123"

var _fails: int = 0
var _checks: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("PASS ", label)
	else:
		_fails += 1
		print("FAIL %s: %s" % [label, detail])


func _repo(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()


func _msgs() -> Array[Dictionary]:
	return [{"role": "user", "content": "hello"}]


func _openai_config() -> Dictionary:
	return {"backend": "openai", "model": "test-model", "base_url": "http://localhost:9/v1/", "api_key_env": ENV_NAME}


func _command_config(with_out: bool) -> Dictionary:
	var godot: String = OS.get_executable_path()
	var args: Array = [godot, "--headless", "--audio-driver", "Dummy", "--path",
		ProjectSettings.globalize_path("res://").simplify_path(), "-s", _repo("tests/fixtures/fake_teacher.gd"),
		"--", "{prompt_file}"]
	if with_out:
		args.append("{out_file}")
	return {"backend": "command", "model": "fake-teacher", "command": args}


func _initialize() -> void:
	OS.set_environment(ENV_NAME, ENV_VALUE)

	# validate_config
	_check("openai config valid", ProviderScript.validate_config(_openai_config()).is_empty(),
		str(ProviderScript.validate_config(_openai_config())))
	_check("command config valid", ProviderScript.validate_config(_command_config(true)).is_empty(),
		str(ProviderScript.validate_config(_command_config(true))))
	for key: String in ["backend", "model", "base_url", "api_key_env"]:
		var c: Dictionary = _openai_config()
		c.erase(key)
		_check("openai config without %s rejected" % key, not ProviderScript.validate_config(c).is_empty())
	var c2: Dictionary = _command_config(true)
	c2.erase("command")
	_check("command config without command rejected", not ProviderScript.validate_config(c2).is_empty())
	c2 = _command_config(true)
	c2["command"] = []
	_check("empty command rejected", not ProviderScript.validate_config(c2).is_empty())
	var c3: Dictionary = _openai_config()
	c3["base_url"] = "ftp://x"
	_check("non-http base_url rejected", not ProviderScript.validate_config(c3).is_empty())
	c3 = _openai_config()
	c3["backend"] = "carrier-pigeon"
	_check("unknown backend rejected", not ProviderScript.validate_config(c3).is_empty())
	var ex: Variant = JSON.parse_string(FileAccess.get_file_as_string(_repo("tools/cuegen/cuegen.example.json")))
	_check("example config parses", ex is Dictionary)
	if ex is Dictionary:
		_check("example config is rejected until filled in", not ProviderScript.validate_config(ex as Dictionary).is_empty())
	var err_text: String = str(ProviderScript.validate_config({"backend": "openai", "model": "m", "base_url": "http://h", "api_key_env": "<X>"}))
	_check("placeholder error does not echo values", not err_text.contains("<X>"), err_text)
	for key: String in ["backend", "model", "base_url", "api_key_env"]:
		var pc: Dictionary = _openai_config()
		pc[key] = "<placeholder>"
		var pc_errors: Array[String] = ProviderScript.validate_config(pc)
		_check("placeholder in %s rejected without echo" % key,
			not pc_errors.is_empty() and not str(pc_errors).contains("<placeholder>"), str(pc_errors))
	var pc2: Dictionary = _command_config(true)
	pc2["command"] = ["prog", "<argument>"]
	var pc2_errors: Array[String] = ProviderScript.validate_config(pc2)
	_check("placeholder in command element rejected without echo",
		not pc2_errors.is_empty() and not str(pc2_errors).contains("<argument>"), str(pc2_errors))

	# with_system / flatten / fill
	var ws: Array[Dictionary] = ProviderScript.with_system("SYS", _msgs())
	_check("with_system prepends", ws.size() == 2 and ws[0]["role"] == "system" and ws[0]["content"] == "SYS")
	_check("with_system skips empty", ProviderScript.with_system("", _msgs()).size() == 1)
	_check("flatten_messages", ProviderScript.flatten_messages(_msgs()) == "[user]\nhello\n",
		ProviderScript.flatten_messages(_msgs()))
	var filled: Array[String] = ProviderScript.fill_command(["p", "--in={prompt_file}", "{system_file}", "{out_file}"], "A", "B", "C")
	_check("fill_command", filled == ["p", "--in=A", "B", "C"], str(filled))

	# build_request
	var req: Dictionary = ProviderScript.build_request(_openai_config(), ws)
	_check("url", req["url"] == "http://localhost:9/v1/chat/completions", str(req["url"]))
	var headers: PackedStringArray = req["headers"]
	_check("content-type header", headers.has("Content-Type: application/json"))
	_check("bearer header from env var", headers.has("Authorization: Bearer " + ENV_VALUE))
	var body: Variant = JSON.parse_string(req["body"])
	_check("body is JSON object", body is Dictionary)
	if body is Dictionary:
		var bd: Dictionary = body
		_check("body model", bd["model"] == "test-model")
		_check("body messages", (bd["messages"] as Array).size() == 2)
		_check("body fallbacks", is_equal_approx(float(bd["temperature"]), 0.8) and int(bd["max_tokens"]) == 2048)
	_check("no error when key present", req["error"] == "")
	var cfg_custom: Dictionary = _openai_config()
	cfg_custom["temperature"] = 0.2
	cfg_custom["max_tokens"] = 100
	var bd2: Dictionary = JSON.parse_string(ProviderScript.build_request(cfg_custom, ws)["body"])
	_check("body honours config", is_equal_approx(float(bd2["temperature"]), 0.2) and int(bd2["max_tokens"]) == 100)
	var unset: Dictionary = _openai_config()
	unset["api_key_env"] = "CUEGEN_TEST_KEY_UNSET_XYZ"
	var req2: Dictionary = ProviderScript.build_request(unset, ws)
	_check("unset env var gives error naming the variable only",
		String(req2["error"]).contains("CUEGEN_TEST_KEY_UNSET_XYZ") and not String(req2["error"]).contains(ENV_VALUE)
		and req2["url"] == "")

	# parse_response
	var ok_body: String = JSON.stringify({"choices": [{"message": {"role": "assistant", "content": "tempo 96\n"}}]})
	var r: Dictionary = ProviderScript.parse_response(200, ok_body)
	_check("parse ok", r["ok"] == true and r["text"] == "tempo 96\n" and r["error"] == "")
	r = ProviderScript.parse_response(401, JSON.stringify({"error": {"message": "bad key"}}))
	_check("parse error json", r["ok"] == false and String(r["error"]).contains("401") and String(r["error"]).contains("bad key"), str(r))
	r = ProviderScript.parse_response(500, "oops")
	_check("parse non-200 plain body", r["ok"] == false and String(r["error"]).contains("500") and String(r["error"]).contains("oops"), str(r))
	r = ProviderScript.parse_response(200, "not json")
	_check("parse invalid json", r["ok"] == false and r["error"] == "malformed response")
	r = ProviderScript.parse_response(200, JSON.stringify({"choices": []}))
	_check("parse no choices", r["ok"] == false and r["error"] == "malformed response")
	r = ProviderScript.parse_response(200, JSON.stringify({"choices": [{"message": {"content": null}}]}))
	_check("parse null content", r["ok"] == false and r["error"] == "malformed response")

	# command backend end to end (spawns this Godot executable with the fake teacher; no network)
	var cr: Dictionary = ProviderScript.complete(_command_config(true), "SYS", _msgs())
	_check("command backend with out_file", cr["ok"] == true and String(cr["text"]).contains("tempo 96"), str(cr))
	var cs: Dictionary = ProviderScript.complete(_command_config(false), "SYS", _msgs())
	_check("command backend via stdout", cs["ok"] == true and String(cs["text"]).contains("tempo 96"), str(cs))
	var fail_msgs: Array[Dictionary] = [{"role": "user", "content": "please FAKE:fail now"}]
	var cf: Dictionary = ProviderScript.complete(_command_config(true), "SYS", fail_msgs)
	_check("command backend non-zero exit", cf["ok"] == false and String(cf["error"]).contains("3"), str(cf))
	var leftovers: PackedStringArray = DirAccess.get_files_at(ProjectSettings.globalize_path(ProviderScript.TMP_DIR))
	_check("temp files cleaned up", leftovers.is_empty(), str(leftovers))
	var bad_cfg: Dictionary = {"backend": "command", "model": "m", "command": []}
	_check("complete rejects a bad config", ProviderScript.complete(bad_cfg, "", _msgs())["ok"] == false)

	# denylist: no vendor names in the new files (the test file itself is excluded because it lists them;
	# the backend id "openai" is allowed, only the token "openai.com" is searched)
	var deny: Array[String] = ["claude", "anthropic", "openai.com", "gpt-", "gemini", "mistral"]
	var files: Array[String] = [
		"project/addons/godot_synth/cue/gen/cue_gen_provider.gd",
		"tools/cuegen/cuegen.example.json",
		"tests/fixtures/fake_teacher.gd",
	]
	for rel: String in files:
		var text: String = FileAccess.get_file_as_string(_repo(rel)).to_lower()
		var hit: String = ""
		for tok: String in deny:
			if text.contains(tok):
				hit = tok
		_check("no vendor name in %s" % rel, not text.is_empty() and hit == "", "found: " + hit)

	print("checks: %d, failures: %d" % [_checks, _fails])
	if _fails == 0:
		print("PASS (%d checks)" % _checks)
	quit(1 if _fails > 0 else 0)
