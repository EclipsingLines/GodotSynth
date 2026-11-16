extends SceneTree
# CueRenderer: cue + scenario to frames, events, sections, WAV, CLI logic.
# Run: Godot --headless --audio-driver Dummy --path project -s ../tests/test_cue_render.gd

const RendererScript = preload("res://addons/godot_synth/cue/cue_renderer.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")

const SR := 22050
const CUE_LINES := [
	"tempo 120",
	"seed 1",
	"param danger 0..1 = 0",
	"state calm:",
	"  s(\"kick*2\")",
	"state fight:",
	"  s(\"kick*4\")",
	"  s(\"hat*8\")",
	"transition calm -> fight on bar",
	"stinger hit on beat len 1: s(\"hat*2\")",
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

func cue_text() -> String:
	return "\n".join(CUE_LINES) + "\n"

func scenario() -> Dictionary:
	return {
		"duration_cycles": 4, "sample_rate": SR, "tail_sec": 0.5,
		"events": [
			{"at": 1.3, "stinger": "hit"},
			{"at": 1.0, "set_state": "fight"},
			{"at": 0.0, "set_param": "danger", "value": 0.7},
		],
	}

func on_frames(events: Array, track: String) -> Array:
	var out: Array = []
	for e: Dictionary in events:
		if e.get("type") == "note" and e.get("track") == track:
			out.append(int(e.on_frame))
	out.sort()
	return out

func peak_in(a: PackedVector2Array, from: int, to: int) -> float:
	var p := 0.0
	for i in range(from, mini(to, a.size())):
		p = maxf(p, maxf(absf(a[i].x), absf(a[i].y)))
	return p

func parse_wav(b: PackedByteArray) -> Dictionary:
	var out: Dictionary = {}
	if b.size() < 12 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WAVE":
		return out
	var pos := 12
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var sz := b.decode_u32(pos + 4)
		if id == "fmt ":
			out["channels"] = b.decode_u16(pos + 10)
			out["rate"] = b.decode_u32(pos + 12)
			out["bits"] = b.decode_u16(pos + 22)
		elif id == "data":
			out["data_size"] = sz
			out["data_pos"] = pos + 8
			break
		pos += 8 + sz + (sz & 1)
	return out

func _initialize() -> void:
	var catalog = CatalogScript.load_default()
	var r: Dictionary = RendererScript.render(cue_text(), scenario(), catalog)
	check("render ok", r.ok, str(r.diagnostics))
	if not r.ok:
		print("FAIL ", failures, " of ", checks)
		quit(1)
		return
	for k in ["ok", "diagnostics", "sample_rate", "cps", "duration_cycles", "frames", "events", "log", "sections"]:
		check("result key " + k, r.has(k), k)
	check("sample rate", r.sample_rate == SR, str(r.sample_rate))
	check("cps", is_equal_approx(r.cps, 0.5), str(r.cps))

	# frame count = (duration_cycles / cps + tail) * rate
	var expect_frames: int = roundi(4.0 / 0.5 * float(SR)) + roundi(0.5 * float(SR))
	check("frame count", r.frames.size() == expect_frames, "%d vs %d" % [r.frames.size(), expect_frames])

	# sections: calm [0,1) and fight [1,4)
	check("two sections", r.sections.size() == 2, str(r.sections))
	if r.sections.size() == 2:
		var s0: Dictionary = r.sections[0]
		var s1: Dictionary = r.sections[1]
		check("section 0", s0.state == "calm" and s0.start_frame == 0 and s0.end_frame == 2 * SR and is_equal_approx(s0.end_cycle, 1.0), str(s0))
		check("section 1", s1.state == "fight" and s1.start_frame == 2 * SR and s1.end_frame == expect_frames and is_equal_approx(s1.end_cycle, 4.0), str(s1))

	# events at expected frames (one cycle = 2 s = 2 * SR frames; a quarter cycle = SR / 2)
	var calm_kick := on_frames(r.events, "calm/kick")
	check("calm kick frames", calm_kick == [0, SR], str(calm_kick))
	var fight_kick := on_frames(r.events, "fight/kick")
	check("fight kick count", fight_kick.size() == 12, str(fight_kick.size()))
	check("fight kick first frames", fight_kick.size() >= 2 and fight_kick[0] == 2 * SR and fight_kick[1] == 2 * SR + SR / 2, str(fight_kick.slice(0, 3)))
	check("fight hat count", on_frames(r.events, "fight/hat").size() == 24, str(on_frames(r.events, "fight/hat").size()))
	var hits := on_frames(r.events, "stingers/hat")
	check("stinger quantized to the next beat (cycle 1.5 and 2.0)", hits == [3 * SR, 4 * SR], str(hits))

	var switched := false
	for e: Dictionary in r.log:
		if e.get("type") == "switch" and e.get("to") == "fight" and absf(float(e.cycle) - 1.0) < 1e-9:
			switched = true
	check("log has the switch at cycle 1", switched, str(r.log))
	check("audio present after the switch", peak_in(r.frames, 2 * SR, 3 * SR) > 0.001, str(peak_in(r.frames, 2 * SR, 3 * SR)))

	# determinism (the stock drum presets use the engine's random noise waveform,
	# which is random by design, so compare on presets without a noise layer)
	var r2: Dictionary = RendererScript.render(cue_text(), scenario(), catalog)
	check("two renders have the same events", r2.ok and r2.events == r.events, str(r2.diagnostics))
	var det_catalog = CatalogScript.from_dict({"version": 1, "instruments": {
		"kick": {"preset": "BassPreset", "polyphony": 2},
		"hat": {"preset": "BassPreset", "polyphony": 4},
	}})
	check("deterministic catalog loads", det_catalog.errors.is_empty(), str(det_catalog.errors))
	var d1: Dictionary = RendererScript.render(cue_text(), scenario(), det_catalog)
	var d2: Dictionary = RendererScript.render(cue_text(), scenario(), det_catalog)
	check("two renders are bit-identical", d1.ok and d2.ok and d1.frames == d2.frames and d1.events == d2.events, str(d1.diagnostics) + " " + str(d2.diagnostics))

	# WAV
	var wav_path := ProjectSettings.globalize_path("user://cue_render_test.wav")
	var err: int = RendererScript.save_wav(r.frames, r.sample_rate, wav_path)
	check("save_wav ok", err == OK, str(err))
	var bytes := FileAccess.get_file_as_bytes(wav_path)
	var w := parse_wav(bytes)
	check("wav is RIFF/WAVE with fmt and data", w.has("data_pos"), str(bytes.size()))
	if w.has("data_pos"):
		check("wav stereo 16-bit at the rate", w.channels == 2 and w.bits == 16 and w.rate == SR, str(w))
		check("wav data size", w.data_size == expect_frames * 4, str(w.data_size))
		var probe: int = 2 * SR + 100
		var want_x: int = clampi(roundi(r.frames[probe].x * 32767.0), -32768, 32767)
		var want_y: int = clampi(roundi(r.frames[probe].y * 32767.0), -32768, 32767)
		check("wav samples match the frames", bytes.decode_s16(int(w.data_pos) + probe * 4) == want_x and bytes.decode_s16(int(w.data_pos) + probe * 4 + 2) == want_y)
	DirAccess.remove_absolute(wav_path)

	# invalid cue
	var bad_inst: Dictionary = RendererScript.render("state a:\n  s(\"nosuch\")\n", RendererScript.default_scenario(), catalog)
	check("unknown instrument fails", not bad_inst.ok and bad_inst.frames.size() == 0, str(bad_inst.diagnostics))
	var has_code := false
	for d: Dictionary in bad_inst.diagnostics:
		if d.code == "E_UNKNOWN_INSTRUMENT":
			has_code = true
	check("E_UNKNOWN_INSTRUMENT reported", has_code, str(bad_inst.diagnostics))
	var bad_syntax: Dictionary = RendererScript.render("state a\n", RendererScript.default_scenario(), catalog)
	check("syntax error fails with E_SYNTAX", not bad_syntax.ok and bad_syntax.diagnostics.size() > 0 and bad_syntax.diagnostics[0].code == "E_SYNTAX", str(bad_syntax.diagnostics))

	# scenario errors
	var bad_state: Dictionary = RendererScript.render(cue_text(), {"duration_cycles": 2, "sample_rate": SR, "events": [{"at": 1.0, "set_state": "nope"}]}, catalog)
	check("unknown state is E_SCENARIO", not bad_state.ok and bad_state.diagnostics.size() == 1 and bad_state.diagnostics[0].code == "E_SCENARIO" and str(bad_state.diagnostics[0].message).contains("nope"), str(bad_state.diagnostics))
	var bad_misc: Dictionary = RendererScript.render(cue_text(), {"duration_cycles": 2, "sample_rate": SR, "events": [
		{"at": 5.0, "set_state": "fight"},
		{"at": 0.5, "set_param": "nope", "value": 1},
		{"at": 0.5, "set_param": "danger"},
		{"at": 0.5, "stinger": "hit", "set_state": "fight"},
		{"at": 0.5, "stinger": "nope"},
	], "extra": 1}, catalog)
	var codes_ok: bool = not bad_misc.ok and bad_misc.diagnostics.size() == 6
	for d: Dictionary in bad_misc.diagnostics:
		codes_ok = codes_ok and d.code == "E_SCENARIO"
	check("every scenario violation is reported once as E_SCENARIO", codes_ok, str(bad_misc.diagnostics))

	var defaults: Dictionary = RendererScript.default_scenario()
	check("default scenario", defaults.duration_cycles == 8.0 and defaults.sample_rate == 44100 and defaults.tail_sec == 2.0 and defaults.events.is_empty(), str(defaults))

	# CLI logic
	var dir := ProjectSettings.globalize_path("user://")
	var cue_path := dir.path_join("cue_render_test.cue")
	var scn_path := dir.path_join("cue_render_test.json")
	var out_path := dir.path_join("cue_render_cli.wav")
	var f := FileAccess.open(cue_path, FileAccess.WRITE)
	f.store_string(cue_text())
	f.close()
	f = FileAccess.open(scn_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"duration_cycles": 2, "sample_rate": SR, "tail_sec": 0.25, "events": [{"at": 1.0, "set_state": "fight"}]}))
	f.close()
	var cli: Dictionary = RendererScript.run(PackedStringArray([cue_path, "--scenario", scn_path, "--out", out_path]))
	check("cli ok", cli.exit_code == 0 and cli.lines.size() == 1 and cli.error == "", str(cli))
	if cli.lines.size() == 1:
		var parsed = JSON.parse_string(cli.lines[0])
		check("cli line is JSON with ok, out, sample_rate, frames, seconds, diagnostics", parsed is Dictionary and parsed.ok == true and parsed.out == out_path and int(parsed.sample_rate) == SR and int(parsed.frames) == 4 * SR + roundi(0.25 * float(SR)) and parsed.has("seconds") and parsed.has("diagnostics"), cli.lines[0])
		check("cli line has no newline", not cli.lines[0].contains("\n"))
	check("cli wrote the wav", FileAccess.file_exists(out_path) and FileAccess.get_file_as_bytes(out_path).slice(0, 4).get_string_from_ascii() == "RIFF")
	f = FileAccess.open(scn_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"events": [{"at": 1.0, "set_state": "nope"}]}))
	f.close()
	DirAccess.remove_absolute(out_path)
	var cli_bad: Dictionary = RendererScript.run(PackedStringArray([cue_path, "--scenario", scn_path, "--out", out_path]))
	check("cli invalid scenario exits 1 and writes nothing", cli_bad.exit_code == 1 and cli_bad.lines.size() == 1 and not FileAccess.file_exists(out_path), str(cli_bad))
	check("cli usage error (no args)", RendererScript.run(PackedStringArray()).exit_code == 2)
	check("cli usage error (no --out)", RendererScript.run(PackedStringArray([cue_path])).exit_code == 2)
	check("cli usage error (missing value)", RendererScript.run(PackedStringArray([cue_path, "--out"])).exit_code == 2)
	check("cli usage error (unknown option)", RendererScript.run(PackedStringArray([cue_path, "--out", out_path, "--nope", "x"])).exit_code == 2)
	var missing: Dictionary = RendererScript.run(PackedStringArray([dir.path_join("nope.cue"), "--out", out_path]))
	check("cli unreadable cue exits 2 with an error", missing.exit_code == 2 and missing.error != "", str(missing))
	DirAccess.remove_absolute(cue_path)
	DirAccess.remove_absolute(scn_path)

	if failures == 0:
		print("PASS all ", checks, " checks")
		quit(0)
	else:
		print("FAIL ", failures, " of ", checks)
		quit(1)
