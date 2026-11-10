class_name CueGenProvider extends RefCounted
# Teacher-model access for the cue dataset generator. The provider is chosen by
# config only: an OpenAI-compatible chat endpoint, or a command template run
# through OS.execute. No endpoint, model or key is defaulted or stored here.

const BACKEND_OPENAI: String = "openai"
const BACKEND_COMMAND: String = "command"
const TMP_DIR: String = "user://cuegen_tmp"

# Errors for a config Dictionary, empty when valid. Rules: "backend" is one of the two ids; "model" is a
# non-empty String; no String value (and no element of "command") may start with "<" (unfilled placeholder);
# openai: "base_url" non-empty String starting with "http://" or "https://", "api_key_env" non-empty String;
# command: "command" is a non-empty Array whose elements are all Strings and whose first element is non-empty;
# "temperature"/"max_tokens"/"timeout_sec", when present, are numbers (> 0 for max_tokens and timeout_sec).
# Each error names the offending key; no error contains a key value.
static func validate_config(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var backend: Variant = config.get("backend", null)
	var backend_ok: bool = backend is String and (backend == BACKEND_OPENAI or backend == BACKEND_COMMAND)
	if not backend_ok:
		errors.append("backend: missing or not a known backend id")

	var model: Variant = config.get("model", null)
	if not (model is String) or String(model).is_empty():
		errors.append("model: missing or empty")

	for key: Variant in config.keys():
		var key_text: String = String(key)
		if key_text.begins_with("_"):
			continue
		var value: Variant = config[key]
		if value is String and String(value).begins_with("<"):
			errors.append(key_text + ": unfilled placeholder")
		elif key_text == "command" and value is Array:
			for element: Variant in value:
				if element is String and String(element).begins_with("<"):
					errors.append(key_text + ": unfilled placeholder")
					break

	if backend == BACKEND_OPENAI:
		var base_url: Variant = config.get("base_url", null)
		var base_url_ok: bool = base_url is String and not String(base_url).is_empty()
		if base_url_ok:
			base_url_ok = String(base_url).begins_with("http://") or String(base_url).begins_with("https://")
		if not base_url_ok:
			errors.append("base_url: missing or not an http(s) URL")
		var api_key_env: Variant = config.get("api_key_env", null)
		if not (api_key_env is String) or String(api_key_env).is_empty():
			errors.append("api_key_env: missing or empty")
	elif backend == BACKEND_COMMAND:
		var command: Variant = config.get("command", null)
		if not (command is Array) or (command as Array).is_empty():
			errors.append("command: missing or empty")
		else:
			var command_array: Array = command
			var all_strings: bool = true
			for element: Variant in command_array:
				if not (element is String):
					all_strings = false
					break
			if not all_strings:
				errors.append("command: every element must be a String")
			elif String(command_array[0]).is_empty():
				errors.append("command: program must not be empty")

	if config.has("temperature") and not _is_number(config["temperature"]):
		errors.append("temperature: must be a number")
	if config.has("max_tokens") and (not _is_number(config["max_tokens"]) or float(config["max_tokens"]) <= 0.0):
		errors.append("max_tokens: must be a positive number")
	if config.has("timeout_sec") and (not _is_number(config["timeout_sec"]) or float(config["timeout_sec"]) <= 0.0):
		errors.append("timeout_sec: must be a positive number")

	return errors

static func _is_number(value: Variant) -> bool:
	return value is int or value is float

# Prepends {"role": "system", "content": system} (skipped when system is empty) to messages
# (Array of {"role": String, "content": String}). Returns a new Array[Dictionary].
static func with_system(system: String, messages: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not system.is_empty():
		result.append({"role": "system", "content": system})
	for message: Dictionary in messages:
		result.append(message)
	return result

# Pure. Request for an OpenAI-compatible chat endpoint. messages already include the system message.
# url = base_url without trailing "/" + "/chat/completions".
# headers = PackedStringArray(["Content-Type: application/json", "Authorization: Bearer <key>"]) where key =
# OS.get_environment(config.api_key_env).
# body = JSON.stringify({"model", "messages", "temperature", "max_tokens"}) with that key order and the
# documented fallbacks 0.8 / 2048 for the two optional keys.
# When the env var is unset or empty: {url: "", headers: PackedStringArray(), body: "", error:
# "environment variable <NAME> is not set"} (the NAME, never a value). Otherwise error is "".
static func build_request(config: Dictionary, messages: Array[Dictionary]) -> Dictionary:
	var key_name: String = String(config.get("api_key_env", ""))
	var key: String = OS.get_environment(key_name)
	if key.is_empty():
		return {
			"url": "",
			"headers": PackedStringArray(),
			"body": "",
			"error": "environment variable " + key_name + " is not set",
		}

	var base_url: String = String(config.get("base_url", ""))
	while base_url.ends_with("/"):
		base_url = base_url.substr(0, base_url.length() - 1)
	var payload: Dictionary = {
		"model": String(config.get("model", "")),
		"messages": messages,
		"temperature": float(config.get("temperature", 0.8)),
		"max_tokens": int(config.get("max_tokens", 2048)),
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + key,
	])
	return {
		"url": base_url + "/chat/completions",
		"headers": headers,
		"body": JSON.stringify(payload),
		"error": "",
	}

# Pure. Interprets an HTTP status and body. code != 200 -> {ok: false, text: "", error: "http <code>: <detail>"}
# where detail is body.error.message when the body is JSON with an error object holding a String message,
# else the first 200 characters of the body. A 200 body must be JSON with
# choices[0].message.content a non-empty String -> {ok: true, text: content, error: ""}; anything else ->
# {ok: false, text: "", error: "malformed response"} (invalid JSON, no choices, null or empty content).
static func parse_response(code: int, body: String) -> Dictionary:
	if code != 200:
		var detail: String = body.substr(0, 200)
		var parsed: Variant = JSON.parse_string(body)
		if parsed is Dictionary:
			var error_value: Variant = (parsed as Dictionary).get("error", null)
			if error_value is Dictionary:
				var message: Variant = (error_value as Dictionary).get("message", null)
				if message is String:
					detail = message
		return {"ok": false, "text": "", "error": "http %d: %s" % [code, detail]}

	var response: Variant = JSON.parse_string(body)
	if not (response is Dictionary):
		return {"ok": false, "text": "", "error": "malformed response"}
	var choices: Variant = (response as Dictionary).get("choices", null)
	if not (choices is Array) or (choices as Array).is_empty():
		return {"ok": false, "text": "", "error": "malformed response"}
	var first: Variant = (choices as Array)[0]
	if not (first is Dictionary):
		return {"ok": false, "text": "", "error": "malformed response"}
	var message_dict: Variant = (first as Dictionary).get("message", null)
	if not (message_dict is Dictionary):
		return {"ok": false, "text": "", "error": "malformed response"}
	var content: Variant = (message_dict as Dictionary).get("content", null)
	if not (content is String) or String(content).is_empty():
		return {"ok": false, "text": "", "error": "malformed response"}
	return {"ok": true, "text": content, "error": ""}

# Blocking HTTP POST for a real call; no await, usable from a SceneTree tool. Returns {code: int, body: String,
# error: String}; error is "" on success, code is 0 and error set on any transport failure. Never logs headers.
static func http_post(url: String, headers: PackedStringArray, body: String, timeout_sec: float) -> Dictionary:
	var use_tls: bool = url.begins_with("https://")
	var rest: String = url
	if use_tls:
		rest = url.substr(8)
	elif url.begins_with("http://"):
		rest = url.substr(7)
	var slash: int = rest.find("/")
	var host_part: String = rest if slash < 0 else rest.substr(0, slash)
	var path: String = "/" if slash < 0 else rest.substr(slash)
	var host: String = host_part
	var port: int = 443 if use_tls else 80
	var colon: int = host_part.rfind(":")
	if colon >= 0:
		host = host_part.substr(0, colon)
		port = int(host_part.substr(colon + 1))

	var client := HTTPClient.new()
	var err: int = client.connect_to_host(host, port, TLSOptions.client() if use_tls else null)
	if err != OK:
		return {"code": 0, "body": "", "error": "connect failed"}

	var deadline: int = Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() > deadline:
			client.close()
			return {"code": 0, "body": "", "error": "timeout"}
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		client.close()
		return {"code": 0, "body": "", "error": "connect failed"}

	err = client.request(HTTPClient.METHOD_POST, path, headers, body)
	if err != OK:
		client.close()
		return {"code": 0, "body": "", "error": "request failed"}

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() > deadline:
			client.close()
			return {"code": 0, "body": "", "error": "timeout"}

	if not client.has_response():
		client.close()
		return {"code": 0, "body": "", "error": "no response"}

	var code: int = client.get_response_code()
	var chunks := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk: PackedByteArray = client.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(10)
		else:
			chunks.append_array(chunk)
		if Time.get_ticks_msec() > deadline:
			client.close()
			return {"code": 0, "body": "", "error": "timeout"}

	client.close()
	return {"code": code, "body": chunks.get_string_from_utf8(), "error": ""}

# Pure. Flattens messages into the prompt text for the command backend: for each message,
# "[" + role + "]\n" + content, joined by "\n\n", plus a final "\n".
static func flatten_messages(messages: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for message: Dictionary in messages:
		parts.append("[" + String(message.get("role", "")) + "]\n" + String(message.get("content", "")))
	return "\n\n".join(parts) + "\n"

# Pure. Replaces "{prompt_file}", "{system_file}" and "{out_file}" in every element of the template.
static func fill_command(template: Array, prompt_file: String, system_file: String, out_file: String) -> Array[String]:
	var result: Array[String] = []
	for element: Variant in template:
		var filled: String = String(element)
		filled = filled.replace("{prompt_file}", prompt_file)
		filled = filled.replace("{system_file}", system_file)
		filled = filled.replace("{out_file}", out_file)
		result.append(filled)
	return result

# Runs the command backend. The prompt and system text are written to temp files, the command template is
# filled, and the program runs through OS.execute. OS.execute blocks and has no timeout, so the command
# must bound itself. Returns {ok, text, error}; temp files are always removed.
static func run_command(config: Dictionary, system: String, messages: Array[Dictionary]) -> Dictionary:
	var tmp_dir: String = ProjectSettings.globalize_path(TMP_DIR)
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var stem: String = "%d_%d" % [Time.get_ticks_usec(), randi() % 100000]
	var prompt_path: String = tmp_dir.path_join(stem + ".prompt.txt")
	var system_path: String = tmp_dir.path_join(stem + ".system.txt")
	var out_path: String = tmp_dir.path_join(stem + ".out.txt")
	var temp_paths: Array[String] = [prompt_path, system_path, out_path]

	var prompt_file: FileAccess = FileAccess.open(prompt_path, FileAccess.WRITE)
	if prompt_file == null:
		_remove_temp(temp_paths)
		return {"ok": false, "text": "", "error": "could not write prompt file"}
	prompt_file.store_string(flatten_messages(messages))
	prompt_file.close()

	var system_file: FileAccess = FileAccess.open(system_path, FileAccess.WRITE)
	if system_file == null:
		_remove_temp(temp_paths)
		return {"ok": false, "text": "", "error": "could not write system file"}
	system_file.store_string(system)
	system_file.close()

	var template: Array = []
	if config.get("command") is Array:
		template = config["command"]
	var uses_out: bool = false
	for element: Variant in template:
		if element is String and String(element).contains("{out_file}"):
			uses_out = true

	var args: Array[String] = fill_command(template, prompt_path, system_path, out_path)
	if args.is_empty():
		_remove_temp(temp_paths)
		return {"ok": false, "text": "", "error": "command is empty"}
	var program: String = args[0]
	var rest := PackedStringArray(args.slice(1))

	var output: Array = []
	var code: int = OS.execute(program, rest, output, false)
	if code == -1:
		_remove_temp(temp_paths)
		return {"ok": false, "text": "", "error": "command could not start"}
	if code != 0:
		_remove_temp(temp_paths)
		return {"ok": false, "text": "", "error": "command exited with code %d" % code}

	var text: String = ""
	if uses_out and FileAccess.file_exists(out_path):
		text = FileAccess.get_file_as_string(out_path)
	else:
		var parts := PackedStringArray(output)
		text = "".join(parts)

	_remove_temp(temp_paths)
	if text.strip_edges().is_empty():
		return {"ok": false, "text": "", "error": "command produced no output"}
	return {"ok": true, "text": text, "error": ""}

static func _remove_temp(paths: Array[String]) -> void:
	for path: String in paths:
		DirAccess.remove_absolute(path)

# Entry point used by the runner: validates the config (error "config: <first error>"), then dispatches.
# openai: with_system(system, messages) -> build_request(config, that) -> http_post -> parse_response
# (build_request expects messages to already include the system message; complete() is the only caller
# required to prepend it, so system is never silently dropped for the openai backend).
# command: run_command(config, system, messages) (run_command receives system and messages separately and
# is responsible for its own flattening). Returns {ok, text, error}.
static func complete(config: Dictionary, system: String, messages: Array[Dictionary]) -> Dictionary:
	var errors: Array[String] = validate_config(config)
	if not errors.is_empty():
		return {"ok": false, "text": "", "error": "config: " + errors[0]}

	if String(config["backend"]) == BACKEND_OPENAI:
		var request: Dictionary = build_request(config, with_system(system, messages))
		var request_error: String = String(request.get("error", ""))
		if not request_error.is_empty():
			return {"ok": false, "text": "", "error": request_error}
		var headers: PackedStringArray = request["headers"]
		var response: Dictionary = http_post(
			String(request["url"]),
			headers,
			String(request["body"]),
			float(config.get("timeout_sec", 120))
		)
		var response_error: String = String(response.get("error", ""))
		if not response_error.is_empty():
			return {"ok": false, "text": "", "error": response_error}
		return parse_response(int(response.get("code", 0)), String(response.get("body", "")))

	return run_command(config, system, messages)
