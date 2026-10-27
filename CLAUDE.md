# GodotSynth

A GDExtension (C++, godot-cpp) that adds a modular synthesizer to Godot 4.7+ (built against the 4.7 API): an engine for virtual analog, chord and future synths, modulation sources, modulated effects, and a GDScript editor addon. It's a public MIT project (github.com/EclipsingLines/GodotSynth). It's in beta, currently v0.95. See README.md for the user-facing API and CHANGELOG.md for releases.

## Build

- **Local Windows build (verified 2026-10-27):** run `python -m SCons target=template_debug -j8` from **PowerShell or cmd**, at the repo root. SCons finds MSVC on its own (VS 2022 Build Tools are installed), so there's no need for a VS dev prompt. MSVC builds fail under Git Bash/MSYS, so never run them from the Bash tool.
  - SCons 4.11 is pip-installed per user (`python -m pip install --user scons`). Its `scons.exe` is not on PATH, so use `python -m SCons`.
  - A clean build compiles all of godot-cpp first, which takes several minutes, so run it in the background. Later builds are incremental.
- Use `target=template_release` for release. The VS Code `build` task runs plain `scons`. CI (`.github/workflows/`) pins SCons 4.4.0 and cross-compiles Windows with MinGW on Ubuntu.
- SCons globs every `.cpp` under `src/synth/` up to 4 levels deep, so new files need no build-script edits.
- Output goes to `godot_synth/bin/` and is installed into `project/addons/godot_synth/bin/`. On Windows the output is `libgodot_synth.windows.{debug|release}.x86_64.dll`, and its name must match `project/addons/godot_synth/godot_synth.gdextension` (entry symbol `synth_library_init`). Godot must be closed or the DLL is locked.
- `godot-cpp/` is a git submodule (github.com/godotengine/godot-cpp), pinned to `10.0.0-stable`. godot-cpp is now versioned independently of Godot and v10 supports Godot 4.3–4.7; the target engine API is picked with `api_version`. `SConstruct` passes `"api_version": "4.7"` to `SConscript("godot-cpp/SConstruct", ...)` (the way godot-cpp's README documents), and `api_version=4.x` on the command line overrides it. A build that targets 4.7 won't load in older Godot. After cloning, run `git submodule update --init`. To change versions, `git -C godot-cpp fetch --tags origin`, `git -C godot-cpp checkout <tag>` and then `git add godot-cpp`. A clean build takes about 7 minutes locally, most of it compiling godot-cpp.
- The committed release binaries in `project/addons/godot_synth/bin/` (~3–16 KB) look like empty stubs from a broken CI run. Don't trust them.
- Known pitfall: `LNK4042` on `src/gen/doc_data.gen.*.obj` (the object is specified twice) is treated as an error. Clean the stale `.obj` before relinking.
- There are no automated tests. To verify, build, open `project/` in Godot and play `addons/godot_synth/keyboard/piano_keyboard.tscn`. `project/issue_1.gd` is a repro scene script.

## Layout

- `src/synth/register_types.cpp`: every class must be registered here (`GDREGISTER_CLASS` or `GDREGISTER_ABSTRACT_CLASS`), grouped into `register_*()` helpers. Reverb is intentionally left unregistered because of CPU cost.
- `src/synth/core/`: `AudioSynthPlayer` (node, voice allocation), `SynthNoteContext` (per-note handle: note_on/off, velocity, articulation), `SynthVoice`, `SynthConfiguration` (abstract) plus `ConfigurationPrototype`/`SynthPreset`, `AudioStreamGeneratorEngine` (abstract oscillator engine) plus `EngineFactory`, `ModulatedParameter`/`ModulationSource`, `WaveHelperCache`, `PitchHelper`, and the stream/playback classes.
- `src/synth/va/` is the virtual analog engine (the shipped one). `src/synth/chord/` is the chord engine (work in progress).
- `src/synth/mod/`: modulation sources (adsr, lfo, velocity, keyboard tracking, note duration, articulation).
- `src/synth/effects/`: `SynthAudioEffect` base, `EffectChain`, and the `filter/`, `delay/`, `distortion/` and `spatial/` effects.
- `src/synth/time/`: `BpmManager`, `Sequencer`.
- `src/synth/ext/`: vendored third-party headers (`qoa.h`). Don't reformat them.
- `project/addons/godot_synth/`: the editor plugin (`synth_plugin.gd`), custom inspectors (ADSR/LFO/modulated-parameter editors), the `keyboard/` test scene, the `music_engine/` GDScript helpers (arpeggio, motif, rhythms), and the `.tres` presets in `assets/`.
- `docs/` is the Jekyll GitHub Pages site (eclipsinglines.github.io/GodotSynth). Anything added there is published.
- `design/` holds internal design notes that are not published: the QOA/preload plan migrated from cline. `custom_inspector_implementation.md` at the root is an older design note.

## Headless checks in Godot 4.7

Use the console exe (`C:\Godot\4.7\Godot_v4.7-stable_win64_console.exe`), which prints to stdout. Build the DLL first. Run these from the repo root:
- Parse-check one script: `--headless --path project --check-only --script res://addons/godot_synth/<file>.gd`. Exit code 0 means it parsed.
- Scripted run: `--headless --audio-driver Dummy --path project -s <path\to\script.gd>`, where the script `extends SceneTree`. Keep it in the scratchpad, not in `project/`. For a smoke test, load `res://addons/godot_synth/keyboard/piano_keyboard.tscn`, add it to `root`, and call `play_note`/`stop_note` on its `CenterContainer` node (the `SynthPlayer` script) for a few frames. Then return `true` from `_process` to quit. Don't let a script error loop forever, because it floods stdout.
- Add `--verbose` to see which addon scripts and resources load and to get details on leaked instances.
- Known noise: the editor prints about 148 `Instantiated ModulatedParameter used as default value for <Effect>'s "<x>_parameter" property` warnings. The VA engine also prints `Fast Pitch`/`Regular Exp`/`Virtual Analog took ...` lines on every audio block.
- A `-s` script that calls `ResourceSaver.save` drops the `uid=` fields from `.tscn`/`.tres` files, so resave scenes in the real editor instead.

## Conventions

- Format with the repo's `.clang-format`: LLVM base, **tabs**, indent width 4, no column limit.
- Source files use **CRLF** line endings. Keep them CRLF when editing.
- Headers use `#ifndef NAME_H` include guards. Everything goes in `namespace godot { … }`. Classes use `GDCLASS(Name, Base)` with `static void _bind_methods()` in `protected:`. Parameters are prefixed `p_`, and there are `set_x`/`get_x` pairs exposed with `ClassDB::bind_method(D_METHOD(...))` plus `ADD_PROPERTY`.
- Modulation sources implement `get_value(const Ref<SynthNoteContext>&) const`, `reset()` and `duplicate()`.
- Effect parameters should be `ModulatedParameter`s so they can take modulation.
- Audio-thread code must not allocate or lock in the per-sample path.
- Update CHANGELOG.md (Keep a Changelog format) for user-visible changes.

## In-flight work (as of migration, Oct 2026)

- Uncommitted changes in core/va/chord: fractional MIDI notes (`SynthNoteContext.note` changed from int to float), a new `PitchHelper` class with a fast-pitch path (`process_block(..., use_fast_pitch)`), and `SynthConfiguration.mod_update_rate` (modulation is recomputed every N samples, default 8).
- `docs/multiple_notes.md` (staged) documents `AudioSynthPlayer.play_note_on_context` and `SynthNoteContext.note_on_deferred`. **Neither exists in `src/` yet.** Either implement them or fix the doc before publishing. The bug it describes is that only the last of several same-frame notes plays (repro: `project/issue_1.gd`).
- Planned: QOA-compressed offline note rendering and preloading. See `design/qoa_preload.md`.
- Roadmap (README/CHANGELOG): chord engine, 4-op FM, formant, wavetable, SIMD, LFO lookup tables, step sequencer.
