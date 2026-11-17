extends SceneTree
# CueReference: generated tables, marker replacement, --check, and the page itself.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_reference.gd

const ReferenceScript = preload("res://addons/godot_synth/cue/cue_reference.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")
const CheckerScript = preload("res://addons/godot_synth/cue/cue_checker.gd")

const HEADINGS := [
	"# Cue Language Reference",
	"## 1. A complete example",
	"## 2. Lexical rules",
	"## 3. Statements",
	"## 4. Mini-notation",
	"## 5. Expressions and functions",
	"## 6. Runtime semantics",
	"## 7. Diagnostics",
	"## 8. Instruments",
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

func _initialize() -> void:
	var catalog = CatalogScript.load_default()

	# 1. signature()
	check("signature unary method", ReferenceScript.signature("fast", {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]}) == "fast(numeric)")
	check("signature no-arg method", ReferenceScript.signature("rev", {"kind": "method", "min_args": 0, "max_args": 0, "arg_kinds": []}) == "rev()")
	check("signature bare signal", ReferenceScript.signature("sine", {"kind": "signal", "min_args": 0, "max_args": 0, "arg_kinds": []}) == "sine")
	check("signature bare constructor", ReferenceScript.signature("silence", {"kind": "constructor", "min_args": 0, "max_args": 0, "arg_kinds": []}) == "silence")
	check("signature variadic", ReferenceScript.signature("stack", {"kind": "constructor", "min_args": 1, "max_args": -1, "arg_kinds": ["pattern"]}) == "stack(pattern...)")
	check("signature three args", ReferenceScript.signature("euclidRot", {"kind": "method", "min_args": 3, "max_args": 3, "arg_kinds": ["numeric", "numeric", "numeric"]}) == "euclidRot(numeric, numeric, numeric)")
	check("signature optional arg", ReferenceScript.signature("x", {"kind": "method", "min_args": 1, "max_args": 2, "arg_kinds": ["numeric", "string"]}) == "x(numeric, [string])")
	check("signature signal with arg", ReferenceScript.signature("irand", {"kind": "signal", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]}) == "irand(numeric)")

	# 2. functions_block()
	var fb: String = ReferenceScript.functions_block()
	var rows := fb.split("\n")
	check("functions table header", rows[0] == "| Name | Kind | Signature |" and rows[1] == "|---|---|---|", rows[0])
	check("one row per function", rows.size() == CueLib.FUNCTIONS.size() + 2, "%d rows" % rows.size())
	var names: Array = []
	for i in range(2, rows.size()):
		names.append(rows[i].split("`")[1])
	var sorted_names := names.duplicate()
	sorted_names.sort()
	check("rows are sorted by name", names == sorted_names, str(names))
	var all_present := true
	for k in CueLib.FUNCTIONS.keys():
		all_present = all_present and names.has(k)
	check("every function is listed", all_present)
	check("s is constructor and method", fb.contains("| `s` | constructor, method | `s(string)` |"), fb)
	check("no trailing newline", not fb.ends_with("\n"))

	# 3. instruments_block()
	var ib: String = ReferenceScript.instruments_block(catalog)
	check("instruments block is a text fence", ib.begins_with("```text\n") and ib.ends_with("\n```"), ib.left(40))
	var all_inst := true
	for n in catalog.instrument_names():
		all_inst = all_inst and ib.contains("\n" + n + " | ")
	check("every instrument has a line", all_inst, ib)

	# 4. replace_block / regenerate on a synthetic doc
	var B1: String = ReferenceScript.FUNCTIONS_BEGIN
	var E1: String = ReferenceScript.FUNCTIONS_END
	var B2: String = ReferenceScript.INSTRUMENTS_BEGIN
	var E2: String = ReferenceScript.INSTRUMENTS_END
	var doc := "intro\n%s\nOLD\n%s\nmiddle\n%s\nOLD2\n%s\noutro\n" % [B1, E1, B2, E2]
	var rb: Dictionary = ReferenceScript.replace_block(doc, B1, E1, "BODY")
	check("replace_block ok and keeps outside text", rb.ok and rb.text == "intro\n%s\nBODY\n%s\nmiddle\n%s\nOLD2\n%s\noutro\n" % [B1, E1, B2, E2], str(rb))
	var rg: Dictionary = ReferenceScript.regenerate(doc, catalog)
	check("regenerate ok", rg.ok, str(rg))
	check("regenerate fills both blocks", rg.text.contains(fb) and rg.text.contains(ib) and not rg.text.contains("OLD"))
	var rg2: Dictionary = ReferenceScript.regenerate(rg.text, catalog)
	check("regenerate is idempotent", rg2.ok and rg2.text == rg.text)
	check("missing marker is an error", not ReferenceScript.replace_block("no markers here", B1, E1, "x").ok and not ReferenceScript.replace_block(B1 + "\nonly begin\n", B1, E1, "x").ok)
	check("end before begin is an error", not ReferenceScript.replace_block(E1 + "\n" + B1 + "\n", B1, E1, "x").ok)
	check("duplicate marker is an error", not ReferenceScript.replace_block(doc + B1 + "\n" + E1 + "\n", B1, E1, "x").ok)

	# 5. the real page is up to date, and run(--check) agrees
	var doc_path: String = ReferenceScript.default_doc_path()
	check("docs/cue-language.md exists", FileAccess.file_exists(doc_path), doc_path)
	var page := FileAccess.get_file_as_string(doc_path)
	var regen: Dictionary = ReferenceScript.regenerate(page, catalog)
	check("page regenerates without error", regen.ok, str(regen))
	check("page is up to date (run tools/cue_reference.gd to refresh)", regen.ok and regen.text == page)
	var chk: Dictionary = ReferenceScript.run(PackedStringArray(["--check", "--doc", doc_path]))
	check("--check passes on the page", chk.exit_code == 0 and chk.lines.size() == 1 and chk.lines[0] == "up to date", str(chk))
	var chk_default: Dictionary = ReferenceScript.run(PackedStringArray(["--check"]))
	check("--check uses the default doc path", chk_default.exit_code == 0, str(chk_default))

	# 6. stale detection and write mode on a temp copy
	var tmp := ProjectSettings.globalize_path("user://cue_reference_test.md")
	var stale := page.replace("| `fast` | method | `fast(numeric)` |", "| `fast` | method | `fast(STALE)` |")
	check("the stale copy differs from the page", stale != page)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(stale)
	f.close()
	var chk_stale: Dictionary = ReferenceScript.run(PackedStringArray(["--check", "--doc", tmp]))
	check("--check fails on a stale doc", chk_stale.exit_code == 1 and chk_stale.lines.size() == 1 and str(chk_stale.lines[0]).begins_with("out of date"), str(chk_stale))
	check("--check wrote nothing", FileAccess.get_file_as_string(tmp) == stale)
	var fix: Dictionary = ReferenceScript.run(PackedStringArray(["--doc", tmp]))
	check("write mode updates the file", fix.exit_code == 0 and fix.lines.size() == 1 and fix.lines[0] == "updated " + tmp, str(fix))
	check("the file now equals the page", FileAccess.get_file_as_string(tmp) == page)
	var again: Dictionary = ReferenceScript.run(PackedStringArray(["--doc", tmp]))
	check("second write reports unchanged", again.exit_code == 0 and again.lines.size() == 1 and again.lines[0] == "unchanged " + tmp, str(again))
	DirAccess.remove_absolute(tmp)
	check("usage error", ReferenceScript.run(PackedStringArray(["--bogus"])).exit_code == 2 and ReferenceScript.run(PackedStringArray(["--doc"])).exit_code == 2)
	check("missing doc is exit 2", ReferenceScript.run(PackedStringArray(["--check", "--doc", tmp])).exit_code == 2)

	# 7. the hand-written part
	check("front matter", page.begins_with("---\nlayout: custom_default\ntitle: Cue Language Reference\n---\n"), page.left(80))
	check("no Liquid tags and no CR", not page.contains("{{") and not page.contains("{%") and not page.contains("\r"))
	var pos := 0
	var in_order := true
	for h: String in HEADINGS:
		var at := page.find("\n" + h + "\n", pos)
		if at < 0:
			in_order = false
			print("  missing or out of order heading: ", h)
			break
		pos = at + 1
	check("headings present in order", in_order)
	check("example uses hat, not crash", page.contains("fill s(\"hat\")") and not page.contains("crash"))
	for code in ["E_SYNTAX", "E_UNKNOWN_INSTRUMENT", "E_UNKNOWN_CONTROL", "E_BIND_CONFLICT", "E_MINI", "W_N_WITHOUT_SCALE", "W_UNUSED_LET"]:
		check("diagnostic code documented: " + code, page.contains(code))

	# 8. the main example is a valid cue with the real catalog
	var start := page.find("```cue\n")
	var stop := page.find("\n```", start + 7)
	check("example fence found", start >= 0 and stop > start)
	if start >= 0 and stop > start:
		var example := page.substr(start + 7, stop - (start + 7)) + "\n"
		var res: Dictionary = CheckerScript.check_source(example, "cue-language.md", catalog.validator_catalog())
		check("the page's example passes cue_check with the real catalog", res.ok, str(res.diagnostics))
		check("the example is the forest cue", example.contains("state explore:") and example.contains("state combat:") and example.contains("stinger found") and example.contains("bind pad.lpf"))

	if failures == 0:
		print("PASS all ", checks, " checks")
		quit(0)
	else:
		print("FAIL ", failures, " of ", checks)
		quit(1)
