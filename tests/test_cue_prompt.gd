extends SceneTree
# Prompt pack: manifest, examples pass the checker, provider-neutral, CuePrompt assembly and CLI logic.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_prompt.gd

const PromptScript = preload("res://addons/godot_synth/cue/cue_prompt.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")
const CheckerScript = preload("res://addons/godot_synth/cue/cue_checker.gd")

const DENYLIST := ["claude", "anthropic", "openai", "gpt", "gemini", "llama", "mistral", "tool_call", "function_call", "tool_use", "<tool"]
const COVERAGE := [
	"tempo ", "seed ", "let ", "param ", "state ", "transition ", "stinger ", "bind ",
	"transition * ->", " fade ", " fill ", " len ", "on bar", "on beat", "on now", " bars ", " beats ",
	"game(", "stack(", "cat(", ".every(", ".off(", ".sometimesBy(", ".superimpose(", ".scale(", "<-", "..", "(3,8)", "<", "[",
]

var failures := 0
var checks := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS ", name)
	else:
		failures += 1
		print("FAIL ", name, ": ", detail)

func denied_word(text: String) -> String:
	var low := text.to_lower()
	for w: String in DENYLIST:
		if low.contains(w):
			return w
	return ""

func list_files(dir_path: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(f)
	out.sort()
	return out

func _initialize() -> void:
	var catalog = CatalogScript.load_default()
	var pack_dir: String = PromptScript.default_pack_dir()

	# 1. manifest
	var pack_text := FileAccess.get_file_as_string(pack_dir.path_join("pack.json"))
	var pack = JSON.parse_string(pack_text)
	check("pack.json parses to an object", pack is Dictionary, pack_dir)
	if not (pack is Dictionary):
		print("FAIL ", failures, " of ", checks)
		quit(1)
		return
	check("pack keys", str(pack.keys()) == str(["version", "system_file", "catalog_table", "examples"]), str(pack.keys()))
	check("pack basics", int(pack.version) == 1 and pack.system_file == "system.md" and pack.catalog_table == true, str(pack))
	check("at least 6 examples", pack.examples.size() >= 6, str(pack.examples.size()))
	var listed: Array = []
	for e: Dictionary in pack.examples:
		check("example entry is {request, cue_file}: " + str(e.get("cue_file")), e.keys().size() == 2 and str(e.get("request", "")).strip_edges() != "" and FileAccess.file_exists(pack_dir.path_join(str(e.get("cue_file", "")))), str(e))
		listed.append(str(e.get("cue_file", "")).get_file())
	listed.sort()
	check("examples folder holds exactly the listed files", list_files(pack_dir.path_join("examples"), ".cue") == listed, str(listed))
	check("README exists", FileAccess.file_exists(pack_dir.path_join("README.md")))

	# 2. every example is a clean cue with the real catalog; together they cover the language
	var all_text := ""
	for e: Dictionary in pack.examples:
		var path: String = pack_dir.path_join(str(e.cue_file))
		var text := FileAccess.get_file_as_string(path)
		all_text += text + "\n"
		var res: Dictionary = CheckerScript.check_source(text, str(e.cue_file), catalog.validator_catalog())
		check("example is valid with no diagnostics: " + str(e.cue_file), res.ok and res.diagnostics.is_empty(), str(res.diagnostics))
		check("example hygiene: " + str(e.cue_file), text.begins_with("// ") and not text.contains("\r") and not text.contains(" \n") and not text.contains("\t") and text.split("\n").size() <= 36, text.left(40))
	var reg := RegEx.new()
	reg.compile("tempo [0-9]+ [0-9]+/[0-9]+")
	check("a tempo with a meter", reg.search(all_text) != null)
	for token: String in COVERAGE:
		check("examples cover: " + token, all_text.contains(token))
	reg.compile("param [a-z_]+ [0-9.]+\\.\\.[0-9.]+ = ")
	var has_range := reg.search(all_text) != null
	reg.compile("param [a-z_]+ = ")
	check("both param forms", has_range and reg.search(all_text) != null)
	reg.compile("bind [a-z_]+\\.[a-z_]+ <- [a-z_]+\\n")
	var bind_plain := reg.search(all_text) != null
	reg.compile("bind [a-z_]+\\.[a-z_]+ <- [a-z_]+ [0-9.]+\\.\\.[0-9.]+")
	check("bind with and without a range", bind_plain and reg.search(all_text) != null)
	reg.compile("\\n\\s+\\.[a-zA-Z]+\\(")
	check("a continuation line", reg.search(all_text) != null)

	# 3. provider-neutral
	var system_md := FileAccess.get_file_as_string(pack_dir.path_join("system.md"))
	check("system.md is substantial", system_md.length() > 1500 and system_md.length() < 14000, str(system_md.length()))
	check("system.md has no vendor or tool-call words", denied_word(system_md) == "", denied_word(system_md))
	for word in ["tempo", "seed", "let", "param", "state", "transition", "stinger", "bind", "mini-notation", "## "]:
		check("system.md mentions: " + word, system_md.to_lower().contains(word))
	check("system.md has no CR", not system_md.contains("\r"))
	check("no denied words in pack.json, examples or README", denied_word(pack_text) == "" and denied_word(all_text) == "" and denied_word(FileAccess.get_file_as_string(pack_dir.path_join("README.md"))) == "")

	# 4. build()
	var req := "A tense chase through a neon city."
	var p: Dictionary = PromptScript.build(req, catalog)
	check("build ok", p.error == "" and p.system != "" and p.messages is Array, str(p.error))
	var n_ex: int = pack.examples.size()
	check("message count = 2 per example + the request", p.messages.size() == 2 * n_ex + 1, str(p.messages.size()))
	check("system = system.md + instrument table", p.system.begins_with(system_md.rstrip("\n")) and p.system.contains("\n\n## Instruments\n\n" + catalog.to_prompt_table().rstrip("\n")) and p.system.ends_with("\n"))
	var roles_ok := true
	var keys_ok := true
	for i in p.messages.size():
		var m: Dictionary = p.messages[i]
		roles_ok = roles_ok and m.role == ("user" if i % 2 == 0 else "assistant")
		keys_ok = keys_ok and str(m.keys()) == str(["role", "content"])
	check("roles alternate user/assistant and end with user", roles_ok and p.messages[p.messages.size() - 1].role == "user")
	check("messages are exactly {role, content}", keys_ok)
	check("last message is the request", p.messages[p.messages.size() - 1].content == req)
	var first_cue := FileAccess.get_file_as_string(pack_dir.path_join(str(pack.examples[0].cue_file)))
	check("first pair is the first example", p.messages[0].content == pack.examples[0].request and p.messages[1].content == first_cue.rstrip("\n"))
	check("assistant messages pass the checker", CheckerScript.check_source(String(p.messages[1].content) + "\n", "m", catalog.validator_catalog()).ok)
	var p2: Dictionary = PromptScript.build(req, catalog)
	check("build is deterministic", p2 == p)
	check("request is stripped", PromptScript.build("  hello \n", catalog).messages.back().content == "hello")
	var empty: Dictionary = PromptScript.build("   ", catalog)
	check("empty request is an error", empty.error != "" and empty.messages.is_empty() and empty.system == "", str(empty))
	var bad: Dictionary = PromptScript.build(req, catalog, ProjectSettings.globalize_path("user://no_such_pack_dir"))
	check("missing pack is an error", bad.error != "" and bad.messages.is_empty(), str(bad))
	check("load_pack reports the problem", PromptScript.load_pack(ProjectSettings.globalize_path("user://no_such_pack_dir")).ok == false)

	# 5. to_text()
	var t: String = PromptScript.to_text(p)
	check("text starts with the system block", t.begins_with("=== SYSTEM ===\n" + String(p.system).left(30)))
	check("block counts", t.count("=== USER ===\n") == n_ex + 1 and t.count("=== ASSISTANT ===\n") == n_ex and t.count("=== SYSTEM ===\n") == 1)
	check("text ends with the request and one newline", t.ends_with("=== USER ===\n" + req + "\n") and not t.ends_with("\n\n"))

	# 6. CLI logic
	var ok: Dictionary = PromptScript.run(PackedStringArray(["--request", req]))
	check("run ok equals to_text(build)", ok.exit_code == 0 and ok.error == "" and ok.text == t, str(ok.exit_code))
	check("run usage: no args", PromptScript.run(PackedStringArray()).exit_code == 2)
	check("run usage: missing value", PromptScript.run(PackedStringArray(["--request"])).exit_code == 2)
	check("run usage: empty request", PromptScript.run(PackedStringArray(["--request", ""])).exit_code == 2)
	check("run usage: unknown option", PromptScript.run(PackedStringArray(["--request", req, "--nope"])).exit_code == 2)
	check("run: bad pack dir", PromptScript.run(PackedStringArray(["--request", req, "--pack", ProjectSettings.globalize_path("user://no_such_pack_dir")])).exit_code == 2)
	var with_pack: Dictionary = PromptScript.run(PackedStringArray(["--request", req, "--pack", pack_dir]))
	check("run with an explicit pack dir", with_pack.exit_code == 0 and with_pack.text == t)

	if failures == 0:
		print("PASS all ", checks, " checks")
		quit(0)
	else:
		print("FAIL ", failures, " of ", checks)
		quit(1)
